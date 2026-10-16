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

## M13 — closing the forms layer (RadioList, FormLayout, Tooltip) (done)

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

- **`FormLayout`** (class B, 603 lines) — **done**, the cheap end of M12's deferrals and the one rule
  that changes how every control already ported *renders*: only the exception is marked, so under a
  form-wide default an "Optional" marker appears only where it means something. Upstream supplies the
  rule through React context and the port takes it as `?optionality` on each field, for the concrete
  reason that a context must be live while the child tree is *built* — and a child here is a tree the
  caller has already built. `Bonsai.Dynamic_scope` is the right shape and the wrong moment. The rule
  is upstream's exactly, including the half that is easy to lose: a layout default moves
  `aria-required` and never the native `required` attribute, so choosing a form default cannot switch
  on the browser's own validation.

- ~~**`disabledMessage`** on `CheckboxInput` and `Switch`~~ — **done**, and not the way this line
  first said it would be. It was going to compose `Tooltip`; it does not, because the description has
  to be present for as long as the control is disabled rather than only while hovered, and the visual
  half is one CSS rule. The controls keep their stateless signatures. The canceled click this note
  predicted `Switch` would need is now there, and it was load-bearing the moment focusable-disabled
  controls started firing clicks.
- **`Tooltip`** (class B, 1,998 lines) — **now built**, in the overlay pillar below rather than here,
  and it is what a control reaches for when the message should appear on hover and go away again. The other deferral this
  section used to claim is smaller than it looked: `FieldStatus`'s third variant already renders its
  message as a visually-hidden live region (`field.ml`'s `announcement_node`), so assistive technology
  gets the message today and only the *visible* bubble is missing.

**One thing this milestone got wrong and then fixed.** It recorded Tooltip's 200 ms hover delay as
unportable, on the grounds that a timer's callback cannot write back into a component's state. It can:
`Vdom.Attr.create_hook` builds a vdom hook and a hook's input may carry a `unit Effect.t` that
`Effect.Expert` runs. `Common.Delay_hook` is that, the delay is ported, and the browser gate presses it
— and the same mechanism is what will let a *controlled* overlay call `showModal` when a value changes
rather than only when an event fires, which is what the pillar below was waiting for. Gate 23 has the
full account; the short version is that the reason was sound and the premise was never checked.

Next: the overlay pillar (`Tooltip`, `Dialog`/`AlertDialog`, `Popover`, `BottomSheet`, then the
`Layer` primitives underneath them) — class C, portal-driven, 2.4k–6.6k lines each, and much more
than a way to close this one. It is the largest unblock in the registry: the field-side deferrals
above wait on `Tooltip`, and so do `Selector`, `DateInput`'s calendar and `Combobox`. (Note what
that deferral actually is: the port renders the tooltip *variant* of a field status as a
visually-hidden live region rather than a visible bubble — a substitute, described as one in
`field.ml`, not parity.)

