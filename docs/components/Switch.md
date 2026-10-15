# Switch

**Category:** Form Controls  |  **Group:** -  |  **Port status:** not started

A toggle control for on/off states that take effect immediately. Supports
labels, descriptions, loading states, and validation. Use it for settings or
preferences that apply instantly. For changes requiring a form submission,
use a checkbox instead.

## When to reach for it / when not to

- **Do:** Use for settings that apply immediately; the toggle should take effect
  without a separate save action.
- **Do:** Pair with a clear, concise label that describes the setting being
  controlled.
- **Don't:** Use for options that require a form submission to take effect; use a
  checkbox instead.
- **Don't:** Use a switch for multi-state values; it's strictly on/off.
- **Don't:** Wrap a disabled switch in Tooltip to explain why it is disabled;
  disabled controls swallow the hover events the wrapper needs. Use the
  disabledMessage prop instead.

## Props

| prop | type | required | default | meaning |
| --- | --- | --- | --- | --- |
| `ref` | `React.Ref<HTMLInputElement>` | no | `` | Ref forwarded to the underlying <input> element. |
| `label` | `string` | yes | `` | Label text for the switch (always rendered for accessibility). |
| `value` | `boolean` | yes | `` | Whether the switch is on or off. |
| `onChange` | `(checked: boolean, e: ChangeEvent<HTMLInputElement>) => void` | no | `` | Callback fired when the switch state changes. |
| `changeAction` | `(checked: boolean, e: ChangeEvent<HTMLInputElement>) => void \| Promise<void>` | no | `` | Async action fired after onChange. Triggers optimistic UI and shows a loading spinner until the promise resolves. |
| `isLoading` | `boolean` | no | `false` | Whether the switch is in a loading state, showing a spinner inside the thumb. |
| `isLabelHidden` | `boolean` | no | `false` | Visually hides the label while keeping it accessible to screen readers. |
| `description` | `string` | no | `` | Description text displayed below the label. |
| `isDisabled` | `boolean` | no | `false` | Whether the switch is disabled. |
| `size` | `'sm' \| 'md'` | no | `'md'` | Size variant controlling track and thumb dimensions. sm (32x20px) matches sm checkbox/radio vertical rhythm; md (40x24px, default) matches md checkbox/radio vertical rhythm. |
| `htmlName` | `string` | no | `` | The HTML name attribute for the underlying checkbox input, useful for form submissions (submits "on" when the switch is on). |
| `disabledMessage` | `string` | no | `` | Explains why the switch is disabled. With isDisabled, shows a tooltip on hover/keyboard focus and keeps the switch focusable via aria-disabled (toggling stays blocked). Use this instead of wrapping a disabled Switch in Tooltip. Disabled controls swallow the hover events an external Tooltip needs. |
| `isOptional` | `boolean` | no | `false` | Whether the field is optional. Mutually exclusive with isRequired. |
| `isRequired` | `boolean` | no | `false` | Whether the switch is required. Mutually exclusive with isOptional. |
| `status` | `{type: 'warning' \| 'error' \| 'success', message?: string}` | no | `` | Status indicator with type and message. Displays a colored message box below the switch and sets aria-invalid when type is "error". |
| `onFocus` | `(e: FocusEvent<HTMLInputElement>) => void` | no | `` | Callback fired when the switch receives focus. |
| `onBlur` | `(e: FocusEvent<HTMLInputElement>) => void` | no | `` | Callback fired when the switch loses focus. |
| `labelIcon` | `IconType` | no | `` | Icon displayed before the label text. See `astryx docs icons` for valid semantic names. |
| `labelTooltip` | `string` | no | `` | Tooltip text shown in an info icon at the end of the label. |
| `labelPosition` | `'start' \| 'end'` | no | `'end'` | Which side of the switch the label appears on. "start" places the label before the switch. |
| `labelSpacing` | `'hug' \| 'spread'` | no | `'hug'` | Spacing behavior between label and switch. "hug" places them next to each other; "spread" pushes them to opposite ends of the container (full width). |
| `width` | `SizeValue` | no | `` | Width of the field (number = pixels, string used as-is, e.g. "100%"). Sizes the whole field (label, control, and status) so they stay aligned. |

## Anatomy

- `Field` (required) — Container arranging the switch, label, and feedback.
- `Track` (required) — Pill-shaped surface that shows the off or on state.
- `Thumb` (required) — Indicator that moves across the track when state changes.
- `Label` (required) — Text identifying the setting controlled by the switch.
- `Description` (optional) — Helper text below the label.
- `Spinner` (optional) — Loading indicator shown inside the thumb while busy.
- `Status message` (optional) — Error, warning, or success message below the switch.

## Accessibility contract

- **Track and thumb** — 1.4.11 Non-text Contrast, needs 3:1 in Rest, Hover, Pointer down. The on and off tracks must each have at least 3:1 contrast with the surface behind them, and the thumb with its track. For Hover and Pointer down, measure the final colors after the tint and the pressed overlay are applied.

## Retrieval keywords

`switch`, `toggle`, `onoff`, `flipswitch`, `boolean`, `toggleswitch`

---

Generated from `astryx/packages/core/src/Switch/Switch.doc.mjs` (MIT, https://github.com/facebook/astryx). Spec: yes · upstream tests: yes.

<!-- port-status:begin (generated by tools/gen-port-status.py) -->
## OCaml port

**Status:** not ported yet. The upstream contract above is the specification; see `docs/PORT-STATUS.md` for the milestone it is planned in.

<!-- port-status:end -->
