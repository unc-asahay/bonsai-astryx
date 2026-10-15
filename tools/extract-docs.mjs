// Extract the machine-readable ComponentDoc objects that Astryx ships
// alongside every component (packages/core/src/<Name>/<Name>.doc.mjs).
// Output: registry.json - the source of truth for generated LLM references.
import { readdirSync, existsSync, writeFileSync, statSync } from 'node:fs';
import { join } from 'node:path';
import { pathToFileURL } from 'node:url';

const SRC = join(process.env.HOME, 'src/astryx/packages/core/src');
const OUT = join(process.env.HOME, 'src/astryx-port/registry.json');

const dirs = readdirSync(SRC).filter((d) => {
  const p = join(SRC, d);
  return statSync(p).isDirectory() && !d.startsWith('_') && d !== 'hooks';
});

const entries = [];
const failures = [];
for (const dir of dirs) {
  const docPath = join(SRC, dir, `${dir}.doc.mjs`);
  if (!existsSync(docPath)) { failures.push({ dir, reason: 'no doc.mjs' }); continue; }
  try {
    const mod = await import(pathToFileURL(docPath).href);
    const doc = mod.docs ?? mod.default;
    if (!doc) { failures.push({ dir, reason: 'no `docs` export' }); continue; }
    entries.push({ dir, doc });
  } catch (err) {
    failures.push({ dir, reason: String(err.message).slice(0, 120) });
  }
}

entries.sort((a, b) => a.dir.localeCompare(b.dir));
const registry = {
  source: {
    repo: 'https://github.com/facebook/astryx',
    path: 'packages/core/src/<Name>/<Name>.doc.mjs',
    license: 'MIT',
    extracted: new Date().toISOString(),
    components: entries.length,
    failures,
  },
  components: entries.map(({ dir, doc }) => ({
    dir,
    name: doc.name ?? dir,
    group: doc.group ?? null,
    category: doc.category ?? null,
    keywords: doc.keywords ?? [],
    description: doc.usage?.description ?? null,
    bestPractices: doc.usage?.bestPractices ?? [],
    accessibility: doc.usage?.accessibility ?? [],
    anatomy: doc.usage?.anatomy ?? [],
    props: doc.props ?? [],
    hasSpec: existsSync(join(SRC, dir, `${dir}.spec.md`)),
    hasTests: existsSync(join(SRC, dir, '__tests__')),
  })),
};

writeFileSync(OUT, JSON.stringify(registry, null, 2));
const p = registry.components;
const sum = (f) => p.reduce((n, c) => n + f(c), 0);
console.log(`components with docs: ${p.length}   failures: ${failures.length}`);
console.log(`props documented:     ${sum((c) => c.props.length)}`);
console.log(`do/don't guidance:    ${sum((c) => c.bestPractices.length)}`);
console.log(`a11y criteria:        ${sum((c) => c.accessibility.length)}`);
console.log(`anatomy entries:      ${sum((c) => c.anatomy.length)}`);
console.log(`with spec.md:         ${p.filter((c) => c.hasSpec).length}`);
console.log(`with __tests__:       ${p.filter((c) => c.hasTests).length}`);
if (failures.length) console.log('failures:', JSON.stringify(failures.slice(0, 8)));
const sample = p.find((c) => c.name === 'Button');
console.log('\nsample (Button):', JSON.stringify({
  category: sample.category, keywords: sample.keywords.slice(0, 6),
  props: sample.props.map((x) => `${x.name}: ${String(x.type).slice(0, 40)}`).slice(0, 6),
}, null, 1));
console.log('\n->', OUT);
