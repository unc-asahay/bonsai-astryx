# Demo app

A js_of_ocaml app that renders the ported components. It is the subject of the
DOM harness and the thing to open when you want to *look* at the port.

## Run it

```sh
# 1. build the bundle (from the repo root)
dune build

# 2. serve the repo root — dune's build output is what the page loads, so the
#    page must be served from the root, not from this directory
python3 -m http.server 8788

# 3. open http://127.0.0.1:8788/examples/demo/index.html
```

Opening `index.html` straight off the filesystem also works in most browsers,
since the script path is relative to this file.

## Verify it without a browser

```sh
node tools/visual/verify-dom.mjs         # assertions; non-zero exit on failure
node tools/visual/verify-dom.mjs --dump  # full structural report as JSON
```

That mounts the same compiled bundle in jsdom and reads the resulting document —
46 assertions covering the component tree, headings, button semantics, the
loading/disabled contracts, the status dot's role and label, and the variant
class vocabulary. See [`docs/VERIFICATION.md`](../../docs/VERIFICATION.md).

## What the demo exercises

Buttons (all four variants, all three sizes, loading, disabled, icon-only),
Card with elevation and padding, Stack in both directions with alignment, Text
and Heading type scales, Badge variants (semantic and coloured), Divider,
StatusDot, and Skeleton.

It deliberately goes through the public `Astryx` API only — no `Astryx.Common`
internals except the shared spacing/alignment vocabulary — so it doubles as
proof that the API is usable from outside the library.
