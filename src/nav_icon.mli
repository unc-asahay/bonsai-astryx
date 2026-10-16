(* NavIcon — a hand-port of Astryx's NavIcon/NavIcon.tsx.

   The smallest component in the library: one fixed-size round accent bubble holding one
   icon, used as the leading badge in a navigation row. Upstream is a single <span> and
   nothing else, so the port has no wrapper element either.

   [icon] is the caller's node, and like upstream the port does not mark it aria-hidden.
   NavIcon's contract is purely visual; whether the icon is decorative or meaningful is
   the caller's decision (a decorative icon should carry aria-hidden itself). Hiding it
   here would silence an icon that a caller deliberately gave a role and a label. *)

open! Core
open! Bonsai_web

val view : ?attrs:Vdom.Attr.t list -> icon:Vdom.Node.t -> unit -> Vdom.Node.t
