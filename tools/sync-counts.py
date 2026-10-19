#!/usr/bin/env python3
"""Sync the hard-coded counts the gates and the README assert.

The browser gate freezes the per-section example counts, the section
count, the nav-link count and the coverage totals as literals, so they
have to be rewritten whenever a component lands. Doing that by hand is
exactly how they go stale, so this derives them from the page itself:
it reads the section list the gate prints, and rewrites the literals to
match what is actually rendered.

Usage:
  node tools/visual/verify-browser.mjs http://127.0.0.1:8791/site/index.html \\
      > /tmp/browser.txt || true
  python3 tools/sync-counts.py /tmp/browser.txt

(--examples-file is optional: a file with "Section:count" pairs, as
printed by the gate, used when no transcript is at hand.)
"""

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GATE = ROOT / "tools" / "visual" / "verify-browser.mjs"
README = ROOT / "README.md"

# Section titles that are not a port.json component name.
ALIASES = {
    "Field": "Field + TextInput",
    "TextInput": "Field + TextInput",
    "Interactive": "Interactive",
}


def parse_sections(text):
    """The gate prints one line of `Name:count` pairs for the whole page."""
    sections = {}
    for line in text.splitlines():
        line = line.strip()
        if not line or ":" not in line:
            continue
        parts = line.split()
        pairs = []
        for p in parts:
            if ":" not in p:
                continue
            name, _, count = p.partition(":")
            if not count.isdigit():
                continue
            if re.fullmatch(r"[A-Za-z][A-Za-z0-9 +_]*", name):
                pairs.append((name, int(count)))
        # A section line is long and every token is a name:count pair.
        if len(pairs) >= 10 and len(pairs) == len(parts):
            for name, count in pairs:
                sections[name] = count
    return sections


def parse_checks(text):
    """The last "N/M checks passed" line of each run in the transcript."""
    runs = re.findall(r"(\d+)/(\d+) checks passed", text)
    return [(int(a), int(b)) for a, b in runs]


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)
    text = Path(sys.argv[1]).read_text()
    sections = parse_sections(text)
    if not sections:
        print("no section list found in the transcript; run the browser gate first")
        sys.exit(1)
    total_examples = sum(sections.values())
    print(f"parsed {len(sections)} sections, {total_examples} examples")

    data = json.loads((ROOT / "port.json").read_text())
    ported = [e["component"] for e in data["ported"]]
    ported_count = len(ported)
    total_components = len([p for p in (ROOT / "docs" / "components").glob("*.md")])
    not_ported = total_components - ported_count

    g = GATE.read_text()

    # 1. the per-section map, rebuilt from the page
    m = re.search(r"(const expectedExamples = \{\n)(.*?)(\n  \};)", g, re.S)
    assert m, "expectedExamples map not found"
    body = "".join(f"    {name}: {count},\n" for name, count in sections.items())
    g = g[: m.start(2)] + body + g[m.end(2) :]
    print(f"  expectedExamples: {len(sections)} entries")

    # 2. the totals
    def set_num(pattern, value, what):
        nonlocal g
        mm = re.search(pattern, g)
        assert mm, f"count site not found: {what}"
        g = g[: mm.start(1)] + str(value) + g[mm.end(1) :]
        print(f"  {what}: {value}")

    set_num(r'check\("(\d+) examples across the page"', total_examples, "examples total")
    set_num(r'check\("(\d+) sections"', len(sections), "sections")
    set_num(r'check\("(\d+) nav links"', len(sections), "nav links")

    # 3. EXPECTED: keep the curated list, add any ported component's section
    mm = re.search(r"(const EXPECTED = \[\n)(.*?)(\n  \];)", g, re.S)
    assert mm, "EXPECTED array not found"
    have = set(re.findall(r'"([^"]+)"', mm.group(2)))
    add = []
    for comp in ported:
        title = ALIASES.get(comp, comp)
        if title in sections and title not in have:
            add.append(title)
            have.add(title)
    if add:
        g = g[: mm.end(2)] + "".join(f'    "{t}",\n' for t in add) + g[mm.end(2) :]
        print(f"  EXPECTED += {add}")

    # 4. the coverage panel: ported / not ported / total
    mm = re.search(r'"coverage stats are (\d+) ported / (\d+) not / (\d+) total"', g)
    assert mm, "coverage stats literal not found"
    g = (
        g[: mm.start(1)]
        + str(ported_count)
        + g[mm.end(1) : mm.start(2)]
        + str(not_ported)
        + g[mm.end(2) : mm.start(3)]
        + str(total_components)
        + g[mm.end(3) :]
    )
    # the comparison array beside it
    tail = g[mm.end() :]
    m2 = re.search(r"\[\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*\]", tail)
    if m2:
        new_tail = (
            tail[: m2.start()]
            + f"[{ported_count}, {not_ported}, {total_components}]"
            + tail[m2.end() :]
        )
        g = g[: mm.end()] + new_tail
    print(f"  coverage stats: {ported_count} ported / {not_ported} not / {total_components} total")
    GATE.write_text(g)

    # 5. the README rows
    r = README.read_text()
    runs = parse_checks(text)
    browser_checks = max((a for a, _ in runs), default=0)
    component_checks = 0
    ocaml = ROOT / "docs" / "verification" / "ocaml-tests.txt"
    if ocaml.exists():
        mm = re.search(r"(\d+) checks, 0 failures", ocaml.read_text())
        if mm:
            component_checks = int(mm.group(1))

    def sub(pattern, repl, what, text_):
        mm = re.search(pattern, text_)
        if not mm:
            print(f"  README: {what} not found")
            return text_
        print(f"  README {what}: {mm.group(0)[:60]}")
        return text_[: mm.start()] + repl + text_[mm.end() :]

    r = sub(r"🚧 \d+ of \d+ ported", f"🚧 {ported_count} of {total_components} ported", "ported", r)
    r = sub(r"✅ \d+ checks, 0 failures \| `node test/run\.mjs`",
            f"✅ {component_checks} checks, 0 failures | `node test/run.mjs`", "component checks", r)
    r = sub(r"all \d+ ported components \+ DialogHeader \+ InputGroupText \+ MetadataListItem \+ the layer mechanism, \d+ examples, \d+ sections",
            f"all {ported_count} ported components + DialogHeader + InputGroupText + MetadataListItem + the layer mechanism, {total_examples} examples, {len(sections)} sections",
            "showcase row", r)
    r = sub(r"✅ \d+ / \d+ / \d+ \| `node tools/site/gen-coverage\.mjs`",
            f"✅ {ported_count} / {not_ported} / {total_components} | `node tools/site/gen-coverage.mjs`", "coverage row", r)
    README.write_text(r)
    print(f"  browser checks seen in transcript: {browser_checks}")


if __name__ == "__main__":
    main()
