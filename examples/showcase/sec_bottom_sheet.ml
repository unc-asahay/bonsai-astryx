open! Core
open! Bonsai_web

module Bottom_sheet = Astryx.Bottom_sheet

open Prelude

(* ------------------------------------------------------------------ helpers *)

(* The section draws its own buttons rather than a house button: the point of
   the section is the sheet, and a trigger only has to open and close it. *)
let button ~label ~on_click : Vdom.Node.t =
  Vdom.Node.button
    ~attrs:
      [ Vdom.Attr.create "type" "button"
      ; Vdom.Attr.on_click (fun _ -> on_click)
      ]
    [ Vdom.Node.text label ]
;;

let note (text : string) : Vdom.Node.t = Vdom.Node.p ~attrs:[] [ Vdom.Node.text text ]
;;

let heading (text : string) : Vdom.Node.t = Vdom.Node.h3 ~attrs:[] [ Vdom.Node.text text ]
;;

(* The setter a sheet reports its dismissals through: the sheet never opens or
   closes itself, so the section owns the value it follows. *)
let open_change_of (set_open : (bool -> bool) -> unit Effect.t) : (bool -> unit Effect.t) Bonsai.t =
  Bonsai.return (fun value -> set_open (fun _ -> value))
;;

(* --------------------------------------------------------------------- demo *)

let demo (graph : Bonsai.graph) : Vdom.Node.t Bonsai.t =
  (* 1. The default sheet: a native modal dialog with a scrim. *)
  let info_open, set_info_open = Bonsai.state' false graph in
  let info =
    Bottom_sheet.view
      ~id:"showcase-bottom-sheet-info"
      ~label:"Account details"
      ~is_open:info_open
      ~on_open_change:(open_change_of set_info_open)
      ~children:
        (Bonsai.return
           [ heading "Account details"
           ; note
               "The sheet is a native dialog, so the page behind it is inert while it is open, Escape closes it, and a click on the scrim closes it too."
           ; button ~label:"Close" ~on_click:(set_info_open false)
           ])
      graph
  in
  (* 2. A sheet that protects what was typed into it: the scrim and a swipe
     no longer dismiss it, and only Escape still does. *)
  let form_open, set_form_open = Bonsai.state' false graph in
  let form =
    Bottom_sheet.view
      ~id:"showcase-bottom-sheet-form"
      ~label:"Rename project"
      ~purpose:Bottom_sheet.Form
      ~height:Bottom_sheet.Tall
      ~is_open:form_open
      ~on_open_change:(open_change_of set_form_open)
      ~children:
        (Bonsai.return
           [ heading "Rename project"
           ; note "A form sheet keeps what was typed: the scrim and a swipe do not dismiss it, and Escape still does."
           ; button ~label:"Save" ~on_click:(set_form_open false)
           ])
      graph
  in
  (* 3. A sheet that refuses every implicit dismissal and has to be answered,
     which is why it is an alertdialog. *)
  let required_open, set_required_open = Bonsai.state' false graph in
  let required =
    Bottom_sheet.view
      ~id:"showcase-bottom-sheet-required"
      ~label:"Delete this project"
      ~purpose:Bottom_sheet.Required
      ~is_open:required_open
      ~on_open_change:(open_change_of set_required_open)
      ~children:
        (Bonsai.return
           [ heading "Delete this project"
           ; note "A required sheet blocks every implicit dismissal — Escape, the scrim and a swipe all do nothing — so it can only be answered from inside."
           ; button ~label:"Keep it" ~on_click:(set_required_open false)
           ])
      graph
  in
  (* 4. A sheet with stops: dragging the handle settles it at one of them. *)
  let snaps_open, set_snaps_open = Bonsai.state' false graph in
  let snaps =
    Bottom_sheet.view
      ~id:"showcase-bottom-sheet-snaps"
      ~label:"A sheet with stops"
      ~snap_points:[ Bottom_sheet.Fraction 0.5; Bottom_sheet.Px 240 ]
      ~is_open:snaps_open
      ~on_open_change:(open_change_of set_snaps_open)
      ~children:
        (Bonsai.return
           [ heading "A sheet with stops"
           ; note "Drag the handle: the sheet settles at half the screen, at 240px, or back at the top."
           ; button ~label:"Close" ~on_click:(set_snaps_open false)
           ])
      graph
  in
  (* 5. The showcase path: ordinary markup written into the page, with no top
     layer and no scrim, so a page can show several sheets at once. *)
  let inline =
    Bottom_sheet.view
      ~id:"showcase-bottom-sheet-inline"
      ~label:"A sheet written into the page"
      ~height:Bottom_sheet.Hug
      ~is_inline:true
      ~is_open:(Bonsai.return true)
      ~on_open_change:(Bonsai.return (fun _ -> Effect.Ignore))
      ~children:
        (Bonsai.return
           [ heading "A sheet written into the page"
           ; note "An inline sheet is ordinary markup: it has no top layer and no scrim, and it fits its content."
           ])
      graph
  in
  let with_trigger set_open node =
    Bonsai.map node ~f:(fun node ->
        Vdom.Node.div ~attrs:[] [ node; button ~label:"Open the sheet" ~on_click:(set_open true) ])
  in
  let examples =
    [ ex "a modal sheet" (with_trigger set_info_open info)
    ; ex "a sheet that protects its content" (with_trigger set_form_open form)
    ; ex "a sheet that has to be answered" (with_trigger set_required_open required)
    ; ex "a sheet with stops" (with_trigger set_snaps_open snaps)
    ; ex "a sheet written into the page" inline
    ]
  in
  Bonsai.map (unwrap_all examples) ~f:(fun examples ->
      section
        ~id:"bottom-sheet"
        ~title:"BottomSheet"
        ~note:
          "The sheet that comes up from the bottom: the modal one with its scrim, the one that protects what was typed into it, the one that has to be answered, the one with stops to settle at, and the inline one that is ordinary markup."
        examples)
;;
