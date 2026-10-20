import { existsSync } from "node:fs";
import { resolve } from "node:path";
const cache = resolve(process.env.HOME || "/home/noor", ".cache/ms-playwright");
if (existsSync(cache) && !process.env.PLAYWRIGHT_BROWSERS_PATH) process.env.PLAYWRIGHT_BROWSERS_PATH = cache;
const { chromium } = await import("playwright");
const browser = await chromium.launch();
const page = await browser.newPage();
await page.goto("http://127.0.0.1:8791/site/index.html", { waitUntil: "networkidle" });
const sec = await page.$("section[data-showcase-component='MultiSelector']");
const trigger = await sec.$('[role="combobox"]');
await trigger.click();
await page.waitForTimeout(300);
const out = await page.evaluate(() => {
  const lb = document.getElementById("astryx-multi-selector-listbox");
  const attrs = (el) => { if (!el) return null; const a = {}; for (const n of el.attributes) a[n.name] = n.value; return a; };
  let chain = [];
  let el = lb;
  for (let i = 0; i < 5 && el; i++) { chain.push({ tag: el.tagName, id: el.id || null, cls: (el.getAttribute("class") || "").slice(0, 50), popover: el.getAttribute("popover") }); el = el.parentElement; }
  return {
    listbox: attrs(lb),
    chain,
    options: [...document.querySelectorAll('#astryx-multi-selector-listbox [role="option"]')].map((o) => ({
      text: o.textContent.trim().slice(0, 24), selected: o.getAttribute("aria-selected"), id: o.id,
    })).slice(0, 6),
    groups: [...document.querySelectorAll('#astryx-multi-selector-listbox [role="group"]')].map((g) => g.getAttribute("aria-label")),
    selectedCount: document.querySelectorAll('#astryx-multi-selector-listbox [role="option"][aria-selected="true"]').length,
  };
});
console.log(JSON.stringify(out, null, 1));
await browser.close();
