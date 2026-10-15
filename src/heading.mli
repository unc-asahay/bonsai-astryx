(* Heading — mirrors Astryx's Heading/Heading.tsx.

   [level] is required and selects the semantic element (h1-h6). Astryx renders
   the *visual* 1-6 scale from [level] while [accessibility_level] can override
   the announced level via aria-level. *)

open! Core
open! Bonsai_web

type level =
  | H1
  | H2
  | H3
  | H4
  | H5
  | H6

val view
  :  ?accessibility_level:level
  -> level:level
  -> ?weight:Text.weight
  -> ?color:Text.color
  -> ?display:Text.display
  -> ?max_lines:int
  -> ?justify:Common.Alignment.t
  -> ?has_strikethrough:bool
  -> Vdom.Node.t list
  -> Vdom.Node.t
