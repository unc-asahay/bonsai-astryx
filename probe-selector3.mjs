import { createRequire } from "node:module";
import { dirname } from "node:path";
import { fileURLToPath } from "node:url";

const require = createRequire(import.meta.url);
const root = dirname(fileURLToPath(import.meta.url));
const { chromium } = require(`${root}/node_modules/playwright`);

const browser = await chromium.launch();
const page = await browser.newPage({ viewport: { width: 1440, height: 900 } });
await page.goto("http://127.0.0.1:8791/site/index.html", { waitUntil: "load" });
await page.waitForTimeout(1200);
const sec = "section[data-showcase-component='Selector']";
const out = {};

const active = () =>
  page.evaluate((sec) => {
    const s = document.querySelector(sec);
    const a = document.activeElement;
    return {
      tag: a?.tagName ?? null,
      id: a?.id ?? null,
      isTrigger: a === s.querySelector("#showcase-selector-options"),
      triggerExpanded: s.querySelector("#showcase-selector-options")?.getAttribute("aria-expanded"),
    };
  }, sec);

await page.click("#showcase-selector-options");
await page.waitForTimeout(300);
out.afterClick = await active();
await page.keyboard.press("ArrowDown");
await page.waitForTimeout(300);
out.afterArrow = await active();
await page.keyboard.press("Enter");
await page.waitForTimeout(400);
out.afterEnter = await active();
out.readout = await page.evaluate((sec) => {
  const s = document.querySelector(sec);
  return (s.querySelector("#showcase-selector-readout")?.textContent ?? "").trim();
}, sec);

console.log(JSON.stringify(out, null, 1));
await browser.close();
