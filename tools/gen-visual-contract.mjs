#!/usr/bin/env node
// Generate the appearance contract for each ported component — the "what does it
// look like, measured" text, plus a prompt for image generation.
//
// Why not screenshots: capturing the *upstream* React build needs the Astryx
// Storybook build, which is not available here. But the ported components do not
// need it — their appearance is fully determined by the stylesheet they actually
// use, and that stylesheet only ever references design tokens. So this script
// derives the contract from three real artifacts:
//
//   assets/*.css          the declarations each component's classes carry
//   tokens.ocaml.json     the resolved value of every token
//   the mounted DOM        which classes each component actually emits
//
// The mounted DOM comes from tools/visual/mount.mjs, i.e. the same compiled
// bundle the DOM gate verifies. Nothing here is hand-written or guessed: if a
// component stops emitting a class, its visual contract changes with it.
//
// Usage: node tools/gen-visual-contract.mjs
// Output: docs/visual/<Name>.md for every ported component, + docs/visual/INDEX.md

import { readFileSync, writeFileSync, mkdirSync, existsSync } from "node:fs";
import { resolve } from "node:path";
import { mountDemo, mountedComponents, root, showcaseBundlePath } from "./visual/mount.mjs";

const readJson = (p) => JSON.parse(readFileSync(resolve(root, p), "utf8"));
const port = readJson("port.json");
const registry = readJson("registry.json");
const tokenGroups = readJson("tokens.ocaml.json");

const upstream = (() => {
  const entries = Array.isArray(registry) ? registry : registry.components ?? registry.items;
  return new Map(entries.map((e) => [e.name ?? e.component, e]));
})();

// ---------------------------------------------------------------- tokens

// Flatten every group into name -> value, e.g. {"--color-accent": "#3b82f6"}.
const tokenValues = new Map();
for (const group of Object.values(tokenGroups)) {
  if (group && typeof group === "object") {
    for (const [k, v] of Object.entries(group)) if (typeof v === "string") tokenValues.set(k, v);
  }
}

/** Resolve `var(--x)`, including `var(--x, fallback)`, to a literal value. */
function resolveValue(value, depth = 0) {
  if (typeof value !== "string" || depth > 6) return value;
  const m = value.match(/var\(\s*(--[a-z0-9-]+)\s*(?:,\s*([^)]+))?\)/i);
  if (!m) return value;
  const [, name, fallback] = m;
  const resolved = tokenValues.get(name) ?? (fallback ? fallback.trim() : `unknown:${name}`);
  return resolveValue(value.replace(m[0], resolved), depth + 1);
}

/** Upstream stores themed colours as CSS `light-dark(a, b)`. That is the real
 * value, but a prompt or a mockup wants the two answers spelled out.
 *
 * The split must be paren-aware: the arguments are frequently `rgba(5, 54, 89,
 * 0.1)`, whose own commas are not the separator. */
function humanize(value) {
  const s = String(value).trim();
  const m = s.match(/^light-dark\((.*)\)$/is);
  if (!m) return value;
  const inner = m[1];
  let depth = 0;
  let splitAt = -1;
  for (let i = 0; i < inner.length; i++) {
    const c = inner[i];
    if (c === "(") depth += 1;
    else if (c === ")") depth -= 1;
    else if (c === "," && depth === 0) {
      splitAt = i;
      break;
    }
  }
  if (splitAt < 0) return value;
  const light = inner.slice(0, splitAt).trim();
  const dark = inner.slice(splitAt + 1).trim();
  return `${light} (light) / ${dark} (dark)`;
}

// ---------------------------------------------------------------- CSS

