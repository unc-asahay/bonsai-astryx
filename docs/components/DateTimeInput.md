# DateTimeInput

**Category:** Form Controls  |  **Group:** DateInput  |  **Port status:** not started

DateTimeInput combines date and time selection in one field. With
presentation="adaptive-native" (the default), mouse/trackpad devices use
Astryx typed fields and popovers, while coarse-pointer devices use
browser/OS date and time controls in the same two-segment field.
presentation="native" uses both native controls on every pointer;
presentation="adaptive-bottom-sheet" keeps Astryx's own surfaces — pointer
fields on fine pointers and the coordinated Date/Time bottom sheet on coarse
pointers; "popover" and "bottom-sheet" force one Astryx surface on every
pointer. The closed segments stay side by side when at least 400px is
available and wrap into full-width rows below 400px, independent of viewport
width. Use it for scheduling, event creation, deadline setting, or any form
field that needs a specific datetime.

## When to reach for it / when not to

- **Do:** Base props such as ref, id, data-*, aria-*, and DOM event handlers go to
  the date input, the element that is focused and announced. A DOM handler
  runs after DateTimeInput's own handler for the same event and still
  receives events it handled (including ones it called preventDefault on),
  so it cannot cancel built-in behavior.
- **Do:** Provide clear labels and descriptions so users understand what datetime
  is expected.
- **Do:** Use min and max to restrict selectable datetimes to valid ranges.
- **Do:** Use hasClear when the datetime is optional so the user can reset it.
- **Do:** Choose the hour format (12h or 24h) that matches your audience's locale.
- **Don't:** Use DateTimeInput when only a date is needed; use DateInput instead.
- **Don't:** Use DateTimeInput when only a time is needed; use TimeInput instead.
- **Don't:** Hide the label without surrounding context that makes the field purpose
  obvious.
- **Don't:** Wrap a disabled DateTimeInput in Tooltip to explain why it is disabled;
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
| `isDisabled` | `boolean` | no | `false` | Disable the input and picker. |
| `disabledMessage` | `string` | no | `` | Explains why the input is disabled. With isDisabled, shows a tooltip on hover/keyboard focus and keeps the field focusable via aria-disabled (activation stays blocked). Use this instead of wrapping a disabled DateTimeInput in Tooltip. Disabled controls swallow the hover events an external Tooltip needs. |
| `value` | `ISODateTimeString` | no | `` | Selected datetime in ISO 8601 format (YYYY-MM-DDTHH:MM or YYYY-MM-DDTHH:MM:SS). |
| `onChange` | `(value: ISODateTimeString \| undefined) => void` | yes | `` | Callback invoked when the selected datetime changes. |
| `changeAction` | `(value: ISODateTimeString \| undefined) => void \| Promise<void>` | no | `` | Async action fired after onChange. Drives optimistic UI updates via useTransition. |
| `isLoading` | `boolean` | no | `false` | Whether the input is in a loading state. Disables interaction and shows a spinner. |
| `min` | `ISODateTimeString` | no | `` | Minimum selectable datetime. Constrains both date and time selection. |
| `max` | `ISODateTimeString` | no | `` | Maximum selectable datetime. Constrains both date and time selection. |
| `dateConstraints` | `Array<(date: Date) => boolean>` | no | `` | Array of custom constraint functions that disable specific dates. |
| `hasSeconds` | `boolean` | no | `false` | Include seconds in the time portion. Keeps Astryx's time field even when nativePicker selects native surfaces, because iOS has no seconds wheel. |
| `hourFormat` | `'12h' \| '24h'` | no | `'12h'` | Hour display format. '12h' shows AM/PM; '24h' uses 24-hour notation. |
| `timeIncrement` | `1 \| 5 \| 10 \| 15 \| 30` | no | `1` | Minute step for arrow keys in Astryx's typed time field. A non-default value keeps the Astryx time field in nativePicker modes because iOS treats native step as validation, not picker cadence. Ignored by the Astryx touch sheet, which uses wheels. |
| `timeOptionInterval` | `5 \| 10 \| 15 \| 30 \| 60` | no | `` | Minute cadence for the preset-time combobox on Astryx's fine-pointer time field. Setting it keeps that Astryx time field even in nativePicker modes because the OS picker has no equivalent preset list. The Astryx touch sheet uses wheels. |
| `hasClear` | `boolean` | no | `false` | Shows a clear button when a datetime value is set. |
| `placeholder` | `string` | no | `'Select a date'` | Placeholder text shown in the date portion when no date is selected. |
| `timePlaceholder` | `string` | no | `'Select a time'` | Placeholder text shown in the time portion when no time is selected. On touch, this appears in the closed time segment before a time is chosen. |
| `timeLabel` | `string` | no | `` | Accessible label for the time portion. Defaults to "{label} time" so it is tied to the field label and localizable. |
| `size` | `'sm' \| 'md' \| 'lg'` | no | `'md'` | Size of the input control. |
| `status` | `{type: 'warning' \| 'error' \| 'success', message?: string}` | no | `` | Status indicator object for error, warning, or success states with a message. |
| `labelTooltip` | `string` | no | `` | Tooltip text displayed via an info icon at the end of the label. |
| `numberOfMonths` | `1 \| 2` | no | `1` | Number of months displayed simultaneously in Astryx's pointer calendar popover. Ignored by native date controls and the mobile touch sheet, whose Date panel always shows one swipe-paged month at a time. |
| `weekStartsOn` | `0 \| 1 \| 2 \| 3 \| 4 \| 5 \| 6 \| 'sun' \| 'mon' \| 'tue' \| 'wed' \| 'thu' \| 'fri' \| 'sat'` | no | `0` | First day of week in Astryx calendars. A number (0 = Sunday to 6 = Saturday) or a three-letter day name. Ignored by native date controls. |
| `presentation` | `'popover' \| 'bottom-sheet' \| 'native' \| 'adaptive-bottom-sheet' \| 'adaptive-native'` | no | `'adaptive-native'` | Which surfaces draw the date and time pickers. 'adaptive-native' (the default) uses Astryx's typed fields and popovers on a fine pointer and browser/OS controls on a coarse pointer — with per-segment Astryx fallbacks: hasSeconds, non-default timeIncrement, or timeOptionInterval retain Astryx's time field because iOS cannot express them faithfully; 'native' always uses both browser/OS controls with no fallback; 'adaptive-bottom-sheet' uses popovers on a fine pointer and Astryx's coordinated bottom sheet on a coarse pointer; 'popover' and 'bottom-sheet' force that Astryx surface on every pointer. Every value opens pickers; typed-only fields are TimeInput's alone. Use a non-native presentation when numberOfMonths, weekStartsOn, or visible dateConstraints behavior matters. Constraints are enforced on commit; min/max are forwarded as hints. hourFormat formats the closed time, while the OS picker follows the user's locale. |
| `nativePicker` | `'touch' \| 'always' \| 'never'` | no | `'touch'` | Deprecated: use presentation ('touch' = 'adaptive-native', 'always' = 'native', 'never' = 'adaptive-bottom-sheet'). Still works exactly as released; presentation wins when both are set. |
| `width` | `SizeValue` | no | `` | Width of the field (number = pixels, string used as-is, e.g. "100%"). Sizes the whole field (label, control, and status) so they stay aligned. |
| `containerXstyle` | `StyleXStyles` | no | `` | StyleX styles for the Field box around the label, control, and status. containerClassName and containerStyle take a class name and inline styles for the same box. No effect (development warning) where no Field box renders: inside InputGroup (style the group) and in a horizontal-labels FormLayout. |
| `controlXstyle` | `StyleXStyles` | no | `` | StyleX styles for the visual control box: the row that holds the bordered date and time segments with their icons and end controls, never a native input. controlClassName and controlStyle take a class name and inline styles for the same box. Replaces root xstyle, className, and style, which this component does not accept. |

