(* Tokenizer — the multi-select field: token chips and a combobox input in one box.

   Every example below is a real, controlled field: the application holds the
   selected set, and the component reports every change to it. The examples that
   differ only in their props share that wiring, so the section shows the
   component working rather than a static picture of it.

   The one thing the section cannot show is the asynchronous search: upstream's
   [searchSource] returns promises and its queries are debounced, and this
   port's source is synchronous, so there is no busy state to catch. *)

open! Core
open! Bonsai_web

module Tokenizer = Astryx.Tokenizer

open Prelude

(* The catalogue the examples search. A small, fixed set of people - enough to
   show a result list, and a "nothing matched" list when the query is long
   enough. *)
let catalogue =
  [ { Tokenizer.id = "1"; label = "Ada Lovelace" }
  ; { Tokenizer.id = "2"; label = "Alan Turing" }
  ; { Tokenizer.id = "3"; label = "Grace Hopper" }
  ; { Tokenizer.id = "4"; label = "Katherine Johnson" }
  ; { Tokenizer.id = "5"; label = "Radia Perlman" }
  ; { Tokenizer.id = "6"; label = "Barbara Liskov" }
  ]
;;

(* The catalogue is a list, so picking one by position is [List.nth_exn] - the
   [.(i)] syntax is for arrays. *)
let person index = List.nth_exn catalogue index
;;

(* A synchronous source: a case-insensitive substring match over the
   catalogue. Upstream's bootstrap - what the field offers before anything is
   typed - is the whole catalogue here, which is what [has_entries_on_focus]
   shows. *)
let source =
  { Tokenizer.search =
      (fun query ->
        let query = String.lowercase (String.strip query) in
        if String.is_empty query then []
        else
          List.filter catalogue ~f:(fun (item : Tokenizer.item) ->
            (* A substring match, not a prefix match: the source is the
               caller's, and a caller whose source matches substrings is
               common. *)
            String.is_substring (String.lowercase item.label) ~substring:query))
  ; bootstrap = catalogue
  }
;;

let demo (graph : Bonsai.graph) : Vdom.Node.t Bonsai.t =
  let ex_tree label tree = Bonsai.map tree ~f:(fun node -> ex label node) in
  (* A controlled field: the value is a state, and the change handler writes it
     back. The handler is a [Bonsai.t] because the component takes one - a
     state setter is itself a value in the graph, which is what keeps the call
     site a single expression. *)
  let controlled ~init =
    let value, set_value = Bonsai.state init graph in
    let on_change =
      Bonsai.map set_value ~f:(fun set_value ->
        fun (items : Tokenizer.item list) (_change : Tokenizer.change) -> set_value items)
    in
    (value, on_change)
  in
  (* Each example gets its own id, and the example box around it gets one too,
     so the browser gate can address either the field or the example. *)
  (* The wrapper's id is NOT the component's id: the component takes an id of
     its own, and two elements sharing one would make every id-based address
     in the gate ambiguous. *)
  let example_id name = "showcase-tokenizer-example-" ^ name in
  let boxed name tree =
    Bonsai.map tree ~f:(fun node ->
      Vdom.Node.div ~attrs:[ Vdom.Attr.create "id" (example_id name) ] [ node ])
  in
  (* --- the plain field, with two tokens already chosen ---------------------- *)
  let plain_value, plain_on_change =
    controlled ~init:[ person 0; person 2 ]
  in
  let plain =
    Tokenizer.view
      ~id:"showcase-tokenizer-default"
      ~label:"Reviewers"
      ~value:plain_value
      ~on_change:plain_on_change
      ~source
      graph
  in
  (* --- the field that searches --------------------------------------------- *)
  let search_value, search_on_change =
    controlled ~init:[ person 1 ]
  in
  let search =
    Tokenizer.view
      ~id:"showcase-tokenizer-search"
      ~label:"Add a reviewer"
      ~placeholder:"Search people..."
      ~start_icon:"search"
      ~has_clear:true
      ~has_entries_on_focus:true
      ~value:search_value
      ~on_change:search_on_change
      ~source
      graph
  in
  (* --- free text becomes a token ------------------------------------------- *)
  let create_value, create_on_change =
    controlled ~init:[]
  in
  let create =
    Tokenizer.view
      ~id:"showcase-tokenizer-create"
      ~label:"Tags"
      ~placeholder:"Search or create..."
      ~has_create:true
      ~value:create_value
      ~on_change:create_on_change
      ~source
      graph
  in
  (* --- the bounded field ---------------------------------------------------- *)
  let max_value, max_on_change =
    controlled ~init:[ person 0; person 1; person 2 ]
  in
  let max_entries =
    Tokenizer.view
      ~id:"showcase-tokenizer-max"
      ~label:"Approvers"
      ~description:"Up to three - and three are chosen."
      ~max_entries:3
      ~value:max_value
      ~on_change:max_on_change
      ~source
      graph
  in
  (* --- the disabled field, and why it is disabled --------------------------- *)
  let disabled_value, disabled_on_change =
    controlled ~init:[ person 0 ]
  in
  let disabled =
    Tokenizer.view
      ~id:"showcase-tokenizer-disabled"
      ~label:"Reviewers"
      ~is_disabled:true
      ~disabled_message:"Reviewers are assigned by the release captain."
      ~value:disabled_value
      ~on_change:disabled_on_change
      ~source
      graph
  in
  (* --- the field with a validation message --------------------------------- *)
  let error_value, error_on_change =
    controlled ~init:[]
  in
  let error =
    Tokenizer.view
      ~id:"showcase-tokenizer-error"
      ~label:"Reviewers"
      ~status:
        { Astryx.Input_types.type_ = Astryx.Input_types.Error
        ; message = Some "Choose at least one reviewer."
        }
      ~value:error_value
      ~on_change:error_on_change
      ~source
      graph
  in
  (* --- the sizes ------------------------------------------------------------ *)
  let size_value, size_on_change =
    controlled ~init:[ person 0 ]
  in
  let small =
    Tokenizer.view
      ~id:"showcase-tokenizer-size-sm"
      ~label:"Small"
      ~size:Tokenizer.Sm
      ~value:size_value
      ~on_change:size_on_change
      ~source
      graph
  in
  let large =
    Tokenizer.view
      ~id:"showcase-tokenizer-size-lg"
      ~label:"Large"
      ~size:Tokenizer.Lg
      ~value:size_value
      ~on_change:size_on_change
      ~source
      graph
  in
  let sizes =
    Bonsai.map2 small large ~f:(fun small large ->
      Vdom.Node.div
        ~attrs:[ Vdom.Attr.create "id" (example_id "sizes") ]
        [ small; large ])
  in
  (* --- the field whose tokens overflow ------------------------------------- *)
  let overflow_value, overflow_on_change =
    controlled ~init:[ person 0; person 1; person 2; person 3; person 4 ]
  in
  (* A field narrow enough that the chips cannot all fit: the point of the
     example is the collapse, and a field wide enough for every chip shows
     nothing collapsing. The width is a field width, so the label, the control
     and the message stay aligned. *)
  let overflow =
    Tokenizer.view
      ~id:"showcase-tokenizer-overflow"
      ~label:"Everyone"
      ~description:"A narrow field, so the row collapses to one line."
      ~width:(Astryx.Common.Size_value.Css "min(320px, 100%)")
      ~token_overflow_behavior:Tokenizer.Unfocused_inline
      ~value:overflow_value
      ~on_change:overflow_on_change
      ~source
      graph
  in
  (* --- the form carrier: one hidden input per selected id ------------------- *)
  let html_value, html_on_change =
    controlled ~init:[ person 0; person 3 ]
  in
  let html_name =
    Tokenizer.view
      ~id:"showcase-tokenizer-html-name"
      ~label:"Reviewers"
      ~html_name:"reviewers"
      ~value:html_value
      ~on_change:html_on_change
      ~source
      graph
  in
  let examples =
    [ ex_tree "default: two chips, and the input after them" (boxed "default" plain)
    ; ex_tree "search: type to filter, the clear button empties the field" (boxed "search" search)
    ; ex_tree "create: free text becomes a token" (boxed "create" create)
    ; ex_tree "max entries: the input is still there at the limit" (boxed "max-entries" max_entries)
    ; ex_tree "disabled: the reason is said on hover and on focus" (boxed "disabled" disabled)
    ; ex_tree "error: the message belongs to the field" (boxed "error" error)
    ; ex_tree "sizes: the chips and the input scale together" sizes
    ; ex_tree "overflow: one line, and the rest behind a count" (boxed "overflow" overflow)
    ; ex_tree "form: one hidden input per selected id" (boxed "html-name" html_name)
    ]
  in
  Bonsai.map (unwrap_all examples) ~f:(fun examples ->
    section
      ~id:"tokenizer"
      ~title:"Tokenizer"
      ~note:
        "A multi-select: the chips are the selections and the input beside them \
         searches for the next one. The field is controlled - the application \
         holds the set and the component reports every change to it - and a \
         token that appears or disappears is said in a polite live region. The \
         suggestion list is a listbox, so the highlight is an index and the \
         active option is named by id. The search source is synchronous here, \
         so there is no busy state."
      examples)
;;
