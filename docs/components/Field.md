# Field

**Category:** Form Controls  |  **Group:** Field  |  **Port status:** not started

Field is a low-level wrapper for custom, native, or third-party controls
that do not already provide field label, description, and status UI. Use it
when you need the Field shell around a control you own; use styled Astryx
inputs like TextInput, Typeahead, and Select directly when they already
expose label, description, and validation props.

## When to reach for it / when not to

- **Do:** Wrap custom controls, native inputs, or third-party widgets that need
  labeling, helper text, optional/required indicators, or validation
  status.
- **Do:** Always provide a label for accessibility, even if visually hidden with
  isLabelHidden.
- **Do:** Use inputID and descriptionID to connect the label and description to
  the inner control with htmlFor and aria-describedby.
- **Don't:** Nest Field around styled inputs such as TextInput, Typeahead, Select,
  DateInput, or TextArea; those components already render their own Field
  shell.
- **Don't:** Use the attached status variant on non-bordered controls such as
  sliders, switches, or checkboxes; use detached so the message does not
  overlap the control.
- **Don't:** Set both isOptional and isRequired on the same field.
- **Don't:** Hide the label without providing an alternative way for the user to
  understand the field purpose.

## Props

| prop | type | required | default | meaning |
| --- | --- | --- | --- | --- |
| `label` | `string` | yes | `` | Label text for the field (always rendered for accessibility). |
| `inputID` | `string` | yes | `` | ID for the input element (used for the label htmlFor attribute). |
| `labelID` | `string` | no | `` | ID applied to the label element itself for group accessibility. |
| `isGroupLabel` | `boolean` | no | `false` | Renders the label as a span for control groups (radiogroup, checkbox list). |
| `children` | `ReactNode` | yes | `` | The input or control to render. |
| `isLabelHidden` | `boolean` | no | `false` | Visually hide the label (still accessible to screen readers). |
| `isDisabled` | `boolean` | no | `false` | Whether the associated input is disabled. Propagates disabled styling to the label. |
| `description` | `string` | no | `` | Description text displayed between the label and input. |
| `descriptionID` | `string` | no | `` | ID for the description element (use for aria-describedby on the input). |
| `isOptional` | `boolean` | no | `false` | Whether the field is optional (mutually exclusive with isRequired). |
| `isRequired` | `boolean` | no | `false` | Whether the field is required (mutually exclusive with isOptional). |
| `labelIcon` | `IconType` | no | `` | Icon to display before the label text. See `astryx docs icons` for valid semantic names. |
| `labelTooltip` | `string` | no | `` | Tooltip text to display in an info icon at the end of the label. |
| `status` | `{type: 'warning' \| 'error' \| 'success', message?: string, messageID?: string}` | no | `` | Status indicator with type and optional message. When message is set, displays a colored status box. messageID is for wiring aria-describedby on the input. |
| `statusVariant` | `'attached' \| 'detached'` | no | `'attached'` | How the status message renders relative to the input. Attached overlaps the input border; detached floats below. |
| `width` | `SizeValue` | no | `` | Width of the field (number = pixels, string used as-is, e.g. "100%"). Sizes the whole field (label, control, and status) so they stay aligned. Prefer this over setting width via xstyle/className/style, which only size the inner control box. Without a width, a row can shrink the whole field below the natural width of its control, so filter bars shrink instead of overflowing. |
| `ref` | `React.Ref<HTMLDivElement>` | no | `` | Ref forwarded to the root element. |
| `xstyle` | `StyleXStyles` | no | `` | StyleX styles for layout customization (margins, positioning, sizing). Must be a stylex.create() value: not an inline style object like style={{}}. |
| `className` | `string` | no | `` | CSS class name(s) appended to the root element. Prefer xstyle for StyleX deduplication. |
| `style` | `React.CSSProperties` | no | `` | Inline styles applied to the root element. Takes priority over StyleX inline styles. |

## Anatomy

- `Label` (required) — Text identifying the field. Always rendered for accessibility, optionally hidden visually.
- `Description` (optional) — Helper text between the label and input explaining what to enter.
- `Control slot` (required) — A custom, native, or third-party control that does not already render a field shell.
- `Status message` (optional) — Inline validation feedback showing error, warning, or success with a message.
- `Optional/Required indicator` (optional) — Badge next to the label showing whether the field is optional or required.
- `Label tooltip` (optional) — Info icon at the end of the label with a tooltip explaining the field.

## Retrieval keywords

`field`, `formfield`, `formgroup`, `formcontrol`, `label`, `input`, `required`, `optional`, `helpertext`, `hint`

---

Generated from `astryx/packages/core/src/Field/Field.doc.mjs` (MIT, https://github.com/facebook/astryx). Spec: no · upstream tests: no.

<!-- port-status:begin (generated by tools/gen-port-status.py) -->
## OCaml port

**Status:** ported in M11 — [`src/field.ml`](../src/field.ml)

**Module:** `Astryx.Field` (open `Astryx`)

```ocaml
val view
  :  ?is_label_hidden:bool
  -> ?description:string
  -> ?is_optional:bool
  -> ?is_required:bool
  -> ?is_disabled:bool
  -> ?label_icon:string
  -> ?status:Input_types.status
  -> ?status_variant:status_variant
  -> ?width:width
  -> ?label_id:string
  -> ?is_group_label:bool
  -> ?attrs:Vdom.Attr.t list
  -> label:string
  -> input_id:string
  -> children:Vdom.Node.t list
  -> unit
  -> Vdom.Node.t
```

Call it with the same prop names and defaults the upstream contract above documents; `Divergence` comments in the source record the few places the port deliberately differs (class names, and inline styles for per-instance numeric props).

<!-- port-status:end -->
