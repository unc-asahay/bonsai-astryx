(* The Pagination showcase section: the page controls, in the variants upstream
   ships.

   The page is a value the caller owns, so every example here owns its own
   current page and moves it when a control is clicked. That is what makes
   them worth clicking: the page numbers follow the current page, the count
   follows the range of items, and the previous and next controls disable
   themselves at the ends.

   The examples cover upstream's own variants - the page numbers with their
   ellipses, the item count, the compact "Page 3 of 10", the dots, the
   editable page number - plus the two cases that are not a variant but a
   configuration: a step of five pages at a time, and a list whose end is not
   known, where the only next control is the one that matters.

   Every example carries a distinct DOM id, so the browser gate can address
   it: "showcase-pagination-<variant>". *)

open! Core
open! Bonsai_web
open Prelude

module S = Astryx.Pagination

(* A pagination that owns its own page. The page is a value; the pagination
   reports the page it wants and this is what moves it. *)
let pager ?(page = 1) ?on_change ?total_items ?total_pages ?has_more ?variant ?size
    ?page_size ?step ?has_first_last ?sibling_count ?id () graph =
  let page, set_page = Bonsai.state page graph in
  let on_change =
    match on_change with
    | Some on_change -> on_change
    | None ->
      Bonsai.map set_page ~f:(fun set_page -> fun (p : int) -> set_page p)
  in
  let tree =
    S.view
      ?id
      ?variant
      ?size
      ?total_items
      ?total_pages
      ?has_more
      ?page_size
      ?step
      ?has_first_last
      ?sibling_count
      ~page
      ~on_change
      graph
  in
  tree
;;

let demo (graph : Bonsai.graph) : Vdom.Node.t Bonsai.t =
  let ex_tree label tree = Bonsai.map tree ~f:(fun node -> ex label node) in
  let trees =
    [ (* The page numbers, with the ellipses where the pages in between are
         left out. *)
      ex_tree
        "pages"
        (pager ~id:"showcase-pagination-pages" ~total_items:200 ~page_size:20 () graph)
    ; (* The count of items: which slice of the list is on the page. *)
      ex_tree
        "count"
        (pager
           ~id:"showcase-pagination-count"
           ~variant:S.Count
           ~total_items:200
           ~page_size:20
           () graph)
    ; (* The compact form: which page out of how many. *)
      ex_tree
        "compact"
        (pager
           ~id:"showcase-pagination-compact"
           ~variant:S.Compact
           ~total_items:200
           ~page_size:20
           () graph)
    ; (* The dots: one per page, for when there are only a handful. *)
      ex_tree
        "dots"
        (pager
           ~id:"showcase-pagination-dots"
           ~variant:S.Dots
           ~total_pages:5
           () graph)
    ; (* The editable page number: type a page to go there. *)
      ex_tree
        "input"
        (pager
           ~id:"showcase-pagination-input"
           ~variant:S.Input
           ~total_pages:12
           () graph)
    ; (* A step of five: the previous and next controls move five pages at a
         time, and land on the first or the last page rather than past it. *)
      ex_tree
        "step"
        (pager
           ~id:"showcase-pagination-step"
           ~total_pages:20
           ~step:5
           () graph)
    ; (* A list whose end is not known: there is no page count, so the only
         next control is the one that matters, and the announcement is just
         the page. *)
      ex_tree
        "unknown total"
        (pager ~id:"showcase-pagination-unknown" ~has_more:true () graph)
    ]
  in
  let nodes = unwrap_all trees in
  Bonsai.map nodes ~f:(fun nodes ->
    section
      ~id:"pagination"
      ~title:"Pagination"
      ~note:
        "The controls for moving through pages of content. The page is a \
         value the caller owns: the controls report the page they want, and \
         the page numbers, the count and the announcement all follow it. \
         Click the numbers and the arrows to move."
      [ Vdom.Node.div ~attrs:[ Vdom.Attr.class_ "showcase-row" ] nodes ])
;;
