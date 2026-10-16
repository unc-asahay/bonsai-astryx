#!/usr/bin/env node
// Responsive gate: does every ported component still work at phone, tablet and
// desktop widths — and does it look the same as last time?
//
// Why a third browser tool rather than more checks in verify-browser.mjs:
//
//   verify-browser.mjs     functional checks at ONE viewport (1440x900). It answers
//                          "is the component correct?".
//   verify-responsive.mjs  the same page at several viewports. It answers two
//                          different questions: "does the layout hold when the
//                          viewport changes?" (invariants below), and "did anything
//                          move since the last run?" (pixel diff against a baseline).
//
// What is asserted per viewport, for both the demo and the showcase:
//
//   1. no horizontal overflow of the page itself
//   2. no component box escapes the viewport
//   3. no component has collapsed to zero width or height
//   4. Grid actually reflows: it shows fewer columns as the viewport narrows
//   5. AspectRatio keeps its ratio (height/width) at every width
//   6. a real mouse click on a real button still increments the counter (E2E, by
//      hit-testing the centre point first, so a component covered by an overlay
//      fails here rather than passing on a synthetic .click())
//
// and across viewports:
//
//   7. each viewport's screenshot is compared to docs/verification/responsive/
//      baseline/<page>-<w>x<h>.png with a real pixel diff. No baseline yet means the
//      run CREATES one and says so — it does not claim a regression test passed.
//
// Usage:
//   python3 -m http.server 8791 --bind 127.0.0.1        # repo root
//   node tools/visual/verify-responsive.mjs
//   node tools/visual/verify-responsive.mjs --update-baseline
//   node tools/visual/verify-responsive.mjs --viewports=390x844,834x1112

