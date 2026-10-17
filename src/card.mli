(* Card — mirrors Astryx's Card/Card.tsx (variant, elevation, spacing-step
   padding, size values). Content is whatever you pass as children. *)

open! Core
open! Bonsai_web

type variant =
  | Default
  | Transparent
  | Muted
  | Blue
  | Cyan
  | Gray
  | Green
  | Orange
  | Pink
  | Purple
  | Red
  | Teal
  | Yellow

val variant_of_string : string -> variant
val view
  :  ?variant:variant
  -> ?elevation:Button.elevation
  -> ?padding:Common.Spacing.t
  -> ?width:Common.Size_value.t
  -> ?height:Common.Size_value.t
  -> ?max_width:Common.Size_value.t
  -> ?min_height:Common.Size_value.t
  -> ?component_name:string
  -> ?attrs:Vdom.Attr.t list
  -> Vdom.Node.t list
  -> Vdom.Node.t

(** [component_name] names the marker this card stamps. Card defaults to ["Card"], and a component that
    renders {i through} Card - as {!Selectable_card} and [Clickable_card] do - passes its own name, because
    every tool in this repo identifies a component by that marker and a wrapper that keeps its delegate's
    name is invisible to all of them. The same argument as [Button.view]'s [component_name], and the same
    reason: passing the attribute in through [attrs] does not work, because two attributes of one name meet
    and one silently wins. [attrs] is for the wrapper's own attributes. *)
