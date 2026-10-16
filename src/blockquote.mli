(* Blockquote — a hand-port of Astryx's Blockquote/Blockquote.tsx.

   The optional [cite] renders as a bare <cite>, never wrapped in a <footer>.
   Upstream's comment explains why and it is worth keeping: <blockquote> is a
   sectioning root, so a <footer> inside it maps to a contentinfo document landmark —
   a quote would get an accessibility landmark it should not have. *)

open! Core
open! Bonsai_web

val view : ?cite:Vdom.Node.t -> Vdom.Node.t list -> Vdom.Node.t
