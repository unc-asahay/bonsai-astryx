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

console.log(`\n${checks} checks, ${failures} failure(s)`);
console.log(failures === 0 ? "COMPONENT CHECKS PASSED" : "COMPONENT CHECKS FAILED");
process.exit(failures === 0 ? 0 : 1);
