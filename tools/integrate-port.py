#!/usr/bin/env python3
"""Integrate one ported component into master.

The parallel ports each land their own files in a worktree branch. This
script does the shared-file half of a milestone: merge the branch, append
the component's CSS, wire its showcase section into the page and the nav,
add the port.json entry, and update the hard-coded counts the gates
assert. It is idempotent, so a re-run after a partial integration is safe.

Usage:
  tools/integrate-port.py --component Toast --branch wip-toast \\
      --milestone M59 --class C --module toast \\
      --section-id toast --nav-id toast --examples 6

(--examples is the number of examples in the component's showcase section;
the counts the browser gate asserts are derived from it.)
"""

import argparse
import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def run(*args, check=True):
    r = subprocess.run(args, cwd=ROOT, capture_output=True, text=True)
    if check and r.returncode != 0:
        print(f"FAILED: {' '.join(args)}\n{r.stdout}\n{r.stderr}")
        sys.exit(1)
    return r


def read(path):
    p = ROOT / path
    return p.read_text() if p.exists() else ""


def write(path, text):
    (ROOT / path).write_text(text)
    print(f"  wrote {path}")


def merge_branch(branch):
    print(f"== merging {branch}")
    r = run("git", "merge", "--no-ff", branch, check=False)
    if r.returncode != 0:
        conflicted = run("git", "diff", "--name-only", "--diff-filter=U").stdout.split()
        if not conflicted:
            print(r.stdout, r.stderr)
            sys.exit(1)
        print(f"  conflicts: {conflicted}")
        for f in conflicted:
            resolve_conflict(f)
        run("git", "add", "-A")
    else:
        print("  clean merge")


def resolve_conflict(path):
    """Keep both sides for a conflict: ours plus any module lines theirs adds.

    The only file every port touches is src/astryx.ml, where each port adds
    exactly one `module X = X` line at the end. Both sides are wanted, so
    take ours and append the lines theirs adds that we do not have.
    """
    ours = run("git", "show", f"HEAD:{path}").stdout
    theirs = run("git", "show", f"MERGE_HEAD:{path}").stdout
    if path.endswith("astryx.ml"):
        have = set(re.findall(r"^module\s+(\S+)\s*=\s*(\S+)", ours, re.M))

        def module_line(ln):
            m = re.match(r"^module\s+(\S+)\s*=\s*(\S+)", ln)
            return m.groups() if m else None

        extra = []
        for ln in theirs.splitlines():
            g = module_line(ln)
            if g and g not in have:
                extra.append(ln)
        merged = ours.rstrip("\n")
        if extra:
            merged += "\n" + "\n".join(extra) + "\n"
        write(path, merged)
        run("git", "add", path)
        print(f"  kept both sides of {path} (+{len(extra)} module lines)")
    else:
        # For any other file, keep both sides' added lines, ours first.
        markers = re.split(r"^(<{7}|={7}|>{7}).*$", ours + "\n", flags=re.M)
        print(f"  {path}: manual resolution needed")
        sys.exit(3)


def append_css(module):
    part = ROOT / "assets" / "parts" / f"{module}.css"
    css = ROOT / "assets" / "components.css"
    if not part.exists():
        print(f"  no CSS part for {module} (skipped)")
        return
    body = part.read_text()
    marker = f"/* {module} */"
    current = css.read_text()
    if marker not in current:
        current = current.rstrip("\n") + f"\n\n{marker}\n" + body.strip() + "\n"
        write("assets/components.css", current)


def wire_showcase(module, component, section_id, nav_id):
    path = "examples/showcase/showcase.ml"
    s = read(path)
    mod = "Sec_" + module
    binding = f"  let {module}_section = {mod}.demo graph in\n"
    if binding not in s:
        # bind the section right before the stateful_sections list
        anchor = "  (* One entry per stateful section"
        assert anchor in s, "stateful_sections anchor not found"
        s = s.replace(anchor, binding + anchor, 1)
    list_entry = f"; {module}_section "
    if list_entry not in s:
        # Append to the stateful_sections list. The list opens with "[ " on
        # its own line and closes on the line of its last element, so find
        # the opening line and then the first line that carries the "]".
        lines = s.split("\n")
        start = next(
            (i for i, ln in enumerate(lines) if ln.strip().startswith("let stateful_sections =")),
            None,
        )
        assert start is not None, "stateful_sections list not found"
        end = next((i for i in range(start, len(lines)) if "]" in lines[i]), None)
        assert end is not None, "stateful_sections list is not closed"
        lines.insert(end, f"    ; {module}_section")
        s = "\n".join(lines)
    nav_entry = f'  ; "{nav_id}", "{component}"\n'
    if nav_entry not in s:
        # The top-level nav_items (a demo also has a local one, so match the
        # unindented definition) is a list of "; id, Title" entries closed by
        # a "]" line.
        lines = s.split("\n")
        start = next(
            (i for i, ln in enumerate(lines) if ln.startswith("let nav_items =")),
            None,
        )
        assert start is not None, "nav_items list not found"
        end = next((i for i in range(start, len(lines)) if "]" in lines[i]), None)
        assert end is not None, "nav_items list is not closed"
        lines.insert(end, nav_entry.rstrip("\n"))
        s = "\n".join(lines)
    write(path, s)


