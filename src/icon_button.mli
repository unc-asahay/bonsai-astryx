(* IconButton — a hand-port of Astryx's IconButton/IconButton.tsx.

   Upstream is five lines: [<Button {...props} icon={icon} isIconOnly />], with
   [isIconOnly], [children] and [endContent] removed from the prop set. This port is
   the same preset, so it renders through Button and carries Button's marker — as
   upstream does. It also inherits Button's accessibility contract, which is the
   whole point: [label] is required and becomes the accessible name (aria-label)
   rather than visible text, so an icon-only control can never be nameless. *)

open! Core
open! Bonsai_web

val view
  :  label:string
  -> icon:Vdom.Node.t
  -> ?variant:Button.variant
  -> ?size:Button.size
  -> ?elevation:Button.elevation
  -> ?type_:Button.type_
  -> ?is_loading:bool
  -> ?is_disabled:bool
  -> ?width:Common.Size_value.t
  -> ?href:string
  -> ?target:string
  -> ?rel:string
  -> ?on_click:(Js_of_ocaml.Dom_html.mouseEvent Js_of_ocaml.Js.t -> unit Ui_effect.t)
  -> unit
  -> Vdom.Node.t
