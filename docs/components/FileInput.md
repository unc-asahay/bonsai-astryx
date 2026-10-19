# FileInput

**Category:** Form Controls  |  **Group:** -  |  **Port status:** not started

FileInput provides file upload with optional drag-and-drop support. Use it
for single or multiple file selection with built-in validation for file
type, size, and count. Pair with validation status for upload feedback.

## When to reach for it / when not to

- **Do:** Always specify an accept prop to guide users toward valid file types.
- **Do:** Use maxSize and maxFiles to prevent oversized uploads; the component
  handles validation and error display automatically.
- **Do:** Add a description to communicate constraints like file size limits or
  accepted formats.
- **Do:** Use changeAction for immediate upload workflows that benefit from
  optimistic UI.
- **Don't:** Don't use FileInput for directory or folder uploads; that is not
  supported in v1.
- **Don't:** Don't avoid dropzone mode unless space is constrained; drag-and-drop is
  the expected interaction for file uploads.
- **Don't:** Don't wrap a disabled FileInput in Tooltip to explain why it's disabled;
  disabled controls swallow the hover events the wrapper needs. Use the
  disabledMessage prop instead.

## Props

| prop | type | required | default | meaning |
| --- | --- | --- | --- | --- |
| `label` | `string` | yes | `` | Accessible label for the file input. |
| `value` | `File \| File[] \| null` | yes | `` | Currently selected file(s). Controlled component. |
| `onChange` | `(files: File \| File[] \| null) => void` | yes | `` | Callback fired when files are selected or removed. |
| `changeAction` | `(files: File \| File[] \| null) => Promise<void>` | no | `` | Async change action (React 19 transitions pattern). Use for immediate upload on file selection. |
| `accept` | `string` | no | `` | Accepted file types. Uses the HTML accept attribute format (e.g. "image/*", ".pdf,.doc"). |
| `isMultiple` | `boolean` | no | `false` | Whether multiple files can be selected. When true, value and onChange use File[] instead of File. |
| `maxSize` | `number` | no | `` | Maximum file size in bytes. Files exceeding this are rejected with an error status. |
| `maxFiles` | `number` | no | `` | Maximum number of files (only applies when isMultiple is true). |
| `isLabelHidden` | `boolean` | no | `false` | Visually hides the label while keeping it accessible to screen readers. |
| `description` | `string` | no | `` | Description text displayed between the label and input. |
| `isOptional` | `boolean` | no | `false` | Displays an "Optional" indicator next to the label. Mutually exclusive with isRequired. |
| `isRequired` | `boolean` | no | `false` | Displays a "Required" indicator next to the label and adds a screen-reader-only "Required" description to the trigger (assistive tech does not reliably announce aria-required on the trigger). Mutually exclusive with isOptional. |
| `isDisabled` | `boolean` | no | `false` | Disables the input, preventing interaction and dimming the element. |
| `disabledMessage` | `string` | no | `` | Explains why the input is disabled. With isDisabled, shows a tooltip on hover/keyboard focus and keeps the trigger focusable via aria-disabled (opening the file picker stays blocked). Use this instead of wrapping a disabled FileInput in Tooltip; disabled controls swallow the hover events an external Tooltip needs. |
| `isLoading` | `boolean` | no | `false` | Puts the input in a loading state, showing a spinner and setting aria-busy. |
| `placeholder` | `string` | no | `"Choose file" or "Choose files"` | Placeholder text shown when no file is selected. |
| `mode` | `'input' \| 'dropzone'` | no | `'input'` | Visual mode. 'input' is a compact inline style; 'dropzone' is a larger area with drag-and-drop support. |
| `status` | `{type: 'error' \| 'warning' \| 'success', message?: string}` | no | `` | Validation status: applies a colored border. If message is provided, displays a floating message below the input. Error type also sets aria-invalid. |
| `statusVariant` | `'attached' \| 'detached' \| 'tooltip'` | no | `'attached'` | How the status message is placed relative to the input. attached overlaps directly below the input (bordered treatment); detached floats below as a separate element with spacing; tooltip hides the message box and surfaces it in a tooltip on the status icon. |
| `labelTooltip` | `string` | no | `` | Tooltip text displayed in an info icon at the end of the label. |
| `width` | `SizeValue` | no | `` | Width of the field (number = pixels, string used as-is, e.g. "100%"). Sizes the whole field (label, control, and status) so they stay aligned. |
| `containerXstyle` | `StyleXStyles` | no | `` | StyleX styles for the field container (label, control, and status together). No effect inside InputGroup (style the InputGroup instead) or in a `horizontal-labels` FormLayout. Root `xstyle`, `className`, and `style` are not accepted. |
| `containerClassName` | `string` | no | `` | Class name for the field container. Same targeting as `containerXstyle`. |
| `containerStyle` | `CSSProperties` | no | `` | Inline styles for the field container. Same targeting as `containerXstyle`. |
| `controlXstyle` | `StyleXStyles` | no | `` | StyleX styles for the visual control box: the element that paints the border and background and holds icons and end controls. Never the native input. |
| `controlClassName` | `string` | no | `` | Class name for the visual control box. |
| `controlStyle` | `CSSProperties` | no | `` | Inline styles for the visual control box. |

## Anatomy

- `Label` (required) — Text that identifies the field. Always rendered for accessibility even when visually hidden.
- `Description` (optional) — Helper text between the label and the drop zone explaining accepted formats or size limits.
- `Drop zone` (required) — The clickable area for file selection. In dropzone mode, also accepts dragged files.
- `Upload icon` (optional) — An upload-to-tray icon in the drop zone hinting at the upload action.
- `Placeholder` (optional) — Hint text shown when no files are selected.
- `File name display` (optional) — Shows the name(s) of selected files.
- `Clear button` (optional) — A close button that removes selected files and returns focus to the input.
- `Spinner` (optional) — Loading indicator that appears during async upload actions.
- `Status message` (optional) — Validation feedback showing error, warning, or success with a message.

## Retrieval keywords

`fileinput`, `file`, `upload`, `drag`, `drop`, `dropzone`, `attachment`, `browse`

---

Generated from `astryx/packages/core/src/FileInput/FileInput.doc.mjs` (MIT, https://github.com/facebook/astryx). Spec: yes · upstream tests: no.
