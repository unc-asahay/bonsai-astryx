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

## M12 — the rest of the basic controls (TextArea, then the rest) (done)

The input family shares one contract, and the first thing this milestone did was make the port
share it too. Upstream keeps those types in `Field/types.ts` under the `Input*` names — one status
type, one set of three sizes, and a status record whose `message` is *optional* — and TextInput had
a private copy of all three. `Input_types` is now that one definition, and TextInput moved onto it,
which closed a real gap: a status may carry no message at all (the control takes the colour, no box
is rendered, nothing is announced), and the port had required one. A status that must always have
something to say pushes callers into inventing something to say.

`TextArea` is the second control on that contract and the first whose value is not an attribute: a
textarea's value is its child text, and React hides the difference by treating `value` on a
textarea as a property assignment. A port that copies the JSX has a field that looks right in a
screenshot and discards what the user types — so the browser gate types, lets the state change,
and types again to prove a re-render does not put the old text back.

`FieldLabel` came next, because the two controls that finish this milestone need it: upstream keeps
the label + description group as its own component precisely because `CheckboxInput` and `Switch`
want the label *beside* their control instead of above it. It was living inside `Field` as a private
function; it is now a module `Field` renders through, and the extraction was verified by the checks
that already existed — the 252 component checks and 104 browser checks, unchanged, on the same run —
before a single new assertion was written. Upstream exports it from `Field`'s index and the component
extraction does not list it among the 103, so it is recorded under `infrastructure` rather than
counted in coverage, and that is stated rather than glossed over.

`Indicator` came after that, and before the controls that need it — `CheckboxInput` and `Switch` do
not draw their own boxes, they compose this. Upstream splits it three ways (`CheckIndicator`,
`CheckboxIndicator`, `RadioIndicator`) over one primitive and resolves it through a registry a theme
can swap; the port has one module with a `kind`, which is the judgment it already made for
`HStack`/`VStack` → `Stack`, and the registry's default entry with the theme seam left in front for
when a theme system exists. It is one of the 103, so coverage moved: **29 / 74 / 103**. The checks
that earned their place measured what the engine *painted* rather than what the DOM contained — the
check mark is an SVG path, and an HTML element inside `<svg>` is a no-op that throws nothing
anywhere — and asserted two absences: a bare unchecked mark renders nothing at all, and an
indeterminate box draws a bar rather than a tick. The gate's first run caught a real defect of mine
(an `Icon` that already sets `aria-hidden` being handed a second one); it was a Vdom warning, not a
failed assertion, and that is exactly why the console-error check exists.

`CheckboxInput` followed — the first control whose label is a row partner rather than a heading,
which is what `FieldLabel` was extracted for, and the first with a state that is not a value. Three
things had to be right at once: `checked` and `indeterminate` are DOM *properties* (an attribute
looks correct on the first paint and never moves again); there is deliberately no
`aria-checked="mixed"`, asserted as an absence in both gates; and a click the application refuses has
to be *canceled*, not ignored — React restores a controlled input after every event and Vdom does
not, so the read-only example visibly flipped while the application still said unchecked. The
real-browser gate caught that one, and only it could have: jsdom never clicks.

`Switch` closes the pair. It looks like a checkbox with different paint and is not one: the control is
a native checkbox carrying `role="switch"`, which is the pattern that makes a screen reader announce
"switch, on" rather than "checkbox, checked", and the track is `aria-hidden` paint over it with a
thumb that grows when it is on. It has no third value — everything a third state would say is said
better by a checkbox — and, like the checkbox, deliberately no `aria-checked`, asserted as an absence
in both gates. Upstream gives a switch no read-only prop at all, so neither does the port. One thing
it does *not* yet need is the canceled click the checkbox needed: a disabled switch is natively
disabled, so the browser refuses the click and there is nothing to undo. When the focusable-disabled
path arrives (the `disabledMessage` tooltip, which keeps a disabled control reachable so its reason
can be read), that same cancel will be required here — the seam is commented where it goes.

