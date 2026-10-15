#!/usr/bin/env bash
# Bootstrap a dedicated OCaml switch for the Bonsai component port.
# Does NOT touch the existing `trading-ironbeam` switch.
set -euo pipefail

SWITCH=bonsai-ui
LOG=/home/noor/src/astryx-port/bootstrap.log
exec > >(tee -a "$LOG") 2>&1

echo "=== $(date -Is) bootstrap start ==="

if ! opam switch list --short | grep -qx "$SWITCH"; then
  echo "--- creating switch $SWITCH (ocaml-base-compiler.5.3.0)"
  opam switch create "$SWITCH" ocaml-base-compiler.5.3.0 -y --jobs="$(nproc)"
else
  echo "--- switch $SWITCH already exists"
fi

eval "$(opam env --switch="$SWITCH" --set-switch)"
echo "--- ocaml: $(ocamlc -version)  dune: $(dune --version 2>/dev/null || echo 'not yet')"

echo "--- adding Jane Street opam repository (rank 1: prefer their preview pins)"
opam repo add janestreet https://github.com/janestreet/opam-repository.git --rank 1 || \
  opam repo set-url janestreet https://github.com/janestreet/opam-repository.git

opam update -y

echo "--- installing bonsai stack"
opam install -y --jobs="$(nproc)" \
  bonsai_web ppx_html bonsai_web_components bonsai_web_test \
  js_of_ocaml js_of_ocaml-ppx dune

echo "=== $(date -Is) bootstrap done ==="
opam list --short --columns=name,version 2>/dev/null | grep -iE "^(bonsai|ppx_html|virtual_dom|incr_dom|js_of_ocaml|dune|core) " | head -30
