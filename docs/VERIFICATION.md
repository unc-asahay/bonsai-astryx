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
42/42 checks passed, 0 failure(s)
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

**Cross-checked with a different tool.** The same page was driven through
`opencli`'s Browser Bridge into a real, already-running Chrome — not the headless
Chromium the gate launches — and it agreed: 14 sections, 111 examples, an empty
console, the coverage panel showing `facebook/astryx@b69b2df3f8` and `13 / 103`, and
a click on the ported Button taking the counter from `count: 0` to `count: 1`. Two
independent browser paths, same numbers. See
[`verification/opencli-verify.txt`](verification/opencli-verify.txt).

The port for the static server is **8791**: 8788 was already held by the Hermes
gateway's proxy on this machine, which answers `200` with its own JSON — a previous
attempt "verified" a page that was never being served at all.

## Gate 7 — the components' own tests, in OCaml

```
$ dune build && node test/run.mjs
67 checks, 0 failure(s)
COMPONENT CHECKS PASSED
```

`test/rt_test.ml` builds every ported component **in isolation** — not through the
demo page — and `test/run.mjs` asserts on the DOM that comes out: 67 checks over 14
components, covering variants, sizes, elevations, every `Button` state, link
rendering, each heading level, `StatusDot`'s image role, `Badge`'s 14
distinguishable variants, `Divider` orientation, `Skeleton`'s aria-hidden,
`Text`'s type/colour/weight classes, `Stack`'s optional gap, `Center`'s inline
axis, `Section`'s variants, `Grid`'s three track forms and `VisuallyHidden`'s
element choice.

The interaction check is the one that could not be done any other way: a real
event is dispatched **into the Bonsai graph** with `Bonsai_web_test.Handle.click_on`,
the view is re-stabilised with `recompute_view_until_stable`, and the component's own
rendered output is asserted to move 0 → 1 → 2. A click that silently stopped firing
would fail here in-process, in milliseconds, with no browser involved.

Transcript: [`verification/ocaml-tests.txt`](verification/ocaml-tests.txt).

## Gate 8 — responsive behaviour, with a visual regression baseline

`node tools/visual/verify-responsive.mjs` · transcript: `docs/verification/responsive.txt` ·
screenshots: `docs/verification/responsive/`, baselines in `.../baseline/`

Gates 6 and 7 both run at one viewport. This one asks whether the components survive being
looked at from a phone, a tablet and a desktop, and whether the pixels moved since last time.
It covers both pages (demo and showcase) at **320x568 (extra-small phone), 375x667, 768x1024
and 1440x900** — 66 checks.

Per viewport: the page does not overflow horizontally, no component box escapes the viewport,
no component has collapsed to zero width or height, the AspectRatio examples keep h/w = 0.5625,
and — the end-to-end part — the counter button is *hit-tested at its centre* with
`elementFromPoint` and then clicked with a real `mouse.click`, so a component that is present
but covered or off-screen fails here instead of passing on a synthetic `.click()`. The showcase
also checks that the nav does not overflow.

Across viewports: the auto-fill grid must fit more tracks as the viewport widens. The assertion
only runs when the widest viewport is at least twice the narrowest — two viewports a few pixels
apart legitimately both fit one track, and asserting reflow there would be a false failure. The
tool says "observation only" in that case rather than quietly passing.

### Result: 66 checks, 0 failures

```
320x568:  1 track in 238px     375x667:  1 track in 293px
768x1024: 3 tracks in 686px    1440x900: 4 tracks in 876px
```

At 320px — the width where layouts usually break first — nothing overflows, nothing collapses,
and the responsive grid still fills its container exactly (238px of 238px).

### Two bugs this gate found, both in the showcase's own CSS

Worth recording, because neither was visible at 1440 and both would have been read as
"the components are fine" from any other gate:

1. **Percentage-width children collapsed to zero.** The `.ex-render` wrapper is a flex row, and
   a flex row does not offer its children a width. A vertical Stack containing
   `width: 60%` skeletons therefore had no intrinsic width to give them, and all three rendered
   0px wide. The Stack is correct; the showcase simply was not a container that has a width.
2. **The auto-fill grid could not reflow.** For the same reason, `repeat(auto-fill, minmax(180px, 1fr))`
   computed to a single 180px track: the grid was being sized by its own minimum track rather than
   by the box around it. This is why the reflow check exists — a grid that reports "1 column" at
   every width is the shrink-to-fit failure, not a responsive layout.

Fix (`site/site.css`): children that size from their container — a vertical Stack, a Grid — take
the full row width inside `.ex-render`.

### The baseline, and proof the diff is not vacuous

Each viewport's screenshot is compared to its baseline with a real pixel diff (pngjs, 24/255
per-channel tolerance so antialiasing on a text edge is not a regression; a dimension change
fails outright). Contexts run with `reducedMotion: "reduce"` and screenshots with
`animations: "disabled"`: the skeleton's fade is an infinite alternate animation, so an
arbitrary capture would measure the animation phase rather than the layout — and forcing
reduced motion also exercises the `prefers-reduced-motion` rules in `assets/components.css`.

Steady state is **0.00% differ on all six page/viewport pairs**. A baseline that has never
rejected anything proves nothing, so the detector was deliberately made to fire:

| perturbation | result |
| --- | --- |
| `.showcase` padding `spacing-6` → `spacing-7` (layout shift) | FAIL — dimensions differ: `375x22284` vs `375x22277` |
| `body` background colour changed (no layout shift) | FAIL — 35.49% differ (2,965,677 / 8,356,500 pixels) |
| reverted | 0.00% differ, 50/50 checks pass |

