# TextArea

**Category:** Form Controls  |  **Group:** -  |  **Port status:** not started

TextArea is a multi-line text input for collecting longer-form content like
comments, descriptions, or messages. Use it when the expected input spans
multiple lines. For shorter, single-line values, use TextInput.

## When to reach for it / when not to

- **Do:** Provide a visible label so users know what to enter. If the label must
  be hidden, set isLabelHidden with a descriptive label for screen
  readers.
- **Do:** Set maxLength with a character counter when there is a defined limit; it
  helps users stay within bounds before they submit.
- **Do:** Use the status prop to surface validation feedback inline: show success
  when input is valid, warning for soft limits, and error for hard
  failures.
- **Do:** Add a description or placeholder to clarify expected content, like
  "Describe the issue in detail," but never rely on placeholder alone as
  the only label.
- **Don't:** Avoid using TextArea for short, single-line values like names or emails;
  use TextInput instead.
- **Don't:** Don't rely solely on placeholder text to communicate the purpose of the
  field; placeholders disappear on focus and are not accessible labels.
- **Don't:** Don't show a status message without also setting the status type; the
  colored border and icon are what draw the user's attention to the
  message.
- **Don't:** Don't wrap a disabled TextArea in Tooltip to explain why it's disabled;
  disabled controls swallow the hover events the wrapper needs. Use the
  disabledMessage prop instead.

## Props

| prop | type | required | default | meaning |
| --- | --- | --- | --- | --- |
| `ref` | `React.Ref<HTMLTextAreaElement>` | no | `` | Ref forwarded to the underlying <textarea> element. |
| `label` | `string` | yes | `` | Label text for the textarea. Always rendered for accessibility. |
| `value` | `string` | yes | `` | Current value of the textarea. |
| `onChange` | `(value: string, e: ChangeEvent<HTMLTextAreaElement>) => void` | no | `` | Callback fired when the textarea value changes. |
| `changeAction` | `(value: string, e: ChangeEvent<HTMLTextAreaElement>) => void \| Promise<void>` | no | `` | Async action fired after onChange inside a React transition. Enables optimistic updates via useOptimistic. |
| `isLabelHidden` | `boolean` | no | `false` | Visually hides the label while keeping it accessible to screen readers. |
| `description` | `string` | no | `` | Helper text displayed between the label and textarea. |
| `isOptional` | `boolean` | no | `false` | Displays an "Optional" indicator next to the label. Mutually exclusive with isRequired. |
| `isRequired` | `boolean` | no | `false` | Displays a "Required" indicator next to the label and sets aria-required. Mutually exclusive with isOptional. |
| `isDisabled` | `boolean` | no | `false` | Disables the textarea, preventing interaction. |
| `isReadOnly` | `boolean` | no | `false` | Makes the textarea read-only: the value is shown at full opacity and still submits with the form, but cannot be edited. Unlike isDisabled, a read-only textarea is not dimmed and stays in the tab order. isDisabled takes precedence when both are set. |
| `disabledMessage` | `string` | no | `` | Explains why the textarea is disabled. With isDisabled, shows a tooltip on hover/keyboard focus and keeps the textarea focusable via aria-disabled (the field becomes read-only). Use this instead of wrapping a disabled TextArea in Tooltip. Disabled controls swallow the hover events an external Tooltip needs. |
| `isLoading` | `boolean` | no | `false` | Puts the textarea in a loading state, showing a spinner inside the input. |
| `placeholder` | `string` | no | `` | Placeholder text shown when the textarea is empty. |
| `rows` | `number` | no | `3` | Number of visible text rows. |
| `maxLength` | `number` | no | `` | Maximum number of characters allowed, counted as user-perceived characters: an emoji or flag sequence counts as one. When set, a character counter (current/max) is displayed inside the input container, anchored to the bottom-right beneath the text. Does not enforce the limit natively; when exceeded the counter turns red and shows a warning icon (a non-color cue), and screen-reader users hear the remaining/over-limit count announced. Consumers validating the limit should count with characterCount (exported from the package) so enforcement matches the displayed count. |
| `status` | `{ type: 'warning' \| 'error' \| 'success'; message?: string }` | no | `` | Status indicator that applies a colored border and icon. An optional message is displayed in a floating box below the textarea. |
| `statusVariant` | `'attached' \| 'detached' \| 'tooltip'` | no | `'attached'` | How the status message is placed relative to the input. attached overlaps directly below the input (bordered treatment); detached floats below as a separate element with spacing; tooltip hides the message box and surfaces it in a tooltip on the status icon. |
| `labelTooltip` | `string` | no | `` | Tooltip text displayed in an info icon at the end of the label. |
| `startIcon` | `IconType` | no | `` | Icon component rendered inside the leading edge of the textarea wrapper. See `astryx docs icons` for valid semantic names. |
| `hasSpellCheck` | `boolean` | no | `true` | Enables or disables browser spell checking. |
| `hasAutoFocus` | `boolean` | no | `false` | Automatically focuses the textarea on mount. |
| `size` | `'sm' \| 'md' \| 'lg'` | no | `'md'` | Size of the textarea, affecting internal padding. Height is controlled by rows, not size. |
| `onPaste` | `(e: ClipboardEvent<HTMLTextAreaElement>) => void` | no | `` | Callback fired when content is pasted into the textarea. |
| `htmlName` | `string` | no | `` | HTML name attribute for the textarea element, useful for form submissions. |
| `width` | `SizeValue` | no | `` | Width of the field (number = pixels, string used as-is, e.g. "100%"). Sizes the whole field (label, control, and status) so they stay aligned. |
| `onFocus` | `(e: FocusEvent<HTMLTextAreaElement>) => void` | no | `` | Callback fired when the textarea receives focus. |
| `onBlur` | `(e: FocusEvent<HTMLTextAreaElement>) => void` | no | `` | Callback fired when the textarea loses focus. |
| `autoComplete` | `string` | no | `` | The native autocomplete attribute, forwarded to the textarea unchanged. Does not affect the controlled value. |
| `containerXstyle` | `StyleXStyles` | no | `` | StyleX styles for the field container (label, control, and status together). No effect inside InputGroup (style the InputGroup instead) or in a `horizontal-labels` FormLayout. Root `xstyle`, `className`, and `style` are not accepted. |
| `containerClassName` | `string` | no | `` | Class name for the field container. Same targeting as `containerXstyle`. |
| `containerStyle` | `CSSProperties` | no | `` | Inline styles for the field container. Same targeting as `containerXstyle`. |
| `controlXstyle` | `StyleXStyles` | no | `` | StyleX styles for the visual control box: the element that paints the border and background and holds icons and end controls. Never the native input. |
| `controlClassName` | `string` | no | `` | Class name for the visual control box. |
| `controlStyle` | `CSSProperties` | no | `` | Inline styles for the visual control box. |

