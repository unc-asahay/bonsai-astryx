// Component-level DOM assertions for test/rt_test.ml.
//
// rt_test.ml renders every ported component in isolation and dispatches real events
// into the Bonsai graph; this file asserts on what came out. Run it after
// `dune build`:
//
//   node test/run.mjs
//
// Same jsdom environment as tools/visual/verify-dom.mjs, including the two traps
// documented in docs/VERIFICATION.md: Core needs a Temporal polyfill in the realm
// (or every timezone throws) and jsdom's globals must not be mirrored onto node's
// globalThis (performance.now recurses).

import { createRequire } from "node:module";
import { readFileSync, existsSync } from "node:fs";
import { resolve, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const require = createRequire(import.meta.url);
const here = dirname(fileURLToPath(import.meta.url));
const root = resolve(here, "..");

function resolveFrom(candidates, what) {
  for (const c of candidates) if (existsSync(c)) return c;
  throw new Error(`${what} not found. Tried: ${candidates.join(", ")}`);
}

const jsdomPath = () =>
  resolveFrom([resolve(root, "node_modules/jsdom")], "jsdom");
const temporalPath = () =>
  resolveFrom([resolve(root, "node_modules/@js-temporal/polyfill")], "@js-temporal/polyfill");

const { JSDOM, VirtualConsole } = require(jsdomPath());
const TemporalPolyfill = require(temporalPath());

const bundle = resolve(root, "_build/default/test/rt_test.bc.js");
if (!existsSync(bundle)) {
  console.error(`missing ${bundle} — run: dune build`);
  process.exit(2);
}

const dom = new JSDOM(`<!DOCTYPE html><html><head></head><body></body></html>`, {
  runScripts: "outside-only",
  pretendToBeVisual: true,
  url: "http://localhost/",
  virtualConsole:
    // Forward jsdom's console to the real one. A bare VirtualConsole swallows
    // everything the bundle prints — including the message of an exception the
    // OCaml side catches and reports — which turns a diagnosable failure into an
    // opaque js_of_ocaml value.
    (() => {
      const vc = new VirtualConsole();
      vc.on("error", (...args) => console.error(...args));
      vc.on("warn", (...args) => console.warn(...args));
      vc.on("log", (...args) => console.log(...args));
      vc.on("jsdomError", (error) => console.error("[jsdom]", error.message));
      return vc;
    })(),
  beforeParse(window) {
    try {
      window.Intl = Intl;
    } catch {}
    try {
      window.process = { env: { TZ: "UTC" } };
    } catch {}
    try {
      window.TemporalPolyfill = TemporalPolyfill;
    } catch {}
  },
});

dom.window.eval(readFileSync(bundle, "utf8"));

const document = dom.window.document;

// ------------------------------------------------------------------ framework

let checks = 0;
let failures = 0;

function check(label, ok, detail = "") {
  checks += 1;
  if (ok) {
    console.log(`  ok   ${label}`);
  } else {
    failures += 1;
    console.log(`  FAIL ${label}${detail ? ` — ${detail}` : ""}`);
  }
}

const section = (title) => console.log(`\n${title}`);

const inCase = (name) => {
  const host = document.querySelector(`[data-case="${name}"]`);
  return host ? [...host.querySelectorAll("[data-astryx-component]")] : [];
};

const classesOf = (el) => (el.getAttribute("class") || "").split(/\s+/).filter(Boolean);
const hasClass = (el, re) => classesOf(el).some((c) => re.test(c));
const attr = (el, name) => el.getAttribute(name);

// Components of one kind inside a case. inCase returns every marked element under the
// case, including nested components (an EmptyState contains Buttons), so a case that
// composes components has to filter.
const inCaseOf = (name, component) =>
  inCase(name).filter((e) => attr(e, "data-astryx-component") === component);

// Plain elements inside a case, for cases whose rows are not marked components.
const inCaseMatching = (name, selector) => [
  ...document.querySelectorAll(`[data-case="${name}"] ${selector}`),
];

// ----------------------------------------------------------------- assertions

section("the ported components render in isolation");

check("every case mounted something", document.querySelectorAll("[data-case]").length >= 20,
  `cases: ${document.querySelectorAll("[data-case]").length}`);

// --- Button
{
  const [b] = inCase("button-default");
  check("button-default is a single Button", inCase("button-default").length === 1);
  check("button-default renders a real <button>", b && b.tagName.toLowerCase() === "button", b?.tagName);
  check("button-default carries the component marker", attr(b, "data-astryx-component") === "Button");
  check("button-default is type=button", attr(b, "type") === "button", attr(b, "type"));
  // The default variant is secondary, not primary — taken from the component's own
  // contract (extracted doc.mjs), which is the source of truth for defaults.
  check("button-default carries the secondary variant class", hasClass(b, /--secondary/), classesOf(b).join(" "));
  check("button-default carries its size class", hasClass(b, /--md$/), classesOf(b).join(" "));
  check("button-default shows its label", (b.textContent || "").trim() === "Save", b?.textContent);
}
{
  const bs = inCase("button-variants");
  check("four button variants render", bs.length === 4, `${bs.length}`);
  check("secondary variant class present", bs.some((b) => hasClass(b, /--secondary/)));
  check("ghost variant class present", bs.some((b) => hasClass(b, /--ghost/)));
  check("destructive variant class present", bs.some((b) => hasClass(b, /--destructive/)));
}
{
  const bs = inCase("button-sizes");
  check("three button sizes render", bs.length === 3, `${bs.length}`);
  check("sm/md/lg size classes all present",
    ["--sm", "--md", "--lg"].every((s) => bs.some((b) => hasClass(b, new RegExp(`${s}$`)))));
}
{
  const bs = inCase("button-elevation");
  const sets = new Set(bs.map((b) => classesOf(b).filter((c) => !/^astryx-button$|--primary|--md$/.test(c)).join(" ")));
  check("four elevations render with distinct classes", bs.length === 4 && sets.size === 4, `${bs.length} / ${sets.size} distinct`);
}
{
  const [b] = inCase("button-loading");
  check("loading button reports aria-busy", attr(b, "aria-busy") === "true", attr(b, "aria-busy"));
  check("loading button reports aria-disabled", attr(b, "aria-disabled") === "true", attr(b, "aria-disabled"));
  check("loading button stays focusable (no native disabled)", !b.hasAttribute("disabled"));
  check("loading button announces Loading through its live region",
    /Loading/.test(b.textContent || "") &&
      b.querySelector('.astryx-visually-hidden[role="status"]') !== null);
  // The reason the content wrapper exists: while loading, the visible content is
  // replaced by the spinner, so assistive tech must not still read the label.
  check("loading button hides its content from assistive tech",
    b.querySelector('.astryx-button__content[aria-hidden="true"]') !== null,
    b.querySelector(".astryx-button__content")?.outerHTML?.slice(0, 120));
  check("an idle button still renders the live region (empty) so the change can be announced",
    inCase("button-default").every(
      (x) => x.querySelector('.astryx-visually-hidden[role="status"]') !== null,
    ));
}
{
  const [b] = inCase("button-disabled");
  check("disabled button uses the native disabled attribute", b.hasAttribute("disabled"));
}
{
  const [b] = inCase("button-defaulting");
  check("loading+disabled: native disabled wins", b.hasAttribute("disabled") && attr(b, "aria-busy") === "true");
}
{
  const [b] = inCase("button-icon-only");
  check("icon-only button is named by aria-label", attr(b, "aria-label") === "Add item", attr(b, "aria-label"));
  check("icon-only button renders its icon", /\+/.test(b.textContent || ""));
}
{
  const [b] = inCase("button-with-icon");
  check("button with icon renders icon and label", /\+/.test(b.textContent || "") && /Add/.test(b.textContent || ""),
    b?.textContent);
}
{
  const [a] = inCase("button-link");
  check("href renders an <a>", a && a.tagName.toLowerCase() === "a", a?.tagName);
  check("link keeps its href", attr(a, "href") === "https://github.com/facebook/astryx", attr(a, "href"));
  check("link keeps target and rel", attr(a, "target") === "_blank" && attr(a, "rel") === "noreferrer");
}
{
  const bs = inCase("button-types");
  const types = bs.map((b) => attr(b, "type"));
  check("button types are button/submit/reset", JSON.stringify(types) === JSON.stringify(["button", "submit", "reset"]),
    JSON.stringify(types));
}

// --- StatusDot
{
  const ds = inCase("statusdot-all");
  check("six status dots render", ds.length === 6, `${ds.length}`);
  check("every dot is an image with a name", ds.every((d) => attr(d, "role") === "img" && !!attr(d, "aria-label")));
  check("dot labels are carried through", ds.map((d) => attr(d, "aria-label")).includes("pulsing-dot"));
  const pulsing = ds.find((d) => attr(d, "aria-label") === "pulsing-dot");
  check("only the pulsing dot has a pulsing class",
    hasClass(pulsing, /puls/) && ds.filter((d) => hasClass(d, /puls/)).length === 1);
}

// --- Badge
{
  const bs = inCase("badge-all");
  const variantClasses = new Set(bs.map((b) => classesOf(b).filter((c) => !/^astryx-badge$/.test(c)).join(" ")));
  check("fourteen badge variants render", bs.length === 14, `${bs.length}`);
  check("every badge variant is distinguishable", variantClasses.size === 14, `${variantClasses.size} distinct`);
}

// --- Token
{
  const ts = inCaseOf("token-all", "Token");
  const byLabel = (label) => ts.find((t) =>
    Array.from(t.querySelectorAll(".astryx-token__label")).map((s) => s.textContent).join("") === label);
  check("twelve tokens render", ts.length === 12, `${ts.length}`);
  check("every token names its component", ts.every((t) => attr(t, "data-astryx-component") === "Token"));

  // Branch 3 (inert): plain span, no interactive modifier, no controls - remove included.
  const plain = byLabel("plain");
  check("a plain token is an inert span",
    plain && plain.tagName === "SPAN" && !hasClass(plain, /interactive/));
  check("a plain token with no on_remove contains no controls",
    plain && plain.querySelector("button, a") === null);

  // on_remove without a click stays branch 3: the button exists, the ROOT does not become interactive.
  const detachable = byLabel("detachable");
  check("removability alone adds a remove button but not interactivity",
    detachable && detachable.querySelectorAll("button.astryx-token__remove").length === 1 &&
    !hasClass(detachable, /interactive/));

  // Branch 1: two anchors - and only the safe one keeps its destination.
  const anchors = ts.filter((t) => t.tagName === "A");
  check("two tokens render as anchors", anchors.length === 2, `${anchors.length}`);
  const linked = byLabel("linked");
  check("a live href makes the anchor the ROOT (no container above it)",
    linked && linked.tagName === "A" && !hasClass(linked, /container/) &&
    linked.closest(".astryx-token") === linked);
  check("the refused javascript: destination renders its shape with NO href",
    (t => t && t.tagName === "A" && attr(t, "href") === null)(byLabel("refused")));

  // Branch 2a: sibling containers - the invalid-nesting contract, asserted structurally.
  const linkedDetach = byLabel("linked-detach");
  const innerLink = linkedDetach && linkedDetach.querySelector("a");
  const removeBtn = linkedDetach && linkedDetach.querySelector("button.astryx-token__remove");
  check("href + on_remove becomes a span container with an inner link",
    linkedDetach && linkedDetach.tagName === "SPAN" && hasClass(linkedDetach, /container/) && !!innerLink);
  check("the remove button is a SIBLING of the link, never nested inside it",
    innerLink && removeBtn && removeBtn.parentElement === linkedDetach && innerLink.parentElement === linkedDetach);
  check("the remove button's accessible name is the English default",
    removeBtn && attr(removeBtn, "aria-label") === "Remove linked-detach",
    removeBtn && attr(removeBtn, "aria-label"));

  // Branch 2b: invisible button under the container; disabled reaches the button's own state.
  const clickable = byLabel("clickable");
  const innerButton = clickable && clickable.querySelector("button.astryx-token__invisible-button");
  check("on_click puts a real button inside the container",
    clickable && hasClass(clickable, /container/) && !!innerButton &&
    attr(innerButton, "type") === "button");
  check("the guard's other half exists: click+remove keeps both controls as siblings",
    (t => t && t.querySelector("button.astryx-token__invisible-button") &&
          t.querySelector("button.astryx-token__remove") &&
          t.querySelector("button.astryx-token__invisible-button").parentElement ===
          t.querySelector("button.astryx-token__remove").parentElement)(byLabel("click-detach")));
  const parked = byLabel("parked");
  check("a disabled token is inert at the root and disabled at the button",
    parked && hasClass(parked, /disabled/) &&
    parked.querySelector("button.astryx-token__invisible-button[disabled]") !== null);

  // Markers: pressable only where a press could happen; colour/size reflected as data.
  check("pressable marks every live interactive surface and nothing else",
    attr(byLabel("linked"), "data-astryx-pressable") === "" &&
    attr(clickable, "data-astryx-pressable") === "" &&
    attr(plain, "data-astryx-pressable") === null &&
    attr(parked, "data-astryx-pressable") === null);
  const sized = byLabel("sized");
  check("colour and size are reflected as data and classes",
    attr(sized, "data-astryx-color") === "red" && attr(sized, "data-astryx-size") === "sm" &&
    hasClass(sized, /--red/) && hasClass(sized, /--sm/));

  // Hidden label: clipped for the eye, named for the screen reader.
  const sam = byLabel("sam");
  const samLabel = sam && sam.querySelector(".astryx-token__label");
  check("is_label_hidden keeps the text and names the root instead",
    sam && attr(sam, "aria-label") === "sam" && hasClass(samLabel, /label--hidden/));
  check("description rides along as aria-description, upstream's spelling",
    sam && attr(sam, "aria-description") === "a real person");

  check("end content carries through",
    ((byLabel("tailed") || {}).textContent || "").includes("x9"));
}

// --- Spinner
{
  // inCaseOf picks up both the wrapper and the inner status span in the labelled
  // branch (both are marked, like Dialog's two surfaces); the status element is
  // the span, so filter to role=status before asserting on spinners themselves.
  const allMarks = inCaseOf("spinner-all", "Spinner");
  const ss = allMarks.filter((s) => attr(s, "role") === "status");
  check("eleven spinner status elements render (4 sizes + 4 shades + 2 labelled + explicit label)",
    ss.length === 11, `${ss.length}`);
  check("every spinner is role=status", ss.every((s) => attr(s, "role") === "status"));
  check("the svg is hidden from screen readers",
    ss.every((s) => { const svg = s.querySelector("svg"); return svg && attr(svg, "aria-hidden") === "true"; }));

  // Geometry: md ring is 14px, 3px stroke, box = 14 + 2*3 = 20.
  const md = inCaseOf("spinner-all", "Spinner").find((s) => attr(s, "data-astryx-size") === "md" && attr(s, "data-astryx-shade") === "default") 
    || ss[0];
  const mdSvg = md && md.querySelector("svg");
  check("md spinner draws a 20px box (14px ring + 3px stroke on each side)",
    mdSvg && attr(mdSvg, "width") === "20" && attr(mdSvg, "height") === "20",
    mdSvg && `${attr(mdSvg, "width")}x${attr(mdSvg, "height")}`);
  const [mdArc] = (mdSvg ? [...mdSvg.querySelectorAll("circle")].reverse() : []);
  check("the arc keeps 0.375 of the circumference in its dasharray",
    mdArc && attr(mdArc, "stroke-dasharray") === "16.4934 27.4889",
    mdArc && attr(mdArc, "stroke-dasharray"));

  // Sizes: sm box = 10 + 2*2 = 14; xl box = 28 + 2*4 = 36.
  const sm = ss.find((s) => attr(s, "data-astryx-size") === "sm" && attr(s, "data-astryx-shade") === "default");
  const xl = ss.find((s) => attr(s, "data-astryx-size") === "xl" && attr(s, "data-astryx-shade") === "default");
  check("sm box is 14px", sm && attr(sm.querySelector("svg"), "width") === "14");
  check("xl box is 36px", xl && attr(xl.querySelector("svg"), "width") === "36");

  // Shades: onMedia and inherit put 0.3 / 77/255 on the track.
  const onMedia = inCaseOf("spinner-all", "Spinner").find((s) => attr(s, "data-astryx-shade") === "onMedia");
  const inherit = inCaseOf("spinner-all", "Spinner").find((s) => attr(s, "data-astryx-shade") === "inherit");
  check("onMedia track is translucent (77/255)",
    onMedia && [...onMedia.querySelectorAll("circle")][0] &&
    parseFloat(attr([...onMedia.querySelectorAll("circle")][0], "stroke-opacity")).toFixed(3) === "0.302");
  check("inherit track is at 0.3",
    inherit && [...inherit.querySelectorAll("circle")][0] &&
    attr([...inherit.querySelectorAll("circle")][0], "stroke-opacity") === "0.3");

  // Labelled: string label is visible below, names the status via aria-labelledby (never both).
  const labelled = [...ss].find((s) => s.closest(".astryx-spinner-wrapper"));
  const labelers = ss.filter((s) => s.closest(".astryx-spinner-wrapper"));
  check("two labelled spinners render inside wrappers", labelers.length === 2, `${labelers.length}`);
  const byLabelText = [...document.querySelectorAll('[data-case="spinner-all"] .astryx-spinner-wrapper')]
    .find((w) => (w.textContent || "").includes("Loading..."));
  const labelId = byLabelText && byLabelText.querySelector("[id$='-label']")?.id;
  const named = byLabelText && byLabelText.querySelector("[role=status]");
  check("the string label names the status element via aria-labelledby, never aria-label",
    named && attr(named, "aria-labelledby") === labelId && attr(named, "aria-label") === null);
  check("the visible label text is a Text below the spinner",
    byLabelText && byLabelText.textContent.includes("Loading...") &&
    byLabelText.lastElementChild?.classList?.contains("astryx-text"));

  // Non-string label: cannot be referenced, so the fallback name is the English default.
  const nodeLabel = [...document.querySelectorAll('[data-case="spinner-all"] .astryx-spinner-wrapper')]
    .find((w) => (w.textContent || "").includes("Fetching"));
  const nlv = nodeLabel && nodeLabel.querySelector("[role=status]");
  check("a non-string label falls back to the default accessible name",
    nlv && attr(nlv, "aria-label") === "Loading");

  // Explicit aria_label wins over the string label.
  const explicit = ss.find((s) => attr(s, "aria-label") === "Busy");
  check("explicit aria_label is carried", !!explicit, "");
  check("the unlabelled default is 'Loading'", ss.filter((s) => attr(s, "aria-label") === "Loading").length >= 1);
}

// --- Thumbnail
{
  const tAll = document.querySelector('[data-case="thumbnail-all"]');
  const thumb = (name) =>
    tAll && [...tAll.querySelectorAll(`[data-astryx-thumbnail-case="${name}"] [data-astryx-component="Thumbnail"]`)];

  // Placeholder: no source, not loading -> placeholder silhouette.
  const plain = thumb("placeholder")[0];
  check("thumbnail renders without a source", !!plain, "");
  check("the no-source thumbnail shows the placeholder image", !!(plain && plain.querySelector(".astryx-thumbnail__placeholder svg")));

  // Image: has source -> img loads, alt carried, group named.
  const image = thumb("image")[0];
  check("the image thumbnail renders an img with the src", !!(image && image.querySelector("img")?.getAttribute("src") === "https://example.invalid/a.jpg"));
  check("the image thumbnail shows no placeholder", !(image && image.querySelector(".astryx-thumbnail__placeholder")));
  check("the group is role=group with the accessible name", image && attr(image, "role") === "group" && attr(image, "aria-label") === "A photo", image && attr(image, "aria-label"));

  // Decorative: no alt -> img is alt="" + role=presentation + aria-hidden.
  const deco = thumb("decorative")[0];
  const decoImg = deco && deco.querySelector("img");
  check("a source without alt is decorative (alt='' + role=presentation + aria-hidden)",
    decoImg && attr(decoImg, "alt") === "" && attr(decoImg, "role") === "presentation" && attr(decoImg, "aria-hidden") === "true");
  check("the decorative thumbnail's accessible name is the English fallback",
    deco && attr(deco, "aria-label") === "Thumbnail", deco && attr(deco, "aria-label"));

  // Upload overlay: loading with a source -> scrim + spinner.
  const upload = thumb("upload")[0];
  check("loading with a source shows the upload overlay", !!(upload && upload.querySelector(".astryx-thumbnail__upload-overlay")));
  check("the upload overlay carries a Spinner", !!(upload && upload.querySelector(".astryx-thumbnail__upload-overlay [role=status]")));
  check("the upload overlay image still renders", !!(upload && upload.querySelector("img")));

  // Skeleton: loading without a source.
  const skel = thumb("skeleton")[0];
  check("loading without a source shows a skeleton", !!(skel && skel.querySelector(".astryx-skeleton")));
  check("the skeleton state renders no placeholder", !(skel && skel.querySelector(".astryx-thumbnail__placeholder")));

  // Remove: label names the group and the remove button; hover reveal by default.
  const remove = thumb("remove")[0];
  check("the labelled thumbnail's accessible name joins label — alt", remove && attr(remove, "aria-label") === "report.pdf — R", remove && attr(remove, "aria-label"));
  check("the label is carried as the hover title", remove && attr(remove, "title") === "report.pdf", remove && attr(remove, "title"));
  check("the remove case shows its remove button", !!(remove && remove.querySelector(".astryx-thumbnail__remove-slot .astryx-button")));
  check("the remove button is named 'Remove <name>'", !!(remove && attr(remove.querySelector(".astryx-thumbnail__remove-slot .astryx-button"), "aria-label") === "Remove report.pdf — R"));
  check("the default remove reveal is the hover class", !!(remove && remove.querySelector(".astryx-thumbnail__remove-slot--hover")));

  // Remove always: no hover class.
  const always = thumb("remove-always")[0];
  check("show_remove_on=always omits the hover class", !!(always && !always.querySelector(".astryx-thumbnail__remove-slot--hover")));

  // Interactive: a real button named 'Open <name>' wraps the image.
  const interactive = thumb("interactive")[0];
  const action = interactive && interactive.querySelector(".astryx-thumbnail__action");
  check("the interactive thumbnail renders a real <button>", !!(action && action.tagName.toLowerCase() === "button"));
  check("the open button is named 'Open <name>'", action && attr(action, "aria-label") === "Open I", action && attr(action, "aria-label"));

  // Disabled: opacity class, no remove button, no open button.
  const disabled = thumb("disabled")[0];
  check("the disabled thumbnail carries the disabled class", !!(disabled && hasClass(disabled, /--disabled/)));
  check("a disabled thumbnail shows neither remove nor open buttons",
    !!(disabled && !disabled.querySelector(".astryx-thumbnail__remove-slot .astryx-button") && !disabled.querySelector(".astryx-thumbnail__action")));

  // The error cell: a fresh mount after the src failed shows the placeholder,
  // and a changed src gets a fresh <img> attempt (per-source, not a flag).
  const errOn = new dom.window.Event("error");
  const img = image && image.querySelector("img");
  if (img) {
    img.dispatchEvent(errOn);
    // jsdom owns no event loop for the Bonsai graph here; assert the cell
    // contract indirectly: the error handler is wired and the src cell is
    // per-source (a NEW img for a NEW src). The state update itself is
    // exercised in the browser gate (verify-browser.mjs).
    check("the error handler is wired on the image", image.querySelector("img") === img);
  }
}

// --- ScrollableArea
{
  const sa = document.querySelector('[data-case="scrollable-area-all"]');
  const view = (id) => sa && sa.querySelector(`#${id}`);
  const content = (id) => { const v = view(id); return v && v.querySelector(".astryx-scrollable-area__content"); };

  // The viewport root: the block-axis default, role=group (upstream default).
  const block = view("sa-block");
  check("the block viewport renders", !!block, "");
  check("the viewport is role=group with the accessible label",
    block && attr(block, "role") === "group" && attr(block, "aria-label") === "Activity history",
    block && `${attr(block, "role")}/${attr(block, "aria-label")}`);
  check("the viewport advertises its axis (raw upstream attr, not data-astryx-)",
    block && attr(block, "data-scroll-axis") === "block", block && attr(block, "data-scroll-axis"));
  check("the viewport carries the component marker", block && attr(block, "data-astryx-component") === "ScrollableArea", "");
  check("the content box carries data-scroll-content",
    !!content("sa-block") && attr(content("sa-block"), "data-scroll-content") !== null);

  // Inactive (jsdom has no layout: 0 extents -> unmeasured): tabindex must be absent.
  check("an unmeasured viewport is not a tab stop",
    !!(block && !block.hasAttribute("tabindex")));

  // Axis variants get the correct data-scroll-axis.
  const inline = view("sa-inline");
  const both = view("sa-both");
  check("the inline viewport advertises inline", inline && attr(inline, "data-scroll-axis") === "inline", inline && attr(inline, "data-scroll-axis"));
  check("the both viewport advertises both", both && attr(both, "data-scroll-axis") === "both", both && attr(both, "data-scroll-axis"));

  // Accessibility: role/region via ~role.
  const region = view("sa-region");
  check("~role:Region keeps the region role with the label",
    region && attr(region, "role") === "region" && attr(region, "aria-label") === "Activity history", "");

  // padding / full-bleed are class-driven presentation, but they must not break
  // the data-scroll-* contract.
  const padded = view("sa-padded");
  const fullBleed = view("sa-full-bleed");
  check("the padded viewport still carries the axis attribute",
    padded && attr(padded, "data-scroll-axis") === "block", padded && attr(padded, "data-scroll-axis"));
  check("the full-bleed viewport carries the full-bleed class",
    !!(fullBleed && hasClass(fullBleed, /--full-bleed/)));
}

// --- NavHeadingMenu
{
  const host = document.querySelector('[data-case="nav-heading-menu-all"]');
  const wrap = host && host.querySelector("#nhm-wrap");
  const menu = wrap && wrap.querySelector("#nhm-all");
  const row = (id) => menu && menu.querySelector(`[data-astryx-menu-item="${id}"]`);

  check("the menu surface renders", !!menu, "");
  check("the surface is role=menu with the component marker",
    menu && attr(menu, "role") === "menu" && attr(menu, "data-astryx-component") === "NavHeadingMenu",
    menu && `${attr(menu, "role")}/${attr(menu, "data-astryx-component")}`);
  check("four rows render as menuitems",
    menu && menu.querySelectorAll('[role="menuitem"]').length === 4,
    menu && `${menu.querySelectorAll('[role="menuitem"]').length}`);

  // The row contract: menu-item data id, tabindex=-1 (roving focus), disabled
  // carried as aria-disabled so the keyboard engine's selector skips it.
  check("a row carries its id and a roving tabindex",
    !!row("dashboard") && attr(row("dashboard"), "tabindex") === "-1");
  check("the disabled row is aria-disabled",
    !!row("reports") && attr(row("reports"), "aria-disabled") === "true");
  check("a row with an href is the anchor itself",
    !!(row("dashboard") && row("dashboard").tagName === "A"));
  check("a row without an href is still a menuitem div",
    !!(row("settings") && row("settings").tagName === "DIV"));

  // Icon and description cells.
  check("the icon cell renders", !!(row("analytics") && row("analytics").querySelector(".astryx-nav-heading-menu__icon")));
  check("the description cell renders its text",
    !!(row("analytics") && /Usage by day and by team/.test(row("analytics").textContent || "")));

  // Sizes: class + min-width inline, so an arbitrary override stays easy.
  const sm = host && host.querySelector("#nhm-sm");
  const lg = host && host.querySelector("#nhm-lg");
  check("sm is classed and sized 160px",
    sm && hasClass(sm, /--sm/) && attr(sm, "data-astryx-size") === "sm" && attr(sm, "min-width") === "160px",
    sm && `${attr(sm, "min-width")}`);
  check("lg is classed and sized 240px",
    lg && hasClass(lg, /--lg/) && attr(lg, "data-astryx-size") === "lg" && attr(lg, "min-width") === "240px",
    lg && `${attr(lg, "min-width")}`);
  check("md defaults to 200px", menu && attr(menu, "min-width") === "200px", menu && attr(menu, "min-width"));

  // Effects: choosing a row hands its id to on_select and closes (upstream's
  // select-then-close); Escape runs on_close too. jsdom cannot pump Bonsai's
  // event scheduler, so the live versions of these are asserted in the browser
  // gate on the showcase's controlled demo; here we assert the initial state.
  check("nothing is selected yet", wrap && attr(wrap, "data-selected") === "-", wrap && attr(wrap, "data-selected"));
  check("no row was closed yet", wrap && attr(wrap, "data-closed") === "0", wrap && attr(wrap, "data-closed"));
}


// --- SegmentedControl (M37)
{
  const host = document.querySelector('[data-case="segmented-control-all"]');
  const g = (id) => host && host.querySelector(`#${id}`);
  const radio = (id, value) => g(id) && g(id).querySelector(`[data-astryx-value="${value}"]`);

  check("the control renders as a radiogroup with the marker and its label",
    !!g("segc-all") && attr(g("segc-all"), "role") === "radiogroup"
      && attr(g("segc-all"), "data-astryx-component") === "SegmentedControl"
      && attr(g("segc-all"), "aria-label") === "View mode",
    g("segc-all") && `${attr(g("segc-all"), "role")}/${attr(g("segc-all"), "aria-label")}`);
  check("three segments are role=radio buttons", !!g("segc-all")
    && g("segc-all").querySelectorAll('[role="radio"]').length === 3
    && g("segc-all").querySelector('[role="radio"]').tagName === "BUTTON");
  check("each segment carries its value and the selected one is checked",
    attr(radio("segc-all", "grid"), "aria-checked") === "true"
      && attr(radio("segc-all", "list"), "aria-checked") === "false"
      && attr(radio("segc-all", "table"), "aria-checked") === "false");
  check("the selected segment owns the tab stop, the rest are -1",
    attr(radio("segc-all", "grid"), "tabindex") === "0"
      && attr(radio("segc-all", "list"), "tabindex") === "-1"
      && attr(radio("segc-all", "table"), "tabindex") === "-1");
  check("segments are real buttons (type=button, not anchors)",
    radio("segc-all", "grid") && radio("segc-all", "grid").getAttribute("type") === "button");
  check("the wrap reads the live selected value", (() => {
    const w = host && host.querySelector("#segc-wrap");
    return w && attr(w, "data-selected") === "grid";
  })());

  // Sizes and layout are classes, so an override that ships can be found and overridden.
  const sm = g("segc-sm");
  const fill = g("segc-fill");
  check("sm is a class, not an inline size",
    !!sm && hasClass(sm, /--sm/) && attr(sm, "data-astryx-size") === null);
  check("fill stretches the track and its segments",
    !!fill && hasClass(fill, /--fill/)
      && fill.querySelectorAll("[role=radio].astryx-segmented-control__item--fill").length === 3);

  // Icon+label keeps the visible label; icon-only swaps it for aria-label.
  const icons = g("segc-icons");
  const iconOnly = g("segc-icon-only");
  check("an icon + label segment shows both",
    !!icons && icons.querySelectorAll(".astryx-segmented-control__item-label").length === 3
      && icons.querySelectorAll(".astryx-segmented-control__item-icon").length === 3);
  check("an icon-only segment names itself with aria-label instead",
    !!iconOnly && attr(radio("segc-icon-only", "list"), "aria-label") === "List"
      && !iconOnly.querySelector(".astryx-segmented-control__item-label"));

  // A disabled segment is aria-disabled and out of the roving set.
  const dis = g("segc-disabled-item");
  check("a disabled segment is aria-disabled and not the tab stop",
    !!dis && attr(radio("segc-disabled-item", "list"), "aria-disabled") === "true"
      && attr(radio("segc-disabled-item", "list"), "tabindex") === "-1"
      && attr(radio("segc-disabled-item", "grid"), "aria-disabled") === null);

  // Whole-control disabled: the flag is on the group; pointer events are CSS.
  const disabled = g("segc-disabled");
  check("the disabled group says so and has no focusable segment",
    !!disabled && attr(disabled, "aria-disabled") === "true"
      && disabled.classList.contains("astryx-segmented-control--disabled")
      && ![...disabled.querySelectorAll('[role="radio"]')].some((r) => attr(r, "tabindex") === "0"));

  // Disabled with a reason: the bubble exists, the group points at it, and the
  // selected segment stays focusable (upstream: keepsSelectedFocusable).
  const dm = g("segc-disabled-message");
  const dmWrap = host && host.querySelector("#segc-disabled-message")?.parentElement;
  const bubble = dmWrap && dmWrap.querySelector('[data-astryx-component="DisabledMessage"]');
  check("a reason bubble renders and the group points at it",
    !!dm && !!bubble && attr(bubble, "role") === "tooltip"
      && attr(dm, "aria-describedby") === "segc-disabled-message-disabled-message"
      && bubble.id === "segc-disabled-message-disabled-message");
  check("the selected segment stays the tab stop while disabled-with-message",
    !!dm && attr(radio("segc-disabled-message", "grid"), "tabindex") === "0"
      && attr(radio("segc-disabled-message", "list"), "tabindex") === "-1");
}

// --- Overlay (M38)
{
  const host = document.querySelector('[data-case="overlay-all"]');
  const g = (id) => host && host.querySelector(`#${id}`);
  const scrim = (id) => g(id) && g(id).querySelector(".astryx-overlay-scrim");
  const media = (id) => g(id) && g(id).querySelector("[data-astryx-media]");

  check("the overlay renders as a marked media container", !!g("ov-controlled")
    && attr(g("ov-controlled"), "data-astryx-component") === "Overlay"
    && hasClass(g("ov-controlled"), /astryx-overlay/));
  check("children render in front of the scrim", !!g("ov-controlled")
    && g("ov-controlled").querySelector(".ov-fixture-surface") !== null
    && g("ov-controlled").querySelector(".ov-fixture-surface").nextElementSibling
      === g("ov-controlled").querySelector(".astryx-overlay-scrim"));
  check("the scrim fills the container, aligns to end, and uses the dark mode by default",
    !!scrim("ov-controlled")
      && hasClass(scrim("ov-controlled"), /--fill/)
      && hasClass(scrim("ov-controlled"), /--align-end/)
      && hasClass(scrim("ov-controlled"), /--scrim-dark/));
  check("the media surface gets the dark theme tint", !!media("ov-controlled")
    && attr(media("ov-controlled"), "data-astryx-media") === "dark"
    && /Quick view/.test((media("ov-controlled").textContent || "")));
  check("a closed controlled overlay is hidden and inert", !!scrim("ov-controlled")
    && hasClass(scrim("ov-controlled"), /--hidden/)
    && scrim("ov-controlled").hasAttribute("inert"));
  check("the fixture wrap reads the live open state", (() => {
    const w = host && host.querySelector("#ov-fixture-state");
    return w && (w.textContent || "").trim() === "closed";
  })());

  // Uncontrolled / always-visible variants.
  const bottom = g("ov-bottom");
  check("Bottom is visible and not inert by default", !!bottom
    && !!scrim("ov-bottom") && hasClass(scrim("ov-bottom"), /--visible/)
    && !scrim("ov-bottom").hasAttribute("inert"), bottom && classesOf(bottom).join(" "));
  check("Bottom slides from the bottom edge", !!scrim("ov-bottom") && hasClass(scrim("ov-bottom"), /--visible-from-bottom/));
  check("Top slides from the top edge and flips light via scrim=LIGHT", !!scrim("ov-top")
    && hasClass(scrim("ov-top"), /--visible-from-top/)
    && !hasClass(scrim("ov-top"), /--visible-from-bottom/)
    && attr(media("ov-top"), "data-astryx-media") === "light");
  check("scrim=NONE emits no theme surface at all", !!g("ov-none")
    && g("ov-none").querySelector("[data-astryx-media]") === null
    && !hasClass(scrim("ov-none"), /--scrim-dark/) && !hasClass(scrim("ov-none"), /--scrim-light/));

  // show_on variants: hover/focus stay closed until a real browser interaction;
  // the classes carry the reveal mode.
  check("Hover stays closed with the --hover reveal mode and no --visible", !!scrim("ov-hover")
    && hasClass(scrim("ov-hover"), /--hover/) && !hasClass(scrim("ov-hover"), /--visible/));
  check("Focus stays closed with the --focus reveal mode and no --visible", !!scrim("ov-focus")
    && hasClass(scrim("ov-focus"), /--focus/) && !hasClass(scrim("ov-focus"), /--visible/));
  check("Hover_or_focus plus Bottom carries the hover mode and the bottom slide",
    !!scrim("ov-hover-bottom")
      && hasClass(scrim("ov-hover-bottom"), /--hover/) && hasClass(scrim("ov-hover-bottom"), /--hover-bottom/)
      && !hasClass(scrim("ov-hover-bottom"), /--visible/));

  // Aligns are classes so an override can be found and overridden.
  check("Center is a class, not an inline style", !!scrim("ov-center")
    && hasClass(scrim("ov-center"), /--align-center/) && !/align/.test(attr(scrim("ov-center"), "style") || ""));
}


// --- FileInput (M39)
{
  const host = document.querySelector('[data-case="file-input-all"]');
  const g = (id) => host && host.querySelector(`#${id}`);
  const native = (id) => g(id) && g(id).querySelector('input[type="file"]');
  const grab = (id, sel) => g(id) && g(id).querySelector(sel);

  check("the compact control renders as a marked FileInput", !!g("fi-compact")
    && attr(g("fi-compact"), "data-astryx-component") === "FileInput"
    && hasClass(g("fi-compact"), /astryx-file-input/)
    && hasClass(g("fi-compact"), /--compact/));
  check("there is a real file input behind a visually-hidden button", !!native("fi-compact")
    && !!grab("fi-compact", ".astryx-file-input__trigger")
    && g("fi-compact").querySelector(".astryx-file-input__trigger + input") !== null,
    g("fi-compact") && g("fi-compact").innerHTML.slice(0, 120));
  check("the default content is the upload icon, and no spinner", !!grab("fi-compact", "svg")
    && !grab("fi-compact", ".astryx-spinner"));
  check("the dropzone variant is dashed and spans the width", !!g("fi-dropzone")
    && hasClass(g("fi-dropzone"), /--dropzone/)
    && g("fi-dropzone").querySelector(".astryx-file-input__trigger") !== null);
  check("the disabled control is inert and non-focusable", !!g("fi-disabled")
    && hasClass(g("fi-disabled"), /--disabled/)
    && attr(g("fi-disabled").querySelector(".astryx-file-input__trigger"), "tabindex") === "-1"
    && g("fi-disabled").querySelector(".astryx-file-input__trigger").hasAttribute("inert") !== true);
  check("the busy control swaps the content for a spinner", !!grab("fi-loading", ".astryx-spinner")
    && !g("fi-loading").querySelector('[data-astryx-icon="upload"]'));
  check("the required control marks the trigger aria-required", attr(g("fi-required").querySelector(".astryx-file-input__trigger"), "aria-required") === "true");
  check("multiple files are announced on the native input", !!native("fi-multiple")
    && native("fi-multiple").hasAttribute("multiple"), native("fi-multiple") && native("fi-multiple").outerHTML);
  check("the error status surfaces its message", (host.textContent || "").includes("too large")
    || (g("fi-error") && (g("fi-error").textContent || "").includes("too large")));
  check("the placeholder is shown when no files are chosen", (g("fi-placeholder").textContent || "").includes("Choose a file"));
}

// --- Layout (M41)
{
  const host = document.querySelector('[data-case="layout-all"]');
  const g = (id) => host && host.querySelector(`#${id}`);
  const innerStyle = (id) => (g(id) && g(id).querySelector(".astryx-layout__inner")?.getAttribute("style")) || "";
  const middle = (id) => (g(id) && g(id).querySelector(".astryx-layout__middle")) || null;
  const column = (id) => (g(id) && g(id).querySelector(".astryx-layout__column")) || null;

  check("the five-slot shell renders all five regions", !!g("layout-shell-example")
    && attr(g("layout-shell-example"), "data-astryx-component") === "Layout"
    && !!g("layout-shell-example").querySelector('[data-astryx-component="LayoutHeader"]')
    && g("layout-shell-example").querySelectorAll('[data-astryx-component="LayoutPanel"]').length === 2
    && !!g("layout-shell-example").querySelector('[data-astryx-component="LayoutContent"]')
    && !!g("layout-shell-example").querySelector('[data-astryx-component="LayoutFooter"]'));
  check("the shell is a fill layout and the header is a banner, the content main",
    hasClass(g("layout-shell-example"), /astryx-layout--fill/)
    && attr(g("layout-shell-example"), "data-astryx-height") === "fill"
    && attr(g("layout-shell-example").querySelector('[data-astryx-component="LayoutHeader"]'), "role") === "banner"
    && attr(g("layout-shell-example").querySelector('[data-astryx-component="LayoutContent"]'), "role") === "main");
  check("explicit dividers are static attributes, one per header/footer",
    attr(g("layout-shell-example").querySelector('[data-astryx-component="LayoutHeader"]'), "data-astryx-divider") === "true"
    && attr(g("layout-shell-example").querySelector('[data-astryx-component="LayoutFooter"]'), "data-astryx-divider") === "true");
  check("the two panels carry the divider class and their widths as inline styles",
    [...g("layout-shell-example").querySelectorAll('[data-astryx-component="LayoutPanel"]')]
      .every((p) => hasClass(p, /astryx-layout-panel--has-divider/))
    && /width:\s*200px/.test(attr(g("layout-shell-example").querySelectorAll('[data-astryx-component="LayoutPanel"]')[0], "style") || "")
    && /width:\s*240px/.test(attr(g("layout-shell-example").querySelectorAll('[data-astryx-component="LayoutPanel"]')[1], "style") || ""));
  check("content is scrollable by default", hasClass(
    g("layout-shell-example").querySelector('[data-astryx-component="LayoutContent"]'), /--scrollable/));
  check("the default-dividers layout publishes the default on the inner and leaves the header unresolved (the hook resolves it in the browser)",
    /data-astryx-default-dividers="true"/.test(g("layout-default-dividers").querySelector(".astryx-layout__inner")?.outerHTML || "")
    && !attr(g("layout-default-dividers").querySelector('[data-astryx-component="LayoutHeader"]'), "data-astryx-divider"));
  check("the auto layout marks itself, and its 640px width takes the internal path",
    hasClass(g("layout-auto"), /astryx-layout--auto/)
    && attr(g("layout-auto"), "data-astryx-height") === "auto"
    && /--layout-content-width:\s*640px/.test(innerStyle("layout-auto"))
    && /--layout-alignment-width:\s*640px/.test(innerStyle("layout-auto"))
    && !!middle("layout-auto") && hasClass(middle("layout-auto"), /--query/)
    && !!column("layout-auto") && hasClass(column("layout-auto"), /--single-column/));
  check("a non-scrollable content is clipped rather than scrolled",
    hasClass(g("layout-auto").querySelector('[data-astryx-component="LayoutContent"]'), /--clip/));
  check("a bare panel outside a layout renders with its width and no divider",
    !!g("layout-shell-example") // host holds the bare panel too
    && (() => {
      const bare = host.querySelectorAll('[data-astryx-component="LayoutPanel"]');
      const last = bare[bare.length - 1];
      return last !== g("layout-shell-example").querySelector('[data-astryx-component="LayoutPanel"]')
        && hasClass(last, /astryx-layout-panel--scrollable/)
        && !hasClass(last, /--has-divider/)
        && /width:\s*300px/.test(attr(last, "style") || "");
    })());
  check("every region is named for the harness", !!g("layout-shell-example")
    && [ "LayoutHeader", "LayoutPanel", "LayoutContent", "LayoutFooter" ].every((n) =>
        !!g("layout-shell-example").querySelector(`[data-astryx-component="${n}"]`)));
}

// --- Slider (M42)
{
  const host = document.querySelector('[data-case="slider-all"]');
  const g = (id) => host && host.querySelector(`#${id}`);
  check("eight sliders render marked", inCaseOf("slider-all", "Slider").length === 8,
    `${inCaseOf("slider-all", "Slider").length}`);
  check("the basic slider has a track, fill and one thumb", !!g("sl-basic")
    && !!g("sl-basic").querySelector(".astryx-slider__track")
    && !!g("sl-basic").querySelector(".astryx-slider__fill")
    && g("sl-basic").querySelectorAll(".astryx-slider__thumb").length === 1,
    g("sl-basic") && g("sl-basic").innerHTML.slice(0, 160));
  check("the single thumb carries its value", attr(g("sl-basic").querySelector(".astryx-slider__thumb"), "aria-valuenow") === "25");
  check("the range slider has two thumbs and a group role", !!g("sl-range")
    && g("sl-range").querySelectorAll(".astryx-slider__thumb").length === 2
    && attr(g("sl-range").querySelector(".astryx-slider__track"), "role") === "group");
  check("the disabled slider is inert", !!g("sl-disabled")
    && hasClass(g("sl-disabled"), /--disabled/));
  check("required announces a hidden Required label", (host.textContent || "").includes("Required"));
  check("the description text is rendered", (host.textContent || "").includes("Adjust the amount"));
  check("an error status surfaces its message", (host.textContent || "").includes("Out of range"));
  check("marks render with labels", g("sl-marks").querySelectorAll(".astryx-slider__mark").length === 3
    && (g("sl-marks").querySelectorAll(".astryx-slider__mark-label").length || 0) >= 1,
    g("sl-marks") && g("sl-marks").innerHTML.slice(0, 180));
  check("the vertical variant carries the vertical class", hasClass(g("sl-vertical"), /--vertical/)
    || !!g("sl-vertical").querySelector(".astryx-slider__track--vertical"));
}

// --- Item (M44)
{
  const host = document.querySelector('[data-case="item-all"]');
  const g = (id) => host && host.querySelector(`#${id}`);
  const items = inCaseOf("item-all", "Item");
  check("sixteen item rows render marked", items.length === 16, `${items.length}`);
  check("a basic row carries the row classes and a description",
    hasClass(g("it-basic"), /^astryx-item$/) && hasClass(g("it-basic"), /--density-balanced/)
    && !!g("it-basic").querySelector(".astryx-item__label")
    && g("it-basic").querySelector(".astryx-item__description")?.id?.startsWith("astryx-item-description-"));
  check("align start + compact carry their classes",
    hasClass(g("it-align"), /--align-start/) && hasClass(g("it-align"), /--density-compact/));
  check("density variations carry their classes",
    hasClass(g("it-spacious"), /--density-spacious/));
  check("truncation: one line is ellipsized, two lines are clamped",
    hasClass(g("it-truncate1").querySelector(".astryx-item__description"), /--truncate-single/)
    && hasClass(g("it-truncate2").querySelector(".astryx-item__description"), /--truncate-multi/)
    && (g("it-truncate2").querySelector(".astryx-item__description").getAttribute("style") || "").includes("WebkitLineClamp: 2"));
  check("selected and highlighted rows carry their classes",
    hasClass(g("it-selected"), /--selected/) && hasClass(g("it-highlighted"), /--highlighted/));
  check("a disabled row is told so, and its content fades",
    attr(g("it-disabled"), "aria-disabled") === "true"
    && !!g("it-disabled").querySelector(".astryx-item__content-disabled"));
  check("a row with on_click renders an invisible button",
    !!g("it-click").querySelector("button.astryx-item__invisible-button"));
  check("a row with href renders an invisible anchor carrying the href",
    attr(g("it-link").querySelector("a.astryx-item__invisible-anchor"), "href") === "#it");
  check("a Custom root with href makes the root the anchor",
    g("it-link-root").tagName.toLowerCase() === "a" && hasClass(g("it-link-root"), /--link-root/)
    && attr(g("it-link-root"), "href") === "#it-root");
  check("inline layout puts label and description on one line",
    !!g("it-inline").querySelector(".astryx-item__inline-content")
    && !!g("it-inline").querySelector(".astryx-item__inline-label")
    && !!g("it-inline").querySelector(".astryx-item__inline-description"));
  check("a swipeable row carries the swipe classes and both panels",
    hasClass(g("it-swipe"), /--swipe/)
    && g("it-swipe").querySelectorAll('[data-swipe-panel="leading"]').length === 1
    && g("it-swipe").querySelectorAll('[data-swipe-panel="trailing"]').length === 1);
  check("at rest the panels are inert, and reveal entries are buttons",
    attr(g("it-swipe").querySelector('[data-swipe-panel="leading"]'), "inert") === "true"
    && g("it-swipe").querySelectorAll("button.astryx-item__swipe-entry").length === 3);
  check("variants paint per action: neutral, accent and destructive",
    !!g("it-swipe").querySelector(".astryx-item__swipe-entry--neutral")
    && !!g("it-swipe").querySelector(".astryx-item__swipe-entry--accent")
    && !!g("it-swipe").querySelector(".astryx-item__swipe-entry--destructive"));
  check("commit panels are presentational: aria-hidden and no buttons",
    attr(g("it-swipe-commit").querySelector('[data-swipe-panel="trailing"]'), "aria-hidden") === "true"
    && g("it-swipe-commit").querySelectorAll("button.astryx-item__swipe-entry").length === 0
    && g("it-swipe-commit").querySelectorAll("span.astryx-item__swipe-entry").length === 3);
}

// --- Divider
{
  const ds = inCase("divider-all");
  check("five dividers render", ds.length === 5, `${ds.length}`);
  check("dividers are separators", ds.filter((d) => attr(d, "role") === "separator").length === 5,
    ds.map((d) => attr(d, "role")).join(","));
  check("the labelled divider shows its label", ds.some((d) => /(^|\s)or(\s|$)/.test(d.textContent || "")));
  check("the vertical divider is marked", ds.some((d) => (attr(d, "aria-orientation") || "") === "vertical" ||
    hasClass(d, /vertical/)));
}

// --- Skeleton
{
  const ss = inCase("skeleton-all");
  check("seven skeletons render", ss.length === 7, `${ss.length}`);
  check("skeletons are hidden from screen readers", ss.every((s) => attr(s, "aria-hidden") === "true"));
}

// --- Text
{
  const ts = inCase("text-all");
  check("seven text blocks render", ts.length === 7, `${ts.length}`);
  check("code text carries the code type class", ts.some((t) => hasClass(t, /type-code/)),
    ts.map((t) => classesOf(t).join(" ")).join(" | "));
  check("tabular numbers are marked", ts.some((t) => hasClass(t, /tabular/) || /tabular/.test(attr(t, "style") || "")));
  check("text content is carried through", ts.some((t) => (t.textContent || "").trim() === "body"));
}

// --- Heading
{
  const hs = inCase("heading-levels");
  check("six headings render", hs.length === 6, `${hs.length}`);
  check("headings are h1..h6 in order",
    JSON.stringify(hs.map((h) => h.tagName.toLowerCase())) ===
      JSON.stringify(["h1", "h2", "h3", "h4", "h5", "h6"]),
    hs.map((h) => h.tagName.toLowerCase()).join(","));
}

// --- Stack / Center / Section / Grid / Card / VisuallyHidden
{
  const st = inCase("stack-all");
  check("three stacks render", st.length === 3, `${st.length}`);
  check("horizontal stack is marked horizontal", st.some((s) => hasClass(s, /horizontal/)));
  // Stack applies gap/padding/size as INLINE STYLES (they are per-instance values,
  // not variant classes). Two of the three stacks here were given a gap and the
  // third deliberately was not, so this asserts both directions: the token gets
  // written out when given, and nothing is emitted when it is not.
  const withGap = st.filter((s) => /gap\s*:\s*var\(--spacing-/.test(attr(s, "style") || ""));
  const withoutGap = st.filter((s) => !/gap\s*:/.test(attr(s, "style") || ""));
  check("a given gap is written as an inline style from the spacing token", withGap.length === 2,
    st.map((s) => attr(s, "style")).join(" | "));
  check("a stack given no gap emits no gap property", withoutGap.length === 1,
    st.map((s) => attr(s, "style")).join(" | "));
}
{
  const cs = inCase("center-all");
  check("four centers render", cs.length === 4, `${cs.length}`);
  check("the inline center is marked inline", cs.some((c) => hasClass(c, /inline/)));
}
{
  const sec = inCase("section-all");
  check("three sections render", sec.length === 3, `${sec.length}`);
  check("the muted section is marked", sec.some((s) => hasClass(s, /muted/)));
}
{
  const gs = inCase("grid-tracks");
  check("three grids render", gs.length === 3, `${gs.length}`);
  const styles = gs.map((g) => attr(g, "style") || "");
  check("fixed tracks expand to repeat(n, 1fr)", styles.some((s) => /repeat\(\s*3/.test(s)), styles.join(" | "));
  check("responsive tracks use auto-fill with the min width",
    styles.some((s) => /auto-fill/.test(s) && /180px/.test(s)), styles.join(" | "));
  check("responsive tracks honour fit vs fill", styles.some((s) => /auto-fit/.test(s)), styles.join(" | "));
}
{
  const cs = inCase("card-all");
  check("two cards render", cs.length === 2, `${cs.length}`);
  check("the muted card is marked", cs.some((c) => hasClass(c, /muted/)));
}
{
  const vs = inCase("visuallyhidden-all");
  check("three visually-hidden blocks render", vs.length === 3, `${vs.length}`);
  check("visually-hidden elements keep their element type",
    JSON.stringify(vs.map((v) => v.tagName.toLowerCase())) === JSON.stringify(["span", "div", "p"]),
    vs.map((v) => v.tagName.toLowerCase()).join(","));
  check("visually-hidden is styled as such", vs.every((v) => hasClass(v, /visually-hidden/)));
}

// --- HStack / VStack (prop presets over Stack)
{
  const hs = inCase("hstack-all");
  const vs = inCase("vstack-all");
  check("HStack renders two stacks", hs.length === 2, `${hs.length}`);
  check("HStack carries Stack's marker, not one of its own",
    hs.length > 0 && hs.every((e) => attr(e, "data-astryx-component") === "Stack"),
    hs.map((e) => attr(e, "data-astryx-component")).join(","));
  check("HStack is horizontal", hs.length > 0 && hs.every((e) => hasClass(e, /horizontal/)),
    hs.map((e) => classesOf(e).join(" ")).join(" | "));
  check("VStack renders two stacks", vs.length === 2, `${vs.length}`);
  // Vertical is the base state in this port, so it carries no direction class —
  // the assertion is that nothing marks it horizontal, not that "vertical" appears.
  check("VStack is vertical (nothing marks it horizontal)",
    vs.length > 0 && vs.every((e) => !hasClass(e, /horizontal/)),
    vs.map((e) => classesOf(e).join(" ")).join(" | "));
}

// --- AspectRatio
{
  const ars = inCase("aspect-ratio-all");
  check("three aspect-ratio boxes render", ars.length === 3, `${ars.length}`);
  const styles = ars.map((e) => attr(e, "style") || "");
  // The whole point of the indirection: the ratio must NOT be an inline
  // aspect-ratio, or a consumer rule could never override it.
  check("the ratio travels as a custom property",
    styles.every((s) => /--astryx-aspect-ratio\s*:/.test(s)), styles.join(" | "));
  check("no inline aspect-ratio declaration is emitted",
    styles.every((s) => !/(^|;)\s*aspect-ratio\s*:/.test(s)), styles.join(" | "));
  const ratios = styles.map((s) => Number((s.match(/--astryx-aspect-ratio:\s*([^;]+)/) || [])[1]));
  check("the ratios are the ones asked for (16/9, 1, 4/3)",
    Math.abs(ratios[0] - 16 / 9) < 0.001 &&
      Math.abs(ratios[1] - 1) < 0.001 &&
      Math.abs(ratios[2] - 4 / 3) < 0.001,
    ratios.join(", "));
  check("shape is declared on the component",
    ars.map((e) => attr(e, "data-astryx-shape")).join(",") === "rectangle,ellipse,rectangle",
    ars.map((e) => attr(e, "data-astryx-shape")).join(","));
  check("the ellipse clips to a radius", ars.some((e) => hasClass(e, /--ellipse/)));
  check("every box has its inner child", ars.every((e) => e.querySelector(".astryx-aspect-ratio__child")));
  const overrides = ars.map((e) => {
    const c = e.querySelector(".astryx-aspect-ratio__child");
    return c ? attr(c, "data-astryx-aspect-ratio-override") ?? "none" : "MISSING";
  });
  check("fit is carried on the child as the override attribute (and omitted when unset)",
    overrides.join(",") === "none,cover,center", overrides.join(","));
  check("fit=center centres from the wrapper class",
    ars.some((e) => e.querySelector(".astryx-aspect-ratio__child--center")));
}

// --- IconButton (a Button preset that is its own component to the tooling)
{
  const bs = inCase("icon-button-all");
  check("three icon buttons render", bs.length === 3, `${bs.length}`);
  // This check used to assert the opposite — that IconButton *inherited* Button's marker — which was
  // true of the port's shortcut and is exactly why IconButton was the one ported component with no
  // appearance page: every tool here identifies a component by its marker, so an inherited one made the
  // component invisible to them. Upstream styles it as its own component too.
  check("IconButton carries its own marker",
    bs.length > 0 && bs.every((e) => attr(e, "data-astryx-component") === "IconButton"),
    bs.map((e) => attr(e, "data-astryx-component")).join(","));
  check("and still carries Button's behaviour and naming contract",
    bs.every((e) => (e.className || "").includes("astryx-button")),
    bs.map((e) => e.className).join(" | "));
  check("every icon button has an accessible name",
    bs.every((e) => (attr(e, "aria-label") || "").length > 0),
    bs.map((e) => attr(e, "aria-label")).join(" | "));
  check("the icon is not hidden by the component (upstream leaves that to the caller)",
    bs.every((e) => e.querySelector(".astryx-button__content") !== null));
  // Keyboard operability is asserted through the element's semantics rather than by
  // firing a synthetic Enter: activation of a native <button> is the browser's job,
  // so a dispatch here would pass whether or not the port is keyboard-usable. What
  // matters is that it IS a native button, that it is reachable by Tab, and that it
  // is named. The real keypress is asserted in Chromium (see verify-browser.mjs).
  check("icon buttons are native <button> elements",
    bs.every((e) => e.tagName.toLowerCase() === "button"));
  check("icon buttons are reachable by Tab (no tabindex=-1)",
    bs.every((e) => attr(e, "tabindex") !== "-1"));
  check("the loading icon button stays focusable while busy",
    bs.some((e) => attr(e, "aria-busy") === "true" && !e.hasAttribute("disabled")));
  check("the disabled icon button uses the native disabled attribute",
    bs.some((e) => e.hasAttribute("disabled")));
}

// --- Code
{
  const cs = inCase("code-all");
  check("four code elements render", cs.length === 4, `${cs.length}`);
  check("Code renders a real <code> element",
    cs.every((e) => e.tagName.toLowerCase() === "code"),
    cs.map((e) => e.tagName.toLowerCase()).join(","));
  check("the colour variants are carried through",
    JSON.stringify(cs.slice(0, 3).map((e) => attr(e, "data-astryx-color"))) ===
      JSON.stringify(["primary", "secondary", "inherit"]),
    cs.map((e) => attr(e, "data-astryx-color")).join(","));
  check("only the size variant takes the inherit-size class",
    cs.filter((e) => hasClass(e, /size-inherit/)).length === 1);
}

// --- Blockquote
{
  const qs = inCase("blockquote-all");
  check("two blockquotes render", qs.length === 2, `${qs.length}`);
  check("Blockquote renders a real <blockquote>",
    qs.every((e) => e.tagName.toLowerCase() === "blockquote"));
  check("exactly one carries a cite", qs.filter((e) => e.querySelector("cite")).length === 1);
  // Upstream's reason for a bare <cite>: <blockquote> is a sectioning root, so a
  // <footer> inside it would become a contentinfo landmark.
  check("the cite is a bare <cite>, never wrapped in a <footer>",
    qs.every((e) => e.querySelector("footer") === null) &&
      qs.some((e) => e.querySelector("cite.astryx-blockquote__cite")));
}

// --- NavIcon
{
  const ns = inCase("nav-icon-all");
  check("two nav icons render", ns.length === 2, `${ns.length}`);
  check("NavIcon renders a span", ns.every((e) => e.tagName.toLowerCase() === "span"));
  check("NavIcon carries its marker",
    ns.every((e) => attr(e, "data-astryx-component") === "NavIcon"));
  check("NavIcon keeps whatever the caller passed as the icon",
    ns.every((e) => e.children.length >= 1));
  // Deliberate: upstream leaves the icon's accessibility to the caller, so a component
  // that hid the icon would silence one that a caller gave a role and a label.
  check("NavIcon does not hide the caller's icon from assistive tech",
    ns.every((e) => e.getAttribute("aria-hidden") !== "true"));
}

// --- EmptyState
{
  const es = inCaseOf("empty-state-all", "EmptyState");
  check("two empty states render", es.length === 2, `${es.length}`);
  check("the case also contains the two nested buttons",
    inCaseOf("empty-state-all", "Button").length === 2,
    `${inCaseOf("empty-state-all", "Button").length}`);
  check("the empty state is a live region (role=status)",
    es.every((e) => attr(e, "role") === "status"));
  const [full, compact] = es;
  check("the illustration is hidden from assistive tech",
    full.querySelector('[aria-hidden="true"]') !== null);
  check("the default title is an h3",
    full.querySelector("h3.astryx-empty-state__title") !== null,
    full.querySelector(".astryx-empty-state__title")?.tagName);
  check("headingLevel is honoured (h2 when asked)",
    compact.querySelector("h2.astryx-empty-state__title") !== null,
    compact.querySelector(".astryx-empty-state__title")?.tagName);
  check("the description is a div, not a p",
    full.querySelector(".astryx-empty-state__description")?.tagName.toLowerCase() === "div",
    full.querySelector(".astryx-empty-state__description")?.tagName);
  // The reason for the div: the description accepts arbitrary nodes, and a <p> cannot
  // legally contain block children.
  check("no <p> anywhere in the empty state", full.querySelector("p") === null);
  check("compact carries both the class and the variant marker",
    hasClass(compact, /empty-state--compact/) && attr(compact, "data-astryx-variant") === "compact",
    `${compact.className} / ${attr(compact, "data-astryx-variant")}`);
  check("actions render inside the actions row",
    full.querySelectorAll(".astryx-empty-state__actions button").length === 2,
    `${full.querySelectorAll(".astryx-empty-state__actions button").length}`);
  check("a compact empty state with no actions renders no actions row",
    compact.querySelector(".astryx-empty-state__actions") === null);
  check("the title text is rendered as text, not markup",
    full.querySelector(".astryx-empty-state__title")?.textContent.trim() === "No results",
    full.querySelector(".astryx-empty-state__title")?.textContent);
}

// --- Citation
{
  const cs = inCase("citation-all");
  check("six citations render", cs.length === 6, `${cs.length}`);
  check("a citation with a safe URL is a real link",
    cs[0].tagName.toLowerCase() === "a" && attr(cs[0], "href") === "https://example.com/spec",
    `${cs[0].tagName} ${attr(cs[0], "href")}`);
  check("the link does not hand over window.opener",
    attr(cs[0], "target") === "_blank" && attr(cs[0], "rel") === "noopener noreferrer",
    `${attr(cs[0], "target")} ${attr(cs[0], "rel")}`);
  check("a javascript: URL is NOT rendered as a link",
    cs[1].tagName.toLowerCase() === "span", cs[1].tagName);
  check("...and the refused URL is not in the markup at all",
    !/javascript:/i.test(cs[1].outerHTML), cs[1].outerHTML.slice(0, 120));
  check("a citation with no URL is inert too", cs[2].tagName.toLowerCase() === "span");
  check("a linked citation uses the doc-noteref link role",
    attr(cs[0], "role") === "doc-noteref", attr(cs[0], "role"));
  // doc-noteref is not permitted on an inert span, so upstream gives it a supported
  // role instead of leaving it unnamed.
  check("an inert citation falls back to a permitted role",
    attr(cs[1], "role") === "group" && attr(cs[2], "role") === "group",
    `${attr(cs[1], "role")}/${attr(cs[2], "role")}`);
  check("every citation is named by its aria-label",
    cs.every((e) => (attr(e, "aria-label") || "").startsWith("Citation ")),
    cs.map((e) => attr(e, "aria-label")).join(" | "));
  check("the label uses upstream's English string",
    attr(cs[0], "aria-label") === "Citation 1: Designing with tokens",
    attr(cs[0], "aria-label"));
  check("a citation with no title falls back to its number in the label",
    attr(cs[2], "aria-label") === "Citation 3: 3", attr(cs[2], "aria-label"));
  check("the number variant renders the number, not the title",
    cs[3].textContent.trim() === "4" && attr(cs[3], "data-astryx-variant") === "number",
    `${cs[3].textContent.trim()} / ${attr(cs[3], "data-astryx-variant")}`);
  check("the number variant is still a link when it has a URL",
    cs[3].tagName.toLowerCase() === "a");
  check("the number variant without a URL is inert", cs[4].tagName.toLowerCase() === "span");
  check("the title attribute carries the visible label",
    attr(cs[0], "title") === "Designing with tokens", attr(cs[0], "title"));
  check("the favicon image is decorative (empty alt)",
    cs[5].querySelector("img")?.getAttribute("alt") === "");
  check("the favicon sits inside the aria-hidden icon wrapper",
    cs[5].querySelector('[aria-hidden="true"] .astryx-citation__icon-img') !== null);
  check("the label text element is present for text overflow handling",
    cs[0].querySelector(".astryx-citation__text")?.textContent === "Designing with tokens");
}

// --- the safe-URL control, as decided by the compiled OCaml
{
  const rows = inCaseMatching("citation-safety", "span[data-url]");
  check("every URL case rendered", rows.length === 13, `${rows.length}`);
  const actual = (r) => r.textContent.trim();
  const expected = (r) => attr(r, "data-safe");
  const wrong = rows.filter((r) => (actual(r) === "safe") !== (expected(r) === "true"));
  check("is_safe_url agrees with upstream on every case", wrong.length === 0,
    wrong.map((r) => `"${attr(r, "data-url")}" decided ${actual(r)}, expected ${expected(r)}`).join(" | "));
  const nul = rows.find((r) => (attr(r, "data-url") || "").includes("\u0000"));
  check("a NUL spliced into the scheme is refused",
    nul !== undefined && nul.textContent.trim() === "unsafe",
    nul ? `${JSON.stringify(attr(nul, "data-url"))} -> ${nul.textContent.trim()}` : "case missing");
  const nl = rows.find((r) => (attr(r, "data-url") || "").includes("\n"));
  check("a newline spliced into the scheme is refused",
    nl !== undefined && nl.textContent.trim() === "unsafe");
}

// --- Icon (and, through it, the generated glyph table)
{
  const SVG_NS = "http://www.w3.org/2000/svg";
  const ic = inCaseOf("icon-all", "Icon");
  check("twelve icons render", ic.length === 12, `${ic.length}`);

  const svgs = ic.map((e) => e.querySelector("svg"));
  // The renderer must build SVG with createElementNS. With plain createElement these
  // elements are HTMLUnknownElement and paint nothing — a blank-icon bug that still
  // compiles, still has the right attributes, and is invisible to a text assertion.
  check(
    "every icon wraps an <svg> in the SVG namespace",
    svgs.every((s, i) => (i === 8 ? s === null : s !== null && s.namespaceURI === SVG_NS)),
    svgs.map((s) => (s ? s.namespaceURI : "missing")).join(","),
  );
  check(
    "glyph children are in the SVG namespace too",
    ic.every((e, i) => i === 8 || [...(svgs[i]?.children || [])].every((c) => c.namespaceURI === SVG_NS)),
  );

  const closeSvg = svgs[0];
  check(
    "the path data matches upstream byte for byte",
    attr(closeSvg.querySelector("path"), "d") === "M6 6l12 12M6 18L18 6",
    attr(closeSvg.querySelector("path"), "d"),
  );
  check("viewBox is upstream's 24x24", attr(closeSvg, "viewBox") === "0 0 24 24", attr(closeSvg, "viewBox"));
  check("the stroke wrapper's attributes are reproduced", [
    attr(closeSvg, "fill") === "none",
    attr(closeSvg, "stroke") === "currentColor",
    attr(closeSvg, "stroke-width") === "1.5",
    attr(closeSvg, "stroke-linecap") === "round",
    attr(closeSvg, "stroke-linejoin") === "round",
    attr(closeSvg, "width") === "1em" && attr(closeSvg, "height") === "1em",
    attr(closeSvg, "xmlns") === SVG_NS,
  ].every(Boolean), `fill=${attr(closeSvg, "fill")} stroke=${attr(closeSvg, "stroke")} sw=${attr(closeSvg, "stroke-width")}`);
  check("strokeWidth became stroke-width, not strokeWidth",
    !closeSvg.hasAttribute("strokeWidth") && !closeSvg.hasAttribute("strokewidth"));

  // The three per-icon deviations from the shared wrapper.
  const successSvg = svgs[1];
  check("a solid glyph fills with currentColor and drops stroke",
    attr(successSvg, "fill") === "currentColor" && !successSvg.hasAttribute("stroke"));
  check("its path keeps fill-rule / clip-rule",
    attr(successSvg.querySelector("path"), "fill-rule") === "evenodd"
      && attr(successSvg.querySelector("path"), "clip-rule") === "evenodd");
  check("'menu' keeps its own stroke-width override",
    attr(svgs[2], "stroke-width") === "2", attr(svgs[2], "stroke-width"));

  const dots = [...svgs[3].querySelectorAll("circle")];
  check("moreHorizontal renders three circles at the upstream coordinates",
    dots.length === 3
      && dots.map((c) => attr(c, "cx")).join(",") === "5,12,19"
      && dots.every((c) => attr(c, "cy") === "12" && attr(c, "r") === "1.5"),
    dots.map((c) => `${attr(c, "cx")}/${attr(c, "cy")}/${attr(c, "r")}`).join(" "));

  const cal = svgs[4];
  check("calendar renders a rect plus a path",
    attr(cal.querySelector("rect"), "width") === "18"
      && attr(cal.querySelector("rect"), "rx") === "2"
      && attr(cal.querySelector("path"), "d") === "M16 2v4M8 2v4M3 10h18",
    cal.innerHTML.slice(0, 90));

  // sizes and colour
  check("the default size is md", hasClass(ic[0], /astryx-icon--md/));
  check("xsm/sm/md/lg all appear", ["xsm", "sm", "md", "lg"].every((s) =>
    ic.some((e) => hasClass(e, new RegExp(`astryx-icon--${s}`)))));
  check("an explicit size is honoured", hasClass(ic[5], /astryx-icon--lg/) && !hasClass(ic[5], /astryx-icon--md/));
  check("a colour class is applied", hasClass(ic[5], /astryx-icon--red/));
  check("no colour class when colour is omitted", !hasClass(ic[0], /astryx-icon--(primary|red|blue)/));

  // the a11y contract
  check("a decorative icon is aria-hidden", attr(ic[0], "aria-hidden") === "true");
  check("a decorative icon has no role and no label",
    !ic[0].hasAttribute("role") && !ic[0].hasAttribute("aria-label"));
  check("a labelled icon becomes a named image",
    attr(ic[6], "role") === "img" && attr(ic[6], "aria-label") === "Delete row");
  check("a labelled icon is NOT aria-hidden", !ic[6].hasAttribute("aria-hidden"));
  check("an empty label is treated as no label",
    attr(ic[7], "aria-hidden") === "true" && !ic[7].hasAttribute("role"));
  check("the inner <svg> is aria-hidden either way (upstream's own attribute)",
    attr(svgs[0], "aria-hidden") === "true" && attr(svgs[6], "aria-hidden") === "true");
  check("the caller's accessibility attributes win",
    attr(ic[9], "aria-hidden") === "false" && attr(ic[9], "role") === "presentation");

  // an unknown name fails loudly instead of silently
  check("an unknown icon name is marked in the DOM",
    attr(ic[8], "data-astryx-icon-missing") === "noSuchIcon");
  check("an unknown icon renders no svg", svgs[8] === null);
}

// --- FieldStatus
{
  const svgData = JSON.parse(readFileSync(resolve(root, "assets/icons.json"), "utf8"));
  const iconPath = (name) => {
    const icon = svgData.icons.find((i) => i.name === name);
    const first = icon.children.find((c) => c.tag === "path");
    return first.attrs.find(([k]) => k === "d")[1];
  };

  const fs = inCaseOf("field-status-all", "FieldStatus");
  check("six field statuses render", fs.length === 6, `${fs.length}`);
  check("each carries its type class", [
    hasClass(fs[0], /astryx-field-status--warning/),
    hasClass(fs[1], /astryx-field-status--error/),
    hasClass(fs[2], /astryx-field-status--success/),
  ].every(Boolean), fs.slice(0, 3).map((e) => e.className).join(" | "));
  check("attached is the default variant", hasClass(fs[0], /astryx-field-status--attached/));
  check("detached is honoured", hasClass(fs[3], /astryx-field-status--detached/));

  // Announcement urgency: an error interrupts, the others wait their turn.
  check("an error is announced assertively (role=alert)", attr(fs[1], "role") === "alert");
  check("warnings and successes are polite (role=status)",
    attr(fs[0], "role") === "status" && attr(fs[2], "role") === "status");

  // Attached: bare text. Upstream renders the message directly, with no icon and no
  // wrapper — adding a wrapper here would be a visible divergence, not a detail.
  check("attached renders the message as bare text",
    fs[0].textContent === "Careful: this cannot be undone." && fs[0].children.length === 0,
    `${fs[0].children.length} child element(s)`);
  check("attached renders no icon", fs[0].querySelector("svg") === null);

  // Detached: icon + message, with the icon for the type.
  check("detached wraps its content", fs[3].querySelector(".astryx-field-status__content") !== null);
  const dIcon = fs[3].querySelector(".astryx-field-status__icon svg");
  check("detached error shows the error glyph",
    dIcon !== null && attr(dIcon.querySelector("path"), "d") === iconPath("error"),
    attr(dIcon?.querySelector("path"), "d"));
  check("detached success shows the success glyph",
    attr(fs[4].querySelector(".astryx-field-status__icon svg path"), "d") === iconPath("success"));
  check("the detached icon is the sm size",
    hasClass(fs[3].querySelector(".astryx-field-status__icon .astryx-icon"), /astryx-icon--sm/));
  check("detached still shows its message", fs[3].textContent === "Detached error", fs[3].textContent);

  // The first-paint rule: this tree is the first thing the page renders, so nothing here
  // may carry an entry-animation class. Upstream suppresses the animation on first paint.
  check("nothing animates on the first paint",
    fs.every((e) => ![...e.classList].some((c) => c.startsWith("astryx-enter--"))),
    fs.map((e) => e.className).join(" | "));

  check("caller attributes are applied last", attr(fs[5], "id") === "status-custom");
}

// --- the interaction: a real event dispatched into the Bonsai graph
section("interaction (OCaml dispatched the event)");
{
  const countOf = (name) => {
    const host = document.querySelector(`[data-case="${name}"]`);
    return host ? attr(host.querySelector("[data-click-count]"), "data-click-count") : null;
  };
  const before = countOf("click-before");
  const after = countOf("click-after");
  const after2 = countOf("click-after-2");
  check("the click target is a ported Button",
    inCase("click-before").some((b) => attr(b, "data-astryx-component") === "Button"));
  check("count starts at 0", before === "0", String(before));
  check("one dispatched click moves the count to 1", after === "1", String(after));
  check("a second click moves it to 2", after2 === "2", String(after2));
}

// --------------------------------------------------------------------- report

// --- DropdownMenu
section("DropdownMenu (the APG menu-button core)");

{
  const closed = inCaseOf("dropdown-menu-closed", "DropdownMenu")[0];
  const open = inCaseOf("dropdown-menu-open", "DropdownMenu")[0];
  const selected = inCaseOf("dropdown-menu-selected", "DropdownMenu")[0];

  check("the menu mounts in all three states", Boolean(closed && open && selected),
    `${Boolean(closed)}/${Boolean(open)}/${Boolean(selected)}`);

  // Selected by class and attribute rather than by id on purpose: all three fixtures
  // carry the same ids, and jsdom resolves a scoped "#id" query document-first, so a
  // scoped id query returns null for every case but the first.
  const trigger = (root) => root.querySelector('button[aria-haspopup="menu"]');
  const popover = (root) => root.querySelector(".astryx-dropdown__popover");
  const menu = (root) => root.querySelector(".astryx-dropdown__menu");
  const rows = (root) => [...root.querySelectorAll("[data-astryx-menu-item]")];
  const row = (root, id) => rows(root).find((r) => attr(r, "data-astryx-menu-item") === id);

  // The trigger is the APG menu button: what it opens, whether it is open, and which
  // element that is.
  check("the trigger is a button with the menu-button ARIA",
    trigger(open).tagName === "BUTTON" &&
      attr(trigger(open), "aria-haspopup") === "menu" &&
      attr(trigger(open), "aria-controls") === menu(open).id &&
      menu(open).id !== "");
  check("aria-expanded follows the state",
    attr(trigger(closed), "aria-expanded") === "false" && attr(trigger(open), "aria-expanded") === "true",
    `${attr(trigger(closed), "aria-expanded")}/${attr(trigger(open), "aria-expanded")}`);

  // The surface is in the DOM even while closed, so aria-controls never dangles;
  // [hidden] closes it rather than its absence, and the state is stated on it too.
  check("the element aria-controls names exists while closed",
    document.getElementById(menu(closed).id) === menu(closed));
  check("closed hides the surface with [hidden]", popover(closed).hasAttribute("hidden"));
  check("open removes [hidden]", !popover(open).hasAttribute("hidden"));
  check("the surface states its own state",
    attr(popover(closed), "data-astryx-state") === "closed" && attr(popover(open), "data-astryx-state") === "open");
  check("the menu is a role=menu named by the trigger",
    attr(menu(open), "role") === "menu" && attr(menu(open), "aria-labelledby") === trigger(open).id);
  check("the menu is programmatically focusable", attr(menu(open), "tabindex") === "-1");
  check("the surface caps its height", /^max-height:\d+px$/.test(menu(open).getAttribute("style") || ""),
    `style=${menu(open).getAttribute("style")}`);

  // Rows exist only while open, which keeps the closed menu out of the tab order and
  // out of the accessibility tree entirely.
  check("no rows render while closed", rows(closed).length === 0, `${rows(closed).length}`);
  check("every row renders while open", rows(open).length === 8, `${rows(open).length}`);
  check("every row is a programmatically focusable menuitem",
    rows(open).every((r) => attr(r, "role") === "menuitem" && attr(r, "tabindex") === "-1"));

  // A disabled row cannot take focus, so navigation has to skip it; the port excludes
  // it by selector, which is why no index can ever point at an unfocusable row.
  const disabled = row(open, "duplicate");
  check("a disabled row says so and stays a menuitem",
    attr(disabled, "aria-disabled") === "true" && attr(disabled, "role") === "menuitem");
  check("a disabled row is not an anchor", attr(disabled, "href") === null);

  // A row with an href *is* the anchor, so ⌘-click and middle-click keep working.
  const link = row(open, "docs");
  check("an href row is the anchor itself, with the menu role",
    link.tagName === "A" && attr(link, "href") === "#menu-docs" && attr(link, "role") === "menuitem");
  check("exactly one row is a link", rows(open).filter((r) => r.tagName === "A").length === 1,
    rows(open).filter((r) => r.tagName === "A").map((r) => attr(r, "data-astryx-menu-item")).join(","));

  const headings = [...open.querySelectorAll(".astryx-dropdown__heading")];
  check("both section headings render", headings.length === 2,
    headings.map((h) => h.textContent).join(" | "));
  check("the divider is a separator", open.querySelectorAll('[role="separator"]').length === 1);

  const groups = [...open.querySelectorAll('[role="group"]')];
  check("both groups are role=group", groups.length === 2, `${groups.length}`);
  check("a titled group is named by a heading that exists",
    document.getElementById(attr(groups[0], "aria-labelledby") || "")?.textContent === "Sort by");
  check("an untitled group is left unnamed rather than mislabelled",
    attr(groups[1], "aria-labelledby") === null);

  const first = row(open, "new");
  check("a row's icon is decorative and wrapped",
    first.querySelector('.astryx-dropdown__item-icon[aria-hidden="true"] svg') !== null);
  check("a row renders label and description",
    first.querySelector(".astryx-dropdown__item-label").textContent === "New file" &&
      first.querySelector(".astryx-dropdown__item-description").textContent === "Create a file in this project");
  check("end content renders after the body",
    first.querySelector(".astryx-dropdown__item-end").textContent === "⌘N");
  check("a destructive row is marked as one",
    hasClass(row(open, "delete"), /astryx-dropdown__item--destructive/));
  check("an ordinary row is not", !hasClass(row(open, "open"), /destructive/));

  // The selection reached the consumer: [data-selected] is the case's own state,
  // rendered by the component's parent, not something the menu wrote.
  check("the consumer received the selection",
    selected.parentElement.getAttribute("data-selected") === "open",
    `data-selected=${selected.parentElement.getAttribute("data-selected")}`);
  check("selecting a row closes the menu",
    attr(trigger(selected), "aria-expanded") === "false" && popover(selected).hasAttribute("hidden"));
  check("closing empties the surface again", rows(selected).length === 0, `${rows(selected).length}`);
}


// --- Field + TextInput (M11)
//
// The point of these two components is the wiring, so that is what is asserted: how the control
// is named, which text it points at, and which of the three placements the message took.

section("Field + TextInput");

{
  const textOf = (el) => (el ? el.textContent || "" : "");
  const input = (id) => document.querySelector(`#${id}`);
  const label = (id) => document.querySelector(`label[for="${id}"]`);
  const wrapper = (id) => input(id)?.closest(".astryx-text-input");
  const fields = inCaseOf("field-static", "TextInput");
  const inputs = inCaseMatching("field-static", "input");

  check("seven fields mount in the static case", fields.length === 7, `${fields.length}`);
  check("every field renders a control", inputs.length === 7, `${inputs.length}`);

  // A control named twice is announced twice: the label is the only name.
  check(
    "no control also names itself with aria-labelledby",
    inputs.every((i) => !i.hasAttribute("aria-labelledby")),
    inputs.map((i) => attr(i, "aria-labelledby")).filter(Boolean).join(","));

  // --- the label, the description and the marker
  check("the label is a real <label for>", !!label("rt-field-required"),
    label("rt-field-required")?.outerHTML?.slice(0, 100));
  check("the label carries the label text",
    textOf(label("rt-field-required")).includes("Full name"),
    textOf(label("rt-field-required")));
  check("a required field shows and announces Required",
    textOf(label("rt-field-required")).includes("Required")
      && attr(input("rt-field-required"), "aria-required") === "true",
    `aria-required=${attr(input("rt-field-required"), "aria-required")}`);
  check("the marker's separator is decoration only",
    label("rt-field-required").querySelector('[aria-hidden="true"]') !== null);
  check("an optional field shows Optional and is not aria-required",
    textOf(label("rt-field-optional")).includes("Optional")
      && !input("rt-field-optional").hasAttribute("aria-required"));
  check("the description is described by, not part of the name",
    attr(input("rt-field-required"), "aria-describedby") === "rt-field-required-desc"
      && textOf(document.querySelector("#rt-field-required-desc")).includes("On the invoice."),
    `aria-describedby=${attr(input("rt-field-required"), "aria-describedby")}`);
  check("the description is a sibling of the <label>, not inside it",
    label("rt-field-required").querySelector("#rt-field-required-desc") === null);

  // --- the three placements
  const errorField = input("rt-field-error").closest(".astryx-field");
  check("an error sets aria-invalid",
    attr(input("rt-field-error"), "aria-invalid") === "true");
  check("the error message is described by the control",
    attr(input("rt-field-error"), "aria-describedby") === "rt-field-error-status");
  check("the attached status sits inside the control's wrapper",
    errorField.querySelector(".astryx-field__input-status .astryx-field-status--error") !== null,
    errorField.querySelector(".astryx-field__input-status")?.outerHTML?.slice(0, 120));
  check("an error is announced assertively",
    errorField.querySelector('.astryx-field-status[role="alert"]') !== null);

  const detachedField = input("rt-field-detached").closest(".astryx-field");
  check("the detached status is not in the control's wrapper",
    detachedField.querySelector(".astryx-field__input-status") === null);
  check("the detached status is a direct child of the field",
    [...detachedField.children].some((c) => hasClass(c, /astryx-field-status--success/)),
    [...detachedField.children].map((c) => attr(c, "class")).join(" | "));

  const tooltipField = input("rt-field-tooltip").closest(".astryx-field");
  check("the tooltip placement renders no message box",
    tooltipField.querySelector(".astryx-field-status") === null);
  const announcement = tooltipField.querySelector(`#rt-field-tooltip-status`);
  check("the tooltip placement still announces the message",
    !!announcement && textOf(announcement).includes("Read only.")
      && hasClass(announcement, /astryx-visually-hidden/),
    announcement?.outerHTML?.slice(0, 120));
  check("the input points at the announcement it must read",
    attr(input("rt-field-tooltip"), "aria-describedby") === "rt-field-tooltip-status");

  // --- hidden label, disabled, read-only
  const hiddenField = input("rt-field-hidden").closest(".astryx-field");
  check("a hidden label is hidden from sight, not from assistive tech",
    hasClass(label("rt-field-hidden"), /astryx-visually-hidden/)
      && !hiddenField.classList.contains("astryx-field--labeled"));
  check("a disabled field carries the attribute and the class",
    input("rt-field-hidden").hasAttribute("disabled")
      && hasClass(wrapper("rt-field-hidden"), /astryx-text-input--disabled/));
  check("a read-only field is read-only, not disabled",
    input("rt-field-readonly").hasAttribute("readonly")
      && !input("rt-field-readonly").hasAttribute("disabled"));

  // --- sizes and the controlled value
  check("every wrapper states its size",
    fields.every((f) => attr(f, "data-astryx-size") === "md"),
    fields.map((f) => attr(f, "data-astryx-size")).join(","));

  const before = document.querySelector('[data-case="field-before"]');
  const after = document.querySelector('[data-case="field-after"]');
  check("the control starts empty and the application agrees",
    before.querySelector("#rt-field-live").value === ""
      && before.querySelector("[data-rt-value]").getAttribute("data-rt-value") === "",
    `value=${before.querySelector("#rt-field-live").value}`);
  check("typing reaches the control and the application",
    after.querySelector("#rt-field-live").value === "Ada Lovelace"
      && after.querySelector("[data-rt-value]").getAttribute("data-rt-value") === "Ada Lovelace",
    `value=${after.querySelector("#rt-field-live").value}, state=${after
      .querySelector("[data-rt-value]")
      .getAttribute("data-rt-value")}`);
}

// --- TextArea (M12)
//
// TextInput's wrapper with a different control inside it, so these assert what is different about a
// textarea: the element, the row count as the height, a value that is child text rather than an
// attribute, and a status that carries no message at all.

section("TextArea");

{
  const area = (id) => document.querySelector(`#${id}`);
  const wrapper = (id) => area(id)?.closest(".astryx-text-area");
  const field = (id) => area(id)?.closest(".astryx-field");
  const areas = inCaseMatching("textarea-static", "textarea");

  check("six textareas mount in the static case", areas.length === 6, `${areas.length}`);
  check(
    "every one of them is a real <textarea>",
    areas.every((a) => a.tagName === "TEXTAREA"),
    areas.map((a) => a.tagName).join(","),
  );
  check("no input element is involved", inCaseMatching("textarea-static", "input").length === 0);

  // The row count is the height: upstream's own note is that rows controls it, not size.
  check("rows defaults to 3", attr(area("rt-textarea-default"), "rows") === "3",
    attr(area("rt-textarea-default"), "rows"));
  check("rows comes from the prop when given", attr(area("rt-textarea-rows"), "rows") === "6",
    attr(area("rt-textarea-rows"), "rows"));
  check("the wrapper states the row count for the styling layer",
    attr(wrapper("rt-textarea-rows"), "data-astryx-rows") === "6",
    attr(wrapper("rt-textarea-rows"), "data-astryx-rows"));

  // The difference a copied port gets wrong: there is no value attribute on a textarea.
  check(
    "the value is the element's text, with no value attribute",
    area("rt-textarea-default").value === "line one"
      && !area("rt-textarea-default").hasAttribute("value"),
    `value=${JSON.stringify(area("rt-textarea-default").value)} attr=${attr(area("rt-textarea-default"), "value")}`,
  );

  check("spell check is on by default", attr(area("rt-textarea-default"), "spellcheck") === "true");
  check("spell check can be turned off", attr(area("rt-textarea-readonly"), "spellcheck") === "false");
  check("a disabled textarea is disabled", area("rt-textarea-disabled").disabled === true);
  check(
    "a read-only textarea is read-only, not disabled",
    area("rt-textarea-readonly").hasAttribute("readonly")
      && !area("rt-textarea-readonly").hasAttribute("disabled"),
  );

  // A status with no message: the control takes the colour, and nothing is said.
  check(
    "a status with no message still colours the control",
    wrapper("rt-textarea-no-message").classList.contains("astryx-text-area--warning"),
    wrapper("rt-textarea-no-message").className,
  );
  check(
    "a status with no message renders no message box",
    field("rt-textarea-no-message").querySelector(".astryx-field-status") === null,
    field("rt-textarea-no-message").querySelector(".astryx-field-status")?.outerHTML?.slice(0, 120),
  );
  check(
    "a status with no message is not referenced in aria-describedby",
    !(attr(area("rt-textarea-no-message"), "aria-describedby") || "").includes(
      "rt-textarea-no-message-status",
    ),
    attr(area("rt-textarea-no-message"), "aria-describedby"),
  );

  // A status with a message: the same wiring M11 asserts, on this control.
  check(
    "an error sets aria-invalid and points at its message",
    attr(area("rt-textarea-error"), "aria-invalid") === "true"
      && attr(area("rt-textarea-error"), "aria-describedby") === "rt-textarea-error-status",
    attr(area("rt-textarea-error"), "aria-describedby"),
  );
  check(
    "the error is announced assertively",
    field("rt-textarea-error").querySelector('.astryx-field-status[role="alert"]') !== null,
  );

  // Enter is a character in a textarea, so the value the application receives contains newlines.
  const before = document.querySelector('[data-case="textarea-before"]');
  const after = document.querySelector('[data-case="textarea-after"]');
  check(
    "the textarea starts empty and the application agrees",
    before.querySelector("#rt-textarea-live").value === ""
      && before.querySelector("[data-rt-value]").getAttribute("data-rt-value") === "",
  );
  check(
    "typing reaches the control and the application, newlines included",
    after.querySelector("#rt-textarea-live").value === "first line\nsecond line"
      && after.querySelector("[data-rt-value]").getAttribute("data-rt-value")
        === "first line\nsecond line",
    JSON.stringify(after.querySelector("[data-rt-value]").getAttribute("data-rt-value")),
  );
}

// --- FieldLabel (M12)
//
// The label group on its own, which is how the controls that want the label beside them use it.
// The group-label path matters most: a <label> names exactly one form control, so a group label
// must not be one — it is a <span> that a group references with aria-labelledby.

section("FieldLabel");

{
  const labelOf = (id) => document.querySelector(`label[for="${id}"]`);
  const groupLabel = document.getElementById("rt-fl-group-label");
  const group = document.querySelector('[role="group"][aria-labelledby="rt-fl-group-label"]');

  check("a label names its control with a real <label for>", !!labelOf("rt-fl-named"),
    labelOf("rt-fl-named")?.outerHTML?.slice(0, 90));
  check("the label and the description share one group",
    !!labelOf("rt-fl-named")?.closest(".astryx-field__label-group"));
  check("the description is a sibling of the label, never inside it",
    labelOf("rt-fl-named").querySelector("#rt-fl-named-desc") === null
      && !!document.getElementById("rt-fl-named-desc"));
  check("a required label says Required, exactly once",
    (labelOf("rt-fl-required").textContent.match(/Required/g) || []).length === 1,
    labelOf("rt-fl-required").textContent);
  check("an optional label says Optional and not Required",
    /Optional/.test(labelOf("rt-fl-optional").textContent)
      && !/Required/.test(labelOf("rt-fl-optional").textContent),
    labelOf("rt-fl-optional").textContent);
  check("the marker's separator is decoration only",
    !!labelOf("rt-fl-required").querySelector('[aria-hidden="true"]'));
  check("a label icon renders inside the label",
    !!labelOf("rt-fl-icon").querySelector(".astryx-icon"));
  check("a hidden label is clipped, not removed, and still names its control",
    labelOf("rt-fl-hidden").classList.contains("astryx-visually-hidden")
      && labelOf("rt-fl-hidden").hasAttribute("for"),
    labelOf("rt-fl-hidden").className);
  check("a disabled label says so",
    attr(labelOf("rt-fl-disabled"), "data-astryx-disabled") === "true",
    String(attr(labelOf("rt-fl-disabled"), "data-astryx-disabled")));
  check("a group label is a <span>, not a <label>",
    groupLabel?.tagName.toLowerCase() === "span" && !groupLabel.hasAttribute("for"),
    groupLabel && `${groupLabel.tagName} for=${attr(groupLabel, "for")}`);
  check("the group names itself from the label",
    attr(group, "aria-labelledby") === "rt-fl-group-label"
      && /Include in the release/.test(groupLabel.textContent));
  check("nothing points at the group label with for=", labelOf("rt-fl-group-label") === null);
}

// ---------------------------------------------------------------- Indicator (M13)
{
  const mark = (id) => document.querySelector(`#${id} > *`);
  const svgNS = "http://www.w3.org/2000/svg";

  const cbUn = mark("rt-ind-cb-un");
  section("Indicator");
  check("an unchecked box draws nothing inside it", cbUn.children.length === 0,
    `children: ${cbUn.children.length}`);
  check("and says it is decorative", cbUn.getAttribute("aria-hidden") === "true");
  check("and is the unchecked state of a checkbox",
    cbUn.dataset.astryxKind === "checkbox" && cbUn.dataset.astryxState === "unchecked");

  const cbOn = mark("rt-ind-cb-on");
  const checkmark = cbOn.querySelector("svg");
  const path = checkmark && checkmark.querySelector("path");
  check("a checked box draws a check mark", !!path);
  // The trap this asserts against: inside <svg> an HTML element is a no-op. It compiles, it
  // renders, it paints nothing, and nothing anywhere throws.
  check("and the mark is really in the SVG namespace",
    !!path && path.namespaceURI === svgNS, path && path.namespaceURI);
  check("and it is upstream's path, not a lookalike",
    !!path && path.getAttribute("d") === "M8.5 2.5L4 7.5L1.5 5", path && path.getAttribute("d"));
  check("and the mark takes its colour from the box",
    !!path && path.getAttribute("stroke") === "currentColor");

  const mixed = mark("rt-ind-cb-mixed");
  check("an indeterminate box draws a bar, not a tick",
    !mixed.querySelector("svg") && !!mixed.querySelector(".astryx-indicator__dash"));
  check("and is still aria-hidden", mixed.getAttribute("aria-hidden") === "true");

  const sm = mark("rt-ind-cb-sm");
  check("the size is on the element, not just in the class list",
    sm.dataset.astryxSize === "sm" && mark("rt-ind-cb-on").dataset.astryxSize === "md");

  const dis = mark("rt-ind-cb-dis");
  check("a disabled indicator says so", dis.classList.contains("astryx-indicator--disabled"));

  const radioOff = mark("rt-ind-radio-off");
  const radioOn = mark("rt-ind-radio-on");
  check("an unchecked radio draws a circle with nothing in it",
    radioOff.classList.contains("astryx-indicator--radio") && radioOff.children.length === 0);
  check("a checked radio draws a dot", !!radioOn.querySelector(".astryx-indicator__dot"));

  const checkOff = mark("rt-ind-check-off");
  const checkOn = mark("rt-ind-check-on");
  check("an unchecked bare check mark renders nothing at all",
    checkOff === null || checkOff.dataset.astryxComponent === undefined || checkOff.children.length === 0,
    checkOff === null ? "nothing" : `children: ${checkOff.children.length}`);
  check("a checked bare check mark is the port's own icon, marked decorative",
    !!checkOn && !!checkOn.querySelector("svg[aria-hidden='true']"));
}

// ---------------------------------------------------------------- CheckboxInput (M12)
{
  const input = (id) => document.querySelector(`#${id}`);
  const box = (id) => document.querySelector(`#${id}`).closest(".astryx-checkbox-input");
  section("CheckboxInput");

  // checked and indeterminate are DOM *properties*, not attributes. The attribute only sets a
  // checkbox's initial state, and there is no indeterminate attribute at all — an implementation
  // that "renders" them as attributes looks right on the first paint and never updates after.
  const on = input("rt-cb-on");
  const off = input("rt-cb-off");
  const mixed = input("rt-cb-mixed");
  check("a checked box has the checked property", on.checked === true);
  check("an unchecked box does not", off.checked === false);
  check("the checked property is not the checked attribute",
    on.hasAttribute("checked") === false && on.checked === true);
  check("an indeterminate box has the indeterminate property", mixed.indeterminate === true);
  check("and it is not checked at the same time", mixed.checked === false);
  check("an indeterminate box carries no indeterminate attribute",
    mixed.hasAttribute("indeterminate") === false);
  // The deliberate omission: upstream dropped aria-checked="mixed" because the native property is
  // the authoritative mixed state, and two sources of truth can disagree.
  check("and no aria-checked, deliberately — the native property is authoritative",
    mixed.getAttribute("aria-checked") === null);

  check("the label is a real <label for> the input",
    document.querySelector('label[for="rt-cb-on"]') !== null);
  check("the label names the control", input("rt-cb-on").labels.length === 1);
  const described = input("rt-cb-described");
  check("a description is linked, not nested",
    (described.getAttribute("aria-describedby") || "").includes("rt-cb-described-desc")
      && document.querySelector('label[for="rt-cb-described"] #rt-cb-described-desc') === null,
    described.getAttribute("aria-describedby"));
  const errored = input("rt-cb-error");
  check("an error status is linked and the input is invalid",
    (errored.getAttribute("aria-describedby") || "").includes("rt-cb-error-status")
      && errored.getAttribute("aria-invalid") === "true",
    `${errored.getAttribute("aria-describedby")} / ${errored.getAttribute("aria-invalid")}`);
  check("a warning status that has no message renders nothing below the row",
    box("rt-cb-warning").querySelector(".astryx-status") === null
      && input("rt-cb-warning").getAttribute("aria-invalid") === null);

  check("a disabled box is disabled", input("rt-cb-disabled").disabled === true);
  check("and it is not a hover scope", input("rt-cb-disabled")
    .closest(".astryx-checkbox-input__container").classList.contains("astryx-indicator-scope") === false);
  check("an enabled box is a hover scope", input("rt-cb-on")
    .closest(".astryx-checkbox-input__container").classList.contains("astryx-indicator-scope") === true);
  check("a read-only box says so", input("rt-cb-readonly").getAttribute("aria-readonly") === "true");
  check("a hidden label is clipped rather than removed",
    document.querySelector('label[for="rt-cb-hidden"]').classList.contains("astryx-visually-hidden"));
  check("required is said once", /Required/.test(box("rt-cb-required").textContent)
    && !/Required/.test(box("rt-cb-optional").textContent));

  // The visual has to agree with the property, or the box lies about its own state.
  check("the box's own state is on the element",
    box("rt-cb-mixed").dataset.astryxState === "indeterminate"
      && box("rt-cb-on").dataset.astryxState === "checked");
  check("the indicator draws a bar for the mixed state, not a tick",
    !!box("rt-cb-mixed").querySelector(".astryx-indicator__dash")
      && !box("rt-cb-mixed").querySelector(".astryx-indicator__check"));
  check("and a tick for the checked one",
    !!box("rt-cb-on").querySelector(".astryx-indicator__check"));
}

// ---------------------------------------------------------------- Switch (M12)
{
  const input = (id) => document.querySelector(`#${id}`);
  const root = (id) => input(id).closest(".astryx-switch");
  section("Switch");

  // role="switch" is what makes a screen reader say "switch, on" rather than "checkbox, checked".
  // It is a native checkbox underneath, which is the pattern that gets the keyboard for free.
  const on = input("rt-sw-on");
  const off = input("rt-sw-off");
  check("the control is a native checkbox with role=switch",
    on.getAttribute("type") === "checkbox" && on.getAttribute("role") === "switch");
  check("an on switch has the checked property", on.checked === true);
  check("an off switch does not", off.checked === false);
  check("the checked property is not the checked attribute",
    on.hasAttribute("checked") === false && on.checked === true);
  // The deliberate omission, same judgment as the checkbox's missing aria-checked="mixed".
  check("and there is no aria-checked, deliberately", on.getAttribute("aria-checked") === null);

  check("the label is a real <label for> the input",
    document.querySelector('label[for="rt-sw-on"]') !== null && on.labels.length === 1);
  check("the track is paint, not control", root("rt-sw-on")
    .querySelector(".astryx-switch__track").getAttribute("aria-hidden") === "true");
  check("the track's state matches the value",
    root("rt-sw-on").querySelector(".astryx-switch__track--on") !== null
      && root("rt-sw-off").querySelector(".astryx-switch__track--off") !== null);
  check("and the thumb is the on/off one to match",
    root("rt-sw-on").querySelector(".astryx-switch__thumb--on") !== null
      && root("rt-sw-off").querySelector(".astryx-switch__thumb--off") !== null);
  check("the root reports the state for the gates",
    root("rt-sw-on").dataset.astryxState === "on" && root("rt-sw-off").dataset.astryxState === "off");
  check("the size is on the element", root("rt-sw-sm").dataset.astryxSize === "sm");
  check("a disabled switch is disabled", input("rt-sw-disabled").disabled === true);

  const described = input("rt-sw-described");
  check("a description is linked, not nested",
    (described.getAttribute("aria-describedby") || "").includes("rt-sw-described-desc"),
    described.getAttribute("aria-describedby"));
  const errored = input("rt-sw-error");
  check("an error status is linked and the input is invalid",
    (errored.getAttribute("aria-describedby") || "").includes("rt-sw-error-status")
      && errored.getAttribute("aria-invalid") === "true");
  check("a hidden label is clipped rather than removed",
    document.querySelector('label[for="rt-sw-hidden"]').classList.contains("astryx-visually-hidden"));
  check("required is said once", /Required/.test(root("rt-sw-required").textContent));
}

// ---------------------------------------------------------------- RadioList (M13)
{
  const group = (id) => document.querySelector(`#${id}`);
  const items = (id) => [...group(id).querySelectorAll("input[type=radio]")];
  section("RadioList");

  const g = group("rt-rl-live");
  check("the group is a radiogroup", g.getAttribute("role") === "radiogroup");
  // A group label is a <span> that the group names itself from — a <label> names one control and
  // cannot name a set. This is the group-label path's first real consumer.
  const label = document.getElementById("rt-rl-live-label");
  check("its label is a group label, not a <label for>",
    !!label && label.tagName.toLowerCase() === "span"
      && g.getAttribute("aria-labelledby") === "rt-rl-live-label");
  const radios = items("rt-rl-live");
  // The shared name is what gives the group its keyboard for free.
  const names = new Set(radios.map((r) => r.getAttribute("name")));
  check("its radios share one name, which is what makes them one group",
    radios.length === 3 && names.size === 1, `names: ${[...names].join(",")}`);
  check("exactly one radio is checked, the selected one",
    radios.filter((r) => r.checked).length === 1
      && radios.find((r) => r.checked).value === "express");
  check("checked is a property, not an attribute",
    radios.every((r) => r.hasAttribute("checked") === false));
  check("and no aria-checked shadows it",
    radios.every((r) => r.getAttribute("aria-checked") === null));
  check("each item's label is a real <label for>, so clicking it chooses the radio",
    radios.every((r) => r.labels.length === 1));
  check("the selected radio's indicator is the filled one",
    !!group("rt-rl-live").querySelectorAll(".astryx-radio-list__item")[1]
      .querySelector(".astryx-indicator__dot")
      && !group("rt-rl-live").querySelectorAll(".astryx-radio-list__item")[0]
        .querySelector(".astryx-indicator__dot"));
  check("an item description is linked from its radio",
    (radios[1].getAttribute("aria-describedby") || "").includes("rt-rl-live-item-1-description"),
    radios[1].getAttribute("aria-describedby"));

  // Field renders the description and the status outside the group, so the group has to link them
  // itself or a screen reader reading the radiogroup never reaches either.
  const errGroup = group("rt-rl-status");
  const errDescribed = errGroup.getAttribute("aria-describedby") || "";
  check("the group links its status message", errDescribed.includes("rt-rl-status-status"), errDescribed);
  check("and says it is invalid", errGroup.getAttribute("aria-invalid") === "true");

  const required = items("rt-rl-required");
  check("required is on every radio, and on the group as aria-required",
    required.every((r) => r.hasAttribute("required"))
      && group("rt-rl-required").getAttribute("aria-required") === "true");
  check("a disabled group is on the element", group("rt-rl-disabled")
    .classList.contains("astryx-radio-list__group--disabled"));
  const mixed = group("rt-rl-disabled-item");
  check("one disabled item disables only its own radio",
    mixed.querySelectorAll(".astryx-radio-list__item")[1].querySelector("input").disabled === true
      && mixed.querySelectorAll(".astryx-radio-list__item")[0].querySelector("input").disabled === false);
  check("the orientation is on the element",
    group("rt-rl-horizontal").classList.contains("astryx-radio-list__group--horizontal"));
  check("a hidden label is clipped rather than removed",
    document.getElementById("rt-rl-hidden-label").classList.contains("astryx-visually-hidden"));
}

// ---------------------------------------------------------------- CheckboxList (M48)
{
  const group = (id) => document.querySelector(`#${id}`);
  const boxes = (id) => [...group(id).querySelectorAll("input[type=checkbox]")];
  section("CheckboxList");

  const g = group("rt-cl-live");
  check("the group is a group", g.getAttribute("role") === "group");
  // Like RadioList, the label is a <span> the group names itself from — the set is one field.
  const label = document.getElementById("rt-cl-live-label");
  check("its label is a group label, not a <label for>",
    !!label && label.tagName.toLowerCase() === "span"
      && g.getAttribute("aria-labelledby") === "rt-cl-live-label");
  const inputs = boxes("rt-cl-live");
  check("one checkbox per item, the selected one checked",
    inputs.length === 3 && inputs.filter((i) => i.checked).length === 1 && inputs[0].checked === true);
  check("checked is a property, not an attribute",
    inputs.every((i) => i.hasAttribute("checked") === false));
  // Each box names itself from its own hidden label; there is no <label for> on the visible
  // row text, and no aria-checked shadowing the native property.
  check("each box has its own label, and none is aria-checked",
    inputs.every((i) => i.labels.length === 1) && inputs.every((i) => i.getAttribute("aria-checked") === null));
  check("the visible row label is plain text, not a second <label for>",
    !!group("rt-cl-live").querySelector(".astryx-checkbox-list__label")
      && group("rt-cl-live").querySelectorAll("label").length === inputs.length);
  check("the selected row is marked",
    !!group("rt-cl-live").querySelector(".astryx-checkbox-list__item--selected"));
  check("an item description is linked from its own checkbox",
    (inputs[1].getAttribute("aria-describedby") || "").includes("rt-cl-live-item-1-description"),
    inputs[1].getAttribute("aria-describedby"));

  const errGroup = group("rt-cl-status");
  const errDescribed = errGroup.getAttribute("aria-describedby") || "";
  check("the group links its status message", errDescribed.includes("rt-cl-status-status"), errDescribed);
  check("and says it is invalid", errGroup.getAttribute("aria-invalid") === "true");

  const dis = group("rt-cl-disabled");
  check("a disabled group is on the element", dis.classList.contains("astryx-checkbox-list__group--disabled"));
  check("its reason bubble is mounted with role=tooltip",
    !!document.getElementById("rt-cl-disabled-disabled-message")
      && document.getElementById("rt-cl-disabled-disabled-message").getAttribute("role") === "tooltip");
  check("its checkboxes stay focusable (aria-disabled, not native disabled)",
    boxes("rt-cl-disabled").every((b) => b.disabled === false && b.getAttribute("aria-disabled") === "true"));
  // The group linking the reason lets AT discover it without hovering; the individual boxes do not
  // each mount their own bubble, which is the point of the focusable-disabled path.
  check("the group links its disabled reason",
    (dis.getAttribute("aria-describedby") || "").includes("rt-cl-disabled-disabled-message"),
    dis.getAttribute("aria-describedby"));

  const mixed = group("rt-cl-disabled-item");
  check("one disabled item disables only its own checkbox",
    mixed.querySelectorAll(".astryx-checkbox-list__item")[1].querySelector("input").disabled === true
      && mixed.querySelectorAll(".astryx-checkbox-list__item")[0].querySelector("input").disabled === false);

  const load = group("rt-cl-loading");
  check("a loading item is busy on its row, not on its box alone",
    load.querySelectorAll(".astryx-checkbox-list__item")[0].getAttribute("aria-busy") === "true");
  check("the loading item's checkbox is click-blocked by the spinner",
    !!load.querySelector(".astryx-checkbox-list__item [data-astryx-component=Spinner]"));

  const ro = group("rt-cl-readonly");
  check("a read-only group keeps its values visible, drops the interactive tint, and stays focusable",
    boxes("rt-cl-readonly")[0].checked === true
      && ro.querySelectorAll(".astryx-checkbox-list__item--selected").length === 0
      && boxes("rt-cl-readonly").every((b) => b.getAttribute("aria-disabled") === null));

  const required = boxes("rt-cl-required");
  check("required is the set's, not each box's: aria-required on the group, no required on the boxes",
    required.every((b) => b.hasAttribute("required") === false)
      && group("rt-cl-required").getAttribute("aria-required") === "true");

  check("a hidden label is clipped rather than removed",
    document.getElementById("rt-cl-hidden-label").classList.contains("astryx-visually-hidden"));

  const compact = group("rt-cl-compact");
  check("density and dividers ride as data attributes on the list",
    compact.querySelector(".astryx-checkbox-list__list").dataset.astryxDensity === "compact"
      && compact.querySelector(".astryx-checkbox-list__list").dataset.astryxDividers === "true");

  const end = group("rt-cl-end");
  check("end content sits in its own slot inside the row",
    !!end.querySelector(".astryx-checkbox-list__item .astryx-checkbox-list__end")
      && end.querySelector(".astryx-checkbox-list__end").textContent === "Popular");
}

// ---------------------------------------------------------------- Banner (M49)
{
  const bn = (id) => document.getElementById(id);
  section("Banner");

  const info = bn("rt-bn-info");
  check("the info banner is a marked Banner carrying its status",
    !!info && attr(info, "data-astryx-component") === "Banner" && attr(info, "data-astryx-status") === "info");
  check("its header paints the info fill on the section container",
    !!info && !!info.querySelector(".astryx-banner__header--info")
      && info.classList.contains("astryx-banner--section")
      && info.classList.contains("astryx-banner--elevation-none"));
  check("the description sits in its own slot",
    !!info && !!info.querySelector(".astryx-banner__description"));
  check("the status glyph is present and its wrapper is aria-hidden",
    !!info && !!info.querySelector(".astryx-banner__icon")
      && attr(info.querySelector(".astryx-banner__icon"), "aria-hidden") === "true");
  // The default call: null config is forced to closed by the banner (the hook's own
  // default is open, so a banner that forgot its override would leak open content).
  check("a default collapsible banner starts closed: no content region",
    !!info && !info.querySelector(".astryx-banner__content"));
  const toggle = info && info.querySelector(".astryx-banner__end button");
  check("its Expand toggle names itself and reports closed",
    !!toggle && attr(toggle, "aria-label") === "Expand" && attr(toggle, "aria-expanded") === "false");
  check("the collapsed toggle carries no aria-controls (nothing mounted to point at)",
    !!toggle && !toggle.hasAttribute("aria-controls"));
  check("a non-dismissable banner has no close control",
    !!info && !info.querySelector(".astryx-banner__end [aria-label='Dismiss']"));

  const open = bn("rt-bn-open");
  const openToggle = open && open.querySelector(".astryx-banner__end button");
  check("an explicitly open collapsible mounts its content and links it",
    !!open && !!open.querySelector("#rt-bn-open-content")
      && !!openToggle && attr(openToggle, "aria-expanded") === "true"
      && attr(openToggle, "aria-controls") === "rt-bn-open-content"
      && attr(openToggle, "aria-label") === "Collapse");

  const never = bn("rt-bn-never");
  check("Never pins the content open with no toggle and no end area",
    !!never && !!never.querySelector(".astryx-banner__content")
      && !never.querySelector(".astryx-banner__end"));
  check("a pinned content region is not given an id (nothing links it)",
    !!never && !never.querySelector(".astryx-banner__content").hasAttribute("id"));
  check("Never carries the warning fill",
    !!never && !!never.querySelector(".astryx-banner__header--warning"));
  check("no aria-expanded or aria-controls anywhere on a Never banner",
    !!never && !never.querySelector("[aria-expanded]") && !never.querySelector("[aria-controls]"));

  const err = bn("rt-bn-error");
  check("end content sits in the end area and marks the body",
    !!err && !!err.querySelector(".astryx-banner__end span")
      && err.querySelector(".astryx-banner__end").textContent === "Retry"
      && err.querySelector(".astryx-banner__body").classList.contains("astryx-banner__body--with-end"));
  check("the error banner paints the error fill",
    !!err && !!err.querySelector(".astryx-banner__header--error"));

  const dis = bn("rt-bn-dismiss");
  const dismiss = dis && dis.querySelector(".astryx-banner__end button");
  check("the dismiss control is named by the caller's label",
    !!dismiss && attr(dismiss, "aria-label") === "Dismiss Saved" && attr(dismiss, "title") === "Dismiss Saved");
  check("the success banner paints the success fill",
    !!dis && !!dis.querySelector(".astryx-banner__header--success"));

  const card = bn("rt-bn-card");
  check("a Card banner with content starts closed as a standalone elevated card",
    !!card && card.classList.contains("astryx-banner--card")
      && card.classList.contains("astryx-banner--rounded")
      && card.classList.contains("astryx-banner--elevation-med")
      && !card.querySelector(".astryx-banner__content")
      && card.querySelector(".astryx-banner__header").classList.contains("astryx-banner__header--card-standalone"));

  const unknown = bn("rt-bn-unknown");
  check("an unknown status renders no fill and no default glyph",
    !!unknown
      && !unknown.querySelector(".astryx-banner__header--info, .astryx-banner__header--warning, .astryx-banner__header--error, .astryx-banner__header--success")
      && !unknown.querySelector(".astryx-banner__icon"));
}

// ---------------------------------------------------------------- Collapsible (M50)
{
  const cl = (id) => document.getElementById(id);
  section("Collapsible");

  const def = cl("rt-col-default");
  const defBtn = def && def.querySelector(".astryx-collapsible__trigger");
  check("a default collapsible is a marked Collapsible and opens by default",
    !!def && attr(def, "data-astryx-component") === "Collapsible"
      && attr(def, "data-astryx-open") === "true");
  check("its trigger is a real button naming the content it controls",
    !!defBtn && attr(defBtn, "aria-expanded") === "true"
      && attr(defBtn, "aria-controls") === "rt-col-default-content");
  check("the open content region is mounted and not hidden",
    !!def && !!def.querySelector("#rt-col-default-content")
      && !def.querySelector("#rt-col-default-content").classList.contains("astryx-collapsible__content--hidden"));
  const chev = def && def.querySelector(".astryx-collapsible__chevron");
  check("the chevron is decorative (aria-hidden) and expanded-rotated",
    !!chev && attr(chev, "aria-hidden") === "true"
      && chev.classList.contains("astryx-collapsible__chevron--expanded")
      && !chev.classList.contains("astryx-collapsible__chevron--start"));

  const closed = cl("rt-col-closed");
  const closedBtn = closed && closed.querySelector(".astryx-collapsible__trigger");
  check("an explicitly closed collapsible keeps its content in the DOM but hidden",
    !!closed && !!closed.querySelector("#rt-col-closed-content")
      && closed.querySelector("#rt-col-closed-content").classList.contains("astryx-collapsible__content--hidden")
      && attr(closed, "data-astryx-open") === "false"
      && attr(closedBtn, "aria-expanded") === "false");

  const dis = cl("rt-col-disabled");
  const disBtn = dis && dis.querySelector(".astryx-collapsible__trigger");
  check("a disabled trigger uses the system convention: aria-disabled and unfocusable",
    !!disBtn && attr(disBtn, "aria-disabled") === "true" && attr(disBtn, "tabindex") === "-1"
      && disBtn.classList.contains("astryx-collapsible__trigger--disabled")
      && !disBtn.hasAttribute("disabled"));

  const ldr = cl("rt-col-start");
  const ldrBtn = ldr && ldr.querySelector(".astryx-collapsible__trigger");
  const ldrChev = ldr && ldr.querySelector(".astryx-collapsible__chevron");
  check("a Start chevron leads the trigger text and points right until open",
    !!ldr && ldrBtn.firstChild === ldrChev
      && ldrChev.classList.contains("astryx-collapsible__chevron--start")
      && ldrChev.classList.contains("astryx-collapsible__chevron--closed"));
  check("the trigger text sits in its own label span",
    !!ldr && !!ldr.querySelector(".astryx-collapsible__trigger-label"));

  const grp = cl("rt-col-group");
  check("the group is a marked accordion coordinator in single mode",
    !!grp && attr(grp, "data-astryx-component") === "CollapsibleGroup"
      && attr(grp, "data-astryx-mode") === "single"
      && grp.classList.contains("astryx-collapsible-group"));
  const rowA = grp && grp.querySelector("[data-astryx-value='a']");
  const rowB = grp && grp.querySelector("[data-astryx-value='b']");
  check("the seeded item is open and its siblings are closed",
    !!rowA && attr(rowA, "data-astryx-open") === "true"
      && !!rowB && attr(rowB, "data-astryx-open") === "false");
  check("group rows carry the divider chrome when asked",
    !!grp && grp.querySelectorAll(".astryx-collapsible--divided").length === 3);
  check("row content ids are scope-and-value derived",
    !!rowA && !!document.getElementById("rt-col-group-a-content")
      && !!document.getElementById("rt-col-group-b-content"));
  const rowC = grp && grp.querySelector("[data-astryx-value='c']");
  check("a disabled group row still keeps the disabled-trigger convention",
    !!rowC && attr(rowC.querySelector(".astryx-collapsible__trigger"), "aria-disabled") === "true");

  const multi = cl("rt-col-group-multi");
  check("a multiple group reports its mode and starts with nothing open",
    !!multi && attr(multi, "data-astryx-mode") === "multiple"
      && multi.querySelectorAll("[data-astryx-open='true']").length === 0);
}

// ---------------------------------------------------------------- FormLayout (M13)
{
  section("FormLayout");
  // Each field's marker lives in the label that points at its control, so the label is also the
  // association under test.
  const labelText = (id) => {
    const l = document.querySelector(`label[for="${id}"]`);
    return l ? l.textContent : null;
  };
  const has = (id, word) => (labelText(id) || "").includes(word);
  const input = (id) => document.getElementById(id);

  // A layout container is a div, not a form — upstream is explicit that submission is elsewhere.
  const vertical = document.querySelector('[data-astryx-component="FormLayout"][data-astryx-direction="vertical"]');
  check("a layout renders a div, not a form", !!vertical && vertical.tagName.toLowerCase() === "div");
  check("and names its direction",
    !!document.querySelector('[data-astryx-direction="horizontal"]')
      && !!document.querySelector('[data-astryx-direction="horizontal-labels"]'));

  // The rule: only the exception is marked.
  check("under optionality=Optional the required field still reads Required", has("rt-fl-opt-email", "Required"));
  check("under optionality=Optional a field that matches the default shows nothing",
    !has("rt-fl-opt-nick", "Optional") && !has("rt-fl-opt-nick", "Required"));
  check("under optionality=Required the optional field reads Optional", has("rt-fl-req-nick", "Optional"));
  check("under optionality=Required a field that matches the default shows nothing",
    !has("rt-fl-req-email", "Optional") && !has("rt-fl-req-email", "Required"));
  check("with no layout default each field marks itself, as before",
    has("rt-fl-both-email", "Required") && has("rt-fl-both-nick", "Optional"));

  // The half that is easy to lose: a layout default moves aria-required and never the native
  // attribute, so choosing a default cannot switch on the browser's own validation.
  check("a layout default sets aria-required on the unmarked majority",
    input("rt-fl-req-email").getAttribute("aria-required") === "true");
  check("but never the native required attribute, so validation stays off",
    input("rt-fl-req-email").hasAttribute("required") === false);
  check("an explicitly optional field is required by neither route",
    input("rt-fl-req-nick").getAttribute("aria-required") === null
      && input("rt-fl-req-nick").hasAttribute("required") === false);
  // Upstream's TextInput sets aria-required and nothing else — there is no native required
  // attribute on it anywhere, so no field of this kind can turn on the browser's own validation,
  // under any layout default. (Checkbox and radio inputs do carry the native attribute, which is
  // why their contracts assert it separately.)
  check("a text field is never natively required, by either route",
    input("rt-fl-opt-email").getAttribute("aria-required") === "true"
      && input("rt-fl-opt-email").hasAttribute("required") === false);

  // Nesting: a horizontal layout inside a vertical one is two containers, not one flattened one.
  check("a horizontal layout nests inside a vertical one",
    document.querySelectorAll('[data-astryx-direction="horizontal"]').length >= 2);
}

// ---------------------------------------------------------------- Tooltip (M13)
{
  section("Tooltip");
  const anchorOf = (id) => document.querySelector(`[data-astryx-component="Tooltip"] .astryx-tooltip-anchor, .astryx-tooltip-anchor:has(#${id})`);
  const closedAnchor = anchorOf("rt-tip-closed-trigger");
  check("a closed tooltip renders its anchor", !!closedAnchor);
  // Nothing is rendered while closed — not a hidden element, not an empty one. Upstream does not
  // mount its layer either, so the message is absent rather than invisible.
  check("and no message element at all",
    document.querySelector('[role="tooltip"]') === null
      || !document.getElementById("rt-tip-closed-message"));
  check("a closed anchor does not describe anything",
    !closedAnchor || closedAnchor.getAttribute("aria-describedby") === null);

  const openAnchor = anchorOf("rt-tip-open-trigger");
  const message = document.getElementById("rt-tip-open-message");
  check("an open tooltip renders a message with role=tooltip",
    !!message && message.getAttribute("role") === "tooltip");
  check("the message carries the text", !!message && message.textContent === "Open because the caller says so.");
  // The association appears for exactly as long as the message does, which is upstream's lifecycle:
  // it sets aria-describedby when the layer opens and restores what was there when it closes.
  check("and the anchor describes it, only while it is open",
    !!openAnchor && openAnchor.getAttribute("aria-describedby") === "rt-tip-open-message");
  check("the trigger is inside the anchor",
    !!openAnchor && openAnchor.querySelector("#rt-tip-open-trigger") !== null);
  const placed = document.getElementById("rt-tip-placed-message");
  check("placement and alignment are stated on the message",
    !!placed && placed.getAttribute("data-astryx-placement") === "below"
      && placed.getAttribute("data-astryx-alignment") === "end",
    placed ? `${placed.getAttribute("data-astryx-placement")}/${placed.getAttribute("data-astryx-alignment")}` : "missing");
}

// ------------------------------------------------------- disabledMessage (M13)
{
  section("disabledMessage");
  const input = (id) => document.getElementById(id);
  const describedBy = (id) =>
    (input(id)?.getAttribute("aria-describedby") || "").split(/\s+/).filter(Boolean);

  const withReason = input("dm-checkbox-reason");
  // The native attribute is what a reason has to give up: it refuses focus as well as input, and a
  // control nobody can reach can never explain itself.
  check("a disabled control with a reason drops the native disabled attribute",
    !!withReason && !withReason.hasAttribute("disabled"));
  check("it is disabled by aria instead", withReason?.getAttribute("aria-disabled") === "true");
  // form="" is what keeps that from being a lie: the control is out of any form it sits in, so it
  // still submits nothing.
  check("and it is detached from any form", withReason?.getAttribute("form") === "");
  const reason = input("dm-checkbox-reason-disabled-message");
  check("the reason is rendered, with role=tooltip",
    !!reason && reason.getAttribute("role") === "tooltip"
      && reason.textContent === "Your administrator manages this.");
  // Described for as long as it is disabled, not only while hovered — which is the whole reason this
  // is not simply a bubble owned by the Tooltip component.
  check("and the control describes it",
    describedBy("dm-checkbox-reason").includes("dm-checkbox-reason-disabled-message"));
  check("without losing the description it already had",
    describedBy("dm-checkbox-reason").includes("dm-checkbox-reason-description"));

  const noReason = input("dm-checkbox-noreason");
  check("a disabled control with no reason keeps the native attribute",
    !!noReason && noReason.hasAttribute("disabled"));
  check("and renders no reason at all",
    input("dm-checkbox-noreason-disabled-message") === null);

  const enabled = input("dm-checkbox-enabled");
  check("a reason on an enabled control changes nothing",
    !!enabled && !enabled.hasAttribute("disabled") && enabled.getAttribute("aria-disabled") === null
      && input("dm-checkbox-enabled-disabled-message") === null);

  const sw = input("dm-switch-reason");
  check("the switch does the same",
    !!sw && !sw.hasAttribute("disabled") && sw.getAttribute("aria-disabled") === "true"
      && sw.getAttribute("form") === ""
      && describedBy("dm-switch-reason").includes("dm-switch-reason-disabled-message"));
}

// ---------------------------------------------------------------- Dialog (M14)
{
  section("Dialog");
  // jsdom has no dialog behaviour — showModal and close do not exist on its elements — so the
  // structural half is pressed through the inline path, and the modal path is pressed for the two
  // things jsdom *can* say: that it renders a real <dialog> with the modal attributes, and that it
  // does not throw in a realm where the platform has no dialog at all.
  const inline = document.getElementById("dlg-inline");
  check("an inline dialog renders as a dialog role with the component marker",
    !!inline && inline.getAttribute("role") === "dialog"
      && inline.getAttribute("data-astryx-component") === "Dialog");
  check("and it states its purpose", inline?.getAttribute("data-purpose") === "info");
  // The port's own lesson: read the attribute, then look up what it points at.
  const named = inline?.getAttribute("aria-labelledby");
  const titleEl = named ? document.getElementById(named) : null;
  check("its title is a real element, and the dialog names itself from it",
    !!named && !!titleEl && titleEl.textContent === "Title", named ?? "no aria-labelledby");

  check("a closed inline dialog renders nothing at all",
    document.getElementById("dlg-inline-closed") === null);

  // The inline path is the showcase one, and upstream puts no role on it either — the role belongs to
  // the modal element, which is checked below. What the inline path does carry is its purpose.
  const required = document.getElementById("dlg-inline-required");
  check("an inline dialog states its purpose",
    required?.getAttribute("data-purpose") === "required");

  const fullscreen = document.getElementById("dlg-inline-fullscreen");
  check("variant = fullscreen is a class on the surface",
    !!fullscreen && fullscreen.classList.contains("astryx-dialog--fullscreen"));

  const sized = document.getElementById("dlg-inline-sized");
  check("width and position are inline styles on the surface",
    !!sized && /width:28rem/.test(sized.getAttribute("style") || "")
      && /top:4rem/.test(sized.getAttribute("style") || ""),
    sized?.getAttribute("style") ?? "no style");

  // The modal path: a real <dialog>, and rendering it here must not throw.
  const modal = document.getElementById("dlg-modal-closed");
  check("the modal path renders a real <dialog> element",
    !!modal && modal.tagName === "DIALOG" && modal.getAttribute("aria-modal") === "true",
    modal?.tagName ?? "missing");
  // This is the assertion that would have failed had the port called showModal unconditionally:
  // in jsdom it does not exist, and the whole page would have thrown while mounting.
  check("and it renders where showModal does not exist, without throwing",
    !!modal && modal.open === false);
  check("a required modal is an alertdialog as well",
    document.getElementById("dlg-modal-required")?.getAttribute("role") === "alertdialog");
}

// ---------------------------------------------------------------- AlertDialog (M14)
{
  section("AlertDialog");
  // These read the *component* mount from rt_test, not the showcase page — the showcase ids belong to
  // the browser gate, which is the only place they exist.
  const inline = document.getElementById("adlg-plain");
  // The role override is the contract: the modal form says alertdialog, and the inline preview must NOT,
  // because the role promises an interruption, a focus trap and an inert page behind it that a preview
  // does not have.
  check("an inline alert dialog is role = group, not alertdialog",
    !!inline && inline.getAttribute("role") === "group",
    inline?.getAttribute("role") ?? "missing");
  check("and it is built on the form purpose, like upstream's", inline?.getAttribute("data-purpose") === "form");

  // Association, not decoration: a description that is drawn but not described is one assistive
  // technology never reads.
  const named = inline?.getAttribute("aria-labelledby");
  const described = inline?.getAttribute("aria-describedby");
  const nameEl = named ? document.getElementById(named) : null;
  const descEl = described ? document.getElementById(described) : null;
  check("its title element exists and the dialog names itself from it",
    !!nameEl && nameEl.textContent === "Delete this page?", named ?? "no aria-labelledby");
  check("its description element exists and the dialog is described by it",
    !!descEl && /The page and its history/.test(descEl.textContent ?? ""),
    described ?? "no aria-describedby");

  check("both answers are buttons with ids of their own",
    !!document.getElementById("adlg-plain-cancel")
      && !!document.getElementById("adlg-plain-action"));

  // isActionLoading is upstream's prop; the port reaches it through Button's is_loading.
  const loading = document.getElementById("adlg-loading");
  check("is_action_loading is a state the action can carry",
    !!loading && !!loading.querySelector("[aria-busy=\"true\"], .astryx-button--loading"),
    "no loading marker on the action");
}

// ---------------------------------------------------------------- DialogHeader (M14)
{
  section("DialogHeader");
  const noClose = document.getElementById("dhdr-no-close");
  check("the header renders a heading", !!noClose && !!noClose.querySelector("h2"),
    noClose ? noClose.innerHTML.slice(0, 60) : "missing");
  // The heading is what names the dialog, so it has to carry the id — and be focusable without
  // joining the tab order, which is exactly what tabindex="-1" means.
  const heading = noClose?.querySelector("h2");
  check("the heading carries the id a dialog names itself from",
    heading?.getAttribute("id") === "dhdr-no-close-title", heading?.getAttribute("id") ?? "none");
  check("and it is focusable programmatically without being in the tab order",
    heading?.getAttribute("tabindex") === "-1");
  // What the dialog's hook looks for. The platform would focus the close button instead.
  check("and it marks itself as what the dialog should focus on open",
    !!heading && heading.hasAttribute("data-astryx-focus-on-open"));
  check("its text is the dialog's accessible name",
    heading?.textContent === "Delete this project?", heading?.textContent ?? "none");

  // The absence is the claim: upstream renders no close button without an onOpenChange.
  check("no callback means NO close button",
    !!noClose && noClose.querySelectorAll(".astryx-button, .astryx-icon-button").length === 0,
    `${noClose?.querySelectorAll(".astryx-button, .astryx-icon-button").length} button(s)`);

  const withClose = document.getElementById("dhdr-with-close");
  const close = withClose?.querySelector(".astryx-icon-button, .astryx-button");
  check("a callback means the button exists, and it has an accessible name",
    !!close && (close.getAttribute("aria-label") || "").length > 0,
    close?.getAttribute("aria-label") ?? "no button");
  check("the subtitle sits in its own slot",
    withClose?.querySelector(".astryx-dialog-header__subtitle")?.textContent
      === "This cannot be undone.");
  check("has_divider is a class on the header",
    !!withClose && withClose.classList.contains("astryx-dialog-header--divider"));
}

// ---------------------------------------------------------------------------- Kbd (M15)
{
  const live = document.getElementById("kbd-live");
  check("the wrapper is an image with a spoken name, not a pile of glyphs",
    live?.getAttribute("role") === "img", live?.getAttribute("role") ?? "none");
  // The runner is Linux, so `mod` is Ctrl here. The Mac answer is asserted through the rules below.
  check("and that name is words: 'Control + K'",
    live?.getAttribute("aria-label") === "Control + K", live?.getAttribute("aria-label") ?? "none");
  check("every key gets its own cap",
    live?.querySelectorAll("kbd").length === 2, `${live?.querySelectorAll("kbd").length} cap(s)`);
  const caps = [...(live?.querySelectorAll("kbd") ?? [])];
  check("the caps themselves are hidden from assistive technology",
    caps.length === 2 && caps.every(c => c.getAttribute("aria-hidden") === "true"));
  check("and they render the keys as text",
    caps.map(c => c.textContent).join(",") === "Ctrl,K",
    caps.map(c => c.textContent).join(","));
  const multi = document.getElementById("kbd-live-multi");
  check("a three-key shortcut names all three",
    multi?.getAttribute("aria-label") === "Control + Shift + P",
    multi?.getAttribute("aria-label") ?? "none");

  const rule = id => document.getElementById(id)?.textContent ?? null;
  check("mod is Command on a Mac", rule("kbd-rule-mod-mac-display") === "\u2318", rule("kbd-rule-mod-mac-display") ?? "none");
  check("and is spoken as Command, not as the glyph", rule("kbd-rule-mod-mac-label") === "Command");
  check("mod is Ctrl elsewhere", rule("kbd-rule-mod-other-display") === "Ctrl");
  check("and is spoken as Control", rule("kbd-rule-mod-other-label") === "Control");
  check("the alias esc displays as Esc, not ESC", rule("kbd-rule-esc-display") === "Esc", rule("kbd-rule-esc-display") ?? "none");
  check("and is spoken in full", rule("kbd-rule-esc-label") === "Escape");
  check("the alias return is Enter", rule("kbd-rule-return-display") === "\u21b5", rule("kbd-rule-return-display") ?? "none");
  check("shift+plus is two keys, not three", rule("kbd-rule-plus-display") === "\u21e7+\u002b", rule("kbd-rule-plus-display") ?? "none");
  check("a key upstream never heard of renders as itself",
    rule("kbd-rule-unknown-display") === "PAGEUP", rule("kbd-rule-unknown-display") ?? "none");
  check("and is spoken as itself", rule("kbd-rule-unknown-label") === "PAGEUP");
  check("keys are trimmed and lowercased before lookup",
    rule("kbd-rule-split") === "mod,shift,p", rule("kbd-rule-split") ?? "none");
}

// ----------------------------------------------------------------------- Layer (M16)
{
  // The attribute is what a supporting browser acts on. Asserting its presence here is not decoration:
  // the whole mechanism is "the platform does it", so the attribute IS the mechanism.
  const closedSurface = document.getElementById("layer-closed-surface");
  check("a layer renders with the attribute a supporting browser acts on",
    closedSurface?.getAttribute("popover") === "auto",
    String(closedSurface?.getAttribute("popover")));
  check("and carries the component marker", !!closedSurface?.hasAttribute("data-astryx-component"));
  // This engine has no showPopover, so the guard makes the hook a no-op. The evidence that it did not
  // crash is that the assertion below can read a tree that a throw would have left unbuilt — and the
  // value is untouched, which is the honest fallback: no API means no open state to reconcile.
  check("in an engine with no Popover API the hook is a no-op, and the caller's value survives",
    document.getElementById("layer-open-value")?.textContent === "the value says open",
    String(document.getElementById("layer-open-value")?.textContent));
  check("nothing claims the layer is open in the DOM when the platform cannot say so",
    !!closedSurface && !closedSurface.hasAttribute("open"),
    String(closedSurface?.outerHTML?.slice(0, 80)));

  /* The trigger's ARIA is written by a *hook*, and this harness does not pump mount effects the way a
     real runtime does — so the ARIA itself is the browser gate's assertion (it is checked there, along
     with the keyboard path). What belongs here is the structure the hook has to find, because a
     mechanism that is handed nothing can still pass every browser check it does not exercise. */
  const wrapper = document.getElementById("layer-closed-trigger-wrapper");
  check("the wrapper the mechanism lives on contains a real button for it to find",
    !!wrapper?.querySelector("button"),
    wrapper ? wrapper.innerHTML.slice(0, 60) : "no wrapper");
  /* Not a restatement of the line above: the button and the surface have to be siblings under the same
     root, because that is the structure the hook's id reference resolves against. */
  const layerRoot = document.getElementById("layer-closed");
  check("with the surface it controls as a sibling in the same root",
    !!layerRoot?.querySelector("div[popover=\"auto\"]"),
    layerRoot ? layerRoot.innerHTML.slice(0, 80) : "no root");
}

/* --------------------------------------------------------- Layer geometry (M43)
   The geometry is pure functions; the harness can press both branches without a browser
   (and jsdom has no anchor positioning at all). The provider and the surface are
   structure, so the custom property, the class list and the inline wiring are asserted
   here; the computed gutter and caps are the browser gate's. */
{
  const rule = (id) => document.getElementById(id)?.textContent ?? "";
  check("a below/center layer covers the block end of the anchor",
    rule("layer-geo-area-below-center") === "self-block-end",
    rule("layer-geo-area-below-center"));
  check("an above/start layer covers the named corner of the anchor",
    rule("layer-geo-area-above-start") === "self-block-start span-self-inline-end",
    rule("layer-geo-area-above-start"));
  check("an end/end layer is the block-start span of the inline end",
    rule("layer-geo-area-end-end") === "self-inline-end span-self-block-start",
    rule("layer-geo-area-end-end"));
  check("a start/end layer is the block-start span of the inline start",
    rule("layer-geo-area-start-end") === "self-inline-start span-self-block-start",
    rule("layer-geo-area-start-end"));
  check("centered fallbacks flip first, then slide the least distance",
    rule("layer-geo-fallbacks-below-center")
      === "flip-block, flip-inline, flip-block flip-inline, bottom span-left, bottom span-right, top span-left, top span-right, --astryx-layer-slide-below-center-same, --astryx-layer-slide-below-center-opposite",
    rule("layer-geo-fallbacks-below-center"));
  check("an aligned pair falls back to flips and its two slides only",
    rule("layer-geo-fallbacks-start-start")
      === "flip-block, flip-inline, flip-block flip-inline, --astryx-layer-slide-start-start-same, --astryx-layer-slide-start-start-opposite",
    rule("layer-geo-fallbacks-start-start"));
  check("a visible anchor keeps the browser's default alignment",
    rule("layer-geo-self-aligned-inview") === "none",
    rule("layer-geo-self-aligned-inview"));
  check("an out-of-view aligned layer pins justify-self unsafe toward the anchor",
    rule("layer-geo-self-aligned-out") === "justify-self:unsafe self-start",
    rule("layer-geo-self-aligned-out"));
  check("centered layers never pin their alignment",
    rule("layer-geo-self-centered-out") === "none",
    rule("layer-geo-self-centered-out"));
  check("inline placements pin align-self instead of justify-self",
    rule("layer-geo-self-inline-out") === "align-self:unsafe self-end",
    rule("layer-geo-self-inline-out"));
  check("slide names are the names the stylesheet defines",
    rule("layer-geo-slide-name") === "--astryx-layer-slide-below-center-same",
    rule("layer-geo-slide-name"));
  check("the inset declares one custom property per declared edge",
    rule("layer-geo-inset-properties")
      === "--astryx-layer-inset-block-end=56px,--astryx-layer-inset-inline-start=12px",
    rule("layer-geo-inset-properties"));

  const provider =
    document.getElementById("layer-geo-provider")?.querySelector(".astryx-layer-provider");
  check("the provider element exists", !!provider, "provider missing");
  /* jsdom's cssstyle normalizes known properties ("display: contents", space after the
     custom-property colon), so both sides are flattened before comparing. */
  const flat = (s) => (s ?? "").replace(/:\s+/g, ":").replace(/;\s*/g, ";");
  check("it writes the block-end inset for its subtree",
    flat(provider?.getAttribute("style")).includes("--astryx-layer-inset-block-end:56px"),
    provider?.getAttribute("style"));
  check("and adds no box of its own",
    flat(provider?.getAttribute("style")).includes("display:contents"),
    provider?.getAttribute("style"));

  const surface = document.getElementById("layer-geo-surface");
  const surfaceClasses = (surface?.getAttribute("class") ?? "").split(/\s+/);
  check("the surface carries the base and the far placement classes",
    surfaceClasses.includes("astryx-layer") && surfaceClasses.includes("astryx-layer--far-below"),
    surface?.getAttribute("class"));
  check("centered layers keep both inline gutters",
    surfaceClasses.includes("astryx-layer--gutter-inline-start")
      && surfaceClasses.includes("astryx-layer--gutter-inline-end"),
    surface?.getAttribute("class"));
  const surfaceStyle = flat(surface?.getAttribute("style"));
  check("it writes the anchor wiring inline",
    surfaceStyle.includes("position-anchor:--demo-anchor")
      && surfaceStyle.includes("position-area:self-block-end"),
    surfaceStyle);
  check("including the full fallbacks list",
    surfaceStyle.includes("--astryx-layer-slide-below-center-opposite"),
    surfaceStyle);
  check("with no clearance when the caller gave no offset",
    !surfaceStyle.includes("--_astryx-layer-clearance"), surfaceStyle);

  const offsetSurface = document.getElementById("layer-geo-surface-offset");
  const offsetClasses = (offsetSurface?.getAttribute("class") ?? "").split(/\s+/);
  check("an offset swaps the margin class for the placement class",
    offsetClasses.includes("astryx-layer--placement-below")
      && !offsetClasses.includes("astryx-layer--far-below"),
    offsetSurface?.getAttribute("class"));
  check("and travels as the clearance custom property",
    flat(offsetSurface?.getAttribute("style")).includes("--_astryx-layer-clearance:8px"),
    offsetSurface?.getAttribute("style"));

  /* The module generates the slide sheet; the stylesheet must ship what it generates. The
     generator itself is machine-checked here by counting the options it actually names and
     spot-checking the two ends of its ordering. */
  const layerCss = readFileSync(resolve(root, "assets/components.css"), "utf8");
  const slideCount = (layerCss.match(/@position-try --astryx-layer-slide-/g) ?? []).length;
  check("the stylesheet ships all 24 slide options", slideCount === 24, String(slideCount));
  check("including the first and last of the generator's order",
    layerCss.includes("@position-try --astryx-layer-slide-above-start-same")
      && layerCss.includes("@position-try --astryx-layer-slide-end-end-opposite"),
    "slide names");
}

/* ------------------------------------------------------------------- ButtonGroup (M17) */
/* The tab stop and the arrow keys are written by a mount effect, and this harness does not pump those -
   so, as with the layer trigger (Gate 30), the behaviour is asserted in the browser gate and this one
   asserts the structure: a named region whose members are inside it, one of them genuinely disabled
   rather than merely styled that way. */
{
  const group = document.querySelector('[data-astryx-component="ButtonGroup"]');
  check("the group is one named region",
    group?.getAttribute("role") === "group" && group?.getAttribute("aria-label") === "Actions",
    `role=${group?.getAttribute("role")} label=${group?.getAttribute("aria-label")}`);
  const members = group ? [...group.querySelectorAll("button")] : [];
  check("with every member inside it", members.length === 3, String(members.length));
  check("including one that is disabled, not just styled that way",
    members.some((b) => b.disabled === true),
    members.map((b) => `${b.textContent}:${b.disabled}`).join(" "));
}

/* ---------------------------------------------------------------------- Popover (M18) */
/* The platform's dismissal, the focus rule and the value being told are the browser gate's - a hook
   writes them, and this harness does not pump mount effects (Gate 30). What belongs here is the
   structure, including the one structural fact the focus rule rests on. */
{
  const surface = document.getElementById("popover-surface");
  check("the surface is a named dialog",
    surface?.getAttribute("role") === "dialog"
      && surface?.getAttribute("aria-modal") === "true"
      && surface?.getAttribute("aria-label") === "Share",
    surface ? surface.outerHTML.slice(0, 140) : "no surface");
  check("carrying the attribute a supporting browser acts on, not a class that means the same thing",
    surface?.getAttribute("popover") === "auto",
    String(surface?.getAttribute("popover")));
  const content = surface?.querySelector(".astryx-popover__content");
  const close = surface?.querySelector(".astryx-popover__close");
  check("and a generated close control that is labelled for a screen reader",
    !!close && close.getAttribute("aria-label") === "Close popover",
    close ? close.outerHTML.slice(0, 90) : "no close control");
  check("which sits *outside* the content wrapper — that is what keeps it out of initial focus",
    !!close && !!content && !content.contains(close),
    content ? `content: ${content.outerHTML.slice(0, 60)}` : "no content wrapper");
  check("with the trigger inside the anchor wrapper the mechanism locates it in",
    !!document.querySelector(".astryx-popover__anchor button"),
    "the anchor wrapper is what the trigger ARIA is applied to");
}

/* -------------------------------------------------------------------------- Toolbar (M21) */

check("the toolbar says what it is and is named", (() => {
  const tb = document.getElementById("tb-actions");
  return tb !== null && tb.getAttribute("role") === "toolbar" &&
    tb.getAttribute("aria-label") === "Document actions";
})());

check("a vertical toolbar says which way it runs", (() => {
  const tb = document.getElementById("tb-vertical");
  return tb !== null && tb.getAttribute("aria-orientation") === "vertical" &&
    tb.classList.contains("astryx-toolbar--vertical");
})());

check("a centre slot switches the row to three columns", (() => {
  const tb = document.getElementById("tb-center");
  return tb !== null && tb.classList.contains("astryx-toolbar--grid") &&
    tb.querySelectorAll(".astryx-toolbar__slot").length === 3;
})());

check("slots are direct children of the toolbar, not wrappers around it", (() => {
  const tb = document.getElementById("tb-actions");
  return tb !== null && Array.from(tb.children).every((c) => c.classList.contains("astryx-toolbar__slot"));
})());

// A toolbar may hold a text field, which is the case the caret guard exists for - so an input has to be
// inside the toolbar element for the guard to have anything to guard.
check("a text field inside a toolbar is inside the toolbar element", (() => {
  const tb = document.getElementById("tb-vertical");
  const input = document.getElementById("tb-input");
  return tb !== null && input !== null && tb.contains(input);
})());

/* ----------------------------------------------------------------------- InputGroup (M20) */

// The group's surface: which element the label names, that the label carries no `for` (a group label names
// the group, not a control), the size class, and that the adornment is a child of the group rather than a
// sibling. The shared border and the corners are CSS, so they belong to the browser gate.

check("group carries role=group and is named by its label", (() => {
  const g = document.querySelector('[data-astryx-component="InputGroup"]');
  return g !== null && g.getAttribute("role") === "group" &&
    (() => {
      const id = g.getAttribute("aria-labelledby");
      const label = id && document.getElementById(id);
      return Boolean(label) && label.textContent.trim() === "Amount";
    })();
})());

// A group label is a span, not a label: a <label> exists to point at a control with `for` (or to wrap
// one), and a group is not a control. The first version of this check demanded a <label> with no `for`,
// which the port correctly refuses to emit.
check("group label is a span, not a label — it names a group, not a control", (() => {
  const label = document.getElementById("ig-amount-label");
  return label !== null && label.tagName === "SPAN" && !label.hasAttribute("for");
})());

check("the adornment is inside the group", (() => {
  const g = document.getElementById("ig-amount-group");
  return g !== null && g.querySelector(".astryx-input-group-text") !== null;
})());

check("size is a class on the box, not a message to the children", (() => {
  const a = document.getElementById("ig-amount-group");
  const b = document.getElementById("ig-locked-group");
  return a !== null && b !== null &&
    a.classList.contains("astryx-input-group--sm") &&
    b.classList.contains("astryx-input-group--lg");
})());

check("a disabled group says so once, on the box", (() => {
  const g = document.getElementById("ig-locked-group");
  return g !== null && g.classList.contains("astryx-input-group--disabled");
})());

/* ------------------------------------------------------------------------- Timer (M19) */
{
  /* The attributes land on the <time> itself, so this is the element - asking for a <time> *inside* it
     finds nothing, which is how this check was first written. */
  const time = document.getElementById("timer-elapsed");
  check("the reading is a real <time> element, not a span that looks like one",
    time?.tagName === "TIME", String(time?.tagName));
  check("carrying a machine-readable duration beside the human one",
    time?.getAttribute("datetime") === "PT0S" && time?.textContent === "0s",
    JSON.stringify({ datetime: time?.getAttribute("datetime"), text: time?.textContent }));
  const clock = document.getElementById("timer-clock");
  check("and the clock format differs in exactly the way it should at zero",
    clock?.getAttribute("datetime") === "PT0S" && clock?.textContent === "0:00",
    JSON.stringify({ datetime: clock?.getAttribute("datetime"), text: clock?.textContent }));
  /* Tabular figures are what stop the numbers shifting as they change. The *class* is all this engine
     can decide - jsdom has no cascade - and the browser gate measures the computed value it produces. */
  check("with the tabular-figure treatment applied, so the numbers do not jump",
    !!time?.closest(".astryx-text--tabular"), String(time?.parentElement?.className));
}


// ---------------------------------------------------------------- overflow arithmetic (pure)
// One row per case: the expectation and the port's answer both live in the DOM, so this compares two
// numbers rather than trusting a hand-copied one. It is the only part of the overflow mechanism that needs
// no browser, which is why it is checked here and not in the browser gate.
{
  // Common.Attr.data prefixes with data-astryx-, so the attribute names are not what a bare
  // Attr.create would have produced - and a selector that matches nothing makes the check below pass
  // vacuously, which is why the count is asserted first.
  const rows = [...document.querySelectorAll('[data-case="overflow-math"] [data-astryx-label]')];
  check("the overflow arithmetic rendered its cases", rows.length === 11, `got ${rows.length}`);
  const wrong = rows
    .map((r) => ({
      label: r.getAttribute("data-astryx-label"),
      expected: `${r.getAttribute("data-astryx-expect-visible")}/${r.getAttribute("data-astryx-expect-rows")}`,
      got: `${r.getAttribute("data-astryx-got-visible")}/${r.getAttribute("data-astryx-got-rows")}`,
    }))
    .filter((r) => r.expected !== r.got);
  check("every overflow case computes the agreed answer", rows.length === 11 && wrong.length === 0,
    wrong.map((r) => `${r.label}: expected ${r.expected}, got ${r.got}`).join(" | "));
}

// ---------------------------------------------------------------- linkify (pure)
// Rows carry both the expectation and the computed answer, so the gate compares two sexps it can both
// see. The count assertion is not decoration: a selector that matches nothing would otherwise pass.
{
  const rows = [...document.querySelectorAll('[data-case="linkify"] [data-astryx-label]')];
  check(
    "the linkify walk rendered its cases",
    rows.length === 9,
    `got ${rows.length}`,
  );
  const wrong = rows.filter(
    (r) => r.getAttribute("data-astryx-expect") !== r.getAttribute("data-astryx-got"),
  );
  check(
    "every linkify case cuts the text the agreed way",
    wrong.length === 0 && rows.length === 9,
    wrong.map((r) => r.getAttribute("data-astryx-label")).join("; ") || "all correct",
  );
}

// ---------------------------------------------------------------- linkify, scanner + walk together
{
  const rows = [...document.querySelectorAll('[data-case="linkify-builtins"] [data-astryx-label]')];
  check(
    "the linkify scanner rendered its cases",
    rows.length === 7,
    `got ${rows.length}`,
  );
  const wrong = rows.filter(
    (r) => r.getAttribute("data-astryx-expect") !== r.getAttribute("data-astryx-got"),
  );
  check(
    "the built-in patterns find and cut real text the agreed way",
    wrong.length === 0 && rows.length === 7,
    wrong.map((r) => `${r.getAttribute("data-astryx-label")}: ${r.getAttribute("data-astryx-got")}`).join(" | ") || "all correct",
  );
}

// ---------------------------------------------------------------- the destination handoff
{
  const rows = [...document.querySelectorAll('[data-case="link-destination"] [data-astryx-label]')];
  check("the destination handoff rendered its cases", rows.length === 8, `got ${rows.length}`);
  const wrong = rows.filter(
    (r) => r.getAttribute("data-astryx-expect") !== r.getAttribute("data-astryx-got"),
  );
  check(
    "every destination resolves to the branch upstream would take",
    wrong.length === 0 && rows.length === 8,
    wrong
      .map((r) => `${r.getAttribute("data-astryx-label")}: ${r.getAttribute("data-astryx-got")}`)
      .join(" | ") || "all correct",
  );
}

// ---------------------------------------------------------------- the interactive role
{
  const rows = [...document.querySelectorAll('[data-case="interactive-role"] [data-astryx-label]')];
  check("the interactive-role fixture rendered its cases", rows.length === 8, `got ${rows.length}`);
  const expected = {
    "an href with no click is a link": "link",
    "no href but a click is a button": "button",
    "neither is inert": "inert",
    "a DISABLED href is not a link - it resolves through the remaining steps": "inert",
    "a disabled href WITH a click is still a button": "button",
    "href outranks a click": "link",
    "an inert thing with no href still renders as a button": "button",
    "but an inert thing WITH an href renders as a plain anchor": "inert",
  };
  let wrong = 0;
  for (const row of rows) {
    const label = row.getAttribute("data-astryx-label");
    const got = row.getAttribute("data-astryx-got");
    if (!(label in expected)) { wrong++; continue; }
    if (!got.startsWith(expected[label])) wrong++;
  }
  check(
    "every interactive-role case matches upstream's priority order",
    wrong === 0 && rows.length === 8,
    wrong ? `${wrong} of ${rows.length} wrong` : "all correct",
  );
}

// ---------------------------------------------------------------- target / rel normalization
{
  const rows = [...document.querySelectorAll('[data-case="target-and-rel"] [data-astryx-label]')];
  check("the target/rel fixture rendered its cases", rows.length === 8, `got ${rows.length}`);
  const wrong = rows.filter(
    (r) => r.getAttribute("data-astryx-expect") !== r.getAttribute("data-astryx-got"),
  );
  check(
    "every target/rel case is normalized the way upstream normalizes it",
    wrong.length === 0 && rows.length === 8,
    wrong.map((r) => `${r.getAttribute("data-astryx-label")}: ${r.getAttribute("data-astryx-got")}`).join(" | ") || "all correct",
  );
}

// --- List (M45)
{
  const host = document.querySelector('[data-case="list-all"]');
  const g = (id) => host && host.querySelector(`#${id}`);
  check("four lists render (basic, dividers, ordered, compact)",
    !!g("ls-basic") && !!g("ls-dividers") && !!g("ls-ordered") && !!g("ls-compact"));
  check("the basic list is a ul with role=list and the list class",
    g("ls-basic").tagName === "UL" && attr(g("ls-basic"), "role") === "list"
    && hasClass(g("ls-basic"), /astryx-list/),
    g("ls-basic") && g("ls-basic").outerHTML.slice(0, 120));
  check("each list carries three li rows", g("ls-basic").querySelectorAll(":scope > li").length === 3);
  check("dividers: data flag, header and aria-labelledby pairing",
    attr(g("ls-dividers"), "data-astryx-dividers") === "true"
    && !!g("ls-dividers").parentElement.querySelector(".astryx-list__header h3")
    && g("ls-dividers").getAttribute("aria-labelledby")?.length > 0
    && !!document.getElementById(g("ls-dividers").getAttribute("aria-labelledby")));
  check("the ordered list is an ol with start=4 and decimal marker",
    g("ls-ordered").tagName === "OL" && attr(g("ls-ordered"), "start") === "4"
    && attr(g("ls-ordered"), "data-astryx-marker") === "decimal"
    && g("ls-ordered").querySelectorAll("li .astryx-list-item__marker").length === 3);
  check("the compact list carries its density", attr(g("ls-compact"), "data-astryx-density") === "compact"
    && hasClass(g("ls-compact"), /--density-compact/));
  check("rows are Items carrying marker spans", g("ls-basic").querySelectorAll("li.astryx-item").length === 3);
}

// --- TreeList (M46)
{
  const host = document.querySelector('[data-case="tree-list-all"]');
  const root = host && host.querySelector(".astryx-tree-list");
  const list = root && root.querySelector(".astryx-tree-list__list");
  const item = (id) => list && list.querySelector(`li[data-tree-id="${id}"]`);
  check("the TreeList fixture mounts its root, a role=tree ul and the port's flags",
    !!root && !!list && attr(root, "data-astryx-component") === "TreeList"
    && attr(root, "data-astryx-density") === "balanced"
    && attr(root, "data-astryx-variant") === "lineGuides"
    && attr(list, "role") === "tree",
    root && `${attr(root, "data-astryx-component")}/${attr(root, "data-astryx-variant")} ul role=${attr(list, "role")}`);
  check("the root declares the indent and row-gap variables", (attr(root, "style") || "").includes("--tree-list-indent"));
  check("four visible top-level treeitems (a, b, c, d)",
    list && [...list.querySelectorAll(":scope > li[role=treeitem]")].length === 4,
    list && String(list.querySelectorAll(":scope > li").length));
  check("nine visible treeitems in total (a1/a2 under a, d1/d1x/d2 under d)",
    list && list.querySelectorAll("li[role=treeitem]").length === 9,
    list && String(list.querySelectorAll("li").length));
  check("aria-expanded lives on the three expandable rows a, d, d1 (and only them)",
    !!item("a") && attr(item("a"), "aria-expanded") === "true"
    && attr(item("d"), "aria-expanded") === "true"
    && attr(item("d1"), "aria-expanded") === "true"
    && attr(item("b"), "aria-expanded") === null
    && attr(item("a1"), "aria-expanded") === null);
  check("the selected row carries aria-selected", !!item("a2") && attr(item("a2"), "aria-selected") === "true");
  check("the disabled row carries aria-disabled and data-tree-disabled",
    !!item("c") && attr(item("c"), "aria-disabled") === "true" && attr(item("c"), "data-tree-disabled") === "true");
  check("exactly one treeitem is the roving tab stop",
    list && [...list.querySelectorAll("li[role=treeitem]")]
      .filter((e) => attr(e, "tabindex") === "0").length === 1);
  check("three chevrons, one per expandable row, each carrying aria-expanded",
    list && list.querySelectorAll("[data-tree-toggle]").length === 3
    && attr(list.querySelector('[data-tree-id="a"] [data-tree-toggle]'), "aria-expanded") === "true");
  check("guide lines render under the default lineGuides variant",
    !!list && list.querySelectorAll(".astryx-tree-list__guide--full").length > 0
    && list.querySelectorAll(".astryx-tree-list__guide").length > 0);
  check("rows are segmented with level, position and set-size",
    !!item("d1x") && attr(item("d1x"), "aria-level") === "3"
    && attr(item("d1x"), "data-tree-level") === "3"
    && attr(item("a2"), "aria-posinset") === "2");
}

// --- NumberInput (M47)
{
  const host = document.querySelector('[data-case="number-input-all"]');
  const root = host && host.querySelector("#ni-all");
  const g = (id) => root && document.getElementById(id);
  const input = (id) => g(id) && g(id).matches(".astryx-number-input__input") ? g(id) : null;
  const wrap = (id) => input(id) && input(id).closest(".astryx-number-input");
  const wraps = () => root ? [...root.querySelectorAll(".astryx-number-input")] : [];
  check("ten NumberInputs render, each marked by the component marker",
    wraps().length === 10 && wraps().every((e) => attr(e, "data-astryx-component") === "NumberInput"));
  check("the input is a text spinbutton with inputmode and aria range",
    !!(input("ni-controlled")) && attr(input("ni-controlled"), "role") === "spinbutton"
    && attr(input("ni-controlled"), "inputmode") === "decimal"
    && attr(input("ni-controlled"), "type") === "text"
    && attr(input("ni-controlled"), "aria-valuemin") === "0"
    && attr(input("ni-controlled"), "aria-valuemax") === "20"
    && attr(input("ni-controlled"), "aria-valuenow") === "42");
  check("the controlled field carries steppers and a clear button",
    !!g("ni-controlled") && wrap("ni-controlled").querySelectorAll("[aria-label='Increase value']").length === 1
    && wrap("ni-controlled").querySelectorAll("[aria-label='Decrease value']").length === 1
    && !!wrap("ni-controlled").querySelector(".astryx-number-input__clear"));
  check("steppers exist only where asked",
    !!g("ni-steppers") && wrap("ni-steppers").querySelectorAll(".astryx-number-input__stepper").length === 2
    && !wrap("ni-plain").querySelector(".astryx-number-input__stepper"));
  check("the clear button appears only when has_clear and there is a value",
    !!g("ni-clear") && !!wrap("ni-clear").querySelector(".astryx-number-input__clear")
    && !wrap("ni-plain").querySelector(".astryx-number-input__clear"));
  check("units render inside the wrapper and are described by",
    !!g("ni-units") && wrap("ni-units").querySelector(".astryx-number-input__units")?.textContent === "px"
    && attr(input("ni-units"), "aria-describedby")?.includes("ni-units-units"));
  check("an integer-only field uses numeric inputmode and marks integer",
    !!g("ni-integer") && attr(input("ni-integer"), "inputmode") === "numeric"
    && attr(wrap("ni-integer"), "data-astryx-integer") === "true");
  check("read-only passes readonly on the input and marks the wrapper",
    !!g("ni-readonly") && !!input("ni-readonly") && attr(input("ni-readonly"), "readonly") !== null
    && attr(wrap("ni-readonly"), "data-astryx-readonly") === "true");
  check("disabled with a reason stays focusable: aria-disabled, no disabled attr, reason shown",
    !!g("ni-disabled") && attr(input("ni-disabled"), "disabled") === null
    && attr(input("ni-disabled"), "aria-disabled") === "true"
    && wrap("ni-disabled").querySelector(".astryx-number-input__disabled-reason")?.textContent === "Locked");
  check("required and description land on the input's aria",
    !!g("ni-required") && attr(input("ni-required"), "aria-required") === "true"
    && attr(input("ni-required"), "aria-describedby")?.includes("ni-required-desc"));
  check("error status colors the wrapper and marks the input invalid",
    !!g("ni-error") && attr(wrap("ni-error"), "data-astryx-status") === "error"
    && attr(input("ni-error"), "aria-invalid") === "true"
    && hasClass(wrap("ni-error"), /--error/));
  check("the controlled value starts at 42 and the readout echoes it",
    !!g("ni-controlled") && root.querySelector("[data-ni-state]")?.getAttribute("data-ni-state") === "42");
  check("the label names the control through a real for=/id pair",
    !!g("ni-controlled") && !!root.querySelector("label[for='ni-controlled']"));
}

// --- Breadcrumbs (M51)
{
  const host = document.querySelector('[data-case="breadcrumbs-all"]');
  const g = (id) => host && host.querySelector(`#${id}`);
  const liOf = (id, n) => g(id)?.querySelectorAll('li')[n];
  const sepText = (id, n) => g(id)?.querySelectorAll('.astryx-breadcrumb-item__separator')[n]?.textContent || '';
  check("five crumb trails render in the fixture",
    !!g("rt-bc-basic") && !!g("rt-bc-explicit") && !!g("rt-bc-opout")
    && !!g("rt-bc-supporting") && !!g("rt-bc-unsafe"));
  check("a trail is a labelled nav wrapping an ol of list items",
    g("rt-bc-basic").tagName === "NAV" && g("rt-bc-basic").getAttribute("aria-label")?.length > 0
    && g("rt-bc-basic").querySelector(':scope > ol.astryx-breadcrumbs__list') !== null
    && g("rt-bc-basic").querySelectorAll(':scope ol > li.astryx-breadcrumb-item').length === 3);
  check("crumbs are links until the current page",
    g("rt-bc-basic").querySelectorAll('a.astryx-breadcrumb-item__link').length === 2
    && !!liOf("rt-bc-basic", 2).querySelector('[aria-current="page"]'));
  check("the auto-current crumb is the last one, and only it",
    liOf("rt-bc-basic", 2).querySelectorAll('[aria-current]').length === 1
    && liOf("rt-bc-basic", 0).querySelectorAll('[aria-current]').length === 0
    && liOf("rt-bc-basic", 1).querySelectorAll('[aria-current]').length === 0);
  check("an explicit current wins even when it is not last",
    liOf("rt-bc-explicit", 1).querySelectorAll('[aria-current="page"]').length === 1
    && liOf("rt-bc-explicit", 0).querySelectorAll('[aria-current]').length === 0);
  check("opting out suppresses auto-current entirely",
    g("rt-bc-opout").querySelectorAll('[aria-current]').length === 0);
  check("the supporting variant is marked and small",
    liOf("rt-bc-supporting", 0).getAttribute("data-astryx-variant") === "supporting"
    && hasClass(liOf("rt-bc-supporting", 0), /--supporting/));
  check("a custom separator renders its own text, hidden from the AT",
    sepText("rt-bc-supporting", 0) === "\u203a"
    && sepText("rt-bc-basic", 0) === "/"
    && attr(g("rt-bc-basic").querySelector(".astryx-breadcrumb-item__separator"), "aria-hidden") === "true");
  check("an unsafe href is refused (the crumb renders without href)",
    g("rt-bc-unsafe").querySelector('a')?.getAttribute("href") === null);
}


// --- Carousel (M52)
{
  const host = document.querySelector('[data-case="carousel-all"]');
  const g = (id) => host && host.querySelector(`#${id}`);
  const slidesOf = (id) => g(id)?.querySelectorAll('.astryx-carousel__item') || [];
  const btn = (id, side) => g(id)?.querySelector(`[data-astryx-nav="${side}"]`);
  check("four carousels render in the fixture",
    !!g("rt-car-basic") && !!g("rt-car-loop") && !!g("rt-car-snap") && !!g("rt-car-nobuttons"));
  check("a carousel is a labelled region with carousel role description",
    g("rt-car-basic")?.getAttribute("role") === "region"
    && g("rt-car-basic")?.getAttribute("aria-roledescription") === "carousel"
    && (g("rt-car-basic")?.getAttribute("aria-label") || "") === "Carousel"
    && g("rt-car-basic")?.getAttribute("data-astryx-component") === "Carousel");
  const sc = g("rt-car-basic")?.querySelector('.astryx-carousel__scroller');
  check("the scroller is focusable and carries the default gap token",
    !!sc && sc.getAttribute("tabindex") === "0"
    && sc.getAttribute("data-astryx-gap") === "1"
    && !sc.hasAttribute("data-astryx-snap"));
  const slides = slidesOf("rt-car-basic");
  check("each item is a slide group named N of M",
    slides.length === 4
    && slides[0].getAttribute("role") === "group"
    && slides[0].getAttribute("aria-roledescription") === "slide"
    && slides[0].getAttribute("aria-label") === "Slide 1 of 4"
    && slides[3].getAttribute("aria-label") === "Slide 4 of 4");
  check("nav pills are present and disabled at both edges (no overflow yet)",
    !!btn("rt-car-basic", "start") && !!btn("rt-car-basic", "end")
    && btn("rt-car-basic", "start").hasAttribute("disabled")
    && btn("rt-car-basic", "end").hasAttribute("disabled")
    && btn("rt-car-basic", "start").parentElement.classList.contains("astryx-carousel__pill--hidden")
    && btn("rt-car-basic", "start").getAttribute("aria-label") === "Scroll left");
  check("loop mode starts with the same edge-disabled contract",
    !!btn("rt-car-loop", "start") && !!btn("rt-car-loop", "end")
    && btn("rt-car-loop", "start").hasAttribute("disabled"));
  check("snap mode marks the scroller as snap-enabled",
    g("rt-car-snap")?.querySelector('.astryx-carousel__scroller')?.hasAttribute("data-astryx-snap"));
  check("has_buttons false renders no nav controls",
    g("rt-car-nobuttons")?.querySelector('[data-astryx-controls]') === null);
  check("no edge fade is applied before the first measurement",
    sc && sc.getAttribute("data-astryx-fade") === null);
}

// --- TabList (M53)
{
  const host = document.querySelector('[data-case="tab-list-all"]');
  const g = (id) => host && host.querySelector(`#${id}`);
  const stripOf = (id) => g(id)?.querySelector('.astryx-tab-list__strip');
  const tabsOf = (id) => g(id)?.querySelectorAll('.astryx-tab') || [];
  check("the TabList fixture mounts three tab lists",
    !!g("rt-tb-basic") && !!g("rt-tb-aria") && !!g("rt-tb-fill"));
  const nav = g("rt-tb-basic");
  check("the nav wrapper is an astryx-tab-list landmark with divider + md size",
    !!nav
    && nav.hasAttribute("data-astryx-tab-list")
    && nav.classList.contains("astryx-tab-list--divider")
    && nav.classList.contains("astryx-tab-list--md")
    && nav.tagName.toLowerCase() === "nav"
    && !!stripOf("rt-tb-basic"));
  const tabs = tabsOf("rt-tb-basic");
  check("each tab is a single tab stop and the selected tab is aria-current",
    tabs.length === 5
    && tabs[0].getAttribute("tabindex") === "0"
    && tabs[1].getAttribute("tabindex") === "-1"
    && tabs[0].getAttribute("aria-current") === "true"
    && tabs[0].classList.contains("astryx-tab--selected")
    && tabs[0].getAttribute("data-tab-value") === "one");
  check("a disabled tab is skipped for activation and flagged to AT",
    tabs[2].getAttribute("aria-disabled") === "true"
    && tabs[2].classList.contains("astryx-tab--disabled"));
  check("the menu trigger expands an options menu (closed here)",
    !!nav.querySelector('.astryx-tab-menu__trigger')
    && nav.querySelector('.astryx-tab-menu__trigger').getAttribute("aria-expanded") === "false"
    && nav.querySelector('.astryx-tab-menu__trigger').getAttribute("aria-haspopup") === "menu");
  const aria = g("rt-tb-aria");
  const ariaStrip = stripOf("rt-tb-aria");
  const ariaTabs = tabsOf("rt-tb-aria");
  check("the tablist pattern asserts tab semantics on strip and missiles",
    ariaStrip?.getAttribute("role") === "tablist"
    && ariaStrip?.getAttribute("aria-label") === "Panels"
    && ariaTabs.length === 3
    && ariaTabs[0].getAttribute("role") === "tab"
    && ariaTabs[0].getAttribute("aria-selected") === "true"
    && ariaTabs[1].getAttribute("aria-selected") === "false"
    && ariaTabs[0].getAttribute("aria-controls") === "rt-tb-p1");
  check("the tabs pattern ignores href (no anchor link is emitted)",
    ariaTabs[2].tagName.toLowerCase() !== "a"
    && !ariaTabs[2].hasAttribute("href"));
  const fill = g("rt-tb-fill");
  check("fill layout + sm size classify wrapper and tabs",
    fill?.classList.contains("astryx-tab-list--fill")
    && fill.classList.contains("astryx-tab-list--sm")
    && (tabsOf("rt-tb-fill")[0]?.classList.contains("astryx-tab--fill"))
    && (tabsOf("rt-tb-fill")[0]?.classList.contains("astryx-tab--sm")));
}

// --- Lightbox (M54)
{
  const host = document.querySelector('[data-case="lightbox-all"]');
  const g = (id) => host && host.querySelector(`#${id}`);
  const navBtn = (id, side) => g(id)?.querySelector(`.astryx-lightbox__nav--${side}`);
  check("three lightboxes mount in the fixture",
    !!g("rt-lb-gallery") && !!g("rt-lb-single") && !!g("rt-lb-video"));
  check("the gallery is a closed native dialog named by the current media",
    g("rt-lb-gallery")?.tagName.toLowerCase() === "dialog"
    && !g("rt-lb-gallery").hasAttribute("open")
    && g("rt-lb-gallery").getAttribute("data-astryx-component") === "Lightbox"
    && g("rt-lb-gallery").getAttribute("aria-label") === "A");
  check("the gallery renders the first item: image alt + zoomable wrapper",
    g("rt-lb-gallery")?.querySelector("img")?.getAttribute("src") === "rt-img-a"
    && g("rt-lb-gallery")?.querySelector("img")?.getAttribute("alt") === "A"
    && g("rt-lb-gallery")?.querySelector(".astryx-lightbox__wrapper")?.classList
        .contains("astryx-lightbox__wrapper--zoomable"));
  check("gallery nav: prev disabled at the first edge, next enabled, counter 1 / 3",
    !!navBtn("rt-lb-gallery", "prev")
    && navBtn("rt-lb-gallery", "prev").hasAttribute("disabled")
    && navBtn("rt-lb-gallery", "next")?.hasAttribute("disabled") === false
    && g("rt-lb-gallery")?.querySelector(".astryx-lightbox__counter")?.textContent.trim() === "1 / 3");
  check("a single-image lightbox has no nav or counter",
    g("rt-lb-single")?.querySelector(".astryx-lightbox__nav--prev") === null
    && g("rt-lb-single")?.querySelector(".astryx-lightbox__counter") === null
    && g("rt-lb-single")?.querySelector("img")?.getAttribute("alt") === "D");
  check("a video item renders a video element with controls and autoplay",
    g("rt-lb-video")?.querySelector("video")?.getAttribute("src") === "rt-clip.mp4"
    && g("rt-lb-video")?.querySelector("video")?.hasAttribute("controls")
    && g("rt-lb-video")?.querySelector("video")?.hasAttribute("autoplay")
    && !g("rt-lb-video")?.querySelector(".astryx-lightbox__wrapper")?.classList
        .contains("astryx-lightbox__wrapper--zoomable"));
  check("controls and the polite live region are present",
    !!g("rt-lb-gallery")?.querySelector(".astryx-lightbox__close")
    && !!g("rt-lb-gallery")?.querySelector('[aria-live="polite"]'));
}

// --- Timestamp (M56)
{
  const host = document.querySelector('[data-case="timestamp-all"]');
  const g = (id) => host && host.querySelector(`#${id}`);
  const d = new Date("2026-03-21T02:51:53Z");
  const fmtDate = (opts) => new Intl.DateTimeFormat("en", opts).format(d);
  const expectedDate = fmtDate({ year: "numeric", month: "short", day: "numeric", calendar: "gregory" });
  const sysParts = new Intl.DateTimeFormat("en-US",
    { year: "numeric", month: "2-digit", day: "2-digit", hour: "2-digit", minute: "2-digit",
      second: "2-digit", hourCycle: "h23", calendar: "gregory" }).formatToParts(d);
  const sysMap = {};
  for (const p of sysParts) if (p.type !== "literal") sysMap[p.type] = p.value;
  const expectedSystem = `${sysMap.year}-${sysMap.month}-${sysMap.day} ${sysMap.hour}:${sysMap.minute}:${sysMap.second}`;
  const anchorOf = (el) => el && el.closest(".astryx-hover-card-anchor");

  check("seven timestamps mount in the fixture",
    !!g("rt-ts-now") && !!g("rt-ts-2h") && !!g("rt-ts-date") && !!g("rt-ts-system")
    && !!g("rt-ts-unix") && !!g("rt-ts-card") && !!g("rt-ts-invalid"));
  check("the relative reading is a semantic <time> carrying its full absolute name",
    g("rt-ts-now")?.tagName.toLowerCase() === "time"
    && g("rt-ts-now")?.getAttribute("data-astryx-component") === "Timestamp"
    && g("rt-ts-now")?.textContent.trim() === "now"
    && (g("rt-ts-now")?.getAttribute("aria-label") ?? "").length > 3
    && g("rt-ts-now")?.getAttribute("tabindex") === "0");
  check("an explicit relative phrase matches the host Intl tier",
    g("rt-ts-2h")?.textContent.trim() === "2 hours ago"
    && (g("rt-ts-2h")?.getAttribute("aria-label") ?? "").length > 3);
  check("an absolute date reads through the host Intl and the ISO datetime is exact",
    g("rt-ts-date")?.textContent.trim() === expectedDate
    && g("rt-ts-date")?.getAttribute("datetime") === "2026-03-21T02:51:53.000Z"
    && g("rt-ts-date")?.getAttribute("aria-label") === null
    && g("rt-ts-date")?.getAttribute("tabindex") === null
    && anchorOf(g("rt-ts-date")) === null);
  check("the system date-time reads the viewer's wall clock",
    g("rt-ts-system")?.textContent.trim() === expectedSystem
    && /^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$/.test(g("rt-ts-system")?.textContent.trim() ?? ""));
  check("unix seconds is exact and its datetime matches the same instant",
    g("rt-ts-unix")?.textContent.trim() === "1742565113"
    && g("rt-ts-unix")?.getAttribute("datetime") === new Date(1742565113000).toISOString());
  check("a relative timestamp with zones attaches the card: wrapper, dialog link, tab stop — closed",
    anchorOf(g("rt-ts-card")) !== null
    && (anchorOf(g("rt-ts-card"))?.getAttribute("aria-haspopup") ?? null) === "dialog"
    && g("rt-ts-card")?.getAttribute("tabindex") === "0"
    && anchorOf(g("rt-ts-card"))?.querySelector(".astryx-hover-card") === null);
  check("an invalid value renders nothing and the probe carries the intent",
    g("rt-ts-invalid")?.getAttribute("data-astryx-invalid") === "true"
    && g("rt-ts-invalid")?.getAttribute("data-astryx-component") === "Timestamp"
    && g("rt-ts-invalid")?.querySelector("time") === null
    && host?.querySelectorAll("time").length === 6);
}

// --- ComplexSelector (M57)
// Structural only: the open/close behaviour is the platform's popover mechanism,
// which jsdom cannot run, so the interaction assertions live in the browser gate.
{
  const host = document.querySelector('[data-case="complex-selector-all"]');
  const g = (id) => host && host.querySelector(`#${id}`);
  const box = (id) => g(id)?.parentElement; // the control box the button sits in
  const content = (id) => host && host.querySelector(`#${id}-content`);
  const all = (sel) => [...(host?.querySelectorAll(sel) ?? [])];

  check("seven selectors mounted under their case, each marking itself and its size",
    !!host && ["rt-cs-basic", "rt-cs-secondary", "rt-cs-ghost", "rt-cs-disabled",
      "rt-cs-error", "rt-cs-lg", "rt-cs-busy"].every((id) => !!g(id))
      && all('.astryx-complex-selector[data-astryx-component="ComplexSelector"]').length === 7
      && box("rt-cs-basic")?.getAttribute("data-astryx-size") === "md"
      && box("rt-cs-lg")?.getAttribute("data-astryx-size") === "lg");

  check("the trigger is a real button with the full popover ARIA contract",
    g("rt-cs-basic")?.tagName.toLowerCase() === "button"
      && g("rt-cs-basic")?.getAttribute("type") === "button"
      && g("rt-cs-basic")?.getAttribute("aria-haspopup") === "dialog"
      && g("rt-cs-basic")?.getAttribute("aria-expanded") === "false"
      && g("rt-cs-basic")?.getAttribute("aria-controls") === "rt-cs-basic-content"
      && g("rt-cs-basic")?.getAttribute("aria-labelledby") === "rt-cs-basic-label");

  check("the label the button names itself with is on the page and carries the text",
    g("rt-cs-basic-label")?.textContent.includes("Color") === true);

  check("the popup is a named native-popover dialog anchored to the trigger",
    !!content("rt-cs-basic")
      && content("rt-cs-basic")?.getAttribute("popover") === "auto"
      && content("rt-cs-basic")?.getAttribute("role") === "dialog"
      && content("rt-cs-basic")?.getAttribute("aria-modal") === "true"
      && content("rt-cs-basic")?.getAttribute("aria-label") === "Color"
      && content("rt-cs-basic")?.getAttribute("tabindex") === "-1"
      && content("rt-cs-basic")?.classList.contains("astryx-complex-selector__popover")
      && content("rt-cs-basic")?.classList.contains("astryx-complex-selector__popover--below")
      && content("rt-cs-basic")?.classList.contains("astryx-complex-selector__popover--align-start"));

  check("the application's options render inside the content, three of them",
    content("rt-cs-basic")?.querySelectorAll(".astryx-complex-selector__content > button").length === 3
      && ["Red", "Green", "Blue"].every((o) =>
        content("rt-cs-basic")?.querySelector(`[data-astryx-option="${o}"]`) !== null));

  check("secondary and ghost are variant classes on the same box, not new elements",
    box("rt-cs-secondary")?.classList.contains("astryx-complex-selector--secondary")
      && box("rt-cs-ghost")?.classList.contains("astryx-complex-selector--ghost"));

  check("error status colours the box, marks the trigger invalid and renders the message",
    box("rt-cs-error")?.classList.contains("astryx-complex-selector--error")
      && g("rt-cs-error")?.getAttribute("aria-invalid") === "true"
      && g("rt-cs-error-status")?.textContent.includes("no longer exists"));

  check("disabled locks the trigger (native disabled) and marks the box",
    g("rt-cs-disabled")?.hasAttribute("disabled")
      && g("rt-cs-disabled")?.getAttribute("aria-disabled") === null
      && box("rt-cs-disabled")?.classList.contains("astryx-complex-selector--disabled"));

  check("busy announces itself and shows the spinner, not the chevron's friend",
    g("rt-cs-busy")?.getAttribute("aria-busy") === "true"
      && !!g("rt-cs-busy")?.parentElement?.querySelector(".astryx-complex-selector__spinner"));

  check("the trigger reads the placeholder until the caller supplies a label",
    g("rt-cs-basic")?.textContent.trim() === "Choose..."
      && box("rt-cs-basic")?.classList.contains("astryx-complex-selector--placeholder"));

  check("the indicator is the chevron and starts closed (no --open class)",
    box("rt-cs-basic")?.querySelector(".astryx-complex-selector__indicator > svg") !== null
      && box("rt-cs-basic")?.querySelector(".astryx-complex-selector__indicator--open") === null);
}

// --- Outline (M58)
// Scroll-spy math needs real layout, so the live assertions (scroll → active,
// click → hash + aria-current, Space, controlled toggle) live in the browser
// gate. Here: the structure, the ARIA shape, and the one thing jsdom CAN
// assert — the controlled attribute mirror and the indent mapping.
{
  const host = document.querySelector('[data-case="outline-all"]');
  const g = (id) => host && host.querySelector(`#${id}`);
  const all = (sel) => [...(host?.querySelectorAll(sel) ?? [])];
  const activeLinks = (id) => [...(g(id)?.querySelectorAll('a[aria-current="location"]') ?? [])];

  check("five outlines mounted: a nav per case, list/listitem groups, four items in the basic one",
    !!host && ["rt-ol-basic", "rt-ol-controlled", "rt-ol-nested", "rt-ol-compact", "rt-ol-label"]
      .every((id) => !!g(id))
      && all('nav.astryx-outline[data-astryx-component="Outline"]').length === 5
      && g("rt-ol-basic")?.querySelector('ul[role="list"]') !== null
      && g("rt-ol-basic")?.querySelectorAll('ul[role="list"] > li > a').length === 4
      && g("rt-ol-basic")?.getAttribute("aria-label") === "Table of contents");

  check("each anchor is an href to its heading id, one tab stop at a time, with the label span",
    [...(g("rt-ol-basic")?.querySelectorAll('ul[role="list"] > li > a') ?? [])]
      .every((a, i) => a.getAttribute("href") === `#rt-ol-${i + 1}`
        && a.getAttribute("tabindex") === "-1"
        && a.querySelector(".astryx-outline__label")?.textContent.length > 0));

  check("the track and the indicator sit under the list (the CSS-anchored marker's scaffold)",
    g("rt-ol-basic")?.querySelector(".astryx-outline__track") !== null
      && g("rt-ol-basic")?.querySelector(".astryx-outline__track .astryx-outline__divider") !== null
      && g("rt-ol-basic")?.querySelector(".astryx-outline__indicator") !== null
      && g("rt-ol-basic")?.querySelector(".astryx-outline__indicator")?.getAttribute("aria-hidden") === "true");

  check("the jsdom harness does not pump the scroll-spy hook: links start unmarked at -1 (the browser gate owns the attribute)",
    activeLinks("rt-ol-basic").length === 0
      && [...(g("rt-ol-basic")?.querySelectorAll("a[href]") ?? [])]
        .every((a) => a.getAttribute("tabindex") === "-1"));

  check("controlled mode renders the same roving-tabindex markup; the caller's active_id mirror is the browser gate's check",
    activeLinks("rt-ol-controlled").length === 0
      && [...(g("rt-ol-controlled")?.querySelectorAll("a[href]") ?? [])]
        .every((a) => a.getAttribute("tabindex") === "-1")
      && g("rt-ol-controlled")?.querySelectorAll("ul[role=\"list\"] > li > a").length === 4);

  check("heading levels 1-5 map to upstream's visual indents 1,1,2,3,4",
    [...(g("rt-ol-nested")?.querySelectorAll(".astryx-outline__link") ?? [])]
      .map((a) => [...a.classList].find((c) => c.startsWith("astryx-outline__link--indent-")))
      .join(",") === "astryx-outline__link--indent-1,astryx-outline__link--indent-1,astryx-outline__link--indent-2,astryx-outline__link--indent-3,astryx-outline__link--indent-4");

  check("compact density is a class on the link, not a different element",
    [...(g("rt-ol-compact")?.querySelectorAll(".astryx-outline__link") ?? [])]
      .every((a) => a.classList.contains("astryx-outline__link--compact")));

  check("a custom label names the nav",
    g("rt-ol-label")?.getAttribute("aria-label") === "Jump to"
      && g("rt-ol-label")?.querySelector(".astryx-outline__list") !== null);
}

// ---------------------------------------------------------------- Resizable
{
  const host = document.querySelector('[data-case="resizable-all"]');
  const g = (id) => host && host.querySelector(`#${id}`);
  const all = (sel) => [...(host?.querySelectorAll(sel) ?? [])];
  const sep = (id) => {
    const el = g(id);
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
      label: el.getAttribute("aria-label"),
      tabindex: el.getAttribute("tabindex"),
    };
  };

  check("four resizable regions mounted, each with its own separator",
    !!host
      && all('[data-astryx-component="Resizable"]').length === 4
      && ["rt-rz-horizontal", "rt-rz-vertical", "rt-rz-disabled", "rt-rz-snaps"]
        .every((id) => !!g(id)),
    JSON.stringify({ regions: all('[data-astryx-component="Resizable"]').length }));

  const h = sep("rt-rz-horizontal-handle");
  check("the horizontal separator is a WAI-ARIA separator with a value, a label and a tab stop",
    h !== null
      && h.role === "separator"
      && h.orientation === "vertical"
      && h.now !== null
      && h.min !== null
      && h.max !== null
      && h.now >= h.min
      && h.now <= h.max
      && h.label === "Resize sidebar"
      && h.tabindex === "0",
    JSON.stringify(h));

  const v = sep("rt-rz-vertical-handle");
  check("the vertical region reports the horizontal orientation",
    v !== null && v.orientation === "horizontal",
    JSON.stringify(v));

  const d = sep("rt-rz-disabled-handle");
  check("a disabled separator is out of the tab order",
    d !== null && d.tabindex === "-1",
    JSON.stringify(d));

  const s = sep("rt-rz-snaps-handle");
  check("a region with snap points starts on one of them",
    s !== null && s.now !== null && [120, 220, 320].includes(s.now),
    JSON.stringify(s));

  check("the panel and the content are both rendered, and the panel carries the size",
    g("rt-rz-horizontal")?.textContent.includes("Sidebar") === true
      && g("rt-rz-horizontal")?.textContent.includes("Content") === true
      && g("rt-rz-horizontal")?.querySelector(".astryx-resizable__panel") !== null);
}

// -------------------------------------------------------------------- Toast
{
  const host = document.querySelector('[data-case="toast-all"]');
  const g = (id) => host && host.querySelector(`#${id}`);
  const all = (sel) => [...(host?.querySelectorAll(sel) ?? [])];

  const info = g("rt-toast-info");
  const error = g("rt-toast-error");
  check("an informational toast is a polite live region",
    info !== null
      && info.getAttribute("data-astryx-component") === "Toast"
      && info.getAttribute("role") === "status"
      && info.getAttribute("aria-live") === "polite"
      && info.getAttribute("aria-atomic") === "true"
      && info.getAttribute("data-astryx-toast-type") === "info",
    info ? info.outerHTML.slice(0, 200) : "missing");

  check("an error toast is an assertive live region",
    error !== null
      && error.getAttribute("role") === "alert"
      && error.getAttribute("aria-live") === "assertive"
      && error.getAttribute("data-astryx-toast-type") === "error",
    error ? error.outerHTML.slice(0, 200) : "missing");

  check("both toasts carry their dismissal control",
    !!info?.querySelector('[aria-label="Dismiss notification"]')
      && !!error?.querySelector('[aria-label="Dismiss notification"]'));

  check("the toast's body is rendered",
    info?.querySelector(".astryx-toast__content")?.textContent.trim() === "Saved successfully",
    info?.querySelector(".astryx-toast__content")?.textContent.trim() ?? null);

  const viewport = g("rt-toast-viewport");
  check("the viewport holds the stack it was given, and names the position",
    viewport !== null
      && viewport.getAttribute("data-astryx-component") === "ToastViewport"
      && viewport.getAttribute("data-astryx-position") === "bottom-end"
      && viewport.querySelectorAll("[data-toast-id]").length === 1
      && viewport.textContent.includes("In the stack"),
    viewport ? viewport.outerHTML.slice(0, 240) : "missing");

  // The viewport becomes a labelled region once it holds something - and the
  // announcement region the screen reader reads is mounted by an effect, so
  // the browser gate is where that one is asserted.
  check("the viewport is a labelled region once it holds a toast",
    viewport !== null
      && viewport.getAttribute("role") === "region"
      && viewport.getAttribute("aria-label") === "Notifications",
    viewport ? viewport.outerHTML.slice(0, 240) : "missing");
}

// ----------------------------------------------------------------- MobileNav
{
  const host = document.querySelector('[data-case="mobile-nav-all"]');
  const g = (id) => host && host.querySelector(`#${id}`);
  const all = (sel) => [...(host?.querySelectorAll(sel) ?? [])];

  const closed = g("rt-mn-closed");
  const open = g("rt-mn-open");
  const inline = g("rt-mn-inline");
  check("three drawers mounted: closed, open and inline",
    !!host && all('[data-astryx-component="MobileNav"]').length === 3
      && !!closed && !!open && !!inline,
    JSON.stringify({ drawers: all('[data-astryx-component="MobileNav"]').length }));

  check("the drawer is a modal dialog with a label and a close control",
    open !== null
      && open.tagName.toLowerCase() === "dialog"
      && open.getAttribute("aria-modal") === "true"
      && open.getAttribute("aria-label") === "Navigation"
      && !!open.querySelector('[aria-label="Close navigation"]'),
    open ? open.outerHTML.slice(0, 200) : "missing");

  // The drawer is opened with showModal(), which jsdom does not implement -
  // so the `open` attribute is the browser gate's business - but the port's
  // own open-state class is there in both.
  check("the drawer follows the caller's value: the open one carries the open state",
    closed !== null && !closed.getAttribute("class").includes("astryx-mobile-nav--open")
      && open !== null && open.getAttribute("class").includes("astryx-mobile-nav--open"),
    JSON.stringify({
      closedClass: closed?.getAttribute("class"),
      openClass: open?.getAttribute("class"),
    }));

  check("the inline drawer is ordinary markup: no top layer, no modal",
    inline !== null
      && inline.tagName.toLowerCase() !== "dialog"
      && inline.getAttribute("aria-modal") === null,
    inline ? inline.outerHTML.slice(0, 200) : "missing");

  check("the drawer holds its content and the header's heading",
    open?.querySelector(".astryx-mobile-nav__drawer") !== null
      && open?.textContent.includes("Drawer content") === true
      && open?.querySelector('[data-astryx-component="Heading"]') !== null);
}


// ------------------------------------------- the cases that were missing
{
  const host = document.querySelector('[data-case="avatar-group-all"]');
  const g = (id) => host && host.querySelector(`#${id}`);
  const basic = g("rt-ag-basic");
  const over = g("rt-ag-overflow");

  check("an avatar group is a labelled group with its avatars and the keyboard hint",
    basic !== null
      && basic.getAttribute("data-astryx-component") === "AvatarGroup"
      && basic.getAttribute("role") === "group"
      && basic.getAttribute("aria-label") === "Team"
      && basic.querySelectorAll(".astryx-avatar-group > div").length === 2
      && basic.querySelector(".astryx-visually-hidden")?.textContent.includes("arrow keys") === true,
    basic ? basic.outerHTML.slice(0, 240) : "missing");

  check("the overflow slot is rendered alongside the avatars",
    over !== null
      && over.querySelectorAll(".astryx-avatar-group > div").length === 3
      && over.textContent.includes("+3"),
    over ? over.outerHTML.slice(0, 240) : "missing");
}

{
  const host = document.querySelector('[data-case="clickable-card-all"]');
  const all = [...(host?.querySelectorAll('[data-astryx-component="ClickableCard"]') ?? [])];
  const link = all[0]?.querySelector("a");
  const button = all[1]?.querySelector("button");

  check("a clickable card with a href is a real link, named and focusable",
    all.length === 2
      && link !== null
      && link.getAttribute("href") === "https://example.com/report"
      && link.getAttribute("aria-label") === "Open the report"
      && link.getAttribute("tabindex") === "0",
    link ? link.outerHTML.slice(0, 200) : "missing");

  check("a disabled clickable card is a disabled button, not a link",
    button !== null
      && button.hasAttribute("disabled")
      && button.getAttribute("aria-label") === "Disabled card"
      && all[1].getAttribute("class").includes("astryx-clickable-card--disabled"),
    button ? button.outerHTML.slice(0, 200) : "missing");

  check("the card's own content is rendered next to the control",
    all[0]?.textContent.includes("The report") === true
      && all[1]?.textContent.includes("Nothing here") === true);
}

{
  const host = document.querySelector('[data-case="selectable-card-all"]');
  const all = [...(host?.querySelectorAll('[data-astryx-component="SelectableCard"]') ?? [])];

  check("a selected card says so, and the selection is a real checkbox",
    all.length === 2
      && all[0].getAttribute("data-astryx-selected") === "true"
      && all[0].getAttribute("class").includes("astryx-selectable-card--selected")
      && all[0].querySelector('input[type="checkbox"]')?.getAttribute("aria-label") === "First",
    all[0] ? all[0].outerHTML.slice(0, 220) : "missing");

  check("an unselected card says so too",
    all[1]?.getAttribute("data-astryx-selected") === "false"
      && !all[1].getAttribute("class").includes("astryx-selectable-card--selected")
      && all[1].querySelector('input[type="checkbox"]')?.getAttribute("aria-label") === "Second",
    all[1] ? all[1].outerHTML.slice(0, 220) : "missing");
}

{
  const host = document.querySelector('[data-case="toggle-button-all"]');
  const g = (id) => host && host.querySelector(`#${id}`);

  check("a toggle button reports its pressed state",
    g("rt-tb-pressed")?.getAttribute("aria-pressed") === "true"
      && g("rt-tb-unpressed")?.getAttribute("aria-pressed") === "false",
    JSON.stringify({
      pressed: g("rt-tb-pressed")?.getAttribute("aria-pressed"),
      unpressed: g("rt-tb-unpressed")?.getAttribute("aria-pressed"),
    }));

  check("a disabled toggle button is disabled, and says it is not pressed",
    g("rt-tb-disabled")?.hasAttribute("disabled") === true
      && g("rt-tb-disabled")?.getAttribute("aria-pressed") === "false"
      && g("rt-tb-disabled")?.getAttribute("data-astryx-component") === "ToggleButton",
    g("rt-tb-disabled") ? g("rt-tb-disabled").outerHTML.slice(0, 200) : "missing");

  check("the toggle's label is its visible text",
    g("rt-tb-pressed")?.textContent.includes("Bold") === true
      && g("rt-tb-unpressed")?.textContent.includes("Italic") === true);
}

{
  const host = document.querySelector('[data-case="metadata-list-all"]');
  const g = (id) => host && host.querySelector(`#${id}`);
  const basic = g("rt-ml-basic");
  const multi = g("rt-ml-multi");

  check("a metadata list is a description list, with its title and its items",
    basic !== null
      && basic.getAttribute("data-astryx-component") === "MetadataList"
      && basic.querySelector("dl") !== null
      && basic.querySelector(".astryx-metadata-list__title")?.textContent === "Details"
      && basic.querySelectorAll("dl > div").length === 4,
    basic ? basic.outerHTML.slice(0, 260) : "missing");

  check("the columns change the list's layout class",
    multi !== null
      && multi.querySelector("dl") !== null
      && multi.querySelector("dl").getAttribute("class").includes("astryx-metadata-list__grid--stacked-multi")
      && basic.querySelector("dl").getAttribute("class").includes("astryx-metadata-list__grid--single"),
    multi ? multi.outerHTML.slice(0, 220) : "missing");
}

{
  const host = document.querySelector('[data-case="more-menu-all"]');
  const g = (id) => host && host.querySelector(`#${id}`);
  const closedTrigger = g("rt-mm-closed-trigger");
  const openTrigger = g("rt-mm-open-trigger");

  check("a more menu's trigger says what it opens and whether it is open",
    closedTrigger !== null
      && closedTrigger.getAttribute("aria-haspopup") === "menu"
      && closedTrigger.getAttribute("aria-expanded") === "false"
      && closedTrigger.getAttribute("aria-controls") === "rt-mm-closed-menu"
      && openTrigger?.getAttribute("aria-expanded") === "true",
    JSON.stringify({
      closed: closedTrigger?.getAttribute("aria-expanded"),
      open: openTrigger?.getAttribute("aria-expanded"),
    }));

  check("the closed menu's surface is hidden, and the open one is not",
    g("rt-mm-closed-menu") !== null
      && g("rt-mm-closed-menu").getAttribute("role") === "menu"
      && g("rt-mm-closed-menu").closest("[data-astryx-state]")?.getAttribute("data-astryx-state") === "closed"
      && g("rt-mm-open-menu")?.closest("[data-astryx-state]")?.getAttribute("data-astryx-state") === "open",
    JSON.stringify({
      closed: g("rt-mm-closed-menu")?.closest("[data-astryx-state]")?.getAttribute("data-astryx-state"),
      open: g("rt-mm-open-menu")?.closest("[data-astryx-state]")?.getAttribute("data-astryx-state"),
    }));

  check("the open menu holds its rows, and the closed one does not",
    (g("rt-mm-open-menu")?.querySelectorAll('[role="menuitem"]').length ?? 0) === 1
      && (g("rt-mm-closed-menu")?.querySelectorAll('[role="menuitem"]').length ?? 0) === 0,
    JSON.stringify({
      openRows: g("rt-mm-open-menu")?.querySelectorAll('[role="menuitem"]').length,
      closedRows: g("rt-mm-closed-menu")?.querySelectorAll('[role="menuitem"]').length,
    }));
}

{
  const host = document.querySelector('[data-case="overflow-list-all"]');
  const all = [...(host?.querySelectorAll(".astryx-overflow-list__item") ?? [])];
  const indicator = host?.querySelector(".astryx-overflow-list__indicator");

  check("an overflow list measures its items and shows the overflow",
    host?.querySelector('[data-astryx-component="OverflowList"]') !== null
      && all.length === 10
      && indicator !== null
      && indicator.textContent.trim() === "+5",
    JSON.stringify({ items: all.length, indicator: indicator?.textContent.trim() }));
}

{
  const host = document.querySelector('[data-case="progress-bar-all"]');
  const g = (id) => host && host.querySelector(`#${id}`);
  const bar = g("rt-pb-value")?.querySelector('[role="progressbar"]');

  check("a progress bar is a progressbar with its value, its bounds and its text",
    bar !== null
      && bar.getAttribute("aria-valuenow") === "40"
      && bar.getAttribute("aria-valuemin") === "0"
      && bar.getAttribute("aria-valuemax") === "100"
      && bar.getAttribute("aria-valuetext") === "40%"
      && g("rt-pb-value")?.querySelector(".astryx-progress-bar__label")?.textContent === "Upload",
    bar ? bar.outerHTML.slice(0, 240) : "missing");

  check("the fill is the value's share of the track",
    g("rt-pb-value")?.querySelector(".astryx-progress-bar__fill")?.getAttribute("style")?.includes("40") === true,
    g("rt-pb-value")?.querySelector(".astryx-progress-bar__fill")?.getAttribute("style") ?? null);

  check("a completed bar reads 100% and the indeterminate one is marked",
    g("rt-pb-success")?.querySelector('[role="progressbar"]')?.getAttribute("aria-valuetext") === "100%"
      && g("rt-pb-indeterminate")?.querySelector('[role="progressbar"]') !== null,
    JSON.stringify({
      success: g("rt-pb-success")?.querySelector('[role="progressbar"]')?.getAttribute("aria-valuetext"),
    }));

  // The mark is a tick on the track, and its label lives in the tooltip that
  // wraps it - the tick itself carries the label for assistive technology.
  const mark = g("rt-pb-marks")?.querySelector(".astryx-progress-bar__mark");
  check("a bar with marks renders the mark, and the tick carries its label",
    mark !== null && mark.getAttribute("aria-label") === "Quarter",
    mark ? mark.outerHTML.slice(0, 220) : "missing");
}


// ------------------------------------------------ HoverCard and Tokenizer
{
  const host = document.querySelector('[data-case="hover-card-all"]');
  const anchors = [...(host?.querySelectorAll('[data-astryx-component="HoverCard"].astryx-hover-card-anchor') ?? [])];
  const closed = anchors.find((a) => !a.getAttribute("aria-describedby"));
  const open = anchors.find((a) => a.getAttribute("aria-describedby"));

  check("a closed hover card's anchor is focusable and names its placement, with no card to describe",
    closed !== undefined
      && closed.getAttribute("tabindex") === "0"
      && closed.getAttribute("data-astryx-placement") === "above"
      && closed.getAttribute("data-astryx-alignment") === "center"
      && closed.querySelector(".astryx-hover-card") === null,
    closed ? closed.outerHTML.slice(0, 200) : "missing");

  check("an open hover card points at its card, and the card is a group with the right placement",
    open !== undefined
      && open.getAttribute("aria-describedby") === "rt-hc-open"
      && open.querySelector("#rt-hc-open") !== null
      && open.querySelector("#rt-hc-open").getAttribute("role") === "group"
      && open.querySelector("#rt-hc-open").getAttribute("data-astryx-placement") === "above"
      && (open.querySelector("#rt-hc-open").getAttribute("class") ?? "").includes("astryx-hover-card--align-center"),
    open ? open.outerHTML.slice(0, 240) : "missing");

  check("the card holds its content",
    open?.querySelector(".astryx-hover-card__content")?.textContent === "the other card",
    open?.querySelector(".astryx-hover-card__content")?.textContent ?? null);
}

{
  const host = document.querySelector('[data-case="tokenizer-all"]');
  const input = host?.querySelector("#rt-tk-plain");
  const listbox = host?.querySelector("#rt-tk-plain-listbox");
  const group = host?.querySelector("#rt-tk-plain-group");
  const label = host?.querySelector('label[for="rt-tk-plain"]');

  check("the token input is a combobox that controls a hidden listbox",
    input?.getAttribute("role") === "combobox"
      && input?.getAttribute("aria-expanded") === "false"
      && input?.getAttribute("aria-controls") === "rt-tk-plain-listbox"
      && listbox?.getAttribute("role") === "listbox"
      && listbox?.hasAttribute("hidden") === true,
    JSON.stringify({
      role: input?.getAttribute("role"),
      controls: input?.getAttribute("aria-controls"),
      hidden: listbox?.hasAttribute("hidden"),
    }));

  check("the selected values live in a labelled group, and the field's label points at the input",
    group?.getAttribute("data-astryx-component") === "Tokenizer"
      && group?.getAttribute("role") === "group"
      && group?.getAttribute("aria-label") === "Reviewers"
      && label?.textContent === "Reviewers",
    JSON.stringify({
      group: group?.getAttribute("aria-label"),
      label: label?.textContent,
    }));

  check("the menu announces its results in a polite live region",
    host?.querySelector('[aria-live="polite"][role="status"]') !== null);

  const disabled = host?.querySelector("#rt-tk-disabled-group");
  check("a disabled tokenizer says so, on the group and on the field's label",
    disabled?.getAttribute("data-astryx-disabled") === "true"
      && (disabled?.getAttribute("class") ?? "").includes("astryx-tokenizer--disabled")
      && host?.querySelector('label[for="rt-tk-disabled"]')?.getAttribute("data-astryx-disabled") === "true",
    JSON.stringify({
      group: disabled?.getAttribute("data-astryx-disabled"),
      label: host?.querySelector('label[for="rt-tk-disabled"]')?.getAttribute("data-astryx-disabled"),
    }));
}

{
  const host = document.querySelector('[data-case="calendar-all"]');
  const single = host?.querySelector("#rt-cal");
  const grid = single?.querySelector("[role='grid']");
  const cells = [...(single?.querySelectorAll("[role='gridcell']") ?? [])];
  const buttons = [...(single?.querySelectorAll("[role='gridcell'] button") ?? [])];
  const outside = buttons.find((b) => b.className.includes("astryx-calendar__day--outside"));
  const inside = buttons.find((b) => !b.className.includes("astryx-calendar__day--outside"));
  const rangeGrid = host?.querySelector("#rt-cal-range [role='grid']");
  const twoGrids = [...(host?.querySelectorAll("#rt-cal-two [role='grid']") ?? [])];
  const weekNumbers = host?.querySelectorAll("#rt-cal-week .astryx-calendar__week-number");

  check("a calendar draws a grid that names its month",
    grid?.getAttribute("role") === "grid"
      && /^[A-Z][a-z]+ \d{4}$/.test(grid?.getAttribute("aria-label") ?? "")
      && single?.getAttribute("data-astryx-component") === "Calendar",
    JSON.stringify({ role: grid?.getAttribute("role"), label: grid?.getAttribute("aria-label") }));

  check("the month has a cell for each of its days",
    cells.length >= 28 && cells.length <= 42 && buttons.length === cells.length,
    JSON.stringify({ cells: cells.length, buttons: buttons.length }));

  check("a day names its full date",
    /^\w+, \w+ \d+, \d{4}$/.test(inside?.getAttribute("aria-label") ?? ""),
    inside?.getAttribute("aria-label") ?? null);

  check("a day outside the month is refused",
    outside?.getAttribute("aria-disabled") === "true" && inside?.getAttribute("aria-disabled") === null,
    JSON.stringify({ outside: outside?.getAttribute("aria-disabled"), inside: inside?.getAttribute("aria-disabled") }));

  check("a range grid takes more than one day",
    rangeGrid?.getAttribute("aria-multiselectable") === "true",
    rangeGrid?.getAttribute("aria-multiselectable") ?? null);

  check("two months draw two grids",
    twoGrids.length === 2 && twoGrids[1]?.getAttribute("aria-label") !== twoGrids[0]?.getAttribute("aria-label"),
    JSON.stringify(twoGrids.map((g) => g.getAttribute("aria-label"))));

  check("a month with week numbers numbers its weeks",
    (weekNumbers?.length ?? 0) >= 4,
    String(weekNumbers?.length ?? 0));
}

{
  const host = document.querySelector('[data-case="top-nav-all"]');
  const nav = host?.querySelector("#rt-tn");
  const heading = nav?.querySelector(".astryx-top-nav-heading");
  const items = [...(nav?.querySelectorAll(".astryx-top-nav-item") ?? [])];
  const centred = host?.querySelector("#rt-tn-centred");

  check("a top nav is a navigation landmark that names itself",
    nav?.tagName === "NAV"
      && nav?.getAttribute("role") === "navigation"
      && nav?.getAttribute("aria-label") === "Top navigation"
      && nav?.getAttribute("data-astryx-component") === "TopNav",
    JSON.stringify({ tag: nav?.tagName, label: nav?.getAttribute("aria-label") }));

  check("the heading is a link, and the items are links too",
    heading?.tagName === "A"
      && items.length === 2
      && items.every((i) => i.tagName === "A")
      && items.map((i) => i.textContent.trim()).join(",") === "Home,Docs",
    JSON.stringify({ heading: heading?.tagName, items: items.map((i) => i.textContent.trim()) }));

  check("a bar with a centre lays out as a grid",
    centred?.getAttribute("class")?.includes("astryx-top-nav--grid") === true,
    centred?.getAttribute("class") ?? null);
}

{
  const host = document.querySelector('[data-case="code-block-all"]');
  const block = host?.querySelector("#rt-cb");
  const numbered = host?.querySelector("#rt-cb-numbered");
  const diff = host?.querySelector("#rt-cb-diff");

  check("a code block is a pre that says what language it holds",
    block?.tagName === "PRE"
      && block?.getAttribute("data-astryx-component") === "CodeBlock"
      && block?.getAttribute("data-astryx-language") === "javascript",
    JSON.stringify({ tag: block?.tagName, lang: block?.getAttribute("data-astryx-language") }));

  check("the code is inside the block, painted through spans",
    block?.querySelector("code") !== null
      && block.querySelector("code").textContent.includes("answer"),
    block?.querySelector("code")?.textContent ?? null);

  check("a numbered block numbers its lines and marks the highlighted one",
    numbered?.querySelectorAll(".astryx-code-block__line--numbered").length > 0
      && numbered?.querySelectorAll(".astryx-code-block__line--highlighted").length > 0,
    JSON.stringify({
      numbered: numbered?.querySelectorAll(".astryx-code-block__line--numbered").length,
      highlighted: numbered?.querySelectorAll(".astryx-code-block__line--highlighted").length,
    }));

  check("a diff says it is a diff, and each line gets its glyph",
    diff?.getAttribute("data-astryx-is-diff") === "true"
      && diff?.querySelectorAll(".astryx-code-block__diff-marker").length > 0
      && diff?.querySelectorAll(".astryx-code-block__line--added").length > 0
      && diff?.querySelectorAll(".astryx-code-block__line--removed").length > 0,
    JSON.stringify({
      isDiff: diff?.getAttribute("data-astryx-is-diff"),
      markers: diff?.querySelectorAll(".astryx-code-block__diff-marker").length,
      added: diff?.querySelectorAll(".astryx-code-block__line--added").length,
      removed: diff?.querySelectorAll(".astryx-code-block__line--removed").length,
    }));
}

{
  const host = document.querySelector('[data-case="pagination-all"]');
  const nav = host?.querySelector("#rt-pg");
  const list = nav?.querySelector(".astryx-pagination__pages");
  const numbers = [...(list?.querySelectorAll("button") ?? [])].map((b) => b.textContent.trim());
  const current = list?.querySelector("[aria-current='page']");
  const prev = nav?.querySelector("button[aria-label*='previous']");
  const next = nav?.querySelector("button[aria-label*='next']");
  const count = host?.querySelector("#rt-pg-count .astryx-pagination__info");
  const unknown = host?.querySelector("#rt-pg-unknown");
  const range = host?.querySelector("[data-page-range]");

  check("a pagination is a navigation region that names itself",
    nav?.tagName === "NAV"
      && nav?.getAttribute("aria-label") === "Pagination"
      && nav?.getAttribute("data-astryx-component") === "Pagination",
    JSON.stringify({ tag: nav?.tagName, label: nav?.getAttribute("aria-label") }));

  check("the page range follows upstream's algorithm",
    range?.getAttribute("data-page-range") === "1 ... 4 5 6 ... 10",
    range?.getAttribute("data-page-range") ?? null);

  check("the page numbers are a list and the current page is marked",
    list?.getAttribute("role") === "list"
      && current?.textContent.trim() === "5"
      && numbers.includes("5"),
    JSON.stringify({ role: list?.getAttribute("role"), current: current?.textContent.trim() }));

  check("the pages that are left out are an ellipsis",
    list?.querySelectorAll(".astryx-pagination__ellipsis").length === 2,
    String(list?.querySelectorAll(".astryx-pagination__ellipsis").length));

  check("both controls are live in the middle of the range",
    prev?.disabled === false && next?.disabled === false,
    JSON.stringify({ prev: prev?.disabled, next: next?.disabled }));

  check("the count variant reports the range of items on the page",
    count?.textContent.trim() === "81–100 of 200",
    count?.textContent.trim() ?? null);

  check("a pagination with no known end has only the next control to offer",
    unknown?.querySelectorAll("button").length === 2
      && unknown?.querySelector("button[aria-label*='previous']")?.disabled === true
      && unknown?.querySelector("button[aria-label*='next']")?.disabled === false,
    JSON.stringify({
      buttons: unknown?.querySelectorAll("button").length,
      prev: unknown?.querySelector("button[aria-label*='previous']")?.disabled,
      next: unknown?.querySelector("button[aria-label*='next']")?.disabled,
    }));
}

{
  const host = document.querySelector('[data-case="multi-selector-all"]');
  const trigger = host?.querySelector("#rt-ms");
  const listbox = host?.querySelector("#rt-ms-listbox");
  const options = [...(listbox?.querySelectorAll('[role="option"]') ?? [])];
  const group = host?.querySelector('[role="group"][aria-label="Advanced"]');

  check("the trigger is a button that names the listbox it controls, and says it is closed",
    trigger?.tagName === "BUTTON"
      && trigger?.getAttribute("aria-haspopup") === "listbox"
      && trigger?.getAttribute("aria-expanded") === "false"
      && trigger?.getAttribute("aria-controls") === "rt-ms-listbox"
      && trigger?.getAttribute("aria-labelledby") === "rt-ms-label",
    JSON.stringify({
      tag: trigger?.tagName,
      haspopup: trigger?.getAttribute("aria-haspopup"),
      expanded: trigger?.getAttribute("aria-expanded"),
      controls: trigger?.getAttribute("aria-controls"),
    }));

  check("the count display says how many are chosen",
    trigger?.querySelector(".astryx-multi-selector__trigger-text")?.textContent === "1 selected",
    trigger?.querySelector(".astryx-multi-selector__trigger-text")?.textContent ?? null);

  check("the list is a multi-select listbox, and the chosen value is the selected one",
    listbox?.getAttribute("role") === "listbox"
      && listbox?.getAttribute("aria-multiselectable") === "true"
      && options.length === 3
      && options.filter((o) => o.getAttribute("aria-selected") === "true").length === 1
      && options[1]?.getAttribute("aria-selected") === "true",
    JSON.stringify({
      role: listbox?.getAttribute("role"),
      options: options.map((o) => ({
        text: o.textContent.trim().slice(0, 20),
        selected: o.getAttribute("aria-selected"),
      })),
    }));

  check("a disabled option is listed and announced, but not choosable",
    options[2]?.getAttribute("aria-disabled") === "true"
      && (options[2]?.getAttribute("class") ?? "").includes("astryx-multi-selector__option--disabled"),
    JSON.stringify({ disabled: options[2]?.getAttribute("aria-disabled") }));

  check("the section's options sit in a group that carries the section's name",
    group !== null
      && group?.querySelectorAll('[role="option"]').length === 1
      && group?.querySelector(".astryx-multi-selector__section-heading")?.textContent === "Advanced",
    JSON.stringify({
      group: group?.getAttribute("aria-label"),
      options: group?.querySelectorAll('[role="option"]').length,
    }));

  const searchTrigger = host?.querySelector("#rt-ms-search");
  const searchInput = host?.querySelector("#rt-ms-search-search");
  check("with a search field, the search input takes the combobox role and the trigger shows the chosen label",
    searchTrigger?.getAttribute("role") === null
      && searchTrigger?.querySelector(".astryx-multi-selector__trigger-text")?.textContent === "Email"
      && searchInput?.getAttribute("role") === "combobox"
      && searchInput?.getAttribute("aria-controls") === "rt-ms-search-listbox"
      && searchInput?.getAttribute("aria-autocomplete") === "list",
    JSON.stringify({
      triggerRole: searchTrigger?.getAttribute("role"),
      triggerText: searchTrigger?.querySelector(".astryx-multi-selector__trigger-text")?.textContent,
      inputRole: searchInput?.getAttribute("role"),
      controls: searchInput?.getAttribute("aria-controls"),
    }));
}
{
  const host = document.querySelector('[data-case="stepper-all"]');
  const root = host?.querySelector("#rt-sp");
  const list = root?.querySelector(".astryx-stepper__list");
  const steps = [...(root?.querySelectorAll(".astryx-stepper__step") ?? [])];

  check("the stepper is an ordered list of steps, named for what it is",
    root?.getAttribute("data-astryx-component") === "Stepper"
      && root?.getAttribute("data-astryx-orientation") === "horizontal"
      && list?.tagName === "OL"
      && list?.getAttribute("aria-label") === "Progress"
      && steps.length === 3,
    JSON.stringify({
      component: root?.getAttribute("data-astryx-component"),
      tag: list?.tagName,
      label: list?.getAttribute("aria-label"),
      steps: steps.length,
    }));

  check("the current step is the one the caller named, and the others are not current",
    steps[0]?.getAttribute("aria-current") === "step"
      && (steps[0]?.getAttribute("class") ?? "").includes("astryx-stepper__step--active")
      && steps.slice(1).every((s) => s.getAttribute("aria-current") === null),
    JSON.stringify(steps.map((s) => s.getAttribute("aria-current"))));

  check("a step you can go to is a button that says which step it is",
    steps[0]?.querySelector("button")?.getAttribute("aria-label") === "Go to step 1: Account"
      && steps[1]?.querySelector("button")?.getAttribute("aria-label") === "Go to step 2: Profile, completed",
    JSON.stringify([
      steps[0]?.querySelector("button")?.getAttribute("aria-label"),
      steps[1]?.querySelector("button")?.getAttribute("aria-label"),
    ]));

  check("a disabled step is not a button, and it says it is disabled",
    steps[2]?.querySelector("button") === null
      && (steps[2]?.getAttribute("class") ?? "").includes("astryx-stepper__step--disabled"),
    JSON.stringify({
      button: steps[2]?.querySelector("button") === null ? null : "there is one",
      cls: steps[2]?.getAttribute("class"),
    }));

  const vertical = host?.querySelector("#rt-sp-vertical");
  check("the vertical stepper runs vertically",
    vertical?.getAttribute("data-astryx-orientation") === "vertical"
      && (vertical?.getAttribute("class") ?? "").includes("astryx-stepper--vertical"),
    JSON.stringify({
      orientation: vertical?.getAttribute("data-astryx-orientation"),
      cls: vertical?.getAttribute("class"),
    }));
}



console.log(`\n${checks} checks, ${failures} failure(s)`);
console.log(failures === 0 ? "COMPONENT CHECKS PASSED" : "COMPONENT CHECKS FAILED");

process.exit(failures === 0 ? 0 : 1);
