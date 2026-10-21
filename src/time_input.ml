(* TimeInput — the typed time field.

   Port of upstream's [packages/core/src/TimeInput] (the typed-field surface)
   and the shared [utils/timeParser.ts] it is built on. The behaviour contract
   is upstream's own: the accepted input formats, the twelve/twenty-four hour
   display, the arrow-key adjustment, the range check and the accessibility
   wiring.

   Documented divergences (also in the .mli):
   - The value is a house-local [time] record, not upstream's branded
     [ISOTimeString]. [of_iso] / [to_iso] convert at the boundary, exactly as
     [Plain_date.of_iso] / [Plain_date.to_iso] do for a date.
   - No native picker, popover or bottom-sheet time surface, and no
     [presentation] / [nativePicker] prop: the house has no time picker to
     point them at, so the typed field is the only surface and the props do
     not exist here rather than being accepted and ignored.
   - No [change_action] and no optimistic value (upstream fires an async action
     after onChange and keeps an optimistic value through the transition; a
     Bonsai graph has no counterpart for either).
   - No ref forwarding, and no DOM event-handler props on the control: the port
     keeps Enter and the arrow keys itself and reaches the rest through
     [attrs].
   - No [label_tooltip] (Tooltip is not ported) and no InputGroup context.
   - The strings are fixed English (upstream resolves them through its i18n
     catalogue).
   - The live regions are drawn in place, like [Calendar] does: upstream
     announces through document-level live regions created by [useAnnounce],
     and the OCaml layer has no document-level outlet.
   - The clock is a plain house [Icon]; the house icon registry has no clock of
     its own.
   - A typed field must be digits: upstream's parseInt read "2x" as 2, the port
     refuses an entry it could not read back.
   - Generated ids derive from [id] (id-desc, id-status, id-reason) rather than
     React's useId, so markup is deterministic and testable. *)

module Field_ = Field

open! Core
open! Bonsai_web
open Js_of_ocaml

module Attr = Common.Attr

(* ------------------------------------------------------------------ the value *)

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

(* ------------------------------------------------------------------ parsing *)

(* A field of the input must be a run of digits. *)
let int_of_digits s =
  let n = String.length s in
  if n = 0 then None
  else
    let ok = ref true in
    for i = 0 to n - 1 do
      match s.[i] with
      | '0' .. '9' -> ()
      | _ -> ok := false
    done;
    if !ok then Some (int_of_string s) else None
;;

(* Upstream's parseISOTime: "HH:MM" or "HH:MM:SS", every field in range. *)
let of_iso s =
  match String.split_on_chars ~on:[':'] s with
  | [ hour; minute ] -> (
    match (int_of_digits hour, int_of_digits minute) with
    | Some hour, Some minute when hour <= 23 && minute <= 59 ->
      Some { hour; minute; second = 0 }
    | _ -> None)
  | [ hour; minute; second ] -> (
    match (int_of_digits hour, int_of_digits minute, int_of_digits second) with
    | Some hour, Some minute, Some second when hour <= 23 && minute <= 59 && second <= 59 ->
      Some { hour; minute; second }
    | _ -> None)
  | _ -> None
;;

let to_iso ?(include_seconds = false) t =
  if include_seconds
  then Printf.sprintf "%02d:%02d:%02d" t.hour t.minute t.second
  else Printf.sprintf "%02d:%02d" t.hour t.minute
;;

(* The meridiem a typed entry ends with. Upstream's regexes accept "p", "pm",
   "p.m.", "p.m" and the dotted spellings, and the detection is derived from
   the same match as the removal so the two can never disagree — a dotted
   meridiem used to skip the twelve-to-twenty-four conversion and parse twelve
   hours off. *)
let meridiem_of s =
  let n = String.length s in
  let ends_with suffix =
    let m = String.length suffix in
    if n < m then false
    else String.equal (String.sub s ~pos:(n - m) ~len:m) suffix
  in
  if ends_with "pm" || ends_with "p.m." || ends_with "p.m" || ends_with "p." || ends_with "p"
  then Some `PM
  else if ends_with "am" || ends_with "a.m." || ends_with "a.m" || ends_with "a." || ends_with "a"
  then Some `AM
  else None
;;

(* Remove the meridiem suffix, along with the space before it. *)
let strip_meridiem s =
  let n = String.length s in
  let rec last_non_space i =
    if i < 0 then None
    else
      match s.[i] with
      | ' ' | '\t' -> last_non_space (i - 1)
      | _ -> Some i
  in
  match last_non_space (n - 1) with
  | None -> s
  | Some i -> String.sub s ~pos:0 ~len:i |> String.strip
;;

let parse_time_input ?(include_seconds = false) input =
  let trimmed = String.lowercase (String.strip input) in
  if String.is_empty trimmed then None
  else
    let meridiem = meridiem_of trimmed in
    let time_str = strip_meridiem trimmed in
    (* A meridiem is only meaningful on hours 1-12, and it moves the hour onto
       the twenty-four hour clock: 12 AM is 0, 12 PM is 12, 2 PM is 14. *)
    let convert_hour hour =
      match meridiem with
      | None -> if hour >= 0 && hour <= 23 then Some hour else None
      | Some `AM -> if hour < 1 || hour > 12 then None else if hour = 12 then Some 0 else Some hour
      | Some `PM -> if hour < 1 || hour > 12 then None else if hour = 12 then Some 12 else Some (hour + 12)
    in
    let build hour minute second =
      match convert_hour hour with
      | None -> None
      | Some hour ->
        (* Upstream's value string carries no seconds when the field does not
           show them, so a parsed entry drops them too. *)
        Some { hour; minute; second = (if include_seconds then second else 0) }
    in
    let n = String.length time_str in
    if n = 0 then None
    else if n <= 2 && Option.is_some (int_of_digits time_str) then
      (* "2pm" — an hour on its own. *)
      match int_of_digits time_str with
      | Some hour -> build hour 0 0
      | None -> None
    else if n = 4 && Option.is_some (int_of_digits time_str) then
      (* "1430" — a twenty-four hour clock without the colon. *)
      match int_of_digits time_str with
      | Some packed ->
        let hour = packed / 100 and minute = packed mod 100 in
        if minute <= 59 then build hour minute 0 else None
      | None -> None
    else if n = 6 && Option.is_some (int_of_digits time_str) then
      (* "143000" — with seconds. *)
      match int_of_digits time_str with
      | Some packed ->
        let hour = packed / 10000 and minute = (packed / 100) mod 100 and second = packed mod 100 in
        if minute <= 59 && second <= 59 then build hour minute second else None
      | None -> None
    else
      (* "2:30", "14:30:45" — the colon forms. *)
      match String.split_on_chars ~on:[':'] time_str with
      | [ hour; minute ] -> (
        match (int_of_digits hour, int_of_digits minute) with
        | Some hour, Some minute when minute <= 59 -> build hour minute 0
        | _ -> None)
      | [ hour; minute; second ] -> (
        match (int_of_digits hour, int_of_digits minute, int_of_digits second) with
        | Some hour, Some minute, Some second when minute <= 59 && second <= 59 -> build hour minute second
        | _ -> None)
      | _ -> None
;;

(* ---------------------------------------------------------------- formatting *)

let format_display_time ?(include_seconds = false) hour_format t =
  match hour_format with
  | H24 ->
    if include_seconds
    then Printf.sprintf "%02d:%02d:%02d" t.hour t.minute t.second
    else Printf.sprintf "%02d:%02d" t.hour t.minute
  | H12 ->
    (* Midnight reads 12 AM and noon 12 PM. *)
    let hour12 = if t.hour = 0 then 12 else if t.hour > 12 then t.hour - 12 else t.hour in
    let meridiem = if t.hour < 12 then "AM" else "PM" in
    if include_seconds
    then Printf.sprintf "%d:%02d:%02d %s" hour12 t.minute t.second meridiem
    else Printf.sprintf "%d:%02d %s" hour12 t.minute meridiem
;;

let compare_time a b =
  let total_a = (a.hour * 60 + a.minute) * 60 + a.second in
  let total_b = (b.hour * 60 + b.minute) * 60 + b.second in
  Int.compare total_a total_b
;;

let is_time_in_range t ~min ~max =
  let above_min = match min with None -> true | Some m -> compare_time t m >= 0 in
  let below_max = match max with None -> true | Some m -> compare_time t m <= 0 in
  above_min && below_max
;;

let adjust_time t ~delta_minutes =
  (* Wrap around midnight; the double modulo handles the negative side. *)
  let total_minutes = t.hour * 60 + t.minute + delta_minutes in
  let total_minutes = ((total_minutes mod 1440) + 1440) mod 1440 in
  { hour = total_minutes / 60; minute = total_minutes mod 60; second = t.second }
;;

(* ------------------------------------------------------------------ the field *)

let size_string = function
  | Sm -> "sm"
  | Md -> "md"
  | Lg -> "lg"
;;

let status_string = function
  | Warning -> "warning"
  | Error -> "error"
  | Success -> "success"
;;

(* Upstream keeps the typed text in state while the field is being edited, and
   the committed value is the application's. The same split here: [pending] is
   the draft text, and the value arrives through the graph. *)
let is_ime_key_event (ev : Dom_html.keyboardEvent Js.t) =
  Js.to_bool
    (Js.Unsafe.fun_call
       (Js.Unsafe.pure_js_expr
          "(function(ev){return ev.isComposing === true || ev.keyCode === 229;})")
       [| Js.Unsafe.inject ev |])
;;

let focus_input (id : string) () =
  match Js.Opt.to_option (Js.Unsafe.meth_call Dom_html.document "getElementById" [| Js.Unsafe.inject (Js.string id) |]) with
  | Some el -> Js.Unsafe.meth_call el "focus" [| |]
  | None -> ()
;;

(* The host's local wall clock, for the arrow keys' "start from now" default.
   Upstream reads [new Date()]; the house reads the same thing through the
   Intl seam [Timestamp.zone_parts] with the viewer's own zone, which keeps
   one wall-clock reading in the library instead of a second one here. *)
let local_now () =
  let ms = Js.to_float (Js.Unsafe.coerce (Js.Unsafe.eval_string "Date.now()")) in
  let _, _, _, hour, minute, second = Timestamp.zone_parts ~ms ~timezone_id:"" in
  { hour; minute; second }
;;

let view
      ?(id = "astryx-time-input")
      ?(attrs = [])
      ~label
      ?(is_label_hidden = false)
      ?description
      ?(is_optional = false)
      ?(is_required = false)
      ?(is_disabled = false)
      ?disabled_message
      ?value
      ?on_change
      ?min
      ?max
      ?(has_seconds = false)
      ?(has_clear = false)
      ?(has_auto_focus = false)
      ?(hour_format = H12)
      ?(increment = 1)
      ?(placeholder = "Select a time")
      ?(is_loading = false)
      ?status
      ?(status_variant = Attached)
      ?(size = Md)
      ?width
      ?html_name
      graph =
  let shows_disabled_message = is_disabled && Option.is_some disabled_message in
  let required_and_not_optional = is_required && not is_optional in
  let description_id = id ^ "-desc" in
  let message_id = id ^ "-status" in
  let reason_id = id ^ "-reason" in
  let has_status_message =
    match status with
    | Some { Input_types.message = Some m; _ } -> not (String.is_empty m)
    | _ -> false
  in
  let status_is_error =
    match status with Some { Input_types.type_ = Error; _ } -> true | _ -> false
  in
  (* The committed value and the callback are optional, so a field with no
     application state behind it still renders. *)
  let value_tree = Option.value value ~default:(Bonsai.return None) in
  let on_change_tree =
    Option.value on_change ~default:(Bonsai.return (fun (_ : time option) -> Bonsai.Effect.Many []))
  in
  let pending, set_pending = Bonsai.state None graph in
  let focused, set_focused = Bonsai.state false graph in
  let announced, set_announced = Bonsai.state "" graph in
  let vc = Bonsai.both value_tree on_change_tree in
  let pf = Bonsai.both pending focused in
  let ann = announced in
  let setters = Bonsai.both (Bonsai.both set_pending set_focused) set_announced in
  Bonsai.map2 (Bonsai.both vc pf) (Bonsai.both ann setters)
    ~f:(fun
      ( (value_now, on_change_fn)
      , (pending_now, focused_now)
      )
        (announced_now, ((set_pending_fn, set_focused_fn), set_announced_fn)) ->
        (* What the field shows: the draft text while it is being edited, the
           formatted value otherwise. *)
        let formatted_value =
          match value_now with
          | None -> ""
          | Some t -> format_display_time ~include_seconds:has_seconds hour_format t
        in
        let display_value =
          match pending_now with
          | Some text -> text
          | None -> formatted_value
        in
        (* An entry is valid when it parses and falls inside the range. *)
        let is_input_valid =
          match pending_now with
          | None -> true
          | Some text ->
            if String.is_empty (String.strip text) then true
            else (
              match parse_time_input ~include_seconds:has_seconds text with
              | None -> false
              | Some t -> is_time_in_range t ~min ~max)
        in
        (* The focused and empty field shows the format hint instead of the
           placeholder, so the expected shape is visible while typing. *)
        let display_placeholder =
          if focused_now && String.is_empty display_value
          then (match hour_format with H12 -> "e.g., 2:30 PM" | H24 -> "e.g., 14:30")
          else placeholder
        in
        let fire_change new_value = on_change_fn new_value in
        let commit_if_valid text =
          match parse_time_input ~include_seconds:has_seconds text with
          | Some t when is_time_in_range t ~min ~max -> Some t
          | _ -> None
        in
        let on_input (text : string) : unit Bonsai.Effect.t =
          if is_disabled then Bonsai.Effect.Many []
          else
            (* Upstream commits as soon as the entry is valid, without waiting
               for a blur. *)
            let changed =
              match (commit_if_valid text, value_now) with
              | Some t, Some current when compare_time t current = 0 -> Bonsai.Effect.Many []
              | Some _, _ -> fire_change (commit_if_valid text)
              | None, _ -> Bonsai.Effect.Many []
            in
            Bonsai.Effect.Many [ set_pending_fn (Some text); changed ]
        in
        let on_blur : unit Bonsai.Effect.t =
          (* The unfocus effect has to be part of what the blur returns, not a
             statement before it: a setter's effect is what performs it. *)
          let unfocus = set_focused_fn false in
          match pending_now with
          | None -> Bonsai.Effect.Many [ unfocus ]
          | Some text ->
            if String.is_empty (String.strip text) then
              (* An emptied field clears the value. *)
              let cleared = match value_now with None -> Bonsai.Effect.Many [] | Some _ -> fire_change None in
              Bonsai.Effect.Many [ unfocus; set_pending_fn None; cleared ]
            else
              let changed =
                match (commit_if_valid text, value_now) with
                | Some t, Some current when compare_time t current = 0 -> Bonsai.Effect.Many []
                | Some _, _ -> fire_change (commit_if_valid text)
                | None, _ -> Bonsai.Effect.Many []
              in
              (* The draft is dropped either way: the field falls back to the
                 formatted value, so an invalid entry reverts. *)
              Bonsai.Effect.Many [ unfocus; set_pending_fn None; changed ]
        in
        let step_time direction : unit Bonsai.Effect.t =
          (* Stepping starts from the committed value, or from now when there
             is none. *)
          let current = match value_now with Some t -> t | None -> local_now () in
          let next = adjust_time current ~delta_minutes:(direction * increment) in
          if is_time_in_range next ~min ~max
          then
            let changed =
              match value_now with
              | Some t when compare_time t next = 0 -> Bonsai.Effect.Many []
              | _ -> fire_change (Some next)
            in
            (* Stepping rewrites a plain text box's value, and screen readers do
               not announce that, so the new time is spoken explicitly. *)
            Bonsai.Effect.Many
              [ set_pending_fn None
              ; changed
              ; set_announced_fn (format_display_time ~include_seconds:has_seconds hour_format next)
              ]
          else Bonsai.Effect.Many []
        in
        let on_keydown (ev : Dom_html.keyboardEvent Js.t) : unit Bonsai.Effect.t =
          (* An IME candidate window uses the arrow keys to navigate candidates,
             so the composing keydown is left alone. *)
          if is_ime_key_event ev then Bonsai.Effect.Many []
          else if is_disabled then Bonsai.Effect.Many []
          else
            let key = Option.value (Common.string_prop (Obj.magic ev : _ Js.t) "key") ~default:"" in
            if String.equal key "ArrowUp" || String.equal key "ArrowDown"
            then
              Bonsai.Effect.Many
                [ Bonsai.Effect.of_thunk (fun () -> Common.prevent_default ev)
                ; step_time (if String.equal key "ArrowUp" then 1 else -1)
                ]
            else Bonsai.Effect.Many []
        in
        let described_by =
          List.filter_opt
            [ (if Option.is_some description then Some description_id else None)
            ; (if has_status_message && not (Poly.equal status_variant Tooltip) then Some message_id else None)
            ; (if shows_disabled_message then Some reason_id else None)
            ]
          |> String.concat ~sep:" "
        in
        let input_attrs =
          [ Vdom.Attr.create "id" id ]
          @ [ Vdom.Attr.create "type" "text" ]
          @ [ Vdom.Attr.create "value" display_value ]
          @ (match html_name with
             | Some name when not is_disabled -> [ Vdom.Attr.create "name" name ]
             | _ -> [])
          @ [ Vdom.Attr.create "placeholder" display_placeholder ]
          @ (if is_disabled && not shows_disabled_message then [ Vdom.Attr.create "disabled" "disabled" ] else [])
          @ (if shows_disabled_message then [ Vdom.Attr.create "readonly" "readonly" ] else [])
          @ (if shows_disabled_message then Attr.aria "disabled" "true" else [])
          @ (if String.is_empty described_by then [] else [ Vdom.Attr.create "aria-describedby" described_by ])
          @ (if required_and_not_optional then Attr.aria "required" "true" else [])
          @ (if status_is_error || not is_input_valid then Attr.aria "invalid" "true" else [])
          @ (if is_loading then Attr.aria "busy" "true" else [])
          @ (if has_auto_focus then [ Vdom.Attr.autofocus true ] else [])
          @ [ Vdom.Attr.on_input (fun _ text -> on_input text) ]
          @ [ Vdom.Attr.on_focus (fun _ -> if is_disabled then Bonsai.Effect.Many [] else set_focused_fn true) ]
          @ [ Vdom.Attr.on_blur (fun _ -> on_blur) ]
          @ [ Vdom.Attr.on_keydown on_keydown ]
          @ Attr.class_ [ "astryx-time-input__input" ]
        in
        let clock_icon =
          [ Vdom.Node.span ~attrs:(Attr.class_ [ "astryx-time-input__icon" ])
              [ Icon.view ~name:"clock" ~size:Icon.Sm ~color:Icon.Secondary () ]
          ]
        in
        (* The invalid entry is announced: the value reverts silently on blur,
           so without this a screen-reader user gets no feedback (WCAG 3.3.1). *)
        let invalid_alert =
          if not is_input_valid
          then
            [ Vdom.Node.div
                ~attrs:
                  (Attr.class_ [ "astryx-time-input__invalid-alert"; "astryx-visually-hidden" ]
                   @ Attr.role "alert"
                   @ [ Vdom.Attr.create "aria-live" "assertive" ])
                [ Vdom.Node.text "Invalid time" ]
            ]
          else []
        in
        let clear_button =
          if has_clear && Option.is_some value_now && not is_disabled
          then
            [ Vdom.Node.button
                ~attrs:
                  (Attr.class_ [ "astryx-time-input__clear" ]
                   @ Attr.aria "label" "Clear value"
                   @ [ Vdom.Attr.on_click (fun _ ->
                         Bonsai.Effect.Many
                           [ set_pending_fn None
                           ; fire_change None
                           ; Bonsai.Effect.of_thunk (fun () -> focus_input id ())
                           ]) ])
                [ Icon.view ~name:"close" ~size:Icon.Sm ~color:Icon.Secondary () ]
            ]
          else []
        in
        let spinner = if is_loading then [ Spinner.view ~size:Spinner.Sm () ] else [] in
        (* The stepped time is spoken through a live region drawn in place. *)
        let live_region =
          [ Vdom.Node.div
              ~attrs:
                (Attr.class_ [ "astryx-visually-hidden" ]
                 @ Attr.role "status"
                 @ Attr.aria "live" "polite")
              [ Vdom.Node.text announced_now ]
          ]
        in
        let reason_nodes =
          if shows_disabled_message
          then
            [ Vdom.Node.div
                ~attrs:(Attr.class_ [ "astryx-time-input__disabled-reason" ] @ [ Vdom.Attr.id reason_id ])
                [ Vdom.Node.text (Option.value_exn disabled_message) ]
            ]
          else []
        in
        let wrapper_attrs =
          Attr.class_
            ([ "astryx-time-input"; "astryx-time-input--" ^ size_string size ]
             @ (if is_disabled then [ "astryx-time-input--disabled" ] else [])
             @ (match status with
                | Some { Input_types.type_; _ } -> [ "astryx-time-input--" ^ status_string type_ ]
                | None -> []))
          @ Attr.data "component" "TimeInput"
          @ Attr.data "size" (size_string size)
          @ (match status with
             | Some { Input_types.type_; _ } -> Attr.data "status" (status_string type_)
             | None -> [])
          @ (if is_disabled then Attr.data "disabled" "true" else [])
          @ (if has_seconds then Attr.data "seconds" "true" else [])
          @ (match hour_format with H12 -> Attr.data "hour-format" "12h" | H24 -> Attr.data "hour-format" "24h")
          @ attrs
        in
        let wrapper =
          Vdom.Node.div ~attrs:wrapper_attrs
            (clock_icon
             @ [ Vdom.Node.input ~attrs:input_attrs () ]
             @ invalid_alert
             @ clear_button
             @ spinner
             @ reason_nodes
             @ live_region)
        in
        let required_nodes =
          if required_and_not_optional
          then
            [ Vdom.Node.span
                ~attrs:[ Vdom.Attr.class_ "astryx-visually-hidden"; Vdom.Attr.id (id ^ "-required") ]
                [ Vdom.Node.text "Required" ]
            ]
          else []
        in
        Field_.view
          ~label
          ~input_id:id
          ~is_label_hidden
          ?description
          ~is_optional
          ~is_required
          ~is_disabled
          ?status
          ~status_variant
          ?width
          ~children:(wrapper :: required_nodes)
          ())
;;
