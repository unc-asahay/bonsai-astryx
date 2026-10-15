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
  -> Vdom.Node.t list
  -> Vdom.Node.t
