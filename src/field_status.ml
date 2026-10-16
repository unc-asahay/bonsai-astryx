open! Core
open! Bonsai_web

type type_ =
  | Warning
  | Error
  | Success

type variant =
  | Attached
  | Detached

let type_class = function
  | Warning -> "astryx-field-status--warning"
  | Error -> "astryx-field-status--error"
  | Success -> "astryx-field-status--success"
;;

let variant_class = function
  | Attached -> "astryx-field-status--attached"
  | Detached -> "astryx-field-status--detached"
;;

let icon_name = function
  | Warning -> "warning"
  | Error -> "error"
  | Success -> "success"
;;

(* An error interrupts, so it is announced assertively; the others wait their turn. *)
let announcement_role = function
  | Error -> "alert"
  | Warning | Success -> "status"
;;

let view ?(variant = Attached) ?(attrs = []) ~type_ ~message () =
  let classes =
    [ "astryx-field-status"; type_class type_; variant_class variant ]
    @ (if Entry_animation.animate () then [ Entry_animation.class_ Entry_animation.Slide_down ]
       else [])
  in
  let content =
    match variant with
    | Attached ->
      (* Bare text: upstream renders the message directly, with no icon and no wrapper. *)
      [ Vdom.Node.text message ]
    | Detached ->
      [ Vdom.Node.span
          ~attrs:(Common.Attr.class_ [ "astryx-field-status__content" ])
          [ Vdom.Node.span
              ~attrs:(Common.Attr.class_ [ "astryx-field-status__icon" ])
              [ Icon.view ~size:Icon.Sm ~name:(icon_name type_) () ]
          ; Vdom.Node.span [ Vdom.Node.text message ]
          ]
      ]
  in
  Vdom.Node.div
    ~attrs:
      (Common.Attr.class_ classes
       @ Common.Attr.data "component" "FieldStatus"
       @ [ Vdom.Attr.create "role" (announcement_role type_) ]
       @ attrs)
    content
;;
