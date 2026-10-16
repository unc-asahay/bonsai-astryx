(* HStack — a hand-port of Astryx's HStack/HStack.tsx.

   Upstream HStack is a thin wrapper: it forwards every Stack prop and pins
   [direction='horizontal'], resolving [hAlign = hAlign ?? justify] and
   [vAlign = vAlign ?? align]. Forwarding to Stack gives the same result, because
   Stack resolves justify/align as main/cross-axis aliases under Horizontal.

   It renders with Stack's marker (data-astryx-component="Stack"), exactly as
   upstream does — HStack is a prop preset, not a separate component identity. *)

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
