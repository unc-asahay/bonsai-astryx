open! Core
open! Bonsai_web

module Attr = Common.Attr

type status_type = Input_types.status_type =
  | Warning
  | Error
  | Success

type status_variant = Field_status.placement =
  | Attached
  | Detached
  | Tooltip

type width = Common.Size_value.t =
  | Px of int
  | Css of string

(* The tooltip placement renders no message box, so the message has to reach assistive
   technology some other way. This is that way: a live region carrying the same id the control
   points at with aria-describedby, so the message is both described and announced — at the same
   urgency the visible strip would have used. *)
let announcement_node ~type_ ~message_id ~message =
  let role = match type_ with Field_status.Error -> "alert" | _ -> "status" in
  Vdom.Node.span
    ~attrs:
      (Attr.class_ [ "astryx-visually-hidden" ]
       @ Attr.role role
       @ [ Vdom.Attr.create "id" message_id ]
       @ Attr.data "field-status-announcement" "true")
    [ Vdom.Node.text message ]
;;

let status_node ~status_variant ~message_id (type_ : status_type) ~message =
  match (status_variant : status_variant) with
  | Attached ->
    Some
      (Field_status.view
         ~variant:Field_status.Attached
         ~type_
         ~message
         ~attrs:[ Vdom.Attr.create "id" message_id ]
         ())
  | Detached ->
    Some
      (Field_status.view
         ~variant:Field_status.Detached
         ~type_
         ~message
         ~attrs:[ Vdom.Attr.create "id" message_id ]
         ())
  | Tooltip -> Some (announcement_node ~type_ ~message_id ~message)
;;

let view
      ?(is_label_hidden = false)
      ?description
      ?(is_optional = false)
      ?(is_required = false)
      ?(is_disabled = false)
      ?label_icon
      ?status
      ?(status_variant = Attached)
      ?width
      ?label_id
      ?(is_group_label = false)
      ?(attrs = [])
      ~label
      ~input_id
      ~children
      ()
  =
  (* The two ids a control points at with aria-describedby. Upstream derives the same defaults
     from inputID, so a caller that passes neither still gets working references. *)
  let description_id = input_id ^ "-desc" in
  let message_id = input_id ^ "-status" in
  (* The label group is a component of its own upstream, because CheckboxInput and Switch want it
     beside their control rather than above it. Field renders it here; it does not own it. *)
  let label_group =
    Field_label.view
      ?label_icon
      ?label_id
      ~is_group_label
      ~is_label_hidden
      ~is_disabled
      ~is_optional
      ~is_required
      ?description
      ~description_id
      ~label
      ~input_id
      ()
  in
  let status_content =
    match status with
    | None -> None
    (* A status with no message still colours the control — that is the control's class, not this
       — but it has nothing to put in a message box, and nothing to announce. Upstream renders no
       box in that case rather than an empty one. *)
    | Some { Input_types.type_ = _; message = None } -> None
    | Some { Input_types.type_; message = Some message } ->
      status_node ~status_variant ~message_id type_ ~message
  in
  let root_attrs =
    Attr.class_
      ([ "astryx-field" ] @ (if is_label_hidden then [] else [ "astryx-field--labeled" ]))
    @ Attr.data "component" "Field"
    @ (match width with
       | None -> []
       | Some width -> Attr.style [ ("width", Common.Size_value.to_css width) ])
    @ attrs
  in
  let body =
    match status_variant with
    | Attached ->
      (* The wrapper exists so an attached status can be pulled up behind the control's bottom
         edge without escaping the field's own stacking surface. *)
      [ Vdom.Node.div
          ~attrs:(Attr.class_ [ "astryx-field__input-status" ])
          (children @ Option.to_list status_content)
      ]
    | Detached | Tooltip -> children @ Option.to_list status_content
  in
  Vdom.Node.div ~attrs:root_attrs (label_group :: body)
;;
