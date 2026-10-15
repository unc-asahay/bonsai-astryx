(* VisuallyHidden — mirrors Astryx's VisuallyHidden/VisuallyHidden.tsx.

   Renders content that assistive technology exposes but sight does not. The clip
   block is fixed (upstream deliberately omits className/style for this one, so a
   consumer cannot accidentally un-hide it); [element] defaults to a span and
   should be a block element for live regions. *)

open! Core
open! Bonsai_web

type element =
  | Span
  | Div
  | P

val view : ?element:element -> Vdom.Node.t list -> Vdom.Node.t
