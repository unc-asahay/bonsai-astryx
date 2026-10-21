open! Core
open! Bonsai_web
open! Js_of_ocaml

module Attr = Common.Attr

(* ------------------------------------------------------------------ the type model *)

type operator_value =
  | Empty
  | String of
      { search_source : (string -> string list) option
      ; is_arbitrary_string_allowed : bool
      }
  | String_list of
      { search_source : (string -> string list) option
      ; is_arbitrary_string_allowed : bool
      ; tokenization : tokenization option
      }
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
  | Date_relative of
      { is_past_allowed : bool
      ; is_future_allowed : bool
      }
  | Date_range of
      { interval_date_presets : date_range_preset list
      ; relative_date_presets : relative_date_preset list
      }
  | Enum of enum_item list
  | Enum_list of enum_item list
  | Entity_list of
      { search_source : (string -> string list) option
      ; is_arbitrary_string_allowed : bool
      ; tokenization : tokenization option
      }
  | Custom of { get_string : string -> string }
  | Nested

and tokenization =
  { regex : string option
  ; sort : bool
  }

and enum_item =
  { value : string
  ; label : string
  }

and relative_date =
  { back_value : int
  ; unit : relative_unit
  }

and relative_unit =
  | Second
  | Minute
  | Hour
  | Day
  | Week
  | Month
  | Year

and date_range_part =
  | Now
  | Absolute of string
  | Relative of relative_date

and date_time_range =
  { start : date_range_part
  ; end_ : date_range_part
  }

and date_range_preset =
  { label : string
  ; value : date_time_range
  }

and relative_date_preset =
  { label : string
  ; value : string
  }

type filter_value =
  | Value_empty
  | Value_string of string
  | Value_string_list of string list
  | Value_integer of int
  | Value_float of float
  | Value_time of string
  | Value_date_absolute of string
  | Value_date_relative of string
  | Value_date_range of date_time_range
  | Value_enum of string
  | Value_enum_list of string list
  | Value_entity_list of entity list
  | Value_custom of string
  | Value_nested of filter list

and entity =
  { id : string
  ; label : string
  ; photo : string option
  }

and filter =
  { field : string
  ; operator : string
  ; value : filter_value
  ; is_read_only : bool
  }

type operator =
  { key : string
  ; label : string
  ; value : operator_value
  }

type field =
  { key : string
  ; label : string
  ; operators : operator list
  ; default_operator : string option
  ; group : string option
  ; description : string option
  ; typeahead_aliases : string list
  ; typeahead_min_query_length : int option
  ; is_value_match_allowed : bool
  }

type config =
  { name : string
  ; fields : field list
  ; content_search_field_key : string option
  }

type change_type =
  | Add
  | Edit
  | Remove

type size = Tokenizer.size = Sm | Md | Lg

type status = Input_types.status =
  { type_ : Field_status.type_
  ; message : string option
  }

type status_variant = Tokenizer.status_variant = Attached | Detached | Tooltip

type token_overflow_behavior = Tokenizer.overflow_behavior =
  | Wrap
  | Unfocused_inline
  | Unfocused_layer

(* ------------------------------------------------------------------ the helpers *)

let get_field config key =
  List.find config.fields ~f:(fun (field : field) -> String.equal field.key key)
;;

let get_operator config field_key operator_key =
  match get_field config field_key with
  | None -> None
  | Some field ->
    List.find field.operators ~f:(fun (operator : operator) ->
        String.equal operator.key operator_key)
;;

let get_default_operator config field_key =
  match get_field config field_key with
  | None -> None
  | Some field ->
    (match field.default_operator with
     | Some key -> get_operator config field_key key
     | None ->
       (match field.operators with
        | [] -> None
        | operator :: _ -> Some operator))
;;

let operator_value_type = function
  | Empty -> "empty"
  | String _ -> "string"
  | String_list _ -> "string_list"
  | Integer _ -> "integer"
  | Float _ -> "float"
  | Time _ -> "time"
  | Date_absolute _ -> "date_absolute"
  | Date_relative _ -> "date_relative"
  | Date_range _ -> "date_range"
  | Enum _ -> "enum"
  | Enum_list _ -> "enum_list"
  | Entity_list _ -> "entity_list"
  | Custom _ -> "custom"
  | Nested -> "nested"
