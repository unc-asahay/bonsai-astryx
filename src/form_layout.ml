open! Core
open! Bonsai_web

module Attr = Common.Attr

type direction =
  | Vertical
  | Horizontal
  | Horizontal_labels

type optionality = Common.Optionality.t =
  | Optional
  | Required

let direction_class = function
  | Vertical -> "astryx-form-layout--vertical"
  | Horizontal -> "astryx-form-layout--horizontal"
  | Horizontal_labels -> "astryx-form-layout--horizontal-labels"
;;

let direction_name = function
  | Vertical -> "vertical"
  | Horizontal -> "horizontal"
  | Horizontal_labels -> "horizontal-labels"
;;

let view ?(attrs = []) ?(direction = Vertical) ~children () =
  Vdom.Node.div
    ~attrs:
      (Attr.class_ [ "astryx-form-layout"; direction_class direction ]
       @ Attr.data "component" "FormLayout"
       @ Attr.data "direction" (direction_name direction)
       @ attrs)
    children
;;
