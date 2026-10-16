// Mount the compiled demo bundle in a real DOM (jsdom) and report what the
// OCaml/Bonsai components actually put in the document.
//
// Why this exists: the OCaml compiler proves the code is well-typed, which is
// not the same as proving the DOM is right. This script closes that gap — it
// renders the real js_of_ocaml output and asserts on structure, classes and
// ARIA, so "it renders" is a checked claim rather than a hopeful one.
//
// Usage:
//   node tools/visual/verify-dom.mjs          # assertions, non-zero exit on failure
//   node tools/visual/verify-dom.mjs --dump    # full structural report as JSON
//
// jsdom is a declared devDependency of this repo (package.json). Nothing here reaches
// outside it: a sibling checkout is not a dependency, and CI does not have one.
// node_modules of its own (see resolveJsdom below).

import { createRequire } from "node:module";
import { readFileSync, existsSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const require = createRequire(import.meta.url);
const here = dirname(fileURLToPath(import.meta.url));
const root = resolve(here, "../..");
const dump = process.argv.includes("--dump");

function resolveJsdom() {
  const candidates = [
    resolve(root, "node_modules/jsdom"),
  ];
  for (const c of candidates) {
    if (existsSync(c)) return c;
  }
  throw new Error(
    "jsdom not found. Install it (`pnpm add -D jsdom`) or point NODE_PATH at a checkout that has it.",
  );
}

const { JSDOM, VirtualConsole } = require(resolveJsdom());

// @js-temporal/polyfill, resolved from the project's own node_modules.
function jsonTemporalPolyfill() {
  const candidates = [resolve(root, "node_modules/@js-temporal/polyfill")];
  for (const c of candidates) {
    if (existsSync(c)) return require(c);
  }
  throw new Error("install @js-temporal/polyfill (pnpm add -D @js-temporal/polyfill)");
}

// Surface whatever the page reports: uncaught errors and console output both
// arrive here, which is how a non-Error throw from js_of_ocaml gets a message.
const virtualConsole = new VirtualConsole();
virtualConsole.on("jsdomError", (e) => console.error("[jsdomError]", e.message, e.detail || ""));
virtualConsole.on("error", (...a) => console.error("[page error]", ...a));
virtualConsole.on("warn", (...a) => console.error("[page warn]", ...a));
virtualConsole.on("log", (...a) => console.error("[page log]", ...a));

// The bundle lives in dune's build directory: dune owns that path, and a copy in
// the source tree makes dune refuse to build ("multiple rules generated").
const bundle = resolve(root, "_build/default/examples/demo/demo.bc.js");
if (!existsSync(bundle)) {
  console.error(`missing ${bundle}\nBuild it first: dune build`);
  process.exit(2);
}

const tokensCss = readFileSync(resolve(root, "assets/tokens.css"), "utf8");
const componentsCss = readFileSync(resolve(root, "assets/components.css"), "utf8");
const layoutCss = readFileSync(resolve(root, "assets/layout.css"), "utf8");

const dom = new JSDOM(
  `<!DOCTYPE html><html><head><style>${tokensCss}\n${componentsCss}\n${layoutCss}</style></head>` +
    `<body><div id="astryx-demo"></div></body></html>`,
  {
    runScripts: "outside-only",
    pretendToBeVisual: true,
    url: "http://localhost/",
    virtualConsole,
    // jsdom does not implement Intl on its window. Core's [Time_ns.Zone.local] needs
    // it and raises "unknown zone" without it, which kills Bonsai's startup — so
    // lend the window node's Intl.
    beforeParse(window) {
      try {
        window.Intl = Intl;
      } catch (e) {
        console.error("[beforeParse] could not install Intl:", e.message);
      }
      // Core resolves the local zone at startup. On js_of_ocaml it either reads
      // TZ or drives Temporal; a bare jsdom realm has neither, so Core raises
      // "unknown zone" and Bonsai's startup dies before rendering anything.
      // The demo does not depend on local time, so pinning UTC is the honest
      // choice here — it also makes the render deterministic.
      try {
        window.process = { env: { TZ: "UTC" } };
      } catch (e) {
        console.error("[beforeParse] could not install process.env.TZ:", e.message);
      }
      // Core's js_of_ocaml timezone loader drives Temporal, falling back to
      // [globalThis.TemporalPolyfill.Temporal]. Without Temporal, *every* zone
      // lookup fails — including "UTC" — with "unknown zone", and Bonsai's
      // startup dies before rendering. Graft the polyfill (and, if the node
      // build has it behind --harmony-temporal, native Temporal) into the realm.
      try {
        window.TemporalPolyfill = jsonTemporalPolyfill();
      } catch (e) {
        console.error("[beforeParse] could not install TemporalPolyfill:", e.message);
      }
    },
  },
);

const { window } = dom;

// The bundle runs via window.eval, so it already sees jsdom's own globals.
// Do NOT mirror them onto node's globalThis: jsdom's Performance implementation
// delegates to the *global* performance.now(), so overwriting it recurses until
// the stack dies. (Learned the hard way.)

const source = readFileSync(bundle, "utf8");

try {
  window.eval(source);
} catch (err) {
  console.error("bundle threw while evaluating:", err && err.message);
  console.error("thrown value:", err);
  console.error("inspect:", require("node:util").inspect(err, { depth: 20, maxArrayLength: 50 }));
  console.error(err && err.stack);
  process.exit(3);
}

// The app mounts synchronously in jsdom (no rAF loop needed for the first
// paint), but give the scheduler a chance to run before reading the DOM.
await new Promise((r) => setTimeout(r, 250));

const doc = window.document;
// Bonsai takes over the bind element: the <div id="astryx-demo"> is replaced by
// the component tree, so look for the tree itself, not the original element.
const bindEl = doc.getElementById("astryx-demo");
const rootEl = bindEl || doc.querySelector("body [data-astryx-component]") || doc.body;

if (!rootEl || !doc.querySelector("[data-astryx-component]")) {
  console.error("the app did not mount: no ported component in the document");
  console.error("body:", doc.body.innerHTML.slice(0, 400));
  process.exit(4);
}

// ---------------------------------------------------------------- collection

const components = [...doc.querySelectorAll("[data-astryx-component]")];

function describe(el) {
  const attrs = {};
  for (const a of el.attributes) attrs[a.name] = a.value;
  return {
    tag: el.tagName.toLowerCase(),
    component: el.getAttribute("data-astryx-component"),
    variant: el.getAttribute("data-astryx-variant"),
    text: (el.textContent || "").trim().slice(0, 60),
    attrs,
  };
}

const report = {
  mounted: true,
  html_length: doc.body.innerHTML.length,
  counts: {
    components: components.length,
    by_component: components.reduce((acc, el) => {
      const k = el.getAttribute("data-astryx-component");
      acc[k] = (acc[k] || 0) + 1;
      return acc;
    }, {}),
    h1: doc.querySelectorAll("h1").length,
    h3: doc.querySelectorAll("h3").length,
    buttons: doc.querySelectorAll("button").length,
    anchors: doc.querySelectorAll("a").length,
    badges: doc.querySelectorAll(".astryx-badge").length,
    status_dots: doc.querySelectorAll(".astryx-status-dot").length,
    skeletons: doc.querySelectorAll(".astryx-skeleton").length,
    dividers: doc.querySelectorAll(".astryx-divider").length,
    cards: doc.querySelectorAll(".astryx-card").length,
    spinners: doc.querySelectorAll(".astryx-spinner").length,
    visually_hidden: doc.querySelectorAll(".astryx-visually-hidden").length,
  },
  // The accessibility contract of the ported Button, read off the live DOM.
  buttons: [...doc.querySelectorAll("button, a.astryx-button")].map((b) => ({
    label: (b.textContent || "").trim().replace(/\s+/g, " "),
    type: b.getAttribute("type"),
    busy: b.getAttribute("aria-busy"),
    aria_disabled: b.getAttribute("aria-disabled"),
    native_disabled: b.hasAttribute("disabled"),
    classes: b.className,
  })),
  status_dots: [...doc.querySelectorAll(".astryx-status-dot")].map((d) => ({
    role: d.getAttribute("role"),
    aria_label: d.getAttribute("aria-label"),
    variant: d.getAttribute("data-astryx-variant"),
    classes: d.className,
  })),
  headings: [...doc.querySelectorAll("h1, h3")].map((h) => ({
    tag: h.tagName.toLowerCase(),
    text: (h.textContent || "").trim(),
    classes: h.className,
  })),
  elements: components.map(describe),
};

if (dump) {
  console.log(JSON.stringify(report, null, 2));
  process.exit(0);
}

// ---------------------------------------------------------------- assertions

const failures = [];
function check(name, cond, detail) {
  if (cond) {
    console.log(`  ok   ${name}`);
  } else {
    console.log(`  FAIL ${name}${detail ? ` — ${detail}` : ""}`);
    failures.push(name);
  }
}

console.log(`mounted: ${report.html_length} chars of DOM\n`);

console.log("structure");
// The exact tree the demo should produce. Asserting the map (not a total) means
// a component that silently stops rendering is caught, not averaged away.
const expectedByComponent = {
  Stack: 12,
  Button: 7,
  Heading: 6,
  Text: 6,
  Badge: 5,
  Divider: 2,
  Center: 2,
  Skeleton: 2,
  Card: 1,
  StatusDot: 1,
  Grid: 1,
  Section: 1,
  VisuallyHidden: 1,
};
const got = report.counts.by_component;
for (const [name, n] of Object.entries(expectedByComponent)) {
  check(`${name} rendered x${n}`, got[name] === n, `got ${got[name]}`);
}
const unexpected = Object.keys(got).filter((k) => !(k in expectedByComponent));
check("no unexpected component types", unexpected.length === 0, unexpected.join(", "));
check(
  "47 component instances total",
  report.counts.components === Object.values(expectedByComponent).reduce((a, b) => a + b, 0),
  `got ${report.counts.components}`,
);
check("one h1", report.counts.h1 === 1, `got ${report.counts.h1}`);
check("five h3 section headings", report.counts.h3 === 5, `got ${report.counts.h3}`);
check("seven buttons", report.counts.buttons === 7, `got ${report.counts.buttons}`);
check("five badges", report.counts.badges === 5, `got ${report.counts.badges}`);
check("one status dot", report.counts.status_dots === 1, `got ${report.counts.status_dots}`);
check("two skeletons", report.counts.skeletons === 2, `got ${report.counts.skeletons}`);
check("two dividers", report.counts.dividers === 2, `got ${report.counts.dividers}`);
check("one card", report.counts.cards === 1, `got ${report.counts.cards}`);

console.log("\nbutton accessibility contract");
const named = (label) => report.buttons.find((b) => b.label.startsWith(label));
for (const label of ["Primary", "Secondary", "Ghost", "Delete", "Save", "Disabled", "Large"]) {
  check(`button "${label}" exists`, Boolean(named(label)));
}
for (const b of report.buttons) {
  check(`"${b.label}" has type=button`, b.type === "button", `type=${b.type}`);
  if (b.label.startsWith("Save")) {
    check("loading button is aria-busy", b.busy === "true", `aria-busy=${b.busy}`);
    check("loading button is aria-disabled", b.aria_disabled === "true", `aria-disabled=${b.aria_disabled}`);
    check("loading button stays focusable (not native disabled)", !b.native_disabled);
    // The visible label alone does not say "loading", so the state must be
    // announced on top of it — that is what the visually-hidden node is for.
    check("loading state is announced in the accessible name", b.label === "SaveLoading", `got "${b.label}"`);
  }
  if (b.label.startsWith("Disabled")) {
    check("disabled button uses native disabled", b.native_disabled);
  }
}
check("spinner rendered for the loading button", report.counts.spinners === 1, `got ${report.counts.spinners}`);
check("loading announced to assistive tech", report.counts.visually_hidden >= 1, `got ${report.counts.visually_hidden}`);

console.log("\nlayout primitives (M2)");
const byComponent = (name) => report.elements.filter((e) => e.component === name);
const grid = byComponent("Grid")[0];
check(
  "Grid declares its tracks",
  grid && grid.attrs["data-astryx-columns"] === "repeat(3, 1fr)",
  grid && grid.attrs["data-astryx-columns"],
);
check(
  "Grid defaults to stretch on both axes",
  Boolean(
    grid &&
      grid.attrs.class.includes("astryx-grid--align-stretch") &&
      grid.attrs.class.includes("astryx-grid--justify-stretch"),
  ),
);
check("Grid uses display:grid", grid && grid.attrs.class.includes("astryx-grid"));
const section = byComponent("Section")[0];
check("Section renders a <section> element", section && section.tag === "section", section && section.tag);
check(
  "Section variant is classed",
  section && section.attrs.class.includes("astryx-section--muted"),
  section && section.attrs.class,
);
check(
  "Section dividers are classed on the asked-for sides",
  Boolean(
    section &&
      section.attrs.class.includes("astryx-section--divider-top") &&
      section.attrs.class.includes("astryx-section--divider-bottom"),
  ),
  section && section.attrs.class,
);
const centers = byComponent("Center");
check(
  "Center honours the requested axis",
  centers.length === 2 &&
    centers.some((c) => c.attrs["data-astryx-axis"] === "both") &&
    centers.some((c) => c.attrs["data-astryx-axis"] === "horizontal"),
  centers.map((c) => c.attrs["data-astryx-axis"]).join(","),
);
const vh = byComponent("VisuallyHidden")[0];
check("VisuallyHidden applies the clip block", vh && vh.attrs.class.includes("astryx-visually-hidden"));
check(
  "VisuallyHidden keeps its content in the a11y tree",
  vh && vh.text.includes("screen reader only"),
  vh && vh.text,
);

console.log("\nstatus dot");
const dot = report.status_dots[0];
check("status dot exposes role=img", dot && dot.role === "img", dot && `role=${dot.role}`);
check("status dot carries its label", dot && dot.aria_label === "Healthy", dot && `aria-label=${dot.aria_label}`);
check("status dot is variant success", dot && dot.classes.includes("astryx-status-dot--success"));

console.log("\nclass vocabulary");
check("button variants are classed", report.buttons.some((b) => b.classes.includes("astryx-button--primary")));
check("destructive variant is classed", report.buttons.some((b) => b.classes.includes("astryx-button--destructive")));
check("badges carry variant classes", report.counts.badges > 0 ? [...doc.querySelectorAll(".astryx-badge")].every((b) => b.className.includes("astryx-badge--")) : false);

console.log(`\n${failures.length === 0 ? "ALL CHECKS PASSED" : `${failures.length} CHECK(S) FAILED`}`);
process.exit(failures.length === 0 ? 0 : 1);
