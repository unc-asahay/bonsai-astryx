(* Section — mirrors Astryx's Section/Section.tsx: a page region with a
   background variant, spacing-scale padding (default step 4) and optional
   divider borders on chosen sides.

   Note [dividers] takes logical sides ([Start]/[End] map to the inline-start /
   inline-end borders), matching upstream. *)

open! Core
open! Bonsai_web

type variant =
  | Section
  | Transparent
  | Muted

type side =
  | Top
  | Bottom
  | Start
  | End

val view
  :  ?variant:variant
  -> ?dividers:side list
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
  -> Vdom.Node.t list
  -> Vdom.Node.t
