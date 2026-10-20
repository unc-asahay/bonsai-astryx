open! Core
open! Bonsai_web

(** The Pagination — standalone controls for navigating through pages of content.

    A pagination shows where you are in a long list and lets you move: the
    previous and next controls, the page numbers with their ellipses, the
    number of items on the page, and a way to jump straight to a page.

    The page is a value the caller owns. The pagination never moves itself; it
    reports the page you asked for through [on_change] and the caller moves.

    {2 Example}

    {[
      let page, set_page = Bonsai.state 1 graph in
      Pagination.view
        ~page
        ~on_change:(Bonsai.map set_page ~f:(fun set -> fun (p : int) -> set p))
        ~total_items:200
        ~page_size:20
        graph
    ]} *)

(** What appears between the previous and next controls.

    - [Pages] (the default) shows the page numbers, with an ellipsis where
      the pages in between are left out.
    - [Count] shows "1–20 of 200" — the range of items on the page.
    - [Compact] shows "Page 1 of 10".
    - [Dots] shows one dot per page.
    - [Input] shows an editable box: "Page [ 1 ] of 10".
    - [None] shows nothing between them. *)
type variant =
  | Pages
  | Count
  | Compact
  | Dots
  | Input
  | None_

(** The size of the controls. *)
type size =
  | Sm
  | Md

(** One slot in the page range: a page number, or an ellipsis. *)
type range_item =
  | Page of int
  | Ellipsis

(** The page numbers to show, and where the ellipses go.

    The slots are the first page, the last page, the current page and its
    [sibling_count] neighbours on each side, plus room for two ellipses. When
    the pages fit in the slots, every page is shown.

    {[
      generate_page_range ~current_page:5 ~total_pages:10 ~sibling_count:1
      = [ Page 1; Ellipsis; Page 4; Page 5; Page 6; Ellipsis; Page 10 ]
    ]} *)
val generate_page_range
  :  current_page:int
  -> total_pages:int
  -> sibling_count:int
  -> range_item list

(** [view] renders the pagination.

    @param page the current page, 1-based. The caller owns it.
    @param on_change called with the page the user asked for. The pagination
      never moves itself.
    @param total_items the number of items in the whole list. It takes
      precedence over [total_pages] when both are given.
    @param total_pages the number of pages, for when the count of items is not
      known.
    @param has_more whether more pages follow the current one — for cursor
      pagination, where the total is not known.
    @param page_size the number of items on a page. It only matters for
      working out the page count from the item count. Defaults to 10.
    @param variant what appears between the previous and next controls.
    @param label the navigation region's accessible name. Defaults to
      "Pagination".
    @param page_label the noun before the editable box in the [Input] variant.
      Defaults to "Page".
    @param has_first_last whether the first and last page controls are shown.
      They are shown by default in the [Input] variant and only on request in
      the [Compact] one; the other variants ignore it. The last control needs
      a known page count, so both are left out when the total is unknown.
    @param step how many pages the previous and next controls move per click.
      A step that would go past the end lands on the first or last page.
      Defaults to 1.
    @param sibling_count how many page numbers to show on each side of the
      current one. It only applies to the [Pages] variant. Defaults to 1.
    @param size the size of the controls.
    @param is_disabled whether the controls are inert. *)
val view
  :  ?attrs:Vdom.Attr.t list
  -> ?id:string
  -> ?variant:variant
  -> ?size:size
  -> ?label:string
  -> ?total_items:int
  -> ?total_pages:int
  -> ?has_more:bool
  -> ?page_size:int
  -> ?page_label:string
  -> ?has_first_last:bool
  -> ?step:int
  -> ?sibling_count:int
  -> ?is_disabled:bool
  -> on_change:(int -> unit Effect.t) Bonsai.t
  -> page:int Bonsai.t
  -> Bonsai.graph
  -> Vdom.Node.t Bonsai.t

(** {2 Divergences from upstream}

    - Upstream's [changeAction] runs an async action after [onChange] and
      keeps an optimistic page number while it runs. There is no transition
      here: the page is a value the caller owns, so the caller decides what
      happens while it loads, and this port's [?is_loading] is not needed
      either — the controls stay as they are until the page changes.

    - Upstream's page-size selector is a [Selector] component, and this
      library has no [Selector] yet, so the selector is not ported. The page
      count is still worked out from [?total_items] and [?page_size], and
      [?page_size] still decides what the count variant reports.

    - Upstream's strings come from the [@astryx.pagination.*] translation
      namespace. This library has no translation layer, so they are spelled
      out here in English. *)
