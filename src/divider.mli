(* Divider — mirrors Astryx's Divider/Divider.tsx. Renders a separator; when a
   label is supplied upstream centres it on the line. *)

open! Core
open! Bonsai_web

type orientation =
  | Horizontal
  | Vertical

type variant =
  | Subtle
  | Strong

val view
  :  ?orientation:orientation
  -> ?variant:variant
  -> ?label:Vdom.Node.t
  -> ?is_full_bleed:bool
  -> unit
  -> Vdom.Node.t
