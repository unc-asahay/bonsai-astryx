(* SideNav — the side navigation column.

   The column has a heading at the top, a pinned area under it, the
   scrollable body, the footer and the icon bar at the bottom. It can
   collapse to an icon rail, and it can be resized with a separator that
   carries the value.

   The examples below show the column with its parts, a heading, a group of
   items, a selected item, the collapsed rail, and the resizable column. *)

open! Core
open! Bonsai_web

module Side_nav = Astryx.Side_nav

open Prelude

let demo (graph : Bonsai.graph) : Vdom.Node.t Bonsai.t =
  (* A group of items, unwrapped into nodes so they can be the section's
     children. *)
  let items =
    unwrap_all
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
    Bonsai.map items ~f:(fun items ->
        Side_nav.section
          ~id:"showcase-side-nav-section"
          ~title:"Workspace"
          ~subtitle:"Four places"
          ~children:items
          graph)
  in
  let plain_body =
    Bonsai.map items ~f:(fun items ->
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
          graph)
  in
  let collapsed =
    Bonsai.map items ~f:(fun items ->
        Side_nav.view
          ~id:"showcase-side-nav-collapsed"
          ~is_collapsible:true
          ~default_is_collapsed:true
          ~header:[ Side_nav.heading ~id:"showcase-side-nav-heading-collapsed" ~heading:"Acme" graph ]
          ~children:items
          graph)
  in
  let resizable =
    Bonsai.map items ~f:(fun items ->
        Side_nav.view
          ~id:"showcase-side-nav-resizable"
          ~is_collapsible:true
          ~is_resizable:true
          ~default_width:240.
          ~min_width:180.
          ~max_width:400.
          ~children:items
          graph)
  in
  Bonsai.map2 plain_body group ~f:(fun column group ->
      Vdom.Node.div
        ~attrs:[ Vdom.Attr.class_ "showcase-col" ]
        [ column; Vdom.Node.div ~attrs:[ Vdom.Attr.class_ "showcase-col" ] [ group ] ])
  |> Bonsai.map ~f:(fun row ->
         [ row
         ; Vdom.Node.div
             ~attrs:[ Vdom.Attr.class_ "showcase-col" ]
             [ collapsed ]
         ; Vdom.Node.div
             ~attrs:[ Vdom.Attr.class_ "showcase-col" ]
             [ resizable ] ])
  |> Bonsai.map ~f:(fun columns ->
         section
           ~id:"side-nav"
           ~title:"SideNav"
           ~note:
             "A column of navigation items, with a heading at the top, a pinned area under it, the scrollable body, the footer and the icon bar. The column can collapse to an icon rail, and it can be resized with a separator that carries the value."
           (List.map ~f:(fun column -> ex "the column" column) columns))
;;

let _ = demo
