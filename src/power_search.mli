(** PowerSearch — a search field that also takes structured filters.

    The field is one box: the filters that are set sit in it as chips, and the text the user
    types goes into the same box. Typing names a field — "status", "created" — and choosing
    one opens a small editor for the value, so a search is a list of filters rather than a
    sentence.

    {2 The shape of it}

    - A {b config} says what may be filtered: the {b fields}, and for each field the
      {b operators} that compare it. The operator decides the {b kind of value}: a field
      compared with "is" has no value, one compared with "is greater than" has a number, one
      compared with "is in" has a list of a fixed set.
    - A {b filter} is a field, an operator and a value. The value's type is the operator's
      type, so the two can never disagree.
    - The component is {b controlled}: the application holds the filters and hands them
      over, and every change is reported to the application, which decides what the new
      list is. Nothing is changed behind the application's back.

    {2 The ARIA}

    The box is the house {!Tokenizer}, so the combobox contract is the house's: the input
    is the control, the list is a listbox, focus never leaves the input, and the set of
    filters is announced as it changes. The editor is a house {!Popover} that is not a
    dialog — upstream's own note is that the popup's listbox is the exposed semantics and
    the focus stays on the input.

    {2 What the token says}

    A chip reads as the field's label, then the operator, then the value: "Status: is
    Archived". The value is written by the same rules upstream writes it by — a number with
    its units, an enum's label rather than its value, a list of one item as that item and
    a list of many as "3 items", a date as a date and a relative date as it was written.

    {2 Divergences from upstream}

    These are the surfaces upstream has and this port does not, each with its reason.

    - {b The operator's label is raw text.} Upstream's operator may name a key in a
      translation catalog instead; the house has no catalog, so the label is the text.
    - {b A date is stored as an ISO date, not as seconds since the epoch.} Upstream stores
      seconds and renders them in the user's time zone; the house has {!Plain_date}, which
      is a calendar date and nothing else, and a time zone is a thing this port has no
      way to hold. A range's ends are the same: an absolute end is an ISO date and a
      relative one is "7d".
    - {b A value of a set is edited as a comma-separated text, not as a tokenizer.} The
      house has a tokenizer, but a filter's value is edited inside a popover that the
      filter's own field does not own, and a second combobox inside a popover is a
      keyboard puzzle. The value that is stored is the same either way: the list.
    - {b The custom editor is a text input.} Upstream's custom operator carries a React
      component; the port's carries a function from the stored string to the text the chip
      shows, and the editor is a text input.
    - {b A nested value is shown, not edited.} Upstream's nested operator opens a
      sub-editor that holds filters of filters; the port shows the nested filters as a
      list and leaves them to the application.
    - {b There is no imperative handle.} Upstream's [handleRef] focuses the input from
      outside; this port's input is focused by the house tokenizer's own rules.

    {2 What is not ported}

    Upstream's tables of results, its i18n catalog, its per-type component overrides (the
    consumer's own token and editor) and its measurement of the menu's width are not part
    of this port's contract.

    Two of upstream's own knobs have no house equivalent. Upstream caps the operator
    menu in the editor at [max_operator_menu_items]; the house selector that lists the
    operators has no cap of its own, and the port's editor shows them all. Upstream
    reports the field's focus and blur through [on_focus] and [on_blur]; the house
    tokenizer has no such callbacks, and the port's field does not report them.

    The port covers the field, the chips, the typeahead over the fields, the editor, and
    the reporting of every change. *)

open! Core
open! Bonsai_web

(** The kind of value an operator compares against. This is what decides the editor, so it
    is upstream's [OperatorValue]. *)
type operator_value =
  | Empty
      (** No value: the operator is the whole filter, as in "is archived". *)
  | String of
      { search_source : (string -> string list) option
      ; is_arbitrary_string_allowed : bool
      }
      (** A single string. With a [search_source] the editor may offer the strings that
          source knows. *)
  | String_list of
      { search_source : (string -> string list) option
      ; is_arbitrary_string_allowed : bool
      ; tokenization : tokenization option
      }
      (** A set of strings. *)
  | Integer of
      { min_value : int option
      ; max_value : int option
      ; units : string option
      }
  | Float of
      { min_value : float option
      ; max_value : float option
      ; units : string option
      }
  | Time of
      { min_value : string option
      ; max_value : string option
      }
  | Date_absolute of { is_date_only : bool }
      (** An absolute date, stored as an ISO date. *)
  | Date_relative of
      { is_past_allowed : bool
      ; is_future_allowed : bool
      }
      (** A date relative to now, stored as a string such as "7d". *)
  | Date_range of
      { interval_date_presets : date_range_preset list
      ; relative_date_presets : relative_date_preset list
      }
      (** A range, with a start and an end, each of which may be relative. *)
  | Enum of enum_item list
      (** One of a fixed set of values. *)
  | Enum_list of enum_item list
      (** A set of values from a fixed set. *)
  | Entity_list of
      { search_source : (string -> string list) option
      ; is_arbitrary_string_allowed : bool
      ; tokenization : tokenization option
      }
      (** A set of entities, each an id and a label. *)
  | Custom of { get_string : string -> string }
      (** A value the consumer reads with its own function. The editor is a text input. *)
  | Nested
      (** A value that is itself a list of filters. *)

(** How pasted text is split into tokens. *)
and tokenization =
  { regex : string option
  ; sort : bool
  }

(** One of the values an [Enum] operator offers. *)
and enum_item =
  { value : string
  ; label : string
  }

(** A relative date, as a number of units and the unit itself. *)
and relative_date =
  { back_value : int
  ; unit : relative_unit
  }

(** The units a relative date can be measured in. Upstream's [DateTimeRangePart] unit. *)
and relative_unit =
  | Second
  | Minute
  | Hour
  | Day
  | Week
  | Month
  | Year

(** One end of a date range: now, an absolute date, or a date relative to now. *)
and date_range_part =
  | Now
  | Absolute of string
      (** An ISO date, "2024-03-05". *)
  | Relative of relative_date

(** A range, with a start and an end. *)
and date_time_range =
  { start : date_range_part
  ; end_ : date_range_part
  }

(** A named range the editor offers. *)
and date_range_preset =
  { label : string
  ; value : date_time_range
  }

(** A named relative date the editor offers. *)
and relative_date_preset =
  { label : string
  ; value : string
  }

(** The value a filter stores. Its type is the operator's type. *)
type filter_value =
  | Value_empty
  | Value_string of string
  | Value_string_list of string list
  | Value_integer of int
  | Value_float of float
  | Value_time of string
  | Value_date_absolute of string
      (** An ISO date. *)
  | Value_date_relative of string
  | Value_date_range of date_time_range
  | Value_enum of string
  | Value_enum_list of string list
  | Value_entity_list of entity list
  | Value_custom of string
  | Value_nested of filter list

(** An entity, as the entity_list operator stores it. *)
and entity =
  { id : string
  ; label : string
  ; photo : string option
  }

(** A filter: a field, an operator and a value. *)
and filter =
  { field : string
  ; operator : string
  ; value : filter_value
  ; is_read_only : bool
      (** A read-only filter cannot be edited or removed. *)
  }

(** A way of comparing a field. The label is raw text: the consumer owns the translation of
    it, as upstream's [PowerSearchOperatorWithLabel] does. *)
type operator =
  { key : string
  ; label : string
  ; value : operator_value
  }

(** A thing that can be filtered on. *)
type field =
  { key : string
  ; label : string
  ; operators : operator list
  ; default_operator : string option
      (** The operator used when the field is chosen and none is named. *)
  ; group : string option
      (** The heading the field is listed under in the typeahead. *)
  ; description : string option
  ; typeahead_aliases : string list
      (** Other strings that find this field in the typeahead. *)
  ; typeahead_min_query_length : int option
  ; is_value_match_allowed : bool
      (** Whether the field may be found by the value the user types. *)
  }

(** What the component is configured with: the fields, and which of them is the one that
    searches the content. *)
type config =
  { name : string
  ; fields : field list
  ; content_search_field_key : string option
  }

(** What happened to the filters. Upstream's [PowerSearchChangeType]. *)
type change_type =
  | Add
  | Edit
  | Remove

(** The size of the field, matching the house [Tokenizer]'s and upstream's
    PowerSearch, whose sizes are the same three. *)
type size = Tokenizer.size = Sm | Md | Lg

(** The status of the field, matching the house [Tokenizer]. *)
type status = Input_types.status =
  { type_ : Field_status.type_
  ; message : string option
  }

(** Where a status message is placed, matching the house [Tokenizer]. *)
type status_variant = Tokenizer.status_variant = Attached | Detached | Tooltip

(** How the chips behave when there are more of them than fit, matching the
    house [Tokenizer]. *)
type token_overflow_behavior = Tokenizer.overflow_behavior =
  | Wrap
  | Unfocused_inline
  | Unfocused_layer

(** The field with this key, if there is one. *)
val get_field : config -> string -> field option

(** The operator with this key on this field, if there is one. *)
val get_operator : config -> string -> string -> operator option

(** The operator a field uses when none is named: its [default_operator] if it has one, and
    otherwise the first of its operators. Upstream's [getDefaultOperator]. *)
val get_default_operator : config -> string -> operator option

(** The operator value's kind, as the short name upstream uses in its type strings. *)
val operator_value_type : operator_value -> string

(** The filter value's kind, as the short name upstream uses in its type strings. *)
val filter_value_type : filter_value -> string

(** The unit's name, as upstream writes it: "second", "minute", "hour", "day", "week",
    "month", "year". *)
val relative_unit_name : relative_unit -> string

(** The unit a name stands for, if it is one of the seven. *)
val relative_unit_of_name : string -> relative_unit option

(** The number of days a unit is worth, for the units that have a fixed length. A month is
    thirty days and a year is three hundred and sixty-five. The units shorter than a day
    have no whole-day length, and are zero. *)
val relative_unit_days : relative_unit -> int

(** The text a relative date is written as: the number of units, then the unit's first
    letter, as upstream writes "7d" for seven days. *)
val relative_date_to_string : relative_date -> string

(** The relative date a text stands for, if it is one. *)
val relative_date_of_string : string -> relative_date option

(** The text a filter's value is shown as — the part of the chip after the field and the
    operator.

    The rules are upstream's [formatFilterValue]: a number carries its units, an enum shows
    its label rather than its value, a list of one shows that one and a list of many shows
    a count, a date shows as a date and a relative date shows as it was written. The text
    is cut to [max_length] characters, which is upstream's [maxTokenLength]. *)
val format_filter_value
  :  ?max_length:int
  -> ?timezone_id:string
  -> config
  -> operator_value
  -> filter_value
  -> string

(** The search field. [view ~config ~filters ~on_change graph].

    [filters] is the application's list of filters and [on_change] is how the application
    hears about a change: the new list, what happened, and the index it happened at. The
    application decides what the new list is and hands it back; the component never keeps
    a list of its own.

    [label] is the field's accessible name ("Search"), [placeholder] is what the empty
    field says ("Search..."), [max_token_length] cuts the value in a chip (upstream's
    default is 40), [max_search_results] bounds the typeahead's results (10), and
    [popover_save_button_label] names the editor's button ("Apply"). *)
val view
  :  ?id:string
  -> ?attrs:Vdom.Attr.t list
  -> config:config
  -> filters:filter list Bonsai.t
  -> on_change:(filter list -> change_type -> int -> unit Ui_effect.t) Bonsai.t
  -> ?label:string
  -> ?is_label_hidden:bool
  -> ?placeholder:string
  -> ?has_auto_focus:bool
  -> ?has_clear:bool
  -> ?is_read_only:bool
  -> ?is_disabled:bool
  -> ?disabled_message:string
  -> ?start_icon:string
  -> ?size:size
  -> ?status:status
  -> ?status_variant:status_variant
  -> ?token_overflow_behavior:token_overflow_behavior
  -> ?menu_width:int
  -> ?max_token_length:int
  -> ?max_search_results:int
  -> ?popover_save_button_label:string
  -> ?timezone_id:string
  -> ?result_count:string
  -> ?end_content:Vdom.Node.t
  -> Bonsai.graph
  -> Vdom.Node.t Bonsai.t
