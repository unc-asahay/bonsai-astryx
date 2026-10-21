(* TimeInput — the typed time field.

   The field owns the text being typed; the application owns the committed
   time. A time that can be read is committed as it is typed. Text that
   cannot be read is kept in the field while it is typed, and the field
   falls back to the committed time when it is left or Enter is pressed.

   The examples below show the field alone, a committed time, the
   twenty-four hour clock, seconds, the field disabled with a reason, and
   the field bounded by a minimum and a maximum. *)

open! Core
open! Bonsai_web

module Time_input = Astryx.Time_input

open Prelude

let ex_tree label tree = Bonsai.map tree ~f:(fun node -> ex label node)

let join_all (trees : Vdom.Node.t Bonsai.t list) =
  List.fold trees ~init:(Bonsai.return []) ~f:(fun acc tree ->
    Bonsai.both acc tree |> Bonsai.map ~f:(fun (acc, tree) -> tree :: acc))
  |> Bonsai.map ~f:List.rev
;;

let demo (graph : Bonsai.graph) : Vdom.Node.t Bonsai.t =
  (* A time the section owns, and the callback the component reports to. *)
  let committed, set_committed = Bonsai.state' (None : Time_input.time option) graph in
  let on_change =
    Bonsai.map set_committed ~f:(fun set_committed -> fun value -> set_committed (fun _ -> value))
  in
  let readout =
    Bonsai.map committed ~f:(fun value ->
        Vdom.Node.div
          ~attrs:[ Vdom.Attr.create "id" "showcase-time-readout" ]
          [ Vdom.Node.text
              (match value with
               | Some t -> "committed " ^ Time_input.to_iso t
               | None -> "nothing committed yet") ])
  in
  let plain =
    Time_input.view
      ~id:"showcase-time-plain"
      ~label:"Time"
      ~value:committed
      ~on_change
      graph
  in
  let with_value =
    Time_input.view
      ~id:"showcase-time-value"
      ~label:"Time"
      ~value:(Bonsai.return (Time_input.of_iso "14:30"))
      graph
  in
  let twenty_four =
    Time_input.view
      ~id:"showcase-time-24"
      ~label:"Time"
      ~hour_format:Time_input.H24
      ~value:(Bonsai.return (Time_input.of_iso "14:30"))
      graph
  in
  let with_seconds =
    Time_input.view
      ~id:"showcase-time-seconds"
      ~label:"Time"
      ~has_seconds:true
      ~value:(Bonsai.return (Time_input.of_iso "14:30:45"))
      graph
  in
  let disabled =
    Time_input.view
      ~id:"showcase-time-disabled"
      ~label:"Time"
      ~is_disabled:true
      ~disabled_message:"Times are set by the scheduler"
      ~value:(Bonsai.return (Time_input.of_iso "09:00"))
      graph
  in
  let bounded =
    Time_input.view
      ~id:"showcase-time-bounded"
      ~label:"Time"
      ~min:(Option.value_exn (Time_input.of_iso "09:00"))
      ~max:(Option.value_exn (Time_input.of_iso "17:00"))
      ~value:(Bonsai.return (Time_input.of_iso "12:00"))
      graph
  in
  join_all
    [ ex_tree "the field" plain
    ; ex_tree "a committed time" (Bonsai.map2 plain readout ~f:(fun field readout ->
        Vdom.Node.div ~attrs:[ Vdom.Attr.class_ "showcase-col" ] [ field; readout ]))
    ; ex_tree "a time already set" with_value
    ; ex_tree "a time on a twenty-four hour clock" twenty_four
    ; ex_tree "with seconds" with_seconds
    ; ex_tree "disabled, with a reason" disabled
    ; ex_tree "bounded between nine in the morning and five in the evening" bounded
    ]
  |> Bonsai.map ~f:(fun examples ->
         section
           ~id:"time-input"
           ~title:"TimeInput"
           ~note:
             "A text field for a time. The field owns the text being typed and the application owns the committed time. A time that can be read is committed as it is typed; text that cannot be read stays in the field until it is left, and the field falls back to what was committed."
           examples)
;;
