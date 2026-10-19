# TimeInput

**Category:** Form Controls  |  **Group:** -  |  **Port status:** not started

TimeInput uses a browser/OS time picker on coarse pointers by default and
Astryx's typed field on fine pointers. It converts values to a standard
format and supports arrow-key adjustment on the typed surface. Use it in
forms, scheduling flows, or any interface where users need to select a
specific time.

## When to reach for it / when not to

- **Do:** Base props such as ref, id, data-*, aria-*, and DOM event handlers go to
  the time input, the element that is focused and announced. A DOM handler
  runs after TimeInput's own handler for the same event and still receives
  events it handled (including ones it called preventDefault on), so it
  cannot cancel built-in behavior.
- **Do:** Choose the hour format (12h or 24h) that matches your audience's locale:
  12-hour with AM/PM for US-centric UIs, 24-hour for international or
  technical contexts.
- **Do:** Set min and max constraints when the context has a valid range, like
  business hours or event windows, so users cannot submit an out-of-bounds
  time.
- **Do:** Provide a description or placeholder that hints at the expected format
  or purpose, like "Business hours: 9 AM – 5 PM".
- **Do:** Use the status prop to surface validation errors inline: show a message
  like "Time must be during business hours" so users know exactly what to
  fix.
- **Do:** Enable hasClear when the field is optional, so users can remove a
  previously selected time.
- **Do:** Place TimeInput inside InputGroup when the time needs a single-line
  prefix or suffix addon, like a start/end label or timezone marker.
- **Don't:** Don't use TimeInput for combined date-and-time selection; pair it with a
  separate DateInput instead.
- **Don't:** Don't hide the label; even when space is tight, keep the label visible
  or provide a description so the purpose is clear.
- **Don't:** Wrap a disabled TimeInput in Tooltip to explain why it is disabled;
  disabled triggers swallow the hover events the wrapper needs. Use the
  disabledMessage prop instead.

## Props

