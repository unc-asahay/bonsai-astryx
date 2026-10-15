(* Badge — mirrors Astryx's Badge/Badge.tsx: a one-line status or category chip.
   Upstream semantic variants first (neutral, info, success, warning, error),
   then the extended colour set. *)

open! Core
open! Bonsai_web

type variant =
  | Neutral
  | Info
  | Success
  | Warning
  | Error
  | Blue
  | Cyan
  | Green
  | Orange
  | Pink
  | Purple
  | Red
  | Teal
  | Yellow

val view : ?variant:variant -> ?icon:Vdom.Node.t -> string -> Vdom.Node.t
