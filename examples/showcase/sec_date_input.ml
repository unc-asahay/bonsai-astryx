(* DateInput — a text field for a date, with a calendar to pick one from.

   The field owns the text being typed; the application owns the committed
   date. A date that can be read is committed as it is typed. Text that
   cannot be read is kept in the field while it is typed, and the field
   falls back to the committed date when it is left or Enter is pressed.

   The examples below show the field alone, a committed date, the ISO form,
   the long form, disabled, and the field bounded by a minimum date. *)

open! Core
open! Bonsai_web

module Date_input = Astryx.Date_input
module Plain_date = Astryx.Plain_date

open Prelude

let ex_tree label tree = Bonsai.map tree ~f:(fun node -> ex label node)

let join_all (trees : Vdom.Node.t Bonsai.t list) =
  List.fold trees ~init:(Bonsai.return []) ~f:(fun acc tree ->
    Bonsai.both acc tree |> Bonsai.map ~f:(fun (acc, tree) -> tree :: acc))
  |> Bonsai.map ~f:List.rev
;;

let demo (graph : Bonsai.graph) : Vdom.Node.t Bonsai.t =
  let committed, set_committed = Bonsai.state' (None : Plain_date.t option) graph in
  let on_change =
    Bonsai.map set_committed ~f:(fun set_committed -> fun value -> set_committed (fun _ -> value))
  in
  let plain =
    Date_input.view
      ~id:"showcase-date-plain"
      ~label:"Date"
      ~value:committed
      ~on_change
      graph
  in
  let with_value =
    Date_input.view
      ~id:"showcase-date-value"
      ~label:"A committed date"
      ~value:(Bonsai.return (Some (Plain_date.create ~year:2026 ~month:3 ~day:21)))
      ~on_change
      graph
  in
  let system_date =
    Date_input.view
      ~id:"showcase-date-iso"
      ~label:"In the system form"
      ~format:Date_input.System_date
      ~value:(Bonsai.return (Some (Plain_date.create ~year:2026 ~month:3 ~day:21)))
      ~on_change
      graph
  in
  let long_form =
    Date_input.view
      ~id:"showcase-date-long"
      ~label:"With the month spelled out"
      ~format:Date_input.Date_long
      ~value:(Bonsai.return (Some (Plain_date.create ~year:2026 ~month:3 ~day:21)))
      ~on_change
      graph
  in
  let disabled =
    Date_input.view
      ~id:"showcase-date-disabled"
      ~label:"Disabled"
      ~is_disabled:true
      ~disabled_message:"Dates are not available for this account"
      ~on_change
      graph
  in
  let bounded =
    Date_input.view
      ~id:"showcase-date-bounded"
      ~label:"From the tenth onwards"
      ~min:(Plain_date.create ~year:2026 ~month:3 ~day:10)
      ~on_change
      graph
  in
  join_all
    [ ex_tree "the field alone" plain
    ; ex_tree "with a committed date" with_value
    ; ex_tree "in the system form" system_date
    ; ex_tree "with the month spelled out" long_form
    ; ex_tree "disabled" disabled
    ; ex_tree "with a minimum date" bounded
    ]
  |> Bonsai.map ~f:(fun examples ->
         section
           ~id:"date-input"
           ~title:"DateInput"
           ~note:
             "A text field for a date, and a calendar to pick one from. The field owns the text being typed and the application owns the committed date. A date that can be read is committed as it is typed; text that cannot be read stays in the field until it is left, and the field falls back to what was committed."
           examples)