| prop | type | required | default | meaning |
| --- | --- | --- | --- | --- |
| `label` | `string` | yes | `` | Label text for the input (required for accessibility). |
| `isLabelHidden` | `boolean` | no | `false` | Visually hides the label while keeping it accessible to screen readers. |
| `description` | `string` | no | `` | Description text displayed between the label and input. |
| `isOptional` | `boolean` | no | `false` | Shows an "(optional)" indicator next to the label. Mutually exclusive with isRequired. |
| `isRequired` | `boolean` | no | `false` | Marks the field as required and sets aria-required. Mutually exclusive with isOptional. |
| `isDisabled` | `boolean` | no | `false` | Disables the input and suppresses interactions. |
| `disabledMessage` | `string` | no | `` | Explains why the input is disabled. With isDisabled, shows a tooltip on hover/keyboard focus and keeps the field focusable via aria-disabled (activation stays blocked). Use this instead of wrapping a disabled TimeInput in Tooltip. Disabled controls swallow the hover events an external Tooltip needs. |
| `value` | `ISOTimeString` | no | `` | Controlled time value in ISO format (HH:MM or HH:MM:SS). |
| `onChange` | `(value: ISOTimeString \| undefined) => void` | no | `` | Callback fired when the time changes. Receives undefined when the input is cleared. |
| `changeAction` | `(value: ISOTimeString \| undefined) => void \| Promise<void>` | no | `` | Async action fired after onChange. Wrapped in a React transition to provide optimistic UI; triggers the loading spinner while pending. |
| `isLoading` | `boolean` | no | `false` | Puts the input into a loading state, displaying a spinner. |
| `min` | `ISOTimeString` | no | `` | Minimum selectable time in ISO format. Values outside the range are rejected. |
| `max` | `ISOTimeString` | no | `` | Maximum selectable time in ISO format. Values outside the range are rejected. |
| `hasSeconds` | `boolean` | no | `false` | Includes seconds in the time display and parsing. |
| `hasClear` | `boolean` | no | `false` | Shows a clear button when a value is set and the input is not disabled. |
| `hourFormat` | `'12h' \| '24h'` | no | `'12h'` | Controls the display format. '12h' shows AM/PM (e.g. '2:30 PM'); '24h' uses 24-hour notation (e.g. '14:30'). |
| `increment` | `number` | no | `1` | Number of minutes to add or subtract when the user presses the up or down arrow key. |
| `presentation` | `'text-input' \| 'popover' \| 'bottom-sheet' \| 'native' \| 'adaptive-bottom-sheet' \| 'adaptive-native'` | no | `'adaptive-native'` | Which surface selects the time. 'adaptive-native' (the default) uses Astryx's typed field on a fine pointer and the browser/OS input type=time on a coarse pointer — except hasSeconds or increment other than 1, which retain the typed field because iOS has no seconds wheel and treats step as validation rather than picker cadence; 'native' always uses the browser/OS control with no Astryx fallback; 'adaptive-bottom-sheet' uses the typed field on a fine pointer and Astryx's bottom-sheet time wheels on a coarse pointer; 'bottom-sheet' forces the wheels on every pointer; 'text-input' (like 'popover', which has no distinct TimeInput surface) keeps only the typed field. Native mode forwards min/max and enforces them on commit. hourFormat formats the closed value; the open OS picker follows the device locale. |
| `nativePicker` | `'touch' \| 'always' \| 'never'` | no | `'touch'` | Deprecated: use presentation ('touch' = 'adaptive-native', 'always' = 'native', 'never' = 'text-input'). Still works exactly as released; presentation wins when both are set. |
| `placeholder` | `string` | no | `'Select a time'` | Placeholder text shown when no time is selected. When the input is focused and empty, a format hint overrides this text. |
| `size` | `'sm' \| 'md' \| 'lg'` | no | `'md'` | Controls the height of the input element. |
| `status` | `{type: 'warning' \| 'error' \| 'success', message?: string}` | no | `` | Status indicator that colors the border and displays an icon. When a message is provided it is rendered below the input. |
| `statusVariant` | `'attached' \| 'detached' \| 'tooltip'` | no | `'attached'` | How the status message is placed relative to the input. attached overlaps directly below the input (bordered treatment); detached floats below as a separate element with spacing; tooltip hides the message box and surfaces it in a tooltip on the status icon. |
| `labelTooltip` | `string` | no | `` | Tooltip text rendered as an info icon at the end of the label row. |
| `width` | `SizeValue` | no | `` | Width of the field (number = pixels, string used as-is, e.g. "100%"). Sizes the whole field (label, control, and status) so they stay aligned. |
| `containerXstyle` | `StyleXStyles` | no | `` | StyleX styles for the Field box around the label, control, and status. containerClassName and containerStyle take a class name and inline styles for the same box. No effect (development warning) where no Field box renders: inside InputGroup (style the group) and in a horizontal-labels FormLayout. |
| `controlXstyle` | `StyleXStyles` | no | `` | StyleX styles for the visual control box: the bordered element that holds the text, icons, and end controls, never the native input. controlClassName and controlStyle take a class name and inline styles for the same box. Replaces root xstyle, className, and style, which this component does not accept. |

## Anatomy

- `Clock icon` (optional) — A leading clock icon that identifies the field and opens the browser/OS picker in native mode.
- `Time control` (required) — A real input type=time in native modes, or Astryx's editable text field for fine pointers, presentation="text-input", seconds, and custom increments.
- `Clear button` (optional) — A trailing button to reset the value, shown when hasClear is true and a value is set.
- `Status icon` (optional) — A trailing icon indicating error, warning, or success state.
- `Spinner` (optional) — Replaces trailing content during loading to show an async action is in progress.

## Retrieval keywords

`timeinput`, `timepicker`, `time`, `clock`, `hour`, `minute`, `ampm`, `timeselect`, `timefield`, `schedule`

---

Generated from `astryx/packages/core/src/TimeInput/TimeInput.doc.mjs` (MIT, https://github.com/facebook/astryx). Spec: no · upstream tests: no.

<!-- port-status:begin (generated by tools/gen-port-status.py) -->
## OCaml port

**Status:** not ported yet. The upstream contract above is the specification; see `docs/PORT-STATUS.md` for the milestone it is planned in.

<!-- port-status:end -->
