open! Core
open! Bonsai_web

(* A synthetic component used only to rehearse the integration path. *)

let view ~(graph : Bonsai.graph) : Vdom.Node.t Bonsai.t =
  Bonsai.return
    (Vdom.Node.div
       ~attrs:
         [ Vdom.Attr.class_ "astryx-widget"
         ; Vdom.Attr.create "data-astryx-component" "Widget"
         ]
       [ Vdom.Node.text "widget" ])
