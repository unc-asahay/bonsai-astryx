# DateInput

**Category:** Form Controls  |  **Group:** DateInput  |  **Port status:** not started

DateInput lets the user type or pick a date from a calendar popover. Use it
for scheduling, deadlines, booking dates, or any form field that needs a
specific calendar date.

## When to reach for it / when not to

- **Do:** Base props such as ref, id, data-*, aria-*, and DOM event handlers go to
  the date input, the element that is focused and announced. A DOM handler
  runs after DateInput's own handler for the same event and still receives
  events it handled (including ones it called preventDefault on), so it
  cannot cancel built-in behavior.
- **Do:** Provide clear labels and descriptions so users understand what date is
  expected.
- **Do:** Use min, max, and dateConstraints to restrict selectable dates to valid
  ranges.
- **Do:** Use hasClear when the date is optional so the user can reset it.
- **Do:** Show a loading state with changeAction when the date triggers a
  server-side save.
- **Do:** Use DateInput inside InputGroup when adding a short static prefix or
  suffix, such as a due-date hint.
- **Don't:** Use a DateInput for free-form text that does not represent a calendar
  date.
- **Don't:** Hide the label without surrounding context that makes the field purpose
  obvious.
- **Don't:** Rely on the calendar alone; the text input lets users type dates
  directly, which is faster for known dates.
- **Don't:** Wrap a disabled DateInput in Tooltip to explain why it is disabled;
  disabled triggers swallow the hover events the wrapper needs. Use the
  disabledMessage prop instead.

## Props

