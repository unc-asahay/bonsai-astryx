(* DateRangeInput — a pair of text fields for the ends of a date range, with
   a calendar to pick them.

   The field owns the draft text of each end and whether the calendar is
   open; the application owns the committed range. A range picked in the
   calendar is the whole range, so the fields go back to showing the
   committed value and the surface closes.

   The examples below show the field with a committed range, on its own, in
   the disabled state, and while a search is in flight. *)

open! Core
open! Bonsai_web

module Date_range_input = Astryx.Date_range_input
module Plain_date = Astryx.Plain_date
module Calendar = Astryx.Calendar

open Prelude

let ex_tree label tree = Bonsai.map tree ~f:(fun node -> ex label node)

let join_all (trees : Vdom.Node.t Bonsai.t list) =
  List.fold trees ~init:(Bonsai.return []) ~f:(fun acc tree ->
    Bonsai.both acc tree |> Bonsai.map ~f:(fun (acc, tree) -> tree :: acc))
  |> Bonsai.map ~f:List.rev
;;

(* A day in the middle of the month, so the committed range is easy to see. *)
let day n = Plain_date.create ~year:2026 ~month:3 ~day:n

let demo (graph : Bonsai.graph) : Vdom.Node.t Bonsai.t =
  (* The committed range is the application's own state, so the field is
     controlled: it shows what it is given and reports what was picked. *)
  let committed, set_committed = Bonsai.state' (None : Date_range_input.date_range option) graph in
  let committed_value = Bonsai.map committed ~f:(fun value -> value) in
  let on_change =
    Bonsai.map set_committed ~f:(fun set_committed -> fun value -> set_committed (fun _ -> value))
  in
  let plain =
    Date_range_input.view
      ~id:"showcase-date-range-plain"
      ~label:"Date range"
      ~value:committed_value
      ~on_change
      graph
  in
  let with_range =
    Date_range_input.view
      ~id:"showcase-date-range-value"
      ~label:"A committed range"
      ~value:(Bonsai.return (Some { Calendar.start_date = day 3; end_date = day 11 }))
      ~on_change
      graph
  in
  let disabled =
    Date_range_input.view
      ~id:"showcase-date-range-disabled"
      ~label:"Disabled"
      ~is_disabled:true
      ~disabled_message:"Ranges are not available for this account"
      ~value:(Bonsai.return None)
      ~on_change
      graph
  in
  let loading =
    Date_range_input.view
      ~id:"showcase-date-range-loading"
      ~label:"While the calendar loads"
      ~is_loading:true
      ~value:(Bonsai.return None)
      ~on_change
      graph
  in
  let constrained =
    Date_range_input.view
      ~id:"showcase-date-range-constrained"
      ~label:"From the 10th onwards"
      ~min:(day 10)
      ~value:(Bonsai.return None)
      ~on_change
      graph
  in
  join_all
    [ ex_tree "the field alone" plain
    ; ex_tree "with a committed range" with_range
    ; ex_tree "disabled" disabled
    ; ex_tree "while the calendar loads" loading
    ; ex_tree "with a minimum date" constrained
    ]
  |> Bonsai.map ~f:(fun examples ->
         section
           ~id:"date-range-input"
           ~title:"DateRangeInput"
           ~note:
             "Two text fields for the ends of a range, and a calendar to pick them. The field owns the draft text of each end; the application owns the committed range. A range picked in the calendar is the whole range, so the fields go back to showing what was committed."
           examples)
