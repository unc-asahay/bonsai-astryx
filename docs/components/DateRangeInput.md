# DateRangeInput

**Category:** Form Controls  |  **Group:** DateInput  |  **Port status:** not started

DateRangeInput lets users select a start and end date from a dual-month
calendar popover. Use it for filtering data by time period, report
generation, analytics dashboards, and booking flows.

## When to reach for it / when not to

- **Do:** Base props such as ref, id, data-*, aria-*, and DOM event handlers go to
  the range trigger, the element that is focused and announced. A DOM
  handler runs after DateRangeInput's own handler for the same event and
  still receives events it handled (including ones it called
  preventDefault on), so it cannot cancel built-in behavior.
- **Do:** Use presets for common ranges like "Last 7 days" to speed up selection.
- **Do:** Use min/max to constrain selectable dates to valid ranges.
- **Do:** Keep hasClear enabled (default) so users can reset the filter.
- **Do:** Provide clear labels and descriptions so users understand what the range
  controls.
- **Don't:** Use DateRangeInput when only a single date is needed; use DateInput
  instead.
- **Don't:** Hide the label without surrounding context that makes the purpose
  obvious.
- **Don't:** Wrap a disabled DateRangeInput in Tooltip to explain why it is disabled;
  disabled triggers swallow the hover events the wrapper needs. Use the
  disabledMessage prop instead.

## Props

| prop | type | required | default | meaning |
| --- | --- | --- | --- | --- |
| `label` | `string` | yes | `` | Label text. |
| `isLabelHidden` | `boolean` | no | `false` | Visually hide the label. |
| `description` | `string` | no | `` | Helper text displayed below the label. |
| `isOptional` | `boolean` | no | `false` | Show an "(optional)" indicator. |
| `isRequired` | `boolean` | no | `false` | Mark the field as required. |
| `isDisabled` | `boolean` | no | `false` | Disable the trigger and picker. |
| `disabledMessage` | `string` | no | `` | Explains why the input is disabled. With isDisabled, shows a tooltip on hover/keyboard focus and keeps the field focusable via aria-disabled (activation stays blocked). Use this instead of wrapping a disabled DateRangeInput in Tooltip. Disabled controls swallow the hover events an external Tooltip needs. |
| `value` | `DateRange \| null` | yes | `` | Selected date range or null. Import the `DateRange` type from `@astryxdesign/core/DateRangeInput`; it is `{start: ISODateString, end: ISODateString}`. Do NOT redeclare your own DateRange type; use the exported one so TypeScript structurally matches. |
| `onChange` | `(value: DateRange \| null) => void` | yes | `` | Callback when the range changes. Called with null on clear. |
| `changeAction` | `(value: DateRange \| null) => void \| Promise<void>` | no | `` | Async action fired after onChange. Drives optimistic UI updates via useTransition. |
| `isLoading` | `boolean` | no | `false` | Whether the input is in a loading state. Disables interaction and shows a spinner. |
| `min` | `ISODateString` | no | `` | Minimum selectable date. `ISODateString` is a template literal type (`\`${number}${number}${number}${number}-${number}${number}-${number}${number}\``). Pass a string literal like `"2026-01-28"`, not a runtime string variable. Import it from `@astryxdesign/core/Calendar` or use `as ISODateString` if computing the value dynamically. |
| `max` | `ISODateString` | no | `` | Maximum selectable date. Same template literal type as `min`: use a YYYY-MM-DD string literal or cast with `as ISODateString`. |
| `dateConstraints` | `Array<(date: Date) => boolean>` | no | `` | Custom constraint functions to disable specific dates. |
| `maxRangeSpan` | `number` | no | `` | Maximum days a selected range may span, counting both endpoints (`7` = a 7-day window, start + 6). Once a start is picked, days beyond this distance are disabled so the range cannot stretch past the cap. Rolling window relative to the start; for fixed calendar bounds use `min`/`max`. Constrains selection only; it never rewrites a `value` already wider than the cap (flag that with `status`). |
| `minRangeSpan` | `number` | no | `` | Minimum days a selected range must span, counting both endpoints (`2` forbids a single-day range). Once a start is picked, days closer than this are disabled. Clicking the start again commits a one-day range when allowed, or cancels the in-progress selection when the minimum is longer. Defaults to 1 (same-day start and end allowed). |
| `presets` | `Array<DateRangePreset>` | no | `` | Preset ranges shown as quick-select options beside the calendar. A preset is disabled when either endpoint violates min, max, or dateConstraints, or when its span violates minRangeSpan or maxRangeSpan. |
| `hasClear` | `boolean` | no | `true` | Shows a clear button when a range is selected. |
| `placeholder` | `string` | no | `'Select date range'` | Placeholder text when no range is selected. |
| `size` | `'sm' \| 'md' \| 'lg'` | no | `'md'` | Size of the trigger. |
| `status` | `{type: 'warning' \| 'error' \| 'success', message?: string}` | no | `` | Status indicator for error, warning, or success states. |
| `statusVariant` | `'attached' \| 'detached' \| 'tooltip'` | no | `'attached'` | How the status message is placed relative to the input. attached overlaps directly below the input (bordered treatment); detached floats below as a separate element with spacing; tooltip hides the message box and surfaces it in a tooltip on the status icon. |
| `labelTooltip` | `string` | no | `` | Tooltip text via info icon at label end. |
| `numberOfMonths` | `1 \| 2` | no | `2` | Number of months in the calendar. |
| `weekStartsOn` | `0 \| 1 \| 2 \| 3 \| 4 \| 5 \| 6 \| 'sun' \| 'mon' \| 'tue' \| 'wed' \| 'thu' \| 'fri' \| 'sat'` | no | `0` | First day of week in the calendar. A number (0 = Sunday to 6 = Saturday) or a three-letter day name. |
| `width` | `SizeValue` | no | `` | Width of the field (number = pixels, string used as-is, e.g. "100%"). Sizes the whole field (label, control, and status) so they stay aligned. |
| `containerXstyle` | `StyleXStyles` | no | `` | StyleX styles for the Field box around the label, control, and status. containerClassName and containerStyle take a class name and inline styles for the same box. No effect (development warning) where no Field box renders: inside InputGroup (style the group) and in a horizontal-labels FormLayout. |
| `controlXstyle` | `StyleXStyles` | no | `` | StyleX styles for the visual control box: the bordered element that holds the text, icons, and end controls, never the native input. controlClassName and controlStyle take a class name and inline styles for the same box. Replaces root xstyle, className, and style, which this component does not accept. |

## Anatomy

- `Label` (required) — Text above the trigger describing what date range is expected.
- `Field surface` (required) — Bordered control containing the calendar toggle, range trigger, and end affordances.
- `Trigger button` (required) — A button showing the formatted range or placeholder. Clicking opens the popover.
- `Calendar icon` (required) — A trailing icon that also opens the popover.
- `Calendar popover` (required) — A dual-month calendar grid with range selection and hover preview.
- `Preset sidebar` (optional) — A list of preset range options beside the calendar.
- `Preset button` (optional) — A quick-select action for one preset range, reflecting current and disabled states.
- `Clear button` (optional) — A × button that resets the range to null.
- `Status message` (optional) — An error, warning, or success message below the trigger.

## Retrieval keywords

`daterangepicker`, `daterange`, `range`, `calendar`, `filter`, `analytics`, `period`, `schedule`

---

Generated from `astryx/packages/core/src/DateRangeInput/DateRangeInput.doc.mjs` (MIT, https://github.com/facebook/astryx). Spec: yes · upstream tests: no.
