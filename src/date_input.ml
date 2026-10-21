(* The library's own Field, bound before the opens below. Core defines a module
   named Field as well (first-class fields), so after [open! Core] the
   unqualified name refers to Core's — and this module would silently fail to
   compile against it. *)
module Field_ = Field

open! Core
open! Bonsai_web
open Js_of_ocaml

module Plain_date = Plain_date

(** The size of the date input, matching the house [Input_types.size]. *)
type size = Input_types.size = Sm | Md | Lg

(** The status of the date input, matching the house [Input_types.status]. *)
type status = Input_types.status

(** Where a status message is placed, matching the house field status. *)
type status_variant = Field_status.placement = Attached | Detached | Tooltip

(** How a committed date is written in the field. *)
type format =
  | Date
  | Date_long
  | Date_weekday
  | System_date
  | Custom of (Plain_date.t -> string)

(* ------------------------------------------------------------------ text *)

let js_property (ev : 'a) name : string =
  Js.to_string (Js.Unsafe.coerce (Js.Unsafe.get (Obj.magic ev : Js.Unsafe.any) name))
;;

let js_prevent_default (ev : 'a) : unit =
  ignore (Js.Unsafe.meth_call (Obj.magic ev : Js.Unsafe.any) "preventDefault" [||])
;;

let starts_with ~prefix text =
  let n = String.length prefix in
  let m = String.length text in
  if m < n then false else String.equal (String.sub text ~pos:0 ~len:n) prefix
;;

let all_digits text =
  let text = String.strip text in
  let rec loop index =
    if index >= String.length text then true
    else
      let c = Char.to_int text.[index] in
      c >= Char.to_int '0' && c <= Char.to_int '9' && loop (index + 1)
  in
  String.length text > 0 && loop 0
;;

let int_of_digits text = int_of_string (String.strip text)

(* Upstream asks Intl whether the locale puts the day before the month. We
   cannot ask Intl, so the house keeps the list of locales that do; everything
   else, including plain "en", is month-first. *)
let day_first_locales =
  [ "en-gb"; "en-ie"; "en-au"; "en-nz"; "en-in"; "en-ca"; "fr"; "de"; "it"; "es"; "pt"
  ; "nl"; "ru"; "uk"; "pl"; "cs"; "da"; "sv"; "no"; "fi"; "hu"; "ro"; "tr"; "ar"; "he"
  ; "id"; "vi"; "lt"; "lv"; "et"; "sl"; "hr"; "bg"; "el"
  ]
;;

let is_locale_day_first locale =
  let locale = String.lowercase locale in
  List.exists
    day_first_locales
    ~f:(fun candidate -> starts_with ~prefix:candidate locale)
;;

let month_number name =
  match String.lowercase (String.strip name) with
  | "january" | "jan" -> Some 1
  | "february" | "feb" -> Some 2
  | "march" | "mar" -> Some 3
  | "april" | "apr" -> Some 4
  | "may" -> Some 5
  | "june" | "jun" -> Some 6
  | "july" | "jul" -> Some 7
  | "august" | "aug" -> Some 8
  | "september" | "sep" | "sept" -> Some 9
  | "october" | "oct" -> Some 10
  | "november" | "nov" -> Some 11
  | "december" | "dec" -> Some 12
  | _ -> None
;;

(* A date is only made when it is a real day of a real month: [Plain_date.create]
   raises on an impossible one, and a field must not raise on what someone
   typed. *)
let make_date year month day =
  if year < 1 || month < 1 || month > 12 || day < 1 then None
  else if day > Plain_date.days_in_month year month then None
  else Some (Plain_date.create ~year ~month ~day)
;;

(* The words of the text, with commas and spaces both as separators. *)
let words text =
  let parts =
    text
    |> String.split_on_chars ~on:[',']
    |> List.concat_map ~f:(fun part -> String.split_on_chars ~on:[' '] part)
  in
  List.filter_map parts ~f:(fun word -> if String.equal word "" then None else Some word)
;;

(* "March 21, 2026" and "21 March 2026", with the month written out. *)
let parse_named ~year ~month_word ~day_word =
  match month_number month_word with
  | Some month when all_digits day_word -> make_date year month (int_of_digits day_word)
  | _ -> None
;;

let parse_date ~locale text =
  let text = String.strip text in
  if String.equal text "" then None
  else
    (* An ISO date: YYYY-M-D. It is unambiguous, so it is tried first. *)
    let iso =
      match String.split_on_chars ~on:['-'] text with
      | [ year; month; day ]
        when all_digits year && all_digits month && all_digits day
             && String.length (String.strip year) = 4 ->
        make_date
          (int_of_digits year)
          (int_of_digits month)
          (int_of_digits day)
      | _ -> None
    in
    match iso with
    | Some date -> Some date
    | None ->
      (* A month written out, with the year. *)
      let named =
        match words text with
        | [ first; second; third ]
          when all_digits third && String.length (String.strip third) = 4 ->
          let year = int_of_digits third in
          (match month_number first with
           | Some _ -> parse_named ~year ~month_word:first ~day_word:second
           | None -> parse_named ~year ~month_word:second ~day_word:first)
        | _ -> None
      in
      match named with
      | Some date -> Some date
      | None ->
        (* A numeric date: 3/21/2026 or 21/3/2026. Both separators have to be
           the same one, and the order follows the locale when the two fields
           are ambiguous. *)
        let numeric separator =
          match String.split_on_chars ~on:[ separator ] text with
          | [ first; second; year ]
            when all_digits first && all_digits second && all_digits year
                 && String.length (String.strip year) = 4 ->
            let first = int_of_digits first in
            let second = int_of_digits second in
            let year = int_of_digits year in
            if first > 12 && second <= 12 then make_date year second first
            else if second > 12 && first <= 12 then make_date year first second
            else if first > 12 && second > 12 then None
            else if is_locale_day_first locale then make_date year second first
            else make_date year first second
          | _ -> None
        in
        (match numeric '/' with
         | Some date -> Some date
         | None ->
           (match numeric '.' with
            | Some date -> Some date
            | None -> numeric '-'))
;;

(* --------------------------------------------------------------- writing *)

let format_date ~locale ~format date =
  match format with
  | Date -> Plain_date.format_short ~locale date
  | Date_long -> Plain_date.format_long ~locale date
  | Date_weekday -> Plain_date.format_short_with_weekday ~locale date
  | System_date -> Plain_date.to_iso date
  | Custom f -> f date
;;

(* ----------------------------------------------------------------- model *)

type model =
  { draft : string option  (** The text being typed, until it is committed. *)
  ; is_open : bool  (** Whether the calendar is open. *)
  ; epoch : int  (** Bumped to rebuild the field when its text must change. *)
  }

let initial_model = { draft = None; is_open = false; epoch = 0 }

(* ------------------------------------------------------------------ view *)

let view
  ?id
  ?(attrs = [])
  ~label
  ?(is_label_hidden = false)
  ?description
  ?(is_optional = false)
  ?(is_required = false)
  ?(is_disabled = false)
  ?disabled_message
  ?(is_loading = false)
  ?value
  ?on_change
  ?min
  ?max
  ?(date_constraints = [])
  ?placeholder
  ?(format = Date)
  ?(locale = "en")
  ?(number_of_months = 1)
  ?(week_starts_on = 0)
  ?(size = Md)
  ?status
  ?(status_variant = Attached)
  ?width
  graph
  =
  let id = Option.value id ~default:"astryx-date-input" in
  let value = Option.value value ~default:(Bonsai.return None) in
  let on_change =
    Option.value on_change ~default:(Bonsai.return (fun (_ : Plain_date.t option) -> Effect.Ignore))
  in
  let model, set_model = Bonsai.state' initial_model graph in
  let set_model_f = Bonsai.map set_model ~f:(fun f -> f) in
  let on_change_f = Bonsai.map on_change ~f:(fun f -> f) in
  let value_f = Bonsai.map value ~f:(fun f -> f) in
  (* The model's value, the setter, the committed date and the change
     callback, all as values rather than as trees. *)
  let ext =
    Bonsai.map3 model set_model_f value_f ~f:(fun model set value -> (model, set, value))
  in
  let ext =
    Bonsai.map2 ext on_change_f ~f:(fun (model, set, value) on_change ->
      (model, set, value, on_change))
  in
  (* A date the caller will accept: inside the bounds, and inside the
     constraints. *)
  let acceptable date =
    let within_bounds =
      match (min, max) with
      | None, None -> true
      | Some low, None -> not (Plain_date.is_before date low)
      | None, Some high -> not (Plain_date.is_after date high)
      | Some low, Some high ->
        (not (Plain_date.is_before date low)) && not (Plain_date.is_after date high)
    in
    within_bounds
    && List.for_all date_constraints ~f:(fun constraint_ -> constraint_ date)
  in
  let calendar_value =
    Bonsai.map value ~f:(fun value ->
      match value with
      | Some date -> Some (Calendar.Single_date date)
      | None -> None)
  in
  let calendar_node =
    Calendar.view
      ~id:(id ^ "-calendar")
      ~mode:Calendar.Single
      ~value:calendar_value
      ~on_change:
        (Bonsai.map on_change ~f:(fun on_change -> fun selection ->
           match selection with
           | Calendar.Single_date date -> on_change (Some date)
           | Calendar.Date_range _ -> Effect.Ignore))
      ?min
      ?max
      ~date_constraints
      ~number_of_months
      ~week_starts_on
      ~locale
      graph
  in
  Bonsai.map2 ext calendar_node ~f:(fun (model, set, value, on_change) calendar ->
      let button_size =
        match size with
        | Sm -> Button.Sm
        | Md -> Button.Md
        | Lg -> Button.Lg
      in
      let size_class =
        match size with
        | Sm -> "sm"
        | Md -> "md"
        | Lg -> "lg"
      in
      (* The text the field shows: the draft while it is being typed, and the
         committed date otherwise. *)
      let committed_text =
        match value with
        | Some date -> Some (format_date ~locale ~format date)
        | None -> None
      in
      let text =
        match model.draft with
        | Some draft -> draft
        | None -> Option.value committed_text ~default:""
      in
      let input_id = id ^ "-input" in
      (* The text is committed as it is typed, when it can be read; the draft
         stays in the field until the field is left or Enter is pressed. *)
      let commit_typed typed =
        match parse_date ~locale typed with
        | Some date when acceptable date -> on_change (Some date)
        | _ -> Effect.Ignore
      in
      (* The calendar opens from the field as well as from the button, so the
         field is the combobox: it says what it opens, and whether it is
         open. Upstream's DateInput does exactly this, and so does the house
         Date_time_input. *)
      let open_calendar () =
        if is_disabled || model.is_open then Effect.Ignore
        else
          set (fun _model ->
            { is_open = true
            ; draft = None
            ; epoch = _model.epoch + 1
            })
      in
      let close_calendar () =
        if not model.is_open then Effect.Ignore
        else
          set (fun _model ->
            { is_open = false
            ; draft = None
            ; epoch = _model.epoch + 1
            })
      in
      let input_attrs =
        ([ Vdom.Attr.create "id" input_id
         ; Vdom.Attr.create "type" "text"
         ; Vdom.Attr.create "value" text
         ; Vdom.Attr.create "autocomplete" "off"
         ; Vdom.Attr.role "combobox"
         ; Vdom.Attr.create "aria-haspopup" "dialog"
         ; Vdom.Attr.create "aria-expanded" (Bool.to_string model.is_open)
         ; Vdom.Attr.create "aria-autocomplete" "none"
         ; Vdom.Attr.create "placeholder" (Option.value placeholder ~default:"")
         ; Vdom.Attr.on_input (fun (_ : Dom_html.event Js.t) typed ->
              Effect.Many
                [ set (fun model -> { model with draft = Some typed })
                ; commit_typed typed
                ])
         ; Vdom.Attr.on_change (fun (_ : Dom_html.event Js.t) typed ->
              Effect.Many
                [ set (fun model ->
                    { model with
                      draft = None
                    ; epoch = model.epoch + 1
                    })
                ; commit_typed typed
                ])
         ; Vdom.Attr.on_click (fun (_ : Dom_html.mouseEvent Js.t) -> open_calendar ())
         ; Vdom.Attr.on_keydown (fun (ev : Dom_html.keyboardEvent Js.t) ->
              let key = js_property ev "key" in
              if String.equal key "ArrowDown" then
                (js_prevent_default ev;
                 open_calendar ())
              else if String.equal key "Escape" then
                (js_prevent_default ev;
                 close_calendar ())
              else if String.equal key "Enter" then
                (js_prevent_default ev;
                 Effect.Many
                   [ set (fun model ->
                       { model with
                         draft = None
                       ; epoch = model.epoch + 1
                       })
                   ; commit_typed text
                   ])
              else Effect.Ignore)
         ]
         @ (if is_disabled || is_loading then [ Vdom.Attr.create "readonly" "readonly" ] else [])
         @ (match disabled_message with
            | Some _ -> [ Vdom.Attr.create "aria-describedby" (id ^ "-disabled-message") ]
            | None -> []))
      in
      let trigger =
        Button.view
          ~label:(if model.is_open then "Close calendar" else "Open calendar")
          ~variant:Button.Secondary
          ~size:button_size
          ~is_icon_only:true
          ~icon:(Icon.view ~name:"calendar" ~size:Icon.Sm ())
          ~is_disabled
          ~on_click:(fun (_ : Dom_html.mouseEvent Js.t) ->
            set (fun _model ->
              { is_open = (not _model.is_open)
              ; draft = None
              ; epoch = _model.epoch + 1
              }))
          []
      in
      let popover =
        Popover.view
          ~id:(id ^ "-calendar-popover")
          ~label:"Choose a date"
          ~close_button_label:"Close calendar"
          ~role:Popover.Dialog
          ~is_modal:false
          ~has_auto_focus:true
          ~has_light_dismiss:true
          ~has_escape_dismiss:true
          ~trigger
          ~content:calendar
          ~is_open:model.is_open
          ~on_open_change:(fun is_open ->
            set (fun _model ->
              { is_open
              ; draft = None
              ; epoch = _model.epoch + 1
              }))
          ()
      in
      let field =
        Field_.view
          ~label
          ~input_id
          ~is_label_hidden
          ?description
          ~is_optional
          ~is_required
          ~is_disabled
          ?status
          ~status_variant
          ?width
          ~children:
            [ Vdom.Node.input ~key:("input-" ^ string_of_int model.epoch) ~attrs:input_attrs ()
            ; popover
            ]
          ()
      in
      let reason =
        match disabled_message with
        | Some message when is_disabled ->
          [ Vdom.Node.div
              ~attrs:
                [ Vdom.Attr.create "id" (id ^ "-disabled-message")
                ; Vdom.Attr.create "role" "alert"
                ]
              [ Vdom.Node.text message ]
          ]
        | _ -> []
      in
      Vdom.Node.div
        ~attrs:
          (Common.Attr.class_ [ "astryx-date-input"; "astryx-date-input--" ^ size_class ]
          @ Common.Attr.data "component" "DateInput"
          @ attrs)
        ([ field ] @ reason))
;;
