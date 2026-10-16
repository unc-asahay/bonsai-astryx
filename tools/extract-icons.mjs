#!/usr/bin/env node
/**
 * extract-icons.mjs — generate the OCaml icon table from upstream's registry.
 *
 * Source of truth (pinned):
 *   packages/core/src/Icon/defaultIcons.tsx   — the SVG definitions
 *   packages/core/src/Icon/globalIconRegistry.tsx — the IconName union
 *
 * Why generate instead of hand-porting: the icon set is *data* — 30 SVG trees —
 * and hand-typing 30 path strings is how you get a subtly wrong glyph that no
 * test notices. Generating it also lets the extraction fail loudly: the checks
 * below refuse to write output when a name is missing, an element type is
 * unknown, or a child has children.
 *
 * The subtle part is attribute names. React maps a camelCase JSX prop to a DOM
 * attribute, and for SVG it kebab-cases the name — EXCEPT a fixed list that
 * keeps its camelCase spelling, of which `viewBox` is the one this file uses.
 * So `strokeWidth` becomes `stroke-width` while `viewBox` stays `viewBox`.
 * Getting this backwards produces icons that render at the wrong size or not at
 * all, and the difference is invisible in the TSX. Hence `reactAttrName` below.
 *
 * Usage: node tools/extract-icons.mjs [--check]
 *   --check  don't write; exit non-zero if the on-disk output is stale.
 */

import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const HERE = path.dirname(fileURLToPath(import.meta.url));
const REPO = path.resolve(HERE, "..");
const UPSTREAM = process.env.ASTRYX_UPSTREAM ?? path.join(process.env.HOME, "src/astryx");
const SRC_DIR = path.join(UPSTREAM, "packages/core/src/Icon");

const DEFAULT_ICONS = path.join(SRC_DIR, "defaultIcons.tsx");
const REGISTRY = path.join(SRC_DIR, "globalIconRegistry.tsx");

const OUT_ML = path.join(REPO, "src/icon_data.ml");
const OUT_JSON = path.join(REPO, "assets/icons.json");

const fail = (msg) => {
  console.error(`extract-icons: ${msg}`);
  process.exit(1);
};

// --- React's SVG attribute naming -------------------------------------------

/** SVG attributes React deliberately does NOT kebab-case. */
const PRESERVE_CAMEL = new Set([
  "attributeName", "attributeType", "baseFrequency", "clipPathUnits",
  "diffuseConstant", "edgeMode", "filterUnits", "glyphRef", "gradientTransform",
  "gradientUnits", "kernelMatrix", "kernelUnitLength", "keyPoints", "keySplines",
  "keyTimes", "lengthAdjust", "limitingConeAngle", "markerHeight", "markerUnits",
  "markerWidth", "maskContentUnits", "maskUnits", "numOctaves", "pathLength",
  "patternContentUnits", "patternTransform", "patternUnits", "pointsAtX",
  "pointsAtY", "pointsAtZ", "preserveAlpha", "preserveAspectRatio",
  "primitiveUnits", "refX", "refY", "repeatCount", "repeatDur",
  "requiredExtensions", "requiredFeatures", "specularConstant",
  "specularExponent", "spreadMethod", "startOffset", "stdDeviation",
  "stitchTiles", "surfaceScale", "systemLanguage", "tableValues", "targetX",
  "targetY", "textLength", "viewBox", "viewTarget", "xChannelSelector",
  "yChannelSelector", "zoomAndPan",
]);

/** JSX prop name -> DOM attribute name, the way React does it for SVG. */
function reactAttrName(name) {
  if (PRESERVE_CAMEL.has(name)) return name;
  if (name === "className") return "class";
  // Already hyphenated ('aria-hidden': true) passes through; camelCase (ariaHidden)
  // gets one hyphen inserted. Doing the slice without this check produced
  // "aria--hidden", which the DOM ignores — every icon would have lost its
  // decorative hiding.
  if (name.startsWith("aria-")) return name;
  if (name.startsWith("aria")) return `aria-${name.slice(4).toLowerCase()}`;
  if (name === "xmlns") return "xmlns";
  // kebab-case every remaining camelCase name; already-lowercase names pass through.
  return name.replace(/[A-Z]/g, (c) => `-${c.toLowerCase()}`);
}

/** Attribute names this generator is willing to emit. Anything else is a bug here,
 *  not a discovery in upstream — fail loudly instead of shipping a bad attribute. */
const ALLOWED_ATTRS = new Set([
  "xmlns", "viewBox", "fill", "fill-rule", "clip-rule", "stroke", "stroke-width",
  "stroke-linecap", "stroke-linejoin", "width", "height", "aria-hidden", "d",
  "x", "y", "rx", "cx", "cy", "r", "opacity", "transform",
]);

function assertAttrName(name, where) {
  if (!ALLOWED_ATTRS.has(name)) {
    fail(`${where}: attribute "${name}" is not in the allowed set — add it deliberately if upstream really uses it`);
  }
  return name;
}