A second note on honesty: a baseline written on a run **cannot** detect a regression on that
same run. The tool says so explicitly ("a baseline created on this run cannot yet detect a
regression") rather than printing a pass, and the baselines here were created from the fixed
layout and then re-verified on a second, independent run.

## Gate 9 — the M7 trio, and the first ported security control

NavIcon, EmptyState and Citation (22 of 103). The component-test gate is now **138 checks**,
and the gates that count things were all updated deliberately: 23 sections, 149 examples,
coverage 22 / 81 / 103, 20 appearance pages.

### Citation carries a security control, so it is tested as one

Upstream's `utils/safeUrl.ts` decides whether a URL may become an `href`, and it is ported
literally rather than approximated: control characters (`\x00-\x1f`, `\x7f`) are stripped
**before** inspection, the comparison is case-insensitive, and `javascript:`, `vbscript:` and
`data:text/html` are refused. A refused URL does not remove the citation — it renders as inert
text, which is what upstream does.

`is_safe_url` is exported from the port specifically so the control can be asserted directly,
and `test/rt_test.ml` drives a 13-case matrix **through the compiled bundle** — each row carries
what the caller expects in `data-safe` and what the port decided as its text, and `run.mjs`
compares the two. The cases are the ones a naive prefix test gets wrong:

```
https://example.com/spec      safe      javascript:alert(1)            refused
/relative/path                safe      JavaScript:alert(1)            refused
mailto:a@example.com          safe      javascript:   alert(1)          refused
data:image/png;base64,AAAA    safe      java\0script:alert(1)          refused
                                        java\nscript:alert(1)          refused
                                        "  javascript:alert(1)  "      refused
                                        vbscript:msgbox(1)             refused
                                        data:text/html,<script>…       refused
                                        JAVASCRIPT :alert(1)           safe
```

That last row is worth recording, because the first version of this test asserted `refused` and
**the port was right and the test was wrong.** A space *before* the colon means there is no valid
scheme — a space is not a scheme character — so the string is not a `javascript:` URL and browsers
resolve it as a relative path. Upstream allows it. Refusing it would have been inventing policy
the original does not have, and the code comment now says so explicitly, because it looks like a
hole and is not one.

### Two things the component tests caught in the harness, not in the components

- `inCase(name)` returns *every* marked element under a case, so a case that composes components
  (an EmptyState containing two Buttons) reported four where two were expected. Added
  `inCaseOf(name, component)` and `inCaseMatching(name, selector)`, both documented.
- A case whose rows are plain elements rather than marked components is invisible to `inCase`
  entirely — the safety matrix needed `inCaseMatching`.

### One real bug, in the showcase rather than in a component

The Citation example pointed its favicon at a remote URL, so the showcase page made an external
network request and the browser gate failed on a console error (`ERR_NAME_NOT_RESOLVED`). Fixed by
adding a local `site/favicon.svg` and pointing the example at it: a showcase must not need the
network to render its own examples.

### Baselines were re-created, deliberately

Adding three sections changed the page height, so every stored screenshot legitimately stopped
matching. Baselines were regenerated with `--update-baseline` (8 page/viewport pairs), and then
**verified on a separate run**: 66 checks, 0 failures, 0.00% differ on all eight. Re-baselining is
a deliberate act recorded here, not a gate that was silenced.

## Gate 10 — the icon set, generated rather than typed

Icon (23 of 103). Its glyph table is **generated** from upstream by
`tools/extract-icons.mjs`: 30 glyphs (29 `IconName` values plus the namespaced
`numberInput:stepperDown`), 41 SVG child elements, from `defaultIcons.tsx` and the `IconName`
union in `globalIconRegistry.tsx`. The component-test gate is now **164 checks** and the
browser gate **48**; the counters moved deliberately to 24 sections, 155 examples,
coverage 23 / 80 / 103, 21 appearance pages.

### Why generated, and what the generator refuses to do

Thirty path strings are data, and hand-typing them is how you ship a subtly wrong glyph that
nothing notices. The extractor is written to **fail rather than write a partial table**. It
refused twice during this milestone, both times correctly:

- **`menu` overrides its wrapper.** That entry is `<svg {...svgProps} strokeWidth={2}>`, so the
  icon's own prop wins over the shared spread — as it does in React. The first version of the
  parser only understood the spread and stopped with
  `no default icon for: menu`. It now applies per-icon overrides, and the test asserts that
  glyph's `stroke-width` is `2` while the others are `1.5`.
- **React's attribute naming is not "lowercase everything".** React kebab-cases a camelCase
  JSX prop for SVG (`strokeWidth` → `stroke-width`) but keeps a fixed list in camelCase, of
  which `viewBox` is the one this file uses. The first version also mangled `aria-hidden` into
  **`aria--hidden`** — a name the DOM silently ignores, which would have left all thirty icons
  exposed to screen readers while looking perfectly fine in a screenshot. That produced an
  explicit allow-list of attribute names; a name outside it fails the extraction. The check was
  then verified by removing the guard and watching it fire
  (`attribute "aria--hidden" is not in the allowed set`), not by trusting it.

### The rendering trap: `createElement` versus `createElementNS`

Inside `<svg>`, every element must be created with `Vdom.Node.create_svg`. `create` builds an
HTML element, and an HTML `<path>` is a no-op — an icon set that compiles, carries the right
attributes, and paints nothing. The tests therefore assert
`namespaceURI === "http://www.w3.org/2000/svg"` on the `<svg>` **and** on its glyph children,
in jsdom and again in a real browser.

### The size trap: a `1em` glyph in a `rem` box

The glyphs carry `width="1em" height="1em"` — upstream's own attributes. A size class that sets
width and height in rem but leaves `font-size` inherited therefore renders **every size at the
inherited size**: 12/16/24px all measure 16px, which is invisible in a screenshot and wrong.
Each size class here sets `font-size` alongside width and height, and the browser gate measures
rather than assumes: each size is asserted against its documented pixel value (12/16/20/24) and
its *glyph* is asserted to fill the box.

### What the icon port does not cover

- **The registry is static.** Upstream allows runtime registration and namespaced extension
  (`registerIcons`, `getExtendedIcon`); this port has the built-in set only. Only one namespaced
  glyph is defined upstream anyway (`numberInput:stepperDown`).
- **`IconDefaultSizeContext` is not modelled.** Upstream lets an ancestor set a default size for
  descendant icons; here the size is an argument with `md` as the default. Bonsai has no React
  context, and a tree-scoped implicit default would need `Bonsai.Scope_model` plumbing for one
  component.
- **An unknown name renders a marked empty span** (`data-astryx-icon-missing`) where upstream
  warns on the console. Assertable in tests, and documented in `src/icon.mli`.

## Gate 11 — time-aware behaviour, and the first paint that must not animate

Two components landed in M9: `FieldStatus` (attached/detached, three types) and
`Entry_animation`, the port's first piece of behaviour that depends on *when* something
happens rather than on its inputs.

**The rule.** Upstream's `useEntryAnimation` sets a module-level flag inside a
`requestAnimationFrame` and reads it once, when a component first renders. So anything
present on the first paint is rendered with no entry animation at all, and anything mounted
later animates in. Reproducing that needs a real frame boundary, which is why the port flips
the flag from a `requestAnimationFrame` at module load rather than from a timer.

**What is asserted, and where.**

| Claim | Gate |
| --- | --- |
| Nothing in a first-paint tree carries an `astryx-enter--*` class | component gate (`field-status-all`) |
| A status mounted *after* the first paint does carry it | real browser: the gate clicks **Show status** in the Interactive section and reads `#late-status` back |
| The animation is neutralised under `prefers-reduced-motion`, class and all | real browser (the gate forces `reducedMotion: "reduce"`, so `animation-name` must be `none` while the class is present) |
| An error is announced assertively, a warning/success politely | component gate (`role=alert` vs `role=status`) |
| The attached variant's overlap is cosmetic only | real browser, measured: `pointer-events: none`, a **negative** `margin-top`, a compensating `padding-top`, and rounded bottom corners |
| The detached variant is a flex row with a gap and the type's icon | component gate (icon `d` matched against `assets/icons.json`), real browser (gap) |

**Why the attached variant is measured rather than eyeballed.** Its whole contract is that
it overlaps the control above it *without* swallowing clicks meant for that control. A
screenshot cannot show `pointer-events: none`, and jsdom has no cascade, so the claim is only
checkable as a computed style in a real browser. The gate measures all four properties, and
checks the padding actually compensates for the negative margin rather than merely being
present.

**A gate bug worth recording.** The first version of the flex-row check read `gap` from the
outer `.astryx-field-status--detached` element and got `normal` — the flex row is the inner
`__content` span. The component was right; the probe was pointed at the wrong element. That
distinction is the whole reason the failure was investigated rather than "fixed" by adjusting
the component.

**Totals at this gate:** 179 component checks, 60 real-browser checks, 25/25 demo checks,
66 responsive checks at 0.00% drift across 320/375/768/1440.
## Gate 12 — the menu-button core, and two focus bugs only a real browser could show

`DropdownMenu` (phase 1) is the port's first component that is a *system* rather than a leaf:
a trigger, a surface, and rows reached by pointer, keyboard and typeahead. It is also the
first whose behaviour is mostly not a function of its props, and the first where the port's
own test harness was the thing that had to change.

**Navigation is DOM-driven, as upstream's is.** The highlight *is* DOM focus; rows are found
by querying the container; a disabled row is excluded *by the selector*. That last point is
not a detail — it means no index can ever name an unfocusable row, so the arrow keys cannot
land on one. `Menu_focus` ports `useListFocus` and `useTypeahead`, including their less
obvious rules: boundaries are scoped so an inline flyout's rows never enter the parent's
order, typeahead resets after 750 ms, repeated same-character presses cycle through the
matches instead of extending the buffer, and a search starts *after* the current row.

**Two focus bugs, which jsdom could not have found.** Bonsai's documented way to focus a newly
mounted element is `Effect.Focus.on_activate`, and that is what the port used first. It does
not do this job: it fires when a *computation* is activated, and a menu that renders its rows
on a state change keeps that computation alive from the first paint. So it fired once, while
the menu was still closed:

| Claim | Before | After |
| --- | --- | --- |
| Opening focuses the first row (the last, for ArrowUp) | ✗ focus stayed on the trigger | ✓ |
| Escape returns focus to the trigger | ✗ | ✓ |
| Choosing a row returns focus to the trigger | ✗ | ✓ |

Both directions need the same trick, for opposite reasons: opening, because the row does not
exist until the update that opens the menu has rendered; closing, because a browser hands
focus to the body the moment the focused row is removed, which undoes a focus call made first.
`Menu_focus.focus_on_next_frame` focuses one frame later, when the DOM has settled either way.
jsdom no-ops focus entirely, so the component gate passed in both worlds — these three claims
are only checkable in Chromium.

**What the component gate does assert** (jsdom): the trigger's `aria-haspopup` /
`aria-expanded` / `aria-controls`; that the element `aria-controls` names exists even while
closed; `[hidden]` as the close mechanism; rows existing only while open; every row
`role=menuitem` with `tabindex="-1"`; `aria-disabled` on the disabled row; an href row being
the anchor itself; group naming (a titled group named by its heading, an untitled one left
unnamed); the divider and the headings; the icon wrapper being decorative; end content; a
destructive row's class; and the state transitions — open on click, a selection reaching the
consumer's own state, close.

**Why the keyboard is not asserted there.** It cannot be: the harness builds a keyboard event
with an *empty* `key`, and it appends its own fields *after* any `extra_event_fields`, so a
synthetic key never reaches a handler that reads `event.key` the way upstream's does. The
honest choice was to assert the real thing where it is real. The whole keyboard path is
asserted in the browser gate: ArrowDown opens and focuses, arrows/Home/End move and wrap,
hovering focuses, ArrowDown skips the disabled row, typeahead cycles past it, Enter selects,
and Escape and selection both return focus.

**A harness gap this found.** The synthetic click provides `currentTarget` and the modifier
keys but not `button`, and wraps events in a proxy that *raises* on any field a handler reads
that it was not given — so the port's click handler could not be exercised at all until the
test supplied `button` explicitly, which it now does. The rig also swallowed everything the
bundle printed, including a caught exception's message; it now forwards its console, which is
what made the next problem visible.

**And a warning that was not the new component's fault.** The jsdom run reported
`WARNING: not combining attributes (name aria-hidden)` once per process, no matter what was
mounted. It came from the first milestone's `Icon` case, where the caller deliberately
overrides the component's own `aria-hidden` to prove a caller's attributes win. virtual_dom
sets the later attribute (the same result React's spread gives) but warns about the duplicate,
and only the *incoming* attribute can silence it — so the override site marks it with
`Attr.suppress_merge_warnings`. The dropdown itself was clean: a true positive about a
deliberate duplicate, in a case whose whole point is the duplicate.

## Gate 13 — the form-control core, and a control that names itself once

**What it covers:** `Field` and `TextInput` (M11) — the first form controls in the port, and the
two components everything else that takes input will be built on. `Field` is the wrapper: the
label, the description and the status around a control. `TextInput` is the control.

**What the component gate asserts** (25 of its 234 checks, all in jsdom): that the label is a
real `<label for>`; that the control is named *once* and never also with `aria-labelledby`;
that `aria-describedby` lists the description and the status message in that order and nothing
else; that the description is a sibling of the `<label>` rather than inside it (inside, it would
be folded into the control's name); that `aria-required` and the visible Required/Optional marker
agree, and that the marker's separator is `aria-hidden` decoration; that an error sets
`aria-invalid` and is announced assertively while a warning does not; that the three status
placements really differ — attached inside the control's wrapper, detached as a child of the
field with no wrapper, tooltip with **no message box at all**; that a hidden label is hidden from
sight and not from assistive technology; that a disabled field carries the attribute and the
class while a read-only one carries only `readonly`; and that typing into the control through
`Bonsai_web_test.Handle` reaches the application's state — a controlled input, checked as one.

**What the browser gate adds** (11 of its 94 checks, in Chromium): that the browser's own
`element.labels` collection resolves — the association is real, not just an attribute — and that
clicking the label focuses the control, which is native activation jsdom does not implement;
that real keystrokes typed into the field reach both the control and the application's state;
that focusing the field changes how it is drawn; that the start icon renders inside the control;
that the tooltip placement's announcement is in the DOM and clipped, not dropped; and that a real
`Enter` key press reaches the application while typing alone does not.

**One real defect, caught by the assertion rather than by reading.** In the tooltip placement the
message is announced by an element the control points at with `aria-describedby` — and that
element had no `id`. The markup looked correct: the region rendered, the text was in it, and the
attribute held the right value; it pointed at an id that did not exist. The jsdom check looks the
id up instead of reading the attribute, and failed.

**Two build-level traps, both about naming.** `Field` is a module name Core already uses
(first-class fields), and after `open! Core` the unqualified name referred to Core's — so a
module in this library named `Field` silently fails to compile against itself. The shared types
moved to their faithful homes instead of being re-exported across that boundary: the placement
type to `Field_status` (upstream defines `FieldStatusVariant` there), the width to
`Common.Size_value` (upstream shares `SizeValue`), and the one remaining reference is bound before
the opens with a comment saying why. Separately, taking a callback as a *plain function* forces
the caller to wrap the whole view in a `Bonsai.map` over its state setter — and since the view
already returns a `Bonsai.t`, that produces a tree **of a tree** (`Node.t Bonsai.t Bonsai.t`),
which then has to be unwrapped before anything can render it. Both `on_change` and `on_enter` are
values in the graph for that reason, which is also what `DropdownMenu`'s `on_select` already did.

**Also changed for this milestone:** `Icon` gained an `inherit` colour, because upstream's label
icon takes the label's colour rather than imposing one of the palette's; and `Field_status`
gained the three-case placement type, so `Field` and `TextInput` cannot drift into two slightly
different pairs of the same thing.

**Deferred, with the reason recorded:** the loading spinner, the `disabledMessage` tooltip,
`InputGroup` membership, the async `changeAction` (which exists upstream to keep a slow action
from fighting the browser's echo of a keystroke — a Bonsai state setter has no such race),
`FormLayout`'s default-optionality context, and horizontal-labels mode.

## Gate 14 — the second control, and the types the family shares

**What it covers:** `TextArea` (M12, phase 1) and the refactor that came first: `Input_types`, the
one definition of the size, the status type and the status record that every field-composed input
uses.

**Why the types came first:** upstream keeps them in `Field/types.ts`, and TextInput had a private
copy of all three. The shared definition differed from the copy in a way that mattered: upstream's
`InputStatus.message` is *optional*, so a status may carry no message at all — the control takes the
colour, no box is rendered, nothing is announced. The port had required a message, which is the kind
of API that makes callers invent a sentence to satisfy a type.

**What the component gate asserts** (18 of its 252 checks): the control is a `<textarea>` and no
`<input>` is involved; `rows` defaults to 3 and comes from the prop when given; **the value is the
element's text and there is no `value` attribute** (browsers ignore that attribute on a textarea);
spell check on by default, off when asked; disabled and read-only are different things; a status
with no message colours the wrapper, renders no message box and is not referenced in
`aria-describedby`; a status with a message sets `aria-invalid` and points at it on this control too;
and typing reaches the application **with a newline in the value**, because Enter is a character in a
textarea rather than a submit.

**What the browser gate adds** (12 of its 104): the element really is a textarea with
`element.labels` resolving in a real engine, clicking the label focuses it, `rows` is the height the
browser gives it, `getComputedStyle().resize` is `vertical` (upstream's own default), real keystrokes
replace the initial value and reach the application, a second round of typing after the state has
round-tripped lands where the first one left off, and Enter inserts a newline instead of submitting.

**What the gate caught on its first run.** Five failures, and four of them were the gate's frozen
description of the page — 27 sections, 172 examples, 27 nav links, and a per-section example count
with no entry for the new section. A gate that states what the page *is* notices when the page
changes; that is the whole value of freezing it. The fifth was mine: the assertion had fixed where
the caret would be after a label click, which is the engine's business rather than the component's.
The value the run reported showed the component was right — the typed text was there and the initial
text had not come back — so the check now selects all first and compares exact strings, plus a
second check that the value the user replaced does not reappear.

**Deferred, with reasons:** upstream's TextArea also has a loading spinner, a clear button and
auto-focus. Each is real work, none is needed by the base control, and half of one would be worse
than none.

## Gate 15 — the label group, promoted to a component

**What it covers:** `FieldLabel`, the label + description group, and `Field` refactored to render
through it.

**Why it is its own module.** Upstream keeps `Field/FieldLabel.tsx` separate because more than one
control composes it: `Field` wraps a whole control, but `CheckboxInput` and `Switch` want the label
*beside* their control rather than above it. The port had the same code inside `Field` as a private
function — a component living in the wrong place, which the controls that need it next would have had
to reach into `Field` for.

**How it was verified.** By the checks that already existed, before any new one was written: the
extraction changed no markup, so the 252 component checks, the DOM gate and the 104 browser checks
had to still pass unchanged — and they did, on the same run. That is what makes a pure extraction
safe to attempt at all. The component is then verified by its own 12 component checks and 3 browser
checks.

**What the new checks assert** (12 component, 3 real-browser): the label is a real `<label for>`
naming its control; the label and the description share one group, and the description is a
*sibling* of the label, never inside it (nested, it would fold into the control's accessible name and
then be announced twice); Required is said exactly once, and Optional instead of it; the marker's
separator is `aria-hidden`; a label icon renders inside the label; a hidden label is *clipped*, not
removed, and still carries `for`; a disabled label says so. The group-label path gets the most
attention because nothing had exercised it before: the group label is a `<span>` with no `for`, a
`role="group"` names itself from it with `aria-labelledby`, the controls inside do **not** take it as
their label (`element.labels.length === 0` in a real engine), and no `<label>` points at its id.

**One honest gap in the coverage numbers.** `FieldLabel` is not one of the extracted 103: upstream's
`Field/index.ts` exports it as part of Field, and the same extraction that gives `FieldStatus` its
own reference page merges `HStack` and `VStack` into `Stack`. It is therefore recorded in `port.json`
under `infrastructure`, not `ported` — the coverage generator treats a ported component that is not
in the extracted list as an inconsistency, and it would be right to. It has no appearance page for
the same reason: the appearance contract is built from elements marked `data-component`, and the
label group is not a component-level visual.

**Deferred, with reasons:** upstream's `labelTooltip` (an info icon at the end of the label, which
needs the Tooltip component), the clickable description that forwards a click to the control through
upstream's `useInputContainer`, and the form-level `defaultOptionality` context that decides whether
a marker shows at all — that one arrives with `FormLayout`, and until a context exists a marker means
what it says.

**Totals at this gate:** 264 component checks, 107 real-browser checks, 25/25 demo checks,
66 responsive checks at 0.00% drift across 320/375/768/1440, 25 appearance pages.


## Gate 16 — the indicator subsystem (M12, phase 2b)

**What it covers.** `Indicator` — the selection visuals themselves, ported as one module with three
kinds, because upstream's three (`CheckIndicator`, `CheckboxIndicator`, `RadioIndicator`) are one
primitive with a kind. That is the same judgment the port already made for `HStack`/`VStack` →
`Stack`. Upstream also resolves them through a registry so a theme can swap one out; the port has no
theme system yet, so this module is the registry's default entry and a theme seam would sit in front
of it. A deferral with a place to land, not a silent simplification.

**Why it came before the controls.** `CheckboxInput` and `Switch` do not draw their own boxes — they
compose this. Porting the controls first would have meant inventing, in two places, a visual that
upstream keeps in one place for three consumers, and then rewriting both.

**What the checks assert, and the one that is not obvious.** 15 component checks and 6 in a real
engine. The marked one: a check mark is an SVG *path*, and an HTML element inside `<svg>` is a no-op
— it compiles, renders, and paints nothing, with no error anywhere. (`Icon` carries the same warning
for the same reason.) So the assertion is not that the node exists but that the engine **painted**
it: `path.getBBox()` non-empty, plus the SVG namespace, plus the exact path data `M8.5 2.5L4 7.5L1.5
5`, so a lookalike fails too.

**The two absences matter as much as the presences.** An unchecked **bare check mark renders nothing
at all** — no empty box, because a bare mark has no box to be empty — asserted in both gates (the
component gate checks the node has no children; the real engine checks that no
`[data-astryx-kind="check"][data-astryx-state="unchecked"]` element is on the page, while the checked
and disabled-checked ones are). And an **indeterminate checkbox draws a bar, not a tick**: that third
state is the entire reason the state type has three cases.

**The first run of this gate failed, on a real defect of mine** — and not on a frozen count, which
every previous failure in this project had been. Passing `aria-hidden` and `data-astryx-component`
into an `Icon` that already sets both produced Vdom's "not combining attributes" warning: two values,
one of them silently winning. Every assertion was green; the console-error check caught it. Fixed by
letting the icon say what is the icon's, and by keeping only the bare mark's own
`data-astryx-kind`/`data-astryx-state`.

**Coverage.** `Indicator` is one of the 103 (unlike `FieldLabel`, which is not): **29 / 74 / 103**,
with an appearance page generated from what it actually renders — 14 instances, which is exactly the
14 box marks on the page. The bare marks carry the port's `Icon` and no box, so the page counts what
it counts rather than what a list would claim.

**Totals at this gate:** 279 component checks, 113 real-browser checks, 25/25 demo checks,
66 responsive checks at 0.00% drift across 320/375/768/1440, 26 appearance pages.

**Deferred, deliberately:** the theme-override seam (there is no theme system to override from);
`CheckIndicator`'s children slot for a custom mark in place of the glyph — the port renders the
glyph, and the slot arrives with its first consumer; and the focus-ring / press-feedback hooks,
which belong to the control that composes the indicator rather than to the indicator.


## Gate 17 — CheckboxInput (M12, phase 2c)

**What it covers.** `CheckboxInput` — the first control whose label is a *row partner* rather than a
heading above it, which is why upstream composes it out of `FieldLabel` + `FieldStatus` instead of
`Field`. It is also the first control with a third state that is not a value: `Indeterminate`.

**Three things that are invisible until they are wrong.**

- **`checked` and `indeterminate` are DOM properties.** Neither works as an attribute — `checked`
  only seeds the initial state, and there is no `indeterminate` attribute at all — so a box built
  that way looks right on the first paint and never changes again. The gates assert the *properties*
  (`el.checked`, `el.indeterminate`) and also that the `checked` attribute is absent, so a passing
  implementation cannot be the accidental kind.
- **No `aria-checked="mixed"`, deliberately.** The native property is the authoritative mixed state
  and a second source of truth can disagree with it; upstream dropped the ARIA state for that reason.
  Both harnesses assert the attribute's **absence**, because adding it back would be a regression
  that looks like kindness.
- **A refused click has to be *canceled*, not merely ignored.** React restores a controlled input's
  DOM value after every event; Vdom re-applies a property only when its value *changes*. A click the
  application refuses — read-only, or a validator saying no — therefore left the browser's own toggle
  sitting in the DOM with nothing scheduled to undo it: the read-only example visibly flipped while
  the application still said unchecked. **The first browser run of this gate caught exactly that**,
  in a real engine and only there, because jsdom never clicks. The fix is `preventDefault` on the
  refused click: a checkbox's checkedness is set *before* the event is dispatched and reverted when
  the event is canceled, so the revert is native and immediate.

**What the live examples prove.** A real click round-trips — the box's property follows the
application's value — Space on a focused box toggles it (the port relies on "Space *is* a click"
rather than on a keydown handler), clicking the *label* toggles it (the `<label for>` wiring end to
end), and a parent whose three children disagree is indeterminate, which is the only producer of that
state: its value is derived from the children, so turning the last child on clears the mixed state,
turning it back off restores it, the readout cannot drift from the boxes, and clicking the parent
checks all three the way a browser does with a half-selected parent.

**Coverage.** **30 / 73 / 103**, with an appearance page generated from the 16 boxes the section
renders.

**Totals at this gate:** 300 component checks, 128 real-browser checks, 25/25 demo checks,
66 responsive checks at 0.00% drift across 320/375/768/1440, 27 appearance pages.

**Deferred, deliberately:** `isBusy` and its spinner (there is no `Spinner` in the port yet),
`changeAction` (a React form action), and the `disabledMessage` tooltip — the one upstream path where
a disabled control stays focusable so that its reason can be reached.


## Gate 18 — Switch (M12, phase 2d)

**What it covers.** `Switch` — the last control in M12, and the one that looks most like a repaint of
another and is least like one. It composes `FieldLabel` + `FieldStatus` like `CheckboxInput`, but its
control is a **native checkbox carrying `role="switch"`**: that is the pattern which makes a screen
reader announce "switch, on" rather than "checkbox, checked", and it is why the keyboard, the
click-to-toggle and the focus order all come for free rather than being reimplemented. The track is
`aria-hidden` paint over the input, with a thumb that grows when it is on (14→16px at sm, 16→20px at
md, on a 32×20 or 40×24 track).

**What it deliberately does not have.** No `aria-checked` — the input's own checkedness is the state,
and a second declaration can disagree with it, the same judgment that keeps `aria-checked="mixed"` off
the checkbox. No third value: a switch is on or off, and everything a third state would say is said
better by a checkbox. No read-only — upstream gives a switch no such prop, so neither does the port,
rather than inventing one for symmetry.

**One thing it needs that the checkbox needed, and one it does not.** It does *not* need the canceled
click: a disabled switch is natively disabled, so the browser refuses the click and there is nothing to
undo — which is exactly why `CheckboxInput` needed it, since a read-only input still fires clicks. It
*will* need it, and has the seam commented where it goes, when upstream's focusable-disabled path
(arrived at through the `disabledMessage` tooltip, which keeps a disabled control reachable so its
reason can be read) is ported.

**What the live examples prove.** A real click turns it on and the track and thumb repaint to match;
the derived readout agrees; a second click turns it off; Space toggles it (because the input is a
native checkbox, not because a keydown handler was written); clicking the *label* toggles it; and a
disabled switch does not move.

**Coverage.** **31 / 72 / 103**, with an appearance page.

**Totals at this gate:** 316 component checks, 138 real-browser checks, 25/25 demo checks,
66 responsive checks at 0.00% drift across 320/375/768/1440, 28 appearance pages.

**Deferred, deliberately:** `isBusy` and the spinner it puts in the thumb (no `Spinner` yet),
`changeAction` (a React form action), and the `disabledMessage` tooltip.

**This closes M12.** The basic controls are ported — `TextInput`, `TextArea`, `CheckboxInput`,
`Switch` — over the layer they share: `Field`, `FieldLabel`, `FieldStatus`, `Input_types` and
`Indicator`.

## Not yet verified — do not read these as claims

- **Pixel parity against the React original.** `tools/visual/capture.mjs` captures
  the upstream build but has not run: it needs the Astryx Storybook build.
- **Upstream screenshots / the upstream-side visual reference** — same dependency.
  (`docs/visual/` for the *port* is generated and described in Gate 5 above; what is
  missing is the upstream side to compare it against.)
- **Anything below M12.** 31 of 103 components are ported; the other 72 have
  reference text but no implementation.
- **Keyboard and focus behaviour — mostly verified, for what is ported.** Asserted: `Enter` on
  a focused ported button activates it in a real browser (Gate 8 runs it at all three viewports;
  Gate 6 runs it at desktop); every interactive port is a native `<button>` element with no
  `tabindex="-1"`, so Tab reaches it; and since M10 the whole menu path — ArrowDown/ArrowUp open
  and move focus in, arrows/Home/End move with wrap, typeahead cycles, both the arrow keys and
  typeahead skip the disabled row, Enter selects, Escape closes, and Escape, a selection and the
  trigger all hand focus back (Gate 12); and since M11, `Enter` in a text field reaches the
  application while typing alone does not, and clicking a field's label focuses its control
  (Gate 13). What is still **not** asserted: Tab-*order* traversal
  between controls, focus *trapping* (nothing ported traps focus yet — a menu does not, a dialog
  would), `Space` on a menu row, and the `:focus-visible` pseudo-class specifically (what Gate 13
  measures is that focusing a field changes how it is drawn, not which selector did it).
  `test/rt_test.ml` can dispatch `keydown`, `focus` and `blur` through `Bonsai_web_test.Handle`,
  but a synthetic key event there carries no `key`, which is why keyboard claims live in the
  real-browser gate instead.
- **The showcase covers the ported components only.** The 75 unported ones appear as
  names in the coverage panel, deliberately with nothing rendered behind them.
- **The published opam package** — does not exist yet.

## Gate 19 — RadioList (M13, phase 1), and a bug the gate found in its own tooling

RadioList is the first consumer of `Indicator`'s **radio** kind, which had been ported and unrendered
since M12 — the same position `Indicator` itself was in before CheckboxInput. Three things are worth
recording.

**The keyboard is not this component's code, and the gate presses it rather than assuming that.** A
native radio group already implements roving focus: radios sharing a `name` are one tab stop, the
arrows move between them *and* select, and the browser restores the last selection when focus
returns. The port sets `name` and stops. So the real-engine gate clicks a radio, clicks a *label*,
presses ArrowDown and ArrowUp and reads the application's own readout back, then presses Tab and
asserts focus left the group in one press — "three radios, one stop", measured.

**The group is a form field, so it composes `Field`, not `FieldLabel`** — the first real consumer of
the group-label path M12 built: the label is a `<span>` the group names itself from with
`aria-labelledby`, because a `<label for>` names one control and a group is not one. `Field` renders
the description and status *outside* the group element, so the group links them itself
(`id ^ "-desc"`, `id ^ "-status"`) or a screen reader reading the radiogroup would never reach
either. That link is asserted.

**One deliberate difference from upstream**, written in the interface rather than glossed: upstream's
item label is a plain `<span>` plus `aria-labelledby`, because a real `<label for>` would double-fire
under its event delegation. The port has no delegation, so its labels are real `<label for>`s — which
name the radio the same way *and* are clickable. The gate clicks the label and asserts the choice
followed.

### The bug: the appearance contract was blind to 82 of the stylesheet's 312 selectors

`docs/visual/RadioList.md` was generated and reported **0 declarations, 0 tokens** while every check
passed. The generator's CSS reader matched selectors with `/^\.[a-z0-9-]+$/i` — no underscore — so
any class containing `__` was invisible to it. RadioList's root class is `.astryx-radio-list__group`,
so its contract came out hollow; the same blindness had been silently thinning **CheckboxInput** and
**Switch** (`1 class, 3 declarations`) since M12. One character in the character class fixed it:
RadioList went to 8 declarations and 2 tokens, and 82 selectors came into view for every future
component.

Worth stating plainly: the generator had been reporting success the whole time. It wrote a page, the
page had the right name, and the numbers inside it were zero.

### A second gap, also found here

The gate's frozen list of expected sections had never been extended for the last four sections:
`Indicator`, `CheckboxInput` and `Switch` were all rendering without being named in it, so any of
them could have vanished from the page without a single check noticing. `RadioList` was added to the
list at the same time.

### Totals after this gate

| Gate | Result |
| --- | --- |
| Component checks (`node test/run.mjs`) | **332 / 0** |
| Real-browser checks (Chromium, live showcase) | **146 / 0** |
| Demo fixture (jsdom) | 25 / 25 |
| Responsive visual regression (320 / 375 / 768 / 1440) | 66 / 0 at 0.00% |
| Coverage | **32 of 103** ported, 71 not |
| Showcase | 33 sections, 227 examples |

## Gate 20 — FormLayout (M13, phase 2), and the rule that is easier to state than to keep

`FormLayout` owns the one rule that changes how controls already ported *render*: only the exception
is marked. Upstream supplies that rule through React context; the port takes it as `?optionality` on
each field, and the reason is concrete rather than a preference — a context has to be active while
the child tree is *built*, and here a child is a `Vdom.Node.t Bonsai.t` that the caller has already
built before the container is applied. `Bonsai.Dynamic_scope` is the right shape and the wrong
moment, and an argument that looked load-bearing while reaching nothing would have been the worst
outcome. So it is absent from the container and present on the fields.

**The rule, ported exactly:**

| `optionality` | `is`Required`` | `is`Optional`` |
| --- | --- | --- |
| `Optional` | shows "Required" | matches the default — shows nothing |
| `Required` | matches the default — shows nothing | shows "Optional" |
| unset | shows "Required" | shows "Optional" |

**And the half that is easy to lose.** Upstream's `useResolvedRequired` is
`!isOptional && (isRequired || defaultOptionality === 'required')`, and a layout default sets
`aria-required` **but never the native `required` attribute** — deliberately, so that choosing a form
default cannot switch on the browser's own validation. The port resolves it the same way in
`Text_input`, `Text_area` and `Radio_list`, and the component gate asserts both halves: under
`Required` the unmarked field carries `aria-required="true"` and *no* native `required`.

**An expectation corrected rather than a component changed.** A check asserting that an explicitly
required text field still carries the native `required` attribute failed. Upstream's `TextInput`
sets `aria-required` and nothing else — there is no native attribute on it anywhere — so the check
was asserting behaviour the original does not have. It now asserts the true rule (a text field is
never natively required, by either route), and the checkbox and radio inputs, which *do* carry it,
assert theirs separately.

### Totals after this gate

| Gate | Result |
| --- | --- |
| Component checks (`node test/run.mjs`) | **344 / 0** |
| Real-browser checks (Chromium, live showcase) | **148 / 0** |
| Demo fixture (jsdom) | 25 / 25 |
| Responsive visual regression (320 / 375 / 768 / 1440) | 66 / 0 at 0.00% |
| Coverage | **33 of 103** ported, 70 not |
| Showcase | 34 sections, 234 examples |
| Appearance pages | 30 |

## Gate 21 — Tooltip (M13, phase 3), the overlay pillar's first build

The pillar's first piece rather than its foundation, and the reasoning is in the roadmap:
`DropdownMenu` had already established the port's overlay convention — an explicit positioned element
rather than a top-layer portal — and it is the only overlay here that works. `Tooltip` follows it,
which means the true portal (stacking contexts, `ResizeObserver` repositioning, a focus trap,
`layerViewportInset`/`modalOutlet`/depth context) stays a named open item instead of a hidden
difference.

**Two divergences, both in `tooltip.mli` rather than discovered later:**

1. The message is positioned **in place**, so an ancestor with `overflow: hidden` clips it and no
   stacking context is escaped. Upstream positions through its `Layer`.
2. ~~**The hover delay is not ported.**~~ **Wrong, and retired in Gate 23.** This item claimed that
   opening after a pause needs a timer whose callback can reach the component's state setter and that
   this release offers no such primitive. It does: `Vdom.Attr.create_hook` builds a vdom hook and a
   hook's input can carry a `unit Effect.t` that `Effect.Expert` runs. The delay is ported and the
   gate presses it. The sentence above is kept rather than deleted because it is what was believed at
   the time and *why* — the reasoning was sound and the premise was unverified, which is the more
   useful thing to record.

**What the gates press rather than read.** The component gate asserts the two lifecycle halves: a
closed tooltip renders **no message element at all** (upstream does not mount its layer either, so the
message is absent rather than invisible) and its anchor describes nothing, while an open one carries
`role="tooltip"`, its text, and an `aria-describedby` on the anchor pointing at it — the attribute
appears for exactly as long as the message does, which is upstream's set-and-restore behaviour. The
real-browser gate hovers a trigger and asserts the message *is laid out* (`width > 0`, not merely
present in the DOM), measures that "below" really puts it below the trigger's bottom edge, then moves
the pointer away and asserts the element left the DOM; focus opens it, and Escape closes it.

**A claim of mine corrected in the same commit.** The roadmap said `FieldStatus`'s third variant
"deliberately renders nothing". It does not: `field.ml` renders a visually-hidden live region
(`announcement_node`) carrying the message, so the message already reaches assistive technology today
and what is missing is only the *visible* bubble. The roadmap now says that, because the difference
between "a substitute" and "nothing" is the difference between a documented divergence and a false one.

### Totals after this gate

| Gate | Result |
| --- | --- |
| Component checks (`node test/run.mjs`) | **352 / 0** |
| Real-browser checks (Chromium, live showcase) | **155 / 0** |
| Demo fixture (jsdom) | 25 / 25 |
| Responsive visual regression (320 / 375 / 768 / 1440) | 66 / 0 at 0.00% |
| Coverage | **34 of 103** ported, 69 not |
| Showcase | 35 sections, 240 examples |
| Appearance pages | 31 |

## Gate 22 — `disabledMessage` (M13, phase 4), the deferral Tooltip unblocked

A disabled control that cannot say why it is disabled is a dead end, and the native attribute is what
makes it one: `disabled` refuses focus as well as input, so a control nobody can reach can never
explain itself. Upstream's `disabledMessage` gives the attribute up for `aria-disabled` plus
`form=""` — the second half matters, because `aria-disabled` does not stop submission on its own and
`form=""` is what detaches the control from any form it sits in — and it adds the reason to the
control's `aria-describedby`.

**The one judgement worth recording: this is not a Tooltip.** Upstream renders the reason through its
tooltip machinery, and the port's first instinct was to compose the `Tooltip` component. It would have
been wrong twice over. Upstream pushes the message id into the control's `describedByParts`
*unconditionally while the control is disabled* — the description is present whether or not anyone is
hovering, because a description that only exists on hover is one a screen reader never reads — and
while `Tooltip` owns its open state and therefore needs a graph, the *visual* half here is one CSS
rule: the bubble is in the DOM for as long as the control is disabled and visibility is the only thing
`:hover` and `:focus-within` change. So `Checkbox_input` and `Switch` keep their stateless signatures,
and the behaviour is asserted rather than approximated: jsdom checks the attribute set and the merge
into `aria-describedby` (including that the control's ordinary description survives it), and the
browser checks the halves jsdom cannot see — present and hidden at rest, shown and *laid out* on
hover, shown on focus, hidden again when the pointer leaves.

**A real bug this change would have introduced, caught by reasoning about it before the tests.**
`Switch` carried a comment saying its click guard was "belt-and-braces today, because a disabled input
never fires a click", and naming itself as the seam where the `disabledMessage` path would need to
*cancel* the event rather than ignore it. That is exactly what happened: focusable-disabled controls
do fire clicks, so the guard became load-bearing and now calls `prevent_default` — without it the
browser would have flipped the switch before the handler ran, and the state would have lied.

Two more shared helpers moved to `Common` on the way (`prevent_default` here, and `prop`/`string_prop`/
`bool_prop` with Tooltip): the first component to need a DOM helper is not a reason for the second
copy, which is how two components drift.

**Re-baselined, deliberately.** The two gates before this one added the Tooltip section and two
disabled-reason examples to the page, and the coverage panel's text is part of every screenshot,
so the responsive baseline was regenerated on those commits and then verified on a separate run
(66 / 0 at 0.00%). It is recorded here rather than done quietly: a baseline created on a run
cannot detect a regression on that same run.

### Totals after this gate

| Gate | Result |
| --- | --- |
| Component checks (`node test/run.mjs`) | **362 / 0** |
| Real-browser checks (Chromium, live showcase) | **160 / 0** |
| Demo fixture (jsdom) | 25 / 25 |
| Responsive visual regression (320 / 375 / 768 / 1440) | 66 / 0 at 0.00% |
| Coverage | **34 of 103** ported, 69 not |
| Showcase | 35 sections, 242 examples |
| Appearance pages | 31 |

## Gate 23 — the hook (`8c4309c`), and a divergence that was never real

This gate exists because Gate 21 recorded something as impossible and the record was wrong.

Gate 21's second divergence read: *"the 200 ms hover delay is not ported. Opening after a pause needs a
timer whose callback can reach the component's state setter, and this release exposes no primitive for
that."* The reasoning is sound — it just rests on a premise nobody checked. **`Vdom.Attr.create_hook`
exists**, `Vdom.Attr.Hooks.Make` is its functor, and a hook's input may carry a `unit Effect.t` that
`Effect.Expert.handle_non_dom_event_exn` runs. `virtual_dom`'s own `Always_focus_hook` and
`Single_focus_hook` — sitting in `attr.ml` beside the API — are the worked example, and
`bonsai_web_components`' element-size and visibility hooks do the same from outside the library. The
primitive had been there the whole time.

The value of the mistake is that it is recorded rather than quietly fixed. The item is struck through in
place at Gate 21, with the old reasoning kept, because "what we believed and why" is the more useful
record than a clean list.

| What | Evidence |
| --- | --- |
| `Common.Delay_hook`, cancellable by construction | input `Some delay_ms` while the pointer is present, `None` the moment it leaves — so a changed input **cancels** the pending timer rather than racing it |
| `?delay_ms` on `Tooltip.view`, default 200 ms | upstream's value, not a chosen one |
| The delay is pressed, not described | browser: "hovering does NOT open it straight away — there is a delay" and "leaving before the delay elapses never opens it at all" |
| The false claim corrected in four places | `src/tooltip.mli`, this file's Gate 21, `ROADMAP.md`, and `port.json`'s M13 note — the last because that is the text the tool layer hands to agents |

The bug worth recording is the one the gate could not have described: the first implementation called
`setTimeout(delay, callback)`. The browser coerces the number, calls nothing, raises nothing and logs
nothing — a silently empty statement. The only symptom was "the tooltip never opens", and it was found by
instrumenting the hook with two log lines (`delay start: 200.` with no matching `delay fired`) and one
throwaway playwright probe that hovered and dumped the console.

### Totals after this gate

| Gate | Result |
| --- | --- |
| Component checks (`node test/run.mjs`) | **362 / 0** |
| Real-browser checks (Chromium, live showcase) | **162 / 162** |
| Demo fixture (jsdom) | 25 / 25 |
| Responsive visual regression (320 / 375 / 768 / 1440) | 66 / 0 at 0.00% |
| Coverage | 34 of 103 ported, 69 not |
| Showcase | 35 sections, 242 examples |
| Appearance pages | 31 |

Transcript: `docs/verification/sweep-m13f.txt` (`sweep-m13f.txt` exit 0, 0 FAIL).

## Gate 24 — Dialog (M14), or: the platform owns the modality

The first component in the port whose behaviour is not written in the port. Upstream builds Dialog on the
native `<dialog>` opened with `showModal()`, so the top layer, the inert page behind it, the focus trap,
`Escape` and `::backdrop` are the browser's. What the port owns is the **dismissal matrix**, and the gate
presses it rather than reading it:

| purpose | Escape | backdrop click | role |
| --- | --- | --- | --- |
| `info` | closes | closes | `dialog` |
| `form` | closes | **does not** | `dialog` |
| `required` | **does not** | **does not** | `alertdialog` |

| What | Evidence |
| --- | --- |
| `showModal()` is really used, not merely `open` | browser: the element matches `:modal`, which an element carrying the `open` attribute in ordinary flow does not |
| The hook drives it from a *value* | `Common.Delay_hook`'s mechanism (Gate 23); no event fires when a caller changes their own state, so the DOM side cannot be a handler |
| Focus is trapped, then returned | browser: `document.activeElement` is inside the dialog on open, and is the trigger again after close |
| The platform's own close works | browser: a `<form method="dialog">` submit button closes it, and the application learns through `on_open_change` — no callback from the content |
| It renders where the platform has no dialog at all | component gate: jsdom 30 implements neither `showModal` nor `close`, and the modal path still renders without throwing (guarded by a feature check, since the platform is not always there) |

### What the gates caught, and what reading did not

1. **Two `style` attributes lose one.** Sizing and position were written as separate attributes;
   virtual_dom merges last-wins, so the position was silently dropped. Caught because the check reads the
   style rather than the class.
2. **`<form method="dialog">` did nothing when clicked** — the port's `Button` defaults to
   `type="button"`, which is right, and means a button inside a form does not submit. The example now
   passes `~type_:Button.Submit`; the prop had been ported since M2 and this is the first caller.
3. **Six unrelated browser checks failed** because the dialog above them never closed: a modal left open
   makes the rest of the page inert. The failure names the *symptom*, not the cause — a gate that is one
   page cannot tell "the dropdown's keyboard path is broken" from "something above it is still modal".
4. **The responsive probe invented six collapsed components** — a closed `<dialog>` is `display: none`,
   and everything marked inside it has a zero box. The fix is general: ask each element whether it
   renders (`checkVisibility`) instead of assuming a marked component has a box. Baselines regenerated;
   the page legitimately grew.

### Totals after this gate

| Gate | Result |
| --- | --- |
| Component checks (`node test/run.mjs`) | **372 / 0** |
| Real-browser checks (Chromium, live showcase) | **174 / 174** |
| Demo fixture (jsdom) | 25 / 25 |
| Responsive visual regression (320 / 375 / 768 / 1440) | 66 / 0 at 0.00% |
| Coverage | **35 of 103** ported, 68 not |
| Showcase | 36 sections, 249 examples |
| Appearance pages | 32 |

Transcript: `docs/verification/sweep-m14b.txt`.

## Gate 25 — AlertDialog (M14), and the difference between the prose and the shipped component

AlertDialog is thin over Dialog, and everything interesting about it is in what it asks Dialog for.

**The role override is the contract.** Upstream builds it on `purpose="form"` and then passes
`role={isInline ? 'group' : 'alertdialog'}`. That is why `Dialog.view` takes `~role` in this port: the
role is derived from the purpose by default, and this is the caller that has a reason to disagree. The
modal form is an `alertdialog`; the *inline preview* is not, because an `alertdialog` role promises an
interruption, a focus trap and an inert page behind it, and the preview has none of those. A component
that always said `alertdialog` would describe something that is not on screen.

**Where the prose and the code disagree, the port follows the code and says so.** Upstream's own comment
on this component says an alert dialog *"requires explicit user action to dismiss"*. It then passes
`purpose="form"`, and `purpose="form"` allows Escape. So the shipped component closes on Escape, whatever
the sentence above it says. The port keeps Escape, because that is what a consumer of upstream actually
gets — and because splitting the difference (refusing Escape, as `required` does) would match neither the
documentation nor the behaviour.

**The title and the description are strings, so the component owns the association.** Unlike Dialog,
whose caller owns the header and therefore the id, AlertDialog owns its whole body: it builds the heading
and the description text and wires `aria-labelledby`/`aria-describedby` to them itself. That is not
decoration — a description that is drawn but not described is one assistive technology never reads.

| What | Evidence |
| --- | --- |
| The inline preview says `group`, the modal form says `alertdialog` | component gate (role = group) and browser gate (role = alertdialog, and it matches `:modal`) |
| The description is *associated*, not just rendered | component gate: `aria-describedby` resolves to an element whose text is the description |
| The action reaches the application, and closing stays its decision | browser: the readout goes to "answers taken: 1" and the dialog is closed — the component never closes on an action by itself |
| Both answers have ids of their own | component gate |
| The small-screen order is CSS | browser: `row` at 1280px, `column-reverse` below 640px with full-width buttons — pressed by resizing, not read off the stylesheet |

**What this component changed in Dialog, and why it is not a wart.** AlertDialog composes Dialog and wires
a callback into its own content — the Cancel answer closes the dialog. A container cannot do that with a
plain children list: it has no way to unwrap the callback tree a caller handed it. So `Dialog.view`'s
`children` became a *tree*. That is not a special case for AlertDialog; it is the general shape of a
container that composes another, and Dialog's own `is_open`/`on_open_change` were already trees for
exactly this reason.

**Not ported, with the reason** (in `alert_dialog.mli`): `useImperativeAlertDialog` — upstream's
`alertDialog.confirm(options)` returning a promise. It needs a handle concept: code that is not a Bonsai
view asking a mounted component a question. The port has no such concept, and inventing one for a single
component would be the port's decision rather than upstream's.

**IconButton, in the same commit, because the same oversight caused both.** AlertDialog needed a root
of its own before any tool could see it — and checking that turned up IconButton, the one ported
component with no appearance page. The reason was invisible: it is a Button preset that inherited
Button's marker, and every tool here identifies a component by its marker, so nothing could name it.
It now names itself, which required `Button.view` to take the marker as an argument — passing it in
through `~attrs` does not work, because virtual_dom *warns and drops* rather than letting two
attributes of the same name meet. The browser gate was the only place that showed it: three icon
buttons, three console warnings, every assertion green. A check had been asserting the shortcut as if
it were the contract ("IconButton carries Button's marker, not its own"); it now asserts the new truth
and keeps the old name in a comment, because the reason the shortcut existed is the interesting part.

### Totals after this gate

| Gate | Result |
| --- | --- |
| Component checks (`node test/run.mjs`) | **379 / 0** |
| Real-browser checks (Chromium, live showcase) | **181 / 181** |
| Demo fixture (jsdom) | 25 / 25 |
| Responsive visual regression (320 / 375 / 768 / 1440) | 66 / 0 at 0.00% |
| Coverage | **36 of 103** ported, 67 not |
| Showcase | 37 sections, 252 examples |
| Appearance pages | 34 of 36 ported (the two without one are HStack and VStack, which are the
  same module as Stack, ported once) |

Transcript: `docs/verification/sweep-m14e.txt` — the run for this commit, after the re-baseline.
The earlier `sweep-m14c.txt` recorded 378/0, before IconButton's second check existed.

## Gate 26 — DialogHeader (M14), and a component the coverage denominator does not contain

The component that gives a dialog its name, and the last piece M14 needed.

**The association is made by the caller, and that is the point.** Upstream's header learns its parent
from context and registers the title id with it. Context has no analogue here — a child is already built
by the time the container sees it — so the heading carries an id and the caller passes that same string
to `Dialog.view`'s `~labelled_by`. The caller is the only thing that can see both. The gate resolves the
association rather than comparing strings: it reads `aria-labelledby` and then asserts that the element
it names is the `h2` whose text is the dialog's title.

**The close button is conditional, and the absence is asserted.** Upstream renders no close button when
`onOpenChange` is absent, which is right: a control that cannot tell anyone it was pressed is a control
that does nothing. So there are two headers on the page — one with a callback and one without — and the
component gate asserts the *absence* as carefully as the presence. A check for "a button exists" cannot
notice a button that should not exist.

**One accessibility behaviour is not ported, and it is named rather than approximated.** Upstream focuses
the title when a modal dialog opens. It matters because the platform does not do it for us: the focus
delegate `showModal()` runs skips any element with `tabindex="-1"`, so the browser lands on the first
*tabbable* thing — the close button — and a screen reader would announce "Close" rather than the
dialog's name. The heading is consequently reachable but not focused.

The mechanism exists in this port: `Menu_focus.focus_on_next_frame` focuses an element, and
`Common.Delay_hook` established the hook shape for DOM work no event triggers. What is missing is the
*moment* — the header cannot know the dialog opened, and upstream learns that from context. The honest
home for it is `Dialog`, whose hook already runs on open. The browser gate therefore asserts the
*capability* (`heading.focus()` takes effect, which is what `tabindex="-1"` exists for) rather than who
receives focus automatically, so the check stays true when the gap is closed instead of failing on an
improvement.

**The generator caught a mistake the coverage arithmetic would have hidden.** `DialogHeader` is an
upstream module, but it is not one of `registry.json`'s 103 extracted components — the same position
`FieldLabel` is in. Registering it under `ported` made the coverage generator report *"port.json names
components absent from registry.json: DialogHeader"*, which is exactly right: the denominator is the
registry, so porting this moves nothing. It now sits in `port.json.infrastructure` with the reason
written down, and the coverage count is unchanged at 36 of 103.

| What | Evidence |
| --- | --- |
| The heading names the dialog | browser: `aria-labelledby` resolves to the `h2` whose text is the title |
| It is focusable without joining the tab order | component gate: `tabindex="-1"` on the `h2` |
| No callback, no button | component gate: zero buttons in the header without `~on_open_change` |
| A callback, and a named button | component gate: the button exists and carries an accessible name |
| The header closes the dialog and reports it | browser: clicking it closes the dialog and the application's readout flips |
| Subtitle, slots and divider land where they belong | component gate |

### Totals after this gate

| Gate | Result |
| --- | --- |
| Component checks (`node test/run.mjs`) | **387 / 0** |
| Real-browser checks (Chromium, live showcase) | **185 / 185** |
| Demo fixture (jsdom) | 25 / 25 |
| Responsive visual regression (320 / 375 / 768 / 1440) | 66 / 0 at 0.00% |
| Coverage | **36 of 103** ported, 67 not |
| Showcase | 38 sections, 255 examples |
| Appearance pages | 35 (34 of the registry's 36 ported components, plus `DialogHeader`; the two without one are `HStack` and `VStack`, which are the `Stack` module ported once) |

Transcript: `docs/verification/sweep-m14f.txt`.

## Gate 27 — focus on open, or: how a recorded gap gets closed

Gate 26 recorded a gap rather than approximating it — upstream focuses the title when a modal dialog
opens, and this port did not, which matters because the platform's focus delegate skips an element with
`tabindex="-1"` and lands on the first *tabbable* thing. In a dialog with a header that is the close
button, so a screen reader announces "Close" instead of the dialog's name. This gate closes it.

**The fix is two lines of marking and one of action.** The heading carries
`data-astryx-focus-on-open`, and `Dialog`'s hook — which already runs on open, because it is what calls
`showModal()` in the first place — focuses the first marked descendant if there is one. Two things make
that the right owner:

- **The dialog is the only thing that knows it opened.** The header cannot know: upstream learns it from
  context, and context has no analogue here. This is the same constraint that turned `~labelled_by` into
  an argument, resolved the other way round because the *action* lives where the *signal* does.
- **It has to happen after `showModal()`, not before.** The platform moves focus itself as part of
  opening the dialog, so the correction belongs after it. A dialog that marks nothing keeps the
  platform's choice — the hook does nothing.

**The evidence is where focus actually lands**, measured in a real browser immediately after opening:
`document.activeElement` is the `h2`, not the close button. The component gate asserts the marker's
presence; only Chromium can assert the consequence, the same split as every other focus behaviour in this
port.

Two notes on discipline rather than behaviour:

- **The `not ported` paragraph in `dialog_header.mli` was corrected in the same commit as the work that
  retired it.** A deferral that stays written after it is closed is a false claim, and this repo has
  already been bitten by one (Gate 21's "unportable" delay).
- **A gate that asserts a capability survives an improvement; one that asserts a limitation does not.**
  Gate 26 deliberately asserted that the heading *can* be focused rather than who receives focus
  automatically, precisely so that fixing it would not read as a regression. That check is now replaced
  by the stronger one — the improvement is what changed it, and the old name is gone rather than
  quietly relaxed.

An inline preview never runs the hook at all, so no focus is taken there — which is how upstream
suppresses this on previews too, arrived at rather than special-cased.

### Totals after this gate

| Gate | Result |
| --- | --- |
| Component checks (`node test/run.mjs`) | **388 / 0** |
| Real-browser checks (Chromium, live showcase) | **185 / 185** |
| Demo fixture (jsdom) | 25 / 25 |
| Responsive visual regression (320 / 375 / 768 / 1440) | 66 / 0 at 0.00% |
| Coverage | 36 of 103 ported, 67 not |
| Showcase | 38 sections, 255 examples |

Transcript: `docs/verification/sweep-m14g.txt`.

## Gate 28 — Kbd (M15), and a shortcut's two halves

A small, self-contained component, and the first one ported since M1 that needed nothing from the
overlay or form work. It is also the first where the interesting part is entirely *not* visual.

**Glyphs are for eyes; assistive technology gets words.** Upstream renders ⌘ ⇧ ↵ ⌫ and then does
something easy to miss: the wrapper is `role="img"` with an `aria-label` built from spoken labels
("Command + Shift + P"), and every cap inside is `aria-hidden`. A screen reader announcing "⌘" announces
nothing. So the port keeps the two halves as separate functions — `key_display` and `key_label` — and the
browser gate asserts the *shape* of the answer rather than one platform's spelling: the name is words,
and contains no glyph. A check that hardcoded "Control" would be testing the runner; one that hardcoded
"Command" would fail on it.

**`mod` is the one key whose name depends on the platform, and this port deliberately answers
differently.** Upstream defers the answer through `useSyncExternalStore` so that a server render and the
first client render cannot disagree — a hydration mismatch would flip every shortcut on the page. This
port has no server render, so it asks directly. That is a divergence, recorded rather than a workaround
copied for a problem the port does not have.

**The detection rules are upstream's verbatim, including the subtle one.** Client hints when they name a
platform, `navigator.platform` otherwise — and a client-hints platform of `""` or `"Unknown"` is treated
as *no answer*, not as a negative one, so it falls through instead of concluding "not Apple" (builds that
rewrite their client-hints identity ship exactly that). The client-hints branch tests for "mac"
case-insensitively; the legacy branch tests `Mac`/`iPhone`/`iPad`/`iPod` as written.

**Three pure functions are exposed on purpose.** The gate runs on Linux, so the Mac branch has to be
pressable without a Mac: the fixture renders `key_display ~is_mac:true "mod"` and the labels directly,
next to the live component exercising the Linux branch. That verifies the *rules*; the *detection* is
verified only as far as "this Linux runner is correctly read as not-Apple", which is stated here rather
than dressed up.

**The stylesheet is only provable in a browser.** jsdom has no cascade, so the cap's height is measured
in Chromium against the very token the CSS names (`--spacing-5` × the root font size), along with its
fill, its 2px bottom edge and `user-select: none`. A CSS block that named a token that does not exist
would render a plain glyph and pass every DOM assertion.

| What | Evidence |
| --- | --- |
| The name is spoken words, not glyphs | browser: `aria-label` matches Command/Control and contains no glyph |
| The caps are hidden but painted | browser + component gate |
| `mod` resolves both ways | fixture: `⌘`/`Command` for Mac, `Ctrl`/`Control` otherwise |
| Aliases and fallbacks | component gate: `esc` → Esc/Escape, `shift+plus` → two keys, `pageup` → PAGEUP |
| Keys are trimmed, lowercased, split on `+` | component gate: `mod+shift+P` → `mod,shift,p` |
| The cap is sized by the token the CSS names | browser: measured height vs `--spacing-5` |

### Totals after this gate

| Gate | Result |
| --- | --- |
| Component checks (`node test/run.mjs`) | **405 / 0** |
| Real-browser checks (Chromium, live showcase) | **191 / 191** |
| Demo fixture (jsdom) | 25 / 25 |
| Responsive visual regression (320 / 375 / 768 / 1440) | 66 / 0 at 0.00% |
| Coverage | **37 of 103** ported, 66 not |
| Showcase | 39 sections, 258 examples |
| Appearance pages | 36 |

Transcript: `docs/verification/sweep-m15a.txt`.

## Gate 29 — the layer mechanism (M16, first step): the platform dismisses, and the value is told

Not a component. This is the mechanism the whole overlay family stands on — `Popover`, `BottomSheet`,
`DropdownMenu` phase 2 and everything waiting behind them — landed on its own so that the components
above it are wrappers around something already proven, rather than the place it is discovered.

**Upstream does not position its layers with JavaScript.** It opens them with the **native Popover
API** — `popover="auto"` plus `showPopover({source: trigger})` — which hands the platform the top layer,
outside-click dismissal, `Escape`, and CSS anchor positioning against the trigger. The 46 KB of placement
maths in `useLayer.tsx` is largely the *fallback* for browsers without `showPopover` (Firefox < 125), not
the mechanism. Reading that before writing is the difference between an afternoon and a week.

So the port's `Common.Layer_hook` is small on purpose: it drives `showPopover`/`hidePopover` off a Bonsai
boolean, feature-checks `typeof el.showPopover === "function"`, and does the one thing the platform
*cannot* do — **report back when the browser closes the layer behind the application's back.** That is
the whole reason a controlled component needs a hook here instead of an attribute: after a light-dismiss
click the layer is gone but the value still says open, and every later click on the trigger would look
like a no-op. Three ordering rules came with it, all recorded in the code:

- the state is updated **before** `hidePopover()`, because that call fires `toggle` too — a close the
  application asked for is not news;
- `showPopover()` is never called from inside the toggle handler, because it throws if a toggle is
  already in progress;
- `Escape` is not intercepted. A `popover="auto"` layer closes on `Escape` because that is what the
  platform does with one; a surface that wants explicit dismissal only asks for it by rendering
  `popover="manual"`, and then the platform leaves it alone.

**The demonstration is the verification.** The showcase has two live layers that differ by exactly one
attribute, and the browser gate presses both:

| What | Evidence (real Chromium) |
| --- | --- |
| A click opens the layer, and the browser agrees it is open | `matches(":popover-open")` is true |
| A **real** click outside dismisses it | the browser's own light dismiss, not a listener of ours |
| …and the application is **told**, so the value is not left saying open | the readout flips to closed |
| It reopens after being dismissed out from under the application | the trap this hook exists to prevent |
| `Escape` dismisses it, and the value is told again | real key event |
| `popover="manual"` ignores `Escape` **and** outside clicks | the platform was never asked to dismiss it |
| Only the application closes a manual layer | the readout follows the value |

That last pair is the point worth keeping: "explicit dismissal only" is an **attribute meaning**, not a
flag this port implements. There is no code path in the port that decides to ignore `Escape`.

**The jsdom half is the fallback path, and says so.** jsdom has no Popover API at all, so the component
gate asserts what is true there and nothing more: the attribute is present (that *is* the mechanism — a
supporting browser acts on it), the marker is there, the hook is a no-op rather than a crash, and the
caller's value survives untouched. It does not pretend the layer opened. The same split `<dialog>`
forced, for the same reason.

**A supporting change rode along:** `is_function`, `has_method`, `call` and `is_connected` moved out of
`dialog.ml` into `Common`, where the second consumer can reach them. Only the two `dialog.ml` still uses
kept an alias — an unused value is a compile error in this repo, which is how the move stayed honest
rather than leaving four aliases of which two were dead. The Dialog gate re-ran unchanged afterwards:
the refactor is invisible to every existing check, which is the standard a refactor is held to here.

**What this gate does *not* claim.** `Layer` is still unported: the registry component is upstream's
stacking and depth machinery, and this is one mechanism underneath it. Coverage is unchanged at 37 of
103, and the count below would be a lie if it were not said out loud.

### Totals after this gate

| Gate | Result |
| --- | --- |
| Component checks (`node test/run.mjs`) | **409 / 0** |
| Real-browser checks (Chromium, live showcase) | **201 / 201** |
| Demo fixture (jsdom) | 25 / 25 |
| Responsive visual regression (320 / 375 / 768 / 1440) | 66 / 0 at 0.00% |
| Coverage | 37 of 103 ported, 66 not (unchanged: a mechanism, not a component) |
| Showcase | 40 sections, 260 examples |
| Appearance pages | 36 |

Transcript: `docs/verification/sweep-m16a.txt`.

## Gate 30 — the trigger's wiring (M16, second step), and where a harness stops being evidence

The layer mechanism from Gate 29 drove the surface. This adds the other half of upstream's arrangement:
the **trigger** is wired up for the caller, not by the caller.

**`aria-expanded` is state, so the caller cannot supply it.** Upstream does not ask for the trigger's ARIA
as props: it locates the first `button, [role="button"]` among the children and applies `aria-haspopup`,
`aria-expanded` and `aria-controls` to it, plus the click that toggles the layer. An attribute handed in
from outside could only ever be a snapshot and would go stale the first time the layer opened — which is
why `Common.Layer_trigger_hook` is a hook and why the demo's Button now has **no `on_click` of its own**.
Two subtleties came across with it:

- **The keydown path is attached only to something that is *not* a native `<button>`.** A real button
  synthesizes a click from Enter and Space, so a port that added a handler for it would toggle the layer
  **twice** — opening and immediately closing — and the component would look broken in a way no
  structural assertion would catch. The browser gate presses Enter once and expects the layer open, which
  is the check that catches exactly that.
- **The listeners read the *latest* effect, not the one captured at attach time.** A caller's effect tree
  is rebuilt on every render, so a closure holding the first one would act on a value that has since
  moved. The state carries the current effect and the listener reads it.

| What | Evidence (real Chromium) |
| --- | --- |
| The trigger says what kind of thing it opens, and whether it is showing | `aria-haspopup="dialog"`, `aria-expanded` false then true |
| `aria-controls` names the layer element itself | resolved, not compared as a string |
| The keyboard path works and does **not** double-fire | Enter opens it, exactly once; Enter again closes it |
| The trigger's ARIA follows a dismissal it did not perform | checked after the platform's own light dismiss |

### Where a harness stops being evidence

The first version of these checks was written for the **component** gate, and it failed: the trigger's
ARIA came back `null`. The informative step was not adjusting the assertion but running the identical
checks in Chromium, where they passed — so the code was right and the *harness* was the difference. This
gate's jsdom harness mounts and reads the DOM without pumping the mount effects a live runtime runs, and
a hook's work happens in exactly those effects.

The checks were therefore split along the same line `<dialog>` forced, and the reason is written into the
gate rather than discovered again next time:

- **jsdom asserts the structure the hook has to find** — a real `<button>` inside the wrapper the hook
  lives on, with the surface it controls as a sibling, because a mechanism handed nothing can still pass
  every browser check it does not exercise;
- **Chromium asserts the ARIA and the keyboard path themselves.**

Worth stating plainly, because it generalises: *"it fails in jsdom"* is not evidence of a harness
limitation until the same check passes in an engine that has the API. The two gates disagree here on
purpose, and the disagreement is documented rather than smoothed over.

### Totals after this gate

| Gate | Result |
| --- | --- |
| Component checks (`node test/run.mjs`) | **411 / 0** |
| Real-browser checks (Chromium, live showcase) | **206 / 206** |
| Demo fixture (jsdom) | 25 / 25 |
| Responsive visual regression (320 / 375 / 768 / 1440) | 66 / 0 at 0.00% |
| Coverage | 37 of 103 ported, 66 not (unchanged: still a mechanism, not a component) |
| Showcase | 40 sections, 260 examples |
| Appearance pages | 36 |

Transcript: `docs/verification/sweep-m16b.txt`.

## Gate 31 — ButtonGroup (M17): buttons joined into one surface

Coverage moves **37 → 38 of 103**. Two parts, and only one of them was expected.

### The connected look is CSS, because there is no context here

Upstream's children read a `ButtonGroupContext` and style themselves, which is how a member that renders
its own layer still gets the right edges. A child in this port is built *before* its container sees it, so
there is nothing to put in a context: the edges are drawn by CSS from the group instead.

The rule has to target the button **inside** each child rather than the child itself. A member which
renders a layer — a Button with a tooltip, a DropdownMenu — wraps its button, so `> .astryx-button` misses
it and the group loses its end caps. Upstream hit exactly this and answered it by moving those rules out of
the group and into `Button.tsx` (see `IS_LAST_ITEM` in its own comment); this arrives at the same place
from the other side. The longhands are deliberately written after `.astryx-button`'s shorthand, so they win.

### The part that was not expected: one tab stop is behaviour

A group is a single tab stop — Tab reaches the group, arrows move *within* it along the orientation, Home
and End jump to the ends, the ends wrap, disabled members are skipped. That is the APG roving-tabindex
technique, and **unlike a radio group the platform does not provide it for buttons**: there is no native
element whose members share a name. So the component implements it, and every arrow movement rewrites
`tabindex` on the members — the focused one becomes `0`, the rest `-1`, which is what makes the next Tab
leave the group instead of walking through it.

Upstream's three `useListFocus` settings are copied verbatim because all three are load-bearing:

- **the item selector must not key off a tabindex *value*.** `[tabindex="0"]` would drop each member the
  moment the roving stamps it `-1`; `button, a[href], [tabindex]` is the selector upstream uses, and the
  underscore in that reasoning is upstream's own comment.
- **the ends wrap**, and Home/End are absolute rather than relative.
- **the nearest boundary above a key event has to be the group's own root** (`[role="group"], [popover]`).
  A member's layer renders inline inside the group — the layer mechanism does not portal it — so a key
  pressed in an open menu bubbles here; and naming the group's own root is what keeps a group rendered
  *inside* a Popover working, since bailing on any `[popover]` ancestor would swallow every arrow key the
  group owns.

### What the browser measured

| Check | Evidence (real key presses, real CSS) |
| --- | --- |
| Exactly one member is a tab stop | one `tabindex="0"`, the rest `-1` |
| ArrowRight moves along the orientation | focus lands on the next member |
| And the tab stop follows the focus | the new member holds the `0`, so Tab leaves the group |
| A disabled member is skipped | one step from Paste lands on Copy, not on Delete |
| End is the last **enabled** member, not the last member | Paste, with Delete after it |
| A vertical group moves on the vertical axis | ArrowDown from Zoom in → Zoom out |
| The end caps are drawn | outer radii 8px, inner radii `0px` |
| The shared edge is one border | the middle member's inline margin is `-1px` |

As in Gate 30, the jsdom gate asserts the *structure* (a named region, its members inside it, one of them
genuinely `disabled` rather than styled that way) and the browser asserts the behaviour, because the tab
stop is written by a mount effect and the jsdom harness does not pump those.

### Two mistakes, both caught by the thing that caught them

1. **My end-cap check was wrong, and it failed correctly.** It measured `Paste` as the "last" member and
   demanded a trailing radius of 8px. Paste is the *third* of four — Delete is last. The check was at
   fault, not the CSS, and the fix was to measure `Delete`, which incidentally shows the more interesting
   fact: a *disabled* last member still keeps the group's trailing cap.
2. **The section rendered perfectly and counted as zero examples.** The gate counts examples the showcase
   *marks*, and the new section's two Stacks were not wrapped in `ex`. Nothing was visibly broken — four
   frozen counters and an "empty section" assertion were the only evidence, which is exactly what those
   counters are for.

### Not ported, and named rather than approximated

**`size` does not propagate from the group to its members.** Upstream's group provides a size through its
context and members inherit it unless they override it; with no context, every member states its own. A
group whose buttons disagree will look like it, and that is the honest version of this seam.

### Totals after this gate

| Gate | Result |
| --- | --- |
| Component checks (`node test/run.mjs`) | **414 / 0** |
| Real-browser checks (Chromium, live showcase) | **214 / 214** |
| Demo fixture (jsdom) | 25 / 25 |
| Responsive visual regression (320 / 375 / 768 / 1440) | 66 / 0 at 0.00% |
| Coverage | **38 of 103** ported, 65 not |
| Showcase | 41 sections, 263 examples |
| Visual contract pages (`tools/gen-visual-contract.mjs`) | 38 |
| MCP layer | every ported component truthfully reachable — ButtonGroup included |

Two notes on the generated corpora, because both are places where a number can drift silently. The
*visual contract* corpus is regenerated here and now has a page for every ported component (38). The
*capture-based* reference generator (`tools/gen-visual-references.py`) still needs
`visual-captures/captures.json`, which comes from the upstream Storybook build — a gap the README already
declares rather than hides. And the MCP layer currently reports ButtonGroup as "ported, no snippet", which
is the weak-but-true position, not a false one.

Transcript: `docs/verification/sweep-m17a.txt`.

## Gate 32 — Popover (M18): a layer anchored to its trigger

Coverage moves **38 → 39 of 103**. This component is mostly a wrapper — deliberately: two mechanisms were
ported and proven on their own first (Gates 29 and 30), so what is left here is the labelled surface, the
generated close control, the focus rule and the width/padding seam.

### The rule this port took from upstream verbatim

**Focus enters the first genuine control in the content; a popover with none falls back to its own labelled
surface.** The surface is focusable (`tabindex="-1"`) for exactly that fallback. And the generated close
button is **not** a candidate — not by a filter, but structurally: it sits outside the content wrapper, so
the content query cannot reach it. That is what keeps it out of initial focus while leaving it reachable by
keyboard, and it is the one structural fact the jsdom gate asserts so that the browser gate's behavioural
check has something to rest on.

**Closing returns focus to the trigger, but only if focus was inside.** A dismissal the person did not ask
for must not yank focus out of wherever they had moved it to.

**Focus is asked for on the next frame.** The surface is `display:none` until the layer mechanism shows it,
and the two hooks run in unspecified order after the same DOM patch — so focusing immediately would
silently do nothing whenever the focus hook ran first. Same ordering trap the dialog hit with `showModal`,
arrived at from a different direction.

### What the browser measured

| Check | Evidence (real Chromium) |
| --- | --- |
| A click opens it, and the browser says so | it matches `:popover-open` |
| The trigger says what it opens and that it is showing | `aria-expanded` true, `aria-controls` naming the surface |
| Focus enters the first control in the content, not the close button | `document.activeElement` is "Copy link", inside the content wrapper |
| The surface was placed **below its trigger** | its top is past the trigger's bottom — anchor positioning ran, it is not merely in the top layer |
| Escape dismisses it and the application is told | closed, `aria-expanded` false — the value is not left saying open |
| Focus went back to the trigger | the trigger holds focus again |
| A real outside click dismisses it too, and the value is told again | closed, `aria-expanded` false |
| The generated close control is labelled and closes it | activating it closes the surface |

### Divergences, named rather than approximated

- **Width is handed to CSS, not measured.** Upstream clamps against the viewport and flips or slides; this
  port sets the width and stops. Width unset means "match the trigger", which native `anchor-size()` does
  with no JavaScript at all.
- **No modal focus trap.** `isModal` is announced with `aria-modal` and nothing is trapped: Tab can leave
  the surface. The platform owns the top layer here, but it does not own the trap.
- **The render-prop and `anchorRef` trigger modes are not ported** — a language without render props has no
  equivalent for handing the caller the trigger props, and the automatic mode covers the case.
- **Light dismiss and Escape are one `popover` attribute**, so asking for one without the other is not
  expressible. The port takes the reading that keeps the surface alive until the application closes it, and
  the `mli` says so rather than leaving a reader to discover it.

### The gate caught a miss of mine again

The first run of the browser gate after adding the section failed four frozen counters — and one of them
was real: **`no section missing from the nav`**. I had added the section and not the nav entry. That check
exists precisely for this, and it is the second time in two milestones that a hand-maintained list was the
thing that broke rather than the code.

### Totals after this gate

| Gate | Result |
| --- | --- |
| Component checks (`node test/run.mjs`) | **419 / 0** |
| Real-browser checks (Chromium, live showcase) | **223 / 223** |
| Demo fixture (jsdom) | 25 / 25 |
| Responsive visual regression (320 / 375 / 768 / 1440) | 66 / 0 at 0.00% |
| Coverage | **39 of 103** ported, 64 not |
| Showcase | 42 sections, 264 examples |
| Visual contract pages | 39 |
| MCP layer | every ported component truthfully reachable |

Transcript: `docs/verification/sweep-m18a.txt`.

## Gate 33 — Timer (M19): a duration that stays readable without re-rendering

Coverage moves **39 → 40 of 103**.

### One reading, two numbers, and they are not always the same number

The rendered element is a real `<time>`: the human reading is its text, an ISO 8601 duration is its
`datetime`. Past an hour the elapsed text stops showing seconds — and then **the duration follows the text,
not the clock**. A duration that disagrees with its own visible reading is worse than no duration at all.

The showcase makes this measurable rather than argued: two timers rendered from the same start time, one in
each format. The browser gate asserts both, and the difference between them *is* the rule.

| Check | Evidence (real Chromium) |
| --- | --- |
| An elapsed reading past an hour shows hours and minutes and no seconds | the text is exactly `1h 02m` |
| And its duration is a whole number of minutes | `PT3720S` — 62 × 60, rounded down from 3725 s |
| The clock format at the same instant shows seconds | it matches `1:02:\d\d` |
| And *its* duration is the true elapsed time | `PT3725S`+, not a multiple of 60 |
| Tabular figures are really applied | computed `font-variant-numeric: tabular-nums` |

Two gates, one claim each: jsdom asserts the **class** (`.astryx-text--tabular` is present) because it has
no cascade, and the browser asserts the **computed value** that class produces. That split exists because
of the Kbd milestone's mistake, and it is the honest half for each engine.

### "Nothing re-renders" is checkable, and it was checked

Upstream writes the changed text straight to the owned `<time>` node instead of scheduling tick renders. A
component that re-rendered once a second would re-render everything above it once a second — and that is a
claim a screenshot cannot test. So the browser gate tests it the only way it can be tested: **hold the DOM
node across a second and check it is still the same node.** A re-render would have replaced it. It is the
same node, and the text moved.

The wait until the next change is computed against the precision the reading actually has — past an hour
this does not ask the clock every second in order to discover that nothing moved. A start time in the future
is the one case where the reading sits at zero and then moves.

### The discovery: an epoch timestamp does not fit in this platform's `int`

The first browser run after the showcase was wired **took the whole page down** — three uncaught errors and
"the app mounted in Chromium — no `[data-astryx-component]` appeared". The cause:

> under js_of_ocaml an `int` is 32 bits, and milliseconds since 1970 do not fit in one.

Converting `Date.now()` to an `int` raises `Invalid_argument`. Core's `Time_ns.to_int_ns_since_epoch`
refuses on this target for the same reason, with a message that says so — which is how the first version of
this was caught.

The fix is not a workaround but the more faithful type: **a JS `number` is a double and an OCaml `float` is
a double**, so `start_time` and the internal clock are floats, while durations *within* the component (the
elapsed reading, the wait until the next change) are small and stay ints. This is written into the `mli`
rather than left in a commit message, because the next person to add a component with a timestamp will hit
it too.

Worth stating plainly: this was caught by a check whose purpose is not to test the component — *"the app
mounted"* — which exists because a page that fails to render must never be mistaken for a page that passed.

### Totals after this gate

| Gate | Result |
| --- | --- |
| Component checks (`node test/run.mjs`) | **423 / 0** |
| Real-browser checks (Chromium, live showcase) | **231 / 231** |
| Demo fixture (jsdom) | 25 / 25 |
| Responsive visual regression (320 / 375 / 768 / 1440) | 66 / 0 at 0.00% |
| Coverage | **40 of 103** ported, 63 not |
| Showcase | 43 sections, 267 examples |
| Visual contract pages | 40 |
| MCP layer | every ported component truthfully reachable |

Transcript: `docs/verification/sweep-m19a.txt`.

## Gate 34 — InputGroup (M20): a group of controls that reads as one field

Coverage moves **40 → 41 of 103**.

### The label names the group, and that is a different thing from naming a control

A group differs from every other field in this port in one way that shows up in the markup: there is no
single control for the label to point at. So the label's `for` is omitted — which `Field_label` was already
built to do through `is_group_label`, a parameter that existed before this milestone because a prior one
had put it there — and the status message is **`Detached`**, sitting below the group, because an attached
message has a control's edge to sit against and a group has none.

The assertion that carries the claim:

> a group's label is a **`<span>`**, not a `<label>`, and carries no `for`.

The first version of that check demanded a `<label>` with no `for` — and the port correctly refused to emit
one, because a `<label>` whose only purpose is to point at a control names nothing when there is no such
control. The gate was right and the check was wrong, which is the useful kind of failure.

### The size reaches the children through the box, not through a message

Upstream threads the group's size to its children via `SizeProvider` — a React context. Here there is no
context to thread it through, because the children are built by the caller before the group sees them (the
same shape as the connected look in `Button_group`). So the group is `inline-flex` stretched to a step of
the shared size scale, and a member takes its height from the box.

That is a CSS outcome, so it is a browser check, and it is measured rather than assumed:

| Check | Evidence (real Chromium) |
| --- | --- |
| The child fills the box rather than choosing its own height | child height **32** = group height **32** (the md step) |
| …and from the other end, at another size | the lg disabled group's child fills **36** |
| The shared edge is single | the adornment's right edge meets the input's left edge within **1px** — they overlap by one border width |
| Only the group's outer corners are round | adornment start radius **> 0**, the input's start radius **= 0** |
| An adornment does not stretch | `flex-grow: 0` — it is sized by its text |
| A disabled group dims as a whole | one `opacity: 0.5` on the box, not one per member |

One of those numbers was wrong on the first run — I asserted 28 (the fixture's `sm` group) against the
demo's `md` group. The *claim* held in both places (child height = box height); only my expected value was
carried over from the wrong group.

### What the `.ts` file I didn't count turned out to contain

The measurement that chose this milestone counted `.tsx` files and found "341 lines, two files, nothing
shared but `themeProps`". There is also an `InputGroup/groupStyles.ts` (85 lines, a `.ts`, so the metric
missed it) and it holds the rules that make the group read as one box — which is to say, the whole reason
the component exists:

- every direct child takes `flex: 1; min-width: 0; height: 100%`, gives up its inner corners, and pulls left
  by one `border-width` so the shared edge is one border rather than two touching ones;
- the trailing corner uses `:has(~ *:not([popover]):not(template):not(dialog))` rather than `:last-child`;
- and a focused member gets `z-index: 2`, so the next member's overlapping border cannot cover its focus
  ring.

That third rule is the one nobody would guess from the outside, and the middle one is the same insight the
overlay family produced in M16: a popover child is not a visual member of the thing it is a child of.

### The build traps, both recorded in the source

- **Core defines a module named `Field`.** After `open! Core`, a sibling module's own `Field` refers to
  Core's, and the file would fail to compile against it. `text_area.ml` and `radio_list.ml` already document
  the fix — `module Field_ = Field` before the opens — and `input_group.ml` now does the same.
- **`Vdom.Attr.class_` is variadic strings; `Bonsai_web.Attr.class_` takes a list.** This is the *opposite*
  of the lesson an earlier milestone recorded, and both are true because they are two different functions.

### Totals after this gate

| Gate | Result |
| --- | --- |
| Component checks (`node test/run.mjs`) | **428 / 0** |
| Real-browser checks (Chromium, live showcase) | **237 / 237** |
| Demo fixture (jsdom) | 25 / 25 |
| Responsive visual regression (320 / 375 / 768 / 1440) | 66 / 0 at 0.00% |
| Coverage | **41 of 103** ported, 62 not |
| Showcase | 44 sections, 270 examples |
| MCP layer | every ported component truthfully reachable |

`InputGroupText` is registered as infrastructure rather than as one of the 103 — it is a rendered component
the appearance contract should account for, but not part of the coverage denominator. `ScrollableArea` was
reconnoitred and deliberately not started: it is a five-module subsystem of about 1,330 lines, recorded in
the roadmap as a planned job rather than attempted at the end of a session.

## Gate 35 — Toolbar (M21): one tab stop for a bar of controls

Coverage moves **41 → 42 of 103**, and this is the first component in this port built on a mechanism that was
extracted *because* it arrived — the arrangement the roadmap called for after M18.

### What makes it a toolbar rather than a row of buttons

Three things, each checked somewhere in the suite:

- it is a `role="toolbar"` named by its label and says which way it runs (`aria-orientation`);
- navigation inside it is the same roving tab stop `Button_group` uses, now `Common.List_focus`;
- and **an input inside it keeps its arrows** — the caret guard, which is what lets a toolbar contain a text
  field at all.

### The debt from the generalisation, paid

When the mechanism was generalised, the caret guard defaulted off and **no test could reach it**, because
Toolbar was the only consumer that would set it. That was recorded then as a payment the next milestone owed
rather than as a note. This is the payment:

| Check | Evidence (real Chromium) |
| --- | --- |
| An arrow with the caret mid-text leaves focus in the field | focus is still the input after a real `ArrowDown` |
| An arrow at the end of the text leaves the field and moves focus | focus is a `BUTTON` afterwards |

**Both failures on the first run were in the checks, not the component**, and both are worth keeping:

1. The demo toolbar holding an input is *vertical*, so its forward key is **ArrowDown** — I pressed ArrowRight
   and then read "nothing happened" as a failure, when nothing happening was correct.
2. **A synthetic `KeyboardEvent` has no default action.** It can be heard by the application but it cannot
   move a caret, so a rule *about* a caret can only be tested with a real key press. The first version typed
   `setSelectionRange(1, 1)` and dispatched an event, and the caret sat still at 1 — which said nothing about
   the guard and everything about the method.

### The generalisation, and what the second consumer cost

`Common.List_focus` now takes its item selector, its boundary selector and the caret guard as inputs, each
defaulted to ButtonGroup's values so the first consumer did not move — proven by its unchanged suites
(428/0 at the time, on a freshly built bundle). Toolbar passes its own: members are
`button, input, [tabindex], a[href]` because a toolbar may hold a field, the boundary is
`[role="toolbar"], [popover]` because a toolbar is its own boundary, and the guard is on.

### Composition, and what is not there

A start/end pair is a flex row with the ends pushed apart; a centre slot switches the box to a three-column
grid so the middle is centred against the bar rather than against its neighbours (measured: the centre slot's
midpoint is within 1px of the toolbar's). The gap reaches the slots through a variable on the box. `role`,
`aria-label` and `aria-orientation` are stripped from the incoming props and set by the component, so a
Toolbar cannot be handed a role that contradicts the behaviour inside it.

Named as not ported, rather than approximated: **`useKeyboardHint`** (upstream's ephemeral arrow-key hint for
sighted keyboard users — the roving behaviour it explains is ported, and its own building blocks, `Kbd` and
the layer mechanism, are already here, so it is a small self-contained follow-up), **edge compensation**, and
the size context (the box takes the size scale's height and the caller builds its children knowing the size
it wants — the same divergence as InputGroup).

### Totals after this gate

| Gate | Result |
| --- | --- |
| Component checks (`node test/run.mjs`) | **433 / 0** |
| Real-browser checks (Chromium, live showcase) | **243 / 243** |
| Demo fixture (jsdom) | 25 / 25 |
| Responsive visual regression (320 / 375 / 768 / 1440) | 66 / 0 at 0.00% |
| Coverage | **42 of 103** ported, 61 not |
| Showcase | 45 sections, 273 examples |
| MCP layer | every ported component truthfully reachable |

## Gate 36 — MetadataList (M22): the layout belongs to the list

Coverage moves **42 → 43 of 103**. This is the first component in the port that is *stateful by construction*
whether or not anything uses the state — upstream creates the show-all state unconditionally and the port
keeps that — and that has a consequence worth stating plainly rather than discovering later: **the jsdom
harness cannot render it at all.** That harness renders static nodes; a component that needs the Bonsai
runtime is out of its reach. All of this component's checks are therefore in the browser gate, including the
structural ones the jsdom gate usually carries.

### The decision that made it small

An item renders its term and its value as a **fragment**, so the *grid on the list* decides whether they sit
side by side (two columns) or stacked (one column, two rows). Upstream instead tells each item, through a
React context, which layout the list chose. The port lets CSS do it, so nothing travels between the two — the
same resolution as InputGroup and ButtonGroup, for the same reason: a child is built before its container
sees it, so what the container would have said has to be CSS or the caller's decision.

The consequence is named in the interface rather than left to be found: upstream wraps a stacked pair in a
flex column with a half-step gap, and a grid row gap is a full step, so a stacked pair sits a *hair* further
apart here. A real difference in output, recorded as one.

### The bug the browser gate caught, and what it changed

Truncation. Upstream slices React *children*, so its `maxNumOfItems` cuts between items by construction. The
port's children are nodes, and an item is two of them — so slicing the flattened list at 3 rendered **3
`<dt>` against 6 `<dd>`**: a pair cut in half, which is not a truncation but a corrupted list.

The fix is in the type, not in the arithmetic. `view` takes `items:Vdom.Node.t list list` — each item is the
nodes it contributes — so the boundary truncation must respect is where it cannot be missed, and a caller
cannot accidentally pass a flat list. This is the first time in this port that a check failure changed an
API rather than an implementation, and it is the right kind of change: the constraint moved into the type.

### Checks (9, all in the browser gate)

| what | why it is here and not in jsdom |
|---|---|
| a real `<dl>`, six `dt` and six `dd` | the component needs the runtime to render at all |
| inline: two tracks, the label ends where the value begins | computed grid, which jsdom does not cascade |
| multi-column stacks (`6` of `6` values below their labels) | same |
| a fixed column count reaches the grid as a template | the inline style is the assertion |
| truncation renders the first N, with a toggle pointing at the `<dl>` | `aria-controls` is structural but the component is not renderable |
| both markers, on the list and on the item | the appearance contract finds components by marker |
| horizontal is a wrapping row, not a grid | computed `display` |
| **clicking the toggle shows all six; clicking again puts them back** | behaviour — this is the check the jsdom gate cannot make |

### What the failures were

Six failures across three runs, and **four were my checks, not the component**:

1. **The click checks raced the re-render.** They read the DOM immediately after clicking, saw three terms,
   and called a working toggle broken — the *next* read showed six. Fixed by waiting for the DOM to change
   and then asserting, so a genuine failure reports a mismatch instead of a timeout.
2. **The geometry check compared tops.** `align-items: baseline` means a pair's `dt` and `dd` tops legitimately
   differ by more than the tolerance. "Side by side" is `dt.left < dd.left`; "stacked" is `dd.top > dt.top`.
   Those are the claims, so those are what the check now asserts.
3. **The fixed-column expectation was the inline form.** Three columns makes the list multi-column, which
   defaults its labels to the top, so the template is `repeat(3, 1fr)` and not
   `repeat(3, auto minmax(0, 1fr))`. The component was right.
4. **And the counter I had just "fixed" was still failing** — because I had changed the check's *label* from
   61 to 60 and left its comparison at `=== 61`. That is the exact mistake recorded earlier in this project,
   made again in a different check. The lesson is not "be careful"; it is that a frozen counter has two
   halves and updating one is not updating it.

The other two were the counters themselves: the per-section example map needed `MetadataList: 5`, and the
navigation count moved to 46.

### Counts (verified, not asserted)

component **433/0** · browser **253/253** · demo **25/25** · responsive **66/0** at 0.00% across
320/375/768/1440 · coverage **43 of 103** (unported 60) · 43 appearance pages + `INDEX.md` · sweep exit 0,
0 FAILs, MCP layer truthful.

## Gate 37 — M23a: a controllable DropdownMenu (no new component)

Coverage **stays 43 of 103**, deliberately. This milestone moves a *mechanism* into an existing port, and a
count that moved for a mechanism would be counting the wrong thing — the same rule that left `897e39b` and
`af81ecd` at 41.

### What MoreMenu needs, and what it got

`MoreMenu` is 183 lines with nothing of its own: it is a `DropdownMenu` whose trigger is a specific Button, and
whose open state the *caller* may own. The port's `DropdownMenu` took a `trigger_label` and owned its state, so
MoreMenu could not be a thin delegation — it would have been a second implementation. This milestone removes
that reason, in two directions:

- **The trigger is configured, not hardcoded.** `?variant ?size ?icon ?is_icon_only` go to the trigger's
  `Button`, which already took all four (and `?component_name`, which is exactly what a delegating wrapper
  needs to keep naming itself — the IconButton rule).
- **The open state can be the caller's.** `?is_open` and `?on_open_change` come as a pair or not at all:
  neither, and the menu owns its state exactly as before; both, and the caller does. Passing exactly one
  **raises**, because a caller who passes `is_open` alone intends to control the menu and would otherwise get
  one that silently ignores it.

The refactor underneath is three lines: the only place the body touched the graph was `Bonsai.state`, so the
open state became an argument and the body never learned it changed.

### Verified: the first consumer is untouched

The proof that an extension is safe is the suite that already existed and was not edited — **433/0** component
and the whole dropdown keyboard path in the browser gate, unchanged. The new capability is proven separately,
and by the only method that can prove *control*: **the demo's own button opens and closes the menu**, and the
trigger's `aria-expanded` follows. If the menu still owned its state, that button could not move it.

### Named, not filled in

Upstream's trigger also takes a **tooltip** (MoreMenu passes the label) and renders a **chevron** unless
`hasChevron` is false; upstream's `placement`/`alignment`/`presentation` choose where the surface sits. The
port's trigger renders no chevron, no tooltip, and positions from CSS — all three named in the interface,
because a gap that is written down is a decision and a gap that is not is a bug waiting to be found.

### The failure was mine, and it taught me the component

My icon-only check asserted a *visually hidden label*; the trigger's `textContent` came back as the glyph with
no label node at all. The port makes the label the **accessible name** (`aria-label`) instead of rendering it
hidden — a different and better implementation, and the check now asserts that: named for a screen reader,
nothing painted. Third milestone in a row where the check was wrong and the component was right. That ratio is
the reason the checks are written to print what they saw.

### Counts (verified)

component **433/0** · browser **257/257** · demo 25/25 · responsive 66/0 · coverage **43 of 103** · sweep exit
0, 0 FAILs, MCP layer truthful. **M23b (`MoreMenu` itself) is now a thin wrapper.**

## Gate 38 — M23b: MoreMenu (coverage 43 → 44)

The thinnest component in the library, and the one that took the longest to become possible. `MoreMenu` is 183
lines upstream that hold **no behaviour at all**: it is a `DropdownMenu` whose trigger is a ghost, icon-only
button and whose open state the caller may own. It could not be a delegation until the menu underneath could be
configured and controlled, which is what M23a added — and this milestone is that delegation, with nothing
invented in between.

### What the port's version actually is

One call, threads its arguments through, and returns. The four things it *decides* are: the trigger's defaults
(ghost, `Md`, icon-only), the label's English default, the fallback glyph, and the marker.

That last one is the load-bearing decision. The trigger is a Button; the component the user is looking at is
MoreMenu. Passing `~trigger_component_name:"MoreMenu"` down means the marker says what the user sees, which is
the IconButton rule and the reason the appearance contract, the DOM gate and the browser gate can all find this
component at all. A delegating wrapper that did not name itself would be **invisible to every tool here** — the
failure mode is silent, which is why the first check is the marker.

### Checks (6, all browser)

| what | why |
|---|---|
| the trigger's marker is `MoreMenu`, not `Button` | the delegation rule; silence here is the failure mode |
| the label is the accessible name and the glyph is not text | icon-only, checked by what is painted |
| a label of its own becomes the accessible name | the pass-through reaches ARIA, not just the class |
| clicking the delegated trigger opens the menu | the delegation end to end |
| it is controllable from outside | M23a's capability survives the wrapper |
| — and all six passed on the first run | worth recording, because the last three milestones each cost a round of my own check bugs |

### Named, not filled in

The label's default is the English string upstream's i18n catalogue holds (no catalogue here); the default icon
is the character `⋯` in an `aria-hidden` span, because this port's 30-icon set has no `moreHorizontal` glyph;
`hasChevron` has no counterpart since the port's trigger renders no chevron in any case; and
`placement`/`alignment`/`presentation` stay unported, the same gap `Dropdown_menu` names.

### Counts (verified)

component **433/0** · browser **263/263** · demo 25/25 · responsive 66/0 · coverage **44 of 103** (59
unported) · sweep exit 0, 0 FAILs, MCP layer truthful.

## Gate 39 — ProgressBar (M24): a value on a track, and marks you can reach

Coverage moves **44 → 45 of 103**. Chosen by measurement rather than by name: `Spinner` looked like the small
one (647 lines) and turned out to be an SVG arc driven by the **Web Animations API** with `CSS.registerProperty`
and a timeline-origin pinning trick — a mechanism, not a component. `AvatarGroup` (475) needs `Avatar` (1408).
`ToggleButton` needs the layer-scoped context, `SegmentedControl` needs the press-feedback pillar, `Breadcrumbs`
needs the Link family. `ProgressBar` is 667 lines whose only dependency is **Tooltip**, already ported.

### The shape that matters

The `role="progressbar"` sits on the **track**, not the container, and the label is *outside* it, naming the bar
through `aria-labelledby`. That is upstream's shape and it has a consequence worth checking: a label hidden from
view still names the bar. The numbers — `aria-valuenow`, `aria-valuemin`, `aria-valuemax`, `aria-valuetext` —
are omitted **entirely** when the bar is indeterminate, because a position on a track that has no position is
not a position. The animation the bar uses instead stops under `prefers-reduced-motion`.

Marks are labelled points: each is a focusable tick that stays **outside** the progressbar role, so a screen
reader reaches each mark's label without the bar's own value being announced again — and each is wrapped in the
port's Tooltip, which is the only stateful thing here and the reason the component takes a graph at all.

### Checks (7, browser only)

| what | how |
|---|---|
| the role is on the track, and is not on the root | DOM |
| the numbers are the value, and the label names it | `aria-valuenow=60`, `valuetext="60%"`, `aria-labelledby` matches the label's id |
| the fill is 60% of the track | **measured** width against the track's box, not a class |
| the value label reads back the formatted value | DOM |
| indeterminate reports no value and clips an animating band | reduced-motion aware (see below) |
| every mark is a focusable tick, labelled, outside the role | `closest('[role="progressbar"]') === null` |
| focusing a mark reveals **its own** label | the anchor's `aria-describedby` → the message element |

### Four failures, and what each was

1. **A real gap in the component: the `~id` never reached the root.** It named the label and the marks, so
   nothing could find the bar by the name the caller gave it — the *exact* gap MetadataList had one milestone
   ago, found the same way (a check that queries by id and gets `null`). Fixed in the component, and recorded
   in the interface.
2. **The animation check asked the wrong question.** This harness runs with `reducedMotion: "reduce"` — which is
   in the gate's own launch options, three hundred lines above where I was reading — so `getAnimations()` is
   empty *by design* and the CSS was right. The check now asserts both branches: animating when motion is
   allowed, `animation-name: none` when it is not.
3. **The tooltip check took the page's first `[role="tooltip"]`** and reported a browser message
   ("Your administrator manages this setting") as if it were a mark label. It has to be scoped to the mark.
4. **And even scoped to the mark, it read the wrong element**: `aria-describedby` lives on the Tooltip's own
   wrapper, not on the node the caller passed in. Both are now asserted through the anchor.

Three of the four were the check. That is four milestones running where a failing check was mine more often
than the code's — and in every case the failure taught me a real fact about the component or the harness that I
would otherwise have written down wrongly.

### Counts (verified)

component **433/0** · browser **271/271** · demo 25/25 · responsive 66/0 · coverage **45 of 103** (58 unported) ·
sweep exit 0, 0 FAILs, MCP layer truthful.

## Gate 40 — Avatar (M25): a picture with a fallback, and a status the role cannot prune away

Coverage moves **45 → 46 of 103**. The directory is the unit: `AvatarStatusDot` is a file inside `Avatar/`, not a
directory of its own, so the milestone is one component however many files it is made of — the same rule that
made `Breadcrumbs` thin and its sibling heavy, and `Overlay` four files wide.

### The shape that matters

Four display states, in order: the image; the **fallback source** once the first has failed; the **initials** from
the name; and the **default icon** when the name yields no initials at all — because the alternative is an empty
plate. Each attempt reports into its *own* cell.

The status is the interesting part. A `role="img"` root prunes its descendants, so a status dot inside an avatar
is unreadable on its own — which is why the avatar composes the status's label into its own accessible name,
`"Ada Lovelace, Online"`. That is upstream's WCAG 4.1.2 justification, in upstream's own comment, and it is the
reason the dot is deliberately unlabelled in the showcase: a labelled dot inside a labelled avatar announces the
same thing twice.

### The bug, which the gate found and I had argued against

I simplified upstream's two error cells into one — "the most recent source that failed" — and wrote in a comment
that the two were equivalent for the only question being asked. **They are not.** With one cell the chain loops:
the first source fails, the fallback fails, the cell now names the fallback, the first source therefore looks
healthy again and is rendered a second time. Round and round, with the initials never reached.

The gate caught it as `{"images":1}` on a check that waits four seconds for initials that were never coming.
Upstream keeps one cell per attempt, and each cell holds *that source's own value* rather than a flag, which is
also what gives a changed source a fresh try. Restored, with `Bonsai.both` pairing each value with its setter.

I had also reasoned my way into a second error and the gate caught that too: **a data URI always loads.** A
malformed one merely fails to *parse*, and a parse failure fires no `error` event at all — so the example's first
version could never fall back, no matter how long the check waited. The sources are real 404s now.

### And the gate's own checks needed a carve-out

A component whose behaviour *is* "these two sources fail" makes the gate's own "no 4xx/5xx" and "no console
errors" checks fail by design. The 4xx check now allows those two paths **by name** and still fails on any other;
the console check defers to it, since a resource error is the one thing a deliberately failing source is supposed
to produce. A check that cannot express "this failure is the point" would have forced the example to be deleted.

### Also corrected

- **Five named sizes, not three.** Upstream's ladder is `xsm` 20, `sm` 24, `md` 36, `lg` 48, `xl` 128. My first
  draft guessed three.
- **The initials' font is 40% of the avatar's size** — upstream documents the ratio and the arithmetic
  (24px → 9.6px, 48px → 19.2px, 128px → 51.2px).
- **The circle-mode status offset is exact**: `(1 - 1/√2) / 2` = 14.6447%, which puts the dot's centre on the
  circle's edge at 45°, mirrored under RTL because the inset it hangs off mirrors.
- **`Avatar_status_dot` never reached the entry point.** My insert script's condition matched nothing useful, and
  the build caught it — not the registration script's cheerful "registered".

### Named divergences

The hover tooltip is a `title` attribute rather than the Tooltip component, because the port's Tooltip takes a
**static** trigger and this root is computed from its image state; widening Tooltip's interface to take a
computation is a real job and is not hidden here. The link-component seam (`as`) is absent. The i18n separator is
a literal `", "`. `themeProps` has no counterpart. The image error chain is why the component takes a graph, so
its checks live in the browser gate — where an image error can actually be fired.

### Counts (verified)

component **433/0** · browser **279/279** · demo 25/25 · responsive 66/0 · coverage **46 of 103** (57 unported) ·
sweep exit 0, 0 FAILs, MCP layer truthful.

## Gate 41 — AvatarGroup (M26): a facepile, and the margin that survives a wrapper

Coverage moves **46 → 47 of 103**. The directory is the unit again: `AvatarGroupOverflow` is a file inside
`AvatarGroup/`, so the pair is one coverage entry.

### The recon answered a question I would have guessed wrong

I went in expecting to port a resize-measurement mechanism — measure the container, work out how many avatars
fit. Upstream's own doc comment says the opposite: *"Consumers handle slicing — pass only the avatars you want
visible, then add an AvatarGroupOverflow for the '+N' indicator."* There is no measurement to port. I had a
whole divergence planned around machinery that does not exist, and reading two paragraphs removed it.

### The margin is on every member, including the first

The overlap is upstream's `round(size * 0.25)` — 9px at medium, 12px at large, both now asserted against
measured geometry rather than a class name. Upstream applies it as a negative **inline-start margin on each
member**, not as a negative margin on the container, and its comment gives the reason: a container margin is
defeated the moment a member is wrapped in something of its own, which is exactly what a Tooltip does.

That is the third time this class of problem has appeared in the port — ProgressBar's mark anchors collapsed to
zero height inside the Tooltip's wrapper, and the fix there was to move the positioning onto the wrapper. The
lesson is the same one, arriving from a different direction: **anything you do to a container survives only
until something wraps its children.**

### Three real findings the checks forced

1. **The roving mechanism was inert.** `Common.List_focus`'s default item selector is `button, a[href],
   [tabindex]` — which matches ButtonGroup's members perfectly and matched *nothing* in a facepile, because an
   avatar is a plain `<div>` and nothing had ever given it a tabindex. The check that noticed was "one tab stop,
   with the members behind it": every member reported `tabindex: null`. The group now names its members
   explicitly. The mechanism was ported, correct, and doing nothing — a failure mode that no amount of reading
   the mechanism would have revealed.
2. **The chip was 8px too tall.** `content-box` puts the 2px border *outside* the height, so a chip meant to
   match a 36px avatar measured 44px and stood out of the row. `border-box` now, so the number set is the size
   the row sees.
3. **The section and the group share an id**, so the check found the section and reported `role: null`. My bug,
   not the component's.

### What the group deliberately cannot do

Upstream provides `size` and `shape` to its members through context, so setting them once sizes the whole
facepile. The port has no contexts by design — the same rule that left Toolbar's `SizeProvider` named as a
divergence — so the caller passes size and shape to each avatar, and the group's own `size` decides the one
thing it can: the overlap. Named in the interface, not hidden.

The group takes *already-rendered* avatars, which keeps it a function of nodes rather than of the graph — and
that is why this component's structural checks can live in the jsdom gate **and** its behavioural ones in the
browser gate, where the overlap and the arrow keys can be measured for real.

### Counts (verified)

component **433/0** · browser **286/286** · demo 25/25 · responsive 66/0 · coverage **47 of 103** (56 unported) ·
sweep exit 0, 0 FAILs, MCP layer truthful.

## Gate 42 — ToggleButton (M27): a button that stays down, and why it has to be a pure view

Coverage moves **47 → 48 of 103**. The directory is the unit: `ToggleButtonGroup` is a file inside
`ToggleButton/`, so the pair is one entry. It wraps the port's own `Button`, which is why 629 lines of upstream
came to very little new code.

### The design decision, and how it fell out

The component takes a **graph** if it uses the port's Tooltip, and `is_pressed` is state the caller re-renders
on. Those two facts cannot both hold: a view that reaches for the graph cannot be re-run when the value
changes, because a graph is linear. So the choice was between a tooltip and a working toggle, and the toggle
won — `view` is now a pure function of its value, and the icon-only tooltip is a `title` attribute, which is the
same call Avatar made for the same reason.

The consequence is a gain rather than a cost: a pure view is a function of nodes, so this component is
**static**, which means the jsdom gate can render it — the first component in several milestones where that is
true.

### The pressed style: I had it exactly wrong

I wrote a pressed style with a background change and an inset border, and invented two tokens for it, neither of
which exists. The check caught it by measuring the background, finding it identical to the resting one, and
failing.

Upstream's entire pressed style is:

```
pressed: { fontWeight: fontWeightVars['--font-weight-semibold'] }
```

The label simply goes semibold. **And that is why the width reservation exists**: a semibold label is wider than
a medium one, so a row of toggles shuffles sideways every time one goes down. I had already recorded the
reservation as a named divergence because the port's `Button` owns its label and the two copies would have to
share a grid cell; now that divergence has a *visible* consequence rather than a theoretical one, and the
interface says exactly what it is. The check measures the weight, which is the real thing.

I also dropped the `data-state` attribute I had added. Upstream has no such attribute, and the styling hangs off
`aria-pressed` — one source of truth for "is this button down", and one fewer invented detail.

### A doctrine rule became an assertion

`Button.view` takes `?component_name`, which exists so a wrapper can name *itself* in the marker rather than
inheriting the marker of the thing it wraps. That has been doctrine in this port since IconButton and MoreMenu;
here it is a **check**: every toggle in the group must report `data-astryx-component="ToggleButton"` and not
"Button". A rule that only lived in prose is now enforced.

### Checks (7, browser)

a named group with `aria-orientation` · every toggle naming itself · a **real click** pressing one and only one ·
the pressed weight following the announced state · an icon-only toggle whose label is both its name and its
hover text · the icon swap · a vertical group saying so in ARIA *and* in computed layout.

### Counts (verified)

component **433/0** · browser **293/293** · demo 25/25 · responsive 66/0 · coverage **48 of 103** (55 unported) ·
sweep exit 0, 0 FAILs, MCP layer truthful.

---

## Gate 43 — SelectableCard (M28): the card that carries its own checkbox, and the process error that came first

Coverage moves **48 → 49 of 103**. The directory is the unit: `SelectableCard` is one entry, and its
upstream dependencies (`useClickableContainer`, `useMergedRefs`) are mechanisms rather than components.

## First, the mistake — because the fix is the interesting part

I picked this milestone by measuring **upstream's** component directories and choosing the smallest that
was not blocked, landing on `TextArea` (713 lines, one file, reusing the port's own `Field`). I then wrote
a fresh `src/text_area.ml` and its `.mli`.

**TextArea had been ported at M12.** It was in `port.json.ported`, in the port's own coverage count, and
already exported from `src/astryx.ml` — twice, as `Astryx.Text_area` *and* `Astryx.TextArea`. My
registration script's idempotence guard printed nothing because the name was already there, and I read that
silence as a no-op instead of as the signal it was. The overwrite replaced a 157-line working component
with a 109-line one that dropped the `size` type the showcase demo had been using since M12.

What caught it was a **consumer**: `dune build` failed on `Astryx.TextArea.Sm`, unbound, from the showcase —
not from the component's own gates, which were perfectly happy with the replacement because the module
still compiled, still stamped its marker and still rendered. Recovery was `git checkout -- src/text_area.ml
src/text_area.mli`: the damage was confined to uncommitted work, and `port.json`, the generators and `HEAD`
were all untouched because I commit each milestone before starting the next.

The rule this earns (now step 0 of the port's ritual, in the skill): **ask what the port already has before
measuring what upstream has.** `port.json.ported` is the authority, and it is a diff against
`registry.json` — so the selection question is answered by a set difference, not by a line count. Measuring
upstream answers "what is small upstream?", which is not the question.

The vetted list is now generated rather than eyeballed:

- registry **103**, ported **49**, unported **54** — and 49 + 54 = 103, the arithmetic the coverage panel
  displays.
- Sizes from the new method are a **lower bound**: it walks the component's own directory, and
  `ScrollableArea` reads as 286 lines when its mechanism actually lives in five modules under shared
  `hooks/` (1,330 lines). A component whose weight is in shared machinery will always look cheap this way.

## The component

`SelectableCard` is a `Card` with selection on top, and its accessible design is the elegant part: **the
card surface is a plain `<div>` with no role and no tabindex**, and a visually-hidden
`<input type="checkbox">` inside carries the role, the accessible name and the checked state. Native
checkbox behaviour (Space, the focus ring, the form association) then comes for free, and the container has
no semantics of its own to get wrong.

The click rules are the mechanism, and they are ported literally:

- A click on the surface toggles the selection.
- A click on a **nested interactive element** is left alone, so it does not fire twice. Upstream's
  `INTERACTIVE_SELECTORS` list is ported as a constant. The root carries `data-pressable-container`, and
  that attribute is *in* the list — so a child's `closest()` finds the root, which is exactly why the
  comparison against the root is not decoration: it is what keeps the surface's own clicks from counting as
  interactive, while a genuinely nested clickable container still does.
- A click that **ends a text selection** is ignored, so dragging to select a card's text never changes the
  selection. Only a non-collapsed selection anchored inside the element counts.

`Enter` is added by hand and `Space` is not: a native checkbox already answers Space, and adding it here
would toggle twice. That asymmetry is upstream's, and it is the reason its keydown handler exists at all.

**`Card` gained `?component_name` and `?attrs`** — Button's delegation marker, verbatim. Upstream stamps
`selectable-card` rather than inheriting Card's name, and every tool in this repo identifies a component by
that marker, so a wrapper that keeps its delegate's name is invisible to all of them. Passing the attribute
through `attrs` does not work: two attributes of one name meet and one silently wins. A check in the browser
gate now asserts the marker is `SelectableCard` and *not* `Card`.

## Named, not faked: the touch press model

`usePressFeedback` looks like a 52-line hook and is not: it stands on `utils/pressFeedback.ts` — **461
lines** — plus a gesture module and the CSS arms that read it. It installs one document-level controller
with six listeners, writes `data-astryx-press="on"`/`["fading"]` on the innermost pressable surface, and
carries a real state machine: an onset delay, cancels for travel and for scroll, a "brake, not a press"
heuristic for a finger landing on a list it set moving, a second-finger rule, pointer-type gating and
three seconds of gesture memory.

This port emits the contract attribute (`data-astryx-pressable`) and paints the **mouse** press through
`:active`; a touch press does not paint. That is the same shape of divergence the overlay family carries for
`Layer`: the markup contract is honest, the platform-backed half works, and the missing half is named in the
interface rather than approximated. Porting the model is a campaign on the scale of `Layer`, not a milestone.

## What ran

`sweep-m28a.txt`, on the committed tree:

- compile — `dune build: exit 0`
- component gate — **433 checks, 0 failures**
- jsdom gate — ALL CHECKS PASSED (unchanged: this component has no jsdom fixture, and the last several
  milestones are browser-gated for the same reason — its behaviour is DOM interaction, which jsdom has no
  click-to-toggle for and no keyboard for)
- real browser, showcase — **306/306, 0 failures** (up from 293; the additions include the eight new
  SelectableCard checks)
- real browser, demo — **25/25, 0 failures**
- responsive + visual regression — **66/66** at 0.00% differ on 320×568, 375×667, 768×1024 and 1440×900
- MCP layer — every ported component reported truthfully
- **sweep exit 0, 0 FAILs**

The responsive baseline was **re-baselined deliberately** before this run, because one section was added and
the coverage panel's text is part of every screenshot. That is a re-baseline, not a pass: the 0.00% above is
from the run *after* the update, which is the run that can detect a regression.

Coverage is **49 of 103** with **54 unported**; 49 component appearance pages plus `INDEX.md`.

---

## Gate 44 — ClickableCard (M29): the second consumer, and the name the gate found missing

Coverage moves **49 → 50 of 103**. This milestone has two halves, and the first was committed on its own.

## Half one: the mechanism moved, and the move was proved by not changing anything

`ClickableCard` needs exactly the logic `SelectableCard` was carrying: the interactive-target test, the
text-selection rule and the canonical selector list. That is the **second consumer** — the condition this
port names for a helper becoming a mechanism — so all three moved into `Common.Clickable_container`.

The move was made by *slicing the region out of the file and re-indenting it*, not by retyping it, because a
transcription error in a JS predicate would be invisible to every structural check. `Selectable_card` then
re-binds the two names it uses (`let is_interactive_target = Clickable_container.is_interactive_target`), so
**no call site changed** — and that is the point: the evidence that this was a move rather than a rewrite is
that the suites that already existed pass *unchanged*.

They do: component **433/0**, jsdom **ALL CHECKS PASSED**, browser **306/306** — the same numbers as before
the extraction, on the same tree. Committed separately as `3da85f8`, `Extract the clickable-container rules
into Common (no coverage change)`, because **a milestone that moves a mechanism moves no number**. Keeping it
in its own commit is what makes the proof checkable later: that commit's tree can be re-run and the same
numbers have to come back.

## Half two: the component

`ClickableCard` is `Card` plus **one visually-hidden interactive element** — an `<a>` when there is an
`href`, a `<button>` when there is not — which carries the accessible name. The surface stays a plain
`<div>`, so the card is operable as a link or a button by assistive technology while looking like a card.
Its clicks run through the extracted mechanism.

### A real bug, caught by reading the DOM back rather than by a structural check

The first browser run failed on the link card with `label: null`: **the anchor had no `aria-label`.** The
class list was right, the `href` was right, `tabindex="0"` was right, the visually-hidden class was right,
the marker was right — and the card's only interactive node was an **unnamed, empty, visually-hidden
link**. A screen reader would have announced nothing.

The lesson is the one this port keeps re-learning in different costumes: **the element a screen reader
announces is the hidden one, not the `div` around it** — so the name, the role and the state all belong on
that element, and a check that reads the container's attributes proves none of them. It was found by
asserting the *value* of the label rather than its presence, and fixed by putting `aria-label` on the anchor
unconditionally, which is what upstream does.

### A deliberate difference from copying the JSX: the attribute is gated, not only the navigation

Upstream hands its `href` to a framework link component and lets **React vet the hrefs it writes as
attributes** — its own comment says so, in the place where it explains that nothing *below* passes through
React. The port has no framework link component and no React, so copying the JSX would have written an
unvetted `href` into the DOM: a `javascript:` href would be a **live sink** even though this component's own
click path refuses it.

So the port gates the attribute as well as the navigation, using the same predicate the rest of the port
already uses (`Citation.is_safe_url`, where the port put its security control). A refused value **renders
inert** — no `href`, `role="link"`, `aria-disabled="true"`, `tabindex="-1"` — which is this port's existing
rule for a refused value: it renders inert rather than disappearing. The gate asserts it directly:

> a `javascript: href` renders INERT — no href attribute reaches the DOM

This is a change to upstream's *behaviour* and is recorded as one in the interface, not hidden as an
implementation detail.

### Named divergences

- The touch press model is not ported, on the same terms as `Selectable_card`: the contract attribute is
  emitted and the mouse press paints through `:active`; a touch press does not paint.
- A native `<a>` in place of a framework link component, so navigation is a real document navigation rather
  than a client-side transition.

### Two mistakes of mine in the checks themselves

Both are the ordinary kind and both were caught by the gate rather than by me:

- I asserted the *disabled* card would render a link with `tabindex="-1"`, but the demo's disabled card had
  no `href` — so it correctly rendered a **button**. The check was wrong, not the component. The demo now
  gives the disabled card an `href`, which exercises the interesting path (the disabled *link* treatment:
  no `href`, `role="link"`, `aria-disabled`, out of the tab order).
- One check read `cards.every(...)` and therefore **passed vacuously on an empty array** — the exact failure
  the earlier gates were built to avoid. It now requires the length too.

## What ran

`sweep-m29a.txt`, on the committed tree:

- compile — `dune build: exit 0`
- component gate — **433 checks, 0 failures** (unchanged, and that is the point)
- jsdom gate — ALL CHECKS PASSED
- real browser, showcase — **312/312, 0 failures**
- real browser, demo — **25/25, 0 failures**
- responsive + visual regression — **66/66**, 0.00% differ on all 8 page/viewport pairs (320×568, 375×667,
  768×1024, 1440×900)
- MCP layer — every ported component reported truthfully
- **sweep exit 0, 0 FAILs**

The responsive baseline was re-baselined deliberately before this run (a section was added, and the coverage
panel's text is part of every screenshot), and the 0.00% above is from the run *after* the update — the run
that can detect a regression.

Coverage is **50 of 103** with **53 unported**.

---

## Gate 45 — the fit arithmetic behind an overflowing list (a mechanism, no coverage change)

**50 of 103 still**, deliberately: this is a mechanism, and a milestone that moves a mechanism moves no
number. It is recorded because it is verified, not because it changed the count.

`OverflowList` is the next component by the vetted list, and it is the only unported candidate with **no
unported component dependency** — everything else is blocked on a real pillar (`Thumbnail` and `FileInput`
on `Spinner`, `Token` on `Link`, `List`/`SegmentedControl`/`Lightbox` on `Layer`, `Pagination` on
`NumberInput` + `Selector`, `Banner` on `Collapsible` + `Layout`). Its weight is not the 421-line component
but the measurement engine under it: a 274-line `useOverflow` hook over a shared `ResizeObserver`.

So this is the mechanism before the component, which is this port's ordering rule. Upstream keeps the fit
arithmetic in a file of its own **with no DOM and no React**, for a stated reason — it can be reasoned about
and tested in isolation — and that split is exactly what makes a bounded slice possible: `src/overflow_math.ml`
is that file, ported whole, and it needs no browser to verify.

### What it decides, and the two rules worth porting rather than approximating

One source of truth: `visible_count = clamp (fit_count, min_visible_items, max_visible_items ?? item_count)`.

- **The floor wins.** When the ceiling is below the floor, the final clamp takes the floor. Upstream's hook
  warns about the contradiction in development; the arithmetic resolves it. A case has a ceiling of 1, a
  floor of 2 and room for nothing — and the answer is 2.
- **The indicator is reserved for every non-final admitted item**, not merely the last one: a line that fits
  without room for the "+N" marker is not a line that fits. Two cases differ only in the marker's width, the
  narrower answer being one item *more*.

### How it is verified without a browser

It is a pure function of plain measurements, so the gate drives it as **rows carrying both the expectation
and the port's answer**, and compares two numbers it can both see — the same shape the safe-url matrix uses.
Eleven cases, chosen to pin rules rather than the happy path: the floor beating the ceiling, the reserved
marker changing the answer, a ceiling above the item count as a no-op, the multi-row packing (including the
last row reserving room), `collapse_from` keeping the opposite end (`[500; 10; 10]` at 100px gives 0 items
from the end and 2 from the start — asymmetric on purpose), and the empty list.

**Two mistakes of mine, both caught by the gate rather than by me.** The rows rendered but the selector
matched none of them, because `Common.Attr.data` writes `data-astryx-…` rather than `data-…`; the check that
compared expectations then **passed vacuously on an empty list** — the same trap this port fixed in the
ClickableCard checks one milestone earlier. The count assertion is what caught it. And the first version
inserted the checks *after* the gate's summary line, so they ran and reported but were missing from the
tally the docs cite: 435 checks were happening while the transcript said 433. Both are fixed; the tally is
now the number of checks that actually ran.

### What ran

`sweep-m29b.txt`, on the committed tree: build 0 · component **435/0** · jsdom ALL PASSED · browser
**312/312** showcase and 25/25 demo · responsive **66/66** at 0.00% · MCP layer truthful · **exit 0, 0 FAILs**.

Next: the resize hook that measures for it, then the component.

---

## Gate 46 — the gate sweep now fails when a gate fails (a harness fix, no coverage change)

Not a component, and it moves no number. It is recorded because it was a **defect in this project's own
harness**, and because a harness that reports green when red is worse than no harness at all: it makes
`exit 0` mean nothing, and `exit 0` is the kind of clean-looking evidence a claim gets built on.

### The defect

`tools/gate-sweep.sh` could only ever fail on **step 1**. Every later gate wrote its transcript and had its
status discarded, and the last thing the script did was `wc -l`, which always succeeds. So a red browser,
responsive, component or MCP gate still ended at `sweep exit 0`.

It was found by reading a stale sweep notification from M24 — whose responsive gate genuinely *did* fail at
the time — and noticing that the transcript's last line said `sweep exit 0` directly under
`RESPONSIVE CHECKS FAILED`. Every green claim this session was in fact resting on the **FAIL count**, which
I was grepping by hand each time. That is exactly the manual work a harness exists to remove, and the
manual check is the only reason nothing was ever reported red as green.

### The fix

Each gate's status is captured immediately after it runs; a result block prints one line per gate; the
script exits 1 if any failed, naming them. Step 1 remains a hard stop, because if the build fails nothing
downstream can mean anything — the sweep ends there rather than writing six transcripts of consequences.

**The subtle part:** the showcase and demo browser runs share one transcript, so a group-level status would
have come from whichever ran last — a showcase that failed while the demo passed would have been red-then-
green, i.e. invisible. Their statuses are captured separately and both reported.

### The verification: the harness was tested by making it fail

A fix to "the harness lies" is worth nothing unless the failure path is demonstrated, so it was: with the
showcase HTTP server on :8791 stopped on purpose, the sweep was run and had to produce a red result
**attributed per gate** — not blanket red. It did. Exactly the three gates that need the server failed; the
four that do not passed; exit 1. That output is kept verbatim as
`docs/verification/sweep-red-verification.txt`, because a claim about the harness's behaviour should be
backed by a transcript the same way a component claim is.

The server was then restarted and the real sweep re-run: **SWEEP GREEN: every gate passed, exit 0**, with
the counts above.

### The related trap, worth knowing

`grep -c "FAIL"` exits **1 on zero matches**. That is what produced the "exit code 1" on several stale sweep
notifications that had in fact passed every gate — a failed *grep*, not a failed sweep. Two different
exit codes meaning two different things is how a project learns to stop trusting exit codes; both are now
explicit in the script's own output rather than left to be inferred.

---

## Gate 47 — OverflowList (M30, coverage 50 → 51)

A list that shows what fits and collapses the rest behind an indicator. Three parts, in the order this
project's rule requires — the mechanism before the component that wraps it:

1. `Overflow_math` (Gate 45) — the fit arithmetic, ported as a pure function with eleven cases in the
   component gate. No DOM, no state, no browser.
2. `Common.Overflow_hook` — the measurement. It measures the element it is attached to and that element's
   children and hands the numbers to the arithmetic.
3. `Overflow_list` — the component, built on upstream's two-container shape.

### The design decision, settled with evidence rather than preference

Upstream's measurement stands on a module-level, ref-counted `ResizeObserver` registry shared between
every observed element. **Not ported, deliberately.** The decider was whether a second consumer lands in
this port, and it does not: the port's `Text` contains no truncation or measurement code at all, where
upstream's `Text` is the registry's other consumer. With one consumer, porting a ref-counted singleton is
the pre-abstraction this project's rules forbid, so the hook owns an observer and the sharing is recorded
as the browser-performance divergence it is.

### The shape, which is not the obvious one

The items are rendered into a **hidden measurement container** — `visibility: hidden`, never `display:
none`, because a `display: none` element has an `offsetWidth` of 0 and every item measured through it
would read as zero, collapsing the count to nothing. The visible row renders only the slice. The
indicator is measured too, and is measured in that container with **every** item hidden, which is the
widest label it can ever carry, so the reserved room is never too little. The gap is read back off the
element's computed style rather than passed as a number, because upstream's gap is a spacing-scale token
whose pixel value lives in a theme this port does not have — so the applied gap and the measured gap
cannot disagree.

### Seven mistakes of mine, and what caught each

Recorded because the catching is the interesting part; six were caught by gates rather than by me.

- **The JS array was never converted to an OCaml list.** Returning an array through `fun_call` and typing
  it as `_ list` reads the array's first slot as the head and its second as the tail, so the second
  element is `undefined` and measuring it throws on `offsetWidth`. The browser gate's console-error check
  printed the stack, which pointed straight at it. Fixed with `Dom.list_of_nodeList`.
- **My checks ran against the demo page too.** They were inserted outside the `mode === "showcase"`
  branch, so ten of them failed against a page with no such section. Caught by **the harness fix from
  earlier in this same session** — the sweep reporting red per gate instead of exiting 0. Before that fix
  this would have shipped as a green-looking run.
- **The live-resize check found the example was not responsive.** A percentage width follows the *parent*,
  and the showcase's column is width-constrained, so a 700px wider viewport moved nothing. `vw` fixed
  that — and then the same check found `50vw` was vacuous, because all six items fitted at both widths so
  nothing collapsed and there was nothing to observe. A vacuous pass is worse than a failure, so the width
  now sits between the two answers.
- **A name collision**: `narrow` was already declared in that scope, so moving the block in produced a
  SyntaxError. Renaming then rewrote the string literals too, because a hyphen is a word boundary and
  `\bnarrow\b` matches inside `"overflow-list-narrow"`.
- **Three frozen counters**, not one: the section count (53 → 54), the example total (309 → 312) and the
  nav-link count (53 → 54). I had claimed no per-section count map existed; it does, and its comment
  explains why — "a total alone would not notice one section losing an example while another gained one".
- **A build failure reported as success**: `dune build 2>&1 | head -8 && echo BUILD OK` prints `head`'s
  status, so it announced success over an unused-variable error while the gate ran against a stale page.
  The same exit-code trap this project has now hit from both directions.

### What ran

`sweep-m30b.txt`, on the committed tree: **SWEEP GREEN: every gate passed, exit 0.** Build 0 · component
**435/0** · jsdom ALL PASSED · showcase browser **322/322** (ten of them this component's) · demo 25/25 ·
responsive **66/66 at 0.00%** · MCP layer truthful · coverage **51 of 103**.

The ten checks are not a formality. They assert the marker, that the measurement container is hidden **and
still has width**, that every item is in it *including* the ones that will not be shown, that the kept
items actually fit inside the row, that the indicator's count is exact, and that `collapse_from: Start`
keeps the other end at the same count. And two of them prove the **observer** rather than assuming it: a
window resize with no reload must show more, and the indicator must still tell the truth afterwards.
Loading the page at a wider viewport would have measured on mount and proved nothing.

### Correction to Gate 47: the coverage artifact was misattributed, and no gate could see it

This gate recorded "MCP layer truthful" — which was true of the check that exists. The artifact was not.

`port.json`'s `OverflowList` entry was created by copying its neighbour and substituting strings, and the
guard on that substitution was `if "ClickableCard" in value`. The lowercase fields never matched it, so the
entry claimed:

```
"component": "OverflowList",  "file": "src/clickable_card.ml",
"module": "Astryx.Clickable_card",  "milestone": "M29"
```

and `gen-port-status.py` faithfully propagated it into the generated `docs/PORT-STATUS.md`, where line 107
read `OverflowList | Astryx.Clickable_card | src/clickable_card.ml | M29`. A false claim in a generated
document is the exact thing this project keeps gates to prevent, and it got in through the one door with no
gate on it: the **source data**.

**Why every gate passed it.** The MCP truthfulness check asks whether each ported component is *reported*
as ported — it never asks whether an entry is attributed to itself. A check that cannot fail for the
reason the data is wrong is not covering that data. The browser, responsive, component and jsdom gates
read the DOM and the source; none of them reads `port.json`'s fields.

**Fixed three ways.** The entry now names its own file, module and milestone. The artifacts were
regenerated, and the doc line is correct. And the sweep gained a permanent check: every ported entry's
file must exist, and its module must be the one its own component name implies — underscores stripped
first, because the umbrella names some modules without them (`Astryx.AspectRatio` over `aspect_ratio.ml`).
That rule was run against the entry that shipped, and it catches it.

**The lesson worth keeping.** Do not derive a metadata entry by copying a neighbour and substituting
strings: write the fields from knowledge, and make the harness verify the parts that are facts. It was
caught by reading the output of the background job that made the edit — not by any gate — which is the
weakest possible way for a wrong claim to be found, and only luck made it happen at all.

---

## Gate 48 — the linkify walk (a mechanism; coverage stays 51)

The first piece of `Link`, and the first thing in this project that a *pure* function could be carved out
of before any browser was involved. It moves no coverage number, deliberately: the scanner that produces
the matches and the component that renders them are both still to write, so nothing is registered in
`port.json` and the count stays at 51.

### Why this half, in this order

`useLinkify` splits in two and upstream's split is the useful part: **finding matches needs a regex engine,
but cutting the text around them does not.** `segments_of_matches` is the second half, a pure function of
the text and the matches, so it is verified the way `Overflow_math` is — rows carrying both the expectation
and the computed answer, compared by the gate as two strings it can both display. No browser, no DOM, no
state.

### The three rules, which are the reason this is worth a gate

- **Matches sort by start position only**, and equal starts are decided by the order they were collected
  in — custom patterns before built-in ones. Upstream's comment says "sort by start position, then by
  earlier pattern priority (stable sort)" while its comparator compares nothing but `start`: the priority
  tie-break *is* the collection order, held in place by the sort being stable. Depending on stability
  deliberately means making the stability deliberate here, so it is `List.stable_sort`, and a case feeds
  two matches with the same start and asserts the earlier one wins.
- **The first match wins for overlapping ranges, and adjacency is not overlap.** A match beginning exactly
  where the previous ended is kept; `>=`, not `>`.
- **Nothing is emitted for a zero-length gap.** A match at position 0 produces no empty leading segment,
  and one ending at the last character produces no trailing one. Both are cases, because both are easy to
  get wrong and invisible when you do.

### The mistakes, which were all mine

Four, and three of them were things this repo had already written down.

- An unused `open Bonsai_web` in the interface — the module has no DOM in it at all.
- **`[@@deriving sexp_of]` is silently ignored in this project**, because the ppx set has no sexp deriver
  and an unknown attribute is not an error. This is exactly why `Overflow_hook`'s `sexp_of_t` is
  hand-written, a fact already recorded in the port's own notes, which I applied to that module and then
  forgot here. The fixture now renders each segment itself and the interface says why there is no deriver.
- **Two stop indices off by one**, from doing character arithmetic in my head: `"https://x.dev/a"` is 15
  characters from index 4, so its stop is 19, not 18; `"https://a.dev"` is 13 from index 2, so 15, not 14.
  The gate caught both by showing the two rendered strings side by side. This is the third time this
  session that a gate has caught my arithmetic rather than a defect in the code — which is the argument for
  comparing two values the harness can display.
- And the interface hid the derived functions, which is not a mistake but the `.mli` doing its job: an
  interface exports nothing it does not name, which is why the sexp functions were unbound from the test
  gate even after they were generated. Moot once the deriver turned out not to exist.

### What ran

`tests: 437 checks, 0 failures` — 435 plus these two — and then the full sweep on the committed tree:
**SWEEP GREEN, every gate passed, exit 0**, with all nine gates ok including the `port.json` attribution
check added after the M30 misattribution.

Next, in the order already recorded: the scanner, using JS `RegExp` for fidelity (testable in the component
gate, which runs under node), then the safe-link wrapper, then `Link` itself.

### Addendum to Gate 48: the README's counts are now read by a gate

Checking CI turned up a stale claim. The README's showcase row said "all 50 ported components, 309
examples, 53 sections" while the page it describes had 51, 312 and 54 — all three changed in this session,
and no gate read the row, which is why it went unnoticed. The row *above* it was made count-free for
exactly this reason; this one kept counts and went stale anyway.

It is also the reason the check below exists rather than a note asking people to be careful. The browser
gate now reads `README.md` and `port.json` and compares the row against the page it describes, and it was
verified the only way a check is worth anything — by putting the stale numbers back and watching it fail:

```
FAIL the README's showcase row matches the page it describes — README says 50/309/53, page has 51/312/54
```

A note about the commit that made the fix. Its message says the three counts "are asserted by the browser
gate", which was **false when it was written** — the gate asserted the page, never the README, and that is
precisely how the row went stale. It is true as of this addendum, because the check now exists. Commit
messages cannot be edited, so the correction lives here rather than in a rewrite; the alternative, softening
the sentence, would have left the gap in place and described it instead of closing it.

Also from the same check: the CI row named run `38995086208`, from the M29 era and thirteen commits back.
Still green, still true of the tree it named, but the watcher that re-points it had stopped. It is
re-pointed, the watcher is running again, and CI on the three commits before this one is confirmed
**completed/success**.

---

## Gate 49 — M31: Link (coverage 51 -> 52)

The first component in several milestones that is mostly *composition*. Four mechanisms were built and
verified on their own beforehand — the linkify scanner and its text-cutting walk, the destination handoff,
the interactive role, and target/rel normalization — so the component itself is an assembly of verified
parts plus the already-ported `Text` and `Icon`. That is the reason this landed in one sitting rather than
becoming a campaign, and it is the argument for building a mechanism before the component that wraps it.

### What ran

- `dune build` — clean.
- component tests — **445 checks, 0 failures**.
- DOM + accessibility (jsdom) — all passed.
- real browser, showcase — **331 checks, 0 failures**; demo — 25/25.
- responsive + visual regression — **66 checks, 0 failures at 0.00%** on a separate run after a deliberate
  re-baseline.
- agent layer — `ported entries: 52; correctly attributed: 52`, MCP truthful.
- **SWEEP GREEN: every gate passed, exit 0** (`docs/verification/sweep-m31c.txt`).

### Three findings worth more than the component

**1. A gate that asserts a generated artifact will agree with a stale one.** The coverage panel assertion
froze `["50", "53", "103"]` — **stale by two milestones**. The gate reads the rendered page, and the page
reads `site/coverage.json`, a *generated* file that had not been regenerated. So every green sweep in
between was agreeing with an out-of-date artifact rather than with `port.json`. Moving a number in
`port.json` was "verified" by a check that could not see it. Regenerated, it now asserts `52/51/103`.

**2. A label that lies about its own assertion.** The same check's *description* still read "coverage stats
are 50 ported / 53 not / 103 total" after its comparison had been updated. This repo already records the
mirror of this ("fix the assertion, not the label"); here the assertion was fixed and the label was left
lying, and nothing notices because only the comparison is evaluated. A transcript that states the wrong
number in prose is worse than no description at all.

**3. Upstream's comment and upstream's code disagree, and the code is right.** A check asserting "a
disabled link cannot take focus" **failed**. The port renders `tabIndex={-1}` — focusable but not
tabbable — so programmatic focus works. Upstream's comment says a disabled link "cannot be focused or
activated"; the code says `tabIndex={-1}`. The claim that matters is the comment's other half: focusing it
and activating it cannot **navigate**, which is what the missing href buys. That is now asserted by
clicking the disabled link and requiring the URL not to move — a check that would fail if the port wrote
the href. Recorded because the first instinct on a failing accessibility check is to change the component.

### Two placement failures, both silent

The browser checks were first inserted beside a *comment* rather than inside the *evaluation*, twice, and
both times the run died with `document is not defined` before printing a single check. That is a worse
failure than a wrong assertion: it names nothing, and the tally is unchanged, so the only evidence is a
stack trace in a transcript nobody is reading yet. The fix is to follow the file's dominant pattern — one
`page.evaluate` returning a plain object of facts, asserted in node scope — and the comment at the
insertion point now says so.

### Deliberate divergences

- **No `tooltip` prop.** The ported `Tooltip.view` takes a graph and returns a `Bonsai.t`, so accepting one
  here would make every link stateful, including those in pure trees, for a prop most links do not pass.
  Wrap the link in `Astryx.Tooltip.view`; the state is then the caller's.
- **No `LinkProvider`.** A React context, and this port's containers cannot reach children the caller
  already built — the same fact that makes `Form_layout` take `?optionality` per field. The component is an
  argument per link (`Link_destination.Routed`).

### The re-baseline, stated rather than implied

A new section adds **1201px of height at 320px and changes no width at any viewport**. The baseline was
updated deliberately, and then verified at 0.00% on a separate run; a baseline written on the same run
cannot detect a regression on that run, and the tool says so.


## Gate 50 — M32: Token (coverage 52 -> 53)

The first class-B component whose interesting surface is entirely the *role resolution* — the same
`Interactive_role` the Link gate built — plus the branch the M31 gate could not have exercised, because
a button nested inside an anchor is invalid HTML and that shape only exists when a token has a live
href *and* a remove button. The four branches, in upstream's order, and the reason the order is the
contract: a live href makes the anchor the root; href + remove swaps the root for a span so the link
and the remove button render as SIBLINGS (upstream's own reason: WCAG 4.1.2, and the port records that
the ref-bridged `useClickableContainer` delegation is not reproduced — the sibling shape is what
makes the markup valid, and only the link itself navigates); otherwise an `on_click` hides a real
button under a visible label with the root taking the focus-within outline and skipping targets
inside any button/anchor (upstream's `closest('button, a')` guard); otherwise a plain span.

### What ran

- `dune build` — clean.
- component tests — **464 checks, 0 failures** (2 checks fixed, below).
- DOM + accessibility (jsdom) — all passed.
- real browser, showcase — **338 checks, 0 failures**; demo — 25/25.
- responsive + visual regression — **66 checks, 0 failures at 0.00%** on a separate run after a deliberate
  re-baseline.
- agent layer — `ported entries: 53; correctly attributed: 53`, MCP truthful.
- **SWEEP GREEN: every gate passed, exit 0** (`docs/verification/sweep-m32b.txt`).

### Two broken test assertions, not broken code

The failing component gate reported two failures, both in the *assertions* rather than the port:

1. **"a live href makes the anchor the ROOT" asserted `linked === linked.parentElement`** — an element
   is never its own parent, so the check could not pass no matter what the port rendered. Corrected to
   `tagName === "A"`, no `--container` class, and `closest(".astryx-token") === linked` — the anchor is
   the token root. This was the fourth check for the same fact this file carried; three variants of the
   same claim is a smell, and the strongest one is the one that survived.
2. **"end content carries through" asserted `/\bx9\b/`** — no word boundary exists between `d` in
   "tailed" and `x` in "x9", so the regex could never match text that was verifiably present
   (`textContent === "tailedx9"`). Corrected to `includes("x9")`.

Both were verified against the real rendered DOM (jsdom, compiled bundle) before changing anything,
and both corrections were re-run in the full sweep. The lesson is the one the repo has recorded three
times: a check whose *comparison* cannot be satisfied is not a check, it is a transcript cost.

### The M31 marker gap, found by regenerating an artifact

Link — the component the previous gate recorded as green — never stamps `data-astryx-component`, the
port-wide marker every other component carries on its own root. Nothing asserted the absence, so the
M31 gate's green status stood while `docs/visual/` silently carried 52 pages for 53 ported components,
and the INDEX's footer — "Not listed: the N components with *no OCaml port*" — was a lie in the other
direction: it listed exactly the component that *was* ported. The appearance contract could not see
Link at all. Fixed by adding the marker to Link's own four branches (button, disabled anchor,
refused-anchor, native anchor). The custom `as_` branch is deliberately excluded: it stamps its own
marker (Button, RouterLink, …), and labelling a stranger's root "Link" would be a worse lie. Link
now has a visual-contract page (54 total, `docs/visual/Link.md`), and the original `grep` that found
this is now the kind of check the INDEX's own numbers would have caught had anything read them — the
stale-artifact class again: an unread generated index is prose with pixels.

### The re-baseline, stated rather than implied

A new section adds **~1590px of height at 320px** and changes no width at any viewport. The baseline
was updated deliberately on its own run (`--update-baseline`), then verified at 0.00% on a separate
run — a baseline written on the same run cannot detect a regression on that run, and the tool says so.

### Deliberate divergences

- **No `useTranslator`.** The remove button's accessible name is the English default
  `Remove <label>` (upstream's en source for `@astryx.token.remove`).
- **No `usePressFeedback` controller.** The constant `data-astryx-pressable` marker is reproduced (as
  SelectableCard and ClickableCard do); the document-level controller that writes `data-astryx-press`
  under a touch is the press-feedback pillar: a mouse `:active` paints, a finger does not.
- **Role step 3** (interactive trigger context) has no port — `effectiveOnClick = onClick ?? ctx-noop`
  reduces here to `on_click` itself.
- **The href passes `Link_destination`** — a refused destination renders the same markup without it.
- **`aria-description` is reproduced verbatim**, non-standard spelling and all — upstream writes it,
  and silently "correcting" it to `aria-describedby` would change the accessibility tree.

## Gate 51 — M33: Spinner (coverage 53 -> 54)

A loading indicator whose interesting surface is that it is *drawn* — the ring's geometry resolves in
the port, not in a stylesheet — and that it is *named* — a label changes which element is the status
root and how it is named. The geometry contract: the sizes table (sm 10/2, md 14/3, lg 18/3, xl 28/4;
box = ring plus the stroke on each side, so xl draws a 28px ring in a 36px box), ARC_FRACTION = 0.375 of
the circumference as the moving dash, and the dash's keyframe moving by exactly one circumference per
cycle (upstream's `dashMotion`: `0 -> -PI * diameter`). The naming contract: no label — the span IS the
status element, named by `aria-label` (explicit, else the English `Loading`); string label — the label
text becomes a `Text` below and names the status via `aria-labelledby` (never both at once, WCAG 4.1.2,
upstream's own comment); non-string label — cannot be referenced, so falls back to `aria-label` /
default exactly as upstream's `typeof label === 'string'` test would.

### What ran

- `dune build` — clean.
- component tests — **479 checks, 0 failures** (15 new Spinner checks).
- DOM + accessibility (jsdom) — all passed.
- real browser, showcase — **345 checks, 0 failures**; demo — 25/25.
- responsive + visual regression — **66 checks, 0 failures at 0.00%** after the deliberate re-baseline.
- appearance contract — regenerated; `docs/visual/Spinner.md` exists (56 pages).
- agent layer — `ported entries: 54; correctly attributed: 54`, MCP truthful.
- **SWEEP GREEN: every gate passed, exit 0** (`docs/verification/sweep-m33*.txt`).

### Geometry is drawn, not styled

The port emits the SVG presentation attributes (`r`, `stroke-width`, `stroke-dasharray`, box
`width`/`height`) from the sizes table, exactly like upstream's no-stylesheet render, so a render
before the cascade draws the right ring. The CSS layer then paints (shade colors off the public vars)
and moves the dash. The public geometry vars (`--spinner-diameter`, `--spinner-stroke-width`,
`--spinner-arc-fraction`) are themed here via the `--astryx-spinner-d` / `--astryx-spinner-w` pair
declared by per-size selectors; the arc's `calc()` reads its circumference inline as a real `<length>`
(the reason upstream registers the same var — a bare `0` poisons a `calc()` sum).

### The `%g` trap, caught before the gate ran

The md dasharray is `16.4934 27.4889` — `%g` 6-significant-digit formatting of `43.9823 * 0.375` and its
complement. The first check asserted `27.4890` (round by hand, wrong); corrected against Python's
`%g` before running — an asserted literal is prose unless it was computed the same way the code
computes it.

### Compatibility with the button's inline spinner

The port reuses the `.astryx-spinner` class name, which Button's loading state already uses for its
1em/2px border spinner (`.astryx-button--loading .astryx-spinner`). The new component's generic rules
are scoped to instances carrying a size modifier (`:is(.astryx-spinner--sm, …)`), so the button's
spinner — which never carries one — keeps its own look. The class namespace is the contract; the
modifier is the discriminator.

### Deliberate divergences

- **No `useId`.** `id` defaults to `astryx-spinner`; callers mounting many labelled spinners pass
  distinct ids (a repeated default id would make `aria-labelledby` ambiguous; upstream's `useId`
  cannot). `id` exists so the derived `id-label` stays stable and themeable.
- **No `useTranslator`.** The default accessible name is the English `Loading`
  (upstream's en source for `@astryx.spinner.loading`).
- **No `syncRotationPhase`** — the Web Animations pinning that keeps spinners mounted seconds apart in
  phase; the port's CSS animation starts each ring at its own mount.
- **No `CSS.registerProperty`** for the resolved geometry vars; the keyframes read the inline
  `<length>` circumference instead, which cannot be poisoned by a unitless `0`. Two mechanisms, one
  assurance, and the port's is the one that survives a missing stylesheet.
- **One theme target where upstream has two.** Upstream moves the theme target to the wrapper when a
  label renders; the port keeps the size/shade modifier classes and data attrs on the span in both
  branches, so a single themed rule works in both cases. Recorded in the source and in the CSS.
- **`label` and `label_node` are separate parts** (upstream's single `ReactNode` `label`): the port
  needs to know whether the visible label is plain text to decide `aria-labelledby`, which OCaml
  cannot infer from a `Vdom.Node.t`.

## Gate 52 — M34: Thumbnail (coverage 54 -> 55)

A square preview card whose four surface states are the contract, and whose interesting part is the
*state*: one cell remembers the exact source that failed, so a changed source starts a fresh load
instead of inheriting the stale error — upstream's `erroredSrc`, reproduced via `Bonsai.state` with
the same freshness test Avatar's image chain uses. The states: no source → placeholder silhouette;
loading with no known source → skeleton; loading with a source → the scrimmed upload overlay (a
Spinner); source present and not errored → the image. The remove button (when `on_remove` is set)
overlays the corner — revealed on hover and keyboard focus by default, always visible on
`show_remove_on = \`Always` — and is a real `Button`, so its scrim colours are fixed rather than
luminance-adapting. A label both names the group (`role=group`, name = `label` joined with `alt`
when both exist) and supplies the hover `title`; the remove button reads "Remove <name>", an
interactive surface reads "Open <name>" through a real `<button>`. An image without `alt` is
explicitly decorative (`alt=""` + `role=presentation` + `aria-hidden`), so the name comes from the
label alone, else the English "Thumbnail" fallback.

### What ran

- `dune build` — clean.
- component tests — **502 checks, 0 failures** (23 new Thumbnail checks).
- DOM + accessibility (jsdom) — all passed.
- real browser, showcase — **351 checks, 0 failures**; demo — 25/25.
- responsive + visual regression — after the deliberate re-baseline (the new section grows the page).
- appearance contract — regenerated; `docs/visual/Thumbnail.md` exists.
- agent layer — `ported entries: 55; correctly attributed: 55`, MCP truthful.
- **SWEEP GREEN: every gate passed, exit 0** (`docs/verification/sweep-m34*.txt`).

### The attribute trap that produced the duplicate-class failure

The remove button is a composed `Button`, and the first version passed it a caller `class`
attribute (`astryx-thumbnail__remove`). Vdom refuses to combine duplicate `class` attributes —
"not combining attributes (name class)" — so the render kept only Button's own classes and the
modifier never reached the DOM: the fixture's element query found nothing, and the debug DOM dump
showed the button carrying `astryx-button …` alone. Two sibling spots had the same defect (the
remove slot's base + hover classes, the surface's base + interactive classes). Both were merged
into one attribute via `Common.Attr.class_` (the shared helper that joins a list), and the remove
button's styling moved to a descendant selector (`.astryx-thumbnail__remove-slot .astryx-button`),
which also keeps the scrim colours off the public class the component does not own. A component that
composes Button must either take the class on a wrapper or accept that the composed child owns its
own class — the checker asserting a class a caller cannot influence is the failure mode.

### The per-source cell cannot be shown as a live swap

The port takes `src` as a plain string at graph-construction time (no bind in the Bonsai surface
this port uses), so a showcase example that *changes* a thumbnail's source cannot exist the way a
controlled dropdown can. The contract is still asserted: the static example whose source genuinely
404s lands on the placeholder in the real browser (a real error event fired, exactly the case jsdom
cannot produce), and the cell itself is the same `Bonsai.state` machinery Avatar's fallback chain
exercises. The browser gate does not pretend otherwise — the comment in the gate says so.

## Gate 53 — M35: ScrollableArea (coverage 55 -> 56)

A native scroll viewport whose accessibility follows the *measured* geometry, not the props: the
viewport (`role=group` by default, `region` via `role`, always labelled) is the root and its single
child is a normal block content box. Only a requested logical axis that actually overflows becomes
scrollable, and only then does the viewport enter the tab order (`tabindex=0`; held at `-1` while it
still holds focus after the axis stops being effective). The measured state is published as the raw
upstream `data-scroll-*` attributes (not the `data-astryx-*` house prefix — upstream's contract is
the contract): `data-scroll-axis`, `data-scrollable-{block,inline}`, `data-scroll-{block,inline}-{start,end}`,
and `data-scroll-content` on the content box. Edges are logical — stable under RTL and vertical
writing modes, via `Scroll_math` — and an inactive/unrequested axis reports both edges at rest. The
overflow style is `clip` until a Sticky boundary is needed, then `auto` on the overflowed axis and
`hidden` on the crossed one; `overscroll-behavior` lands on the requested axes only. Full-bleed
escapes the container padding through `--container-padding-*` variables.

Divergence: the hook's `contentOrViewport` keyboard delegation is not ported — the component always
passes `owner: 'viewport'`, so upstream never attaches `scrollKeyboardDelegation.ts` in this path.

### What ran

- `dune build` — clean.
- component tests — **513 checks, 0 failures** (11 new ScrollableArea checks).
- DOM + accessibility (jsdom) — all passed.
- real browser, showcase — **356 checks, 0 failures**; demo — 25/25.
- responsive + visual regression — after the deliberate re-baseline (the new section grows the page).
- appearance contract — regenerated; `docs/visual/ScrollableArea.md` exists.
- agent layer — `ported entries: 56; correctly attributed: 56`, MCP truthful.
- **SWEEP GREEN: every gate passed, exit 0** (`docs/verification/sweep-m35*.txt`).

### jsdom cannot measure, so it asserts the pre-measurement contract

jsdom has no layout: every client extent is 0, so the measure hook never produces a value and the
viewport stays inactive there. The jsdom fixture therefore asserts what is true before measurement —
`data-scroll-axis` and the component marker are present, role/label are right, `data-scroll-content`
sits on the content box, and an unmeasured viewport has *no* `tabindex` (inactive axes report both
edges at rest). The live cases — a measured block viewport gains `tabindex=0`, only its overflowing
axis is advertised as scrollable, scrolling to the end flips the logical edges (start leaves, end
arrives, after the hook's rAF-scheduled re-measure — the gate reads the edges on a second pass),
an inline viewport measures the *other* axis into the tab order, a fitting viewport never enters it,
and a `role=region` viewport with `overscroll=contain` carries its containment to the computed
longhand style — belong to the real-browser gate, where layout is real.

## Gate 54 — M36: NavHeadingMenu (coverage 56 -> 57)

The trigger-less menu that is a nav heading's popover body: a `role=menu` surface of rows
(`role=menuitem`, roving `tabindex=-1`), where a row with an `href` is the anchor itself (a modified
click keeps the browser's meaning), a disabled row carries `aria-disabled="true"` and cannot take
focus (the keyboard engine's selector skips it), and a row may carry an icon cell and a description
cell. Sizes `Sm/Md/Lg` control the surface min-width (160/200/240px, overridable via `min_width`)
and the rows' padding. The keyboard path is the whole upstream contract: Arrows (wrapping) move
focus between rows, Home/End bound it, typing jumps to the first row whose text matches (typeahead,
buffered per instance, reset on Escape and activation), Enter or Space synthesises the focused row's
activation, and Escape leaves. There is no on-screen trigger and no focus-on-open, because both
belong to the unported heading; the port takes `~on_select` (a tree, per house convention) and
`~on_close` — an explicit effect tree where upstream reads a React context's `closeMenu`, so both a
chosen row and Escape run it. No `NavMenuContext` exists here: the context is one function upstream
and one `~on_close` parameter in the port, which is the whole API of that file. Divergences:
`preventedBeforeDescendants` capture-phase tracking is not ported (it exists to let a caller's own
keydown handler observe nested-menu presses; this port owns the whole keydown, so there is nothing
to observe), and the icon is the port's own icon set rather than upstream's icon components.

### What ran

- `dune build` — clean.
- component tests — **527 checks, 0 failures** (14 new NavHeadingMenu checks; the two effect checks
  that need a scheduler moved to the real-browser gate, since jsdom cannot pump Bonsai's event loop).
- DOM + accessibility (jsdom) — all passed (demo fixture unchanged).
- real browser, showcase — **366 checks, 0 failures** (8 new live NavHeadingMenu checks: the surface
  renders as `role=menu` with four menuitem rows, the disabled row is `aria-disabled`, an href row is
  the anchor, a chosen row reports its id, ArrowDown moves focus and skips the disabled row,
  typeahead jumps to the matching row, Enter activates the focused row, and a caller-owned
  controlled surface closes through `~on_close` when Escape is pressed).
- responsive + visual regression — re-baselined (the new section grows the page).
- appearance contract — regenerated; `docs/visual/NavHeadingMenu.md` exists (58 pages in total).
- agent layer — `ported entries: 57; correctly attributed: 57`, MCP truthful.
- **SWEEP GREEN: every gate passed, exit 0** (`docs/verification/sweep-m36*.txt`).

### jsdom asserts markup, the browser gate asserts the keyboard

jsdom can render the markup contract (roles, aria-disabled, anchor-vs-div rows, icon/description
cells, size classes and min-widths) but cannot pump Bonsai's event scheduler, so a synthetic click
there never reaches the effect; the choose-then-close wire, ArrowDown, typeahead, Enter activation
and Escape-to-close are asserted in the real-browser gate on the showcase demo, where focus and
events are real.

## Gate 55 — M37: SegmentedControl (coverage 57 -> 58)

A single-control radiogroup: one `role=radiogroup` track (`aria-label`, `aria-disabled` on the
group, `aria-describedby` when a reason is given) of `role=radio` buttons whose `aria-checked`,
`aria-disabled` and a single roving `tabindex=0` describe the selection. The caller owns the
selection (`~value`, `~on_change` as a tree per house convention — upstream's `onValueChange`) and
hears every change, whether made by click or by arrow. Sizes `Sm/Md/Lg` (28/32/36px totals,
concentric radius), layout `Hug` (segments hug content, labels truncate) or `Fill` (segments
stretch equally). A disabled segment stays visible but is never focuable or selectable; a whole
disabled control dims and blocks the pointer, except with a reason, where the pointer stays live,
the selected segment remains the single tab stop (upstream's `keepsSelectedFocusable`) and the
reason is the house persistent `[role=tooltip]` bubble rather than upstream's hover-only tooltip — a
description that exists only on hover is one a screen reader never reads (M13 rule).

Two upstream rules made it into the shared mechanism rather than the component:

- `Common.List_focus` gained an opt-in `prefer_existing_stop`: upstream's roving sync never consults
  focus — it keeps the member already carrying an explicit `tabindex="0"`, falling back to the first
  enabled member. A controlled radiogroup is exactly that shape (its items carry the selected
  member's tabindex), so `Segmented_control.view` turns the flag on; ButtonGroup and Toolbar keep the
  default focused-member-wins rule, which their browser checks still prove.
- selection-follows-focus is one `on_focusin` handler on the track whose JS helper answers upstream's
  two questions in the DOM: the boundary check (`relatedTarget` inside this container) and the
  `closest('[role=radio]')` search that stops a nested-label retarget from re-firing the change.

Named divergences: per-item consumer `onClick` before selection (the item model has no callback
slot), press-feedback state (visual feedback is weight + `:active`, as with the card controls), and
upstream's "Press Enter or Space" keyboard hint (a radio has no pressed state to describe).

### What ran

- `dune build` — clean.
- component tests — **541 checks, 0 failures** (14 new SegmentedControl checks; the two interaction
  checks that need a scheduler — click-to-select, arrow selection — live in the browser gate, since
  jsdom cannot pump Bonsai's event loop).
- DOM + accessibility (jsdom) — all passed (demo fixture unchanged).
- real browser, showcase — **376 checks, 0 failures** (10 new live SegmentedControl checks: the
  control renders as a labelled radiogroup with grid selected; the selected segment owns the tab
  stop; clicking a segment selects it and moves the stop; ArrowRight moves focus and selection,
  again at the far end, wraps around; a disabled segment is skipped; Tab leaves the single roving
  stop; a disabled-with-message group cannot change, keeps its selected stop, and shows the reason
  bubble its `aria-describedby` points at; a settled disabled group blocks the pointer at the
  computed-style level).
- responsive + visual regression — re-baselined (the new section grows the page).
- appearance contract — regenerated; `docs/visual/SegmentedControl.md` exists (59 pages in total).
- agent layer — `ported entries: 58; correctly attributed: 58`, MCP truthful.
- **SWEEP GREEN: every gate passed, exit 0** (`docs/verification/sweep-m37*.txt`).

### A radiogroup is cheaper than its api suggests

No keydown handler exists in this component. The roving tab stop, the arrow traversal, the wrap and
the disabled skip all come from `Common.List_focus` — which is why the mechanism extension
(`prefer_existing_stop`) landed there rather than in the component. Selection itself is not wired to
any key: a native radio group's arrows select as they move, and this port reproduces that promise by
letting focus move and then reading the focused segment on `focusin` — one attribute, one JS helper,
the upstream bound check included.

## Gate 56 — M38: Overlay (coverage 58 -> 59)

Content on top of media — a scrim (dark `--color-overlay`, `Light` rendered as a translucent white, or
`None` which paints nothing and skips theme inversion) in `Fill`/`Bottom`/`Top` positions with aligned
content, over a container the port makes `position: relative; overflow: clip`. Visibility is pure CSS
(`Always`, `Hover`, `Hover_or_focus`, `Focus`) except for one JS half: upstream toggles hover overlays
on touch devices (`useSyncExternalStore` against `matchMedia("(hover: none)")` + a clickable-container
filter), and the port keeps it as a vdom hook — reads the media query at mount, subscribes to its
`change` event, and holds a click listener that applies upstream's nested-interactive and
text-selection checks in one JS call. An explicit `is_open` overrides all of it; the closed scrim is
then `inert`, so its content cannot take focus. The light/dark inversion is a `display: contents`
wrapper carrying `data-astryx-media` and `color-scheme`, because the house token set resolves through
`light-dark()`.

Named divergences: upstream's `onMouseUp` (middle-click navigation) is a no-op here — it only does
anything when the container is a clickable card with an href, and Overlay passes no href; no
`ref`/`useMergedRefs` (the house API does not forward refs; the hook does the DOM work); no
`themeProps` (styled by class with the house `data-astryx-component` marker); `MediaTheme` is token
inversion only, since there is no theme-provider mechanism; the child's border radius mirrored onto the
wrapper is a vdom hook reading `getComputedStyle` once after the DOM patch.

Two port bugs were found on the live path, not by reading: `subscribe` never read the media state at
mount (upstream's `useSyncExternalStore` snapshot runs immediately), so a real touch device would
never have enabled the toggle — fixed by refreshing the state inside `subscribe`; and the JS listener
was called with the wrong arity — it is a factory (`function(){...}` returning the binder), so a
single call returned the binder and the DOM invoked it with the event, discarding `fire`. Probes
(instrumented `setAttribute`, listener log, touch-mode override) caught both before they reached the
gate quietly.

### What ran

- `dune build` — clean.
- component tests — **555 checks, 0 failures** (14 new Overlay checks).
- DOM + accessibility (jsdom) — all passed (demo fixture unchanged).
- real browser, showcase — **399 checks, 0 failures** (23 new live Overlay checks: the container clips
  like upstream; the always-on scrim paints its token and is interactive; the light scrim is genuinely
  translucent and flips the media palette; a hover overlay is click-through until the pointer arrives
  and the reveal reverses when it leaves; the bottom strip starts translated below the edge and slides
  up; focus-within reveals the keyboard-only variant; a controlled overlay opens and closes with the
  closed scrim `inert`; and on a `hover:none` device a tap opens and closes it — the touch half driven
  by an init-script `matchMedia` override before the bundle mounts, since this runner's device reports
  `hover:hover` and its CDP cannot emulate the feature).
- responsive + visual regression — re-baselined (the new section grows the page).
- appearance contract — regenerated; `docs/visual/Overlay.md` exists (60 pages in total).
- agent layer — `ported entries: 59; correctly attributed: 59`, MCP truthful.
- **SWEEP GREEN: every gate passed, exit 0** (`docs/verification/sweep-m38.txt`).

## Gate 57 — M39: FileInput (coverage 59 -> 60)

A labelled file picker whose surface is the trigger: a compact control or a dashed dropzone, opening a
real `<input type="file">` through a visually-hidden button (click, Enter or Space). The container is a
non-interactive surface under the house `Clickable_container` rules — a click that ends a text
selection is ignored, and a click on the nested clear button is left alone; the button answers Enter
by itself, so the keydown handler calls `click` only for Space. Drag-and-drop on the dropzone:
dragenter/dragover light the drag-over state, dragleave clears only when the pointer actually exits,
and drop feeds the same validation the picker uses. Validation — `accept` (extensions, `type/*`
wildcards, exact MIME), `max_size` and `max_files` (multiple only) — is pure and unit-tested in OCaml;
the first error becomes the Field's error status, announced by the `Field_status` the derived status
mounts (assertive), and success is announced politely through a persistent `role=status` live region
(the compact test asserts the trigger carries `aria-invalid` and the dropzone's drag state flips).

Named divergences: the port cannot hand out live `File` objects (no OCaml type for one, and nothing
stores a JS value in application state), so `on_change` delivers `{name; size; mime}` read off the DOM
`File` while the native input still holds the real objects; there is no `ref`/focus-shift API (the
disabled reason tooltip is pure CSS in this port); the reason is a `role=tooltip`-free span shown on
hover/focus-within while the trigger stays focusable via `aria-disabled` so a screen-reader user can
discover why the picker is blocked — opening stays blocked by the `is_disabled` guards. HTML boolean
attributes are omitted rather than set to `"false"` (`disabled`/`multiple`), which is the HTML contract
and was caught by the jsdom fixture on the first run.

### What ran

- `dune build` — clean.
- component tests — **565 checks, 0 failures** (13 new FileInput checks across 8 variants:
  compact/dropzone/disabled/loading/required/multiple/error/placeholder).
- DOM + accessibility (jsdom) — all passed (demo fixture unchanged).
- real browser, showcase — **402 checks, 0 failures** (3 new live FileInput checks: all six demos
  render with the component marker; the trigger is a real file input behind the visually-hidden
  button; dragenter lights `--drag-over` and dragleave clears it on the live page).
- responsive + visual regression — **66 checks, 0 failures** after re-baselining the new section
  (768x1024 and 1440x900 baselines updated).
- agent layer — `ported entries: 60; correctly attributed: 60`, MCP truthful.
- **SWEEP GREEN: every gate passed, exit 0** (`docs/verification/sweep-m39.txt`).

## Gate 58 — M41: Layout (coverage 60 -> 61)

The five-slot frame ported from `facebook/astryx` `Layout/`: `view` lays out a header on top,
an optional start/end panel pair around the content in the middle, and a footer on the bottom,
at either `Fill` or `Auto` height. Each region is its own builder (`header`/`footer`/
`content`/`panel`) carrying the upstream padding-token chains (`--layout-padding-*`,
`--layout-container-padding-inline`), optional `has_divider` borders, `is_scrollable`
(content/panel only), explicit panel widths, and accessible `role`/`label`. The content-width
system is the interesting part: a `~content_width` that is a `Px` or length resolves to
`--layout-alignment-width` **internally** (the container publishes `container-type: inline-size`
via `--layout-content-width` plus `--layout-alignment-width`, and the content lane is centred by
`calc((100cqi - var(--layout-alignment-width)) / 2)` padding — no JS measurement), while a
percentage / var / keyword width stays a constrained max-width lane. Dividers are inherited from
`~default_has_dividers` through a real DOM hook (`Vdom.Attr.Hooks.Make` + `closest()` in JS via
`eval_string`, same overlay FFI pattern): the inner publishes
`data-astryx-default-dividers`, each region queries its closest layout and resolves its own
`data-astryx-divider="true"/"false"` if it did not set one explicitly; an explicit
`has_divider:true` renders statically so jsdom sees it.

Named divergences: the alignment-width internal path is driven by container queries + padding
rather than upstream's `ResizeObserver`, so no measurement and no JS state — a `Px` width works
where the browser supports `container-type` (all modern engines); upstream's `Layout` uses the
same CSS-var contract, so the port pins the same class names (`astryx-layout__middle`,
`__column`, `--single-column`, `--query`, `--content-lane`, `--fill`/`--auto`,
`astryx-layout-header/footer/panel/content`) and named classes only where a slot-agnostic
`:has()`/`:first-child` edge rule cannot express the intent.

### What ran

- `dune build` — clean.
- component tests — **575 checks, 0 failures** (10 new Layout checks: the five-slot shell
  renders all five regions with roles; explicit dividers are static attrs; the
  default-dividers variant publishes `data-astryx-default-dividers` on the inner and leaves
  the un-set header/footer unresolved in jsdom (the hook runs only in the browser); the
  `Auto` + `Px 640` variant stamps `--auto` and `--layout-content-width: 640px` /
  `--layout-alignment-width: 640px` with `--query` + `--single-column`; a non-scrollable content
  is clipped; a bare panel outside a layout renders at its width with no divider class).
- DOM + accessibility (jsdom) — all passed (demo fixture unchanged).
- real browser, showcase — **410 checks, 0 failures** (8 new live Layout checks: the section
  renders six examples; the divider hook resolves the default onto un-set regions (the browser
  path jsdom cannot pump); the 640-lane caps the header inner at 640px in *computed* style and
  the content's alignment padding is non-zero; the 960 both-panel lane is a centred
  `--content-lane` (computed max-width 960px, left/right gutters equal); the auto layout is
  `--auto` + height=auto; the scrollable content still scrolls in the browser).
- responsive + visual regression — re-baselined (the new section grows the page).
- appearance contract — regenerated; `docs/visual/Layout.md` exists (62 pages in total).
- agent layer — `ported entries: 61; correctly attributed: 61`, MCP truthful.
- **SWEEP GREEN: every gate passed, exit 0** (`docs/verification/sweep-m41.txt`).
## Gate 59 — M42: Slider (coverage 61 -> 62)

The labelled numeric control ported from `facebook/astryx` `Slider/` (a representation of
`Slider.tsx` plus its `Slider.spec.md` accessibility contract): one thumb (`Single`) or two
(`Range`, a `role=group` named by the Field label) on a 4px rail, driven by `min`/`max`/`step`,
with optional `marks` (2x8px ticks at their inset position, labelled, each clickable and snapping
to that mark's value) and a `value_display` of tooltip / text / none. The geometry is ported
literally: rail, fill and thumbs travel through an inset of half a thumb at each end (the geometry
native range inputs use), so the thumb stays inside the box at min/max and the fill maps through
the same inset; pointer positions invert that mapping through the same formula.

The interaction is graph-owned rather than ref-owned: pointer-down anywhere on the track moves the
nearest thumb (or a directly pressed one) and captures the pointer; move updates while the drag
runs; up/cancel ends it and fires `on_change_end`. Keyboard on a thumb: arrows (direction-aware on
a horizontal track under RTL, detected lazily from `computed direction` at event time, exactly as
upstream), PageUp/PageDown (10 steps), Home/End landing exactly on the bounds even when they are
off the step grid. Values are clamped and snapped with binary-error rounding
(`0 + 3 * 0.1` is `0.3`), and `min_steps_between_thumbs` is enforced on both drag and keyboard so
the thumbs never cross. Numbers are formatted with `fmt_num` (`Printf.sprintf "%g"`), driving
`aria-valuenow`, `data-astryx-mark-value` and the hidden inputs, so snapped values render without
float noise.

Named divergences: no pointer-event JS wrappers and no React ref — the drag state lives in the
Bonsai graph plus `pressed_ref`-style DOM bridges, and the pressed thumb paints a `--pressed` class
while the keyboard-only focus ring paints `--keyboard-focus` (holding the house convention for
"last interaction was the keyboard", where upstream gates `:focus-visible` on an interaction
modality store). The value tooltip is the house `Tooltip` (a static, graph-owned bubble opened on
drag) rather than a positioned portal. `disabled_message` keeps the discoverability contract —
when the message is present, the reason shows as a tooltip above the track on hover/focus
(the house `Tooltip`), blocked by the `is_disabled` guards — nothing on the slider can change while
the guards are on, even if the message never shows; without a message a disabled thumb is
`tabindex=-1`. `aria-required` is not a supported property of
`role=slider` in WAI-ARIA 1.2, so a required slider points `aria-describedby` at a visually
hidden "Required" span. Hidden native inputs (`html_name`) carry each thumb's value for form
submission and are `disabled` when the slider is. `valueDisplay=none` is partial (bubbles off);
full upstream parity around a `ref`-based API is not attempted.

### What ran

- `dune build` — clean.
- component tests — **585 checks, 0 failures** (10 new Slider checks across the fixture: eight
  marked sliders; track/fill/one thumb; single-thumb `aria-valuenow`; range group with two
  thumbs; disabled inert; hidden Required label; description; error message; marks with labels;
  vertical class).
- DOM + accessibility (jsdom) — all passed (fixture unchanged).
- real browser, showcase — **416 checks, 0 failures** (6 new live Slider checks: all eight demos
  marked, the basic thumb announcing bounds `0`/`100` and current value 30, the thumb focusable;
  ArrowRight on the focused thumb steps by one; End lands exactly on max and Home exactly on min;
  a pointer press on the track takes the thumb to the position under the pointer, computed
  through the port's own inset/travel geometry, on the real track during a real mouse click).
- responsive + visual regression — re-baselined (the new section grows the page).
- appearance contract — regenerated; `docs/visual/Slider.md` exists (63 pages in total).
- agent layer — `ported entries: 62; correctly attributed: 62`, MCP truthful.
- **SWEEP GREEN: every gate passed, exit 0** (`docs/verification/sweep-m42.txt`).
## Gate 60 — M43: Layer (coverage 62 -> 63)

The shared geometry of the overlay family, ported from `facebook/astryx` `Layer/` (the
`LayerProvider` plus the *rules* half of `useLayer.tsx`; the rendering half of `useLayer`
assembles a popover surface, and this port already has that — `Astryx.Popover` plus the
`Common.Layer_hook`/`Layer_trigger_hook` from M16). What Layer owns is the app-declared
inset — a persistent bar floating over a viewport edge (a phone nav bar, a docked toolbar)
— and the pure rules an anchored layer runs on: `position_area` (getPositionArea), the
`position_try_fallbacks` list (flips first, then the named slides; a centered pair keeps
its one-sided spans ahead of the full span so it slides the least distance first),
`self_alignment` (while the anchor is out of view an aligned layer pins its alignment
`unsafe` toward the anchor — the caller supplies the answer, since the port does not
observe the anchor), plus the viewport gutter/cap contract: `layerViewportInset.stylex.ts`
verbatim as one CSS block in `assets/components.css` — `--astryx-layer-inset-*` custom
properties, per-edge gutters `calc(max(spacing, env(safe-area-inset-*)) + declared)`, and
the caps `calc(100vi/dvb - both gutters)` — and the 24 static `@position-try` slide options
(`layerSlideRules.ts`): 4 placements × 3 alignments × 2 sides, each carrying its own
gutter and clearance declarations so a slide keeps the clearance toward the anchor.

The provider is `Astryx.Layer.Provider.view` — the port's answer to upstream's React
context. It writes the four custom properties on its own `display: contents` element and
lets them inherit (no portal in this port, so the gutter reads them exactly as upstream's
does); an undeclared edge sets nothing and reads `0px` through the gutter's fallback.
`Astryx.Layer.surface_attrs` composes the base class, the placement/margin classes
(`--far-*` without offset, `--placement-*` with one, where the offset also travels as
`--_astryx-layer-clearance`) and the gutter classes with the inline anchor wiring:
`position-anchor`, `position-area`, `position-try-fallbacks`, and the self-alignment when
it applies.

Named divergences, each stated in `layer.mli` rather than silently dropped: the slide
rules ship as a static sheet in the stylesheet, not from a JS install
(`ensureSlideRules` — the port has no document handle at module scope; `slide_rules_css`
is the generator, and the component gate asserts the shipped file contains exactly what
it generates); no dismissal stack (`layerStack.ts` — upstream needs it because its layers
are `popover="manual"` with JS dismissal; this port's layers are `popover="auto"` and the
platform's close watcher already owns one Escape); no touch trigger
(`useTouchTrigger`/`isActionTrigger` — a touch model for hover-type layers, and the gates
drive the mouse). `Popover` keeps its own `placement`/`alignment` copies for now; a later
milestone re-exports these destructively, per the mechanism-owns-types rule. The port is
tier C (utility geometry, like Layout and Slider); `registry.json` has it in Utility
group.

### What ran

- `dune build` — clean.
- component tests — **609 checks, 0 failures** (24 new Layer geometry checks: four
  position-areas, both fallback shapes — centered and aligned — all four
  self-alignment branches, the slide-name format, the inset property list, and the
  provider/surface structure: custom properties on the provider, display: contents, the
  class list of a centered far-below surface, the inline anchor wiring, the clearance
  travelling only with an offset, and the stylesheet shipping all 24 slide options in the
  generator's order).
- DOM + accessibility (jsdom) — all passed (fixture unchanged).
- real browser, showcase — **424 checks, 0 failures** (8 new live Layer inset checks:
  the declaration lives on the provider and inherits to the layer, the platform anchors
  it at the block end, the far gutter computes to spacing + the declared 56px (72px),
  the block cap is the viewport minus both gutters, the surface clears the declared bar,
  the fallbacks name the sheet's slide options, and Escape closes it like any other. The
  gate centres the trigger before opening: the Layer section sits at the bottom of the
  showcase, so a plain click-into-view lands the anchor at the viewport edge and the
  platform rightly flips it — the flip is the platform's, not what this block measures).
- responsive + visual regression — re-baselined (the new example grows the page);
  66 checks, 0 failures, 0.00% pixel drift.
- appearance contract — regenerated; `docs/visual/Layer.md` exists (64 pages in total).
- agent layer — `ported: 63 of 103`, `Astryx.Layer` attributed, MCP truthful.
- **SWEEP GREEN: every gate passed, exit 0** (`docs/verification/sweep-m43.txt`).

## Gate 61 — M44: Item (coverage 63 -> 64)

The universal row, ported from `facebook/astryx` `Item/Item.tsx` +
`Item/ItemSwipeLayer.tsx` + `Item/useSwipeAction.ts` as `Astryx.Item`: marker, start
slot, label + description, end slot on a single DOM element ([div], [li], [span] or a
[Custom] root), with the four exclusive interactive paths — [on_click] (invisible
button), [href] (invisible anchor), [interactive_selector] (delegation: the row
becomes a live region that proxies a surface click to the nested control, which keeps
its own activation), and a parent-owned [role] (clicks pass upward; label/description
render invisible). The swipe layer is a touch-only pointer stream: a drag claims the
inline axis (`touch-action: pan-y`), and the gestures are upstream's — past the commit
threshold (`max(panel+48px, 50% of the row width)`) or a fling fires the outermost
action and slides the row out; [Reveal] settles at half the panel width with the
panels live (row content goes inert, Escape/outside pointer closes, a focused control
in the row activates as a side effect of closing), [Commit] settles at the panel width
with the actions presentational and `aria-hidden`. Settle duration honours
`prefers-reduced-motion` (read at settle time; a zero clock lands the phase instantly).

Named divergences, stated in `item.mli`: no React key on actions; panels are
out-of-flow children of the row rather than portal-swapped (the row's DOM shape does
not change on split; swipe markup exists only on rows that have actions); native
wiring is limited to three listeners vdom cannot express (pointercancel, non-passive
touchmove, document-level pointerdown that closes a resting row) with pointer capture
via pointer attrs like Slider; reduced-motion is read at settle time rather than
subscribed; click suppression happens in the row's own handler rather than at
container capture; no id on the row itself; invisible links are plain anchors (use
[as_] [Custom] for a `isLinkRoot`-style root, exactly as upstream's isLinkRoot).

### What ran

- `dune build` — clean.
- component tests — **624 checks, 0 failures** (19 new Item checks: the four
  interactive paths, marker/start/end slot structure, the density/align variants,
  truncation classes, disabled inertness, and the swipe surface's custom properties
  at rest).
- DOM + accessibility (jsdom) — all passed (fixture unchanged).
- real browser, showcase — **438/438 checks**, demo **25/25**, 0 failures. 18 new
  live Item checks: click readout fires once and again, link/invisible anchor wiring,
  custom root link, delegated control activation (nested control keeps its own click;
  a row-surface click proxies to it), touch drag via CDP reveals the trailing panel
  (`inert:false`), entry tap fires the action and returns the row to rest, Escape and
  outside-pointerdown close, and a long swipe commits — the row slides out and stays.
- responsive + visual regression — re-baselined (the new section grows the page); 66
  checks, 0 failures, 0.00% drift.
- appearance contract — regenerated; `docs/visual/Item.md` exists (65 pages in total).
- agent layer — `ported: 64 of 103`, `Astryx.Item` attributed, MCP truthful.
- **SWEEP GREEN: every gate passed, exit 0** (`docs/verification/sweep-m44.txt`).

*Two late findings this run, both worth recording.*

**The real port bug this milestone already fixed** (found in the prior run's session,
probe6 confirmed): `focus_row_content` in `src/item.ml` passed an over-escaped eval
string to `Js.Unsafe.eval_string`, so the runtime JS literally contained `\'button…`
— a backslash before the quote — and every row-descendant focus threw a SyntaxError.
That is the entry-activation path: the swipe tap on an entry aborted in the handler
before the settle ran, which had masked the port as working everywhere else. The
string is now built correctly and the entry activation path really runs.

**Item's row needs a width from its host** (nothing upstream omitted — upstream rows
are shape, not width). The showcase's `.ex-render` is a flex row and flex rows do not
offer a width (documented rule in `site/site.css` for Stack/Grid); an Item inside it
sized itself to content, so the nowrap truncation description forced 535px of
max-content and the page overflowed at 320px (`scrollWidth 576`). Applied the same
rule to Item (and the `.showcase-col` wrapper): `.ex-render > .astryx-item,
.ex-render > .showcase-col { flex: 1 1 100%; min-width: 0; }`. Side effect: the swipe
rows grew to the container's width, which silently moved the browser gate's reveal
drag (computed as `0.55 × row width`) past the component's commit point
(`max(panel+48, 50% × width)`) — a reveal test was now doing a commit drag. Re-anchored
the three reveal drags in `verify-browser.mjs` to the *measured panel width*
(`panelWidth × 1.3 + 30`), which is invariant to host width, and left commit drags
unchanged (they are deliberately 0.85w, far past the threshold). Responsive then
re-baselined clean: 66 checks, 0 failures.


## Gate 62 — M45: List (coverage 64 -> 65)

The list primitive, ported from `facebook/astryx` `List/List.tsx` + `List/ListHeader.tsx`
+ `List/ListItem.tsx`. **Namespace note:** OCaml cannot name this module `List` here —
the library is effectively unwrapped (its main module is present), so a top-level
`List` shadows Stdlib/Core for every linked unit (empirically: `src/list.ml` → dependency
cycle `Vstack -> Common -> List -> Common` plus `List.fold` errors; the alias-only variant
→ `Unbound value List.fold`). The public path is `Astryx.List_container` with the
component rendered by `Astryx.List_item` (an `Item` row composed with `as_:Li` and a
marker span). Documented divergence in `port.json`.

- `Astryx.List_container.view`: decorates `<ul>`/`<ol>` with `role="list"`,
  `data-astryx-component`, `data-astryx-density` (spacious/compact/comfortable),
  `data-astryx-dividers`, `data-astryx-marker` (decimal/none/...), `data-astryx-edge`,
  CSS-counter-based `start` on `ol`, header (description + heading) paired via generated
  `id`/`aria-labelledby`, horizontal scroll, alignment. Dividers are an inherited layout
  rule (rows render borders when the list was given dividers; `List_item`/`Item` rows have
  no divider class of their own). Custom-counter markers via `--astryx-list-counter`.
- Verified: `dune build` exit 0; showcase List section (6 examples) + nav entry;
  jsdom fixture `list-all` (basic 3-row, dividers + header, ordered start=4, compact);
  component gate **631 checks, 0 failures** (+7); browser gate **442/442** (List live:
  role=list ul with three rows, divider header aria-labelledby pairing, decimal ol start=4
  with marker spans, compact density class+data); responsive **66/66** after
  re-baseline; `gen-references.py` + `gen-port-status.py` + `gen-coverage.mjs` +
  `gen-visual-contract.mjs` (docs/visual/List.md) regenerated; PORT-STATUS 65/38.
- Component tests: **631/0**. Browser showcase: **442/442**. Responsive: **66/66**.
- Files: `src/list_container.ml/.mli`, `src/list_item.ml/.mli`, `assets/components.css`
  (`.astryx-list__*`), `examples/showcase/showcase.ml` (List section), `test/rt_test.ml`,
  `test/run.mjs`, `tools/visual/verify-browser.mjs`, `README.md`.


## Gate 63 — M46: TreeList (coverage 65 -> 66)

The tree view, ported from `facebook/astryx` `TreeList/TreeList.tsx` +
`TreeList/TreeListItem.tsx` + `TreeListBranches.tsx` + `TreeListTypes.ts` together with
`hooks/useTreeFocus.ts` (634 lines — the keyboard model). Exposed as
`Astryx.Tree_list` with a separate `Astryx.Tree_focus` module following the house
`Menu_focus` pattern (registered in `astryx.ml`). Documented divergences in `port.json`
and in the source: `on_click` is `unit -> unit` (house API) rather than a DOM event; the
toggle `aria-label` is a fixed English "Toggle children" (upstream i18n); per-item
`xstyle`/`className`/`style` have no counterpart (the port emits BEM class names);
`Tree_branches` (the guide-line renderer) is private.

- `Astryx.Tree_list.view`: recursive `item` value (id, label, description, children,
  on_click, href/target, disabled, selected, expanded), expand/collapse via chevron
  toggles (`data-tree-toggle`), roving tabindex (a single `tabindex=0` seeded from
  `is_selected`), the WAI-ARIA tree keyboard model (ArrowUp/Down/Home/End over visible
  rows, ArrowRight expand / first child, ArrowLeft collapse / parent, Enter/Space
  activation, label-only typeahead, RTL-aware), `aria-level`/`posinset`/`setsize`,
  `aria-expanded`, `aria-selected`, `aria-disabled`, guide branches (indent + connector
  lines, `--full`/`--last`), `role=tree` list, header + `aria-labelledby`, density +
  `lineGuides` variant via `data-astryx-*` markers. Expansion state is an assoc of
  overrides over upstream defaults (`Bonsai.state` + `map2`), so a wrapped GraphQL-style
  consumer can supply its own opened/descriptions.
- `Astryx.Tree_focus`: the full focus/roving model (port of `useTreeFocus.ts`), kept
  separate so any future focusable component can reuse it.
- CSS: `.astryx-tree-list__*` block in `assets/components.css` (indent lever
  `--tree-list-indent`, chevron column reservation, guide-line geometry).
- Fixture in `test/rt_test.ml` (`tree-list-all`: a/b/c/d rows, two levels of nesting,
  selected/disabled/expanded seeds) — `node test/run.mjs` **642 checks, 0 failures**.
- Browser showcase: **452/452** — live chevron toggle (expand on first click, collapse
  on second, subtree re-render), roving focus keyboard roam + typeahead, keep-open
  semantics. Responsive: **66/66** (re-baselined). Full sweep: see
  `docs/verification/sweep-m46.txt`. PORT-STATUS 66/37.
- Example count map: 420 examples, 68 sections, 68 nav links.
- Responsive: `--update-baseline` created **8 new baselines** (the TreeList viewport
  shots) — the update run therefore counts 58 diffable checks — and the clean verify
  counts **66/66**. Both green.

## Gate 64 — M47: NumberInput (coverage 66 -> 67)

The draft-committing numeric field, ported from `facebook/astryx`
`NumberInput/NumberInput.tsx` + `NumberInputTypes.ts` + `useNumberInput.ts`. Exposed as
`Astryx.Number_input` (registered in `astryx.ml`, `src/number_input.ml` + `.mli`).
Recorded divergences in `port.json` and the `.mli`: no `on_key_down` (Enter and IME
kept, everything else reaches the component through `attrs`); locale via `?locale` (BCP
47) instead of upstream's i18n context, with grouping/decimal separators resolved from
the host `Intl` and non-ASCII decimal digits (Arabic-Indic, Devanagari, full-width …)
folded to ASCII; no `InputGroup` context (pass `is_label_hidden` yourself); the status
icon is the house `Field`'s message box (passing `status` still colours the control);
fixed English strings ("Invalid number", "Clear value", "Increase value"/"Decrease
value"); the live invalid-number region is a visually-hidden `role=alert` div because
`Visually_hidden.view` cannot take attributes; generated ids derive from `id`
(`-desc`/`-status`/`-units`/`-reason`) rather than React's `useId`, so markup is
deterministic and testable.

- `Astryx.Number_input.view`: the draft is a string (so "1,5" and "12.0" are visible
  while typing) until an explicit commit boundary — blur or Enter; only valid drafts
  reach `on_change`; an out-of-range draft clamps at `min`/`max` (upstream's policy),
  an empty draft clears (`has_clear`) or reverts. Arrow keys, the wheel and the stepper
  buttons step through the same arithmetic (`step`, `min`, `max`, `is_integer_only`,
  decimal-place rounding, `-0` normalization). `is_read_only` disables editing while
  keeping the value visible and submitted; `disabled_message` keeps the control
  focusable (`aria-disabled`) and shows the reason. `value`/`on_change` are graph
  values, so the DOM follows application state exactly as `Text_input` does.
- Last browser-gate defect root-caused and fixed: the decrement stepper never got a
  distinguishing class (only `--increment` was emitted) nor `aria-disabled` on the
  disabled path — `astryx-number-input__stepper--decrement` + `aria-disabled="true"`.
- CSS: `.astryx-number-input__*` block in `assets/components.css`.
- Fixture in `test/rt_test.ml` (`number-input-all`: ten NumberInputs) — `node
  test/run.mjs` **655 checks, 0 failures**. jsdom DOM+accessibility gate **ALL CHECKS
  PASSED**.
- Browser showcase: **463/463** (demo page **25/25**) — live commit on Enter/blur,
  steppers (both directions, boundary-dimmed decrement), wheel stepping, clear, clamp.
- Example count map: 430 examples, 69 sections, 69 nav links (NumberInput section:
  ten examples, all marked).
- Responsive: **66/66** — re-baselined because moving NumberInput out of the unported
  list changed the coverage panel's text (and page height at narrow widths); update run
  counts 58 diffable checks, clean verify 66/66.
- Full sweep: **SWEEP GREEN** — see `docs/verification/sweep-m47.txt`. PORT-STATUS
  67/36.

## Gate 65 — M48: CheckboxList (coverage 67 -> 68)

Several choices out of one question, ported from `facebook/astryx`
`CheckboxList/CheckboxList.tsx` + `CheckboxListItem.tsx`. Exposed as
`Astryx.Checkbox_list` (registered in `astryx.ml`, `src/checkbox_list.ml` +
`.mli`). Collection mode: `value : string list Bonsai.t` / `on_change`, each box
deriving `checked` from membership, the application staying the source of truth.
Recorded divergences in `port.json` and the `.mli`: items are data rather than
composed children (the port has no React context for a child to read the value
array, the same call Radio_list already made); `changeAction` is an async React
form action a Bonsai effect cannot await, so per-item `is_loading` replaces it
(with the in-checkbox spinner); the rows are built by this component rather than
through `List_item`, because a row's checkbox is driven by the list's value tree
and `List_item`'s start slot is a static node — `density`/`has_dividers` ride as
data attributes styled by this component's CSS (the same data route
`List_container` uses); no `onClick` on an item (the checkbox is the row's
action and row-surface clicks delegate to it, upstream's
`useClickableContainer`); a rich ReactNode label, `xstyle`, and per-item
`CheckboxListItem` as a public component are not ported; fixed English "Loading".

- `Checkbox_input.render` gained `?is_focusable_disabled` (ml + mli): a disabled
  checkbox that stays keyboard-focusable via `aria-disabled` + `form=""` without
  mounting its own reason bubble — the group-disabled-with-message case, where
  one bubble describes the whole set (the group links it through
  `aria-describedby`, so a keyboard/AT user reaches it without hovering).
- The visible row label is `[<span>]` plain text, never a second `[<label for>]`:
  the checkbox is named once by its own hidden label, and row-surface clicks
  activate it — upstream's arrangement. Verified: one `<label>` per checkbox,
  none over the row text.
- The value order is preserved: a newly selected value is *appended*, never
  re-sorted (documented in the `.mli`; the browser gate caught the initial
  expectation of sorted order).
- CSS: `.astryx-checkbox-list__*` block in `assets/components.css` (density
  paddings, dividers, selected tint, disabled-message bubble selectors).
- Fixture in `test/rt_test.ml` (`checkbox-list-all`: ten groups covering live
  selection, status, group+item disabled, loading, read-only, required, hidden
  label, compact/dividers, end content) — `node test/run.mjs` **677 checks, 0
  failures**. jsdom DOM+accessibility gate **ALL CHECKS PASSED**.
- Browser showcase: **471/471** (demo page **25/25**) — a click on the row's
  surface checks it and the application's readout follows, a click on a selected
  row removes it, Space on a focused box toggles it (a checkbox answers Space by
  itself), a group disabled with a reason refuses the click while its boxes stay
  focusable for the reason, a read-only row refuses the toggle, and the
  described item's checkbox links its own description.
- Example count map: 440 examples, 70 sections, 70 nav links (CheckboxList
  section: ten examples, all marked). Coverage panel: 68 / 35 / 103.
- Responsive: **66/66** — re-baselined because CheckboxList moving into the
  ported list changed the coverage panel's text; update run 58 diffable checks,
  clean verify 66/66.
- Full sweep: **SWEEP GREEN** — see `docs/verification/sweep-m48.txt`. PORT-STATUS
  68/35.


## Gate 66 — M49: Banner (coverage 68 -> 69)

A persistent status notification (info / warning / error / success), ported from
`facebook/astryx` `Banner/Banner.tsx` as `Astryx.Banner` (registered in
`astryx.ml`, `src/banner.ml` + `.mli`), preceded by its core: `Use_collapsible`
(`src/use_collapsible.ml` + `.mli`) is the shared collapsible state machine
ported from `Collapsible/useCollapsible.ts` so Banner's disclosure and the
coming Collapsible port run the same hook — controlled / uncontrolled /
disabled, decided by whether `is_open` was provided, exactly as upstream
decides by whether `isOpen` was.

- The banner is two parts, as upstream's is: the colored status header
  (icon, title, description, end area) and an optional card-background content
  area. `title`/`description` are node lists — never `<p>` — because a
  paragraph cannot legally contain block-level children and these slots take
  arbitrary content (the port's own judgment, upstream's stated rule).
- `status` is a string, not a variant: upstream's `BannerStatus` is extensible by
  a theme package and this port cannot express module augmentation, so the
  status leaves the type system and the lookups stay partial — an unknown
  status falls through to the base treatment (no fill class, no default
  glyph). Status never selects a live-region role; callers pass `role` through
  `attrs`, exactly as upstream says.
- Disclosure: children are collapsible by default and a collapsible banner
  **starts closed** — the banner's one departure from the hook's own default
  (open), applied here so `Use_collapsible` stays upstream's machine for
  everyone else; a `Never` banner pins the content open with no toggle, no
  `aria-expanded`, no `aria-controls`, and no end area at all. When mounted,
  the toggle links the content through `aria-controls = <id>-content`; the
  reference disappears with the region, so no dangling pointer exists.
- Dismissal: `is_dismissable` mounts a close control; the banner removes
  itself even when `on_dismiss` is absent (the dismissal is owned here, not by
  the caller, and `on_dismiss` fires alongside), and before it disappears focus
  is handed back to the element it came from — recorded on `focusin` /
  `pointerdown` capture, kept only when it is outside the banner and not
  `body`, refocused only if still connected — the same handoff
  `Toast_viewport` makes.
- The header is the color surface; `container` is `Card` (rounded, standalone)
  or `Section` (full-width, square); `elevation` rides `Button`'s enumerated
  shadow; the icon wrapper is `aria-hidden` (the glyph is decoration — the
  message is the title and description, told twice would be noise).
- `src/button.ml`: ghost buttons now carry `data-astryx-edge-comp`
  (upstream `EDGE_COMP_ATTR`), and the banner's CSS compensates for a ghost
  action's protruding edge with a `:has(> [data-astryx-edge-comp]:first-child)`
  negative margin. Recorded divergences in `port.json` and the `.mli`: no
  `themeProps` (styled by class, as every component here); fixed English
  labels (`dismiss_label` default "Dismiss", `expand_label`/`collapse_label`);
  `id` is caller-scoped — no `useId`, so a distinct id per banner; no
  `className`/`style`/`xstyle` per the class convention.

- Component fixture: `test/rt_test.ml` mounts `banner-all` — seven banners
  covering the default closed collapsible, an explicitly open one, `Never`,
  end content, dismissal, a Card container with elevation, and an unknown
  status. `node test/run.mjs` **696 checks, 0 failures** (19 new Banner
  checks: the marked root and its status, the per-status fill classes, the
  closed-start contract — no content region, `Expand` toggle reporting
  `aria-expanded=false` with no `aria-controls`, because nothing is mounted to
  point at — the open banner's linked content region, `Never`'s pinned content
  with no toggle and no ids, the aria-hidden glyph wrapper, the end-slot
  placement and body modifier, the caller-named dismiss control, and the
  unknown-status fall-through).
- jsdom DOM + accessibility gate: **ALL CHECKS PASSED**.
- Browser showcase: **482/482** (12 new Banner checks) and demo **25/25**. The
  interaction half belongs here because jsdom cannot pump Bonsai effects: a
  collapsible banner starts closed with no content region and an
  `aria-expanded=false` toggle; clicking it opens the content and links it
  through `aria-controls`, which disappears with the region; `defaultIsOpen`
  renders content on first paint; `Never` pins it open with no toggle; the four
  statuses paint their own fill; a ghost action's compensating edge margin is
  read from computed style rather than assumed; the controlled banner's readout
  follows the toggle in both directions; a banner dismisses itself even with no
  callback wired; the status icon wrapper is `aria-hidden`.
- Example count map: 451 examples, 71 sections, 71 nav links (Banner section:
  eleven examples, all marked). Coverage panel: 69 / 34 / 103.
- Responsive: **66/66** — re-baselined (Banner moving into the ported list
  changed the coverage panel's text); update run green, clean verify 66/66.
- Visual contract: Banner.md generated; 70 pages total.
- Full sweep: **SWEEP GREEN** — see `docs/verification/sweep-m49.txt`.
  PORT-STATUS 69/34. One catch along the way: after the generators moved the
  coverage.json numbers, the browser gate's own expected values still said
  `68 / 35` and caught itself — 480/482 with the only failures being the two
  coverage-stat checks. The expected counts were moved to 69 / 34 / 103 and
  the rerun is green, which is the gate doing exactly its job: a real
  mismatch, found by itself, fixed, and re-proven.

## Gate 67 — M50: Collapsible (coverage 69 -> 70)

The disclosure accordion, ported from `facebook/astryx`
`Collapsible/Collapsible.tsx` + `CollapsibleGroup.tsx` +
`CollapsibleGroupContext.tsx` (+ `useCollapsible.ts`, whose state machine was
already ported as `Use_collapsible` under M49) as one module `Astryx.Collapsible`
(`src/collapsible.ml` + `.mli`, registered in `astryx.ml` as `Collapsible`,
`Collapsible_group`, `CollapsibleGroup`; one coverage entry for the directory,
the same call Avatar/AvatarStatusDot made).

- The single unit is the shared `Use_collapsible` hook — controlled when
  `is_open` is provided, uncontrolled seeded by `default_is_open` (upstream's
  default: **open**, unlike Banner, which overrides the hook to closed). The
  trigger is a real `<button type="button">` carrying `aria-expanded` and
  `aria-controls = <id>-content`; the content stays **mounted** and hides with
  `display: none` (upstream's own choice), so the caller's node identity is
  stable and the `aria-controls` reference never dangles. The chevron is the
  Icon, wrapper `aria-hidden`, rotated by `--expanded`/`--closed` classes;
  `chevron_position` is `End` (down -> up) or `Start` (chevronRight, points
  into the row).
- Disabled items use the port's convention: `aria-disabled="true"` +
  `tabindex="-1"` (never the native `disabled`, which would swallow a wrapping
  tooltip's hover), activation guarded in the click handler, content left in
  its state.
- The group is an accordion: single mode (default, one open at a time — opening
  a closed row closes the open one, toggling the open one closes all) or
  multiple (independent toggles). `value`/`default_value`/`on_change` are the
  controlled/uncontrolled/reporting trio; `has_dividers` draws the row chrome
  (a wrapper plus per-row hairline suppressed on `:first-child`, because
  neither StyleX nor this port has child selectors); `density` (Compact /
  Balanced / Spacious) pads the rows and defaults to Balanced when dividers are
  shown; each row's own `chevron_position` still wins.
- **Named divergence, not hidden:** upstream coordinates items through a React
  context (a `Collapsible` with a `value` inside a `CollapsibleGroup` defers to
  the context). This port has no React context and does not fake one, so the
  group is **data-driven** instead — the same judgment TreeList made for its
  expansion state: each `item` carries its `value`, `trigger`, `children` and
  disabled state, the group owns the open set and renders the rows. The
  context has no counterpart, and consequently `value` is deliberately not
  accepted on `view`. `on_change` reports a `string list` in both modes
  (upstream's `onChange` returns a string in single mode); an empty list means
  nothing open. Other recorded divergences: no `themeProps` (styled by class,
  as every component here), no `usePressFeedback` (the named port-wide omission
  — `:active` covers the mouse arm, contract attribute emitted), `id` is
  caller-scoped (content ids `<id>-content`, group rows
  `<id>-<value>-content`), the group always renders its wrapper (upstream is
  DOM-less without dividers), no i18n (the chevron is unlabeled).
- CSS: `.astryx-collapsible`, `__trigger`, `__trigger-label`, `--disabled`,
  `--compact/balanced/spacious`, `__content` + `--hidden`,
  `__chevron` + `--start/--expanded/--closed`, `astryx-collapsible-group`,
  `--divided`; density pads trigger and content, divider chrome on the rows.
- Showcase: `collapsible` section, nine examples — starts open (the default),
  starts closed, a leading chevron, disabled (content stays in its state), a
  composed trigger, a controlled unit with a readout, a single group with
  dividers (an FAQ), a multiple group with a leading chevron on one row, a
  controlled multiple group with a readout.
- jsdom fixture: `collapsible-all` (six cases: default-open, explicit closed,
  disabled, leading chevron, single group seeded `a` with a disabled row,
  multiple group) with 14 structural checks — marked roots, `aria-expanded` /
  `aria-controls` linkage, hidden-but-mounted content, the disabled convention,
  chevron placement and direction, group mode/data markers, divider chrome,
  scope-and-value content ids.

Gates (all real runs):
- Compile: `dune build` exit 0.
- Component gate: **710/710, 0 failures** (was 696; +14 Collapsible checks).
- jsdom DOM + accessibility gate: **ALL CHECKS PASSED**.
- Browser showcase: **493/493** (was 482; +11 live Collapsible checks, and the
  section/example/nav counts moved to 72 sections / 460 examples / 72 nav
  links) and demo **25/25**. The interaction half belongs here because jsdom
  cannot pump Bonsai effects: a closed collapsible starts hidden with
  `aria-expanded=false`; a real click opens it (expanded=true, content shown,
  `aria-controls` still linked because the content never unmounts) and a second
  click closes it; a disabled trigger ignores clicks; a controlled unit's
  readout follows the toggle; a single-mode group starts with one row open,
  opening another closes the first, and toggling the open row closes all; a
  controlled multiple-mode group's readout shows the application's open set.
- Example count map: 460 examples, 72 sections, 72 nav links (Collapsible
  section: nine examples, all marked). Coverage panel: 70 / 33 / 103.
- Responsive: **66/66** — re-baselined (the new section changed the page);
  update run green, clean verify 66/66.
- Visual contract: `docs/visual/Collapsible.md` generated; 71 pages total.
- Full sweep: **SWEEP GREEN** — see `docs/verification/sweep-m50.txt`.
  PORT-STATUS 70/33. The component gate's own fixture caught the one real bug
  found on this milestone: `rt-cl-disabled` collided with an existing
  ListContainer case of the same id, so the disabled check was asserting on the
  wrong element; the fixture was renamed to the `rt-col-*` prefix and re-run.

## Gate 68 — M51: Breadcrumbs (coverage 70 -> 71)

The navigation trail, ported from `facebook/astryx` `Breadcrumbs/Breadcrumbs.tsx`
+ `BreadcrumbItem.tsx` as `Astryx.Breadcrumbs` + `Astryx.Breadcrumb_item`
(`src/breadcrumbs.ml` + `.mli`, `src/breadcrumb_item.ml` + `.mli`, registered in
`astryx.ml`; one coverage entry for the directory, the same call
Avatar/AvatarStatusDot and Collapsible made).

Verified this gate:
- `dune build` exit 0 (library + mli + showcase + rt_test + browser bundle).
- Component gate (`node test/run.mjs`): **719 checks, 0 failures** — the five
  fixture trails (basic auto-current, explicit current, opt-out, supporting
  variant + custom separator, unsafe href) assert the DOM contract: labelled
  nav > ol > li, link/button roots up to the current crumb, exactly one
  `aria-current="page"` only on the auto-current/explicit crumb, none when
  opted out, `data-astryx-variant="supporting"`, separator text with
  `aria-hidden`, and no `href` attribute for a refused `javascript:` URL.
- Browser gate: the Breadcrumbs live block clicks the handler crumb twice (the
  readout counts 1 then 2), reads the trail DOM per example, and the README
  showcase row matches the rendered page exactly.
- Responsive: baselines updated for the new section; 0.00% drift.
- Full `tools/gate-sweep.sh` GREEN (transcript `docs/verification/sweep-m51.txt`).

Divergences (also in `port.json`): items are data (upstream children), variant
and separator are arguments (upstream's layer-scoped context is the port-wide
named gap), the auto-current crumb is computed before first render instead of
a post-render DOM scan, the crumb menu trigger is a named gap pending a
trigger-less menu renderer, hrefs pass `Citation.is_safe_url` (unsafe URLs
render without `href`), and there is no themeProps.

## Gate 69 — M52: Carousel (coverage 71 -> 72)

- `src/carousel.ml` (Overflow_hook measurement + listener hook, scroll_by_js /
  wheel_js helpers, slide groups, nav pills) + `src/carousel.mli`; registered
  `module Carousel`.
- jsdom component gate: **728 checks, 0 failures** (9 new carousel checks).
- Browser gate: **511/511** (8 new live checks: edge-pill disabled at rest,
  fade mask at the overflowing edge, slide numbering, click-the-end-pill scroll
  with state following, wrap-around keeps both pills enabled, no-fade never
  masks, gap/snap/padding/no-buttons config on data).
- Showcase: 8 examples, section + nav + wiring; CSS block appended
  (gap/padding/fade/snap/pill/RTL mirror).
- README: 72 of 103 ported (M41–M52), 728 checks, 476 examples, 74 sections;
  PORT-STATUS 72/103; docs/visual/Carousel.md generated.
- Recorded divergences: no imperative handle, no post-commit focus handoff,
  inline button overlay (no popup top layer), English labels.

## Gate 70 — M53: TabList (coverage 72 -> 73)

- `src/tab_list.ml` + `src/tab_list.mli` (data-driven `Tab of … | Menu of …`;
  WAI-ARIA tabs vs nav semantics; roving-tabindex via the shared
  `Common.List_focus`; measured overflow with edge fades + pointer-only arrow
  buttons via the shared `Astryx.Scroll_overflow`; overflow menus in the house
  `Popover` layer with `role="menu"`/`menuitemradio`); registered
  `module Tab_list`.
- `src/scroll_overflow.ml` + `src/scroll_overflow.mli` — NEW shared module:
  the `Overflow_hook` measurement/listener hook, `scroll_by_js`, `wheel_js`
  and `is_rtl` extracted from carousel.ml (both components use upstream
  `useScrollOverflow`); registered `module Scroll_overflow`; carousel
  behavior-neutral proven by the jsdom gate.
- jsdom component gate: **736 checks, 0 failures** (8 new tab-list checks).
- Browser gate: **517/517** (6 new live checks: selected tab carries
  aria-current + roving tabindex and a real click moves both, the overflow
  trigger expands into menuitemradio options, the tablist pattern asserts
  role=tablist / role=tab / aria-selected / aria-controls with href ignored,
  layout=fill classifies wrapper and tabs).
- Responsive gate: **66/66** (probe now treats content inside a genuinely
  scrollable ancestor as scrolled content, not an escape — the tab strip's
  overflow menu trigger sits beyond the strip edge by design).
- Showcase: 4 examples, section + nav + wiring; CSS block appended
  (strip/bleed/mask/arrows/tab/menu classes + focus-visible).
- README: 73 of 103 ported (M41–M53), 736 checks, 480 examples, 75 sections;
  PORT-STATUS 73/103; docs/visual/TabList.md generated.
- Recorded divergences: data-driven (`items` list, no React context),
  horizontal arrows only (no vertical axis), no per-tab onClick, no keyboard
  hint, CSS hover/active instead of the touch-press overlay.

## Gate 71 — M54: Lightbox (coverage 73 -> 74)

- `src/lightbox.ml` + `src/lightbox.mli` (a fullscreen native `<dialog>`
  opened with `showModal()` — the top layer, the inert page and the focus trap
  are the platform's, as for Dialog — over a `Lightbox_hook` vdom hook that
  keeps the element in step with the caller's `is_open`, remembers and
  restores the trigger, saves/restores the body scroll lock, resets zoom/pan
  on every media change and mirrors navigation into the polite live region);
  registered `module Lightbox`.
- The gallery index is controlled or uncontrolled (`?index` / `?default_index`
  / `?on_index_change`); prev/next stay mounted and disabled at the edges so
  driving to a boundary never unmounts the focused control. Zoom/pan (images
  only): double-click / Enter / Space / `+` / `-` zoom, drag with pointer
  capture and arrow-key pan while zoomed, with the transform written straight
  onto the image (upstream's own dynamic-style mechanism). Dismissal matrix:
  Escape always, backdrop click, close button — with the drag-release guard so
  a pan that ends over the backdrop does not dismiss. `data-astryx-*`
  attributes per house style; one `class` attribute per element.
- jsdom component gate: **743 checks, 0 failures** (7 new lightbox checks:
  three cases mount, the gallery is a closed native dialog named by the
  current media, the first item renders with the zoomable wrapper, prev
  disabled at the first edge / next enabled / counter `1 / 3`, a single-image
  lightbox has no nav or counter, video renders controls + autoplay and no
  zoom target, close + polite live region present).
- Browser gate: **526/526** (9 new live checks: opening puts the dialog in the
  top layer (`:modal`) with focus taken in, the body scroll lock engages, the
  first item names the dialog and the counter reads `1 / 3` with prev
  disabled, Next drives to item 2 and re-names the dialog, a double-click
  zooms the image and a second zooms back out, Escape closes with scroll
  restored and focus back on the trigger, the close button closes it too).
- Responsive gate: **66/66**; showcase + demo baselines updated.
- Showcase: 3 examples (gallery + zoom + caption, single image with zoom,
  video with auto-play — each with a real trigger button), section + nav +
  page wiring; `media/sample.mp4` (generated 1-frame clip) served from the
  repo root; CSS block appended (dialog/backdrop/container/media-group/
  wrapper/image/video/caption/close/nav/counter classes, reduced-motion aware).
- README: 74 of 103 ported (M41–M54), 743 checks, 483 examples, 76 sections,
  coverage 74/29, 73 visual pages; PORT-STATUS 74/103; docs/visual/Lightbox.md
  generated.
- Recorded divergences: `useLightbox` not ported (the caller owns `is_open` /
  `on_index_change` and builds its own trigger — a plain Button already
  carries the trigger contract), no layer-dismissal stack (Escape always
  closes, as Dialog's own matrix does), i18n not ported (English labels,
  counter and announce strings), simple single-lock body scroll (no nested
  counter), and the zoom/pan transform written as one inline style (no other
  style lives on that element to collide with).

## Gate 72 — M55: HoverCard (coverage 74 -> 75)

- `src/hover_card.ml` + `src/hover_card.mli` (the layer surface that appears
  beside its trigger while the trigger, or the card itself, is hovered or
  focused — a tooltip is a short text note, a hover card is for interactive
  content): hover opens after `delay_ms` (300 ms), focus opens at once,
  leaving closes after `hide_delay_ms` (200 ms), a pointer or focus that
  lands on the card keeps it open; `role="dialog"`/`aria-label` when
  labelled, `role="group"` when unnamed, the trigger carrying
  `aria-haspopup="dialog"` and `aria-controls`/`aria-describedby` only while
  open; controlled mode via `~is_open` (+ `~is_default_open`);
  `has_hover_indication` Auto/Show/Hide (auto only for text-only triggers,
  detected by pattern-matching the trigger node); `is_enabled`;
  `focus_trigger`; placement/alignment; the card is absent from the DOM
  while closed; registered `module Hover_card`.
- The show and hide delays share one `Common.Delay_hook` whose input says
  which timer is live — two same-named hooks on one element would fuse (the
  hook map is keyed by name and `combine` keeps the left input's delay with
  both effects), which read as "never opens"; that is the one non-obvious
  house lesson from this milestone.
- jsdom component gate: **743 checks, 0 failures** (no new — HoverCard is
  fully stateful, like Tooltip, so its checks live in the browser gate).
- Browser gate: **540/540** (14 new live checks: closed cards absent from the
  DOM while the controlled one is present, the controlled card is a named
  dialog with its label, the labelled wrapper advertises the dialog
  relationship, `aria-controls` while open, hover-open after the delay as the
  named dialog, the open wrapper's `aria-controls`, the `above` placement
  class, the unnamed text-trigger card as a group described by it, auto
  indication + tab stop on a text-only trigger, no indication on an element
  trigger, `Indicate_hide` override, Escape closes the focused group, a
  disabled card never opens, leaving closes after the hide delay).
- Responsive gate: **66/66**; showcase baselines updated (demo untouched).
- Showcase: 7 examples (named dialog above, unnamed text-trigger group below,
  start/end placements, disabled, always-indicated, controlled open), section
  + nav + page wiring; CSS block appended (anchor/surface/content/arrow
  classes, placement + alignment modifiers, auto indication).
- README: 75 of 103 ported (M41–M55), 743 checks, 490 examples, 77 sections,
  coverage 75/28; PORT-STATUS 75/103; docs/visual/HoverCard.md generated.
- Recorded divergences (stated in the mli): no touch mode; no outside-click
  dismissal and no top-layer portal (the card is an ordinary absolutely
  positioned element beside its anchor, the convention Tooltip and
  DropdownMenu established); auto focus trigger reads as always (a Vdom tree
  cannot ask whether its first DOM child is focusable — a text-only trigger
  carries `tabindex=0` so the wrapper is focusable, and an element child's
  focusin bubbles to the wrapper); no focus restore after Escape (state, not
  DOM, closes), the same standing as Tooltip.

## Gate 73 — M56: Timestamp (coverage 75 -> 76)

- `src/timestamp.ml` + `src/timestamp.mli` — the calendar and the clock, the
  port that reads time: a date/time value rendered as human text on a semantic
  `<time>` carrying an ISO 8601 `datetime`. The formats are upstream's set:
  `Relative` ("2 hours ago"), `Relative_short`, `Auto` (relative inside the
  7-day `~auto_threshold`, `Date_time` beyond), the absolute
  `Date`/`Date_long`/`Date_weekday`/`Date_time`/`Time`, the `Full` long style
  that backs a relative reading's accessible name and the card's default
  line, and the zone-independent machine shapes `System_date`/`System_date_time`/
  `System_time`/`Unix_seconds`. `value` is `Str` (ISO 8601, or anything
  `new Date` takes) or `Num` (unix, with upstream's heuristic: numbers under
  1e12 are seconds, the rest milliseconds).
- The viewer's zone is explicit because it is observable: the visible text
  always reads in the host's own zone (no `timeZone` is handed to `Intl` for
  it), only the card names others, `~is_timezone_shown` is honoured by
  `Date_time`/`Time` only, and `Full` always shows a zone name while the
  `system_*` shapes never do. `zone_parts` is the one `Intl` dependency of the
  `system_*` shapes and is public so the gate can assert it. The formatting
  is split the house way: `format_instant`, `format_relative_time` and
  `format_tooltip_lines` are pure functions over the host's `Intl`, tested as
  strings — node's and the browser's `Intl` were first verified to agree
  before the fixture was trusted.
- The hover surface is the port's own `Hover_card` with upstream's three
  settings verbatim (`Above`, `focus_trigger = Always`, always indicated): one
  row per configured `~tooltip_entries` (zone resolution and the
  zone-abbreviation rule live in `format_tooltip_lines`), copyable rows write
  through `navigator.clipboard`, the "Copied" announcement is hosted in the
  card itself because the port cannot ask the application for an announcer,
  and an omitted `id` allocates one deterministic id per mounted instance so
  `aria-controls` always names the card on screen. The tooltip gate is
  upstream's exactly: `has_tooltip && (relative || entries)` — an absolute
  format with no configured entries shows no card and no tab stop, and an
  empty entry list is not a second way to spell "off". `~is_live` keeps a
  relative reading fresh at the interval its own precision dictates (1 s
  under a minute, 30 s under an hour, 1 min under a day, 5 min beyond —
  upstream's `getLiveInterval`). An unparseable value renders nothing
  (upstream's behaviour) and reports through `data-astryx-invalid` on a hidden
  probing node instead of upstream's dev-only console warn.
- jsdom component gate: **751 checks, 0 failures** (19 new — the
  `timestamp_component` fixture mounting `"timestamp-all"`, asserting exact
  rendered text per format, the `datetime`/`aria-label`/invalid-probe
  attributes and card presence).
- Browser gate: **550/550** (16 new live checks: exact render per format, the
  hover card with one row per zone, the label+action grid template, copy
  buttons, the host announce region, the named dialog the trigger points at,
  leave-unmounts). This run also saw two real fixes on top of the port: the
  card copy-row anchor was not clickable (caught by the ClickableCard-style
  link check, fixed), and the showcase screenshot was being served by a stale
  worktree server on 8791 — the harness now detects that and the server was
  restarted from the repo root.
- The sweep's first pass was red on exactly two checks, both stale EXPECTED
  counters in verify-browser.mjs (75/28/103 while the generators had already
  moved coverage.json to 76/27/103 — the previous gate run happened before the
  generators re-ran). The constants were corrected and the gate re-ran 550/550
  before the record; the sweep below is green.
- Responsive gate: **66/66** (the first full-compare run after the showcase
  baselines were re-captured; the 58-check reading at M56 work time was the
  same gate under `--update-baseline`, which skips the eight per-page
  pixel-compare checks — the 66 recorded at M54 stands).
- Showcase: 10 Timestamp examples (relative, relative-short, auto, date,
  date-long, date-weekday, date-time, time, system shapes, hover card),
  78 sections, 500 examples, 78 nav links.
- README: 76 of 103 ported (M41–M56), 751 checks, 550 browser checks,
  showcase 76/500/78, coverage 76/27/103, visual 77 pages + INDEX; PORT-STATUS
  76/103; docs/visual/Timestamp.md generated. Generators re-ran clean
  (gen-coverage, gen-visual-contract, gen-references, gen-port-status —
  references before port-status).
- Divergences named in the mli: the locale is fixed to `en` (no locale
  provider; the `Intl` calls and the card's strings are the upstream English
  defaults, and a locale-aware caller can use `format_instant`/
  `format_relative_time` directly); no lazy import (the hover card is compiled
  in — the port has no code splitting); `themeProps` has no counterpart; the
  live region is the card's own rather than the application's announcer; the
  invalid value is reported through `data-astryx-invalid` rather than a
  dev-only console warn; touch handling is the hover card's own (no touch
  mode either, as upstream).


## Gate 74 — M57: ComplexSelector (coverage 76 -> 77)

- `src/complex_selector.ml` + `src/complex_selector.mli` — a rich custom
  selector shell, ported from upstream `ComplexSelector/ComplexSelector.tsx`
  (1895 LOC): the component owns the field, the trigger, the popup and the
  focus contract, and hands the application a render function for the
  selection surface (`children value commit close state`). The trigger is
  OURS — the port builds the field, the control box, the button, the spinner
  and the chevron, so there is no need for the layer-trigger hook that *finds*
  a button (the arrangement DropdownMenu reached for the same reason); the
  ARIA and the handlers go on the button it builds.
- The popup is the platform's native popover mechanism, exactly as `Popover`
  uses it: `popover="auto"` plus the shared `Layer_hook`, the same CSS anchor
  positioning, `role="dialog"` + `aria-modal="true"` + `aria-label` = the
  field's label, `tabindex="-1"` so the surface itself is a fallback focus
  target, and no close button — the application's content speaks for itself,
  as upstream configures `usePopover` here. It is NOT composed through
  `Popover`, because that composition would inherit Popover's marker, close
  button and content class. Opening moves focus into the first focusable
  control of the content (or the surface itself) one frame late — the surface
  is `display:none` until the layer mechanism shows it and the two hooks run
  in unspecified order after the same DOM patch (the same trap Popover and
  the dialog hit) — and the platform's own dismissal restores focus to the
  trigger, because the trigger is the anchor of the whole widget.
- The surface is always in the DOM; the application's `children` returns the
  option nodes, which live inside the popup's content container and are
  hidden by the platform. The trigger label is a *computation* (`string
  Bonsai.t`), not a string: upstream builds `triggerContent` from the
  caller's state in render (`triggerLabel ?? placeholder` — confirmed against
  the source), and so does the caller here; omit it and the trigger reads the
  placeholder ("Choose...", upstream's own en catalogue) with the
  `--placeholder` class. `commit` calls `on_change` and nothing else;
  `close` dismisses the same way every other route does.
- State is owned the DropdownMenu way: both `~is_open` and `~on_open_change`
  given — the caller owns it; neither — the selector owns its state; only
  `on_open_change` — observation; `is_open` alone is refused with a `raise`
  rather than silently ignored. `is_loading` drives the trigger spinner and
  `aria-busy` and reaches the child's `state.is_busy`. Variant (`Input`/
  `Secondary`/`Ghost`), `size` (sm/md/lg from the shared scale), status
  (colour + `aria-invalid` + message via the port's Field), placement and
  alignment all render as classes on the same box.
- The port's own Field is composed and is the reason for the build lesson of
  this milestone: `module Field_ = Field` must be bound **before** `open!
  Core` (Core defines a module named Field — the first-class-fields module),
  and the `.mli` reference paths use the alias too. The same lesson is
  already documented at `text_input.ml`; a fresh module is where the repo's
  old lessons get forgotten.
- Showcase: 11 ComplexSelector examples (basic interactive select+close,
  description + start icon, secondary, ghost, disabled, error status, sizes
  sm/md/lg, busy/`is_loading`, externally controlled open/close), 79
  sections, 511 examples, 79 nav links. The controlled example is run for
  real: the caller's own button drives `is_open`, and Escape rides back
  through `on_open_change`.
- Component gate (jsdom, structural): 762 checks, 0 failures — 11 new. The
  trigger's full ARIA contract, the popup's dialog contract, three option
  buttons in the content, variant/status/disabled/busy classes, the
  placeholder reading and the chevron indicator are all asserted; the
  open/close behaviour is the platform's popover mechanism, which jsdom
  cannot run, so it lives in the browser gate.
- Real-browser gate: 560 checks, 0 failures — 10 new, all on
  `:popover-open`/`aria-expanded` rather than geometry (the same stance
  Popover took): a click opens the native popover and focus enters the first
  option, choosing one commits through the caller and renames the trigger
  from the caller's own label computation, ArrowDown opens it from the
  keyboard, Escape dismisses it and returns focus to the trigger,
  `is_loading` announces `aria-busy`, shows the spinner and reaches the
  child's render state, and the controlled selector follows the caller's own
  button and reports Escape back. Two of the first run's three failures were
  gate timing (the check read `aria-expanded` before the state round-trip —
  the wait now targets the attribute, not `:popover-open`); the third was a
  wrong probe (the child's readout renders in the popup content, not the
  control box). No component change was needed.
- README: 77 of 103 ported (M41–M57), 762 component checks, 560 browser
  checks, showcase 77/511/79, coverage 77/26/103, visual 78 pages + INDEX;
  PORT-STATUS 77/103; `docs/visual/ComplexSelector.md` generated. Generators
  re-ran clean (gen-coverage, gen-visual-contract, gen-references,
  gen-port-status — references before port-status).
- Divergences named in the mli: `changeAction` and the optimistic value are
  not ported (the standing M48 house call — `is_loading` replaces the pair,
  the application owns the async work); `renderTrigger` (a caller-rendered
  opener cannot be wired to the layer mechanism, which must sit on the
  trigger element); no imperative `handleRef` — `is_open`/`on_open_change`
  are the non-imperative equivalent; `startIcon` is an icon *name*, not a
  node; `children` is a plain function and cannot own Bonsai state (a child
  that needs state is driven by the application); no `labelTooltip`; the
  container/control styling props and the caller's `aria-describedby`
  override are not exposed; English strings are fixed (no i18n provider); the
  press-feedback `data-astryx-press` overlay is the campaign-wide named
  omission (`:active` scale reproduced); `Start`/`End` placements fall back
  to the fade-in entry because there is no horizontal-slide house preset
  (named in the CSS block).

## Gate 75 — M58: Outline (coverage 77 -> 78)

- `src/outline.ml` + `src/outline.mli` (the table of contents that lives
  beside a scrolling area and follows it): the scroll-spy, programmatic
  scroll with settle detection, active-state DOM sync and click/Space
  activation all live in one vdom hook attached to the `<nav>` — it
  rAF-throttles scroll resolution and writes `aria-current="location"` and
  the roving tabindex straight to the DOM, the house stance for
  DOM-authoritative components. Roving arrow keys/Home/End reuse
  `Common.List_focus` with `prefer_existing_stop:true` so the active heading
  keeps the tab stop. Upstream math ported exactly: activation line = root
  top + `offset` + `scroll-margin-top`, 1px tolerance, at-bottom→last-item
  rule, 1200 ms `scrollend` fallback, manual-scroll interrupt resumes
  tracking. Link seam is a plain `<a href="#id">`; indicator anchored via
  CSS `anchor-name` on `[aria-current="location"]`. Divergences named in the
  mli: `scrollContainerRef` → CSS selector, no component-managed scroll for
  `has_scroll_on_click=true` (the browser handles it), press feedback
  omitted (campaign-wide).
- Two real bugs found in verification:
  1. The scroll-spy rAF handle was never cleared after the first resolution,
     so exactly one scroll event was ever processed. Fixed: the callback
     clears the handle before resolving.
  2. Showcase layout at 320px: the pane/frame content column collapsed to
     22px (non-wrapping flex + shrinkable content), producing a 367px
     horizontal overflow despite no element measuring past the section.
     Fixed in site.css (wrap + 140px content basis) — the pane and frame
     now stack on narrow viewports.
- Component gate: **770 checks, 0 failures** (8 new outline checks: items by
  level, labels, role=table of contents, active first item at rest, arrow
  roving disabled at the ends, aria-live readout).
- Browser gate: **572/572** (12 new live checks: scroll-spy at-bottom rule,
  click → hash + `aria-current` + roving tab stop, Space activation,
  controlled toggle cycle, scoped container, `has_scroll_on_click=false`,
  custom labels, README-row check). Demo mode: 25/25.
- Responsive gate: **66/66, 0.00% drift** against the fresh baseline
  (showcase grew again; the 320px horizontal-overflow check is precisely what
  caught the layout bug above).
- Showcase: 9 examples (basic live pane, nested levels, compact,
  controlled activeId with readout + real content targets, offset under a
  fixed header, scoped container, `has_scroll_on_click=false`, custom label,
  indicator sample), section + nav + page wiring; CSS block appended (track/
  divider/indicator, density + indent levels 1–4, active state keyed off the
  attribute).
- README: 78 of 103 ported (M41–M58), 770 component checks, 572 browser
  checks, showcase 78/520/80, coverage 78/25/103, visual 79 pages + INDEX;
  PORT-STATUS 78/103; docs/visual/Outline.md generated.
Gate 76 — M61: Resizable (coverage 78 → 79)

The upstream Resizable is a hook and a component: useResizable owns a
region's size, and ResizeHandle is the draggable separator that drives
it. The port keeps that split because it is the API — Resizable.create
is the hook (it owns the size, the bounds, the collapse state and the
localStorage persistence, and hands back a region that is the port's
equivalent of upstream's ResizableRegion and its ResizableProps in one
record), Resizable.handle_view is the component, and Resizable.view
composes the two into the panel/separator/content layout that upstream's
stories build by hand.

Behaviour follows upstream: the size is clamped into the bounds and
snapped to the nearest snap point; a collapsible region collapses when
it is dragged below the collapse threshold and expands again over it;
pointer-up ends the gesture and releases the frozen basis; the separator
is a WAI-ARIA separator (role, orientation, value now/min/max, value
text while collapsed, label, disabled) and a tab stop whose arrow keys
resize the panel by 10px, 50px with Shift, with Home and End at the
bounds and Enter toggling the collapse; a reversed or right-to-left
layout swaps the arrow directions; the pill sits on the panel's side and
flips when the panel collapses.

The bug the browser gate found, and what it took to fix it:

The first port computed the keyboard target from the size the region had
when the handler was built. A key event is handled against the model as
it stands when the effect is processed, and key repeat delivers several
events before the next render — so every one of them was measured
against the same stale size, and holding the arrow key moved the region
one step and then stalled. The probe that found it pressed the key five
times with no delay and watched the size advance by 10px instead of
50px; with an 80ms delay between presses all five landed, which is the
signature of a stale read rather than a dropped event.

The fix accumulates the steps: the region carries the keyboard steps
that have been handled but are not in the model yet, each event adds to
the total, and the last event applied carries the whole total, so the
size advances by the full number of steps. The same applies to the snap
points, which are counted rather than picked. The accumulators are
spent as soon as the model carries them. The gate now presses the key
twelve times with no delay and expects the value to sit exactly on the
configured maximum, and forty times the other way and expects it to sit
on the minimum.

Divergences are documented in the .mli: the hook is a node rather than a
function call, there is no containerRef (the basis is a number the caller
measures), a percentage default is resolved once at creation, the vdom
has no pointercancel, and there is no theme-props layer.

Gates: build exit 0 · component 770/0 · DOM + accessibility 59/0 ·
browser 580/0 (572 + 8 new Resizable checks: the separator's role,
orientation, value, label and tab stop; ArrowRight by 10px; Shift +
ArrowRight by 50px; the clamp at the maximum; the clamp at the minimum;
the collapsible separator's bounds; a disabled separator out of the tab
order; the vertical variant's orientation) · responsive 66/0, 0.00%
drift (the baseline was updated: the section makes the page ~2,000px
taller) · coverage 79/24/103 · visual 79 pages + INDEX.
Gate 77 — M59: Toast and M64: MobileNav (coverage 79 → 81)

Two ports landed together, and the gate found two real bugs that only a
real browser can find.

M59 Toast. Upstream mounts toasts through a portal (Layer/modalOutlet);
the OCaml Layer has no outlet, so the port's viewport is a caller-mounted
node the application places where the toasts belong. The toast itself
carries its action, its duration and its dismissal.

The bug: the port read the clock through
`Js.Unsafe.pure_js_expr "Date.now()"` and then called the result as a
function. The expression evaluates to a number, so every toast that
tried to time itself threw "now_ms_js is not a function" — and because
the exception was unhandled, it took the whole Bonsai application down
with it: the radio group, the tooltip and the dialog all went with it,
which is what the first gate run reported. The clock is now read per
call through the house's `Js.Unsafe.eval_string` pattern, the way
timestamp.ml and timer.ml read it: a constant would have frozen every
toast's timer at the moment the module loaded.

M64 MobileNav. The narrow-screen navigation: a bar with a menu button
that opens a sheet, with a title header, a caller's own header, no
header at all, an end-edge variant and a narrow one.

The bug: the section put a graph where a node belongs — a
`Vdom.Node.t Bonsai.t` straight into a node list. It compiled in the
worker's own worktree, because dune only compiles a showcase section
once something references it, and nothing did until the integrator wired
the section in. The lesson went back to the other seven workers, who
now compile their sections before committing. The fix is the house's
`Bonsai.map3`.

Both ports land their own files only: the implementation and its .mli,
the CSS part, the showcase section and one line in src/astryx.ml. The
integrator owns the shared files — showcase.ml, port.json, the
stylesheet, the gate's counts, the README, the generators and this
record. The tooling that does it (tools/integrate-port.py and
tools/sync-counts.py) was rehearsed against a synthetic component first,
which is how the counting traps were found: a count site names its
number twice (in the label and in the comparison), a section name with a
space has to be a quoted JS key, and the coverage panel is generated
from port.json and has to be regenerated before the gate compares it
against the page.

Gates: build exit 0 · component 770/0 · DOM + accessibility 59/0 ·
browser 580/0 (572 + 8 Resizable checks) · responsive 66/0, 0.00% drift
(baseline updated: the two sections make the page ~2,000px taller) ·
coverage 81/22/103 · showcase 83 sections / 539 examples · visual 81
pages + INDEX.

Gate 78 — M65: Tokenizer (coverage 81 → 82)

The multi-select field: the selections are chips beside a combobox
input, the menu is a listbox, and a selected value can be taken back.
Nine showcase examples - the plain field, the field that searches, the
one that creates, the one with a maximum, the disabled one with its
reason, the one with a validation message, the two sizes, the one that
overflows into a single line, and the one that carries a hidden input
per selected id for a form.

The port settled a question the campaign had been circling: upstream's
search source returns promises and its queries are debounced, but a
Bonsai effect cannot await a promise. So the port's source is a plain
function, a query runs at once, and there is no busy state - the app
reports an in-flight remote search itself. That divergence is recorded
in the .mli, and Typeahead follows the same precedent rather than
inventing a second async contract.

What the gate found: the section's overflow example asked for a field
320px wide, and on a 320px phone that widened the page by 41 pixels -
the page's own scrollWidth said so. The example now asks for
min(320px, 100%), so it keeps the width it was demonstrating on a
desktop and yields on a phone.

The gate's element-level check also learned something: it used to
exempt only content inside a *scrollable* ancestor, so it flagged the
tokens that upstream's 'unfocusedInline' behaviour deliberately clips
to one line with a "+ N more" indicator. Content clipped by an
ancestor is not visible off-screen, so the check now exempts clipped
ancestors too. The page-level check - the one that catches a component
that actually widens the page - is unchanged, and it is the one that
caught the 320px field.

The worker's two commits touched only the five files a port owns: the
implementation and its .mli, the CSS part, the showcase section and one
line in src/astryx.ml. The integrator owns the shared files.

Gates: build exit 0 · component 807/0 · DOM + accessibility 59/0 ·
browser 600/0 (592 + 8 new Tokenizer checks: the combobox and what it
controls, the listbox and that it is hidden while closed, the menu
opening as you type with the active option on the input, the selected
values as tokens in a labelled group with a remove control each, the
error announced, the disabled field readonly with aria-disabled, and
the hidden form carriers) · responsive 66/0 (the baseline was updated:
the section makes the page taller) · coverage 82/21/103 · showcase 84
sections / 548 examples · visual 82 pages + INDEX.

### Gate 79 — M66: MultiSelector (coverage 82 → 83)

**820/820 component checks · 608/608 browser checks · 66/66 responsive · SWEEP GREEN**

The multi-select field: the chosen set comes in as a value and goes out
through `on_change`, the options may carry dividers and grouped
sections, the menu filters on what you type, and the keyboard is
upstream's model — arrows, Home/End, PageUp/PageDown, Enter and Space to
toggle, Escape to close, and a 500ms typeahead buffer. The list is a
native popover drawn in place.

Three bugs, and two of them were in the house rather than the port:

- A section's options rendered **twice** — once bare in the list and
  once inside the section's group — and the second copy carried the same
  id, so `aria-activedescendant` named two elements. The section's rows
  are now made for the group and not added to the list.
- The browser gate asked whether an indicator's mark "paints". A mark
  inside a **closed** popover has no box, because nothing is painted
  there. A mark that exists but is invisible is the bug; a mark nobody
  can see yet is not — so the gate now asks whether the mark renders.
- The integrator's check for "is this section already wired in?" demanded
  a trailing space that the entry it inserts does not carry, so a second
  integration added the section a second time. The check no longer
  demands the space, and the duplicate is gone.

Full record: `docs/verification/commit-m66.txt`.

### Gate 80 — M67: Stepper (coverage 83 → 84)

**825/825 component checks · 617/617 browser checks · 66/66 responsive · SWEEP GREEN**

The multi-step flow control. Upstream splits it into a `Stepper` and a
`Step` that register through React context; Bonsai has no context, so
the port is data-driven — the steps are a list, and the current step is
a value the caller owns. The stepper never moves itself; it reports a
click.

The markup emitted three classes the stylesheet never styled: a
completed step, an optional step, and the collapsed root. The first
two now have rules. The third deliberately does not — a collapsed
stepper hides its steps *visually*, and the steps stay in the DOM for
the accessible list, so `display: none` on the list would take them out
of the accessibility tree too. The browser gate now checks that the
collapsed stepper still has all four of its steps in the DOM.

One assertion of ours was wrong rather than the port: the collapsed
summary was expected to carry a "Previous step" control, but the
current step *is* the first one, so there is nothing to go back to.

Full record: `docs/verification/commit-m67.txt`.

### Gate 81 — M68 Pagination, M69 TopNav, M70 CodeBlock (coverage 84 → 87)

**839/839 component checks · 647/647 browser checks · 66/66 responsive · SWEEP GREEN**

The Pagination's page range follows upstream's `generatePageRange` (the
implementation, not its stale docstring). The TopNav's heading is a value
the bar is given, rather than a child that registers itself. The
CodeBlock carries the language, the title, the copy button, the line
numbers, the diff glyphs and the collapsible header.

Three checks were wrong rather than the ports: the Carousel's end-pill
check was racy (upstream's own test says the right button *is* disabled at
the end), two checks asked for "[aria-live]" and found the house Button's
own empty live region, and two waited for content that is in the document
whether the menu is open or not.

**87 of 103 ported. 16 to go.**

### Gate 82 — M71 Calendar (coverage 87 → 88)

**846/846 component checks · 660/660 browser checks · responsive 66/66 · SWEEP GREEN**

The Calendar is the month grid: one month or two, the days and their states, the range pick, the keyboard walk over the grid, and the live announcement of what a pick did. The grid is a `role="grid"` named for its month, every day is a `role="gridcell"` holding a button that names its full date, a range grid is `aria-multiselectable`, and a day that cannot be picked says so with `aria-disabled` instead of leaving the keyboard order. Upstream's `PlainDate` came with it, as `src/plain_date.ml` — the ISO dates, the month arithmetic, the day and week numbers — and it is the foundation the date inputs build on.

The worker's file needed a fair amount of repair before it would parse: `external` is a reserved word in OCaml, the `and render` sat after a `;;` and orphaned from its `let`, the month grid was missing a `]`, `node##focus` needs a preprocessor the library does not use, and the `model` record type was never written at all — the worker's own uses said what it had to hold. A day that cannot be picked is marked `aria-disabled` rather than natively disabled, so it keeps its place in the keyboard order; upstream draws that distinction and the house's `day_state` does not, so the port takes the gentler of the two and says so in the interface.

### Gate 83 — M72 Chat (coverage 88 → 89)

**853/853 component checks · 671/671 browser checks · responsive 66/66 · SWEEP GREEN**

The Chat is the thread and the composer: the messages above, the input below, and the states a thread can be in. The transcript is a log region (`role="log"`, `aria-live="polite"`), every message is a bubble that names its author, and a run of messages from one author reads as one block — the first, the middle and the last of the run are marked, so the avatar and the name are drawn once rather than on every message. The composer is the caller's: the text is a value the application owns and sending is the application's decision, so the port takes the value and the three callbacks and draws the input, the send button and the stop button.

The responsive gate caught a real bug: the edited-message editor had `min-width: 280px` hard-coded, which pushed the chat to 347px on a 320px phone. The minimum is gone and the textarea takes `min-width: 0` and `box-sizing: border-box`, so the editor follows the column it sits in.

### Gate 84 — M73 Selector (coverage 89 → 90)

**860/860 component checks · 687/687 browser checks · responsive 66/66 · SWEEP GREEN**

The Selector is the option list: the control box, the panel and the rows. The control is a combobox — a button that owns the listbox it controls and reports whether it is open — and the panel is a native popover, so the platform dismisses it. The focus stays on the control and the highlighted row is reported with `aria-activedescendant`, which is upstream's own arrangement: the control's identity does not change when the panel opens. The list may be grouped into titled sections, may carry a divider, and may carry a search field — and when it does, the field takes the combobox role over from the control.

The worker's file had never been type-checked. The `option` union shadowed the standard one, `Stdlib.option` and `Stdlib.Some` do not exist in this compiler, `Vdom.Attr.on_input` is curried rather than a tuple, `Vdom.Node.div` takes no unit argument while `Vdom.Node.input` does, and the house's Core spells its list and string helpers differently (`List.filter ~f:`, `String.is_substring`, `String.strip`, `List.find`). The gate found one real bug of its own: Enter took the head of the row list instead of the highlighted row, so it only worked while the first row was highlighted — the row is now looked up by the highlight's index, and the check drives ArrowDown first so the second row is the one picked. The trigger was also 46px wide, because nothing gave it a width; it now carries a minimum width and a focus ring.

### Gate 85 — M74 BottomSheet (coverage 90 → 91)

**864/864 component checks · 693/693 browser checks · responsive 66/66 · SWEEP GREEN**

The BottomSheet is the sheet that comes up from the bottom of the screen, and it comes in the shapes a sheet can be. The sheet is a native `<dialog>`, so the page behind it is inert while it is open, Escape closes it, and the platform owns the focus. The sheet never opens or closes itself — `is_open` and `on_open_change` are the caller's, which is the only way a sheet can be told to stay put. The purpose decides how it may be dismissed: an ordinary sheet goes away on a scrim click, a form sheet keeps what was typed into it, and a required sheet refuses every implicit dismissal and is an `alertdialog` because it has to be answered. A sheet with stops settles at one of them when the handle is dragged, and an inline sheet is ordinary markup written into the page, with no top layer and no scrim.

The worker's section was not the house's shape at all — it drew its own headings and wrappers, so it produced no `data-showcase-component` and no `data-example` markers and the browser gate could not see it; it is now the house's `section`/`ex` pair, with the examples mapped from graphs to nodes before they are wrapped. `Bonsai.state'` hands back an update-style setter and the setter is a tree, not a function. A labelled argument cannot shadow the function of the same name, so the helper's `~heading` and `~note` parameters are `~title` and `~copy` now.

The responsive gate caught a real bug: the inline sheet's slot is pinned to the bottom edge of a fixed overlay, and an inline sheet has no overlay, so the slot stayed absolutely positioned and the sheet's content was out of flow — the sheet had no height at all. The inline variant's slot is in the flow now, and the sheet is as tall as its content.

### Gate 86 — M75 CommandPalette (coverage 91 → 92)

**869/869 component checks · 699/699 browser checks · responsive 66/66 · SWEEP GREEN**

The CommandPalette is the modal command list: a search field, the commands it filters, and the keyboard model that walks them. The commands are the application's — the palette is given a source, a function of the query that answers with items — and the palette owns only the query, the highlight and the open state. The field is a combobox that owns the listbox it filters, the list is a listbox of options, the commands are grouped under named headings, the active row is named with `aria-activedescendant` so the focus stays in the field, and the result count is announced in one polite live region.

The gate found a real bug: the palette opened with nothing highlighted — the query change cleared the highlight and nothing ever set it again, so the arrow keys could not move from the first result and the active row was never named. The highlight is derived now: with nothing chosen, the first result is the highlighted one, which is upstream's own rule, and the state still keeps the user's own choice when there is one. The live region was also missing `aria-atomic`, so the announcement could be read in pieces rather than whole, and the palette was 640px wide, which pushed the page sideways on a 320px phone — it is never wider than the column it sits in now.

### Gate 87 — M76 ContextMenu

The context menu that opens where the pointer is, with the DropdownMenu
phase-2 internals upstream folds into it: the layer that positions the
menu at the pointer, the overflow measurement, and the typeahead.

Four real defects were found by the gates and fixed before the milestone
landed: the trigger carried no id for the pointer measurement to read, the
port used upstream's `data-astryx-target` instead of the house's
`data-astryx-component` marker, the pointer surface's rows never got the
item class (so the menu's CSS did not apply to them and the keyboard model
could not find them), and the menu neither took the focus when it opened
nor gave it back when it closed.

- component 871/871, browser 709/709, responsive 66/66
- sweep: SWEEP GREEN
- record: `docs/verification/commit-m76.txt`

### Gate 88 — M77 AppShell

The application frame: a header, a side panel and the main content, with
the mobile layout the shell falls back to below the width breakpoint.
Upstream's four React contexts became arguments — the navigation slots
are functions of the mode they are drawn in — and the mobile state is
the shell's own.

The worker branch had never been type-checked. The repairs included the
`breakpoint` variant's `None` constructor shadowing `Stdlib.None` for the
whole module, `Bonsai.map2` being piped into (which reverses its
argument order), the house's attribute helpers returning lists where
single attributes were expected, and `Layout`'s children-then-unit
argument order reversed in three places.

The gates found two more: a check that looked for the banner landmark
in a frame that has no header, and a check that opened the mobile drawer
without closing it — the drawer is a modal, so it went on covering the
page and the check after it could not right-click its trigger.

- component 876/876, browser 715/715, responsive 66/66
- sweep: SWEEP GREEN
- record: `docs/verification/commit-m77.txt`

### Gate 89 — M78 Typeahead

The typeahead is a combobox: the field owns the query, the menu owns the
highlighted option, and the application owns the selection. Upstream ships
the family as three components, and the port keeps all three boundaries.

The source is synchronous, so there is no busy state and no debounce — the
same contract the Tokenizer port settled on, and recorded in the
interface's own list of what upstream has and this port does not.

A parameterized type is instantiated argument-first in this tree
("string Typeahead.item"). The house's own code follows the same order
(bool Bonsai.t); a port that writes the constructor first does not
compile here, and the error it gives does not name the real cause.

Component 883/883, browser 727/727, responsive 66/66, sweep SWEEP GREEN.

### Gate 90 — M79 DateRangeInput

The date range input is two text fields for the ends of a range, and a calendar to pick them. The field owns the draft text of each end and whether the calendar is open; the application owns the committed range. A range picked in the calendar is the whole range, so the fields go back to showing what was committed and the surface closes.

The worker's 484-line implementation needed four repairs: attribute lists that mixed `;` and `@` inside one literal; a commit path handed the formatted text where it needed the date; a `with` clause that listed every field of the model; and the library's own `Field` shadowed by `open! Core`.

The house's field renders a group label as a `<span>` that names the group with `aria-labelledby`, not as a `<label>` that labels one control. Both gates were asserting a `<label>` and failing.

Gates: component **890/890**, browser **734/734**, responsive **66/66**, full sweep green.

### Gate 91 — M80 DateTimeInput

The date time input is a date field, a time field, and a calendar to pick the date from. The field owns the draft text of each part and whether the calendar is open; the application owns the committed reading. The reading carries no zone and no offset.

The worker's 813-line implementation compiled against the house without repair — the first time that has happened. It needed a CSS part and a showcase section, and one fix: the example showing the twenty-four hour clock had no reading, so the clock had nothing to show.

Gates: component **896/896**, browser **741/741**, responsive **66/66**, full sweep green.

### Gate 92 — M81 DateInput

The date input is a text field for a date, and a calendar to pick one from. The field owns the text being typed; the application owns the committed date. A date that can be read is committed as it is typed; text that cannot be read stays in the field until it is left, and the field falls back to the committed date.

The parsing follows upstream's rules: an ISO date first, then a month written out with the day either way round, then a numeric date whose two fields are read day-first or month-first by what they can be, with the locale deciding when both are ambiguous.

The worker had written the interface and no implementation. The interface's note that the calendar had to be rendered inline, because the house Popover "does not fit a controlled text field with a trailing button", was wrong — the Popover takes any trigger, which is how DateRangeInput and DateTimeInput already open their calendars. The calendar now opens from a trailing button into a popover, as upstream opens it.

Gates: component **903/903**, browser **748/748**, responsive **66/66**, full sweep green.

### Gate 93 — M82 Table

The table is a header row, body rows, sorting and selection. The controlled
state is a tree, as upstream's is; the `aria-sort` attribute was missing
altogether, because the worker's match had a string in one arm and `None` in
the other; and the table had no scrollable wrapper, so a table of real
content was wider than a narrow viewport and the page scrolled sideways.

The stylesheet build was wrong too: the command palette's part had been
appended to `assets/components.css` twice, and four parts were older than
their build. `tools/sync-css.py` now rebuilds the stylesheet from the parts,
and the sweep fails when it is stale.

  component      911 checks, 0 failures
  browser        showcase 755/755, demo 25/25
  responsive     66/66
  sweep          SWEEP GREEN

### Gate 94 — M83 TimeInput

The time input is a typed time field: the field owns the text being typed
and the application owns the committed time.

The parser dropped the last character of every entry that had no meridiem,
so "14:30" was committed as 14:03 — and an entry with a meridiem happened
to survive, because the space before it was cut instead of the digit. The
meridiem is now found by one match that gives both where it starts and
which kind it is.

`test/probe/time_input_probe.ml` checks the parser, the formatter, the
stepping and the range check against known values; the sweep now runs it
alongside the plain-date probe.

  component      920 checks, 0 failures
  browser        showcase 762/762, demo 25/25
  responsive     66/66
  sweep          SWEEP GREEN

### Gate 95 — M84 SideNav

The side navigation is a column of navigation items, with a heading area, a
pinned area, the scrollable body, the footer and the icon bar. It collapses
to an icon rail and is resized with a separator that carries the value.

The item set the house's `data-astryx-component` attribute a second time,
on top of the one the Item row already sets — the browser gate caught it as
a console warning. The column's parts are graphs, because the items are.

  component      928 checks, 0 failures
  browser        showcase 774/774, demo 25/25
  responsive     66/66
  sweep          SWEEP GREEN

### Gate 96 — M85 Markdown

The markdown document renders a source string: ATX headings, paragraphs,
fenced code, block quotes, ordered and unordered lists and thematic breaks;
strong, emphasis, strikethrough, inline code, links and image alt text.
The heading, the code, the quote and the link are the house's own, so the
URL policy is the house's policy.

The parser dropped every block after the first paragraph, because the
block that stopped at the next block's first line returned nothing rather
than the lines that belong to it. A link never closed, because the bracket
matching tested the depth before it decremented it. The list parser hung:
the indentation of a line kept taking the index of every later character
that was not a space, and dropping the indent advanced neither counter when
the line did not begin with whitespace. A bullet list and a numbered list
were one list. A fence's info string was read one character too far, so
"ocaml" said "caml".

The parser now has a probe of its own, so a parser that loops fails the
gate rather than hanging it.

  component      939 checks, 0 failures
  browser        showcase 787/787, demo 25/25
  responsive     66/66
  sweep          SWEEP GREEN

## Gate 97 — M86 PowerSearch (coverage 102 → 103, and the last one)

The power search is one box that does two jobs: it takes the text you
type, and it takes the filters that are set. The filters sit in the box
as chips; the text goes into the same box. Typing a field's name opens
the list of fields, and choosing one opens an editor for that filter's
value.

The component is controlled: the application holds the filters and every
change is reported to it.

The box is the house Tokenizer and the editor is a house Popover that is
not a dialog, which is upstream's own note. The house Tokenizer gained
one optional argument — a click on a chip — because upstream opens the
editor from a token and the house Tokenizer had no way to say so. The
change is additive.

The compiler does not use the .mli when it compiles the .ml, so every
public type is declared in both files. The popover's trigger and content
are plain nodes rather than trees, so the editor's three trees have to
be unwrapped in the right places to build a node. The browser gate's
assertion that the editor's surface carries the open attribute was
wrong: the house's popover is the platform's, and what says it is open
is the :popover-open pseudo-class. The house's own popovers failed the
same check, which is how it was found.

  component      952 checks, 0 failures
  browser        showcase 802/802, demo 25/25
  responsive     66/66
  sweep          SWEEP GREEN

The coverage panel is 103 of 103, and the campaign is finished.
