(* This library's own Field, bound before the opens below. Core defines a module named Field as
   well (first-class fields), so after [open! Core] the unqualified name refers to Core's — and
   this module would silently fail to compile against it. *)
module Field_ = Field

open! Core
open! Bonsai_web
open Js_of_ocaml

module Attr = Common.Attr

type date_range = Calendar.date_range

type size = Input_types.size =
  | Sm
  | Md
  | Lg

type status_type = Input_types.status_type =
  | Warning
  | Error
  | Success

type status_variant = Field_status.placement =
  | Attached
  | Detached
  | Tooltip

(* ------------------------------------------------------------------ model *)

(* The application owns the range; this component owns only what the person has
   typed and whether the calendar surface is open. The epochs are how a field is
   told to start again from the committed value: the input is keyed by them, so
   a new epoch is a new element, and a new element shows the committed text
   rather than the draft that could not be read. *)
type model =
  { is_open : bool
  ; start_draft : string option
  ; end_draft : string option
  ; start_epoch : int
  ; end_epoch : int
  }

let initial_model =
  { is_open = false
  ; start_draft = None
  ; end_draft = None
  ; start_epoch = 0
  ; end_epoch = 0
  }

(* ------------------------------------------------------------------ dates *)

(* The default reading: ISO, with the slashes some keyboards produce. A string
   that is not a date is [None], and the field reverts rather than guessing. *)
let default_parse_date text =
  let text = String.strip text in
  let text = String.concat ~sep:"-" (String.split_on_chars ~on:['/'] text) in
  match String.split_on_chars ~on:['-'] text with
  | [ year; month; day ] ->
    (match Int.of_string_opt year, Int.of_string_opt month, Int.of_string_opt day with
     | Some year, Some month, Some day ->
       (match Plain_date.create ~year ~month ~day with
        | date -> Some date
        | exception Invalid_argument _ -> None)
     | _ -> None)
  | _ -> None
  ;;

(* A day the fields and the calendar both accept. *)
let date_is_allowed ~min_date ~max_date ~date_constraints date =
  let in_window =
    (match min_date with
     | Some min_date -> not (Plain_date.is_before date min_date)
     | None -> true)
    && (match max_date with
        | Some max_date -> not (Plain_date.is_after date max_date)
        | None -> true)
  in
  in_window && List.for_all date_constraints ~f:(fun f -> f date)
;;

(* The span of a range in days, both endpoints included: a one-day range spans
   one day. This is the same counting the calendar uses. *)
let span_days start_date end_date = Plain_date.diff_days end_date start_date + 1

let span_is_allowed ~min_range_span ~max_range_span start_date end_date =
  let span = span_days start_date end_date in
  span >= min_range_span
  && (match max_range_span with
      | Some max_range_span -> span <= max_range_span
      | None -> true)
;;

let size_class = function
  | Sm -> "astryx-date-range-input--sm"
  | Md -> "astryx-date-range-input--md"
  | Lg -> "astryx-date-range-input--lg"
;;

let button_size = function
  | Sm -> Button.Sm
  | Md -> Button.Md
  | Lg -> Button.Lg
;;

let icon_size = function
  | Sm -> Icon.Sm
  | Md -> Icon.Md
  | Lg -> Icon.Lg
;;

