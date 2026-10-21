(* Table — the core of upstream's Table: a header row, body rows, a row-header
   column, optional sorting, optional selection, and the three densities.

   See table.mli for the contract and the divergences. *)

open! Core
open! Bonsai_web
open Js_of_ocaml

module Attr = Common.Attr

type density =
  | Compact
  | Balanced
  | Spacious

type align =
  | Start
  | Center
  | End

type sort_direction =
  | Ascending
  | Descending

type sort = { column_key : string; direction : sort_direction }

type cell = { content : Vdom.Node.t list; sort_value : string option }

type row = { key : string; cells : cell list }

type column =
  { key : string
  ; header : string
  ; align : align
  ; is_row_header : bool
  ; is_sortable : bool
  }

(* ------------------------------------------------------------- helpers ---- *)

let density_class = function
  | Compact -> "astryx-table--compact"
  | Balanced -> "astryx-table--balanced"
  | Spacious -> "astryx-table--spacious"
;;

let density_name = function
  | Compact -> "compact"
  | Balanced -> "balanced"
  | Spacious -> "spacious"
;;

let align_class = function
  | Start -> "astryx-table__cell--start"
  | Center -> "astryx-table__cell--center"
  | End -> "astryx-table__cell--end"
;;

(* The cell at an index, without the exception the standard library's
   [List.nth] raises when the index is past the end: a row may be short a
   cell, and a missing cell is an empty cell, not a crash. *)
let rec cell_at index cells =
  match (cells, index) with
  | [], _ -> None
  | cell :: _, 0 -> Some cell
  | _ :: rest, index when index > 0 -> cell_at (index - 1) rest
  | _ -> None
;;


(* The index of the column a sort names, if the table has such a column. *)
let rec column_index index columns key =
  match columns with
  | [] -> None
  | (column : column) :: rest ->
    if String.equal column.key key then Some index else column_index (index + 1) rest key
;;

(* Upstream's cycle: a fresh column starts ascending, the sorted column goes
   ascending -> descending -> unsorted, and unsorted starts over. *)
let next_sort current column_key =
  match current with
  | Some s when String.equal s.column_key column_key ->
    (match s.direction with
     | Ascending -> Some { s with direction = Descending }
     | Descending -> None)
  | _ -> Some { column_key; direction = Ascending }
;;

(* ---------------------------------------------------------------- view ---- *)

