(* DateTimeInput — a date and a time in one field.

   Port of upstream's [packages/core/src/DateTimeInput]. The behaviour contract
   is upstream's own: [DateTimeInput.spec.md] (intent, ARIA, FR1–FR5) and
   [DateTimeInput.test.tsx] (case by case).

   {2 What the port is}

   One field, one label, two segments: a date segment (a text field and a
   calendar button that opens the month grid in a popover) and a time segment
   (a text field that takes typed time, and arrow-key stepping). The two
   halves make one value — a date and a time of day — so the field is
   committed as a unit: a datetime exists only once both halves do.

   The date half speaks the house's date type ([Astryx.Plain_date.t]) and the
   time half a house-local [time] record, so the value this component carries
   is a [date_time] — not upstream's ISO string. [date_time.of_iso] and
   [date_time.to_iso] convert at the boundary, exactly as
   [Plain_date.of_iso] / [Plain_date.to_iso] do for a plain date.

   {2 Keyboard}

   - The date field is a combobox: [ArrowDown] (or [Alt]+[ArrowDown]) opens the
     calendar popover, [Escape] closes it, [Enter] commits the typed date.
   - The time field steps with [ArrowUp] / [ArrowDown] by [time_increment]
     minutes, wrapping around midnight, and commits the typed time on
     [Enter] or blur.
   - The calendar itself is the house [Astryx.Calendar]: one composite grid
     with a single Tab stop, the arrow keys walking the days.

   {2 Divergences from upstream}

   - {b The value is a [date_time], not an ISO string.} Upstream's public API
     speaks ISO 8601 strings ("2026-03-21T14:30"); this port speaks the
     house's date type and a [time] record. [date_time.of_iso] /
     [date_time.to_iso] convert at the boundary.
   - {b No timezone.} Upstream's value is a naive local datetime with no
     offset and no zone, and the port keeps that: a [date_time] is a wall
     clock reading, and the port never converts between zones. The house has
     no time-zone infrastructure (no zone list, no offset arithmetic, no
     [Intl.DateTimeFormat] timeZone plumbing), so a zone-carrying API could
     not be honoured here. Any zone work belongs in a layer above this
     component.
   - {b No native or touch surfaces.} Upstream's [presentation] /
     [nativePicker] props choose between browser/OS date and time inputs,
     Astryx's own surfaces, and a coordinated bottom sheet. The port renders
     Astryx's own surfaces everywhere; those props do not exist here rather
     than being accepted and ignored.
   - {b No [change_action].} Upstream's async action (and the optimistic
     transition around it) has no counterpart in a Bonsai graph, so the
     component reports through [on_change] only.
   - {b No [label_tooltip] and no [disabled_message] tooltip.} The house
     [Field] renders the label and the status message; the tooltip surfaces
     upstream hangs off them are not ported. [disabled_message] is accepted
     and rendered as the field's description, so the reason is still
     announced.
   - {b No preset-time dropdown.} Upstream's [time_option_interval] turns the
     time field into a combobox listing every time at that cadence. The port
     keeps the typed time field (with arrow-key stepping) and does not add
     the listbox; the list is a shortcut upstream, not a restriction, so
     nothing is lost but the shortcut.
   - {b No [is_loading] spinner.} The house has no loading surface wired
     into an input; the prop is absent rather than faked.
   - {b The live regions are drawn in place.} Upstream announces through
     document-level live regions created by [useAnnounce]; the OCaml Layer
     has no document-level outlet, so the invalid-date and invalid-time
     regions are rendered inside the field, where they still announce the
     same messages.
   - {b The strings are fixed English.} Upstream resolves them through its
     i18n catalogue ("Select a date", "Select a time", "Open calendar",
     "Invalid date", ...); the port has no i18n layer, so the same wording is
     built in.
   - Upstream's press-feedback overlay on the day button is not ported, and
     neither is its [className] / [xstyle] escape hatches; use [attrs]. *)

open! Core
open! Bonsai_web

type time =
  { hour : int  (** 0-23 *)
  ; minute : int  (** 0-59 *)
  ; second : int  (** 0-59 *)
  }
(** A time of day, on a 24-hour clock. *)

type date_time =
  { date : Plain_date.t
  ; time : time
  }
(** A wall-clock reading: a calendar date and a time of day. No zone, no
    offset — the same information upstream's ISO string carries. *)

module Date_time : sig
  val of_iso : string -> date_time option
  (** Parse "YYYY-MM-DDTHH:MM" or "YYYY-MM-DDTHH:MM:SS" (a space is accepted
      in place of the "T"). [None] when the string is not a datetime. *)

  val to_iso : date_time -> string
  (** Render "YYYY-MM-DDTHH:MM", with the seconds appended when they are not
      zero. *)
end

type hour_format =
  | H12  (** "2:30 PM" — the default *)
  | H24  (** "14:30" *)

type time_increment =
  | Minute_1  (** the default *)
  | Minute_5
  | Minute_10
  | Minute_15
  | Minute_30
(** The minute step the time field's arrow keys move by. Upstream's
    [timeIncrement] is the same set. *)

type size = Input_types.size =
  | Sm
  | Md
  | Lg

type status_type = Input_types.status_type =
  | Warning
  | Error
  | Success

type status_variant = Field_status.placement =
  | Attached  (** the message is part of the field's surface, under the control *)
  | Detached  (** the message sits below the field with its own spacing *)
  | Tooltip  (** no message box: the message is announced, not shown *)

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
(** [view ~value ~on_change graph]: the date-and-time field.

    [value] is the controlled value ([None] = nothing picked); [default_value]
    seeds an uncontrolled one. [on_change] reports the new value, and [None]
    when the field is cleared.

    [min] and [max] bound the whole datetime. The date half bounds the
    calendar's selectable days; the time half bounds the time only on the
    day it belongs to (upstream's rule: a time bound applies on the boundary
    date, not on every date). [date_constraints] are predicates over a day, and
    a day is disabled when any of them returns [false].

    [has_seconds] shows and parses seconds. [hour_format] picks the display
    and the parse format for the time half ([H12] is the default and accepts
    a meridiem). [time_increment] is the arrow-key step. [has_clear] adds a
    clear button. [placeholder] and [time_placeholder] are the empty-state
    texts ("Select a date" and "Select a time" by default), and [time_label]
    is the accessible name of the time half ("{label} time" by default).

    [number_of_months] is 1 (the default) or 2; [week_starts_on] is 0 for
    Sunday through 6 for Saturday; [locale] is a BCP 47 tag used for the
    date's own formatting and for the calendar's labels.

    The date half is a combobox whose calendar opens in a popover; the time
    half is a text field that takes typed time and steps with the arrow keys.
    Both halves commit as one value. *)
