(** TimeInput — a text field for a time of day.

    Port of upstream's [TimeInput] (upstream [packages/core/src/TimeInput], the
    typed-field surface, and the shared [utils/timeParser.ts] it is built on).
    The behaviour contract is upstream's own: the parser's accepted formats, the
    twelve/twenty-four hour display, the arrow-key adjustment, the range check
    and the accessibility wiring.

    {2 What the port is}

    A text field a person types a time into. The field owns the draft text; the
    application owns the committed reading. The reading is a plain wall-clock
    {e time of day} — hours, minutes and seconds on a twenty-four hour clock —
    not upstream's ISO string. [of_iso] and [to_iso] convert at the boundary,
    exactly as {!Plain_date.of_iso} / [Plain_date.to_iso] do for a date.

    {2 Keyboard}

    - The field is a plain text box. Typed text is parsed as it is typed and
      committed as soon as it is valid and in range — upstream does not wait
      for blur, and neither does this port.
    - [ArrowUp] / [ArrowDown] step the time by [increment] minutes, wrapping
      around midnight, and the new time is announced (upstream speaks it
      through a document-level live region; the port draws the region in
      place, like {!Calendar} does).
    - The value is validated against [min] / [max] on every keystroke, and an
      out-of-range entry is refused and reported (WCAG 3.3.1).

    {2 Divergences from upstream}

    - {b The value is a [time] record, not an ISO string.} Upstream's public
      API speaks [ISOTimeString] ("14:30" / "09:15:00"). This port speaks a
      house-local [time] record, and [of_iso] / [to_iso] convert at the
      boundary. The information is the same: a time of day with no date and no
      zone, which is what upstream's string carries.
    - {b No native picker, popover or bottom sheet.} Upstream's [presentation]
      prop (spec AST-043) chooses between the browser/OS time picker, Astryx's
      own surfaces and this typed field, and [nativePicker] is its deprecated
      spelling of the same question. The house has no native time picker and no
      Astryx time surface to offer, so the typed field is the only surface and
      those props do not exist here rather than being accepted and ignored.
    - {b No [change_action] and no optimistic value.} Upstream fires an async
      action after [onChange] and keeps an optimistic value through the
      transition. A Bonsai graph has no counterpart for either, so the
      component reports through [on_change] only, and [is_loading] is the
      caller's business to raise.
    - {b No [ref] forwarding.} Upstream forwards a ref to the DOM input; the
      port reaches the element through [attrs] and the generated ids.
    - {b No InputGroup context.} Upstream swaps in a visually-hidden label
      inside an InputGroup; here a field is either inside an explicit
      [Input_group.view] or not (pass [is_label_hidden] yourself).
    - {b No [label_tooltip].} Upstream renders its Tooltip component there.
      Tooltip is not ported, so the argument does not exist here rather than
      being accepted and ignored.
    - {b The strings are fixed English.} Upstream resolves them through its
      i18n catalogue ("Select a time", "Invalid time", "Clear value", ...); the
      port has no i18n layer, so the same wording is built in.
    - {b The live regions are drawn in place.} Upstream announces through
      document-level live regions created by [useAnnounce]; the OCaml layer has
      no document-level outlet, so the invalid-time and stepped-time regions
      are rendered inside the field, where they still announce the same
      messages.
    - {b No in-wrapper status icon.} Upstream paints the status icon inside the
      control; the house [Field] renders the message box, as in
      {!Text_input}. Passing [status] still colours the control
      (data-status/border class).
    - {b The clock icon is a plain icon, not an upstream "clock" glyph
      variant.} The house icon registry has no clock of its own, so the
      control draws the house [Icon] instead.
    - Upstream's press-feedback and hover surfaces on the wrapper are not
      ported, and neither are its [className] / [xstyle] escape hatches; use
      [attrs].

    {2 Surfaces upstream has and this port does not}

    - {b The native/browser time picker} ([presentation = "native"], and the
      deprecated [nativePicker] prop). The house has no native time-picker
      surface, and the OCaml layer has no way to ask the host for one.
    - {b The Astryx popover time surface} and {b the Astryx bottom-sheet time
      surface} ([presentation = "popover" | "bottom-sheet"]). Upstream ships
      whole time-picking widgets for these; the house has no time-picker
      component to point them at, and building one is a different port.
    - {b The coarse-pointer switch} between the picker and the typed field.
      The house has no pointer-media-query seam, and with no picker to switch
      to there would be nothing to switch to.
    - {b [changeAction]} and {b the optimistic value it drives}.
    - {b [ref] forwarding to the DOM input}, and the DOM event-handler props
      ([onFocus], [onBlur], [onKeyDown]) upstream accepts on the control.
      The port keeps Enter and the arrow keys itself and reaches the rest
      through [attrs].
    - {b [labelTooltip]}.
    - {b The InputGroup context} (the visually-hidden label and description
      upstream renders inside a group).
    - {b The i18n catalogue} and its translated strings. *)

