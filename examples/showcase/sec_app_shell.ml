(* AppShell — the application frame: a header, a side panel and a main
   content area, with responsive collapse and a mobile drawer.

   The shell is the frame an application draws itself inside: the top
   navigation goes in the header, the side navigation goes in the panel, and
   the page goes in the middle. Upstream threads four React contexts to
   tell the navigation how it is being rendered; this port has no context,
   so the navigation slots are functions of the mode they are drawn in, and
   the mobile state is the shell's own.

   The examples below show the shell in the shapes an application uses it:
   the plain frame, the frame with both navigations, the four background
   variants, the page that grows with its content instead of filling the
   viewport, and the mobile layout — which is what the shell falls back to
   below the breakpoint. *)

open! Core
open! Bonsai_web

module App_shell = Astryx.App_shell

open Prelude

(* The side navigation, and what it draws as in each mode. A navigation
   that does not care about the mode draws the same thing for all of them;
   the collapsed bar shows the title, the drawer shows the whole list. *)
let side_nav ~title : (App_shell.side_nav_mode -> Vdom.Node.t) =
  fun mode ->
    match mode with
    | App_shell.Default ->
        Vdom.Node.nav
          ~attrs:[ Vdom.Attr.class_ "astryx-showcase-app-shell-nav" ]
          [ Vdom.Node.ul ~attrs:[] [ Vdom.Node.li ~attrs:[] [ Vdom.Node.text "Overview" ]
                                   ; Vdom.Node.li ~attrs:[] [ Vdom.Node.text "Reports" ]
                                   ; Vdom.Node.li ~attrs:[] [ Vdom.Node.text "Settings" ]
                                   ] ]
    | App_shell.Drawer ->
        Vdom.Node.nav
          ~attrs:[ Vdom.Attr.class_ "astryx-showcase-app-shell-nav" ]
          [ Vdom.Node.ul ~attrs:[] [ Vdom.Node.li ~attrs:[] [ Vdom.Node.text "Overview" ]
                                   ; Vdom.Node.li ~attrs:[] [ Vdom.Node.text "Reports" ]
                                   ; Vdom.Node.li ~attrs:[] [ Vdom.Node.text "Settings" ]
                                   ] ]
    | App_shell.Drawer_content ->
        Vdom.Node.div
          ~attrs:[ Vdom.Attr.class_ "astryx-showcase-app-shell-drawer-content" ]
          [ Vdom.Node.text title ]
    | App_shell.Topbar -> Vdom.Node.text title
;;

(* The top navigation, and what it draws as in each mode. *)
let top_nav ~title : (App_shell.top_nav_render -> Vdom.Node.t) =
  fun { App_shell.mode; drawer_content } ->
    let heading =
      Vdom.Node.div
        ~attrs:[ Vdom.Attr.class_ "astryx-showcase-app-shell-brand" ]
        [ Vdom.Node.text title ]
    in
    match mode with
    | App_shell.Default ->
        Vdom.Node.div
          ~attrs:[ Vdom.Attr.class_ "astryx-showcase-app-shell-top" ]
          [ heading
          ; Vdom.Node.div
              ~attrs:[ Vdom.Attr.class_ "astryx-showcase-app-shell-top-end" ]
              [ Vdom.Node.text "Account" ]
          ]
    | App_shell.Mobile_bar ->
        Vdom.Node.div
          ~attrs:[ Vdom.Attr.class_ "astryx-showcase-app-shell-top" ]
          [ heading ]
    | App_shell.Drawer ->
        Vdom.Node.div
          ~attrs:[ Vdom.Attr.class_ "astryx-showcase-app-shell-top" ]
          [ heading
          ; (match drawer_content with
             | Some content -> content
             | None -> Vdom.Node.fragment [])
          ]
;;

(* The page the shell holds. *)
let page ~title =
  Vdom.Node.div
    ~attrs:[ Vdom.Attr.class_ "astryx-showcase-app-shell-page" ]
    [ Vdom.Node.h3 ~attrs:[] [ Vdom.Node.text title ]
    ; Vdom.Node.p ~attrs:[] [ Vdom.Node.text "The main content of the application." ]
    ; Vdom.Node.p ~attrs:[] [ Vdom.Node.text "The skip link at the top of the shell jumps straight here." ]
    ]
;;