/** Minimal but honest CSS reader: rule -> declarations, @media kept as a prefix. */
function parseCss(css) {
  const rules = new Map(); // selector -> Map(prop -> value)
  const clean = css.replace(/\/\*[\s\S]*?\*\//g, "");
  let media = null;
  for (const chunk of clean.split("}")) {
    const [selRaw, bodyRaw] = chunk.split("{");
    if (bodyRaw === undefined) continue;
    const sel = selRaw.trim();
    if (sel.startsWith("@media")) {
      media = sel;
      // the media body is the remainder; treat nested rules on the next pass
      for (const inner of bodyRaw.split("}")) {
        const [s2, b2] = inner.split("{");
        if (b2 !== undefined) addRule(rules, s2, b2, media);
      }
      continue;
    }
    addRule(rules, sel, bodyRaw, media);
  }
  return rules;
}

function addRule(rules, sel, body, media) {
  const s = (sel || "").trim();
  if (!s || s.startsWith("@")) return;
  for (const selector of s.split(",")) {
    const key = (media ? `${media} :: ` : "") + selector.trim();
    const decls = rules.get(key) ?? new Map();
    for (const line of body.split(";")) {
      const i = line.indexOf(":");
      if (i < 0) continue;
      const prop = line.slice(0, i).trim();
      const value = line.slice(i + 1).trim();
      if (prop && value) decls.set(prop, value);
    }
    rules.set(key, decls);
  }
}

const cssText = ["tokens.css", "components.css", "layout.css"]
  .map((f) => resolve(root, "assets", f))
  .filter((p) => existsSync(p))
  .map((p) => readFileSync(p, "utf8"))
  .join("\n");
const cssRules = parseCss(cssText);

/** Every declaration that applies to a class, with tokens resolved.
 *
 * Returns a LIST per property, not one value: a component with variants emits
 * several variant classes at once (primary/secondary/destructive all appear in
 * the demo), and each of them sets background-color/color. Collapsing to a single
 * value would silently pick whichever class happens to sit last in the stylesheet
 * — exactly the information a mockup or image needs most. */
function declarationsFor(classes) {
  const out = new Map();
  const tokensUsed = new Set();
  for (const [selector, decls] of cssRules) {
    const base = selector.includes(" :: ") ? selector.split(" :: ")[1] : selector;
    // match only plain `.class` selectors (skip pseudo/compound for the base look)
    if (!/^\.[a-z0-9-]+$/i.test(base)) continue;
    if (!classes.includes(base.slice(1))) continue;
    for (const [prop, value] of decls) {
      for (const token of value.match(/--[a-z0-9-]+/gi) ?? []) tokensUsed.add(token);
      const list = out.get(prop) ?? [];
      list.push({ raw: value, resolved: humanize(resolveValue(value)), selector: base });
      out.set(prop, list);
    }
  }
  return { declarations: out, tokensUsed };
}

// ---------------------------------------------------------------- categories

const GROUPS = [
  ["background", /^(background|background-color)$/],
  ["colour", /^color$/],
  ["borders", /^(border|border-(top|bottom|inline-start|inline-end|radius)|---)/],
  ["layout", /^(display|position|flex|align-items|justify-content|justify-items|grid-template-columns|flex-direction|flex-wrap|gap|row-gap|column-gap|box-sizing|min-width|aspect-ratio)$/],
  ["spacing", /^(padding|padding-.*|margin|margin-.*)$/],
  ["type", /^(font-.*|line-height|white-space|text-align|text-decoration|font-variant-numeric)$/],
  ["effects", /^(box-shadow|opacity|transition-.*|filter|overflow|outline.*)$/],
];

const groupOf = (prop) => (GROUPS.find(([, re]) => re.test(prop)) ?? ["other"])[0];

// ---------------------------------------------------------------- prompt

function imagePrompt(name, contract, anatomy) {
  const first = (prop) => contract.declarations.get(prop)?.[0];
  const all = (prop) =>
    (contract.declarations.get(prop) ?? []).map((d) => d.resolved).join(" / ");
  const bg = all("background-color") || nas(first("background-color"));
  const fg = all("color") || nas(first("color"));
  const radius = first("border-radius")?.resolved;
  const type = first("font-size")?.resolved;
  const lines = [
    `A flat, labelled component sheet of Astryx ${name} in its documented states, on a neutral surface.`,
    bg ? `Surface fills: ${bg}.` : "",
    fg ? `Content colours: ${fg}.` : "",
    radius ? `Corner radius ${radius}.` : "",
    type ? `Type size ${type}.` : "",
    anatomy ? `Anatomy: ${anatomy}.` : "",
    `System UI / Inter-like geometric sans, generous padding on a 4px spacing grid, no gradients, no drop shadows unless the component declares elevation, crisp 2x rendering, transparent background, no photographic content, no text other than the component's own labels.`,
  ];
  return lines.filter(Boolean).join(" ");
}

function nas(x) {
  return x ? x.resolved : "";
}

// ---------------------------------------------------------------- main

// Mount the SHOWCASE bundle by default: it renders every ported component, whereas
// the demo page is a smaller composition — mounting the demo here would silently
// leave the newest components out of the appearance contract. `--source demo`
// switches back if a smaller page is wanted.
const source = process.argv.includes("--source")
  ? process.argv[process.argv.indexOf("--source") + 1]
  : "showcase";
const { document } = await mountDemo(
  source === "demo"
    ? { quiet: true }
    : { quiet: true, waitMs: 700, bundle: showcaseBundlePath(), rootId: "astryx-showcase" },
);
console.log(`source: ${source} bundle\n`);
const mounted = mountedComponents(document);

// Group mounted instances by component, keeping the union of their classes.
const byComponent = new Map();
for (const m of mounted) {
  const entry = byComponent.get(m.name) ?? { classes: new Set(), count: 0, samples: [] };
  for (const c of m.classes) entry.classes.add(c);
  entry.count += 1;
  if (entry.samples.length < 3) entry.samples.push(m);
  byComponent.set(m.name, entry);
}

const outDir = resolve(root, "docs/visual");
mkdirSync(outDir, { recursive: true });

const portedNames = new Set(port.ported.map((p) => p.component));
const written = [];

for (const [name, entry] of [...byComponent].sort((a, b) => a[0].localeCompare(b[0]))) {
  const ported = port.ported.find((p) => p.component === name);
  if (!ported) continue;

  const classes = [...entry.classes].sort();
  const { declarations, tokensUsed } = declarationsFor(classes);
  const up = upstream.get(name) ?? {};
  const anatomy = typeof up.anatomy === "string" ? up.anatomy : "";

  const grouped = new Map();
  for (const [prop, list] of declarations) {
    const g = groupOf(prop);
    if (!grouped.has(g)) grouped.set(g, []);
    grouped.get(g).push([prop, list]);
  }

  const md = [
    `<!-- generated by tools/gen-visual-contract.mjs — do not edit by hand -->`,
    ``,
    `# ${name} — appearance contract (as ported)`,
    ``,
    `Derived from the classes this component actually emits and the declarations those`,
    `classes carry in \`assets/*.css\`, with every token resolved through`,
    `\`tokens.ocaml.json\`. Measured from the rendered DOM, not from upstream sources —`,
    `so this describes *this port*, which is what you want when generating a mockup or`,
    `an image of it.`,
    ``,
    `Where a property is set by more than one class (a component's variants all appear`,
    `in the demo), every value is listed with the class it comes from — the table is a`,
    `union over the demo's instances, not a single snapshot of one element.`,
    ``,
    `Themed colours are shown as \`light (light) / dark (dark)\`: upstream stores them as`,
    `CSS \`light-dark(a, b)\`, so both answers are given rather than one flattened value.`,
    ``,
    `- module: \`${ported.module}\` (\`${ported.file}\`, ${ported.milestone})`,
    `- rendered instances in the demo: ${entry.count}`,
    `- classes: ${classes.map((c) => `\`${c}\``).join(", ") || "_(none)_"}`,
    ``,
  ];

  for (const [group, items] of grouped) {
    md.push(`## ${group}`, ``, "| property | value | source class |", "| --- | --- | --- |");
    for (const [prop, list] of items.sort()) {
      const values = list
        .map((info) =>
          info.resolved === info.raw
            ? `\`${info.resolved}\``
            : `\`${info.resolved}\` _(from \`${info.raw}\`)_`,
        )
        .join("<br>");
      const sources = [...new Set(list.map((i) => `\`${i.selector}\``))].join("<br>");
      md.push(`| \`${prop}\` | ${values} | ${sources} |`);
    }
    md.push(``);
  }

  md.push(`## tokens referenced`, ``);
  if (tokensUsed.size === 0) {
    md.push("_(none — this component styles itself with literals only)_", ``);
  } else {
    md.push("| token | value |", "| --- | --- |");
    for (const t of [...tokensUsed].sort()) md.push(`| \`${t}\` | \`${tokenValues.get(t) ?? "?"}\` |`);
    md.push(``);
  }

  md.push(`## image-generation prompt`, ``, "```text", imagePrompt(name, { declarations }, anatomy), "```", "");

  writeFileSync(resolve(outDir, `${name}.md`), md.join("\n"));
  written.push({ name, classes: classes.length, declarations: declarations.size, tokens: tokensUsed.size, count: entry.count });
}

