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
  resolveFrom([resolve(root, "node_modules/jsdom"), resolve(root, "../astryx/node_modules/jsdom")], "jsdom");
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
  virtualConsole: new VirtualConsole(),
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

// --- IconButton (a Button preset: keeps Button's marker and naming contract)
{
  const bs = inCase("icon-button-all");
  check("three icon buttons render", bs.length === 3, `${bs.length}`);
  check("IconButton carries Button's marker, not its own",
    bs.length > 0 && bs.every((e) => attr(e, "data-astryx-component") === "Button"),
    bs.map((e) => attr(e, "data-astryx-component")).join(","));
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

console.log(`\n${checks} checks, ${failures} failure(s)`);
console.log(failures === 0 ? "COMPONENT CHECKS PASSED" : "COMPONENT CHECKS FAILED");
process.exit(failures === 0 ? 0 : 1);
