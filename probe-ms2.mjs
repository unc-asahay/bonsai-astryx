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
  const first = document.querySelector('section[data-showcase-component="MultiSelector"] [data-astryx-component="MultiSelector"]');
  const attrs = (el) => { if (!el) return null; const a = {}; for (const n of el.attributes) a[n.name] = n.value; return a; };
  return {
    expanded: first?.querySelector('[role="combobox"]')?.getAttribute("aria-expanded"),
    popover: attrs(first?.querySelector('[popover]')),
    listbox: attrs(first?.querySelector('[role="listbox"]')),
    options: [...(first?.querySelectorAll('[role="option"]') ?? [])].map((o) => ({
      text: o.textContent.trim().slice(0, 30),
      selected: o.getAttribute("aria-selected"),
      disabled: o.getAttribute("aria-disabled"),
      id: o.id,
    })).slice(0, 6),
    groups: [...(first?.querySelectorAll('[role="group"]') ?? [])].map((g) => g.getAttribute("aria-label")),
    active: first?.querySelector('[role="combobox"]')?.getAttribute("aria-activedescendant"),
    activedesc: first?.querySelector('[aria-activedescendant]')?.getAttribute("aria-activedescendant"),
  };
});
console.log(JSON.stringify(out, null, 1));
await browser.close();