/** JSX literal -> attribute value string, the way React serialises it. */
function reactAttrValue(raw) {
  const v = raw.trim();
  if (v === "true") return "true";
  if (v === "false") return "false";
  // '1em' | "none" | currentColor (a bare identifier is a string literal in JSX)
  const quoted = /^['"](.*)['"]$/s.exec(v);
  if (quoted) return quoted[1];
  if (/^-?\d+(\.\d+)?$/.test(v)) return v; // strokeWidth: 1.5 -> "1.5"
  if (v === "currentColor" || v === "none") return v;
  fail(`unexpected attribute value ${JSON.stringify(v)} — refusing to guess`);
}

// --- parse upstream ---------------------------------------------------------

const readOrDie = (p) => {
  if (!fs.existsSync(p)) fail(`missing upstream file: ${p}`);
  return fs.readFileSync(p, "utf8");
};

const iconsSrc = readOrDie(DEFAULT_ICONS);
const registrySrc = readOrDie(REGISTRY);

/** The shared wrapper props objects (svgProps, solidSvgProps). */
function parseWrapperObjects(src) {
  const out = {};
  const re = /^const ([A-Za-z]+) = \{([\s\S]*?)^\};/gm;
  let m;
  while ((m = re.exec(src)) !== null) {
    const [, name, body] = m;
    const props = [];
    for (const line of body.split("\n")) {
      const kv = /^\s*'?([A-Za-z-]+)'?:\s*(.+?),?\s*$/.exec(line);
      if (!kv) continue;
      const [, key, value] = kv;
      props.push([
        assertAttrName(reactAttrName(key), `wrapper ${name}`),
        reactAttrValue(value.replace(/ as const$/, "")),
      ]);
    }
    out[name] = props;
  }
  return out;
}

const WRAPPERS = parseWrapperObjects(iconsSrc);
if (!WRAPPERS.svgProps) fail("could not parse svgProps");
if (!WRAPPERS.solidSvgProps) fail("could not parse solidSvgProps");

/** Every icon entry: name, which wrapper it uses (with per-icon overrides), and its
 *  flattened children. An entry may override the wrapper, e.g.
 *  `<svg {...svgProps} strokeWidth={2}>` — the later prop wins, as it does in React. */
function parseIcons(src) {
  const entries = [];
  const re =
    /^\s{2}(?:'([^']+)'|([A-Za-z0-9_]+)):\s*\(\s*<svg\s+\{\.\.\.([A-Za-z]+)\}([^>]*?)>([\s\S]*?)<\/svg>\s*,?\s*\)/gm;
  let m;
  while ((m = re.exec(src)) !== null) {
    const name = m[1] ?? m[2];
    const wrapper = m[3];
    const overridesText = m[4];
    const inner = m[5];
    if (!WRAPPERS[wrapper]) fail(`icon ${name}: unknown wrapper ${wrapper}`);

    // Per-icon overrides on the svg tag itself, e.g. strokeWidth={2}.
    const svgAttrs = WRAPPERS[wrapper].map(([k, v]) => [k, v]);
    const overrideRe = /([A-Za-z:-]+)=\{([^{}]*)\}|([A-Za-z:-]+)="([^"]*)"/g;
    let o;
    while ((o = overrideRe.exec(overridesText)) !== null) {
      const key = assertAttrName(reactAttrName(o[1] ?? o[3]), `icon ${name}`);
      const value = reactAttrValue(o[2] ?? o[4]);
      const at = svgAttrs.findIndex(([k]) => k === key);
      if (at === -1) svgAttrs.push([key, value]);
      else svgAttrs[at] = [key, value];
    }
    if (overridesText.trim() !== "" && !/([A-Za-z:-]+)=\{([^{}]*)\}|([A-Za-z:-]+)="([^"]*)"/.test(overridesText)) {
      fail(`icon ${name}: unparsed svg attributes: ${JSON.stringify(overridesText.trim())}`);
    }

    const children = [];
    const childRe = /<([a-zA-Z][a-zA-Z0-9]*)((?:\s+[^>]*?)?)\/>/g;
    let c;
    while ((c = childRe.exec(inner)) !== null) {
      const tag = c[1];
      if (!["path", "rect", "circle"].includes(tag)) {
        fail(`icon ${name}: unsupported element <${tag}> — the renderer is generic, but the extractor must be taught it`);
      }
      const attrs = [];
      const attrRe = /([A-Za-z:-]+)="([^"]*)"/g;
      let a;
      while ((a = attrRe.exec(c[2])) !== null) {
        attrs.push([assertAttrName(reactAttrName(a[1]), `icon ${name} <${tag}>`), a[2]]);
      }
      if (attrs.length === 0) fail(`icon ${name}: <${tag}> with no attributes`);
      if (/</.test(c[2].replace(/"[^"]*"/g, ""))) {
        fail(`icon ${name}: <${tag}> appears to contain nested markup; the table is flat by design`);
      }
      children.push({ tag, attrs });
    }
    // Any leftover '<' outside the children we matched means we silently dropped something.
    const leftovers = inner.replace(childRe, "").trim();
    if (leftovers !== "") {
      fail(`icon ${name}: unparsed markup remains: ${JSON.stringify(leftovers.slice(0, 80))}`);
    }
    if (children.length === 0) fail(`icon ${name}: no children parsed`);
    if (children.every((el) => el.tag === "path" && !el.attrs.some(([k]) => k === "d"))) {
      fail(`icon ${name}: path without a d attribute`);
    }
    entries.push({ name, wrapper, svg_attrs: svgAttrs, children });
  }
  return entries;
}

