#!/usr/bin/env bash
# bonsai_web's source uses dune's `include ./<module>__generated` shorthand, which
# is not valid OCaml — dune must expand it before the ppx sees the file. With
# dune 3.24.2 it reaches the ppx raw and dies as a syntax error. Jane Street's
# released v0.17 pins `dune < 3.24.0`, which points at a 3.24 regression. So:
# try older dunes until bonsai_web builds, then install the rest.
set -uo pipefail
SW=bonsai-ui
LOG=/home/noor/src/bonsai-astryx/retry-dune.log
exec > >(tee -a "$LOG") 2>&1

eval "$(opam env --switch="$SW" --set-switch)"
echo "=== $(date -Is) dune downgrade hunt (current: $(dune --version 2>/dev/null))"

ok=""
for v in 3.23.1 3.22.2 3.24.0; do
  echo "--- trying dune $v"
  opam install -y "dune.$v" >/dev/null 2>&1 || { echo "    could not install dune $v"; continue; }
  eval "$(opam env --switch="$SW" --set-switch)"
  echo "    dune now $(dune --version)"
  if opam install -y --jobs="$(nproc)" bonsai_web; then
    echo "    >>> bonsai_web BUILT with dune $(dune --version)"
    ok="$v"; break
  fi
  echo "    bonsai_web still failing with dune $v"
done

if [ -z "$ok" ]; then
  echo "=== $(date -Is) no working dune version found among the candidates"
  exit 31
fi

echo "--- installing the remaining web packages with dune $ok"
opam install -y --jobs="$(nproc)" ppx_html bonsai_web_components bonsai_web_test
rc=$?
echo "=== $(date -Is) exit $rc"
opam list --installed --short --columns=name,version 2>/dev/null | grep -E "^(dune|bonsai_web|bonsai_web_components|bonsai_web_test|ppx_html|ppx_css|virtual_dom|js_of_ocaml) "
exit $rc
