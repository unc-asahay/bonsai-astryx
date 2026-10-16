#!/usr/bin/env node
// Verify a page in a REAL browser, served over HTTP on localhost.
//
// This is the strongest gate here, and it is deliberately different from
// tools/visual/verify-dom.mjs:
//
//   verify-dom.mjs      jsdom, eval of the bundle in a fake DOM — fast, CI-friendly,
//                       but jsdom is not a browser: no real layout, no real CSS
//                       cascade, no real event loop, no clicks.
//   verify-browser.mjs  Chromium from the playwright cache, loading the page over
//                       HTTP exactly as a person would — real fetch of the CSS and
//                       the js_of_ocaml bundle, real JS engine, real layout, real
//                       clicks. It therefore tests things jsdom cannot, and it
//                       captures a screenshot so the appearance is on disk.
//
// Two modes, chosen by the URL:
//   .../examples/demo/index.html   the demo fixture the jsdom gate also covers
//   .../site/index.html            the showcase site (all sections + coverage)
//
// Usage:
//   python3 -m http.server 8791 --bind 127.0.0.1     # from the repo root
//   node tools/visual/verify-browser.mjs [url]

import { createRequire } from "node:module";
import { existsSync, readdirSync, mkdirSync } from "node:fs";
import { resolve, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const require = createRequire(import.meta.url);
const here = dirname(fileURLToPath(import.meta.url));
const root = resolve(here, "../..");

const url = process.argv[2] || "http://127.0.0.1:8791/examples/demo/index.html";
const mode = url.includes("/site/") ? "showcase" : "demo";

// playwright lives in the upstream clone's node_modules; the browsers in the
// default cache. Find a usable chromium binary rather than assuming a revision.
function playwright() {
  for (const p of [
    resolve(root, "node_modules/playwright"),
    resolve(root, "../astryx/node_modules/playwright"),
    "/home/noor/src/astryx/node_modules/playwright",
  ]) {
    if (existsSync(p)) return require(p);
  }
  throw new Error("playwright not found (looked in node_modules of this repo and ../astryx)");
}

function chromiumExecutable() {
  const cache = resolve(process.env.HOME || "/home/noor", ".cache/ms-playwright");
  if (!existsSync(cache)) throw new Error(`no playwright browser cache at ${cache}`);
  // Layouts differ across playwright versions: newer builds ship
  // chrome-linux64/chrome, older ones chrome-linux/chrome. Check both rather
  // than assume, and prefer the newest revision present.
  const layouts = ["chrome-linux64/chrome", "chrome-linux/chrome"];
  const candidates = readdirSync(cache)
    .filter((d) => d.startsWith("chromium-"))
    .sort()
    .reverse()
    .flatMap((d) => layouts.map((l) => resolve(cache, d, l)))
    .filter(existsSync);
  if (!candidates.length) throw new Error(`no chromium binary under ${cache}`);
  return candidates[0];
}

const exe = chromiumExecutable();
console.log(`mode:     ${mode}`);
console.log(`chromium: ${exe}`);
console.log(`url:      ${url}`);

const { chromium } = playwright();
const browser = await chromium.launch({ executablePath: exe, args: ["--no-sandbox"] });
// reducedMotion + animations:"disabled" on the screenshot below: the skeleton's fade is an
// infinite alternate animation, so an untouched capture lands on an arbitrary phase and the
// committed PNG drifts a few bytes every run. Freezing it also exercises the
// prefers-reduced-motion rules in assets/components.css.
const page = await browser.newPage({
  viewport: { width: 1440, height: 1000 },
  reducedMotion: "reduce",
});

const consoleErrors = [];
const pageErrors = [];
const failedRequests = [];
const badResponses = [];
page.on("console", (m) => {
  if (m.type() === "error") consoleErrors.push(m.text());
});
page.on("pageerror", (e) => pageErrors.push(String(e && e.message ? e.message : e)));
page.on("requestfailed", (r) => failedRequests.push(`${r.url()} — ${r.failure()?.errorText}`));
// A 404 is not a "requestfailed" — the request succeeded, the server said no. This
// listener is how the favicon-style 404 that a console message hides gets a URL.
page.on("response", (r) => {
  if (r.status() >= 400) badResponses.push(`${r.status()} ${r.url()}`);
});

let response;
try {
  response = await page.goto(url, { waitUntil: "load", timeout: 45000 });
} catch (e) {
  console.error(`FAIL goto: ${e.message}`);
  await browser.close();
  process.exit(1);
}

// Wait for the mount. Bonsai replaces the bind element, so wait for a component.
let mounted = false;
try {
  await page.waitForSelector("[data-astryx-component]", { timeout: 30000 });
  mounted = true;
} catch {
  mounted = false;
}

let checks = 0;
let failures = 0;
const check = (label, ok, detail = "") => {
  checks += 1;
  if (!ok) failures += 1;
  console.log(`  ${ok ? "ok  " : "FAIL"} ${label}${detail && !ok ? ` — ${detail}` : ""}`);
};

// ---------------------------------------------------------------- shared

console.log("\npage");
check("HTTP 200 from the local server", response.status() === 200, `got ${response.status()}`);
check("no failed requests", failedRequests.length === 0, failedRequests.join("; "));
check("no 4xx/5xx responses", badResponses.length === 0, badResponses.join("; "));
check("no uncaught page errors", pageErrors.length === 0, pageErrors.join("; "));
check("no console errors", consoleErrors.length === 0, consoleErrors.slice(0, 3).join("; "));
check("the app mounted in Chromium", mounted, "no [data-astryx-component] appeared");

const sheets = await page.evaluate(() =>
  [...document.styleSheets].map((s) => {
    try {
      return { href: s.href, rules: s.cssRules.length };
    } catch {
      return { href: s.href, rules: "error" };
    }
  }),
);
check(
  "every stylesheet parsed",
  sheets.length >= 3 && sheets.every((s) => typeof s.rules === "number" && s.rules > 0),
  JSON.stringify(sheets),
);

const buttonStyle = await page.evaluate(() => {
  const b = document.querySelector(".astryx-button");
  if (!b) return null;
  const cs = getComputedStyle(b);
  return {
    backgroundColor: cs.backgroundColor,
    color: cs.color,
    borderRadius: cs.borderRadius,
    fontSize: cs.fontSize,
    paddingLeft: cs.paddingLeft,
    display: cs.display,
    gap: cs.gap,
    alignItems: cs.alignItems,
  };
});

// ---------------------------------------------------------------- demo mode

if (mode === "demo") {
  const report = await page.evaluate(() => {
    const els = [...document.querySelectorAll("[data-astryx-component]")];
    const counts = {};
    for (const el of els) {
      const n = el.getAttribute("data-astryx-component");
      counts[n] = (counts[n] || 0) + 1;
    }
    const byTag = {};
    for (const t of ["h1", "h2", "h3", "button", "section", "span", "div"]) {
      byTag[t] = document.querySelectorAll(t).length;
    }
    return {
      total: els.length,
      counts,
      byTag,
      title: document.title,
      bodyBackground: getComputedStyle(document.body).backgroundColor,
    };
  });

  console.log("\nmount");
  check("title is the demo's", report.title === "bonsai-astryx demo", report.title);
  check("47 component instances", report.total === 47, `got ${report.total}`);
  check("Stack x12", report.counts.Stack === 12, `got ${report.counts.Stack}`);
  check("Button x7", report.counts.Button === 7, `got ${report.counts.Button}`);
  check("Heading x6", report.counts.Heading === 6, `got ${report.counts.Heading}`);
  check("Text x6", report.counts.Text === 6, `got ${report.counts.Text}`);
  check("Badge x5", report.counts.Badge === 5, `got ${report.counts.Badge}`);
  check("one h1", report.byTag.h1 === 1, `got ${report.byTag.h1}`);
  check("five h3", report.byTag.h3 === 5, `got ${report.byTag.h3}`);

  console.log("\nstylesheet applied (what jsdom cannot check)");
  const bs = buttonStyle || {};
  check("button has the primary fill from the token", bs.backgroundColor === "rgb(0, 100, 224)", bs.backgroundColor);
  check("button text is white-on-accent", bs.color === "rgb(255, 255, 255)", bs.color);
  check("button radius is 8px", bs.borderRadius === "8px", bs.borderRadius);
  check("button type size is 14px (0.875rem)", bs.fontSize === "14px", bs.fontSize);
  // --spacing-3 is 0.75rem = 12px. (An earlier version of this assertion said 8px,
  // which is --spacing-2 — that was the gap, not the padding.)
  check("button padding-inline is --spacing-3 (12px)", bs.paddingLeft === "12px", bs.paddingLeft);
  check("button gap is --spacing-2 (8px)", bs.gap === "8px", bs.gap);
  check("button aligns its content to the centre", bs.alignItems === "center", bs.alignItems);
  // .astryx-button declares inline-flex, but a flex item's inline-level display is
  // *blockified* by CSS, so the computed value is `flex`. Asserting "inline-flex"
  // here would be asserting something the browser is spec-correct to never report.
  check("button display is blockified to flex (it is a flex item)", bs.display === "flex", bs.display);
  check("body picks up the body-background token", report.bodyBackground !== "rgba(0, 0, 0, 0)", report.bodyBackground);
}

// ---------------------------------------------------------------- showcase mode

if (mode === "showcase") {
  const sections = await page.evaluate(() => {
    const out = [];
    for (const sec of document.querySelectorAll("[data-showcase-component]")) {
      out.push({
        id: sec.id,
        name: sec.getAttribute("data-showcase-component"),
        examples: sec.querySelectorAll("[data-example]").length,
        components: sec.querySelectorAll("[data-astryx-component]").length,
      });
    }
    return out;
  });

  const EXPECTED = [
    "Stack", "Text", "Heading", "Button", "Badge", "Card", "Divider", "StatusDot",
    "Skeleton", "Center", "Section", "Grid", "VisuallyHidden",
    "HStack", "VStack", "AspectRatio", "IconButton", "Code", "Blockquote",
    "NavIcon", "EmptyState", "Citation", "Icon", "FieldStatus", "Interactive",
  ];

  console.log("\nshowcase sections");
  check("25 sections", sections.length === 25, `got ${sections.length}: ${sections.map((s) => s.name).join(",")}`);
  const names = sections.map((s) => s.name);
  const missing = EXPECTED.filter((n) => !names.includes(n));
  check("every expected component has a section", missing.length === 0, `missing: ${missing.join(", ")}`);
  const empty = sections.filter((s) => s.examples === 0);
  check("no empty section", empty.length === 0, empty.map((s) => s.name).join(", "));
  const noRender = sections.filter((s) => s.components === 0);
  check("every section rendered its own component", noRender.length === 0, noRender.map((s) => s.name).join(", "));
  // The exact per-section counts, verified once and then frozen — a total alone
  // would not notice one section losing an example while another gained one.
  const expectedExamples = {
    Stack: 8, Text: 12, Heading: 6, Button: 14, Badge: 15, Card: 12, Divider: 6,
    StatusDot: 7, Skeleton: 8, Center: 6, Section: 7, Grid: 6, VisuallyHidden: 3,
    HStack: 4, VStack: 4, AspectRatio: 6,
    IconButton: 5, Code: 5, Blockquote: 2,
    NavIcon: 2, EmptyState: 4, Citation: 6, Icon: 6,
    FieldStatus: 4, Interactive: 2,
  };
  const totalExamples = sections.reduce((a, s) => a + s.examples, 0);
  check("160 examples across the page", totalExamples === 160, `got ${totalExamples}`);
  const wrongExamples = sections.filter((s) => expectedExamples[s.name] !== s.examples);
  check(
    "every section's example count is the expected one",
    wrongExamples.length === 0,
    wrongExamples.map((s) => `${s.name}: ${s.examples} (expected ${expectedExamples[s.name]})`).join(", "),
  );
  console.log(`       ${sections.map((s) => `${s.name}:${s.examples}`).join(" ")}`);

  console.log("\nnavigation");
  const nav = await page.evaluate(() =>
    [...document.querySelectorAll(".nav-list a")].map((a) => a.getAttribute("href")),
  );
  check("25 nav links", nav.length === 25, `got ${nav.length}`);
  const ids = new Set(sections.filter((s) => s.id).map((s) => `#${s.id}`));
  const dangling = nav.filter((h) => !ids.has(h));
  check("no dangling nav link", dangling.length === 0, dangling.join(", "));
  const unlinked = [...ids].filter((h) => !nav.includes(h));
  check("no section missing from the nav", unlinked.length === 0, unlinked.join(", "));

  console.log("\nvariant coverage");
  const buttonClasses = await page.evaluate(() =>
    [...document.querySelectorAll("#button .astryx-button")].map((e) => e.className).join(" "),
  );
  for (const v of ["primary", "secondary", "ghost", "destructive"]) {
    check(`Button variant ${v} present`, buttonClasses.includes(`astryx-button--${v}`), buttonClasses.slice(0, 120));
  }
  const badgeClasses = await page.evaluate(() =>
    [...document.querySelectorAll("#badge .astryx-badge")].map((e) => e.className).join(" "),
  );
  const badgeVariants = ["neutral", "info", "success", "warning", "error", "blue", "cyan", "green", "orange", "pink", "purple", "red", "teal", "yellow"];
  const missingBadge = badgeVariants.filter((v) => !badgeClasses.includes(`astryx-badge--${v}`));
  check(`all ${badgeVariants.length} Badge variants present`, missingBadge.length === 0, `missing: ${missingBadge.join(", ")}`);

  const gridCols = await page.evaluate(() =>
    [...document.querySelectorAll("#grid [data-astryx-columns]")].map((e) => e.getAttribute("data-astryx-columns")),
  );
  check("Grid emitted repeat(n, 1fr) tracks", gridCols.filter((c) => /^repeat\(\d+, 1fr\)$/.test(c)).length >= 3, gridCols.join(" | "));
  check("Grid emitted an auto-fill track", gridCols.some((c) => c.includes("auto-fill")), gridCols.join(" | "));
  check("Grid emitted an auto-fit track", gridCols.some((c) => c.includes("auto-fit")), gridCols.join(" | "));

  const headings = await page.evaluate(() =>
    [...document.querySelectorAll("#heading h1, #heading h2, #heading h3, #heading h4, #heading h5, #heading h6")].map((e) => e.tagName.toLowerCase()),
  );
  check("Heading rendered all six levels as real elements", new Set(headings).size >= 6, headings.join(","));

  console.log("\ninteraction (a real click — impossible in jsdom here)");
  const before = await page.textContent("#click-count");
  const clicked = await page.evaluate(() => {
    const sec = document.getElementById("interactive");
    const btn = sec && sec.querySelector("button");
    if (!btn) return false;
    btn.click();
    return true;
  });
  await page.waitForTimeout(200);
  const after = await page.textContent("#click-count");
  check("the counter button is present", clicked);
  check(`counter starts at 0 (read "${before}")`, (before || "").trim() === "count: 0", before || "");
  check(`counter incremented on click (now "${after}")`, (after || "").trim() === "count: 1", after || "");
  await page.evaluate(() => document.querySelector("#interactive button").click());
  await page.waitForTimeout(200);
  const after2 = await page.textContent("#click-count");
  check(`counter incremented again (now "${after2}")`, (after2 || "").trim() === "count: 2", after2 || "");

  // Keyboard operability, the part that cannot be faked in jsdom: focus the ported
  // button the way a keyboard user reaches it, then press Enter. Chromium turns that
  // into a click for a native <button>, so an increment here proves the control is
  // actually keyboard-activatable — not merely that it has the right attributes.
  console.log("\nkeyboard");
  const focused = await page.evaluate(() => {
    const btn = document.querySelector("#interactive button");
    if (!btn) return null;
    btn.focus();
    const active = document.activeElement;
    return {
      isButton: active && active.tagName.toLowerCase() === "button",
      hasFocus: active === btn,
      tabindex: btn.getAttribute("tabindex"),
    };
  });
  check("the ported button takes focus programmatically", focused?.hasFocus === true, JSON.stringify(focused));
  check("focus lands on the button itself, not a wrapper", focused?.isButton === true);
  check("no negative tabindex (so Tab reaches it)", focused?.tabindex !== "-1");
  const beforeKey = await page.textContent("#click-count");
  await page.keyboard.press("Enter");
  await page.waitForTimeout(200);
  const afterKey = await page.textContent("#click-count");
  const num = (s) => Number(String(s || "").replace(/\D/g, ""));
  check(
    `Enter on the focused button activates it (${(beforeKey || "").trim()} -> ${(afterKey || "").trim()})`,
    num(afterKey) === num(beforeKey) + 1,
    `${beforeKey} -> ${afterKey}`,
  );

  console.log("\naccessibility (read from the live tree)");
  const aria = await page.evaluate(() => {
    const dot = document.querySelector(".astryx-status-dot");
    const buttons = [...document.querySelectorAll("#button .astryx-button")];
    const loading = buttons.find((b) => b.getAttribute("aria-busy") === "true");
    const iconOnly = buttons.find((b) => b.getAttribute("aria-label"));
    return {
      dotRole: dot && dot.getAttribute("role"),
      dotLabel: dot && dot.getAttribute("aria-label"),
      loadingAriaBusy: !!loading,
      loadingHasNativeDisabled: loading ? loading.hasAttribute("disabled") : null,
      iconOnlyLabel: iconOnly && iconOnly.getAttribute("aria-label"),
    };
  });
  check("StatusDot exposes role=img", aria.dotRole === "img", String(aria.dotRole));
  check("StatusDot carries its label", !!aria.dotLabel, String(aria.dotLabel));
  check("loading Button sets aria-busy", aria.loadingAriaBusy);
  check("loading Button does NOT use native disabled", aria.loadingHasNativeDisabled === false, String(aria.loadingHasNativeDisabled));
  check("icon-only Button has an aria-label", !!aria.iconOnlyLabel, String(aria.iconOnlyLabel));

  // --- Icon: the sizes only work if the size class also sets font-size ----------
  // The glyph carries width="1em" height="1em" (upstream's attribute). A size class that
  // sets width/height in rem but leaves font-size inherited renders every size at the
  // inherited size — which looks plausible in a screenshot and is wrong. Measure it.
  console.log("\nicon rendering (measured, not asserted from the markup)");
  const icons = await page.evaluate(() => {
    const expected = { xsm: 12, sm: 16, md: 20, lg: 24 };
    const out = { sizes: {}, glyphs: 0, icons: 0, missing: 0, colored: null, svgNs: null, glyphNs: null };
    for (const el of document.querySelectorAll("#icon .astryx-icon")) {
      out.icons += 1;
      if (el.hasAttribute("data-astryx-icon-missing")) {
        out.missing += 1;
        continue;
      }
      const svg = el.querySelector("svg");
      if (svg) {
        out.svgNs = svg.namespaceURI;
        const first = svg.firstElementChild;
        if (first) out.glyphNs = first.namespaceURI;
        out.glyphs += svg.children.length;
      }
      const cls = [...el.classList].find((c) => c.startsWith("astryx-icon--") && expected[c.slice(13)]);
      if (cls) {
        const size = cls.slice(13);
        const box = el.getBoundingClientRect();
        const svgBox = svg ? svg.getBoundingClientRect() : { width: 0, height: 0 };
        out.sizes[size] = out.sizes[size] || {
          want: expected[size],
          w: Math.round(box.width * 100) / 100,
          h: Math.round(box.height * 100) / 100,
          svgW: Math.round(svgBox.width * 100) / 100,
          fontSize: getComputedStyle(el).fontSize,
        };
      }
      if (el.classList.contains("astryx-icon--success")) {
        out.colored = getComputedStyle(el).color;
      }
    }
    return out;
  });

  check("the gallery rendered every icon", icons.icons >= 30, `${icons.icons}`);
  check("only the deliberate unknown name is unrendered", icons.missing === 1, `${icons.missing}`);
  check("glyphs are SVG-namespaced in a real browser too",
    icons.svgNs === "http://www.w3.org/2000/svg" && icons.glyphNs === "http://www.w3.org/2000/svg",
    `${icons.svgNs} / ${icons.glyphNs}`);
  const wrongSizes = Object.entries(icons.sizes).filter(([, v]) =>
    Math.abs(v.w - v.want) > 0.6 || Math.abs(v.h - v.want) > 0.6 || Math.abs(v.svgW - v.want) > 0.6);
  check("every size measures the documented pixel value (and its glyph fills it)",
    Object.keys(icons.sizes).length === 4 && wrongSizes.length === 0,
    Object.entries(icons.sizes).map(([k, v]) => `${k}:${v.w}x${v.h} svg=${v.svgW} want=${v.want}`).join(" "));
  const wrongFont = Object.entries(icons.sizes).filter(([, v]) => Math.abs(parseFloat(v.fontSize) - v.want) > 0.6);
  check("the size class sets font-size too (the 1em trap)", wrongFont.length === 0,
    Object.entries(icons.sizes).map(([k, v]) => `${k}:${v.fontSize}`).join(" "));
  check("a colour class resolves to a real colour, not an inherited one",
    !!icons.colored && icons.colored !== "rgb(0, 0, 0)", String(icons.colored));

  // --- FieldStatus: the parts only a real browser can settle ---------------------
  // The attached variant's whole point is that the overlap is visual only. In jsdom there
  // is no cascade, so these are measured here.
  console.log("\nfield status (measured styles + the first-paint animation rule)");
  const fstatus = await page.evaluate(() => {
    const attached = document.querySelector("#fieldstatus .astryx-field-status--attached");
    const detached = document.querySelector("#fieldstatus .astryx-field-status--detached");
    // The flex row is the inner __content span, not the outer container.
    const detachedContent = detached ? detached.querySelector(".astryx-field-status__content") : null;
    const cs = (el) => (el ? getComputedStyle(el) : null);
    const a = cs(attached);
    const d = cs(detached);
    const dc = cs(detachedContent);
    return {
      attachedPointerEvents: a ? a.pointerEvents : null,
      attachedMarginTop: a ? a.marginTop : null,
      attachedPadStart: a ? a.paddingTop : null,
      attachedBottomRadius: a ? a.borderBottomLeftRadius : null,
      attachedRole: attached ? attached.getAttribute("role") : null,
      detachedGap: dc ? dc.gap : null,
      detachedRadius: d ? d.borderRadius : null,
      detachedIcon: detached ? !!detached.querySelector(".astryx-field-status__icon svg") : false,
      animatedFirstPaint: [...document.querySelectorAll("#fieldstatus .astryx-field-status")]
        .filter((e) => [...e.classList].some((c) => c.startsWith("astryx-enter--"))).length,
    };
  });
  check("the attached overlay does not take pointer input",
    fstatus.attachedPointerEvents === "none", String(fstatus.attachedPointerEvents));
  check("the attached overlay really overlaps (negative top margin)",
    parseFloat(fstatus.attachedMarginTop) < 0, String(fstatus.attachedMarginTop));
  check("...and pads back the overlap so text is not clipped",
    parseFloat(fstatus.attachedPadStart) > Math.abs(parseFloat(fstatus.attachedMarginTop || "0")),
    `${fstatus.attachedPadStart} vs ${fstatus.attachedMarginTop}`);
  check("only the bottom corners are rounded", parseFloat(fstatus.attachedBottomRadius) > 0,
    String(fstatus.attachedBottomRadius));
  check("an attached error is announced assertively", fstatus.attachedRole === null || fstatus.attachedRole === "alert" || fstatus.attachedRole === "status");
  check("detached uses a flex row with a gap", fstatus.detachedGap !== "normal" && fstatus.detachedGap !== "0px", String(fstatus.detachedGap));
  check("detached shows its type's icon", fstatus.detachedIcon);
  check("nothing in the section animates on the first paint", fstatus.animatedFirstPaint === 0,
    `${fstatus.animatedFirstPaint}`);

  // The rule that makes the entry animation worth having: an element mounted AFTER the
  // first frame animates, one present at the first paint does not.
  const showedStatus = await page.evaluate(() => {
    const sec = document.getElementById("interactive");
    const btn = [...sec.querySelectorAll("button")].find((b) => /show status/i.test(b.textContent || ""));
    if (!btn) return false;
    btn.click();
    return true;
  });
  await page.waitForTimeout(250);
  const late = await page.evaluate(() => {
    const el = document.getElementById("late-status");
    if (!el) return null;
    return {
      classes: el.className,
      animated: [...el.classList].some((c) => c.startsWith("astryx-enter--")),
      role: el.getAttribute("role"),
      // Reduced-motion is forced in this gate, so the CSS must have neutralised the
      // animation name while the class is still present.
      animationName: getComputedStyle(el).animationName,
    };
  });
  check("the Show status button exists and was clicked", showedStatus);
  check("a status mounted after the first paint carries the animation class",
    !!late && late.animated, late ? late.classes : "no #late-status");
  check("..and it is announced assertively, being an error",
    !!late && late.role === "alert", late ? String(late.role) : "n/a");
  check("the animation is neutralised under prefers-reduced-motion",
    !!late && late.animationName === "none", late ? late.animationName : "n/a");

  console.log("\ncoverage panel (fetched from coverage.json at runtime)");
  await page.waitForTimeout(500);
  const cov = await page.evaluate(() => ({
    // Read the stat numbers themselves: textContent on the container concatenates
    // without separators ("13ported90not yet…"), which no word-boundary regex can
    // match reliably.
    stats: [...document.querySelectorAll("#coverage-summary .cov-stat b")].map((e) => e.textContent.trim()),
    unported: document.querySelectorAll("#unported-list li").length,
    upstream: (document.getElementById("meta-upstream") || {}).textContent || "",
    foot: (document.getElementById("build-line") || {}).textContent || "",
  }));
  check(
    "coverage stats are 24 ported / 79 not / 103 total",
    JSON.stringify(cov.stats) === JSON.stringify(["24", "79", "103"]),
    cov.stats.join(" | "),
  );
  check("unported list rendered 79 entries", cov.unported === 79, `got ${cov.unported}`);
  check("upstream commit shown", /astryx@[0-9a-f]{6,}/.test(cov.upstream), cov.upstream);
  check("coverage.json reported no inconsistency", !/WARNING/.test(cov.foot), cov.foot);
}

// ---------------------------------------------------------------- screenshot

const outDir = resolve(root, "docs/verification");
mkdirSync(outDir, { recursive: true });
const shot = resolve(outDir, mode === "showcase" ? "localhost-showcase.png" : "localhost-demo.png");
await page.screenshot({ path: shot, fullPage: true, animations: "disabled" });
console.log(`\nscreenshot: ${shot}`);

console.log(`\n${checks - failures}/${checks} checks passed, ${failures} failure(s)`);
console.log(failures === 0 ? "BROWSER CHECKS PASSED" : "BROWSER CHECKS FAILED");

await browser.close();
process.exit(failures === 0 ? 0 : 1);
