(** Terms and their values, as a real [<dl>].

    {2 Layout}

    The list decides the layout and the items live in it, which is the whole reason this component has an API
    at all: every grid below is chosen here, from [columns] and the label position, and reaches the items as
    their container.

    - [columns] is [Single], [Multi], or [Fixed n] for an explicit count. [Multi] is a responsive
      [repeat(auto-fill, minmax(280px, 1fr))]; [Fixed n] is [n] columns whether or not the box is wide enough
      for them.
    - [label_position] is [Start] (inline: term, then value) or [Top] (stacked). Left unset it follows the
      columns - [Top] when there is more than one, [Start] otherwise - and it is always [Top] when the
      orientation is [Horizontal], where an inline pair would have no column to align to.
    - [label_width] fixes the inline term column, which is otherwise [auto]. Ignored when the labels are
      stacked, since there is no term column then.
    - [max_num_of_items] truncates the list and renders a show-all toggle. It is ignored when the orientation
      is [Horizontal] - a row of pairs has no meaningful first N.

    {2 [items] rather than [children]}

    Each item is the *list of nodes it contributes* - its term and its value - because an item renders as a
    fragment, which is what lets the grid place the two halves. Upstream slices React children, so its
    truncation cuts between items by construction; a flat node list here would have to be sliced by node
    count, and that cuts a pair in half for any N. Taking the items keeps the boundary in the type, where it
    cannot be got wrong. The browser gate found this: a three-item slice of a flattened list rendered three
    [<dt>] against six [<dd>].

    {2 Divergences}

    - Upstream exposes a [themeProps] hook for the theme layer to style the root. The port has no such layer
      and styles by class, so there is nothing to pass through.
    - Upstream renders the show-all toggle text through its i18n catalogue, with the number of hidden items
      interpolated into it. The port takes the two labels as arguments, defaulted to English, and does not
      interpolate a count - the caller has the list and can word it as it likes.
    - Upstream derives the content id from [useId], so every list on a page is unique by construction. The
      port takes [?id], puts it on the root - so the list is findable by the name the caller gave it - and
      derives [<id>-content] for the [<dl>] the toggle points at. Two lists on one page must be given
      distinct ids.
    - [max_num_of_items] of zero or less is a programming error, not a truncation to empty: it raises.
*)
open! Core
open! Bonsai_web

type columns =
  | Single
  | Multi
  | Fixed of int

type label_position =
  | Start
  | Top

(** The same type as the roving mechanism uses for its axis: a list laid out horizontally is not a
    differently-oriented thing from a toolbar laid out horizontally, and a second type meaning the same thing
    would only invite a conversion. *)
type orientation = Common.List_focus.orientation =
  | Horizontal
  | Vertical

val view
  :  ?attrs:Vdom.Attr.t list
  -> ?id:string
  -> ?title:Vdom.Node.t
  -> ?columns:columns
  -> ?label_position:label_position
  -> ?label_width:string
  -> ?orientation:orientation
  -> ?max_num_of_items:int
  -> ?show_all_label:string
  -> ?show_less_label:string
  -> items:Vdom.Node.t list list Bonsai.t
  -> Bonsai.graph
  -> Vdom.Node.t Bonsai.t
