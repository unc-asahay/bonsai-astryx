# NumberInput

**Category:** Form Controls  |  **Group:** -  |  **Port status:** not started

A form input for numeric values with built-in validation, min/max
constraints, and step controls. Use NumberInput for quantities,
measurements, percentages, and similar inputs.

## When to reach for it / when not to

- **Do:** Let people paste formatted numbers: a pasted 1,234,234,234 is read under
  the field's locale and commits as 1234234234 on blur. Typing is never
  intercepted.
- **Do:** Set min, max, and step to guide users toward valid values.
- **Do:** Show units (e.g. "%" or "GB") so users know what the number represents.
- **Do:** Set isWheelEnabled={false} when the input appears in a scrolling surface
  where wheel gestures should always scroll the page.
- **Don't:** Use NumberInput for free-form text that happens to contain numbers; use
  TextInput instead.
- **Don't:** Set both isOptional and isRequired on the same field.
- **Don't:** Wrap a disabled NumberInput in Tooltip to explain why it's disabled;
  disabled controls swallow the hover events the wrapper needs. Use the
  disabledMessage prop instead.

## Props

| prop | type | required | default | meaning |
| --- | --- | --- | --- | --- |
| `label` | `string` | yes | `` | Label text for the input (always rendered for accessibility). |
| `value` | `number \| null \| undefined` | yes | `` | Current value of the input. |
| `onChange` | `(value: number) => void` | yes | `` | Callback fired when a valid text edit commits on blur or Enter, or when a step or clear control changes the value. |
| `size` | `'sm' \| 'md' \| 'lg'` | no | `'md'` | Size variant. |
| `isLabelHidden` | `boolean` | no | `` | Visually hide the label (still accessible to screen readers). |
| `description` | `string` | no | `` | Description text displayed between the label and input. |
| `isOptional` | `boolean` | no | `` | Whether the field is optional (mutually exclusive with isRequired). |
| `onKeyDown` | `(e: KeyboardEvent<HTMLInputElement>) => void` | no | `` | Callback fired on keydown events on the input. |
| `isRequired` | `boolean` | no | `` | Whether the field is required (mutually exclusive with isOptional). |
| `isDisabled` | `boolean` | no | `` | Whether the input is disabled. |
| `isReadOnly` | `boolean` | no | `false` | Makes the input read-only: the value is shown at full opacity and still submits with the form, but cannot be edited. Unlike isDisabled, a read-only input is not dimmed and stays in the tab order. Stepping is off in every form while read-only: arrow keys, the wheel, and the number steppers. isDisabled takes precedence when both are set. |
| `disabledMessage` | `string` | no | `` | Explains why the input is disabled. With isDisabled, shows a tooltip on hover/keyboard focus and keeps the input focusable via aria-disabled (the field becomes read-only). Use this instead of wrapping a disabled NumberInput in Tooltip. |
| `placeholder` | `string` | no | `` | Placeholder text. |
| `labelTooltip` | `string` | no | `` | Tooltip text to display in an info icon at the end of the label. |
| `startIcon` | `IconType` | no | `` | Icon to display at the start of the input. See `astryx docs icons` for valid semantic names. |
| `labelIcon` | `IconType` | no | `` | Icon to display before the label text. See `astryx docs icons` for valid semantic names. |
| `status` | `{type: 'error' \| 'warning' \| 'success', message?: string}` | no | `` | Validation status with optional message. |
| `statusVariant` | `'attached' \| 'detached' \| 'tooltip'` | no | `'attached'` | How the status message is placed relative to the input. attached overlaps directly below the input (bordered treatment); detached floats below as a separate element with spacing; tooltip hides the message box and surfaces it in a tooltip on the status icon. |
| `min` | `number \| null` | no | `` | Minimum value allowed. A smaller entry commits at this value on blur or Enter. |
| `max` | `number \| null` | no | `` | Maximum value allowed. A larger entry commits at this value on blur or Enter. |
| `step` | `number \| null` | no | `1` | Step increment for the input. |
| `formatValue` | `(value: number) => string` | no | `` | Formats the committed value while the input is not focused. The raw numeric value is shown on focus for editing and the formatted value is exposed through aria-valuetext. |
| `isWheelEnabled` | `boolean` | no | `true` | Whether scrolling the wheel over the focused input steps the value. Disable this when page scrolling should always take priority. |
| `hasNumberSteppers` | `boolean` | no | `false` | Shows increment and decrement buttons at the end of the input. |
| `units` | `string \| null` | no | `` | Units text to display at the end of the input (e.g., "%" or "GB"). |
| `isIntegerOnly` | `boolean` | no | `` | Only allow integer values (no floating point). |
| `hasClear` | `boolean` | no | `false` | Shows a clear (×) button when the input has a value. When true, the onChange callback also accepts null to signal the user cleared the input. |
| `htmlName` | `string` | no | `` | HTML name attribute for form submissions. |
| `autoComplete` | `string` | no | `` | HTML autocomplete attribute. |
| `width` | `SizeValue` | no | `` | Width of the field (number = pixels, string used as-is, e.g. "100%"). Sizes the whole field (label, control, and status) so they stay aligned. |
| `hasAutoFocus` | `boolean` | no | `` | Whether to focus the input on mount. |
| `onFocus` | `(e: FocusEvent<HTMLInputElement>) => void` | no | `` | Callback fired when the input receives focus. |
| `onBlur` | `(e: FocusEvent<HTMLInputElement>) => void` | no | `` | Callback fired when the input loses focus. |
| `onEnter` | `() => void` | no | `` | Callback fired when the user presses the Enter key. |
| `containerXstyle` | `StyleXStyles` | no | `` | StyleX styles for the field container (label, control, and status together). No effect inside InputGroup (style the InputGroup instead) or in a `horizontal-labels` FormLayout. Root `xstyle`, `className`, and `style` are not accepted. |
| `containerClassName` | `string` | no | `` | Class name for the field container. Same targeting as `containerXstyle`. |
| `containerStyle` | `CSSProperties` | no | `` | Inline styles for the field container. Same targeting as `containerXstyle`. |
| `controlXstyle` | `StyleXStyles` | no | `` | StyleX styles for the visual control box: the element that paints the border and background and holds icons and end controls. Never the native input. |
| `controlClassName` | `string` | no | `` | Class name for the visual control box. |
| `controlStyle` | `CSSProperties` | no | `` | Inline styles for the visual control box. |

## Anatomy

- `Label` (required) — The label for the number input.
- `Description` (optional) — Additional description text below the label.
- `Icon` (optional) — An optional icon within the input.
- `Placeholder` (optional) — Placeholder text shown when the input is empty.
- `Number steppers` (optional) — Optional buttons that increment or decrement by the configured step.

## Retrieval keywords

`numberinput`, `numberfield`, `stepper`, `spinner`, `counter`, `increment`, `decrement`, `quantity`, `numberpicker`

---

Generated from `astryx/packages/core/src/NumberInput/NumberInput.doc.mjs` (MIT, https://github.com/facebook/astryx). Spec: no · upstream tests: yes.

<!-- port-status:begin (generated by tools/gen-port-status.py) -->
## OCaml port

**Status:** not ported yet. The upstream contract above is the specification; see `docs/PORT-STATUS.md` for the milestone it is planned in.

<!-- port-status:end -->
