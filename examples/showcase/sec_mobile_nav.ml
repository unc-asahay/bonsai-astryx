(* The MobileNav showcase section: the drawer, in the variants upstream ships.

   Upstream's own stories (apps/storybook/stories/MobileNav.stories.tsx) are
   the guide: a drawer with a title header, a drawer with a header of the
   caller's own, a drawer with no header at all, a drawer from the end edge,
   a narrow drawer, and the drawer that is really open - a modal, dismissed
   by its close button, by the backdrop and by Escape.

   The drawer is a viewport-wide overlay, so the examples that are *about* its
   anatomy are rendered inline (the showcase path: the same markup, with no
   top layer), each in a frame of its own. The last example is the real
   thing: a modal drawer, opened by a trigger, closed by the three ways a
   modal can be closed.

   Every example carries a distinct DOM id, so the browser gate can address
   it: "showcase-mobile-nav-<variant>" on the drawer, and the trigger of the
   live one is "showcase-mobile-nav-open". *)

open! Core
open! Bonsai_web
open Prelude

module Mobile_nav = Astryx.Mobile_nav

let demo (graph : Bonsai.graph) : Vdom.Node.t Bonsai.t =
  let ex_tree label tree = Bonsai.map tree ~f:(fun node -> ex label node) in
  (* The frame an inline drawer is shown in. The drawer is a viewport-wide
     overlay, so the showcase gives it a box of its own to be measured
     against. The showcase owns the frame; the drawer's own styles are in
     assets/parts/mobile_nav.css. *)
  let frame ?(width = "360px") ?(height = "420px") node =
    Vdom.Node.div
      ~attrs:
        [ Vdom.Attr.create
            "style"
            (Printf.sprintf
               "width: %s; height: %s; position: relative; overflow: hidden; \
                border: 1px solid var(--color-border); \
                border-radius: var(--radius-container); \
                background: var(--color-background-body);"
               width
               height)
        ]
      [ node ]
  in
  (* The drawer's content: the kind of list a mobile drawer holds. Upstream
     fills it with SideNavSection and SideNavItem; those are not ported yet,
     so the links stand in for them. *)
  let nav_item text =
    Astryx.Link.view
      ~href:"#"
      ~attrs:[ Vdom.Attr.create "style" "padding-block: var(--spacing-2);" ]
      [ Vdom.Node.text text ]
  in
  let nav_content = [ nav_item "Home"; nav_item "Inbox"; nav_item "Settings" ] in
  (* An inline drawer: the real component, without the top layer. *)
  let inline ?id ?header ?width ?side ?label children =
    Mobile_nav.view
      ?id
      ?header
      ?width
      ?side
      ?label
      ~is_inline:true
      ~is_open:(Bonsai.return true)
      ~on_open_change:(Bonsai.return (fun _ -> Effect.Many []))
      ~children:(Bonsai.return children)
      ()
  in
  let title_header = inline ~id:"showcase-mobile-nav-title" ~header:(Mobile_nav.Title "Navigation") nav_content in
  let custom_header =
    inline
      ~id:"showcase-mobile-nav-custom-header"
      ~header:
        (Mobile_nav.Content
           (Vdom.Node.div
              ~attrs:[ Vdom.Attr.create "style" "display: flex; align-items: center; gap: var(--spacing-2);" ]
              [ Astryx.Text.view ~type_:Astryx.Text.Label [ Vdom.Node.text "Workspace" ]
              ; Astryx.Text.view ~type_:Astryx.Text.Supporting [ Vdom.Node.text "Astrograph" ]
              ]))
      nav_content
  in
  let no_header = inline ~id:"showcase-mobile-nav-no-header" nav_content in
  let side_end = inline ~id:"showcase-mobile-nav-side-end" ~side:Mobile_nav.End nav_content in
  let narrow = inline ~id:"showcase-mobile-nav-narrow" ~width:240 nav_content in
  (* The live one: a modal drawer, with the application owning its state. *)
  let live =
    let is_open, set_is_open = Bonsai.state false graph in
    let trigger =
      Bonsai.map set_is_open ~f:(fun set_is_open ->
        Astryx.Button.view
          ~variant:Astryx.Button.Secondary
          ~label:"Open navigation"
          ~attrs:[ Vdom.Attr.create "id" "showcase-mobile-nav-open" ]
          ~on_click:(fun _ -> set_is_open true)
          [])
    in
    let readout =
      Bonsai.map is_open ~f:(fun is_open ->
        Vdom.Node.div
          ~attrs:
            [ Vdom.Attr.create "id" "showcase-mobile-nav-state"
            ; Vdom.Attr.create
                "style"
                "font-size: var(--text-supporting-size); color: var(--text-secondary);"
            ]
          [ Vdom.Node.text
              (if is_open
               then "the application says: open"
               else "the application says: closed")
          ])
    in
    let drawer =
      Mobile_nav.view
        ~id:"showcase-mobile-nav-live"
        ~header:(Mobile_nav.Title "Navigation")
        ~side:Mobile_nav.Start
        ~is_open
        ~on_open_change:(Bonsai.map set_is_open ~f:(fun set_is_open value -> set_is_open value))
        ~children:(Bonsai.return nav_content)
        ()
    in
    Bonsai.map2 trigger readout ~f:(fun trigger readout ->
      Vdom.Node.div [ trigger; readout; drawer ])
  in
  let examples =
    [ ex_tree "Title header" (Bonsai.map title_header ~f:(fun node -> frame node))
    ; ex_tree "Header of the caller's own" (Bonsai.map custom_header ~f:(fun node -> frame node))
    ; ex_tree "No header: the close button alone" (Bonsai.map no_header ~f:(fun node -> frame node))
    ; ex_tree "From the end edge" (Bonsai.map side_end ~f:(fun node -> frame node))
    ; ex_tree "Narrow (240px)" (Bonsai.map narrow ~f:(fun node -> frame node))
    ; ex_tree "Live: open it, then dismiss it" live
    ]
  in
  let nodes = unwrap_all examples in
  Bonsai.map nodes ~f:(fun nodes ->
    section
      ~id:"mobile-nav"
      ~title:"MobileNav"
      ~note:
        "The mobile navigation drawer: a header, a list, a close button, and a \
         scrim. The last example is a real modal - dismiss it with the close \
         button, with a click on the scrim, or with Escape."
      [ Vdom.Node.div ~attrs:[ Vdom.Attr.class_ "showcase-row" ] nodes ])
;;