| prop | type | required | default | meaning |
| --- | --- | --- | --- | --- |
| `label` | `string` | yes | `` | Label text. |
| `isLabelHidden` | `boolean` | no | `false` | Visually hide the label. |
| `description` | `string` | no | `` | Helper text displayed below the label. |
| `isOptional` | `boolean` | no | `false` | Show an "(optional)" indicator next to the label. |
| `isRequired` | `boolean` | no | `false` | Mark the field as required. |
| `isDisabled` | `boolean` | no | `false` | Disable the input and calendar. |
| `disabledMessage` | `string` | no | `` | Explains why the input is disabled. With isDisabled, shows a tooltip on hover/keyboard focus and keeps the field focusable via aria-disabled (activation stays blocked). Use this instead of wrapping a disabled DateInput in Tooltip. Disabled controls swallow the hover events an external Tooltip needs. |
| `value` | `ISODateString` | no | `` | Selected date in YYYY-MM-DD format. |
| `onChange` | `(value: ISODateString \| undefined) => void` | no | `` | Callback invoked when the selected date changes. |
| `changeAction` | `(value: ISODateString \| undefined) => void \| Promise<void>` | no | `` | Async action fired after onChange. Drives optimistic UI updates via useTransition. |
| `isLoading` | `boolean` | no | `false` | Whether the input is in a loading state. Disables interaction and shows a spinner. |
| `min` | `ISODateString` | no | `` | Minimum selectable date (YYYY-MM-DD). |
| `max` | `ISODateString` | no | `` | Maximum selectable date (YYYY-MM-DD). |
| `dateConstraints` | `ReadonlyArray<(date: Date) => boolean>` | no | `` | Array of custom constraint functions that disable specific dates. |
| `placeholder` | `string` | no | `'Select a date'` | Placeholder text shown in the text input. |
| `size` | `'sm' \| 'md' \| 'lg'` | no | `'md'` | Size of the input control. |
| `status` | `{type: 'warning' \| 'error' \| 'success', message?: string}` | no | `` | Status indicator object for error, warning, or success states with a message. |
| `statusVariant` | `'attached' \| 'detached' \| 'tooltip'` | no | `'attached'` | How the status message is placed relative to the input. attached overlaps directly below the input (bordered treatment); detached floats below as a separate element with spacing; tooltip hides the message box and surfaces it in a tooltip on the status icon. |
| `labelTooltip` | `string` | no | `` | Tooltip text displayed via an info icon at the end of the label. |
| `hasClear` | `boolean` | no | `false` | Shows a clear (×) button when a date value is set. Clicking it clears the value and returns focus to the input. |
| `numberOfMonths` | `1 \| 2` | no | `1` | Number of months displayed simultaneously in the calendar popover. |
| `weekStartsOn` | `0 \| 1 \| 2 \| 3 \| 4 \| 5 \| 6 \| 'sun' \| 'mon' \| 'tue' \| 'wed' \| 'thu' \| 'fri' \| 'sat'` | no | `0` | First day of week in Astryx calendar surfaces. A number (0 = Sunday to 6 = Saturday) or a three-letter day name; native pickers remain browser/OS-owned. |
| `format` | `'date' \| 'date_long' \| 'date_weekday' \| 'system_date' \| ((value: ISODateString) => string)` | no | `'date_long'` | How the committed date value is displayed. Named values are reused from Timestamp's format vocabulary: 'date' shows 'Mar 21, 2026', 'date_long' shows 'March 21, 2026', 'date_weekday' shows 'Wed, Mar 21, 2026', 'system_date' shows '2026-03-21'. A function receives the ISO value and returns a custom string. Applies only to the committed value, never to text being typed. |
| `presentation` | `'popover' \| 'bottom-sheet' \| 'native' \| 'adaptive-bottom-sheet' \| 'adaptive-native'` | no | `'adaptive-native'` | Which surface draws the date picker. 'adaptive-native' (the default) uses Astryx's calendar popover on a fine pointer and the browser/OS picker (input type=date) on a coarse pointer, keeping Astryx fallbacks where a native control cannot express the value; 'native' always uses the browser/OS picker with no fallback; 'adaptive-bottom-sheet' uses the popover on a fine pointer and Astryx's bottom-sheet picker on a coarse pointer; 'popover' and 'bottom-sheet' force that Astryx surface on every pointer. Every value opens a picker; a typed-only field is TimeInput's alone. Use a non-native presentation for a field that needs weekStartsOn, numberOfMonths or dateConstraints, none of which a native picker can express. |
| `nativePicker` | `'touch' \| 'always' \| 'never'` | no | `'touch'` | Deprecated: use presentation ('touch' = 'adaptive-native', 'always' = 'native', 'never' = 'adaptive-bottom-sheet'). Still works exactly as released; presentation wins when both are set. |
| `width` | `SizeValue` | no | `` | Width of the field (number = pixels, string used as-is, e.g. "100%"). Sizes the whole field (label, control, and status) so they stay aligned. |
| `containerXstyle` | `StyleXStyles` | no | `` | StyleX styles for the Field box around the label, control, and status. containerClassName and containerStyle take a class name and inline styles for the same box. No effect (development warning) where no Field box renders: inside InputGroup (style the group) and in a horizontal-labels FormLayout. |
| `containerClassName` | `string` | no | `` | Class name for the Field box. Same targeting as containerXstyle. |
| `containerStyle` | `CSSProperties` | no | `` | Inline styles for the Field box. Same targeting as containerXstyle. |
| `controlXstyle` | `StyleXStyles` | no | `` | StyleX styles for the visual control box: the bordered element that holds the text, icons, and end controls, never the native input. controlClassName and controlStyle take a class name and inline styles for the same box. Replaces root xstyle, className, and style, which this component does not accept. |
| `controlClassName` | `string` | no | `` | Class name for the visual control box. Same targeting as controlXstyle. |
| `controlStyle` | `CSSProperties` | no | `` | Inline styles for the visual control box. Same targeting as controlXstyle. |

## Anatomy

- `Label` (required) — Text above the input describing what date is expected.
- `Text input` (required) — A field where the user can type a date directly. Parses common formats like MM/DD/YYYY.
- `Calendar icon` (required) — A button that opens the calendar popover for visual date picking.
- `Calendar popover` (optional) — A month grid that appears when the icon is clicked or the input is focused.
- `Clear button` (optional) — A × button that resets the date value. Shown when hasClear is true and a date is set.
- `Status message` (optional) — An error, warning, or success message below the input.

## Retrieval keywords

`dateinput`, `datepicker`, `datefield`, `calendar`, `dateselect`, `dateentry`, `datechooser`

---

Generated from `astryx/packages/core/src/DateInput/DateInput.doc.mjs` (MIT, https://github.com/facebook/astryx). Spec: yes · upstream tests: no.
