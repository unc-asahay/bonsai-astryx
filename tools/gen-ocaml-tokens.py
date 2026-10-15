#!/usr/bin/env python3
"""Generate OCaml token bindings and the CSS token layer from upstream source.

Source of truth: astryx `packages/core/src/theme/tokens.stylex.ts` (the
`*Defaults` maps), MIT, pinned by this repository's NOTICE.

Outputs:
  src/tokens.ml        OCaml string bindings + `all`, for tests, docs and any
                       OCaml code that needs a token value
  assets/tokens.css    the same tokens as CSS custom properties on :root, with
                       `color-scheme: light dark` so upstream's `light-dark(...)`
                       values resolve per the user's preference

Never hand-edit either output: run this script.
"""
import json, re
from pathlib import Path

ROOT = Path.home() / "src/bonsai-astryx"
TS = Path.home() / "src/astryx/packages/core/src/theme/tokens.stylex.ts"
UPSTREAM = "astryx:packages/core/src/theme/tokens.stylex.ts"

BLOCKS = [
    ("color", "colorDefaults"),
    ("spacing", "spacingDefaults"),
    ("size", "sizeDefaults"),
    ("border", "borderDefaults"),
    ("focus", "focusDefaults"),
    ("radius", "radiusDefaults"),
    ("shadow", "shadowDefaults"),
    ("duration", "durationDefaults"),
    ("ease", "easeDefaults"),
    ("typography", "typographyDefaults"),
    ("text_size", "textSizeDefaults"),
    ("font_weight", "fontWeightDefaults"),
    ("type_scale", "typeScaleDefaults"),
]

text = TS.read_text()


def parse_block(name):
    m = re.search(rf"export const {name} = \{{(.*?)\n\}} as const;", text, re.S)
    if not m:
        return []
    out = []
    for key, val in re.findall(r"'(--[a-z0-9-]+)':\s*'([^']*)'", m.group(1)):
        out.append((key, val))
    for key, val in re.findall(r"'(--[a-z0-9-]+)':\s*([0-9.]+)\b", m.group(1)):
        out.append((key, val))
    return out


def ocaml_name(token):
    return token.lstrip("-").replace("-", "_")


def ocaml_str(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


(ROOT / "assets").mkdir(exist_ok=True)
(ROOT / "src").mkdir(exist_ok=True)


groups, flat = [], []
for prefix, block in BLOCKS:
    toks = parse_block(block)
    if not toks:
        print(f"  ! no tokens parsed from {block}")
        continue
    groups.append((prefix, toks))
    flat.extend(toks)

ml = [
    "(* GENERATED FILE — do not edit by hand.",
    f"   Source: {UPSTREAM}  (MIT, Meta Platforms, Inc. and affiliates)",
    "   Regenerate with: python3 tools/gen-ocaml-tokens.py",
    "",
    "   These are the upstream design tokens as published. Values may use modern CSS",
    "   syntax (e.g. light-dark(...)); they are emitted verbatim, so anything that",
    "   consumes them must be a browser (or resolve them the same way). *)",
    "",
    "open! Core",
    "",
    "let source = " + ocaml_str(UPSTREAM),
    "",
]
for prefix, toks in groups:
    ml.append(f"(* {prefix}: {len(toks)} tokens *)")
    for k, v in toks:
        ml.append(f"let {ocaml_name(k)} = {ocaml_str(v)}")
    ml.append("")

ml.append("let all : (string * string) list =")
ml.append("  [")
for k, v in flat:
    ml.append(f"    {ocaml_str(k)}, {ocaml_name(k)};")
ml.append("  ]")
ml.append("")
ml.append("let find name = List.Assoc.find all ~equal:String.equal name")
ml.append("")
(ROOT / "src/tokens.ml").write_text("\n".join(ml))

css = [
    "/* GENERATED FILE — do not edit by hand.",
    f"   Source: {UPSTREAM} (MIT, Meta Platforms, Inc. and affiliates)",
    "   Regenerate with: python3 tools/gen-ocaml-tokens.py",
    "   Upstream values use light-dark(...); color-scheme below makes them resolve. */",
    "",
    ":root {",
    "  color-scheme: light dark;",
]
for prefix, toks in groups:
    css.append(f"  /* {prefix} */")
    for k, v in toks:
        css.append(f"  {k}: {v};")
    css.append("")
css.append("}")
(ROOT / "assets/tokens.css").write_text("\n".join(css) + "\n")

summary = {p: len(t) for p, t in groups}
(ROOT / "tokens.ocaml.json").write_text(json.dumps({p: dict(toks) for p, toks in groups}, indent=2))
print(f"src/tokens.ml        {len(flat)} tokens in {len(groups)} groups")
print(f"assets/tokens.css    {sum(summary.values())} custom properties")
for p, n in summary.items():
    print(f"   {p:14} {n}")
