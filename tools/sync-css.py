#!/usr/bin/env python3
"""Rebuild assets/components.css from the parts in assets/parts/.

The part files are the source of truth for each component's styles.
assets/components.css is the build the site serves: each part is appended
under a "/* <module> */" marker, in the order the parts were integrated.

This rewrites every part's section in place, so editing a part and
forgetting to rebuild the stylesheet is not possible to do by accident.

    python3 tools/sync-css.py           # rewrite the sections
    python3 tools/sync-css.py --check   # fail if the build is stale
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PARTS = ROOT / "assets" / "parts"
BUILD = ROOT / "assets" / "components.css"

# A part's section runs from its marker to the next part's marker.
MARKER = re.compile(r"^/\* ([a-z0-9_]+) \*/$", re.MULTILINE)


def sections(text: str) -> list[tuple[str, int, int]]:
    """The (module, start, end) of every part section in the build."""
    found = []
    matches = list(MARKER.finditer(text))
    for index, match in enumerate(matches):
        start = match.start()
        end = matches[index + 1].start() if index + 1 < len(matches) else len(text)
        found.append((match.group(1), start, end))
    return found


def main() -> int:
    check_only = "--check" in sys.argv
    text = BUILD.read_text()
    located = sections(text)

    stale = []
    # The sections are rebuilt in one pass, so no offset goes stale: each
    # piece of the build is copied over except the part sections, which are
    # replaced wholesale.
    pieces = []
    cursor = 0
    for module, start, end in located:
        part = PARTS / f"{module}.css"
        if not part.exists():
            continue
        body = part.read_text().strip()
        expected = f"/* {module} */\n{body}"
        current = text[start:end].strip()
        if current == expected:
            continue
        if check_only:
            stale.append(module)
            continue
        pieces.append(text[cursor:start])
        pieces.append(expected)
        pieces.append("\n\n")
        cursor = end
    pieces.append(text[cursor:])

    # A part that has no section in the build at all was never merged, or
    # the merge was lost. Append it, as the integration does.
    present = {module for module, _, _ in located}
    for part in sorted(PARTS.glob("*.css")):
        module = part.stem
        if module in present:
            continue
        if check_only:
            stale.append(module)
            continue
        pieces.append(f"/* {module} */\n{part.read_text().strip()}\n\n")

    if check_only:
        if stale:
            print(f"STALE: {', '.join(stale)} — run: python3 tools/sync-css.py")
            return 1
        print("the stylesheet build is current")
        return 0

    if not pieces:
        print("the stylesheet build is current")
        return 0

    BUILD.write_text("".join(pieces))
    print("assets/components.css rebuilt from the parts")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