The pillar's *first* build is `Tooltip` rather than `Layer`, and the port's own precedent is why:
`DropdownMenu` already renders its surface as an explicit positioned element rather than in a
top-layer portal, with the divergence written in its interface ("the top-layer mechanics and the
press model are phase 2"), and it is the only overlay the port has that works. Follow that, and the
true portal — stacking contexts, `overflow: hidden` ancestors, a real focus trap, `ResizeObserver`
repositioning — stays a named open item rather than a hidden difference. `layerViewportInset`,
`modalOutlet` and the depth context exist upstream precisely because portals solve problems that
in-place positioning cannot; they belong to the pillar's later phases. Likewise `Table` (5,007, class B),
`SideNav`/`TopNav` (6,334/5,238, class B) and `Markdown` (7,754, class B): each is self-contained and
each is a larger single sitting than anything above.

## M14 — the overlay pillar opens (Dialog, AlertDialog, DialogHeader) (done)

`Tooltip` proved the pillar's convention; `Dialog` is where the port starts handing the *behaviour*
over to the platform rather than reimplementing it. Upstream builds Dialog on the native `<dialog>`
opened with `showModal()`, so the top layer, the inert page behind it, the focus trap, the `Escape`
handling and the `::backdrop` are the browser's — nothing in the port writes them. That is the same
judgment as porting a native radio group with no keydown handler (M13), and it is the reason Dialog is
the first overlay that is not a copy of the `DropdownMenu` positioning convention.

What the port *does* own is the **dismissal matrix**, which is why the milestone's browser checks press
it rather than read it:

- `purpose = info` — `Escape` closes it, a backdrop click closes it.
- `purpose = form` — `Escape` closes it; **a backdrop click does not.** A half-filled form should not be
  lost to a stray click, and that distinction is invisible in the DOM: it shows up only as behaviour.
- `purpose = required` — neither exit works, and the element carries `role = alertdialog`. A dialog that
  refuses every exit is one the user has to answer.

**The mechanism that makes it possible is Gate 23's hook.** A controlled dialog's `is_open` is a value,
and `showModal()`/`close()` have to follow it — but no event fires when a *caller* changes their own
state, so the DOM side cannot live in a handler. `Common.Delay_hook` established that
`Vdom.Attr.create_hook` plus a `unit Effect.t` in the hook's input is that primitive; `Dialog` is its
first real customer. Gate 21 had recorded this class of thing as unportable, and this is the milestone
where the correction pays.

Three finds, all of them caught by gates rather than by reading:

1. **`<form method="dialog">` closes a dialog with no JavaScript at all** — the platform's own
   mechanism, and the reason the component's `children` stay plain nodes: a caller never has to hand a
   setter down into the content to get a close button. The port reports the close through
   `on_open_change`, and the `close` event is what carries it.
   *The first version did nothing when clicked*: `Button.view` defaults to `type="button"`, which is the
   correct default and also means a button inside a form does not submit. The example now passes
   `~type_:Button.Submit`. The port had carried upstream's `type?: 'button' | 'submit' | 'reset'` prop
   since M2; this is the first time anything needed it.
2. **Two `style` attributes silently lose one.** The sizing and the position were written as separate
   `style` attributes, and virtual_dom merges last-wins, so the position was dropped. The component gate
   caught it because the check reads the *style* rather than the class. One merged attribute now.
3. **A modal left open makes the rest of the page inert** — so six *unrelated* browser checks failed
   (focus, `Enter` on a button, the whole dropdown keyboard path) purely as a consequence of the dialog
   above them not closing. A real-browser failure is not always about the thing it names; the gate is
   one page and the checks share it.

A fourth, in the responsive probe: a closed `<dialog>` is `display: none`, so the dialog *and every
marked component inside it* report a zero box — and the probe called that "a component collapsed to zero
size", six of them. The fix is the general one: ask each element whether it renders at all
(`checkVisibility`), rather than assuming every marked component has a box. The baselines were
regenerated, because the page legitimately grew.

**Deferred with reasons** (recorded in `dialog.mli`, not hidden): upstream's `Layer` gives a dialog a
depth stack, a page scroll lock, a modal outlet and a directional open animation. None is ported. Focus
*restoration* is, because that is behaviour rather than flourish — the element that had focus is captured
on open and given it back on close. The title association is an argument here (`~labelled_by`) where
upstream wires it from React context, because a child in this port is already built by the time the
container sees it — the same moment that shaped `FormLayout` in M13.

**`DialogHeader`** closes the milestone: the heading carries the id a dialog is told to name itself
from (the caller makes that link, because the caller is the only thing that can see both), and the close
button exists exactly when there is an `~on_open_change` to report to — upstream's rule, since a control
that cannot tell anyone it was pressed does nothing, so the gate asserts the *absence* as carefully as the
button. One accessibility behaviour is not ported and is named in `dialog_header.mli` rather than
approximated: upstream focuses the title when a modal dialog opens, which matters because the platform's
focus delegate skips a `tabindex="-1"` element and lands on the close button, so a screen reader would
announce "Close" rather than the dialog's name. The mechanism exists; what is missing is the moment, and
the honest home for it is `Dialog`, which knows when it opened.

A note on the count: `DialogHeader` is an upstream module but **not** one of `registry.json`'s 103
extracted components, so porting it does not move the coverage number. The generator said so by name
("port.json names components absent from registry.json: DialogHeader") and it is now recorded under
`port.json.infrastructure` with a reason — the same treatment `FieldLabel` gets. Coverage stayed honest at
36 of 103 through a milestone that added three components.

## M15 — the two halves of a shortcut (Kbd) (done)

`Kbd` is small and entirely static, which is why it was worth doing while the overlay pillar is still
open: it needed nothing from `Layer`, and it is the first component since M1 whose interesting part is
not visual at all.

Rendering a shortcut is a `role="img"` wrapper with an `aria-label` built from *spoken* words and a set of
`aria-hidden` caps inside it. Glyphs are announced meaninglessly, so a shortcut can look perfect and be
unusable, and the port keeps the two halves as separate functions — `key_display` and `key_label` — which
is also what makes the Mac branch testable from a Linux runner. `mod` is the one platform-dependent key,
and this port answers that question directly instead of deferring it through `useSyncExternalStore` (a
workaround for a hydration mismatch it cannot have); the detection rules themselves are upstream's
verbatim, including the detail that an empty or `Unknown` client-hints platform is *no answer* rather
than a negative one.

A CSS block is only provable in a browser, so the gate measures the cap's height against the very token
the stylesheet names — a block naming a token that does not exist would render a plain glyph and pass
every DOM assertion.

Next in the pillar: `Popover` and `BottomSheet`, then the `Layer` primitives underneath them — which is
what `Selector`, `DateInput`'s calendar and `Combobox` wait on. `Popover`'s recon is done and its cost is
recorded in the porting skill: upstream applies the trigger's ARIA by querying its children for a
`button, [role="button"]`, and positions with CSS anchor positioning through `useLayer`, so a faithful
port needs imperative DOM work at mount and on state change rather than a new trigger API.

### What `Layer` actually is — read, not assumed

`Layer/useLayer.tsx` is 46 KB, which reads as "reimplement a placement engine". Reading it says otherwise:
upstream opens its layers with the **native Popover API** — `popover="auto"` plus
`showPopover({source: trigger})` — and that single call hands the platform the top layer, light dismiss on
pointer-down outside, `Escape`, and **CSS anchor positioning** against the trigger element. The placement
maths is largely the *fallback* for browsers without `showPopover` (Firefox < 125), not the mechanism.

Two consequences worth having on the record before the milestone starts:

- **The structural divergence retires itself.** Since the Tooltip, this port has positioned overlays in
  place, so an ancestor with `overflow: hidden` clips them — documented every time as a divergence. The
  top layer is not clipped, so standing on the same API as upstream removes that divergence for the whole
  family at once, rather than one component at a time.
- **The cost estimate changes.** `Popover` and `BottomSheet` are not gated on reimplementing positioning.
  They are gated on the same "ask the platform first" question that let `Dialog`, `AlertDialog` and
  `DialogHeader` land together — and on two ordering rules the port inherits: `hidePopover()` fires a
  `toggle` event (so clear the open state *before* hiding, as upstream does), and `showPopover()` throws
  if it is called mid-toggle. jsdom has no Popover API at all, so the component gate will press a
  feature-checked fallback while only Chromium exercises the native path — the same split `<dialog>` needed.

### The next component is not the one its line count suggests

`MoreMenu` looks like the cheap one: 183 lines, and its own comment calls it "a thin wrapper around
DropdownMenu with icon-only button defaults". It is — but a wrapper's cost is its delegate's API, not its
own size. It forwards a *button config object* (`label`, `icon`, `variant`, `size`, `isIconOnly`,
`tooltip`), `placement`, `alignment`, `presentation`, and a **controlled** `isMenuOpen`/`onOpenChange`,
and passes `hasChevron={false}`.

The port's `DropdownMenu` takes `~trigger_label : string` and builds its own button, owns its own open
state, and has no placement, alignment or presentation — its own `.mli` records that the top-layer
mechanics are phase 2. So MoreMenu means extending DropdownMenu first, and that extension is the *same*
Layer work `Popover` needs. The dependency graph, read rather than assumed:

    Layer / native popover mechanism
      |- DropdownMenu phase 2 (controlled open, button config, placement)  ->  MoreMenu
      |- Popover  ->  Selector, Combobox, DateInput's calendar
      |- BottomSheet  ->  the adaptive presentation

Which is why the next milestone is the mechanism, not the cheapest-looking wrapper: three components and
the whole overlay family are waiting on one thing, and the platform already implements most of it.

### M16, first step — the layer mechanism (done)

`Common.Layer_hook` drives a native popover layer off a Bonsai boolean: `popover="auto"`, `showPopover`
and `hidePopover`, feature-checked, plus the one thing the platform cannot do — **report back when the
browser dismisses the layer itself.** After a light-dismiss click the layer is gone while the value still
says open, and every later click on the trigger would look like a no-op; the hook listens for the
platform's `toggle` event and tells the application. Two ordering rules came with it: the state moves
*before* `hidePopover()` (that call fires `toggle` too, and a close we asked for is not news), and
`showPopover()` is never called from inside the toggle handler, where it throws.

The demonstration is the verification: two live layers in the showcase differing by one attribute, and a
real Chrome deciding both. `popover="auto"` is dismissed by a genuine outside click and a genuine
`Escape`, and the value is told each time; `popover="manual"` ignores both, because "explicit dismissal
only" is an attribute meaning rather than a flag this port implements. In jsdom — which has no Popover
API at all — the gate asserts only the fallback, and says so.

`Layer` itself is still unported. This is one mechanism underneath it, which is why coverage is
unchanged at 37 of 103: a gate that moved the number by porting a mechanism would be counting the wrong
thing. What is next in the family is now a wrapper around something already proven.

**Second step (done): the trigger's wiring.** `Common.Layer_trigger_hook` locates the first
`button, [role="button"]` among the children and applies `aria-haspopup`, `aria-expanded` and
`aria-controls` to it, plus the click that toggles. It is a hook rather than props for one reason:
`aria-expanded` is *state*, so an attribute handed in by a caller could only be a snapshot. The demo's
Button consequently has no `on_click` of its own — the mechanism owns the click, as upstream's does. Two
subtleties came with it: the keydown path is attached only to a **non**-`<button>` (a native button
synthesizes a click from Enter, so a handler for it would toggle twice — and the browser gate presses
Enter once and expects the layer *open*, which is the check that catches it), and the listeners read the
latest effect rather than the one captured when they were attached.

The two mechanisms together are what `Popover` will be a wrapper around: the surface's show/hide with the
platform's dismissal reported back, and the trigger's ARIA with its click. What remains for the component
itself is the labelled surface (`role="dialog"`, `aria-modal`, `aria-label`), the close button, autofocus
and the `width`/`padding` seam — plus the two things upstream has that this port will *name as missing*
rather than approximate: the modal focus trap and the overflow-measurement machinery.

### M17 — ButtonGroup: buttons joined into one surface (done, 37 → 38 of 103)

Two parts, and only one of them was expected. The connected look is CSS drawn by the group, because a
child here is built before its container sees it and there is no context to put a style into; and the rule
has to target the button *inside* each child, since a member that renders its own layer wraps its button —
upstream's own `IS_LAST_ITEM` comment explains why it moved the same rules into `Button.tsx`.

The part that was not expected: a single tab stop with the arrows moving within it is *behaviour*, and
unlike a radio group the platform does not provide it for buttons. So the group implements the APG roving
tabindex itself, and every arrow movement rewrites `tabindex` on the members — the focused one becomes
`0` and the rest `-1`, which is what makes the next Tab leave the group. Upstream's three `useListFocus`
settings all turned out to be load-bearing and are copied verbatim (see Gate 31).

**The responsive gate earned its place here**, by failing on this milestone's own section rather than on
the component: the demo put two groups side by side in a flex row, and the page overflowed at 320px and
375px. The fix was the layout, not the assertion.


### M18 — Popover: a layer anchored to its trigger (done, 38 → 39 of 103)

Mostly a wrapper, deliberately. The two mechanisms underneath it were ported and proven on their own first
(Gates 29 and 30), and that is what made this milestone small: what is left in the component is the
labelled surface, the generated close control, the focus rule and the width/padding seam.

The focus rule is upstream's exactly — the first genuine control in the content, falling back to the
labelled surface, with the generated close button excluded *structurally* rather than by a filter (it sits
outside the content wrapper), and focus returning to the trigger only if it was inside. Focus is asked for
on the next frame for the same reason the dialog focuses after `showModal`: the surface is `display:none`
until the mechanism shows it, and two hooks after one DOM patch have no defined order.

Named as missing rather than approximated: width clamping against the viewport (handed to CSS instead),
the modal focus trap (`aria-modal` is announced and nothing is trapped), the render-prop and `anchorRef`
trigger modes, and any way to want Escape without light dismiss — they are one `popover` attribute.

**Next in the family:** `BottomSheet` (the other real consumer of these mechanisms) and `DropdownMenu`
phase 2, whose trigger needs exactly the ARIA this milestone put behind `Layer_trigger_hook`.


### M20 — InputGroup: a group of controls that reads as one field (done, 40 → 41 of 103)

The label names the group rather than a control — rendered as a `<span>`, since a `<label>` with no control to
point at names nothing — and the status message is `Detached`, below the group. The size reaches the children
through the box: a member takes its height from an `inline-flex` box stretched to a step of the shared size
scale, rather than through a context, because the children are built by the caller before the group sees them.

Two of React's contexts are therefore named divergences rather than reproduced (`InputGroupContext`,
`SizeProvider`) — the same shape as ButtonGroup's connected look. Not ported and named in the mli: the group's
`aria-describedby` (this port's `Field` does not hand back its description element's id, and an id no element
carries would be worse than its absence).