open! Core
open! Bonsai_web

type time =
  { hour : int  (** 0-23 *)
  ; minute : int  (** 0-59 *)
  ; second : int  (** 0-59 *)
  }
(** A time of day, on a twenty-four hour clock. No date, no zone — the same
    information upstream's ISO time string carries. *)

type hour_format =
  | H12  (** twelve hour clock with a meridiem ("2:30 PM") — the default *)
  | H24  (** twenty-four hour clock ("14:30") *)

type size = Input_types.size =
  | Sm
  | Md
  | Lg

type status_type = Input_types.status_type =
  | Warning
  | Error
  | Success

type status_variant = Field_status.placement =
  | Attached  (** the message is part of the field's surface, under the control — the default *)
  | Detached
  | Tooltip

(** {2 The parser}

    These are upstream's [utils/timeParser.ts] functions, renamed to the
    house's snake_case convention. They are the contract the field is built
    on, and they are public so a caller can parse and format a time without
    going through the field. *)

val of_iso : string -> time option
(** [of_iso "14:30"] = [Some {hour = 14; minute = 30; second = 0}];
    [of_iso "09:15:00"] keeps the seconds. [None] for anything that is not
    "HH:MM" or "HH:MM:SS" with every field in range. Upstream's
    [parseISOTime]. *)

val to_iso : ?include_seconds:bool -> time -> string
(** [to_iso ~include_seconds:false t] = "14:30"; with seconds, "14:30:45".
    Upstream's [formatISOTime]. *)

val parse_time_input : ?include_seconds:bool -> string -> time option
(** Parse what a person typed. Upstream's [parseTimeInput].

    Accepted, with or without a meridiem:

    - "2:30 PM", "2:30pm", "2:30 pm", "2:30 p.m." — a meridiem may carry
      dots, and a dotted meridiem still converts ("2:30 p.m." is 14:30, not
      2:30).
    - "2 PM", "2pm" — an hour on its own.
    - "14:30", "1430" — a twenty-four hour clock, with or without the colon.
    - "143000" — with seconds.

    A meridiem is only valid on hours 1-12; without one the hour must be
    0-23. The minutes and seconds must be 0-59. [None] for anything else. *)

val format_display_time : ?include_seconds:bool -> hour_format -> time -> string
(** The time as it is shown in the field. Upstream's [formatDisplayTime12h] and
    [formatDisplayTime24h]. Twelve hour format is "2:30 PM" (midnight reads
    "12:00 AM", noon "12:00 PM"); twenty-four hour format is "14:30". *)

val adjust_time : time -> delta_minutes:int -> time
(** Step a time by a number of minutes, wrapping around midnight in both
    directions. Upstream's [adjustTime]; the seconds are carried over
    unchanged. *)

val is_time_in_range : time -> min:time option -> max:time option -> bool
(** Whether a time falls inside a range, inclusive at both ends. Upstream's
    [isTimeInRange]. *)

val compare_time : time -> time -> int
(** Negative, zero or positive as the first time is before, the same as, or
    after the second. Upstream's [compareTime]. *)

(** {2 The field} *)

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
  -> ?value:time option Bonsai.t
  -> ?on_change:(time option -> unit Effect.t) Bonsai.t
  -> ?min:time
  -> ?max:time
  -> ?has_seconds:bool
  -> ?has_clear:bool
  -> ?has_auto_focus:bool
  -> ?hour_format:hour_format
  -> ?increment:int
  -> ?placeholder:string
  -> ?is_loading:bool
  -> ?status:Input_types.status
  -> ?status_variant:status_variant
  -> ?size:size
  -> ?width:Common.Size_value.t
  -> ?html_name:string
  -> Bonsai.graph
  -> Vdom.Node.t Bonsai.t
(** [view ~label graph] renders the field.

    [value] is the committed time ([None] = empty) and [on_change] reports the
    new one, and [None] when the field is cleared. Both are graph values: the
    DOM follows application state the same way {!Text_input} does.

    [min] and [max] bound the time. A typed time outside the range is refused
    and reported; the arrow keys will not step past a bound either.

    [has_seconds] shows and parses seconds. [hour_format] picks the display
    and the parse format ([H12] is the default and accepts a meridiem).
    [increment] is the number of minutes the arrow keys step by (1 by
    default). [has_clear] adds a clear button.

    [is_disabled] with [disabled_message] keeps the field focusable
    ([aria-disabled]) and shows the reason, like {!Number_input}. [is_loading]
    shows the spinner. [placeholder] is the empty-state text ("Select a time"
    by default), and the focused-and-empty field shows the format hint
    ("e.g., 2:30 PM") instead, as upstream does. *)
