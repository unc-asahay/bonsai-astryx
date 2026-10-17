(** The fit arithmetic behind an overflowing list, with no DOM and no state in it.

    Upstream keeps this in a file of its own for a stated reason - it is the part of the overflow
    mechanism that can be reasoned about and tested without a browser - and the port keeps that split:
    {!useOverflow} measures, this decides. Porting it first, before the component that consumes it, is this
    port's ordering rule for a mechanism.

    There is one source of truth for the answer:

    {v visible_count = clamp (fit_count, min_visible_items, max_visible_items ?? item_count) v}

    Two rules that are easy to lose and are the reason the arithmetic is worth porting rather than
    approximating:

    - {b The floor wins.} When [max_visible_items] is below [min_visible_items], the final clamp takes the
      floor. Upstream's hook warns in development about the contradiction; the arithmetic resolves it.
    - {b The indicator is reserved for every non-final admitted item}, not merely for the last one - a single
      line that fits without room for the "+N" marker is not a line that fits.

    [collapse_from] names which end collapses: [Start] reverses the measured widths, so the items kept are
    the ones at the other end. [rows] is always 1 on the single-line path, and 0 when nothing is visible.
*)

type collapse_from =
  | Start
  | End

type t =
  { visible_count : int
  ; rows : int
  }
[@@deriving sexp_of]

(** [compute ~widths ~gap ~available_width ~indicator_width ~min_visible_items ?max_visible_items ?max_rows
    ~collapse_from]. [max_rows] above 1 selects the multi-row packing path; absent or 1 is a single line. *)
val compute
  :  widths:int list
  -> gap:int
  -> available_width:int
  -> indicator_width:int
  -> min_visible_items:int
  -> ?max_visible_items:int
  -> ?max_rows:int
  -> collapse_from:collapse_from
  -> unit
  -> t
