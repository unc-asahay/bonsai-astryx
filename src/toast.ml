(* Copyright (c) Meta Platforms, Inc. and affiliates.

   Ported to OCaml/Bonsai from the astryx Toast component: Toast.tsx,
   ToastViewport.tsx, types.ts, useToast.tsx and useToastGesture.ts.

   The system has three parts, and the port keeps the three:

     - the *card* ({!view}): one notification - its live region, its body, its
       trailing slot, its dismiss control, its auto-hide timer and the
       swipe-to-dismiss gesture;
     - the *viewport* ({!viewport}): the fixed stack the cards live in - the
       placement, the visible limit, the enter/exit choreography, the
       announcement and the F6 focus jump;
     - the *list* ({!options}, {!entry}, {!add}): the toasts themselves, which
       the *application* owns.

   That last point is the port's one structural change, and it is forced by
   the runtime: upstream's useToast() keeps the list inside the viewport's
   React context, and a React context can hold a list that grows while the
   component is mounted. A Bonsai graph cannot - its shape is fixed when the
   graph is built - so the application holds the list and hands it to the
   viewport as a value. The viewport therefore *receives* toasts rather than
   owning them, and it tells the application when a toast should leave the
   list. See the .mli for the whole contract. *)

open! Core
open! Bonsai_web
open Js_of_ocaml

module Attr = Common.Attr

(* ------------------------------------------------------------------ the types *)

type type_ =
  | Info
  | Error
(** The toast's status. Upstream's [ToastType]: it picks the surface colour
    and, for [Error], the assertive live region. *)

type position =
  | Top_end
  | Top_start
  | Bottom_end
  | Bottom_start
(** Where the stack sits. Upstream's [ToastPosition], and a *logical* one:
    "start" is the left in a left-to-right document and the right in a
    right-to-left one. *)

type dismiss_reason =
  | Auto
  | Manual
