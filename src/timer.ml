open! Core
open! Bonsai_web
open Js_of_ocaml

type format =
  | Elapsed
  | Clock

type presentation =
  { datetime : string
  ; text : string
  }

let one_second_ms = 1000
let one_minute_ms = 60 * one_second_ms
let one_hour_seconds = 60 * 60
let max_timeout_ms = 2_147_483_647

(* Two digits, like upstream's padStart(2, '0'). Hours are left unpadded on purpose, in both formats. *)
let pad (value : int) = String.pad_left (Int.to_string value) ~len:2 ~char:'0'

let presentation ~format ~elapsed_ms =
  (* Math.floor of a non-negative value is integer division here: elapsed is clamped at zero below. *)
  let elapsed_seconds = elapsed_ms / one_second_ms in
  match (format : format) with
  | Clock ->
    let hours = elapsed_seconds / one_hour_seconds in
    let minutes = elapsed_seconds % one_hour_seconds / 60 in
    let seconds = elapsed_seconds % 60 in
    { datetime = sprintf "PT%dS" elapsed_seconds
    ; text =
        (if hours > 0
         then sprintf "%d:%s:%s" hours (pad minutes) (pad seconds)
         else sprintf "%d:%s" minutes (pad seconds))
    }
  | Elapsed ->
    if elapsed_seconds < 60
    then { datetime = sprintf "PT%dS" elapsed_seconds; text = sprintf "%ds" elapsed_seconds }
    else (
      let total_minutes = elapsed_seconds / 60 in
      if total_minutes < 60
      then
        { datetime = sprintf "PT%dS" elapsed_seconds
        ; text = sprintf "%dm %ss" total_minutes (pad (elapsed_seconds % 60))
        }
      else (
        (* The duration follows the text: this reading has dropped seconds, so the duration it stands for
           is the truncated one rather than the raw elapsed time. *)
        let represented_seconds = total_minutes * 60 in
        { datetime = sprintf "PT%dS" represented_seconds
        ; text = sprintf "%dh %sm" (total_minutes / 60) (pad (total_minutes % 60))
        }))
;;

let milliseconds_until_next_change ~format ~now_ms ~start_time_ms ~elapsed_ms =
  if Float.( < ) now_ms start_time_ms
  then Int.min (Float.to_int (start_time_ms -. now_ms) + one_second_ms) max_timeout_ms
  else (
    (* Past an hour the elapsed reading only moves once a minute, so the wait is computed against the
       precision the reading actually has. *)
    let precision =
      match (format : format) with
      | Elapsed when elapsed_ms >= one_hour_seconds * one_second_ms -> one_minute_ms
      | Elapsed | Clock -> one_second_ms
    in
    precision - (elapsed_ms % precision))
;;

(* --------------------------------------------------------------------------------------------- *)
(* The clock, which owns the node                                                                 *)
(* --------------------------------------------------------------------------------------------- *)
(* The update is written straight to the <time> element: no state, no re-render. A component that
   re-rendered once a second would re-render everything above it once a second.

   The start time is resolved once, on mount, and kept — upstream's useState(() => Date.now()) — so a
   caller who supplies one gets it honoured and a caller who does not gets a clock that does not drift
   every time the application happens to re-render. *)

module Tick_hook = struct
  module T = struct
    module State = struct
      type t =
        { mutable timeout : Js.Unsafe.any option
        ; mutable resolved_start : float option
        ; mutable written_text : string
        ; mutable written_datetime : string
        }

      let create () =
        { timeout = None; resolved_start = None; written_text = ""; written_datetime = "" }
      ;;
    end

    module Input = struct
      type t =
        { start_time : float option
        ; format : format
        }

      let sexp_of_t { start_time; format } =
        Sexp.List
          [ Sexp.Atom (Option.value_map start_time ~default:"mount" ~f:Float.to_string)
          ; Sexp.Atom
              (match format with
               | Elapsed -> "elapsed"
               | Clock -> "clock")
          ]
      ;;

      let combine left _ = left
    end

(* Js.Date is not in this trimmed Js_of_ocaml, and the ## ppx is not enabled here — so the clock is
       read through the same eval'd-JS idiom the port's other DOM helpers use. *)
    let now_ms () : float = Js.Unsafe.eval_string "Date.now()"

    let set_timeout (callback : unit -> unit) (ms : int) =
      Js.Unsafe.meth_call
        Dom_html.window
        "setTimeout"
        [| Js.Unsafe.inject (Js.wrap_callback callback)
         ; Js.Unsafe.inject (Js.float (Float.of_int ms))
        |]
    ;;

    let clear_timeout handle =
      ignore (Js.Unsafe.meth_call Dom_html.window "clearTimeout" [| Js.Unsafe.inject handle |])
    ;;

    let set_attr (el : Dom_html.element Js.t) (name : string) (value : string) =
      ignore
        (Js.Unsafe.meth_call
           el
           "setAttribute"
           [| Js.Unsafe.inject (Js.string name); Js.Unsafe.inject (Js.string value) |])
    ;;

    let start_of (state : State.t) (input : Input.t) =
      match state.resolved_start with
      | Some resolved -> resolved
      | None ->
        let resolved = Option.value input.start_time ~default:(now_ms ()) in
        state.resolved_start <- Some resolved;
        resolved
    ;;

    let rec tick (state : State.t) (input : Input.t) (el : Dom_html.element Js.t) =
      let start_time_ms = start_of state input in
      let now = now_ms () in
      (* Both are epoch floats; the *difference* is a small duration, so it fits an int comfortably. *)
      let elapsed_ms = Int.max 0 (Float.to_int (now -. start_time_ms)) in
      let reading = presentation ~format:input.format ~elapsed_ms in
      (* Written only when it changed. The values are remembered here rather than read back out of the
         DOM, so a re-render that re-mounts nothing cannot make the clock rewrite the same string. *)
      if not (String.equal reading.text state.written_text)
      then (
        Js.Unsafe.set el "textContent" (Js.string reading.text);
        state.written_text <- reading.text);
      if not (String.equal reading.datetime state.written_datetime)
      then (
        set_attr el "datetime" reading.datetime;
        state.written_datetime <- reading.datetime);
      Option.iter state.timeout ~f:clear_timeout;
      state.timeout
      <- Some
           (set_timeout
              (fun () -> tick state input el)
              (milliseconds_until_next_change
                 ~format:input.format
                 ~now_ms:now
                 ~start_time_ms
                 ~elapsed_ms))
    ;;

    let init _ _ = State.create ()
    let on_mount input state el = tick state input el
    let on_mount = `Schedule_immediately_after_this_dom_patch_completes on_mount

    let update ~(old_input : Input.t) ~(new_input : Input.t) (state : State.t) el =
      (* A changed start time or format means the caller meant something different, so the resolution is
         dropped and the clock starts again from what they asked for. *)
      let same_format =
        match old_input.format, new_input.format with
        | Elapsed, Elapsed | Clock, Clock -> true
        | Elapsed, Clock | Clock, Elapsed -> false
      in
      if not (Option.equal Float.equal old_input.start_time new_input.start_time && same_format)
      then (
        state.resolved_start <- None;
        state.written_text <- "";
        state.written_datetime <- "");
      tick state new_input el
    ;;

    let destroy _ (state : State.t) _ =
      Option.iter state.timeout ~f:clear_timeout;
      state.timeout <- None
    ;;
  end

  module Hook = Vdom.Attr.Hooks.Make (T)

  let attr ~start_time ~format () =
    Vdom.Attr.create_hook
      "astryx-timer"
      (Hook.create { T.Input.start_time; format })
  ;;
end

(* --------------------------------------------------------------------------------------------- *)
(* The component                                                                                  *)
(* --------------------------------------------------------------------------------------------- *)

let view
  ?(attrs = [])
  ?start_time
  ?(format = Elapsed)
  ?(type_ = Text.Supporting)
  ?size
  ?(color = Text.Secondary)
  ?weight
  ()
  =
  (* The first painted reading is zero, as upstream's is; the hook corrects it on mount, immediately. *)
  let initial = presentation ~format ~elapsed_ms:0 in
  Text.view
    ~type_
    ?size
    ~color
    ?weight
    (* The digits line up as they change: a timer whose numbers jitter is a timer you cannot read. *)
    ~has_tabular_numbers:true
    [ Vdom.Node.create
        "time"
        ~attrs:
          ([ Vdom.Attr.create "datetime" initial.datetime
           ; Tick_hook.attr ~start_time ~format ()
           ]
           @ Common.Attr.data "component" "Timer"
           @ attrs)
        [ Vdom.Node.text initial.text ]
    ]
;;
