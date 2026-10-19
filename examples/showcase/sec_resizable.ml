(* The Resizable showcase section: the region and the separator, in the variants
   upstream ships.

   Upstream's own stories (apps/storybook/stories/Resizable.stories.tsx) are
   the guide: a horizontal split, a vertical split, a collapsible sidebar, snap
   points, a pill that only shows on hover, a disabled handle, and a reversed
   handle. The composable API (a region plus a handle the application places)
   is used for the collapsible example, because that one needs the region's
   own collapse and expand - upstream's story shows the same Expand button
   there.

   Every example carries a distinct DOM id, so the browser gate can address
   it: "showcase-resizable-<variant>" on the layout, and the separator
   itself is "<that id>-handle". *)

open! Core
open! Bonsai_web
open Prelude

module R = Astryx.Resizable

let demo (graph : Bonsai.graph) : Vdom.Node.t Bonsai.t =
  let join_all (trees : Vdom.Node.t Bonsai.t list) =
    List.fold trees ~init:(Bonsai.return []) ~f:(fun acc tree ->
      Bonsai.map2 acc tree ~f:(fun acc node -> acc @ [ node ]))
  in
  let ex_tree label tree = Bonsai.map tree ~f:(fun node -> ex label node) in
  (* The frame each example lives in. The showcase owns the frame; the
     component's own styles are in assets/parts/resizable.css. The frame is a
     flex box so the layout inside it has a height of its own: a separator
     that spans the panel needs one. *)
  let shell ?(width = "520px") ?(height = "200px") node =
    Vdom.Node.div
      ~attrs:
        [ Vdom.Attr.create
            "style"
            (Printf.sprintf
               "width: %s; height: %s; display: flex; border: 1px solid var(--color-border); \
                border-radius: var(--radius-container); overflow: hidden; \
                background: var(--color-background-surface);"
               width
               height)
        ]
      [ node ]
  in
  (* The resizable side, showing the size it currently holds. *)
  let panel label size =
    Vdom.Node.div
      ~attrs:
        [ Vdom.Attr.create
            "style"
            "padding: var(--spacing-3); font-size: var(--text-supporting-size); \
             color: var(--text-secondary); white-space: nowrap; overflow: hidden;"
        ]
      [ Vdom.Node.text (Printf.sprintf "%s — %dpx" label (int_of_float (Float.round size))) ]
  in
  let content label =
    Vdom.Node.div
      ~attrs:
        [ Vdom.Attr.create
            "style"
            "padding: var(--spacing-3); font-size: var(--text-supporting-size); \
             color: var(--text-secondary);"
        ]
      [ Vdom.Node.text label ]
  in
  let horizontal =
    R.view
      ~id:"showcase-resizable-horizontal"
      ~default_size:(R.Px 220.)
      ~min_size:(R.Px 120.)
      ~max_size:(R.Px 400.)
      ~label:"Resize sidebar"
      ~panel:(fun size -> [ panel "Sidebar" size ])
      ~content:[ content "Content" ]
      graph
  in
  let vertical =
    R.view
      ~id:"showcase-resizable-vertical"
      ~direction:R.Vertical
      ~default_size:(R.Px 130.)
      ~min_size:(R.Px 80.)
      ~max_size:(R.Px 260.)
      ~label:"Resize editor"
      ~panel:(fun size -> [ panel "Editor" size ])
      ~content:[ content "Terminal" ]
      graph
  in
  (* The composable API: the application owns the region, the panel and the
     separator, and can collapse and expand the region itself. *)
  let collapsible_region =
    R.create
      ~default_size:(R.Px 220.)
      ~min_size:(R.Px 120.)
      ~collapsible:true
      ~collapsed_size:60.
      graph
  in
  let collapsible_handle =
    R.handle_view
      ~id:"showcase-resizable-collapsible-handle"
      ~has_divider:true
      ~label:"Resize sidebar"
      ~resizable:collapsible_region
      graph
  in
  let collapsible_panel =
    Bonsai.map collapsible_region ~f:(fun region ->
      Vdom.Node.div
        ~attrs:
          [ Vdom.Attr.class_ "astryx-resizable__panel"
          ; Vdom.Attr.create
              "style"
              (Printf.sprintf "width: %dpx;" (int_of_float (Float.round region.size)))
          ]
        [ panel "Sidebar" region.size ])
  in
  let collapsible_state =
    Bonsai.map collapsible_region ~f:(fun region ->
      if region.is_collapsed
      then
        Vdom.Node.button
          ~attrs:
            [ Vdom.Attr.create "id" "showcase-resizable-expand"
            ; Vdom.Attr.on_click (fun _ -> region.expand)
            ]
          [ Vdom.Node.text "Expand" ]
      else Vdom.Node.text "Expanded")
  in
  let collapsible_content =
    Bonsai.map collapsible_state ~f:(fun state ->
      Vdom.Node.div
        ~attrs:
          [ Vdom.Attr.class_ "astryx-resizable__content"
          ; Vdom.Attr.create
              "style"
              "padding: var(--spacing-3); font-size: var(--text-supporting-size); \
               color: var(--text-secondary);"
          ]
        [ state ])
  in
  let collapsible =
    Bonsai.map3 collapsible_panel collapsible_handle collapsible_content
      ~f:(fun panel handle content ->
        Vdom.Node.div
          ~attrs:
            [ Vdom.Attr.class_ "astryx-resizable astryx-resizable--horizontal"
            ; Vdom.Attr.id "showcase-resizable-collapsible"
            ]
          [ panel; handle; content ])
  in
  let snaps =
    R.view
      ~id:"showcase-resizable-snaps"
      ~default_size:(R.Px 200.)
      ~min_size:(R.Px 120.)
      ~max_size:(R.Px 400.)
      ~snaps:[ 120.; 200.; 300. ]
      ~label:"Resize sidebar"
      ~panel:(fun size -> [ panel "Snaps 120 · 200 · 300" size ])
      ~content:[ content "Content" ]
      graph
  in
  let hidden_pill =
    R.view
      ~id:"showcase-resizable-hidden-pill"
      ~default_size:(R.Px 220.)
      ~min_size:(R.Px 120.)
      ~max_size:(R.Px 400.)
      ~is_always_visible:false
      ~label:"Resize sidebar"
      ~panel:(fun size -> [ panel "Sidebar" size ])
      ~content:[ content "Content" ]
      graph
  in
  let disabled =
    R.view
      ~id:"showcase-resizable-disabled"
      ~default_size:(R.Px 220.)
      ~min_size:(R.Px 120.)
      ~max_size:(R.Px 400.)
      ~is_disabled:true
      ~label:"Locked"
      ~panel:(fun size -> [ panel "Sidebar (locked)" size ])
      ~content:[ content "Content" ]
      graph
  in
  let reversed =
    R.view
      ~id:"showcase-resizable-reversed"
      ~default_size:(R.Px 220.)
      ~min_size:(R.Px 120.)
      ~max_size:(R.Px 400.)
      ~is_reversed:true
      ~label:"Resize content"
      ~panel:(fun size -> [ panel "Content" size ])
      ~content:[ content "Sidebar" ]
      graph
  in
  let examples =
    [ ex_tree "Horizontal split" (Bonsai.map horizontal ~f:(fun node -> shell node))
    ; ex_tree "Vertical split"
        (Bonsai.map vertical ~f:(fun node -> shell ~height:"260px" node))
    ; ex_tree "Collapsible (double-click, or Enter)" (Bonsai.map collapsible ~f:(fun node -> shell node))
    ; ex_tree "Snap points" (Bonsai.map snaps ~f:(fun node -> shell node))
    ; ex_tree "Pill hidden until hover" (Bonsai.map hidden_pill ~f:(fun node -> shell node))
    ; ex_tree "Disabled" (Bonsai.map disabled ~f:(fun node -> shell node))
    ; ex_tree "Reversed (the panel is on the end side)" (Bonsai.map reversed ~f:(fun node -> shell node))
    ]
  in
  let nodes = join_all examples in
  Bonsai.map nodes ~f:(fun nodes ->
    section
      ~id:"resizable"
      ~title:"Resizable"
      ~note:
        "A resizable panel and the separator that resizes it: drag the handle, or focus it \
         and use the arrow keys, Home and End. The separator is a WAI-ARIA separator that \
         announces the panel's size."
      [ Vdom.Node.div ~attrs:[ Vdom.Attr.class_ "showcase-row" ] nodes ])
;;
