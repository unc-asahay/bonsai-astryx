(** DateRangeInput — a field for choosing a range of dates.

    Port of upstream [DateRangeInput]. The range is held as a pair of calendar days
    ([date_range]) and the component offers two ways to set it: the pair of date
    fields, which parse on blur, and the calendar surface, which is the house
    {!Calendar} in [Range] mode behind the house {!Popover}.

    Upstream's own range is a pair of ISO strings; the house range is
    {!Calendar.date_range}, so a day is a {!Plain_date.t} everywhere in this
    interface — the same convention the ported calendar and plain-date modules use.

    {2 Divergences (also recorded in [port.json])}

    - {b Entry surface.} Upstream's DateRangeInput presents the range through a
      trigger that opens the calendar. This port keeps that surface and adds a pair
      of date fields beside it, so a range can be typed as well as picked; the
      fields parse on blur and revert when the text cannot be read. The upstream
      file could not be read line by line in this port's budget, so the typed
      entry is the port's own addition, not a transcription of upstream markup.
    - {b The popover is the house {!Popover}.} Upstream positions and dismisses
      with the native Popover API, which is exactly what the house popover stands
      on; the port reuses it rather than writing a second positioning engine, and
      says so instead of shipping an unproven fallback. The calendar surface is
      therefore the house calendar, not a second month grid.
    - {b Locale via argument, not context.} Upstream reads the locale out of its
      i18n context; the port takes [?locale] (a BCP 47 tag) and formats through the
      host Intl when it is available.
    - {b Dates are {!Plain_date.t}, not ISO strings.} Upstream's [min]/[max] and
      its [dateConstraints] speak ISO strings and [Date] objects; here a day is a
      [Plain_date.t] and a constraint is a [Plain_date.t -> bool].
    - {b The range is the calendar's own.} Upstream's value is
      [{start, end}] of ISO strings; the port reuses {!Calendar.date_range} so the
      value handed to the calendar needs no conversion.
    - {b Parsing is ISO unless told otherwise.} The house ships no general date
      parser, so the fields read [YYYY-MM-DD] and [YYYY/MM/DD] by default;
      [?parse_date] replaces that and [?format_date] replaces the display. The
      default display is the locale-aware long form ("Mar 21, 2026"), which is a
      format the house cannot read back — hence the two hooks.
    - {b Span limits count days inclusively.} [?min_range_span] and
      [?max_range_span] measure the number of days the range covers, both
      endpoints included, so a one-day range spans 1. [?max_range_span] is [None]
      when there is no upper bound, exactly as the house calendar takes it.
    - {b No async save.} Upstream's [changeAction] saves the range and keeps an
      optimistic value on screen; the house has no promise to await, so the port
      takes [?is_loading] and leaves the save to the caller.
    - {b No in-control status icon.} Upstream paints the status icon inside the
      control; the house [Field] renders the message box, as in [Text_input].
    - {b Fixed English labels.} "Start date", "End date", "Choose dates" and
      "Close calendar" are fixed English (upstream resolves them through its i18n
      catalogue).
    - Generated ids derive from [id] ([id]-desc, [id]-status, [id]-reason,
      [id]-label, [id]-end, [id]-calendar, [id]-popover) rather than React's
      [useId], so markup is deterministic and testable. *)

open! Core
open! Bonsai_web

type date_range = Calendar.date_range
(** The chosen range: [start_date] and [end_date], both calendar days, ordered
    (the start is never after the end). *)

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

val view
  :  ?id:string
  -> ?attrs:Vdom.Attr.t list
  -> label:string
  -> ?is_label_hidden:bool
  -> ?description:string
  -> ?is_optional:bool
  -> ?is_required:bool
  -> ?optionality:Common.Optionality.t
  -> ?is_disabled:bool
  -> ?disabled_message:string
  -> ?is_loading:bool
  -> ?min:Plain_date.t
  -> ?max:Plain_date.t
  -> ?date_constraints:(Plain_date.t -> bool) list
  -> ?min_range_span:int
  -> ?max_range_span:int option
  -> ?has_clear:bool
  -> ?start_placeholder:string
  -> ?end_placeholder:string
  -> ?format_date:(Plain_date.t -> string)
  -> ?parse_date:(string -> Plain_date.t option)
  -> ?size:size
  -> ?status:Input_types.status
  -> ?status_variant:status_variant
  -> ?width:Common.Size_value.t
  -> ?locale:string
  -> ?number_of_months:int
  -> ?week_starts_on:int
  -> value:date_range option Bonsai.t
  -> on_change:(date_range option -> unit Effect.t) Bonsai.t
  -> Bonsai.graph
  -> Vdom.Node.t Bonsai.t
(** [view ~label ~value ~on_change graph].

    [value] is the chosen range ([None] = nothing chosen yet) and [on_change] is
    called with the new range, or with [None] when the range is cleared. Both are
    graph values, so the DOM follows application state the same way
    [Text_input] and [Number_input] do.

    The two fields are the primary way in: a field commits on blur, and a draft
    that cannot be read reverts to the committed value. The calendar surface
    behind the calendar button sets the whole range in one go and closes itself.

    [min]/[max] bound both the fields and the calendar, and [date_constraints] are
    predicates a day must satisfy to be chosen ([false] rejects the day, matching
    the calendar's polarity). [min_range_span]/[max_range_span] bound the length
    of the range in days, both endpoints included.

    [disabled_message] keeps the fields focusable ([aria-disabled]) and states the
    reason, like [Number_input]. [is_loading] shows a spinner and stops the
    fields being edited. [format_date] and [parse_date] override how a day is
    written and read; the defaults are the locale-aware long form for writing and
    ISO for reading. *)