**M12 is done.** The basic form controls are ported: a text field and a textarea, a checkbox with its
three-valued box, and a switch — on top of `Field`, `FieldLabel`, `FieldStatus`, `Input_types` and
`Indicator`, which is the layer they are all built from. What remains from upstream's forms work is
not another control but its surroundings, and each piece is listed where it belongs rather than left
to be discovered: `FormLayout`'s `defaultOptionality` (which decides whether a marker shows at all),
TextArea's loading spinner, clear button and auto-focus, the busy state and `disabledMessage` tooltip
for the two controls that have them upstream, and Indicator's theme-override seam.

What M12 leaves undone is not another control but its surroundings: `FormLayout` (upstream's 603-line
layout component, which owns `defaultOptionality` and horizontal labels), plus, deferred with reasons,
TextArea's loading spinner, clear button and auto-focus; FieldLabel's `labelTooltip` and its clickable
description; Indicator's theme-override seam, its children slot for a custom mark, and the focus-ring /
press-feedback hooks that belong to whichever control composes it; and the `isBusy` spinner and
`disabledMessage` tooltip for `CheckboxInput` and `Switch`.

Next: the next slice of the 72 unported components, chosen against `docs/PORT-STATUS.md`.

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

## M13 — closing the forms layer (RadioList, FormLayout, Tooltip)

M12 ported the controls; this milestone finishes their surroundings. Every piece of it is tractable
*because* of what M12 left in place, which is the only reason it is worth doing before the larger
pillars below.

- **`RadioList`** (class B, 1,781 lines) — **done**, and it is worth saying what it actually cost. It is
  the first consumer of `Indicator`'s **radio** kind, which had been ported and unrendered since M12
  (the same position `Indicator` itself was in before `CheckboxInput`). The keyboard was free, exactly
  as this section predicted: a *native* radio group is one tab stop and its arrows move **and** select,
  so the port sets a shared `name` and writes no keydown handler at all — and the real-browser gate
  presses ArrowDown, ArrowUp and Tab rather than believing that. What did have to be right: the group
  composes `Field` twice over (a radio group is a form field, so its label is a *group* label — a
  `<span>` the group names itself from with `aria-labelledby`, and it is the first real consumer of the
  group-label path M12 built for `FieldLabel`), and `Field` renders the description and status outside
  the group, so the group links them itself.

  Two incidental finds, both of which had been passing silently: the appearance-contract generator
  could not see any class containing `__` (`82` of the stylesheet's `312` selectors, including
  `CheckboxInput`'s and `Switch`'s whole innards — their pages had been reporting `1 class, 3
  declarations`), and the gate's frozen expected-section list had never been extended for
  `Indicator`, `CheckboxInput` or `Switch`, so any of them could have disappeared from the showcase
  without a check noticing.

- **`FormLayout`** (class B, 603 lines) is the cheap end of M12's deferrals, and it owns the one rule
  that changes how every control already ported *renders*: `defaultOptionality`, which decides
  whether an "Optional" marker appears at all. Porting it retires a deferral that currently affects
  four controls.

- **`Tooltip`** (class B, 1,998 lines) retires the other two: `FieldStatus`'s third variant (which
  the port type-checks and deliberately renders nothing for today) and the `disabledMessage` path on
  `CheckboxInput` and `Switch`. That path is also where `Switch` will need the canceled click
  `CheckboxInput` already has — the seam is commented where it goes.

Deliberately *not* first: the overlay layer (`Layer`, `Dialog`, `Popover`, `BottomSheet` — class C,
portal-driven, 2.4k–6.6k lines each). It is the largest unblocker left in the registry, and it is a
pillar of its own rather than a way to close this one. Likewise `Table` (5,007, class B),
`SideNav`/`TopNav` (6,334/5,238, class B) and `Markdown` (7,754, class B): each is self-contained and
each is a larger single sitting than anything above.

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
