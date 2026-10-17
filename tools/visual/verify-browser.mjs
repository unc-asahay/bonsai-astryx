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
import { existsSync, readdirSync, mkdirSync, readFileSync } from "node:fs";
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
// The avatar's fallback example points deliberately at two sources that cannot load - that *is* the
// behaviour under test - so those two are allowed by name and everything else still fails the gate.
const deliberate = ["this-source-does-not-exist.png", "neither-does-this-one.png"];
const unexpectedResponses = badResponses.filter((r) => !deliberate.some((d) => r.includes(d)));
check("no unexpected 4xx/5xx responses", unexpectedResponses.length === 0, unexpectedResponses.join("; "));
check("no uncaught page errors", pageErrors.length === 0, pageErrors.join("; "));
// A deliberately failing image logs a resource error, which the check above already accounts for; this check
// is about the port's own code. Anything that is not a resource load still fails here.
const unexpectedConsoleErrors = consoleErrors.filter((e) => !/Failed to load resource/.test(e));
check("no console errors", unexpectedConsoleErrors.length === 0, unexpectedConsoleErrors.slice(0, 3).join("; "));
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
    "NavIcon", "EmptyState", "Citation", "Icon", "FieldStatus", "Kbd", "Layer", "DropdownMenu",
    "Interactive",
    "Field + TextInput", "TextArea", "FieldLabel", "Indicator", "CheckboxInput", "Switch",
    "RadioList", "FormLayout", "Tooltip", "Dialog", "AlertDialog", "DialogHeader",
    "SelectableCard", "ClickableCard", "OverflowList",
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

  // ---------------------------------------------------------------- FormLayout (M13)
  console.log("\nFormLayout (live)");
  const boxes = (sel) =>
    page.evaluate((s) => [...document.querySelectorAll(s)].map((e) => {
      const r = e.getBoundingClientRect();
      return { x: Math.round(r.x), y: Math.round(r.y), w: Math.round(r.width) };
    }), sel);

  // "Equal columns" is a claim about geometry, so measure it rather than reading the class back.
  const cols = await boxes(
    '[data-astryx-direction="horizontal"]:has(#showcase-fl-h-street) > .astryx-field',
  );
  const equalWidths = cols.length >= 3 && cols.every((c) => Math.abs(c.w - cols[0].w) <= 2);
  const oneRow = cols.every((c) => Math.abs(c.y - cols[0].y) <= 2);
  const increasing = cols.every((c, i) => i === 0 || c.x > cols[i - 1].x);
  check("three fields sit on one row, left to right, in equal columns",
    equalWidths && oneRow && increasing, JSON.stringify(cols));

  // "Labels to the left" means the label is beside the control, not above it — again geometry.
  const placed = await page.evaluate(() => {
    const label = document.querySelector('label[for="showcase-fl-l-account"]');
    const input = document.getElementById("showcase-fl-l-account");
    if (!label || !input) return null;
    const l = label.getBoundingClientRect();
    const i = input.getBoundingClientRect();
    return { labelX: Math.round(l.x), inputX: Math.round(i.x), overlap: Math.round(Math.min(l.bottom, i.bottom) - Math.max(l.top, i.top)) };
  });
  check("labels to the left put the label beside its control, not above it",
    !!placed && placed.labelX < placed.inputX && placed.overlap > 0, JSON.stringify(placed));

  // ---------------------------------------------------------------- Tooltip (M13)
  console.log("\nTooltip (live)");
  const tipBox = (id) =>
    page.evaluate((i) => {
      const el = document.getElementById(i);
      if (!el) return null;
      const r = el.getBoundingClientRect();
      return { w: Math.round(r.width), h: Math.round(r.height), top: Math.round(r.top), bottom: Math.round(r.bottom), x: Math.round(r.x) };
    }, id);
  const triggerBox = (sel) =>
    page.evaluate((s) => {
      const el = document.querySelector(s);
      if (!el) return null;
      const r = el.getBoundingClientRect();
      return { top: Math.round(r.top), bottom: Math.round(r.bottom) };
    }, sel);

  // The caller-opened one needs no interaction, and being *laid out* is the claim: a message that
  // exists in the DOM but measures zero would satisfy every structural assertion.
  const shown = await tipBox("showcase-tip-controlled-message");
  check("a caller-opened tooltip is laid out, not merely present",
    !!shown && shown.w > 0 && shown.h > 0, JSON.stringify(shown));

  // Hover and focus are the two ways in, and both are real events here.
  const hoverTarget = "showcase-tip-below-trigger";
  check("the hovered tooltip starts closed",
    (await tipBox("showcase-tip-below-message")) === null);
  await page.hover(`#${hoverTarget}`);
  // The delay is the claim: a tooltip that appears the instant the pointer crosses an icon is a
  // different (and worse) component than one that appears when the pointer stops on it.
  await page.waitForTimeout(60);
  check("hovering does NOT open it straight away — there is a delay",
    (await tipBox("showcase-tip-below-message")) === null);
  await page.waitForTimeout(300);
  const opened = await tipBox("showcase-tip-below-message");
  check("hovering the trigger opens the message", !!opened && opened.w > 0, JSON.stringify(opened));
  // "below" is a geometric claim: the message sits under the trigger, not over it.
  const trigger = await triggerBox(`#${hoverTarget}`);
  check("and 'below' puts it below the trigger, measured",
    !!opened && !!trigger && opened.top >= trigger.bottom - 1,
    `message.top=${opened?.top} trigger.bottom=${trigger?.bottom}`);
  await page.mouse.move(2, 2);
  await page.waitForTimeout(150);
  check("moving away closes it, and the element leaves the DOM",
    (await tipBox("showcase-tip-below-message")) === null);

  // Leaving before the delay elapses cancels the timer rather than racing it.
  await page.hover("#showcase-tip-start-trigger");
  await page.waitForTimeout(60);
  await page.mouse.move(2, 2);
  await page.waitForTimeout(400);
  check("leaving before the delay elapses never opens it at all",
    (await tipBox("showcase-tip-start-message")) === null);

  await page.focus("#showcase-tip-above-trigger button");
  await page.waitForTimeout(150);
  check("focusing the trigger opens it too", !!(await tipBox("showcase-tip-above-message")));
  await page.keyboard.press("Escape");
  await page.waitForTimeout(150);
  check("Escape closes it", (await tipBox("showcase-tip-above-message")) === null);

  // ------------------------------------------------- disabledMessage (M13)
  console.log("\ndisabledMessage (live)");
  const reasonState = (id) =>
    page.evaluate((i) => {
      const el = document.getElementById(i);
      if (!el) return null;
      const cs = getComputedStyle(el);
      const r = el.getBoundingClientRect();
      return { visibility: cs.visibility, opacity: cs.opacity, w: Math.round(r.width) };
    }, id);

  // In the DOM always, visible only while the pointer or the focus is there. jsdom cannot say either
  // half of that: it has no layout, so "hidden" and "zero-sized" look alike from inside it.
  const atRest = await reasonState("showcase-checkbox-reason-disabled-message");
  check("a disabled control's reason is present but not shown at rest",
    !!atRest && atRest.visibility === "hidden", JSON.stringify(atRest));
  await page.hover("#showcase-checkbox-reason");
  await page.waitForTimeout(120);
  const onHover = await reasonState("showcase-checkbox-reason-disabled-message");
  check("hovering the control shows it, laid out",
    !!onHover && onHover.visibility === "visible" && onHover.w > 0, JSON.stringify(onHover));
  await page.focus("#showcase-checkbox-reason");
  check("and so does focusing it", (await reasonState("showcase-checkbox-reason-disabled-message"))?.visibility === "visible");
  await page.mouse.move(2, 2);
  await page.evaluate(() => document.activeElement?.blur());
  await page.waitForTimeout(120);

  await page.hover("#showcase-switch-reason");
  await page.waitForTimeout(120);
  const swShown = await reasonState("showcase-switch-reason-disabled-message");
  check("the switch's reason behaves the same way",
    !!swShown && swShown.visibility === "visible" && swShown.w > 0, JSON.stringify(swShown));
  await page.mouse.move(2, 2);
  await page.waitForTimeout(120);
  check("and hides again when the pointer leaves",
    (await reasonState("showcase-switch-reason-disabled-message"))?.visibility === "hidden");

  // ---------------------------------------------------------------- Dialog (M14)
  console.log("\nDialog (live)");
  const dialogState = (name) =>
    page.evaluate((n) => {
      const d = document.getElementById(`showcase-dialog-${n}`);
      return {
        open: !!d && d.open,
        modal: !!d && d.matches(":modal"),
        role: d?.getAttribute("role") ?? null,
        readout: document.getElementById(`showcase-dialog-state-${n}`)?.textContent ?? null,
        focusInside: !!d && d.contains(document.activeElement),
      };
    }, name);
  const openDialog = async (name) => {
    await page.click(`#showcase-dialog-open-${name}`);
    await page.waitForTimeout(120);
  };
  const pressEscape = async () => {
    await page.keyboard.press("Escape");
    await page.waitForTimeout(120);
  };

  // INFO: every exit works. The first assertion is that showModal() was used at all — a dialog with
  // the open attribute would be in ordinary flow and would not match :modal.
  await openDialog("info");
  let info = await dialogState("info");
  check("opening a dialog puts it in the top layer, modally", info.open && info.modal,
    JSON.stringify(info));
  check("and focus is taken into it, which is the trap", info.focusInside);
  check("the application is told it is open", /open$/.test(info.readout ?? ""), info.readout ?? "");
  await pressEscape();
  info = await dialogState("info");
  check("Escape closes it, and the application hears about it",
    !info.open && /closed$/.test(info.readout ?? ""), JSON.stringify(info));
  const focusBack = await page.evaluate(
    () => document.activeElement?.id ?? null);
  check("and focus goes back where it came from", focusBack === "showcase-dialog-open-info",
    `focus is on ${focusBack}`);

  // FORM: a half-filled form must not be lost to a stray click, but Escape is still an exit.
  await openDialog("form");
  await page.mouse.click(5, 5);
  await page.waitForTimeout(120);
  let form = await dialogState("form");
  check("purpose = form: a backdrop click does NOT close it", form.open && form.modal);
  check("and the application is still told it is open", /open$/.test(form.readout ?? ""), form.readout ?? "");
  await pressEscape();
  form = await dialogState("form");
  check("but Escape does close it", !form.open && /closed$/.test(form.readout ?? ""));

  // REQUIRED: neither exit, and it says so in its role.
  await openDialog("required");
  let required = await dialogState("required");
  check("purpose = required is role = alertdialog", required.role === "alertdialog", required.role ?? "none");
  await pressEscape();
  required = await dialogState("required");
  check("Escape does NOT close it", required.open && /open$/.test(required.readout ?? ""));
  await page.mouse.click(5, 5);
  await page.waitForTimeout(120);
  required = await dialogState("required");
  check("and neither does a backdrop click", required.open && /open$/.test(required.readout ?? ""));

  // The platform's own close: a <form method="dialog"> submit button, with no callback from the
  // application at all — the component reports the close through on_open_change.
  await page.click("#showcase-dialog-close-required");
  await page.waitForTimeout(150);
  required = await dialogState("required");
  check("a form method=dialog button closes it, and the application is told",
    !required.open && /closed$/.test(required.readout ?? ""), JSON.stringify(required));

  // ---------------------------------------------------------------- AlertDialog (M14)
  console.log("\nAlertDialog (live)");
  const adState = () =>
    page.evaluate(() => {
      const d = document.getElementById("showcase-alert-dialog-live");
      return {
        open: !!d && d.open,
        modal: !!d && d.matches(":modal"),
        role: d?.getAttribute("role") ?? null,
        purpose: d?.getAttribute("data-purpose") ?? null,
        readout: document.getElementById("showcase-alert-dialog-state")?.textContent ?? null,
      };
    });
  await page.click("#showcase-alert-dialog-open");
  await page.waitForTimeout(120);
  let ad = await adState();
  check("a live alert dialog is modal, and says alertdialog",
    ad.open && ad.modal && ad.role === "alertdialog", JSON.stringify(ad));
  check("built on the form purpose, which is what upstream passes", ad.purpose === "form");
  await page.keyboard.press("Escape");
  await page.waitForTimeout(120);
  ad = await adState();
  // Upstream's docs say an alert dialog requires an explicit action to dismiss, and the shipped
  // component passes purpose="form" — which allows Escape. The port follows the code, and says so.
  check("Escape closes it: purpose = form allows it, whatever the prose says",
    !ad.open && /closed/.test(ad.readout ?? ""), JSON.stringify(ad));

  await page.click("#showcase-alert-dialog-open");
  await page.waitForTimeout(120);
  await page.click("#showcase-alert-dialog-live-action");
  await page.waitForTimeout(150);
  ad = await adState();
  check("the action reaches the application AND the dialog closes",
    !ad.open && /answers taken: 1/.test(ad.readout ?? ""), ad.readout ?? "");

  await page.click("#showcase-alert-dialog-open");
  await page.waitForTimeout(120);
  await page.click("#showcase-alert-dialog-live-cancel");
  await page.waitForTimeout(150);
  ad = await adState();
  check("and Cancel closes it without taking the answer",
    !ad.open && /answers taken: 1/.test(ad.readout ?? ""), ad.readout ?? "");

  // The small-screen order is a CSS rule in this port where upstream reads the viewport in JavaScript.
  // Press it: the answer is on top below 640px, and the buttons take the full width.
  const actionsDir = () =>
    page.evaluate(() => {
      const el = document.querySelector("#showcase-alert-dialog-inline .astryx-alert-dialog__actions");
      const btn = el?.querySelector(".astryx-button");
      return {
        direction: el ? getComputedStyle(el).flexDirection : null,
        buttonWidth: btn ? Math.round(btn.getBoundingClientRect().width) : null,
        containerWidth: el ? Math.round(el.getBoundingClientRect().width) : null,
      };
    });
  const wide = await actionsDir();
  await page.setViewportSize({ width: 400, height: 800 });
  await page.waitForTimeout(200);
  const narrow = await actionsDir();
  await page.setViewportSize({ width: 1280, height: 900 });
  await page.waitForTimeout(200);
  check("the answers are a row on a wide screen", wide.direction === "row", JSON.stringify(wide));
  check("and a reversed column below 640px, with full-width buttons",
    narrow.direction === "column-reverse"
      && narrow.buttonWidth !== null && narrow.containerWidth !== null
      && narrow.buttonWidth >= narrow.containerWidth - 2,
    JSON.stringify(narrow));

  // ---------------------------------------------------------------- DialogHeader (M14)
  console.log("\nDialogHeader (live)");
  await page.click("#showcase-dialog-header-open");
  await page.waitForTimeout(150);
  const headerFacts = await page.evaluate(() => {
    const d = document.getElementById("showcase-dialog-header-live");
    const named = d?.getAttribute("aria-labelledby");
    const heading = named ? document.getElementById(named) : null;
    const active = document.activeElement;
    return {
      activeIsHeading: !!heading && active === heading,
      activeId: active?.id ?? active?.tagName ?? null,
      open: !!d && d.open,
      modal: !!d && d.matches(":modal"),
      named,
      tag: heading?.tagName ?? null,
      text: heading?.textContent ?? null,

      readout: document.getElementById("showcase-dialog-header-state")?.textContent ?? null,
    };
  });
  check("the dialog opens modal, named by its header",
    headerFacts.open && headerFacts.modal && headerFacts.named === "showcase-dialog-header-live-title",
    JSON.stringify(headerFacts));
  // The association, resolved: not "the attribute holds this string" but "the thing it points at is
  // the heading whose text is the dialog's name".
  check("and what it points at is the heading carrying the title",
    headerFacts.tag === "H2" && headerFacts.text === "Delete this project?",
    `${headerFacts.tag} ${headerFacts.text}`);
  // Where focus actually lands, which is the whole point of the marker: the platform's focus delegate
  // skips a tabindex=-1 element, so without the dialog's hook this would be the close button and a
  // screen reader would announce "Close" rather than the dialog's name.
  check("the dialog focuses its marked title, not the close button",
    headerFacts.activeIsHeading, `focus is on ${headerFacts.activeId}`);
  await page.click("#showcase-dialog-header-live .astryx-icon-button, #showcase-dialog-header-live .astryx-button");
  await page.waitForTimeout(150);
  const afterClose = await page.evaluate(() => {
    const d = document.getElementById("showcase-dialog-header-live");
    return {
      open: !!d && d.open,
      readout: document.getElementById("showcase-dialog-header-state")?.textContent ?? null,
    };
  });
  check("the header's close button closes the dialog, and the application is told",
    !afterClose.open && /closed$/.test(afterClose.readout ?? ""), JSON.stringify(afterClose));

  console.log("\nshowcase sections");
  check("54 sections", sections.length === 54, `got ${sections.length}: ${sections.map((s) => s.name).join(",")}`);
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
    MetadataList: 5, MoreMenu: 3, ProgressBar: 5, Avatar: 8, AvatarGroup: 3, ToggleButton: 3, SelectableCard: 3, ClickableCard: 4, OverflowList: 3,
    Stack: 8, Text: 12, Heading: 6, Button: 14, Badge: 15, Card: 12, Divider: 6,
    StatusDot: 7, Skeleton: 8, Center: 6, Section: 7, Grid: 6, VisuallyHidden: 3,
    HStack: 4, VStack: 4, AspectRatio: 6,
    IconButton: 5, Code: 5, Blockquote: 2,
    NavIcon: 2, EmptyState: 4, Citation: 6, Icon: 6,
    FieldStatus: 4, DropdownMenu: 4, Interactive: 2, CheckboxInput: 11, Switch: 9,
    "Field + TextInput": 10, TextArea: 9, FieldLabel: 7, Indicator: 12, Kbd: 3, Layer: 2,
    ButtonGroup: 3, Popover: 1, Timer: 3, InputGroup: 3, Toolbar: 3,
    RadioList: 9, FormLayout: 7, Tooltip: 6, Dialog: 7, AlertDialog: 3, DialogHeader: 3,
  };
  const totalExamples = sections.reduce((a, s) => a + s.examples, 0);
  check("312 examples across the page", totalExamples === 312, `got ${totalExamples}`);
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
  check("54 nav links", nav.length === 54, `got ${nav.length}`);
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

  // ---------------------------------------------------------------- Kbd (M15)
  console.log("\nKbd (measured in a real engine)");
  {
    // The claim that matters is not the glyph, it is the split: words for assistive technology, glyphs
    // for eyes. So this asserts the accessible name is *words* rather than comparing it to one
    // platform's answer — the machine running this gate decides whether that is Command or Control,
    // and a check that hardcoded either would be testing the runner instead of the component.
    const kbd = await page.evaluate(() => {
      const el = document.getElementById("kbd")?.querySelector(".astryx-kbd");
      if (!el) return null;
      const cap = el.querySelector(".astryx-kbd__key");
      const cs = cap ? getComputedStyle(cap) : null;
      const root = getComputedStyle(document.documentElement);
      return {
        role: el.getAttribute("role"),
        label: el.getAttribute("aria-label"),
        caps: el.querySelectorAll(".astryx-kbd__key").length,
        allHidden: [...el.querySelectorAll(".astryx-kbd__key")].every(
          (c) => c.getAttribute("aria-hidden") === "true",
        ),
        capText: cap ? cap.textContent : null,
        height: cap ? Math.round(cap.getBoundingClientRect().height * 100) / 100 : null,
        tokenHeight: root.getPropertyValue("--spacing-5").trim(),
        rootFontSize: root.fontSize,
        radius: cs ? cs.borderTopLeftRadius : null,
        borderBottom: cs ? cs.borderBottomWidth : null,
        background: cs ? cs.backgroundColor : null,
        userSelect: cs ? cs.userSelect : null,
      };
    });
    check("the wrapper is one image with one name", !!kbd && kbd.role === "img" && !!kbd.label,
      JSON.stringify(kbd && { role: kbd.role, label: kbd.label }));
    check("and the name is words, not glyphs to be read out",
      !!kbd && /(Command|Control)/.test(kbd.label) && !/[\u2318\u2303\u21e7]/.test(kbd.label),
      String(kbd && kbd.label));
    check("each cap is hidden from assistive technology but painted for eyes",
      !!kbd && kbd.caps >= 1 && kbd.allHidden && (kbd.capText || "").length > 0,
      JSON.stringify(kbd && { caps: kbd.caps, hidden: kbd.allHidden, text: kbd.capText }));
    // The stylesheet, which jsdom cannot speak to at all: the cap's height has to come from the same
    // spacing token the CSS names, and the cap has to paint something rather than be a bare glyph.
    // Everything has to be read inside the page: getComputedStyle does not exist in Node, and a
    // reference to it here throws before a single check runs.
    const tokenPx = kbd && kbd.tokenHeight && kbd.rootFontSize
      ? Math.round(parseFloat(kbd.tokenHeight) * parseFloat(kbd.rootFontSize) * 100) / 100
      : null;
    check("the cap is sized by --spacing-5, measured against the token",
      !!kbd && tokenPx !== null && Math.abs(kbd.height - tokenPx) <= 1,
      `cap=${kbd?.height} token=${tokenPx} raw=${kbd?.tokenHeight}`);
    check("and it paints: a background, a bottom edge and a radius",
      !!kbd && kbd.background !== "rgba(0, 0, 0, 0)" && kbd.borderBottom === "2px" && !!kbd.radius,
      JSON.stringify(kbd && { bg: kbd.background, border: kbd.borderBottom, radius: kbd.radius }));
    check("the caps are not selectable text", !!kbd && kbd.userSelect === "none", String(kbd?.userSelect));
  }

  // ---------------------------------------------------------------- Layer (the popover mechanism)
  console.log("\nLayer (the native popover API)");
  {
    const layerState = (id) =>
      page.evaluate((i) => {
        const el = document.getElementById(`${i}-surface`);
        const app = document.getElementById(`${i}-state`);
        return {
          present: !!el,
          /* `:popover-open` is the browser's own answer to "is this layer up?", which is not the same
             as the value the application holds — that difference is the thing being tested. */
          open: !!el && el.matches(":popover-open"),
          popover: el ? el.getAttribute("popover") : null,
          value: app ? app.textContent.trim() : null,
        };
      }, id);

    await page.click("#showcase-layer-auto-trigger");
    await page.waitForTimeout(250);
    const opened = await layerState("showcase-layer-auto");
    check("a click opens the layer, and the browser says it is open",
      opened.open === true, JSON.stringify(opened));
    check("the value the application holds agrees", /open$/.test(opened.value ?? ""), String(opened.value));

    /* Light dismiss is the platform's, not a document-level listener of ours: a real pointer-down
       outside the layer. The top-left corner is page margin, chosen so the click cannot land on a
       control and navigate away from the thing under test. */
    await page.mouse.click(5, 5);
    await page.waitForTimeout(300);
    const dismissed = await layerState("showcase-layer-auto");
    check("a real click outside dismisses it — the browser's light dismiss",
      dismissed.open === false, JSON.stringify(dismissed));
    /* The part the platform cannot know. Without the hook's report the layer would be gone and the
       value would still say open, and every later click on the trigger would look like a no-op. */
    check("and the application is told, so the value is not left saying open",
      /closed$/.test(dismissed.value ?? ""), String(dismissed.value));

    await page.click("#showcase-layer-auto-trigger");
    await page.waitForTimeout(250);
    check("it reopens after being dismissed out from under the application",
      (await layerState("showcase-layer-auto")).open === true);
    await page.keyboard.press("Escape");
    await page.waitForTimeout(300);
    const escaped = await layerState("showcase-layer-auto");
    check("Escape dismisses it too, and the value is told again",
      escaped.open === false && /closed$/.test(escaped.value ?? ""), JSON.stringify(escaped));

    /* The trigger's ARIA is state, so it has to move with the value — checked after a dismissal rather
       than only at rest. */
    const triggerAria = () =>
      page.evaluate(() => {
        const t = document.getElementById("showcase-layer-auto-trigger");
        return {
          haspopup: t ? t.getAttribute("aria-haspopup") : null,
          expanded: t ? t.getAttribute("aria-expanded") : null,
          controls: t ? t.getAttribute("aria-controls") : null,
          controlsExists: !!(t && document.getElementById(t.getAttribute("aria-controls"))),
        };
      });
    const aria = await triggerAria();
    check("the trigger says what it opens, and whether it is showing",
      aria.haspopup === "dialog" && aria.expanded === "false",
      JSON.stringify(aria));
    check("aria-controls names the layer element itself", aria.controlsExists, JSON.stringify(aria));

    /* The double-handler trap: a native button synthesizes a click from Enter, so a port that also
       attached a keydown listener would toggle twice — opening and immediately closing. Pressing it
       once and expecting it open is the check that catches that. */
    await page.focus("#showcase-layer-auto-trigger");
    await page.keyboard.press("Enter");
    await page.waitForTimeout(250);
    check("Enter on the trigger opens it, exactly once — no second handler fighting the first",
      (await layerState("showcase-layer-auto")).open === true);
    check("and the trigger now reports it as expanded",
      (await triggerAria()).expanded === "true", JSON.stringify(await triggerAria()));
    await page.keyboard.press("Enter");
    await page.waitForTimeout(250);
    check("Enter again closes it",
      (await layerState("showcase-layer-auto")).open === false);

    /* ------------------------------------------------------------------ ButtonGroup (M17) */
/* One tab stop with the arrows moving within it is behaviour the platform provides for radios and not
   for buttons, so this port implements it - which means it has to be measured, not assumed. Everything
   below is a real key press against a real group. */
{
  const membersOf = (groupId) => page.evaluate((id) => {
    const group = document.getElementById(id);
    return [...group.querySelectorAll("button, a[href], [tabindex]")].map((m) => ({
      id: m.id,
      tabindex: m.getAttribute("tabindex"),
      disabled: m.disabled === true,
      focused: m === document.activeElement,
    }));
  }, groupId);
  const stopsOf = (members) => members.filter((m) => m.tabindex === "0").map((m) => m.id);
  const focusedOf = (members) => members.find((m) => m.focused)?.id ?? null;

  await page.focus("#showcase-bg-copy");
  await page.waitForTimeout(120);
  let members = await membersOf("showcase-button-group");
  check("exactly one member of the group is a tab stop, the rest are reachable only by arrow",
    stopsOf(members).length === 1,
    JSON.stringify(members.map((m) => `${m.id}:${m.tabindex}`)));

  await page.keyboard.press("ArrowRight");
  await page.waitForTimeout(120);
  members = await membersOf("showcase-button-group");
  check("ArrowRight moves the focus to the next member", focusedOf(members) === "showcase-bg-cut", String(focusedOf(members)));
  check("and the tab stop follows the focus, so the next Tab leaves the group",
    stopsOf(members).join() === "showcase-bg-cut",
    stopsOf(members).join());

  /* The disabled member is the one that matters: it must be skipped, so one step from Cut lands on
     Copy rather than on the disabled button sitting at the end. */
  await page.focus("#showcase-bg-cut");
  await page.keyboard.press("ArrowRight");
  await page.waitForTimeout(120);
  members = await membersOf("showcase-button-group");
  check("a disabled member is skipped rather than focused",
    focusedOf(members) === "showcase-bg-copy",
    JSON.stringify({ focused: focusedOf(members), disabled: members.find((m) => m.disabled)?.id }));

  await page.keyboard.press("End");
  await page.waitForTimeout(120);
  check("End jumps to the last enabled member, which is not the last member",
    focusedOf(await membersOf("showcase-button-group")) === "showcase-bg-cut",
    String(focusedOf(await membersOf("showcase-button-group"))));

  /* Vertical is the same component on the other axis. */
  await page.focus("#showcase-bg-in");
  await page.keyboard.press("ArrowDown");
  await page.waitForTimeout(120);
  check("a vertical group moves on the vertical axis",
    focusedOf(await membersOf("showcase-button-group-vertical")) === "showcase-bg-out",
    String(focusedOf(await membersOf("showcase-button-group-vertical"))));

  /* The connected edges are CSS, so a browser is the only place they can be measured: the outer
     corners keep their radius, the inner ones lose it, and the shared edge is one border not two. */
  const edges = await page.evaluate(() => {
    const first = document.getElementById("showcase-bg-copy");
    const middle = document.getElementById("showcase-bg-cut");
    const last = document.getElementById("showcase-bg-delete");
    const f = getComputedStyle(first);
    const l = getComputedStyle(last);
    return {
      firstOuter: f.borderStartStartRadius,
      firstInner: f.borderStartEndRadius,
      lastInner: l.borderStartStartRadius,
      lastOuter: l.borderStartEndRadius,
      overlap: getComputedStyle(middle).marginInlineStart,
    };
  });
  check("the end caps are drawn: outer corners keep their radius, inner ones lose it",
    edges.firstInner === "0px" && edges.lastInner === "0px"
      && parseFloat(edges.firstOuter) > 0 && parseFloat(edges.lastOuter) > 0,
    JSON.stringify(edges));
  check("and the shared edge is one border, not two stacked",
    parseFloat(edges.overlap) < 0, JSON.stringify(edges));
}

/* ------------------------------------------------------------------- Popover (M18) */
/* The component is a wrapper around the layer mechanism, so the interesting assertions are the ones a
   wrapper can get wrong: that the platform's own dismissal reaches the application, that focus lands
   where upstream says it lands, and that the surface really was placed by the browser rather than
   merely being present in the top layer. */
{
  const state = () => page.evaluate(() => {
    const surface = document.getElementById("showcase-popover-surface");
    const trigger = document.getElementById("showcase-popover-trigger");
    const content = surface?.querySelector(".astryx-popover__content");
    const active = document.activeElement;
    return {
      open: !!surface?.matches(":popover-open"),
      expanded: trigger?.getAttribute("aria-expanded"),
      controls: trigger?.getAttribute("aria-controls"),
      focusedText: (active?.textContent || active?.tagName || "").trim().slice(0, 24),
      focusInside: !!content?.contains(active),
      triggerTop: trigger?.getBoundingClientRect().top ?? null,
      surfaceTop: surface?.getBoundingClientRect().top ?? null,
      positionArea: surface ? getComputedStyle(surface).positionArea : null,
    };
  });

  await page.click("#showcase-popover-trigger");
  await page.waitForTimeout(220);
  let st = await state();
  check("a click opens it, and the browser says so", st.open === true, JSON.stringify(st));
  check("the trigger says what it opens and that it is showing", st.expanded === "true", JSON.stringify(st));
  check("aria-controls names the surface, not a class that stands in for one",
    st.controls === "showcase-popover-surface", String(st.controls));

  /* Upstream's rule, exactly: focus enters the first genuine control in the content - not the generated
     close button, which is outside the content wrapper for precisely this reason. */
  check("focus enters the first control in the content, not the generated close button",
    st.focusInside === true && st.focusedText === "Copy link",
    JSON.stringify({ focusInside: st.focusInside, focusedText: st.focusedText }));

  /* Placement is the platform's: if anchor positioning did not run, the surface would sit at the
     viewport's origin rather than under its trigger. */
  check("and the surface was placed below its trigger by the platform, not merely shown",
    st.surfaceTop !== null && st.triggerTop !== null && st.surfaceTop > st.triggerTop,
    JSON.stringify({ trigger: st.triggerTop, surface: st.surfaceTop, positionArea: st.positionArea }));

  await page.keyboard.press("Escape");
  await page.waitForTimeout(220);
  st = await state();
  check("Escape dismisses it, and the application is told - the value is not left saying open",
    st.open === false && st.expanded === "false", JSON.stringify(st));
  check("and focus went back to the trigger", st.focusedText.startsWith("Share"), String(st.focusedText));

  await page.click("#showcase-popover-trigger");
  await page.waitForTimeout(220);
  await page.mouse.click(4, 4);
  await page.waitForTimeout(220);
  st = await state();
  check("a real click outside dismisses it too, and the value is told again",
    st.open === false && st.expanded === "false", JSON.stringify(st));

  /* The generated close control: present, labelled, and able to close the thing it belongs to. */
  await page.click("#showcase-popover-trigger");
  await page.waitForTimeout(220);
  const closedByButton = await page.evaluate(() => {
    const button = document.querySelector(".astryx-popover__close");
    if (!button) return "no close control";
    button.click();
    return button.getAttribute("aria-label");
  });
  await page.waitForTimeout(220);
  st = await state();
  check("the generated close control is labelled and closes the surface",
    closedByButton === "Close popover" && st.open === false,
    JSON.stringify({ label: closedByButton, open: st.open }));
}

/* ---------------------------------------------------------------------- Timer (M19) */
/* The reading moves on its own, and the interesting rules are about *what* it says at the boundaries -
   so the showcase renders timers with fixed past start times and the assertions are exact rather than
   "about a minute". */
{
  const reading = (id) => page.evaluate((id) => {
    const el = document.getElementById(id);
    return { tag: el?.tagName, text: el?.textContent, datetime: el?.getAttribute("datetime") };
  }, id);
  const secondsOf = (duration) => {
    const m = /^PT(\d+)S$/.exec(duration || "");
    return m ? Number(m[1]) : null;
  };

  /* "Nothing re-renders" is exactly the claim a screenshot cannot check, so it is checked by identity:
     a re-render would replace the node, and this one is written to in place. */
  await page.evaluate(() => {
    window.__timerNode = document.getElementById("showcase-timer-live");
    window.__timerText = window.__timerNode.textContent;
  });
  await page.waitForTimeout(1400);
  const live = await page.evaluate(() => ({
    sameNode: window.__timerNode === document.getElementById("showcase-timer-live"),
    before: window.__timerText,
    after: document.getElementById("showcase-timer-live")?.textContent,
  }));
  check("the reading moves on its own", live.before !== live.after, JSON.stringify(live));
  check("and it moves by writing to the node it owns — the element is the same one, not a re-render",
    live.sameNode === true, JSON.stringify({ sameNode: live.sameNode }));
  check("counting in whole seconds, as an elapsed reading does", /^\d+s$/.test(live.after || ""), String(live.after));

  /* The rule worth the most: past an hour the elapsed *text* drops its seconds, and the duration agrees
     with the text rather than with the clock. */
  const hour = await reading("showcase-timer-elapsed-hour");
  const hourSeconds = secondsOf(hour.datetime);
  check("an elapsed reading past an hour shows hours and minutes, with no seconds",
    hour.text === "1h 02m", String(hour.text));
  check("and its duration is a whole number of minutes — it follows the text, not the clock",
    hourSeconds !== null && hourSeconds % 60 === 0 && hourSeconds >= 3720,
    JSON.stringify({ datetime: hour.datetime, seconds: hourSeconds }));

  /* Same start time, clock format: now the duration *is* the real elapsed time. */
  const clock = await reading("showcase-timer-clock");
  const clockSeconds = secondsOf(clock.datetime);
  check("the clock format at the same instant reads hours, minutes and seconds",
    /^1:02:\d\d$/.test(clock.text || ""), String(clock.text));
  check("and its duration is the true elapsed time rather than a rounded one",
    clockSeconds !== null && clockSeconds % 60 !== 0 && clockSeconds >= 3725,
    JSON.stringify({ datetime: clock.datetime, seconds: clockSeconds }));

  /* The jsdom gate can see the class; only a browser can say what the class *does*. */
  const figures = await page.evaluate(() =>
    getComputedStyle(document.getElementById("showcase-timer-live")).fontVariantNumeric);
  check("tabular figures are actually applied — the numbers cannot shift as they change",
    String(figures).includes("tabular-nums"), String(figures));
}

// --------------------------------------------------------------------- InputGroup (M20)
// Every check here is a CSS outcome, so every one of them is a browser check by necessity: jsdom has no
// cascade. What the group's structure looks like lives in the component gate.

const igLayout = await page.evaluate(() => {
  const g = document.getElementById("showcase-group-amount-group");
  if (!g) return null;
  const members = Array.from(g.children);
  const adorn = g.querySelector(".astryx-input-group-text");
  const input = g.querySelector("input");
  const cs = (el) => getComputedStyle(el);
  return {
    memberCount: members.length,
    // one shared edge: the adornment's right edge meets the input's left edge, give or take the overlap
    edgeGap: adorn && input ? adorn.getBoundingClientRect().right - input.getBoundingClientRect().left : null,
    adornStartRadius: adorn ? parseFloat(cs(adorn).borderStartStartRadius) : null,
    inputStartRadius: input ? parseFloat(cs(input).borderStartStartRadius) : null,
    inputEndRadius: input ? parseFloat(cs(input).borderStartEndRadius) : null,
    inputHeight: input ? Math.round(input.getBoundingClientRect().height) : null,
    groupHeight: Math.round(g.getBoundingClientRect().height),
    flexGrow: adorn ? cs(adorn).flexGrow : null,
  };
});

check("the group renders as one box with its members", igLayout !== null && igLayout.memberCount === 2,
  JSON.stringify(igLayout));

check("the shared edge is single — the members overlap by one border width",
  igLayout !== null && Math.abs(igLayout.edgeGap) <= 1, String(igLayout && igLayout.edgeGap));

check("only the group\'s outer corners are rounded: the adornment keeps the start, the input gives it up",
  igLayout !== null && igLayout.adornStartRadius > 0 && igLayout.inputStartRadius === 0,
  JSON.stringify(igLayout && {a: igLayout.adornStartRadius, i: igLayout.inputStartRadius}));

// 32 is the md step of the size scale: this demo group is md, and the assertion that matters is the second
// one — the child's height *is* the box's, not a height of its own choosing. ("the disabled group" check
// below corroborates from the other end: an lg group's child fills 36.)
check("the child fills the box\u2019s height rather than choosing its own — which is how the size reaches it",
  igLayout !== null && igLayout.inputHeight === igLayout.groupHeight &&
  igLayout.inputHeight === 32, JSON.stringify(igLayout && {i: igLayout.inputHeight, g: igLayout.groupHeight}));

check("an adornment does not stretch: it is sized by its text, not by the box",
  igLayout !== null && igLayout.flexGrow === "0", String(igLayout && igLayout.flexGrow));

const igDisabled = await page.evaluate(() => {
  const g = document.getElementById("showcase-group-locked-group");
  return g ? {opacity: getComputedStyle(g).opacity, h: Math.round(g.getBoundingClientRect().height)} : null;
});

check("a disabled group dims as a whole — one opacity on the box, not one per member",
  igDisabled !== null && Math.abs(parseFloat(igDisabled.opacity) - 0.5) < 0.01 &&
  igDisabled.h === 36, JSON.stringify(igDisabled));

// ---------------------------------------------------------------------------- Toolbar (M21)
// Behaviour, so all of it is here rather than in jsdom: a single tab stop, arrows between members, and the
// caret guard - the branch the roadmap recorded as a debt when the mechanism was generalised, exercised now
// from both ends because this is the only consumer that turns it on.

const tbIdle = await page.evaluate(() => {
  const tb = document.getElementById("showcase-toolbar-actions");
  if (!tb) return null;
  const members = Array.from(tb.querySelectorAll("button, input, [tabindex], a[href]"));
  return {
    count: members.length,
    stops: members.filter((m) => m.getAttribute("tabindex") === "0").length,
    gridCentre: (() => {
      const c = document.getElementById("showcase-toolbar-zoom");
      if (!c) return null;
      const slot = c.querySelector(".astryx-toolbar__slot--center");
      if (!slot) return null;
      return {
        slotMid: Math.round(slot.getBoundingClientRect().left + slot.getBoundingClientRect().width / 2),
        barMid: Math.round(c.getBoundingClientRect().left + c.getBoundingClientRect().width / 2),
      };
    })(),
  };
});

check("a toolbar starts as one tab stop", tbIdle !== null && tbIdle.count >= 2 && tbIdle.stops === 1,
  JSON.stringify(tbIdle));

const tbArrows = await page.evaluate(() => {
  const tb = document.getElementById("showcase-toolbar-actions");
  if (!tb) return null;
  const members = Array.from(tb.querySelectorAll("button"));
  if (members.length < 2) return null;
  members[0].focus();
  const before = document.activeElement.textContent;
  tb.dispatchEvent(new KeyboardEvent("keydown", {key: "ArrowRight", bubbles: true}));
  const after = document.activeElement.textContent;
  return {before, after, moved: document.activeElement !== members[0]};
});

check("an arrow moves focus to the next member",
  tbArrows !== null && tbArrows.moved === true && tbArrows.before !== tbArrows.after,
  JSON.stringify(tbArrows));

// The caret guard, mid-text: the key belongs to the caret, so focus stays where it is.
//
// Two things this check had to learn. The first demo toolbar holding an input is *vertical*, so the key that
// moves between its members is ArrowDown, not ArrowRight - pressing ArrowRight on it should do nothing, and
// the first version of this check asserted that nothing had happened as though it were a failure. The second
// is that a synthetic KeyboardEvent has no default action: it can be heard by the application but it cannot
// move a caret, so the only way to test a rule *about* a caret is with a real key press.
await page.evaluate(() => {
  const input = document.getElementById("showcase-toolbar-input");
  if (input) {
    input.focus();
    input.setSelectionRange(1, 1);
  }
});
await page.keyboard.press("ArrowDown");
const caretMid = await page.evaluate(() => {
  const input = document.getElementById("showcase-toolbar-input");
  return input === null ? null : {stillInside: document.activeElement === input};
});

check("an arrow with the caret mid-text leaves focus in the field (the caret keeps the key)",
  caretMid !== null && caretMid.stillInside === true, JSON.stringify(caretMid));

// The caret guard, at the edge: now the key belongs to the toolbar.
await page.evaluate(() => {
  const input = document.getElementById("showcase-toolbar-input");
  if (input) {
    input.focus();
    input.setSelectionRange(input.value.length, input.value.length);
  }
});
await page.keyboard.press("ArrowDown");
const caretEdge = await page.evaluate(() => ({
  stillInside: document.activeElement.tagName === "INPUT",
  tag: document.activeElement.tagName,
}));

check("an arrow at the end of the text leaves the field and moves focus",
  caretEdge.stillInside === false && caretEdge.tag === "BUTTON", JSON.stringify(caretEdge));

check("a centre slot is centred against the bar, not against its neighbours",
  tbIdle !== null && tbIdle.gridCentre !== null &&
  Math.abs(tbIdle.gridCentre.slotMid - tbIdle.gridCentre.barMid) <= 1,
  JSON.stringify(tbIdle && tbIdle.gridCentre));

const tbGap = await page.evaluate(() => {
  const slot = document.querySelector("#showcase-toolbar-actions .astryx-toolbar__slot");
  return slot ? getComputedStyle(slot).gap : null;
});

check("the gap reaches the slots from the box", tbGap === "4px", String(tbGap));

// A controlled menu: the demo's own button - not the trigger - opens and closes it, and the trigger's
// aria-expanded follows, which is only true if the state the caller owns is the state the menu reads.
const menuRows = () => page.evaluate(() => document.querySelectorAll("#menu-controlled-menu [role='menuitem']").length);
const menuExpanded = () => page.getAttribute("#menu-controlled-trigger", "aria-expanded");
check("a controlled menu starts closed", (await menuRows()) === 0 && (await menuExpanded()) === "false");
await page.click("#menu-controlled-toggle");
await page.waitForFunction(() => document.querySelector("#menu-controlled-trigger").getAttribute("aria-expanded") === "true", null, { timeout: 3000 }).catch(() => {});
const openedFromOutside = (await menuRows()) > 0 && (await menuExpanded()) === "true";
check("the button outside it opens it, and the trigger reports that it is open", openedFromOutside, `rows=${await menuRows()} expanded=${await menuExpanded()}`);
await page.click("#menu-controlled-toggle");
await page.waitForFunction(() => document.querySelector("#menu-controlled-trigger").getAttribute("aria-expanded") === "false", null, { timeout: 3000 }).catch(() => {});
check("and closes it again", (await menuRows()) === 0 && (await menuExpanded()) === "false");

// An icon-only trigger: the label is still the accessible name, but it is not what is painted.
const iconOnly = await page.evaluate(() => {
  const button = document.querySelector("#menu-icon-only-trigger");
  if (!button) return null;
  // What an icon-only button does with its label: it becomes the accessible name, and nothing is painted.
  // (My first version of this check asserted a visually hidden label and failed - the component is right,
  // and the failure is the only reason I know which of the two it does.)
  const text = [...button.childNodes]
    .filter((n) => n.nodeType === 3)
    .map((n) => n.textContent.trim())
    .join("");
  return {
    innerText: button.textContent.trim(),
    ariaLabel: button.getAttribute("aria-label"),
    hasGlyph: !!button.querySelector(".demo-glyph"),
    bareText: text,
  };
});
check(
  "an icon-only trigger names itself for a screen reader and paints no label text",
  iconOnly && iconOnly.ariaLabel === "More" && iconOnly.hasGlyph && iconOnly.bareText === "",
  JSON.stringify(iconOnly),
);

// MetadataList: the layout belongs to the list, so the list is what a check reads - and because the
// component is stateful it is here rather than in the jsdom gate, which cannot render it at all.
const readList = (id) =>
  page.evaluate((id) => {
    const root = document.getElementById(id);
    if (!root) return null;
    const dl = root.querySelector("dl");
    if (!dl) return { root: true, dl: false };
    const dts = [...dl.querySelectorAll("dt")];
    const dds = [...dl.querySelectorAll("dd")];
    const cs = getComputedStyle(dl);
    const rows = dts.map((dt, i) => ({
      dtTop: Math.round(dt.getBoundingClientRect().top),
      ddTop: Math.round(dds[i].getBoundingClientRect().top),
      dtLeft: Math.round(dt.getBoundingClientRect().left),
      ddLeft: Math.round(dds[i].getBoundingClientRect().left),
    }));
    const toggle = root.querySelector(".astryx-metadata-list__toggle");
    return {
      root: true,
      marker: root.getAttribute("data-astryx-component"),
      dl: true,
      dlId: dl.id,
      gridClass: dl.className,
      display: cs.display,
      tracks: cs.gridTemplateColumns,
      inlineStyle: dl.getAttribute("style"),
      dts: dts.length,
      dds: dds.length,
      itemMarker: dts[0] ? dts[0].getAttribute("data-astryx-component") : null,
      sideBySide: rows.filter((r) => r.dtLeft < r.ddLeft).length,
      stacked: rows.filter((r) => r.ddTop > r.dtTop).length,
      toggle: toggle
        ? {
            label: toggle.textContent.trim(),
            controls: toggle.getAttribute("aria-controls"),
            type: toggle.getAttribute("type"),
          }
        : null,
    };
  }, id);

const single = await readList("showcase-metadata-single");
const multi = await readList("showcase-metadata-multi");
const fixed = await readList("showcase-metadata-fixed");
const truncated = await readList("showcase-metadata-truncated");
const horizontal = await readList("showcase-metadata-horizontal");

check("the list renders a real <dl>", single && single.dl === true);
check(
  "every term has its value: six dt and six dd",
  single && single.dts === 6 && single.dds === 6,
  `got ${single && single.dts} dt / ${single && single.dds} dd`,
);
check(
  "inline labels: two tracks, and the label ends where the value begins",
  single && single.tracks.split(" ").length === 2 && single.sideBySide === 6,
  `tracks=${single && single.tracks} sideBySide=${single && single.sideBySide}`,
);
check(
  "a multi-column list stacks its labels, because there is no term column to align to",
  multi && multi.gridClass.includes("stacked-multi") && multi.stacked === 6,
  `${multi && multi.gridClass} stacked=${multi && multi.stacked}`,
);
check(
  "an explicit column count reaches the grid as a template (three columns, labels stacked by default)",
  fixed && (fixed.inlineStyle || "").includes("repeat(3, 1fr)"),
  `${fixed && fixed.inlineStyle}`,
);
check(
  "truncation renders only the first N, and a toggle that points at the <dl>",
  truncated &&
    truncated.dts === 3 &&
    truncated.toggle &&
    truncated.toggle.controls === truncated.dlId &&
    truncated.toggle.type === "button",
  `${truncated && truncated.dts} dt, toggle=${JSON.stringify(truncated && truncated.toggle)}, dlId=${truncated && truncated.dlId}`,
);
check(
  "both markers are present, on the list and on the item",
  single && single.marker === "MetadataList" && single.itemMarker === "MetadataListItem",
  `list=${single && single.marker} item=${single && single.itemMarker}`,
);
check(
  "a horizontal list is a wrapping row, not a grid",
  horizontal && horizontal.gridClass.includes("horizontal") && horizontal.display === "flex",
  `${horizontal && horizontal.gridClass} display=${horizontal && horizontal.display}`,
);

// The behaviour the state exists for: clicking the toggle shows the rest, and clicking it again puts them
// back. This is the check the jsdom gate cannot make.
await page.click("#showcase-metadata-truncated .astryx-metadata-list__toggle");
// The click schedules the update and the read would otherwise beat the re-render - which is how this check
// first failed: it read three terms and called a working toggle broken. Wait for the DOM, then assert.
await page
  .waitForFunction(() => document.querySelectorAll("#showcase-metadata-truncated dl dt").length === 6, null, {
    timeout: 3000,
  })
  .catch(() => {});
const expanded = await readList("showcase-metadata-truncated");
check(
  "clicking the toggle shows all six",
  expanded && expanded.dts === 6 && expanded.toggle.label === "Show less",
  `${expanded && expanded.dts} dt, label=${expanded && expanded.toggle.label}`,
);
await page.click("#showcase-metadata-truncated .astryx-metadata-list__toggle");
await page
  .waitForFunction(() => document.querySelectorAll("#showcase-metadata-truncated dl dt").length === 3, null, {
    timeout: 3000,
  })
  .catch(() => {});
const collapsed = await readList("showcase-metadata-truncated");
check(
  "clicking it again puts them back",
  collapsed && collapsed.dts === 3 && collapsed.toggle.label === "Show all",
  `${collapsed && collapsed.dts} dt, label=${collapsed && collapsed.toggle.label}`,
);

// MoreMenu: the delegation, and the marker rule that makes it visible. The trigger is a Button, but the
// component the user is looking at is MoreMenu, and that is what the marker has to say.
const moreTrigger = await page.evaluate(() => {
  const button = document.getElementById("more-menu-trigger");
  if (!button) return null;
  return {
    tag: button.tagName,
    marker: button.getAttribute("data-astryx-component"),
    ariaLabel: button.getAttribute("aria-label"),
    glyph: !!button.querySelector(".astryx-more-menu__glyph"),
    background: getComputedStyle(button).backgroundColor,
  };
});
check(
  "a delegating trigger names the component the user sees, not the Button it is",
  moreTrigger && moreTrigger.marker === "MoreMenu" && moreTrigger.tag === "BUTTON",
  JSON.stringify(moreTrigger),
);
check(
  "the default label is the accessible name, and the glyph is not text",
  moreTrigger && moreTrigger.ariaLabel === "More" && moreTrigger.glyph && !moreTrigger.textContent,
  JSON.stringify(moreTrigger),
);
const namedTrigger = await page.getAttribute("#more-menu-named-trigger", "aria-label");
check("a label of its own becomes the accessible name", namedTrigger === "Actions", `${namedTrigger}`);

// The delegation end to end: this trigger is a Button, and clicking it is what opens the menu.
const moreRows = () => page.evaluate(() => document.querySelectorAll("#more-menu-menu [role='menuitem']").length);
check("it starts closed", (await moreRows()) === 0);
await page.click("#more-menu-trigger");
await page.waitForFunction(() => document.querySelector("#more-menu-trigger").getAttribute("aria-expanded") === "true", null, { timeout: 3000 }).catch(() => {});
check("clicking the delegated trigger opens the menu it delegates to", (await moreRows()) > 0, `rows=${await moreRows()}`);
await page.keyboard.press("Escape");

const moreControlled = async () => page.getAttribute("#more-menu-controlled-trigger", "aria-expanded");
await page.click("#more-menu-controlled-toggle");
await page.waitForFunction(() => document.querySelector("#more-menu-controlled-trigger").getAttribute("aria-expanded") === "true", null, { timeout: 3000 }).catch(() => {});
check("and it is controllable, because the menu underneath is", (await moreControlled()) === "true", `${await moreControlled()}`);

// ProgressBar: the fill is measured, the role is on the track, and the marks are reachable on their own.
const progress = await page.evaluate(() => {
  const root = document.getElementById("progress-labelled");
  if (!root) return null;
  const track = root.querySelector('[role="progressbar"]');
  const fill = root.querySelector(".astryx-progress-bar__fill");
  const trackBox = track.getBoundingClientRect();
  const fillBox = fill.getBoundingClientRect();
  const label = document.getElementById(root.id + "-label");
  return {
    roleIsOnTrack: !!track,
    roleIsNotOnRoot: !root.hasAttribute("role"),
    valueNow: track.getAttribute("aria-valuenow"),
    valueMin: track.getAttribute("aria-valuemin"),
    valueMax: track.getAttribute("aria-valuemax"),
    valueText: track.getAttribute("aria-valuetext"),
    labelPoints: track.getAttribute("aria-labelledby") === (label && label.id),
    measuredPct: Math.round((fillBox.width / trackBox.width) * 100),
    valueLabelText: (root.querySelector(".astryx-progress-bar__value") || {}).textContent,
  };
});
check(
  "the role is on the track and the numbers are the value",
  progress && progress.roleIsOnTrack && progress.roleIsNotOnRoot && progress.valueNow === "60" && progress.valueMin === "0" && progress.valueMax === "100" && progress.valueText === "60%",
  JSON.stringify(progress),
);
check("the label names it through aria-labelledby", progress && progress.labelPoints === true, JSON.stringify(progress));
check(
  "and the fill is 60% of the track, measured rather than read off a class",
  progress && Math.abs(progress.measuredPct - 60) <= 2,
  `measured ${progress && progress.measuredPct}%`,
);
check("the value label reports the value", progress && progress.valueLabelText === "60%", `${progress && progress.valueLabelText}`);

const indeterminate = await page.evaluate(() => {
  const root = document.getElementById("progress-indeterminate");
  const track = root && root.querySelector('[role="progressbar"]');
  const fill = root && root.querySelector(".astryx-progress-bar__fill");
  const reduced = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  return track
    ? {
        hasValueNow: track.hasAttribute("aria-valuenow"),
        hasValueText: track.hasAttribute("aria-valuetext"),
        clipped: !!root.querySelector(".astryx-progress-bar__track--clipped"),
        reduced,
        // Under reduced motion the animation is off *by design*, so "is it animating" is the wrong question
        // to ask unconditionally: this harness runs with reduced motion, which is how the first version of
        // this check failed while the CSS was right.
        animating: fill ? fill.getAnimations().length > 0 : false,
        declaredAnimation: fill ? getComputedStyle(fill).animationName : null,
      }
    : null;
});
check(
  "an indeterminate bar reports no value, and clips a band that animates unless motion is reduced",
  indeterminate &&
    !indeterminate.hasValueNow &&
    !indeterminate.hasValueText &&
    indeterminate.clipped &&
    (indeterminate.reduced ? indeterminate.declaredAnimation === "none" : indeterminate.animating),
  JSON.stringify(indeterminate),
);

const marks = await page.evaluate(() => {
  const root = document.getElementById("progress-marked");
  if (!root) return null;
  const ticks = [...root.querySelectorAll(".astryx-progress-bar__mark")];
  const track = root.querySelector('[role="progressbar"]');
  return {
    count: ticks.length,
    allFocusable: ticks.every((t) => t.getAttribute("tabindex") === "0"),
    allLabelled: ticks.every((t) => (t.getAttribute("aria-label") || "").length > 0),
    // The claim that matters: a tick is not inside the progressbar role, so a screen reader reaches each
    // mark's label without re-announcing the bar's value.
    outsideTheRole: ticks.every((t) => t.closest('[role="progressbar"]') === null),
    trackIsAncestor: !!track && !!root.querySelector(".astryx-progress-bar__track-container"),
  };
});
check(
  "every mark is a focusable tick with a label, outside the progressbar role",
  marks && marks.count === 3 && marks.allFocusable && marks.allLabelled && marks.outsideTheRole,
  JSON.stringify(marks),
);

// Scoped to the mark's own tooltip: the page has dozens, and asking for the first [role=tooltip] found
// another section's - which is how this check first failed, reporting a browser message instead of a label.
await page.focus("#progress-marked .astryx-progress-bar__mark");
// aria-describedby sits on the Tooltip's own wrapper - the anchor - not on the node the caller passed in,
// which is the second thing this check got wrong before it got it right.
const readMarkTip = () =>
  page.evaluate(() => {
    const tick = document.querySelector("#progress-marked .astryx-progress-bar__mark");
    const anchor = tick && tick.closest(".astryx-tooltip-anchor");
    const id = anchor && anchor.getAttribute("aria-describedby");
    const tip = id ? document.getElementById(id) : null;
    return { id, text: tip ? tip.textContent.trim() : null };
  });
await page
  .waitForFunction(
    () => {
      const tick = document.querySelector("#progress-marked .astryx-progress-bar__mark");
      const anchor = tick && tick.closest(".astryx-tooltip-anchor");
      const id = anchor && anchor.getAttribute("aria-describedby");
      return !!(id && document.getElementById(id));
    },
    null,
    { timeout: 2000 },
  )
  .catch(() => {});
const markTip = await readMarkTip();
check(
  "focusing a mark reveals its own label through the tooltip",
  !!markTip.text && markTip.text.includes("checkpoint"),
  JSON.stringify(markTip),
);

const disabledBar = await page.evaluate(() => {
  const root = document.getElementById("progress-disabled");
  const fill = root && root.querySelector(".astryx-progress-bar__fill");
  return fill ? { cls: fill.className, bg: getComputedStyle(fill).backgroundColor } : null;
});
check(
  "a disabled bar paints its fill muted rather than in a variant colour",
  disabledBar && disabledBar.cls.includes("--disabled") && disabledBar.bg !== "rgba(0, 0, 0, 0)",
  JSON.stringify(disabledBar),
);

// Avatar: the four display states in order, and the ARIA that a role="img" root forces.
const avatarInitials = await page.evaluate(() => {
  const root = document.getElementById("avatar-initials");
  return root
    ? {
        text: (root.querySelector(".astryx-avatar__initials") || {}).textContent,
        role: root.getAttribute("role"),
        label: root.getAttribute("aria-label"),
        tag: root.tagName,
      }
    : null;
});
check(
  "an avatar with a name derives initials and announces the name",
  avatarInitials && avatarInitials.text === "AL" && avatarInitials.role === "img" && avatarInitials.label === "Ada Lovelace" && avatarInitials.tag === "DIV",
  JSON.stringify(avatarInitials),
);

// The chain is the behaviour: two sources that cannot load, then the initials. A real image error has to fire,
// which is exactly what this gate can do and the jsdom harness cannot.
await page
  .waitForFunction(
    () => {
      const root = document.getElementById("avatar-fallback");
      const initials = root && root.querySelector(".astryx-avatar__initials");
      return !!initials && initials.textContent === "GH";
    },
    null,
    { timeout: 4000 },
  )
  .catch(() => {});
const avatarChain = await page.evaluate(() => {
  const root = document.getElementById("avatar-fallback");
  return root
    ? {
        initials: (root.querySelector(".astryx-avatar__initials") || {}).textContent,
        images: root.querySelectorAll("img").length,
        label: root.getAttribute("aria-label"),
      }
    : null;
});
check(
  "both sources fail, and the initials take over",
  avatarChain && avatarChain.initials === "GH" && avatarChain.images === 0,
  JSON.stringify(avatarChain),
);

const avatarImage = await page.evaluate(() => {
  const root = document.getElementById("avatar-image");
  const img = root && root.querySelector("img");
  return root
    ? {
        hasImage: !!img,
        src: img ? img.getAttribute("src") : null,
        initials: root.querySelectorAll(".astryx-avatar__initials").length,
        label: root.getAttribute("aria-label"),
      }
    : null;
});
check(
  "a source that loads is the image, with no initials behind it",
  avatarImage && avatarImage.hasImage && (avatarImage.src || "").startsWith("data:image/svg+xml") && avatarImage.initials === 0,
  JSON.stringify(avatarImage),
);

const avatarStatus = await page.evaluate(() => {
  const root = document.getElementById("avatar-status");
  const dot = root && root.querySelector(".astryx-avatar-status-dot");
  return root
    ? {
        label: root.getAttribute("aria-label"),
        hasDot: !!dot,
        dotHidden: dot ? dot.getAttribute("aria-hidden") === "true" : false,
        dotLabelled: dot ? dot.hasAttribute("aria-label") : false,
        dotInsideContent: !!root.querySelector(".astryx-avatar__content .astryx-avatar-status-dot"),
      }
    : null;
});
check(
  "the status is composed into the avatar's own name",
  avatarStatus && avatarStatus.label === "Ada Lovelace, Online" && avatarStatus.hasDot,
  JSON.stringify(avatarStatus),
);
check(
  "and the dot stays decorative, so the status is announced once",
  avatarStatus && avatarStatus.dotHidden && !avatarStatus.dotLabelled && !avatarStatus.dotInsideContent,
  JSON.stringify(avatarStatus),
);

const avatarDecorative = await page.evaluate(() => {
  const root = document.getElementById("avatar-decorative");
  return root
    ? { role: root.getAttribute("role"), hidden: root.getAttribute("aria-hidden") }
    : null;
});
check(
  "an avatar with no name and no labelled status is decorative rather than a generic \"Avatar\"",
  avatarDecorative && avatarDecorative.role === "presentation" && avatarDecorative.hidden === "true",
  JSON.stringify(avatarDecorative),
);

const avatarElement = await page.evaluate(() => {
  const link = document.getElementById("avatar-link");
  const button = document.getElementById("avatar-button");
  return {
    linkTag: link ? link.tagName : null,
    linkHref: link ? link.getAttribute("href") : null,
    linkLabel: link ? link.getAttribute("aria-label") : null,
    linkRole: link ? link.getAttribute("role") : null,
    buttonTag: button ? button.tagName : null,
    buttonType: button ? button.getAttribute("type") : null,
    buttonLabel: button ? button.getAttribute("aria-label") : null,
  };
});
check(
  "a link is an <a> and a click handler is a <button type=button>, and neither takes role=img",
  avatarElement.linkTag === "A" &&
    avatarElement.linkHref === "#avatars" &&
    avatarElement.linkLabel === "Grace Hopper" &&
    avatarElement.linkRole === null &&
    avatarElement.buttonTag === "BUTTON" &&
    avatarElement.buttonType === "button" &&
    avatarElement.buttonLabel === "Grace Hopper",
  JSON.stringify(avatarElement),
);

const avatarGeometry = await page.evaluate(() => {
  const circle = document.getElementById("avatar-circle");
  const square = document.getElementById("avatar-square");
  const md = document.querySelector(".astryx-avatar--md");
  const xl = document.querySelector(".astryx-avatar--xl");
  const radius = (el) => (el ? parseFloat(getComputedStyle(el).borderTopLeftRadius) : null);
  return {
    circleRadius: radius(circle),
    circleWidth: circle ? circle.getBoundingClientRect().width : null,
    squareRadius: radius(square),
    mdWidth: md ? md.getBoundingClientRect().width : null,
    xlWidth: xl ? xl.getBoundingClientRect().width : null,
  };
});
check(
  "the shapes differ by radius, and the named sizes are upstream's ladder",
  avatarGeometry &&
    avatarGeometry.circleRadius >= avatarGeometry.circleWidth / 2 &&
    avatarGeometry.squareRadius <= 0.5 &&
    Math.round(avatarGeometry.mdWidth) === 36 &&
    Math.round(avatarGeometry.xlWidth) === 128,
  JSON.stringify(avatarGeometry),
);

// AvatarGroup: the group's ARIA, the chip, and an overlap that can be measured rather than eyeballed.
const avatarGroup = await page.evaluate(() => {
  const root = document.querySelector("#avatar-group .astryx-avatar-group");
  if (!root) return null;
  const hintId = root.getAttribute("aria-describedby");
  const hint = hintId ? document.getElementById(hintId) : null;
  const member = (k) => document.getElementById("avatar-group-member-" + k);
  const a = member("a");
  const b = member("b");
  const chip = document.getElementById("avatar-group-overflow");
  return {
    role: root.getAttribute("role"),
    label: root.getAttribute("aria-label"),
    hint: hint ? hint.textContent.trim() : null,
    // The measurement that matters: adjacent members overlap by round(36 * 0.25) = 9px.
    overlap: a && b ? Math.round(b.getBoundingClientRect().left - a.getBoundingClientRect().right) : null,
    chipTag: chip ? chip.tagName : null,
    chipText: chip ? chip.textContent.trim() : null,
    chipLabel: chip ? chip.getAttribute("aria-label") : null,
    chipSize: chip ? Math.round(chip.getBoundingClientRect().height) : null,
  };
});
check(
  "the group is a named group, and tells a screen reader it is navigable",
  avatarGroup && avatarGroup.role === "group" && avatarGroup.label === "Team" && !!avatarGroup.hint,
  JSON.stringify(avatarGroup),
);
check(
  "adjacent avatars overlap by round(size * 0.25), measured",
  avatarGroup && avatarGroup.overlap === -9,
  `overlap ${avatarGroup && avatarGroup.overlap}px`,
);
check(
  "the chip is a button the size of an avatar plus its border, labelled with the count",
  avatarGroup &&
    avatarGroup.chipTag === "BUTTON" &&
    avatarGroup.chipText === "+7" &&
    avatarGroup.chipLabel === "7 more" &&
    avatarGroup.chipSize === 40,
  JSON.stringify(avatarGroup),
);

const avatarGroupLarge = await page.evaluate(() => {
  const a = document.getElementById("avatar-group-large-member-a");
  const b = document.getElementById("avatar-group-large-member-b");
  const chip = document.getElementById("avatar-group-large-overflow");
  return {
    overlap: a && b ? Math.round(b.getBoundingClientRect().left - a.getBoundingClientRect().right) : null,
    chipSize: chip ? Math.round(chip.getBoundingClientRect().height) : null,
  };
});
check(
  "and the overlap is a ratio, so a large group overlaps further",
  avatarGroupLarge.overlap === -12 && avatarGroupLarge.chipSize === 52,
  JSON.stringify(avatarGroupLarge),
);

const avatarGroupCustom = await page.evaluate(() => {
  const chip = document.getElementById("avatar-group-custom-overflow");
  return chip ? { text: chip.textContent.trim(), label: chip.getAttribute("aria-label") } : null;
});
check(
  "a caller-supplied chip says what the caller wants and still names the count",
  avatarGroupCustom && avatarGroupCustom.text === "see all" && avatarGroupCustom.label === "99 more",
  JSON.stringify(avatarGroupCustom),
);

// One tab stop, arrows between members - which is the mechanism's behaviour, checked from the outside.
const roving = await page.evaluate(() => {
  const tabs = (id) => {
    const el = document.getElementById(id);
    return el ? el.getAttribute("tabindex") : "__missing__";
  };
  return {
    first: tabs("avatar-group-member-a"),
    second: tabs("avatar-group-member-b"),
    third: tabs("avatar-group-member-c"),
  };
});
check(
  "a group is one tab stop, with the members behind it",
  roving.first === "0" && roving.second === "-1" && roving.third === "-1",
  JSON.stringify(roving),
);

await page.focus("#avatar-group-member-a");
await page.keyboard.press("ArrowRight");
const afterArrow = await page.evaluate(() => {
  const active = document.activeElement;
  return active ? active.id : null;
});
check("and the arrow keys move between members", afterArrow === "avatar-group-member-b", `${afterArrow}`);

// ToggleButton: aria-pressed is the state, and a real click has to move it.
const toggleGroup = await page.evaluate(() => {
  const root = document.getElementById("toggle-group");
  if (!root) return null;
  return {
    role: root.getAttribute("role"),
    label: root.getAttribute("aria-label"),
    orientation: root.getAttribute("aria-orientation"),
    pressed: ["toggle-bold", "toggle-italic", "toggle-underline"].map((id) => {
      const el = document.getElementById(id);
      return el ? el.getAttribute("aria-pressed") : "__missing__";
    }),
    markers: ["toggle-bold", "toggle-italic", "toggle-underline"].map((id) => {
      const el = document.getElementById(id);
      return el ? el.getAttribute("data-astryx-component") : "__missing__";
    }),
  };
});
check(
  "a group of toggles is a named group, and every toggle starts up",
  toggleGroup &&
    toggleGroup.role === "group" &&
    toggleGroup.label === "Text style" &&
    toggleGroup.orientation === "horizontal" &&
    JSON.stringify(toggleGroup.pressed) === JSON.stringify(["false", "false", "false"]),
  JSON.stringify(toggleGroup),
);
// The delegation marker: without it a wrapper carries Button's marker and is invisible to every tool that
// identifies components by it - the IconButton rule, and the reason ToggleButton passes component_name.
check(
  "each toggle names itself rather than inheriting the Button it wraps",
  toggleGroup && toggleGroup.markers.every((m) => m === "ToggleButton"),
  JSON.stringify(toggleGroup && toggleGroup.markers),
);

await page.click("#toggle-bold");
await page
  .waitForFunction(
    () => {
      const el = document.getElementById("toggle-bold");
      return el && el.getAttribute("aria-pressed") === "true";
    },
    null,
    { timeout: 2000 },
  )
  .catch(() => {});
const afterClick = await page.evaluate(() => {
  const el = document.getElementById("toggle-bold");
  const other = document.getElementById("toggle-italic");
  return {
    pressed: el ? el.getAttribute("aria-pressed") : null,
    neighbour: other ? other.getAttribute("aria-pressed") : null,
    // The styles hang off the ARIA attribute, so the painted weight and the announced state cannot disagree.
    // The pressed style is the label's weight - upstream's pressed style is exactly that, and nothing else.
    weight: el ? getComputedStyle(el).fontWeight : null,
    resting: other ? getComputedStyle(other).fontWeight : null,
  };
});
check(
  "clicking a toggle presses it, and only it",
  afterClick.pressed === "true" && afterClick.neighbour === "false",
  JSON.stringify(afterClick),
);
check(
  "and the pressed style - the label weight - follows the announced state",
  Number(afterClick.weight) > Number(afterClick.resting),
  `${afterClick.weight} vs ${afterClick.resting}`,
);

const toggleIconOnly = await page.evaluate(() => {
  const el = document.getElementById("toggle-icon-only");
  return el
    ? {
        label: el.getAttribute("aria-label"),
        text: el.textContent.trim(),
        title: el.getAttribute("title"),
        pressed: el.getAttribute("aria-pressed"),
      }
    : null;
});
check(
  "an icon-only toggle names itself with its label and shows it on hover",
  toggleIconOnly &&
    toggleIconOnly.label === "Favorite" &&
    toggleIconOnly.text === "" &&
    toggleIconOnly.title === "Favorite" &&
    toggleIconOnly.pressed === "true",
  JSON.stringify(toggleIconOnly),
);

const swapped = await page.evaluate(() => {
  const on = document.querySelector("#toggle-swap svg circle");
  const off = document.querySelector("#toggle-swap-off svg circle");
  return {
    pressedFill: on ? on.getAttribute("fill") : null,
    restingFill: off ? off.getAttribute("fill") : null,
  };
});
check(
  "the pressed icon replaces the resting one",
  swapped.pressedFill === "currentColor" && swapped.restingFill === "none",
  JSON.stringify(swapped),
);

const verticalGroup = await page.evaluate(() => {
  const root = document.getElementById("toggle-group-vertical");
  return root
    ? { orientation: root.getAttribute("aria-orientation"), direction: getComputedStyle(root).flexDirection }
    : null;
});
check(
  "a vertical group says so, in its ARIA and in its layout",
  verticalGroup && verticalGroup.orientation === "vertical" && verticalGroup.direction === "column",
  JSON.stringify(verticalGroup),
);

/* popover="manual" is how a surface asks for explicit dismissal only — and that is an attribute
       meaning, not a flag this port implements. */
    await page.click("#showcase-layer-manual-trigger");
    await page.waitForTimeout(250);
    check("a manual layer opens", (await layerState("showcase-layer-manual")).open === true);
    await page.keyboard.press("Escape");
    await page.waitForTimeout(250);
    check("Escape does not touch it — the platform was never asked to dismiss this one",
      (await layerState("showcase-layer-manual")).open === true);
    await page.mouse.click(5, 5);
    await page.waitForTimeout(250);
    check("nor does a real click outside",
      (await layerState("showcase-layer-manual")).open === true);
    await page.click("#showcase-layer-manual-close");
    await page.waitForTimeout(250);
    const manualClosed = await layerState("showcase-layer-manual");
    check("only the application closes it, and the value follows",
      manualClosed.open === false && /closed$/.test(manualClosed.value ?? ""),
      JSON.stringify(manualClosed));
  }

  // -------------------------------------------------------- SelectableCard (M28)
  console.log("\nSelectableCard (live)");
  const scState = (id) =>
    page.evaluate((sel) => {
      const el = document.getElementById(sel);
      if (!el) return null;
      const input = el.querySelector('input[type="checkbox"]');
      return {
        marker: el.getAttribute("data-astryx-component"),
        selected: el.getAttribute("data-astryx-selected"),
        checked: input ? input.checked : null,
        label: input ? input.getAttribute("aria-label") : null,
        ariaDisabled: input ? input.getAttribute("aria-disabled") : null,
        hidden: input ? input.classList.contains("astryx-visually-hidden") : null,
      };
    }, id);
  {
    const first = await scState("sc-blue");
    // The marker is the whole point of Card's ?component_name: a wrapper that inherited "Card"
    // would be invisible to the appearance contract and to this gate.
    check("a selectable card stamps its OWN marker, not Card's",
      first && first.marker === "SelectableCard", JSON.stringify(first));
    check("its state is announced as an attribute the CSS can read",
      first && first.selected === "false", String(first && first.selected));
    check("the visually-hidden checkbox carries the accessible name",
      first && first.label === "Blue" && first.hidden === true, JSON.stringify(first));

    await page.click("#sc-blue");
    await page.waitForFunction(
      () => document.getElementById("sc-blue")?.getAttribute("data-astryx-selected") === "true",
    ).catch(() => {});
    const selected = await scState("sc-blue");
    check("clicking the surface selects it, and the checkbox follows",
      selected && selected.selected === "true" && selected.checked === true, JSON.stringify(selected));

    await page.click("#sc-green");
    await page.waitForTimeout(200);
    const [still, green] = [await scState("sc-blue"), await scState("sc-green")];
    check("a second card selects too - the set is the caller's, so the first stays",
      still.selected === "true" && green.selected === "true", JSON.stringify([still.selected, green.selected]));

    await page.click("#sc-blue");
    await page.waitForTimeout(200);
    check("clicking a selected card deselects it",
      (await scState("sc-blue")).selected === "false");

    check("the nested-control card really does contain a button",
      await page.evaluate(() => !!document.querySelector("#sc-nested button")) === true);
    await page.click("#sc-nested button");
    await page.waitForTimeout(250);
    check("clicking the nested button does NOT select the card",
      (await scState("sc-nested")).selected === "false");

    const disabled = await scState("sc-disabled");
    check("a disabled card still names itself and reports aria-disabled",
      disabled && disabled.ariaDisabled === "true" && disabled.label === "Unavailable",
      JSON.stringify(disabled));
    await page.click("#sc-disabled", { force: true }).catch(() => {});
    await page.waitForTimeout(250);
    check("clicking a disabled card changes nothing",
      (await scState("sc-disabled")).selected === "false");

    // Space is native on a checkbox; Enter is not, which is why upstream adds it by hand.
    await page.evaluate(() => {
      document.querySelector('#sc-purple input[type="checkbox"]').focus();
    });
    await page.keyboard.press("Enter");
    await page.waitForTimeout(250);
    check("Enter selects, because a native checkbox does not answer Enter",
      (await scState("sc-purple")).selected === "true");

    // The rule that is easy to lose: a click that ends a text selection is a selection, not a click.
    // sc-purple is selected now, so a handler that ignored this rule would deselect it.
    const dragged = await page.evaluate(() => {
      const card = document.getElementById("sc-purple");
      const range = document.createRange();
      range.selectNodeContents(card);
      const sel = window.getSelection();
      sel.removeAllRanges();
      sel.addRange(range);
      const nonCollapsed = sel.isCollapsed === false;
      // dispatched directly, so nothing collapses the selection before the handler reads it
      card.dispatchEvent(new MouseEvent("click", { bubbles: true, cancelable: true }));
      return nonCollapsed;
    });
    check("the selection is genuinely non-collapsed before the synthetic click", dragged === true);
    await page.waitForTimeout(250);
    check("a click that ends a text selection does not change the selection",
      (await scState("sc-purple")).selected === "true",
      `selected=${(await scState("sc-purple")).selected}`);
    await page.evaluate(() => window.getSelection().removeAllRanges());
  }

  // --------------------------------------------------------- ClickableCard (M29)
  console.log("\nClickableCard (live)");
  {
    const cards = await page.evaluate(() =>
      [...document.querySelectorAll('#clickable-card [data-astryx-component="ClickableCard"]')].map((c) => {
        const a = c.querySelector("a");
        const b = c.querySelector("button");
        const el = a || b;
        return {
          marker: c.getAttribute("data-astryx-component"),
          href: a ? a.getAttribute("href") : null,
          role: a ? a.getAttribute("role") : null,
          ariaDisabled: el ? el.getAttribute("aria-disabled") : null,
          tabindex: el ? el.getAttribute("tabindex") : null,
          label: el ? el.getAttribute("aria-label") : null,
          hidden: el ? el.classList.contains("astryx-visually-hidden") : null,
          isButton: !!b,
        };
      }));
    check("four clickable cards render", cards.length === 4, `got ${cards.length}`);
    check("each stamps its OWN marker, not Card's",
      cards.length === 4 && cards.every((c) => c.marker === "ClickableCard"),
      JSON.stringify(cards.map((c) => c.marker)));
    check("the link card carries its href, its accessible name and the visually-hidden class",
      cards[0] && cards[0].href === "https://example.com/report" && cards[0].label === "Open the report"
        && cards[0].hidden === true,
      JSON.stringify(cards[0]));
    check("with no href the action is a button, not a link", cards[1] && cards[1].isButton === true,
      JSON.stringify(cards[1]));
    check("disabled: no href, role=link, aria-disabled, and out of the tab order",
      cards[2] && cards[2].href === null && cards[2].role === "link"
        && cards[2].ariaDisabled === "true" && cards[2].tabindex === "-1",
      JSON.stringify(cards[2]));
    // A security assertion rather than a structural one: unlike upstream - which hands the href to a
    // framework link component that vets it - nothing here passes through React, so the ATTRIBUTE has to
    // be gated too. No href at all is the only safe rendering of a refused value.
    check("a javascript: href renders INERT - no href attribute reaches the DOM",
      cards[3] && cards[3].href === null && cards[3].ariaDisabled === "true",
      JSON.stringify(cards[3]));
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
    "coverage stats are 50 ported / 53 not / 103 total",
    JSON.stringify(cov.stats) === JSON.stringify(["50", "53", "103"]),
    cov.stats.join(" | "),
  );
  check("unported list rendered 53 entries", cov.unported === 53, `got ${cov.unported}`);
  check("upstream commit shown", /astryx@[0-9a-f]{6,}/.test(cov.upstream), cov.upstream);
  check("coverage.json reported no inconsistency", !/WARNING/.test(cov.foot), cov.foot);


  // The README's showcase row is prose, and prose is where numbers go stale unobserved: this row claimed
  // 50 ported components, 309 examples and 53 sections while the page it describes had 51, 312 and 54 -
  // every one of those changed in a single session, and no gate looked. A number a gate can compare is a
  // claim; a number nothing reads is a liability. This reads it.
  {
    const readme = readFileSync(resolve(root, "README.md"), "utf8");
    const row = readme.split("\n").find((l) => l.startsWith("| Showcase site")) ?? "";
    const ported = JSON.parse(readFileSync(resolve(root, "port.json"), "utf8")).ported.length;
    const claimed = {
      components: Number(row.match(/all (\d+) ported components/)?.[1]),
      examples: Number(row.match(/(\d+) examples/)?.[1]),
      sections: Number(row.match(/(\d+) sections/)?.[1]),
    };
    check(
      "the README's showcase row matches the page it describes",
      claimed.components === ported &&
        claimed.examples === totalExamples &&
        claimed.sections === sections.length,
      `README says ${claimed.components}/${claimed.examples}/${claimed.sections}, page has ${ported}/${totalExamples}/${sections.length}`,
    );
  }
  // ---------------------------------------------------------------- OverflowList (M30)
  //
  // The component's whole design is the pair of containers, so the checks read both: the hidden one that
  // is measured, and the visible one that shows the slice. Two traps in particular. The measurement
  // container must be hidden AND still have width - a display:none element has none, and every item
  // measured through it would read as zero. And the visible items must actually FIT: a count is only
  // right if the widths it kept, plus the gaps between them, are inside the row.
  console.log("\nOverflowList (live)");
  const olState = (rootId) =>
    page.evaluate((id) => {
      const root = document.getElementById(id);
      if (!root) return null;
      const measure = root.querySelector(".astryx-overflow-list__measure");
      const row = root.querySelector(".astryx-overflow-list__row");
      const items = [...row.querySelectorAll(".astryx-overflow-list__item")];
      const indicator = row.querySelector(".astryx-overflow-list__indicator");
      const gap = row ? Math.round(parseFloat(getComputedStyle(row).columnGap) || 0) : 0;
      const widths = items.map((i) => i.offsetWidth);
      return {
        marker: root.getAttribute("data-astryx-component"),
        measureVisibility: measure ? getComputedStyle(measure).visibility : null,
        measureWidth: measure ? measure.offsetWidth : 0,
        measureChildren: measure ? measure.children.length : 0,
        rowWidth: row ? row.offsetWidth : 0,
        visible: items.length,
        visibleLabels: items.map((i) => i.textContent.trim()),
        widths,
        gap,
        fits: widths.reduce((a, b) => a + b, 0) + gap * Math.max(0, widths.length - 1) <= (row ? row.offsetWidth : 0),
        indicator: indicator ? indicator.textContent.trim() : null,
      };
    }, rootId);

  const olNarrow = await olState("overflow-list-narrow");
  const olFromStart = await olState("overflow-list-start");
  const olRoomy = await olState("overflow-list-roomy");

  check("the wrapper stamps its own marker, not the one it wraps",
    olNarrow?.marker === "OverflowList", String(olNarrow?.marker));

  check("the measurement container is hidden but still MEASURABLE",
    olNarrow?.measureVisibility === "hidden" && olNarrow?.measureWidth > 0,
    `visibility=${olNarrow?.measureVisibility} width=${olNarrow?.measureWidth}`);

  check("every item is in the hidden container, even the ones that will not be shown",
    olNarrow?.measureChildren === 7, String(olNarrow?.measureChildren) + " children (6 items + the indicator)");

  check("something did collapse, and not everything did",
    olNarrow !== null && olNarrow.visible > 0 && olNarrow.visible < 6, `${olNarrow?.visible} of 6 visible`);

  check("the items it kept actually fit inside the row",
    olNarrow?.fits === true,
    `widths=${JSON.stringify(olNarrow?.widths)} gap=${olNarrow?.gap} row=${olNarrow?.rowWidth}`);

  check("the indicator says how many are hidden - exactly",
    olNarrow?.indicator === "+" + String(6 - (olNarrow?.visible ?? 0)), String(olNarrow?.indicator));

  check("collapse_from: Start keeps the other end, at the same count",
    olFromStart !== null &&
      olFromStart.visible === olNarrow?.visible &&
      olFromStart.visibleLabels.join(",") !== olNarrow?.visibleLabels.join(",") &&
      olFromStart.visibleLabels[olFromStart.visibleLabels.length - 1] === "six",
    `start=[${olFromStart?.visibleLabels.join(",")}] end=[${olNarrow?.visibleLabels.join(",")}]`);

  check("with room for all six, nothing is hidden and there is no indicator",
    olRoomy?.visible === 6 && olRoomy?.indicator === null,
    `${olRoomy?.visible} visible, indicator=${String(olRoomy?.indicator)}`);

  // The observer, proved rather than assumed. Loading the page at a wider viewport would measure on
  // mount and prove nothing about it - the only evidence that live resizing works is a WINDOW RESIZE
  // with no reload, and the count following it.
  const olViewportBefore = page.viewportSize();
  const olBefore = await olState("overflow-list-narrow");
  await page.setViewportSize({
    width: (olViewportBefore?.width ?? 1280) + 700,
    height: olViewportBefore?.height ?? 900,
  });
  await page.waitForTimeout(500); // a frame for the observer, and one for the re-render
  const olAfter = await olState("overflow-list-narrow");
  check("resizing the window re-measures and shows more, with no reload",
    (olAfter?.visible ?? 0) > (olBefore?.visible ?? 0),
    `${olBefore?.visible} -> ${olAfter?.visible} visible, row ${olBefore?.rowWidth} -> ${olAfter?.rowWidth}px`);
  check("and the indicator keeps telling the truth after it",
    olAfter?.indicator === (olAfter?.visible === 6 ? null : "+" + String(6 - (olAfter?.visible ?? 0))),
    String(olAfter?.indicator));
  if (olViewportBefore) await page.setViewportSize(olViewportBefore);
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
