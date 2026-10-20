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

// 1. click an option
await page.click("#showcase-selector-options");
await page.waitForTimeout(300);
await page.click("#showcase-selector-options-listbox-item-0");
await page.waitForTimeout(400);
out.afterClick = await page.evaluate((sec) => {
  const s = document.querySelector(sec);
  const trigger = s.querySelector("#showcase-selector-options");
  return {
    triggerText: (trigger?.textContent ?? "").trim().slice(0, 30),
    expanded: trigger?.getAttribute("aria-expanded"),
    readout: (s.querySelector("#showcase-selector-readout")?.textContent ?? "").trim(),
  };
}, sec);

// 2. reopen and press Enter (no arrow)
await page.click("#showcase-selector-options");
await page.waitForTimeout(300);
await page.keyboard.press("Enter");
await page.waitForTimeout(400);
out.afterEnter = await page.evaluate((sec) => {
  const s = document.querySelector(sec);
  const trigger = s.querySelector("#showcase-selector-options");
  const list = s.querySelector("#showcase-selector-options-listbox");
  return {
    triggerText: (trigger?.textContent ?? "").trim().slice(0, 30),
    expanded: trigger?.getAttribute("aria-expanded"),
    readout: (s.querySelector("#showcase-selector-readout")?.textContent ?? "").trim(),
    highlighted: list?.querySelectorAll(".astryx-selector__option--highlighted").length ?? 0,
    activeDescendant: trigger?.getAttribute("aria-activedescendant"),
  };
}, sec);

// 3. typeahead: focus the trigger and type a letter
await page.click("#showcase-selector-options");
await page.waitForTimeout(250);
await page.keyboard.press("Escape");
await page.waitForTimeout(250);
await page.click("#showcase-selector-options");
await page.waitForTimeout(250);
await page.keyboard.type("g");
await page.waitForTimeout(350);
out.afterType = await page.evaluate((sec) => {
  const s = document.querySelector(sec);
  const trigger = s.querySelector("#showcase-selector-options");
  const list = s.querySelector("#showcase-selector-options-listbox");
  const h = list?.querySelector(".astryx-selector__option--highlighted");
  return {
    highlightedText: (h?.textContent ?? "").trim().slice(0, 30),
    activeDescendant: trigger?.getAttribute("aria-activedescendant"),
  };
}, sec);

console.log(JSON.stringify(out, null, 1));
await browser.close();
