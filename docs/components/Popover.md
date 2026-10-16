# Popover

**Category:** Overlay  |  **Group:** Popover  |  **Port status:** not started

A click-triggered overlay anchored to a button or trigger element. Use it
for secondary actions, inline confirmations, or supplementary information
that does not warrant a full dialog. For hover previews use HoverCard, for
brief helper text use Tooltip.

## When to reach for it / when not to

- **Do:** Keep popover content focused on a single task or piece of information.
- **Do:** Provide a clear way to close: either by clicking outside or with an
  explicit close button.
- **Do:** Theme the painted surface through the canonical popover target.
- **Don't:** Nest popovers inside other popovers; it creates confusing focus and
  navigation.
- **Don't:** Assume input complexity alone determines the presentation; evaluate the
  task's focus, space, and interaction requirements.
- **Don't:** Assume scrolling alone means Popover is the wrong component; a bounded
  Popover may scroll while a focused anchored interaction remains
  appropriate.

## Props

| prop | type | required | default | meaning |
| --- | --- | --- | --- | --- |
| `children` | `ReactNode \| ((props: PopoverTriggerRenderProps) => ReactNode)` | no | `` | The trigger element. Accepts either: **ReactNode (automatic mode):** Must contain a `<button>` or `[role="button"]` element — the popover locates it and applies click/keydown handlers and ARIA attributes automatically. Components that consume `InteractiveRoleContext` (e.g., Token) will render as a button automatically when placed here. **Render function (explicit mode):** Receives `PopoverTriggerRenderProps` with ref, onClick, and ARIA attributes. The consumer is responsible for attaching these to their trigger element. Use this for custom triggers or third-party components. The trigger is rendered inside an anchor wrapper used for CSS anchor positioning. The wrapper is stable (no pressed-state transforms), preventing popover position jitter. When `anchorRef` is provided, children can be omitted and the popover attaches to the external ref element as a sibling. @example ``` <Popover content={...}><Button label="Open" /></Popover> <Popover content={...}><Token label="Filter" /></Popover> <Popover content={...}> {(triggerProps) => <MyCustomTrigger {...triggerProps} />} </Popover> ``` / |
| `anchorRef` | `React.RefObject<HTMLElement>` | no | `` | External ref to use as the popover anchor. When provided (and no children), the popover attaches to this element instead of wrapping children. The referenced element must be a `<button>` or `[role="button"]` — the popover applies click/keydown handlers and ARIA attributes to it directly. / |
| `content` | `ReactNode` | yes | `` | Content to display inside the popover. / |
| `placement` | `LayerPlacement` | no | `'below' /` | Position placement relative to the trigger. Uses CSS anchor positioning via useLayer. |
| `alignment` | `LayerAlignment` | no | `'start' /` | Alignment along the placement axis. |
| `isOpen` | `boolean` | no | `` | Whether the popover is open (controlled mode). Omit for uncontrolled behavior. / |
| `onOpenChange` | `(isOpen: boolean) => void` | no | `` | Callback fired when the popover visibility changes. / |
| `isEnabled` | `boolean` | no | `true /` | Whether the popover is enabled. When false, trigger interactions are ignored. |
| `width` | `number \| string` | no | `'auto' /` | Width of the popover container. Numbers are px, strings are CSS widths. The popover renders at this width up to the viewport minus its gutters — it is never shrunk to the room beside the trigger; when it does not fit there it flips or slides. |
| `padding` | `SpacingStep` | no | `3 /` | Inner padding of the popover surface, using the spacing scale. Accepts numeric spacing steps: 0, 0.5, 1, 1.5, 2, 3, 4, 5, 6, 8, 10. Matches the `padding` prop on `Card` and `Stack`. Pass `0` for a flush surface when the content owns its own edges — a list of rows whose hover paint reaches the edge, or a header row with a bottom rule — and pad the content itself. The padding sits on the painted surface (the `popover` theme target), so a theme's `padding` on that target replaces it rather than nesting. |
| `label` | `string` | no | `` | Accessible label for the popover dialog. Recommended for accessibility when `role` is `'dialog'`. / |
| `role` | `'dialog' \| 'none'` | no | `'dialog' /` | ARIA role stamped on the popover content wrapper. Use `'dialog'` for dialog-style popovers. Use `'none'` when the popup content owns its own role, such as a child `role="menu"` or `role="listbox"`. |
| `isModal` | `boolean` | no | `true /` | Whether a dialog-style popover is modal (`aria-modal`). Only applies when `role` is `'dialog'`. |
| `hasCloseButton` | `boolean` | no | `true /` | Whether to include a hidden close button for accessibility. The button appears when keyboard users tab past the last element. |
| `closeButtonLabel` | `string` | no | `"Close popover" /` | Label for the hidden close button. |
| `hasAutoFocus` | `boolean` | no | `true /` | Whether to move focus into the popover when it opens. Focus enters the first genuine caller content control; dialogs with none fall back to the labeled surface. The generated fallback close control is excluded from initial focus and reveals only when reached through keyboard navigation. Set to `false` for input-owned focus, inline showcases, or documentation previews. |
| `hasLightDismiss` | `boolean` | no | `true /` | Whether clicking outside dismisses the popover. Set to `false` for surfaces that should stay open until explicitly dismissed, like onboarding coachmarks or multi-step flows. |
| `hasEscapeDismiss` | `boolean 'data-testid'?: string` | no | `true /` | Whether pressing Escape dismisses the popover. Only takes full effect together with `hasLightDismiss={false}`: with light dismiss on, the browser's native light dismiss also closes on Escape. Set both to `false` for explicit-dismiss-only surfaces. |

## Anatomy

- `Trigger element` (required) — Caller-supplied or externally referenced control that anchors and toggles the popover.
- `Popover surface` (required) — Painted surface owned and themed by Popover through the canonical popover target.
- `Popover content` (required) — Caller-supplied content rendered inside the surface.
- `Fallback close control` (optional) — Keyboard-reachable close affordance appended by usePopover when enabled.

## Retrieval keywords

`popover`, `popup`, `dropdown`, `tooltip`, `overlay`, `flyout`, `callout`, `popper`, `anchor`, `floating`, `bubble`

---

Generated from `astryx/packages/core/src/Popover/Popover.doc.mjs` (MIT, https://github.com/facebook/astryx). Spec: yes · upstream tests: no.

<!-- port-status:begin (generated by tools/gen-port-status.py) -->
## OCaml port

**Status:** ported in M18 — [`src/popover.ml`](../src/popover.ml)

**Module:** `Astryx.Popover` (open `Astryx`)

```ocaml
val view
  :  ?attrs:Vdom.Attr.t list
  -> ?id:string
  -> ?placement:placement
  -> ?alignment:alignment
  -> ?width:string
  -> ?padding:Common.Spacing.t
  -> ?label:string
  -> ?role:role
  -> ?is_modal:bool
  -> ?has_close_button:bool
  -> ?close_button_label:string
  -> ?has_auto_focus:bool
  -> ?has_light_dismiss:bool
  -> ?has_escape_dismiss:bool
  -> ?is_enabled:bool
  -> trigger:Vdom.Node.t
```

Call it with the same prop names and defaults the upstream contract above documents; `Divergence` comments in the source record the few places the port deliberately differs (class names, and inline styles for per-instance numeric props).

<!-- port-status:end -->