const icons = parseIcons(iconsSrc);

// --- cross-check against the IconName union ---------------------------------

function parseIconNames(src) {
  const m = /export type IconName\s*=([\s\S]*?);/.exec(src);
  if (!m) fail("could not find the IconName union");
  return [...m[1].matchAll(/'([^']+)'/g)].map((x) => x[1]);
}

const iconNames = parseIconNames(registrySrc);
if (iconNames.length === 0) fail("IconName union parsed empty");

const byName = new Map(icons.map((i) => [i.name, i]));
const missing = iconNames.filter((n) => !byName.has(n));
if (missing.length > 0) fail(`no default icon for: ${missing.join(", ")}`);

const namespaced = icons.filter((i) => !iconNames.includes(i.name)).map((i) => i.name);

// --- emit -------------------------------------------------------------------

const esc = (s) => s.replace(/\\/g, "\\\\").replace(/"/g, '\\"');
const ocamlList = (pairs) =>
  pairs.map(([k, v]) => `"${esc(k)}", "${esc(v)}"`).join("; ");

/** Ordered by the registry union so the file reads like upstream, namespaced last. */
const ordered = [
  ...iconNames.map((n) => byName.get(n)),
  ...icons.filter((i) => !iconNames.includes(i.name)),
];

const ml = `(* Generated by tools/extract-icons.mjs — do not edit by hand.
   Source: astryx packages/core/src/Icon/defaultIcons.tsx (pinned in registry.json)
           astryx packages/core/src/Icon/globalIconRegistry.tsx (the IconName union)

   ${ordered.length} icons, ${ordered.reduce((a, i) => a + i.children.length, 0)} SVG child elements.
   Attribute names are already converted from React's JSX spelling to DOM
   spelling (strokeWidth -> stroke-width, but viewBox stays viewBox), so the
   renderer emits exactly the attributes upstream's React output would have. *)

open! Core

type el = { tag : string; attrs : (string * string) list }

type t =
  { name : string
  ; svg_attrs : (string * string) list
  ; children : el list
  }

let all : t list =
  [ ${ordered
    .map(
      (i) =>
        `{ name = "${esc(i.name)}"\n  ; svg_attrs = [ ${ocamlList(i.svg_attrs)} ]\n  ; children =\n      [ ${i.children
        .map((el) => `{ tag = "${esc(el.tag)}"; attrs = [ ${ocamlList(el.attrs)} ] }`)
        .join("\n      ; ")}\n      ]\n  }`,
    )
    .join("\n  ; ")}
  ]
;;

let names : string list = List.map all ~f:(fun t -> t.name)
let find (name : string) : t option = List.find all ~f:(fun t -> String.equal t.name name)
`;

const json = {
  generated_by: "tools/extract-icons.mjs",
  source: {
    defaultIcons: path.relative(UPSTREAM, DEFAULT_ICONS),
    registry: path.relative(UPSTREAM, REGISTRY),
  },
  icon_names: iconNames,
  namespaced: namespaced,
  count: ordered.length,
  children: ordered.reduce((a, i) => a + i.children.length, 0),
  icons: ordered,
};

const report = [
  `extract-icons: ${ordered.length} icons (${iconNames.length} IconName + ${namespaced.length} namespaced: ${namespaced.join(", ") || "none"})`,
  `extract-icons: ${json.children} child elements`,
  `extract-icons: wrappers ${Object.keys(WRAPPERS).join(", ")}`,
  `extract-icons: element types ${[...new Set(ordered.flatMap((i) => i.children.map((c) => c.tag)))].sort().join(", ")}`,
  `extract-icons: every IconName has graphics — no fallback needed for: ${iconNames.length} names`,
].join("\n");

if (process.argv.includes("--check")) {
  const same = fs.existsSync(OUT_ML) && fs.readFileSync(OUT_ML, "utf8") === ml;
  console.log(report);
  if (!same) fail("src/icon_data.ml is stale — re-run without --check");
  console.log("extract-icons: src/icon_data.ml is up to date");
} else {
  fs.writeFileSync(OUT_ML, ml);
  fs.writeFileSync(OUT_JSON, JSON.stringify(json, null, 2) + "\n");
  console.log(report);
  console.log(`extract-icons: wrote ${path.relative(REPO, OUT_ML)} and ${path.relative(REPO, OUT_JSON)}`);
}
