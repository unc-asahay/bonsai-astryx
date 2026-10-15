(* Skeleton — mirrors Astryx's Skeleton/Skeleton.tsx: a placeholder shape for
   content that is still loading. Decorative, so aria-hidden. *)

open! Core
open! Bonsai_web

type radius =
  | R_none
  | R0
  | R1
  | R2
  | R3
  | R4
  | Rounded

val view
  :  ?width:Common.Size_value.t
  -> ?height:Common.Size_value.t
  -> ?radius:radius
  -> ?index:int
  -> unit
  -> Vdom.Node.t
