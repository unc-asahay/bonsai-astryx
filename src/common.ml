(* Shared vocabulary for the port: spacing steps, size values, class names and
   the small CSS helpers the components share.

   Divergence from upstream, recorded deliberately: Astryx compiles StyleX to
   atomic CSS at build time. This port emits BEM-ish class names for structure
   and variants (so parity tests can compare them) and inline [style] attributes
   for the numeric props (gap, padding, width, height), which are per-instance
   values rather than reusable rules. The token *values* are the upstream ones —
   see src/tokens.ml and assets/tokens.css, both generated. *)

open! Core
open! Bonsai_web
open Js_of_ocaml

module Spacing = struct
  (* Astryx's numeric spacing scale: 0, 0.5, 1, 1.5, 2, 3, 4, 5, 6, 8, 10.
     Token names use a dash for the half step: --spacing-0-5. *)
  type t =
    | S0
    | S0_5
    | S1
    | S1_5
    | S2
    | S3
    | S4
    | S5
    | S6
    | S8
    | S10
  [@@deriving sexp_of]

  let step = function
    | S0 -> "0"
    | S0_5 -> "0-5"
    | S1 -> "1"
    | S1_5 -> "1-5"
    | S2 -> "2"
    | S3 -> "3"
    | S4 -> "4"
    | S5 -> "5"
    | S6 -> "6"
    | S8 -> "8"
    | S10 -> "10"
  ;;

  let var t = sprintf "var(--spacing-%s)" (step t)

  let all = [ S0; S0_5; S1; S1_5; S2; S3; S4; S5; S6; S8; S10 ]
end

(* Which state a form treats as its default. Upstream declares this in FormLayout.tsx and passes it
   down through React context; the port puts the value here, next to the other shared value types,
   because the controls and the layout both need it and neither should own the other. *)
(* Generic property reads on a JS object. A DOM event's fields are untyped from OCaml's side, and a
   missing one has to come back as a value rather than raising — so these are the only places that
   reach for [Js.Unsafe.get]. *)
