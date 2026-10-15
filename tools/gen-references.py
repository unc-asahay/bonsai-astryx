#!/usr/bin/env python3
"""Generate per-component LLM reference text + a compact index from registry.json.

Design rule: every byte of reference text is generated from a machine-readable
source (registry.json, extracted from Astryx's own <Name>.doc.mjs), so the docs
cannot drift from the upstream contract. Port-specific facts (OCaml module,
parity status) come from port.json when it exists.
"""
import json, re
from pathlib import Path

ROOT = Path.home() / "src/astryx-port"
DOCS = ROOT / "docs"
COMPONENTS = DOCS / "components"
registry = json.loads((ROOT / "registry.json").read_text())
port_meta = json.loads((ROOT / "port.json").read_text()) if (ROOT / "port.json").exists() else {}

COMPONENTS.mkdir(parents=True, exist_ok=True)


def slug(name):
    return re.sub(r"(?<!^)(?=[A-Z])", "_", name).lower()


def wrap(text, width=76, indent=""):
    words, lines, cur = str(text).split(), [], ""
    for w in words:
        if len(cur) + len(w) + 1 > width:
            lines.append(indent + cur); cur = w
        else:
            cur = f"{cur} {w}".strip()
    if cur:
        lines.append(indent + cur)
    return "\n".join(lines)


def render(c):
    name = c["name"]
    p = port_meta.get(name, {})
    L = []
    L.append(f"# {name}")
    L.append("")
    L.append(f"**Category:** {c['category'] or '-'}  |  **Group:** {c['group'] or '-'}  "
             f"|  **Port status:** {p.get('status', 'not started')}")
    L.append("")
    if c["description"]:
        L.append(wrap(c["description"]))
        L.append("")

    L.append("## When to reach for it / when not to")
    L.append("")
    for b in c["bestPractices"]:
        mark = "**Do:**" if b.get("guidance") else "**Don't:**"
        L.append(f"- {mark} {wrap(b.get('description', ''), width=72, indent='  ').lstrip()}")
    L.append("")

    if c["props"]:
        L.append("## Props")
        L.append("")
        L.append("| prop | type | required | default | meaning |")
        L.append("| --- | --- | --- | --- | --- |")
        for pr in c["props"]:
            t = str(pr.get("type", "")).replace("|", "\\|")
            d = str(pr.get("default", "")).replace("|", "\\|")
            desc = str(pr.get("description", "")).replace("\n", " ").replace("|", "\\|")
            L.append(f"| `{pr.get('name')}` | `{t}` | {'yes' if pr.get('required') else 'no'} "
                     f"| `{d}` | {desc} |")
        L.append("")

    if c["anatomy"]:
        L.append("## Anatomy")
        L.append("")
        for a in c["anatomy"]:
            req = "required" if a.get("required") else "optional"
            L.append(f"- `{a.get('name')}` ({req}) — {a.get('description', '')}")
        L.append("")

    if c["accessibility"]:
        L.append("## Accessibility contract")
        L.append("")
        for a in c["accessibility"]:
            L.append(f"- **{a.get('name')}** — {a.get('criterion', '')}, "
                     f"needs {a.get('requirement', '')} in "
                     f"{', '.join(a.get('states', [])) or 'all states'}. {a.get('description', '')}")
        L.append("")

    if p:
        L.append("## OCaml / Bonsai API")
        L.append("")
        if p.get("module"):
            L.append(f"- Module: `{p['module']}`")
        if p.get("signature"):
            L.append("```ocaml")
            L.append(p["signature"].rstrip())
            L.append("```")
        if p.get("customization"):
            L.append(f"- Customization: {p['customization']}")
        if p.get("divergence"):
            L.append(f"- Divergence from upstream: {p['divergence']}")
        if p.get("parity"):
            L.append(f"- Parity evidence: {p['parity']}")
        L.append("")

    L.append("## Retrieval keywords")
    L.append("")
    L.append(", ".join(f"`{k}`" for k in c["keywords"]))
    L.append("")
    L.append("---")
    L.append("")
    L.append(f"Generated from `astryx/packages/core/src/{c['dir']}/{c['dir']}.doc.mjs` "
             f"(MIT, {registry['source']['repo']}). "
             f"Spec: {'yes' if c['hasSpec'] else 'no'} · "
             f"upstream tests: {'yes' if c['hasTests'] else 'no'}.")
    return "\n".join(L) + "\n"


index = ["# Component index", "",
         f"Generated {registry['source']['extracted'][:10]} from Astryx "
         f"({registry['source']['components']} documented components, MIT). "
         "One line per component; open the per-component file for the full contract.", "",
         "| component | category | status | one-liner |", "| --- | --- | --- | --- |"]
written = 0
for c in registry["components"]:
    (COMPONENTS / f"{c['name']}.md").write_text(render(c))
    written += 1
    one = (c["description"] or "").split(". ")[0][:110]
    status = port_meta.get(c["name"], {}).get("status", "not started")
    index.append(f"| [{c['name']}](components/{c['name']}.md) | {c['category'] or '-'} | {status} | {one} |")

(DOCS / "INDEX.md").write_text("\n".join(index) + "\n")
print(f"wrote {written} component references -> {COMPONENTS}")
print(f"index -> {DOCS / 'INDEX.md'}")
print(f"total bytes: {sum(f.stat().st_size for f in COMPONENTS.glob('*.md')):,}")
