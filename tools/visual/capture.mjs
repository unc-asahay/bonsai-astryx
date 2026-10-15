#!/usr/bin/env node
/**
 * Capture the visual contract of every Astryx component.
 *
 * Input : a built Storybook (`apps/storybook/dist`, which contains index.json)
 * Output: visual-captures/
 *           shots/<storyId>__<theme>__<mode>.png   component screenshots, 2x
 *           captures.json                          measurements + metadata
 *
 * The screenshots are reference material for mockup and image generation; the
 * measurements feed tools/gen-visual-references.py, which writes the prose
 * visual contract per component and the aggregated design tokens.
 *
 * Usage:
 *   node tools/visual/capture.mjs \
 *     --storybook-dir apps/storybook/dist \
 *     --out visual-captures \
 *     [--themes neutral,dark] [--limit 20] [--filter Button]
 *
 * Theme names come from the Storybook toolbar globals used upstream:
 *   astryxTheme = butter|chocolate|gothic|matcha|neutral|probe|stone|y2k
 *   colorMode   = light|dark
 */
import { chromium } from 'playwright';
import * as fs from 'node:fs';
import * as path from 'node:path';

const args = Object.fromEntries(
  process.argv.slice(2).flatMap((a, i, all) => (a.startsWith('--') ? [[a.slice(2), all[i + 1]?.startsWith('--') || all[i + 1] === undefined ? 'true' : all[i + 1]]] : [])),
);
const STORYBOOK_DIR = path.resolve(args['storybook-dir'] ?? 'apps/storybook/dist');
const OUT = path.resolve(args.out ?? 'visual-captures');
const MODES = (args.modes ?? 'light,dark').split(',').map((s) => s.trim()).filter(Boolean);
const THEME = args.theme ?? 'neutral';
const LIMIT = args.limit ? Number(args.limit) : Infinity;
const FILTER = args.filter ?? '';
const SHOTS = path.join(OUT, 'shots');

fs.mkdirSync(SHOTS, { recursive: true });

function readIndex() {
  const candidates = ['index.json', 'stories.json'];
  for (const c of candidates) {
    const p = path.join(STORYBOOK_DIR, c);
    if (fs.existsSync(p)) return JSON.parse(fs.readFileSync(p, 'utf8'));
  }
  throw new Error(`no storybook index found in ${STORYBOOK_DIR} (looked for ${candidates.join(', ')})`);
}

function storyEntries(index) {
  const raw = index.entries ?? index.stories ?? {};
  return Object.values(raw)
    .filter((e) => (e.type ?? 'story') === 'story')
    .map((e) => ({ id: e.id, title: e.title ?? e.kind ?? '', name: e.name ?? '' }))
    .filter((e) => (FILTER ? `${e.title}${e.name}`.toLowerCase().includes(FILTER.toLowerCase()) : true))
    .sort((a, b) => a.id.localeCompare(b.id));
}

/** Component name from a story title: "Button" / "Components/Button" -> "Button". */
const componentOf = (title) => title.split('/').filter(Boolean).pop()?.replace(/\s+/g, '') ?? title;

const MEASURE = `(() => {
  const root = document.querySelector('#storybook-root') ?? document.body;
  const el = root.firstElementChild ?? root;
  const cs = getComputedStyle(el);
  const pick = (k) => cs.getPropertyValue(k).trim();
  const vars = {};
  const rootCS = getComputedStyle(document.documentElement);
  for (const name of rootCS) if (name.startsWith('--')) vars[name] = rootCS.getPropertyValue(name).trim();
  const rect = el.getBoundingClientRect();
  const bg = pick('background-color');
  return {
    tag: el.tagName.toLowerCase(),
    role: el.getAttribute('role'),
    aria: {
      label: el.getAttribute('aria-label'),
      busy: el.getAttribute('aria-busy'),
      disabled: el.getAttribute('aria-disabled'),
      describedby: el.getAttribute('aria-describedby') !== null,
    },
    box: { w: Math.round(rect.width), h: Math.round(rect.height) },
    style: {
      color: pick('color'),
      background: bg,
      borderColor: pick('border-top-color'),
      borderWidth: pick('border-top-width'),
      borderRadius: pick('border-top-left-radius'),
      boxShadow: pick('box-shadow'),
      fontFamily: pick('font-family').split(',')[0].replace(/["']/g, ''),
      fontSize: pick('font-size'),
      fontWeight: pick('font-weight'),
      lineHeight: pick('line-height'),
      letterSpacing: pick('letter-spacing'),
      textTransform: pick('text-transform'),
      padding: pick('padding'),
      gap: pick('gap'),
      display: pick('display'),
      opacity: pick('opacity'),
      cursor: pick('cursor'),
    },
    themeVars: vars,
    text: (el.textContent ?? '').trim().slice(0, 200),
    html: el.outerHTML.slice(0, 1200),
  };
})()`;

const index = readIndex();
const stories = storyEntries(index).slice(0, LIMIT === Infinity ? undefined : LIMIT);
console.log(`storybook: ${STORYBOOK_DIR}`);
console.log(`stories  : ${stories.length} (theme ${THEME}, modes ${MODES.join('+')})`);
console.log(`output   : ${OUT}`);

const browser = await chromium.launch();
const context = await browser.newContext({ deviceScaleFactor: 2, viewport: { width: 900, height: 700 } });
const page = await context.newPage();

const captures = [];
let failures = 0;
const started = Date.now();

for (const [i, story] of stories.entries()) {
  for (const mode of MODES) {
    const id = `${story.id}__${THEME}__${mode}`;
    const shot = path.join(SHOTS, `${id}.png`);
    const url = `iframe.html?id=${encodeURIComponent(story.id)}&viewMode=story&globals=astryxTheme:${THEME};colorMode:${mode}`;
    try {
      await page.goto(new URL(url, `file://${STORYBOOK_DIR}/`).href, { waitUntil: 'load', timeout: 30000 });
      await page.waitForSelector('#storybook-root', { timeout: 10000 }).catch(() => {});
      await page.evaluate(() => document.fonts?.ready).catch(() => {});
      await page.waitForTimeout(120);
      const measured = await page.evaluate(MEASURE);
      const root = await page.$('#storybook-root');
      await (root ?? page).screenshot({ path: shot });
      captures.push({
        storyId: story.id,
        component: componentOf(story.title),
        title: story.title,
        story: story.name,
        theme: THEME,
        mode,
        shot: path.relative(OUT, shot),
        url,
        ...measured,
      });
    } catch (err) {
      failures += 1;
      captures.push({ storyId: story.id, component: componentOf(story.title), title: story.title, story: story.name, theme: THEME, mode, error: String(err.message).slice(0, 200) });
    }
    if ((i + 1) % 25 === 0) console.log(`  ${i + 1}/${stories.length} stories, ${captures.length} captures, ${failures} errors`);
  }
}

await browser.close();
const meta = {
  generated: new Date().toISOString(),
  storybook: STORYBOOK_DIR,
  theme: THEME,
  modes: MODES,
  stories: stories.length,
  captures: captures.filter((c) => !c.error).length,
  errors: failures,
  seconds: Math.round((Date.now() - started) / 1000),
  components: [...new Set(captures.map((c) => c.component))].sort(),
};
fs.writeFileSync(path.join(OUT, 'captures.json'), JSON.stringify({ meta, captures }, null, 2));
console.log(`done: ${meta.captures} captures in ${meta.seconds}s, ${failures} errors, ${meta.components.length} components`);
console.log(`-> ${path.join(OUT, 'captures.json')}`);
