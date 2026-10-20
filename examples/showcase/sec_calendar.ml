(* Calendar — the showcase section: the month grid in the states it supports.

   Every example drives the component through its public API only, so the
   section is also the proof that the API is usable from outside the
   library. The picked value is held here, not inside the component, so the
   readouts show what the component reported. *)

open! Core
open! Bonsai_web

module Calendar = Astryx.Calendar
module Plain_date = Astryx.Plain_date

open Prelude

let demo (graph : Bonsai.graph) : Vdom.Node.t Bonsai.t =
  let ex_tree label tree = Bonsai.map tree ~f:(fun node -> ex label node) in
  (* A value the section owns, and the callback the component reports to. *)
  let single, set_single = Bonsai.state' (None : Calendar.selection option) graph in
  let single_value = Bonsai.map single ~f:(fun value -> value) in
  let single_on_change =
    Bonsai.map set_single ~f:(fun set -> fun (selection : Calendar.selection) -> set (fun _ -> Some selection))
  in
  let single_readout =
    Bonsai.map single ~f:(fun selection ->
        Vdom.Node.div
          ~attrs:[ Vdom.Attr.create "id" "showcase-calendar-single-readout" ]
          [ Vdom.Node.text
              (match selection with
               | Some (Calendar.Single_date d) -> "picked " ^ Plain_date.to_iso d
               | Some (Calendar.Date_range r) ->
                 "picked " ^ Plain_date.to_iso r.start_date ^ " to " ^ Plain_date.to_iso r.end_date
               | None -> "nothing picked yet") ])
  in
  let single_calendar =
    Calendar.view ~id:"showcase-calendar-single" ~value:single_value ~on_change:single_on_change graph
  in
  (* A range, picked in two clicks. *)
  let range, set_range = Bonsai.state' (None : Calendar.selection option) graph in
  let range_value = Bonsai.map range ~f:(fun value -> value) in
  let range_on_change =
    Bonsai.map set_range ~f:(fun set -> fun (selection : Calendar.selection) -> set (fun _ -> Some selection))
  in
  let range_readout =
    Bonsai.map range ~f:(fun selection ->
        Vdom.Node.div
          ~attrs:[ Vdom.Attr.create "id" "showcase-calendar-range-readout" ]
          [ Vdom.Node.text
              (match selection with
               | Some (Calendar.Date_range r) ->
                 "picked " ^ Plain_date.to_iso r.start_date ^ " to " ^ Plain_date.to_iso r.end_date
               | Some (Calendar.Single_date d) -> "picked " ^ Plain_date.to_iso d
               | None -> "pick a start day, then an end day") ])
  in
  let range_calendar =
    Calendar.view
      ~id:"showcase-calendar-range"
      ~mode:Calendar.Range
      ~value:range_value
      ~on_change:range_on_change
      graph
  in
  (* Uncontrolled, seeded with a value, and bounded by a window. *)
  let bounded_calendar =
    Calendar.view
      ~id:"showcase-calendar-bounded"
      ~default_value:(Some (Calendar.Single_date (Plain_date.create ~year:2026 ~month:3 ~day:15)))
      ~min:(Plain_date.create ~year:2026 ~month:3 ~day:1)
      ~max:(Plain_date.create ~year:2026 ~month:4 ~day:30)
      graph
  in
  (* Only weekdays can be picked. *)
  let weekday_calendar =
    Calendar.view
      ~id:"showcase-calendar-weekdays"
      ~date_constraints:[ (fun d ->
          let day = Plain_date.day_of_week d in
          day <> 0 && day <> 6) ]
      graph
  in
  (* Two months side by side. *)
  let two_months_calendar = Calendar.view ~id:"showcase-calendar-two-months" ~number_of_months:2 graph in
  let examples =
    [ ex_tree "single: pick a day" single_calendar
    ; ex_tree "single: the day the component reported" single_readout
    ; ex_tree "range: pick a start, then an end" range_calendar
    ; ex_tree "range: the range the component reported" range_readout
    ; ex_tree "bounded: a window of selectable days" bounded_calendar
    ; ex_tree "constrained: weekdays only" weekday_calendar
    ; ex_tree "two months at once" two_months_calendar
    ]
  in
  Bonsai.map (unwrap_all examples) ~f:(fun examples ->
      section
        ~id:"calendar"
        ~title:"Calendar"
        ~note:
          "The month grid a person picks a date (or a date range) with. It is one composite \
           widget: the grid holds a single Tab stop, the arrow keys walk the days, PageUp and \
           PageDown page by month, and Home and End jump to the ends of the week row. In range \
           mode the first pick starts the range, the pointer previews its end, and the second \
           pick commits it. The live region announces the month that just came into view and \
           the progress of a range."
        examples)
;;