let view
      ?id
      ?(attrs = [])
      ~label
      ?(is_label_hidden = false)
      ?description
      ?(is_optional = false)
      ?(is_required = false)
      ?optionality
      ?(is_disabled = false)
      ?disabled_message
      ?(is_loading = false)
      ?min
      ?max
      ?(date_constraints = [])
      ?(min_range_span = 1)
      ?(max_range_span = None)
      ?(has_clear = false)
      ?(start_placeholder = "Start date")
      ?(end_placeholder = "End date")
      ?format_date
      ?parse_date
      ?(size = Md)
      ?status
      ?(status_variant = Attached)
      ?width
      ?(locale = "en")
      ?(number_of_months = 1)
      ?(week_starts_on = 0)
      ~value
      ~on_change
      graph
  : Vdom.Node.t Bonsai.t =
  let id = Option.value id ~default:"astryx-date-range-input" in
  let locale = locale in
  (* The house cannot read its own long form back, so the display and the
     reading are two separate hooks: the display writes, the reading reads. *)
  let format_date =
    Option.value format_date ~default:(fun date -> Plain_date.format_shared ~locale date `Date)
  in
  let parse_date = Option.value parse_date ~default:default_parse_date in
  let date_constraints = date_constraints in
  let min_range_span = min_range_span in
  let max_range_span = max_range_span in
  let start_placeholder = start_placeholder in
  let end_placeholder = end_placeholder in
  let is_disabled = is_disabled in
  let is_loading = is_loading in
  let has_clear = has_clear in
  let is_label_hidden = is_label_hidden in
  let is_optional = is_optional in
  let is_required = is_required in
  let status_variant = status_variant in
  let size = size in
  (* The component's own state, and the setter that changes it. *)
  let model, set_model = Bonsai.state' initial_model graph in
  let set_model_f = Bonsai.map set_model ~f:(fun f -> f) in
  (* What the application said: the range it holds and the way it hears about a
     new one. *)
  let externals =
    Bonsai.map2 value on_change ~f:(fun value on_change -> (value, on_change))
  in
  let with_model = Bonsai.map2 model externals ~f:(fun model ext -> (model, ext)) in
  let all =
    Bonsai.map2 with_model set_model_f ~f:(fun (model, ext) set -> (model, ext, set))
  in
  (* The calendar surface is the house calendar in range mode: it is built here,
     off the graph, because a component cannot be built inside a map. *)
  let calendar_value =
    Bonsai.map value ~f:(fun range ->
        Option.map range ~f:(fun (range : date_range) -> Calendar.Date_range range))
  in
  let calendar_on_change =
    Bonsai.map2 on_change set_model_f ~f:(fun on_change set ->
        fun (selection : Calendar.selection) ->
          match selection with
          | Calendar.Date_range range ->
            (* A range picked in the calendar is the whole range, so the fields
               go back to showing the committed value and the surface closes. *)
            Effect.Many
              [ on_change (Some range)
              ; set (fun model ->
                  { is_open = false
                    ; start_draft = None
                    ; end_draft = None
                    ; start_epoch = model.start_epoch + 1
                    ; end_epoch = model.end_epoch + 1
                  })
              ]
          | Calendar.Single_date _ -> Effect.Ignore)
  in
  let calendar_node =
    Calendar.view
      ~id:(id ^ "-calendar")
      ~mode:Calendar.Range
      ~value:calendar_value
      ~on_change:calendar_on_change
      ?min
      ?max
      ~date_constraints
      ~max_range_span
      ~min_range_span
      ~number_of_months
      ~week_starts_on
      ~locale
      graph
  in
  Bonsai.map2 all calendar_node ~f:(fun (model, ext, set) calendar ->
      let value, on_change = ext in
      (* The committed value, as text. The fields show this, so a draft that
         cannot be read is replaced by it. *)
      (* The committed range as text, for the fields to show, and as dates, for
         the commit logic to reason about. *)
      let committed_start_text =
        match value with
        | Some range -> Some (format_date range.start_date)
        | None -> None
      in
      let committed_end_text =
        match value with
        | Some range -> Some (format_date range.end_date)
        | None -> None
      in
      let committed_start =
        match value with
        | Some range -> Some range.start_date
        | None -> None
      in
      let committed_end =
        match value with
        | Some range -> Some range.end_date
        | None -> None
      in
      let start_text = Option.value committed_start_text ~default:"" in
      let end_text = Option.value committed_end_text ~default:"" in
      (* What the fields point at with aria-describedby: only what is really
         rendered, because a dangling reference is announced as nothing at best. *)
      let status_message =
        match status with
        | Some { Input_types.message = Some message; _ } when not (String.is_empty message) ->
          Some message
        | _ -> None
      in
      let described_by =
        List.filter_opt
          [ (if Option.is_some description then Some (id ^ "-desc") else None)
          ; Option.map status_message ~f:(fun _ -> id ^ "-status")
          ; (match disabled_message with
             | Some _ when is_disabled -> Some (id ^ "-reason")
             | _ -> None)
          ]
        |> String.concat ~sep:" "
      in
      let described_by_attr =
        if String.is_empty described_by then [] else [ Vdom.Attr.create "aria-describedby" described_by ]
      in
      (* The other end of the range: what is typed in the other field, else the
         committed end. A half-typed range waits for its other half. *)
      let other_end ~draft ~committed =
        match draft with
        | Some text -> parse_date text
        | None -> committed
      in
      let commit ~field ~text ~other_draft ~other_committed =
        match parse_date text with
        | None ->
          (* The text cannot be read: the field goes back to the committed value. *)
          set (fun model ->
              match field with
              | `Start -> { model with start_draft = None; start_epoch = model.start_epoch + 1 }
              | `End -> { model with end_draft = None; end_epoch = model.end_epoch + 1 })
        | Some date ->
          if
            not
              (date_is_allowed
                 ~min_date:min
                 ~max_date:max
                 ~date_constraints
                 date)
          then
            set (fun model ->
                match field with
                | `Start -> { model with start_draft = None; start_epoch = model.start_epoch + 1 }
                | `End -> { model with end_draft = None; end_epoch = model.end_epoch + 1 })
          else
            match other_end ~draft:other_draft ~committed:other_committed with
            | None ->
              (* A valid day on its own: keep it until the other end is typed. *)
              set (fun model ->
                  match field with
                  | `Start -> { model with start_draft = Some text }
                  | `End -> { model with end_draft = Some text })
            | Some other ->
              if not (Plain_date.is_before date other)
              then
                (* The range would be unordered, so it is not a range yet. *)
                set (fun model ->
                    match field with
                    | `Start -> { model with start_draft = None; start_epoch = model.start_epoch + 1 }
                    | `End -> { model with end_draft = None; end_epoch = model.end_epoch + 1 })
              else
                let start_date = date and end_date = other in
                if
                  not
                    (span_is_allowed
                       ~min_range_span
                       ~max_range_span
                       start_date
                       end_date)
                then
                  set (fun model ->
                      match field with
                      | `Start -> { model with start_draft = None; start_epoch = model.start_epoch + 1 }
                      | `End -> { model with end_draft = None; end_epoch = model.end_epoch + 1 })
                else
                  Effect.Many
                    [ on_change (Some { start_date; end_date })
                    ; set (fun model ->
                        { model with
                          start_draft = None
                        ; end_draft = None
                        ; start_epoch = model.start_epoch + 1
                        ; end_epoch = model.end_epoch + 1
                        })
                    ]
      in
      let start_input =
        let attrs =
          ([ Vdom.Attr.create "id" id
           ; Vdom.Attr.create "type" "text"
           ; Vdom.Attr.create "value" start_text
           ; Vdom.Attr.create "placeholder" start_placeholder
           ; Vdom.Attr.create "autocomplete" "off"
           ; Vdom.Attr.on_input (fun (_ : Dom_html.event Js.t) text ->
               set (fun model -> { model with start_draft = Some text }))
           ; Vdom.Attr.on_change (fun (_ : Dom_html.event Js.t) text ->
               commit
                 ~field:`Start
                 ~text
                 ~other_draft:model.end_draft
                 ~other_committed:committed_end)
           ]
           @ Attr.aria "label" "Start date"
           @ described_by_attr
           @ (if is_disabled then Attr.aria "disabled" "true" else [])
           @ (if is_disabled || is_loading then [ Vdom.Attr.create "readonly" "readonly" ] else [])
           @ Attr.class_ [ "astryx-date-range-input__input" ])
        in
        Vdom.Node.input ~key:("start-" ^ string_of_int model.start_epoch) ~attrs ()
      in
      let end_input =
        let attrs =
          ([ Vdom.Attr.create "id" (id ^ "-end")
           ; Vdom.Attr.create "type" "text"
           ; Vdom.Attr.create "value" end_text
           ; Vdom.Attr.create "placeholder" end_placeholder
           ; Vdom.Attr.create "autocomplete" "off"
           ; Vdom.Attr.on_input (fun (_ : Dom_html.event Js.t) text ->
               set (fun model -> { model with end_draft = Some text }))
           ; Vdom.Attr.on_change (fun (_ : Dom_html.event Js.t) text ->
               commit
                 ~field:`End
                 ~text
                 ~other_draft:model.start_draft
                 ~other_committed:committed_start)
           ]
           @ Attr.aria "label" "End date"
           @ described_by_attr
           @ (if is_disabled then Attr.aria "disabled" "true" else [])
           @ (if is_disabled || is_loading then [ Vdom.Attr.create "readonly" "readonly" ] else [])
           @ Attr.class_ [ "astryx-date-range-input__input" ])
        in
        Vdom.Node.input ~key:("end-" ^ string_of_int model.end_epoch) ~attrs ()
      in
      let separator =
        Vdom.Node.span
          ~attrs:(Attr.class_ [ "astryx-date-range-input__separator" ] @ Attr.aria "hidden" "true")
          [ Vdom.Node.text "\xe2\x80\x93" ]
      in
      let spinner =
        if is_loading
        then
          [ Vdom.Node.span
              ~attrs:(Attr.class_ [ "astryx-spinner" ] @ Attr.aria "hidden" "true")
              []
          ]
        else []
      in
      (* The reason a disabled field is disabled, said once, where a screen
         reader can read it with the field. *)
      let reason =
        match disabled_message with
        | Some message when is_disabled ->
          [ Vdom.Node.span
              ~attrs:
                (Attr.class_ [ "astryx-visually-hidden" ]
                @ [ Vdom.Attr.create "id" (id ^ "-reason") ])
              [ Vdom.Node.text message ]
          ]
        | _ -> []
      in
      let clear_button =
        if (not has_clear) || Option.is_none value
        then []
        else
          [ Button.view
              ~label:"Clear dates"
              ~variant:Button.Ghost
              ~size:(button_size size)
              ~is_icon_only:true
              ~icon:(Icon.view ~name:"close" ~size:(icon_size size) ())
              ~on_click:(fun (_ : Dom_html.mouseEvent Js.t) ->
                  Effect.Many
                    [ on_change None
                    ; set (fun model ->
                        { model with
                          start_draft = None
                        ; end_draft = None
                        ; start_epoch = model.start_epoch + 1
                        ; end_epoch = model.end_epoch + 1
                        })
                    ])
              []
          ]
      in
      let trigger =
        Button.view
          ~label:"Choose dates"
          ~variant:Button.Secondary
          ~size:(button_size size)
          ~is_icon_only:true
          ~icon:(Icon.view ~name:"calendar" ~size:(icon_size size) ())
          ~is_disabled
          []
      in
      let popover =
        Popover.view
          ~id:(id ^ "-popover")
          ~label:"Choose dates"
          ~close_button_label:"Close calendar"
          ~is_modal:false
          ~placement:Popover.Below
          ~alignment:Popover.Align_start
          ~trigger
          ~content:
            (Vdom.Node.div
               ~attrs:(Attr.class_ [ "astryx-date-range-input__calendar" ])
               [ calendar ])
          ~is_open:model.is_open
          ~on_open_change:(fun is_open -> set (fun model -> { model with is_open }))
          ()
      in
      let group =
        Vdom.Node.div
          ~attrs:
            (Attr.class_ [ "astryx-date-range-input__group" ]
            @ Attr.role "group"
            @ Attr.aria "labelledby" (id ^ "-label"))
          ([ start_input; separator; end_input ] @ spinner @ [ popover ] @ clear_button @ reason)
      in
      let field =
        Field_.view
          ~label
          ~input_id:id
          ~label_id:(id ^ "-label")
          ~is_group_label:true
          ~is_label_hidden
          ?description
          ~is_optional
          ~is_required
          ?optionality
          ~is_disabled
          ?status
          ~status_variant
          ?width
          ~children:[ group ]
          ()
      in
      Vdom.Node.div
        ~attrs:
          (Attr.class_ [ "astryx-date-range-input"; size_class size ]
          @ Attr.data "component" "DateRangeInput"
          @ attrs)
        [ field ])
;;