// Index
const idx = [
  `<!-- generated by tools/gen-visual-contract.mjs — do not edit by hand -->`,
  ``,
  `# Visual contract index`,
  ``,
  `${written.length} ported component(s). Each page records the appearance the port`,
  `actually produces, with tokens resolved to literal values, plus a prompt suitable`,
  `for image generation.`,
  ``,
  `| component | rendered | classes | declarations | tokens | page |`,
  `| --- | --- | --- | --- | --- | --- |`,
  ...written.map(
    (w) => `| ${w.name} | ${w.count} | ${w.classes} | ${w.declarations} | ${w.tokens} | [${w.name}.md](${w.name}.md) |`,
  ),
  ``,
  `Not listed: the ${upstream.size - written.length} components with no OCaml port. They`,
  `have no appearance here yet — \`get_snippet\` in the MCP server refuses to invent`,
  `one, and this page does not invent a look either.`,
  ``,
];
writeFileSync(resolve(outDir, "INDEX.md"), idx.join("\n"));

console.log(`wrote docs/visual/ for ${written.length} ported component(s):`);
for (const w of written) {
  console.log(`  ${w.name.padEnd(16)} ${String(w.count).padStart(2)} instance(s), ${w.classes} class(es), ${w.declarations} declaration(s), ${w.tokens} token(s)`);
}
console.log(`wrote docs/visual/INDEX.md`);

// jsdom's pretendToBeVisual keeps a requestAnimationFrame timer alive, so node
// would otherwise sit here until killed. Nothing is pending at this point.
process.exit(0);
