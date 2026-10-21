#!/usr/bin/env bash
# Full gate sweep. Re-run after any change; every transcript here is overwritten with
# what actually ran, so the docs can point at output rather than at a claim.
#
# THIS SCRIPT'S EXIT STATUS IS THE POINT OF IT. It is non-zero if ANY gate failed, not just the
# build. That was a real defect: only step 1 could fail the sweep, while steps 2..6 wrote their
# transcripts and had their statuses discarded, so a red browser or responsive gate still ended
# at "sweep exit 0" - the last thing the script did was `wc -l`, which always succeeds. The only
# thing catching those was reading the FAIL count by hand, and a harness that reports green when
# red is worse than no harness, because it makes "exit 0" mean nothing.
#
# Each gate's status is captured immediately after it runs. Step 1 is a hard stop: if the build
# fails, nothing downstream can mean anything, so the sweep ends there rather than producing six
# transcripts of consequences.
set -u
cd "$(dirname "$0")/.." || exit 1
eval "$(opam env --switch=bonsai-ui --set-switch)" 2>/dev/null

failures=()

note() { # note <status> <gate>
  if [ "$1" -eq 0 ]; then
    echo "  ok      $2"
  else
    echo "  FAILED  $2 (exit $1)"
    failures+=("$2 (exit $1)")
  fi
}

echo "=== 1. compile ==="
if timeout 500 dune build; then
  echo "dune build: exit 0"
else
  echo "dune build: FAILED"
  echo
  echo "=== sweep result ==="
  echo "SWEEP RED: the build failed, so no downstream gate was run."
  exit 1
fi

# The stylesheet the site serves is built from assets/parts/*.css. A part that
# was edited without the build being regenerated leaves the page styled by the
# old rules, and the responsive gate then fails on a layout that no longer
# exists in the source. This check is here so that cannot pass unnoticed.
echo "=== 1b. the stylesheet build is current ==="
if python3 tools/sync-css.py --check; then
  echo "stylesheet build: current"
else
  echo "stylesheet build: STALE"
  failures+=("stylesheet build is stale (run: python3 tools/sync-css.py)")
fi

echo "=== 2. component tests (OCaml builds each component, node asserts on the DOM) ==="
{
  echo "# Component test gate — transcript"
  echo "# command: node test/run.mjs  (after: dune build)"
  echo
  timeout 240 node test/run.mjs 2>&1
} > docs/verification/ocaml-tests.txt
rc_component=$?
tail -3 docs/verification/ocaml-tests.txt

echo "=== 2b. the numeric probes (the parsers and the arithmetic) ==="
{
  echo "# Numeric probes — transcripts"
  echo "# command: node _build/default/test/probe/<probe>.bc.js"
  echo
} > docs/verification/probes.txt
rc_probes=0
for probe in plain_date_probe time_input_probe; do
  echo "## $probe" >> docs/verification/probes.txt
  timeout 120 node "_build/default/test/probe/$probe.bc.js" >> docs/verification/probes.txt 2>&1
  rc=$?
  if [ "$rc" -ne 0 ]; then rc_probes=$rc; fi
done
grep -E "FAIL|all .* checks passed" docs/verification/probes.txt || true

echo "=== 3. DOM + accessibility (jsdom, real js_of_ocaml bundle) ==="
{
  echo "# jsdom gate — transcript"
  echo "# command: node tools/visual/verify-dom.mjs"
  echo
  timeout 240 node tools/visual/verify-dom.mjs 2>&1
} > docs/verification/verify-dom.txt
rc_dom=$?
tail -3 docs/verification/verify-dom.txt

echo "=== 4. real browser (Chromium over HTTP) ==="
{
  echo "# Real-browser gate — transcript"
  echo "# command: node tools/visual/verify-browser.mjs <url>"
  echo "# pages served over HTTP on 127.0.0.1:8791 from the repo root"
  echo
  echo "## showcase (site/index.html)"
} > docs/verification/browser-verify.txt
timeout 280 node tools/visual/verify-browser.mjs "http://127.0.0.1:8791/site/index.html" \
  >> docs/verification/browser-verify.txt 2>&1
rc_showcase=$?
{
  echo
  echo "## demo (examples/demo/index.html)"
} >> docs/verification/browser-verify.txt
timeout 280 node tools/visual/verify-browser.mjs "http://127.0.0.1:8791/examples/demo/index.html" \
  >> docs/verification/browser-verify.txt 2>&1
rc_demo=$?
# The two runs share one transcript, so their statuses are captured separately rather than taken
# from the last one to run - a showcase that failed while the demo passed must still be red.
grep -E "checks passed|CHECKS" docs/verification/browser-verify.txt || true

echo "=== 5. responsive + visual regression (mobile / tablet / desktop) ==="
{
  echo "# Responsive gate — transcript"
  echo "# command: node tools/visual/verify-responsive.mjs"
  echo "# viewports: 375x667, 768x1024, 1440x900; screenshots + baselines beside this file"
  echo
} > docs/verification/responsive.txt
timeout 300 node tools/visual/verify-responsive.mjs >> docs/verification/responsive.txt 2>&1
rc_responsive=$?
tail -3 docs/verification/responsive.txt

