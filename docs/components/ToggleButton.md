# ToggleButton

**Category:** Action  |  **Group:** Button  |  **Port status:** not started

ToggleButton switches between selected and unselected states to represent a
persistent on/off choice. Use it standalone for binary actions like bold,
mute, or favorite, or inside a ToggleButtonGroup for single-select or
multi-select toolbar controls.

## When to reach for it / when not to

- **Do:** Use a filled or colored icon for the pressed state so users can see the
  current state at a glance: an outline star vs a solid star, for example.
- **Do:** Keep the label identical between pressed and unpressed states. Let the
  visual treatment (icon, weight, background) communicate the change.
- **Do:** Wrap related toggles in a ToggleButtonGroup with an accessible label so
  screen readers announce them as a connected set.
- **Don't:** Don't use a ToggleButton for one-time actions like "Submit" or "Delete";
  those are regular Buttons, not toggles.
- **Don't:** Don't mix ToggleButtons with regular Buttons inside the same group; use
  only ToggleButtons in a ToggleButtonGroup.
- **Don't:** Don't use a ToggleButton for on/off settings that persist across
  sessions; use a Switch instead, which better communicates "setting"
  semantics.

## Props

| prop | type | required | default | meaning |
| --- | --- | --- | --- | --- |
| `label` | `string` | yes | `` | Accessible label for the button. Used as visible text, or as aria-label for icon-only buttons. |
| `isPressed` | `boolean` | no | `` | Whether the button is currently pressed. Ignored for a ToggleButtonGroup member with a value. |
| `onPressedChange` | `(isPressed: boolean, event: MouseEvent) => void` | no | `` | Called synchronously when pressed state should change. Receives the next state and the click event; call event.preventDefault() to skip pressedChangeAction. Without an Action, the callback produces no Action-pending feedback. Ignored for a ToggleButtonGroup member with a value. |
| `pressedChangeAction` | `(isPressed: boolean) => void \| Promise<void>` | no | `` | Action handler for API- or navigation-backed toggles, run in a transition after the synchronous onPressedChange callback unless that callback calls event.preventDefault(). Works without onPressedChange. Shows an optimistic pressed state and a spinner while pending, and remains interruptible by re-clicks. Omit it for callback-only toggles with no Action-pending feedback. Ignored for a ToggleButtonGroup member with a value. |
| `size` | `'sm' \| 'md' \| 'lg'` | no | `'md'` | Button size. Defaults to group size when inside a group. |
| `elevation` | `'none' \| 'low' \| 'med' \| 'high'` | no | `'none'` | Resting shadow depth for floating (FAB-style) toggle buttons, mirroring Button. `none` is the default flat button; `low`/`med`/`high` map to the shadow token scale. Applies inside a ToggleButtonGroup as well — grouped children retain their own elevation. |
| `isDisabled` | `boolean` | no | `false` | Whether the button is disabled. |
| `isLoading` | `boolean` | no | `false` | Whether the button shows a loading spinner. |
| `icon` | `ReactNode` | no | `` | Icon element. When provided without children, button becomes icon-only with tooltip from label. |
| `isIconOnly` | `boolean` | no | `false` | When true, renders as a square icon-only button with `label` as the aria-label and an automatic tooltip from the label. |
| `pressedIcon` | `ReactNode` | no | `` | Icon shown when pressed. Falls back to icon if not provided. |
| `children` | `ReactNode` | no | `` | Visible content. If omitted with icon, button becomes icon-only. |
| `tooltip` | `string` | no | `` | Tooltip text shown on hover. |
| `value` | `string` | no | `` | Value identifier when used inside ToggleButtonGroup. Required in groups. |
| `data-testid` | `string` | no | `` | Test selector for automated testing frameworks. |

## Anatomy

- `Icon` (optional) — A leading icon that represents the toggle action, like a star for favorite or bold "B" for formatting.
- `Pressed icon` (optional) — An alternate icon shown when pressed: typically a filled version of the default icon to reinforce the active state.
- `Label` (required) — The visible text or accessible name. For icon-only toggles, used as the aria-label and auto-tooltip.
- `Spinner` (optional) — Replaces the icon during async operations triggered by pressedChangeAction.

## Accessibility contract

- **Text label** — 1.4.3 Contrast (Minimum), needs 4.5:1 in Unselected, Selected, Hover, Pointer down. The label must have at least 4.5:1 contrast with the button background when selected and unselected. For Hover and Pointer down, measure the final background after the overlay is applied.
- **Essential icon or spinner arc** — 1.4.11 Non-text Contrast, needs 3:1 in Icon only, Loading. An icon-only ToggleButton must have at least 3:1 contrast between its icon and button background. The moving spinner arc must also meet 3:1. An icon beside a visible label does not need its own check.
- **Selected state indicator** — 1.4.11 Non-text Contrast, needs 3:1 if relied upon in Selected. The selected background must reach 3:1 only when users need it to tell selected from unselected. Label weight or a changed icon can also show selection.
- **Visible control boundary** — 1.4.11 Non-text Contrast, needs 3:1 if needed in Rest. The button edge needs 3:1 contrast only when users need it to see the control. A visible label or icon can show the control instead.
- **Keyboard focus indicator** — 1.4.11 Non-text Contrast, needs 3:1 in Focus visible. The focus outline must have at least 3:1 contrast with the area around the button. Check both selected and unselected states.
- **Disabled appearance** — 1.4.3 and 1.4.11 exceptions, needs Not required in Disabled. Disabled controls do not need to meet these contrast ratios.

## Retrieval keywords

`toggle`, `togglebutton`, `pressed`, `toolbar`, `formatting`, `segmented`, `button-group`, `exclusive`, `multi-select`

---

Generated from `astryx/packages/core/src/ToggleButton/ToggleButton.doc.mjs` (MIT, https://github.com/facebook/astryx). Spec: no · upstream tests: yes.

<!-- port-status:begin (generated by tools/gen-port-status.py) -->
## OCaml port

**Status:** ported in M27 — [`src/toggle_button.ml`](../src/toggle_button.ml)

**Module:** `Astryx.Toggle_button` (open `Astryx`)

```ocaml
val view
  :  ?attrs:Vdom.Attr.t list
  -> ?id:string
  -> ?is_pressed:bool
  -> ?on_pressed_change:(bool -> unit Effect.t)
  -> ?size:Button.size
  -> ?variant:Button.variant
  -> ?elevation:Button.elevation
  -> ?is_disabled:bool
  -> ?is_loading:bool
  -> ?icon:Vdom.Node.t
```

Call it with the same prop names and defaults the upstream contract above documents; `Divergence` comments in the source record the few places the port deliberately differs (class names, and inline styles for per-instance numeric props).

<!-- port-status:end -->
