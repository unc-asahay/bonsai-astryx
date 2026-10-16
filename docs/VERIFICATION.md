<!-- This file records what has actually been run, with the output that proved it.
     It is the honest answer to "does it work?" — update it when a gate runs,
     and never record a gate that has not been run on this commit. -->

# Verification record

Upstream pinned at `facebook/astryx@b69b2df3f837d7b7c0627811d00eeb58d8ef5d5e` (2026-10-15, MIT).

Toolchain: OCaml 5.2.1 in the `bonsai-ui` opam switch, dune 3.23.1,
`bonsai` / `bonsai_web` / `virtual_dom` / `ppx_html` / `bonsai_web_components`
at `v0.18~preview.130.106+341` (Jane Street's opam repository),
`js_of_ocaml` 6.4.1.

## Gate 1 — compile

```
$ dune build
$ echo $?
0
```

Builds the library (`src/`), the js_of_ocaml demo app (`examples/demo/`), and
produces `_build/default/examples/demo/demo.bc.js` — **44,570,882 bytes** of
linked JavaScript.

## Gate 2 — DOM + accessibility (jsdom, real bundle)

```
$ node tools/visual/verify-dom.mjs
```

**59 checks passed, 0 failed.** Full transcript: [`verify-dom.txt`](verification/verify-dom.txt).

The harness mounts the compiled bundle in jsdom (not a mock DOM, not a
screenshot diff) and reads the live document. What it proves:

| claim | how it is checked |
| --- | --- |
| the app mounts | 7,372 characters of DOM under the bind element |
| the component tree is exactly as expected | per-component instance counts (Stack 12, Button 7, Heading 6, Text 6, Badge 5, Divider 2, Center 2, Skeleton 2, Card 1, StatusDot 1, Grid 1, Section 1, VisuallyHidden 1 = 47), and no unexpected component types |
| heading semantics | one `h1`, five `h3` |
| buttons render as buttons | 7 `<button>` elements, each `type="button"` |
| loading state is announced | `aria-busy="true"`, `aria-disabled="true"`, spinner present, visually-hidden "Loading" node present |
| a loading button keeps focus | **no** native `disabled` attribute (upstream keeps it focusable) |
| a disabled button is really disabled | native `disabled` present |
| the accessible name reads in the right order | text content is `SaveLoading`, i.e. label then state, not `LoadingSave` |
| status dot is not a decorative blob | `role="img"` + `aria-label="Healthy"` |
| variant vocabulary is emitted | `astryx-button--primary`, `--destructive`, and variant classes on every badge |
| Grid's tracks match upstream's rule | `columns={3}` renders `data-astryx-columns="repeat(3, 1fr)"`; default alignment is `stretch` on both axes |
| Section is a real region | rendered as `<section>`, variant classed (`--muted`), dividers classed on the asked-for sides |
| Center honours the logical axis | `axis=both` and `axis=horizontal` produce their respective classes |
| VisuallyHidden is hidden *and* exposed | clip-block class applied, content still present in the accessibility tree |

### Two environment facts worth writing down

Both cost real debugging time and are not obvious from any error message:

1. **Core raises `Base__Info0.Exn: unknown zone` in a bare jsdom realm**, which
   kills Bonsai's startup before it renders. Core's js_of_ocaml timezone loader
   drives `Temporal` (falling back to `globalThis.TemporalPolyfill.Temporal`), so
   *every* zone lookup fails — including `UTC`. The harness installs
   `@js-temporal/polyfill` into the realm and pins `TZ=UTC` for determinism.
   Node's own Temporal is behind `--harmony-temporal` and is not sufficient.
2. **Do not mirror jsdom's globals onto node's `globalThis`.** jsdom's
   `performance.now()` delegates to the *global* `performance`, so copying
   `window.performance` over it recurses until the stack dies.

## Gate 3 — reference corpus

```
$ python3 tools/gen-port-status.py
docs updated: 100 component page(s) touched
ported 13/103; wrote docs/PORT-STATUS.md
```

Every one of the 103 reference pages now states whether an OCaml port exists,
which module to call, and the signature lifted from the `.mli` — so the text an
AI reads is derived from the code and cannot drift from it.

## Gate 4 — the agent-facing tool layer (MCP)

```
$ pnpm ... # nothing: pure node, no dependencies beyond the repo files
$ node tools/mcp/astryx-mcp.mjs --cli status
upstream: facebook/astryx @ b69b2df3f837d7b7c0627811d00eeb58d8ef5d5e (MIT)
ported: 13 of 103
by milestone: M1=9, M2=4
```

Protocol paths exercised by piping raw JSON-RPC frames in and checking every
reply — transcript in [`mcp-stdio.txt`](verification/mcp-stdio.txt):

| what | result |
| --- | --- |
| `initialize` | returns protocol version and `capabilities.tools` |
| `notifications/initialized` | **no reply** — 6 replies for 7 frames, as the spec requires |
| `tools/list` | the six tools |
| `tools/call get_snippet {name: Grid}` | the compile-verified call |
| `tools/call list_components {filter: ported}` | `13 component(s) ported — 13 of 103` |
| unknown tool | `isError: true` with a message, not a crash |
| unknown method | JSON-RPC `-32601` |

The server cannot answer outside its files: for an unported component
`get_snippet` returns "not ported yet … anything I emit would be invented" plus
the upstream props to design against. That refusal is the point — it is what
keeps an agent honest about what exists.

## Gate 5 — appearance contract for the ported components

```
$ node tools/gen-visual-contract.mjs
wrote docs/visual/ for 13 ported component(s)
```

`docs/visual/<Name>.md` records the appearance the port *actually produces*, derived
from three real artifacts — the classes each component emits in the mounted DOM, the
declarations those classes carry in `assets/*.css`, and the token values in
`tokens.ocaml.json` — and finishes with an image-generation prompt built from those
measured numbers. Nothing is hand-written, so it cannot drift from the code.

Two details that make the output usable rather than merely present:

- every token is resolved to a literal (`var(--spacing-2)` → `0.5rem`, with the
  token named alongside), and `light-dark(a, b)` is shown as `a (light) / b (dark)`;
- where variants set the same property, **all** values are listed with the class
  each comes from — Button reports four background colours (primary, secondary,
  ghost, destructive), because a component sheet that showed only one would be
  wrong about the other three.

This is an appearance contract for *the port*. It is not a screenshot diff against
the React original — that is the next gate and it is still unrun.

## Gate 6 — the showcase site, in a real browser over HTTP

```
$ python3 -m http.server 8791 --bind 127.0.0.1     # repo root, so _build/ is reachable
$ node tools/visual/verify-browser.mjs http://127.0.0.1:8791/site/index.html
38/38 checks passed, 0 failure(s)
BROWSER CHECKS PASSED
$ node tools/visual/verify-browser.mjs http://127.0.0.1:8791/examples/demo/index.html
25/25 checks passed, 0 failure(s)
BROWSER CHECKS PASSED
```

Chromium (from the playwright cache) loads the page the way a person would: the
CSS and the 44 MB `js_of_ocaml` bundle are fetched over HTTP, parsed and executed
for real. This is the only gate that can check the things jsdom cannot:

- **the CSS cascade actually resolves** — `rgb(0, 100, 224)`, `8px` radius,
  `14px` type are read from `getComputedStyle`, not from what the stylesheet says;
- **a real click reaches the component** — the showcase's counter is a ported
  `Button` whose `on_click` increments `Bonsai.state`; the gate clicks it and reads
  the rendered text back, asserting `count: 0` → `count: 1` → `count: 2`;
- **4xx responses are caught** — this found a real bug: neither page declared a
  favicon, so the browser requested `/favicon.ico`, the static server answered 404,
  and the console logged an error. Fixed with an inline `data:` icon on both pages.

Three failures had to be *fixed as wrong assertions* rather than wrong code, and
they are worth recording because they are the kind of thing that makes a gate look
like it works:

- **`display: inline-flex` is never reported for a flex item.** `.astryx-button`
  declares `inline-flex`; the computed value is `flex`, because CSS *blockifies* an
  inline-level display when the element becomes a flex item. The port was right, the
  assertion was wrong.
- **12px, not 8px.** `--spacing-3` is `0.75rem`; 8px (`--spacing-2`) is the button's
  `gap`. The assertion had been written from a guess about which token was used.
- **A word-boundary regex cannot read concatenated `textContent`.** The coverage
  panel rendered "13ported90not yet103…"; the check now reads the stat elements.

Both pages' runs are in [`verification/browser-verify.txt`](verification/browser-verify.txt),
with screenshots at `verification/localhost-{demo,showcase}.png`.

## Not yet verified — do not read these as claims

- **Pixel parity against the React original.** `tools/visual/capture.mjs` captures
  the upstream build but has not run: it needs the Astryx Storybook build.
- **Upstream screenshots / the upstream-side visual reference** — same dependency.
  (`docs/visual/` for the *port* is generated and described in Gate 5 above; what is
  missing is the upstream side to compare it against.)
- **Anything below M2.** 13 of 103 components are ported; the other 90 have
  reference text but no implementation.
- **Keyboard and focus behaviour.** One click path is now verified in a real browser
  (the showcase counter), but `Tab`/`Enter`/`Escape`, focus order, focus trapping and
  `:focus-visible` are not asserted anywhere yet. The keyboard surface needs
  `bonsai_web_test`'s event dispatch for the dune-level tests and more Playwright
  `keydown` cases for the browser gate.
- **The showcase covers the ported components only.** The 90 unported ones appear as
  names in the coverage panel, deliberately with nothing rendered behind them.
- **The published opam package** — does not exist yet.
