(* Selector — the showcase section: the option list in the shapes it takes.

   Every example drives the component through its public API only, so the
   section is also the proof that the API is usable from outside the
   library. The chosen value is held here, not inside the component, so
   the readout shows what the component reported. *)

open! Core
open! Bonsai_web

module Selector = Astryx.Selector

open Prelude

let demo (graph : Bonsai.graph) : Vdom.Node.t Bonsai.t =
  let ex_model label tree = Bonsai.map tree ~f:(fun node -> ex label node) in
  (* The value is the caller's, and so is the callback that reports a pick. *)
  let chosen, set_chosen = Bonsai.state' (None : string option) graph in
  let value = Bonsai.map chosen ~f:(fun value -> value) in
  let on_change =
    Bonsai.map set_chosen ~f:(fun set -> fun (next : string option) -> set (fun _ -> next))
  in
  let readout =
    Bonsai.map chosen ~f:(fun value ->
        Vdom.Node.div
          ~attrs:[ Vdom.Attr.create "id" "showcase-selector-readout" ]
          [ Vdom.Node.text
              (match value with
               | Some v -> "picked " ^ v
               | None -> "nothing picked yet")
          ])
  in
  (* The option list is a union: a row, a divider, or a group. *)
  let opt ?label ?description ?icon ?is_disabled value =
    Selector.Row (Selector.row ~value ?label ?description ?icon ?is_disabled ())
  in
  let plain_options : Selector.row list =
    [ opt ~label:"Ada Lovelace" "ada"
    ; opt ~label:"Alan Turing" "alan"
    ; opt ~label:"Grace Hopper" "grace"
    ]
  in
  let grouped_options : Selector.row list =
    [ Selector.Section
        { Selector.title = Some "Analysts"
        ; options =
            [ Selector.row ~value:"ada" ~label:"Ada Lovelace" ()
            ; Selector.row ~value:"grace" ~label:"Grace Hopper" ()
            ]
        }
    ; Selector.Section
        { Selector.title = Some "Engineers"
        ; options = [ Selector.row ~value:"alan" ~label:"Alan Turing" () ]
        }
    ]
  in
  let divided_options : Selector.row list =
    [ opt ~label:"Ada Lovelace" "ada"
    ; Selector.Divider
    ; opt ~label:"Alan Turing" "alan"
    ]
  in
  let described_options : Selector.row list =
    [ opt
        ~label:"Ada Lovelace"
        ~description:(Vdom.Node.text "the first programmer")
        "ada"
    ; opt ~label:"Alan Turing" "alan"
    ]
  in
  let disabled_options : Selector.row list =
    [ opt ~label:"Ada Lovelace" "ada"
    ; opt ~label:"Alan Turing" ~is_disabled:true "alan"
    ]
  in
  let trees =
    [ ex_model
        "the options"
        (Selector.view
           ~id:"showcase-selector-options"
           ~label:"Who"
           ~options:plain_options
           ~value
           ~on_change
           graph)
    ; ex_model
        "a grouped list"
        (Selector.view
           ~id:"showcase-selector-grouped"
           ~label:"Who"
           ~options:grouped_options
           ~value
           ~on_change
           graph)
    ; ex_model
        "a list with a divider"
        (Selector.view
           ~id:"showcase-selector-divider"
           ~label:"Who"
           ~options:divided_options
           ~value
           ~on_change
           graph)
    ; ex_model
        "a list with a search field"
        (Selector.view
           ~id:"showcase-selector-search"
           ~label:"Who"
           ~has_search:true
           ~options:plain_options
           ~value
           ~on_change
           graph)
    ; ex_model
        "a row with a description"
        (Selector.view
           ~id:"showcase-selector-described"
           ~label:"Who"
           ~options:described_options
           ~value
           ~on_change
           graph)
    ; ex_model
        "an option that cannot be picked"
        (Selector.view
           ~id:"showcase-selector-disabled"
           ~label:"Who"
           ~options:disabled_options
           ~value
           ~on_change
           graph)
    ; ex_model
        "the list with nothing in it"
        (Selector.view
           ~id:"showcase-selector-empty"
           ~label:"Who"
           ~options:[]
           ~value
           ~on_change
           graph)
    ; Bonsai.map readout ~f:(fun node -> ex "the option that was picked" node)
    ]
  in
  let nodes =
    List.fold trees ~init:(Bonsai.return []) ~f:(fun acc node ->
      Bonsai.both acc node |> Bonsai.map ~f:(fun (acc, node) -> node :: acc))
    |> Bonsai.map ~f:List.rev
  in
  Bonsai.map nodes ~f:(fun nodes -> Vdom.Node.div ~attrs:[] nodes)
;;
