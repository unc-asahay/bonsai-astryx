(* Item — the universal row: start/end slots, a label and a description, and the interactive
   paths (click, link, delegated control, parent-owned role). Port of upstream
   Item/Item.tsx + Item/ItemSwipeLayer.tsx + Item/useSwipeAction.ts. *)

open! Core
open! Bonsai_web
open Js_of_ocaml

type align =
  | Center
  | Start

type density =
  | Compact
  | Balanced
  | Spacious

type layout =
  | Stacked
  | Inline

type swipe_action_variant =
  | Neutral
  | Accent
  | Destructive

type swipe_behavior =
  | Reveal
  | Commit

type side =
  | Leading  (** a drag toward the inline end (rightward in LTR) *)
  | Trailing  (** a drag toward the inline start (leftward in LTR) *)

type phase =
  | Idle
  | Dragging
  | Settling
  | Resting
  | Held

type swipe_action =
  { label : string
  ; icon : Vdom.Node.t option
  ; on_activate : unit -> unit Effect.t
  ; is_disabled : bool
  ; variant : swipe_action_variant
  ; has_removal : bool
  }

type swipe_actions =
  { leading : swipe_action list
  ; trailing : swipe_action list
  }

type as_ =
  | Div
  | Li
  | Span
  | Custom of (Vdom.Attr.t list -> Vdom.Node.t list -> Vdom.Node.t)

type view_state =
  { phase : phase
  ; side : side
  ; is_armed : bool
  }

let idle_state = { phase = Idle; side = Leading; is_armed = false }

type drag_info =
  { pointer_id : int
  ; start_x : float
  ; start_y : float
  ; base_travel : float
  ; mutable claimed : bool option
  ; mutable side : side
  ; mutable panel_width : float
  ; mutable commit_px : float
  ; mutable last_x : float
  ; mutable last_time : float
  ; mutable prev_x : float
  ; mutable prev_time : float
  ; mutable travel : float
  ; inline_sign : int
  }

(* ------------------------------------------------------------------ pure rules *)

(* Roles on which WAI-ARIA permits aria-selected (upstream ARIA_SELECTED_ROLES). *)
let aria_selected_roles =
  [ "option"; "tab"; "row"; "gridcell"; "columnheader"; "rowheader"; "treeitem" ]
;;

(* Roles whose content model permits interactive descendants, so a swipe panel's
   buttons may live inside the row (upstream SWIPE_ROLES). *)
let swipe_roles = [ "listitem" ];;

let sign_of_side = function Leading -> 1. | Trailing -> -1.

(* A module-level counter: the description id, when the caller did not pass one, is
   unique per row on the page. Upstream derives one from useId; the port has a
   counter because a vdom node has no identity it could name. *)
let description_counter = ref 0
let next_description_id () = incr description_counter; sprintf "astryx-item-description-%d" !description_counter

(* ------------------------------------------------------------------ DOM bits *)

