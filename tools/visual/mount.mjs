// Mount the compiled demo bundle in a real DOM (jsdom).
//
// This is the canonical version of the mount, including the two environment
// traps that are otherwise rediscovered every time (see docs/VERIFICATION.md):
//
//   1. Core resolves the local timezone at startup and its js_of_ocaml loader
//      drives Temporal, so a bare jsdom realm throws `Base__Info0.Exn: unknown
//      zone` for *every* zone — including UTC — and Bonsai never renders.
//      Fix: install @js-temporal/polyfill into the realm and pin TZ.
//   2. Do not mirror jsdom's globals onto node's globalThis: jsdom's
//      performance.now() delegates to the global one, so copying
//      window.performance recurses until the stack dies.
//
// tools/visual/verify-dom.mjs still carries its own copy of this setup; it is the
// older file and is left untouched so a working gate is not disturbed mid-flight.

import { createRequire } from "node:module";
import { readFileSync, existsSync } from "node:fs";
import { resolve, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const require = createRequire(import.meta.url);
const here = dirname(fileURLToPath(import.meta.url));
export const root = resolve(here, "../..");

function resolveFrom(candidates, what) {
  for (const c of candidates) if (existsSync(c)) return c;
  throw new Error(`${what} not found. Tried: ${candidates.join(", ")}`);
}

export const jsdomPath = () =>
  resolveFrom([resolve(root, "node_modules/jsdom")], "jsdom");

export const temporalPath = () =>
  resolveFrom([resolve(root, "node_modules/@js-temporal/polyfill")], "@js-temporal/polyfill");

export const bundlePath = () => resolve(root, "_build/default/examples/demo/demo.bc.js");

/* The showcase bundle renders every ported component (the demo page is a smaller
   composition). Tools that need the full set — the appearance contract — mount this
   one instead. */
export const showcaseBundlePath = () =>
  resolve(root, "_build/default/examples/showcase/showcase.bc.js");

export function assetsCss() {
  const assets = resolve(root, "assets");
  const order = ["tokens.css", "components.css", "layout.css"];
  return order
    .filter((f) => existsSync(resolve(assets, f)))
    .map((f) => readFileSync(resolve(assets, f), "utf8"))
    .join("\n");
}

/**
 * Boots the demo app in jsdom and returns the live window once it has mounted.
 * Throws (rather than exiting) so callers can decide how to report failure.
 */
export async function mountDemo({
  quiet = true,
  waitMs = 250,
  bundle = null,
  rootId = "astryx-demo",
} = {}) {
  const { JSDOM, VirtualConsole } = require(jsdomPath());
  const TemporalPolyfill = require(temporalPath());

  const virtualConsole = new VirtualConsole();
  if (!quiet) {
    virtualConsole.on("jsdomError", (e) => console.error("[jsdomError]", e.message, e.detail || ""));
    virtualConsole.on("error", (...a) => console.error("[page error]", ...a));
    virtualConsole.on("warn", (...a) => console.error("[page warn]", ...a));
    virtualConsole.on("log", (...a) => console.error("[page log]", ...a));
  }

  const dom = new JSDOM(
    `<!DOCTYPE html><html><head><style>${assetsCss()}</style></head>` +
      `<body><div id="${rootId}"></div></body></html>`,
    {
      runScripts: "outside-only",
      pretendToBeVisual: true,
      url: "http://localhost/",
      virtualConsole,
      beforeParse(window) {
        try {
          window.Intl = Intl;
        } catch {
          /* older node exposes it differently; harmless */
        }
        // Core reads TZ (or drives Temporal) to resolve the local zone. The demo
        // does not depend on local time, so UTC keeps the render deterministic.
        try {
          window.process = { env: { TZ: "UTC" } };
        } catch {
          /* ignore */
        }
        try {
          window.TemporalPolyfill = TemporalPolyfill;
        } catch {
          /* ignore */
        }
      },
    },
  );

  const bundlePathToUse = bundle ?? bundlePath();
  if (!existsSync(bundlePathToUse)) throw new Error(`missing ${bundlePathToUse} — run: dune build`);

  // ES modules are strict: no implicit globals. Everything goes through dom.window.
  dom.window.eval(readFileSync(bundlePathToUse, "utf8"));
  await new Promise((r) => setTimeout(r, waitMs));

  const document = dom.window.document;
  if (!document.querySelector("[data-astryx-component]")) {
    throw new Error(
      "the app did not mount: no ported component in the document. " +
        `body was: ${document.body.innerHTML.slice(0, 300)}`,
    );
  }
  return { dom, window: dom.window, document };
}

/** All mounted components, as {name, el, attrs, classes, text}. */
export function mountedComponents(document) {
  return [...document.querySelectorAll("[data-astryx-component]")].map((el) => {
    const attrs = {};
    for (const a of el.attributes) attrs[a.name] = a.value;
    return {
      name: el.getAttribute("data-astryx-component"),
      el,
      tag: el.tagName.toLowerCase(),
      attrs,
      classes: (el.getAttribute("class") || "").split(/\s+/).filter(Boolean),
      text: (el.textContent || "").trim().slice(0, 80),
    };
  });
}
