open! Core
open! Bonsai_web

module Attr = Common.Attr

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
       @ (match description_id with
          | Some id -> [ Vdom.Attr.create "id" id ]
          | None -> []))
    [ Vdom.Node.text description ]
;;

let view
      ?label_icon
      ?label_id
      ?(is_group_label = false)
      ?(is_label_hidden = false)
      ?(is_disabled = false)
      ?(is_optional = false)
      ?(is_required = false)
      ?description
      ?description_id
      ?(attrs = [])
      ~label
      ~input_id
      ()
  =
  let marker = marker_text ~is_optional ~is_required in
  let label =
    label_node ~label ~label_icon ~marker ~label_id ~input_id ~is_group_label ~is_disabled
      ~is_label_hidden
  in
  let description =
    match description with
    | None -> []
    | Some text -> [ description_node ~description:text ~description_id ~is_label_hidden ]
  in
  Vdom.Node.div ~attrs:(Attr.class_ [ "astryx-field__label-group" ] @ attrs) (label :: description)
;;
