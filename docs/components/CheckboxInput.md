# CheckboxInput

**Category:** Form Controls  |  **Group:** Checkbox  |  **Port status:** not started

CheckboxInput toggles a single on/off value. Use it for settings like
"Enable notifications", terms acceptance, or opt-in choices. For multiple
checkboxes in a group, use CheckboxList instead.

## When to reach for it / when not to

- **Do:** Always provide a visible label so the user knows what they are toggling.
  Use isLabelHidden only when surrounding context makes it obvious.
- **Do:** Add a description for choices that need extra context, like explaining
  what "Share usage data" actually shares.
- **Do:** Use the indeterminate state for "select all" checkboxes when only some
  items in a group are selected.
- **Don't:** Use a checkbox for mutually exclusive choices; use RadioList when only
  one option can be selected.
- **Don't:** Use a checkbox for actions that take effect immediately; use a toggle
  switch or button instead.
- **Don't:** Wrap a disabled checkbox in Tooltip to explain why it is disabled;
  disabled controls swallow the hover events the wrapper needs. Use the
  disabledMessage prop instead.

## Props

| prop | type | required | default | meaning |
| --- | --- | --- | --- | --- |
| `ref` | `React.Ref<HTMLInputElement>` | no | `` | Ref forwarded to the underlying <input> element. |
| `label` | `string` | yes | `` | Label text for the checkbox (always rendered for accessibility). |
| `isLabelHidden` | `boolean` | no | `false` | Whether to visually hide the label (still accessible to screen readers). |
| `description` | `string` | no | `` | Description text displayed below the label. |
| `value` | `boolean \| 'indeterminate'` | yes | `` | Whether the checkbox is checked, unchecked, or indeterminate. |
| `onChange` | `(checked: boolean, e: ChangeEvent<HTMLInputElement>) => void` | no | `` | Callback fired when the checkbox state changes. |
| `changeAction` | `(checked: boolean, e: ChangeEvent<HTMLInputElement>) => void \| Promise<void>` | no | `` | Async action on change. Fires after onChange if not prevented. Shows loading spinner while pending. |
| `isLoading` | `boolean` | no | `false` | Whether the checkbox is in a loading state. Shows spinner and prevents interaction. |
| `isDisabled` | `boolean` | no | `false` | Whether the checkbox is disabled. |
| `htmlName` | `string` | no | `` | The HTML name attribute for the underlying checkbox input, useful for form submissions (submits "on" when checked). |
| `disabledMessage` | `string` | no | `` | Explains why the checkbox is disabled. With isDisabled, shows a tooltip on hover/keyboard focus and keeps the checkbox focusable via aria-disabled (toggling stays blocked). Use this instead of wrapping a disabled CheckboxInput in Tooltip. Disabled controls swallow the hover events an external Tooltip needs. |
| `isReadOnly` | `boolean` | no | `false` | Whether the checkbox is read-only. Displays the current state at full opacity but prevents interaction. Unlike `isDisabled`, read-only checkboxes are not visually dimmed. |
| `isOptional` | `boolean` | no | `false` | Whether the field is optional. Mutually exclusive with isRequired. |
| `isRequired` | `boolean` | no | `false` | Whether the checkbox is required. Mutually exclusive with isOptional. |
| `size` | `'sm' \| 'md'` | no | `'md'` | The size of the checkbox. sm for compact layouts, md for default. |
| `onFocus` | `(e: FocusEvent<HTMLInputElement>) => void` | no | `` | Callback fired when the checkbox receives focus. |
| `onBlur` | `(e: FocusEvent<HTMLInputElement>) => void` | no | `` | Callback fired when the checkbox loses focus. |
| `labelIcon` | `ReactNode \| IconType` | no | `` | Semantic icon name or custom content displayed before the label text. See `astryx docs icons` for valid semantic names. |
| `status` | `{ type: 'error' \| 'warning' \| 'success', message: string }` | no | `` | Status indicator. Displays a colored message box below the checkbox and sets aria-invalid for errors. |
| `width` | `SizeValue` | no | `` | Width of the field (number = pixels, string used as-is, e.g. "100%"). Sizes the whole field (label, control, and status) so they stay aligned. |

## Anatomy

- `Checkbox` (required) — The check box itself: unchecked, checked, or indeterminate.
- `Label` (required) — Text describing what the checkbox controls. Always present for accessibility.
- `Description` (optional) — Helper text below the label with additional context.
- `Status message` (optional) — An error, warning, or success message below the checkbox.

## Accessibility contract

- **Checkbox box** — 1.4.11 Non-text Contrast, needs 3:1 in Rest, Hover, Pointer down, Checked. The box edge (unchecked) and fill (checked) must have at least 3:1 contrast with the surface behind them. For Hover and Pointer down, measure the final colors after the tint and the pressed overlay are applied.

## Retrieval keywords

`checkbox`, `check`, `toggle`, `tick`, `indeterminate`, `boolean`, `tristate`

---

Generated from `astryx/packages/core/src/CheckboxInput/CheckboxInput.doc.mjs` (MIT, https://github.com/facebook/astryx). Spec: yes · upstream tests: yes.

<!-- port-status:begin (generated by tools/gen-port-status.py) -->
## OCaml port

**Status:** ported in M12 — [`src/checkbox_input.ml`](../src/checkbox_input.ml)

**Module:** `Astryx.Checkbox_input` (open `Astryx`)

```ocaml
val view
  :  ?attrs:Vdom.Attr.t list
  -> ?is_disabled:bool
  -> ?disabled_message:string
```

Call it with the same prop names and defaults the upstream contract above documents; `Divergence` comments in the source record the few places the port deliberately differs (class names, and inline styles for per-instance numeric props).

<!-- port-status:end -->
