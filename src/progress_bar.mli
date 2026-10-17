(** A bar that reports how far along something is.

    The value, the track and the fill are one component; the [role="progressbar"] sits on the *track* and
    carries the numbers, with the label outside it pointing in through [aria-labelledby]. That shape is
    upstream's and it matters: a label hidden from view must still name the bar.

    {2 Marks}

    A mark is a labelled point on the track, and every mark is wrapped in a {!Tooltip} whose trigger is the
    tick — the tick is focusable in its own right and stays *outside* the progressbar role, so a keyboard user
    can reach each mark's label without the bar's own value being announced again. [marks] is ignored when the
    bar is indeterminate, because a point on a track that has no position is not a point.

    {2 Divergences}

    - Upstream loads the mark tooltip lazily (a dynamic import behind Suspense) so a bar without marks never
      carries it. The port has no code splitting, so the tooltip is part of the component either way.
    - That tooltip owns state, so [view] takes the graph whether or not the bar has marks: the port cannot ask
      for a graph conditionally. A bar without marks has nothing stateful in it, but the shape is the same, and
      the consequence is that the jsdom gate cannot render this component at all — its checks live in the
      browser gate, which measures the fill rather than reading a class.
    - Upstream exposes [themeProps('progress-bar', ...)] for the theme layer. The port styles by class.
    - [id] is the root's name as well as the prefix for the label's and the marks' ids, so the bar is findable
      by the name the caller gave it.
    - [format_value_label] is a plain function in both; the port's default rounds to a whole percent, and a
      [max] of zero or less reports 0% rather than dividing by it.
*)
open! Core
open! Bonsai_web

(** [Accent] is upstream's default. *)
type variant =
  | Accent
  | Success
  | Warning
  | Neutral
  | Error

type mark =
  { value : float
  ; label : string
  }

val view
  :  ?attrs:Vdom.Attr.t list
  -> ?id:string
  -> ?value:float
  -> ?max:float
  -> ?is_label_hidden:bool
  -> ?has_value_label:bool
  -> ?format_value_label:(float -> float -> string)
  -> ?variant:variant
  -> ?is_indeterminate:bool
  -> ?is_disabled:bool
  -> ?marks:mark list
  -> label:string
  -> Bonsai.graph
  -> Vdom.Node.t Bonsai.t
