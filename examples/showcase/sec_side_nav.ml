(* SideNav — the side navigation column.

   The column has a heading at the top, a pinned area under it, the
   scrollable body, the footer and the icon bar at the bottom. It can
   collapse to an icon rail, and it can be resized with a separator that
   carries the value.

   The examples below show the column with its parts, a group of items, the
   collapsed rail, and the resizable column. *)

open! Core
open! Bonsai_web

module Side_nav = Astryx.Side_nav

open Prelude

let ex_tree label tree = Bonsai.map tree ~f:(fun node -> ex label node)

let demo (graph : Bonsai.graph) : Vdom.Node.t Bonsai.t =
  (* The items are graphs, so they are built once and shared. *)
  let items =
    [ Side_nav.item ~id:"showcase-side-nav-item-home" ~label:"Home" ~icon:"menu" graph
    ; Side_nav.item
        ~id:"showcase-side-nav-item-search"
        ~label:"Search"
        ~icon:"search"
        ~selected_icon:"funnel"
        ~is_selected:true
        graph
    ; Side_nav.item ~id:"showcase-side-nav-item-calendar" ~label:"Calendar" ~icon:"calendar" graph
    ; Side_nav.item
        ~id:"showcase-side-nav-item-disabled"
        ~label:"Reports"
        ~icon:"copy"
        ~is_disabled:true
        graph
    ]
  in
  let group =
    Side_nav.section
      ~id:"showcase-side-nav-section"
      ~title:"Workspace"
      ~subtitle:"Four places"
      ~children:items
      graph
  in
  let plain_body =
    Side_nav.view
      ~id:"showcase-side-nav-plain"
      ~header:
        [ Side_nav.heading
            ~id:"showcase-side-nav-heading"
            ~heading:"A product"
            ~superheading:"Acme"
            ~subheading:"The workspace"
            graph ]
      ~top_content:[ Side_nav.item ~id:"showcase-side-nav-item-pinned" ~label:"Pinned" ~icon:"check" graph ]
      ~children:items
      ~footer:[ Vdom.Node.text "A footer" ]
      ~footer_icons:[ Vdom.Node.text "···" ]
      graph
  in
  let collapsed =
    Side_nav.view
      ~id:"showcase-side-nav-collapsed"
      ~is_collapsible:true
      ~default_is_collapsed:true
      ~header:[ Side_nav.heading ~id:"showcase-side-nav-heading-collapsed" ~heading:"Acme" graph ]
      ~children:items
      graph
  in
  let resizable =
    Side_nav.view
      ~id:"showcase-side-nav-resizable"
      ~is_collapsible:true
      ~is_resizable:true
      ~default_width:240.
      ~min_width:180.
      ~max_width:400.
      ~children:items
      graph
  in
  let examples =
    [ ex_tree "the column" plain_body
    ; ex_tree "a group of items" group
    ; ex_tree "collapsed to an icon rail" collapsed
    ; ex_tree "resizable" resizable
    ]
  in
  let examples =
    List.fold examples ~init:(Bonsai.return []) ~f:(fun acc example ->
      Bonsai.both acc example |> Bonsai.map ~f:(fun (acc, example) -> example :: acc))
    |> Bonsai.map ~f:List.rev
  in
  Bonsai.map examples ~f:(fun examples ->
         section
           ~id:"side-nav"
           ~title:"SideNav"
           ~note:
             "A column of navigation items, with a heading at the top, a pinned area under it, the scrollable body, the footer and the icon bar. The column can collapse to an icon rail, and it can be resized with a separator that carries the value."
           examples)
;;

let _ = demo
