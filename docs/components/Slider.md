# Slider

**Category:** Form Controls  |  **Group:** -  |  **Port status:** not started

A draggable control for selecting a numeric value or range within defined
bounds. Supports single value and range selection, tick marks, custom value
formatting, and vertical orientation. Use it when users need to explore a
continuous range, such as volume, price, or percentage.

## When to reach for it / when not to

- **Do:** Always provide a label, even if visually hidden, so the slider is
  accessible to screen readers.
- **Do:** Format values with meaningful units like "$50" or "75%" instead of raw
  numbers.
- **Don't:** Use for precise numeric entry; pair with a text input or use NumberInput
  instead.
- **Don't:** Set a step size so large that only a few positions are possible; use
  SegmentedControl or radio buttons instead.
- **Don't:** Wrap a disabled slider in Tooltip to explain why it is disabled;
  disabled controls swallow the hover events the wrapper needs. Use the
  disabledMessage prop instead.

## Props

| prop | type | required | default | meaning |
| --- | --- | --- | --- | --- |
| `label` | `string` | yes | `` | Label text (always rendered for accessibility). |
| `value` | `number \| [number, number]` | yes | `` | Current value: a `number` for single thumb mode or `[number, number]` for range mode. |
| `onChange` | `(value: number) => void \| (value: [number, number]) => void` | no | `` | Callback fired on value change during drag. |
| `onChangeEnd` | `(value: number) => void \| (value: [number, number]) => void` | no | `` | Callback fired when drag ends. |
| `min` | `number` | no | `0` | Minimum value. |
| `max` | `number` | no | `100` | Maximum value. |
| `step` | `number` | no | `1` | Step increment. |
| `orientation` | `'horizontal' \| 'vertical'` | no | `'horizontal'` | Orientation of the slider. |
| `formatValue` | `(value: number) => string` | no | `` | Custom value formatting function used for display and `aria-valuetext`. |
| `valueDisplay` | `'tooltip' \| 'text' \| 'none'` | no | `'tooltip'` | How the current value is displayed. |
| `marks` | `Array<{ value: number; label?: string }>` | no | `` | Tick marks at specified positions with optional labels. Unfilled marks use the track color; marks inside the filled region (at or behind the thumb, or between the thumbs in range mode) use the fill color. |
| `minStepsBetweenThumbs` | `number` | no | `0` | Minimum number of steps between thumbs in range mode; prevents thumbs from overlapping. |
| `isDisabled` | `boolean` | no | `false` | Whether the slider is disabled. |
| `htmlName` | `string` | no | `` | The HTML name attribute for form submissions. Renders hidden inputs carrying the current value (two entries in range mode). |
| `disabledMessage` | `string` | no | `` | Explains why the slider is disabled. With isDisabled, shows a tooltip on hover/keyboard focus and keeps the thumb focusable via aria-disabled (value changes stay blocked). Use this instead of wrapping a disabled Slider in Tooltip. Disabled controls swallow the hover events an external Tooltip needs. |
| `isOptional` | `boolean` | no | `false` | Whether the field is optional. |
| `isRequired` | `boolean` | no | `false` | Whether the field is required. |
| `isLabelHidden` | `boolean` | no | `false` | Whether to visually hide the label. |
| `description` | `string` | no | `` | Description text rendered below the label. |
| `status` | `{type: 'warning' \| 'error' \| 'success', message?: string}` | no | `` | Status indicator object (`{ type, message }`) for validation feedback. |
| `labelTooltip` | `string` | no | `` | Tooltip text for an info icon displayed next to the label. |
| `width` | `SizeValue` | no | `` | Width of the field (number = pixels, string used as-is, e.g. "100%"). Sizes the whole field (label, control, and status) so they stay aligned. |
| `containerXstyle` | `StyleXStyles` | no | `` | StyleX styles for the field container (label, control, and status together). No effect inside InputGroup (style the InputGroup instead) or in a `horizontal-labels` FormLayout. Root `xstyle`, `className`, and `style` are not accepted. |
| `containerClassName` | `string` | no | `` | Class name for the field container. Same targeting as `containerXstyle`. |
| `containerStyle` | `CSSProperties` | no | `` | Inline styles for the field container. Same targeting as `containerXstyle`. |
| `controlXstyle` | `StyleXStyles` | no | `` | StyleX styles for the visual control box: the element that paints the border and background and holds icons and end controls. Never the native input. |
| `controlClassName` | `string` | no | `` | Class name for the visual control box. |
| `controlStyle` | `CSSProperties` | no | `` | Inline styles for the visual control box. |

## Anatomy

- `Label` (required) — Text identifying the numeric setting controlled by the slider.
- `Description` (optional) — Helper text between the label and the slider control.
- `Slider` (required) — Control row containing the track, thumb or thumbs, and optional text value.
- `Interactive control` (required) — Pointer and keyboard interaction surface containing the rail, fill, marks, and thumbs.
- `Track` (required) — Background rail representing the available numeric range.
- `Filled range` (required) — Accent segment from the minimum to a single value, or between two range values.
- `Tick mark` (optional) — Position marker supplied through the marks collection.
- `Mark label` (optional) — Optional text displayed beside a tick mark.
- `Thumb` (required) — Draggable value indicator; range mode renders a minimum and maximum thumb.
- `Value display` (optional) — Formatted current value shown beside the slider when valueDisplay is text.
- `Value tooltip` (optional) — Formatted current value shown in a tooltip when valueDisplay is tooltip.
- `Status message` (optional) — Error, warning, or success message below the slider.

## Accessibility contract

- **Thumb** — 1.4.11 Non-text Contrast, needs 3:1 in Rest, Hover, Pointer down. The thumb must have at least 3:1 contrast with the track and the surface behind it. Pointer down is the whole drag: measure the thumb with the pressed overlay applied.

## Retrieval keywords

`slider`, `range`, `slidebar`, `trackbar`, `scrubber`, `knob`, `thumb`, `rangeslider`

---

Generated from `astryx/packages/core/src/Slider/Slider.doc.mjs` (MIT, https://github.com/facebook/astryx). Spec: yes · upstream tests: yes.
