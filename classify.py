#!/usr/bin/env python3
"""Classify astryx core components by how mechanically a Bonsai port could be done."""
import re, os, json, csv
from pathlib import Path

SRC = Path.home() / "src/astryx/packages/core/src"
HOOKS = re.compile(r"\buse(State|Effect|Ref|Context|Reducer|LayoutEffect|Id|Memo|Callback|SyncExternalStore)\b")
rows = []
for d in sorted(p for p in SRC.iterdir() if p.is_dir() and not p.name.startswith("_")):
    tsx = sorted(d.glob("*.tsx"))
    if not tsx:
        continue
    src = "\n".join(f.read_text(errors="replace") for f in tsx)
    loc = sum(len(f.read_text(errors="replace").splitlines()) for f in tsx)
    flags = dict(
        hooks=bool(HOOKS.search(src)),
        radix="'@radix-ui" in src or '"@radix-ui' in src,
        stylex="stylex" in src,
        portal="createPortal" in src,
        measure=bool(re.search(r"getBoundingClientRect|ResizeObserver|IntersectionObserver|scrollIntoView", src)),
        effect=bool(re.search(r"\buseEffect\b|\buseLayoutEffect\b", src)),
        state=bool(re.search(r"\buseState\b", src)),
        context=bool(re.search(r"\buseContext\b|createContext", src)),
        i18n=bool(re.search(r"useIntl|useTranslation|i18n", src)),
    )
    cls = "A" if not any(flags[k] for k in ("hooks", "portal", "measure")) else (
          "B" if not flags["portal"] and not flags["measure"] else "C")
    rows.append(dict(name=d.name, loc=loc, tsx=len(tsx), cls=cls,
                     doc=(d / f"{d.name}.doc.mjs").exists(),
                     spec=(d / f"{d.name}.spec.md").exists(),
                     tests=(d / "__tests__").exists(), **flags))

out = Path.home() / "src/astryx-port"
out.mkdir(exist_ok=True)
with (out / "component-inventory.csv").open("w", newline="") as fh:
    w = csv.DictWriter(fh, fieldnames=list(rows[0].keys()))
    w.writeheader(); w.writerows(rows)

by = {}
for r in rows:
    by.setdefault(r["cls"], []).append(r["name"])
print(f"components scanned: {len(rows)}   total .tsx LOC: {sum(r['loc'] for r in rows):,}")
for k in "ABC":
    v = by.get(k, [])
    print(f"\n[Class {k}] {len(v)} components")
    print("  " + ", ".join(v[:45]) + (" …" if len(v) > 45 else ""))
for key in ("hooks", "radix", "stylex", "portal", "measure", "effect", "state", "context"):
    print(f"{key:8} {sum(1 for r in rows if r[key]):3}/{len(rows)}")
print(f"doc.mjs {sum(1 for r in rows if r['doc'])}/{len(rows)}   spec.md {sum(1 for r in rows if r['spec'])}/{len(rows)}   __tests__ {sum(1 for r in rows if r['tests'])}/{len(rows)}")
print("inventory ->", out / "component-inventory.csv")
