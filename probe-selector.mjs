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

out.before = await page.evaluate((sec) => {
  const s = document.querySelector(sec);
  const trigger = s.querySelector("#showcase-selector-options");
  const panel = s.querySelector("#showcase-selector-options-panel");
  const list = s.querySelector("#showcase-selector-options-listbox");
  return {
    expanded: trigger.getAttribute("aria-expanded"),
    panelHasPopover: panel?.hasAttribute("popover") ?? false,
    listRole: list?.getAttribute("role") ?? null,
    optionCount: list?.querySelectorAll(".astryx-selector__option").length ?? 0,
    optionRoles: [...(list?.querySelectorAll(".astryx-selector__option") ?? [])].map((o) => o.getAttribute("role")),
    optionIds: [...(list?.querySelectorAll(".astryx-selector__option") ?? [])].map((o) => o.id),
    listVisible: list ? getComputedStyle(list).display !== "none" : null,
  };
}, sec);

await page.click("#showcase-selector-options");
await page.waitForTimeout(400);
out.afterOpen = await page.evaluate((sec) => {
  const s = document.querySelector(sec);
  const trigger = s.querySelector("#showcase-selector-options");
  const list = s.querySelector("#showcase-selector-options-listbox");
  const opts = [...(list?.querySelectorAll(".astryx-selector__option") ?? [])];
  const first = opts[0];
  return {
    expanded: trigger.getAttribute("aria-expanded"),
    listRect: list ? (() => { const r = list.getBoundingClientRect(); return { w: Math.round(r.width), h: Math.round(r.height) }; })() : null,
    firstText: (first?.textContent ?? "").trim().slice(0, 30),
    firstRole: first?.getAttribute("role") ?? null,
    firstSelected: first?.getAttribute("aria-selected") ?? null,
    highlighted: list?.querySelectorAll(".astryx-selector__option--highlighted").length ?? 0,
    activeDescendant: trigger.getAttribute("aria-activedescendant"),
  };
}, sec);

await page.keyboard.press("ArrowDown");
await page.waitForTimeout(250);
out.afterArrow = await page.evaluate((sec) => {
  const s = document.querySelector(sec);
  const trigger = s.querySelector("#showcase-selector-options");
  const list = s.querySelector("#showcase-selector-options-listbox");
  const h = list?.querySelector(".astryx-selector__option--highlighted");
  return {
    highlightedText: (h?.textContent ?? "").trim().slice(0, 30),
    activeDescendant: trigger.getAttribute("aria-activedescendant"),
    activeId: trigger.getAttribute("aria-activedescendant") ? document.getElementById(trigger.getAttribute("aria-activedescendant"))?.textContent?.trim().slice(0, 30) : null,
  };
}, sec);

await page.keyboard.press("Enter");
await page.waitForTimeout(400);
out.afterEnter = await page.evaluate((sec) => {
  const s = document.querySelector(sec);
  const trigger = s.querySelector("#showcase-selector-options");
  const readout = s.querySelector("#showcase-selector-readout");
  return {
    triggerText: (trigger?.textContent ?? "").trim().slice(0, 30),
    expanded: trigger?.getAttribute("aria-expanded"),
    readout: (readout?.textContent ?? "").trim(),
  };
}, sec);

console.log(JSON.stringify(out, null, 1));
await browser.close();
