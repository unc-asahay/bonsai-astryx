#!/usr/bin/env python3
"""Generate the visual contract + design tokens for LLM-driven mockups and images.

Input : visual-captures/captures.json   (from tools/visual/capture.mjs)
        registry.json                   (upstream prop/usage contract)
Output: tokens.json                     aggregated design tokens with counts
        docs/visual/TOKENS.md           human + LLM readable token table
        docs/visual/<Name>.md           per-component visual contract, incl. an
                                        image-generation prompt and mockup notes

Design rule: everything here is measured or extracted — never invented. Where a
value is unknown the file says so instead of guessing.
"""
import json, re, statistics
from collections import Counter, defaultdict
from pathlib import Path

ROOT = Path.home() / "src/bonsai-astryx"
CAPS = json.loads((ROOT / "visual-captures/captures.json").read_text())
REG = {c["name"]: c for c in json.loads((ROOT / "registry.json").read_text())["components"]}
OUT_DOCS = ROOT / "docs/visual"
OUT_DOCS.mkdir(parents=True, exist_ok=True)

captures = [c for c in CAPS["captures"] if not c.get("error")]
by_component = defaultdict(list)
for c in captures:
    by_component[c["component"]].append(c)


def px(v):
    m = re.match(r"^(-?[\d.]+)px$", str(v).strip())
    return float(m.group(1)) if m else None


def is_transparent(c):
    return c in ("rgba(0, 0, 0, 0)", "transparent", "")


def summary(values, unit="px", limit=4):
    """Most common values, with how many components share them."""
    counts = Counter(v for v in values if v and v not in ("normal",))
    out = []
    for v, n in counts.most_common(limit):
        out.append(f"{v} ({n})" if unit == "" else f"{v} ({n})")
    return "; ".join(out) if out else "n/a"


# ---------------------------------------------------------------- tokens
def collect(key, unit="px", filt=None):
    vals = []
    for c in captures:
        v = c.get("style", {}).get(key)
        if v and (filt is None or filt(v)):
            vals.append(v)
    return vals


colors = Counter()
for c in captures:
    for k in ("color", "background", "borderColor"):
        v = c["style"].get(k)
        if v and not is_transparent(v):
            colors[v] += 1

radii = Counter(v for v in collect("borderRadius") if px(v) and px(v) > 0)
spacings = Counter()
for c in captures:
    pad = c["style"].get("padding", "")
    if pad and pad != "0px":
        spacings[pad] += 1
shadows = Counter(v for v in collect("boxShadow") if v and v != "none")
fonts = Counter(v for v in collect("fontFamily"))
sizes = Counter(v for v in collect("fontSize") if px(v))
weights = Counter(v for v in collect("fontWeight"))
heights = Counter(str(c["box"]["h"]) + "px" for c in captures if c.get("box", {}).get("h"))
gaps = Counter(v for v in collect("gap") if v and v != "normal" and px(v) and px(v) > 0)

# colour roles come from the theme variables the upstream build defines
theme_vars = {}
for c in captures:
    for k, v in (c.get("themeVars") or {}).items():
        if v and not is_transparent(v):
            theme_vars.setdefault(k, Counter())[v] += 1
theme_vars = {k: v.most_common(1)[0][0] for k, v in theme_vars.items() if len(v) == 1 or True}

tokens = {
    "source": CAPS["meta"],
    "colors": dict(colors.most_common(40)),
    "radii": dict(radii.most_common(12)),
    "spacings": dict(spacings.most_common(20)),
    "shadows": dict(shadows.most_common(10)),
    "fontFamilies": dict(fonts.most_common(6)),
    "fontSizes": dict(sizes.most_common(15)),
    "fontWeights": dict(weights.most_common(10)),
    "componentHeights": dict(heights.most_common(15)),
    "gaps": dict(gaps.most_common(12)),
    "themeVariables": dict(sorted(theme_vars.items())[:200]),
}
(ROOT / "tokens.json").write_text(json.dumps(tokens, indent=2))


def hex_of(rgb):
    m = re.match(r"rgba?\((\d+), ?(\d+), ?(\d+)", str(rgb))
    if not m:
        return None
    return "#%02x%02x%02x" % tuple(int(x) for x in m.groups())


t = ["# Design tokens", "",
     f"Measured from {CAPS['meta']['captures']} rendered captures across "
     f"{len(CAPS['meta']['components'])} components "
     f"(theme `{CAPS['meta']['theme']}`, modes {', '.join(CAPS['meta']['modes'])}).",
     "Values are observed frequencies, not a spec — use them as the palette a mockup",
     "should draw from, and `tokens.json` for machine consumption.", ""]
for title, data, note in [
    ("Colours (text, surface, border — measured)", colors, "count = how many captures used it"),
    ("Corner radii", radii, ""),
    ("Inner padding", spacings, ""),
    ("Elevation (box-shadow)", shadows, ""),
    ("Type — families", fonts, ""),
    ("Type — sizes", sizes, ""),
    ("Type — weights", weights, ""),
    ("Component heights", heights, ""),
    ("Gaps inside components", gaps, ""),
]:
    t += [f"## {title}", "", f"| value | count |{' notes |' if note else ''}", "| --- | --- | --- |" if not note else "| --- | --- | --- |"]
    for v, n in list(data.most_common(15)):
        t.append(f"| `{v}` | {n} |{' ' + note if note else ''} |")
    t.append("")
