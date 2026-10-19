open! Core
open! Bonsai_web
open Prelude

module Widget = Astryx.Widget

let demo (graph : Bonsai.graph) : Vdom.Node.t Bonsai.t =
  Bonsai.return (section ~id:"widget" ~title:"Widget" ~note:"A synthetic section." [ ex "Widget" (Widget.view ~graph) ])
