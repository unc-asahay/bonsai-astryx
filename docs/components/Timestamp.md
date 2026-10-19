# Timestamp

**Category:** Content  |  **Group:** -  |  **Port status:** not started

Timestamp formats a date or time value into human-readable text. Use it to
show when something was created, updated, or is scheduled; picking relative
for recency, absolute for precision, or auto to let the component decide.

## When to reach for it / when not to

- **Do:** Use the auto format in feeds and lists so recent items show "2 hours
  ago" and older items show the full date automatically.
- **Do:** Keep formatting consistent within the same list or table; mixing
  relative and absolute timestamps in the same column confuses scanning.
- **Do:** Enable isTimezoneShown when the audience spans multiple time zones, like
  a global team calendar or audit log.
- **Do:** Use tooltipEntries when readers must compare zones, such as an incident
  log where the reader's time and the event's origin zone both matter.
- **Do:** Label every entry once a tooltip shows more than one zone; a bare
  abbreviation is not always recognizable (Tokyo renders as "GMT+9", not
  "JST").
- **Do:** Use isLive for active dashboards or real-time feeds so the relative time
  stays accurate without a page refresh.
- **Do:** Reach for tooltipEntries when readers need to grab an exact value: an
  incident log or deploy record where someone pastes the UTC time or Unix
  seconds elsewhere; configuring entries turns the hover into
  copy-to-clipboard rows.
- **Don't:** Don't display raw Unix timestamps or ISO strings to users; always pass
  them through Timestamp to get a human-readable format.
- **Don't:** Avoid system_date or system_time formats in user-facing UI; they are
  meant for developer tools, logs, and machine-readable contexts.
- **Don't:** Don't disable the hover card on relative timestamps; users expect to
  hover for the full date when they see "3 hours ago".
- **Don't:** Don't stack many zones into one card; it is capped at 300px wide and
  long labelled lines wrap. Two or three entries read well.
- **Don't:** Don't pass a fixed-offset abbreviation like "EST" as timezoneID; it is a
  valid identifier but never observes daylight saving, so it reads an hour
  wrong for half the year. Use the region id, "America/New_York".

## Props

| prop | type | required | default | meaning |
| --- | --- | --- | --- | --- |
| `value` | `string \| number` | yes | `` | The date/time to display. Accepts Unix timestamps (seconds) or ISO 8601 strings. |
| `format` | `'relative' \| 'relative_short' \| 'auto' \| 'date' \| 'date_long' \| 'date_weekday' \| 'date_time' \| 'time' \| 'system_date' \| 'system_date_time' \| 'system_time' \| 'unix_seconds'` | no | `'auto'` | Display format. 'relative' uses the locale's native long relative-time wording ('2 hours ago' in English), 'relative_short' uses its narrow pattern ('2h ago' in English) for compact surfaces, 'date' shows 'Mar 21, 2025', 'date_long' shows 'March 21, 2025', 'date_weekday' shows 'Wed, Mar 21, 2025', 'date_time' shows 'Mar 21, 2025, 2:51 PM', 'time' shows '2:51 PM', 'system_*' variants use ISO-style formatting, 'unix_seconds' shows the Unix time in whole seconds since the epoch (an absolute, zone-independent value), 'auto' switches from relative to date_time based on recency. |
| `autoThreshold` | `number` | no | `604800` | Threshold in seconds for 'auto' format to switch from relative to date_time. |
| `hasTooltip` | `boolean` | no | `true` | Whether to show a copyable hover card with the full date/time on hover. Applies to relative timestamps and to any format once tooltipEntries is configured. |
| `tooltipEntries` | `ReadonlyArray<{timezoneID?: string; format?: TimestampTooltipFormat; label?: string; isCopyable?: boolean}>` | no | `` | Lines to show on hover, so one instant can be read (and optionally copied) in several time zones and/or formats at once. Each entry is one line, in the order given. Omit timezoneID (or pass 'local') for the viewer's own zone; format defaults to the full absolute style and also accepts 'full' alongside every non-relative TimestampFormat. Rows are read-only unless they set isCopyable (default false); copyable rows show a copy button in a dedicated trailing action column so buttons align, and the column is only present when some row is copyable. With no entries the card shows a single default row with the full absolute time, which is copyable. Configuring entries also attaches the surface to absolute formats, which otherwise have none. |
| `isTimezoneShown` | `boolean` | no | `false` | Whether to append the timezone abbreviation to the visible text. Applies to the date_time and time formats; system_* formats stay machine-readable and never carry one. Use tooltipEntries to control the tooltip's time zones. |
| `isLive` | `boolean` | no | `false` | Whether the relative time should update live (e.g. "2 min ago" → "3 min ago"). |
| `type` | `'body' \| 'large' \| 'label' \| 'supporting' \| 'code' \| 'display-1' \| 'display-2' \| 'display-3' \| 'inherit'` | no | `'supporting'` | Semantic text type from Text. Determines size, weight, and line-height. |
| `size` | `'4xs' \| '3xs' \| '2xs' \| 'xsm' \| 'sm' \| 'base' \| 'lg' \| 'xl' \| '2xl' \| '3xl' \| '4xl'` | no | `` | Explicit font size override. Overrides the size from type. |
| `color` | `'primary' \| 'secondary' \| 'disabled' \| 'placeholder' \| 'accent' \| 'inherit'` | no | `'secondary'` | Text color. |
| `weight` | `'normal' \| 'medium' \| 'semibold' \| 'bold'` | no | `` | Font weight override. |

## Anatomy

- `Formatted text` (required) — The rendered date, time, or relative label like "2 hours ago" or "Mar 21, 2025".
- `Hover card` (optional) — A copyable hover card showing the full absolute date and time when the display is relative, or the rows configured via tooltipEntries. Its default single row carries the full absolute time.
- `Hover card row` (optional) — One row of the card: an optional label beside the instant rendered in one time zone and format. Rows opt into a copy button via isCopyable.
- `Copy button` (required) — Per-row copy-to-clipboard button in the hover card; copies that row's formatted value.

## Retrieval keywords

`date`, `time`, `datetime`, `relative`, `ago`, `clock`, `format`, `duration`

---

Generated from `astryx/packages/core/src/Timestamp/Timestamp.doc.mjs` (MIT, https://github.com/facebook/astryx). Spec: no · upstream tests: no.
