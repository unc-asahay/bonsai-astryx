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
  check("loading button announces Loading to screen readers",
    /Loading/.test(b.textContent || "") && b.querySelector('[aria-hidden="true"]') !== null);
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
