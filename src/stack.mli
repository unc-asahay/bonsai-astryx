(* Stack — layout primitive. Mirrors Astryx's Stack/Stack.tsx props.

   [h_align] / [v_align] resolve per [direction]: with [Horizontal] hAlign drives
   the main axis (justify-content) and vAlign the cross axis (align-items); with
   [Vertical] the reverse. [justify] and [align] are axis aliases that win over
   them. See Common.Alignment for the per-axis legality rule. *)

open! Core
open! Bonsai_web

type direction =
  | Horizontal
  | Vertical

(* Alias for readability; the constructors live in Common.Alignment. *)
type align = Common.Alignment.t

val view
  :  ?direction:direction
  -> ?h_align:Common.Alignment.t
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
