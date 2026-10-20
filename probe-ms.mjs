import { readdirSync, existsSync } from "node:fs";
import { resolve } from "node:path";

const cache = resolve(process.env.HOME || "/home/noor", ".cache/ms-playwright");
if (existsSync(cache) && !process.env.PLAYWRIGHT_BROWSERS_PATH) {
  process.env.PLAYWRIGHT_BROWSERS_PATH = cache;
}
const { chromium } = await import("playwright");

const browser = await chromium.launch();
const page = await browser.newPage();
await page.goto("http://127.0.0.1:8791/site/index.html", { waitUntil: "networkidle" });

const out = await page.evaluate(() => {
  const sec = document.querySelector("section[data-showcase-component='MultiSelector']");
  if (!sec) return { error: "no section" };
  const all = [...sec.querySelectorAll('[data-astryx-component="MultiSelector"]')];
  const first = all[0];
  const attrs = (el) => {
    if (!el) return null;
    const a = {};
    for (const n of el.attributes) a[n.name] = n.value;
    return a;
  };
  return {
    count: all.length,
    first: attrs(first),
    trigger: attrs(first?.querySelector('[role="combobox"]')),
    triggerTag: first?.querySelector('[role="combobox"]')?.tagName,
    listboxId: first?.querySelector('[role="listbox"]')?.id ?? null,
    listboxAttrs: attrs(first?.querySelector('[role="listbox"]')),
    sectionIds: [...sec.querySelectorAll('[id^="showcase-multi-selector"]')].map((e) => e.id),
    text: first?.textContent?.slice(0, 120),
  };
});
console.log(JSON.stringify(out, null, 1));
await browser.close();
