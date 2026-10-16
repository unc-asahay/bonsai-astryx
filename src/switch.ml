open! Core
open! Bonsai_web

module Attr = Common.Attr
let prevent_default = Common.prevent_default

(* A disabled control with a reason stays focusable: [aria-disabled] instead of the native
   [disabled] attribute, and [form=""] so it is detached from any form it sits in and therefore
   submits nothing — which is the whole point of the native attribute it replaces. The reason is
   described unconditionally while the control is in that state, because a description that only
   exists on hover is a description a screen reader never reads; the *bubble* is shown on hover and
   focus by CSS. *)
let message_bubble ~id ~content =
  Vdom.Node.div
    ~attrs:
      (Common.Attr.class_ [ "astryx-disabled-message" ]
       @ [ Vdom.Attr.create "role" "tooltip"; Vdom.Attr.create "id" id ]
       @ Common.Attr.data "component" "DisabledMessage")
    [ Vdom.Node.text content ]
;;

let view
      ?(attrs = [])
      ?(is_disabled = false)
      ?disabled_message
      ?(is_label_hidden = false)
      ?(is_optional = false)
      ?(is_required = false)
      ?optionality
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
  |> Bonsai.map ~f:(fun (is_on, on_change) ->
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
    let description_id =
      match description with
      | Some _ -> Some (Option.value description_id ~default:(id ^ "-description"))
      | None -> description_id
    in
    let status_message_id = id ^ "-status" in
    let shows_disabled_message = is_disabled && Option.is_some disabled_message in
    let disabled_message_id = id ^ "-disabled-message" in
    let described_by =
      List.filter_opt
        [ description_id
        ; (if Option.is_some status_message then Some status_message_id else None)
        ]
      |> String.concat ~sep:" "
    in
    (* The reason is described for as long as the control is disabled, not only while the pointer is
       over it: a description that exists only on hover is one a screen reader never reads. *)
    let described_by =
      if shows_disabled_message
      then
        String.concat
          ~sep:" "
          (List.filter_opt
             [ (if String.is_empty described_by then None else Some described_by)
             ; Some disabled_message_id
             ])
      else described_by
    in
    let message_bubble_nodes =
      match disabled_message with
      | Some content when shows_disabled_message -> [ message_bubble ~id:disabled_message_id ~content ]
      | Some _ | None -> []
    in
    let input_attrs =
      Attr.class_ [ "astryx-switch__input" ]
      @ [ Vdom.Attr.create "type" "checkbox"
        ; (* The whole point of the control: a native checkbox that announces itself as a switch. *)
          Vdom.Attr.create "role" "switch"
        ; Vdom.Attr.create "id" id
        ; (* The checked *property*, as for CheckboxInput: the attribute only seeds the first paint.
             No aria-checked, deliberately — the input's own checkedness is the state, and upstream
             omits the second declaration for the same reason. *)
          Vdom.Attr.checked_prop is_on
        ]
      @ (if shows_disabled_message
          then (* Focusable-disabled: the native attribute would also refuse focus, which is exactly
                  what a reason needs to be discoverable. *)
            Attr.aria "disabled" "true" @ [ Vdom.Attr.create "form" "" ]
          else if is_disabled
          then [ Vdom.Attr.create "disabled" "disabled" ]
          else [])
      @ (if is_required then [ Vdom.Attr.create "required" "required" ] else [])
      @ [ Vdom.Attr.on_click (fun ev ->
            (* Focusable-disabled fires clicks after all — that is the price of staying reachable —
               so this guard is load-bearing now, and it cancels the event rather than ignoring it,
               because the browser has already flipped the box by the time it runs. *)
            if is_disabled
            then (
              prevent_default ev;
              Effect.Many [])
            else on_change (not is_on))
        ]
      @ (match status_type with
         | Some Input_types.Error -> Attr.aria "invalid" "true"
         | Some (_ : Input_types.status_type) | None -> [])
      @ (if String.is_empty described_by then [] else Attr.aria "describedby" described_by)
    in
    let track =
      (* aria-hidden: the track is the paint. The input underneath owns the role, the name, the
         state and the focus ring, which is why the ring is drawn here by a sibling rule. *)
      Vdom.Node.div
        ~attrs:
          (Attr.class_
             ([ "astryx-switch__track"
              ; (if is_on then "astryx-switch__track--on" else "astryx-switch__track--off")
              ]
              @ (if is_disabled then [ "astryx-switch__track--disabled" ] else []))
           @ Attr.aria "hidden" "true")
        [ Vdom.Node.div
            ~attrs:
              (Attr.class_
                 [ "astryx-switch__thumb"
                 ; (if is_on then "astryx-switch__thumb--on" else "astryx-switch__thumb--off")
                 ])
            []
        ]
    in
    let control =
      Vdom.Node.div
        ~attrs:(Attr.class_ [ "astryx-switch__control" ])
        ([ Vdom.Node.input ~attrs:input_attrs (); track ] @ message_bubble_nodes)
    in
    let label_wrapper =
      Vdom.Node.div
        ~attrs:(Attr.class_ [ "astryx-switch__label-wrapper" ])
        [ Field_label.view
          ?optionality
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
    let container =
      Vdom.Node.div
        ~attrs:
          (Attr.class_
             ("astryx-switch__container"
              :: (if is_label_hidden then [ "astryx-switch__container--label-hidden" ] else [])))
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
        (Attr.class_ [ "astryx-switch" ]
         @ Attr.data "component" "Switch"
         @ Attr.data "state" (if is_on then "on" else "off")
         @ Attr.data "size" (Indicator.size_string size)
         @ attrs)
      (container :: status_node))
;;