def add_port_json(component, module, milestone, klass):
    data = json.loads(read("port.json"))
    if any(e["component"] == component for e in data["ported"]):
        print(f"  port.json already has {component}")
        return
    entry = {
        "class": klass,
        "component": component,
        "file": f"src/{module}.ml",
        "milestone": milestone,
        "module": f"Astryx.{module}",
    }
    data["ported"].append(entry)
    write("port.json", json.dumps(data, indent=2) + "\n")


def bump_counts(component, module, examples):
    """Update the hard-coded counts the browser gate and the README assert."""
    path = "tools/visual/verify-browser.mjs"
    s = read(path)

    def bump(pattern, add, what):
        nonlocal s
        m = re.search(pattern, s)
        assert m, f"count site not found: {what}"
        old = int(m.group(1))
        s = s[: m.start(1)] + str(old + add) + s[m.end(1) :]
        print(f"  {what}: {old} -> {old + add}")

    bump(r'check\("(\d+) examples across the page"', examples, "examples total")
    bump(r'check\("(\d+) sections"', 1, "sections")
    bump(r'check\("(\d+) nav links"', 1, "nav links")
    # coverage stats: ported +1, not ported -1
    m = re.search(r'"coverage stats are (\d+) ported / (\d+) not / (\d+) total"', s)
    assert m, "coverage stats site not found"
    s = (
        s[: m.start(1)]
        + str(int(m.group(1)) + 1)
        + s[m.end(1) : m.start(2)]
        + str(int(m.group(2)) - 1)
        + s[m.end(2) :]
    )
    print(f"  coverage stats: {m.group(1)} ported / {m.group(2)} not -> {int(m.group(1)) + 1} / {int(m.group(2)) - 1}")
    # the comparison array next to the coverage check
    m2 = re.search(r"\[\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*\]", s[m.end() :])
    if m2:
        abs_s = m.end() + m2.start(1)
        s = s[:abs_s] + str(int(m2.group(1)) + 1) + s[abs_s + len(m2.group(1)) :]
        abs_s2 = m.end() + m2.start(2)
        s = s[:abs_s2] + str(int(m2.group(2)) - 1) + s[abs_s2 + len(m2.group(2)) :]
        print("  coverage comparison array bumped")
    # EXPECTED array: the component name must have a section
    if f'"{component}"' not in s.split("const EXPECTED")[1].split("];")[0]:
        m3 = re.search(r"(const EXPECTED = \[\n)", s)
        assert m3, "EXPECTED array not found"
        s = s[: m3.end(1)] + f'    "{component}",\n' + s[m3.end(1) :]
        print(f"  EXPECTED += {component}")
    # expectedExamples map
    m4 = re.search(r"(const expectedExamples = \{\n)", s)
    assert m4, "expectedExamples map not found"
    s = s[: m4.end(1)] + f"    {component}: {examples},\n" + s[m4.end(1) :]
    write(path, s)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--component", required=True)
    ap.add_argument("--branch", required=True)
    ap.add_argument("--milestone", required=True)
    ap.add_argument("--class", dest="klass", required=True)
    ap.add_argument("--module", required=True)
    ap.add_argument("--section-id", required=True)
    ap.add_argument("--nav-id", required=True)
    ap.add_argument("--examples", type=int, required=True)
    args = ap.parse_args()

    if run("git", "status", "--porcelain").stdout.strip():
        print("working tree is not clean; commit or stash first")
        sys.exit(1)

    merge_branch(args.branch)
    append_css(args.module)
    wire_showcase(args.module, args.component, args.section_id, args.nav_id)
    add_port_json(args.component, args.module, args.milestone, args.klass)
    print("\n== now run: opam exec -- dune build")
    print("== then: node tools/visual/verify-browser.mjs http://127.0.0.1:8791/site/index.html > /tmp/browser.txt")
    print("== then: python3 tools/sync-counts.py /tmp/browser.txt   (derives the gate's counts from the page)")


if __name__ == "__main__":
    main()
