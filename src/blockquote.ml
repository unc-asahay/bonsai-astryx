open! Core
open! Bonsai_web

let view ?cite children =
  let attrs =
    Common.Attr.class_ [ "astryx-blockquote" ] @ Common.Attr.data "component" "Blockquote"
  in
  let cite_node =
    match cite with
    | None -> []
    | Some cite ->
      [ Vdom.Node.cite
          ~attrs:[ Vdom.Attr.class_ "astryx-blockquote__cite" ]
          [ cite ]
      ]
  in
  Vdom.Node.blockquote ~attrs (children @ cite_node)
;;
