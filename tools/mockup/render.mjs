#!/usr/bin/env node
/**
 * Render a screen recipe (docs/mockups/<id>.json) three ways:
 *
 *   --format html     static HTML + CSS built from measured design tokens
 *   --format prompt   a text-to-image prompt (+ negative prompt)
 *   --format bonsai   an OCaml/Bonsai skeleton using only ported components
 *
 * The point of routing mockups through the same component registry the library
 * uses: a mockup can only name components and props that actually exist, so
 * "design something we can't build" stops being possible.
 *
 * Usage:
 *   node tools/mockup/render.mjs docs/mockups/login.json --format html
 *   node tools/mockup/render.mjs --all --format prompt
 */
import * as fs from 'node:fs';
import * as path from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const OUT = path.join(ROOT, 'mockups/out');
const registry = JSON.parse(fs.readFileSync(path.join(ROOT, 'registry.json'), 'utf8'));
const byName = new Map(registry.components.map((c) => [c.name, c]));
const port = fs.existsSync(path.join(ROOT, 'port.json')) ? JSON.parse(fs.readFileSync(path.join(ROOT, 'port.json'), 'utf8')) : {};
const tokens = fs.existsSync(path.join(ROOT, 'tokens.json')) ? JSON.parse(fs.readFileSync(path.join(ROOT, 'tokens.json'), 'utf8')) : null;

// Layout primitives are the library's own composition vocabulary; they are
// validated permissively because their job is layout, not API surface.
const LAYOUT = new Set(['Stack', 'Grid', 'Card', 'Section', 'AppShell', 'Page', 'Toolbar', 'Dialog', 'AlertDialog']);
const LAYOUT_PROPS = new Set(['direction', 'gap', 'align', 'justify', 'padding', 'width', 'wrap', 'columns', 'role', 'open', 'title', 'description']);
// `text` is a content alias accepted everywhere (recipes are content, not code).
const CONTENT_PROPS = new Set(['text', 'children', 'label', 'placeholder', 'value', 'rows', 'cols', 'icon', 'checked', 'href', 'page', 'totalPages', 'total', 'caption', 'columns', 'rows', 'level', 'variant', 'size', 'type', 'isFullWidth', 'isLabelHidden', 'isDisabled', 'isLoading', 'state', 'items', 'activeIndex', 'image', 'initials', 'name', 'progress']);

const problems = [];

function validate(node, trail = []) {
  const where = trail.join(' > ') || '(root)';
  if (!node || !node.component) { problems.push(`${where}: node without a component`); return; }
  const { component, props = {}, children = [] } = node;
  const known = byName.get(component);
  if (!known && !LAYOUT.has(component)) {
    problems.push(`${where}: unknown component "${component}" (not in registry.json)`);
  }
  if (known) {
    const allowed = new Set(known.props.map((p) => p.name));
    for (const k of Object.keys(props)) {
      if (!allowed.has(k) && !CONTENT_PROPS.has(k)) problems.push(`${where}: ${component} has no prop "${k}"`);
    }
  }
  if (LAYOUT.has(component)) {
    for (const k of Object.keys(props)) if (!LAYOUT_PROPS.has(k)) problems.push(`${where}: layout ${component} has unexpected prop "${k}"`);
  }
  children.forEach((c, i) => validate(c, [...trail, `${component}[${i}]`]));
}

const count = (node) => 1 + (node.children ?? []).reduce((n, c) => n + count(c), 0);
function inventory(node, acc = new Map()) {
  acc.set(node.component, (acc.get(node.component) ?? 0) + 1);
  (node.children ?? []).forEach((c) => inventory(c, acc));
  return acc;
}

// ------------------------------------------------------------------ tokens
const FALLBACK = {
  bg: '#ffffff', fg: '#1a1a1a', subtle: '#6b7280', border: '#d4d4d8',
  primary: '#2563eb', primaryFg: '#ffffff', radius: '8px', pad: '16px',
  gap: '12px', font: 'Inter, system-ui, sans-serif', size: '14px', heading: '24px',
};
function tok() {
  if (!tokens) return FALLBACK;
  const first = (o, fb) => (o && Object.keys(o).length ? Object.keys(o)[0] : fb);
  return {
    ...FALLBACK,
    bg: first(Object.fromEntries(Object.entries(tokens.colors ?? {}).filter(([c]) => c.startsWith('#'))), FALLBACK.bg),
    radius: first(tokens.radii ?? {}, FALLBACK.radius),
    size: first(tokens.fontSizes ?? {}, FALLBACK.size),
    font: first(tokens.fontFamilies ?? {}, FALLBACK.font),
  };
}
const T = tok();

