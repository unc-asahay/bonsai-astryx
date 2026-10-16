open! Core
open! Bonsai_web

type color =
  | Primary
  | Secondary
  | Inherit

type size = Inherit

let color_class = function
  | Primary -> "astryx-code--primary"
  | Secondary -> "astryx-code--secondary"
  | Inherit -> "astryx-code--inherit"
;;

let color_data = function
  | Primary -> "primary"
  | Secondary -> "secondary"
  | Inherit -> "inherit"
;;

let view ?(color = Primary) ?size children =
  let attrs =
    Common.Attr.class_
      [ "astryx-code"
      ; color_class color
      ; (match size with Some Inherit -> "astryx-code--size-inherit" | None -> "")
      ]
    @ Common.Attr.data "component" "Code"
    @ Common.Attr.data "color" (color_data color)
  in
  Vdom.Node.code ~attrs children
;;
