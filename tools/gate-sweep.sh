#!/usr/bin/env bash
# Full gate sweep. Re-run after any change; every transcript here is overwritten with
# what actually ran, so the docs can point at output rather than at a claim.
set -u
cd "$(dirname "$0")/.." || exit 1
eval "$(opam env --switch=bonsai-ui --set-switch)" 2>/dev/null

echo "=== 1. compile ==="
timeout 500 dune build && echo "dune build: exit 0" || { echo "dune build: FAILED"; exit 1; }

echo "=== 2. component tests (OCaml builds each component, node asserts on the DOM) ==="
{ echo "# Component test gate — transcript"
  echo "# command: node test/run.mjs  (after: dune build)"
  echo
  timeout 240 node test/run.mjs 2>&1
} > docs/verification/ocaml-tests.txt
tail -3 docs/verification/ocaml-tests.txt

echo "=== 3. DOM + accessibility (jsdom, real js_of_ocaml bundle) ==="
{ echo "# jsdom gate — transcript"
  echo "# command: node tools/visual/verify-dom.mjs"
  echo
  timeout 240 node tools/visual/verify-dom.mjs 2>&1
} > docs/verification/verify-dom.txt
tail -3 docs/verification/verify-dom.txt

echo "=== 4. real browser (Chromium over HTTP) ==="
{ echo "# Real-browser gate — transcript"
  echo "# command: node tools/visual/verify-browser.mjs <url>"
  echo "# pages served over HTTP on 127.0.0.1:8791 from the repo root"
  echo
  echo "## showcase (site/index.html)"
  timeout 280 node tools/visual/verify-browser.mjs "http://127.0.0.1:8791/site/index.html" 2>&1
  echo
  echo "## demo (examples/demo/index.html)"
  timeout 280 node tools/visual/verify-browser.mjs "http://127.0.0.1:8791/examples/demo/index.html" 2>&1
} > docs/verification/browser-verify.txt
grep -E "checks passed|CHECKS" docs/verification/browser-verify.txt

echo "=== 5. responsive + visual regression (mobile / tablet / desktop) ==="
{ echo "# Responsive gate — transcript"
  echo "# command: node tools/visual/verify-responsive.mjs"
  echo "# viewports: 375x667, 768x1024, 1440x900; screenshots + baselines beside this file"
  echo
  timeout 300 node tools/visual/verify-responsive.mjs 2>&1
} > docs/verification/responsive.txt
tail -3 docs/verification/responsive.txt

echo "=== 6. agent-facing tool layer ==="
{ echo "# MCP gate — transcript"
  echo "# command: node tools/mcp/astryx-mcp.mjs --cli status"
  echo
  timeout 120 node tools/mcp/astryx-mcp.mjs --cli status 2>&1
} > docs/verification/mcp-stdio.txt
tail -3 docs/verification/mcp-stdio.txt

echo
echo "=== transcript line counts ==="
wc -l docs/verification/ocaml-tests.txt docs/verification/verify-dom.txt \
      docs/verification/browser-verify.txt docs/verification/responsive.txt
