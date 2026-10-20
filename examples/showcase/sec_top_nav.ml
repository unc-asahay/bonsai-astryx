(* The TopNav showcase section: the bar, its items and its heading.

   The bar and its items are pure nodes. The heading's menu needs an open flag
   the caller owns, so that example carries a state of its own.

   Every example carries a distinct DOM id, so the browser gate can address it:
   "showcase-top-nav-<variant>". *)

open! Core
open! Bonsai_web
open Prelude

module Top_nav = Astryx.Top_nav

let logo_mark () =
  Vdom.Node.span ~attrs:[ Vdom.Attr.class_ "astryx-top-nav-heading__logo-mark" ] [ Vdom.Node.text "A" ]

let menu_item text =
  Vdom.Node.a
    ~attrs:[ Vdom.Attr.create "role" "menuitem"; Vdom.Attr.create "href" "#" ]
    [ Vdom.Node.text text ]

let demo (graph : Bonsai.graph) : Vdom.Node.t Bonsai.t =
  let open Astryx in
  let items =
    [ Top_nav.Item.view ~label:"Home" ~href:"#" []
    ; Top_nav.Item.view ~label:"Products" ~href:"#" []
    ; Top_nav.Item.view ~label:"Pricing" ~href:"#" []
    ; Top_nav.Item.view ~label:"Docs" ~href:"#" []
    ]
  in
  let heading = Top_nav.Heading.view ~logo:(logo_mark ()) ~heading:"Astra" ~heading_href:"#" () in
  (* The heading's menu follows the caller's flag, the way a popover does. *)
  let menu_open, set_menu_open = Bonsai.state false graph in
  let heading_with_menu =
    Bonsai.map2 menu_open set_menu_open ~f:(fun is_open set_open -> is_open, set_open)
    |> Bonsai.map ~f:(fun (is_open, set_open) ->
           Top_nav.Heading.view
             ~logo:(logo_mark ())
             ~heading:"Astra Suite"
             ~heading_href:"#"
             ~menu:[ menu_item "Profile"; menu_item "Preferences"; menu_item "Sign out" ]
             ~is_menu_open:is_open
             ~on_menu_open_change:(fun is_open -> set_open is_open)
             ())
  in
  Bonsai.map heading_with_menu ~f:(fun heading_with_menu ->
           section
             ~id:"top-nav"
             ~title:"TopNav"
             ~note:
               "A navigation bar with a heading, start, center and end slots; the items it carries; and the heading that names the product. The last example opens the heading's menu from its chevron."
             [ ex
                 "showcase-top-nav-default"
                 (Top_nav.view
                    ~id:"showcase-top-nav-default"
                    ~heading:heading
                    ~start_content:items
                    ~end_content:[ chip "Sign in" ]
                    [])
             ; ex
                 "showcase-top-nav-center"
                 (Top_nav.view
                    ~id:"showcase-top-nav-center"
                    ~heading:heading
                    ~start_content:items
                    ~center_content:[ chip "Search" ]
                    ~end_content:[ chip "Sign in" ]
                    [])
             ; ex
                 "showcase-top-nav-items"
                 (Vdom.Node.div
                    ~attrs:[ Vdom.Attr.id "showcase-top-nav-items" ]
                    [ Top_nav.Item.view ~label:"Home" ~href:"#" ~is_selected:true []
                    ; Top_nav.Item.view ~label:"Products" ~href:"#" []
                    ; Top_nav.Item.view ~label:"Archive" ~href:"#" ~is_disabled:true []
                    ; Top_nav.Item.view
                        ~label:"Settings"
                        ~href:"#"
                        ~icon:(Vdom.Node.text "*")
                        ~is_icon_only:true
                        []
                    ])
             ; ex
                 "showcase-top-nav-heading"
                 (Top_nav.Heading.view
                    ~id:"showcase-top-nav-heading"
                    ~logo:(logo_mark ())
                    ~superheading:"Astra Suite"
                    ~superheading_href:"#"
                    ~heading:"Workspace"
                    ~heading_href:"#"
                    ~subheading:"Production"
                    ~subheading_href:"#"
                    ())
             ; ex
                 "showcase-top-nav-menu"
                 (Top_nav.view ~id:"showcase-top-nav-menu" ~heading:heading_with_menu ~start_content:items [])
             ])
;;
