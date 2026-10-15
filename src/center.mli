(* Center — mirrors Astryx's Center/Center.tsx.

   [axis] follows upstream's logical flex axes, not physical sides: with
   [Horizontal] the main/inline axis is centred, with [Vertical] the cross/block
   axis, and [Both] centres on both. [is_inline] swaps flex for inline-flex.

   Padding resolution matches upstream's precedence: the more specific property
   wins, so paddingInlineStart beats paddingInline beats padding (same for the
   block axis). The emitted style declarations are ordered least- to
   most-specific, which is what makes the browser apply that precedence. *)

open! Core
open! Bonsai_web

type axis =
  | Both
  | Horizontal
  | Vertical

val view
  :  ?axis:axis
  -> ?width:Common.Size_value.t
  -> ?height:Common.Size_value.t
  -> ?max_width:Common.Size_value.t
  -> ?min_height:Common.Size_value.t
  -> ?padding:Common.Spacing.t
  -> ?padding_inline:Common.Spacing.t
  -> ?padding_inline_start:Common.Spacing.t
  -> ?padding_inline_end:Common.Spacing.t
  -> ?padding_block:Common.Spacing.t
  -> ?padding_block_start:Common.Spacing.t
  -> ?padding_block_end:Common.Spacing.t
  -> ?is_inline:bool
  -> Vdom.Node.t list
  -> Vdom.Node.t
