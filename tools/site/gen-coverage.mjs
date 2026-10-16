#!/usr/bin/env node
// Generate site/coverage.json — what is ported and what is not.
//
// The showcase page renders the ported components *live* (it is the compiled
// bundle), but the unported ones have nothing to render, and the site should say
// so rather than quietly omitting 90 components. This writes the honest list the
// page fetches at load time, derived from port.json and registry.json.
//
// Usage: node tools/site/gen-coverage.mjs

import { readFileSync, writeFileSync, mkdirSync, existsSync } from "node:fs";
import { resolve, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import { execFileSync } from "node:child_process";

const here = dirname(fileURLToPath(import.meta.url));
const root = resolve(here, "../..");
const readJson = (p) => JSON.parse(readFileSync(resolve(root, p), "utf8"));

const port = readJson("port.json");
const registry = readJson("registry.json");
const entries = Array.isArray(registry) ? registry : registry.components ?? registry.items;
const all = entries.map((e) => e.name ?? e.component);

const ported = port.ported.map((p) => ({
  name: p.component,
  module: p.module,
  file: p.file,
  milestone: p.milestone,
}));
const portedNames = new Set(ported.map((p) => p.name));
const unported = all.filter((n) => !portedNames.has(n)).sort();
const missing = [...portedNames].filter((n) => !all.includes(n));

// The upstream commit this corpus was extracted from, so the site can state it.
let commit = port.upstream?.commit ?? port.upstream_commit ?? null;
if (!commit && existsSync(resolve(root, "../astryx/.git"))) {
  try {
    commit = execFileSync("git", ["rev-parse", "HEAD"], {
      cwd: resolve(root, "../astryx"),
      encoding: "utf8",
    }).trim();
  } catch {
    /* leave null */
  }
}

const out = {
  generated_by: "tools/site/gen-coverage.mjs",
  upstream: { repo: "facebook/astryx", commit },
  counts: {
    ported: ported.length,
    unported: unported.length,
    total: all.length,
    documented: entries.length,
  },
  ported: ported.sort((a, b) => a.name.localeCompare(b.name)),
  unported,
  // A port list naming something the registry does not have would mean the two
  // sources disagree; surface it instead of hiding it.
  inconsistency: missing.length ? missing : null,
};

const dir = resolve(root, "site");
mkdirSync(dir, { recursive: true });
writeFileSync(resolve(dir, "coverage.json"), JSON.stringify(out, null, 2) + "\n");

console.log(`ported:   ${out.counts.ported}`);
console.log(`unported: ${out.counts.unported}`);
console.log(`total:    ${out.counts.total}`);
if (out.inconsistency) console.log(`WARNING: port.json names ${out.inconsistency.length} component(s) not in registry.json: ${out.inconsistency.join(", ")}`);
console.log(`wrote site/coverage.json (upstream ${commit ? commit.slice(0, 12) : "unknown"})`);
