open! Core
open! Bonsai_web

type orientation = Common.List_focus.orientation =
  | Horizontal
  | Vertical

type elevation =
  | None_
  | Low
  | Med
  | High

(* The roving tab stop this group stands on lives in Common.List_focus, together with the note that
   explains why it is a mechanism and not a loop: the item selector, the wrap, and the boundary check. *)
module Roving_hook = Common.List_focus

(* --------------------------------------------------------------------------------------------- *)
(* The group                                                                                      *)
(* --------------------------------------------------------------------------------------------- *)

let elevation_class = function
  | None_ -> "astryx-button-group--elevation-none"
  | Low -> "astryx-button-group--elevation-low"
  | Med -> "astryx-button-group--elevation-med"
  | High -> "astryx-button-group--elevation-high"
;;

let view
  ?(attrs = [])
  ?(orientation = Horizontal)
  ?(elevation = None_)
  ?(is_disabled = false)
  ~label
  ~children
  ()
  =
  Vdom.Node.div
      ~attrs:
      (Common.Attr.class_
         [ "astryx-button-group"
         ; (match orientation with
            | Horizontal -> "astryx-button-group--horizontal"
            | Vertical -> "astryx-button-group--vertical")
         ; elevation_class elevation
         ]
       @ [ Vdom.Attr.create "role" "group"; Vdom.Attr.create "aria-label" label ]
       @ (if is_disabled then [ Vdom.Attr.create "aria-disabled" "true" ] else [])
       @ Common.Attr.data "component" "ButtonGroup"
       @ [ Roving_hook.attr ~orientation () ]
       @ attrs)
    children
;;
