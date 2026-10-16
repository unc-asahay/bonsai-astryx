open! Core
open! Bonsai_web
open Js_of_ocaml

module Attr = Common.Attr

type value = Indicator.state =
  | Checked
  | Unchecked
  | Indeterminate
;;

(* What a click produces, from the value on screen: an indeterminate box becomes checked (the
   browser's own rule for clicking a group's half-selected parent) and so does an unchecked one;
   only a checked box becomes unchecked. Deriving it from the current value instead of reading the
   DOM property back keeps the application's value the single source of truth — the alternative is
   to trust that the DOM and the app agree, which is exactly what a controlled input exists to
   avoid. *)
(* The same one-liner Dropdown_menu uses: a click on a checkbox sets its checkedness *before* the
   event is dispatched and reverts it if the event is canceled, so refusing the click this way is
   both native and immediate. Leaving the property flipped and waiting for a re-render to fix it
   would not work — nothing re-renders when the application's value did not change, so a read-only
   box would sit there visibly checked while the application still says it is not. *)
let prevent_default (obj : 'a Js.t) = ignore (Js.Unsafe.meth_call obj "preventDefault" [||])

let toggled = function
  | Checked -> Unchecked
  | Unchecked | Indeterminate -> Checked
;;

let view
      ?(attrs = [])
      ?(is_disabled = false)
      ?(is_read_only = false)
      ?(is_label_hidden = false)
      ?(is_optional = false)
      ?(is_required = false)
      ?label_icon
      ?description
      ?description_id
      ?status
      ?(size = Indicator.Md)
      ~label
      ~id
      ~value
      ~on_change
      ()
  =
  Bonsai.both value on_change
  |> Bonsai.map ~f:(fun (value, on_change) ->
    let is_indeterminate =
      match value with
      | Indeterminate -> true
      | Checked | Unchecked -> false
    in
    let is_checked =
      match value with
      | Checked -> true
      | Unchecked | Indeterminate -> false
    in
    (* The description is rendered by FieldLabel, which is also where its id comes from when the
       caller does not name one; the status message gets its own id so the input can point at both
       without either being announced as the control's *name*. *)
    let description_id =
      match description with
      | Some _ -> Some (Option.value description_id ~default:(id ^ "-description"))
      | None -> description_id
    in
    let status_message =
      match status with
      | Some { Input_types.message = Some message; _ } -> Some message
      | Some { message = None; _ } | None -> None
    in
    let status_type =
      match status with
      | Some { Input_types.type_ = type_; _ } -> Some type_
      | None -> None
    in
    let status_message_id = id ^ "-status" in
    let described_by =
      List.filter_opt
        [ description_id
        ; (if Option.is_some status_message then Some status_message_id else None)
        ]
      |> String.concat ~sep:" "
    in
    let input_attrs =
      Attr.class_ [ "astryx-checkbox-input__input" ]
      @ [ Vdom.Attr.create "type" "checkbox"
        ; Vdom.Attr.create "id" id
        ; (* Both of these are DOM *properties*. The checked attribute only sets a checkbox's
             initial state, and there is no indeterminate attribute at all. *)
          Vdom.Attr.checked_prop is_checked
        ; Vdom.Attr.bool_property "indeterminate" is_indeterminate
        ]
      @ (if is_disabled then [ Vdom.Attr.create "disabled" "disabled" ] else [])
      @ (if is_read_only then [ Vdom.Attr.create "readonly" "readonly" ] else [])
      @ (if is_required then [ Vdom.Attr.create "required" "required" ] else [])
      @ [ Vdom.Attr.on_click (fun ev ->
            (* The DOM refuses clicks on a disabled input, but a read-only one still fires them, so
               the guard is here as well as on the attribute — and it cancels the event rather than
               only ignoring it, because the browser has already flipped the checkbox by then. *)
            if is_disabled || is_read_only
            then (
              prevent_default ev;
              Effect.Many [])
            else on_change (toggled value))
        ]
      @ (if is_read_only then Attr.aria "readonly" "true" else [])
      @ (match status_type with
         | Some Input_types.Error -> Attr.aria "invalid" "true"
         | Some (_ : Input_types.status_type) | None -> [])
      @ (if String.is_empty described_by then [] else Attr.aria "describedby" described_by)
    in
    let indicator_slot =
      Vdom.Node.span
        ~attrs:(Attr.class_ [ "astryx-checkbox-input__indicator-slot" ])
        [ Indicator.view ~kind:Indicator.Checkbox ~state:value ~size ~is_disabled () ]
    in
    let control =
      Vdom.Node.div
        ~attrs:(Attr.class_ [ "astryx-checkbox-input__control" ])
        [ Vdom.Node.input ~attrs:input_attrs (); indicator_slot ]
    in
    let label_wrapper =
      Vdom.Node.div
        ~attrs:(Attr.class_ [ "astryx-checkbox-input__label-wrapper" ])
        [ Field_label.view
            ~label
            ~input_id:id
            ?label_icon
            ~is_label_hidden
            ~is_disabled
            ~is_optional
            ~is_required
            ?description
            ?description_id
            ()
        ]
    in
    (* Hover and focus reach the box through the owning row rather than through props, so hovering
       the label lights it — the same ancestor scope the standalone indicator uses. A disabled
       control is not a scope: nothing is going to light up. *)
    let container =
      Vdom.Node.div
        ~attrs:
          (Attr.class_
             ([ "astryx-checkbox-input__container" ]
              @ (if is_label_hidden
                 then [ "astryx-checkbox-input__container--label-hidden" ]
                 else [])
              @ (if is_disabled then [] else [ "astryx-indicator-scope" ])))
        [ control; label_wrapper ]
    in
    let status_node =
      match status_message, status_type with
      | Some message, Some type_ ->
        [ Field_status.view
            ~variant:Field_status.Detached
            ~attrs:[ Vdom.Attr.create "id" status_message_id ]
            ~type_
            ~message
            ()
        ]
      | (Some _ | None), _ -> []
    in
    Vdom.Node.div
      ~attrs:
        (Attr.class_ [ "astryx-checkbox-input" ]
         @ Attr.data "component" "CheckboxInput"
         @ Attr.data "state" (Indicator.state_string value)
         @ Attr.data "size" (Indicator.size_string size)
         @ attrs)
      (container :: status_node))
;;
