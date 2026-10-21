(* Table — the core table: a header row, body rows, a row-header column,
   optional sorting, optional selection, and the three densities.

   Upstream's Table is a plugin pipeline; this port is its core, so the
   examples below show the pieces the core has rather than the plugins it
   does not. Sorting and selection are shown in their controlled form: the
   showcase owns the state, so the current sort and the selected rows are
   visible next to the table.

   Every example carries a distinct DOM id, so the browser gate can address
   it: "showcase-table-<variant>" on the table itself. *)

open! Core
open! Bonsai_web
open Prelude

module T = Astryx.Table

(* The record fields are written qualified, so the showcase never has to
   disambiguate a field name against another component's. *)
let column ~key ~header ?(align = T.Start) ?(is_row_header = false) ?(is_sortable = false) () : T.column =
  { T.key = key
  ; T.header = header
  ; T.align = align
  ; T.is_row_header = is_row_header
  ; T.is_sortable = is_sortable
  }
;;

let cell ~content ?sort_value () : T.cell = { T.content = content; T.sort_value = sort_value }

let row ~key ~cells () : T.row = { T.key = key; T.cells = cells }

let text_content s = [ Vdom.Node.text s ]

(* The data set every example draws on. The first column is the row header:
   it names the row, so it is a [th scope="row"] rather than a cell that
   belongs to a column. *)
let rows =
  [ ("ada", "Ada Lovelace", "Engineer", "Platform", "42")
  ; ("grace", "Grace Hopper", "Engineer", "Compilers", "87")
  ; ("alan", "Alan Turing", "Researcher", "Cryptography", "31")
  ; ("katherine", "Katherine Johnson", "Mathematician", "Orbital", "26")
  ; ("margaret", "Margaret Hamilton", "Engineer", "Guidance", "64")
  ]
;;

let columns =
  [ column ~key:"name" ~header:"Name" ~is_row_header:true ~is_sortable:true ()
  ; column ~key:"role" ~header:"Role" ~is_sortable:true ()
  ; column ~key:"team" ~header:"Team" ~is_sortable:true ()
  ; column ~key:"commits" ~header:"Commits" ~align:T.End ~is_sortable:true ()
  ]
;;

let build_rows ~columns =
  List.map rows ~f:(fun (key, name, role, team, commits) ->
    let cells =
      List.map columns ~f:(fun (column : T.column) ->
        let content, sort_value =
          match column.T.key with
          | "name" -> (text_content name, Some name)
          | "role" -> (text_content role, Some role)
          | "team" -> (text_content team, Some team)
          | "commits" -> (text_content commits, Some commits)
          | _ -> ([], None)
        in
        cell ~content ?sort_value ())
    in
    row ~key ~cells ())
;;

let demo (graph : Bonsai.graph) : Vdom.Node.t Bonsai.t =
  let ex_tree label tree = Bonsai.map tree ~f:(fun node -> ex label node) in
  let data = build_rows ~columns in
  (* The plain table: a header row and body rows, nothing else. *)
  let basic = T.view ~id:"showcase-table-basic" ~columns ~rows:data graph in
  (* The same table with the first column as the row header. The columns
     above already mark it, so this example differs from the plain one by
     showing what the row header does to the cell: it heads its row. *)
  let row_header =
    let row_header_columns =
      [ column ~key:"name" ~header:"Name" ~is_row_header:true ()
      ; column ~key:"role" ~header:"Role" ()
      ; column ~key:"team" ~header:"Team" ()
      ; column ~key:"commits" ~header:"Commits" ~align:T.End ()
      ]
    in
    T.view
      ~id:"showcase-table-row-header"
      ~columns:row_header_columns
      ~rows:(build_rows ~columns:row_header_columns)
      graph
  in
  (* The three densities, one example each. *)
  let density_compact =
    T.view ~id:"showcase-table-density-compact" ~density:T.Compact ~columns ~rows:data graph
  in
  let density_balanced =
    T.view ~id:"showcase-table-density-balanced" ~density:T.Balanced ~columns ~rows:data graph
  in
  let density_spacious =
    T.view ~id:"showcase-table-density-spacious" ~density:T.Spacious ~columns ~rows:data graph
  in
  (* Sorting, in its controlled form: the showcase owns the sort state, so
     the current sort can be read out beside the table. Clicking a header
     cycles that column ascending -> descending -> unsorted. *)
  let sort, set_sort = Bonsai.state (None : T.sort option) graph in
  let set_sort_f = Bonsai.map set_sort ~f:(fun f -> f) in
  let on_sort_change = Bonsai.map set_sort_f ~f:(fun set_sort -> fun next -> set_sort next) in
  let sort_readout =
    Bonsai.map sort ~f:(fun sort ->
      let text =
        match sort with
        | None -> "sort: none"
        | Some sort ->
          sprintf
            "sort: %s, %s"
            sort.T.column_key
            (match sort.T.direction with
             | T.Ascending -> "ascending"
             | T.Descending -> "descending")
      in
      Vdom.Node.div ~attrs:[ Vdom.Attr.create "id" "showcase-table-sorting-readout" ] [ Vdom.Node.text text ])
  in
  let sorting =
    Bonsai.map2 (T.view ~id:"showcase-table-sorting" ~sort ~on_sort_change ~columns ~rows:data graph) sort_readout
      ~f:(fun table readout -> Vdom.Node.div ~attrs:[] [ table; readout ])
  in
  (* Selection, also controlled: the showcase owns the selected row keys, so
     the count is visible beside the table. The header carries the select-all
     checkbox, which is indeterminate while the selection is partial. *)
  let selected, set_selected = Bonsai.state ([] : string list) graph in
  let set_selected_f = Bonsai.map set_selected ~f:(fun f -> f) in
  let on_selection_change =
    Bonsai.map set_selected_f ~f:(fun set_selected -> fun next -> set_selected next)
  in
  let selection_readout =
    Bonsai.map selected ~f:(fun selected ->
      Vdom.Node.div ~attrs:[ Vdom.Attr.create "id" "showcase-table-selection-readout" ]
        [ Vdom.Node.text (sprintf "selected: %d" (List.length selected)) ])
  in
  let selection =
    Bonsai.map2
      (T.view
         ~id:"showcase-table-selection"
         ~is_selectable:true
         ~selected
         ~on_selection_change
         ~columns
         ~rows:data
         graph)
      selection_readout
      ~f:(fun table readout -> Vdom.Node.div ~attrs:[] [ table; readout ])
  in
  let examples =
    [ ex_tree "a header row and body rows" basic
    ; ex_tree "a row-header column" row_header
    ; ex_tree "density: compact" density_compact
    ; ex_tree "density: balanced" density_balanced
    ; ex_tree "density: spacious" density_spacious
    ; ex_tree "sorting, on a column" sorting
    ; ex_tree "selection, per row" selection
    ]
  in
  Bonsai.map (unwrap_all examples) ~f:(fun examples ->
    section
      ~id:"table"
      ~title:"Table"
      ~note:
        "A semantic table: a header row of column headers, body rows of cells, and a \
         row-header column that heads its row rather than belonging to a column. The density \
         sets the cell padding. Sorting and selection are controlled here — the showcase \
         owns the state, so the current sort and the selected rows are read out beside the \
         table. Upstream's virtualisation, column resize, column grouping and sticky columns \
         are not ported."
      examples)
;;
