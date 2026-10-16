(* AspectRatio — a hand-port of Astryx's AspectRatio/AspectRatio.tsx.

   Structure is upstream's, and it is two elements, not one: the outer box holds
   the ratio and the clipping, and the inner box is what fills it. The inner box
   carries [data-astryx-aspect-ratio-override] only when [fit] is given — that
   attribute is what the baseline child-sizing rules in components.css key on, so
   a child that sizes itself still wins. *)

open! Core
open! Bonsai_web

(* [rectangle] (default) is a plain box; [ellipse] clips to a 50% border radius, so
   the result is a circle at ratio 1 and an oval at other ratios. *)
type shape =
  | Rectangle
  | Ellipse

(* How the child fills the box: [cover] crops, [contain] letterboxes, [center] keeps
   the child at its natural size in the middle. Omitted, the child styles itself. *)
type fit =
  | Cover
  | Contain
  | Center

val view : ?shape:shape -> ?fit:fit -> ratio:float -> Vdom.Node.t list -> Vdom.Node.t
