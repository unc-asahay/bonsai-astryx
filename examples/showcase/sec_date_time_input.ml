(* DateTimeInput — a date field, a time field, and a calendar to pick the date
   from.

   The field owns the draft text of the date and of the time, and whether
   the calendar is open; the application owns the committed reading. The
   reading has no zone and no offset: it is a calendar date and a time of
   day, which is the same information upstream's ISO string carries.

   The examples below show the field alone, a committed reading, the
   twenty-four hour clock, disabled, and the field with seconds. *)

open! Core
open! Bonsai_web

module Date_time_input = Astryx.Date_time_input
module Plain_date = Astryx.Plain_date

open Prelude

let ex_tree label tree = Bonsai.map tree ~f:(fun node -> ex label node)

let join_all (trees : Vdom.Node.t Bonsai.t list) =
  List.fold trees ~init:(Bonsai.return []) ~f:(fun acc tree ->
    Bonsai.both acc tree |> Bonsai.map ~f:(fun (acc, tree) -> tree :: acc))
  |> Bonsai.map ~f:List.rev
;;

let demo (graph : Bonsai.graph) : Vdom.Node.t Bonsai.t =
  let committed, set_committed = Bonsai.state' (None : Date_time_input.date_time option) graph in
  let on_change =
    Bonsai.map set_committed ~f:(fun set_committed -> fun value -> set_committed (fun _ -> value))
  in
  let plain =
    Date_time_input.view
      ~id:"showcase-date-time-plain"
      ~label:"Date and time"
      ~value:committed
      ~on_change
      graph
  in
  let with_value =
    Date_time_input.view
      ~id:"showcase-date-time-value"
      ~label:"A committed reading"
      ~value:
        (Bonsai.return
           (Some
              { Date_time_input.date = Plain_date.create ~year:2026 ~month:3 ~day:18
              ; time = { Date_time_input.hour = 14; minute = 30; second = 0 }
              }))
      ~on_change
      graph
  in
  let twenty_four_hour =
    Date_time_input.view
      ~id:"showcase-date-time-24h"
      ~label:"On the twenty-four hour clock"
      ~hour_format:Date_time_input.H24
      ~value:
        (Bonsai.return
           (Some
              { Date_time_input.date = Plain_date.create ~year:2026 ~month:3 ~day:18
              ; time = { Date_time_input.hour = 14; minute = 30; second = 0 }
              }))
      ~on_change
      graph
  in
  let disabled =
    Date_time_input.view
      ~id:"showcase-date-time-disabled"
      ~label:"Disabled"
      ~is_disabled:true
      ~disabled_message:"Readings are not available for this account"
      ~on_change
      graph
  in
  let with_seconds =
    Date_time_input.view
      ~id:"showcase-date-time-seconds"
      ~label:"With seconds"
      ~has_seconds:true
      ~on_change
      graph
  in
  join_all
    [ ex_tree "the field alone" plain
    ; ex_tree "with a committed reading" with_value
    ; ex_tree "on the twenty-four hour clock" twenty_four_hour
    ; ex_tree "disabled" disabled
    ; ex_tree "with seconds" with_seconds
    ]
  |> Bonsai.map ~f:(fun examples ->
         section
           ~id:"date-time-input"
           ~title:"DateTimeInput"
           ~note:
             "A date, a time, and a calendar to pick the date from. The field owns the draft text of each part and whether the calendar is open; the application owns the committed reading. The reading carries no zone and no offset."
           examples)
