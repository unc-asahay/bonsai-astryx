open! Core
open! Bonsai_web

let view ?(attrs = []) ~children () =
  Vdom.Node.div
    ~attrs:
      ([ Vdom.Attr.class_ "astryx-input-group-text" ]
       @ Common.Attr.data "component" "InputGroupText"
       @ attrs)
    children
;;
