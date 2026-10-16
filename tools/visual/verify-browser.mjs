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

// playwright is a declared devDependency of this repo (package.json). Nothing here reaches
// outside it: a sibling checkout is not a dependency, and CI does not have one.
// default cache. Find a usable chromium binary rather than assuming a revision.
function playwright() {
  for (const p of [
    resolve(root, "node_modules/playwright"),
  ]) {
    if (existsSync(p)) return require(p);
  }
  throw new Error("playwright not found in node_modules — run `pnpm install`");
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
    "NavIcon", "EmptyState", "Citation", "Icon", "FieldStatus", "DropdownMenu", "Interactive",
    "Field + TextInput", "TextArea", "FieldLabel", "Indicator", "CheckboxInput", "Switch",
    "RadioList",
  ];

  // ---------------------------------------------------------------- RadioList (M13)
  console.log("\nRadioList (live)");
  const rlReadout = () =>
    page.evaluate(() => document.getElementById("showcase-radio-list-state")?.textContent ?? null);
  const rlChecked = (gid) =>
    page.evaluate((id) => {
      const r = [...document.getElementById(id).querySelectorAll("input[type=radio]")].find((x) => x.checked);
      return r ? r.value : null;
    }, gid);

  check("the live group starts on the value the application holds",
    (await rlReadout()) === "chosen: express", String(await rlReadout()));
  await page.click("#showcase-radio-list-live-item-0");
  await page.waitForTimeout(150);
  check("clicking a radio chooses it, and the readout follows",
    (await rlReadout()) === "chosen: standard", String(await rlReadout()));
  await page.click('label[for="showcase-radio-list-live-item-2"]');
  await page.waitForTimeout(150);
  check("clicking the label chooses its radio — the port's labels are real <label for>s",
    (await rlReadout()) === "chosen: pickup", String(await rlReadout()));

  // The headline claim of this component is not this file's doing: a native radio group is one tab
  // stop and the arrows move *and* select. Pressed, not assumed.
  await page.focus('input[id="showcase-radio-list-live-item-2"]');
  await page.keyboard.press("ArrowDown");
  await page.waitForTimeout(150);
  check("Down moves to the next radio *and* selects it, as a native group does",
    (await rlReadout()) === "chosen: standard", String(await rlReadout()));
  await page.keyboard.press("ArrowUp");
  await page.waitForTimeout(150);
  check("Up comes back, and selects on the way",
    (await rlReadout()) === "chosen: pickup", String(await rlReadout()));
  await page.keyboard.press("Tab");
  await page.waitForTimeout(90);
  check("Tab leaves the group in one press — three radios, one stop",
    await page.evaluate(() => !document.getElementById("showcase-radio-list-live").contains(document.activeElement)));

  await page.evaluate(() => document.getElementById("showcase-radio-disabled-item-item-1").click());
  await page.waitForTimeout(150);
  check("a disabled item cannot change the group — it holds its own selection",
    (await rlChecked("showcase-radio-disabled-item")) === "monthly",
    String(await rlChecked("showcase-radio-disabled-item")));
  check("the group's status message is rendered below it", await page.evaluate(() => {
    const msg = document.getElementById("showcase-radio-status-status");
    return !!msg && (msg.textContent || "").includes("Pick one");
  }));

  console.log("\nshowcase sections");
  check("33 sections", sections.length === 33, `got ${sections.length}: ${sections.map((s) => s.name).join(",")}`);
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
    FieldStatus: 4, DropdownMenu: 2, Interactive: 2, CheckboxInput: 10, Switch: 8,
    "Field + TextInput": 10, TextArea: 9, FieldLabel: 7, Indicator: 12,
    RadioList: 9,
  };
  const totalExamples = sections.reduce((a, s) => a + s.examples, 0);
  check("227 examples across the page", totalExamples === 227, `got ${totalExamples}`);
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
  check("33 nav links", nav.length === 33, `got ${nav.length}`);
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

  // DropdownMenu: the behaviour that exists only in a real browser. The highlight is
  // DOM focus, rows are found by querying the container, and the keyboard is what moves
  // between them — none of which the jsdom harness can express, because its synthetic
  // key event carries no `key`. So the keyboard, the typeahead, the disabled-row skip,
  // the selection and the focus return are all asserted here.
  console.log("\ndropdown menu (keyboard and focus)");
  const menuState = () =>
    page.evaluate(() => {
      const trigger = document.querySelector("#menu-file-trigger");
      const surface = document.querySelector(".astryx-dropdown__popover");
      const active = document.activeElement;
      const row = active && active.closest ? active.closest("[data-astryx-menu-item]") : null;
      return {
        exists: Boolean(trigger && surface),
        expanded: trigger && trigger.getAttribute("aria-expanded"),
        surfaceHidden: surface ? surface.hasAttribute("hidden") : null,
        rowCount: document.querySelectorAll("#menu-file-menu [data-astryx-menu-item]").length,
        focusedRow: row ? row.getAttribute("data-astryx-menu-item") : null,
        focusOnTrigger: active === trigger,
        selection: ((document.querySelector("#menu-selection") || {}).textContent || "").trim(),
      };
    });
  const focusTrigger = () =>
    page.evaluate(() => {
      const t = document.querySelector("#menu-file-trigger");
      if (!t) return false;
      t.focus();
      return document.activeElement === t;
    });
  const key = async (k) => {
    await page.keyboard.press(k);
    await page.waitForTimeout(90);
  };

  const dm0 = await menuState();
  check("the menu is closed on the first paint",
    dm0.exists && dm0.expanded === "false" && dm0.surfaceHidden === true, JSON.stringify(dm0));
  check("no rows exist while closed", dm0.rowCount === 0, `${dm0.rowCount}`);
  check("nothing is selected yet", dm0.selection === "selected: —", dm0.selection);
  check("the trigger takes focus", (await focusTrigger()) === true);

  await key("ArrowDown");
  const dm1 = await menuState();
  check("Down on the trigger opens the menu",
    dm1.expanded === "true" && dm1.surfaceHidden === false, JSON.stringify(dm1));
  check("opening focuses the first row", dm1.focusedRow === "new", String(dm1.focusedRow));

  await key("ArrowDown");
  check("Down moves to the next row", (await menuState()).focusedRow === "open", String((await menuState()).focusedRow));
  await key("End");
  check("End reaches the last row (an href row is focusable)",
    (await menuState()).focusedRow === "docs", String((await menuState()).focusedRow));
  await key("Home");
  check("Home returns to the first row", (await menuState()).focusedRow === "new", String((await menuState()).focusedRow));
  await key("ArrowUp");
  check("Up from the first row wraps to the last",
    (await menuState()).focusedRow === "docs", String((await menuState()).focusedRow));

  // Moving the pointer onto a row focuses it, which is upstream's menuItemHover — the
  // keyboard and the pointer drive one highlight rather than two.
  await page.hover('#menu-file-menu [data-astryx-menu-item="save"]');
  await page.waitForTimeout(90);
  check("hovering a row focuses it", (await menuState()).focusedRow === "save", String((await menuState()).focusedRow));

  // The disabled row cannot take focus, so it must be skipped rather than landed on.
  await key("ArrowDown");
  check("Down skips the disabled row",
    (await menuState()).focusedRow === "delete", String((await menuState()).focusedRow));

  // Typeahead: "d" matches Delete project, Date modified and Documentation; pressing the
  // same character again inside the reset window cycles through them. The disabled
  // "Duplicate" starts with the same letter and must not be a candidate.
  await key("d");
  const t1 = (await menuState()).focusedRow;
  await key("d");
  const t2 = (await menuState()).focusedRow;
  await key("d");
  const t3 = (await menuState()).focusedRow;
  // The search starts after the current row, so the first "d" from "delete" is
  // "sort-date"; wrapping past the end lands back on "delete", which is also what
  // proves the disabled "Duplicate" — the earlier "d" in document order — is not a
  // candidate.
  check(`typing "d" jumps to the next match after the current row (${t1})`, t1 === "sort-date", String(t1));
  check(`typing "d" again cycles to the next match (${t2})`, t2 === "docs", String(t2));
  check(`and wraps past the end, skipping the disabled row (${t3})`, t3 === "delete", String(t3));

  // Enter on the focused row: the consumer receives the selection — its own state, not
  // the menu's — the menu closes, and focus goes back to the trigger.
  await key("Enter");
  const picked = await menuState();
  check(`Enter chooses the focused row (${picked.selection})`, picked.selection === "selected: delete", picked.selection);
  check("choosing closes the menu", picked.expanded === "false" && picked.surfaceHidden === true, JSON.stringify(picked));
  check("choosing hands focus back to the trigger", picked.focusOnTrigger === true);

  // Escape is the documented way out, and it must also return focus.
  await focusTrigger();
  await key("ArrowDown");
  check("the menu reopens on Down", (await menuState()).expanded === "true");
  await key("Escape");
  const escaped = await menuState();
  check("Escape closes the menu", escaped.expanded === "false" && escaped.surfaceHidden === true, JSON.stringify(escaped));
  check("Escape hands focus back to the trigger", escaped.focusOnTrigger === true);
  check("the selection survives the menu closing", escaped.selection === "selected: delete", escaped.selection);

  // A click anywhere else closes it too.
  await focusTrigger();
  await key("ArrowDown");
  await page.click(".sec-title");
  await page.waitForTimeout(120);
  const outside = await menuState();
  check("a click outside closes the menu",
    outside.expanded === "false" && outside.surfaceHidden === true, JSON.stringify(outside));

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

  // --- Field + TextInput: what only a real browser can decide ------------------
  // jsdom has no keyboard of its own and does not implement label activation, so the parts
  // below are exactly the parts the component gate cannot speak to.
  console.log("\ntext input (real keys, real focus, native label activation)");
  {
    const fieldState = () =>
      page.evaluate(() => {
        const el = document.querySelector("#showcase-field-name");
        if (!el) return null;
        const wrapper = el.closest(".astryx-text-input");
        const cs = getComputedStyle(wrapper);
        return {
          value: el.value,
          labels: el.labels ? el.labels.length : -1,
          labelText: el.labels && el.labels[0] ? el.labels[0].textContent.trim() : "",
          focused: document.activeElement === el,
          shadow: cs.boxShadow,
          border: cs.borderTopColor,
        };
      });

    const initial = await fieldState();
    check("the field is wired to its label in a real engine",
      initial && initial.labels === 1 && initial.labelText.includes("Full name"),
      JSON.stringify(initial && { labels: initial.labels, text: initial.labelText }));

    // Native activation: clicking the label is supposed to focus the control. jsdom does not
    // implement that, and a <div> pretending to be a label would silently pass every DOM test.
    await page.click('label[for="showcase-field-name"]');
    const afterLabelClick = await fieldState();
    check("clicking the label focuses the control", afterLabelClick && afterLabelClick.focused,
      JSON.stringify(afterLabelClick && { focused: afterLabelClick.focused }));

    await page.keyboard.type("Ada Lovelace");
    await page.waitForTimeout(120);
    const typed = await fieldState();
    const echo = (await page.textContent("[data-showcase-typed]")) || "";
    check("real keystrokes reach the control", typed && typed.value === "Ada Lovelace",
      typed && typed.value);
    check("real keystrokes reach the application", /name="Ada Lovelace"/.test(echo), echo);

    const focusRing = await fieldState();
    check("focusing the field changes how it is drawn",
      initial && focusRing && (initial.shadow !== focusRing.shadow || initial.border !== focusRing.border),
      JSON.stringify(initial && { before: initial.shadow, after: focusRing.shadow }));

    const startIcon = await page.evaluate(() => {
      const slot = document
        .querySelector("#showcase-field-email")
        ?.closest(".astryx-text-input")
        ?.querySelector(".astryx-text-input__start-icon svg");
      return slot ? { color: getComputedStyle(slot).color, size: Math.round(slot.getBoundingClientRect().width) } : null;
    });
    check("the start icon renders inside the control, in its slot",
      !!startIcon && startIcon.size > 0, JSON.stringify(startIcon));

    // The tooltip placement renders no box, so the message must still be readable to assistive
    // technology — clipped out of sight rather than absent.
    const tooltipPlacement = await page.evaluate(() => {
      const field = document.querySelector("#showcase-field-tooltip")?.closest(".astryx-field");
      if (!field) return null;
      const announced = field.querySelector("[data-astryx-field-status-announcement]");
      const rect = announced ? announced.getBoundingClientRect() : null;
      return {
        hasBox: Boolean(field.querySelector(".astryx-field-status")),
        text: announced ? announced.textContent.trim() : "",
        width: rect ? Math.round(rect.width) : null,
        height: rect ? Math.round(rect.height) : null,
      };
    });
    check("the tooltip placement renders no message box",
      tooltipPlacement && !tooltipPlacement.hasBox, JSON.stringify(tooltipPlacement));
    check("its message is still in the DOM, clipped rather than dropped",
      tooltipPlacement
        && tooltipPlacement.text.includes("read-only")
        && tooltipPlacement.width <= 2
        && tooltipPlacement.height <= 2,
      JSON.stringify(tooltipPlacement));

    // Enter: the one thing a synthetic key event cannot test, because the harness gives its
    // events an empty key.
    const submitted = () =>
      page.evaluate(() =>
        (document.querySelector("[data-showcase-submitted]") || {}).getAttribute
          ? document.querySelector("[data-showcase-submitted]").getAttribute("data-showcase-submitted")
          : null);
    check("nothing is submitted before Enter", (await submitted()) === "false", String(await submitted()));
    await page.click("#showcase-field-enter");
    await page.keyboard.type("hello");
    await page.keyboard.press("Enter");
    await page.waitForTimeout(120);
    check("a real Enter reaches the application", (await submitted()) === "true", String(await submitted()));
    check("the field that was submitted still holds what was typed",
      (await page.inputValue("#showcase-field-enter")) === "hello",
      await page.inputValue("#showcase-field-enter"));
  }

  console.log("\ntextarea (real typing, native label activation, the missing value attribute)");
  {
    const areaState = () =>
      page.evaluate(() => {
        const el = document.querySelector("#showcase-textarea-live");
        if (!el) return null;
        const cs = getComputedStyle(el);
        return {
          tag: el.tagName,
          value: el.value,
          hasValueAttr: el.hasAttribute("value"),
          labels: el.labels ? el.labels.length : -1,
          labelText: el.labels && el.labels[0] ? el.labels[0].textContent.trim() : "",
          focused: document.activeElement === el,
          resize: cs.resize,
          rows: el.rows,
        };
      });

    const initial = await areaState();
    check(
      "the control is a textarea, wired to its label in a real engine",
      initial &&
        initial.tag === "TEXTAREA" &&
        initial.labels === 1 &&
        initial.labelText.includes("Release notes"),
      JSON.stringify(initial && { tag: initial.tag, labels: initial.labels }),
    );
    check(
      "the value is carried as the element's text, with no value attribute",
      initial && initial.value === "Ready when you are." && initial.hasValueAttr === false,
      JSON.stringify(initial && { value: initial.value, hasValueAttr: initial.hasValueAttr }),
    );
    check(
      "rows comes from the prop, and the box is as tall as its rows",
      initial && initial.rows === 4,
      String(initial && initial.rows),
    );
    check(
      "the control resizes vertically only (upstream's resize: vertical)",
      initial && initial.resize === "vertical",
      String(initial && initial.resize),
    );

    await page.click('label[for="showcase-textarea-live"]');
    const afterLabelClick = await areaState();
    check("clicking the label focuses the textarea", afterLabelClick && afterLabelClick.focused);

    // Select-all first: where the caret lands after a label click is the engine's business, and an
    // assertion that depended on it would be testing Chromium's focus behaviour rather than the
    // port. With the value replaced, the expected string below is exact.
    await page.keyboard.press("Control+a");
    await page.keyboard.type("Shipped M12.");
    await page.waitForTimeout(120);
    const typed = await areaState();
    const echo = (await page.textContent("[data-showcase-textarea]")) || "";
    check("real keystrokes replace the initial value, in the control",
      typed && typed.value === "Shipped M12.", typed && typed.value);
    check("real keystrokes reach the application", /textarea="Shipped M12\."/.test(echo), echo);

    // The failure a copied port has: a re-render that puts the element's earlier text back over
    // what the user typed. Typing again after the state has changed is what catches it.
    const beforeMore = await areaState();
    await page.keyboard.type(" Again.");
    await page.waitForTimeout(120);
    const afterMore = await areaState();
    check(
      "a re-render does not put the old text back over what was typed",
      afterMore && beforeMore && afterMore.value === "Shipped M12. Again.",
      JSON.stringify(afterMore && afterMore.value),
    );
    check(
      "the value the user replaced does not come back",
      afterMore && !afterMore.value.includes("Ready when you are."),
      JSON.stringify(afterMore && afterMore.value),
    );

    // Enter is a character here, not a submit - the difference from TextInput that a shared
    // control would quietly lose.
    await page.keyboard.press("Enter");
    await page.keyboard.type("second line");
    await page.waitForTimeout(120);
    const multiline = await areaState();
    check(
      "Enter inserts a newline instead of submitting",
      multiline && multiline.value.includes("\nsecond line"),
      JSON.stringify(multiline && multiline.value),
    );
  }

  console.log("\nfield label (element.labels: a group label names nothing)");
  {
    const state = await page.evaluate(() => {
      const named = document.querySelector("#showcase-fl-named");
      const groupLabel = document.getElementById("showcase-fl-group-label");
      const choice = document.querySelector("#showcase-fl-group-a");
      const group = document.querySelector('[role="group"][aria-labelledby="showcase-fl-group-label"]');
      return {
        namedLabels: named && named.labels ? named.labels.length : -1,
        namedText: named && named.labels && named.labels[0] ? named.labels[0].textContent.trim() : "",
        groupTag: groupLabel ? groupLabel.tagName : null,
        groupHasFor: groupLabel ? groupLabel.hasAttribute("for") : null,
        groupLabelledBy: group ? group.getAttribute("aria-labelledby") : null,
        choiceLabels: choice && choice.labels ? choice.labels.length : -1,
      };
    });
    check(
      "a label names its control in a real engine",
      state && state.namedLabels === 1 && state.namedText.includes("Workspace name"),
      JSON.stringify(state && { labels: state.namedLabels, text: state.namedText }),
    );
    check(
      "a group label is a <span> with no for",
      state && state.groupTag === "SPAN" && state.groupHasFor === false,
      JSON.stringify(state && { tag: state.groupTag, hasFor: state.groupHasFor }),
    );
    check(
      "the group takes the group label as its name, and its controls do not",
      state &&
        state.groupLabelledBy === "showcase-fl-group-label" &&
        state.choiceLabels === 0,
      JSON.stringify(state && { labelledby: state.groupLabelledBy, choiceLabels: state.choiceLabels }),
    );
  }

  console.log("\nindicator marks (real engine)");
  {
    // Inside <svg> an HTML element is a no-op: it compiles, renders, and paints nothing, with no
    // error anywhere. A namespace check would catch the mistake; measuring what the engine
    // actually painted catches it *and* catches a mark that exists but is invisible.
    const paths = await page.evaluate(() =>
      [...document.querySelectorAll(".astryx-indicator__check path")].map((p) => ({
        ns: p.namespaceURI,
        w: Math.round(p.getBBox().width * 100) / 100,
        h: Math.round(p.getBBox().height * 100) / 100,
      })),
    );
    check(
      "every check mark is a real SVG path in the SVG namespace",
      paths.length > 0 && paths.every((p) => p.ns === "http://www.w3.org/2000/svg"),
      `got ${JSON.stringify(paths.slice(0, 2))}`,
    );
    check(
      "and every one of them actually paints",
      paths.length > 0 && paths.every((p) => p.w > 0 && p.h > 0),
      `boxes: ${JSON.stringify(paths.slice(0, 3))}`,
    );

    const bar = await page.evaluate(() => {
      const d = document.querySelector(
        ".astryx-indicator--indeterminate .astryx-indicator__dash",
      );
      if (!d) return null;
      const r = d.getBoundingClientRect();
      return {w: Math.round(r.width), h: Math.round(r.height)};
    });
    check("the indeterminate bar paints, and is a bar", !!bar && bar.w > bar.h && bar.h > 0,
      JSON.stringify(bar));

    const dot = await page.evaluate(() => {
      const d = document.querySelector(
        ".astryx-indicator--radio.astryx-indicator--checked .astryx-indicator__dot",
      );
      if (!d) return null;
      const r = d.getBoundingClientRect();
      return {w: Math.round(r.width), h: Math.round(r.height)};
    });
    check("the radio dot is round and paints", !!dot && dot.w > 0 && dot.w === dot.h,
      JSON.stringify(dot));

    // The two absences, in a real engine: a bare check mark renders nothing when it is not on.
    const absences = await page.evaluate(() => {
      const on = document.querySelectorAll(
        '[data-astryx-kind="check"][data-astryx-state="checked"]',
      ).length;
      const off = document.querySelectorAll(
        '[data-astryx-kind="check"][data-astryx-state="unchecked"]',
      ).length;
      return {on, off};
    });
    check("an unchecked bare check mark renders nothing at all — not even an empty box",
      absences.off === 0, JSON.stringify(absences));
    check("while its checked and disabled-checked siblings are on the page",
      absences.on === 2, JSON.stringify(absences));
  }

  console.log("\ncheckbox (real engine)");
  {
    const state = (id) =>
      page.evaluate((id) => {
        const el = document.getElementById(id);
        return {checked: el.checked, indeterminate: el.indeterminate, disabled: el.disabled};
      }, id);

    // The round trip: a real click changes the application's value, and the DOM's *property* has to
    // follow it back. jsdom cannot test this — it has no click-to-toggle for a checkbox.
    check("the live box starts unchecked", (await state("showcase-checkbox-live")).checked === false);
    await page.click("#showcase-checkbox-live");
    await page.waitForTimeout(200);
    const afterClick = await state("showcase-checkbox-live");
    const readout = ((await page.textContent("#showcase-checkbox-live-state")) || "").trim();
    check("a real click checks it, and the property follows the value",
      afterClick.checked === true, JSON.stringify(afterClick));
    check("and the readout agrees", readout === "this box: checked", readout);
    await page.click("#showcase-checkbox-live");
    await page.waitForTimeout(200);
    check("clicking it again unchecks it", (await state("showcase-checkbox-live")).checked === false);

    // Space on a focused checkbox *is* a click in every browser. The port relies on that instead of
    // a keydown handler, so this is what decides whether a keyboard user can use it at all.
    await page.evaluate(() => document.getElementById("showcase-checkbox-live").focus());
    await page.keyboard.press("Space");
    await page.waitForTimeout(200);
    check("Space toggles it, because Space on a checkbox is a click",
      (await state("showcase-checkbox-live")).checked === true);

    // Clicking the *label* is the other half of a real <label for>: the browser forwards it.
    await page.click('label[for="showcase-checkbox-live"]');
    await page.waitForTimeout(200);
    check("clicking the label toggles the box too",
      (await state("showcase-checkbox-live")).checked === false);

    // The group. A parent whose children disagree is the only producer of the third state.
    const parentBefore = await state("showcase-checkbox-parent");
    check("the parent starts indeterminate, with two of three children on",
      parentBefore.indeterminate === true && parentBefore.checked === false,
      JSON.stringify(parentBefore));
    await page.click("#showcase-checkbox-child-2");
    await page.waitForTimeout(200);
    const parentAll = await state("showcase-checkbox-parent");
    check("turning the last child on checks the parent and clears the mixed state",
      parentAll.checked === true && parentAll.indeterminate === false, JSON.stringify(parentAll));
    await page.click("#showcase-checkbox-child-2");
    await page.waitForTimeout(200);
    const parentMixed = await state("showcase-checkbox-parent");
    const parentReadout = ((await page.textContent("#showcase-checkbox-parent-state")) || "").trim();
    check("turning it back off makes the parent indeterminate again",
      parentMixed.indeterminate === true && parentMixed.checked === false,
      JSON.stringify(parentMixed));
    check("and the readout is derived from the children, so it cannot drift",
      parentReadout === "the parent: indeterminate", parentReadout);
    check("a mixed box still carries no aria-checked, in a real engine",
      (await page.evaluate(() =>
        document.getElementById("showcase-checkbox-parent").getAttribute("aria-checked"),
      )) === null);

    // Clicking the parent sets all three, which is what the browser does with a half-selected one.
    await page.click("#showcase-checkbox-parent");
    await page.waitForTimeout(200);
    const kids = await page.evaluate(() =>
      ["showcase-checkbox-child-1", "showcase-checkbox-child-2", "showcase-checkbox-child-3"].map(
        (id) => document.getElementById(id).checked,
      ),
    );
    check("clicking the parent checks every child", kids.every((k) => k === true), JSON.stringify(kids));
    check("and the parent's own box is checked rather than mixed",
      (await state("showcase-checkbox-parent")).indeterminate === false);

    // Read-only takes focus and refuses the click; disabled cannot be reached at all.
    await page.click("#showcase-checkbox-readonly");
    await page.waitForTimeout(150);
    check("a read-only box refuses the click",
      (await state("showcase-checkbox-readonly")).checked === false);
    const disabled = await page.evaluate(() => {
      const el = document.getElementById("showcase-checkbox-disabled");
      el.click();
      return {disabled: el.disabled, checked: el.checked};
    });
    check("a disabled box is disabled and does not move",
      disabled.disabled === true && disabled.checked === true, JSON.stringify(disabled));
  }

  console.log("\nswitch (real engine)");
  {
    const isOn = (id) => page.evaluate((id) => document.getElementById(id).checked, id);
    const trackState = (id) =>
      page.evaluate((id) => {
        const root = document.getElementById(id).closest(".astryx-switch");
        return {
          on: !!root.querySelector(".astryx-switch__track--on"),
          thumbOn: !!root.querySelector(".astryx-switch__thumb--on"),
        };
      }, id);

    check("the live switch starts off", (await isOn("showcase-switch-live")) === false);
    await page.click("#showcase-switch-live");
    await page.waitForTimeout(200);
    const onState = await trackState("showcase-switch-live");
    check("a real click turns it on", (await isOn("showcase-switch-live")) === true);
    check("and the track and thumb repaint to match",
      onState.on === true && onState.thumbOn === true, JSON.stringify(onState));
    const readout = ((await page.textContent("#showcase-switch-live-state")) || "").trim();
    check("and the derived readout agrees", readout === "this switch: on", readout);
    await page.click("#showcase-switch-live");
    await page.waitForTimeout(200);
    check("clicking again turns it off", (await isOn("showcase-switch-live")) === false);

    await page.evaluate(() => document.getElementById("showcase-switch-live").focus());
    await page.keyboard.press("Space");
    await page.waitForTimeout(200);
    check("Space toggles it, because the input is a native checkbox",
      (await isOn("showcase-switch-live")) === true);

    await page.click('label[for="showcase-switch-live"]');
    await page.waitForTimeout(200);
    check("clicking the label toggles it too",
      (await isOn("showcase-switch-live")) === false);

    // role="switch" is exposed, and the second declaration is deliberately absent.
    const semantics = await page.evaluate(() => {
      const el = document.getElementById("showcase-switch-on");
      return {role: el.getAttribute("role"), ariaChecked: el.getAttribute("aria-checked")};
    });
    check("the control announces itself as a switch", semantics.role === "switch", JSON.stringify(semantics));
    check("with no aria-checked shadowing its own checkedness", semantics.ariaChecked === null);

    const frozen = await page.evaluate(() => {
      const el = document.getElementById("showcase-switch-disabled-off");
      el.click();
      return {disabled: el.disabled, checked: el.checked};
    });
    check("a disabled switch does not move", frozen.disabled === true && frozen.checked === false,
      JSON.stringify(frozen));
  }

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
    "coverage stats are 32 ported / 71 not / 103 total",
    JSON.stringify(cov.stats) === JSON.stringify(["32", "71", "103"]),
    cov.stats.join(" | "),
  );
  check("unported list rendered 71 entries", cov.unported === 71, `got ${cov.unported}`);
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
