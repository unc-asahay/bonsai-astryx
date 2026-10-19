(** A data-driven tree list.

    Port of upstream `TreeList` (TreeList.tsx + TreeListItem.tsx +
    TreeListBranches.tsx + TreeListTypes.ts + useTreeFocus.ts). Accepts a
    recursive [items] structure; expansion state is internal, seeded from
    per-item [is_expanded]. Keyboard model: ArrowUp/ArrowDown/Home/End roam the
    visible treeitems, ArrowRight expands / moves to first child, ArrowLeft
    collapses / moves to parent, Enter/Space activate the row's own inner
    action (falling back to toggling), printable characters typeahead against
    the label. Exactly one treeitem is the single tab stop (roving tabindex),
    repaired on focus. *)

open! Core
open! Bonsai_web

type density =
  | Compact
  | Balanced
  | Spacious

type variant =
  | Line_guides (** connector lines between parent and child rows (default) *)
  | No_guides (** indentation alone conveys nesting *)

type item = {
  id : string;
  label : Vdom.Node.t;
  description : string option;
  start_content : Vdom.Node.t option;
  end_content : Vdom.Node.t option;
  children : item list;
  on_click : (unit -> unit) option;
  href : string option;
  target : string option;
  is_disabled : bool;
  is_selected : bool;
  is_expanded : bool;
}

val view :
     ?id:string
  -> ?attrs:Vdom.Attr.t list
  -> ?density:density
  -> ?variant:variant
  -> ?header:Vdom.Node.t list
  -> items:item list
  -> Bonsai.graph
  -> Vdom.Node.t Bonsai.t
(** [view ~items ?density ?variant ?header graph]. A leaf reserves the chevron
    column (so its label lines up under a parent's caret) whenever the tree
    contains any expandable item — a whole-tree property, as upstream computes
    it. *)
