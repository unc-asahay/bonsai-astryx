#!/usr/bin/env python3
"""Fill registry.json gaps from TypeScript source.

Astryx ships a `<Name>.doc.mjs` for 100 components; the rest (Heading, HStack,
VStack, …) only have source, and a few documented ones list no props at all.
Rather than treat those as unknown, extract the `<Name>Props` interface from the
`.tsx`/`.ts` source so every consumer (validator, mockup renderer, reference
generator) sees one uniform contract.

Components filled this way get `docSource: "tsx"`, so a consumer can tell a
hand-authored upstream doc from a mechanically derived one.

Usage: python3 tools/extract-source-contracts.py
"""
import json, re
from pathlib import Path

ROOT = Path.home() / "src/bonsai-astryx"
SRC = Path.home() / "src/astryx/packages/core/src"
REG = ROOT / "registry.json"

registry = json.loads(REG.read_text())
by_dir = {c["dir"]: c for c in registry["components"]}
dirs = sorted(d for d in (p.name for p in SRC.iterdir() if p.is_dir())
              if not d.startswith("_") and d not in {"i18n", "theme", "utils"})

# Candidates: not documented at all, or documented but with no props listed.
targets = [d for d in dirs if d not in by_dir or not by_dir[d].get("props")]

MEMBER = re.compile(r"^(\s+)([A-Za-z_][A-Za-z0-9_]*)(\?)?:\s*(.*)$")


def balanced_body(text, open_idx):
    depth, i = 0, open_idx
    while i < len(text):
        if text[i] == "{":
            depth += 1
        elif text[i] == "}":
            depth -= 1
            if depth == 0:
                return text[open_idx + 1:i]
        i += 1
    return ""


def clean(s):
    """Drop comment noise that leaks in when a type spans lines."""
    s = s.split("/**")[0]
    s = re.sub(r"//.*", "", s)
    return re.sub(r"\s+", " ", s).strip().rstrip(";, ")


def parse_props(text, name):
    m = re.search(rf"(?:export\s+)?(?:interface|type)\s+{name}Props\b[^{{;]*{{", text)
    if not m:
        return None
    body = balanced_body(text, m.end() - 1)
    if not body.strip():
        return None
    lines = body.splitlines()
    base = min((len(mm.group(1)) for line in lines if (mm := MEMBER.match(line))), default=None)
    if base is None:
        return None

    props, doc, cur = [], [], None
    in_doc = False
    for line in lines:
        stripped = line.strip()
        if in_doc:
            doc.append(stripped.lstrip("*").strip())
            if "*/" in stripped:
                in_doc = False
            continue
        if stripped.startswith("/**"):
            doc, in_doc = [stripped.lstrip("/*").strip()], "*/" not in stripped
            continue
        if stripped.startswith("*") or stripped.startswith("//") or not stripped:
            continue
        mm = MEMBER.match(line)
        if mm and len(mm.group(1)) == base:
            if cur:
                props.append(cur)
            docstr = " ".join(x for x in doc if x).strip()
            default = ""
            dm = re.search(r"@default\s+(.+)", docstr)
            if dm:
                default = dm.group(1).strip()
                docstr = docstr.replace(dm.group(0), "").strip()
            cur = {
                "name": mm.group(2),
                "type": clean(mm.group(4)),
                "required": mm.group(3) != "?",
                "default": default,
                "description": docstr or None,
            }
            doc = []
        elif cur:
            cur["type"] = clean(cur["type"] + " " + stripped)
    if cur:
        props.append(cur)
    return [p for p in props if p["name"] != "ref"] or None


added = []
for d in targets:
    found = None
    for f in sorted((SRC / d).glob("*.ts*")):
        if f.name.endswith((".test.tsx", ".test.ts", ".doc.mjs")):
            continue
        props = parse_props(f.read_text(errors="ignore"), d)
        if props:
            found = (props, f.name)
            break
    if not found:
        print(f"  ! {d}: no usable <{d}Props> interface")
        continue
    entry = by_dir.get(d)
    if entry is None:
        entry = {
            "dir": d, "name": d, "group": None, "category": None, "keywords": [],
            "description": None, "bestPractices": [], "accessibility": [], "anatomy": [],
            "hasSpec": (SRC / d / f"{d}.spec.md").exists(),
            "hasTests": (SRC / d / "__tests__").exists(),
        }
        registry["components"].append(entry)
    entry["props"] = found[0]
    entry["docSource"] = "tsx"
    entry["propsFrom"] = found[1]
    added.append((d, len(found[0])))

registry["components"].sort(key=lambda c: c["name"])
registry["source"]["components"] = len(registry["components"])
registry["source"]["filledFromSource"] = sorted(d for d, _ in added)
REG.write_text(json.dumps(registry, indent=2))

print(f"filled from TypeScript source: {len(added)}")
for d, n in added:
    print(f"  {d:20} {n} props")
print(f"\nregistry now: {len(registry['components'])} components, "
      f"{sum(len(c.get('props') or []) for c in registry['components'])} props")

for probe in ("Stack", "Heading", "CheckboxInput", "Divider"):
    c = by_dir.get(probe) or next((x for x in registry["components"] if x["name"] == probe), None)
    if not c:
        print(f"\n{probe}: MISSING from registry")
        continue
    props = c.get("props") or []
    print(f"\n{probe} ({len(props)} props, source={c.get('docSource', 'doc.mjs')}):")
    print("  " + ", ".join(f"{p.get('name')}{'?' if not p.get('required') else ''}" for p in props[:18]))