**A `.ts` file the planning metric missed, holding the whole reason the component exists.**
`InputGroup/groupStyles.ts` (85 lines) is where members take `flex: 1; height: 100%`, give up their inner
corners, pull left by one border-width so the shared edge is single, and where a focused member gets
`z-index: 2` so the next member's overlapping border cannot cover its focus ring. The trailing corner uses
`:has(~ *:not([popover]):not(template):not(dialog))` rather than `:last-child` — a popover child is not a
visual member, the same insight the overlay family produced in M16.

**Correction to the measurement below:** it counted `.tsx` files. Count `.ts` as well.

### M19 — Timer: a duration that stays readable without re-rendering (done, 39 → 40 of 103)

One reading, two numbers, and they are deliberately not always the same number: a real `<time>` carries an
ISO 8601 duration in `datetime` and the human reading as its text, and past an hour the elapsed text drops
its seconds — at which point the duration follows the *text* rather than the clock. The showcase renders two
timers from one start time to make the difference measurable rather than argued.

"Nothing re-renders" turned out to be checkable: the browser gate holds the DOM node across a second and
checks it is still the same node, because a re-render would have replaced it.

**The discovery of this milestone is a platform one and it took the whole page down:** under js_of_ocaml an
`int` is 32 bits, so milliseconds since 1970 do not fit in one and converting raises `Invalid_argument`.
Core's `Time_ns` refuses on this target for the same reason. A JS `number` is a double and an OCaml `float`
is a double, so `start_time` and the internal clock are floats — the faithful type on both sides rather than
a workaround — while durations within the component stay ints. What caught it was the browser gate's *"the
app mounted in Chromium"* check, from a page that had gone blank.