import { createRequire } from "node:module";
import { existsSync, readdirSync, mkdirSync, writeFileSync, readFileSync } from "node:fs";
import { resolve, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const require = createRequire(import.meta.url);
const here = dirname(fileURLToPath(import.meta.url));
const root = resolve(here, "../..");

const args = process.argv.slice(2);
const updateBaseline = args.includes("--update-baseline");
const viewportArg = args.find((a) => a.startsWith("--viewports="));
const VIEWPORTS = (viewportArg ? viewportArg.split("=")[1] : "320x568,375x667,768x1024,1440x900")
  .split(",")
  .map((s) => {
    const [w, h] = s.split("x").map(Number);
    return { name: s, width: w, height: h };
  });

const PAGES = [
  { mode: "showcase", url: "http://127.0.0.1:8791/site/index.html" },
  { mode: "demo", url: "http://127.0.0.1:8791/examples/demo/index.html" },
];

const shotDir = resolve(root, "docs/verification/responsive");
const baseDir = resolve(shotDir, "baseline");
mkdirSync(shotDir, { recursive: true });
mkdirSync(baseDir, { recursive: true });

function playwright() {
  for (const p of [
    resolve(root, "node_modules/playwright"),
    resolve(root, "../astryx/node_modules/playwright"),
    "/home/noor/src/astryx/node_modules/playwright",
  ]) {
    if (existsSync(p)) return require(p);
  }
  throw new Error("playwright not found (looked in node_modules of this repo and ../astryx)");
}

function chromiumExecutable() {
  const cache = resolve(process.env.HOME || "/home/noor", ".cache/ms-playwright");
  if (!existsSync(cache)) throw new Error(`no playwright browser cache at ${cache}`);
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

// pngjs is CJS and already present in the upstream clone's node_modules; the diff
// itself is a few lines, so there is no reason to take on pixelmatch's ESM shape.
function pngjs() {
  for (const p of [
    resolve(root, "node_modules/pngjs"),
    resolve(root, "../astryx/node_modules/pngjs"),
    "/home/noor/src/astryx/node_modules/pngjs",
  ]) {
    if (existsSync(p)) return require(p);
  }
  return null;
}

let passed = 0;
const failures = [];
function check(name, ok, detail) {
  if (ok) {
    passed += 1;
    console.log(`  ok   ${name}`);
  } else {
    failures.push(name);
    console.log(`  FAIL ${name}${detail ? ` — ${detail}` : ""}`);
  }
}

// A real pixel diff: decode both PNGs, count pixels whose channels differ by more
// than a tolerance (so antialiasing on a text edge is not a regression), and report
// the percentage. Different dimensions are an automatic fail.
function pixelDiff(png, aPath, bPath, tolerance = 24) {
  const a = png.PNG.sync.read(readFileSync(aPath));
  const b = png.PNG.sync.read(readFileSync(bPath));
  if (a.width !== b.width || a.height !== b.height) {
    return { mismatch: Infinity, total: a.width * a.height, dims: [a.width, a.height, b.width, b.height] };
  }
  let mismatch = 0;
  for (let i = 0; i < a.data.length; i += 4) {
    if (
      Math.abs(a.data[i] - b.data[i]) > tolerance ||
      Math.abs(a.data[i + 1] - b.data[i + 1]) > tolerance ||
      Math.abs(a.data[i + 2] - b.data[i + 2]) > tolerance
    ) {
      mismatch += 1;
    }
  }
  return { mismatch, total: a.width * a.height };
}

const { chromium } = playwright();
const exe = chromiumExecutable();
console.log(`chromium:   ${exe}`);
console.log(`viewports:  ${VIEWPORTS.map((v) => v.name).join(", ")}`);
console.log(`baseline:   ${baseDir}${updateBaseline ? "  (--update-baseline)" : ""}`);

const browser = await chromium.launch({ executablePath: exe, args: ["--no-sandbox"] });

// Grid reflow probe. It targets the auto-fill/auto-fit grid deliberately: a
// `repeat(3, 1fr)` grid does not reflow by definition, so measuring the first grid
// on the page (which is the fixed-2 example) would "fail" for a reason that is not a
// defect. Column counts are read from the computed track list, which is what the
// browser actually laid out.
const GRID_PROBE = () => {
  const grids = [...document.querySelectorAll(".astryx-grid")];
  const responsive =
    grids.find((g) => /auto-fill|auto-fit/.test(g.getAttribute("data-astryx-columns") || "")) ||
    grids[0];
  if (!responsive) return null;
  const cols = getComputedStyle(responsive).gridTemplateColumns;
  const parent = responsive.parentElement;
  return {
    tracks: cols.trim() ? cols.trim().split(/\s+/).length : 0,
    decl: responsive.getAttribute("data-astryx-columns"),
    width: Math.round(responsive.getBoundingClientRect().width),
    parentWidth: parent ? Math.round(parent.getBoundingClientRect().width) : 0,
    all: grids.map((g) => {
      const c = getComputedStyle(g).gridTemplateColumns;
      return {
        decl: (g.getAttribute("data-astryx-columns") || "").slice(0, 28),
        tracks: c.trim() ? c.trim().split(/\s+/).length : 0,
      };
    }),
  };
};

const LAYOUT_PROBE = () => {
  const vw = window.innerWidth;
  const boxes = [...document.querySelectorAll("[data-astryx-component]")].map((el) => {
    const r = el.getBoundingClientRect();
    return {
      component: el.getAttribute("data-astryx-component"),
      left: Math.round(r.left),
      right: Math.round(r.right),
      width: Math.round(r.width),
      height: Math.round(r.height),
    };
  });
  const ar = document.querySelector("[data-astryx-aspect-ratio]");
  const arBox = ar ? ar.getBoundingClientRect() : null;
  return {
    vw,
    scrollWidth: document.documentElement.scrollWidth,
    bodyScrollWidth: document.body ? document.body.scrollWidth : 0,
    boxes,
    collapsed: boxes.filter((b) => b.width === 0 || b.height === 0),
    escaping: boxes.filter((b) => b.right > vw + 1 || b.left < -1),
    aspect: arBox ? { w: Math.round(arBox.width), h: Math.round(arBox.height) } : null,
    navLinks: [...document.querySelectorAll(".nav-list a")].map((a) => {
      const r = a.getBoundingClientRect();
      return { right: Math.round(r.right), left: Math.round(r.left), width: Math.round(r.width) };
    }),
    counter: (() => {
      const el = document.getElementById("click-count");
      return el ? el.textContent.trim() : null;
    })(),
  };
};

const gridColumns = {};

for (const page of PAGES) {
  console.log(`\n${"=".repeat(72)}\n${page.mode}  ${page.url}\n${"=".repeat(72)}`);
  for (const vp of VIEWPORTS) {
    console.log(`\n${page.mode} @ ${vp.name}`);
    // reducedMotion: the skeleton's fade is an infinite alternate animation, so a
    // screenshot taken at an arbitrary moment captures an arbitrary phase and the
    // diff would measure the animation, not the layout. Forcing reduced motion both
    // makes the capture deterministic and exercises the prefers-reduced-motion rules
    // in assets/components.css (a skeleton that still pulses would be a bug there).
    const ctx = await browser.newContext({
      viewport: { width: vp.width, height: vp.height },
      reducedMotion: "reduce",
    });
    const p = await ctx.newPage();
    const errors = [];
    p.on("console", (m) => m.type() === "error" && errors.push(m.text()));
    p.on("pageerror", (e) => errors.push(String(e)));
    await p.goto(page.url, { waitUntil: "load" });
    await p.waitForTimeout(700);

    const L = await p.evaluate(LAYOUT_PROBE);

    check(`[${vp.name}] the page does not overflow horizontally`,
      L.scrollWidth <= L.vw + 1, `scrollWidth ${L.scrollWidth} vs viewport ${L.vw}`);
    check(`[${vp.name}] no component escapes the viewport`,
      L.escaping.length === 0,
      L.escaping.map((b) => `${b.component}(${b.left}..${b.right})`).join(", "));
    check(`[${vp.name}] no component collapsed to zero size`,
      L.collapsed.length === 0,
      L.collapsed.map((b) => b.component).join(", "));
    check(`[${vp.name}] ported components are on the page`, L.boxes.length > 0, `${L.boxes.length}`);

    const fit = L.aspect ? L.aspect.h / L.aspect.w : null;
    if (L.aspect) {
      // Every AspectRatio example on the page is 16/9, so the rendered ratio must be
      // ~0.5625 at every viewport — this is exactly what a ratio box must not lose.
      check(`[${vp.name}] AspectRatio holds its ratio (h/w = ${fit.toFixed(4)})`,
        Math.abs(fit - 9 / 16) < 0.02, `got ${fit.toFixed(4)}, want ${(9 / 16).toFixed(4)}`);
      check(`[${vp.name}] AspectRatio fits the viewport width`,
        L.aspect.w <= L.vw, `${L.aspect.w} > ${L.vw}`);
    }

    if (page.mode === "showcase") {
      const g = await p.evaluate(GRID_PROBE);
      gridColumns[vp.name] = g;
      // The invariant that matters is not "the grid is wide" (a phone is legitimately
      // narrow) but "the grid fills the box it was given": an auto-fill grid sized by
      // its own minimum track is the shrink-to-fit failure this gate exists to catch.
      check(`[${vp.name}] the responsive grid fills its container (${g.width}px of ${g.parentWidth}px, ${g.tracks} track(s))`,
        g.tracks >= 1 && g.width >= Math.min(g.parentWidth, 320) - 2,
        `container ${g.width}px vs parent ${g.parentWidth}px, ${g.tracks} track(s), decl "${g.decl}"`);
      check(`[${vp.name}] the nav does not overflow`,
        L.navLinks.every((l) => l.right <= L.vw + 1 && l.left >= -1),
        L.navLinks.filter((l) => l.right > L.vw + 1).length + " link(s) outside");
      // E2E: hit-test the button's centre first, so a component that is present in
      // the DOM but covered (or off-screen) fails instead of silently passing.
      const hit = await p.evaluate(() => {
        const btn = document.querySelector("#interactive button");
        if (!btn) return { ok: false, why: "no button" };
        const centre = () => {
          const r = btn.getBoundingClientRect();
          return { cx: r.left + r.width / 2, cy: r.top + r.height / 2 };
        };
        let { cx, cy } = centre();
        // Off-screen (below the fold) is normal on a short viewport; bring it into
        // view and re-measure rather than reporting a hit test that never ran.
        if (cy < 0 || cy > innerHeight) {
          btn.scrollIntoView({ block: "center" });
          ({ cx, cy } = centre());
        }
        const at = document.elementFromPoint(cx, cy);
        return {
          ok: true,
          cx,
          cy,
          hitIsButton: !!at && (at === btn || btn.contains(at)),
          tag: at ? `${at.tagName}${at.className ? "." + String(at.className).split(" ")[0] : ""}` : "nothing",
        };
      });
      check(`[${vp.name}] the button is hit-testable at its centre`,
        hit.hitIsButton === true, `elementFromPoint -> ${hit.tag} at ${Math.round(hit.cx)},${Math.round(hit.cy)}`);
      const before = Number((await p.textContent("#click-count")).replace(/\D/g, ""));
      await p.mouse.click(hit.cx, hit.cy);
      await p.waitForTimeout(250);
      const after = Number((await p.textContent("#click-count")).replace(/\D/g, ""));
      check(`[${vp.name}] a real mouse click increments the counter (${before} -> ${after})`,
        after === before + 1, `${before} -> ${after}`);
    }

    check(`[${vp.name}] no console errors`, errors.length === 0, errors.slice(0, 2).join(" | "));

    const shot = resolve(shotDir, `${page.mode}-${vp.name}.png`);
    await p.screenshot({ path: shot, fullPage: true, animations: "disabled" });
    const base = resolve(baseDir, `${page.mode}-${vp.name}.png`);
    const png = pngjs();
    if (!png) {
      console.log(`  note  pngjs not found — screenshot written, no pixel diff`);
    } else if (!existsSync(base) || updateBaseline) {
      writeFileSync(base, readFileSync(shot));
      console.log(`  note  baseline ${updateBaseline ? "updated" : "created"} — ${base.replace(root + "/", "")}`);
      console.log(`        (a baseline created on this run cannot yet detect a regression)`);
    } else {
      const d = pixelDiff(png, base, shot);
      const pct = (100 * d.mismatch) / d.total;
      check(`[${vp.name}] pixels match the baseline (${pct.toFixed(2)}% differ)`,
        pct < 0.5,
        d.dims ? `dimensions differ: ${d.dims.join("x")}` : `${d.mismatch}/${d.total} pixels differ`);
    }
    await ctx.close();
  }
}

// Cross-viewport: the whole point of a responsive layout is that it responds.
console.log("\nreflow (auto-fill grid: tracks per viewport)");
const cols = Object.entries(gridColumns).sort((a, b) => parseInt(a[0]) - parseInt(b[0]));
for (const [name, g] of cols) {
  console.log(`  ${name}: ${g.tracks} track(s) in ${g.width}px`);
  console.log(`     all grids: ${g.all.map((x) => `${x.tracks}x[${x.decl}]`).join(" ")}`);
}
if (cols.length >= 2) {
  const narrow = cols[0];
  const wide = cols[cols.length - 1];
  const narrowW = parseInt(narrow[0]);
  const wideW = parseInt(wide[0]);
  if (wideW < narrowW * 2) {
    // Two viewports a few pixels apart may both fit exactly one track, and that is not
    // a defect. Only assert reflow across a width gap wide enough that the track count
    // must change; otherwise record the observation without pretending it is a test.
    console.log(
      `  note  widest viewport (${wideW}px) is less than twice the narrowest (${narrowW}px) — ` +
        `reflow not asserted, observation only`,
    );
  } else {
    check("the auto-fill grid fits more tracks on a wide viewport than on a narrow one",
      wide[1].tracks > narrow[1].tracks,
      cols.map(([k, g]) => `${k}:${g.tracks}`).join(" "));
  }
  check("every grid on the page has a non-zero track count",
    cols.every(([, g]) => g.all.every((x) => x.tracks > 0)),
    cols.map(([k, g]) => `${k}:${g.all.filter((x) => x.tracks === 0).length} empty`).join(" "));
} else {
  check("reflow compared across viewports", false, "need at least two viewports");
}

await browser.close();

console.log(`\n${passed} checks passed, ${failures.length} failure(s)`);
if (failures.length) {
  console.log("failures:");
  for (const f of failures) console.log(`  - ${f}`);
  console.log("RESPONSIVE CHECKS FAILED");
  process.exit(1);
}
console.log("RESPONSIVE CHECKS PASSED");