t += ["## Theme variables exposed by the upstream build", "",
      "| variable | value |", "| --- | --- |"]
for k, v in list(sorted(theme_vars.items()))[:80]:
    t.append(f"| `{k}` | `{v}` |")
(OUT_DOCS / "TOKENS.md").write_text("\n".join(t) + "\n")

# ---------------------------------------------------------------- per component
def appearance(name, caps):
    """Prose description of how the component looks, for a text-to-image model."""
    c = caps[0]
    s = c["style"]
    bits = []
    if hex_of(s.get("background")):
        bits.append(f"filled with {hex_of(s['background'])}")
    else:
        bits.append("on a transparent background")
    if px(s.get("borderWidth")) and px(s["borderWidth"]) > 0:
        bits.append(f"a {s['borderWidth']} {hex_of(s.get('borderColor')) or s.get('borderColor')} border")
    r = px(s.get("borderRadius"))
    bits.append(f"{s['borderRadius']} rounded corners" if r else "square corners")
    if s.get("boxShadow") and s["boxShadow"] != "none":
        bits.append(f"elevation {s['boxShadow']}")
    bits.append(f"{s.get('fontFamily')} {s.get('fontWeight')} {s.get('fontSize')} text in {hex_of(s.get('color')) or s.get('color')}")
    box = c.get("box", {})
    if box.get("w") and box.get("h"):
        bits.append(f"measured {box['w']}x{box['h']} px")
    return f"A single {name} component: " + ", ".join(bits) + "."


def prompt(name, caps, reg):
    c = caps[0]
    s = c["style"]
    lines = [appearance(name, caps)]
    if reg and reg.get("description"):
        lines.append("Purpose: " + reg["description"].strip().replace("\n", " ")[:300])
    if reg and reg.get("keywords"):
        lines.append("Descriptor words: " + ", ".join(reg["keywords"][:12]) + ".")
    states = sorted({x["story"] for x in caps if x.get("story")})
    if states:
        lines.append("States shown upstream: " + ", ".join(states[:12]) + ".")
    lines.append("Style: flat UI screenshot of an isolated component on a plain background, "
                 "crisp edges, no mockup chrome, no browser window, neutral studio background.")
    return "\n".join(lines)


written = 0
for name, caps in sorted(by_component.items()):
    reg = REG.get(name, {})
    L = [f"# {name} — visual contract", "",
         f"Captured from the upstream build ({len(caps)} reference images, theme "
         f"`{CAPS['meta']['theme']}`, modes {', '.join(CAPS['meta']['modes'])}). "
         "Use with `docs/components/%s.md` for behaviour and props." % name, ""]
    L += ["## How it looks", "", appearance(name, caps), ""]

    s = caps[0]["style"]
    L += ["## Measured style", "", "| property | value |", "| --- | --- |"]
    for k in ("display", "background", "color", "borderWidth", "borderColor",
              "borderRadius", "boxShadow", "fontFamily", "fontSize", "fontWeight", "lineHeight",
              "letterSpacing", "textTransform", "padding", "gap", "opacity"):
        L.append(f"| {k} | `{s.get(k)}` |")
    box = caps[0].get("box", {})
    L.append(f"| measured box | `{box.get('w')}x{box.get('h')} px` |")
    if caps[0].get("tag"):
        L.append(f"| root element | `{caps[0]['tag']}` |")
    L += ["", "## Accessibility attributes observed", ""]
    aria = caps[0].get("aria", {})
    L.append("- " + ", ".join(f"{k}={v}" for k, v in aria.items() if v) or "- none captured")
    L += ["", "## States captured", "", "| state | image |", "| --- | --- |"]
    for c in caps:
        L.append(f"| {c['story']} ({c['mode']}) | `{c['shot']}` |")
    L += ["", "## Reference images", ""]
    for c in caps[:8]:
        L.append(f"- `{c['shot']}` — {c['story']} ({c['mode']})")
    L += ["", "## Image-generation prompt", "", "```text", prompt(name, caps, reg), "```", ""]
    if reg.get("anatomy"):
        L += ["## Parts to render", ""]
        for a in reg["anatomy"]:
            L.append(f"- `{a['name']}` ({'required' if a.get('required') else 'optional'}) — {a.get('description','')}")
        L.append("")
    if reg.get("bestPractices"):
        L += ["## Do / don't when compositing a mockup", ""]
        for b in reg["bestPractices"]:
            label = "Do" if b.get("guidance") else "Don't"
            L.append(f"- **{label}:** {b.get('description','')}")
        L.append("")
    (OUT_DOCS / f"{name}.md").write_text("\n".join(L) + "\n")
    written += 1

print(f"components with visual contract: {written}")
print(f"tokens.json: {len(tokens['colors'])} colours, {len(tokens['radii'])} radii, "
      f"{len(tokens['fontSizes'])} font sizes, {len(tokens['shadows'])} shadows")
print(f"-> {OUT_DOCS}")
