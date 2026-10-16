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

**Totals at this gate:** 252 component checks, 104 real-browser checks, 25/25 demo checks,
66 responsive checks at 0.00% drift across 320/375/768/1440, 25 appearance pages.

## Not yet verified — do not read these as claims

- **Pixel parity against the React original.** `tools/visual/capture.mjs` captures
  the upstream build but has not run: it needs the Astryx Storybook build.
- **Upstream screenshots / the upstream-side visual reference** — same dependency.
  (`docs/visual/` for the *port* is generated and described in Gate 5 above; what is
  missing is the upstream side to compare it against.)
- **Anything below M12.** 28 of 103 components are ported; the other 75 have
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
