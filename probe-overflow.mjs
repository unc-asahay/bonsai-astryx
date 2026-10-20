import { readdirSync, existsSync } from "node:fs";
import { resolve } from "node:path";

const cache = resolve(process.env.HOME || "/home/noor", ".cache/ms-playwright");
if (existsSync(cache) && !process.env.PLAYWRIGHT_BROWSERS_PATH) {
  process.env.PLAYWRIGHT_BROWSERS_PATH = cache;
}
const { chromium } = await import("playwright");

const browser = await chromium.launch();
const page = await browser.newPage({ viewport: { width: 320, height: 568 } });
await page.goto("http://127.0.0.1:8791/site/index.html", { waitUntil: "networkidle" });

const out = await page.evaluate(() => {
  const group = document.getElementById("showcase-tokenizer-default-group");
  const chain = [];
  let el = group;
  for (let i = 0; i < 6 && el; i++) {
    const cs = getComputedStyle(el);
    chain.push({
      tag: el.tagName,
      id: el.id || null,
      cls: (el.getAttribute("class") || "").slice(0, 60),
      display: cs.display,
      flexWrap: cs.flexWrap,
      width: Math.round(el.getBoundingClientRect().width),
      minWidth: cs.minWidth,
      overflowX: cs.overflowX,
      flex: cs.flex,
    });
    el = el.parentElement;
  }
  const content = group.querySelector(".astryx-tokenizer__content");
  const cs = content ? getComputedStyle(content) : null;
  return {
    chain,
    content: content
      ? {
          display: cs.display,
          flexWrap: cs.flexWrap,
          width: Math.round(content.getBoundingClientRect().width),
          scrollWidth: content.scrollWidth,
          minWidth: cs.minWidth,
          flex: cs.flex,
        }
      : null,
    contentChildren: content
      ? [...content.children].map((c) => ({
          cls: (c.getAttribute("class") || "").slice(0, 40),
          w: Math.round(c.getBoundingClientRect().width),
          left: Math.round(c.getBoundingClientRect().left),
          top: Math.round(c.getBoundingClientRect().top),
        }))
      : null,
  };
});
console.log(JSON.stringify(out, null, 1));
await browser.close();