let view
    ?(attrs = [])
    ?(id = "astryx-table")
    ?(density = Balanced)
    ?(is_selectable = false)
    ?(has_sticky_header = false)
    ?sort
    ?default_sort
    ?on_sort_change
    ?selected
    ?default_selected
    ?on_selection_change
    ~columns
    ~rows
    graph
  =
  (* A controlled table is one whose caller owns the state: the caller
     passes the sort or the selection as a tree, and the table reports every
     change and keeps nothing. An uncontrolled table is given a starting
     value and keeps the state itself. *)
  let is_controlled_sort = Option.is_some sort in
  let is_controlled_selection = Option.is_some selected in
  let default_sort = Option.value default_sort ~default:None in
  let default_selected = Option.value default_selected ~default:[] in
  let internal_sort, set_internal_sort = Bonsai.state default_sort graph in
  let effective_sort =
    match sort with
    | Some tree -> tree
    | None -> Bonsai.map internal_sort ~f:(fun sort -> sort)
  in
  let report_sort =
    match on_sort_change with
    | Some tree -> tree
    | None -> Bonsai.return (fun (_ : sort option) -> Effect.Ignore)
  in
  let internal_selected, set_internal_selected = Bonsai.state default_selected graph in
  let effective_selected =
    match selected with
    | Some tree -> tree
    | None -> Bonsai.map internal_selected ~f:(fun selected -> selected)
  in
  let report_selection =
    match on_selection_change with
    | Some tree -> tree
    | None -> Bonsai.return (fun (_ : string list) -> Effect.Ignore)
  in
  let sort_state =
    Bonsai.map3 effective_sort report_sort set_internal_sort
      ~f:(fun sort report_sort set_internal_sort -> (sort, report_sort, set_internal_sort))
  in
  let selection_state =
    Bonsai.map3 effective_selected report_selection set_internal_selected
      ~f:(fun selected report_selection set_internal_selected ->
        (selected, report_selection, set_internal_selected))
  in
  Bonsai.map2 sort_state selection_state
    ~f:(fun
      (sort, report_sort, set_internal_sort)
      (selected, report_selection, set_internal_selected)
      ->
      let set_sort next =
        let effects =
          (if is_controlled_sort then [] else [ set_internal_sort next ])
          @ [ report_sort next ]
        in
        Effect.Many effects
      in
      let set_selection next =
        let effects =
          (if is_controlled_selection then [] else [ set_internal_selected next ])
          @ [ report_selection next ]
        in
        Effect.Many effects
      in
      (* The rows as the table shows them: the sorted order, or the order
         the caller gave when nothing is sorted. *)
      let sorted_rows =
        match sort with
        | None -> rows
        | Some s ->
          (match column_index 0 columns s.column_key with
           | None -> rows
           | Some index ->
             let value row =
               match cell_at index row.cells with
               | None -> ""
               | Some cell -> Option.value cell.sort_value ~default:""
             in
             let compare_rows a b = String.compare (value a) (value b) in
             (match s.direction with
              | Ascending -> List.stable_sort rows ~compare:compare_rows
              | Descending -> List.stable_sort rows ~compare:(fun a b -> compare_rows b a)))
      in
      let all_keys = List.map rows ~f:(fun (row : row) -> row.key) in
      let selected_count =
        List.fold rows ~init:0 ~f:(fun count row ->
          if List.mem selected row.key ~equal:String.equal then count + 1 else count)
      in
      let is_all_selected = selected_count > 0 && selected_count = List.length rows in
      let is_some_selected = selected_count > 0 && not is_all_selected in
      let select_all_value =
        if is_all_selected then Checkbox_input.Checked
        else if is_some_selected then Checkbox_input.Indeterminate
        else Checkbox_input.Unchecked
      in
      let toggle_all (value : Checkbox_input.value) =
        let next = match value with Checkbox_input.Checked -> all_keys | _ -> [] in
        set_selection next
      in
      let toggle_row key (value : Checkbox_input.value) =
        let next =
          match value with
          | Checkbox_input.Checked ->
            if List.mem selected key ~equal:String.equal then selected else selected @ [ key ]
          | _ -> List.filter selected ~f:(fun k -> not (String.equal k key))
        in
        set_selection next
      in
      (* One header cell. A sortable column's header is a real button, so
         the keyboard reaches it and the sort state is announced through
         the [aria-sort] on the cell itself. *)
      let render_header_cell (column : column) =
        let aria_sort =
          match sort with
          | Some s when String.equal s.column_key column.key ->
            (match s.direction with
             | Ascending -> Some "ascending"
             | Descending -> Some "descending")
          | _ -> None
        in
        let icon_name =
          match sort with
          | Some s when String.equal s.column_key column.key ->
            (match s.direction with
             | Ascending -> "arrowUp"
             | Descending -> "arrowDown")
          | _ -> "arrowsUpDown"
        in
        let label = Text.view ~type_:Text.Label [ Vdom.Node.text column.header ] in
        let content =
          if column.is_sortable then
            let next = next_sort sort column.key in
            [ Vdom.Node.button
                ~attrs:
                  (Attr.class_ [ "astryx-table__sort" ]
                   @ [ Vdom.Attr.create "type" "button"
                     ; Vdom.Attr.on_click
                         (fun (_ : Dom_html.mouseEvent Js.t) -> set_sort next)
                     ])
                [ label
                ; Icon.view ~size:Icon.Xsm ~name:icon_name ()
                ]
            ]
          else [ label ]
        in
        Vdom.Node.th
          ~attrs:
            (Attr.class_ [ "astryx-table__header-cell"; align_class column.align ]
             @ (match aria_sort with
                | Some value -> [ Vdom.Attr.create "aria-sort" value ]
                | None -> [])
             @ Common.Attr.data "column" column.key)
          content
      in
      let render_selection_header_cell () =
        Vdom.Node.th
          ~attrs:(Attr.class_ [ "astryx-table__header-cell"; "astryx-table__cell--selection" ])
          [ Checkbox_input.render
              ~is_label_hidden:true
              ~label:"Select all rows"
              ~id:(id ^ "-select-all")
              ~value:select_all_value
              ~on_change:toggle_all
              ()
          ]
      in
      let render_body_row (row : row) =
        let is_selected = List.mem selected row.key ~equal:String.equal in
        let cells =
          List.mapi columns ~f:(fun index (column : column) ->
            let content =
              match cell_at index row.cells with
              | None -> []
              | Some cell -> cell.content
            in
            if column.is_row_header then
              Vdom.Node.th
                ~attrs:
                  (Attr.class_
                     [ "astryx-table__cell"
                     ; "astryx-table__cell--row-header"
                     ; align_class column.align ]
                   @ [ Vdom.Attr.create "scope" "row" ]
                   @ Common.Attr.data "column" column.key)
                content
            else
              Vdom.Node.td
                ~attrs:
                  (Attr.class_ [ "astryx-table__cell"; align_class column.align ]
                   @ Common.Attr.data "column" column.key)
                content)
        in
        let selection_cell =
          if not is_selectable then
            []
          else
            [ Vdom.Node.td
                ~attrs:(Attr.class_ [ "astryx-table__cell"; "astryx-table__cell--selection" ])
                [ Checkbox_input.render
                    ~is_label_hidden:true
                    ~label:("Select " ^ row.key)
                    ~id:(id ^ "-select-" ^ row.key)
                    ~value:(if is_selected then Checkbox_input.Checked else Checkbox_input.Unchecked)
                    ~on_change:(toggle_row row.key)
                    ()
                ]
            ]
        in
        Vdom.Node.tr
          ~attrs:
            (Attr.class_
               ([ "astryx-table__row" ]
                @ (if is_selected then [ "astryx-table__row--selected" ] else []))
             @ (if is_selectable
                then [ Vdom.Attr.create "aria-selected" (if is_selected then "true" else "false") ]
                else [])
             @ Common.Attr.data "row" row.key)
          (selection_cell @ cells)
      in
      let header_cells =
        (if is_selectable then [ render_selection_header_cell () ] else [])
        @ List.map columns ~f:render_header_cell
      in
      let header_row = Vdom.Node.tr ~attrs:(Attr.class_ [ "astryx-table__row" ]) header_cells in
      let body_rows = List.map sorted_rows ~f:render_body_row in
      let root_attrs =
        Attr.class_
          ([ "astryx-table"; density_class density ]
           @ (if has_sticky_header then [ "astryx-table--sticky-header" ] else []))
        @ Common.Attr.data "component" "Table"
        @ Common.Attr.data "density" (density_name density)
        @ Common.Attr.data "is-selectable" (string_of_bool is_selectable)
        @ Common.Attr.data "selected-count" (string_of_int selected_count)
        @ Common.Attr.data
            "sort-column"
            (match sort with
             | Some s -> s.column_key
             | None -> "")
        @ Common.Attr.data
            "sort-direction"
            (match sort with
             | Some s ->
               (match s.direction with
                | Ascending -> "ascending"
                | Descending -> "descending")
             | None -> "none")
        @ [ Vdom.Attr.create "id" id ]
        @ attrs
      in
      Vdom.Node.table
        ~attrs:root_attrs
        [ Vdom.Node.thead ~attrs:[] [ header_row ]
        ; Vdom.Node.tbody ~attrs:[] body_rows
        ])
;;
