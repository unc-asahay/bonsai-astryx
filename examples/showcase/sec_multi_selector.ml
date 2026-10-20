(* MultiSelector — the multi-select field: the trigger's summary of the
   selection, and the options list it opens.

   Every example below is controlled: the selection lives in the example's own
   state, and the field writes the next selection back into it. That is the
   shape an application uses — the component never holds the selection itself.

   The list is a native popover surface, so it is drawn in place rather than in
   a portal (the house has no portal): the platform promotes it to the top
   layer, dismisses it on an outside pointer press and anchors it to the
   trigger. *)

open! Core
open! Bonsai_web

module Multi_selector = Astryx.Multi_selector

open Prelude

(* An option, with the label defaulting to the value, the way upstream's
   normalizeOption does. *)
(* The data behind one option. A section holds option data, so the two are
   separate: [data] is the row, [item] wraps it for the top-level list. *)
let data ?label ?description ?(is_disabled = false) value =
  { Multi_selector.value = value
  ; label = Option.value label ~default:(Some value)
  ; description
  ; is_disabled
  }

let item ?label ?description ?is_disabled value =
  Multi_selector.Option (data ?label ?description ?is_disabled value)
;;

let section_of ?title options =
  Multi_selector.Section { Multi_selector.title; options }
;;

let demo (graph : Bonsai.graph) : Vdom.Node.t Bonsai.t =
  let ex_tree label tree = Bonsai.map tree ~f:(fun node -> ex label node) in
  let join_all (trees : Vdom.Node.t Bonsai.t list) =
    List.fold trees ~init:(Bonsai.return []) ~f:(fun acc tree ->
      Bonsai.both acc tree |> Bonsai.map ~f:(fun (acc, tree) -> tree :: acc))
    |> Bonsai.map ~f:List.rev
  in
  let people =
    [ item "Ada Lovelace"; item "Grace Hopper"; item "Alan Turing"; item "Katherine Johnson" ]
  in
  let permissions =
    [ item ~label:(Some "Read") "read"
    ; item ~label:(Some "Write") "write"
    ; item ~label:(Some "Admin") "admin"
    ; item ~label:(Some "Billing (not available yet)") ~is_disabled:true "billing"
    ]
  in
  (* Each example owns its selection: the field is controlled, so the state
     here is the source of truth for what is chosen. *)
  let default_value, default_on_change = Bonsai.state [ "read" ] graph in
  let search_value, search_on_change = Bonsai.state [ "read"; "write" ] graph in
  let badges_value, badges_on_change = Bonsai.state [ "read"; "write"; "admin" ] graph in
  let labels_value, labels_on_change = Bonsai.state [ "Grace Hopper" ] graph in
  let clear_value, clear_on_change = Bonsai.state [ "read"; "write" ] graph in
  let disabled_value, disabled_on_change = Bonsai.state [ "read" ] graph in
  let empty_value, empty_on_change = Bonsai.state [] graph in
  let grouped_value, grouped_on_change = Bonsai.state [ "Ada Lovelace" ] graph in
  let examples =
    [ ex_tree
        "Default"
        (Multi_selector.view
           ~label:"Columns"
           ~options:[ item "Name"; item "Email"; item "Role"; item "Status" ]
           ~value:default_value
           ~on_change:default_on_change
           graph)
    ; ex_tree
        "With search"
        (Multi_selector.view
           ~label:"Permissions"
           ~has_search:true
           ~search_placeholder:"Search permissions..."
           ~options:permissions
           ~value:search_value
           ~on_change:search_on_change
           graph)
    ; ex_tree
        "Badges"
        (Multi_selector.view
           ~label:"Permissions"
           ~trigger_display:Multi_selector.Badges
           ~options:permissions
           ~value:badges_value
           ~on_change:badges_on_change
           graph)
    ; ex_tree
        "Labels"
        (Multi_selector.view
           ~label:"Owner"
           ~trigger_display:Multi_selector.Labels
           ~options:people
           ~value:labels_value
           ~on_change:labels_on_change
           graph)
    ; ex_tree
        "With clear button"
        (Multi_selector.view
           ~label:"Permissions"
           ~has_clear:true
           ~options:permissions
           ~value:clear_value
           ~on_change:clear_on_change
           graph)
    ; ex_tree
        "Disabled"
        (Multi_selector.view
           ~label:"Permissions"
           ~is_disabled:true
           ~options:permissions
           ~value:disabled_value
           ~on_change:disabled_on_change
           graph)
    ; ex_tree
        "Empty"
        (Multi_selector.view
           ~label:"Permissions"
           ~options:[]
           ~value:empty_value
           ~on_change:empty_on_change
           graph)
    ; ex_tree
        "Sections and dividers"
        (Multi_selector.view
           ~label:"People"
           ~options:
             [ section_of ~title:"Pioneers" [ data "Ada Lovelace"; data "Grace Hopper" ]
             ; Multi_selector.Divider
             ; section_of ~title:"Everyone else" [ data "Alan Turing"; data "Katherine Johnson" ]
             ]
           ~value:grouped_value
           ~on_change:grouped_on_change
           graph)
    ]
  in
  let nodes = join_all examples in
  Bonsai.map nodes ~f:(fun nodes ->
      section
        ~id:"multi-selector"
        ~title:"MultiSelector"
        ~note:
          "The multi-select field. The trigger summarises the selection (a count, the chosen labels, or a badge each); opening it lists the options, with the chosen ones marked, a search field when asked for, and sections and dividers where the caller groups them."
        nodes)
;;
