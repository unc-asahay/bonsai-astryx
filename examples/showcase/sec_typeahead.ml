(* Typeahead — a text field with a filtered list of suggestions.

   The typeahead is a combobox: the field owns the query, the menu owns the
   highlighted option, and the application owns the selection. The examples
   below show it with a static source, with grouped results, with a
   controlled selection that the application echoes back, and the states the
   field can be in — disabled, read-only, empty. *)

open! Core
open! Bonsai_web

module Typeahead = Astryx.Typeahead
module Input_types = Astryx.Input_types

open Prelude

(* The section's own helpers: [ex_tree] lifts a tree into an example, and
   [join_all] combines the example trees pairwise — this Bonsai has no list
   combinator. *)
let ex_tree label tree = Bonsai.map tree ~f:(fun node -> ex label node)

let join_all (trees : Vdom.Node.t Bonsai.t list) =
  List.fold trees ~init:(Bonsai.return []) ~f:(fun acc tree ->
    Bonsai.both acc tree |> Bonsai.map ~f:(fun (acc, tree) -> tree :: acc))
  |> Bonsai.map ~f:List.rev

(* ------------------------------------------------------------------ the data *)

type fruit = Apple | Pear | Banana | Cherry | Date | Elderberry

let fruit_item ~group fruit =
  let label =
    match fruit with
    | Apple -> "Apple"
    | Pear -> "Pear"
    | Banana -> "Banana"
    | Cherry -> "Cherry"
    | Date -> "Date"
    | Elderberry -> "Elderberry"
  in
  { Typeahead.id = label
  ; label
  ; group
  ; auxiliary_data = fruit
  ; element = None
  }

let fruits =
  [ fruit_item ~group:(Some "Pome") Apple
  ; fruit_item ~group:(Some "Pome") Pear
  ; fruit_item ~group:(Some "Berry") Cherry
  ; fruit_item ~group:(Some "Berry") Elderberry
  ; fruit_item ~group:(Some "Drupaceous") Banana
  ; fruit_item ~group:(Some "Drupaceous") Date
  ]

(* The static source matches on the label and on any extra keywords. *)
let source = Typeahead.create_static_source fruits

(* -------------------------------------------------------------- the examples *)

let demo (graph : Bonsai.graph) : Vdom.Node.t Bonsai.t =
  (* The selection is the application's own state, so the field is controlled:
     it shows what it is given, and reports what the user picked. *)
  let selected, set_selected = Bonsai.state' (None : fruit Typeahead.item option) graph in
  let selected_item =
    Bonsai.map selected ~f:(fun selected ->
        match selected with
        | None -> None
        | Some item ->
          Some
            { Typeahead.id = item.Typeahead.id
            ; label = item.Typeahead.label
            ; group = item.Typeahead.group
            ; auxiliary_data = item.Typeahead.auxiliary_data
            ; element = None
            })
  in
  let plain =
    Typeahead.view
      ~id:"showcase-typeahead-plain"
      ~label:"Search for a fruit"
      ~placeholder:"Start typing…"
      ~source
      ~value:selected_item
      ~on_change:(Bonsai.map set_selected ~f:(fun set_selected -> fun item ->
           set_selected (fun _ -> item)))
      graph
  in
  let grouped =
    Typeahead.view
      ~id:"showcase-typeahead-grouped"
      ~label:"Grouped results"
      ~placeholder:"Try 'a'…"
      ~source
      ~value:(Bonsai.return None)
      ~on_query_change:(Bonsai.return (fun _ -> Effect.Ignore))
      graph
  in
  let disabled =
    Typeahead.view
      ~id:"showcase-typeahead-disabled"
      ~label:"Disabled"
      ~placeholder:"Not available"
      ~is_disabled:true
      ~source
      ~value:(Bonsai.return None)
      graph
  in
  let empty =
    Typeahead.view
      ~id:"showcase-typeahead-empty"
      ~label:"Nothing matches"
      ~placeholder:"Search for a unicorn"
      ~empty_search_text:"No fruits found"
      ~source
      ~value:(Bonsai.return None)
      graph
  in
  let sized =
    Typeahead.view
      ~id:"showcase-typeahead-sized"
      ~label:"A large field"
      ~size:Input_types.Lg
      ~description:"The field keeps the house's input sizes."
      ~source
      ~value:(Bonsai.return None)
      graph
  in
  join_all
    [ ex_tree "the field alone" plain
    ; ex_tree "with grouped results" grouped
    ; ex_tree "disabled" disabled
    ; ex_tree "when nothing matches" empty
    ; ex_tree "the sizes" sized
    ]
  |> Bonsai.map ~f:(fun examples ->
         section
           ~id:"typeahead"
           ~title:"Typeahead"
           ~note:
             "A combobox: the field owns the query, the menu owns the highlighted option, and the application owns the selection. Type a letter to filter, arrow down to move the highlight, and Enter to pick it."
           examples)