let demo (graph : Bonsai.graph) : Vdom.Node.t Bonsai.t =
  let ex_tree label tree = Bonsai.map tree ~f:(fun node -> ex label node) in
  let join_all (trees : Vdom.Node.t Bonsai.t list) =
    List.fold trees ~init:(Bonsai.return []) ~f:(fun acc tree ->
      Bonsai.both acc tree |> Bonsai.map ~f:(fun (acc, tree) -> tree :: acc))
    |> Bonsai.map ~f:List.rev
  in
  (* --- the plain frame: the content alone --- *)
  let plain =
    App_shell.view ~id:"showcase-app-shell-plain" ~children:[ page ~title:"Overview" ] graph
  in
  (* --- the frame with both navigations --- *)
  let with_navigations =
    App_shell.view
      ~id:"showcase-app-shell-navs"
      ~side_nav:(side_nav ~title:"Sections")
      ~top_nav:(top_nav ~title:"Astra")
      ~children:[ page ~title:"Reports" ]
      graph
  in
  (* --- the banner: the announcement above the top navigation --- *)
  let with_banner =
    App_shell.view
      ~id:"showcase-app-shell-banner"
      ~banner:
        (Vdom.Node.div
           ~attrs:[ Vdom.Attr.class_ "astryx-showcase-app-shell-banner" ]
           [ Vdom.Node.text "Scheduled maintenance on Sunday." ])
      ~side_nav:(side_nav ~title:"Sections")
      ~top_nav:(top_nav ~title:"Astra")
      ~children:[ page ~title:"Reports" ]
      graph
  in
  (* --- the four background variants --- *)
  let variant_example variant =
    App_shell.view
      ~id:("showcase-app-shell-variant-" ^ String.lowercase (match variant with
        | App_shell.Wash -> "wash"
        | App_shell.Surface -> "surface"
        | App_shell.Section -> "section"
        | App_shell.Elevated -> "elevated"))
      ~variant
      ~side_nav:(side_nav ~title:"Sections")
      ~top_nav:(top_nav ~title:"Astra")
      ~children:[ page ~title:"Settings" ]
      graph
  in
  let variants =
    join_all
      [ ex_tree "wash" (variant_example App_shell.Wash)
      ; ex_tree "surface" (variant_example App_shell.Surface)
      ; ex_tree "section" (variant_example App_shell.Section)
      ; ex_tree "elevated" (variant_example App_shell.Elevated)
      ]
  in
  (* --- auto height: the page grows with its content instead of filling the
         viewport, so the whole page scrolls --- *)
  let auto_height =
    App_shell.view
      ~id:"showcase-app-shell-auto"
      ~height:App_shell.Auto
      ~side_nav:(side_nav ~title:"Sections")
      ~top_nav:(top_nav ~title:"Astra")
      ~children:[ page ~title:"Auto height" ]
      graph
  in
  (* --- the mobile layout: the shell falls back to it below the width
         breakpoint. The breakpoint here is the widest one, so the window
         this is shown in is below it and the collapsed bar and the drawer
         can be seen without resizing anything. --- *)
  let mobile_config =
    { App_shell.has_toggle = true
    ; is_open = None
    ; on_open_change = None
    ; content = None
    ; breakpoint = App_shell.Xxl
    ; default_is_mobile = true
    }
  in
  (* No top navigation here: with only a side navigation, the shell draws the
     collapsed mobile bar itself and puts the toggle in it. With a top
     navigation, the shell renders that navigation in its mobile form
     instead, and the toggle goes in the header. *)
  let mobile =
    App_shell.view
      ~id:"showcase-app-shell-mobile"
      ~mobile_nav:(App_shell.Config mobile_config)
      ~side_nav:(side_nav ~title:"Sections")
      ~children:[ page ~title:"Mobile" ]
      graph
  in
  join_all
    [ ex_tree "the frame alone" plain
    ; ex_tree "with a top navigation and a side navigation" with_navigations
    ; ex_tree "with a banner above the navigation" with_banner
    ; ex_tree "the background variants" (Bonsai.map variants ~f:(fun nodes -> Vdom.Node.fragment nodes))
    ; ex_tree "auto height: the page scrolls as a whole" auto_height
    ; ex_tree "the mobile layout" mobile
    ]
  |> Bonsai.map ~f:(fun examples ->
         section
           ~id:"app-shell"
           ~title:"AppShell"
           ~note:
             "The application frame: a header, a side panel and a main content area, with responsive collapse and a mobile drawer. The navigation slots are functions of the mode they are drawn in, and the skip link at the top of the shell jumps straight to the content."
           examples)