let prop (obj : 'a Js.t) (name : string) = Js.Unsafe.get obj name

(* Generic DOM helpers live here rather than in whichever component needed them first: the second
   copy is how two components drift. *)
let prevent_default (obj : 'a Js.t) = ignore (Js.Unsafe.meth_call obj "preventDefault" [||])

let string_prop (obj : 'a Js.t) (name : string) : string option =
  Option.map (Js.Opt.to_option (prop obj name : Js.js_string Js.t Js.opt)) ~f:Js.to_string
;;

let bool_prop (obj : 'a Js.t) (name : string) : bool = Js.to_bool (prop obj name)

module Optionality = struct
  type t =
    | Optional
    | Required
end

module Size_value = struct
  (* Astryx: numbers are pixels, strings are used as-is. *)
  type t =
    | Px of int
    | Css of string

  let to_css = function
    | Px n -> sprintf "%dpx" n
    | Css s -> s
  ;;
end

(* Shared by Stack, Text and Heading. Astryx types these as one union whose legal
   values differ per axis: the main axis takes start|center|end|between|around|
   evenly, the cross axis takes start|center|end|stretch. Values that are illegal
   for the axis they land on fall back to that axis's neutral value. *)
module Alignment = struct
  type t =
    | Start
    | Center
    | End
    | Stretch
    | Between
    | Around
    | Evenly

  let to_string = function
    | Start -> "start"
    | Center -> "center"
    | End -> "end"
    | Stretch -> "stretch"
    | Between -> "between"
    | Around -> "around"
    | Evenly -> "evenly"
  ;;

  (* Cross axis: start | center | end | stretch. *)
  let cross_class = function
    | Start | Between -> "astryx-align--start"
    | Center | Around -> "astryx-align--center"
    | End | Evenly -> "astryx-align--end"
    | Stretch -> "astryx-align--stretch"
  ;;

  (* Main axis: start | center | end | between | around | evenly. *)
  let main_class = function
    | Start -> "astryx-justify--start"
    | Center -> "astryx-justify--center"
    | End -> "astryx-justify--end"
    | Between -> "astryx-justify--between"
    | Around -> "astryx-justify--around"
    | Evenly -> "astryx-justify--evenly"
    | Stretch -> "astryx-justify--start"
  ;;

  (* Text justification accepts only the cross-axis subset. *)
  let text_justify_class = function
    | Start -> "astryx-text--justify-start"
    | Center -> "astryx-text--justify-center"
    | End -> "astryx-text--justify-end"
    | Stretch | Between | Around | Evenly -> ""
  ;;
end

module Css = struct
  let of_pairs pairs = String.concat ~sep:"; " (List.map pairs ~f:(fun (k, v) -> sprintf "%s: %s" k v))
end

module Attr = struct
  let class_list classes = String.concat ~sep:" " (List.filter classes ~f:(Fn.non String.is_empty))

  (* [style] with empty pairs omitted, so an unstyled element carries no attribute. *)
  let style pairs =
    let pairs = List.filter pairs ~f:(fun (_, v) -> not (String.is_empty v)) in
    match pairs with
    | [] -> []
    | _ -> [ Vdom.Attr.create "style" (Css.of_pairs pairs) ]
  ;;

  let class_ classes =
    let s = class_list classes in
    if String.is_empty s then [] else [ Vdom.Attr.class_ s ]
  ;;

  let aria name value = [ Vdom.Attr.create (sprintf "aria-%s" name) value ]
  let aria_opt name = function Some v -> aria name v | None -> []
  let role r = [ Vdom.Attr.create "role" r ]

  (* data-* attributes are how the parity harness reads an element's intent, so
     every ported component states its own name and the props it received. *)
  let data name value = [ Vdom.Attr.create (sprintf "data-astryx-%s" name) value ]
end

(* A vdom hook is the only way to do DOM work that is not triggered by an event. Two things had
   been blamed on their absence — "there is no timer that can write back into the graph", and the
   overlay pillar's need to call showModal()/close() when a *value* changes — and both are wrong:
   Vdom.Attr.create_hook exists, Hooks.Make builds one, and a hook's input can carry a
   [unit Ui_effect.t] that Effect.Expert runs. The focus hooks in virtual_dom's own attr.ml are the
   worked example this follows. *)

let timeout (f : unit -> unit) (delay_ms : float) : Js.Unsafe.any =
  Js.Unsafe.meth_call
    Dom_html.window
    "setTimeout"
    (* Order matters: setTimeout takes (callback, delay). Passing the delay first is silently a
       no-op — the browser coerces it and never calls anything, which is exactly how this looked
       for one debugging round. *)
    [| Js.Unsafe.inject (Js.wrap_callback f); Js.Unsafe.inject (Js.number_of_float delay_ms) |]
;;

let clear_timeout (id : Js.Unsafe.any) : unit =
  ignore (Js.Unsafe.meth_call Dom_html.window "clearTimeout" [| Js.Unsafe.inject id |])
;;

(* Fires its effect once, [delay_ms] after the node it is attached to appears. Cancelled if the node
   is destroyed first, and restarted if the input changes — which is what a hover delay needs: the
   pointer leaving before the delay elapses must cancel the timer, not race it. *)
module Delay_hook = struct
  module T = struct
    module State = struct
      type t = { mutable id : Js.Unsafe.any option }

      let create () = { id = None }
    end

    module Input = struct
      type t =
        { (* [None] cancels: an input change is how a caller says "never mind", which is what a
             pointer leaving before the delay elapses has to say. *)
          delay_ms : float option
        ; on_elapsed : (unit Effect.t[@sexp.opaque])
        }

      (* Written by hand: this project's ppx list has no sexp deriver, and the interface wants one
         (an effect cannot be printed, so only the delay is worth showing). *)
      let sexp_of_t { delay_ms; _ } =
        Sexp.Atom (Option.value_map delay_ms ~default:"cancelled" ~f:Float.to_string)
      ;;

      let combine left right =
        { left with on_elapsed = Effect.Many [ left.on_elapsed; right.on_elapsed ] }
      ;;
    end

    let init _ _ = State.create ()
    let cancel state = Option.iter state.State.id ~f:clear_timeout

    let start state (input : Input.t) =
      cancel state;
      match input.delay_ms with
      | None -> ()
      | Some delay_ms ->
        state.id
          <- Some
               (timeout
                  (fun () ->
                    state.id <- None;
                    Effect.Expert.handle_non_dom_event_exn input.on_elapsed)
                  delay_ms)
    ;;

    let on_mount input state _ = start state input
    let on_mount = `Schedule_immediately_after_this_dom_patch_completes on_mount
    let update ~old_input:_ ~new_input state _ = start state new_input
    let destroy _ state _ = cancel state
  end

  (* The hook API is re-exported under Vdom.Attr; bonsai_web_components' own element-size hooks
     build theirs the same way. *)
  module Hook = Vdom.Attr.Hooks.Make (T)

  let attr ~delay_ms ~on_elapsed =
    Vdom.Attr.create_hook "astryx-delay" (Hook.create { T.Input.delay_ms; on_elapsed })
  ;;

  let cancel = attr ~delay_ms:None ~on_elapsed:Effect.Ignore
end
