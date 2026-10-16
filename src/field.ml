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

(* Upstream: isOptional takes precedence, and setting both is a dev warning. *)
let marker_text ~is_optional ~is_required =
  if is_optional then Some "Optional" else if is_required then Some "Required" else None
;;

(* The label text, the icon before it, and the required/optional marker after it. The marker is
   two nodes: a separator that is decoration (hence aria-hidden) and the word itself, which is
   part of what a screen reader reads out with the label. *)
let label_children ~label ~label_icon ~marker =
  let icon =
    match label_icon with
    | Some name -> [ Icon.view ~name ~size:Icon.Sm ~color:Icon.Inherit () ]
    | None -> []
  in
  let marker =
    match marker with
    | None -> []
    | Some text ->
      [ Vdom.Node.span
          ~attrs:(Attr.class_ [ "astryx-field__marker" ])
          [ Vdom.Node.span ~attrs:(Attr.aria "hidden" "true") [ Vdom.Node.text " \xe2\x88\x99 " ]
          ; Vdom.Node.text text
          ]
      ]
  in
  icon @ (Vdom.Node.text label :: marker)
;;

let label_node ~label ~label_icon ~marker ~label_id ~input_id ~is_group_label ~is_disabled
      ~is_label_hidden
  =
  let attrs =
    Attr.class_
      ([ "astryx-field__label" ]
       @ (if is_label_hidden then [ "astryx-visually-hidden" ] else []))
    (* A <label> names one control, so it carries htmlFor; a group label is a <span> and the
       group names itself from it with aria-labelledby. *)
    @ (if is_group_label then [] else [ Vdom.Attr.create "for" input_id ])
    @ (match label_id with Some id -> [ Vdom.Attr.create "id" id ] | None -> [])
    @ (if is_disabled then Attr.data "disabled" "true" else [])
  in
  let children = label_children ~label ~label_icon ~marker in
  if is_group_label then Vdom.Node.span ~attrs children else Vdom.Node.label ~attrs children
;;

let description_node ~description ~description_id ~is_label_hidden =
  Vdom.Node.span
    ~attrs:
      (Attr.class_
         ([ "astryx-field__description" ]
          @ (if is_label_hidden then [ "astryx-visually-hidden" ] else []))
       @ [ Vdom.Attr.create "id" description_id ])
    [ Vdom.Node.text description ]
;;

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
  let marker = marker_text ~is_optional ~is_required in
  let label_node =
    label_node ~label ~label_icon ~marker ~label_id ~input_id ~is_group_label ~is_disabled
      ~is_label_hidden
  in
  let label_group =
    Vdom.Node.div
      ~attrs:(Attr.class_ [ "astryx-field__label-group" ])
      (label_node
       :: (match description with
           | None -> []
           | Some text ->
             [ description_node ~description:text ~description_id ~is_label_hidden ]))
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
