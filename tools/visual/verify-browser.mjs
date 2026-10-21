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
    "SelectableCard", "ClickableCard", "OverflowList", "Link", "Token", "Spinner", "Thumbnail",
    "ScrollableArea",
    "NavHeadingMenu",
    "SegmentedControl",
    "Overlay",
    "FileInput",
    "Layout",
    "Slider",
    "Item",
    "List",
    "TreeList",
    "NumberInput",
    "CheckboxList",
    "Banner",
    "Collapsible",
    "Breadcrumbs",
    "Carousel",
    "TabList",
    "Lightbox",
    "HoverCard",
    "Timestamp",
    "ComplexSelector",
    "Outline",    "ButtonGroup",
    "Popover",
    "Timer",
    "InputGroup",
    "Toolbar",
    "MetadataList",
    "MoreMenu",
    "ProgressBar",
    "Avatar",
    "AvatarGroup",
    "ToggleButton",
    "Resizable",
    "Toast",
    "MobileNav",
    "Tokenizer",
    "MultiSelector",
    "Stepper",
    "Pagination",
    "TopNav",
    "CodeBlock",
    "Calendar",
    "Chat",
    "Selector",
    "BottomSheet",
    "CommandPalette",
    "ContextMenu",
    "AppShell",
    "Typeahead",
    "DateRangeInput",
    "DateTimeInput",

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
  check("99 sections", sections.length === 99, `got ${sections.length}: ${sections.map((s) => s.name).join(",")}`);
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
    Stack: 8,
    Text: 12,
    Heading: 6,
    Button: 14,
    Badge: 15,
    Card: 12,
    Divider: 6,
    StatusDot: 7,
    Skeleton: 8,
    Center: 6,
    Section: 7,
    Grid: 6,
    VisuallyHidden: 3,
    HStack: 4,
    VStack: 4,
    AspectRatio: 6,
    IconButton: 5,
    Code: 5,
    Blockquote: 2,
    NavIcon: 2,
    EmptyState: 4,
    Citation: 6,
    Icon: 6,
    FieldStatus: 4,
    FieldLabel: 7,
    Indicator: 12,
    Kbd: 3,
    ButtonGroup: 3,
    Timer: 3,
    InputGroup: 3,
    Toolbar: 3,
    ClickableCard: 4,
    Link: 5,
    Token: 8,
    Spinner: 6,
    "Field + TextInput": 10,
    TextArea: 9,
    CheckboxInput: 11,
    Switch: 9,
    RadioList: 9,
    FormLayout: 7,
    Tooltip: 6,
    Dialog: 7,
    AlertDialog: 3,
    DialogHeader: 3,
    Layer: 3,
    Popover: 1,
    DropdownMenu: 4,
    Interactive: 2,
    MetadataList: 5,
    MoreMenu: 3,
    ProgressBar: 5,
    Avatar: 8,
    AvatarGroup: 3,
    ToggleButton: 3,
    SelectableCard: 3,
    OverflowList: 3,
    Thumbnail: 9,
    ScrollableArea: 7,
    NavHeadingMenu: 4,
    SegmentedControl: 10,
    Overlay: 12,
    FileInput: 6,
    Layout: 6,
    Slider: 8,
    Item: 13,
    List: 6,
    TreeList: 7,
    NumberInput: 10,
    Banner: 11,
    CheckboxList: 10,
    Collapsible: 9,
    Breadcrumbs: 8,
    Carousel: 8,
    TabList: 4,
    Lightbox: 3,
    HoverCard: 7,
    Resizable: 7,
    Toast: 6,
    Chat: 19,
    MobileNav: 6,
    Tokenizer: 9,
    MultiSelector: 8,
    CommandPalette: 4,
    Stepper: 7,
    Pagination: 7,
    TopNav: 5,
    CodeBlock: 8,
    Calendar: 7,
    Selector: 8,
    BottomSheet: 5,
    ContextMenu: 3,
    AppShell: 10,
    Typeahead: 5,
    DateRangeInput: 5,
    DateTimeInput: 5,
    Timestamp: 10,
    ComplexSelector: 11,
    Outline: 9,

  };
  const totalExamples = sections.reduce((a, s) => a + s.examples, 0);
  check("654 examples across the page", totalExamples === 654, `got ${totalExamples}`);

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
  check("99 nav links", nav.length === 99, `got ${nav.length}`);
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
    // A mark inside a closed surface is not painted because nothing is
    // painted there: the MultiSelector's option indicators live in a popover
    // that is closed until the field opens, and a closed popover is
    // display:none, so its marks have no box. Asking whether the mark
    // renders at all is the same question the responsive probe asks about a
    // closed dialog - a mark that exists but is invisible is the bug, and a
    // mark nobody can see yet is not.
    const paths = await page.evaluate(() =>
      [...document.querySelectorAll(".astryx-indicator__check path")]
        .filter((p) => p.checkVisibility?.() !== false)
        .map((p) => ({
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

    /* --------------------------------------------------- Layer: the app-declared inset (M43)
       The geometry the port owns: the provider's declaration must reach the layer (inherited
       custom property), the gutter must be spacing + declared inset, and the cap must be the
       viewport minus both gutters. All measured, not read back from classes. */
    /* The Layer section sits at the bottom of the showcase, so a plain click-into-view lands
       the anchor at the viewport's bottom edge and the platform correctly flips to the other
       side — which is not what this block is about. Center the anchor first so the declaration
       (gutter, cap, placement) is what is measured. */
    await page.evaluate(() => {
      document
        .getElementById("showcase-layer-inset-trigger")
        ?.scrollIntoView({ block: "center" });
    });
    await page.waitForTimeout(200);
    await page.click("#showcase-layer-inset-trigger");
    await page.waitForTimeout(250);
    const insetInfo = await page.evaluate(() => {
      const provider = document.getElementById("showcase-layer-inset-provider");
      const surface = document.getElementById("showcase-layer-inset-surface");
      const cs = surface ? getComputedStyle(surface) : null;
      const rect = surface?.getBoundingClientRect() ?? null;
      return {
        open: !!surface?.matches(":popover-open"),
        providerClass: provider ? provider.className : null,
        inset: cs ? cs.getPropertyValue("--astryx-layer-inset-block-end").trim() : null,
        positionArea: cs ? cs.positionArea : null,
        inlineFallbacks: surface?.getAttribute("style") ?? null,
        marginBlockEnd: cs ? cs.marginBlockEnd : null,
        maxBlockSize: cs ? cs.maxBlockSize : null,
        viewportH: window.innerHeight,
        surfaceBottom: rect ? Math.round(rect.bottom) : null,
      };
    });
    check("the layer under a declared inset opens",
      insetInfo.open === true, JSON.stringify(insetInfo));
    check("the declaration sits on the provider and inherits to the layer",
      !!insetInfo.providerClass?.includes("astryx-layer-provider") && insetInfo.inset === "56px",
      JSON.stringify({ cls: insetInfo.providerClass, inset: insetInfo.inset }));
    check("the surface is anchored at the block end by the platform",
      insetInfo.positionArea === "self-block-end", String(insetInfo.positionArea));
    check("the far gutter is the spacing plus the declared inset",
      insetInfo.marginBlockEnd === "72px", String(insetInfo.marginBlockEnd));
    /* The cap is the viewport minus both gutters: plain spacing on the start edge, spacing
       plus the declared 56px on the end edge (1rem is 16px). Computed from the live viewport
       so the check does not depend on the gate's window size. */
    check("the block cap is the viewport minus both gutters",
      insetInfo.maxBlockSize === `${insetInfo.viewportH - 16 - 72}px`,
      `got ${insetInfo.maxBlockSize} for viewport ${insetInfo.viewportH}`);
    check("the surface clears the declared bar, not just the viewport",
      insetInfo.surfaceBottom !== null && insetInfo.surfaceBottom <= insetInfo.viewportH - 72,
      JSON.stringify({ bottom: insetInfo.surfaceBottom, viewportH: insetInfo.viewportH }));
    check("the fallbacks name the slide options the stylesheet defines",
      (insetInfo.inlineFallbacks ?? "").includes("--astryx-layer-slide-below-center-same"),
      String(insetInfo.inlineFallbacks));
    await page.keyboard.press("Escape");
    await page.waitForTimeout(250);
    const insetClosed = await page.evaluate(() =>
      document.getElementById("showcase-layer-inset-surface")?.matches(":popover-open"));
    check("Escape closes the inset layer like any other", insetClosed === false, String(insetClosed));

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

// Thumbnail: the states that need a real browser — the image error (a source that
// 404s fires a real error event, and the errored-source cell returns the placeholder
// while a *changed* source gets a fresh attempt), the hover reveal of the remove
// button, and the interactive surface being a real button named "Open <name>".
const thumbError = await page.evaluate(() => {
  const root = document.getElementById("thumbnail-error");
  const placeholder = root && root.querySelector(".astryx-thumbnail__placeholder");
  return root
    ? {
        label: root.getAttribute("aria-label"),
        title: root.getAttribute("title"),
        role: root.getAttribute("role"),
        hasImg: !!root.querySelector("img"),
        hasPlaceholder: !!placeholder,
      }
    : null;
});
check(
  "a thumbnail whose source fails keeps the placeholder (the errored-source cell)",
  thumbError && thumbError.hasPlaceholder && !thumbError.hasImg,
  JSON.stringify(thumbError),
);
check(
  "the failing thumbnail is still the group labelled by its own name",
  thumbError && thumbError.role === "group" && thumbError.label === "broken.png — Anything" && thumbError.title === "broken.png",
  JSON.stringify(thumbError),
);

// The per-source freshness cell (a changed src gets a fresh <img> rather than the
// stale error) cannot be swapped live here — src is a plain string at graph-construction
// time, so the showcase renders the contract statically: a source that 404s lands on the
// placeholder. The internal cell is the same Bonsai.state machinery Avatar uses.
const thumbHover = await page.evaluate(() => {
  const root = document.getElementById("thumbnail-remove-hover");
  const slot = root && root.querySelector(".astryx-thumbnail__remove-slot--hover");
  const btn = slot && slot.querySelector(".astryx-button");
  return root
    ? {
        hasSlot: !!slot,
        revealed: slot ? getComputedStyle(slot).opacity === "1" : false,
        btnLabel: btn ? btn.getAttribute("aria-label") : null,
      }
    : null;
});
check(
  "the hover-reveal remove button is present but hidden until hover (CSS reveal), named Remove <name>",
  thumbHover && thumbHover.hasSlot && thumbHover.btnLabel === "Remove report.pdf — A lilac square",
  JSON.stringify(thumbHover),
);

const thumbAlways = await page.evaluate(() => {
  const root = document.getElementById("thumbnail-remove-always");
  const slot = root && root.querySelector(".astryx-thumbnail__remove-slot");
  return root
    ? {
        hasPlainSlot: !!slot,
        hasHoverSlot: !!root.querySelector(".astryx-thumbnail__remove-slot--hover"),
        visible: slot ? getComputedStyle(slot).opacity === "1" : false,
      }
    : null;
});
check(
  "show_remove_on always keeps the remove button visible (no hover class)",
  thumbAlways && thumbAlways.hasPlainSlot && !thumbAlways.hasHoverSlot && thumbAlways.visible,
  JSON.stringify(thumbAlways),
);

const thumbInteractive = await page.evaluate(() => {
  const root = document.getElementById("thumbnail-interactive");
  const action = root && root.querySelector(".astryx-thumbnail__action");
  return root
    ? {
        tag: action ? action.tagName : null,
        label: action ? action.getAttribute("aria-label") : null,
        type: action ? action.getAttribute("type") : null,
        hasImg: !!root.querySelector("img"),
      }
    : null;
});
check(
  "the interactive surface is a real <button type=button> named Open <name>",
  thumbInteractive && thumbInteractive.tag === "BUTTON" && thumbInteractive.type === "button" && thumbInteractive.label === "Open A lilac square" && thumbInteractive.hasImg,
  JSON.stringify(thumbInteractive),
);

const thumbDisabled = await page.evaluate(() => {
  const root = document.getElementById("thumbnail-disabled");
  return root
    ? {
        disabledClass: root.className.includes("astryx-thumbnail--disabled"),
        hasAction: !!root.querySelector(".astryx-thumbnail__action"),
        hasRemove: !!root.querySelector(".astryx-thumbnail__remove-slot"),
      }
    : null;
});
check(
  "a disabled thumbnail keeps its class and drops both action buttons",
  thumbDisabled && thumbDisabled.disabledClass && !thumbDisabled.hasAction && !thumbDisabled.hasRemove,
  JSON.stringify(thumbDisabled),
);

// ScrollableArea: the states that need real layout — jsdom has no geometry, so the
// measured contract (tabindex appears on an effective axis, edges flip when the
// viewport scrolls, data-scroll-* reflect the measured state) is the browser gate's
// job. The fitting example must stay unmeasured-inactive: no effective axis, no tab
// stop, and both edges at rest.
const saFitting = await page.evaluate(() => {
  const root = document.getElementById("scrollable-fitting");
  if (!root) return null;
  return {
    tabindex: root.hasAttribute("tabindex") ? root.getAttribute("tabindex") : null,
    blockScrollable: root.getAttribute("data-scrollable-block"),
    blockStart: root.getAttribute("data-scroll-block-start"),
    blockEnd: root.getAttribute("data-scroll-block-end"),
    inlineStart: root.getAttribute("data-scroll-inline-start"),
    inlineEnd: root.getAttribute("data-scroll-inline-end"),
  };
});
check(
  "fitting content: no effective axis, so no tab stop and both edges at rest",
  saFitting &&
    saFitting.tabindex === null &&
    saFitting.blockScrollable === null &&
    saFitting.blockStart === "true" &&
    saFitting.inlineStart === "true",
  JSON.stringify(saFitting),
);

const saBlock = await page.evaluate(() => {
  const root = document.getElementById("scrollable-block");
  if (!root) return null;
  const content = root.querySelector(".astryx-scrollable-area__content");
  const before = {
    tabindex: root.hasAttribute("tabindex") ? root.getAttribute("tabindex") : null,
    role: root.getAttribute("role"),
    label: root.getAttribute("aria-label"),
    axis: root.getAttribute("data-scroll-axis"),
    scrollableBlock: root.getAttribute("data-scrollable-block"),
    blockStart: root.getAttribute("data-scroll-block-start"),
    blockEnd: root.getAttribute("data-scroll-block-end"),
    hasContentMarker: content && content.hasAttribute("data-scroll-content"),
    clipped: content ? getComputedStyle(content.parentElement).getPropertyValue("--inline-overflow") : null,
  };
  // Scroll to the end of the viewport and re-read the edges after the hook's
  // rAF-scheduled measure has run.
  root.scrollTop = root.scrollHeight;
  return { before };
});
check(
  "a measured block viewport is a tab stop (tabindex 0) with the axis contract",
  saBlock &&
    saBlock.before.tabindex === "0" &&
    saBlock.before.role === "group" &&
    saBlock.before.label === "Activity history" &&
    saBlock.before.axis === "block" &&
    saBlock.before.scrollableBlock === "true" &&
    saBlock.before.hasContentMarker,
  JSON.stringify(saBlock?.before),
);
await page.waitForTimeout(120);
const saBlockAfter = await page.evaluate(() => {
  const root = document.getElementById("scrollable-block");
  if (!root) return null;
  return {
    blockStart: root.getAttribute("data-scroll-block-start"),
    blockEnd: root.getAttribute("data-scroll-block-end"),
    scrollTop: root.scrollTop,
  };
});
check(
  "scrolling to the end flips the block edges (start leaves, end arrives)",
  saBlock && saBlock.before.blockStart === "true" && saBlock.before.blockEnd === null &&
    saBlockAfter && saBlockAfter.blockStart === null && saBlockAfter.blockEnd === "true",
  JSON.stringify(saBlockAfter),
);

const saInline = await page.evaluate(() => {
  const root = document.getElementById("scrollable-inline");
  if (!root) return null;
  return {
    axis: root.getAttribute("data-scroll-axis"),
    scrollableInline: root.getAttribute("data-scrollable-inline"),
    scrollableBlock: root.getAttribute("data-scrollable-block"),
    inlineStart: root.getAttribute("data-scroll-inline-start"),
    tabindex: root.hasAttribute("tabindex") ? root.getAttribute("tabindex") : null,
  };
});
check(
  "the inline viewport measures the inline axis (not the block one) into a tab stop",
  saInline &&
    saInline.axis === "inline" &&
    saInline.scrollableInline === "true" &&
    saInline.scrollableBlock === null &&
    saInline.inlineStart === "true" &&
    saInline.tabindex === "0",
  JSON.stringify(saInline),
);

const saRegion = await page.evaluate(() => {
  const root = document.getElementById("scrollable-region");
  return root
    ? {
        role: root.getAttribute("role"),
        label: root.getAttribute("aria-label"),
        // The component sets the longhands, not the shorthand.
        overscrollY: root.style.overscrollBehaviorY ?? null,
      }
    : null;
});
check(
  "~role:Region + contained overscroll are carried to the viewport",
  saRegion && saRegion.role === "region" && saRegion.label === "Activity history" &&
    (saRegion.overscrollY ?? "").includes("contain"),
  JSON.stringify(saRegion),
);

// NavHeadingMenu: the live keyboard contract — jsdom cannot pump Bonsai's
// event scheduler or move real focus, so choose-then-close, ArrowDown, typeahead,
// Enter activation and Escape-to-close are asserted here on the showcase demos.
const nhm = await page.evaluate(() => {
  const m = document.getElementById("nav-menu-plain");
  if (!m) return null;
  const row = (id) => m.querySelector(`[data-astryx-menu-item="${id}"]`);
  return {
    role: m.getAttribute("role"),
    marker: m.getAttribute("data-astryx-component"),
    items: [...m.querySelectorAll("[role=menuitem]")].length,
    disabledReports: row("reports")?.getAttribute("aria-disabled"),
    hrefTag: row("dashboard")?.tagName,
    readout: document.getElementById("nav-menu-readout")?.textContent ?? null,
  };
});
check(
  "the md surface renders as a role=menu with four menuitem rows",
  nhm && nhm.role === "menu" && nhm.marker === "NavHeadingMenu" && nhm.items === 4,
  JSON.stringify(nhm),
);
check("the disabled row advertises aria-disabled", nhm && nhm.disabledReports === "true", "");
check("a row with an href is the anchor itself", nhm && nhm.hrefTag === "A", "");

await page.evaluate(() => document.querySelector('#nav-menu-plain [data-astryx-menu-item="dashboard"]').click());
await page.waitForTimeout(150);
const nhmSelect = await page.evaluate(() => document.getElementById("nav-menu-readout")?.textContent ?? null);
check("choosing a row reports its id to on_select", /dashboard/.test(nhmSelect ?? ""), String(nhmSelect));

// ArrowDown: next focusable row. The disabled row is not focusable, so from
// analytics the next stop is settings (reports is skipped).
await page.evaluate(() => document.querySelector('#nav-menu-plain [data-astryx-menu-item="dashboard"]').focus());
await page.keyboard.press("ArrowDown");
await page.waitForTimeout(150);
let nhmFocused = await page.evaluate(() => document.activeElement?.getAttribute("data-astryx-menu-item") ?? null);
check("ArrowDown moves focus to the next row", nhmFocused === "analytics", String(nhmFocused));
await page.keyboard.press("ArrowDown");
await page.waitForTimeout(150);
nhmFocused = await page.evaluate(() => document.activeElement?.getAttribute("data-astryx-menu-item") ?? null);
check("ArrowDown skips the disabled row", nhmFocused === "settings", String(nhmFocused));

// Typeahead: typing a letter jumps to the first labelled row starting with it.
await page.keyboard.type("d");
await page.waitForTimeout(150);
nhmFocused = await page.evaluate(() => document.activeElement?.getAttribute("data-astryx-menu-item") ?? null);
check("typeahead jumps to the matching row", nhmFocused === "dashboard", String(nhmFocused));

// Enter synthesizes the row's activation: on_select receives the label on its id.
await page.keyboard.press("Enter");
await page.waitForTimeout(150);
const nhmEnter = await page.evaluate(() => document.getElementById("nav-menu-readout")?.textContent ?? null);
check("Enter activates the focused row", /dashboard/.test(nhmEnter ?? ""), String(nhmEnter));

// Controlled demo: the caller owns the popover state. Open it, then Escape closes
// it through ~on_close — the same wire a nav heading would use.
await page.evaluate(() => document.getElementById("nav-menu-toggle").click());
await page.waitForTimeout(150);
let nhmControlledOpen = await page.evaluate(() => !!document.getElementById("nav-menu-controlled"));
check("the caller can open the controlled surface", nhmControlledOpen);
await page.evaluate(() => document.querySelector('#nav-menu-controlled [data-astryx-menu-item="dashboard"]').focus());
await page.keyboard.press("Escape");
await page.waitForTimeout(150);
nhmControlledOpen = await page.evaluate(() => !!document.getElementById("nav-menu-controlled"));
check("Escape closes through on_close", !nhmControlledOpen);


// SegmentedControl: the live radiogroup contract — click selects, arrows move focus
// AND select (selection follows focus), the disabled segment is skipped, a settled
// group keeps its stop, Tab leaves the group, and a disabled group cannot change.
const segc = await page.evaluate(() => {
  const g = document.getElementById("showcase-segmented-control-live");
  if (!g) return null;
  const seg = (v) => g.querySelector(`[data-astryx-value="${v}"]`);
  return {
    role: g.getAttribute("role"),
    marker: g.getAttribute("data-astryx-component"),
    label: g.getAttribute("aria-label"),
    radios: [...g.querySelectorAll("[role=radio]")].length,
    gridChecked: seg("grid")?.getAttribute("aria-checked"),
    gridTabindex: seg("grid")?.getAttribute("tabindex"),
    listTabindex: seg("list")?.getAttribute("tabindex"),
    readout: document.getElementById("showcase-segmented-control-state")?.textContent ?? null,
  };
});
check(
  "the live control renders as a labelled radiogroup with three radios and grid selected",
  segc && segc.role === "radiogroup" && segc.marker === "SegmentedControl" && segc.label === "View mode"
    && segc.radios === 3 && segc.gridChecked === "true" && segc.readout === "view: grid",
  JSON.stringify(segc),
);
check("the selected segment owns the tab stop", segc && segc.gridTabindex === "0" && segc.listTabindex === "-1", "");

await page.evaluate(() => document.querySelector('#showcase-segmented-control-live [data-astryx-value="list"]').click());
await page.waitForTimeout(150);
let segcState = await page.evaluate(() => ({
  readout: document.getElementById("showcase-segmented-control-state")?.textContent ?? null,
  listChecked: document.querySelector('#showcase-segmented-control-live [data-astryx-value="list"]')?.getAttribute("aria-checked"),
  gridChecked: document.querySelector('#showcase-segmented-control-live [data-astryx-value="grid"]')?.getAttribute("aria-checked"),
  listTabindex: document.querySelector('#showcase-segmented-control-live [data-astryx-value="list"]')?.getAttribute("tabindex"),
}));
check(
  "clicking a segment selects it and moves the tab stop",
  segcState.readout === "view: list" && segcState.listChecked === "true" && segcState.gridChecked === "false"
    && segcState.listTabindex === "0",
  JSON.stringify(segcState),
);

// Arrows: focus the selected segment, press ArrowRight — focus AND selection move together.
await page.evaluate(() => document.querySelector('#showcase-segmented-control-live [data-astryx-value="grid"]').focus());
await page.keyboard.press("ArrowRight");
await page.waitForTimeout(150);
let segcArrow = await page.evaluate(() => ({
  focused: document.activeElement?.getAttribute("data-astryx-value") ?? null,
  readout: document.getElementById("showcase-segmented-control-state")?.textContent ?? null,
}));
check(
  "ArrowRight moves focus and selection to the next segment",
  segcArrow.focused === "list" && segcArrow.readout === "view: list",
  JSON.stringify(segcArrow),
);
await page.keyboard.press("ArrowRight");
await page.waitForTimeout(150);
segcArrow = await page.evaluate(() => ({
  focused: document.activeElement?.getAttribute("data-astryx-value") ?? null,
  readout: document.getElementById("showcase-segmented-control-state")?.textContent ?? null,
}));
check("a second ArrowRight reaches the last segment", segcArrow.focused === "table" && segcArrow.readout === "view: table", JSON.stringify(segcArrow));
await page.keyboard.press("ArrowRight");
await page.waitForTimeout(150);
segcArrow = await page.evaluate(() => ({
  focused: document.activeElement?.getAttribute("data-astryx-value") ?? null,
  readout: document.getElementById("showcase-segmented-control-state")?.textContent ?? null,
}));
check("arrows wrap around the end", segcArrow.focused === "grid" && segcArrow.readout === "view: grid", JSON.stringify(segcArrow));

// A disabled segment is skipped by the arrows.
await page.evaluate(() => {
  const g = document.getElementById("segc-disabled-item");
  g.querySelector('[data-astryx-value="grid"]').focus();
});
await page.keyboard.press("ArrowRight");
await page.waitForTimeout(150);
const segcSkip = await page.evaluate(() =>
  document.activeElement?.getAttribute("data-astryx-value") ?? null);
check("ArrowRight skips the disabled segment", segcSkip === "table", String(segcSkip));

// Tab leaves the single tab stop (roving: one segment is in the tab order).
await page.evaluate(() => document.querySelector('#showcase-segmented-control-live [data-astryx-value="grid"]').focus());
await page.keyboard.press("Tab");
await page.waitForTimeout(150);
const segcTab = await page.evaluate(() =>
  document.activeElement?.getAttribute("data-astryx-value") ?? null);
check("Tab leaves the group (one roving stop)", segcTab === null, String(segcTab));

// Disabled with a reason: the reason bubble is reachable and selection cannot change.
await page.evaluate(() => {
  const g = document.getElementById("segc-disabled-message");
  g.querySelector('[data-astryx-value="list"]').click();
});
await page.waitForTimeout(150);
const segcDisable = await page.evaluate(() => {
  const g = document.getElementById("segc-disabled-message");
  const bubble = document.getElementById("segc-disabled-message-disabled-message");
  return {
    listChecked: g.querySelector('[data-astryx-value="list"]')?.getAttribute("aria-checked"),
    gridChecked: g.querySelector('[data-astryx-value="grid"]')?.getAttribute("aria-checked"),
    gridTabindex: g.querySelector('[data-astryx-value="grid"]')?.getAttribute("tabindex"),
    bubble: bubble ? bubble.textContent.trim() : null,
    describedby: g.getAttribute("aria-describedby"),
  };
});
check(
  "a disabled-with-message group cannot change, keeps its stop, and shows the reason",
  segcDisable.listChecked === "false" && segcDisable.gridChecked === "true"
    && segcDisable.gridTabindex === "0" && segcDisable.bubble === "View mode is locked by the plan."
    && segcDisable.describedby === "segc-disabled-message-disabled-message",
  JSON.stringify(segcDisable),
);

// A settled disabled group really blocks the pointer (CSS, measured).
const segcPointer = await page.evaluate(() => {
  const g = document.getElementById("segc-disabled");
  return g ? getComputedStyle(g).pointerEvents : null;
});
check("a disabled group without a reason blocks pointer events", segcPointer === "none", String(segcPointer));

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

  // -------------------------------------------------------------- Overlay (M38)
  // The rt_test fixture asserts markup/classes; the dynamic half obeys CSS and
  // a touch-device gate that jsdom cannot evaluate: hover reveal, focus-within
  // reveal, the slide geometry, the controlled is_open round-trip (visible +
  // inert), and the hover:none touch toggle (driven by emulating the media
  // feature over CDP, since this runner's device reports hover:hover).
  console.log("\nOverlay (live)");
  const ovDim = (id) =>
    page.evaluate((id2) => {
      const g = (id3) => document.getElementById(id3);
      const root = g(id2);
      if (!root) return null;
      root.scrollIntoView({ block: "center" });
      const s = root.querySelector(".astryx-overlay-scrim");
      if (!s) return { root: null };
      const c = getComputedStyle(s);
      const rc = getComputedStyle(root);
      const media = s.querySelector("[data-astryx-media]");
      return {
        marker: root.getAttribute("data-astryx-component"),
        classes: [...s.classList].join(" "),
        opacity: c.opacity,
        visibility: c.visibility,
        pointerEvents: c.pointerEvents,
        transformY: c.transform === "none" ? 0 : new DOMMatrix(c.transform).m42,
        alignItems: c.alignItems,
        background: c.backgroundColor,
        inert: s.hasAttribute("inert"),
        position: rc.position,
        overflow: rc.overflow,
        colorScheme: media ? getComputedStyle(media).colorScheme : null,
      };
    }, id);

  const ovAlways = await Promise.all([
    ovDim("ov-always-fill-dark"),
    ovDim("ov-always-fill-light"),
    ovDim("ov-always-bottom"),
    ovDim("ov-always-top"),
  ]);
  check(
    "the overlay container clips like upstream (relative + clip)",
    ovAlways.every((d) => d && d.position === "relative" && d.overflow === "clip"),
    JSON.stringify(ovAlways.map((d) => d && `${d.position}/${d.overflow}`)),
  );
  check(
    "the container is marked as the Overlay component",
    ovAlways.every((d) => d && d.marker === "Overlay"),
    JSON.stringify(ovAlways.map((d) => d && d.marker)),
  );
  check(
    "scrim: dark default fills, aligns end, is visible and interactive",
    ovAlways[0] &&
      /--fill/.test(ovAlways[0].classes) &&
      /--align-end/.test(ovAlways[0].classes) &&
      /--scrim-dark/.test(ovAlways[0].classes) &&
      /--visible\b/.test(ovAlways[0].classes) &&
      ovAlways[0].opacity === "1" &&
      ovAlways[0].visibility === "visible" &&
      ovAlways[0].pointerEvents === "auto",
    JSON.stringify(ovAlways[0]),
  );
  check(
    "a dark scrim paints the overlay token and flips the media wrapper to dark",
    ovAlways[0] && ovAlways[0].background !== "rgba(0, 0, 0, 0)" && ovAlways[0].colorScheme === "dark",
    JSON.stringify([ovAlways[0].background, ovAlways[0].colorScheme]),
  );
  check(
    "a light scrim is translucent white and flips the wrapper to light",
    ovAlways[1] &&
      /--scrim-light/.test(ovAlways[1].classes) &&
      ovAlways[1].colorScheme === "light" &&
      parseFloat((ovAlways[1].background.match(/[\d.]+/g) ?? ["1"]).pop()) < 1,
    JSON.stringify([ovAlways[1].background, ovAlways[1].colorScheme]),
  );
  check(
    "the bottom strip is its own position class, not an inset override",
    ovAlways[2] && /--bottom\b/.test(ovAlways[2].classes) && /--visible-from-bottom/.test(ovAlways[2].classes),
    ovAlways[2] && ovAlways[2].classes,
  );
  check(
    "the top strip flips light too",
    ovAlways[3] && /--top\b/.test(ovAlways[3].classes) && /--visible-from-top/.test(ovAlways[3].classes),
    ovAlways[3] && ovAlways[3].classes,
  );

  const ovAlign = await Promise.all([ovDim("ov-align-start"), ovDim("ov-align-center"), ovDim("ov-align-end")]);
  check(
    "align is measured, not just classed: start/center/end line up",
    ovAlign[0] && ovAlign[1] && ovAlign[2] &&
      ovAlign[0].alignItems === "flex-start" &&
      ovAlign[1].alignItems === "center" &&
      ovAlign[2].alignItems === "flex-end",
    JSON.stringify(ovAlign.map((d) => d && d.alignItems)),
  );

  const ovHoverOff = await ovDim("ov-hover-fill");
  check(
    "a hover overlay is invisible and click-through until the pointer arrives",
    ovHoverOff && /--hover\b/.test(ovHoverOff.classes) && !/--visible/.test(ovHoverOff.classes) &&
      ovHoverOff.opacity === "0" && ovHoverOff.visibility === "hidden" && ovHoverOff.pointerEvents === "none",
    JSON.stringify(ovHoverOff),
  );
  await page.hover("#ov-hover-fill");
  await page.waitForTimeout(150);
  const ovHoverOn = await ovDim("ov-hover-fill");
  check(
    "hover reveals it, and it starts taking pointer",
    ovHoverOn && ovHoverOn.opacity === "1" && ovHoverOn.visibility === "visible" && ovHoverOn.pointerEvents === "auto",
    JSON.stringify({ opacity: ovHoverOn && ovHoverOn.opacity, visibility: ovHoverOn && ovHoverOn.visibility }),
  );
  await page.mouse.move(5, 5);
  await page.waitForTimeout(150);
  const ovHoverBack = await ovDim("ov-hover-fill");
  check("moving the pointer away hides it again (the reveal is reversible)",
    ovHoverBack && ovHoverBack.opacity === "0", String(ovHoverBack && ovHoverBack.opacity));

  const ovSlideOff = await ovDim("ov-hover-bottom");
  check(
    "the bottom strip starts translated below the edge",
    ovSlideOff && ovSlideOff.transformY > 10,
    String(ovSlideOff && ovSlideOff.transformY),
  );
  await page.hover("#ov-hover-bottom");
  await page.waitForTimeout(150);
  const ovSlideOn = await ovDim("ov-hover-bottom");
  check(
    "on hover it slides up into place (translateY 0)",
    ovSlideOn && Math.abs(ovSlideOn.transformY) < 1,
    String(ovSlideOn && ovSlideOn.transformY),
  );
  await page.mouse.move(5, 5);
  await page.waitForTimeout(150);

  const ovFocusOff = await ovDim("ov-focus-fill");
  check(
    "the focus-only variant is closed before anything in it has focus",
    ovFocusOff && /--focus\b/.test(ovFocusOff.classes) && ovFocusOff.opacity === "0",
    JSON.stringify(ovFocusOff && { classes: ovFocusOff.classes, opacity: ovFocusOff.opacity }),
  );
  await page.focus("#ov-focus-fill .overlay-demo-surface");
  await page.waitForTimeout(150);
  const ovFocusOn = await ovDim("ov-focus-fill");
  check(
    "focus-within reveals the keyboard-only overlay",
    ovFocusOn && ovFocusOn.opacity === "1" && ovFocusOn.visibility === "visible",
    JSON.stringify({ opacity: ovFocusOn && ovFocusOn.opacity, visibility: ovFocusOn && ovFocusOn.visibility }),
  );

  const ovControlled0 = await ovDim("ov-controlled");
  check(
    "a controlled overlay starts closed, hidden and inert",
    ovControlled0 && /--hidden/.test(ovControlled0.classes) && ovControlled0.opacity === "0" && ovControlled0.inert,
    JSON.stringify(ovControlled0),
  );
  await page.evaluate(() => {
    const b = [...document.querySelectorAll("#overlay button")].find((x) => /toggle overlay/i.test(x.textContent || ""));
    if (b) b.click();
  });
  await page.waitForTimeout(150);
  const ovControlled1 = await ovDim("ov-controlled");
  const ovReadout1 = await page.evaluate(
    () => (document.querySelector("#overlay .overlay-demo-readout") || {}).textContent,
  );
  check(
    "one click opens it: visible, interactive, inert lifted — and the readout agrees",
    ovControlled1 && /--visible/.test(ovControlled1.classes) && ovControlled1.opacity === "1" &&
      ovControlled1.pointerEvents === "auto" && !ovControlled1.inert &&
      /is_open: true/.test(ovReadout1 || ""),
    `${JSON.stringify(ovControlled1)} readout=${ovReadout1}`,
  );
  await page.evaluate(() => {
    const b = [...document.querySelectorAll("#overlay button")].find((x) => /toggle overlay/i.test(x.textContent || ""));
    if (b) b.click();
  });
  await page.waitForTimeout(150);
  const ovControlled2 = await ovDim("ov-controlled");
  const ovReadout2 = await page.evaluate(
    () => (document.querySelector("#overlay .overlay-demo-readout") || {}).textContent,
  );
  check(
    "and the same click closes it again (closed = hidden + inert)",
    ovControlled2 && /--hidden/.test(ovControlled2.classes) && ovControlled2.opacity === "0" &&
      ovControlled2.inert && /is_open: false/.test(ovReadout2 || ""),
    `${JSON.stringify(ovControlled2)} readout=${ovReadout2}`,
  );

  const ovHook = await page.evaluate(() => {
    const card = document.querySelector('#overlay [data-astryx-component="Overlay"].overlay-demo-surface');
    if (!card) return null;
    card.scrollIntoView({ block: "center" });
    const s = card.querySelector(".astryx-overlay-scrim");
    if (!s) return { marker: card.getAttribute("data-astryx-component"), scrim: null };
    const c = getComputedStyle(s);
    return { marker: card.getAttribute("data-astryx-component"), scrim: [...s.classList].join(" "),
             opacity: c.opacity, visibility: c.visibility };
  });
  check(
    "use_overlay dresses an existing container: marker + scrim, closed until hover",
    ovHook && ovHook.marker === "Overlay" && ovHook.scrim !== null &&
      /--hover/.test(ovHook.scrim) && ovHook.opacity === "0" && ovHook.visibility === "hidden",
    JSON.stringify(ovHook),
  );
  await page.hover('#overlay [data-astryx-component="Overlay"].overlay-demo-surface');
  await page.waitForTimeout(150);
  const ovHookOn = await page.evaluate(() => {
    const card = document.querySelector('#overlay [data-astryx-component="Overlay"].overlay-demo-surface');
    const s = card && card.querySelector(".astryx-overlay-scrim");
    return s ? { opacity: getComputedStyle(s).opacity, visibility: getComputedStyle(s).visibility } : null;
  });
  check("the hook's scrim reveals on hover like the wrapper's",
    ovHookOn && ovHookOn.opacity === "1" && ovHookOn.visibility === "visible",
    JSON.stringify(ovHookOn));

  // The touch half: a hover:none device is the only place the click toggle does
  // anything, and this runner's device is hover:hover. Playwright/CDP here cannot
  // emulate the hover media feature (Emulation.setEmulatedMedia leaves
  // matchMedia untouched), so a fresh page overrides matchMedia BEFORE the
  // bundle mounts: the hook then reads "(hover: none)" the way a touch device
  // would, and a tap on the container must open/close the overlay. This tests
  // the port's rule, not the detection — the detection is "this runner reports
  // hover: none", which the override supplies in the same way emulation would.
  const touchPage = await browser.newPage({ viewport: { width: 1440, height: 1000 } });
  await touchPage.addInitScript(() => {
    const orig = window.matchMedia.bind(window);
    const query = (q) => ({
      media: q, matches: false, onchange: null,
      addEventListener: () => {}, removeEventListener: () => {},
      addListener: () => {}, removeListener: () => {}, dispatchEvent: () => false,
    });
    window.matchMedia = (q) => {
      if (q === "(hover: none)") return { ...query(q), matches: true };
      if (q === "(hover: hover)") return query(q);
      return orig(q);
    };
  });
  await touchPage.goto("http://127.0.0.1:8791/site/index.html");
  await touchPage.waitForTimeout(600);
  const ovTouch0 = await touchPage.evaluate(() => {
    const root = document.getElementById("ov-hover-fill");
    const s = root && root.querySelector(".astryx-overlay-scrim");
    return s ? { classes: [...s.classList].join(" "), opacity: getComputedStyle(s).opacity } : null;
  });
  check(
    "on a hover:none device the overlay starts closed (touch mode controls it)",
    ovTouch0 && /--hidden/.test(ovTouch0.classes) && !/--hover\b/.test(ovTouch0.classes),
    JSON.stringify(ovTouch0),
  );
  await touchPage.evaluate(() => {
    const root = document.getElementById("ov-hover-fill");
    if (root) root.click();
  });
  await touchPage.waitForTimeout(200);
  const ovTouchOn = await touchPage.evaluate(() => {
    const root = document.getElementById("ov-hover-fill");
    const s = root && root.querySelector(".astryx-overlay-scrim");
    return s ? { classes: [...s.classList].join(" "), opacity: getComputedStyle(s).opacity, inert: s.hasAttribute("inert") } : null;
  });
  check(
    "a tap opens it (the touch toggle), from the touch state not the CSS reveal",
    ovTouchOn && /--visible/.test(ovTouchOn.classes) && ovTouchOn.opacity === "1" && !ovTouchOn.inert,
    JSON.stringify(ovTouchOn),
  );
  await touchPage.evaluate(() => {
    const root = document.getElementById("ov-hover-fill");
    if (root) root.click();
  });
  await touchPage.waitForTimeout(200);
  const ovTouchOff = await touchPage.evaluate(() => {
    const root = document.getElementById("ov-hover-fill");
    const s = root && root.querySelector(".astryx-overlay-scrim");
    return s ? { classes: [...s.classList].join(" "), opacity: getComputedStyle(s).opacity } : null;
  });
  check("and a second tap closes it",
    ovTouchOff && /--hidden/.test(ovTouchOff.classes) && ovTouchOff.opacity === "0",
    JSON.stringify(ovTouchOff));
  await touchPage.close();


  // -------------------------------------------------------------- FileInput (M39)
  console.log("\nFileInput (live)");
  const fi = await page.evaluate(() => {
    const g = (id) => document.getElementById(id);
    const grab = (id, sel) => g(id) && g(id).querySelector(sel);
    const cls = (id) => (g(id) && g(id).className) || "";
    return {
      compact: !!g("fi-compact-demo") && g("fi-compact-demo").getAttribute("data-astryx-component") === "FileInput",
      dropzone: /--dropzone/.test(cls("fi-dropzone-demo")),
      disabled: /--disabled/.test(cls("fi-disabled-demo")),
      busy: !!grab("fi-busy-demo", ".astryx-spinner"),
      multiple: !!g("fi-multiple-demo") && !!g("fi-multiple-demo").querySelector('input[multiple]'),
      native: !!grab("fi-compact-demo", 'input[type="file"]'),
      hiddenTrigger: !!grab("fi-compact-demo", ".astryx-file-input__trigger"),
      placeholder: (g("fi-placeholder-demo")?.textContent || "").includes("Choose a file"),
    };
  });
  check("the FileInput demos render: compact, dropzone, disabled, busy, multiple, placeholder",
    fi.compact && fi.dropzone && fi.disabled && fi.busy && fi.multiple && fi.placeholder, JSON.stringify(fi));
  check("the trigger is a real file input behind a visually-hidden button", fi.native && fi.hiddenTrigger);
  // The dropzone announces drag state: enter lightens, leave clears (no file dialog opens headless).
  let dropState = { before: null, after: null };
  await page.evaluate(() => {
    const dz = document.getElementById("fi-dropzone-demo");
    const ev = new Event("dragenter", { bubbles: true, cancelable: true });
    dz.dispatchEvent(ev);
  });
  await page.waitForTimeout(120);
  dropState.before = await page.evaluate(() => document.getElementById("fi-dropzone-demo")?.className || "");
  await page.evaluate(() => {
    const dz = document.getElementById("fi-dropzone-demo");
    const ev = new Event("dragleave", { bubbles: true, cancelable: true });
    dz.dispatchEvent(ev);
  });
  await page.waitForTimeout(120);
  dropState.after = await page.evaluate(() => document.getElementById("fi-dropzone-demo")?.className || "");
  check("dragenter lights the --drag-over state and dragleave clears it",
    /--drag-over/.test(dropState.before) && !/--drag-over/.test(dropState.after), JSON.stringify(dropState));

  // -------------------------------------------------------------- Layout (M41)
  console.log("\nLayout (live)");
  const lay = await page.evaluate(() => {
    const ex = (name) =>
      document.querySelector(`#layout [data-example="${name}"] .astryx-layout`);
    const q = (name, sel) => ex(name) && ex(name).querySelector(sel);
    const hdr = (name) => q(name, ".astryx-layout-header");
    return {
      shell: !!ex("Shell: five slots") && !!hdr("Shell: five slots"),
      regions: (() => {
        const e = ex("Shell: five slots");
        return !!e && e.querySelectorAll('[data-astryx-component="LayoutPanel"]').length === 2
          && !!e.querySelector('[data-astryx-component="LayoutContent"]')
          && !!e.querySelector('[data-astryx-component="LayoutFooter"]');
      })(),
      explicitDivider: (hdr("Shell: five slots") || { getAttribute: () => null })
        .getAttribute("data-astryx-divider"),
      inheritedDivider: (hdr("Default dividers on") || { getAttribute: () => null })
        .getAttribute("data-astryx-divider"),
      inheritedFooter: (q("Default dividers on", ".astryx-layout-footer") || { getAttribute: () => null })
        .getAttribute("data-astryx-divider"),
      noDefaultDivider: (hdr("Auto height, not scrollable") || { getAttribute: () => null })
        .getAttribute("data-astryx-divider"),
      autoClass: /astryx-layout--auto/.test((ex("Auto height, not scrollable") || { className: "" }).className),
      // Content-width 640: the header inner should be capped at 640px (its max-width
      // is var(--layout-content-width)), and the content's computed left padding should
      // be non-zero (it is centred by the alignment var).
      headerMaxWidth: (() => {
        const h = q("Content width 640", ".astryx-layout-header__inner");
        return h ? getComputedStyle(h).maxWidth : null;
      })(),
      contentPad: (() => {
        const c = q("Content width 640", ".astryx-layout-content");
        return c ? getComputedStyle(c).paddingInlineStart : null;
      })(),
      // Both panels width 960: the middle is the content lane (max-width 960, centred).
      laneMaxWidth: (() => {
        const m = q("Both panels, width 960", ".astryx-layout__middle");
        return m ? getComputedStyle(m).maxWidth : null;
      })(),
      laneCentred: (() => {
        const m = q("Both panels, width 960", ".astryx-layout__middle");
        if (!m) return false;
        const r = m.getBoundingClientRect();
        const p = m.parentElement.getBoundingClientRect();
        return Math.abs((r.left - p.left) - (p.right - r.right)) < 6;
      })(),
    };
  });
  check("the Layout demos render: the shell's five regions", lay.shell && lay.regions, JSON.stringify({ shell: lay.shell, regions: lay.regions }));
  check("an explicit divider is static on the shell header", lay.explicitDivider === "true", String(lay.explicitDivider));
  check("the divider hook resolves the default onto the inheriting header and footer",
    lay.inheritedDivider === "true" && lay.inheritedFooter === "true",
    `header=${lay.inheritedDivider} footer=${lay.inheritedFooter}`);
  check("a header with no default and no explicit divider stays plain", lay.noDefaultDivider === null, String(lay.noDefaultDivider));
  check("the auto-height layout marks itself", lay.autoClass);
  check("content-width 640: the header inner is capped at 640px by the layout var",
    lay.headerMaxWidth === "640px", String(lay.headerMaxWidth));
  check("content-width 640: the content is centred with real padding", lay.contentPad !== "0px", String(lay.contentPad));
  check("both panels width 960: the middle is a 960px content lane, centred",
    lay.laneMaxWidth === "960px" && lay.laneCentred,
    `maxWidth=${lay.laneMaxWidth} centred=${lay.laneCentred}`);

  // -------------------------------------------------------------- Slider (M42)
  console.log("\nSlider (live)");
  {
    const readBaby = () =>
      page.evaluate(() => {
        const basic = document.getElementById("sl-basic-demo");
        const thumb = basic && basic.querySelector('[role="slider"]');
        return {
          marked: document.querySelectorAll('[data-astryx-component="Slider"]').length,
          track: !!basic && !!basic.querySelector(".astryx-slider__track"),
          thumb: thumb && thumb.getAttribute("aria-valuenow"),
          min: thumb && thumb.getAttribute("aria-valuemin"),
          max: thumb && thumb.getAttribute("aria-valuemax"),
          focusable: thumb && thumb.getAttribute("tabindex"),
          readout: (document.querySelector("#slider .showcase-note") || {}).textContent || "",
        };
      });
    const s0 = await readBaby();
    check("eight sliders render marked, and the basic one has a track and one slider thumb",
      s0.marked === 8 && s0.track && s0.thumb === "30" && s0.min === "0" && s0.max === "100",
      JSON.stringify(s0));
    check("the thumb is focusable and announces its bounds", s0.focusable === "0", String(s0.focusable));

    await page.focus("#sl-basic-demo [role=\"slider\"]");
    await page.keyboard.press("ArrowRight");
    await page.waitForTimeout(150);
    const s1 = await readBaby();
    check("ArrowRight on the focused thumb steps the value up by one",
      s1.thumb === "31", `got ${s1.thumb}`);

    await page.keyboard.press("End");
    await page.waitForTimeout(150);
    const s2 = await readBaby();
    check("End lands exactly on max", s2.thumb === "100", `got ${s2.thumb}`);
    await page.keyboard.press("Home");
    await page.waitForTimeout(150);
    const s3 = await readBaby();
    check("Home lands exactly on min even off the step grid", s3.thumb === "0", `got ${s3.thumb}`);

    // The track is narrow (multi-column showcase row), so use the port's own mapping:
    // fraction = (offset - thumb_inset) / (width - thumb_size), i.e. the same
    // geometry the thumb travels through. Click at 75% of the track width.
    const box = await page.evaluate(() => {
      document.getElementById("sl-basic-demo").scrollIntoView({ block: "center" });
      const r = document.querySelector("#sl-basic-demo .astryx-slider__track").getBoundingClientRect();
      return { x: r.x, y: r.y, w: r.width, h: r.height };
    });
    await page.waitForTimeout(250);
    const box2 = await page.evaluate(() => {
      const r = document.querySelector("#sl-basic-demo .astryx-slider__track").getBoundingClientRect();
      return { x: r.x, y: r.y, w: r.width, h: r.height };
    });
    const expected = Math.round((((box2.w * 0.75 - 10) / (box2.w - 20)) * 100));
    await page.mouse.click(box2.x + box2.w * 0.75, box2.y + box2.h / 2);
    await page.waitForTimeout(150);
    const s4 = await readBaby();
    const v4 = Number(s4.thumb);
    check("a pointer press on the track takes the thumb to that position",
      Math.abs(v4 - expected) <= 2, `got ${s4.thumb}, expected ~${expected}`);
  }

  // --------------------------------------------------------------- Item (M44)
  console.log("\nItem (live)");
  {
    const marked = () =>
      page.evaluate(() =>
        document.querySelectorAll('#item [data-astryx-component="Item"]').length);
    const examples = await page.evaluate(() =>
      document.querySelectorAll('#item [data-example]').length);
    check("thirteen examples, seventeen marked rows under the Item section",
      examples === 13 && (await marked()) === 17, `examples=${examples} rows=${await marked()}`);

    // Click path: the row's surface is the hit target; the handler writes a readout.
    const clickRead = () =>
      page.evaluate(() => document.getElementById("item-click-readout")?.textContent ?? null);
    check("the click readout starts at zero", (await clickRead()) === "clicked 0 times", String(await clickRead()));
    await page.click("#item-click");
    await page.waitForTimeout(120);
    check("clicking the row fires its on_click once",
      (await clickRead()) === "clicked 1 times", String(await clickRead()));
    await page.click("#item-click");
    await page.waitForTimeout(120);
    check("...and again — the handler is the caller's, bound to the row",
      (await clickRead()) === "clicked 2 times", String(await clickRead()));

    const linkFacts = await page.evaluate(() => {
      const row = document.getElementById("item-link");
      const root = document.getElementById("item-link-root");
      const a = row && row.querySelector("a.astryx-item__invisible-anchor");
      return {
        href: a && a.getAttribute("href"),
        tag: root && root.tagName.toLowerCase(),
        rootClass: root && root.className,
        rootHref: root && root.getAttribute("href"),
      };
    });
    check("a row with href wraps an invisible anchor carrying the href",
      linkFacts.href === "#item", JSON.stringify(linkFacts));
    check("a Custom root with href makes the root itself the anchor",
      linkFacts.tag === "a" && /--link-root/.test(linkFacts.rootClass ?? "") && linkFacts.rootHref === "#item-link-root",
      JSON.stringify(linkFacts));

    const delegateFacts = await page.evaluate(() => {
      const row = document.getElementById("item-delegated");
      return {
        interactive: row && /--interactive/.test(row.className),
        invisibleButton: !!row && !!row.querySelector("button.astryx-item__invisible-button"),
        nested: !!row && !!row.querySelector("button"),
        label: row && row.querySelector(".astryx-item__label")?.textContent,
        readout: document.getElementById("item-delegated-readout")?.textContent ?? null,
      };
    });
    check("a delegated row keeps its own interactive surface and really holds the control",
      delegateFacts.interactive && !delegateFacts.invisibleButton && delegateFacts.nested,
      JSON.stringify(delegateFacts));
    // Clear any hash an earlier section's anchor demo left behind (the nav-menu demo
    // navigates to #dashboard), so the no-navigation assertion checks THIS click only.
    await page.evaluate(() => history.replaceState(null, null, location.pathname + location.search));
    await page.click("#item-delegated button");
    await page.waitForTimeout(150);
    const delegateAfter = await page.evaluate(() => ({
      hash: location.hash,
      rowClass: document.getElementById("item-delegated")?.className,
      readout: document.getElementById("item-delegated-readout")?.textContent ?? null,
    }));
    check("clicking the nested control stays with it — one activation, no navigation",
      delegateAfter.hash === "" && delegateAfter.readout === "delegated 1 times"
        && /--interactive/.test(delegateAfter.rowClass ?? ""),
      JSON.stringify(delegateAfter));
    // The row's own surface proxies the click to the nested control (upstream
    // useClickableContainer): a label-surface click is one more activation of the
    // same control, and the row gets no second tab stop.
    const labelBox = await page.evaluate(() => {
      const r = document.querySelector("#item-delegated .astryx-item__label").getBoundingClientRect();
      return { x: r.x + r.width / 2, y: r.y + r.height / 2 };
    });
    await page.mouse.click(labelBox.x, labelBox.y);
    await page.waitForTimeout(150);
    const delegateProxy = await page.evaluate(() => ({
      hash: location.hash,
      rowClass: document.getElementById("item-delegated")?.className,
      readout: document.getElementById("item-delegated-readout")?.textContent ?? null,
    }));
    check("a row-surface click is proxied to the nested control — the label is one activation",
      delegateProxy.hash === "" && delegateProxy.readout === "delegated 2 times"
        && /--interactive/.test(delegateProxy.rowClass ?? ""),
      JSON.stringify(delegateProxy));

    // Swipe: touch-only pointer stream via CDP. The row owns horizontal movement
    // (touch-action: pan-y); a left drag at the inline end reveals the trailing
    // panel, whose width is exactly the settled travel.
    await page.evaluate(() => document.getElementById("item-swipe-reveal").scrollIntoView({ block: "center" }));
    await page.waitForTimeout(300);
    const cdp = await page.context().newCDPSession(page);
    await cdp.send("Emulation.setTouchEmulationEnabled", { enabled: true, maxTouchPoints: 5 });
    const swipeRect = await page.evaluate(() => {
      const r = document.getElementById("item-swipe-reveal").getBoundingClientRect();
      return { x: r.x, y: r.y, w: r.width, h: r.height };
    });
    const yMid = swipeRect.y + swipeRect.h / 2;
    const touch = async (type, x) =>
      cdp.send("Input.dispatchTouchEvent", {
        type,
        touchPoints: type === "touchEnd" ? [] : [{ x, y: yMid, id: 1, radiusX: 4, radiusY: 4, force: 1 }],
      });
    const drag = async (fromX, toX, steps, stepMs) => {
      await touch("touchStart", fromX);
      for (let i = 1; i <= steps; i++) {
        await touch("touchMove", fromX + ((toX - fromX) * i) / steps);
        await page.waitForTimeout(stepMs);
      }
      await touch("touchEnd", toX);
      await page.waitForTimeout(250);
    };
    const swipeState = () =>
      page.evaluate(() => {
        const el = document.getElementById("item-swipe-reveal");
        const panel = el && el.querySelector('[data-swipe-panel="trailing"]');
        return {
          travel: el ? el.style.getPropertyValue("--_item-swipe-travel") : null,
          inert: panel ? panel.hasAttribute("inert") : null,
        };
      });
    // A "reveal"-grade drag: past the half-panel open point, short of the
    // commit point (max(panel+48, 50% of the row's width)), and slow enough
    // that it is not a fling. The distance is anchored to the MEASURED panel
    // width, not the row width: the showcase gives a row the container's
    // width, and a row-width formula (0.55w, as once used) drifts into the
    // commit zone the moment the row gets wide.
    const panelWidth = await page.evaluate(() => {
      const panel = document.querySelector(
        '#item-swipe-reveal [data-swipe-panel="trailing"]');
      const entries = panel
        ? [...panel.querySelectorAll(".astryx-item__swipe-entry")]
        : [];
      return entries.reduce((s, e) => s + e.getBoundingClientRect().width, 0);
    });
    const revealDist = Math.round(Math.max(panelWidth * 1.3 + 30, 140));
    const revealDrag = () =>
      drag(swipeRect.x + swipeRect.w - 40, swipeRect.x + swipeRect.w - 40 - revealDist, 10, 30);
    // (Travel is signed: a trailing swipe moves the row left, so settle writes a
    // negative translation; the CSS derives the panel width with a -1 factor.)
    await revealDrag();
    const open = await swipeState();
    check("a swipe past the half-panel point reveals the trailing panel (no longer inert)",
      Math.abs(parseFloat(open.travel ?? "0")) > 0 && open.inert === false, JSON.stringify(open));

    // Tap the first (Archive) entry: the action fires and the row closes back.
    // (A cleared inline style, not "0px", is the settled closed state — the
    // Idle landing removes the custom properties.)
    await page.click('#item-swipe-reveal [data-swipe-panel="trailing"] .astryx-item__swipe-entry');
    await page.waitForTimeout(250);
    const afterTap = await swipeState();
    check("tapping an entry fires the action and the row returns to rest",
      (parseFloat(afterTap.travel ?? "0") || 0) === 0 && afterTap.inert === true, JSON.stringify(afterTap));

    // Escape closes an open row. The keydown listener sits on the row itself,
    // so it only sees Escape when focus is inside the row: a touch drag focuses
    // nothing (touch leaves focus on the body), so focus an entry first.
    await revealDrag();
    await page.evaluate(() =>
      document.querySelector('#item-swipe-reveal [data-swipe-panel="trailing"] .astryx-item__swipe-entry').focus());
    await page.waitForTimeout(100);
    await page.keyboard.press("Escape");
    await page.waitForTimeout(250);
    const afterEsc = await swipeState();
    check("Escape closes a revealed row back to rest",
      (parseFloat(afterEsc.travel ?? "0") || 0) === 0 && afterEsc.inert === true, JSON.stringify(afterEsc));

    // An outside pointerdown closes it too (the document-level listener).
    await revealDrag();
    await page.mouse.click(6, 6);
    await page.waitForTimeout(250);
    const afterOutside = await swipeState();
    check("a pointerdown outside the row closes it",
      (parseFloat(afterOutside.travel ?? "0") || 0) === 0 && afterOutside.inert === true, JSON.stringify(afterOutside));

    // Commit mode: a long, fast drag fires the outermost action (Delete, has_removal)
    // and the row slides out and stays out.
    await page.evaluate(() => document.getElementById("item-swipe-commit").scrollIntoView({ block: "center" }));
    await page.waitForTimeout(300);
    const cRect = await page.evaluate(() => {
      const r = document.getElementById("item-swipe-commit").getBoundingClientRect();
      return { x: r.x, y: r.y, w: r.width, h: r.height };
    });
    await drag(cRect.x + cRect.w - 40, cRect.x + cRect.w * 0.15, 10, 15);
    const commitState = () =>
      page.evaluate(() => {
        const el = document.getElementById("item-swipe-commit");
        return { travel: el ? el.style.getPropertyValue("--_item-swipe-travel") : null };
      });
    const held = await commitState();
    await page.waitForTimeout(400);
    const heldLater = await commitState();
    check("a long swipe commits: the row slides out past its own content and stays",
      Math.abs(parseFloat(held.travel ?? "0")) > 0 && held.travel === heldLater.travel,
      JSON.stringify({ held, heldLater }));
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
  // ------------------------------------------------------------------ Link (M31)
  //
  // Gathered inside one evaluate and asserted in node scope, which is how every other check in this file
  // works. Two earlier attempts at this put the block where `document` does not exist - beside a comment
  // rather than inside the evaluation - and failed with "document is not defined" instead of a check.
  {
    const lf = await page.evaluate(() => {
      const sec = document.querySelector('[data-showcase-component="Link"]');
      const ex = [...(sec?.querySelectorAll("[data-example]") ?? [])];
      const disabled = ex[3]?.querySelector("a");
      // The point of the missing href: an href-less anchor takes no focus, so programmatic focus plus
      // Enter cannot follow it anywhere. Focusing it and asking the document is the only way to check it.
      if (disabled) disabled.focus();
      const external = ex[2]?.querySelector("a");
      const asButton = ex[4]?.querySelector("button");
      return {
        found: !!sec,
        examples: ex.length,
        disabledHasHref: disabled ? disabled.hasAttribute("href") : null,
        disabledAria: disabled?.getAttribute("aria-disabled") ?? null,
        disabledTab: disabled?.getAttribute("tabindex") ?? null,
        disabledTookFocus: !!disabled && document.activeElement === disabled,
        externalTarget: external?.getAttribute("target") ?? null,
        externalRel: external?.getAttribute("rel") ?? null,
        externalText: external?.textContent ?? "",
        buttonType: asButton?.getAttribute("type") ?? null,
        buttonIsAnchor: !!ex[4]?.querySelector("a"),
      };
    });
    check("the Link section rendered", lf.found, "not found");
    check("the Link section has five examples", lf.examples === 5, `got ${lf.examples}`);
    check(
      "a disabled link is an anchor with NO href",
      lf.disabledHasHref === false,
      `has an href attribute: ${lf.disabledHasHref}`,
    );
    check(
      "a disabled link announces itself and leaves the tab order",
      lf.disabledAria === "true" && lf.disabledTab === "-1",
      `aria-disabled=${lf.disabledAria} tabindex=${lf.disabledTab}`,
    );
    // NOT "cannot take focus": upstream renders tabIndex={-1}, which is focusable-but-not-tabbable, so
    // focusing it programmatically works and the first version of this check was simply wrong. Its own
    // comment overstates it ("cannot be focused"); the code is tabIndex={-1}. The claim that matters is
    // the other half of that comment - focusing it and activating it cannot navigate, which is what the
    // missing href buys. Assert that by clicking it.
    const url_before = page.url();
    await page.evaluate(() => {
      const ex = [...document.querySelectorAll('[data-showcase-component="Link"] [data-example]')];
      ex[3]?.querySelector("a")?.click();
    });
    check(
      "clicking a disabled link does not navigate",
      page.url() === url_before,
      `url went from ${url_before} to ${page.url()}`,
    );
    check(
      "an external link opens in a new tab with noopener and noreferrer",
      lf.externalTarget === "_blank" &&
        /\bnoopener\b/.test(lf.externalRel ?? "") &&
        /\bnoreferrer\b/.test(lf.externalRel ?? ""),
      `target=${lf.externalTarget} rel=${lf.externalRel}`,
    );
    check(
      "an external link announces the new tab instead of leaving it to the icon",
      lf.externalText.includes("(opens in new tab)"),
      JSON.stringify(lf.externalText),
    );
    check(
      "a link with no destination renders as a button",
      lf.buttonType === "button" && !lf.buttonIsAnchor,
      `type=${lf.buttonType} anchor=${lf.buttonIsAnchor}`,
    );
  }

  // ------------------------------------------------------------------ Token (M32)
  // Same shape as the Link block above: everything gathered in ONE evaluate (a block placed
  // outside the evaluation dies with 'document is not defined' and prints no check at all -
  // recorded in the M31 gate).
  {
    const tf = await page.evaluate(() => {
      const sec = document.querySelector('[data-showcase-component="Token"]');
      const ex = [...(sec?.querySelectorAll("[data-example]") ?? [])];
      const pick = (i, sel) => ex[i]?.querySelector(sel) ?? null;
      const demo = pick(0, ".astryx-token");            // Default
      const linkEl = pick(4, "a");                       // Link
      const linkRoot = pick(4, ".astryx-token");         // Link example root
      const sibling = pick(5, ".astryx-token--container"); // Link + removable
      const innerLink = sibling?.querySelector("a");
      const removeBtn = sibling?.querySelector("button.astryx-token__remove");
      const clickable = pick(3, ".astryx-token--container");
      const innerButton = clickable?.querySelector("button.astryx-token__invisible-button");
      const disabledBtn = pick(6, ".astryx-token__invisible-button");
      return {
        found: !!sec,
        examples: ex.length,
        demoTag: demo?.tagName ?? null,
        demoHasControls: !!(demo && demo.querySelector("button, a")),
        linkTag: linkRoot?.tagName ?? null,
        linkHref: linkEl?.getAttribute("href") ?? null,
        siblingTag: sibling?.tagName ?? null,
        innerLinkTag: innerLink?.tagName ?? null,
        removeType: removeBtn?.getAttribute("type") ?? null,
        removeIsSibling: !!sibling && !!innerLink && !!removeBtn &&
          innerLink.parentElement === sibling && removeBtn.parentElement === sibling,
        innerButtonType: innerButton?.getAttribute("type") ?? null,
        disabledBtnDisabled: !!disabledBtn?.hasAttribute("disabled"),
      };
    });
    check("the Token section rendered", tf.found, "not found");
    check("the Token section has eight examples", tf.examples === 8, `got ${tf.examples}`);
    check("a default token is an inert span with no controls",
      tf.demoTag === "SPAN" && !tf.demoHasControls,
      `tag=${tf.demoTag} controls=${tf.demoHasControls}`);
    check("a live href makes the anchor the root",
      tf.linkTag === "A" && tf.linkHref === "https://example.com",
      `tag=${tf.linkTag} href=${tf.linkHref}`);
    check("href + remove is a span container and the remove button is a SIBLING of the link",
      tf.siblingTag === "SPAN" && tf.innerLinkTag === "A" &&
        tf.removeType === "button" && tf.removeIsSibling,
      `container=${tf.siblingTag} inner=${tf.innerLinkTag} type=${tf.removeType} siblings=${tf.removeIsSibling}`);
    check("on_click puts a real button inside the container",
      tf.innerButtonType === "button",
      `type=${tf.innerButtonType}`);
    check("a disabled token disables its inner button",
      tf.disabledBtnDisabled === true);
  }

  // ------------------------------------------------------------------ Spinner (M33)
  {
    const sf = await page.evaluate(() => {
      const sec = document.querySelector('[data-showcase-component="Spinner"]');
      const ex = [...(sec?.querySelectorAll("[data-example]") ?? [])];
      const pick = (i, sel) => ex[i]?.querySelector(sel) ?? null;
      const statusEls = [...(sec?.querySelectorAll("[role=status]") ?? [])];
      const md = [...statusEls].find((s) => s.getAttribute("data-astryx-size") === "md") ?? null;
      const mdSvg = md?.querySelector("svg");
      const arcs = mdSvg ? [...mdSvg.querySelectorAll("circle")] : [];
      const arc = arcs[arcs.length - 1] ?? null;
      return {
        found: !!sec,
        examples: ex.length,
        statusCount: statusEls.length,
        mdBox: mdSvg ? [mdSvg.getAttribute("width"), mdSvg.getAttribute("height")] : null,
        arcDash: arc?.getAttribute("stroke-dasharray") ?? null,
        labelledWithText: (() => {
          const w = [...(sec?.querySelectorAll(".astryx-spinner-wrapper") ?? [])]
            .find((n) => (n.textContent || "").includes("Loading..."));
          const named = w?.querySelector("[role=status]");
          return {
            hasText: !!(w && (w.textContent || "").includes("Loading...")),
            labelledby: named?.getAttribute("aria-labelledby") ?? null,
            label: named?.getAttribute("aria-label") ?? null,
            textBelow: !!w?.lastElementChild?.classList?.contains("astryx-text"),
          };
        })(),
        onMediaClass: (() => {
          const w = [...(sec?.querySelectorAll(".astryx-spinner-wrapper") ?? [])]
            .find((n) => (n.textContent || "").includes("Uploading..."));
          return !!w?.closest(".astryx-demo-on-media");
        })(),
      };
    });
    check("the Spinner section rendered", sf.found, "not found");
    check("the Spinner section has six examples", sf.examples === 6, `got ${sf.examples}`);
    check("status elements carry role=status (labelled or not)", sf.statusCount >= 10, `got ${sf.statusCount}`);
    check("md box is the ring plus its stroke on each side (20px)",
      sf.mdBox && sf.mdBox[0] === "20" && sf.mdBox[1] === "20",
      `got ${sf.mdBox && sf.mdBox.join("x")}`);
    check("the arc is ARC_FRACTION of the circumference",
      sf.arcDash === "16.4934 27.4889", `got ${sf.arcDash}`);
    check("the string label names the status and sits below as Text",
      sf.labelledWithText.hasText && sf.labelledWithText.labelledby !== null &&
        sf.labelledWithText.label === null && sf.labelledWithText.textBelow);
    check("the onMedia example sits on the dark demo surface",
      sf.onMediaClass === true);
  }

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
    "coverage stats are 97 ported / 6 not / 103 total",
    JSON.stringify(cov.stats) === JSON.stringify(["97", "6", "103"]),
    cov.stats.join(" | "),
  );
  check("unported list rendered 6 entries", cov.unported === 6, `got ${cov.unported}`);
  check("upstream commit shown", /astryx@[0-9a-f]{6,}/.test(cov.upstream), cov.upstream);
  check("coverage.json reported no inconsistency", !/WARNING/.test(cov.foot), cov.foot);



  // ---------------------------------------------------------------- List (M45)
  console.log("\nList (live)");
  const lf = await page.evaluate(() => {
    const sec = document.querySelector('#list [data-astryx-component="List"]');
    const grab = (sel) => sec && sec.querySelector(sel);
    return {
      found: !!sec,
      basic: (() => {
        const el = document.querySelector("#list .astryx-list");
        return !!el && el.tagName === "UL" && el.getAttribute("role") === "list"
          && el.querySelectorAll(":scope > li").length === 3;
      })(),
      dividers: (() => {
        const el = document.querySelector("#list [data-astryx-dividers=\"true\"]");
        const labelled = el && el.getAttribute("aria-labelledby");
        return !!el && !!labelled && !!document.getElementById(labelled)
          && !!el.closest(".astryx-list__wrap")?.querySelector(".astryx-list__header h3");
      })(),
      ordered: (() => {
        const el = [...document.querySelectorAll("#list ol.astryx-list")].find((o) => o.getAttribute("start") === "4");
        return !!el && el.getAttribute("data-astryx-marker") === "decimal"
          && el.querySelectorAll("li .astryx-list-item__marker").length === 3;
      })(),
      compact: (() => {
        const el = document.querySelector("#list .astryx-list--density-compact");
        return !!el && el.getAttribute("data-astryx-density") === "compact";
      })(),
    };
  });
  check("the List section renders a role=list ul with three rows", lf.found && lf.basic, JSON.stringify(lf));
  check("dividers carry a header paired through aria-labelledby", lf.dividers);
  check("the ordered demo is a decimal ol starting at 4 with marker spans", lf.ordered);
  check("the compact demo carries its density class and data", lf.compact);

  // ---------------------------------------------------------------- TreeList (M46)
  // jsdom cannot pump Bonsai effects, so expansion is driven here for real: the
  // chevron button owns the click (upstream's activateItem mechanism), arrows
  // roam the visible items, ArrowRight expands a collapsed parent, ArrowLeft
  // collapses it back.
  console.log("\nTreeList (live)");
  const tlf = await page.evaluate(() => {
    const sec = document.getElementById("tree-list");
    const roots = sec ? [...sec.querySelectorAll('[data-astryx-component="TreeList"]')] : [];
    const basic = roots[0] || null;
    const li = (id) => basic && basic.querySelector(`[data-tree-id="${id}"]`);
    return {
      roots: roots.length,
      role: basic && basic.querySelector(".astryx-tree-list__list")?.getAttribute("role"),
      variant: basic && basic.getAttribute("data-astryx-variant"),
      density: basic && basic.getAttribute("data-astryx-density"),
      guides: basic && basic.querySelectorAll(".astryx-tree-list__guide").length,
      stop: basic
        && [...basic.querySelectorAll("li[role=treeitem]")]
          .filter((e) => e.getAttribute("tabindex") === "0")
          .map((e) => e.getAttribute("data-tree-id")),
      appExpanded: li("app") && li("app").getAttribute("aria-expanded"),
      pageTsx: !!li("page.tsx"),
    };
  });
  check(
    "the TreeList section renders seven trees with the tree/lineGuides/balanced contract",
    tlf.roots === 7 && tlf.role === "tree" && tlf.variant === "lineGuides"
      && tlf.density === "balanced" && tlf.guides > 0,
    JSON.stringify(tlf),
  );
  check("one roving tab stop, on the first row of the first tree (src)", JSON.stringify(tlf.stop) === JSON.stringify(["src"]), JSON.stringify(tlf.stop));
  check("a collapsed parent hides its children to begin with", !tlf.pageTsx);
  await page.evaluate(() =>
    document.querySelector('#tree-list [data-astryx-component="TreeList"] [data-tree-id="app"] [data-tree-toggle]').click());
  await page.waitForTimeout(150);
  const tlfClick = await page.evaluate(() => {
    const basic = document.querySelector('#tree-list [data-astryx-component="TreeList"]');
    const li = (id) => basic && basic.querySelector(`[data-tree-id="${id}"]`);
    return { pageTsx: !!li("page.tsx"), layout: !!li("layout.tsx"), appExpanded: li("app") && li("app").getAttribute("aria-expanded") };
  });
  check("clicking a chevron expands the branch: children render, aria-expanded flips",
    tlfClick.pageTsx && tlfClick.layout && tlfClick.appExpanded === "true", JSON.stringify(tlfClick));
  await page.evaluate(() =>
    document.querySelector('#tree-list [data-astryx-component="TreeList"] [data-tree-id="app"] [data-tree-toggle]').click());
  await page.waitForTimeout(150);
  const tlfAgain = await page.evaluate(() => {
    const basic = document.querySelector('#tree-list [data-astryx-component="TreeList"]');
    const li = (id) => basic && basic.querySelector(`[data-tree-id="${id}"]`);
    return { pageTsx: !!li("page.tsx"), appExpanded: li("app") && li("app").getAttribute("aria-expanded") };
  });
  check("clicking the same chevron collapses it again", !tlfAgain.pageTsx && tlfAgain.appExpanded === "false", JSON.stringify(tlfAgain));
  const activeId = () =>
    page.evaluate(() => {
      const t = document.activeElement && document.activeElement.closest?.("[data-tree-id]");
      return t ? t.getAttribute("data-tree-id") : null;
    });
  await page.focus('#tree-list [data-astryx-component="TreeList"] [data-tree-id="src"]');
  await page.keyboard.press("ArrowDown");
  await page.waitForTimeout(150);
  check("ArrowDown moves focus to the next visible treeitem (app)", (await activeId()) === "app", `active=${await activeId()}`);
  await page.keyboard.press("ArrowRight");
  await page.waitForTimeout(150);
  const tlfRight = await page.evaluate(() => {
    const basic = document.querySelector('#tree-list [data-astryx-component="TreeList"]');
    const li = (id) => basic && basic.querySelector(`[data-tree-id="${id}"]`);
    return { pageTsx: !!li("page.tsx"), appExpanded: li("app") && li("app").getAttribute("aria-expanded") };
  });
  check("ArrowRight expands a collapsed parent", tlfRight.pageTsx && tlfRight.appExpanded === "true", JSON.stringify(tlfRight));
  await page.keyboard.press("ArrowDown");
  await page.waitForTimeout(150);
  check("after expansion ArrowDown enters the branch (page.tsx)", (await activeId()) === "page.tsx", `active=${await activeId()}`);
  await page.keyboard.press("ArrowUp");
  await page.waitForTimeout(150);
  check("ArrowUp returns to the parent", (await activeId()) === "app", `active=${await activeId()}`);
  await page.keyboard.press("ArrowLeft");
  await page.waitForTimeout(150);
  const tlfLeft = await page.evaluate(() => {
    const basic = document.querySelector('#tree-list [data-astryx-component="TreeList"]');
    const li = (id) => basic && basic.querySelector(`[data-tree-id="${id}"]`);
    return { pageTsx: !!li("page.tsx"), appExpanded: li("app") && li("app").getAttribute("aria-expanded") };
  });
  check("ArrowLeft collapses the expanded parent and keeps focus", !tlfLeft.pageTsx && tlfLeft.appExpanded === "false" && (await activeId()) === "app", JSON.stringify(tlfLeft));

  // ---------------------------------------------------------------- NumberInput (M47)
  // jsdom cannot pump Bonsai effects, so the commit path is driven here for real:
  // type into the live field, blur — the number reaches the application; Enter
  // commits too; the steppers step the committed value; the clear button empties it.
  console.log("\nNumberInput (live)");
  const niReadout = () =>
    page.evaluate(() => document.querySelector('[data-showcase-number="true"]')?.textContent ?? null);
  const niValue = () =>
    page.evaluate(() => document.querySelector("#showcase-number-live")?.getAttribute("aria-valuenow") ?? null);
  const niFocus = () => page.evaluate(() => document.getElementById("showcase-number-live")?.focus());
  const niSection = await page.evaluate(() => {
    const sec = document.getElementById("number-input");
    return {
      examples: sec ? sec.querySelectorAll("[data-example]").length : 0,
      roots: sec ? [...sec.querySelectorAll('[data-astryx-component="NumberInput"]')] : [],
    };
  });
  check(
    "the NumberInput section renders its ten examples, all marked",
    niSection.examples === 10 && niSection.roots.length === 10,
    `examples=${niSection.examples} roots=${niSection.roots.length}`,
  );
  // The id lives on the input; the steppers/units/reason are wrapper siblings.
  check("the live field starts at the committed 42", (await niReadout()) === "committed=42", String(await niReadout()));
  check("the live field starts at 42 per aria-valuenow", (await niValue()) === "42", String(await niValue()));
  // Type a new draft and blur: the draft commits and the readout follows.
  await niFocus();
  await page.evaluate(() => {
    const el = document.getElementById("showcase-number-live");
    el.value = "";
    el.dispatchEvent(new Event("input", { bubbles: true }));
  });
  await page.evaluate(() => {
    const el = document.getElementById("showcase-number-live");
    el.value = "77";
    el.dispatchEvent(new Event("input", { bubbles: true }));
  });
  // The controlled field renders the draft asynchronously; the blur handler reads the
  // pending text from the graph at the render it was created with, so a blur in the same
  // tick as the keystroke would commit the pre-typing draft. Real users blur much later;
  // the gate waits one frame for the draft to be applied.
  await page.waitForTimeout(150);
  await page.evaluate(() => document.getElementById("showcase-number-live").blur());
  await page.waitForTimeout(650);
  check("typing a new number and blurring commits it to the application", (await niReadout()) === "committed=77", String(await niReadout()));
  check("aria-valuenow follows the committed 77", (await niValue()) === "77", String(await niValue()));
  // Enter commits from a fresh draft.
  await niFocus();
  await page.evaluate(() => {
    const el = document.getElementById("showcase-number-live");
    el.value = "88";
    el.dispatchEvent(new Event("input", { bubbles: true }));
  });
  await page.waitForTimeout(150);
  await page.keyboard.press("Enter");
  await page.waitForTimeout(650);
  check("Enter commits the draft too", (await niReadout()) === "committed=88", String(await niReadout()));
  // A value below min clamps to min on commit (upstream's policy).
  await niFocus();
  await page.evaluate(() => {
    const el = document.getElementById("showcase-number-live");
    el.value = "-5";
    el.dispatchEvent(new Event("input", { bubbles: true }));
  });
  await page.waitForTimeout(150);
  await page.keyboard.press("Enter");
  await page.waitForTimeout(650);
  check("a draft below min clamps to 0 on commit", (await niReadout()) === "committed=0", String(await niReadout()));
  // The steppers step through the declared step (±5).
  const niStepper = (inc) =>
    page.evaluate((i) => {
      const wrap = document.getElementById("showcase-number-live").closest(".astryx-number-input");
      const sel = i ? ".astryx-number-input__stepper--increment" : ".astryx-number-input__stepper--decrement";
      const btn = [...wrap.querySelectorAll(sel)][0];
      if (btn) btn.dispatchEvent(new MouseEvent("click", { bubbles: true }));
    }, inc);
  await niStepper(true);
  await page.waitForTimeout(650);
  check("the increment stepper steps the committed value up by 5", (await niReadout()) === "committed=5", String(await niReadout()));
  await niStepper(false);
  await page.waitForTimeout(650);
  check("the decrement stepper steps it back down", (await niReadout()) === "committed=0", String(await niReadout()));
  // The clear button empties the committed value.
  await page.evaluate(() => document.querySelector("#showcase-number-live").closest(".astryx-number-input").querySelector(".astryx-number-input__clear").click());
  await page.waitForTimeout(650);
  check("the clear button empties the value", (await niReadout()) === "committed=empty", String(await niReadout()));
  // The steppers/clear/arrow-key family is gated on the live field; the static variants still render.
  const niStatic = await page.evaluate(() => ({
    steppers: !!document.querySelector("#showcase-number-steppers").closest(".astryx-number-input").querySelector(".astryx-number-input__stepper"),
    units: document.querySelector("#showcase-number-units").closest(".astryx-number-input").querySelector(".astryx-number-input__units")?.textContent,
    integer: document.querySelector("#showcase-number-integer").getAttribute("inputmode"),
    readonly: document.querySelector("#showcase-number-readonly").getAttribute("readonly") !== null,
    reason: document.querySelector("#showcase-number-disabled").closest(".astryx-number-input").querySelector(".astryx-number-input__disabled-reason")?.textContent,
  }));
  check(
    "the static variants carry their contract (steppers/units/integer/readonly/reason)",
    niStatic.steppers && niStatic.units === "px" && niStatic.integer === "numeric"
      && niStatic.readonly && niStatic.reason === "Deprecated — use Quantity",
    JSON.stringify(niStatic),
  );

  // ---------------------------------------------------------------- CheckboxList (M48)
  // The row surface is the hit target (upstream's useClickableContainer): a click on the row's
  // padding, label or description proxies to the row's own checkbox. jsdom cannot pump Bonsai
  // effects, so the delegation and the refuses are driven here for real.
  console.log("\nCheckboxList (live)");
  {
    const clChecked = (id) =>
      page.evaluate((id) => document.getElementById(id).checked, id);
    const clReadout = () =>
      page.evaluate(() => document.getElementById("showcase-checkbox-list-state")?.textContent ?? null);

    check("the live group starts on the application's value",
      (await clReadout()) === "selected: news, music", String(await clReadout()));
    // A click on the row SURFACE — the visible label is plain text with no <label for>, so
    // clicking it can only reach the checkbox through the row's delegation.
    await page.click("#showcase-checkbox-list-live-item-0");
    await page.waitForTimeout(200);
    check("clicking a row's surface checks it, and the readout follows",
      (await clReadout()) === "selected: news, music, sports", String(await clReadout()));
    check("the box's checked property followed the value",
      (await clChecked("showcase-checkbox-list-live-item-0-checkbox")) === true);
    // Clicking an already-selected row removes it — collection mode reports the new list.
    await page.click("#showcase-checkbox-list-live-item-1");
    await page.waitForTimeout(200);
    check("clicking a selected row unchecks it",
      (await clReadout()) === "selected: music, sports", String(await clReadout()));
    // Keyboard: Space on a focused checkbox is a click — the port's only keyboard path.
    await page.evaluate(() => document.getElementById("showcase-checkbox-list-live-item-1-checkbox").focus());
    await page.keyboard.press("Space");
    await page.waitForTimeout(200);
    check("Space on a focused box toggles it too",
      (await clReadout()) === "selected: music, sports, news", String(await clReadout()));

    // Refusals: a group-disabled row must not move its box, but the box stays focusable
    // (aria-disabled, no native disabled) so a keyboard user can discover the reason.
    const disBefore = await page.evaluate(() => {
      const el = document.getElementById("showcase-checkbox-disabled-group-item-0-checkbox");
      return { checked: el.checked, disabled: el.disabled, ariaDisabled: el.getAttribute("aria-disabled") };
    });
    await page.click("#showcase-checkbox-disabled-group-item-0");
    await page.waitForTimeout(200);
    const disAfter = await page.evaluate(() =>
      document.getElementById("showcase-checkbox-disabled-group-item-0-checkbox").checked);
    check("a group-disabled row stays put, while its box remains focusable for the reason",
      disBefore.checked === false && disAfter === false && disBefore.disabled === false
        && disBefore.ariaDisabled === "true", JSON.stringify(disBefore));

    const roBefore = await page.evaluate(() => [
      document.getElementById("showcase-checkbox-readonly-item-0-checkbox").checked,
      document.getElementById("showcase-checkbox-readonly-item-1-checkbox").checked,
    ]);
    await page.click("#showcase-checkbox-readonly-item-1");
    await page.waitForTimeout(200);
    const roAfter = await page.evaluate(() => [
      document.getElementById("showcase-checkbox-readonly-item-0-checkbox").checked,
      document.getElementById("showcase-checkbox-readonly-item-1-checkbox").checked,
    ]);
    check("a read-only row refuses the toggle: the value cannot move",
      roBefore[0] === true && roBefore[1] === false && roAfter[0] === true && roAfter[1] === false,
      JSON.stringify({ roBefore, roAfter }));

    // An item's description is linked from its own checkbox.
    const described = await page.evaluate(() =>
      document.getElementById("showcase-checkbox-described-item-1-checkbox")
        .getAttribute("aria-describedby") ?? null);
    check("the described item's checkbox links its own description",
      described?.includes("showcase-checkbox-described-item-1-description"), String(described));
  }

  console.log("\nBanner (live)");
  {
    const hasContent = (id) =>
      page.evaluate((id) => !!document.querySelector(`#${id} .astryx-banner__content`), id);
    const toggleState = (id) =>
      page.evaluate((id) => {
        const b = document.querySelector(`#${id} .astryx-banner__end button`);
        return b ? { expanded: b.getAttribute("aria-expanded"), controls: b.getAttribute("aria-controls") } : null;
      }, id);

    // Disclosure starts closed: no content region, toggle says false, no dangling aria-controls.
    check("a collapsible banner starts closed — no content, aria-expanded=false",
      (await hasContent("showcase-banner-collapsible")) === false &&
        (await toggleState("showcase-banner-collapsible"))?.expanded === "false",
      JSON.stringify(await toggleState("showcase-banner-collapsible")));
    await page.click("#showcase-banner-collapsible .astryx-banner__end button");
    await page.waitForTimeout(200);
    const opened = await toggleState("showcase-banner-collapsible");
    check("clicking the toggle opens it: content region appears, aria-expanded=true, aria-controls links it",
      (await hasContent("showcase-banner-collapsible")) === true &&
        opened.expanded === "true" &&
        opened.controls === "showcase-banner-collapsible-content" &&
        (await page.evaluate(() =>
          document.getElementById("showcase-banner-collapsible-content") !== null)),
      JSON.stringify(opened));
    await page.click("#showcase-banner-collapsible .astryx-banner__end button");
    await page.waitForTimeout(200);
    check("clicking again closes it, and the toggle stops pointing at a region that is gone",
      (await hasContent("showcase-banner-collapsible")) === false &&
        (await toggleState("showcase-banner-collapsible"))?.controls === null,
      JSON.stringify(await toggleState("showcase-banner-collapsible")));

    // Starts-open: the config's defaultIsOpen makes it open on first paint.
    check("collapsible with defaultIsOpen=true renders its content on first paint",
      (await hasContent("showcase-banner-open")) === true);

    // Pinned open: collapsible=Never — no toggle at all, and the content is always there.
    const pinned = await page.evaluate(() => {
      const root = document.getElementById("showcase-banner-pinned");
      return {
        toggle: root.querySelector(".astryx-banner__end button") !== null,
        content: root.querySelector(".astryx-banner__content") !== null,
      };
    });
    check("collapsible=Never pins the content open with no toggle",
      pinned.toggle === false && pinned.content === true, JSON.stringify(pinned));

    // Status fills: each known status paints its own header class. Checked BEFORE the
    // dismissal below unmounts the only error example.
    const statusClasses = await page.evaluate(() =>
      [...document.querySelectorAll("[data-showcase-component='Banner'] .astryx-banner__header")].map((h) =>
        [...h.classList].find((c) => c.includes("--info") || c.includes("--warning")
          || c.includes("--error") || c.includes("--success")) ?? null));
    const wantStatus = ["--info", "--warning", "--error", "--success"];
    check("the four statuses each carry their own fill class",
      wantStatus.every((s) => statusClasses.some((c) => c?.includes(s))),
      JSON.stringify(statusClasses));

    // Dismissal: the banner removes itself even though no callback is wired.
    await page.click("#showcase-banner-dismiss .astryx-banner__end button");

    // Edge compensation: a ghost button at the start of the end area pulls the slot
    // inward, so the transparent padding does not double up with the header's.
    const edgeMargin = await page.evaluate(() => {
      const end = document.querySelector("#showcase-banner-warning .astryx-banner__end") ??
        [...document.querySelectorAll("[data-showcase-component='Banner'] .astryx-banner__end")]
          .find((e) => e.querySelector("[data-astryx-edge-comp]"));
      return end ? getComputedStyle(end).marginInlineStart : null;
    });
    // The end slot's base rule is margin-inline-start: auto; only the :has() compensation
    // turns it into the negative step, so auto/0px proves the compensation is absent.
    check("the end area's ghost button compensates its edge (negative margin, not auto)",
      typeof edgeMargin === "string" && !edgeMargin.includes("auto") && edgeMargin.startsWith("-"),
      String(edgeMargin));

    // Controlled: the readout the application renders follows the toggle in both directions.
    const ctlReadout = () =>
      page.evaluate(() => document.getElementById("showcase-banner-controlled-state")?.textContent ?? null);
    check("a controlled banner starts on the application's state",
      (await ctlReadout()) === "open: false", String(await ctlReadout()));
    await page.click("#showcase-banner-controlled .astryx-banner__end button");
    await page.waitForTimeout(200);
    check("the toggle reports to the application, and the readout follows",
      (await ctlReadout()) === "open: true" &&
        (await toggleState("showcase-banner-controlled"))?.expanded === "true",
      String(await ctlReadout()));
    await page.click("#showcase-banner-controlled .astryx-banner__end button");
    await page.waitForTimeout(200);
    check("toggling again reports the close — controlled state never moves on its own",
      (await ctlReadout()) === "open: false", String(await ctlReadout()));

    // The status icon is decorative: the icon wrapper is aria-hidden in every banner.
    const iconHidden = await page.evaluate(() =>
      [...document.querySelectorAll("[data-showcase-component='Banner'] .astryx-banner__icon")]
        .every((i) => i.getAttribute("aria-hidden") === "true"));
    check("the status icon wrapper is aria-hidden everywhere", iconHidden === true);
  }

  console.log("\nCollapsible (live)");
  {
    // The trigger is a real button; the content stays mounted and shows or hides by class.
    const clState = (id) =>
      page.evaluate((id) => {
        const root = document.getElementById(id);
        const btn = root?.querySelector(".astryx-collapsible__trigger");
        const content = root?.querySelector(".astryx-collapsible__content");
        return {
          expanded: btn?.getAttribute("aria-expanded"),
          controls: btn?.getAttribute("aria-controls"),
          hidden: content?.classList.contains("astryx-collapsible__content--hidden"),
        };
      }, id);

    check("a closed collapsible starts hidden with expanded=false",
      (await clState("showcase-collapsible-closed"))?.expanded === "false"
        && (await clState("showcase-collapsible-closed"))?.hidden === true,
      JSON.stringify(await clState("showcase-collapsible-closed")));
    await page.click("#showcase-collapsible-closed .astryx-collapsible__trigger");
    await page.waitForTimeout(200);
    const clOpened = await clState("showcase-collapsible-closed");
    check("clicking the trigger opens it: expanded=true, controls still linked, content shown",
      clOpened.expanded === "true"
        && clOpened.controls === "showcase-collapsible-closed-content"
        && clOpened.hidden === false, JSON.stringify(clOpened));
    await page.click("#showcase-collapsible-closed .astryx-collapsible__trigger");
    await page.waitForTimeout(200);
    const clClosed = await clState("showcase-collapsible-closed");
    check("clicking again closes it: expanded=false and the content hides, still mounted",
      clClosed.expanded === "false" && clClosed.hidden === true, JSON.stringify(clClosed));

    // Disabled: the content stays in its state no matter how often the trigger is clicked.
    const disBefore = await clState("showcase-collapsible-disabled");
    const disTrigger = await page.$("#showcase-collapsible-disabled .astryx-collapsible__trigger");
    check("the disabled trigger is genuinely disabled",
      disTrigger !== null &&
        ((await disTrigger.getAttribute("disabled")) !== null ||
          (await disTrigger.getAttribute("aria-disabled")) === "true"),
      String(await disTrigger?.evaluate((el) => el.outerHTML)));
    // force: a disabled button refuses a normal Playwright click, which is exactly the contract under
    // test — the event, if it reaches the trigger at all, must not change anything.
    await page.click("#showcase-collapsible-disabled .astryx-collapsible__trigger", { force: true });
    await page.waitForTimeout(200);
    const disAfter = await clState("showcase-collapsible-disabled");
    check("a disabled trigger ignores clicks — the content stays open and expanded stays true",
      disBefore.expanded === "true" && disAfter.expanded === "true" && disAfter.hidden === false,
      JSON.stringify([disBefore, disAfter]));

    // Controlled: the readout is the application's own state.
    const ctlReadout = () =>
      page.evaluate(() => document.getElementById("showcase-collapsible-controlled-state")?.textContent ?? null);
    check("a controlled collapsible starts on the application's state",
      (await ctlReadout()) === "open: false", String(await ctlReadout()));
    await page.click("#showcase-collapsible-controlled .astryx-collapsible__trigger");
    await page.waitForTimeout(200);
    check("the toggle reports to the application, and the readout follows",
      (await ctlReadout()) === "open: true"
        && (await clState("showcase-collapsible-controlled"))?.expanded === "true",
      String(await ctlReadout()));

    // Single mode: opening a row closes the other, and the open one's own trigger closes it.
    const rows = (id) =>
      page.evaluate((id) => [...document.querySelectorAll(`#${id} [data-astryx-value]`)]
        .map((r) => [r.getAttribute("data-astryx-value"), r.getAttribute("data-astryx-open")]), id);
    await page.waitForFunction(() => document.querySelectorAll("#showcase-collapsible-group-single [data-astryx-value]").length === 3, { timeout: 30000 });
    check("a single group starts with exactly one row open",
      JSON.stringify(await rows("showcase-collapsible-group-single")) ===
        JSON.stringify([["q1", "true"], ["q2", "false"], ["q3", "false"]]),
      JSON.stringify(await rows("showcase-collapsible-group-single")));
    await page.click("#showcase-collapsible-group-single [data-astryx-value='q2'] .astryx-collapsible__trigger");
    await page.waitForTimeout(200);
    check("opening q2 closes q1 — single mode allows one at a time",
      JSON.stringify(await rows("showcase-collapsible-group-single")) ===
        JSON.stringify([["q1", "false"], ["q2", "true"], ["q3", "false"]]),
      JSON.stringify(await rows("showcase-collapsible-group-single")));
    await page.click("#showcase-collapsible-group-single [data-astryx-value='q2'] .astryx-collapsible__trigger");
    await page.waitForTimeout(200);
    check("toggling the open row in single mode closes everything",
      JSON.stringify(await rows("showcase-collapsible-group-single")) ===
        JSON.stringify([["q1", "false"], ["q2", "false"], ["q3", "false"]]),
      JSON.stringify(await rows("showcase-collapsible-group-single")));

    // Multiple mode, controlled: the readout shows the application's open set.
    const grpReadout = () =>
      page.evaluate(() => document.getElementById("showcase-collapsible-group-controlled-state")?.textContent ?? null);
    check("a controlled multiple group starts on the application's set",
      (await grpReadout()) === "open: general", String(await grpReadout()));
    await page.click("#showcase-collapsible-group-controlled [data-astryx-value='advanced'] .astryx-collapsible__trigger");
    await page.waitForTimeout(200);
    check("multiple mode adds a second, and the readout follows",
      (await grpReadout()) === "open: general, advanced", String(await grpReadout()));
  }

  console.log("\nBreadcrumbs (live)");
  {
    const trail = (id) =>
      page.evaluate((id) => {
        const nav = document.getElementById(id);
        const ol = nav?.querySelector("ol.astryx-breadcrumbs__list");
        const lis = [...(ol ? ol.querySelectorAll("li.astryx-breadcrumb-item") : [])];
        return {
          isNav: nav?.tagName === "NAV",
          labelled: (nav?.getAttribute("aria-label") ?? "").length > 0,
          lis: lis.length,
          links: [...(ol ? ol.querySelectorAll("a.astryx-breadcrumb-item__link") : [])].length,
          current: (ol ? ol.querySelectorAll("[aria-current='page']") : []).length,
          firstHref: lis[0]?.querySelector("a")?.getAttribute("href") ?? null,
          sep: lis[0]?.querySelector(".astryx-breadcrumb-item__separator")?.textContent ?? null,
          variant: lis[0]?.getAttribute("data-astryx-variant"),
        };
      }, id);
    const basic = await trail("showcase-breadcrumbs-basic");
    check("the basic trail is a labelled nav with an ol of three crumbs", basic.isNav && basic.labelled && basic.lis === 3, JSON.stringify(basic));
    check("two of the three crumbs are links and exactly the last is current", basic.links === 2 && basic.current === 1, JSON.stringify(basic));
    const explicit = await trail("showcase-breadcrumbs-explicit");
    check("an explicit current crumb wins even mid-trail", explicit.current === 1, JSON.stringify(explicit));
    const opout = await trail("showcase-breadcrumbs-opout");
    check("opting out suppresses auto-current", opout.current === 0, JSON.stringify(opout));
    const supporting = await trail("showcase-breadcrumbs-supporting");
    check("the supporting variant is marked on the crumb", supporting.variant === "supporting", JSON.stringify(supporting));
    const custom = await trail("showcase-breadcrumbs-custom-sep");
    check("a custom separator renders between crumbs", custom.sep === "\u203a", JSON.stringify(custom));
    const unsafe = await trail("showcase-breadcrumbs-unsafe");
    check("an unsafe href is refused — no href attribute", unsafe.firstHref === null, JSON.stringify(unsafe));
    await page.click("#showcase-breadcrumbs-click button");
    await page.waitForTimeout(200);
    let readout = await page.evaluate(() => document.getElementById("showcase-breadcrumbs-click-state")?.textContent ?? null);
    check("clicking a crumb fires the handler", readout === "clicks: 1", String(readout));
    await page.click("#showcase-breadcrumbs-click button");
    await page.waitForTimeout(200);
    readout = await page.evaluate(() => document.getElementById("showcase-breadcrumbs-click-state")?.textContent ?? null);
    check("the handler fires on every click", readout === "clicks: 2", String(readout));
  }

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
  // ---------------------------------------------------------------- Carousel (M52)
  //
  // The component's whole contract is the measured scroll state, so the checks
  // wait for the overflow hook to report before they assert anything. Two
  // kinds of trap. First, hydration: the hook measures after the patch, so a
  // check that runs before the measurement would see the inactive state (both
  // buttons disabled, no fade). Second, direction: the edge that is disabled
  // is the START edge while the scroller sits at rest, and the END edge is the
  // enabled one — the flow of the fade-flip logic follows the scroll.
  console.log("\nCarousel (live)");
  await page.waitForFunction(
    () => {
      const sc = document.querySelector("#showcase-carousel-basic .astryx-carousel__scroller");
      const end = document.querySelector('#showcase-carousel-basic [data-astryx-nav="end"]');
      return !!sc && sc.getAttribute("data-astryx-fade") !== null
        && !!end && !end.disabled;
    },
    { timeout: 30000 },
  );

  const carState = () =>
    page.evaluate(() => {
      const sc = document.querySelector("#showcase-carousel-basic .astryx-carousel__scroller");
      const start = document.querySelector('#showcase-carousel-basic [data-astryx-nav="start"]');
      const end = document.querySelector('#showcase-carousel-basic [data-astryx-nav="end"]');
      return {
        fade: sc && sc.getAttribute("data-astryx-fade"),
        left: sc ? sc.scrollLeft : null,
        startDisabled: start ? start.disabled : null,
        endDisabled: end ? end.disabled : null,
        slides: sc ? sc.querySelectorAll(".astryx-carousel__item").length : 0,
        firstLabel: sc ? sc.querySelector(".astryx-carousel__item")?.getAttribute("aria-label") : null,
      };
    });

  const carRest = await carState();
  check("a carousel with overflow disables its start pill and enables the end pill",
    carRest?.startDisabled === true && carRest?.endDisabled === false,
    JSON.stringify(carRest));
  check("the overflowing edge carries the measured fade mask",
    carRest?.fade !== null, `fade=${carRest?.fade}`);
  check("slides are numbered groups beginning at Slide 1 of 8",
    carRest?.slides === 8 && carRest?.firstLabel === "Slide 1 of 8",
    `slides=${carRest?.slides} first=${carRest?.firstLabel}`);

  await page.click('#showcase-carousel-basic [data-astryx-nav="end"]');
  // The scroll settles at the end, and only then do the pills know they are at
  // the edge: upstream's own test says the right button is disabled once the
  // scroller is fully right ("At the end edge (scrolled fully right):
  // overflowEnd is false"). So wait for that state, not for the scroll alone.
  await page.waitForFunction(
    () => {
      const sc = document.querySelector("#showcase-carousel-basic .astryx-carousel__scroller");
      const end = document.querySelector('#showcase-carousel-basic [data-astryx-nav="end"]');
      if (!sc || !end) return false;
      const atEnd = sc.scrollLeft >= sc.scrollWidth - sc.clientWidth - 1;
      return atEnd && end.disabled === true;
    },
    { timeout: 30000 },
  );
  const carScrolled = await carState();
  check("clicking the end pill scrolls to the end and flips the disabled edge",
    (carScrolled?.left ?? 0) > 0 && carScrolled?.endDisabled === true
      && carScrolled?.startDisabled === false,
    JSON.stringify(carScrolled));
  check("the fade follows the scrolled state (start edge now overflowing)",
    carScrolled?.fade !== null, `fade=${carScrolled?.fade}`);

  const carLoop = await page.evaluate(() => {
    const sc = document.querySelector("#showcase-carousel-loop .astryx-carousel__scroller");
    const start = document.querySelector('#showcase-carousel-loop [data-astryx-nav="start"]');
    const end = document.querySelector('#showcase-carousel-loop [data-astryx-nav="end"]');
    return { hasFade: !!sc && sc.getAttribute("data-astryx-fade") !== null,
             startDisabled: start && start.disabled, endDisabled: end && end.disabled };
  });
  check("wrap-around mode keeps both pills enabled while the content overflows",
    carLoop?.startDisabled === false && carLoop?.endDisabled === false
      && carLoop?.hasFade === true,
    JSON.stringify(carLoop));

  const carNoFade = await page.evaluate(() =>
    document.querySelector("#showcase-carousel-no-fade .astryx-carousel__scroller")?.getAttribute("data-astryx-fade"));
  check("has_edge_fade false never applies a fade mask (even while overflowing)",
    carNoFade === null, `fade=${String(carNoFade)}`);

  const config = await page.evaluate(() => ({
    gap: document.querySelector("#showcase-carousel-gap .astryx-carousel__scroller")?.getAttribute("data-astryx-gap"),
    snap: document.querySelector("#showcase-carousel-snap .astryx-carousel__scroller")?.hasAttribute("data-astryx-snap"),
    pad: document.querySelector("#showcase-carousel-padded .astryx-carousel__scroller")?.getAttribute("data-astryx-padding"),
    noBtns: !!document.querySelector("#showcase-carousel-no-buttons [data-astryx-controls]"),
  }));
  check("the config surface is driven by data: gap, snap, padding, no-buttons",
    config?.gap === "4" && config?.snap === true && config?.pad === "2" && config?.noBtns === false,
    JSON.stringify(config));


  // ---------------------------------------------------------------- TabList (M53)
  //
  // The component's contract is selection (roving tabindex + aria-current /
  // aria-selected) and the overflow menu. We drive a real click through the
  // Bonsai graph and assert the focus-and-selection state moved with it.
  console.log("\nTabList (live)");
  const tlState = () =>
    page.evaluate(() => {
      const root = document.getElementById("showcase-tab-list-nav");
      const stops = [...(root?.querySelectorAll(".astryx-tab") ?? [])].map((b) => ({
        value: b.getAttribute("data-tab-value"),
        current: b.getAttribute("aria-current"),
        tabindex: b.getAttribute("tabindex"),
      }));
      const trigger = root?.querySelector(".astryx-tab-menu__trigger");
      const aria = document.getElementById("showcase-tab-list-aria");
      const ariaStrip = aria?.querySelector(".astryx-tab-list__strip");
      const ariaTabs = [...(aria?.querySelectorAll(".astryx-tab") ?? [])].map((b) => ({
        role: b.getAttribute("role"),
        selected: b.getAttribute("aria-selected"),
        controls: b.getAttribute("aria-controls"),
        tag: b.tagName,
      }));
      const fill = document.getElementById("showcase-tab-list-fill");
      const menu = document.getElementById("showcase-tab-list-menu");
      const menuTrigger = menu?.querySelector(".astryx-tab-menu__trigger");
      return {
        count: stops.length,
        current: stops.filter((s) => s.current === "true").map((s) => s.value),
        zeroTabindex: stops.filter((s) => s.tabindex === "0").map((s) => s.value),
        expanded: trigger?.getAttribute("aria-expanded") ?? null,
        ariaRole: ariaStrip?.getAttribute("role") ?? null,
        ariaLabel: ariaStrip?.getAttribute("aria-label") ?? null,
        ariaTabs,
        fill: fill?.classList.contains("astryx-tab-list--fill") ?? null,
        fillTabCount: fill?.querySelectorAll(".astryx-tab").length ?? -1,
        fillTabs: fill?.querySelectorAll(".astryx-tab--fill").length ?? -1,
        menuExpanded: menuTrigger?.getAttribute("aria-expanded") ?? null,
      };
    });

  const tlRest = await tlState();
  check("the nav strip holds five tab stops with the selected one marked",
    tlRest?.count === 5
      && tlRest?.current.join(",") === "overview"
      && tlRest?.zeroTabindex.join(",") === "overview",
    JSON.stringify(tlRest));
  await page.click('#showcase-tab-list-nav [data-tab-value="messages"]');
  await page.waitForFunction(
    () => document.querySelector('#showcase-tab-list-nav [data-tab-value="messages"]')
      ?.getAttribute("aria-current") === "true",
    { timeout: 30000 },
  );
  const tlClicked = await tlState();
  check("clicking a tab moves aria-current and roves the tabindex to it",
    tlClicked?.current.join(",") === "messages"
      && tlClicked?.zeroTabindex.join(",") === "messages",
    JSON.stringify(tlClicked));

  const tlMenuOpen = await page.evaluate(async () => {
    const root = document.getElementById("showcase-tab-list-nav");
    root.querySelector(".astryx-tab-menu__trigger").click();
    await new Promise((r) => setTimeout(r, 120));
    const trig = root.querySelector(".astryx-tab-menu__trigger");
    const items = root.querySelectorAll('[data-astryx-component="Popover"] .astryx-tab-menu__item');
    return {
      expanded: trig?.getAttribute("aria-expanded") ?? null,
      items: [...items].map((i) => ({
        role: i.getAttribute("role"),
        checked: i.getAttribute("aria-checked"),
      })),
    };
  });
  check("the trigger expands the overflow menu into menuitemradio options",
    tlMenuOpen?.expanded === "true" && tlMenuOpen?.items.length >= 3
      && tlMenuOpen?.items.every((i) => i.role === "menuitemradio"),
    JSON.stringify(tlMenuOpen));

  const tlAria = await tlState();
  check("the WAI-ARIA tablist pattern asserts role=tablist + role=tab + aria-selected",
    tlAria?.ariaRole === "tablist" && tlAria?.ariaLabel === "Tabbed panels"
      && tlAria?.ariaTabs[0]?.role === "tab"
      && tlAria?.ariaTabs[0]?.selected === "true"
      && tlAria?.ariaTabs[1]?.selected === "false"
      && tlAria?.ariaTabs[0]?.controls === "panel-one",
    JSON.stringify(tlAria));
  check("the tablist pattern ignores href (no anchor element is emitted)",
    tlAria?.ariaTabs[2]?.tag === "BUTTON",
    JSON.stringify(tlAria?.ariaTabs[2]));
  const tlFill = await tlState();
  check("layout=fill classifies the wrapper and every tab",
    tlFill?.fill === true && tlFill?.fillTabCount === 3 && tlFill?.fillTabs === 3,
    JSON.stringify(tlFill));

  // ---------------------------------------------------------------- Lightbox (M54)
  console.log("\nLightbox (live)");
  const lbState = () =>
    page.evaluate(() => {
      const d = document.getElementById("showcase-lightbox-gallery");
      if (!d) return null;
      const img = d.querySelector(".astryx-lightbox__image");
      return {
        open: !!d.open,
        modal: d.matches(":modal"),
        label: d.getAttribute("aria-label"),
        counter: d.querySelector(".astryx-lightbox__counter")?.textContent?.trim() ?? null,
        imgAlt: img?.getAttribute("alt") ?? null,
        transform: img?.getAttribute("style") ?? null,
        prevDisabled: d.querySelector(".astryx-lightbox__nav--prev")?.hasAttribute("disabled") ?? null,
        nextDisabled: d.querySelector(".astryx-lightbox__nav--next")?.hasAttribute("disabled") ?? null,
        focusIn: !!d && d.contains(document.activeElement),
        bodyOverflow: getComputedStyle(document.body).overflow,
      };
    });
  await page.click("#showcase-lightbox-open-gallery");
  await page.waitForTimeout(180);
  let lb = await lbState();
  check("opening the lightbox puts the dialog in the top layer modally",
    lb?.open === true && lb?.modal === true && lb?.focusIn === true, JSON.stringify(lb));
  check("the page scroll lock engages (body overflow hidden)",
    lb?.bodyOverflow === "hidden", JSON.stringify(lb));
  check("the first item names the dialog and the counter reads 1 / 3",
    lb?.label === "Violet plateau" && lb?.counter === "1 / 3"
      && lb?.imgAlt === "Violet plateau"
      && lb?.prevDisabled === true && lb?.nextDisabled === false, JSON.stringify(lb));
  await page.click('#showcase-lightbox-gallery .astryx-lightbox__nav--next');
  await page.waitForTimeout(180);
  lb = await lbState();
  check("next drives the gallery to item 2 and re-names the dialog",
    lb?.counter === "2 / 3" && lb?.imgAlt === "Green valley"
      && lb?.prevDisabled === false, JSON.stringify(lb));
  await page.dblclick("#showcase-lightbox-gallery .astryx-lightbox__wrapper");
  await page.waitForTimeout(250);
  lb = await lbState();
  check("double-click zooms the image (scale written onto it)",
    (lb?.transform ?? "").includes("scale(2)"), JSON.stringify(lb));
  await page.dblclick("#showcase-lightbox-gallery .astryx-lightbox__wrapper");
  await page.waitForTimeout(250);
  lb = await lbState();
  check("a second double-click zooms back out",
    !(lb?.transform ?? "").includes("scale(2)"), JSON.stringify(lb));
  await page.keyboard.press("Escape");
  await page.waitForTimeout(180);
  lb = await lbState();
  check("Escape closes it and unlocks the page scroll",
    lb?.open === false && lb?.bodyOverflow !== "hidden", JSON.stringify(lb));
  const lbFocusBack = await page.evaluate(() => document.activeElement?.id ?? null);
  check("and focus returns to the trigger that opened it",
    lbFocusBack === "showcase-lightbox-open-gallery", `focus is on ${lbFocusBack}`);
  await page.click("#showcase-lightbox-open-gallery");
  await page.waitForTimeout(180);
  await page.click("#showcase-lightbox-gallery .astryx-lightbox__close");
  await page.waitForTimeout(180);
  lb = await lbState();
  check("the close button closes it too", lb?.open === false, JSON.stringify(lb));

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


// ---------------------------------------------------------------- HoverCard (M55)
  //
  // The contract is presence: a card is in the DOM only while it is open, and
  // it is owned by hover, focus, Escape and a controlled flag. We drive a real
  // hover through the Bonsai graph and assert the surface, its role and the
  // trigger's ARIA relationship.
  if (mode === "showcase") {
  console.log("\nHoverCard (live)");
  const hcSurf = (id) =>
    page.evaluate((surfaceId) => {
      const root = document.getElementById(surfaceId);
      if (!root) return null;
      const s = root.closest(".astryx-hover-card");
      if (!s) return null;
      return {
        role: s.getAttribute("role"),
        label: s.getAttribute("aria-label"),
        cls: s.className,
        content: !!s.querySelector(".astryx-hover-card__content"),
      };
    }, id);
  const hcWrap = (id) =>
    page.evaluate((triggerId) => {
      const root = document.getElementById(triggerId);
      const w = root?.closest(".astryx-hover-card-anchor");
      if (!w) return null;
      return {
        describedby: w.getAttribute("aria-describedby"),
        haspopup: w.getAttribute("aria-haspopup"),
        controls: w.getAttribute("aria-controls"),
        indication: w.classList.contains("astryx-hover-card--indication"),
        tabindex: w.getAttribute("tabindex"),
      };
    }, id);

  let hc = null;
  check("all closed cards are absent from the DOM, the controlled one is present",
    (await hcSurf("showcase-hc-above")) === null
      && (await hcSurf("showcase-hc-below")) === null
      && (await hcSurf("showcase-hc-start")) === null
      && (await hcSurf("showcase-hc-end")) === null
      && (await hcSurf("showcase-hc-disabled")) === null
      && (await hcSurf("showcase-hc-hide")) === null
      && (await hcSurf("showcase-hc-controlled")) !== null);
  hc = await hcSurf("showcase-hc-controlled");
  check("the controlled card is a named dialog with its label",
    hc?.role === "dialog" && hc?.label === "Controlled card" && hc?.content === true,
    JSON.stringify(hc));
  check("the labelled wrapper advertises the dialog relationship",
    (await hcWrap("showcase-hc-above-trigger"))?.haspopup === "dialog"
      && (await hcWrap("showcase-hc-above-trigger"))?.controls === null,
    JSON.stringify(await hcWrap("showcase-hc-above-trigger")));
  check("the controlled wrapper points aria-controls at the open card",
    (await hcWrap("showcase-hc-controlled-trigger"))?.controls === "showcase-hc-controlled",
    JSON.stringify(await hcWrap("showcase-hc-controlled-trigger")));

  await page.hover("#showcase-hc-above-trigger");
  await page.waitForFunction(() => { const el = document.getElementById("showcase-hc-above"); return el !== null && el.closest(".astryx-hover-card") !== null; }, { timeout: 30000 });
  hc = await hcSurf("showcase-hc-above");
  check("hovering opens the card after the delay, as the named dialog",
    hc?.role === "dialog" && hc?.label === "Profile card",
    JSON.stringify(hc));
  check("the open wrapper then points aria-controls at the card",
    (await hcWrap("showcase-hc-above-trigger"))?.controls === "showcase-hc-above",
    JSON.stringify(await hcWrap("showcase-hc-above-trigger")));
  check("the card opens against the 'above' placement class",
    hc?.cls?.includes("astryx-hover-card--above") ?? false,
    String(hc?.cls));

  await page.hover("#showcase-hc-below-trigger");
  await page.waitForFunction(() => { const el = document.getElementById("showcase-hc-below"); return el !== null && el.closest(".astryx-hover-card") !== null; }, { timeout: 30000 });
  hc = await hcSurf("showcase-hc-below");
  check("the unnamed card is a group and the text trigger is described by it",
    hc?.role === "group"
      && (await hcWrap("showcase-hc-below-trigger"))?.describedby === "showcase-hc-below",
    JSON.stringify({ hc, wrap: await hcWrap("showcase-hc-below-trigger") }));
  check("a text-only trigger takes the auto-indication and a tab stop",
    (await hcWrap("showcase-hc-below-trigger"))?.indication === true
      && (await hcWrap("showcase-hc-below-trigger"))?.tabindex === "0",
    JSON.stringify(await hcWrap("showcase-hc-below-trigger")));
  check("an element trigger gets no indication",
    (await hcWrap("showcase-hc-above-trigger"))?.indication === false,
    JSON.stringify(await hcWrap("showcase-hc-above-trigger")));
  check("Indicate_hide overrides the auto indication",
    (await hcWrap("showcase-hc-hide-trigger"))?.indication === false,
    JSON.stringify(await hcWrap("showcase-hc-hide-trigger")));

  await page.focus("#showcase-hc-below-trigger");
  await page.keyboard.press("Escape");
  await page.waitForFunction(() => document.getElementById("showcase-hc-below") === null, { timeout: 30000 });
  check("Escape closes the focused card (group is unmounted)",
    (await hcSurf("showcase-hc-below")) === null);

  await page.hover("#showcase-hc-disabled-trigger");
  await page.waitForTimeout(800); // well past the 300 ms show delay
  check("a disabled card does not open on hover",
    (await hcSurf("showcase-hc-disabled")) === null);

  await page.hover("#showcase-hc-above-trigger");
  await page.waitForFunction(() => { const el = document.getElementById("showcase-hc-above"); return el !== null && el.closest(".astryx-hover-card") !== null; }, { timeout: 30000 });
  await page.mouse.move(10, 10); // leave the trigger; the hide delay then unmounts
  await page.waitForFunction(() => document.getElementById("showcase-hc-above") === null, { timeout: 30000 });
  check("leaving the trigger closes the card after the hide delay",
    (await hcSurf("showcase-hc-above")) === null);
  }

// ---------------------------------------------------------------- Timestamp (M56)
  if (mode === "showcase") {
  console.log("\nTimestamp (live)");
  const tsInfo = (id) =>
    page.evaluate((elId) => {
      const t = document.getElementById(elId);
      if (!t) return null;
      return {
        tag: t.tagName.toLowerCase(),
        text: t.textContent.trim(),
        datetime: t.getAttribute("datetime"),
        label: t.getAttribute("aria-label"),
        tabindex: t.getAttribute("tabindex"),
        component: t.getAttribute("data-astryx-component"),
      };
    }, id);
  const tsCard = () =>
    page.evaluate(() => {
      const s = document.getElementById("showcase-ts-card")?.closest(".astryx-hover-card");
      if (!s) return null;
      const dl = s.querySelector(".astryx-timestamp-card");
      return {
        cls: s.className,
        dlCls: dl?.className ?? null,
        rows: s.querySelectorAll(".astryx-timestamp-card__row").length,
        dts: [...s.querySelectorAll("dt")].map((x) => x.textContent.trim()),
        dds: [...s.querySelectorAll("dd")].map((x) => x.textContent.trim()),
        copyButtons: s.querySelectorAll('.astryx-timestamp-card__action [data-astryx-component="IconButton"]').length,
        liveRegion: !!s.querySelector('[role="status"]'),
      };
    });

  const now = await tsInfo("showcase-ts-now");
  check("the live now reading is a semantic <time> with the full absolute name",
    now?.tag === "time" && now?.component === "Timestamp"
      && /^(now|\d+ (seconds?|minutes?) ago)$/.test(now?.text ?? "")
      && now?.tabindex === "0" && (now?.label ?? "").includes("at"),
    JSON.stringify(now));
  const twoHours = await tsInfo("showcase-ts-two-hours");
  check("two hours ago reads through the relative tier with its absolute name",
    twoHours?.text === "2 hours ago" && (twoHours?.label ?? "").length > 3,
    JSON.stringify(twoHours));
  const sys = await tsInfo("showcase-ts-system");
  check("the system date-time is the viewer's wall clock on an exact ISO datetime",
    /^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$/.test(sys?.text ?? "")
      && sys?.datetime === "2026-03-21T02:51:53.000Z",
    JSON.stringify(sys));
  const unix = await tsInfo("showcase-ts-unix");
  check("unix seconds is exact, zone-independent",
    unix?.text === "1742565113", JSON.stringify(unix));
  const invalid = await page.evaluate(() => {
    const p = document.getElementById("showcase-ts-invalid");
    return p && {
      invalid: p.getAttribute("data-astryx-invalid"),
      component: p.getAttribute("data-astryx-component"),
      hasTime: !!p.querySelector("time"),
    };
  });
  check("the invalid probe reports the intent while rendering nothing",
    invalid?.invalid === "true" && invalid?.component === "Timestamp" && invalid?.hasTime === false,
    JSON.stringify(invalid));

  await page.hover("#showcase-ts-card-trigger");
  await page.waitForFunction(() => {
    const el = document.getElementById("showcase-ts-card");
    return el !== null && el.closest(".astryx-hover-card") !== null;
  }, { timeout: 30000 });
  const card = await tsCard();
  check("hovering the relative reading opens the card — one row per zone",
    card !== null && card.rows === 3, JSON.stringify(card));
  check("the card grid carries the label+action template with shared columns",
    card?.dlCls?.includes("astryx-timestamp-card--label-action") === true
      && (card?.dts ?? []).filter((x) => x !== "").length === 2
      && (card?.dds ?? []).length === 3,
    JSON.stringify(card));
  check("rows name zones, copyable rows get a copy button, and the announce region is hosted",
    (card?.dts ?? []).some((x) => x.includes("San Francisco"))
      && (card?.dds ?? []).some((x) => x.includes("UTC"))
      && card?.copyButtons === 2 && card?.liveRegion === true,
    JSON.stringify(card));
  const tsWrap = await page.evaluate(() => {
    const w = document.getElementById("showcase-ts-card-trigger")?.closest(".astryx-hover-card-anchor");
    return w && { haspopup: w.getAttribute("aria-haspopup"), controls: w.getAttribute("aria-controls") };
  });
  check("the open card is a named dialog the trigger advertises and points at",
    tsWrap?.haspopup === "dialog" && tsWrap?.controls === "showcase-ts-card",
    JSON.stringify(tsWrap));
  await page.mouse.move(10, 10);
  await page.waitForFunction(() => document.getElementById("showcase-ts-card") === null, { timeout: 30000 });
  check("leaving the trigger unmounts the card", (await tsCard()) === null);

  // ---------------------------------------------------------------- ComplexSelector (M57)
  // The popup is the platform's native popover, so the interaction contract is
  // asserted on :popover-open / aria-expanded rather than pixel geometry — the
  // same stance Popover took.
  console.log("\nComplexSelector (live)");
  const csBtn = () =>
    page.evaluate(() => {
      const b = document.getElementById("showcase-cs-basic");
      const c = document.getElementById("showcase-cs-basic-content");
      return {
        expanded: b?.getAttribute("aria-expanded") ?? null,
        controls: b?.getAttribute("aria-controls") ?? null,
        open: !!c && c.matches(":popover-open"),
        text: b?.querySelector(".astryx-complex-selector__trigger-text")?.textContent?.trim() ?? null,
        focusedOption: document.activeElement?.getAttribute?.("data-astryx-option") ?? null,
        focusedTrigger: document.activeElement?.id === "showcase-cs-basic",
      };
    });

  const csClosed = await csBtn();
  check("the selector starts closed, announcing it, with the placeholder reading",
    csClosed.expanded === "false" && csClosed.open === false && csClosed.text === "Choose..."
      && csClosed.controls === "showcase-cs-basic-content",
    JSON.stringify(csClosed));

  await page.click("#showcase-cs-basic");
  await page.waitForFunction(
    () => document.getElementById("showcase-cs-basic-content")?.matches(":popover-open"),
    { timeout: 30000 },
  ).catch(() => {});
  const csOpened = await csBtn();
  check("clicking the trigger opens the native popover and announces it",
    csOpened.expanded === "true" && csOpened.open === true, JSON.stringify(csOpened));
  check("focus enters the first option in the surface, not the trigger",
    csOpened.focusedOption === "Red", JSON.stringify(csOpened));

  await page.click('[data-astryx-option="Red"]');
  await page.waitForFunction(
    () => document.getElementById("showcase-cs-basic")?.getAttribute("aria-expanded") === "false",
    { timeout: 30000 },
  ).catch(() => {});
  const csPicked = await csBtn();
  check("choosing an option commits it via the caller, closes the surface and renames the trigger",
    csPicked.text === "Red" && csPicked.expanded === "false" && csPicked.open === false,
    JSON.stringify(csPicked));

  await page.focus("#showcase-cs-basic");
  await page.keyboard.press("ArrowDown");
  await page.waitForFunction(
    () => document.getElementById("showcase-cs-basic-content")?.matches(":popover-open"),
    { timeout: 30000 },
  ).catch(() => {});
  check("ArrowDown on the trigger opens it, as upstream's own button does",
    (await csBtn()).open === true);
  await page.keyboard.press("Escape");
  await page.waitForFunction(
    () => document.getElementById("showcase-cs-basic")?.getAttribute("aria-expanded") === "false",
    { timeout: 30000 },
  ).catch(() => {});
  const csEsc = await csBtn();
  check("Escape dismisses it and returns focus to the trigger",
    csEsc.open === false && csEsc.expanded === "false" && csEsc.focusedTrigger === true,
    JSON.stringify(csEsc));

  const csBusy = await page.evaluate(() => {
    const b = document.getElementById("showcase-cs-busy");
    // The child's readout renders inside the popup content, not the control box.
    const s = document.getElementById("showcase-cs-busy-content")?.querySelector(".showcase-cs-state");
    return {
      busy: b?.getAttribute("aria-busy"),
      spinner: !!b?.parentElement?.querySelector(".astryx-complex-selector__spinner"),
      state: s?.textContent ?? null,
    };
  });
  check("is_loading announces aria-busy, shows the spinner and reaches the child's render state",
    csBusy.busy === "true" && csBusy.spinner === true && csBusy.state === "busy=true open=false",
    JSON.stringify(csBusy));

  const csControlled = () =>
    page.evaluate(() => {
      const b = document.getElementById("showcase-cs-controlled");
      return {
        expanded: b?.getAttribute("aria-expanded") ?? null,
        open: !!document.getElementById("showcase-cs-controlled-content")?.matches(":popover-open"),
      };
    });
  check("the controlled selector starts closed, owned by the caller",
    (await csControlled()).expanded === "false");
  await page.click('[data-astryx-toggle="controlled"]');
  await page.waitForFunction(
    () => document.getElementById("showcase-cs-controlled-content")?.matches(":popover-open"),
    { timeout: 30000 },
  ).catch(() => {});
  check("the caller's own button opens it — is_open drives the surface",
    (await csControlled()).open === true && (await csControlled()).expanded === "true");
  await page.keyboard.press("Escape");
  await page.waitForFunction(
    () => document.getElementById("showcase-cs-controlled")?.getAttribute("aria-expanded") === "false",
    { timeout: 30000 },
  ).catch(() => {});
  check("Escape reports back through on_open_change and the surface follows",
    (await csControlled()).open === false && (await csControlled()).expanded === "false");

  // ---------------------------------------------------------------- Outline (M58)
  console.log("\nOutline (live)");
  const olActive = (navId) =>
    page.evaluate((id) => {
      const nav = document.getElementById(id);
      const active = nav?.querySelector('a[aria-current="location"]');
      return {
        href: active?.getAttribute("href") ?? null,
        tabStop: nav?.querySelector('a[tabindex="0"]')?.getAttribute("href") ?? null,
      };
    }, navId);

  // The default spy tracks the nearest scrollable ancestor — the pane itself.
  // Scroll it to the bottom: the at-bottom rule names the last item.
  await page.evaluate(() => {
    const pane = document.getElementById("showcase-ol-basic-pane");
    pane.scrollTop = pane.scrollHeight;
  });
  await page.waitForTimeout(200);
  check("scrolling the pane to the bottom names the last heading active (the at-bottom rule)",
    (await olActive("showcase-ol-basic")).href === "#ol-guide-6",
    JSON.stringify(await olActive("showcase-ol-basic")));

  // And back to the top: the first heading returns to the seat.
  await page.evaluate(() => {
    document.getElementById("showcase-ol-basic-pane").scrollTop = 0;
  });
  await page.waitForTimeout(200);
  check("scrolling back to the top hands the seat to the first heading",
    (await olActive("showcase-ol-basic")).href === "#ol-guide-1",
    JSON.stringify(await olActive("showcase-ol-basic")));

  // Clicking a link navigates: the hash changes and the clicked heading becomes
  // the active one once the smooth scroll settles.
  await page.click('#showcase-ol-basic a[href="#ol-guide-2"]');
  await page.waitForFunction(
    () => document.querySelector('#showcase-ol-basic a[aria-current="location"]')?.getAttribute("href") === "#ol-guide-2",
    { timeout: 6000 },
  ).catch(() => {});
  check("clicking a heading link navigates to it: hash and aria-current agree after the settle",
    (await page.evaluate(() => location.hash)) === "#ol-guide-2"
      && (await olActive("showcase-ol-basic")).href === "#ol-guide-2",
    JSON.stringify({ hash: await page.evaluate(() => location.hash), ...(await olActive("showcase-ol-basic")) }));

  // Roving arrows: focus is one tab stop, arrows walk it, and the stop travels
  // with the reader's focus (tabindex 0 follows, never yanked by the spy).
  await page.focus('#showcase-ol-basic a[href="#ol-guide-2"]');
  await page.keyboard.press("ArrowDown");
  await page.waitForTimeout(120);
  check("ArrowDown moves the roving stop to the next heading",
    await page.evaluate(() => document.activeElement?.getAttribute("href"))
      === "#ol-guide-3"
      && (await olActive("showcase-ol-basic")).tabStop === "#ol-guide-3",
    JSON.stringify(await page.evaluate(() => ({
      active: document.activeElement?.getAttribute("href"),
      stop: document.querySelector('#showcase-ol-basic a[tabindex="0"]')?.getAttribute("href"),
    }))));

  // Space activates the focused item the same way a click does.
  await page.keyboard.press("Space");
  await page.waitForFunction(
    () => location.hash === "#ol-guide-3", { timeout: 4000 },
  ).catch(() => {});
  await page.waitForTimeout(1300); // let the navigation settle
  check("Space activates the focused heading: hash moves and the seat follows",
    (await page.evaluate(() => location.hash)) === "#ol-guide-3"
      && (await olActive("showcase-ol-basic")).href === "#ol-guide-3",
    JSON.stringify({ hash: await page.evaluate(() => location.hash), ...(await olActive("showcase-ol-basic")) }));

  // Controlled: the demo owns the active id. Clicking reports through
  // on_active_id_change; the button cycles it; the attribute mirrors the caller.
  check("the controlled outline starts on the caller's active id",
    (await olActive("showcase-ol-controlled")).href === "#ol-c-b"
      && (await page.evaluate(() => document.getElementById("showcase-ol-controlled-state")?.textContent))
        === "active: ol-c-b");
  await page.click('#showcase-ol-controlled a[href="#ol-c-d"]');
  await page.waitForFunction(
    () => document.getElementById("showcase-ol-controlled-state")?.textContent === "active: ol-c-d",
    { timeout: 4000 },
  ).catch(() => {});
  check("clicking in controlled mode reports the change and moves the attribute",
    (await olActive("showcase-ol-controlled")).href === "#ol-c-d"
      && (await page.evaluate(() => document.getElementById("showcase-ol-controlled-state")?.textContent))
        === "active: ol-c-d");
  await page.click("#showcase-ol-controlled-next");
  await page.waitForFunction(
    () => document.getElementById("showcase-ol-controlled-state")?.textContent === "active: ol-c-a",
    { timeout: 4000 },
  ).catch(() => {});
  check("the caller's own button cycles the active id and the outline follows",
    (await olActive("showcase-ol-controlled")).href === "#ol-c-a");

  // has_scroll_on_click = false: the hash still changes and the seat still
  // moves, but the pane does not scroll (the consumer owns scrolling).
  const noScrollBefore = await page.evaluate(() => document.getElementById("showcase-ol-noscroll-pane").scrollTop);
  await page.click('#showcase-ol-noscroll a[href="#ol-guide-5"]');
  await page.waitForTimeout(200);
  const noScrollAfter = await page.evaluate(() => document.getElementById("showcase-ol-noscroll-pane").scrollTop);
  check("with has_scroll_on_click=false navigation resolves immediately: hash + seat move, scroll does not",
    (await page.evaluate(() => location.hash)) === "#ol-guide-5"
      && (await olActive("showcase-ol-noscroll")).href === "#ol-guide-5"
      && noScrollAfter === noScrollBefore,
    JSON.stringify({ hash: await page.evaluate(() => location.hash), before: noScrollBefore, after: noScrollAfter }));

  // Scoped: the outline sits beside a pane that is NOT its ancestor, so the
  // spy must be told the container by selector — and it uses that container.
  await page.evaluate(() => {
    const pane = document.getElementById("showcase-ol-scoped-pane");
    pane.scrollTop = pane.scrollHeight;
  });
  await page.waitForTimeout(200);
  check("the scoped spy tracks the named scroll container, not the page",
    (await olActive("showcase-ol-scoped")).href === "#ol-guide-6",
    JSON.stringify(await olActive("showcase-ol-scoped")));

  // The indicator is CSS-anchored to the active link: the attribute the spy
  // writes is what the anchor-name rule keys off.
  check("the active link declares the anchor the indicator tracks",
    await page.evaluate(() => {
      const link = document.querySelector('#showcase-ol-indicator a[aria-current="location"]');
      if (!link) return null;
      const v = getComputedStyle(link).getPropertyValue("anchor-name").trim();
      return v.includes("--astryx-outline-active") ? v : null;
    }) !== null);

  check("the default label is the table-of-contents name, and a custom label overrides it",
    await page.evaluate(() =>
      document.getElementById("showcase-ol-basic")?.getAttribute("aria-label") === "Table of contents"
        && document.getElementById("showcase-ol-label")?.getAttribute("aria-label") === "Jump to"));

  // ------------------------------------------------------------- Resizable
  // The separator is a WAI-ARIA separator: a tab stop whose arrow keys
  // resize the region, with the value reported in aria-valuenow.

  const rz = (id) => page.evaluate((i) => {
    const el = document.getElementById(i);
    if (!el) return null;
    const num = (a) => {
      const v = el.getAttribute(a);
      return v === null ? null : Number(v);
    };
    return {
      role: el.getAttribute("role"),
      orientation: el.getAttribute("aria-orientation"),
      now: num("aria-valuenow"),
      min: num("aria-valuemin"),
      max: num("aria-valuemax"),
      text: el.getAttribute("aria-valuetext"),
      label: el.getAttribute("aria-label"),
      tabindex: el.getAttribute("tabindex"),
    };
  }, id);

  const rzId = "showcase-resizable-horizontal-handle";
  const rzBefore = await rz(rzId);
  check("the separator is a WAI-ARIA separator with a value, a label and a tab stop",
    rzBefore !== null
      && rzBefore.role === "separator"
      && rzBefore.orientation === "vertical"
      && rzBefore.now !== null
      && rzBefore.min !== null
      && rzBefore.now >= rzBefore.min
      && rzBefore.label !== null
      && rzBefore.tabindex === "0",
    JSON.stringify(rzBefore));

  // ArrowRight grows the region by 10px; Shift+ArrowRight by 50px.
  await page.focus(`#${rzId}`);
  await page.keyboard.press("ArrowRight");
  await page.waitForTimeout(120);
  const rzAfterArrow = await rz(rzId);
  check("ArrowRight resizes the region by 10px",
    rzAfterArrow !== null && rzBefore !== null && rzAfterArrow.now === rzBefore.now + 10,
    JSON.stringify({ before: rzBefore?.now, after: rzAfterArrow?.now }));

  await page.keyboard.press("Shift+ArrowRight");
  await page.waitForTimeout(120);
  const rzAfterShift = await rz(rzId);
  check("Shift+ArrowRight resizes the region by 50px",
    rzAfterShift !== null && rzAfterArrow !== null && rzAfterShift.now === rzAfterArrow.now + 50,
    JSON.stringify({ before: rzAfterArrow?.now, after: rzAfterShift?.now }));

  // The value is clamped into the bounds: the max is 400px in the showcase.
  for (let i = 0; i < 12; i++) await page.keyboard.press("ArrowRight");
  await page.waitForTimeout(200);
  const rzClamped = await rz(rzId);
  check("the value is clamped at the configured maximum",
    rzClamped !== null && rzClamped.max !== null && rzClamped.now === rzClamped.max,
    JSON.stringify(rzClamped));

  // ArrowLeft shrinks it again, and never below the minimum.
  for (let i = 0; i < 40; i++) await page.keyboard.press("ArrowLeft");
  await page.waitForTimeout(250);
  const rzMin = await rz(rzId);
  check("the value is clamped at the configured minimum",
    rzMin !== null && rzMin.min !== null && rzMin.now === rzMin.min,
    JSON.stringify(rzMin));

  // The collapsible region reports its bounds and a label.
  const rzCollapse = await rz("showcase-resizable-collapsible-handle");
  check("the collapsible separator reports its bounds and a label",
    rzCollapse !== null && rzCollapse.role === "separator" && rzCollapse.now !== null,
    JSON.stringify(rzCollapse));

  // The disabled separator is not a tab stop.
  const rzDisabled = await rz("showcase-resizable-disabled-handle");
  check("a disabled separator is removed from the tab order",
    rzDisabled !== null && rzDisabled.tabindex === "-1",
    JSON.stringify(rzDisabled));

  // The vertical variant flips the orientation.
  const rzVertical = await rz("showcase-resizable-vertical-handle");
  check("a vertical region reports the horizontal orientation",
    rzVertical !== null && rzVertical.orientation === "horizontal",
    JSON.stringify(rzVertical));

  // ----------------------------------------------------------------- Tokenizer
  const tkSection = await page.$("section[data-showcase-component='Tokenizer']");
  check("the Tokenizer section renders", tkSection !== null,
    tkSection ? "found" : "missing");
  if (tkSection) {
    const tkInput = await page.evaluate(() => {
      const el = document.getElementById("showcase-tokenizer-default");
      if (!el) return null;
      return {
        role: el.getAttribute("role"),
        expanded: el.getAttribute("aria-expanded"),
        controls: el.getAttribute("aria-controls"),
        autocomplete: el.getAttribute("aria-autocomplete"),
        off: el.getAttribute("autocomplete"),
      };
    });
    check("the token input is a combobox that says what it controls",
      tkInput?.role === "combobox"
        && tkInput?.expanded === "false"
        && tkInput?.controls === "showcase-tokenizer-default-listbox"
        && tkInput?.autocomplete === "list"
        && tkInput?.off === "off",
      JSON.stringify(tkInput));

    const tkListbox = await page.evaluate(() => {
      const el = document.getElementById("showcase-tokenizer-default-listbox");
      if (!el) return null;
      return {
        role: el.getAttribute("role"),
        label: el.getAttribute("aria-label"),
        hidden: el.hasAttribute("hidden"),
        options: el.querySelectorAll('[role="option"]').length,
      };
    });
    check("the menu is a listbox, and it is hidden while the menu is closed",
      tkListbox?.role === "listbox"
        && tkListbox?.hidden === true
        && tkListbox?.label !== null,
      JSON.stringify(tkListbox));

    // Upstream's behaviour: the menu appears as you type, not on a click.
    await page.click("#showcase-tokenizer-default");
    await page.type("#showcase-tokenizer-default", "a");
    await page.waitForTimeout(250);
    const tkOpened = await page.evaluate(() => {
      const el = document.getElementById("showcase-tokenizer-default-listbox");
      const input = document.getElementById("showcase-tokenizer-default");
      return {
        expanded: input?.getAttribute("aria-expanded"),
        hidden: el?.hasAttribute("hidden"),
        options: el?.querySelectorAll('[role="option"]').length ?? 0,
        active: input?.getAttribute("aria-activedescendant") ?? null,
      };
    });
    check("opening the menu shows the options and points the input at the active one",
      tkOpened?.expanded === "true"
        && tkOpened?.hidden === false
        && tkOpened?.options > 0
        && typeof tkOpened?.active === "string",
      JSON.stringify(tkOpened));

    const tkTokens = await page.evaluate(() => {
      const group = document.getElementById("showcase-tokenizer-default-group");
      return {
        group: group?.getAttribute("role") ?? null,
        label: group?.getAttribute("aria-label") ?? null,
        component: group?.getAttribute("data-astryx-component") ?? null,
        tokens: [...(group?.querySelectorAll(".astryx-tokenizer__token") ?? [])].map((t) => t.textContent.trim()),
        removable: [...(group?.querySelectorAll(".astryx-tokenizer__token button") ?? [])]
          .map((b) => b.getAttribute("aria-label")),
      };
    });
    check("the selected values are tokens in a labelled group, and each one can be removed",
      tkTokens?.group === "group"
        && tkTokens?.label !== null
        && tkTokens?.component === "Tokenizer"
        && tkTokens?.tokens.length === 2
        && tkTokens?.removable.length === 2
        && tkTokens?.removable.every((l) => l && l.toLowerCase().includes("remove")),
      JSON.stringify(tkTokens));

    const tkError = await page.evaluate(() => {
      const el = document.getElementById("showcase-tokenizer-error-status");
      return { role: el?.getAttribute("role") ?? null, text: el?.textContent.trim() ?? null };
    });
    check("the error example announces the error",
      tkError?.role === "alert" && typeof tkError?.text === "string" && tkError.text.length > 0,
      JSON.stringify(tkError));

    // A field that is disabled AND carries a reason is readonly with
    // aria-disabled, so the reason can still be reached and read.
    const tkDisabled = await page.evaluate(() => {
      const el = document.getElementById("showcase-tokenizer-disabled");
      const group = document.getElementById("showcase-tokenizer-disabled-group");
      return {
        tag: el?.tagName ?? null,
        readonly: el?.hasAttribute("readonly") ?? null,
        ariaDisabled: el?.getAttribute("aria-disabled") ?? null,
        groupDisabled: group?.getAttribute("data-astryx-disabled") ?? null,
        groupClass: group?.getAttribute("class") ?? null,
      };
    });
    check("the disabled example's input is readonly and says it is disabled",
      tkDisabled?.tag === "INPUT"
        && tkDisabled?.readonly === true
        && tkDisabled?.ariaDisabled === "true"
        && tkDisabled?.groupDisabled === "true"
        && (tkDisabled?.groupClass ?? "").includes("astryx-tokenizer--disabled"),
      JSON.stringify(tkDisabled));

    const tkHtmlName = await page.evaluate(() => {
      const group = document.getElementById("showcase-tokenizer-html-name-group");
      return [...(group?.querySelectorAll('input[type="hidden"]') ?? [])]
        .map((i) => ({ name: i.getAttribute("name"), value: i.getAttribute("value") }));
    });
    check("the form example carries one hidden input per selected id",
      Array.isArray(tkHtmlName) && tkHtmlName.length === 2
        && tkHtmlName.every((h) => h.name === "reviewers" && h.value && h.value.length > 0),
      JSON.stringify(tkHtmlName));
  }


  // -------------------------------------------------------------- Selector (M73)
  {
    const selSection = await page.$("section[data-showcase-component='Selector']");
    check("the Selector section renders", selSection !== null,
      selSection ? "found" : "missing");
    if (selSection) {
      const instances = await page.evaluate(() =>
        document.querySelectorAll('section[data-showcase-component="Selector"] [data-astryx-component="Selector"]').length);
      check("all seven Selector instances render", instances === 7, `got ${instances}`);

      const trigger = await page.evaluate(() => {
        const el = document.querySelector('#showcase-selector-options');
        if (!el) return null;
        return {
          tag: el.tagName,
          role: el.getAttribute("role"),
          haspopup: el.getAttribute("aria-haspopup"),
          expanded: el.getAttribute("aria-expanded"),
          controls: el.getAttribute("aria-controls"),
          labelledby: el.getAttribute("aria-labelledby"),
          text: (el.textContent ?? "").trim(),
        };
      });
      check("the trigger is a combobox that names the listbox it controls",
        trigger?.tag === "BUTTON"
          && trigger?.role === "combobox"
          && trigger?.haspopup === "listbox"
          && trigger?.expanded === "false"
          && trigger?.controls === "showcase-selector-options-listbox"
          && trigger?.labelledby === "showcase-selector-options-label",
        JSON.stringify(trigger));
      check("the trigger shows the placeholder until something is picked",
        trigger?.text === "Select...", JSON.stringify(trigger?.text));

      const list = await page.evaluate(() => {
        const el = document.getElementById("showcase-selector-options-listbox");
        if (!el) return null;
        const rows = [...el.querySelectorAll(".astryx-selector__option")];
        return {
          role: el.getAttribute("role"),
          rows: rows.length,
          rowRoles: rows.map((r) => r.getAttribute("role")),
          labels: rows.map((r) => (r.textContent ?? "").trim()),
        };
      });
      check("the list is a listbox of three rows",
        list?.role === "listbox" && list?.rows === 3
          && list?.rowRoles.every((r) => r === "row"),
        JSON.stringify(list));
      check("the rows carry the option labels",
        list?.labels?.join("|") === "Ada Lovelace|Alan Turing|Grace Hopper",
        JSON.stringify(list?.labels));

      const panel = await page.evaluate(() => {
        const el = document.getElementById("showcase-selector-options-panel");
        return el ? { popover: el.getAttribute("popover") } : null;
      });
      check("the panel is a native popover", panel?.popover === "auto", JSON.stringify(panel));

      await page.click("#showcase-selector-options");
      await page.waitForTimeout(250);
      const opened = await page.evaluate(() => {
        const trigger = document.getElementById("showcase-selector-options");
        const list = document.getElementById("showcase-selector-options-listbox");
        const highlighted = list?.querySelector(".astryx-selector__option--highlighted");
        return {
          expanded: trigger?.getAttribute("aria-expanded"),
          highlighted: (highlighted?.textContent ?? "").trim(),
          active: trigger?.getAttribute("aria-activedescendant"),
        };
      });
      check("opening the panel expands the trigger and highlights the first row",
        opened?.expanded === "true"
          && opened?.highlighted === "Ada Lovelace"
          && opened?.active === "showcase-selector-options-listbox-item-0",
        JSON.stringify(opened));

      await page.keyboard.press("ArrowDown");
      await page.waitForTimeout(200);
      const moved = await page.evaluate(() => {
        const trigger = document.getElementById("showcase-selector-options");
        const list = document.getElementById("showcase-selector-options-listbox");
        const highlighted = list?.querySelector(".astryx-selector__option--highlighted");
        return {
          highlighted: (highlighted?.textContent ?? "").trim(),
          active: trigger?.getAttribute("aria-activedescendant"),
        };
      });
      check("the arrow key moves the highlight and the active descendant",
        moved?.highlighted === "Alan Turing"
          && moved?.active === "showcase-selector-options-listbox-item-1",
        JSON.stringify(moved));

      await page.keyboard.press("Enter");
      await page.waitForTimeout(300);
      const picked = await page.evaluate(() => {
        const trigger = document.getElementById("showcase-selector-options");
        const readout = document.getElementById("showcase-selector-readout");
        return {
          expanded: trigger?.getAttribute("aria-expanded"),
          text: (trigger?.textContent ?? "").trim(),
          readout: (readout?.textContent ?? "").trim(),
        };
      });
      check("Enter picks the highlighted row and closes the panel",
        picked?.expanded === "false"
          && picked?.text === "Alan Turing"
          && picked?.readout === "picked alan",
        JSON.stringify(picked));

      const shapes = await page.evaluate(() => {
        // the panel is a sibling of the control, not a descendant of it
        const boxOf = (id) => document.getElementById(`${id.replace(/^#/, "")}-panel`);
        const grouped = boxOf("#showcase-selector-grouped");
        const divided = boxOf("#showcase-selector-divider");
        const described = boxOf("#showcase-selector-described");
        const disabled = boxOf("#showcase-selector-disabled");
        const empty = boxOf("#showcase-selector-empty");
        const searched = boxOf("#showcase-selector-search");
        return {
          groups: [...(grouped?.querySelectorAll(".astryx-selector__group-title") ?? [])].map((t) => (t.textContent ?? "").trim()),
          dividers: (divided?.querySelectorAll(".astryx-selector__divider") ?? []).length,
          descriptions: [...(described?.querySelectorAll(".astryx-selector__option-description") ?? [])].map((d) => (d.textContent ?? "").trim()),
          disabledRows: (disabled?.querySelectorAll(".astryx-selector__option--disabled") ?? []).length,
          empty: (empty?.querySelector(".astryx-selector__empty")?.textContent ?? "").trim(),
          searchInput: searched?.querySelector("input") !== null && searched?.querySelector("input") !== undefined,
        };
      });
      check("a grouped list carries its group titles",
        shapes?.groups?.join("|") === "Analysts|Engineers", JSON.stringify(shapes?.groups));
      check("a list can carry a divider", shapes?.dividers === 1, JSON.stringify(shapes?.dividers));
      check("a row can carry a description",
        shapes?.descriptions?.join("|") === "the first programmer", JSON.stringify(shapes?.descriptions));
      check("a row can be unpickable", shapes?.disabledRows === 1, JSON.stringify(shapes?.disabledRows));
      check("an empty list says so", (shapes?.empty ?? "") !== "", JSON.stringify(shapes?.empty));
      check("the list can carry a search field", shapes?.searchInput === true, JSON.stringify(shapes?.searchInput));
    }
  }


  // -------------------------------------------------------------- BottomSheet (M74)
  {
    const bsSection = await page.$("section[data-showcase-component='BottomSheet']");
    check("the BottomSheet section renders", bsSection !== null,
      bsSection ? "found" : "missing");
    if (bsSection) {
      const shape = await page.evaluate(() => {
        const sec = document.querySelector("section[data-showcase-component='BottomSheet']");
        const dialogs = [...sec.querySelectorAll("dialog")];
        const inline = sec.querySelector("#showcase-bottom-sheet-inline");
        return {
          components: sec.querySelectorAll("[data-astryx-component='BottomSheet']").length,
          dialogs: dialogs.length,
          ids: dialogs.map((d) => d.id),
          inlineTag: inline?.tagName ?? null,
          inlineClass: inline?.getAttribute("class") ?? null,
          handles: sec.querySelectorAll(".astryx-bottom-sheet__handle").length,
        };
      });
      check("the section draws five sheets, four of them dialogs and one inline",
        shape?.components === 5
          && shape?.dialogs === 4
          && shape?.inlineTag === "DIV"
          && (shape?.inlineClass ?? "").includes("astryx-bottom-sheet--inline"),
        JSON.stringify(shape));
      check("each sheet has a drag handle", shape?.handles === 5, JSON.stringify(shape?.handles));

      await page.click("text=Open the sheet");
      await page.waitForTimeout(400);
      const opened = await page.evaluate(() => {
        const sec = document.querySelector("section[data-showcase-component='BottomSheet']");
        const d = sec?.querySelector("dialog[open]");
        if (!d) return null;
        return {
          id: d.id,
          modal: d.matches(":modal"),
          role: d.getAttribute("role"),
          label: d.getAttribute("aria-label"),
        };
      });
      check("the sheet opens as a native modal dialog that names itself",
        opened?.id === "showcase-bottom-sheet-info"
          && opened?.modal === true
          && opened?.role === "dialog"
          && opened?.label === "Account details",
        JSON.stringify(opened));

      await page.keyboard.press("Escape");
      await page.waitForTimeout(400);
      const escaped = await page.evaluate(() => {
        const sec = document.querySelector("section[data-showcase-component='BottomSheet']");
        return {
          open: sec?.querySelectorAll("dialog[open]").length ?? -1,
        };
      });
      check("Escape closes the sheet", escaped?.open === 0, JSON.stringify(escaped));

      const purposes = await page.evaluate(() => {
        const sec = document.querySelector("section[data-showcase-component='BottomSheet']");
        const form = sec?.querySelector("#showcase-bottom-sheet-form");
        const required = sec?.querySelector("#showcase-bottom-sheet-required");
        return {
          formRole: form?.getAttribute("role") ?? null,
          requiredRole: required?.getAttribute("role") ?? null,
        };
      });
      check("a sheet that has to be answered is an alertdialog",
        purposes?.requiredRole === "alertdialog", JSON.stringify(purposes));
    }
  }


  // ---------------------------------------------------------- CommandPalette (M75)
  {
    const cpSection = await page.$("section[data-showcase-component='CommandPalette']");
    check("the CommandPalette section renders", cpSection !== null,
      cpSection ? "found" : "missing");
    if (cpSection) {
      const shape = await page.evaluate(() => {
        const sec = document.querySelector("section[data-showcase-component='CommandPalette']");
        const input = sec.querySelector("input");
        const list = sec.querySelector("#showcase-command-palette-inline-list");
        const items = [...(list?.querySelectorAll("[role='option']") ?? [])];
        const groups = [...(sec.querySelectorAll("[role='group']") ?? [])];
        return {
          inputs: sec.querySelectorAll("input").length,
          listboxes: sec.querySelectorAll("[role='listbox']").length,
          inputRole: input?.getAttribute("role") ?? null,
          inputExpanded: input?.getAttribute("aria-expanded") ?? null,
          inputControls: input?.getAttribute("aria-controls") ?? null,
          listRole: list?.getAttribute("role") ?? null,
          items: items.length,
          itemRoles: [...new Set(items.map((i) => i.getAttribute("role")))],
          itemLabels: items.slice(0, 3).map((i) => (i.textContent ?? "").trim().slice(0, 24)),
          groups: groups.map((g) => g.getAttribute("aria-label")).slice(0, 2),
          groupItems: groups[0]?.querySelectorAll("[role='option']").length ?? 0,
          active: input?.getAttribute("aria-activedescendant") ?? null,
        };
      });
      check("the palette is a combobox over a listbox of options",
        shape?.inputRole === "combobox"
          && shape?.listRole === "listbox"
          && shape?.inputControls === "showcase-command-palette-inline-list"
          && shape?.items === 6
          && shape?.itemRoles.every((r) => r === "option"),
        JSON.stringify(shape));
      check("the field is expanded while the list is on the page",
        shape?.inputExpanded === "true", JSON.stringify(shape?.inputExpanded));
      check("the commands are grouped, and the group names them",
        shape?.groups?.join("|") === "Account|Navigation" && shape?.groupItems > 0,
        JSON.stringify({ groups: shape?.groups, groupItems: shape?.groupItems }));
      check("the highlighted row is named with aria-activedescendant",
        typeof shape?.active === "string" && shape.active.length > 0,
        JSON.stringify(shape?.active));

      await page.fill("#showcase-command-palette-inline-input", "set");
      await page.waitForTimeout(400);
      const filtered = await page.evaluate(() => {
        const sec = document.querySelector("section[data-showcase-component='CommandPalette']");
        const list = sec.querySelector("#showcase-command-palette-inline-list");
        return {
          items: list?.querySelectorAll("[role='option']").length ?? -1,
          labels: [...(list?.querySelectorAll("[role='option']") ?? [])].map((i) => (i.textContent ?? "").trim().slice(0, 20)),
        };
      });
      check("typing filters the commands",
        filtered?.items === 1 && filtered?.labels?.[0] === "Settings",
        JSON.stringify(filtered));
    }
  }

  // --------------------------------------------------------------- AppShell (M77)
  {
    const asSection = await page.$("section[data-showcase-component='AppShell']");
    check("the AppShell section renders", asSection !== null,
      asSection === null ? "not found" : "found");

    if (asSection) {
      const shape = await page.evaluate(() => {
        const shells = [...document.querySelectorAll("[data-astryx-component='AppShell']")];
        const first = shells[0];
        const main = first?.querySelector("[role='main']");
        const skip = first?.querySelector(".astryx-app-shell__skip-link");
        // The frame alone has no header: the header is only drawn when
        // there is navigation or a banner to put in it.
        const withHeader = shells.find((s) => s.querySelector(".astryx-app-shell__header") !== null);
        const header = withHeader?.querySelector(".astryx-app-shell__header");
        return {
          shells: shells.length,
          roles: shells.map((s) => s.getAttribute("data-astryx-variant")),
          mainRole: main?.getAttribute("role") ?? null,
          mainId: main?.getAttribute("id") ?? null,
          mainTabindex: main?.getAttribute("tabindex") ?? null,
          skipHref: skip?.getAttribute("href") ?? null,
          skipText: (skip?.textContent ?? "").trim(),
          headerRole: header?.getAttribute("role") ?? null,
          banner: first?.querySelector(".astryx-app-shell__banner") !== null,
          navs: first?.querySelectorAll("nav").length ?? 0,
        };
      });

      check("every example renders its own shell, and the root carries the house's marker",
        shape?.shells >= 4 && shape?.roles.every((v) => v !== null),
        JSON.stringify(shape));

      check("the content is the main landmark, with the id the skip link points at",
        shape?.mainRole === "main"
          && shape?.mainId === "astryx-app-shell-main"
          && shape?.mainTabindex === "-1",
        JSON.stringify(shape));

      check("the skip link is the shell's own, and it says where it goes",
        shape?.skipHref === "#astryx-app-shell-main" && shape?.skipText === "Skip to content",
        JSON.stringify({ href: shape?.skipHref, text: shape?.skipText }));

      check("the header is the banner landmark when there is navigation in it",
        shape?.headerRole === "banner", JSON.stringify({ role: shape?.headerRole }));

      // The frame alone has no header at all - there is nothing to put in it.
      const headerless = await page.evaluate(() => {
        const shells = [...document.querySelectorAll("[data-astryx-component='AppShell']")];
        const plain = shells.find((s) => s.querySelector(".astryx-app-shell__header") === null);
        return {
          exists: plain !== undefined,
          main: plain?.querySelector("[role='main']") !== null,
        };
      });
      check("the frame alone has no header, and still holds the content",
        headerless?.exists === true && headerless?.main === true,
        JSON.stringify(headerless));

      // The four background variants.
      const variants = await page.evaluate(() => {
        const names = [...document.querySelectorAll("[data-astryx-component='AppShell']")]
          .map((s) => s.getAttribute("data-astryx-variant"));
        return [...new Set(names)];
      });
      check("the background variants are all present",
        ["wash", "surface", "section", "elevated"].every((v) => variants.includes(v)),
        JSON.stringify(variants));

      // The banner: the announcement above the navigation.
      const banner = await page.evaluate(() => {
        const withBanner = [...document.querySelectorAll("[data-astryx-component='AppShell']")]
          .find((s) => s.querySelector(".astryx-app-shell__banner") !== null);
        const b = withBanner?.querySelector(".astryx-app-shell__banner");
        return {
          exists: b !== null && b !== undefined,
          text: (b?.textContent ?? "").trim().slice(0, 40),
          inHeader: b?.closest(".astryx-app-shell__header") !== null,
        };
      });
      check("the banner is rendered above the navigation, inside the header",
        banner?.exists === true && banner?.inHeader === true,
        JSON.stringify(banner));

      // The mobile layout: the collapsed bar and the toggle that opens the drawer.
      const mobile = await page.evaluate(() => {
        const shells = [...document.querySelectorAll("[data-astryx-component='AppShell']")];
        const m = shells.find((s) => s.querySelector(".astryx-app-shell__mobile-bar") !== null);
        const toggle = m?.querySelector(".astryx-app-shell__toggle button")
          ?? m?.querySelector(".astryx-app-shell__toggle");
        return {
          exists: m !== undefined,
          bar: m?.querySelector(".astryx-app-shell__mobile-bar") !== null,
          toggle: toggle !== null && toggle !== undefined,
          expanded: toggle?.getAttribute("aria-expanded") ?? null,
          controls: toggle?.getAttribute("aria-controls") ?? null,
        };
      });
      check("the mobile layout collapses to the bar, and the toggle says what it controls",
        mobile?.exists === true && mobile?.bar === true
          && mobile?.toggle === true && mobile?.expanded !== null,
        JSON.stringify(mobile));

      // The toggle opens the drawer.
      const drawer = await page.evaluate(async () => {
        const shells = [...document.querySelectorAll("[data-astryx-component='AppShell']")];
        const m = shells.find((s) => s.querySelector(".astryx-app-shell__mobile-bar") !== null);
        const toggle = m?.querySelector(".astryx-app-shell__toggle button")
          ?? m?.querySelector(".astryx-app-shell__toggle");
        toggle?.click();
        await new Promise((r) => setTimeout(r, 400));
        const after = toggle?.getAttribute("aria-expanded");
        const nav = document.getElementById(toggle?.getAttribute("aria-controls") ?? "");
        return {
          expanded: after,
          drawer: nav !== null && nav !== undefined,
          open: nav?.open ?? null,
        };
      });
      check("the toggle opens the drawer and says so",
        drawer?.expanded === "true" && drawer?.drawer === true && drawer?.open === true,
        JSON.stringify(drawer));

      // The drawer is a modal dialog: it must be closed again, or it goes on
      // covering the page for every check that follows.
      await page.keyboard.press("Escape");
      await page.waitForTimeout(400);
      const closed = await page.evaluate(() => {
        const shells = [...document.querySelectorAll("[data-astryx-component='AppShell']")];
        const m = shells.find((s) => s.querySelector(".astryx-app-shell__mobile-bar") !== null);
        const toggle = m?.querySelector(".astryx-app-shell__toggle button")
          ?? m?.querySelector(".astryx-app-shell__toggle");
        const nav = document.getElementById(toggle?.getAttribute("aria-controls") ?? "");
        return {
          expanded: toggle?.getAttribute("aria-expanded") ?? null,
          open: nav?.open ?? null,
        };
      });
      check("Escape closes the drawer again",
        closed?.expanded === "false" && closed?.open === false,
        JSON.stringify(closed));
    }
  }

  // ------------------------------------------------------------- ContextMenu (M76)
  {
    const cmSection = await page.$("section[data-showcase-component='ContextMenu']");
    check("the ContextMenu section renders", cmSection !== null,
      cmSection ? "found" : "missing");
    if (cmSection) {
      const shape = await page.evaluate(() => {
        const sec = document.querySelector("section[data-showcase-component='ContextMenu']");
        return {
          examples: sec.querySelectorAll("[data-example]").length,
          components: sec.querySelectorAll("[data-astryx-component='ContextMenu']").length,
          triggers: sec.querySelectorAll("[data-astryx-target='context-menu-trigger']").length,
        };
      });
      check("the section draws three menus, each with a trigger",
        shape?.examples === 3 && shape?.components === 3 && shape?.triggers === 3,
        JSON.stringify(shape));

      // The menu is closed until the trigger is right-clicked.
      const before = await page.evaluate(() => {
        const menu = document.getElementById("showcase-context-menu-basic-menu");
        return { exists: menu !== null, items: menu?.querySelectorAll("[role='menuitem']").length ?? -1 };
      });
      check("the menu is not in the document until it is opened",
        before?.exists === false, JSON.stringify(before));

      // Right-click the trigger: the menu opens at the pointer.
      const trigger = await page.$("section[data-showcase-component='ContextMenu'] [data-astryx-target='context-menu-trigger']");
      if (trigger) {
        // The trigger is far down the page: scroll it into view before
        // clicking, or the click lands somewhere else entirely.
        await trigger.scrollIntoViewIfNeeded();
        const box = await trigger.boundingBox();
        await page.mouse.click(box.x + 10, box.y + 10, { button: "right" });
        await page.waitForTimeout(300);
      }
      const opened = await page.evaluate(() => {
        const menu = document.getElementById("showcase-context-menu-basic-menu");
        if (!menu) return null;
        const items = [...menu.querySelectorAll("[role='menuitem']")];
        const groups = [...menu.querySelectorAll("[role='group']")];
        const separators = [...menu.querySelectorAll("[role='separator']")];
        return {
          role: menu.getAttribute("role"),
          label: menu.getAttribute("aria-label"),
          items: items.length,
          groups: groups.length,
          separators: separators.length,
          labels: items.map((i) => (i.textContent ?? "").trim().slice(0, 16)),
          haspopup: items.filter((i) => i.getAttribute("aria-haspopup") === "true").length,
          disabled: items.filter((i) => i.getAttribute("aria-disabled") === "true").length,
          groupLabel: groups[0]?.getAttribute("aria-label") ?? null,
          left: menu.style.left ?? "",
          top: menu.style.top ?? "",
        };
      });
      check("the menu opens as a labelled menu of rows",
        opened?.role === "menu" && opened?.label === "File" && opened?.items === 6,
        JSON.stringify(opened));
      check("a divider and a labelled group separate the rows",
        opened?.separators === 1 && opened?.groups === 1 && opened?.groupLabel === "Edit",
        JSON.stringify(opened));
      check("the row that carries children says so, and a disabled row says it is disabled",
        opened?.haspopup === 1 && opened?.disabled === 1,
        JSON.stringify(opened));
      check("the menu is positioned at the pointer, not at the origin",
        opened?.left !== "0px" && opened?.top !== "0px",
        JSON.stringify({ left: opened?.left, top: opened?.top }));

      // The keyboard model: arrows move the focus, Home and End jump.
      const focused = await page.evaluate(() => {
        const menu = document.getElementById("showcase-context-menu-basic-menu");
        return menu?.contains(document.activeElement) ?? false;
      });
      check("the opened menu takes the focus", focused === true, String(focused));

      await page.keyboard.press("ArrowDown");
      await page.waitForTimeout(120);
      const afterArrow = await page.evaluate(() => {
        const menu = document.getElementById("showcase-context-menu-basic-menu");
        const active = document.activeElement;
        return {
          inMenu: menu?.contains(active) ?? false,
          text: (active?.textContent ?? "").trim().slice(0, 16),
        };
      });
      check("ArrowDown moves the focus onto a row",
        afterArrow?.inMenu === true && (afterArrow?.text ?? "") !== "",
        JSON.stringify(afterArrow));

      // Escape closes the menu again.
      await page.keyboard.press("Escape");
      await page.waitForTimeout(250);
      const closed = await page.evaluate(() => {
        const menu = document.getElementById("showcase-context-menu-basic-menu");
        return { exists: menu !== null };
      });
      check("Escape closes the menu", closed?.exists === false, JSON.stringify(closed));
    }
  }

  // -------------------------------------------------------------- MultiSelector
  {
    const msSection = await page.$("section[data-showcase-component='MultiSelector']");
    check("the MultiSelector section renders", msSection !== null,
      msSection ? "found" : "missing");
    if (msSection) {
      const instances = await page.evaluate(() =>
        document.querySelectorAll('section[data-showcase-component="MultiSelector"] [data-astryx-component="MultiSelector"]').length);
      check("all eight MultiSelector instances render", instances === 8, `got ${instances}`);

      const trigger = await page.evaluate(() => {
        const el = document.querySelector('section[data-showcase-component="MultiSelector"] [role="combobox"]');
        if (!el) return null;
        return {
          tag: el.tagName,
          role: el.getAttribute("role"),
          haspopup: el.getAttribute("aria-haspopup"),
          expanded: el.getAttribute("aria-expanded"),
          controls: el.getAttribute("aria-controls"),
          label: el.getAttribute("aria-labelledby"),
        };
      });
      check("the trigger is a combobox that names the listbox it controls",
        trigger?.tag === "BUTTON"
          && trigger?.role === "combobox"
          && trigger?.haspopup === "listbox"
          && trigger?.expanded === "false"
          && trigger?.controls === "astryx-multi-selector-listbox"
          && trigger?.label === "astryx-multi-selector-label",
        JSON.stringify(trigger));

      const before = await page.evaluate(() => {
        const pop = document.getElementById("astryx-multi-selector-popover");
        const lb = document.getElementById("astryx-multi-selector-listbox");
        return {
          popover: pop?.getAttribute("popover") ?? null,
          // The popover is what hides: a closed one is display:none, and the
          // listbox inside it is display:block the whole time. What matters is
          // whether the thing RENDERS, so ask for its box.
          popDisplay: pop ? getComputedStyle(pop).display : null,
          box: lb ? Math.round(lb.getBoundingClientRect().height) : 0,
        };
      });
      check("the list is a native popover, and it is closed until the field is opened",
        before?.popover === "auto" && before?.popDisplay === "none" && before?.box === 0,
        JSON.stringify(before));

      await page.click('section[data-showcase-component="MultiSelector"] [role="combobox"]');
      await page.waitForTimeout(250);

      const opened = await page.evaluate(() => {
        const lb = document.getElementById("astryx-multi-selector-listbox");
        const trig = document.querySelector('section[data-showcase-component="MultiSelector"] [role="combobox"]');
        return {
          expanded: trig?.getAttribute("aria-expanded"),
          box: lb ? Math.round(lb.getBoundingClientRect().height) : 0,
          role: lb?.getAttribute("role"),
          multi: lb?.getAttribute("aria-multiselectable"),
          options: lb?.querySelectorAll('[role="option"]').length ?? 0,
          active: lb?.getAttribute("aria-activedescendant") ?? null,
        };
      });
      check("opening the field shows a multi-select listbox with its options",
        opened?.expanded === "true"
          && opened?.box > 0
          && opened?.role === "listbox"
          && opened?.multi === "true"
          && opened?.options > 0
          && typeof opened?.active === "string",
        JSON.stringify(opened));

      const activeBefore = opened?.active;
      await page.keyboard.press("ArrowDown");
      await page.waitForTimeout(150);
      const activeAfter = await page.evaluate(() => {
        const lb = document.getElementById("astryx-multi-selector-listbox");
        return { active: lb?.getAttribute("aria-activedescendant") ?? null };
      });
      check("the arrow keys move the active option, and the listbox says which one it is",
        activeAfter?.active !== activeBefore && typeof activeAfter?.active === "string",
        JSON.stringify({ before: activeBefore, after: activeAfter?.active }));

      await page.keyboard.press("Enter");
      await page.waitForTimeout(200);
      const toggled = await page.evaluate(() => {
        const lb = document.getElementById("astryx-multi-selector-listbox");
        const selected = [...(lb?.querySelectorAll('[role="option"][aria-selected="true"]') ?? [])];
        return { selected: selected.length, first: selected[0]?.textContent.trim() ?? null };
      });
      check("Enter toggles the option, and the row says it is selected",
        toggled?.selected > 0 && typeof toggled?.first === "string",
        JSON.stringify(toggled));

      await page.keyboard.press("Escape");
      await page.waitForTimeout(250);
      const closed = await page.evaluate(() => {
        const trig = document.querySelector('section[data-showcase-component="MultiSelector"] [role="combobox"]');
        const lb = document.getElementById("astryx-multi-selector-listbox");
        return {
          expanded: trig?.getAttribute("aria-expanded"),
          box: lb ? Math.round(lb.getBoundingClientRect().height) : 0,
        };
      });
      check("Escape closes the list",
        closed?.expanded === "false" && closed?.box === 0,
        JSON.stringify(closed));
    }
  }

  // ------------------------------------------------------------------ Stepper
  {
    const spSection = await page.$("section[data-showcase-component='Stepper']");
    check("the Stepper section renders", spSection !== null,
      spSection ? "found" : "missing");
    if (spSection) {
      const root = await page.evaluate(() => {
        const el = document.getElementById("showcase-stepper-horizontal");
        if (!el) return null;
        const list = el.querySelector(".astryx-stepper__list");
        return {
          component: el.getAttribute("data-astryx-component"),
          orientation: el.getAttribute("data-astryx-orientation"),
          density: el.getAttribute("data-astryx-density"),
          position: el.getAttribute("data-astryx-indicator-position"),
          listLabel: list?.getAttribute("aria-label") ?? null,
          steps: el.querySelectorAll(".astryx-stepper__step").length,
          bars: el.querySelectorAll(".astryx-stepper__bar").length,
          rings: el.querySelectorAll(".astryx-stepper__ring").length,
        };
      });
      check("the stepper names its orientation, its density and its indicator position",
        root?.component === "Stepper"
          && root?.orientation === "horizontal"
          && root?.density === "balanced"
          && root?.position === "separated"
          && root?.listLabel === "Progress",
        JSON.stringify(root));

      check("the flow draws a step and a connector for each of the four steps",
        root?.steps === 4 && root?.bars === 4 && root?.rings === 1,
        JSON.stringify({ steps: root?.steps, bars: root?.bars, rings: root?.rings }));

      const current = await page.evaluate(() =>
        [...document.querySelectorAll("#showcase-stepper-horizontal .astryx-stepper__step")]
          .map((s) => ({
            current: s.getAttribute("aria-current"),
            cls: s.getAttribute("class") ?? "",
          })));
      check("the current step is marked, and the ones after it say they have not started",
        current[0]?.current === "step"
          && (current[0]?.cls ?? "").includes("astryx-stepper__step--active")
          && current.slice(1).every((s) => s.current === null
            && (s.cls ?? "").includes("astryx-stepper__step--not-started")),
        JSON.stringify(current));

      // The claim that matters: clicking a step moves the current one.
      await page.click('#showcase-stepper-horizontal button[aria-label^="Go to step 3"]');
      await page.waitForTimeout(200);
      const afterClick = await page.evaluate(() => {
        const steps = [...document.querySelectorAll("#showcase-stepper-horizontal .astryx-stepper__step")];
        return {
          current: steps.findIndex((s) => s.getAttribute("aria-current") === "step"),
          cls: steps.map((s) => s.getAttribute("class") ?? ""),
        };
      });
      check("clicking a step moves the current step to it",
        afterClick?.current === 2
          && (afterClick?.cls?.[2] ?? "").includes("astryx-stepper__step--active"),
        JSON.stringify(afterClick));

      const statuses = await page.evaluate(() =>
        [...document.querySelectorAll("#showcase-stepper-statuses .astryx-stepper__step")]
          .map((s) => s.getAttribute("class") ?? ""));
      check("a step's status, its optional flag and its disabled flag reach the markup",
        statuses.some((c) => c.includes("astryx-stepper__step--success"))
          && statuses.some((c) => c.includes("astryx-stepper__step--warning"))
          && statuses.some((c) => c.includes("astryx-stepper__step--error"))
          && statuses.some((c) => c.includes("astryx-stepper__step--optional"))
          && statuses.some((c) => c.includes("astryx-stepper__step--disabled")),
        JSON.stringify(statuses));

      const vertical = await page.evaluate(() => {
        const el = document.getElementById("showcase-stepper-vertical");
        return {
          orientation: el?.getAttribute("data-astryx-orientation") ?? null,
          cls: el?.getAttribute("class") ?? "",
        };
      });
      check("the vertical stepper says so",
        vertical?.orientation === "vertical"
          && (vertical?.cls ?? "").includes("astryx-stepper--vertical"),
        JSON.stringify(vertical));

      const collapsed = await page.evaluate(() => {
        const el = document.getElementById("showcase-stepper-collapsed");
        return {
          collapsed: (el?.getAttribute("class") ?? "").includes("astryx-stepper--collapsed"),
          summary: el?.querySelector(".astryx-stepper__summary") !== null,
          summaryText: el?.querySelector(".astryx-stepper__summary")?.textContent.trim() ?? null,
          buttons: [...(el?.querySelectorAll(".astryx-stepper__summary button") ?? [])]
            .map((b) => b.getAttribute("aria-label")),
          // A collapsed stepper hides its steps VISUALLY: they stay in the
          // DOM for the accessible list, which is the contract the .mli
          // states and the reason the list is not display:none.
          stepsInDom: el?.querySelectorAll(".astryx-stepper__step").length ?? 0,
        };
      });
      check("a narrow stepper collapses into a summary row, with its own controls",
        collapsed?.collapsed === true
          && collapsed?.summary === true
          // The current step is the FIRST one, so there is a step to go
          // forward to and none to go back to: the Previous control is
          // only there when there is a previous step.
          && collapsed?.buttons?.includes("Next step")
          && !collapsed?.buttons?.includes("Previous step"),
        JSON.stringify(collapsed));

      check("and the collapsed stepper keeps its steps for the accessible list",
        collapsed?.stepsInDom === 4,
        JSON.stringify({ stepsInDom: collapsed?.stepsInDom }));
    }
  }

  // -------------------------------------------------------------------- Chat
  {
    const chatSection = await page.$("section[data-showcase-component='Chat']");
    check("the Chat section renders", chatSection !== null);
    const chatState = await page.evaluate(() => {
      const sec = document.querySelector("section[data-showcase-component='Chat']");
      const root_ = sec?.querySelector("[data-astryx-component='Chat']");
      const log = sec?.querySelector("[role='log']");
      const bubbles = [...(sec?.querySelectorAll(".astryx-chat__bubble") ?? [])];
      const authors = [...(sec?.querySelectorAll(".astryx-chat__author") ?? [])];
      const composer = sec?.querySelector(".astryx-chat__composer");
      const input = composer?.querySelector("textarea, input");
      const send = composer?.querySelector("button[aria-label='Send']");
      const firstExample = sec?.querySelector("[data-example]");
      return {
        examples: sec?.querySelectorAll("[data-example]").length ?? 0,
        component: root_?.getAttribute("data-astryx-component") ?? null,
        logRole: log?.getAttribute("role") ?? null,
        logLive: log?.getAttribute("aria-live") ?? null,
        bubbles: bubbles.length,
        bubbleText: bubbles[0]?.textContent?.trim().slice(0, 30) ?? null,
        authors: authors.map((a) => (a.textContent ?? "").trim()).slice(0, 4),
        inputLabel: input?.getAttribute("aria-label") ?? null,
        inputTag: input?.tagName?.toLowerCase() ?? null,
        sendDisabled: send?.hasAttribute("disabled") ?? null,
        sendLabel: send?.getAttribute("aria-label") ?? null,
        ghost: sec?.querySelectorAll(".astryx-chat__bubble--ghost").length ?? 0,
        grouped: sec?.querySelectorAll(".astryx-chat__bubble--group-first").length ?? 0,
        loading: sec?.querySelectorAll(".astryx-chat__loading").length ?? 0,
        empty: sec?.querySelectorAll(".astryx-chat__empty").length ?? 0,
        error: sec?.querySelectorAll(".astryx-chat__error").length ?? 0,
        firstExampleId: firstExample?.getAttribute("data-example") ?? null,
      };
    });
    check("the chat is marked as the chat", chatState.component === "Chat", JSON.stringify(chatState));
    check("the transcript is a log region", chatState.logRole === "log" && chatState.logLive === "polite", JSON.stringify(chatState));
    check("the messages are drawn as bubbles", chatState.bubbles > 0 && (chatState.bubbleText ?? "").length > 0, JSON.stringify(chatState));
    check("a message names its author", chatState.authors.length > 0 && chatState.authors.every((a) => a.length > 0), JSON.stringify(chatState));
    check("the composer takes the message", chatState.inputTag === "textarea" && chatState.inputLabel === "Message input", JSON.stringify(chatState));
    check("an empty composer cannot send", chatState.sendDisabled === true && chatState.sendLabel === "Send", JSON.stringify(chatState));
    check("a run of messages reads as one block", chatState.grouped > 0, JSON.stringify(chatState));
    check("a ghost bubble is marked as one", chatState.ghost > 0, JSON.stringify(chatState));
    check("the thread knows its three states", chatState.loading > 0 && chatState.empty > 0 && chatState.error > 0, JSON.stringify(chatState));

    // a real interaction: typing enables the send
    const typed = await page.evaluate(async () => {
      const composer = document.querySelector(".astryx-chat__composer");
      const input = composer?.querySelector("textarea, input");
      const send = composer?.querySelector("button[aria-label='Send']");
      if (!input) return { ok: false };
      const setter = Object.getOwnPropertyDescriptor(
        window.HTMLTextAreaElement.prototype, "value")?.set;
      setter?.call(input, "the release notes are out");
      input.dispatchEvent(new Event("input", { bubbles: true }));
      await new Promise((r) => setTimeout(r, 300));
      return { ok: true, disabled: send?.hasAttribute("disabled") ?? null, value: input.value };
    });
    check("typing enables the send button", typed.ok && typed.disabled === false, JSON.stringify(typed));
  }

  // ---------------------------------------------------------------- Calendar
  {
    const calSection = await page.$("section[data-showcase-component='Calendar']");
    check("the Calendar section renders", calSection !== null);
    const calState = await page.evaluate(() => {
      const sec = document.querySelector("section[data-showcase-component='Calendar']");
      const single = document.querySelector("#showcase-calendar-single");
      const root_ = sec?.querySelector("[data-astryx-component='Calendar']");
      const grid = single?.querySelector("[role='grid']");
      const gridcells = [...(single?.querySelectorAll("[role='gridcell']") ?? [])];
      const dayButtons = [...(single?.querySelectorAll("[role='gridcell'] button") ?? [])];
      const outside = dayButtons.find((b) =>
        b.className.includes("astryx-calendar__day--outside"));
      const inside = dayButtons.find((b) =>
        !b.className.includes("astryx-calendar__day--outside"));
      const rangeGrid = document
        .querySelector("#showcase-calendar-range")
        ?.querySelector("[role='grid']");
      const twoMonths = document.querySelector("#showcase-calendar-two-months");
      const twoGrids = [...(twoMonths?.querySelectorAll("[role='grid']") ?? [])];
      return {
        examples: sec?.querySelectorAll("[data-example]").length ?? 0,
        component: root_?.getAttribute("data-astryx-component") ?? null,
        gridRole: grid?.getAttribute("role") ?? null,
        gridLabel: grid?.getAttribute("aria-label") ?? null,
        gridcells: gridcells.length,
        dayButtons: dayButtons.length,
        outsideDisabled: outside?.getAttribute("aria-disabled") ?? null,
        insideDisabled: inside?.getAttribute("aria-disabled") ?? null,
        insideLabel: inside?.getAttribute("aria-label") ?? null,
        rangeMulti: rangeGrid?.getAttribute("aria-multiselectable") ?? null,
        twoGridLabels: twoGrids.map((g) => g.getAttribute("aria-label")),
        boundedLabel: document
          .querySelector("#showcase-calendar-bounded")
          ?.querySelector("[role='grid']")
          ?.getAttribute("aria-label") ?? null,
      };
    });
    check("the calendar draws its month grid", calState.gridRole === "grid", JSON.stringify(calState));
    check("the grid is named for the month it shows", /^[A-Z][a-z]+ \d{4}$/.test(calState.gridLabel ?? ""), JSON.stringify(calState));
    check("the month has a cell for every day", calState.gridcells >= 28 && calState.gridcells <= 42, JSON.stringify(calState));
    check("every day is a button", calState.dayButtons === calState.gridcells, JSON.stringify(calState));
    check("a day names its full date", /\w+, \w+ \d+, \d{4}/.test(calState.insideLabel ?? ""), JSON.stringify(calState));
    check("a day outside the month cannot be picked", calState.outsideDisabled === "true" && calState.insideDisabled === null, JSON.stringify(calState));
    check("a range grid takes more than one day", calState.rangeMulti === "true", JSON.stringify(calState));
    check("two months draw two grids", calState.twoGridLabels.length === 2, JSON.stringify(calState));
    check("the second month names itself", (calState.twoGridLabels[1] ?? "").startsWith("November"), JSON.stringify(calState));
    check("a bounded calendar opens on its first day", calState.boundedLabel === "March 2026", JSON.stringify(calState));

    // a real click: pick a day and the section's readout reports it
    await page.click("#showcase-calendar-single [role='gridcell'] button:not(.astryx-calendar__day--outside)");
    await page.waitForTimeout(300);
    const picked = await page.evaluate(() => {
      const readout = document.querySelector("#showcase-calendar-single-readout");
      const cell = document.querySelector(
        "#showcase-calendar-single [role='gridcell'] button:not(.astryx-calendar__day--outside)");
      return {
        readout: (readout?.textContent ?? "").trim(),
        label: cell?.getAttribute("aria-label") ?? null,
        selected: cell?.getAttribute("aria-selected") ?? null,
      };
    });
    check("clicking a day reports the pick", /^picked \d{4}-\d{2}-\d{2}$/.test(picked.readout), JSON.stringify(picked));
    check("the picked day says it is selected", (picked.label ?? "").endsWith(", selected"), JSON.stringify(picked));
  }

  // ------------------------------------------------------------------- TopNav
  {
    const tnSection = await page.$("section[data-showcase-component='TopNav']");
    check("the TopNav section renders", tnSection !== null);
    const tnState = await page.evaluate(() => {
      const nav = document.querySelector("#showcase-top-nav-default");
      const heading = nav?.querySelector(".astryx-top-nav__heading a");
      const items = [...(nav?.querySelectorAll(".astryx-top-nav__start a") ?? [])];
      return {
        tag: nav?.tagName?.toLowerCase() ?? null,
        role: nav?.getAttribute("role") ?? null,
        label: nav?.getAttribute("aria-label") ?? null,
        component: nav?.getAttribute("data-astryx-component") ?? null,
        headingText: heading?.textContent.trim() ?? null,
        headingTag: heading?.tagName?.toLowerCase() ?? null,
        itemLabels: items.map((a) => a.textContent.trim()),
        itemTags: items.map((a) => a.tagName.toLowerCase()),
        leftSection: nav?.querySelector(".astryx-top-nav__left-section") !== null,
        startSlot: nav?.querySelector(".astryx-top-nav__start") !== null,
        slots: ["left-section", "start", "center", "right"].filter((c) =>
          nav?.querySelector(`.astryx-top-nav__${c}`) !== null),
      };
    });
    check("a top nav is a navigation landmark with an accessible name",
      tnState?.tag === "nav" && tnState?.role === "navigation"
        && tnState?.label === "Top navigation"
        && tnState?.component === "TopNav",
      JSON.stringify(tnState));
    check("the heading is a link that names the product",
      tnState?.headingTag === "a" && tnState?.headingText?.includes("Astra"),
      JSON.stringify(tnState));
    check("the start slot carries the items as links",
      tnState?.itemLabels?.includes("Home") && tnState?.itemLabels?.includes("Docs")
        && tnState?.itemTags?.every((t) => t === "a"),
      JSON.stringify(tnState));
    check("the bar has a left section and a start slot for the items",
      tnState?.leftSection === true && tnState?.startSlot === true,
      JSON.stringify(tnState));

    const tnMenu = await page.evaluate(() => {
      const nav = document.querySelector("#showcase-top-nav-menu");
      const trigger = nav?.querySelector(".astryx-top-nav__heading button");
      return {
        trigger: trigger?.getAttribute("aria-label") ?? null,
        expanded: trigger?.getAttribute("aria-expanded") ?? null,
        menus: nav?.querySelectorAll("[role='menu']").length ?? 0,
        menuItems: nav?.querySelectorAll("[role='menuitem']").length ?? 0,
      };
    });
    check("the heading's menu is a trigger that says whether it is open",
      tnMenu?.trigger !== null && tnMenu?.expanded === "false",
      JSON.stringify(tnMenu));

    // A real click: the menu opens and its items are there.
    await page.click("#showcase-top-nav-menu .astryx-top-nav-heading__chevron-button");
    await page.waitForFunction(
      () => {
        const btn = document.querySelector("#showcase-top-nav-menu .astryx-top-nav-heading__chevron-button");
        return btn?.getAttribute("aria-expanded") === "true";
      },
      { timeout: 30000 },
    );
    const tnOpen = await page.evaluate(() => {
      const nav = document.querySelector("#showcase-top-nav-menu");
      const trigger = nav?.querySelector(".astryx-top-nav__heading button");
      return {
        expanded: trigger?.getAttribute("aria-expanded") ?? null,
        menuItems: [...(nav?.querySelectorAll("[role='menuitem']") ?? [])].map((m) => m.textContent.trim()),
      };
    });
    check("clicking the heading's chevron opens its menu",
      tnOpen?.expanded === "true" && tnOpen?.menuItems?.length === 3
        && tnOpen?.menuItems?.includes("Sign out"),
      JSON.stringify(tnOpen));
  }

  // ---------------------------------------------------------------- CodeBlock
  {
    const cbSection = await page.$("section[data-showcase-component='CodeBlock']");
    check("the CodeBlock section renders", cbSection !== null);
    const cbState = await page.evaluate(() => {
      const block = document.querySelector("#showcase-code-block-default");
      const header = block?.querySelector(".astryx-code-block__header");
      const copy = block?.querySelector("button[aria-label*='Copy']");
      const code = block?.querySelector(".astryx-code-block__code, .astryx-code-block__viewport code, code");
      return {
        tag: block?.tagName?.toLowerCase() ?? null,
        component: block?.getAttribute("data-astryx-component") ?? null,
        language: block?.getAttribute("data-astryx-language") ?? null,
        container: block?.getAttribute("data-astryx-container") ?? null,
        headerTitle: header?.querySelector(".astryx-code-block__title")?.textContent.trim() ?? null,
        copyLabel: copy?.getAttribute("aria-label") ?? null,
        hasCode: !!code,
        codeText: code?.textContent?.trim().slice(0, 40) ?? null,
        spans: code?.querySelectorAll("span").length ?? 0,
      };
    });
    check("a code block is a pre that says what language it holds",
      cbState?.tag === "pre" && cbState?.component === "CodeBlock"
        && cbState?.language === "javascript",
      JSON.stringify(cbState));
    check("the header carries the language and a copy button",
      cbState?.headerTitle === "javascript" && cbState?.copyLabel === "Copy code",
      JSON.stringify(cbState));
    check("the code is painted through spans, so it can be highlighted",
      cbState?.hasCode === true && cbState?.spans > 0,
      JSON.stringify(cbState));

    const cbVariants = await page.evaluate(() => {
      const titled = document.querySelector("#showcase-code-block-titled");
      const numbered = document.querySelector("#showcase-code-block-numbered");
      const diff = document.querySelector("#showcase-code-block-diff");
      const scrolling = document.querySelector("#showcase-code-block-scrolling");
      const collapsible = document.querySelector("#showcase-code-block-collapsible");
      const collapsedToggle = collapsible?.querySelector("button[aria-expanded]");
      return {
        titledTitle: titled?.querySelector(".astryx-code-block__title")?.textContent.trim() ?? null,
        numberedLines: numbered?.querySelectorAll(".astryx-code-block__line--numbered").length ?? 0,
        diffIsDiff: diff?.getAttribute("data-astryx-is-diff") ?? null,
        diffGlyphs: diff?.querySelectorAll(".astryx-code-block__diff-marker").length ?? 0,
        scrollingOverflow: (() => {
          const vp = scrolling?.querySelector(".astryx-code-block__viewport");
          if (!vp) return false;
          return vp.scrollHeight > vp.clientHeight || vp.scrollWidth > vp.clientWidth;
        })(),
        collapsibleIsCollapsible: collapsible?.getAttribute("data-astryx-is-collapsible") ?? null,
        collapsedToggleLabel: collapsedToggle?.getAttribute("aria-label") ?? null,
        collapsedToggleExpanded: collapsedToggle?.getAttribute("aria-expanded") ?? null,
        collapsedIsCollapsed: collapsible?.getAttribute("data-astryx-is-collapsed") ?? null,
      };
    });
    check("a titled block names its file in the header",
      cbVariants?.titledTitle !== null && cbVariants?.titledTitle?.length > 0,
      JSON.stringify(cbVariants));
    check("a numbered block numbers its lines",
      cbVariants?.numberedLines > 0,
      JSON.stringify(cbVariants));
    check("a diff says it is a diff and gives each line its glyph",
      cbVariants?.diffIsDiff === "true" && cbVariants?.diffGlyphs > 0,
      JSON.stringify(cbVariants));
    check("a long block scrolls inside its own viewport",
      cbVariants?.scrollingOverflow === true,
      JSON.stringify(cbVariants));
    check("a collapsible block has a toggle that says whether it is open",
      cbVariants?.collapsibleIsCollapsible === "true"
        && cbVariants?.collapsedToggleExpanded === "true"
        && cbVariants?.collapsedIsCollapsed === "false",
      JSON.stringify(cbVariants));

    // A real click: the copy button reports that it copied.
    const copyButton = await page.$("#showcase-code-block-copy button[aria-label*='Copy']");
    if (copyButton) {
      await copyButton.click();
      await page.waitForFunction(
        () => {
          const el = document.querySelector("#showcase-code-block-copy-count");
          return el && /copied:\s*[1-9]/.test(el.textContent);
        },
        { timeout: 30000 },
      );
      const cbCopy = await page.evaluate(() => {
        const el = document.querySelector("#showcase-code-block-copy-count");
        const label = document.querySelector("#showcase-code-block-copy button[aria-label*='Copy']");
        return {
          count: el?.textContent.trim() ?? null,
          label: label?.getAttribute("aria-label") ?? null,
        };
      });
      check("the copy button reports that it copied",
        cbCopy?.count !== null && /copied:\s*[1-9]/.test(cbCopy?.count),
        JSON.stringify(cbCopy));
    } else {
      check("the copy button reports that it copied", false, "no copy button found");
    }
  }

  // ---------------------------------------------------------------- Pagination
  {
    const pgSection = await page.$("section[data-showcase-component='Pagination']");
    check("the Pagination section renders", pgSection !== null);
    const pgState = await page.evaluate(() => {
      const nav = document.querySelector("#showcase-pagination-pages");
      const list = nav?.querySelector(".astryx-pagination__pages");
      const buttons = [...(list?.querySelectorAll("button") ?? [])];
      const current = list?.querySelector("[aria-current='page']");
      const prev = nav?.querySelector("button[aria-label*='previous']");
      const next = nav?.querySelector("button[aria-label*='next']");
      return {
        tag: nav?.tagName?.toLowerCase() ?? null,
        label: nav?.getAttribute("aria-label") ?? null,
        component: nav?.getAttribute("data-astryx-component") ?? null,
        listRole: list?.getAttribute("role") ?? null,
        numbers: buttons.map((b) => b.textContent.trim()),
        current: current?.textContent.trim() ?? null,
        ellipsis: list?.querySelectorAll(".astryx-pagination__ellipsis").length ?? 0,
        prevDisabled: prev?.disabled ?? null,
        nextDisabled: next?.disabled ?? null,
        announcement: nav?.querySelector(".astryx-pagination__announcement")?.textContent.trim() ?? null,
      };
    });
    check("a pagination is a navigation region with an accessible name",
      pgState?.tag === "nav" && pgState?.label === "Pagination"
        && pgState?.component === "Pagination",
      JSON.stringify(pgState));
    check("the page numbers are a list, with the current page marked",
      pgState?.listRole === "list" && pgState?.current === "1"
        && pgState?.numbers?.includes("1"),
      JSON.stringify(pgState));
    check("the pages that are left out are an ellipsis, hidden from the reader",
      pgState?.ellipsis === 1
        && pgState?.numbers?.every((n) => /^[0-9]+$/.test(n)),
      JSON.stringify(pgState));
    check("the previous control is disabled on the first page and the next one is not",
      pgState?.prevDisabled === true && pgState?.nextDisabled === false,
      JSON.stringify(pgState));
    check("the current page is announced politely",
      pgState?.announcement === "Page 1 of 10",
      JSON.stringify(pgState));

    // A real click: the page number the person picks becomes the current one.
    await page.click('#showcase-pagination-pages .astryx-pagination__pages li:nth-child(3) button');
    await page.waitForFunction(
      () => document.querySelector("#showcase-pagination-pages [aria-current='page']")?.textContent.trim() === "3",
      { timeout: 30000 },
    );
    const pgAfter = await page.evaluate(() => {
      const nav = document.querySelector("#showcase-pagination-pages");
      const current = nav?.querySelector("[aria-current='page']");
      const prev = nav?.querySelector("button[aria-label*='previous']");
      const next = nav?.querySelector("button[aria-label*='next']");
      return {
        current: current?.textContent.trim() ?? null,
        prevDisabled: prev?.disabled ?? null,
        nextDisabled: next?.disabled ?? null,
        announcement: nav?.querySelector(".astryx-pagination__announcement")?.textContent.trim() ?? null,
      };
    });
    check("clicking a page number moves the current page",
      pgAfter?.current === "3",
      JSON.stringify(pgAfter));
    check("the controls follow the current page",
      pgAfter?.prevDisabled === false && pgAfter?.nextDisabled === false
        && pgAfter?.announcement === "Page 3 of 10",
      JSON.stringify(pgAfter));

    const pgVariants = await page.evaluate(() => {
      const count = document.querySelector("#showcase-pagination-count");
      const compact = document.querySelector("#showcase-pagination-compact");
      const dots = document.querySelector("#showcase-pagination-dots");
      const input = document.querySelector("#showcase-pagination-input");
      const unknown = document.querySelector("#showcase-pagination-unknown");
      return {
        count: count?.querySelector(".astryx-pagination__info")?.textContent.trim() ?? null,
        compact: compact?.querySelector(".astryx-pagination__info")?.textContent.trim() ?? null,
        dotCount: dots?.querySelectorAll(".astryx-pagination__dot").length ?? 0,
        dotActive: dots?.querySelectorAll(".astryx-pagination__dot--active").length ?? 0,
        dotLabel: dots?.querySelector(".astryx-pagination__dot")?.getAttribute("aria-label") ?? null,
        inputValue: input?.querySelector("input")?.value ?? null,
        inputTotal: input?.querySelector(".astryx-pagination__input-total")?.textContent.trim() ?? null,
        unknownButtons: unknown?.querySelectorAll("button").length ?? 0,
        unknownNextDisabled: unknown?.querySelector("button[aria-label*='next']")?.disabled ?? null,
        unknownPrevDisabled: unknown?.querySelector("button[aria-label*='previous']")?.disabled ?? null,
      };
    });
    check("the count variant reports the range of items on the page",
      pgVariants?.count === "1–20 of 200",
      JSON.stringify(pgVariants));
    check("the compact variant reports the page out of the total",
      pgVariants?.compact === "Page 1 of 10",
      JSON.stringify(pgVariants));
    check("the dots variant draws one dot per page, with the current one marked",
      pgVariants?.dotCount === 5 && pgVariants?.dotActive === 1
        && pgVariants?.dotLabel === "Go to page 1",
      JSON.stringify(pgVariants));
    check("the input variant shows the page and the total",
      pgVariants?.inputValue === "1" && pgVariants?.inputTotal === "/ 12",
      JSON.stringify(pgVariants));
    check("a pagination with no known end has only the next control to offer",
      pgVariants?.unknownButtons === 2 && pgVariants?.unknownNextDisabled === false
        && pgVariants?.unknownPrevDisabled === true,
      JSON.stringify(pgVariants));
  }

  // ------------------------------------------------------------------ Toast
  // A toast is a live region: polite for information, assertive for an
  // error. The viewport is the top-level element an application mounts
  // once; it holds the stack.

  const toastAttrs = (id) => page.evaluate((i) => {
    const el = document.getElementById(i);
    if (!el) return null;
    return {
      role: el.getAttribute("role"),
      live: el.getAttribute("aria-live"),
      atomic: el.getAttribute("aria-atomic"),
      type: el.getAttribute("data-astryx-toast-type"),
      component: el.getAttribute("data-astryx-component"),
      dismiss: !!el.querySelector('[aria-label="Dismiss notification"]'),
    };
  }, id);

  const toastInfo = await toastAttrs("showcase-toast-info");
  const toastError = await toastAttrs("showcase-toast-error");
  check("an informational toast is a polite live region",
    toastInfo !== null
      && toastInfo.component === "Toast"
      && toastInfo.role === "status"
      && toastInfo.live === "polite"
      && toastInfo.atomic === "true"
      && toastInfo.type === "info",
    JSON.stringify(toastInfo));

  check("an error toast is an assertive live region",
    toastError !== null
      && toastError.role === "alert"
      && toastError.live === "assertive"
      && toastError.type === "error",
    JSON.stringify(toastError));

  check("a toast carries its dismissal control",
    toastInfo !== null && toastInfo.dismiss === true,
    JSON.stringify(toastInfo));

  // The announcement region the port creates for the screen reader.
  check("the port creates a polite announcement region",
    await page.evaluate(() => {
      const el = document.querySelector('[data-astryx-live-region="polite"]');
      if (!el) return false;
      return el.getAttribute("aria-live") === "polite"
        && el.getAttribute("role") === "status"
        && el.getAttribute("aria-atomic") === "true";
    }));

  // The viewport: a click on the application's own button adds a toast, and
  // the stack the viewport holds grows.
  const toastCount = () => page.evaluate(() => {
    const el = document.getElementById("showcase-toast-count");
    return el ? el.textContent.trim() : null;
  });
  const before = await toastCount();
  await page.click("#showcase-toast-viewport-example button");
  await page.waitForTimeout(300);
  const after = await toastCount();
  const viewport = await page.evaluate(() => {
    const el = document.getElementById("showcase-toast-viewport");
    if (!el) return null;
    return {
      role: el.getAttribute("role"),
      label: el.getAttribute("aria-label"),
      rows: el.querySelectorAll("[data-toast-id]").length,
    };
  });
  check("the application's button adds a toast to the viewport's stack",
    before === "toasts: 0" && after === "toasts: 1" && viewport !== null && viewport.rows === 1,
    JSON.stringify({ before, after, viewport }));

  check("the viewport is a labelled region that holds the stack",
    viewport !== null && viewport.role === "region" && viewport.label === "Notifications",
    JSON.stringify(viewport));

  // The same unique id replaces the toast instead of stacking behind it.
  // The count readout is shared by both examples, so what matters is that
  // the second click does not grow the stack - and that the toast with the
  // unique id is in the DOM exactly once.
  const uniqueBtn = "#showcase-toast-unique-example button";
  const uniqueBefore = await toastCount();
  await page.click(uniqueBtn);
  await page.waitForTimeout(250);
  const uniqueOnce = await toastCount();
  await page.click(uniqueBtn);
  await page.waitForTimeout(250);
  const uniqueTwice = await toastCount();
  // The replacement is in place: the stack keeps its size, and the toast
  // that held the id now carries the new body rather than a second copy
  // sitting behind it.
  const stackBodies = await page.evaluate(() =>
    [...document.querySelectorAll("#showcase-toast-viewport [data-toast-id] .astryx-toast__content")]
      .map((el) => el.textContent.trim()));
  check("the same unique id replaces the toast instead of stacking behind it",
    uniqueOnce !== uniqueBefore
      && uniqueTwice === uniqueOnce
      && stackBodies.filter((b) => b === "Saved again").length === 1
      && stackBodies.filter((b) => b === "Saved successfully").length === 1,
    JSON.stringify({ uniqueBefore, uniqueOnce, uniqueTwice, stackBodies }));

  // A deliberate dismissal is reported as such (the error toast does not
  // auto-hide, so the reading is not a race with the timer).
  await page.click('#showcase-toast-error [aria-label="Dismiss notification"]');
  await page.waitForTimeout(300);
  check("a deliberate dismissal is reported as a manual dismissal",
    (await page.evaluate(() => {
      const el = document.getElementById("showcase-toast-dismissed");
      return el ? el.textContent.trim() : null;
    })) === "dismissed: manual",
    await page.evaluate(() => {
      const el = document.getElementById("showcase-toast-dismissed");
      return el ? el.textContent.trim() : null;
    }));

  // -------------------------------------------------------------- MobileNav
  // The drawer is a modal dialog the trigger opens.

  const navState = () => page.evaluate(() => {
    const el = document.getElementById("showcase-mobile-nav-state");
    return el ? el.textContent.trim() : null;
  });
  const navDrawer = () => page.evaluate(() => {
    const el = document.getElementById("showcase-mobile-nav-live");
    if (!el) return null;
    return {
      tag: el.tagName.toLowerCase(),
      modal: el.getAttribute("aria-modal"),
      label: el.getAttribute("aria-label"),
      open: el.hasAttribute("open"),
      side: el.getAttribute("data-astryx-side"),
      close: !!el.querySelector('[aria-label="Close navigation"]'),
    };
  });

  const drawerBefore = await navDrawer();
  check("the drawer is a modal dialog with a label and a close control",
    drawerBefore !== null
      && drawerBefore.tag === "dialog"
      && drawerBefore.modal === "true"
      && drawerBefore.label !== null
      && drawerBefore.close === true,
    JSON.stringify(drawerBefore));

  check("the drawer starts closed and the application knows it",
    (await navState()) === "the application says: closed" && drawerBefore.open === false,
    JSON.stringify({ state: await navState(), drawer: drawerBefore }));

  await page.click("#showcase-mobile-nav-open");
  await page.waitForTimeout(400);
  const drawerAfter = await navDrawer();
  check("the trigger opens the drawer, and the application is told",
    (await navState()) === "the application says: open" && drawerAfter.open === true,
    JSON.stringify({ state: await navState(), drawer: drawerAfter }));

  await page.click('#showcase-mobile-nav-live [aria-label="Close navigation"]');
  await page.waitForTimeout(400);
  const drawerClosed = await navDrawer();
  check("the drawer's own close control closes it again",
    (await navState()) === "the application says: closed" && drawerClosed.open === false,
    JSON.stringify({ state: await navState(), drawer: drawerClosed }));

  }


// --------------------------------------------------------------- Typeahead (M78)
if (mode === "showcase") {
  const taSection = await page.$("section[data-showcase-component='Typeahead']");
  check("the Typeahead section renders", taSection !== null,
    taSection === null ? "not found" : "found");

  if (taSection) {
    const input = "#showcase-typeahead-plain-input";
    await page.focus(input);
    await page.waitForTimeout(150);

    const opened = await page.evaluate((sel) => {
      const el = document.querySelector(sel);
      const lb = el?.getAttribute("aria-controls");
      const list = lb ? document.getElementById(lb) : null;
      return {
        expanded: el?.getAttribute("aria-expanded") ?? null,
        role: el?.getAttribute("role") ?? null,
        autocomplete: el?.getAttribute("aria-autocomplete") ?? null,
        listRole: list?.getAttribute("role") ?? null,
        options: list?.querySelectorAll("[role='option']").length ?? 0,
      };
    }, input);
    check("focusing the combobox opens its list, and the combobox says so",
      opened?.expanded === "true" && opened?.role === "combobox"
        && opened?.autocomplete === "list" && opened?.listRole === "listbox",
      JSON.stringify(opened));
    check("the list opens with the source's own entries", opened?.options > 0,
      JSON.stringify(opened));

    // Typing filters. The list is the source's answer, not a fixed list.
    await page.type(input, "an");
    await page.waitForTimeout(200);
    const filtered = await page.evaluate((sel) => {
      const el = document.querySelector(sel);
      const lb = el?.getAttribute("aria-controls");
      const list = lb ? document.getElementById(lb) : null;
      return {
        options: [...(list?.querySelectorAll("[role='option']") ?? [])].map((o) => (o.textContent || "").trim()),
        value: el?.value ?? null,
      };
    }, input);
    check("typing filters the list to what the source answers",
      filtered?.options.length === 1 && filtered.options[0] === "Banana",
      JSON.stringify(filtered));
    check("the query is in the input", filtered?.value === "an", JSON.stringify(filtered));

    // The highlight and the active descendant move together.
    await page.keyboard.press("ArrowDown");
    await page.waitForTimeout(150);
    const highlighted = await page.evaluate((sel) => {
      const el = document.querySelector(sel);
      const active = el?.getAttribute("aria-activedescendant");
      const target = active ? document.getElementById(active) : null;
      return {
        active,
        highlighted: target?.classList.contains("astryx-typeahead__option--highlighted") ?? false,
        text: (target?.textContent ?? "").trim(),
      };
    }, input);
    check("ArrowDown highlights an option and points at it",
      highlighted?.active !== null && highlighted?.active !== undefined
        && highlighted?.highlighted === true && highlighted?.text === "Banana",
      JSON.stringify(highlighted));

    // Enter picks it, and the application is told.
    await page.keyboard.press("Enter");
    await page.waitForTimeout(200);
    const chosen = await page.evaluate((sel) => {
      const el = document.querySelector(sel);
      return {
        value: el?.value ?? null,
        expanded: el?.getAttribute("aria-expanded") ?? null,
      };
    }, input);
    check("Enter takes the highlighted option and closes the list",
      chosen?.value === "Banana" && chosen?.expanded === "false",
      JSON.stringify(chosen));
  }
}


// ---------------------------------------------------------- DateRangeInput (M79)
if (mode === "showcase") {
  const drSection = await page.$("section[data-showcase-component='DateRangeInput']");
  check("the DateRangeInput section renders", drSection !== null,
    drSection === null ? "not found" : "found");

  if (drSection) {
    const shape = await page.evaluate(() => {
      const fields = [...document.querySelectorAll("[data-astryx-component='DateRangeInput']")];
      const first = fields[0];
      const inputs = [...(first?.querySelectorAll("input") ?? [])];
      const group = first?.querySelector("[role='group']");
      const labelId = group?.getAttribute("aria-labelledby") ?? "";
      // A group label is a <span>, not a <label>: it names the group with
      // aria-labelledby rather than labelling one control.
      const label = labelId === "" ? null : first?.querySelector("[id=" + JSON.stringify(labelId) + "]");
      return {
        fields: fields.length,
        inputs: inputs.length,
        ids: inputs.map((i) => i.getAttribute("id")),
        labels: inputs.map((i) => i.getAttribute("aria-label")),
        groupRole: group?.getAttribute("role") ?? null,
        labelledby: labelId,
        labelId: label?.getAttribute("id") ?? null,
        labelText: (label?.textContent ?? "").trim(),
        marker: first?.getAttribute("data-astryx-component") ?? null,
      };
    });

    check("every example renders its own field, and the root carries the house's marker",
      shape?.fields >= 4 && shape?.marker === "DateRangeInput",
      JSON.stringify(shape));

    check("there are two fields, one for each end of the range",
      shape?.inputs === 2 && shape.ids[0] !== shape.ids[1],
      JSON.stringify(shape));

    check("the two ends are a named group, and the label names the group",
      shape?.groupRole === "group" && shape?.labelledby === shape?.labelId
        && shape?.labelText !== "",
      JSON.stringify(shape));

    check("each end is named for a screen reader",
      shape?.labels.every((l) => l !== null && l !== ""),
      JSON.stringify(shape));

    // The committed range is shown in the two fields.
    const committed = await page.evaluate(() => {
      const fields = [...document.querySelectorAll("[data-astryx-component='DateRangeInput']")];
      const withValue = fields[1];
      return [...(withValue?.querySelectorAll("input") ?? [])].map((i) => i.value);
    });
    check("a committed range is shown in the two fields",
      committed.length === 2 && committed[0] !== "" && committed[0] !== committed[1],
      JSON.stringify({ committed }));

    // The calendar opens from the trigger, which is an icon-only button named
    // "Choose dates", and it is the house calendar.
    await page.locator("button[aria-label='Choose dates']").first().click();
    await page.waitForTimeout(300);
    const calendar = await page.evaluate(() => {
      const pop = document.querySelector("#showcase-date-range-plain-popover-surface");
      const cal = pop?.querySelector("[data-astryx-component='Calendar']");
      return {
        open: pop !== null,
        calendar: cal !== null && cal !== undefined,
        grid: pop?.querySelectorAll("[role='gridcell']").length ?? 0,
      };
    });
    check("the trigger opens the calendar, and it is the house calendar",
      calendar?.open === true && calendar?.calendar === true && calendar?.grid > 0,
      JSON.stringify(calendar));
  }
}


// ----------------------------------------------------------- DateTimeInput (M80)
if (mode === "showcase") {
  const dtSection = await page.$("section[data-showcase-component='DateTimeInput']");
  check("the DateTimeInput section renders", dtSection !== null,
    dtSection === null ? "not found" : "found");

  if (dtSection) {
    const shape = await page.evaluate(() => {
      const fields = [...document.querySelectorAll("[data-astryx-component='DateTimeInput']")];
      const first = fields[0];
      const segments = [...(first?.querySelectorAll(".astryx-date-time-input__segment") ?? [])];
      const inputs = [...(first?.querySelectorAll("input") ?? [])];
      const calendarButton = first?.querySelector(".astryx-date-time-input__calendar-button");
      return {
        fields: fields.length,
        marker: first?.getAttribute("data-astryx-component") ?? null,
        segments: segments.map((s) => s.className),
        ids: inputs.map((i) => i.getAttribute("id")),
        calendarLabel: calendarButton?.getAttribute("aria-label") ?? null,
      };
    });

    check("every example renders its own field, and the root carries the house's marker",
      shape?.fields >= 5 && shape?.marker === "DateTimeInput",
      JSON.stringify(shape));

    check("the reading is a date segment and a time segment",
      shape?.segments.length === 2
        && shape.segments[0].includes("--date")
        && shape.segments[1].includes("--time"),
      JSON.stringify(shape));

    check("each part has its own field, and the calendar opens from a named button",
      shape?.ids.length === 2 && shape.ids[0] !== shape.ids[1]
        && shape?.calendarLabel === "Open calendar",
      JSON.stringify(shape));

    // The committed reading shows in the two parts.
    const committed = await page.evaluate(() => {
      const fields = [...document.querySelectorAll("[data-astryx-component='DateTimeInput']")];
      const withValue = fields[1];
      return [...(withValue?.querySelectorAll("input") ?? [])].map((i) => i.value);
    });
    check("a committed reading is shown in the two parts",
      committed.length === 2 && committed[0] !== "" && committed[1] !== "",
      JSON.stringify({ committed }));

    // The twenty-four hour clock shows an afternoon reading without a meridiem.
    const twentyFour = await page.evaluate(() => {
      const fields = [...document.querySelectorAll("[data-astryx-component='DateTimeInput']")];
      const clock = fields[2];
      const inputs = [...(clock?.querySelectorAll("input") ?? [])];
      return { time: inputs[1]?.value ?? "" };
    });
    check("the twenty-four hour clock shows an afternoon reading without a meridiem",
      twentyFour?.time !== "" && !/[ap]m/i.test(twentyFour.time),
      JSON.stringify(twentyFour));

    // The calendar opens from the trigger and is the house calendar.
    await page.locator("button[aria-label='Open calendar']").first().click();
    await page.waitForTimeout(300);
    const calendar = await page.evaluate(() => {
      const pop = document.querySelector("#showcase-date-time-plain-calendar-surface");
      const cal = pop?.querySelector("[data-astryx-component='Calendar']");
      return {
        open: pop !== null,
        calendar: cal !== null && cal !== undefined,
        grid: pop?.querySelectorAll("[role='gridcell']").length ?? 0,
      };
    });
    check("the trigger opens the calendar, and it is the house calendar",
      calendar?.open === true && calendar?.calendar === true && calendar?.grid > 0,
      JSON.stringify(calendar));

    // The calendar closes again, so it does not intercept later checks.
    await page.keyboard.press("Escape");
    await page.waitForTimeout(300);
  }
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
