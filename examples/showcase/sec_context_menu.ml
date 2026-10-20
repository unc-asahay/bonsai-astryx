(* ContextMenu — the right-click menu.

   A context menu is opened by right-clicking, so the examples here cannot
   show the menu as open: they show the trigger, and the menu appears where
   the pointer is when the reader right-clicks it. The keyboard path (Shift+F10
   on the focused trigger) opens the same surface on the trigger's bottom
   edge.

   Upstream renders the pointer surface through a portal and the touch
   presentation through a BottomSheet; neither is ported, so the surface
   renders next to the trigger and the touch presentation is a plain
   bottom-anchored panel. *)

open! Core
open! Bonsai_web

module Context_menu = Astryx.Context_menu

open Prelude

let demo (graph : Bonsai.graph) : Vdom.Node.t Bonsai.t =
  let ex_tree label tree = Bonsai.map tree ~f:(fun node -> ex label node) in
  (* The row that was chosen, so the example shows what a selection reports. *)
  let chosen, set_chosen = Bonsai.state "none" graph in
  let on_select =
    Bonsai.map set_chosen ~f:(fun set_chosen -> fun (item : Context_menu.item) -> set_chosen item.label)
  in
  let readout =
    Bonsai.map chosen ~f:(fun chosen ->
      Vdom.Node.div ~attrs:[ Vdom.Attr.create "id" "showcase-context-menu-chosen" ]
        [ Vdom.Node.text ("chosen: " ^ chosen) ])
  in
  let item
      ?id
      ?description
      ?icon
      ?variant
      ?(is_disabled = false)
      ?href
      ?(has_close_on_select = true)
      ?children
      label
    : Context_menu.item
    =
    { id
    ; label
    ; description
    ; icon
    ; end_content = None
    ; variant = (match variant with Some variant -> variant | None -> Context_menu.Default)
    ; is_disabled
    ; href
    ; has_close_on_select
    ; children
    }
  in
  let entries =
    [ Context_menu.Item (item ~id:"open" ~icon:"copy" "Open")
    ; Context_menu.Item (item ~id:"open-recent" ~description:"The last file you had open" "Open recent")
    ; Context_menu.Divider
    ; Context_menu.Item
        (item ~id:"share" ~children:[ Context_menu.Item (item ~id:"share-copy" "Copy link") ] "Share")
    ; Context_menu.Section
        { id = Some "edit"
        ; title = Some "Edit"
        ; items =
            [ item ~id:"cut" "Cut"
            ; item ~id:"paste" ~is_disabled:true "Paste"
            ; item ~id:"delete" ~variant:Context_menu.Destructive "Delete"
            ]
        }
    ]
  in
  let trigger label =
    Vdom.Node.span
      ~attrs:[ Vdom.Attr.create "class" "chip" ]
      [ Vdom.Node.text label ]
  in
  let menu ~id ~label ?presentation () =
    Context_menu.view
      ~id
      ~label
      ?presentation
      ~trigger:(trigger label)
      ~entries
      ~on_select
      graph
  in
  let basic = menu ~id:"showcase-context-menu-basic" ~label:"File" () in
  let sheet = menu ~id:"showcase-context-menu-sheet" ~label:"Actions" ~presentation:Context_menu.Bottom_sheet () in
  let chosen_example =
    Bonsai.map2 readout basic ~f:(fun readout basic ->
      Vdom.Node.div ~attrs:[ Vdom.Attr.create "id" "showcase-context-menu-example" ] [ readout; basic ])
  in
  let examples =
    [ ex_tree "right-click the trigger: the menu opens at the pointer" basic
    ; ex_tree "the chosen row is reported" chosen_example
    ; ex_tree "the touch presentation is a bottom sheet" sheet
    ]
  in
  Bonsai.map (unwrap_all examples) ~f:(fun examples ->
    section
      ~id:"context-menu"
      ~title:"ContextMenu"
      ~note:
        "A right-click menu. Right-clicking the trigger opens the menu surface at the pointer, and \
         Shift+F10 on the focused trigger opens the same surface on the trigger's bottom edge. A \
         row that carries children drills into them — the sub-menu replaces the surface's rows, \
         the Back row and Escape step back out — and the keyboard model is the menu's own: arrows \
         wrap at both ends, Home and End jump, typeahead matches a row's label, and Enter opens one \
         level. Upstream renders the surface through a portal and the touch presentation through a \
         BottomSheet; neither is ported, so the surface renders next to the trigger and the touch \
         presentation is a plain bottom-anchored panel."
      examples)
;;