;;

let filter_value_type = function
  | Value_empty -> "empty"
  | Value_string _ -> "string"
  | Value_string_list _ -> "string_list"
  | Value_integer _ -> "integer"
  | Value_float _ -> "float"
  | Value_time _ -> "time"
  | Value_date_absolute _ -> "date_absolute"
  | Value_date_relative _ -> "date_relative"
  | Value_date_range _ -> "date_range"
  | Value_enum _ -> "enum"
  | Value_enum_list _ -> "enum_list"
  | Value_entity_list _ -> "entity_list"
  | Value_custom _ -> "custom"
  | Value_nested _ -> "nested"
;;

let relative_unit_name = function
  | Second -> "second"
  | Minute -> "minute"
  | Hour -> "hour"
  | Day -> "day"
  | Week -> "week"
  | Month -> "month"
  | Year -> "year"
;;

let relative_unit_of_name = function
  | "second" | "seconds" -> Some Second
  | "minute" | "minutes" -> Some Minute
  | "hour" | "hours" -> Some Hour
  | "day" | "days" -> Some Day
  | "week" | "weeks" -> Some Week
  | "month" | "months" -> Some Month
  | "year" | "years" -> Some Year
  | _ -> None
;;

let relative_unit_days = function
  | Second -> 0
  | Minute -> 0
  | Hour -> 0
  | Day -> 1
  | Week -> 7
  | Month -> 30
  | Year -> 365
;;

(* The first letter of the unit, as upstream writes it: "7d" for seven days. *)
let relative_unit_letter = function
  | Second -> "s"
  | Minute -> "m"
  | Hour -> "h"
  | Day -> "d"
  | Week -> "w"
  | Month -> "M"
  | Year -> "y"
;;

let relative_date_to_string relative =
  Int.to_string relative.back_value ^ relative_unit_letter relative.unit
;;

let relative_date_of_string text =
  let text = String.strip text in
  let length = String.length text in
  if length < 2 then None
  else
    let number = String.sub text ~pos:0 ~len:(length - 1) in
    let letter = String.sub text ~pos:(length - 1) ~len:1 in
    match Int.of_string_opt number with
    | None -> None
    | Some back_value ->
      let unit =
        match letter with
        | "s" -> Some Second
        | "m" -> Some Minute
        | "h" -> Some Hour
        | "d" -> Some Day
        | "w" -> Some Week
        | "M" -> Some Month
        | "y" -> Some Year
        | _ -> None
      in
      (match unit with
       | None -> None
       | Some unit -> Some { back_value; unit })
;;

(* ------------------------------------------------------------------ the formatting *)

(* Upstream cuts the text at [maxLength] characters. *)
let truncate text max_length =
  if String.length text <= max_length then text
  else String.sub text ~pos:0 ~len:max_length ^ "…"
;;

