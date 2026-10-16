# TextInput

**Category:** Form Controls  |  **Group:** -  |  **Port status:** not started

TextInput collects short-form text like names, emails, or search queries.
Use it for single-line values where the expected input is brief. Pair it
with validation status to guide users through required or formatted fields.

## When to reach for it / when not to

- **Do:** Always provide a visible label so users know what the field is for. Only
  hide the label when surrounding context makes it obvious, like a search
  bar with a magnifying-glass icon.
- **Do:** Use validation status with a message to explain what went wrong: "Email
  must include @" is better than just turning the border red.
- **Do:** Size the input to match the expected content length so users can gauge
  how much to type: small for zip codes, medium for names, large for URLs.
- **Do:** Add a clear button for search and filter inputs so users can quickly
  reset without selecting all text.
- **Don't:** Don't use placeholder text as a replacement for a label; placeholders
  disappear on focus and are not reliably read by screen readers.
- **Don't:** Don't use TextInput for multi-line content like comments or
  descriptions; use TextArea instead.
- **Don't:** Don't mark every field as required; only flag mandatory fields so users
  are not overwhelmed by validation errors.
- **Don't:** Don't wrap a disabled TextInput in Tooltip to explain why it's disabled;
  disabled controls swallow the hover events the wrapper needs. Use the
  disabledMessage prop instead.

## Props

| prop | type | required | default | meaning |
| --- | --- | --- | --- | --- |
| `type` | `'text' \| 'password' \| 'email'` | no | `'text'` | The HTML input type. |
| `label` | `string` | yes | `` | Label text for the input: always rendered for accessibility. |
| `value` | `string` | yes | `` | Current value of the input. |
| `onChange` | `(value: string, e: ChangeEvent<HTMLInputElement>) => void` | no | `` | Callback fired when the input value changes. |
| `changeAction` | `(value: string, e: ChangeEvent<HTMLInputElement>) => void \| Promise<void>` | no | `` | Async action fired after onChange (if not prevented). Triggers optimistic update and shows a loading spinner while pending. |
| `size` | `'sm' \| 'md' \| 'lg'` | no | `'md'` | Size variant of the input. |
| `isLabelHidden` | `boolean` | no | `false` | Visually hides the label while keeping it accessible to screen readers. |
| `description` | `string` | no | `` | Description text displayed between the label and input. |
| `isOptional` | `boolean` | no | `false` | Displays an "Optional" indicator next to the label. Mutually exclusive with isRequired. |
| `isRequired` | `boolean` | no | `false` | Displays a "Required" indicator next to the label and sets aria-required. Mutually exclusive with isOptional. |
| `onEnter` | `() => void` | no | `` | Callback fired when the user presses the Enter key. IME-safe: Enter used to commit a Japanese/Chinese/Korean conversion does not fire it. |
| `onKeyDown` | `(e: KeyboardEvent<HTMLInputElement>) => void` | no | `` | Callback fired on keydown events on the input. |
| `isDisabled` | `boolean` | no | `false` | Disables the input, preventing interaction and dimming the element. |
| `isReadOnly` | `boolean` | no | `false` | Makes the input read-only: the value is shown at full opacity and still submits with the form, but cannot be edited. Unlike isDisabled, a read-only input is not dimmed and stays in the tab order. isDisabled takes precedence when both are set. |
| `disabledMessage` | `string` | no | `` | Explains why the input is disabled. With isDisabled, shows a tooltip on hover/keyboard focus and keeps the input focusable via aria-disabled (the field becomes read-only). Use this instead of wrapping a disabled TextInput in Tooltip. Disabled controls swallow the hover events an external Tooltip needs. |
| `isLoading` | `boolean` | no | `false` | Puts the input in a loading state, showing a spinner and setting aria-busy. |
| `placeholder` | `string` | no | `` | Placeholder text shown when the input is empty. |
| `labelTooltip` | `string` | no | `` | Tooltip text displayed in an info icon at the end of the label. |
| `startIcon` | `IconType` | no | `` | SVG icon component displayed at the start of the input. See `astryx docs icons` for valid semantic names. |
| `status` | `{type: 'error' \| 'warning' \| 'success', message?: string}` | no | `` | Validation status: applies a colored border and status icon. If message is provided, displays a floating message below the input. Error type also sets aria-invalid. |
| `statusVariant` | `'attached' \| 'detached' \| 'tooltip'` | no | `'attached'` | How the status message is placed relative to the input. attached overlaps directly below the input (bordered treatment); detached floats below as a separate element with spacing; tooltip hides the message box and surfaces it in a tooltip on the status icon. |
| `hasClear` | `boolean` | no | `false` | Shows a clear (×) button when the input has a value. Clicking it clears the value and returns focus to the input. |
| `hasAutoFocus` | `boolean` | no | `false` | Automatically focuses the input on mount. |
| `htmlName` | `string` | no | `` | The HTML name attribute for the input, useful for form submissions. |
| `width` | `SizeValue` | no | `` | Width of the field (number = pixels, string used as-is, e.g. "100%"). Sizes the whole field (label, control, and status) so they stay aligned. Without a width the field can shrink with its row, so a filter bar never overflows; use `<HStack wrap="wrap">` when the controls should move to a second line instead. |
| `autoComplete` | `string` | no | `` | The native autocomplete attribute, forwarded to the input unchanged. Does not affect the controlled value. |
| `containerXstyle` | `StyleXStyles` | no | `` | StyleX styles for the field container (label, control, and status together). No effect inside InputGroup (style the InputGroup instead) or in a `horizontal-labels` FormLayout. Root `xstyle`, `className`, and `style` are not accepted. |
| `containerClassName` | `string` | no | `` | Class name for the field container. Same targeting as `containerXstyle`. |
| `containerStyle` | `CSSProperties` | no | `` | Inline styles for the field container. Same targeting as `containerXstyle`. |
| `controlXstyle` | `StyleXStyles` | no | `` | StyleX styles for the visual control box: the element that paints the border and background and holds icons and end controls. Never the native input. |
| `controlClassName` | `string` | no | `` | Class name for the visual control box. |
| `controlStyle` | `CSSProperties` | no | `` | Inline styles for the visual control box. |

