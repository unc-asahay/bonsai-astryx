(** A text field for entering a date, with a calendar for picking one.

    {1 Upstream}

    This is the OCaml/Bonsai port of the React [DateInput] component from
    [astryx]. Upstream renders a text field, a trailing button that opens a
    popover holding a [Calendar], and it parses the text the user types
    against a locale, committing the parsed date as the user types.

    {1 Usage}

    The field is controlled: the caller owns the committed date and receives
    every change through [on_change].

    {[
      let date, set_date =
        Bonsai.state' (None : Plain_date.t option) graph
      in
      Astryx.Date_input.view
        ~label:"Start date"
        ~value:date
        ~on_change:
          (Bonsai.map set_date ~f:(fun set -> fun d -> set (fun _ -> d)))
        graph
    ]}

    {1 The field is a combobox}

    The field is the combobox, the way upstream's is: it carries
    [role=combobox], it says what it opens with [aria-haspopup="dialog"], it
    says whether the calendar is open with [aria-expanded], and it says it
    completes nothing with [aria-autocomplete="none"]. Clicking the field
    opens the calendar, [ArrowDown] opens it, and [Escape] closes it. The
    trailing button opens the same calendar, for the person who would rather
    not type.

    {1 Divergences}

    - The calendar is opened from a trailing button into a house [Popover],
      as upstream opens it.
    - Upstream's field is a combobox whose calendar opens without taking the
      focus, so the person can carry on typing. The house's surfaces take
      the focus when they open — the house [Popover] does it everywhere, and
      so do the house [Selector] and [Complex_selector] — so the focus goes
      into the calendar here, and comes back to the button when it closes.
      The field's own [aria-expanded] says which way it is.
    - Upstream falls back to the browser's own date parser for spellings it
      does not recognise. This port accepts a documented subset only and
      rejects everything else, so a field never silently holds a date the
      caller did not expect.
    - Upstream hands the ISO string to [on_change]. The house API speaks
      [Plain_date.t]; use [Plain_date.to_iso] for the upstream string form.
    - Upstream asks Intl whether the locale puts the day before the month.
      The house keeps the list of locales that do, and treats everything
      else, including plain "en", as month-first.
    - Upstream keeps the text the user typed in the field while they type. This
      port does the same, and reformats the field from the committed date when
      the field is blurred or Enter is pressed. *)

open! Bonsai_web

(** The size of the date input, matching the house [Input_types.size]. *)
type size = Input_types.size = Sm | Md | Lg

(** The status of the date input, matching the house [Input_types.status]. *)
type status = Input_types.status

(** Where a status message is placed, matching the house field status. *)
type status_variant = Field_status.placement = Attached | Detached | Tooltip

(** How a committed date is written in the field.

    [Date] is the short form ("Mar 21, 2026"), [Date_long] spells the month
    out ("March 21, 2026"), [Date_weekday] leads with the weekday ("Wed, Mar
    21, 2026") and [System_date] is the ISO form ("2026-03-21"). [Custom]
    formats the date with a function of your own. *)
type format =
  | Date
  | Date_long
  | Date_weekday
  | System_date
  | Custom of (Plain_date.t -> string)

(** A date input.

    {2 Committed value}

    [value] is the committed date and [on_change] is called with the new
    committed date every time it changes, with [None] when the field is
    cleared. The text the user is typing lives inside the field until it is
    committed or rejected; the field falls back to the committed date on blur
    or when Enter is pressed, whether or not the text could be parsed.

    {2 Parsing}

    The text is parsed as an ISO date ("2026-03-21"), as a numeric date
    ("3/21/2026" or "21/03/2026", where the order follows the locale) or with
    an English month name ("March 21, 2026" or "21 March 2026"). The year is
    required. Anything else is rejected, and the field keeps the committed
    date.

    {2 Bounds}

    [min], [max] and [date_constraints] bound the dates that may be picked and
    the dates that may be committed, with the same polarity the house
    [Calendar] uses. *)
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
  -> ?is_loading:bool
  -> ?value:Plain_date.t option Bonsai.t
  -> ?on_change:(Plain_date.t option -> unit Effect.t) Bonsai.t
  -> ?min:Plain_date.t
  -> ?max:Plain_date.t
  -> ?date_constraints:(Plain_date.t -> bool) list
  -> ?placeholder:string
  -> ?format:format
  -> ?locale:string
  -> ?number_of_months:int
  -> ?week_starts_on:int
  -> ?size:size
  -> ?status:status
  -> ?status_variant:status_variant
  -> ?width:Common.Size_value.t
  -> Bonsai.graph
  -> Vdom.Node.t Bonsai.t
