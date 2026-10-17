open! Core

type collapse_from =
  | Start
  | End
[@@deriving sexp_of]

type t =
  { visible_count : int
  ; rows : int
  }
[@@deriving sexp_of]

(* Math.max(Math.min(value, max), min) - the floor is applied last, which is what makes the floor win when
   the two bounds cross. *)
let clamp value ~min ~max = Int.max (Int.min value max) min

let resolve_bounds ~item_count ~min_visible_items ~max_visible_items =
  let floor = Int.max 0 (Int.min min_visible_items item_count) in
  let ceiling =
    Int.max 0 (Int.min (Option.value max_visible_items ~default:item_count) item_count)
  in
  floor, ceiling
;;

let compute_single_line_fit ordered_widths ~gap ~available_width ~indicator_width ~floor ~ceiling =
  let arr = Array.of_list ordered_widths in
  let n = Array.length arr in
  let total_width = ref 0 in
  let count = ref 0 in
  let i = ref 0 in
  let stop = ref false in
  while (not !stop) && !i < n do
    if !count >= ceiling
    then stop := true
    else (
      let item_width = arr.(!i) in
      let gap_width = if !i > 0 then gap else 0 in
      let candidate_width = !total_width + item_width + gap_width in
      let is_last_item = !i = n - 1 in
      (* Space for the "+N" marker, for every admitted item except the last one - and for the first item
         too when there is a marker to show at all. *)
      let reserved_width =
        if is_last_item
        then 0
        else indicator_width + (if !count > 0 || indicator_width > 0 then gap else 0)
      in
      if candidate_width + reserved_width > available_width && !count >= floor
      then stop := true
      else (
        total_width := candidate_width;
        incr count;
        incr i))
  done;
  !count
;;

let pack_rows ordered_widths ~gap ~available_width ~indicator_reserve ~max_rows =
  let arr = Array.of_list ordered_widths in
  let n = Array.length arr in
  let placed = ref 0 in
  let row = ref 1 in
  let row_width = ref 0 in
  let i = ref 0 in
  while !i < n do
    let w = arr.(!i) in
    let is_first_in_row = !row_width = 0 in
    let candidate = if is_first_in_row then w else !row_width + gap + w in
    let on_last_row = !row = max_rows in
    let reserve = if on_last_row && indicator_reserve > 0 then indicator_reserve + gap else 0 in
    if candidate + reserve <= available_width
    then (
      row_width := candidate;
      incr placed;
      incr i)
    else if is_first_in_row
    then (
      (* An item wider than the row occupies it alone (it will be clipped). But if it cannot coexist with
         the reserved marker on the last row, stop. *)
      if on_last_row && reserve > 0
      then i := n
      else (
        row_width := candidate;
        incr placed;
        incr i))
    else if !row >= max_rows
    then i := n
    else (
      incr row;
      row_width := 0)
    (* else: i is deliberately not advanced - this item is re-attempted as the first of the new row. *)
  done;
  !placed, !row
;;

let count_rows ordered_widths ~gap ~available_width =
  match ordered_widths with
  | [] -> 0
  | _ ->
    let arr = Array.of_list ordered_widths in
    let rows = ref 1 in
    let row_width = ref 0 in
    Array.iter arr ~f:(fun w ->
        let is_first_in_row = !row_width = 0 in
        let candidate = if is_first_in_row then w else !row_width + gap + w in
        if candidate <= available_width || is_first_in_row
        then row_width := candidate
        else (
          incr rows;
          row_width := w));
    !rows
;;

let compute_multi_row_fit ordered_widths ~gap ~available_width ~indicator_width ~max_rows =
  let n = List.length ordered_widths in
  if n = 0
  then 0, 0
  else (
    (* Everything fits within max_rows without reserving space for a marker: no overflow, no marker. *)
    let pack_all = pack_rows ordered_widths ~gap ~available_width ~indicator_reserve:0 ~max_rows in
    match pack_all with
    | placed, rows when placed = n -> n, rows
    | _ ->
      let count, _ = pack_rows ordered_widths ~gap ~available_width ~indicator_reserve:indicator_width ~max_rows in
      let rows = count_rows (List.take ordered_widths count) ~gap ~available_width in
      count, Int.max (if count > 0 then 1 else 0) rows)
;;

let compute
  ~widths
  ~gap
  ~available_width
  ~indicator_width
  ~min_visible_items
  ?max_visible_items
  ?max_rows
  ~collapse_from
  ()
  =
  let item_count = List.length widths in
  if item_count = 0
  then { visible_count = 0; rows = 0 }
  else (
    let floor, ceiling = resolve_bounds ~item_count ~min_visible_items ~max_visible_items in
    let ordered_widths = match collapse_from with End -> widths | Start -> List.rev widths in
    let multi_row = Option.value_map max_rows ~default:false ~f:(fun r -> r > 1) in
    if not multi_row
    then (
      let fit_count =
        compute_single_line_fit ordered_widths ~gap ~available_width ~indicator_width ~floor ~ceiling
      in
      let visible_count = clamp fit_count ~min:floor ~max:ceiling in
      { visible_count; rows = (if visible_count > 0 then 1 else 0) })
    else (
      let max_rows = Option.value_exn max_rows in
      let count, rows =
        compute_multi_row_fit ordered_widths ~gap ~available_width ~indicator_width ~max_rows
      in
      let visible_count = clamp count ~min:floor ~max:ceiling in
      let resolved_rows =
        if visible_count = count
        then rows
        else count_rows (List.take ordered_widths visible_count) ~gap ~available_width
      in
      { visible_count
      ; rows = (if visible_count > 0 then Int.max 1 resolved_rows else 0)
      }))
;;
