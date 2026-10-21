#!/usr/bin/env bash
# Assemble the tree GitHub Pages serves.
#
# The point of this script is that THE PAGE PEOPLE LOOK AT IS THE PAGE THAT
# WAS TESTED. The browser gate loads site/index.html over HTTP and asserts on
# what it renders; if the published page were a rewritten copy of that page,
# the gate would be testing one thing and the site would be serving another.
# So the published tree mirrors the repository root exactly: site/index.html
# still says "../assets/components.css" and "../_build/default/...", and
# those paths resolve the same way they do locally.
#
# The root of the published tree gets a small redirect instead of the page
# itself, so the bare domain lands on the showcase rather than a 404.
#
# Usage: bash tools/publish-tree.sh [bundle] [out]
#   bundle  the compiled showcase bundle (default: the release build)
#   out     the directory to assemble (default: _pages)
set -u
cd "$(dirname "$0")/.." || exit 1

bundle="${1:-_build_release/default/examples/showcase/showcase.bc.js}"
out="${2:-_pages}"

if [ ! -f "$bundle" ]; then
  echo "the showcase bundle is missing: $bundle" >&2
  echo "build it with: dune build --profile release examples/showcase/showcase.bc.js" >&2
  exit 1
fi

rm -rf "$out"
mkdir -p "$out"

# The tracked files, as they are in the working tree. `git archive` would give
# the committed tree instead, which is right in CI but wrong for a local
# rehearsal of an uncommitted change.
git ls-files -z | tar --null -T - -cf - | tar -xf - -C "$out" || exit 1

# The bundle, at the path site/index.html asks for.
mkdir -p "$out/_build/default/examples/showcase"
cp "$bundle" "$out/_build/default/examples/showcase/showcase.bc.js" || exit 1

# The landing redirect.
cat > "$out/index.html" <<'HTML'
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>bonsai-astryx</title>
<meta http-equiv="refresh" content="0; url=site/">
<link rel="canonical" href="site/">
</head>
<body>
<p><a href="site/">The OCaml/Bonsai port of Astryx</a></p>
</body>
</html>
HTML

# Everything the page asks for must be there. A missing file is a 404 on a
# public site and a silent hole in the corpus, so it is checked rather than
# assumed.
missing=0
for path in \
  "site/index.html" \
  "site/site.css" \
  "site/coverage.json" \
  "site/favicon.svg" \
  "assets/components.css" \
  "assets/layout.css" \
  "assets/tokens.css" \
  "docs/PORT-STATUS.md" \
  "docs/verification/verify-dom.txt" \
  "_build/default/examples/showcase/showcase.bc.js"
do
  if [ ! -f "$out/$path" ]; then
    echo "  MISSING  $path" >&2
    missing=$((missing + 1))
  fi
done
if [ "$missing" -ne 0 ]; then
  echo "the publish tree is missing $missing file(s)" >&2
  exit 1
fi

# And the page must not ask for anything the tree does not have. This is the
# check that would catch a page that grew a reference the tree does not carry.
for ref in $(grep -oE '(src|href)="\.\./[^"]*"' "$out/site/index.html" | sed -E 's/.*"\.\.\/([^"]*)"/\1/' | sort -u); do
  if [ ! -f "$out/$ref" ]; then
    echo "  the page asks for ../$ref, which is not in the tree" >&2
    missing=$((missing + 1))
  fi
done
if [ "$missing" -ne 0 ]; then
  echo "the publish tree does not satisfy the page" >&2
  exit 1
fi

echo "publish tree: $out"
echo "  bundle:     $(du -h "$out/_build/default/examples/showcase/showcase.bc.js" | cut -f1)"
echo "  files:      $(find "$out" -type f | wc -l)"
echo "  landing:    index.html -> site/"
echo "  showcase:   site/index.html"
