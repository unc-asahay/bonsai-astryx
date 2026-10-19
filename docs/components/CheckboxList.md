# CheckboxList

**Category:** Form Controls  |  **Group:** Checkbox  |  **Port status:** not started

CheckboxList shows a small group of checkboxes so users can turn several
options on or off at once. Place it in settings pages, filter panels, or
forms where every choice should be visible without scrolling. For a single
standalone checkbox (like "I agree to the terms"), use CheckboxInput
instead. If only one option can be picked, use RadioList. If the list is
long enough to need searching or scrolling, use MultiSelector instead.

## When to reach for it / when not to

- **Do:** Keep the list short: three to seven options is the sweet spot. Beyond
  that, switch to MultiSelector which adds search and scrolling.
- **Do:** Turn on dividers (hasDividers) when items have helper text underneath;
  without them the labels and descriptions blur together.
- **Do:** Write a group label that says what the choices represent: "Export
  formats" tells users more than "Options".
- **Don't:** Show a CheckboxList when the user can only pick one thing; that is what
  RadioList is for.
- **Don't:** Put buttons or links inside the trailing slot (endContent); the whole
  row is already tappable, so a nested button creates two competing click
  targets.
- **Don't:** Wrap a disabled CheckboxList in Tooltip to explain why it is disabled;
  disabled controls swallow the hover events the wrapper needs. Use the
  disabledMessage prop instead.

## Props

| prop | type | required | default | meaning |
| --- | --- | --- | --- | --- |
| `label` | `string` | yes | `` | Label text for the checkbox group (always rendered for accessibility). |
| `children` | `ReactNode` | yes | `` | CheckboxListItem elements. |
| `value` | `string[]` | no | `` | The currently selected values (collection mode). |
| `onChange` | `(values: string[]) => void` | no | `` | Callback fired when the selected values change. |
| `changeAction` | `(values: string[]) => void \| Promise<void>` | no | `` | Async action on change with optimistic updates. While the promise is pending, the toggled item shows a spinner inside its checkbox and is marked aria-busy. |
| `isLabelHidden` | `boolean` | no | `false` | Whether to visually hide the label. |
| `description` | `string` | no | `` | Description text displayed below the label. |
| `density` | `'compact' \| 'balanced' \| 'spacious'` | no | `'balanced'` | Spacing density for list items. |
| `hasDividers` | `boolean` | no | `false` | Whether to show dividers between items. |
| `isDisabled` | `boolean` | no | `false` | Whether all checkbox items are disabled. |
| `disabledMessage` | `string` | no | `` | Explains why the group is disabled. Applies to the whole-group disabled state (isDisabled), not per item. With isDisabled, shows a tooltip on hover/keyboard focus and keeps the checkboxes focusable via aria-disabled (toggling stays blocked). Use this instead of wrapping a disabled CheckboxList in Tooltip. Disabled controls swallow the hover events an external Tooltip needs. |
| `isReadOnly` | `boolean` | no | `false` | Whether all checkbox items are read-only. Displays the current state at full opacity but prevents interaction. Unlike isDisabled, read-only checkboxes are not visually dimmed. |
| `status` | `{type: 'warning' \| 'error' \| 'success', message?: string}` | no | `` | Status indicator ({ type, message }). |
| `width` | `SizeValue` | no | `` | Width of the field (number = pixels, string used as-is, e.g. "100%"). Sizes the whole field (label, control, and status) so they stay aligned. |
| `containerXstyle` | `StyleXStyles` | no | `` | StyleX styles for the field container (label, control, and status together). No effect inside InputGroup (style the InputGroup instead) or in a `horizontal-labels` FormLayout. Root `xstyle`, `className`, and `style` are not accepted. |
| `containerClassName` | `string` | no | `` | Class name for the field container. Same targeting as `containerXstyle`. |
| `containerStyle` | `CSSProperties` | no | `` | Inline styles for the field container. Same targeting as `containerXstyle`. |
| `controlXstyle` | `StyleXStyles` | no | `` | StyleX styles for the visual control box: the element that paints the border and background and holds icons and end controls. Never the native input. |
| `controlClassName` | `string` | no | `` | Class name for the visual control box. |
| `controlStyle` | `CSSProperties` | no | `` | Inline styles for the visual control box. |

## Anatomy

- `Group` (required) — Container for the labeled checkbox group.
- `Group label` (required) — Text identifying what the checkbox options represent.
- `Description` (optional) — Helper text below the group label.
- `Options list` (required) — List containing the available checkbox options.
- `Option row` (required) — Selectable row containing one option.
- `Checkbox` (required) — Selection indicator for an option.
- `Option label` (required) — Primary content identifying an option.
- `Option description` (optional) — Secondary text below an option label.
- `End content` (optional) — Caller-provided content at the end of an option row.
- `Spinner` (optional) — Loading indicator shown inside the pending checkbox.
- `Status message` (optional) — Error, warning, or success message below the group.

## Retrieval keywords

`checkboxlist`, `checkbox`, `checkboxgroup`, `multichoice`, `multiselect`, `checklist`

---

Generated from `astryx/packages/core/src/CheckboxList/CheckboxList.doc.mjs` (MIT, https://github.com/facebook/astryx). Spec: yes · upstream tests: yes.

<!-- port-status:begin (generated by tools/gen-port-status.py) -->
## OCaml port

**Status:** ported in M48 — [`src/checkbox_list.ml`](../src/checkbox_list.ml)

**Module:** `Astryx.Checkbox_list` (open `Astryx`)

```ocaml
val view
  :  ?attrs:Vdom.Attr.t list
  -> ?is_disabled:bool
  -> ?disabled_message:string
  -> ?is_read_only:bool
  -> ?is_label_hidden:bool
  -> ?is_optional:bool
  -> ?is_required:bool
  -> ?optionality:Common.Optionality.t
  -> ?label_icon:string
  -> ?description:string
  -> ?status:Input_types.status
  -> ?width:Common.Size_value.t
  -> ?density:List_container.density
  -> ?has_dividers:bool
  -> label:string
  -> id:string
  -> items:item list
  -> value:string list Bonsai.t
  -> on_change:(string list -> unit Effect.t) Bonsai.t
  -> unit
  -> Vdom.Node.t Bonsai.t
```

Call it with the same prop names and defaults the upstream contract above documents; `Divergence` comments in the source record the few places the port deliberately differs (class names, and inline styles for per-instance numeric props).

<!-- port-status:end -->