## Anatomy

- `Label` (required) — Text that identifies the field. Always rendered for accessibility even when visually hidden.
- `Description` (optional) — Helper text between the label and the input that provides additional context or formatting hints.
- `Start icon` (optional) — A leading icon inside the input that hints at the expected content, like a magnifying glass for search.
- `Placeholder` (optional) — Hint text shown when the input is empty. Disappears on focus.
- `Clear button` (optional) — A trailing × button that resets the value and returns focus to the input.
- `Spinner` (optional) — Loading indicator that appears during async actions like server-side validation.
- `Status icon` (optional) — A trailing icon (error, warning, or success) that communicates validation state.

## Retrieval keywords

`textinput`, `textfield`, `input`, `search`, `clearable`, `prefix`, `suffix`, `adornment`, `validation`

---

Generated from `astryx/packages/core/src/TextInput/TextInput.doc.mjs` (MIT, https://github.com/facebook/astryx). Spec: no · upstream tests: yes.

<!-- port-status:begin (generated by tools/gen-port-status.py) -->
## OCaml port

**Status:** ported in M11 — [`src/text_input.ml`](../src/text_input.ml)

**Module:** `Astryx.Text_input` (open `Astryx`)

```ocaml
val view
  :  ?type_:type_
  -> ?description:string
  -> ?is_label_hidden:bool
  -> ?is_optional:bool
  -> ?is_required:bool
  -> ?optionality:Common.Optionality.t
  -> ?is_disabled:bool
  -> ?is_read_only:bool
  -> ?placeholder:string
  -> ?start_icon:string
  -> ?status:Input_types.status
  -> ?status_variant:status_variant
  -> ?size:size
  -> ?width:Common.Size_value.t
  -> ?html_name:string
  -> ?auto_complete:string
  -> ?on_enter:unit Effect.t Bonsai.t
  -> ?attrs:Vdom.Attr.t list
  -> label:string
  -> id:string
  -> value:string Bonsai.t
  -> on_change:(string -> unit Effect.t) Bonsai.t
  -> unit
  -> Vdom.Node.t Bonsai.t
```

Call it with the same prop names and defaults the upstream contract above documents; `Divergence` comments in the source record the few places the port deliberately differs (class names, and inline styles for per-instance numeric props).

<!-- port-status:end -->
