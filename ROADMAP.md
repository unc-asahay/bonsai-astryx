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
