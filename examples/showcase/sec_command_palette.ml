(* CommandPalette — the modal command list: a search field, the commands it
   filters, and the keyboard model that walks them.

   The commands are the application's: the palette is given a source — a
   function of the query that answers with items — and renders whatever it
   gets. The palette owns the query, the highlight and the open state.

   The surface is a native popover element, so it is drawn in place rather
   than in a portal (the house has no portal): the platform promotes it to
   the top layer, dismisses it on an outside pointer press and anchors it to
   the trigger. The field keeps the DOM focus and the active row is named
   with aria-activedescendant, so the highlight is an index over the results
   rather than a moving focus.

   The examples below are controlled: the open state and the selection live
   in the example's own state, the way an application holds them. The
   trigger belongs to the application too — the palette has no button of its
   own. *)

open! Core
open! Bonsai_web
open Js_of_ocaml

module Command_palette = Astryx.Command_palette

open Prelude

(* One command, in the shape the palette reads: the id it is selected and
   navigated by, the label it shows, the section it is grouped under, the
   extra terms it is searched by, and whether it can be run. *)
let item ?(group = None) ?(keywords = []) ?(is_disabled = false) id label =
  { Command_palette.id
  ; label
  ; group
  ; keywords
  ; is_disabled
  }

(* The commands an application would register: two sections, one command that
   is searched by an extra term, and one that cannot be run. *)
let commands =
  [ item ~group:(Some "Navigation") "home" "Home"
  ; item ~group:(Some "Navigation") ~keywords:[ "start" ] "search" "Search"
  ; item ~group:(Some "Navigation") "settings" "Settings"
  ; item ~group:(Some "Account") "profile" "Profile"
  ; item ~group:(Some "Account") "sign-out" "Sign out"
  ; item ~group:(Some "Account") ~is_disabled:true "billing" "Billing (unavailable)"
  ]

(* A source over a fixed list of commands: a case-insensitive substring of the
   label, or of one of the command's keywords. *)
let source = Command_palette.create_static_source commands

(* A source with nothing in it: the palette opens on its empty state. *)
let empty_source = Command_palette.create_static_source []

(* The palette, open and closed. [is_open] and [on_open_change] come as a
   pair: the application owns the state and hears about the dismissals it did
   not perform. *)
let always_open = Bonsai.return true

let never_closes = Bonsai.return (fun (_ : bool) -> Effect.Ignore)

let demo (graph : Bonsai.graph) : Vdom.Node.t Bonsai.t =
  let ex_tree label tree = Bonsai.map tree ~f:(fun node -> ex label node) in
  let join_all (trees : Vdom.Node.t Bonsai.t list) =
    List.fold trees ~init:(Bonsai.return []) ~f:(fun acc tree ->
      Bonsai.both acc tree |> Bonsai.map ~f:(fun (acc, tree) -> tree :: acc))
    |> Bonsai.map ~f:List.rev
  in
  (* --- inline: the whole palette, drawn in the flow --- *)
  let inline_palette =
    Command_palette.view
      ~id:"showcase-command-palette-inline"
      ~is_inline:true
      ~is_open:always_open
      ~on_open_change:never_closes
      ~source
      graph
  in
  (* --- inline: the picker mode, where the application holds the selection --- *)
  let selected, set_selected = Bonsai.state "" graph in
  let inline_selected =
    Command_palette.view
      ~id:"showcase-command-palette-selected"
      ~is_inline:true
      ~is_open:always_open
      ~on_open_change:never_closes
      ~value:selected
      ~on_value_change:set_selected
      ~source
      graph
  in
  let selection_note =
    Bonsai.map selected ~f:(fun value ->
        Vdom.Node.div
          ~attrs:[ Vdom.Attr.class_ "astryx-showcase-command-palette-selection" ]
          [ Vdom.Node.text
              (if String.is_empty value then "Nothing selected yet" else "Selected: " ^ value)
          ])
  in
  let selected_example =
    Bonsai.both inline_selected selection_note
    |> Bonsai.map ~f:(fun (palette, note) ->
           Vdom.Node.div ~attrs:[] [ palette; note ])
  in
  (* --- inline: the empty state --- *)
  let inline_empty =
    Command_palette.view
      ~id:"showcase-command-palette-empty"
      ~is_inline:true
      ~is_open:always_open
      ~on_open_change:never_closes
      ~source:empty_source
      graph
  in
  (* --- the surface: a trigger the application owns, and the palette it opens --- *)
  let is_open, set_is_open = Bonsai.state false graph in
  let popover_palette =
    Command_palette.view
      ~id:"showcase-command-palette-popover"
      ~is_open
      ~on_open_change:set_is_open
      ~source
      graph
  in
  let trigger =
    Bonsai.map set_is_open ~f:(fun set_is_open ->
        Vdom.Node.button
          ~attrs:
            [ Vdom.Attr.class_ "astryx-showcase-command-palette-trigger"
            ; Vdom.Attr.on_click (fun (_ : Dom_html.mouseEvent Js.t) -> set_is_open true)
            ]
          [ Vdom.Node.text "Open command palette" ])
  in
  let popover_example =
    Bonsai.both trigger popover_palette
    |> Bonsai.map ~f:(fun (trigger, palette) -> Vdom.Node.div ~attrs:[] [ trigger; palette ])
  in
  join_all
    [ ex_tree "inline: grouped commands" inline_palette
    ; ex_tree "inline: selected command" selected_example
    ; ex_tree "inline: empty state" inline_empty
    ; ex_tree "surface: opened by a trigger" popover_example
    ]
  |> Bonsai.map ~f:(fun examples ->
         section
           ~id:"command-palette"
           ~title:"CommandPalette"
           ~note:
             "The modal command list: a search field, the commands it filters grouped by section, and the keyboard model that walks them. The focus stays in the field; the active command is named with aria-activedescendant."
           examples)