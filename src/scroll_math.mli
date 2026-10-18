(** The geometry arithmetic behind a logical-axis scroll viewport, with no DOM and
    no state in it.

    Upstream keeps this in [hooks/scrollGeometry.ts] for the same reason
    [overflow_math] is separate: it is the part that can be reasoned about and
    tested without a browser. The port keeps that split - the scroll hook
    measures, this decides.

    The rules worth stating out loud, because they are the reason the arithmetic
    is ported rather than approximated:

    - {b Tolerance.} A viewport with less than or equal to 1px of excess content
      is not overflowing, and a scroll offset within 1px of an edge is that
      edge. [SCROLL_OVERFLOW_TOLERANCE] in upstream.
    - {b Scroll-capable overflow is required} for an axis to be [is_scrollable]:
      [auto], [scroll], or [overlay]. A `hidden` overflow axis is not scrollable
      and reports the inactive edge state.
    - {b Logical edges through reversed axes.} In RTL the inline axis runs right
      to left, so an inline scroll offset is normalised through the reversal
      before the edge test: [at_start] is the logical start, not the physical
      [scrollLeft = 0].

    [mapping] is one: a writing-mode/direction pair determines which physical
    axis each logical axis resolves to and whether each is reversed. *)

type logical_axis =
  | Inline
  | Block

type physical_axis =
  | X
  | Y

type mapping =
  { inline : physical_axis
  ; block : physical_axis
  ; inline_reversed : bool
  ; block_reversed : bool
  }
[@@deriving sexp_of, equal]

type axis_state =
  { is_scrollable : bool
  ; at_start : bool
  ; at_end : bool
  }
[@@deriving sexp_of, equal]

(** The state of an axis that was not measured (or was measured and found not
    scrollable): not scrollable, and both edges trivially at rest. *)
val inactive_axis_state : axis_state

val tolerance : int

(** [mapping_of ~writing_mode ~direction]. Horizontal writing modes map inline
    to x/block to y, reversed iff RTL. Vertical and sideways modes swap the axes
    (inline is y, block is x); [sideways-lr] runs its natural inline direction
    bottom-to-top and [direction] reverses each. *)
val mapping_of : writing_mode:string -> direction:string -> mapping

(** True iff the computed overflow value can be scrolled: [auto], [scroll],
    [overlay]. *)
val is_scroll_capable : string -> bool

(** [overflow_geometry ~client_extent ~content_extent] - whether content exceeds
    the client extent by more than the tolerance. *)
val overflow_geometry : client_extent:int -> content_extent:int -> bool

(** [scroll_axis ~client_extent ~content_extent ~offset ~overflow ~reversed] -
    the edge state of one axis. Returns [inactive_axis_state] when the axis is
    not scroll-capable or has no room; otherwise [is_scrollable] is true and the
    offset is normalised through [reversed] before the edge test. *)
val scroll_axis
  :  client_extent:int
  -> content_extent:int
  -> offset:int
  -> overflow:string
  -> reversed:bool
  -> axis_state
