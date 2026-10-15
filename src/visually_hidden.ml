open! Core
open! Bonsai_web

type element =
  | Span
  | Div
  | P

let element_string = function
  | Span -> "span"
  | Div -> "div"
  | P -> "p"
;;

let view ?(element = Span) children =
  let attrs =
    Common.Attr.class_ [ "astryx-visually-hidden" ]
    @ Common.Attr.data "component" "VisuallyHidden"
    @ Common.Attr.data "element" (element_string element)
  in
  match element with
  | Span -> Vdom.Node.span ~attrs children
  | Div -> Vdom.Node.div ~attrs children
  | P -> Vdom.Node.p ~attrs children
;;