// ------------------------------------------------------------------ html
const esc = (s) => String(s ?? '').replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));
const gapOf = (g) => ({ sm: '8px', md: '12px', lg: '20px', xl: '32px', none: '0' }[g] ?? (g ? g : T.gap));

function html(node) {
  const { component: c, props: p = {}, children = [] } = node;
  const kids = children.map(html).join('\n');
  switch (c) {
    case 'Stack': {
      const dir = p.direction === 'horizontal' ? 'row' : 'column';
      return `<div style="display:flex;flex-direction:${dir};gap:${gapOf(p.gap)};align-items:${p.align ?? 'stretch'};justify-content:${p.justify ?? 'flex-start'}">${kids}</div>`;
    }
    case 'Grid':
      return `<div style="display:grid;grid-template-columns:repeat(${p.columns ?? 3},1fr);gap:${gapOf(p.gap ?? 'md')}">${kids}</div>`;
    case 'Card':
      return `<div style="background:${T.bg};border:1px solid ${T.border};border-radius:${T.radius};padding:${p.padding === 'none' ? '0' : T.pad};${p.width ? `width:${p.width};` : ''}">${kids}</div>`;
    case 'AppShell':
    case 'Page':
    case 'Section':
      return `<div style="padding:${T.pad};max-width:960px;margin:0 auto">${kids}</div>`;
    case 'Dialog':
    case 'AlertDialog':
      return `<div style="position:relative;background:rgba(0,0,0,.45);padding:48px;border-radius:${T.radius}"><div style="background:${T.bg};border:1px solid ${T.border};border-radius:${T.radius};padding:${T.pad};max-width:420px;margin:0 auto;box-shadow:0 12px 32px rgba(0,0,0,.2)">${kids}</div></div>`;
    case 'Heading': {
      const lvl = Math.min(Math.max(Number(p.level ?? 2), 1), 6);
      const size = lvl === 1 ? T.heading : lvl === 2 ? '18px' : T.size;
      return `<h${lvl} style="margin:0;font-family:${T.font};font-size:${size};font-weight:${lvl <= 2 ? 600 : 500};color:${T.fg}">${esc(p.text)}</h${lvl}>`;
    }
    case 'Text':
      return `<p style="margin:0;font-family:${T.font};font-size:${T.size};color:${p.variant === 'subtle' ? T.subtle : T.fg}">${esc(p.text)}</p>`;
    case 'Label':
      return `<label style="font-family:${T.font};font-size:12px;font-weight:500;color:${T.fg}">${esc(p.text ?? p.label)}</label>`;
    case 'Link':
      return `<a href="${esc(p.href ?? '#')}" style="font-family:${T.font};font-size:${T.size};color:${T.primary};text-decoration:none">${esc(p.label ?? p.text)}</a>`;
    case 'Badge':
      return `<span style="display:inline-block;font-family:${T.font};font-size:12px;font-weight:500;padding:2px 8px;border-radius:999px;background:#eef2ff;color:#3730a3;border:1px solid #c7d2fe">${esc(p.label ?? p.text)}</span>`;
    case 'StatusDot':
      return `<span style="display:inline-block;width:8px;height:8px;border-radius:50%;background:${p.state === 'critical' ? '#dc2626' : p.state === 'warning' ? '#d97706' : '#16a34a'}"></span>`;
    case 'Divider':
    case 'Separator':
      return `<div style="height:1px;background:${T.border};margin:4px 0"></div>`;
    case 'Skeleton':
      return `<div style="height:${p.height ?? '12px'};width:${p.width ?? '100%'};background:#e4e4e7;border-radius:6px"></div>`;
    case 'Avatar':
      return `<div style="width:32px;height:32px;border-radius:50%;background:#e4e4e7;color:${T.subtle};display:flex;align-items:center;justify-content:center;font-family:${T.font};font-size:12px;font-weight:600">${esc(p.initials ?? (p.name ?? 'A').slice(0, 2).toUpperCase())}</div>`;
    case 'IconButton':
      return `<button style="width:32px;height:32px;border:1px solid ${T.border};border-radius:${T.radius};background:${T.bg}">${esc(p.icon ?? '*')}</button>`;
    case 'Button': {
      const primary = p.variant === 'primary';
      const destructive = p.variant === 'destructive';
      const bg = primary ? T.primary : destructive ? '#dc2626' : T.bg;
      const fg = primary || destructive ? '#fff' : T.fg;
      return `<button style="width:${p.isFullWidth ? '100%' : 'auto'};display:inline-flex;align-items:center;gap:8px;justify-content:center;font-family:${T.font};font-size:${T.size};font-weight:500;padding:8px 14px;border-radius:${T.radius};border:1px solid ${primary || destructive ? 'transparent' : T.border};background:${bg};color:${fg};${p.isDisabled ? 'opacity:.5;' : ''}">${p.icon ? `<span>${esc(p.icon)}</span>` : ''}${esc(p.label)}</button>`;
    }
    case 'TextInput':
    case 'TextArea': {
      const field =
        c === 'TextArea'
          ? `<textarea placeholder="${esc(p.placeholder)}" rows="3" style="font-family:${T.font};font-size:${T.size};padding:8px 10px;border:1px solid ${T.border};border-radius:${T.radius};background:${T.bg};resize:vertical">${esc(p.value)}</textarea>`
          : `<input type="${esc(p.type ?? 'text')}" value="${esc(p.value)}" placeholder="${esc(p.placeholder)}" style="font-family:${T.font};font-size:${T.size};padding:8px 10px;border:1px solid ${T.border};border-radius:${T.radius};background:${T.bg}" />`;
      return `<div style="display:flex;flex-direction:column;gap:6px;${p.isFullWidth ? 'width:100%;' : ''}">
  ${p.isLabelHidden ? '' : `<label style="font-family:${T.font};font-size:12px;font-weight:500;color:${T.fg}">${esc(p.label)}</label>`}
  ${field}
</div>`;
    }
    case 'CheckboxInput':
    case 'Checkbox':
      return `<label style="display:inline-flex;align-items:center;gap:8px;font-family:${T.font};font-size:${T.size};color:${T.fg}"><span style="width:16px;height:16px;border:1px solid ${T.border};border-radius:4px;background:${p.checked ? T.primary : T.bg};display:inline-block"></span>${esc(p.label ?? p.text)}</label>`;
    case 'Switch':
      return `<label style="display:inline-flex;align-items:center;gap:8px;font-family:${T.font};font-size:${T.size};color:${T.fg}"><span style="width:34px;height:20px;border-radius:999px;background:${p.checked ? T.primary : '#d4d4d8'};display:inline-block;position:relative"><span style="position:absolute;top:2px;${p.checked ? 'right:2px' : 'left:2px'};width:16px;height:16px;border-radius:50%;background:#fff"></span></span>${esc(p.label ?? p.text)}</label>`;
    case 'Selector':
    case 'Select':
      return `<div style="display:flex;flex-direction:column;gap:6px">${p.isLabelHidden ? '' : `<label style="font-family:${T.font};font-size:12px;font-weight:500;color:${T.fg}">${esc(p.label)}</label>`}<div style="font-family:${T.font};font-size:${T.size};padding:8px 10px;border:1px solid ${T.border};border-radius:${T.radius};background:${T.bg};display:flex;justify-content:space-between">${esc(p.value ?? p.label ?? 'Select')}<span>▾</span></div></div>`;
    case 'ProgressBar':
      return `<div style="height:6px;border-radius:999px;background:#e4e4e7"><div style="height:6px;width:${p.progress ?? '40%'};border-radius:999px;background:${T.primary}"></div></div>`;
    case 'Alert':
      return `<div style="border:1px solid ${T.border};border-left:3px solid ${p.state === 'critical' ? '#dc2626' : p.state === 'warning' ? '#d97706' : T.primary};border-radius:${T.radius};padding:${T.pad};background:${T.bg};font-family:${T.font};font-size:${T.size};color:${T.fg}">${esc(p.title ?? '')}${kids}</div>`;
    case 'EmptyState':
      return `<div style="text-align:center;padding:32px;border:1px dashed ${T.border};border-radius:${T.radius};font-family:${T.font};color:${T.subtle}">${esc(p.title ?? 'Nothing here yet')}${kids}</div>`;
    case 'Table': {
      const cols = p.columns ?? [];
      const rows = p.rows ?? [];
      return `<table style="width:100%;border-collapse:collapse;font-family:${T.font};font-size:${T.size}">
<thead><tr>${cols.map((h) => `<th style="text-align:left;padding:10px 12px;border-bottom:1px solid ${T.border};font-weight:600;color:${T.subtle};font-size:12px;text-transform:uppercase;letter-spacing:.04em">${esc(h)}</th>`).join('')}</tr></thead>
<tbody>${rows.map((r) => `<tr>${r.map((cell) => `<td style="padding:10px 12px;border-bottom:1px solid ${T.border};color:${T.fg}">${esc(cell)}</td>`).join('')}</tr>`).join('\n')}</tbody>
</table>`;
    }
    case 'Pagination':
      return `<div style="display:flex;gap:6px;font-family:${T.font};font-size:${T.size}">${Array.from({ length: Math.min(Number(p.totalPages ?? 3), 5) }, (_, i) => `<span style="min-width:28px;text-align:center;padding:4px 8px;border:1px solid ${(p.page ?? 1) === i + 1 ? T.primary : T.border};border-radius:${T.radius};color:${(p.page ?? 1) === i + 1 ? '#fff' : T.fg};background:${(p.page ?? 1) === i + 1 ? T.primary : T.bg}">${i + 1}</span>`).join('')}</div>`;
    case 'Tabs':
      return `<div style="display:flex;gap:16px;border-bottom:1px solid ${T.border};font-family:${T.font};font-size:${T.size}">${(p.items ?? []).map((it, i) => `<span style="padding:8px 0;border-bottom:2px solid ${i === (p.activeIndex ?? 0) ? T.primary : 'transparent'};color:${i === (p.activeIndex ?? 0) ? T.fg : T.subtle}">${esc(it)}</span>`).join('')}</div>`;
    case 'Breadcrumbs':
      return `<div style="font-family:${T.font};font-size:12px;color:${T.subtle}">${(p.items ?? []).map(esc).join(' / ')}</div>`;
    default:
      return `<div data-component="${esc(c)}" style="border:1px dashed ${T.border};border-radius:${T.radius};padding:8px;font-family:${T.font};font-size:12px;color:${T.subtle}">${esc(c)}${kids ? '' : ''}</div>`;
  }
}

