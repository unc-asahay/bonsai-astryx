#!/usr/bin/env bash
# Rebuild the Bonsai switch on OCaml 5.2.1.
# Why: `effect` became a reserved keyword in OCaml 5.3, and the only source of
# bonsai_web / ppx_html is Jane Street's v0.18~preview package, whose library
# sources use `effect` as a normal identifier (ui_effect/src/ui_effect.ml,
# src/global_listeners.ml). 5.2.1 predates the keyword change and satisfies the
# packages' `ocaml {>= "5.1.0"}` constraint, so the preview builds unpatched.
set -uo pipefail
SW=bonsai-ui
LOG=/home/noor/src/astryx-port/bootstrap-52.log
exec > >(tee -a "$LOG") 2>&1

echo "=== $(date -Is) bootstrap (OCaml 5.2.1) start"

opam switch remove "$SW" -y 2>/dev/null || true
opam pin remove virtual_dom -y 2>/dev/null || true

opam switch create "$SW" ocaml-base-compiler.5.2.1 -y --jobs="$(nproc)" || { echo "!! switch create failed"; exit 1; }
eval "$(opam env --switch="$SW" --set-switch)"
echo "ocaml is now: $(ocamlc -version)"

opam repo add janestreet https://github.com/janestreet/opam-repository.git --rank 1 2>/dev/null || \
  opam repo set-url janestreet https://github.com/janestreet/opam-repository.git
opam update -y

echo "--- installing bonsai stack (this is the long part)"
opam install -y --jobs="$(nproc)" \
  dune js_of_ocaml js_of_ocaml-ppx \
  bonsai_web ppx_html bonsai_web_components bonsai_web_test
rc=$?
echo "=== opam install exit: $rc  $(date -Is)"
opam list --short --columns=name,version 2>/dev/null | grep -iE "bonsai|ppx_html|virtual_dom|incr_dom|js_of_ocaml|^dune" | head -20
exit $rc