## Anatomy

- `Label` (required) — Text above the input describing what datetime is expected.
- `Segment row` (required) — The unbordered layout row that holds the two bordered segments and wraps them when its container is narrow.
- `Date input` (required) — A typed date field with calendar popover on the fine-pointer Astryx surface, a real input type=date in native modes, or a read-only segment opening the Astryx touch sheet under presentation="adaptive-bottom-sheet" on a coarse pointer.
- `Calendar icon` (required) — A button that opens the active date surface: the platform picker, Astryx calendar popover, or Astryx touch sheet.
- `Date picker` (optional) — The browser/OS picker in native modes, an Astryx month-grid popover on a fine pointer, or the Date panel of the Astryx bottom sheet on a coarse pointer with presentation="adaptive-bottom-sheet".
- `Time input` (required) — A real input type=time for the default minute-precision native mode, a text/combobox time field when seconds, custom increments, or preset options are requested, or a read-only segment opening accessible time wheels under presentation="adaptive-bottom-sheet" on a coarse pointer.
- `Clock icon` (required) — The time glyph shown as a leading identifier on the Astryx pointer field and as the picker affordance in native and touch-sheet time segments.
- `Time options popover` (optional) — A list of preset times at the timeOptionInterval cadence. Setting the prop retains Astryx's text/combobox time field even when nativePicker otherwise selects native controls; the Astryx touch sheet uses wheels instead.
- `Time option` (optional) — One selectable preset time in the optional time-options popover.
- `Clear button` (optional) — A × button that resets the datetime value.
- `Status message` (optional) — An error, warning, or success message below the inputs.

## Retrieval keywords

`datetimepicker`, `datetime`, `datepicker`, `timepicker`, `calendar`, `schedule`, `event`, `deadline`, `timestamp`

---

Generated from `astryx/packages/core/src/DateTimeInput/DateTimeInput.doc.mjs` (MIT, https://github.com/facebook/astryx). Spec: yes · upstream tests: no.

<!-- port-status:begin (generated by tools/gen-port-status.py) -->
## OCaml port

**Status:** ported in M80 — [`src/date_time_input.ml`](../src/date_time_input.ml)

**Module:** `Astryx.date_time_input` (open `Astryx`)

```ocaml
val view
  :  ?id:string
  -> ?attrs:Vdom.Attr.t list
  -> label:string
  -> ?is_label_hidden:bool
  -> ?description:string
  -> ?is_optional:bool
  -> ?is_required:bool
  -> ?is_disabled:bool
  -> ?disabled_message:string
  -> ?value:date_time option Bonsai.t
  -> ?default_value:date_time option
  -> ?on_change:(date_time option -> unit Effect.t) Bonsai.t
  -> ?min:date_time
  -> ?max:date_time
  -> ?date_constraints:(Plain_date.t -> bool) list
  -> ?has_seconds:bool
  -> ?hour_format:hour_format
  -> ?time_increment:time_increment
  -> ?has_clear:bool
  -> ?placeholder:string
  -> ?time_placeholder:string
  -> ?time_label:string
  -> ?size:size
  -> ?status:Input_types.status
  -> ?status_variant:status_variant
  -> ?width:Common.Size_value.t
  -> ?number_of_months:int
  -> ?week_starts_on:int
  -> ?locale:string
  -> Bonsai.graph
  -> Vdom.Node.t Bonsai.t
```

Call it with the same prop names and defaults the upstream contract above documents; `Divergence` comments in the source record the few places the port deliberately differs (class names, and inline styles for per-instance numeric props).

<!-- port-status:end -->