function renderHtml(recipe) {
  const inv = [...inventory(recipe.root)];
  return `<!doctype html>
<html lang="en"><head><meta charset="utf-8"><title>${esc(recipe.title)}</title>
<style>
  :root { --bg:${T.bg}; --fg:${T.fg}; --border:${T.border}; --primary:${T.primary}; }
  body { margin:0; background:#f4f4f5; font-family:${T.font}; color:${T.fg}; }
  .frame { width:${recipe.viewport?.w ?? 900}px; min-height:${recipe.viewport?.h ?? 600}px; background:${T.bg};
           margin:24px auto; border:1px solid ${T.border}; border-radius:12px; box-shadow:0 1px 2px rgba(0,0,0,.06); overflow:hidden; }
  .meta { width:${recipe.viewport?.w ?? 900}px; margin:24px auto 0; font:12px ui-monospace,monospace; color:#71717a; }
</style></head>
<body>
<div class="frame">${html(recipe.root)}</div>
<div class="meta">${esc(recipe.id)} — ${esc(recipe.title)} — components: ${inv.map(([n, c]) => `${n}${c > 1 ? ` x${c}` : ''}`).join(', ')}</div>
</body></html>
`;
}

function renderPrompt(recipe) {
  const ip = recipe.imagePrompt ?? {};
  const inv = [...inventory(recipe.root)];
  const notPorted = inv.map(([n]) => n).filter((n) => !LAYOUT.has(n) && (port[n]?.status ?? 'not started') !== 'ported');
  return `SUBJECT: ${ip.subject ?? recipe.title}
COMPOSITION: ${ip.composition ?? 'single screen, vertical layout'}
MOOD: ${ip.mood ?? 'clean, professional'}

Screen: ${recipe.title}. ${recipe.intent}

Components present (in order): ${inv.map(([n, c]) => `${n}${c > 1 ? ` x${c}` : ''}`).join(', ')}.

Visual language (measured from the reference implementation, use these values):
- background ${T.bg}, text ${T.fg}, borders ${T.border}, primary accent ${T.primary}
- corner radius ${T.radius}, inner padding ${T.pad}, component gap ${T.gap}
- type: ${T.font}, body ${T.size}, section headings ${T.heading}, weights 500/600
- flat surfaces with 1px borders; elevation only for overlays (0 12px 32px rgba(0,0,0,.2))

Constraints: no browser chrome, no device frame, no invented components, no gradients,
no drop shadows on flat surfaces, keep to the component list above. Single primary action per view.

${recipe.notes?.length ? 'Design notes: ' + recipe.notes.join(' ') : ''}

NEGATIVE PROMPT: blurry, cluttered, extra UI elements, invented widgets, gradients,
heavy shadows, 3D bevels, stock-photo faces, watermarks, text artifacts.
`;
}

