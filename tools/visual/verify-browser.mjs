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
const page = await browser.newPage({ viewport: { width: 1440, height: 1000 } });

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
    "HStack", "VStack", "AspectRatio", "Interactive",
  ];

  console.log("\nshowcase sections");
  check("17 sections", sections.length === 17, `got ${sections.length}: ${sections.map((s) => s.name).join(",")}`);
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
    Interactive: 1,
  };
  const totalExamples = sections.reduce((a, s) => a + s.examples, 0);
  check("125 examples across the page", totalExamples === 125, `got ${totalExamples}`);
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
  check("17 nav links", nav.length === 17, `got ${nav.length}`);
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
    "coverage stats are 16 ported / 87 not / 103 total",
    JSON.stringify(cov.stats) === JSON.stringify(["16", "87", "103"]),
    cov.stats.join(" | "),
  );
  check("unported list rendered 87 entries", cov.unported === 87, `got ${cov.unported}`);
  check("upstream commit shown", /astryx@[0-9a-f]{6,}/.test(cov.upstream), cov.upstream);
  check("coverage.json reported no inconsistency", !/WARNING/.test(cov.foot), cov.foot);
}

// ---------------------------------------------------------------- screenshot

const outDir = resolve(root, "docs/verification");
mkdirSync(outDir, { recursive: true });
const shot = resolve(outDir, mode === "showcase" ? "localhost-showcase.png" : "localhost-demo.png");
await page.screenshot({ path: shot, fullPage: true });
console.log(`\nscreenshot: ${shot}`);

console.log(`\n${checks - failures}/${checks} checks passed, ${failures} failure(s)`);
console.log(failures === 0 ? "BROWSER CHECKS PASSED" : "BROWSER CHECKS FAILED");

await browser.close();
process.exit(failures === 0 ? 0 : 1);