**Next:** `BottomSheet` and `DropdownMenu` phase 2 — both now consumers of mechanisms that are proven, which
is what M18 was for.


### Recon on what is next, measured — because file sizes mislead four times

The first version of this section claimed "the cheap wins are spent" and named `ScrollableArea` a quick win.
Both were wrong, and the way they were wrong is worth keeping.

Each time, the *main file's* line count described the container and not the job:

| Component | main file | what the job actually is |
| --- | --- | --- |
| `Breadcrumbs` | 167 | `BreadcrumbItem` beside it is **689** — the container is thin because the work is next door |
| `ScrollableArea` | 260 | `useScrollableArea` (493) + geometry (155) + resize observer (142) + keyboard delegation (233) + owner registry (47) ≈ **1,330** |
| `ClickableCard` | 401 | a card wrapper *plus* the press-feedback pillar (`usePressFeedback`, the interaction overlay) that `SelectableCard` and `Thumbnail` also stand on |
| `Table` | 301 | the roadmap's own pillar, and the main file is the smallest part of it |

So the honest planning metric is **the component's whole directory plus every `hooks/` and `utils/` module it
pulls in from outside it**. Measured that way, the remaining 63 sort like this (smallest first):

```
 tsx lines  files  component          shared machinery pulled in from outside
       183      1  MoreMenu           —            (blocked: see below)
       260      1  ScrollableArea     hooks/useScrollableArea + 4 more
       341      2  InputGroup         utils/themeProps only
       395      1  Toolbar            hooks/useListFocus, useKeyboardHint
       401      1  ClickableCard      hooks/usePressFeedback (a pillar)
       411      1  OverflowList       hooks/useOverflow, useMergedRefs
       426      2  AvatarGroup        hooks/useListFocus, useMergedRefs
       463      1  SelectableCard     hooks/useClickableContainer, usePressFeedback
       508      1  Outline            hooks/useIsomorphicLayoutEffect, useListFocus
       557      3  MetadataList       utils/themeProps only
       586      2  SegmentedControl   hooks/useKeyboardHint, useListFocus
       609      2  ToggleButton       utils/mergeProps, themeProps, types
       ...                    (the pillars: TopNav 3,030 · PowerSearch 3,093 · DateTimeInput 4,222 ·
                               DateInput 4,608 · Chat 6,184)
```

Two things fall out of that table and neither was guessable from the sizes I first used:

- **`InputGroup` (341, two files, nothing shared but `themeProps`) is the cheapest honest next step** — it is
  a layout wrapper with no mechanism of its own and no subsystem behind it.
- **`Toolbar` is the second**, and for a specific reason: the machinery it pulls in, `useListFocus`, *already
  exists in this port* — `ButtonGroup` implemented the APG roving tabindex in M17. Toolbar is largely a
  consumer of something already proven, which is the shape that made Popover and Timer small.
- **`MoreMenu` (183, one file, nothing shared) stays blocked** on `DropdownMenu`'s surface anyway: the port's
  `DropdownMenu` takes a trigger *label* and owns its open state, while MoreMenu forwards a button config, a
  placement and a *controlled* `isMenuOpen`.

`BottomSheet` (6.6k) and `Chat` (12.9k) remain multi-milestone jobs, to be planned as such rather than
started at the end of a session. The next milestone should be chosen as *which mechanism to build next*,
with its first consumer as the component — the arrangement that made Popover small.