function renderBonsai(recipe) {
  const name = recipe.id.replace(/[^a-z0-9]+/gi, '_');
  const inv = [...inventory(recipe.root)];
  const blocked = inv.map(([n]) => n).filter((n) => !LAYOUT.has(n) && (port[n]?.status ?? 'not started') !== 'ported');
  const header = `(* GENERATED from docs/mockups/${recipe.id}.json — do not edit by hand.
   Screen: ${recipe.title}
   ${recipe.intent}
${blocked.length ? `   BLOCKED: not ported yet -> ${blocked.join(', ')}\n` : ''}*)
open! Core
open! Bonsai_web

let view ~inject:_ =
  let open Bonsai.Let_syntax in
  let%arr () = Bonsai.return () in
  (* TODO: replace the placeholders as each component becomes available. *)
  {%html|<div class="screen">...|}
;;
`;
  const comments = [];
  const walk = (n, depth = 0) => {
    const pad = '  '.repeat(depth);
    const status = LAYOUT.has(n.component) ? 'layout' : (port[n.component]?.status ?? 'not started');
    comments.push(`${pad}(* ${n.component} — ${status} *)`);
    (n.children ?? []).forEach((c) => walk(c, depth + 1));
  };
  walk(recipe.root);
  return header + '\n' + comments.join('\n') + '\n';
}

