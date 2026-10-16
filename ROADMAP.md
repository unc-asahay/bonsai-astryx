# Roadmap

Scoped by **how mechanical the port is**, measured from the upstream source rather
than guessed. Class counts come from `tools/classify.py` over
`packages/core/src` (103 components with usable contracts, ~249k lines of `.tsx`).

| class | what it means | count | why it is this class |
| --- | --- | --- | --- |
| A | props → markup, no hooks, no portal, no measurement | 25 | mechanical: types → variants, markup → `ppx_html`, classes passed through |
| B | local state and variants (variant maps, toggles, tabs, tables) | 55 | state maps to `Bonsai.state`, variants to OCaml variants; logic is small and reviewable |
| C | portals, overlays, measurement, focus management | 28 | behaviour must be reimplemented against `js_of_ocaml`: focus traps, positioning, `ResizeObserver` |

A full port is on the order of 200+ engineer-days; the point of the classification
is that the first three milestones are small and provable.

## M0 — infrastructure (done)

- [x] Extract the upstream contract into `registry.json` (103 components,
      ~1.4k props, do/don't rules, anatomy, accessibility criteria)
- [x] Generate `docs/components/*.md` and `docs/INDEX.md`
- [x] Visual pipeline: screenshot + measure every component → `docs/visual/*.md`,
      `tokens.json`
- [x] Mockup pipeline: recipe → HTML | image prompt | OCaml skeleton, validated
      against the registry
- [x] Port classifier with real counts

## M1 — foundations + first vertical slice

The components everything else composes from.

- [ ] `Stack`, `Center`, `Grid`, `Section`, `Card` (layout)
- [ ] `Text`, `Heading`, `Code`, `Blockquote`, `Link` (typography)
- [ ] `Button`, `IconButton`, `Icon`, `Badge`, `StatusDot`, `Divider`, `Skeleton`
- [ ] Parity harness green for the slice, with screenshots committed as evidence
- [ ] `port.json` populated for the slice

Exit criteria: `dune build` clean, parity tests green for every listed component,
`docs/` regenerated, and a demo screen built entirely from ported components.

## M2 — presentational remainder (Class A)

`AspectRatio`, `EmptyState`, `Indicator`, `Kbd`, `VisuallyHidden`,
`ProgressBar`, `Avatar`, `AvatarGroup`, `Thumbnail`, `Timestamp`, `MetadataList`,
`List`, `Blockquote`-family, `Token`, `Citation`.

Exit criteria: all Class A components ported; the reference generator emits a
`ported` status line for each.

## M3 — inputs and simple state (Class B)

`TextInput`, `TextArea`, `CheckboxInput`, `CheckboxList`, `RadioList`, `Switch`,
`Slider`, `SegmentedControl`, `ToggleButton`, `Field`, `FieldStatus`, `Banner`,
`Alert`, `Toast` (non-portalled form), `Tabs`/`TabList`, `Table`, `Pagination`,
`Breadcrumbs`, `Stepper`.

Exit criteria: form demo page; keyboard interaction parity tests passing.

## M4 — overlays and measured components (Class C)

`Dialog`, `AlertDialog`, `Popover`, `HoverCard`, `Tooltip`, `DropdownMenu`,
`ContextMenu`, `MoreMenu`, `CommandPalette`, `Selector`/`MultiSelector`/
`ComplexSelector`, `Typeahead`, `DateInput`/`DateRangeInput`/`TimeInput`,
`OverflowList`, `Carousel`, `Lightbox`, `BottomSheet`, `Tooltip` positioning.

These need a shared overlay/positioning layer ported once. Divergences are
expected and must be documented per component.

## M5 — packaging and publishing

- [ ] `check-drift.mjs` wired into CI (corpus must match the pinned upstream commit)
- [ ] opam package + `dune-project` metadata, `odoc` documentation
- [ ] Published docs site built from `docs/INDEX.md` + per-component files
- [ ] Release with a pinned upstream Astryx revision recorded in `NOTICE`

## M10 — the menu-button core (DropdownMenu, phase 1) (done)

Landed `DropdownMenu` phase 1 — the APG menu-button core — with `Menu_focus`, the navigation
ported from upstream's `useListFocus`/`useTypeahead`.

Three things worth carrying forward:

1. **Navigation is DOM-driven, exactly as upstream's is.** The highlight *is* DOM focus, rows are
   found by querying the container, and a disabled row is excluded *by the selector* — so no
   index can ever name an unfocusable row. Phases built on an index into a model would drift the
   moment a row is conditionally rendered.
2. **`Effect.Focus.on_activate` does not do what it sounds like.** It fires when a *computation*
   is activated, and a menu that renders its rows on a state change keeps that computation alive
   from the first paint — so it fired once, with the menu closed, and neither opening nor closing
   moved focus. `Menu_focus.focus_on_next_frame` focuses a frame later, which is the only moment
   that works in both directions. jsdom no-ops focus, so only the real browser could show this.
3. **The keyboard belongs in the browser gate.** The test harness's synthetic key event carries
   an *empty* `key` and appends its own fields after any `extra_event_fields`, so a handler that
   reads `event.key` (as upstream does) cannot be driven from jsdom at all. Rather than assert a
   fiction there, the whole keyboard path is asserted in Chromium.

Phase 2 — the inline-flyout system, the bottom sheet and the native `popover="auto"` press model
— remains open, as does `MoreMenu`, which wraps this.

## M11 — the form-control core (Field + TextInput, phase 1) (done)

Landed `Field` — the wrapper every input renders through — and `TextInput`, the first control that
uses it: label, description, status, three status placements, and the ARIA wiring that is the
whole reason these two exist in a port.

Three things worth carrying forward:

1. **A callback has to be a value in the graph, not a plain function.** `on_change` and `on_enter`
   are `Bonsai.t`s. With a plain function the caller has to wrap the view in a `Bonsai.map` over
   its state setter to get one — and because the view already returns a `Bonsai.t`, that wrap
   produces a *tree of a tree* (`Node.t Bonsai.t Bonsai.t`) that then needs unwrapping before it
   can render. `DropdownMenu.on_select` already had the right shape; now the rule is uniform.
2. **`Field` is a name Core already uses.** After `open! Core`, `Field` means Core's first-class
   fields, so a module of ours with that name cannot be referred to from inside the library. The
   fix was not a rename but better placement: the shared types went to their faithful homes —
   `Field_status.placement` (upstream's `FieldStatusVariant`), `Common.Size_value` (upstream's
   `SizeValue`) — leaving one reference, bound before the opens with a comment.
3. **Two types with the same constructor names need annotations.** `Field_status` now declares
   `variant` (the two strips it renders) and `placement` (all three places a message can go), and
   OCaml disambiguates an unannotated match towards the most recently declared type. Both matches
   carry `(variant : variant)` for that reason.

Also in this milestone: `Icon` gained an `inherit` colour (upstream's label icon inherits the
label's colour instead of imposing a palette one). Deferred with reasons: the loading spinner, the
`disabledMessage` tooltip, `InputGroup`, the async `changeAction`, `FormLayout`'s
default-optionality context, and horizontal-labels mode.

## M9 — FieldStatus and entry animations (done)

Landed `FieldStatus` (attached/detached × warning/error/success) and `Entry_animation`, the
first behaviour in the port that depends on *when*, not on inputs.

The point worth carrying forward: upstream animates a component **only when it was mounted
after the first paint**, and reproduces that by flipping a module-level flag inside a
`requestAnimationFrame` and reading it once, at first render. The port does the same, which is
why `FieldStatus` builds its own view synchronously instead of taking a `Bonsai.graph`. Both
halves of the rule are gated: the in-process tests assert nothing on the first paint animates,
and the browser gate mounts one on demand and asserts the class *and* that
`prefers-reduced-motion` neutralises it.

## Next milestone — DropdownMenu, and why it is not a trio

Only seven Class A components remained when this was written, and the two most valuable are
gated on things the port does not have yet:

- **`MoreMenu` is a wrapper, not a component.** Its 183 lines mostly forward props to
  `DropdownMenu` (it supplies the `moreHorizontal` icon, an i18n label, `variant: 'ghost'`).
  Porting it alone would mean shipping a stub, so it follows `DropdownMenu`.
- **`DropdownMenu` is 1,765 lines** across `DropdownMenu.tsx` plus submodules
  (`DropdownMenuSubMenu` alone is 910), with a 4,177-line test file. It brings typeahead,
  a roving highlight with focus held on the container, drill-in submenus, modal regions
  (header/footer make it a dialog), a bottom-sheet presentation, and a native
  `popover="auto"` layer whose dismissal is the browser's own light dismiss.
- **Phase 1 scope**: the APG menu-button core — trigger (`aria-haspopup` / `aria-expanded` /
  `aria-controls`), a `role="menu"` popup, `role="menuitem"` rows, arrow / Home / End /
  Escape / Enter / Space, typeahead, click-outside dismissal, and focus returning to the
  trigger. Deferred: submenus, regions, bottom sheet, checkbox and radio items.
- That phase is also what makes the keyboard claims assertable at last: Tab order, Escape,
  focus return and `:focus-visible` currently have no ported component with those semantics.

Porting `Icon` unblocked the other direction: **`FieldStatus`** (needs `Icon` plus an entry
animation) and **`Pagination`** (needs `Icon`) are now tractable, and both are closer to a
single-session port than `DropdownMenu` is.

## M6 — second upstream: shadcn

shadcn is harder than Astryx, not easier: it is Radix primitives plus Tailwind
utilities, so a port is two libraries' worth of behaviour. Upstream Astryx already
ships shadcn interop material (`internal/shadcn-registry`), which we can use as a
starting map. Deferred until M4's overlay layer exists, because that layer is what
Radix behaviour would need anyway.

## Deliberately out of scope

- A React/Vue-to-Bonsai transpiler. Semantics do not survive the trip; see README.
- Nuxt/Vue SFC components as a first-class source. Template DSL plus Vue
  reactivity is a strictly harder translation than React, and only purely
  presentational SFCs would be mechanical.
- Anything requiring the upstream design system to be redistributed wholesale
  (fonts, brand assets, icons beyond what MIT covers).