(* Upstream's "N items", "N entities" and "N filters". *)
let count_text singular plural count =
  if Int.equal count 1
  then "1 " ^ singular
  else Int.to_string count ^ " " ^ plural
;;

let enum_label value values =
  match List.find values ~f:(fun (item : enum_item) -> String.equal item.value value) with
  | Some item -> item.label
  | None -> value
;;

let format_date_absolute iso =
  (* [Plain_date.of_iso] raises on a malformed date, and a date that came from
     the application may well be malformed. *)
  match
    try Some (Plain_date.of_iso iso) with Invalid_argument _ -> None
  with
  | None -> iso
  | Some date -> Plain_date.format_short date
;;

let format_filter_value ?(max_length = 40) ?timezone_id config operator_value filter_value =
  ignore (config : config);
  ignore (timezone_id : string option);
  let cut text = truncate text max_length in
  match filter_value with
  | Value_empty -> ""
  | Value_string value -> cut value
  | Value_string_list items ->
    (match items with
     | [] -> ""
     | [ single ] -> cut single
     | many ->
       let joined = String.concat ~sep:", " many in
       if String.length joined <= max_length
       then joined
       else count_text "item" "items" (List.length items))
  | Value_integer value ->
    let units =
      match operator_value with
      | Integer { units = Some units; _ } -> " " ^ units
      | _ -> ""
    in
    Int.to_string value ^ units
  | Value_float value ->
    let units =
      match operator_value with
      | Float { units = Some units; _ } -> " " ^ units
      | _ -> ""
    in
    Float.to_string value ^ units
  | Value_time value -> value
  | Value_date_absolute iso -> cut (format_date_absolute iso)
  | Value_date_relative value -> value
  | Value_date_range range ->
    ignore range;
    "date range"
  | Value_enum value ->
    let text =
      match operator_value with
      | Enum values -> enum_label value values
      | _ -> value
    in
    cut text
  | Value_enum_list items ->
    (match items with
     | [] -> ""
     | _ ->
       (match operator_value with
        | Enum_list values ->
          let labels = List.map items ~f:(fun value -> enum_label value values) in
          (match labels with
           | [ single ] -> cut single
           | many ->
             let joined = String.concat ~sep:", " many in
             if String.length joined <= max_length
             then joined
             else count_text "item" "items" (List.length many))
        | _ ->
          (match items with
           | [ single ] -> cut single
           | many -> count_text "item" "items" (List.length many))))
  | Value_entity_list entities ->
    (match entities with
     | [] -> ""
     | [ single ] -> cut single.label
     | many ->
       let joined = String.concat ~sep:", " (List.map many ~f:(fun (e : entity) -> e.label)) in
       if String.length joined <= max_length
       then joined
       else count_text "entity" "entities" (List.length many))
  | Value_custom value ->
    let text =
      match operator_value with
      | Custom { get_string; _ } -> get_string value
      | _ -> value
    in
    cut text
  | Value_nested filters -> count_text "filter" "filters" (List.length filters)
;;

(* ------------------------------------------------------------------ the ids *)

(* A chip's id says which filter it is, so the tokenizer's list of chips can be read back
   into the application's filters. *)
let filter_item_id index = "filter:" ^ Int.to_string index
;;

let filter_item_id_index id =
  if String.is_prefix ~prefix:"filter:" id then
    Int.of_string_opt (String.sub id ~pos:7 ~len:(String.length id - 7))
  else None
;;

(* A suggestion's id says which field it names, and — for the field that searches the
   content — the text the user had typed, which is the value the filter takes. The key and
   the text are separated by the first colon, so the text may itself hold colons. *)
let suggestion_item_id field_key query = "field:" ^ field_key ^ ":" ^ query
;;

let suggestion_item_id_parts id =
  if not (String.is_prefix ~prefix:"field:" id)
  then None
  else
    let rest = String.sub id ~pos:6 ~len:(String.length id - 6) in
    match String.split_on_chars ~on:[':'] rest with
    | [] -> None
    | key :: tail ->
      Some (key, String.concat ~sep:":" tail)
;;

(* ------------------------------------------------------------------ the chip's text *)

(* The chip reads as the field's label, then the operator, then the value. *)
let filter_display_text config filter ~max_length =
  let field_label =
    match get_field config filter.field with
    | Some field -> field.label
    | None -> filter.field
  in
  let operator_label =
    match get_operator config filter.field filter.operator with
    | Some operator -> if String.equal operator.label "" then "" else ": " ^ operator.label
    | None -> ""
  in
  let value_text =
    match get_operator config filter.field filter.operator with
    | Some operator ->
      format_filter_value config operator.value filter.value ~max_length
    | None -> ""
  in
  if String.equal value_text ""
  then field_label ^ operator_label
  else field_label ^ operator_label ^ " " ^ value_text
;;

(* ------------------------------------------------------------------ the editor *)

(* The editor holds the value being written, and the operator it is written for. The
   operator may be changed: a field may be compared in more than one way. *)
type editing =
  | Idle
  | Adding of
      { field_key : string
      ; operator_key : string option
      }
  | Editing_filter of
      { index : int
      ; field_key : string
      ; operator_key : string
      }

(* The value the editor starts with, for the kind of value it is editing. *)
let initial_value_for operator_value =
  match operator_value with
  | Empty -> Value_empty
  | String _ -> Value_string ""
  | String_list _ -> Value_string_list []
  | Integer _ -> Value_integer 0
  | Float _ -> Value_float 0.0
  | Time _ -> Value_time ""
  | Date_absolute _ -> Value_date_absolute ""
  | Date_relative _ -> Value_date_relative ""
  | Date_range _ ->
    Value_date_range
      { start = Now
      ; end_ = Now
      }
  | Enum _ -> Value_enum ""
  | Enum_list _ -> Value_enum_list []
  | Entity_list _ -> Value_entity_list []
  | Custom _ -> Value_custom ""
  | Nested -> Value_nested []
;;

(* The text the editor's field shows for a value of the given kind. *)
let value_to_text = function
  | Value_empty -> ""
  | Value_string value -> value
  | Value_string_list items -> String.concat ~sep:", " items
  | Value_integer value -> Int.to_string value
  | Value_float value -> Float.to_string value
  | Value_time value -> value
  | Value_date_absolute value -> value
  | Value_date_relative value -> value
  | Value_date_range range ->
    let part (p : date_range_part) =
      match p with
      | Now -> "now"
      | Absolute iso -> iso
      | Relative relative -> relative_date_to_string relative
    in
    part range.start ^ " - " ^ part range.end_
  | Value_enum value -> value
  | Value_enum_list items -> String.concat ~sep:", " items
  | Value_entity_list entities ->
    String.concat ~sep:", " (List.map entities ~f:(fun (e : entity) -> e.label))
  | Value_custom value -> value
  | Value_nested _ -> ""
;;

(* The value the editor's field produces, for the kind of value it is editing. *)
let text_to_value operator_value text =
  let text = String.strip text in
  let split_list text =
    text
    |> String.split_on_chars ~on:[',']
    |> List.map ~f:String.strip
    |> List.filter ~f:(fun part -> not (String.equal part ""))
  in
  match operator_value with
  | Empty -> Value_empty
  | String _ -> Value_string text
  | String_list _ -> Value_string_list (split_list text)
  | Integer _ -> (
    match Int.of_string_opt text with
    | Some value -> Value_integer value
    | None -> Value_integer 0)
  | Float _ -> (
    match Float.of_string_opt text with
    | Some value -> Value_float value
    | None -> Value_float 0.0)
  | Time _ -> Value_time text
  | Date_absolute _ -> Value_date_absolute text
  | Date_relative _ -> Value_date_relative text
  | Date_range _ -> Value_date_range { start = Now; end_ = Now }
  | Enum _ -> Value_enum text
  | Enum_list _ -> Value_enum_list (split_list text)
  | Entity_list _ ->
    Value_entity_list
      (List.map (split_list text) ~f:(fun label -> { id = label; label; photo = None }))
  | Custom _ -> Value_custom text
  | Nested -> Value_nested []
;;

(* ------------------------------------------------------------------ the suggestions *)

(* A field is found by its label, by its aliases and by its description. Upstream
   matches the same three. *)
let field_matches field query =
  let query = String.lowercase (String.strip query) in
  if String.equal query "" then true
  else
    let haystacks =
      field.label
      :: field.typeahead_aliases
      @ (match field.description with Some text -> [ text ] | None -> [])
    in
    List.exists haystacks ~f:(fun text ->
        String.is_substring (String.lowercase text) ~substring:query)
;;

(* The fields the typeahead offers for a query. The content-search field is offered
   with the text that was typed, because that text is the value the filter takes. *)
let suggestions config query ~max_results =
  let query = String.strip query in
  let offered =
    List.filter_map
      config.fields
      ~f:(fun (field : field) ->
        let min_length = Option.value field.typeahead_min_query_length ~default:0 in
        if String.length query < min_length then None
        else if not (field_matches field query) then None
        else if
          (not field.is_value_match_allowed)
          && not (String.equal query "")
          && Option.is_none config.content_search_field_key
        then None
        else
          Some
            { Tokenizer.id = suggestion_item_id field.key query
            ; label = field.label
            })
  in
  (match offered with
   | [] -> []
   | _ ->
     if List.length offered <= max_results
     then offered
     else List.filteri offered ~f:(fun index _ -> index < max_results))
;;

(* ------------------------------------------------------------------ the draft *)

(* What the editor is holding: the value being written and the operator it is written
   for. The key says which edit the draft belongs to, so a draft left over from the last
   edit is not mistaken for this one. *)
type draft =
  { key : string
  ; field_key : string
  ; operator_key : string
  ; value : filter_value
  }

let editing_key = function
  | Idle -> ""
  | Adding { field_key; operator_key } ->
    "add:" ^ field_key ^ ":" ^ (Option.value operator_key ~default:"")
  | Editing_filter { index; field_key; operator_key } ->
    "edit:" ^ Int.to_string index ^ ":" ^ field_key ^ ":" ^ operator_key
;;

(* ------------------------------------------------------------------ the view *)

let view
    ?(id = "astryx-power-search")
    ?(attrs = [])
    ~config
    ~filters
    ~on_change
    ?label
    ?(is_label_hidden = true)
    ?(placeholder = "Search…")
    ?(has_auto_focus = false)
    ?(has_clear = true)
    ?(is_read_only = false)
    ?(is_disabled = false)
    ?disabled_message
    ?start_icon
    ?(size = Md)
    ?status
    ?(status_variant = Attached)
    ?token_overflow_behavior
    ?menu_width
    ?(max_token_length = 40)
    ?(max_search_results = 10)
    ?(popover_save_button_label = "Apply")
    ?(timezone_id = "")
    ?result_count
    ?end_content
    graph =
  let label = Option.value label ~default:"Search" in
  (* The port has no time zone, so the time zone is accepted and not used. *)
  ignore timezone_id;
  let save_label = popover_save_button_label in
  (* What the editor is doing, if anything. *)
  let editing, set_editing = Bonsai.state' Idle graph in
  (* What the editor is holding. *)
  let draft, set_draft = Bonsai.state' (None : draft option) graph in
  (* The chips: the filters the application holds. *)
  let items =
    Bonsai.map filters ~f:(fun (filters : filter list) ->
        List.mapi filters ~f:(fun index (filter : filter) ->
            ({ Tokenizer.id = filter_item_id index
             ; label =
                 filter_display_text config filter ~max_length:max_token_length
             }
              : Tokenizer.item)))
  in
  (* The typeahead over the fields. *)
  let source =
    { Tokenizer.search =
        (fun query -> suggestions config query ~max_results:max_search_results)
    ; bootstrap = suggestions config "" ~max_results:max_search_results
    }
  in
  (* ------------------------------------------------------- the change handler *)
  let on_tokenizer_change =
    Bonsai.map3
      filters
      on_change
      set_editing
      ~f:(fun filters on_change set_editing (items : Tokenizer.item list) (change : Tokenizer.change) ->
        match change.type_ with
        | Tokenizer.Add ->
          (match change.item with
           | None -> Effect.Ignore
           | Some item ->
             (match suggestion_item_id_parts item.id with
              | None -> Effect.Ignore
              | Some (field_key, query) ->
                (match get_default_operator config field_key with
                 | None -> Effect.Ignore
                 | Some operator ->
                   let is_content_field =
                     match config.content_search_field_key with
                     | Some key -> String.equal key field_key
                     | None -> false
                   in
                   (match operator.value with
                    | Empty ->
                      let filter =
                        { field = field_key
                        ; operator = operator.key
                        ; value = Value_empty
                        ; is_read_only = false
                        }
                      in
                      on_change (filters @ [ filter ]) Add (List.length filters)
                    | _ ->
                      if is_content_field && not (String.equal query "")
                      then
                        let filter =
                          { field = field_key
                          ; operator = operator.key
                          ; value = Value_string query
                          ; is_read_only = false
                          }
                        in
                        on_change (filters @ [ filter ]) Add (List.length filters)
                      else
                        set_editing (fun _ ->
                            Adding
                              { field_key
                              ; operator_key = Some operator.key
                              })))))
        | Tokenizer.Remove ->
          (match change.item with
           | None -> Effect.Ignore
           | Some item ->
             (match filter_item_id_index item.id with
              | None -> Effect.Ignore
              | Some index ->
                (* A read-only filter stays: it is shown, but it is not removed. *)
                (match List.nth filters index with
                 | Some (filter : filter) when filter.is_read_only -> Effect.Ignore
                 | _ ->
                   let new_filters =
                     List.filter_map items ~f:(fun (item : Tokenizer.item) ->
                         match filter_item_id_index item.id with
                         | None -> None
                         | Some at -> List.nth filters at)
                   in
                   on_change new_filters Remove index)))
        | Tokenizer.Create | Tokenizer.Reorder -> Effect.Ignore)
  in
  (* ------------------------------------------------------- the editor's draft *)
  (* The draft that belongs to the edit being made, or a fresh one. *)
  let current_draft =
    Bonsai.map2 editing draft ~f:(fun editing draft ->
        let key = editing_key editing in
        match draft with
        | Some saved when String.equal saved.key key -> Some saved
        | _ ->
          (match editing with
           | Idle -> None
           | Adding { field_key; operator_key } ->
             let operator =
               match operator_key with
               | Some key -> get_operator config field_key key
               | None -> get_default_operator config field_key
             in
             (match operator with
              | None -> None
              | Some operator ->
                Some
                  { key
                  ; field_key
                  ; operator_key = operator.key
                  ; value = initial_value_for operator.value
                  })
           | Editing_filter { field_key; operator_key; _ } ->
             (match get_operator config field_key operator_key with
              | None -> None
              | Some operator ->
                Some
                  { key
                  ; field_key
                  ; operator_key = operator.key
                  ; value = initial_value_for operator.value
                  })))
  in
  (* ------------------------------------------------------- the editor *)
  (* The editor's controls are built where the draft and the setter are both in
     hand: that is what makes their handlers plain functions rather than trees.
     The value's control is the one that is not plain — the house's text field
     is a tree — so it is built separately and the render picks between it and
     the list of an enum's values. *)
  let kind_of_draft draft =
    match get_operator config draft.field_key draft.operator_key with
    | Some operator -> operator.value
    | None -> Empty
  in
  let is_enum_kind = function
    | Enum _ -> true
    | _ -> false
  in
  let text_control =
    Text_input.view
      ~id:(id ^ "-value")
      ~label:"Value"
      ~value:
        (Bonsai.map current_draft ~f:(fun draft ->
             match draft with
             | Some draft -> value_to_text draft.value
             | None -> ""))
      ~on_change:
        (Bonsai.map2
           set_draft
           current_draft
           ~f:(fun set_draft draft ->
             fun text ->
               set_draft (fun _ ->
                   match draft with
                   | Some draft ->
                     Some { draft with value = text_to_value (kind_of_draft draft) text }
                   | None -> None)))
      ()
  in
  let enum_control =
    Bonsai.map2
      current_draft
      set_draft
      ~f:(fun draft set_draft ->
        match draft with
        | None -> Vdom.Node.div ~attrs:[] []
        | Some draft ->
          (match kind_of_draft draft with
           | Enum values ->
             let selected =
               match draft.value with
               | Value_enum chosen -> chosen
               | _ -> ""
             in
             Vdom.Node.create
               "select"
               ~attrs:
                 [ Vdom.Attr.create "id" (id ^ "-value")
                 ; Vdom.Attr.create "aria-label" "Value"
                 ; Vdom.Attr.create "data-astryx-power-search-value" selected
                 ; Vdom.Attr.on_input (fun _ chosen ->
                     set_draft (fun _ -> Some { draft with value = Value_enum chosen }))
                 ]
               (List.map
                  values
                  ~f:(fun (item : enum_item) ->
                    Vdom.Node.create
                      "option"
                      ~attrs:[ Vdom.Attr.create "value" item.value ]
                      [ Vdom.Node.text item.label ]))
           | _ -> Vdom.Node.div ~attrs:[] []))
  in
  let value_control =
    Bonsai.map2
      (Bonsai.map2 text_control current_draft ~f:(fun text draft -> (text, draft)))
      enum_control
      ~f:(fun (text, draft) enum ->
        match draft with
        | Some draft when is_enum_kind (kind_of_draft draft) -> enum
        | _ -> text)
  in
  let editor_node =
    let base =
      Bonsai.map2
        (Bonsai.map2
           (Bonsai.map2 editing current_draft ~f:(fun editing draft -> (editing, draft)))
           filters
           ~f:(fun (editing, draft) filters -> (editing, draft, filters)))
        value_control
        ~f:(fun (editing, draft, filters) value -> (editing, draft, filters, value))
    in
    let handlers =
      Bonsai.map2
        set_draft
        (Bonsai.map2
           on_change
           set_editing
           ~f:(fun on_change set_editing -> (on_change, set_editing)))
        ~f:(fun set_draft (on_change, set_editing) -> (set_draft, on_change, set_editing))
    in
    Bonsai.map2
      base
      handlers
      ~f:(fun (editing, draft, filters, value) (set_draft, on_change, set_editing) ->
        match editing with
        | Idle -> Vdom.Node.div ~attrs:[] []
        | Adding { field_key; _ } | Editing_filter { field_key; _ } ->
          (match draft with
           | None -> Vdom.Node.div ~attrs:[] []
           | Some draft ->
             let field = get_field config field_key in
             let operators =
               match field with
               | None -> []
               | Some field -> field.operators
             in
             let operator_select =
               Vdom.Node.create
                 "select"
                 ~attrs:
                   [ Vdom.Attr.create "id" (id ^ "-operator")
                   ; Vdom.Attr.create "aria-label" "Operator"
                   ; Vdom.Attr.create
                       "data-astryx-power-search-operator"
                       draft.operator_key
                   ; Vdom.Attr.on_input (fun _ chosen ->
                       set_draft (fun _ ->
                           match get_operator config field_key chosen with
                           | None -> None
                           | Some operator ->
                             Some
                               { draft with
                                 operator_key = chosen
                               ; value = initial_value_for operator.value
                               }))
                   ]
                 (List.map
                    operators
                    ~f:(fun (operator : operator) ->
                      Vdom.Node.create
                        "option"
                        ~attrs:[ Vdom.Attr.create "value" operator.key ]
                        [ Vdom.Node.text operator.label ]))
             in
             let apply =
               fun (_ : Dom_html.mouseEvent Js.t) ->
                 match editing with
                 | Idle -> Effect.Ignore
                 | Adding { field_key; operator_key } ->
                   let operator_key =
                     Option.value operator_key ~default:draft.operator_key
                   in
                   let filter =
                     { field = field_key
                     ; operator = operator_key
                     ; value = draft.value
                     ; is_read_only = false
                     }
                   in
                   Effect.Many
                     [ on_change (filters @ [ filter ]) Add (List.length filters)
                     ; set_editing (fun _ -> Idle)
                     ]
                 | Editing_filter { index; operator_key; _ } ->
                   let new_filters =
                     List.mapi filters ~f:(fun at (filter : filter) ->
                         if Int.equal at index
                         then
                           { filter with
                             operator = operator_key
                           ; value = draft.value
                           }
                         else filter)
                   in
                   Effect.Many
                     [ on_change new_filters Edit index
                     ; set_editing (fun _ -> Idle)
                     ]
             in
             let cancel = fun (_ : Dom_html.mouseEvent Js.t) -> set_editing (fun _ -> Idle) in
             Vdom.Node.div
               ~attrs:
                 (Attr.class_ [ "astryx-power-search__editor" ]
                 @ Attr.data "editor" "true")
               [ Vdom.Node.div
                   ~attrs:(Attr.class_ [ "astryx-power-search__editor-head" ])
                   [ Vdom.Node.text
                       (match field with
                        | Some field -> field.label
                        | None -> field_key)
                   ]
               ; Vdom.Node.div
                   ~attrs:(Attr.class_ [ "astryx-power-search__editor-operator" ])
                   [ operator_select ]
               ; Vdom.Node.div
                   ~attrs:(Attr.class_ [ "astryx-power-search__editor-value" ])
                   [ value ]
               ; Vdom.Node.div
                   ~attrs:(Attr.class_ [ "astryx-power-search__editor-actions" ])
                   [ Vdom.Node.div
                       ~attrs:(Attr.class_ [ "astryx-power-search__editor-cancel" ])
                       [ Button.view ~label:"Cancel" ~variant:Button.Ghost ~on_click:cancel [] ]
                   ; Vdom.Node.div
                       ~attrs:(Attr.class_ [ "astryx-power-search__editor-apply" ])
                       [ Button.view ~label:save_label ~on_click:apply [] ]
                   ] ]))
  in
  (* ------------------------------------------------------- the end lane *)
  let end_content =
    match (result_count, end_content) with
    | Some count, None ->
      Some
        (Vdom.Node.span
           ~attrs:(Attr.class_ [ "astryx-power-search__result-count" ])
           [ Vdom.Node.text count ])
    | Some count, Some node ->
      Some
        (Vdom.Node.div
           ~attrs:(Attr.class_ [ "astryx-power-search__end-lane" ])
           [ Vdom.Node.span
               ~attrs:(Attr.class_ [ "astryx-power-search__result-count" ])
               [ Vdom.Node.text count ]
           ; node ])
    | None, node -> node
  in
  (* ------------------------------------------------------- the field *)
  (* Clicking a chip opens the editor for that filter. A read-only filter is
     not editable, so the click does nothing. *)
  let on_item_click =
    if is_read_only || is_disabled
    then None
    else
      Some
        (Bonsai.map2
           set_editing
           filters
           ~f:(fun set_editing filters ->
             fun (item : Tokenizer.item) ->
               match filter_item_id_index item.id with
               | None -> Effect.Ignore
               | Some index ->
                 (match List.nth filters index with
                  | None -> Effect.Ignore
                  | Some (filter : filter) ->
                    if filter.is_read_only
                    then Effect.Ignore
                    else
                      set_editing (fun _ ->
                          Editing_filter
                            { index
                            ; field_key = filter.field
                            ; operator_key = filter.operator
                            }))))
  in
  let tokenizer =
    Tokenizer.view
      ~id:(id ^ "-field")
      ~label
      ~is_label_hidden
      ~placeholder
      ~has_auto_focus
      ~has_clear:(has_clear && not is_read_only)
      ~is_disabled
      ?disabled_message
      ?start_icon
      ?end_content
      ~size
      ?status
      ~status_variant
      ?token_overflow_behavior
      ?menu_width
      ~max_menu_items:max_search_results
      ~has_entries_on_focus:true
      ~value:items
      ~on_change:on_tokenizer_change
      ?on_item_click
      ~source
      graph
  in
  (* ------------------------------------------------------- the popover *)
  let is_open =
    Bonsai.map editing ~f:(fun editing ->
        match editing with
        | Idle -> false
        | Adding _ | Editing_filter _ -> true)
  in
  (* The popover's trigger and its content are plain nodes, so the trees are
     unwrapped before the popover is built. *)
  let trigger_of tokenizer =
    Vdom.Node.div
      ~attrs:(Attr.class_ [ "astryx-power-search__anchor" ])
      [ tokenizer ]
  in
  let open_handler =
    Bonsai.map2
      is_open
      (Bonsai.map
         set_editing
         ~f:(fun set_editing ->
           fun is_open ->
             if not is_open then set_editing (fun _ -> Idle) else Effect.Ignore))
      ~f:(fun is_open handler -> (is_open, handler))
  in
  let popover_node =
    Bonsai.map2
      (Bonsai.map2
         (Bonsai.map tokenizer ~f:trigger_of)
         editor_node
         ~f:(fun trigger content -> (trigger, content)))
      open_handler
      ~f:(fun (trigger, content) (is_open, handler) ->
        Popover.view
          ~id:(id ^ "-popover")
          ~label:"Filter value"
          ~role:Popover.No_role
          ~is_modal:false
          ~has_auto_focus:false
          ~has_light_dismiss:true
          ~has_escape_dismiss:true
          ~placement:Popover.Below
          ~alignment:Popover.Align_start
          ~trigger
          ~content
          ~is_open
          ~on_open_change:handler
          ())
  in
  (* The root is a tree of a node: the popover's node is unwrapped here, and
     the tree is the view's result. *)
  Bonsai.map2
    popover_node
    (Bonsai.return ())
    ~f:(fun popover () ->
      Vdom.Node.div
        ~attrs:
          (Attr.class_ [ "astryx-power-search" ]
          @ Attr.data "component" "PowerSearch"
          @ attrs)
        [ popover ])
;;