// ------------------------------------------------------------------ main
const argv = process.argv.slice(2);
const fmt = (() => { const i = argv.indexOf('--format'); return i >= 0 ? argv[i + 1] : 'html'; })();
const files = argv.includes('--all')
  ? fs.readdirSync(path.join(ROOT, 'docs/mockups')).filter((f) => f.endsWith('.json')).map((f) => path.join(ROOT, 'docs/mockups', f))
  : argv.filter((a) => a.endsWith('.json'));

if (!files.length) { console.error('usage: render.mjs <recipe.json ...> | --all [--format html|prompt|bonsai]'); process.exit(2); }
fs.mkdirSync(OUT, { recursive: true });

let n = 0;
for (const f of files) {
  const recipe = JSON.parse(fs.readFileSync(f, 'utf8'));
  problems.length = 0;
  validate(recipe.root);
  if (problems.length) {
    console.error(`\n${recipe.id}: ${problems.length} problem(s) — refusing to render`);
    for (const p of problems.slice(0, 12)) console.error(`  - ${p}`);
    process.exitCode = 1;
    continue;
  }
  const out = {
    html: [path.join(OUT, `${recipe.id}.html`), renderHtml(recipe)],
    prompt: [path.join(OUT, `${recipe.id}.prompt.txt`), renderPrompt(recipe)],
    bonsai: [path.join(OUT, `${recipe.id}.ml`), renderBonsai(recipe)],
  }[fmt];
  fs.writeFileSync(out[0], out[1]);
  const inv = [...inventory(recipe.root)];
  console.log(`${recipe.id}: ${count(recipe.root)} nodes, ${inv.length} distinct components -> ${path.relative(ROOT, out[0])}`);
  n += 1;
}
console.log(`\n${n} recipe(s) rendered as ${fmt} (validated against registry.json: ${byName.size} components)`);
