# Collapsible

**Category:** Container  |  **Group:** Collapsible  |  **Port status:** not started

Collapsible hides and reveals content behind a trigger button. Use it in
settings panels, FAQ pages, or detail views to keep the page scannable while
letting users drill into sections they care about. Wrap multiple
collapsibles in CollapsibleGroup for accordion behavior. For custom
collapsible components, use the `useCollapsible` hook directly (`astryx hook
useCollapsible`).

## When to reach for it / when not to

- **Do:** Give every trigger a meaningful accessible name. Visible text usually
  supplies it; custom trigger content should include VisuallyHidden text
  when its visuals do not.
- **Do:** Use hasDividers on CollapsibleGroup for FAQ-style lists: built-in row
  hairlines with themed border tokens, no hand-rolled borders.
- **Do:** Wrap each Collapsible in an Card for visual separation in accordion
  layouts, or use CollapsibleGroup's hasDividers for flat lists; don't
  combine both.
- **Do:** Use CollapsibleGroup with type="single" for settings or FAQ pages where
  only one section should be open at a time.
- **Do:** Use type="multiple" when users need to compare content across sections,
  like feature lists or pricing tiers.
- **Do:** Start sections open (defaultIsOpen) when the content is likely needed on
  first view; don't make users click to see essential info.
- **Don't:** Hide critical or required content behind a collapsible; users may not
  discover it.
- **Don't:** Nest collapsibles more than two levels deep; it makes content hard to
  find and navigate.
- **Don't:** Use a collapsible for a single short paragraph; just show the text
  directly instead.

## Props

| prop | type | required | default | meaning |
| --- | --- | --- | --- | --- |
| `trigger` | `ReactNode` | yes | `` | Content shown in the trigger area (always visible). |
| `children` | `ReactNode` | no | `` | Content that collapses and expands. |
| `defaultIsOpen` | `boolean` | no | `true` | Default open state for standalone uncontrolled usage. Ignored when value binds the item to a surrounding CollapsibleGroup. |
| `isOpen` | `boolean` | no | `` | Controlled open state for standalone usage. Ignored when value binds the item to a surrounding CollapsibleGroup. |
| `isDisabled` | `boolean` | no | `false` | Disable the item so its trigger can't be toggled (dimmed, aria-disabled, and out of the tab order). Doesn't collapse an already-open item. |
| `onOpenChange` | `(isOpen: boolean) => void` | no | `` | Callback invoked when standalone open state changes. A surrounding CollapsibleGroup owns grouped state and calls its onChange instead. |
| `chevronPosition` | `'start' \| 'end'` | no | `'end'` | Logical position of Collapsible's disclosure chevron. `end` (default) follows the label, pointing down when collapsed and up when expanded. `start` precedes the label, pointing inward toward content when collapsed (mirrored under RTL) and down when expanded. Inside a CollapsibleGroup this defaults to the group's chevronPosition. |
| `value` | `string` | no | `` | Identifier used for group coordination. When set inside a CollapsibleGroup, the group owns open state and its onChange is the notification callback. |
| `ref` | `React.Ref<HTMLDivElement>` | no | `` | Ref forwarded to the root collapsible element. |
| `xstyle` | `StyleXStyles` | no | `` | StyleX styles for layout customization. Must be a stylex.create() value. |
| `className` | `string` | no | `` | CSS class name for the root element. Prefer xstyle for styling. |
| `style` | `CSSProperties` | no | `` | Inline styles. Prefer xstyle for StyleX-optimized styling. |
| `data-testid` | `string` | no | `` | Test selector for automated testing frameworks. |

## Anatomy

- `Container` (required) — The root that contains one trigger and its controlled content and, in a divided group, paints the item divider.
- `Trigger` (required) — The always-visible button that toggles the content. Shows a label and a chevron indicator.
- `Chevron` (optional) — Animated disclosure arrow. It follows the label by default; chevronPosition="start" moves it ahead of the label, points inward when collapsed (mirrored under RTL), and turns down when expanded.
- `Content` (optional) — The area that hides or reveals when the trigger is clicked.
- `Group container` (optional) — The CollapsibleGroup wrapper rendered when dividers are enabled. It contains the coordinated items and carries their density.

## Accessibility contract

- **Trigger label** — 1.4.3 Contrast (Minimum), needs 4.5:1 in Rest, Pointer down. The trigger text must have at least 4.5:1 contrast with the surface behind it. For Pointer down, measure against the pressed overlay the trigger row paints while it is pressed.

## Retrieval keywords

`accordion`, `collapse`, `expandable`, `disclosure`, `toggle`, `panel`, `foldable`, `expander`, `expand`

---

Generated from `astryx/packages/core/src/Collapsible/Collapsible.doc.mjs` (MIT, https://github.com/facebook/astryx). Spec: yes · upstream tests: yes.

<!-- port-status:begin (generated by tools/gen-port-status.py) -->
## OCaml port

**Status:** ported in M50 — [`src/collapsible.ml`](../src/collapsible.ml)

**Module:** `Astryx.Collapsible` (open `Astryx`)

```ocaml
val view
  :  ?attrs:Vdom.Attr.t list
  -> ?id:string
  -> ?is_open:bool Bonsai.t
  -> ?is_disabled:bool
  -> ?default_is_open:bool
  -> ?on_open_change:(bool -> unit Effect.t) Bonsai.t
  -> ?chevron_position:chevron_position
  -> trigger:Vdom.Node.t
```

Call it with the same prop names and defaults the upstream contract above documents; `Divergence` comments in the source record the few places the port deliberately differs (class names, and inline styles for per-instance numeric props).

<!-- port-status:end -->
