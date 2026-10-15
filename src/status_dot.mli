(* StatusDot — mirrors Astryx's StatusDot/StatusDot.tsx: a coloured dot carrying
   a required accessible [label]. Decorative to sighted users, meaningful to
   assistive tech, so it renders role="img" with aria-label. *)

open! Core
open! Bonsai_web

type variant =
  | Success
  | Warning
  | Error
  | Accent
  | Neutral

val view : variant:variant -> label:string -> ?is_pulsing:bool -> ?icon:Vdom.Node.t -> unit -> Vdom.Node.t
