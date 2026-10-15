(* Grid — mirrors Astryx's Grid/Grid.tsx.

   [columns] reproduces upstream's two documented forms and their exact CSS:
     [Fixed n]                    -> repeat(n, 1fr)                     (n > 0)
     [Responsive (px, Fill)]      -> repeat(auto-fill, minmax(px, 1fr))
     [Responsive (px, Fit)]       -> repeat(auto-fit, minmax(px, 1fr))

   Divergence, deliberate and bounded: upstream's `{max}` form (capping the
   track count, which needs a calc over the container width) is not ported. If
   you need it, wrap the Grid and set a max-width — and please send the parity
   test when you do.

   [align]/[justify] reuse Common.Alignment; values that are illegal for the
   grid axes (Between/Around/Evenly) fall back to start, the same rule the rest
   of the port uses. *)

open! Core
open! Bonsai_web

type repeat =
  | Fill
  | Fit

type columns =
  | Fixed of int
  | Responsive of int * repeat

val view
  :  ?columns:columns
  -> ?gap:Common.Spacing.t
  -> ?row_gap:Common.Spacing.t
  -> ?column_gap:Common.Spacing.t
  -> ?align:Common.Alignment.t
  -> ?justify:Common.Alignment.t
  -> ?width:Common.Size_value.t
  -> ?height:Common.Size_value.t
  -> ?max_width:Common.Size_value.t
  -> ?min_height:Common.Size_value.t
  -> Vdom.Node.t list
  -> Vdom.Node.t