let el_of (ev : 'a Js.t) : Dom_html.element Js.t option =
  match Js.Opt.to_option (Common.prop ev "currentTarget" : Dom_html.element Js.t Js.opt) with
  | Some el -> Some el
  | None -> None
;;

let target_of (ev : 'a Js.t) : Dom_html.element Js.t option =
  match Js.Opt.to_option (Common.prop ev "target" : Dom_html.element Js.t Js.opt) with
  | Some el -> Some el
  | None -> None
;;

let closest_el (el : 'a Js.t) (selector : string) : Dom_html.element Js.t option =
  match
    Js.Opt.to_option
      (Js.Unsafe.meth_call el "closest" [| Js.Unsafe.inject (Js.string selector) |])
  with
  | Some e -> Some e
  | None -> None
;;

let pointer_type (ev : 'a Js.t) : string =
  match Js.Opt.to_option (Common.prop ev "pointerType" : Js.js_string Js.t Js.opt) with
  | Some s -> Js.to_string s
  | None -> ""
;;

let client_x (ev : 'a Js.t) : float = Js.Unsafe.get ev "clientX"
let client_y (ev : 'a Js.t) : float = Js.Unsafe.get ev "clientY"
let pointer_id (ev : 'a Js.t) : int = Js.Unsafe.get ev "pointerId"

let now_ms () : float =
  Js.Unsafe.fun_call
    (Js.Unsafe.eval_string
       "(function () { return (typeof performance !== 'undefined' && performance.now) \
        ? performance.now() : Date.now(); })")
    [||]
;;

let is_rtl (el : Dom_html.element Js.t) : bool =
  let style = Js.Unsafe.meth_call Js.Unsafe.global "getComputedStyle" [| Js.Unsafe.inject el |] in
  String.equal (Js.to_string (Js.Unsafe.get style "direction")) "rtl"
;;

let capture_pointer (el : Dom_html.element Js.t) (ev : 'a Js.t) : unit =
  try
    match Js.Opt.to_option (Js.Unsafe.get el "setPointerCapture") with
    | None -> ()
    | Some _ -> Js.Unsafe.meth_call el "setPointerCapture" [| Js.Unsafe.inject (pointer_id ev) |]
  with _ -> ()
;;

let release_pointer (el : Dom_html.element Js.t) (ev : 'a Js.t) : unit =
  try
    match Js.Opt.to_option (Js.Unsafe.get el "releasePointerCapture") with
    | None -> ()
    | Some _ -> Js.Unsafe.meth_call el "releasePointerCapture" [| Js.Unsafe.inject (pointer_id ev) |]
  with _ -> ()
;;

let set_property (el : Dom_html.element Js.t) (name : string) (value : string) : unit =
  Js.Unsafe.fun_call
    (Js.Unsafe.eval_string "(function (el, n, v) { el.style.setProperty(n, v); })")
    [| Js.Unsafe.inject el; Js.Unsafe.inject (Js.string name); Js.Unsafe.inject (Js.string value) |]
;;

let remove_properties (el : Dom_html.element Js.t) (names : string list) : unit =
  Js.Unsafe.fun_call
    (Js.Unsafe.eval_string
       "(function (el, names) { for (var i = 0; i < names.length; i++) { \
        el.style.removeProperty(names[i]); } })")
    [| Js.Unsafe.inject el
     ; Js.Unsafe.inject
         (Js.array (Array.of_list (List.map names ~f:(fun n -> Js.Unsafe.inject (Js.string n)))))
    |]
;;

let client_width (el : Dom_html.element Js.t) : float =
  Js.Unsafe.fun_call
    (Js.Unsafe.eval_string "(function (el) { return el.clientWidth || 0; })")
    [| Js.Unsafe.inject el |]
;;

(* The natural width of a side's entries container — the same measurement upstream
   takes off its ref. The container is found by the panel marker and the class, so
   the gesture needs no refs of its own. *)
let measure_panel (el : Dom_html.element Js.t) (side : side) : float =
  let side_name = match side with Leading -> "leading" | Trailing -> "trailing" in
  match
    Js.Opt.to_option
      (Js.Unsafe.meth_call
         el
         "querySelector"
         [| Js.Unsafe.inject
              (Js.string
                 (sprintf "[data-swipe-panel=\"%s\"] .astryx-item__swipe-entries" side_name))
         |])
  with
  | Some entries -> client_width (Obj.magic entries : Dom_html.element Js.t)
  | None -> 0.
;;

let target_in_panel (ev : 'a Js.t) : bool =
  match target_of ev with
  | None -> false
  | Some t -> Option.is_some (closest_el t "[data-swipe-panel]")
;;

(* The first focusable thing in the row outside its swipe panels, for focus to land
   on when a resting panel closes under it (upstream focusRowContent). *)
let focus_row_content (el : Dom_html.element Js.t) : unit =
  let js =
    Js.Unsafe.eval_string
      "(function (root) { var cands = root.querySelectorAll('button, a[href], input, [tabindex]:not([tabindex=\"-1\"])'); \
       for (var i = 0; i < cands.length; i++) { \
       var el = cands[i]; \
       if (el.closest('[data-swipe-panel]') == null) { el.focus(); return; } } \
       var a = document.activeElement; \
       if (a && a.blur) { a.blur(); } })"
  in
  Js.Unsafe.fun_call js [| Js.Unsafe.inject el |]
;;

let prevent_default (ev : 'a Js.t) : unit =
  try Js.Unsafe.meth_call ev "preventDefault" [||] with _ -> ()
;;

let stop_propagation (ev : 'a Js.t) : unit =
  try Js.Unsafe.meth_call ev "stopPropagation" [||] with _ -> ()
;;

let request_frame (f : unit -> unit) : Js.Unsafe.any option =
  if Js.Optdef.test (Js.Unsafe.get Dom_html.window "requestAnimationFrame")
  then
    Some
      (Js.Unsafe.meth_call
         Dom_html.window
         "requestAnimationFrame"
         [| Js.Unsafe.inject (Js.wrap_callback (fun (_ : float) -> f ())) |])
  else (
    f ();
    None)
;;

let cancel_frame (id : Js.Unsafe.any) =
  try
    if Js.Optdef.test (Js.Unsafe.get Dom_html.window "cancelAnimationFrame")
    then Js.Unsafe.meth_call Dom_html.window "cancelAnimationFrame" [| Js.Unsafe.inject id |]
  with _ -> ()
;;

let prefers_reduced_motion () : bool =
  Js.Unsafe.fun_call
    (Js.Unsafe.eval_string
       "(function () { return (typeof window !== 'undefined' && window.matchMedia) \
        ? window.matchMedia('(prefers-reduced-motion: reduce)').matches : false; })")
    [||]
;;

let contains_active (el : Dom_html.element Js.t) : bool =
  Js.Unsafe.fun_call
    (Js.Unsafe.eval_string "(function (el) { return !!el && !!document.activeElement && \
     el.contains(document.activeElement); })")
    [| Js.Unsafe.inject el |]
;;

let is_same_node (a : Dom_html.element Js.t) (b : Dom_html.element Js.t) : bool =
  Js.to_bool (Js.Unsafe.meth_call a "isSameNode" [| Js.Unsafe.inject b |])
;;

let query_selector (el : Dom_html.element Js.t) (selector : string) : Dom_html.element Js.t option =
  Js.Opt.to_option
    (Js.Unsafe.meth_call el "querySelector" [| Js.Unsafe.inject (Js.string selector) |])
;;

let native_click (el : Dom_html.element Js.t) : unit =
  try Js.Unsafe.meth_call el "click" [||] with _ -> ()
;;

(* ------------------------------------------------------------------ the gesture hook
   vdom has no pointercancel, no passive-capable touchmove and no document-level
   listener; the these three are the only native wiring the gesture needs.
   Everything else runs through vdom attrs built in [view], where they reach the
   shared refs (the same split Slider makes). *)

module Swipe_hook = struct
  module T = struct
    module Input = struct
      type t =
        { enabled : bool
        ; phase : phase
        ; cancel : (Dom_html.pointerEvent Js.t -> unit Effect.t) [@sexp.opaque]
        ; touch_move : (Dom_html.event Js.t -> unit Effect.t) [@sexp.opaque]
        ; close : (Dom_html.element Js.t -> unit Effect.t) [@sexp.opaque]
        ; clear_all : (unit -> unit) [@sexp.opaque]
        }

      let phase_name = function
        | Idle -> "idle" | Dragging -> "dragging" | Settling -> "settling"
        | Resting -> "resting" | Held -> "held"
      ;;

      let sexp_of_t t =
        Sexp.Atom (sprintf "item-swipe enabled=%b phase=%s" t.enabled (phase_name t.phase))
      ;;

      let combine left _ = left
    end

    module State = struct
      type t =
        { mutable cancel_listener : Js.Unsafe.any option
        ; mutable touch_listener : Js.Unsafe.any option
        ; mutable outside_listener : Js.Unsafe.any option
        ; mutable input : Input.t option
        }

      let create () = { cancel_listener = None; touch_listener = None; outside_listener = None; input = None }
    end

    let attach (state : State.t) (input : Input.t) (el : Dom_html.element Js.t) =
      state.input <- Some input;
      (* pointercancel: the browser ends a drag it took over (e.g. a scroll that
         won the axis). vdom has no on_pointercancel, so this is attached natively. *)
      (match state.cancel_listener with
       | Some _ -> ()
       | None ->
         let listener =
           Js.wrap_callback (fun (ev : Dom_html.pointerEvent Js.t) ->
             match state.input with
             | Some i -> Effect.Expert.handle_non_dom_event_exn (i.cancel ev)
             | None -> ())
         in
         state.cancel_listener <- Some (Js.Unsafe.inject listener);
         ignore
           (Js.Unsafe.meth_call
              el "addEventListener"
              [| Js.Unsafe.inject (Js.string "pointercancel"); Js.Unsafe.inject listener |]));
      (* touchmove, non-passive: the browser's half of the drag claim. passive:false
         is the point, so it is attached by hand (see the module header). *)
      (match state.touch_listener with
       | Some _ -> ()
       | None ->
         let listener =
           Js.wrap_callback (fun (ev : Dom_html.event Js.t) ->
             match state.input with
             | Some i -> Effect.Expert.handle_non_dom_event_exn (i.touch_move ev)
             | None -> ())
         in
         state.touch_listener <- Some (Js.Unsafe.inject listener);
         ignore
           (Js.Unsafe.meth_call
              el "addEventListener"
              [| Js.Unsafe.inject (Js.string "touchmove")
               ; Js.Unsafe.inject listener
               ; Js.Unsafe.inject (Js.Unsafe.obj [| "passive", Js.Unsafe.inject Js._false |])
              |]))
    ;;

    let set_outside (state : State.t) (input : Input.t) (el : Dom_html.element Js.t) =
      let want = Poly.equal input.phase Resting in
      match state.outside_listener, want with
      | Some listener, false ->
        state.outside_listener <- None;
        ignore
          (Js.Unsafe.meth_call
             Dom_html.document "removeEventListener"
             [| Js.Unsafe.inject (Js.string "pointerdown"); Js.Unsafe.inject listener |])
      | None, true ->
        let outside =
          Js.wrap_callback (fun (ev : Dom_html.pointerEvent Js.t) ->
            let is_outside =
              Js.Unsafe.fun_call
                (Js.Unsafe.eval_string
                   "(function (root, ev) { var t = ev.target; return !(t instanceof Node) || \
                    !root.contains(t); })")
                [| Js.Unsafe.inject el; Js.Unsafe.inject ev |]
            in
            if is_outside
            then (
              match state.input with
              | Some i -> Effect.Expert.handle_non_dom_event_exn (i.close el)
              | None -> ()))
        in
        state.outside_listener <- Some (Js.Unsafe.inject outside);
        ignore
          (Js.Unsafe.meth_call
             Dom_html.document "addEventListener"
             [| Js.Unsafe.inject (Js.string "pointerdown")
              ; Js.Unsafe.inject outside
              ; Js.Unsafe.inject (Js.Unsafe.obj [| "capture", Js.Unsafe.inject Js._true |])
              |])
      | _ -> ()
    ;;

    let destroy _ (state : State.t) (el : Dom_html.element Js.t) =
      (match state.cancel_listener with
       | None -> ()
       | Some l ->
         state.cancel_listener <- None;
         ignore
           (Js.Unsafe.meth_call
              el "removeEventListener"
              [| Js.Unsafe.inject (Js.string "pointercancel"); Js.Unsafe.inject l |]));
      (match state.touch_listener with
       | None -> ()
       | Some l ->
         state.touch_listener <- None;
         ignore
           (Js.Unsafe.meth_call
              el "removeEventListener"
              [| Js.Unsafe.inject (Js.string "touchmove"); Js.Unsafe.inject l |]));
      (match state.outside_listener with
       | None -> ()
       | Some l ->
         state.outside_listener <- None;
         ignore
           (Js.Unsafe.meth_call
              Dom_html.document "removeEventListener"
              [| Js.Unsafe.inject (Js.string "pointerdown"); Js.Unsafe.inject l |]));
      (match state.input with
       | Some i -> i.clear_all ()
       | None -> ())
    ;;

    let init _ _ = State.create ()

    let on_mount input state el =
      attach state input el;
      set_outside state input el
    ;;

    let on_mount = `Schedule_immediately_after_this_dom_patch_completes on_mount

    let update ~old_input:_ ~new_input state el =
      attach state new_input el;
      set_outside state new_input el
    ;;
  end

  module Hook = Vdom.Attr.Hooks.Make (T)

  let attr ~enabled ~phase ~cancel ~touch_move ~close ~clear_all =
    Vdom.Attr.create_hook
      "astryx-item-swipe"
      (Hook.create { T.Input.enabled; phase; cancel; touch_move; close; clear_all })
  ;;
end

(* ------------------------------------------------------------------ the item's view *)

let view
      ?(as_ = Div)
      ?marker
      ?start_content
      ?description
      ?end_content
      ?(align = Center)
      ?(density = Balanced)
      ?label_lines
      ?description_lines
      ?(layout = Stacked)
      ?on_click
      ?interactive_selector
      ?href
      ?target
      ?rel
      ?(is_highlighted = false)
      ?(is_selected = false)
      ?(is_disabled = false)
      ?swipe_actions
      ?(swipe_behavior = Reveal)
      ?role
      ?description_id
      ?(attrs = [])
      ~label
      graph =
  let leading_swipe = match swipe_actions with Some s -> s.leading | None -> [] in
  let trailing_swipe = match swipe_actions with Some s -> s.trailing | None -> [] in
  let has_swipe_side = function
    | Leading -> List.length leading_swipe > 0
    | Trailing -> List.length trailing_swipe > 0
  in
  let is_delegate = Option.is_some interactive_selector in
  let is_link_root = match as_, href with Custom _, Some _ -> true | _ -> false in
  let has_swipe =
    match swipe_actions with
    | None -> false
    | Some _ ->
      (List.length leading_swipe > 0 || List.length trailing_swipe > 0)
      && not is_disabled
      && not is_delegate
      && not is_link_root
      && (match role with None -> true | Some r -> List.mem swipe_roles r ~equal:String.equal)
  in
  let is_interactive = Option.is_some on_click || Option.is_some href || is_delegate in
  let has_parent_role = Option.is_some role in
  let allows_aria_selected =
    match role with
    | Some r -> List.mem aria_selected_roles r ~equal:String.equal
    | None -> false
  in
  let is_inline_slot = Poly.equal layout Inline in
  let is_string_node = function Vdom.Node.Text _ -> true | _ -> false in
  let label_is_string = is_string_node label in
  let description_is_string =
    match description with Some (Vdom.Node.Text _) -> true | _ -> false
  in
  let is_inline = is_inline_slot && Option.is_some description in
  let desc_id =
    match description_id with
    | Some id -> id
    | None -> next_description_id ()
  in

  (* The swipe state machine lives in refs (created once per component instance, the
     same trick Slider uses for its drag index), because the gesture must read and
     write values synchronously within one event sequence — a graph value is only
     as fresh as the last render. The graph mirrors the three values the panels
     need to paint ([phase], [side], [is_armed]). *)
  let state, set_state = Bonsai.state idle_state graph in
  let drag : drag_info option ref = ref None in
  let travel_ref : float ref = ref 0. in
  let inline_sign_ref : int ref = ref 1 in
  let suppress_click_until : float ref = ref 0. in
  let settle_timer : Js.Unsafe.any option ref = ref None in
  let frame_ref : Js.Unsafe.any option ref = ref None in
  let pending_travel : float option ref = ref None in
  let root_el : Dom_html.element Js.t option ref = ref None in
  let last_reported : view_state option ref = ref None in

  (* The state pair is threaded through a map2 like every other stateful component in
     the codebase (dropdown_menu, slider): the map's callback is the only place where
     the [set_state] value is a function instead of a computation. Everything the
     gesture needs — including the render — lives in that callback. *)
  let render
      (view_state_now_in : view_state)
      (set_state_fn : view_state -> unit Effect.t)
    : Vdom.Node.t
    =
    let report (st : view_state) =
      (* Report only when something changed: reporting is a state write, the write
         re-renders, and the re-render is what washes a drag's per-move noise. *)
      if not (Poly.equal (Some st) !last_reported)
      then (
        last_reported := Some st;
        Effect.Expert.handle_non_dom_event_exn (set_state_fn st))
    in

  let write_travel (el : Dom_html.element Js.t) (travel : float) =
    travel_ref := travel;
    set_property el "--_item-swipe-travel" (sprintf "%gpx" travel)
  in
  let write_duration (el : Dom_html.element Js.t) (ms : float) =
    if Float.(>) ms 0.
    then set_property el "--_item-swipe-duration" (sprintf "%gms" ms)
    else set_property el "--_item-swipe-duration" "0s"
  in
  let clear_inline_props (el : Dom_html.element Js.t) =
    remove_properties el [ "--_item-swipe-travel"; "--_item-swipe-dir"; "--_item-swipe-duration" ];
    travel_ref := 0.
  in
  let cancel_pending_paint () =
    (match !frame_ref with
     | Some id -> cancel_frame id; frame_ref := None
     | None -> ());
    pending_travel := None
  in
  (* One write per frame while the finger drives the row (upstream paintOnNextFrame). *)
  let paint_on_next_frame (el : Dom_html.element Js.t) (travel : float) =
    pending_travel := Some travel;
    match !frame_ref with
    | Some _ -> ()
    | None ->
      frame_ref :=
        request_frame (fun () ->
          frame_ref := None;
          match !pending_travel with
          | Some next -> pending_travel := None; write_travel el next
          | None -> ())
  in

  let cancel_all () =
    cancel_pending_paint ();
    match !settle_timer with
    | Some id -> Common.clear_timeout id; settle_timer := None
    | None -> ()
  in

  (* Move the row to [travel] on the settle clock, then land in [phase]. A zero clock
     (reduced motion) lands at once. [after_slide] runs when the clock ends and
     returns [true] when it started a follow-up settle that owns the landing
     (upstream's afterSlide). *)
  let settle
      ~(el : Dom_html.element Js.t)
      ~(side : side)
      ~(travel : float)
      ~(phase : phase)
      ~after_slide
    =
    cancel_pending_paint ();
    let duration = if prefers_reduced_motion () then 0. else 200. in
    report { phase = Settling; side; is_armed = false };
    write_duration el duration;
    write_travel el travel;
    (match !settle_timer with
     | Some id -> Common.clear_timeout id
     | None -> ());
    let land_here () =
      if after_slide ()
      then ()
      else (
        if Poly.equal phase Idle then clear_inline_props el;
        report (if Poly.equal phase Idle then idle_state else { phase; side; is_armed = false }))
    in
    if Float.(<=) duration 0.
    then land_here ()
    else
      settle_timer :=
        Some
          (Common.timeout
             (fun () ->
               settle_timer := None;
               write_duration el 0.;
               land_here ())
             duration)
  in

  (* The outermost entry fires. Under both models the row first travels to its
     slide-out, fires, then holds out ([has_removal]) or springs back. *)
  let fire_outermost (side : side) : bool =
    let entries = match side with Leading -> leading_swipe | Trailing -> trailing_swipe in
    match List.last entries with
    | None -> false
    | Some entry ->
      if entry.is_disabled
      then false
      else (
        Effect.Expert.handle_non_dom_event_exn (entry.on_activate ());
        entry.has_removal)
  in
  let slide_out_and_fire ~(el : Dom_html.element Js.t) ~(side : side) ~(sign : int) =
    let out = sign_of_side side *. float_of_int sign *. (client_width el +. 24.) in
    settle ~el ~side ~travel:out ~phase:Held ~after_slide:(fun () ->
      if fire_outermost side
      then false
      else (
        settle ~el ~side ~travel:0. ~phase:Idle ~after_slide:(fun () -> false);
        true))
  in
  let close (el : Dom_html.element Js.t) (side : side) =
    if contains_active el then focus_row_content el;
    settle ~el ~side ~travel:0. ~phase:Idle ~after_slide:(fun () -> false)
  in

  (* ----------------------------------------------------------- the swipe gesture *)
  (* Mirrors upstream useSwipeAction. The handlers are built here, where they can
     read and write the refs synchronously; the graph only mirrors phase/side/armed. *)
  let on_pointer_down (ev : Dom_html.pointerEvent Js.t) : unit Effect.t =
    if not has_swipe
    then Bonsai.Effect.Ignore
    else if not (String.equal (pointer_type ev) "touch")
    then Bonsai.Effect.Ignore
    else (
      match !drag with
      | Some _ -> Bonsai.Effect.Ignore
      | None -> (
        let current = Option.value !last_reported ~default:idle_state in
        match current.phase with
        | Settling | Held -> Bonsai.Effect.Ignore
        | _ -> (
          match el_of ev with
          | None -> Bonsai.Effect.Ignore
          | Some el ->
            root_el := Some el;
            let inline_sign = if is_rtl el then -1 else 1 in
            inline_sign_ref := inline_sign;
            let start_time = now_ms () in
            drag :=
              Some
                { pointer_id = pointer_id ev
                ; start_x = client_x ev
                ; start_y = client_y ev
                ; base_travel = !travel_ref *. float_of_int inline_sign
                ; claimed = None
                ; side = (match current.phase with Resting -> current.side | _ -> Leading)
                ; panel_width = 0.
                ; commit_px = 0.
                ; last_x = client_x ev
                ; last_time = start_time
                ; prev_x = client_x ev
                ; prev_time = start_time
                ; travel = 0.
                ; inline_sign
                };
            Bonsai.Effect.Ignore)))
  in

  let paint_move (el : Dom_html.element Js.t) (d : drag_info) (delta_x : float) =
    let sign = sign_of_side d.side in
    let raw = Float.max 0. (delta_x *. sign +. d.base_travel *. sign) in
    let offset =
      if Float.(<=) raw d.commit_px
      then raw
      else d.commit_px +. ((raw -. d.commit_px) *. 0.35)
    in
    let is_armed = Float.(>=) raw d.commit_px in
    if Bool.(<>) is_armed (Float.(>=) d.travel d.commit_px)
    then report { phase = Dragging; side = d.side; is_armed };
    d.travel <- raw;
    d.prev_x <- d.last_x;
    d.prev_time <- d.last_time;
    paint_on_next_frame el (sign *. float_of_int d.inline_sign *. offset)
  in

  let on_pointer_move (ev : Dom_html.pointerEvent Js.t) : unit Effect.t =
    match !drag with
    | None -> Bonsai.Effect.Ignore
    | Some d ->
      if d.pointer_id <> pointer_id ev || Poly.equal d.claimed (Some false)
      then Bonsai.Effect.Ignore
      else (
        let delta_x = (client_x ev -. d.start_x) *. float_of_int d.inline_sign in
        let delta_y = client_y ev -. d.start_y in
        match el_of ev with
        | None -> Bonsai.Effect.Ignore
        | Some el -> (
          match d.claimed with
          | Some true ->
            d.last_x <- client_x ev;
            d.last_time <- now_ms ();
            paint_move el d delta_x;
            Bonsai.Effect.Ignore
          | Some false -> Bonsai.Effect.Ignore
          | None ->
            if Float.(<) (Float.max (Float.abs delta_x) (Float.abs delta_y)) 10.
            then Bonsai.Effect.Ignore
            else if Float.(<=) (Float.abs delta_x) (Float.abs delta_y)
            then (
              d.claimed <- Some false;
              Bonsai.Effect.Ignore)
            else (
              let current = Option.value !last_reported ~default:idle_state in
              let resting = Poly.equal current.phase Resting in
              let side =
                if resting then d.side
                else if Float.(>) delta_x 0. then Leading
                else Trailing
              in
              if not (has_swipe_side side)
              then (
                d.claimed <- Some false;
                Bonsai.Effect.Ignore)
              else (
                d.claimed <- Some true;
                d.side <- side;
                d.panel_width <- measure_panel el side;
                d.commit_px <- Float.max (d.panel_width +. 48.) (client_width el *. 0.5);
                set_property el "--_item-swipe-dir" (string_of_int d.inline_sign);
                write_duration el 0.;
                report { phase = Dragging; side; is_armed = false };
                capture_pointer el ev;
                d.last_x <- client_x ev;
                d.last_time <- now_ms ();
                paint_move el d delta_x;
                Bonsai.Effect.Ignore))))
  in

  let end_gesture (ev : 'a Js.t) ~(cancelled : bool) : unit Effect.t =
    match !drag with
    | None -> Bonsai.Effect.Ignore
    | Some d ->
      if d.pointer_id <> pointer_id ev
      then Bonsai.Effect.Ignore
      else (
        drag := None;
        match d.claimed with
        | Some true ->
          suppress_click_until := now_ms () +. 400.;
          (match el_of ev with
           | None -> Bonsai.Effect.Ignore
           | Some el ->
             release_pointer el ev;
             let side = d.side in
             let sign = d.inline_sign in
             let rest_travel = sign_of_side side *. float_of_int sign *. d.panel_width in
             if cancelled
             then (
               settle ~el ~side ~travel:0. ~phase:Idle ~after_slide:(fun () -> false);
               Bonsai.Effect.Ignore)
             else (
               let elapsed = Float.max 1. (d.last_time -. d.prev_time) in
               let velocity =
                 (sign_of_side side *. float_of_int sign *. (d.last_x -. d.prev_x)) /. elapsed
               in
               let flung = Float.(>=) velocity 0.6 && Float.(>=) d.travel 44. in
               if Float.(>=) d.travel d.commit_px || flung
               then (
                 slide_out_and_fire ~el ~side ~sign;
                 Bonsai.Effect.Ignore)
               else if Poly.equal swipe_behavior Reveal && Float.(>=) d.travel (d.panel_width *. 0.5)
               then (
                 settle ~el ~side ~travel:rest_travel ~phase:Resting ~after_slide:(fun () -> false);
                 Bonsai.Effect.Ignore)
               else (
                 settle ~el ~side ~travel:0. ~phase:Idle ~after_slide:(fun () -> false);
                 Bonsai.Effect.Ignore)))
        | _ -> Bonsai.Effect.Ignore)
  in
  let on_pointer_up (ev : Dom_html.pointerEvent Js.t) : unit Effect.t =
    end_gesture ev ~cancelled:false
  in
  let on_pointer_cancel (ev : Dom_html.pointerEvent Js.t) : unit Effect.t =
    end_gesture ev ~cancelled:true
  in
  let on_touch_move (ev : Dom_html.event Js.t) : unit Effect.t =
    match !drag with
    | Some d when Poly.equal d.claimed (Some true) ->
      if Common.bool_prop ev "cancelable" then prevent_default ev else ();
      Bonsai.Effect.Ignore
    | _ -> Bonsai.Effect.Ignore
  in
  let on_key_down (ev : Dom_html.keyboardEvent Js.t) : unit Effect.t =
    let current = Option.value !last_reported ~default:idle_state in
    let key =
      match Js.Opt.to_option (Js.Unsafe.get ev "key" : Js.js_string Js.t Js.opt) with
      | Some k -> Js.to_string k
      | None -> ""
    in
    if Poly.equal current.phase Resting && String.equal key "Escape"
    then (
      stop_propagation ev;
      match el_of ev with
      | Some el ->
        close el current.side;
        Bonsai.Effect.Ignore
      | None -> Bonsai.Effect.Ignore)
    else Bonsai.Effect.Ignore
  in
  (* A resting panel's entry was tapped: fire it, then hold the row out
     ([has_removal]) or close (upstream activateEntry). *)
  let activate_entry ~(root : Dom_html.element Js.t) (entry : swipe_action) :
    unit Effect.t
    =
    let current = Option.value !last_reported ~default:idle_state in
    if not (Poly.equal current.phase Resting)
    then Bonsai.Effect.Ignore
    else (
      if contains_active root then focus_row_content root;
      let holds_out = entry.has_removal in
      let out = sign_of_side current.side *. float_of_int !inline_sign_ref *. (client_width root +. 24.) in
      ignore
        (settle
           ~el:root
           ~side:current.side
           ~travel:(if holds_out then out else 0.)
           ~phase:(if holds_out then Held else Idle)
           ~after_slide:(fun () -> false));
      entry.on_activate ())
  in

  (* --------------------------------------------------------------- the click paths *)
  (* handleContainerClick: a click that lands on a nested control stays with that
     control; only a click on the row's own surface fires the row's onClick. *)
  let handle_container_click (ev : Dom_html.mouseEvent Js.t) : unit Effect.t =
    if is_disabled
    then Bonsai.Effect.Ignore
    else (
      match on_click with
      | None -> Bonsai.Effect.Ignore
      | Some f -> (
        match target_of ev with
        | None -> Bonsai.Effect.Ignore
        | Some target ->
          if Option.is_some (closest_el target "button, a, input, select, textarea")
          then Bonsai.Effect.Ignore
          else f ev))
  in
  (* Delegation mode: the row is an enlarged target for a nested control (upstream
     useClickableContainer with only interactiveRef — a real surface click is
     proxied to the control by clicking it, so the control sees the activation and
     the row adds no second tab stop). *)
  let delegated_click (ev : Dom_html.mouseEvent Js.t) : unit Effect.t =
    if is_disabled
    then Bonsai.Effect.Ignore
    else (
      match el_of ev, target_of ev with
      | Some root, Some target ->
        let selector = Option.value_exn interactive_selector in
        if is_same_node target root
        then Bonsai.Effect.Ignore
        else if Common.Clickable_container.is_interactive_target ~root ~target
        then Bonsai.Effect.Ignore
        else if Common.Clickable_container.has_text_selection root
        then Bonsai.Effect.Ignore
        else (
          match query_selector root selector with
          | None -> Bonsai.Effect.Ignore
          | Some control ->
            native_click control;
            stop_propagation ev;
            Bonsai.Effect.Ignore)
      | _ -> Bonsai.Effect.Ignore)
  in
  let primary_on_click (ev : Dom_html.mouseEvent Js.t) : unit Effect.t =
    if is_delegate
    then delegated_click ev
    else if has_parent_role
    then (match on_click with Some f -> f ev | None -> Bonsai.Effect.Ignore)
    else if is_interactive
    then handle_container_click ev
    else Bonsai.Effect.Ignore
  in
  let root_on_click (ev : Dom_html.mouseEvent Js.t) : unit Effect.t =
    if has_swipe
    then (
      if Float.(<) (now_ms ()) !suppress_click_until && not (target_in_panel ev)
      then (
        suppress_click_until := 0.;
        prevent_default ev;
        stop_propagation ev;
        Bonsai.Effect.Ignore)
      else primary_on_click ev)
    else primary_on_click ev
  in

  (* ------------------------------------------------------------------ rendering *)
  let density_class = function
    | Compact -> "astryx-item--density-compact"
    | Balanced -> "astryx-item--density-balanced"
    | Spacious -> "astryx-item--density-spacious"
  in
  let truncate_class lines ~default : string option =
    match lines with
    | Some n when Int.(<=) n 1 -> Some "astryx-item--truncate-single"
    | Some _ -> Some "astryx-item--truncate-multi"
    | None -> if default then Some "astryx-item--truncate-single" else None
  in
  let line_clamp_style lines : (string * string) list =
    match lines with
    | Some n when Int.(>) n 1 -> [ "WebkitLineClamp", string_of_int n ]
    | _ -> []
  in
  let variant_class = function
    | Neutral -> "astryx-item__swipe-entry--neutral"
    | Accent -> "astryx-item__swipe-entry--accent"
    | Destructive -> "astryx-item__swipe-entry--destructive"
  in
  let side_name = function Leading -> "leading" | Trailing -> "trailing" in

  let phase_now = view_state_now_in.phase in
    let label_truncate = truncate_class label_lines ~default:label_is_string in
    let description_truncate =
      truncate_class description_lines ~default:(description_is_string || is_inline)
    in
    let label_span =
      Vdom.Node.span
        ~attrs:
          (Common.Attr.class_
             ([ "astryx-item__label" ]
              @ Option.to_list (if is_inline then Some "astryx-item__inline-label" else None)
              @ Option.to_list label_truncate)
           @ Common.Attr.style (line_clamp_style label_lines))
        [ label ]
    in
    let description_span =
      match description with
      | None -> []
      | Some desc ->
        [ Vdom.Node.span
            ~attrs:
              ([ Vdom.Attr.create "id" desc_id ]
               @ Common.Attr.class_
                   ([ "astryx-item__description" ]
                    @ Option.to_list (if is_inline then Some "astryx-item__inline-description" else None)
                    @ Option.to_list description_truncate)
               @ Common.Attr.style (line_clamp_style description_lines))
            [ desc ]
        ]
    in
    let label_and_description = [ label_span ] @ description_span in
    let content_class inline =
      [ "astryx-item__content" ]
      @ (if inline then [ "astryx-item__inline-content" ] else [])
      @ (if is_disabled then [ "astryx-item__content-disabled" ] else [])
    in
    let content_node inline =
      if has_parent_role || is_delegate
      then Vdom.Node.span ~attrs:(Common.Attr.class_ (content_class inline)) label_and_description
      else (
        match href with
        | Some h when not is_link_root ->
          let link_attrs =
            (if is_disabled
             then []
             else [ Vdom.Attr.create "href" h
                  ; Vdom.Attr.create "target" (Option.value target ~default:"")
                  ; Vdom.Attr.create "rel" (Option.value rel ~default:"")
                  ])
            @ (if is_disabled
               then [ Vdom.Attr.create "aria-disabled" "true"; Vdom.Attr.create "tabindex" "-1" ]
               else [])
          in
          Vdom.Node.a
            ~attrs:
              (Common.Attr.class_
                 ([ "astryx-item__invisible-anchor" ] @ content_class inline)
               @ link_attrs)
            label_and_description
        | _ -> (
          match on_click with
          | Some f ->
            Vdom.Node.button
              ~attrs:
                (Common.Attr.class_
                   ([ "astryx-item__invisible-button" ] @ content_class inline)
                 @ [ Vdom.Attr.create "type" "button" ]
                 @ (if is_disabled then [ Vdom.Attr.create "disabled" "true" ] else [])
                 @ [ Vdom.Attr.on_click f ])
              label_and_description
          | None ->
            Vdom.Node.span ~attrs:(Common.Attr.class_ (content_class inline)) label_and_description))
    in
    let inner =
      (match marker with Some m -> [ m ] | None -> [])
      @ (match start_content with
         | Some c ->
           [ Vdom.Node.span ~attrs:(Common.Attr.class_ [ "astryx-item__start-content" ]) [ c ] ]
         | None -> [])
      @ [ content_node is_inline ]
      @ (match end_content with
         | Some c ->
           [ Vdom.Node.span
               ~attrs:
                 (Common.Attr.class_
                    ([ "astryx-item__end-content" ]
                     @ (if is_disabled then [ "astryx-item__content-disabled" ] else [])))
               [ c ]
           ]
         | None -> [])
    in
    (* The row root, found from a panel button by walking up: panels are children of
       the root, so the nearest .astryx-item is the owner. *)
    let get_panel_root ev : Dom_html.element Js.t option =
      match el_of ev with
      | Some el -> (
        match closest_el el ".astryx-item" with
        | Some r -> Some r
        | None -> !root_el)
      | None -> !root_el
    in
    (* The swipe panels: out-of-flow children of the root, so the DOM is the one the
       row had before the split; at rest they show nothing. Under [commit] the
       entries are presentational blocks and the panel is aria-hidden. *)
    let panel (side : side) (entries : swipe_action list) : Vdom.Node.t =
      if not has_swipe || List.length entries = 0
      then Vdom.Node.none
      else (
        let outer = List.last_exn entries in
        let is_commit = Poly.equal swipe_behavior Commit in
        let is_live = Poly.equal phase_now Resting && not is_commit in
        let entry (e : swipe_action) =
          let style =
            Common.Attr.class_
              ([ "astryx-item__swipe-entry" ]
               @ [ variant_class e.variant ]
               @ (if e.is_disabled then [ "astryx-item__swipe-entry--disabled" ] else []))
          in
          let content = Option.to_list e.icon @ [ Vdom.Node.span [ Vdom.Node.text e.label ] ] in
          if is_commit
          then
            Vdom.Node.span
              ~attrs:
                (Common.Attr.class_ ([ "astryx-item__swipe-entry" ] @ [ variant_class e.variant ]))
              content
          else
            Vdom.Node.button
              ~attrs:
                (style
                 @ [ Vdom.Attr.create "type" "button" ]
                 @ (if e.is_disabled then [ Vdom.Attr.create "disabled" "true" ] else [])
                 @ [ Vdom.Attr.on_click (fun ev ->
                       match get_panel_root ev with
                       | Some root -> activate_entry ~root e
                       | None -> Bonsai.Effect.Ignore) ])
              content
        in
        Vdom.Node.div
          ~attrs:
            (Common.Attr.class_
               ([ "astryx-item__swipe-panel" ]
                @ [ (match side with
                    | Leading -> "astryx-item__swipe-panel--leading"
                    | Trailing -> "astryx-item__swipe-panel--trailing") ]
                @ [ variant_class outer.variant ])
             @ [ Vdom.Attr.create "data-swipe-panel" (side_name side) ]
             @ (if is_live then [] else [ Vdom.Attr.create "inert" "true" ])
             @ (if is_commit then [ Vdom.Attr.create "aria-hidden" "true" ] else []))
          [ Vdom.Node.div
              ~attrs:
                (Common.Attr.class_
                   ([ "astryx-item__swipe-entries" ]
                    @ (if Poly.equal side Leading then [ "astryx-item__swipe-entries--leading" ] else [])))
              (List.map entries ~f:entry)
          ]
      )
    in
    let panels =
      if has_swipe
      then [ panel Leading leading_swipe; panel Trailing trailing_swipe ]
      else []
    in
    let root_attrs =
      Common.Attr.data "component" "Item"
      @ Common.Attr.data
          "density"
          (match density with Compact -> "compact" | Balanced -> "balanced" | Spacious -> "spacious")
      @ Common.Attr.data "align" (match align with Center -> "center" | Start -> "start")
      @ Common.Attr.data "selected" (if is_selected then "true" else "false")
      @ Common.Attr.data "pressable" (if is_interactive then "true" else "false")
      @ (match role with
         | Some r -> Common.Attr.role r
         | None -> [])
      @ (if allows_aria_selected
         then [ Vdom.Attr.create "aria-selected" (if is_selected then "true" else "false") ]
         else [])
      @ (if is_selected && not allows_aria_selected then [ Vdom.Attr.create "aria-current" "true" ] else [])
      @ (if is_disabled then [ Vdom.Attr.create "aria-disabled" "true" ] else [])
      @ (match is_link_root, href, is_disabled with
         | true, Some h, false ->
           [ Vdom.Attr.create "href" h
           ; Vdom.Attr.create "target" (Option.value target ~default:"")
           ; Vdom.Attr.create "rel" (Option.value rel ~default:"")
           ]
         | _ -> [])
      @ attrs
    in
    let base_attrs =
      Common.Attr.class_
        ([ "astryx-item" ]
         @ [ density_class density ]
         @ (if Poly.equal align Start then [ "astryx-item--align-start" ] else [])
         @ (if is_interactive then [ "astryx-item--interactive" ] else [])
         @ (if is_highlighted then [ "astryx-item--highlighted" ] else [])
         @ (if is_selected then [ "astryx-item--selected" ] else [])
         @ (if is_link_root then [ "astryx-item--link-root" ] else []))
      @ root_attrs
      @ (if has_swipe
         then
           [ Vdom.Attr.class_ "astryx-item--swipe"
           ; Vdom.Attr.on_pointerdown on_pointer_down
           ; Vdom.Attr.on_pointermove on_pointer_move
           ; Vdom.Attr.on_pointerup on_pointer_up
           ; Swipe_hook.attr
               ~enabled:has_swipe
               ~phase:phase_now
               ~cancel:on_pointer_cancel
               ~touch_move:on_touch_move
               ~close:(fun el ->
                 match !last_reported with
                 | Some st ->
                   close el st.side;
                   Bonsai.Effect.Ignore
                 | None -> Bonsai.Effect.Ignore)
               ~clear_all:cancel_all
           ]
         else [])
      @ [ Vdom.Attr.on_click root_on_click
        ; Vdom.Attr.on_keydown on_key_down
        ]
    in
    let children = inner @ panels in
    match as_ with
    | Div -> Vdom.Node.div ~attrs:base_attrs children
    | Li -> Vdom.Node.li ~attrs:base_attrs children
    | Span -> Vdom.Node.span ~attrs:base_attrs children
    | Custom f -> f base_attrs children
  in
  Bonsai.map2 state set_state ~f:render
