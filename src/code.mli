(* Code — a hand-port of Astryx's Code/Code.tsx.

   Renders a real <code> element (unlike Text's 'code' *type*, which is a span with
   code styling — upstream keeps those two separate and so does this port).

   [size = Inherit] is the only size upstream offers, and it exists for one case: a
   code span inside larger text, where the code font must not impose its own size. *)

open! Core
open! Bonsai_web

type color =
  | Primary
  | Secondary
  | Inherit

type size = Inherit

val view : ?color:color -> ?size:size -> Vdom.Node.t list -> Vdom.Node.t
