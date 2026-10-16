open! Core
open! Bonsai_web

let view ?(attrs = []) ~icon () =
  Vdom.Node.span
    ~attrs:
      (Common.Attr.class_ [ "astryx-nav-icon" ]
       @ Common.Attr.data "component" "NavIcon"
       @ attrs)
    [ icon ]
;;