## Anatomy

- `Label` (required) — Text identifying the multi-line field.
- `Description` (optional) — Helper text between the label and the input.
- `Input container` (required) — Painted boundary containing the text area and its overlays.
- `Text area` (required) — Multi-line control that displays and edits the value.
- `Placeholder` (optional) — Hint text shown inside the empty text area.
- `Start icon` (optional) — Astryx Icon rendered at the start when startIcon is a semantic name or icon component.
- `Custom start content` (optional) — Caller-provided ReactNode rendered at the start instead of an Astryx Icon.
- `Spinner` (optional) — Loading indicator shown at the end of the input container.
- `Status icon` (optional) — Error, warning, or success icon shown inside the input.
- `Character counter` (optional) — Current and maximum character counts shown inside the input container.
- `Field status message` (optional) — Attached or detached error, warning, or success message associated with the field.
- `Tooltip status message` (optional) — Tooltip surface presenting the status message for the tooltip variant.

## Retrieval keywords

`textarea`, `textfield`, `multiline`, `comment`, `message`, `autoresize`, `autosize`, `charlimit`

---

Generated from `astryx/packages/core/src/TextArea/TextArea.doc.mjs` (MIT, https://github.com/facebook/astryx). Spec: yes · upstream tests: no.

<!-- port-status:begin (generated by tools/gen-port-status.py) -->
## OCaml port

**Status:** ported in M12 — [`src/text_area.ml`](../src/text_area.ml)

**Module:** `Astryx.Text_area` (open `Astryx`)

```ocaml
val view
  :  ?description:string
  -> ?is_label_hidden:bool
  -> ?is_optional:bool
  -> ?is_required:bool
  -> ?is_disabled:bool
  -> ?is_read_only:bool
  -> ?placeholder:string
  -> ?status:Input_types.status
  -> ?status_variant:status_variant
  -> ?size:size
  -> ?width:Common.Size_value.t
  -> ?html_name:string
  -> ?auto_complete:string
  -> ?rows:int
  -> ?has_spell_check:bool
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
