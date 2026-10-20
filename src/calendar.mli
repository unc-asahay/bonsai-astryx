(* Calendar — the month grid a person picks a date (or a date range) with.

   Port of upstream's [packages/core/src/Calendar]. The behaviour contract is
   upstream's own: [Calendar.spec.md] (intent, ARIA, FR1–FR5) and
   [Calendar.test.tsx] (case by case).

   {2 What the port is}

   One or two month grids render as APG [role=grid] composites: a named grid
   per month, a [columnheader] per weekday, one [row] per week, a [gridcell]
   per day, and a [button] inside each cell that carries the day's full date
   as its accessible name, [aria-current="date"] for today and
   [aria-disabled] for a day that cannot be picked. The grid is one composite
   control: each month's grid holds at most one Tab stop (FR2), and the arrow,
   Home/End and Page keys move it.

   {2 Keyboard}

   - [ArrowLeft] / [ArrowRight] move by a day, following the reading direction
     (mirrored under RTL);
   - [ArrowUp] / [ArrowDown] move by a week, staying in the column;
   - [Home] / [End] move to the first / last enabled day of the week row
     ([Ctrl] / [Cmd] with them: the first / last enabled day of the month);
   - [PageUp] / [PageDown] move by a month, and [Shift] with them by a year;
   - [Enter] / [Space] pick the focused day (the day is a real [button], so the
     browser does it);
   - [Escape] cancels a range selection that is in progress.

   An arrow skips a day a constraint rejects and keeps going in the same
   direction; crossing the month edge moves the visible month so the focused
   day stays visible, in one month or two. A borrowed adjacent-month day is
   exposed [aria-disabled] and is never picked: the focus lands on the real day
   in the month now shown.

   {2 Divergences from upstream}

   - {b Dates are [Plain_date.t], not ISO strings.} Upstream's public API
     speaks ISO date strings; this port speaks the house's date type
     ([Astryx.Plain_date.t]), and [Plain_date.of_iso] / [Plain_date.to_iso]
     convert at the boundary. The same applies to [date_constraints], which
     upstream hands a native [Date] and this port hands a [Plain_date.t].
   - {b The live region is drawn in place.} Upstream announces through a
     document-level pair of live regions created by [useAnnounce]. The OCaml
     Layer has no portal and no document-level outlet, so the polite live
     region is rendered inside the calendar root, where it still announces the
     same messages (the new month, and the range progress).
   - {b No imperative handle.} Upstream's [handleRef] exposes [navigateTo]; a
     controlled owner gets the same power from [focus_date] and
     [on_focus_date_change].
   - {b Shift+PageUp / Shift+PageDown move by a year.} Upstream pages by a
     month only; the year step is the APG date-picker-dialog behaviour and is
     an addition to upstream's contract.
   - {b The strings are fixed English.} Upstream resolves them through its i18n
     catalogue ("Previous month", ", selected", "Start date {date}. Select an
     end date.", ...). This port has no i18n layer, so the same wording is
     built in.
   - {b A fresh id per mounted instance} (the house pattern) is used for the
     live region, where upstream uses React's [useId].
   - Upstream's press-feedback overlay on the day button is not ported, and
     neither is its [className] / [xstyle] escape hatches; use [attrs]. *)

open! Core
open! Bonsai_web

type mode = Single | Range
(** One date, or a start/end pair. *)

type date_range =
  { start_date : Plain_date.t
  ; end_date : Plain_date.t
  }
(** A range, always with [start_date <= end_date]. *)

type selection =
  | Single_date of Plain_date.t
  | Date_range of date_range
(** What the calendar holds: the single-mode selection, or the range-mode
    selection. The variant has to match the [mode]. *)

val view
  :  ?id:string
  -> ?attrs:Vdom.Attr.t list
  -> ?mode:mode
  -> ?value:selection option Bonsai.t
  -> ?default_value:selection option
  -> ?on_change:(selection -> unit Effect.t) Bonsai.t
  -> ?number_of_months:int
  -> ?min:Plain_date.t
  -> ?max:Plain_date.t
  -> ?date_constraints:(Plain_date.t -> bool) list
  -> ?max_range_span:int option
  -> ?min_range_span:int
  -> ?focus_date:Plain_date.t option Bonsai.t
  -> ?on_focus_date_change:(Plain_date.t -> unit Effect.t) Bonsai.t
  -> ?has_outside_days:bool
  -> ?has_week_numbers:bool
  -> ?has_variable_row_count:bool
  -> ?week_starts_on:int
  -> ?locale:string
  -> Bonsai.graph
  -> Vdom.Node.t Bonsai.t
(** [view ~mode ~value ~on_change ()]: the calendar.

    [mode] is [Single] (the default) or [Range]. [value] is the controlled
    selection: pass the optional argument to control the calendar, and
    [default_value] to seed an uncontrolled one. A controlled calendar with
    [value = None] is the controlled empty state — it holds no selection and
    shows nothing as picked until the owner changes [value]. [on_change]
    reports every pick: the new date in [Single] mode, the new range in
    [Range] mode. The callback fires in both modes; in the controlled mode the
    calendar does not move on its own.

    [number_of_months] is 1 (the default) or 2 — any other value is clamped to
    1, as upstream does. [min] and [max] bound the selectable days;
    [date_constraints] are predicates over a day, and a day is disabled when
    any of them returns [false] (upstream's polarity: a constraint answers
    "may this be picked?"). [max_range_span] and [min_range_span] bound a
    range in [Range] mode, counting both endpoints ([max_range_span = 7]
    allows a seven-day window); they have no effect until a range start has
    been picked.

    [focus_date] is the controlled visible month, and [on_focus_date_change]
    reports a change to it. A calendar is controlled for its month when both
    are given; without them it moves its own month and still reports the
    change.

    [has_outside_days] (default [true]) shows the adjacent months' days,
    [has_week_numbers] (default [false]) adds a week-number column, and
    [has_variable_row_count] (default [false]) sizes the grid to the month
    instead of always using six rows. [week_starts_on] is 0 for Sunday
    through 6 for Saturday. [locale] is a BCP 47 tag used for the month and
    day labels; it defaults to ["en"]. *)