echo "=== 6. agent-facing tool layer ==="
{
  echo "# MCP gate — transcript"
  echo "# command: node tools/mcp/astryx-mcp.mjs --cli status"
  echo
} > docs/verification/mcp-stdio.txt
timeout 120 node tools/mcp/astryx-mcp.mjs --cli status >> docs/verification/mcp-stdio.txt 2>&1
rc_mcp_status=$?
{
  echo
  echo "# every ported component must reach get_snippet truthfully"
  echo "# (ported-but-unsnippeted must say so, never 'NOT ported yet')"
  echo
} >> docs/verification/mcp-stdio.txt
python3 - >> docs/verification/mcp-stdio.txt 2>&1 <<'PY'
import json, subprocess
ported = json.load(open("port.json"))["ported"]
bad, snippeted = [], []
for e in ported:
    out = subprocess.run(
        ["node", "tools/mcp/astryx-mcp.mjs", "--cli", "snippet", e["component"]],
        capture_output=True, text=True, timeout=120).stdout
    if "NOT ported yet" in out:
        bad.append(e["component"])
    elif "Astryx.Astryx." in out:
        # port.json stores the module under its public path ("Astryx.Dropdown_menu"), so a
        # bare prefix produces "Astryx.Astryx.Dropdown_menu" — a real bug this caught once.
        bad.append(e["component"] + " (module name double-prefixed)")
    elif "IS ported" in out:
        snippeted.append(f"{e['component']} (ported, no snippet — reported as such)")
print(f"ported components: {len(ported)}; truthfully reachable: {len(ported) - len(bad)}")
for line in snippeted:
    print(f"  note  {line}")
print("FAIL — reported as unported while ported: " + ", ".join(bad) if bad else
      "ok    every ported component is reported as ported")
raise SystemExit(1 if bad else 0)
PY
rc_mcp_truth=$?
{
  echo
  echo "# every ported entry must be attributed to itself: its file must exist, and its module must be"
  echo "# the one its own component name implies. This is here because an entry was once created by"
  echo "# copying its neighbour and substituting strings, which left OverflowList pointing at"
  echo "# ClickableCard's file, module and milestone - and the check above passed it, because that"
  echo "# check only asks whether a ported component is REPORTED as ported, never whether it is"
  echo "# attributed correctly. Underscores are stripped before comparing, since the umbrella names some"
  echo "# modules without them (Astryx.AspectRatio over aspect_ratio.ml)."
  echo
} >> docs/verification/mcp-stdio.txt
python3 - >> docs/verification/mcp-stdio.txt 2>&1 <<'PY'
import json, os, re
d = json.load(open("port.json"))
norm = lambda s: re.sub(r"[^a-z]", "", s.lower())
bad = []
for e in d["ported"]:
    f, mod = e.get("file", ""), e.get("module", "")
    if not os.path.exists(f):
        bad.append(f"{e['component']}: no such file {f}")
    elif norm(mod.split(".")[-1]) != norm(e["component"]) and not e.get("divergent_module"):
        # divergent_module: an explicit opt-out carrying a note — the OCaml module name is
        # addressable-different from the upstream component (List -> List_container, because
        # a top-level module named List shadows Stdlib/Core in this unwrapped library).
        # EVERY exception must be introduced with a note in port.json; the invariant stays
        # on for every other entry.
        bad.append(f"{e['component']}: module {mod} belongs to a different component")
print(f"ported entries: {len(d['ported'])}; correctly attributed: {len(d['ported']) - len(bad)}")
for b in bad:
    print(f"  FAIL {b}")
print("FAIL — misattributed entries: " + "; ".join(bad) if bad else
      "ok    every ported entry names its own file and module")
raise SystemExit(1 if bad else 0)
PY
rc_mcp_attr=$?
tail -3 docs/verification/mcp-stdio.txt

echo
echo "=== sweep result ==="
note "$rc_component" "component tests (test/run.mjs)"
note "$rc_probes" "numeric probes (plain_date, time_input)"
note "$rc_dom" "DOM + accessibility (verify-dom.mjs)"
note "$rc_showcase" "real browser, showcase (verify-browser.mjs)"
note "$rc_demo" "real browser, demo (verify-browser.mjs)"
note "$rc_responsive" "responsive + visual regression (verify-responsive.mjs)"
note "$rc_mcp_status" "MCP layer (--cli status)"
note "$rc_mcp_truth" "MCP layer (every ported component truthfully reachable)"
note "$rc_mcp_attr" "port.json (every entry names its own file and module)"

echo
echo "=== transcript line counts ==="
wc -l docs/verification/ocaml-tests.txt docs/verification/probes.txt docs/verification/verify-dom.txt \
      docs/verification/browser-verify.txt docs/verification/responsive.txt || true

echo
if [ "${#failures[@]}" -eq 0 ]; then
  echo "SWEEP GREEN: every gate passed"
  exit 0
fi
echo "SWEEP RED: ${#failures[@]} gate(s) failed"
for f in "${failures[@]}"; do
  echo "  - $f"
done
exit 1
