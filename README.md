# bonsai-astryx

**An unofficial port of the [Astryx](https://github.com/facebook/astryx) design system to OCaml / [Bonsai](https://github.com/janestreet/bonsai) — shipped with a machine-readable reference corpus that lets an AI write correct UI code, mockups and image prompts against it.**

Not affiliated with or endorsed by Meta Platforms, Inc. or Jane Street Group, LLC. See [NOTICE](NOTICE).

---

## Why this exists

The React ecosystem has thousands of well-designed components. OCaml's [Bonsai](https://github.com/janestreet/bonsai) has a better execution model — incremental, type-checked, no hook rules to break — but almost no component library worth designing against.

A mechanical transpile from React to Bonsai is not possible, and it is worth saying why plainly:

- React re-renders a virtual DOM under hooks (`useState`, `useEffect`, `useRef`, `useContext`); Bonsai is an incremental computation graph with first-class state machines. There is no behaviour-preserving rewrite rule for `useEffect`.
- Styling does not travel with the code: Astryx compiles [StyleX](https://stylexjs.com) at build time; Tailwind is utility classes. Neither maps to `ppx_css`.
- Portalled, measured components (dialog, popover, command palette, combobox) are imperative DOM work — focus traps, positioning, `ResizeObserver` — that must be reimplemented against `js_of_ocaml`'s DOM.

So this project does the other thing: **understand each component, rewrite it by hand with LLM assistance, and prove each port with gates.** The type system does part of the work for us — a wrong port does not "mostly work", it fails to compile. But type-correct is not behaviour-correct, so every component must also pass a **parity test** against the real thing.

## What you get

1. **A Bonsai component library** (`src/`) — components in the Astryx design language, API-compatible where it makes sense, with documented divergences.
2. **A reference corpus** (`docs/`, `registry.json`, `tokens.ocaml.json`) generated from the upstream contract — the part that makes an AI *correct* rather than plausible:
   - `docs/INDEX.md` — one line per component, cheap to keep in context
   - `docs/components/<Name>.md` — props, defaults, anatomy, do/don't rules, accessibility contract, keywords, **plus the OCaml module and signature when a port exists**
   - `docs/PORT-STATUS.md` — what is ported, to which module, and what is not
   - `docs/visual/<Name>.md` — the appearance each ported component actually produces, with every token resolved to a literal value, plus an image-generation prompt
   - `tokens.ocaml.json` / `assets/tokens.css` — the upstream token values, generated into OCaml and CSS
3. **A mockup pipeline** (`tools/mockup/`) — a screen recipe renders three ways: static HTML using measured tokens, a text-to-image prompt, or an OCaml skeleton. Recipes are validated against the registry, so a mockup cannot name a component or prop that does not exist.
4. **A DOM verification harness** (`tools/visual/verify-dom.mjs`) — compiles the library to `js_of_ocaml`, mounts the real bundle in a real DOM (jsdom), and asserts structure, class vocabulary and ARIA behaviour. `test/` is reserved for dune-level parity once the visual capture layer runs.
5. **An agent-facing tool layer** (`tools/mcp/astryx-mcp.mjs`) — an MCP server (stdio) and CLI that answer `list / search / get / snippet / tokens / status` from the files above, so an agent can *ask* rather than guess. It returns a compile-verified call for ported components and explicitly refuses to invent one for the rest. See [docs/MCP.md](docs/MCP.md).
6. **A showcase site** (`site/`) — every ported component in every variant and state, rendered by the compiled OCaml bundle, with a coverage panel that reports what is *not* ported yet. It is also the subject of the real-browser gate, so the page people look at is the page that is tested.

## Status

Pre-alpha. This table is updated as work lands; nothing is claimed here that is not verified by a command you can run.

| area | state | evidence you can run |
| --- | --- | --- |
| Upstream contract extraction (103 components, 1,439 props) | ✅ | `node tools/extract-docs.mjs` + `python3 tools/extract-source-contracts.py` |
| Per-component reference text (`docs/components/*.md`) | ✅ 103 pages | `python3 tools/gen-references.py` |
| Port status injected into every reference page | ✅ | `python3 tools/gen-port-status.py` |
| Design tokens → OCaml + CSS (`assets/tokens.css`, 188 custom properties) | ✅ | `python3 tools/gen-ocaml-tokens.py` |
| Mockup recipes → HTML / prompt / OCaml | ✅ | `node tools/mockup/render.mjs docs/mockups/login.json --format html` |
| Component library (`src/`) | 🚧 48 of 103 ported (M1 + M2 + M5–M15 + M17–M27) | `dune build` |
| **Compile gate** | ✅ exit 0 | `dune build` |
| **DOM + accessibility gate** | ✅ 59 checks, 0 failures | `node tools/visual/verify-dom.mjs` |
| **Component test gate** (each component in isolation, incl. a real event into the Bonsai graph) | ✅ 433 checks, 0 failures | `node test/run.mjs` |
| **Real-browser gate** (Chromium over HTTP: a real click into Bonsai state, Enter on a focused button, measured icon sizes, the entry-animation rule, the menu's whole keyboard path — open, arrows, Home/End, typeahead, Escape, focus return — and a text input typed into with real keystrokes: the label focuses it, the value reaches the application, Enter submits, the tooltip placement's message is in the DOM but clipped, and a textarea typed into with real keystrokes twice — the second time after the state had round-tripped, which is the only way to catch a re-render that puts the element's earlier text back over what the user typed, and a label group whose label is a real <label for> while a *group* label is a <span> that names nothing, and the indicator's check mark measured as *painted* — a non-empty `getBBox()` on an SVG path that would have been invisible had it been built as an HTML element, which is a mistake that throws nothing anywhere, and a live checkbox clicked for real — whose `checked` and `indeterminate` *properties* have to follow the application's value back, including a click the application refuses, which React restores after every event and Vdom does not, a live switch turned on by a click, off by Space and back by clicking its *label* — a native checkbox wearing `role="switch"`, with no `aria-checked` shadowing its own checkedness — a live radio group clicked, then driven by ArrowDown/ArrowUp and left by a single Tab: three radios are one tab stop and the arrows move *and* select, which is the browser's own radio-group behaviour and the reason this component needs no keydown handler at all — a form layout whose "equal columns" and "labels to the left" are *measured* rather than read back off the class: three fields on one row at equal widths, and a label beside its control rather than above it — a tooltip hovered, focused and dismissed with Escape, where the assertion is that the message is *laid out* rather than present, that "below" really is below the trigger's own bottom edge, and that a dismissed message left the DOM entirely, and that the hover delay is real — it must NOT open straight away, it must open once the pause has passed, and a pointer that leaves before that pause must cancel rather than race — and a disabled control whose reason is present but unshown until the pointer or the focus arrives, asserted on the computed visibility because jsdom has no layout to tell hidden from zero-sized, and — the platform doing the work rather than the port — three live dialogs, one per purpose, where the assertions are behavioural rather than structural: that opening one puts it in the top layer (it matches `:modal`, which an element merely carrying the `open` attribute would not), that focus is taken into it and given back to the trigger on close, that `Escape` and a backdrop click are two *separate* permissions — info closes on both, form closes on `Escape` but not on a backdrop click, and required refuses both — and that a `<form method="dialog">` button closes one with no callback from the application) — and a button group measured as one tab stop rather than assumed to be one: exactly one member carries `tabindex="0"`, ArrowRight moves the focus *and* the stop along the orientation, a disabled member is skipped rather than focused, End lands on the last *enabled* member rather than the last member, a vertical group moves on the vertical axis, and the connected edges are read out of computed style — the outer corners keeping their 8px radius while the inner ones are `0px` and the shared edge overlapping by `-1px` — and a popover whose dismissal is the *platform's* rather than the component's: a click opens it and it matches `:popover-open`, focus enters the first control in the content and specifically *not* the generated close button, the surface measurably sits below its trigger because anchor positioning ran rather than because it is merely in the top layer, Escape and a real outside click each dismiss it *and* tell the application, focus goes back to the trigger, and the labelled close control closes it — and a timer whose reading moves *without* the application re-rendering, proven the only way it can be: the gate holds the DOM node across a second and checks it is still the same node, since a re-render would have replaced it, while asserting that elapsed past an hour rounds its machine-readable duration down to a whole minute in step with the text it displays and the clock format at the same start time does not — and a group of controls that reads as one field, where the label names the group rather than a control (it is a `<span>`, not a `<label>` with a `for` pointing nowhere) and the size reaches its children through the box's height rather than through a context, which the browser gate measures: the child is 32px inside a 32px box, the shared edge is single to within a pixel, and only the group's outer corners are round — and a toolbar that is one tab stop, whose arrows move between its members while an input inside it keeps its own arrows unless the caret has reached the edge the key moves toward, which is what lets a toolbar contain a text field, and a menu whose open state the *caller* owns, opened by a button outside it while its own trigger's `aria-expanded` follows, and a trigger configured down to an icon-only ghost button that names itself for a screen reader and paints nothing, a MoreMenu that is nothing but that configuration, a progress bar whose fill is measured against the track rather than read off a class — with its role on the *track* and its marks as focusable ticks that stay outside it — an avatar whose two image sources both fail on purpose, because falling back to the initials is the behaviour under test, a facepile whose overlap and arrow-key roving are measured rather than eyeballed, and a toggle a real click has to press — with a trigger whose marker says MoreMenu rather than Button, because a delegating component that did not name itself would be invisible to every tool here — and a metadata list whose term/value pairs are placed by its *grid* rather than by a context, so "side by side" and "stacked" are read out of geometry rather than off a class, truncated between items with a show-all toggle that is clicked for real and puts them back | ✅ 293 checks, 0 failures | `node tools/visual/verify-browser.mjs http://127.0.0.1:8791/site/index.html` |
| **Responsive + visual-regression gate** (320/375/768/1440 wide, pixel diff vs stored baseline) | ✅ 66 checks, 0 failures, 0.00% pixel drift | `node tools/visual/verify-responsive.mjs` |
| **CI on GitHub** (`.github/workflows/ci.yml`: compile, component, DOM and browser gates on a clean runner) | ✅ [run 38991532287](https://github.com/unc-asahay/bonsai-astryx/actions/runs/38991532287) — build, component, DOM and browser gates all pass on a clean runner. The row carries no counts on purpose: the gate totals live in the table above, which the local sweep keeps current, while a count written here would be stale the moment the next component landed — which is how this row went stale four times in one session. | `gh run list --repo unc-asahay/bonsai-astryx` |
| Showcase site (`site/`, all 48 ported components + DialogHeader + InputGroupText + MetadataListItem + the layer mechanism, 302 examples, 51 sections) | ✅ live | serve the repo root, open `/site/index.html` |
| Coverage panel (ported vs not, from `port.json`) | ✅ 48 / 55 / 103 | `node tools/site/gen-coverage.mjs` |
| Agent-facing tool layer (MCP server + CLI, 6 tools) | ✅ protocol paths tested | `node tools/mcp/astryx-mcp.mjs --cli status` |
| Appearance contract for components that render (`docs/visual/`, tokens resolved to literals) | ✅ 48 component pages + `INDEX.md` — including infrastructure components, since one renders whether or not it is in the coverage denominator (a delegating component appears with the one it renders: HStack and VStack under Stack) | `node tools/gen-visual-contract.mjs` |
| Agent-facing snippets (`snippets.json`, served by the MCP tool layer) | ✅ 14 entries, every one build-checked: verbatim copies are compiled in the demo/showcase, the rest are reproduced in `examples/snippetcheck/` | `dune build` |
| Generated icon table (`src/icon_data.ml` ← upstream's `defaultIcons.tsx`) | ✅ 30 glyphs, refuses a partial or renamed table | `node tools/extract-icons.mjs` |
| Upstream screenshot capture (`tools/visual/capture.mjs`) | ⏳ needs the upstream Storybook build | `node tools/visual/capture.mjs` |
| Upstream-vs-port pixel parity | ⏳ not yet | — |
| Published opam package | ⏳ not yet | — |

## Quickstart

Requires OCaml ≥ 5.2.1 with a switch that has the Jane Street preview packages (see [CONTRIBUTING.md](CONTRIBUTING.md) for the exact bootstrap, including the two upstream build traps we hit), and one `pnpm install` for the node side. The gates resolve `jsdom`, `playwright`, `pngjs` and `@js-temporal/polyfill` from **this repository's** `node_modules` and nowhere else — a sibling checkout is not a dependency, and a fresh clone needs that one command before any gate will run.

```sh
# regenerate the reference corpus from a pinned upstream checkout
node tools/extract-docs.mjs
node tools/extract-source-contracts.py
python3 tools/gen-references.py

# render a screen mockup three ways
node tools/mockup/render.mjs docs/mockups/login.json --format html    # -> mockups/out/login.html
node tools/mockup/render.mjs docs/mockups/login.json --format prompt  # -> mockups/out/login.prompt.txt
node tools/mockup/render.mjs docs/mockups/login.json --format bonsai  # -> mockups/out/login.ml

# build the library, then run the DOM + accessibility gate
dune build
node tools/visual/verify-dom.mjs

# each component's own test, in isolation (incl. a real event into the Bonsai graph)
node test/run.mjs

# regenerate the appearance contract + image prompts for the ported components
node tools/gen-visual-contract.mjs

# ask the library what it contains (same tools an agent gets over MCP)
node tools/mcp/astryx-mcp.mjs --cli search "loading button"

# look at the showcase, and test it in a real browser
node tools/site/gen-coverage.mjs
python3 -m http.server 8791 --bind 127.0.0.1     # from the repo root, leave running
#   then open http://127.0.0.1:8791/site/index.html
node tools/visual/verify-browser.mjs http://127.0.0.1:8791/site/index.html
```

Port 8791 because 8788 may already be in use on a machine running the Hermes gateway.

## Repository layout

```
src/            OCaml/Bonsai component implementations (the library)
assets/
  tokens.css         generated: upstream token values as CSS custom properties
  components.css     the port's stylesheet (variant -> token mappings)
examples/demo/  js_of_ocaml app that renders the ported components
examples/showcase/  the showcase bundle: every ported component, every variant
site/           the showcase site (shell + stylesheet + generated coverage.json)
test/           dune-level parity tests (reserved; see the DOM harness below)
docs/
  INDEX.md      generated component index (start here)
  PORT-STATUS.md generated: what is ported, to which module
  components/   generated per-component contract (props, usage, a11y, OCaml signature)
  visual/       generated appearance contract + image prompts (ported components)
  mockups/      screen recipes (JSON) + this pipeline's documentation
  verification/ transcripts from the gates that actually ran
tools/
  extract-docs.mjs            upstream *.doc.mjs -> registry.json
  extract-source-contracts.py TypeScript props -> registry.json (fills the gaps)
  gen-references.py           registry.json -> docs/components/*.md
  gen-port-status.py          port.json + .mli signatures -> port status in every page
  gen-ocaml-tokens.py         upstream tokens -> src/tokens.ml + assets/tokens.css
  visual/capture.mjs          screenshot + measure every component
  gen-visual-references.py    captures -> docs/visual/*.md
  visual/verify-dom.mjs       mount the compiled app in jsdom, assert the DOM/ARIA
  visual/verify-browser.mjs   the same, in real Chromium over HTTP, with clicks
  visual/mount.mjs            the canonical jsdom mount (Temporal/TZ traps live here)
  site/gen-coverage.mjs       port.json + registry.json -> site/coverage.json
  mockup/render.mjs           recipe -> HTML | image prompt | OCaml
  mcp/astryx-mcp.mjs          MCP server + CLI: list/search/get/snippet/tokens/status
registry.json   extracted upstream contract (source of truth for generators)
port.json       per-component port status (drives gen-port-status.py)
snippets.json   compile-verified OCaml calls, served to agents by the MCP server
tokens.ocaml.json  token values in a machine-readable form
```

## The six gates every ported component passes

1. **Compile** — `.mli` written first as the contract, implementation second. `dune build` must be exit 0. This is the gate OCaml gives you for free and the reason a port is slower but safer than a transpile: a wrong prop type is a compile error, not a runtime surprise.
2. **The component's own test** — `test/rt_test.ml` builds each component in isolation and `test/run.mjs` asserts on the resulting DOM, including a real event dispatched into the Bonsai graph (`Bonsai_web_test.Handle`) asserted to move state 0→1→2. In-process, no browser, milliseconds.
3. **DOM + ARIA** — the compiled app is mounted in jsdom and asserted (`tools/visual/verify-dom.mjs`): element structure, class vocabulary, roles, labels, and state attributes such as `aria-busy`/`aria-disabled`.
4. **A real browser** — `tools/visual/verify-browser.mjs` loads the page from a local HTTP server in Chromium, which jsdom cannot substitute for: real CSS cascade (so a computed colour can be asserted), real layout, and real events. This is the gate that clicks the ported Button and asserts Bonsai state advanced 0→1→2.
5. **Accessibility** — the upstream contract's WCAG criteria and required states become assertions, not advice (`aria-busy` during loading, focus never dropped, `aria-disabled` instead of native `disabled` where the upstream keeps a control focusable).
6. **Reference** — the component's `docs/components/<Name>.md` is regenerated from the code and the upstream contract (`tools/gen-port-status.py`), so the page an AI reads cannot disagree with the code that exists.

Pixel parity against the upstream React build is the remaining gate; it needs the Storybook capture layer, which is not available here yet. See [docs/VERIFICATION.md](docs/VERIFICATION.md) for what is verified and what is explicitly not.

## Roadmap

See [ROADMAP.md](ROADMAP.md). Short version: foundations → presentational components → input components → overlay/measured components → shadcn as a second upstream → published opam package.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). The per-component procedure is written down there precisely so that ports stay consistent — and so an AI agent can follow it too.

## About us

This started as a build project by **Anupam** with **Karina** (a Hermes Agent instance) doing the mechanical work: reading upstream source, extracting contracts, generating references, writing ports, and running the verification gates. It is published so that other people building OCaml front ends do not have to start from an empty `src/`.

If you use it, the useful thing to contribute back is a **parity test for a component you actually use in production** — that is the evidence that keeps the whole corpus honest.

## License

MIT — see [LICENSE](LICENSE). Component documentation text is derived from Astryx's MIT-licensed `.doc.mjs` files and remains the work of the Astryx authors; attribution and provenance are recorded in [NOTICE](NOTICE) and in the footer of every generated file.
