(* VStack — a hand-port of Astryx's VStack (the mirror of HStack).

   Same shape as Hstack: every Stack prop is forwarded, [direction] pinned to
   [vertical]. Under Vertical the axes swap, so [v_align] drives the main axis and
   [h_align] the cross axis — which is what upstream's VStack does by putting
   [vAlign] on the main axis. Renders with Stack's marker, as upstream does. *)

open! Core
open! Bonsai_web

val view
  :  ?h_align:Common.Alignment.t
  -> ?v_align:Common.Alignment.t
  -> ?justify:Common.Alignment.t
  -> ?align:Common.Alignment.t
  -> ?gap:Common.Spacing.t
  -> ?padding:Common.Spacing.t
  -> ?padding_inline:Common.Spacing.t
  -> ?padding_block:Common.Spacing.t
  -> ?width:Common.Size_value.t
  -> ?height:Common.Size_value.t
  -> ?max_width:Common.Size_value.t
  -> ?min_height:Common.Size_value.t
  -> ?is_scrollable:bool
  -> ?wrap:bool
  -> Vdom.Node.t list
  -> Vdom.Node.t
