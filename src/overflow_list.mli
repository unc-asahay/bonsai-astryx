(** A row that shows what fits and collapses the rest behind an indicator.

    Two containers, and the split is the whole design. The items are rendered into a **hidden
    measurement container** - [visibility: hidden], not [display: none], because a [display: none]
    element has an [offsetWidth] of 0 and every item measured through it would read as zero - and the
    hook measures that container and its children. The visible row then renders only the slice that
    fits. Upstream states the reason in one line: measuring the real row would mean rendering
    everything, measuring, and collapsing, which flickers.

    The indicator's width is measured, not given: its label's width depends on the content and on the
    count, so a constant would be wrong for every case but one. In the measurement container it is
    rendered with **every** item hidden, which is the widest label it can ever carry, so the room
    reserved for it is never too little.

    Before the first measurement the list shows everything and the measurement collapses it. That
    ordering is deliberate: the hook always reports its first measurement (its record of the last
    value it reported starts empty), so nothing is rendered in a collapsed state on the first paint
    and then expanded.

    {2 Divergences}

    - The [items] are nodes rather than a render-prop over data, as everywhere else in this port. The
      consequence is that the caller's item order is the caller's business: [collapse_from] keeps the
      opposite end, and no item is re-ordered to keep a preferred one visible.
    - Upstream returns [rowHeight] and [hasOverflow] from the hook and offers a render-prop for the
      indicator. Here the indicator is a label function, and only the count is surfaced, because
      nothing in this port yet consumes the others.
    - [max_rows] above 1 relies on the stylesheet to wrap; no row height is measured.
    - [gap] is a spacing-scale token, as upstream's is, and the row is laid out with it. The hook
      reads the resulting pixel gap back off the element's computed style rather than being told it,
      so the measured gap and the applied gap cannot disagree - the failure mode of the other way is
      a count that is wrong by exactly the gap, which is invisible until it is not. *)

open! Core
open! Bonsai_web

type collapse_from = Overflow_math.collapse_from =
  | Start
  | End

val view
  :  ?max_visible_items:int
  -> ?max_rows:int
  -> ?min_visible_items:int
  -> ?gap:Common.Spacing.t
  -> ?collapse_from:collapse_from
  -> ?overflow_label:(int -> string)
  -> ?attrs:Vdom.Attr.t list
  -> items:Vdom.Node.t list
  -> Bonsai.graph
  -> unit
  -> Vdom.Node.t Bonsai.t