(** Why a toast went away. Upstream's [ToastDismissReason]. *)

type collision_behavior =
  | Overwrite
  | Ignore
(** What happens when a toast arrives with a [unique_id] that is already in the
    list. Upstream's [ToastCollisionBehavior]. *)

type options =
  { body : Vdom.Node.t
  ; type_ : type_
  ; is_auto_hide : bool
  ; auto_hide_duration : float
  ; end_content : Vdom.Node.t option
  ; unique_id : string option
  ; collision_behavior : collision_behavior
  ; on_hide : (dismiss_reason -> unit Effect.t) option
  }
(** One toast's settings. Upstream's [ToastOptions]. *)

type entry =
  { id : string
  ; options : options
  }
(** One toast in the list: its identity plus its settings. Upstream's
    [ToastEntry] (whose [createdAt] the port does not need - nothing in the
    ported behaviour reads the clock). *)

type content =
  { body : Vdom.Node.t
  ; end_content : Vdom.Node.t option
  ; type_ : type_
  ; is_auto_hide : bool
  ; auto_hide_duration : float
  ; dismiss : (unit -> unit Effect.t)
  }
(** What a custom renderer is handed. Upstream's [ToastContentRenderProps]:
    the toast's own content and settings, plus the [dismiss] callback the
    renderer wires to whichever control should close the toast. *)

(* ------------------------------------------------------------------ defaults *)

let default_auto_hide_duration = 5000.
let default_max_visible = 5
let default_dismiss_label = "Dismiss notification"
let default_viewport_label = "Notifications"
let default_card_id = "astryx-toast"
let default_viewport_id = "astryx-toast-viewport"

(* Upstream's default is per type: an info toast is transient, an error toast
   is not. [ToastOptions.isAutoHide] says exactly that in its own comment. *)
let default_is_auto_hide = function Info -> true | Error -> false

let options
    ?(body = Vdom.Node.none)
    ?(type_ = Info)
    ?is_auto_hide
    ?(auto_hide_duration = default_auto_hide_duration)
    ?end_content
    ?unique_id
    ?(collision_behavior = Overwrite)
    ?on_hide
    ()
  =
  { body
  ; type_
  ; is_auto_hide = Option.value is_auto_hide ~default:(default_is_auto_hide type_)
  ; auto_hide_duration
  ; end_content
  ; unique_id
  ; collision_behavior
  ; on_hide
  }
;;  (* Upstream's [ToastOptions]; every field has upstream's default. *)

let next_id = ref 0

let fresh_id () =
  incr next_id;
  sprintf "astryx-toast-%d" !next_id
;;

let entry ?id options = { id = Option.value id ~default:(fresh_id ()); options }
;;  (* One toast, with an identity. The id is what the viewport's rows are
       keyed by and what a dismissal names. *)

let type_name = function Info -> "info" | Error -> "error"
let position_name = function Top_end -> "top-end" | Top_start -> "top-start" | Bottom_end -> "bottom-end" | Bottom_start -> "bottom-start"
let reason_name = function Auto -> "auto" | Manual -> "manual"

(* ------------------------------------------------------------------- the list *)

let has_unique_id (entry : entry) (uid : string) =
  Option.equal String.equal entry.options.unique_id (Some uid)
;;

(* Upstream's addToast: a toast without a unique id is simply appended; a toast
   with one either replaces the toast already holding that id (overwrite, in
   place - the new entry takes the old one's seat in the stack) or is dropped
   (ignore). *)
let add (toasts : entry list) (entry : entry) : entry list =
  match entry.options.unique_id with
  | None -> toasts @ [ entry ]
  | Some uid ->
    let exists = List.exists toasts ~f:(fun t -> has_unique_id t uid) in
    if not exists
    then toasts @ [ entry ]
    else
      match entry.options.collision_behavior with
      | Ignore -> toasts
      | Overwrite ->
        List.map toasts ~f:(fun t -> if has_unique_id t uid then entry else t)
;;

let remove (toasts : entry list) (id : string) : entry list =
  List.filter toasts ~f:(fun t -> not (String.equal t.id id))
;;  (* The other half of upstream's removeToast: the toast leaves the list. *)

(* ------------------------------------------------------------------- the DOM *)

type el = Dom_html.element Js.t

type listener_target =
  | Element
  | Window

let js_string s = Js.Unsafe.inject (Js.string s)
let js_number f = Js.Unsafe.inject (Js.number_of_float f)

(* The host helpers. The clock is read per call - a constant would freeze
   the toast's timer at the moment the module loaded - and the measurement
   helper is a function the port calls with the element. *)
let height_js =
  Js.Unsafe.pure_js_expr
    "(function (el) { var r = el.getBoundingClientRect(); return r ? r.height : 0; })"
;;

let now_ms () : float = Js.to_float (Js.Unsafe.coerce (Js.Unsafe.eval_string "Date.now()"))

let add_listener (el : el) (kind : string) (listener : Js.Unsafe.any) =
  ignore
    (Js.Unsafe.meth_call
       el
       "addEventListener"
       [| Js.Unsafe.inject (Js.string kind); Js.Unsafe.inject listener |])
;;

let remove_listener (el : el) (kind : string) (listener : Js.Unsafe.any) =
  ignore
    (Js.Unsafe.meth_call
       el
       "removeEventListener"
       [| Js.Unsafe.inject (Js.string kind); Js.Unsafe.inject listener |])
;;

let set_property (el : el) (name : string) (value : string) =
  ignore
    (Js.Unsafe.meth_call
       el
       "setProperty"
       [| Js.Unsafe.inject (Js.string name); Js.Unsafe.inject (Js.string value) |])
;;

let remove_property (el : el) (name : string) =
  ignore (Js.Unsafe.meth_call el "removeProperty" [| Js.Unsafe.inject (Js.string name) |])
;;

let style_of (el : el) = Js.Unsafe.get el "style"

let set_style (el : el) (name : string) (value : string) =
  ignore
    (Js.Unsafe.meth_call
       (style_of el)
       "setProperty"
       [| Js.Unsafe.inject (Js.string name); Js.Unsafe.inject (Js.string value) |])
;;

let remove_style (el : el) (name : string) =
  ignore
    (Js.Unsafe.meth_call
       (style_of el)
       "removeProperty"
       [| Js.Unsafe.inject (Js.string name) |])
;;

let rec last = function
  | [] -> None
  | [ x ] -> Some x
  | _ :: rest -> last rest
;;

let el_prop (obj : 'a Js.t) (name : string) : el option =
  Js.Opt.to_option (Common.prop obj name : el Js.opt)
;;

let attribute (el : el) (name : string) : string option =
  match
    Js.Opt.to_option (Js.Unsafe.meth_call el "getAttribute" [| js_string name |])
  with
  | None -> None
  | Some value -> Some (Js.to_string (Js.Unsafe.coerce value))
;;

let query_selector (el : el) (selector : string) : el option =
  Js.Opt.to_option
    (Js.Unsafe.meth_call el "querySelector" [| js_string selector |])
;;

let query_all (el : el) (selector : string) : el list =
  let found =
    Js.Unsafe.meth_call el "querySelectorAll" [| js_string selector |]
  in
  Dom.list_of_nodeList (Js.Unsafe.coerce found) |> List.map ~f:Js.Unsafe.coerce
;;

let text_content (el : el) : string =
  Js.to_string (Js.Unsafe.coerce (Js.Unsafe.get el "textContent"))
;;

let height_of (el : el) : float = Js.Unsafe.fun_call height_js [| Js.Unsafe.inject el |]

let focus (el : el) = ignore (Js.Unsafe.meth_call el "focus" [||])

let is_connected (el : el) : bool = Js.to_bool (Js.Unsafe.get el "isConnected")

let active_element () : el option =
  let document = Js.Unsafe.pure_js_expr "document" in
  el_prop document "activeElement"
;;

(* ------------------------------------------------------- the card's behaviours *)

(* Upstream's useToastGesture, with the timer it shares.

   The constants are upstream's: the slop a drag has to clear before it is a
   drag at all, the fraction of the card's height that dismisses it, the
   distance and speed a flick has to reach, and how far the card is allowed to
   drift from its resting place. *)
let drag_promotion_slop = 8.
let swipe_dismiss_ratio = 0.4
let flick_min_distance = 48.
let flick_velocity = 1.2
let vertical_intent_ratio = 1.2
let swipe_exit_distance = "120%"
let swipe_active_fade_max = 0.4
let swipe_active_scale_max = 0.02

(* Upstream keeps at least a second on the clock when a toast is paused, so a
   toast that is hovered for a long time still gets a moment to be read. *)
let min_remaining_ms = 1000.

type gesture_intent =
  | Pending
  | Vertical
  | Opposite

type gesture =
  { source : [ `Touch | `Pen ]
  ; pointer_id : int
  ; start_x : float
  ; start_y : float
  ; start_time : float
  ; direction : int
  ; mutable intent : gesture_intent
  ; paused_timer : bool
  ; surface_size : float
  ; dismiss_threshold : float
  }

(* The interactive targets a swipe must ignore. Upstream walks up from the
   event target and stops at the card, so a control inside the card (the
   dismiss button, a link in the trailing slot) keeps its own clicks. The
   selector list is the port's shared one, so "interactive" means the same
   thing here as everywhere else in the library. *)
let swipe_interactive_selector =
  Common.Clickable_container.interactive_selectors
  ^ ",[tabindex],[contenteditable]:not([contenteditable=\"false\"])"
;;

let is_interactive_target_js =
  Js.Unsafe.pure_js_expr
    "(function (target, root, selector) {\
     if (!target || !target.matches) return false;\
     var current = target;\
     while (current != null && current !== root && current !== document.body) {\
       if (current.matches(selector)) return true;\
       current = current.parentElement;\
     }\
     return false;\
     })"
;;

let is_interactive_target (target : el) (root : el) : bool =
  Js.Unsafe.fun_call
    is_interactive_target_js
    [| Js.Unsafe.inject target
     ; Js.Unsafe.inject root
     ; Js.Unsafe.inject (Js.string swipe_interactive_selector)
    |]
;;

module Surface_hook = struct
  module T = struct
    module State = struct
      type t =
        { mutable timer : Js.Unsafe.any option
        ; mutable remaining : float
        ; mutable started_at : float
        ; mutable is_paused : bool
        ; mutable gesture : gesture option
        ; mutable listeners : (listener_target * string * Js.Unsafe.any) list
        }

      let create () =
        { timer = None
        ; remaining = 0.
        ; started_at = 0.
        ; is_paused = false
        ; gesture = None
        ; listeners = []
        }
      ;;
    end

    module Input = struct
      type t =
        { auto_hide_duration : float
        ; is_auto_hide : bool
        ; gesture_direction : int
        ; is_gesture_enabled : bool
        ; (* The standalone card's dismissal relay: when this changes, the
             notification is run. The viewport's rows have no relay - the
             viewport itself carries the dismissal - so theirs is always
             [None]. *)
          request : dismiss_reason option
        ; on_request : unit Effect.t
        ; on_auto_dismiss : unit Effect.t
        ; on_manual_dismiss : unit Effect.t
        }

      (* The effects are deliberately not part of the identity: the timer must
         not restart because a re-render produced a new closure. What is part
         of the identity - the duration, whether the toast hides itself, which
         way the swipe goes, and the dismissal relay - changes when the
         behaviour changes, exactly as upstream's effect dependencies do. *)
      let sexp_of_t
          { auto_hide_duration; is_auto_hide; gesture_direction; is_gesture_enabled; request; _ }
        =
        Sexp.List
          [ Sexp.Atom (Float.to_string auto_hide_duration)
          ; Sexp.Atom (Bool.to_string is_auto_hide)
          ; Sexp.Atom (Int.to_string gesture_direction)
          ; Sexp.Atom (Bool.to_string is_gesture_enabled)
          ; Sexp.Atom
              (match request with
               | None -> "none"
               | Some reason -> reason_name reason)
          ]
      ;;

      let combine left right =
        { left with
          on_request = Effect.Many [ left.on_request; right.on_request ]
        ; on_auto_dismiss = Effect.Many [ left.on_auto_dismiss; right.on_auto_dismiss ]
        ; on_manual_dismiss = Effect.Many [ left.on_manual_dismiss; right.on_manual_dismiss ]
        }
      ;;
    end

    (* ---------------------------------------------------------------- the timer *)

    let set_timeout (f : unit -> unit) (ms : float) : Js.Unsafe.any =
      Js.Unsafe.meth_call
        Dom_html.window
        "setTimeout"
        [| Js.Unsafe.inject (Js.wrap_callback f); Js.Unsafe.inject (Js.number_of_float ms) |]
    ;;

    let clear_timeout (id : Js.Unsafe.any) : unit =
      ignore (Js.Unsafe.meth_call Dom_html.window "clearTimeout" [| Js.Unsafe.inject id |])
    ;;

    let cancel_timer (state : State.t) : unit =
      match state.timer with
      | Some id ->
        clear_timeout id;
        state.timer <- None
      | None -> ()
    ;;

    let arm (state : State.t) (input : Input.t) : unit =
      cancel_timer state;
      if input.is_auto_hide
      then (
        state.started_at <- now_ms ();
        state.timer
          <- Some
               (set_timeout
                  (fun () ->
                    state.timer <- None;
                    Effect.Expert.handle_non_dom_event_exn input.on_auto_dismiss)
                  state.remaining))
    ;;

    (* Upstream's pauseTimer: it stops the clock and remembers how much of it
       is left, never less than a second. *)
    let pause_timer (state : State.t) : unit =
      if not state.is_paused
      then (
        state.is_paused <- true;
        cancel_timer state;
        let elapsed = now_ms () -. state.started_at in
        state.remaining <- Float.max min_remaining_ms (state.remaining -. elapsed))
    ;;

    let resume_timer (state : State.t) (input : Input.t) : unit =
      if state.is_paused
      then (
        state.is_paused <- false;
        arm state input)
    ;;

    (* ------------------------------------------------------------ the gesture *)

    let clear_transient_styles (root : el) : unit =
      remove_style root "transition-duration";
      remove_property root "--_toast-swipe-y";
      remove_property root "--_toast-swipe-exit-y";
      remove_property root "--_toast-swipe-opacity";
      remove_property root "--_toast-swipe-scale"
    ;;

    let reset_gesture
          (state : State.t)
          (input : Input.t)
          (root : el)
          (should_resume : bool)
          : unit
      =
      let gesture = state.gesture in
      state.gesture <- None;
      clear_transient_styles root;
      if should_resume
      then
        match gesture with
        | Some g when g.paused_timer -> resume_timer state input
        | _ -> ()
    ;;

    let begin_gesture
          (state : State.t)
          (input : Input.t)
          (root : el)
          (source : [ `Touch | `Pen ])
          (pointer_id : int)
          (client_x : float)
          (client_y : float)
          (target : el option)
          : bool
      =
      if (not input.is_gesture_enabled) || Option.is_some state.gesture
      then false
      else
        let target = Option.value target ~default:root in
        if is_interactive_target target root
        then false
        else (
          let paused_timer = input.is_auto_hide && not state.is_paused in
          if paused_timer then pause_timer state;
          let surface_size = Float.max 1. (height_of root) in
          state.gesture
            <- Some
                 { source
                 ; pointer_id
                 ; start_x = client_x
                 ; start_y = client_y
                 ; start_time = now_ms ()
                 ; direction = input.gesture_direction
                 ; intent = Pending
                 ; paused_timer
                 ; surface_size
                 ; dismiss_threshold =
                     Float.max (surface_size *. swipe_dismiss_ratio) flick_min_distance
                 };
          true)
    ;;

    let move_gesture
          (state : State.t)
          (input : Input.t)
          (root : el)
          (source : [ `Touch | `Pen ])
          (pointer_id : int)
          (client_x : float)
          (client_y : float)
          (prevent_default : unit -> unit)
          (release_capture : unit -> unit)
          : unit
      =
      match state.gesture with
      | Some g when Poly.equal g.source source && Int.equal g.pointer_id pointer_id ->
        let delta_x = client_x -. g.start_x in
        let delta_y = client_y -. g.start_y in
        let abs_x = Float.abs delta_x in
        let abs_y = Float.abs delta_y in
        (match g.intent with
         | Pending ->
           if Float.( > ) abs_x drag_promotion_slop && Float.( > ) abs_x abs_y
           then (
             (* A horizontal drag is not ours: the page may be scrolling, and
                the text may be being selected. *)
             release_capture ();
             reset_gesture state input root true)
           else if Float.( <= ) abs_y drag_promotion_slop || Float.( <= ) abs_y (abs_x *. vertical_intent_ratio)
           then ()
           else (
             g.intent <-
               (if Float.( > ) (delta_y *. Float.of_int g.direction) 0. then Vertical else Opposite);
             if Poly.equal g.intent Opposite
             then (
               (* The wrong way: the card does not follow the finger. *)
               release_capture ();
               reset_gesture state input root true)
             else set_style root "transition-duration" "0s")
         | Vertical | Opposite -> ());
        (match state.gesture with
         | Some g when Poly.equal g.intent Vertical ->
           prevent_default ();
           let travel = Float.max 0. (delta_y *. Float.of_int g.direction) in
           let progress = Float.min 1. (Float.max 0. (travel /. g.surface_size)) in
           set_property root "--_toast-swipe-y" (Printf.sprintf "%gpx" (travel *. Float.of_int g.direction));
           set_property
             root
             "--_toast-swipe-opacity"
             (Printf.sprintf "%.3f" (1. -. (progress *. swipe_active_fade_max)));
           set_property
             root
             "--_toast-swipe-scale"
             (Printf.sprintf "%.3f" (1. -. (progress *. swipe_active_scale_max)))
         | _ -> ())
      | _ -> ()
    ;;

    let end_gesture
          (state : State.t)
          (input : Input.t)
          (root : el)
          (source : [ `Touch | `Pen ])
          (pointer_id : int)
          (client_y : float)
          : unit
      =
      match state.gesture with
      | Some g when Poly.equal g.source source && Int.equal g.pointer_id pointer_id ->
        let travel = Float.max 0. ((client_y -. g.start_y) *. Float.of_int g.direction) in
        let elapsed = Float.max 1. (now_ms () -. g.start_time) in
        let is_dismissed =
          Poly.equal g.intent Vertical
          && (Float.( >= ) travel g.dismiss_threshold
             || (Float.( >= ) travel flick_min_distance
                && Float.( > ) (travel /. elapsed) flick_velocity))
        in
        state.gesture <- None;
        remove_style root "transition-duration";
        if is_dismissed
        then (
          (* The exit animation owns the final translation, so the live drag's
             transform, fade and scale are cleared first. *)
          clear_transient_styles root;
          set_property
            root
            "--_toast-swipe-exit-y"
            (if Int.equal g.direction 1
             then swipe_exit_distance
             else "calc(-1 * " ^ swipe_exit_distance ^ ")");
          Effect.Expert.handle_non_dom_event_exn input.on_manual_dismiss)
        else (
          clear_transient_styles root;
          if g.paused_timer then resume_timer state input)
      | _ -> ()
    ;;

    (* ---------------------------------------------------------- the listeners *)

    let touch_point (event : 'a Js.t) (identifier : int) : (float * float) option =
      match Js.Opt.to_option (Common.prop event "changedTouches" : 'a Js.t Js.opt) with
      | None -> None
      | Some list ->
        let length : int = Js.Unsafe.get list "length" in
        let rec find index =
          if index >= length
          then None
          else
            let touch = Js.Unsafe.get list index in
            let id : float = Js.to_float (Js.Unsafe.coerce (Js.Unsafe.get touch "identifier")) in
            if Int.equal (int_of_float id) identifier
            then
              Some
                ( Js.to_float (Js.Unsafe.coerce (Js.Unsafe.get touch "clientX"))
                , Js.to_float (Js.Unsafe.coerce (Js.Unsafe.get touch "clientY")) )
            else find (index + 1)
        in
        find 0
    ;;

    let touches_length (event : 'a Js.t) : int =
      match Js.Opt.to_option (Common.prop event "touches" : 'a Js.t Js.opt) with
      | None -> 0
      | Some list -> Js.Unsafe.get list "length"
    ;;

    let first_touch (event : 'a Js.t) : (int * float * float) option =
      match Js.Opt.to_option (Common.prop event "changedTouches" : 'a Js.t Js.opt) with
      | None -> None
      | Some list ->
        let length : int = Js.Unsafe.get list "length" in
        if length = 0
        then None
        else
          let touch = Js.Unsafe.get list 0 in
          let identifier : float = Js.to_float (Js.Unsafe.coerce (Js.Unsafe.get touch "identifier")) in
          let client_x : float = Js.to_float (Js.Unsafe.coerce (Js.Unsafe.get touch "clientX")) in
          let client_y : float = Js.to_float (Js.Unsafe.coerce (Js.Unsafe.get touch "clientY")) in
          Some (int_of_float identifier, client_x, client_y)
    ;;

    let pointer_id_of (event : 'a Js.t) : int =
      int_of_float (Js.to_float (Js.Unsafe.coerce (Common.prop event "pointerId")))
    ;;

    let client_x_of (event : 'a Js.t) : float =
      Js.to_float (Js.Unsafe.coerce (Common.prop event "clientX"))
    ;;

    let client_y_of (event : 'a Js.t) : float =
      Js.to_float (Js.Unsafe.coerce (Common.prop event "clientY"))
    ;;

    let is_pen (event : 'a Js.t) : bool =
      String.equal (Option.value (Common.string_prop event "pointerType") ~default:"") "pen"
    ;;

    let listen (state : State.t) (input : Input.t) (el : el) : unit =
      let add kind handler =
        let listener = Js.wrap_callback handler in
        state.listeners <- (Element, kind, Js.Unsafe.inject listener) :: state.listeners;
        add_listener el kind (Js.Unsafe.inject listener)
      in
      (* Hover and focus pause the clock; upstream's onFocusCapture and
         onBlurCapture are the capture-phase cousins of these two. *)
      add "mouseenter" (fun (_ : Dom_html.event Js.t) -> pause_timer state);
      add "mouseleave" (fun (_ : Dom_html.event Js.t) -> resume_timer state input);
      add "focusin" (fun (_ : Dom_html.event Js.t) -> pause_timer state);
      add "focusout" (fun (_ : Dom_html.event Js.t) -> resume_timer state input);
      (* Touch: a one-finger drag towards the card's own edge dismisses it. *)
      add
        "touchstart"
        (fun (event : Dom_html.event Js.t) ->
          if not (Int.equal (touches_length event) 1)
          then reset_gesture state input el true
          else
            match first_touch event with
            | None -> ()
            | Some (identifier, client_x, client_y) ->
              ignore
                (begin_gesture
                   state
                   input
                   el
                   `Touch
                   identifier
                   client_x
                   client_y
                   (el_prop event "target")));
      add
        "touchmove"
        (fun (event : Dom_html.event Js.t) ->
          if not (Int.equal (touches_length event) 1)
          then reset_gesture state input el true
          else
            match state.gesture with
            | Some g when Poly.equal g.source `Touch ->
              (match touch_point event g.pointer_id with
               | None -> ()
               | Some (client_x, client_y) ->
                 move_gesture
                   state
                   input
                   el
                   `Touch
                   g.pointer_id
                   client_x
                   client_y
                   (fun () ->
                     if Js.to_bool (Common.prop event "cancelable")
                     then Common.prevent_default event)
                   (fun () -> ()))
            | _ -> ());
      add
        "touchend"
        (fun (event : Dom_html.event Js.t) ->
          if not (Int.equal (touches_length event) 0)
          then reset_gesture state input el true
          else
            match state.gesture with
            | Some g when Poly.equal g.source `Touch ->
              (match touch_point event g.pointer_id with
               | None -> reset_gesture state input el true
               | Some (_, client_y) -> end_gesture state input el `Touch g.pointer_id client_y)
            | _ -> ());
      add "touchcancel" (fun (_ : Dom_html.event Js.t) -> reset_gesture state input el true);
      (* Pen: the same gesture, driven by the pointer events. The mouse is
         deliberately not included - dragging with a mouse is text selection,
         and upstream leaves the close button as the simple alternative. *)
      add
        "pointerdown"
        (fun (event : Dom_html.event Js.t) ->
          if is_pen event
          then
            ignore
              (begin_gesture
                 state
                 input
                 el
                 `Pen
                 (pointer_id_of event)
                 (client_x_of event)
                 (client_y_of event)
                 (el_prop event "target")));
      add
        "pointermove"
        (fun (event : Dom_html.event Js.t) ->
          if is_pen event
          then
            move_gesture
              state
              input
              el
              `Pen
              (pointer_id_of event)
              (client_x_of event)
              (client_y_of event)
              (fun () -> Common.prevent_default event)
              (fun () -> ()));
      add
        "pointerup"
        (fun (event : Dom_html.event Js.t) ->
          if is_pen event
          then end_gesture state input el `Pen (pointer_id_of event) (client_y_of event))
    ;;

    let listen_window (state : State.t) (input : Input.t) : unit =
      (* A toast must not expire silently while the reader is in another
         window: the clock pauses when the window loses focus and resumes when
         it comes back. *)
      let add kind handler =
        let listener = Js.wrap_callback handler in
        state.listeners <- (Window, kind, Js.Unsafe.inject listener) :: state.listeners;
        ignore
          (Js.Unsafe.meth_call
             Dom_html.window
             "addEventListener"
             [| js_string kind; Js.Unsafe.inject listener |])
      in
      add "blur" (fun (_ : Dom_html.event Js.t) -> pause_timer state);
      add "focus" (fun (_ : Dom_html.event Js.t) -> resume_timer state input)
    ;;

    let init _ _ = State.create ()

    let on_mount (input : Input.t) (state : State.t) (el : el) =
      state.remaining <- input.auto_hide_duration;
      listen state input el;
      listen_window state input;
      arm state input
    ;;
    let on_mount = `Schedule_immediately_after_this_dom_patch_completes on_mount

    let update ~old_input:(old_input : Input.t) ~new_input:(new_input : Input.t) (state : State.t) (_el : el) =
      (* A changed duration is a new toast, as far as the clock is concerned:
         upstream's effect resets the remaining time and starts again. *)
      if not (Float.equal old_input.auto_hide_duration new_input.auto_hide_duration)
      then (
        state.remaining <- new_input.auto_hide_duration;
        state.is_paused <- false;
        arm state new_input)
      else if old_input.is_auto_hide && not new_input.is_auto_hide
      then cancel_timer state
      else if (not old_input.is_auto_hide) && new_input.is_auto_hide
      then (
        state.remaining <- new_input.auto_hide_duration;
        arm state new_input);
      (* The dismissal relay: the notification runs exactly once, when the
         request changes. *)
      if not (Option.equal Poly.equal old_input.request new_input.request)
      then Effect.Expert.handle_non_dom_event_exn new_input.on_request
    ;;

    let destroy _ (state : State.t) (el : el) =
      cancel_timer state;
      List.iter state.listeners ~f:(fun (target, kind, listener) ->
        match target with
        | Element -> remove_listener el kind listener
        | Window ->
          ignore
            (Js.Unsafe.meth_call
               Dom_html.window
               "removeEventListener"
               [| js_string kind; Js.Unsafe.inject listener |]));
      state.listeners <- []
    ;;
  end

  module Hook = Vdom.Attr.Hooks.Make (T)

  let attr
      ~auto_hide_duration
      ~is_auto_hide
      ~gesture_direction
      ~is_gesture_enabled
      ~request
      ~on_request
      ~on_auto_dismiss
      ~on_manual_dismiss
      ()
    =
    Vdom.Attr.create_hook
      "astryx-toast-surface"
      (Hook.create
         { T.Input.auto_hide_duration
         ; is_auto_hide
         ; gesture_direction
         ; is_gesture_enabled
         ; request
         ; on_request
         ; on_auto_dismiss
         ; on_manual_dismiss
         })
  ;;
end

(* ------------------------------------------------------------------ the card *)

(* The dismiss control is a Button, and a Button wants a label even when it is
   icon-only - the label is the accessible name. Upstream's is the translated
   "Dismiss notification". *)
let dismiss_button ~label ~on_dismiss =
  Button.view
    ~label
    ~variant:Button.Ghost
    ~size:Button.Sm
    ~is_icon_only:true
    ~icon:(Icon.view ~size:Icon.Sm ~color:Icon.Inherit ~name:"close" ())
    ~on_click:(fun (_ : Dom_html.mouseEvent Js.t) -> on_dismiss ())
    []
;;

(* The card itself. Everything the DOM needs is here; the two behaviours that
   need the DOM rather than a value - the auto-hide timer and the swipe - live
   in {!Surface_hook} and are attached to the same element. *)
let surface
    ~id
    ~type_
    ~body
    ~end_content
    ~is_auto_hide
    ~auto_hide_duration
    ~is_exiting
    ~gesture_direction
    ~is_gesture_enabled
    ~render_content
    ~request
    ~on_request
    ~dismiss
    ~attrs
    ()
  =
  let is_error = Poly.equal type_ Error in
  let dismiss_control =
    match render_content with
    | Some render ->
      (* Upstream hands the renderer the toast's own content, its resolved
         settings and the dismiss callback, and injects no control of its own:
         "Astryx does not inject a fallback control into custom content." *)
      render
        { body
        ; end_content
        ; type_
        ; is_auto_hide
        ; auto_hide_duration
        ; dismiss = (fun () -> dismiss Manual)
        }
    | None ->
      Vdom.Node.div
        ~attrs:(Attr.class_ [ "astryx-toast__inner" ])
        [ Vdom.Node.div ~attrs:(Attr.class_ [ "astryx-toast__content" ]) [ body ]
        ; Vdom.Node.div
            ~attrs:(Attr.class_ [ "astryx-toast__end" ])
            ((match end_content with Some c -> [ c ] | None -> [])
             @ [ dismiss_button ~label:default_dismiss_label ~on_dismiss:(fun () -> dismiss Manual) ])
        ]
  in
  let classes =
    ([ "astryx-toast"; "astryx-toast--" ^ type_name type_ ]
     @ (if is_exiting then [ "astryx-toast--exiting" ] else []))
  in
  Vdom.Node.div
    ~attrs:
      (Attr.class_ classes
       @ Attr.data "component" "Toast"
       @ Attr.data "toast-type" (type_name type_)
       @ [ Vdom.Attr.create "id" id
         ; Vdom.Attr.create "role" (if is_error then "alert" else "status")
         ; Vdom.Attr.create "aria-live" (if is_error then "assertive" else "polite")
         ; Vdom.Attr.create "aria-atomic" "true"
         ]
       @ [ Surface_hook.attr
             ~auto_hide_duration
             ~is_auto_hide
             ~gesture_direction
             ~is_gesture_enabled
             ~request
             ~on_request
             ~on_auto_dismiss:(dismiss Auto)
             ~on_manual_dismiss:(dismiss Manual)
             () ]
       @ attrs)
    [ dismiss_control ]
;;

(* The public card. Upstream's [Toast] is exported "for inline rendering in
   previews and documentation", and it is a plain component - so is this one.

   The graph is what makes the auto-hide notification *fresh*: the timer fires
   outside any event handler, so the dismissal is relayed through a value the
   graph holds, and the notification runs when that value changes. Without the
   relay the card would call the callback it captured when the timer was
   armed, which is nearly always the same callback and occasionally not. *)
let view
    ?(attrs = [])
    ?(id = default_card_id)
    ?(type_ = Info)
    ?(body = Vdom.Node.none)
    ?end_content
    ?(is_auto_hide = default_is_auto_hide type_)
    ?(auto_hide_duration = default_auto_hide_duration)
    ?(is_exiting = false)
    ?render_content
    ?on_dismiss
    (graph : Bonsai.graph)
  =
  let request, set_request = Bonsai.state (None : dismiss_reason option) graph in
  let set_request_f = Bonsai.map set_request ~f:(fun f -> f) in
  (* The callback is a tree, the house's shape for a component's report to the
     application: the application owns the state it has to change. *)
  let on_dismiss_f =
    match on_dismiss with
    | None -> Bonsai.return (fun (_ : dismiss_reason) -> Effect.Ignore)
    | Some tree -> Bonsai.map tree ~f:(fun f -> f)
  in
  let node =
    Bonsai.map3 request set_request_f on_dismiss_f ~f:(fun request set_request on_dismiss ->
      surface
        ~id
        ~type_
        ~body
        ~end_content
        ~is_auto_hide
        ~auto_hide_duration
        ~is_exiting
        ~gesture_direction:1
        ~is_gesture_enabled:true
        ~render_content
        ~request
        ~on_request:(match request with Some reason -> on_dismiss reason | None -> Effect.Ignore)
        ~dismiss:(fun reason -> set_request (Some reason))
        ~attrs
        ())
  in
  node
;;

(* ---------------------------------------------------------------- the viewport *)

(* The viewport's own state: which rows are on their way out, which rows have
   finished opening, and which toasts have already been announced. *)
type viewport_state =
  { exiting : (string * dismiss_reason) list
  ; settled : string list
  }

(* What a row asks the viewport to do. The card never touches the
   application's list itself: it asks, and the viewport carries the request
   out. *)
type request =
  | Dismiss of string * dismiss_reason
  | Exited of string * dismiss_reason

let viewport_state_init = { exiting = []; settled = [] }

let is_exiting (state : viewport_state) (id : string) =
  List.exists state.exiting ~f:(fun (other, _) -> String.equal other id)
;;

let is_settled (state : viewport_state) (id : string) =
  List.exists state.settled ~f:(fun other -> String.equal other id)

(* Upstream's viewport listens for its own row's transition, and only for that
   row: "grid-template-rows is not private to this wrapper - any descendant may
   animate its own grid, and transitionend bubbles." *)
let transition_property = "grid-template-rows"

(* The exit is a CSS transition, and a transition that never runs - a browser
   with the motion turned off, a headless one - would leave the toast in the
   list for ever. The fallback finishes the exit anyway. *)
let exit_fallback_ms = 400.

module Viewport_hook = struct
  module T = struct
    module Input = struct
      type t =
        { row_ids : string list
        ; pending : request list
        ; entries : entry list
        ; exiting : (string * dismiss_reason) list
        ; on_dismiss : (string -> dismiss_reason -> unit Effect.t)
        ; set_pending : ((request list -> request list) -> unit Effect.t)
        ; set_state : ((viewport_state -> viewport_state) -> unit Effect.t)
        }

      (* The entries and the callback are not part of the identity - they hold
         closures, and a new closure must not restart the viewport's work.
         What is: the rows, the pending requests and the rows on their way
         out. *)
      let sexp_of_t { row_ids; pending; exiting; _ } =
        Sexp.List
          [ Sexp.List (List.map row_ids ~f:(fun id -> Sexp.Atom id))
          ; Sexp.List
              (List.map pending ~f:(fun request ->
                 match request with
                 | Dismiss (id, reason) | Exited (id, reason) ->
                   Sexp.List [ Sexp.Atom id; Sexp.Atom (reason_name reason) ]))
          ; Sexp.List
              (List.map exiting ~f:(fun (id, reason) ->
                 Sexp.List [ Sexp.Atom id; Sexp.Atom (reason_name reason) ]))
          ]
      ;;

      let combine left right =
        { left with
          pending = left.pending @ right.pending
        ; entries = left.entries @ right.entries
        ; exiting = left.exiting @ right.exiting
        }
      ;;
    end

    module State = struct
      type t =
        { mutable input : Input.t option
        ; mutable seen_ids : string list
        ; mutable prev_focus : el option
        ; mutable focus_row_id : string option
        ; mutable pending_focus : string option
        ; mutable live_polite : el option
        ; mutable live_assertive : el option
        ; mutable clear_timer : Js.Unsafe.any option
        ; mutable key_listener : Js.Unsafe.any option
        ; mutable exit_timers : (string * Js.Unsafe.any) list
        }

      let create () =
        { input = None
        ; seen_ids = []
        ; prev_focus = None
        ; focus_row_id = None
        ; pending_focus = None
        ; live_polite = None
        ; live_assertive = None
        ; clear_timer = None
        ; key_listener = None
        ; exit_timers = []
        }
      ;;
    end

    (* ------------------------------------------------------- the live regions *)

    (* Upstream's useAnnounce mounts its two regions ONCE, empty, and only
       mutates their text later: a live region that is created together with
       its content is "born with content", and many screen readers do not
       announce that. The port mounts them on the document body, exactly as
       upstream does, so the guarantee survives. *)
    let visually_hidden_style =
      "position:absolute;width:1px;height:1px;margin:-1px;padding:0;overflow:hidden;\
       clip:rect(0,0,0,0);white-space:nowrap;border:0;pointer-events:none;"
    ;;

    let create_region (politeness : string) (role : string) : el =
      let el = Js.Unsafe.meth_call Dom_html.document "createElement" [| js_string "div" |] in
      ignore
        (Js.Unsafe.meth_call el "setAttribute" [| js_string "data-astryx-live-region"; js_string politeness |]);
      ignore (Js.Unsafe.meth_call el "setAttribute" [| js_string "aria-live"; js_string politeness |]);
      ignore (Js.Unsafe.meth_call el "setAttribute" [| js_string "aria-atomic"; js_string "true" |]);
      ignore (Js.Unsafe.meth_call el "setAttribute" [| js_string "role"; js_string role |]);
      ignore (Js.Unsafe.meth_call el "setAttribute" [| js_string "style"; js_string visually_hidden_style |]);
      let body = Js.Unsafe.get Dom_html.document "body" in
      ignore (Js.Unsafe.meth_call body "appendChild" [| Js.Unsafe.inject el |]);
      el
    ;;

    let remove_region (el : el) : unit =
      let parent = Js.Unsafe.get el "parentNode" in
      ignore (Js.Unsafe.meth_call parent "removeChild" [| Js.Unsafe.inject el |])
    ;;

    let set_region_text (el : el) (text : string) : unit =
      Js.Unsafe.set el "textContent" (Js.string text)
    ;;

    let announce (state : State.t) (politeness : string) (text : string) : unit =
      let region =
        if String.equal politeness "assertive" then state.live_assertive else state.live_polite
      in
      match region with
      | None -> ()
      | Some el ->
        set_region_text el text;
        (* Upstream clears the regions two seconds later, so a stale status
           does not linger in the accessibility tree. *)
        (match state.clear_timer with
         | Some id ->
           ignore (Js.Unsafe.meth_call Dom_html.window "clearTimeout" [| Js.Unsafe.inject id |])
         | None -> ());
        let clear () =
          state.clear_timer <- None;
          (match state.live_polite with Some el -> set_region_text el "" | None -> ());
          (match state.live_assertive with Some el -> set_region_text el "" | None -> ())
        in
        state.clear_timer
          <- Some
               (Js.Unsafe.meth_call
                  Dom_html.window
                  "setTimeout"
                  [| Js.Unsafe.inject (Js.wrap_callback clear); js_number 2000. |])
    ;;

    (* ------------------------------------------------------------ the requests *)

    let find_entry (entries : entry list) (id : string) : entry option =
      List.find entries ~f:(fun entry -> String.equal entry.id id)
    ;;

    let exit_reason (exiting : (string * dismiss_reason) list) (id : string) : dismiss_reason option =
      List.find_map exiting ~f:(fun (other, reason) ->
        if String.equal other id then Some reason else None)
    ;;

    (* The neighbour that takes the focus when the toast holding it leaves:
       the next toast, then the previous one, exactly as upstream picks them
       while the DOM is still intact. *)
    let neighbour_of (entries : entry list) (id : string) : string option =
      let ids = List.map entries ~f:(fun (entry : entry) -> entry.id) in
      let rec find = function
        | [] -> None
        | head :: rest ->
          if String.equal head id
          then (
            match rest with
            | next :: _ -> Some next
            | [] ->
              (match ids with
               | _ :: previous :: _ -> Some previous
               | _ -> None))
          else find rest
      in
      find ids
    ;;

    let handle_requests (state : State.t) (input : Input.t) (el : el) : unit =
      let handle request =
        match request with
        | Dismiss (id, reason) ->
          (* The toast's own onHide fires the moment it is dismissed, exactly
             as upstream's removeToast does - before the exit animation, not
             after it. *)
          (match find_entry input.entries id with
           | Some entry ->
             (match entry.options.on_hide with
              | Some f -> ignore (Effect.Expert.handle_non_dom_event_exn (f reason))
              | None -> ())
           | None -> ());
          (* If the focus lives inside the toast being dismissed, the focus is
             handed to a neighbour once the row unmounts. *)
          (match active_element () with
           | None -> ()
           | Some active ->
             (match query_selector el ("[data-toast-id=\"" ^ id ^ "\"]") with
              | None -> ()
              | Some node ->
                if Js.to_bool (Js.Unsafe.meth_call node "contains" [| Js.Unsafe.inject active |])
                then (
                  state.focus_row_id <- Some id;
                  state.pending_focus <- neighbour_of input.entries id)));
          ignore
            (input.set_state (fun state ->
               { state with
                 exiting =
                   (if is_exiting state id
                    then state.exiting
                    else (id, reason) :: state.exiting)
               }))
        | Exited (id, reason) ->
          (* The exit is over: the toast leaves the list, and the row goes
             with it. *)
          ignore
            (input.set_state (fun state ->
               { exiting =
                   List.filter state.exiting ~f:(fun (other, _) -> not (String.equal other id))
               ; settled = List.filter state.settled ~f:(fun other -> not (String.equal other id))
               }));
          ignore (Effect.Expert.handle_non_dom_event_exn (input.on_dismiss id reason))
      in
      List.iter input.pending ~f:handle;
      (* The requests that have been carried out are dropped, so a later
         update does not carry them out a second time. *)
      if not (List.is_empty input.pending)
      then
        ignore
          (input.set_pending (fun pending ->
             List.filter pending ~f:(fun request ->
               not (List.exists input.pending ~f:(fun done_ -> Poly.equal done_ request)))))
    ;;

    (* ---------------------------------------------------------- the transition *)

    let on_transition_end (state : State.t) (_el : el) (event : Dom_html.event Js.t) : unit =
      let property_name = Option.value (Common.string_prop event "propertyName") ~default:"" in
      if not (String.equal property_name transition_property)
      then ()
      else
        match el_prop event "target" with
        | None -> ()
        | Some target ->
          (match attribute target "data-toast-id" with
           | None -> ()
           | Some id ->
             (match state.input with
              | None -> ()
              | Some input ->
                (match exit_reason input.exiting id with
                 | Some reason ->
                   (* The row finished collapsing: the toast may leave the
                      list now. *)
                   ignore (input.set_pending (fun pending -> pending @ [ Exited (id, reason) ]))
                 | None ->
                   (* The row finished opening: the clip that kept the card's
                      shadow inside the row can be released. *)
                   ignore
                     (input.set_state (fun state ->
                        { state with
                          settled =
                            (if List.exists state.settled ~f:(fun other -> String.equal other id)
                             then state.settled
                             else id :: state.settled)
                        })))))
    ;;

    (* ---------------------------------------------------------------- the F6 *)

    (* F6 is the "go to the notifications" key. Upstream moves the focus into
       the newest toast and remembers where it came from, so the focus can be
       handed back when the last toast goes. *)
    let focusable_in (row : el) : el option =
      let candidates = query_all row Common.Clickable_container.interactive_selectors in
      List.find_map candidates ~f:(fun el ->
        let disabled =
          match Js.Opt.to_option (Common.prop el "disabled" : bool Js.opt) with
          | Some value -> value
          | None -> false
        in
        let aria_disabled =
          match attribute el "aria-disabled" with Some "true" -> true | _ -> false
        in
        let opted_out = match attribute el "tabindex" with Some "-1" -> true | _ -> false in
        if disabled || aria_disabled || opted_out then None else Some el)
    ;;

    let on_key_down (state : State.t) (el : el) (event : Dom_html.event Js.t) : unit =
      let key = Option.value (Common.string_prop event "key") ~default:"" in
      if not (String.equal key "F6")
      then ()
      else
        let active = active_element () in
        let active_inside =
          match active with
          | None -> false
          | Some active -> Js.to_bool (Js.Unsafe.meth_call el "contains" [| Js.Unsafe.inject active |])
        in
        if active_inside
        then ()
        else (
          Common.prevent_default event;
          state.prev_focus <- active;
          (* The newest toast is the last one in the DOM. *)
          let rows = query_all el "[data-toast-id]" in
          match last rows with
          | None -> focus el
          | Some row ->
            let target = Option.value (focusable_in row) ~default:row in
            state.focus_row_id <- attribute row "data-toast-id";
            focus target)
    ;;

    (* When the toast that held the focus leaves, the focus has to go
       somewhere: back where it came from, or into the next toast. *)
    let handoff_focus (state : State.t) (el : el) : unit =
      match state.pending_focus with
      | None -> ()
      | Some target_id ->
        (* The focus moves only once the dismissed row is gone from the DOM. *)
        let still_there =
          match state.focus_row_id with
          | Some id -> Option.is_some (query_selector el ("[data-toast-id=\"" ^ id ^ "\"]"))
          | None -> false
        in
        if still_there
        then ()
        else (
          state.pending_focus <- None;
          state.focus_row_id <- None;
          match query_selector el ("[data-toast-id=\"" ^ target_id ^ "\"]") with
          | Some row -> focus (Option.value (focusable_in row) ~default:row)
          | None ->
            (match state.prev_focus with
             | Some previous when is_connected previous ->
               state.prev_focus <- None;
               focus previous
             | _ -> focus el))
    ;;

    (* ------------------------------------------------------- the announcement *)

    let announce_new (state : State.t) (input : Input.t) (el : el) : unit =
      let fresh =
        List.filter input.row_ids ~f:(fun id ->
          not (List.exists state.seen_ids ~f:(fun other -> String.equal other id)))
      in
      if List.is_empty fresh
      then ()
      else (
        state.seen_ids <- input.row_ids;
        List.iter fresh ~f:(fun id ->
          (* Only the body is announced: the trailing slot is reachable with
             F6, and reading it aloud would say the button's name twice. *)
          match query_selector el ("[data-toast-id=\"" ^ id ^ "\"] .astryx-toast__content") with
          | None -> ()
          | Some content ->
            let text = String.strip (text_content content) in
            if String.is_empty text
            then ()
            else
              let politeness =
                match find_entry input.entries id with
                | Some entry when Poly.equal entry.options.type_ Error -> "assertive"
                | _ -> "polite"
              in
              announce state politeness text))
    ;;

    (* ------------------------------------------------------------ the fallback *)

    let arm_exit_fallbacks (state : State.t) (input : Input.t) : unit =
      List.iter input.exiting ~f:(fun (id, _reason) ->
        if List.exists state.exit_timers ~f:(fun (other, _) -> String.equal other id)
        then ()
        else
          let finish () =
            state.exit_timers
              <- List.filter state.exit_timers ~f:(fun (other, _) -> not (String.equal other id));
            (match state.input with
             | None -> ()
             | Some input ->
               (match exit_reason input.exiting id with
                | None -> ()
                | Some reason ->
                  ignore (input.set_pending (fun pending -> pending @ [ Exited (id, reason) ]))))
          in
          let timer =
            Js.Unsafe.meth_call
              Dom_html.window
              "setTimeout"
              [| Js.Unsafe.inject (Js.wrap_callback finish); js_number exit_fallback_ms |]
          in
          state.exit_timers <- (id, timer) :: state.exit_timers)
    ;;

    let init _ _ = State.create ()

    let on_mount (input : Input.t) (state : State.t) (el : el) =
      state.input <- Some input;
      state.live_polite <- Some (create_region "polite" "status");
      state.live_assertive <- Some (create_region "assertive" "alert");
      let on_key = Js.wrap_callback (fun (event : Dom_html.event Js.t) -> on_key_down state el event) in
      state.key_listener <- Some (Js.Unsafe.inject on_key);
      ignore
        (Js.Unsafe.meth_call
           Dom_html.document
           "addEventListener"
           [| js_string "keydown"; Js.Unsafe.inject on_key |]);
      let on_transition =
        Js.wrap_callback (fun (event : Dom_html.event Js.t) -> on_transition_end state el event)
      in
      add_listener el "transitionend" (Js.Unsafe.inject on_transition)
    ;;
    let on_mount = `Schedule_immediately_after_this_dom_patch_completes on_mount

    let update ~old_input:_ ~new_input (state : State.t) (el : el) =
      state.input <- Some new_input;
      handle_requests state new_input el;
      announce_new state new_input el;
      arm_exit_fallbacks state new_input;
      handoff_focus state el
    ;;

    let destroy _ (state : State.t) _ =
      (match state.live_polite with Some el -> remove_region el | None -> ());
      (match state.live_assertive with Some el -> remove_region el | None -> ());
      state.live_polite <- None;
      state.live_assertive <- None;
      (match state.key_listener with
       | Some listener ->
         ignore
           (Js.Unsafe.meth_call
              Dom_html.document
              "removeEventListener"
              [| js_string "keydown"; Js.Unsafe.inject listener |])
       | None -> ());
      state.key_listener <- None;
      List.iter state.exit_timers ~f:(fun (_, timer) ->
        ignore (Js.Unsafe.meth_call Dom_html.window "clearTimeout" [| Js.Unsafe.inject timer |]));
      state.exit_timers <- []
    ;;
  end

  module Hook = Vdom.Attr.Hooks.Make (T)

  let attr
      ~row_ids
      ~pending
      ~entries
      ~exiting
      ~on_dismiss
      ~set_pending
      ~set_state
      ()
    =
    Vdom.Attr.create_hook
      "astryx-toast-viewport"
      (Hook.create
         { T.Input.row_ids
         ; pending
         ; entries
         ; exiting
         ; on_dismiss
         ; set_pending
         ; set_state
         })
  ;;
end

(* The viewport's stack. The rows are the application's toasts, newest last,
   and the viewport renders the last [max_visible] of them - upstream's
   [toasts.slice(-maxVisible)]. *)
let viewport
    ?(attrs = [])
    ?(id = default_viewport_id)
    ?(position = Bottom_end)
    ?(max_visible = default_max_visible)
    ?(label = default_viewport_label)
    ~toasts
    ~on_dismiss
    (graph : Bonsai.graph)
  =
  let state, set_state = Bonsai.state' viewport_state_init graph in
  let pending, set_pending = Bonsai.state' ([] : request list) graph in
  (* The setters and the application's callback, lifted out of the graph so
     that the rows and the hook can hold on to them. They are stable: a
     setter is a scheduling handle, not a snapshot. *)
  let set_state_f = Bonsai.map set_state ~f:(fun f -> f) in
  let set_pending_f = Bonsai.map set_pending ~f:(fun f -> f) in
  let on_dismiss_f = Bonsai.map on_dismiss ~f:(fun f -> f) in
  let a = Bonsai.map2 toasts state ~f:(fun toasts state -> toasts, state) in
  let b = Bonsai.map2 a pending ~f:(fun (toasts, state) pending -> toasts, state, pending) in
  let c = Bonsai.map2 b set_pending_f ~f:(fun (toasts, state, pending) f -> toasts, state, pending, f) in
  let d = Bonsai.map2 c set_state_f ~f:(fun (toasts, state, pending, f) g -> toasts, state, pending, f, g) in
  let e = Bonsai.map2 d on_dismiss_f ~f:(fun (toasts, state, pending, f, g) h -> toasts, state, pending, f, g, h) in
  Bonsai.map e ~f:(fun (toasts, state, pending, set_pending, set_state, on_dismiss) ->
    let skip = Int.max 0 (List.length toasts - max_visible) in
    let visible = List.drop toasts skip in
    let row_ids = List.map visible ~f:(fun entry -> entry.id) in
    let exiting = state.exiting in
    let is_reversed = Poly.equal position Top_end || Poly.equal position Top_start in
    let row (entry : entry) =
      let is_leaving = is_exiting state entry.id in
      let has_settled = is_settled state entry.id in
      let dismiss reason =
        (* The card never touches the application's list: it asks, and the
           viewport carries the request out. *)
        set_pending (fun pending -> pending @ [ Dismiss (entry.id, reason) ])
      in
      let card =
        surface
          ~id:entry.id
          ~type_:entry.options.type_
          ~body:entry.options.body
          ~end_content:entry.options.end_content
          ~is_auto_hide:entry.options.is_auto_hide
          ~auto_hide_duration:entry.options.auto_hide_duration
          ~is_exiting:is_leaving
          ~gesture_direction:(if is_reversed then -1 else 1)
          ~is_gesture_enabled:true
          ~render_content:None
          ~request:None
          ~on_request:Effect.Ignore
          ~dismiss
          ~attrs:[]
          ()
      in
      Vdom.Node.div
        ~attrs:
          (Attr.class_
             ([ "astryx-toast-viewport__row" ]
              @ (if is_leaving then [ "astryx-toast-viewport__row--exiting" ] else []))
           @ [ Vdom.Attr.create "data-toast-id" entry.id ])
        [ Vdom.Node.div
            ~attrs:
              (Attr.class_
                 ([ "astryx-toast-viewport__row-inner" ]
                  @ (if has_settled && not is_leaving
                     then [ "astryx-toast-viewport__row-inner--settled" ]
                     else [])))
            [ card ] ]
    in
    let has_toasts = not (List.is_empty visible) in
    Vdom.Node.div
      ~attrs:
        (Attr.class_ [ "astryx-toast-viewport"; "astryx-toast-viewport--" ^ position_name position ]
         @ Attr.data "component" "ToastViewport"
         @ Attr.data "position" (position_name position)
         @ [ Vdom.Attr.create "id" id ]
         @ (if has_toasts
            then
              [ Vdom.Attr.create "role" "region"
              ; Vdom.Attr.create "aria-label" label
              ; Vdom.Attr.create "tabindex" "-1"
              ]
            else [])
         @ [ Viewport_hook.attr
               ~row_ids
               ~pending
               ~entries:visible
               ~exiting
               ~on_dismiss
               ~set_pending
               ~set_state
               () ]
         @ attrs)
      (List.map visible ~f:row))
;;
