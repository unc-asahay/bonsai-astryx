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
