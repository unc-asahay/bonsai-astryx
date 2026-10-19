(* Copyright (c) Meta Platforms, Inc. and affiliates.
   Ported to OCaml/Bonsai from the astryx Resizable family:
   Resizable/useResizable.ts (the region hook), Resizable/ResizeHandle.tsx (the
   separator) and Resizable/utils.ts (the size vocabulary).

   The upstream family is a hook plus a component: [useResizable] owns a
   region's size, and [ResizeHandle] is the draggable separator that drives it.
   The port keeps that split, because it is the split that matters:

     - [create] is the hook: it owns the size, the bounds, the collapse state
       and the persistence, and hands back a [region] - the port's equivalent of
       upstream's [ResizableRegion] and its [ResizableProps] in one record.
     - [handle_view] is the component: the separator, its grab zone, its pill,
       its ARIA and its keyboard handling.
     - [view] is the two of them composed into the panel/handle/content layout
       upstream's stories build by hand.

   A React hook is a function call; a Bonsai node is a graph. So the region is
   a [Bonsai.t] and its size is a value the graph recomputes, and the handle
   reads that value the way upstream's handle reads the props object it is
   handed. The gesture itself is the same: pointer-down freezes the size the
   deltas are measured from, moves report a delta, pointer-up ends the
   gesture.

   See the mli for the public surface and the accounting of the divergences. *)

open! Core
open! Bonsai_web
open Js_of_ocaml

module Attr = Common.Attr

(* ------------------------------------------------------------------ vocabulary *)

type direction =
  | Horizontal
  | Vertical

type position =
  | Inline
  | Overlay

type pill_placement =
  | Start
  | End
  | Center
  | Auto

(* A percentage carries exactly one pixel bound, as upstream's
   [percent(value, {min} | {max})] does: a floor or a ceiling, never both. *)
type percent_bound =
  | At_least of float
  | At_most of float

type size =
  | Px of float
  | Percent of { value : float ; bound : percent_bound }

(* Upstream's [percent] helper. *)
let percent ~value ~bound = Percent { value; bound }

(* ------------------------------------------------------------------- constants *)

let fallback_min_size = 50.
let fallback_size = 250.
let fallback_collapsed_size = 40.
let keyboard_step = 10.
let keyboard_large_step = 50.
let default_handle_label = "Resize handle"
let collapsed_aria_text = "Collapsed"

(* ---------------------------------------------------------------------- maths *)

(* Upstream's [clampSize]: the size is clamped into the bounds, and when snap
   points are configured the region can only rest on one of them - the nearest
   one to the clamped size. *)
let clamp_size size min max snaps =
  let clamped = Float.min max (Float.max min size) in
  match snaps with
  | [] -> clamped
  | first :: rest ->
    let nearest =
      List.fold_left
        rest
        ~init:first
        ~f:(fun best snap ->
          if Float.(<) (Float.abs (clamped -. snap)) (Float.abs (clamped -. best)) then snap else best)
    in
    Float.min max (Float.max min nearest)
;;

(* A size resolved against its basis. A pixel size is itself; a percentage is
   a share of the basis, rounded, with its one pixel bound applied. *)
let resolve_size (size : size) ~(basis : float) : float =
  match size with
  | Px px -> px
  | Percent { value; bound } ->
    let share = Float.round ((value /. 100.) *. basis) in
    (match bound with
     | At_least floor_px -> Float.max share floor_px
     | At_most ceiling_px -> Float.min share ceiling_px)
;;

(* A configured bound, or the fallback when it is absent (upstream's
   [resolveBound]). An unbounded maximum is [Float.infinity]. *)
let resolve_bound (bound : size option) ~(basis : float) ~(fallback : float) : float =
  match bound with
  | None -> fallback
  | Some size -> resolve_size size ~basis
;;

(* The snap points, in order and without repeats. *)
let dedup_sorted (points : float list) : float list =
  List.fold_left
    points
    ~init:[]
    ~f:(fun acc point ->
      match acc with
      | head :: _ when Float.equal head point -> acc
      | _ -> point :: acc)
  |> List.rev
;;

(* The snap point [count] points away from the region's current size
   ([direction] grows, [-1] shrinks). A point beyond the bounds counts as that
   bound; the nearest end point serves when fewer remain, and the current size
   when it is already there. *)
let adjacent_snap_point ~snaps ~min ~max ~size ~direction ~count =
  let points =
    List.map snaps ~f:(fun point -> Float.min max (Float.max min point))
    |> List.sort ~compare:Float.compare
    |> dedup_sorted
  in
  let ahead =
    if direction > 0
    then List.filter points ~f:(fun point -> Float.(>) point size)
    else List.filter points ~f:(fun point -> Float.(<) point size) |> List.rev
  in
  match ahead with
  | [] -> size
  | _ ->
    let index = Int.min count (List.length ahead) - 1 in
    List.nth_exn ahead index
;;

let fmt_num (value : float) : string = Printf.sprintf "%g" value

(* -------------------------------------------------------------------------- JS *)

(* The window's extent along an axis. Upstream's released basis for a
   percentage with no container is the window WIDTH on both axes; the maximum a
   vertical region reports reads the window HEIGHT. Both are kept, because both
   are observable. *)
let window_extent_js =
  Js.Unsafe.pure_js_expr
    "(function(vertical){return vertical ? window.innerHeight : window.innerWidth;})"
;;

let window_extent (vertical : bool) : float =
  Js.to_float
    (Js.Unsafe.coerce
       (Js.Unsafe.fun_call window_extent_js [| Js.Unsafe.inject (Js.bool vertical) |]))
;;

(* localStorage, under upstream's [astryx-resizable:] prefix. Three formats
   exist in storage and all three are read: the current one
   ({size, isCollapsed}), a legacy width-only number, and a legacy zero, which
   means "collapsed, with no saved size".

   The host hands the entry back as a small string, "<size>:<collapse flag>",
   so the port never has to read a JavaScript object field by field: -1 is
   "no saved size", and the collapse flag is 0 (expanded), 1 (collapsed) or 2
   (an entry that says nothing about it). *)
let storage_js =
  Js.Unsafe.pure_js_expr
    "(function(){\
var PREFIX = 'astryx-resizable:';\
return {\
  load: function(key){\
    try {\
      var raw = window.localStorage.getItem(PREFIX + key);\
      if (raw == null) return 'none';\
      var parsed = JSON.parse(raw);\
      if (typeof parsed === 'number') {\
        if (!isFinite(parsed)) return 'none';\
        if (parsed === 0) return '-1:1';\
        return parsed + ':2';\
      }\
      if (typeof parsed === 'object' && parsed != null) {\
        var size = parsed.size;\
        var isCollapsed = parsed.isCollapsed;\
        var hasSize = typeof size === 'number' && isFinite(size) && size > 0;\
        if (hasSize || isCollapsed === true) {\
          return (hasSize ? size : -1) + ':' + (isCollapsed === true ? 1 : 0);\
        }\
      }\
      return 'none';\
    } catch (e) { return 'none'; }\
  },\
  save: function(key, size, isCollapsed){\
    try {\
      window.localStorage.setItem(PREFIX + key, JSON.stringify({size: size, isCollapsed: isCollapsed}));\
    } catch (e) {}\
  }\
};\
})()"
;;

type persisted =
  { size : float option
  ; is_collapsed : bool option
  }

let load_persisted (key : string) : persisted option =
  let raw =
    Js.to_string
      (Js.Unsafe.coerce
         (Js.Unsafe.fun_call
            (Js.Unsafe.get storage_js "load")
            [| Js.Unsafe.inject (Js.string key) |]))
  in
  match String.split ~on:':' raw with
  | [ size; flag ] ->
    let size = Float.of_string_opt size in
    let flag = Int.of_string_opt flag in
    (match size, flag with
     | Some size, Some flag ->
       Some
         { size = (if Float.(<) size 0. then None else Some size)
         ; is_collapsed =
             (match flag with
              | 0 -> Some false
              | 1 -> Some true
              | _ -> None)
         }
     | _ -> None)
  | _ -> None
;;

let save_persisted (key : string) (size : float) (is_collapsed : bool) : unit =
  ignore
    (Js.Unsafe.fun_call
       (Js.Unsafe.get storage_js "save")
       [| Js.Unsafe.inject (Js.string key)
        ; Js.Unsafe.inject (Js.number_of_float size)
        ; Js.Unsafe.inject (Js.bool is_collapsed)
        |])
;;

(* The resize cursor has to hold over whatever the pointer is dragged across,
   and the panels own that area - so the override lives on the body, not on the
   handle. It is cleared when the gesture ends and when the handle goes away. *)
let body_drag_js =
  Js.Unsafe.pure_js_expr
    "(function(){\
return function(on, horizontal){\
  var body = document.body;\
  if (!body) return;\
  body.style.cursor = on ? (horizontal ? 'col-resize' : 'row-resize') : '';\
  body.style.userSelect = on ? 'none' : '';\
};\
})()"
;;

let set_body_drag (is_dragging : bool) ~(horizontal : bool) : unit =
  ignore
    (Js.Unsafe.fun_call
       body_drag_js
       [| Js.Unsafe.inject (Js.bool is_dragging); Js.Unsafe.inject (Js.bool horizontal) |])
;;

(* The event helpers. A pointer event's fields are untyped from OCaml's side,
   so they are read through the same accessors the other ports use. *)
let client_x (ev : Dom_html.pointerEvent Js.t) : float = Js.Unsafe.get ev "clientX"
let client_y (ev : Dom_html.pointerEvent Js.t) : float = Js.Unsafe.get ev "clientY"
let pointer_id (ev : Dom_html.pointerEvent Js.t) : int = Js.Unsafe.get ev "pointerId"

let current_target (ev : _ Js.t) : Dom_html.element Js.t option =
  match Js.Opt.to_option (Common.prop ev "currentTarget" : Dom_html.element Js.t Js.opt) with
  | Some el -> Some el
  | None -> None
;;

let is_rtl (el : Dom_html.element Js.t) : bool =
  let style = Js.Unsafe.meth_call Js.Unsafe.global "getComputedStyle" [| Js.Unsafe.inject el |] in
  String.equal (Js.to_string (Js.Unsafe.get style "direction")) "rtl"
;;

let stop_propagation (ev : _ Js.t) : unit =
  ignore (Js.Unsafe.meth_call ev "stopPropagation" [||])
;;

(* The gesture takes the pointer for its whole length: without capture the
   browser re-hit-tests every move, so a frame under the drag path swallows
   the rest of the gesture into the guest document. *)
let capture_pointer (el : Dom_html.element Js.t) (ev : Dom_html.pointerEvent Js.t) : unit =
  match Js.Opt.to_option (Js.Unsafe.get el "setPointerCapture") with
  | None -> ()
  | Some _ -> Js.Unsafe.meth_call el "setPointerCapture" [| Js.Unsafe.inject (pointer_id ev) |]
;;

(* ---------------------------------------------------------------------- hooks *)

(* The body's cursor and text-selection override, for the length of a drag.
   The hook is attached to the handle, so a handle that goes away mid-drag
   releases the override on the way out. *)
module Body_drag_hook = struct
  module T = struct
    module State = struct
      type t = { mutable is_dragging : bool }

      let create () = { is_dragging = false }
    end

    module Input = struct
      type t =
        { is_dragging : bool
        ; horizontal : bool
        }

      let sexp_of_t { is_dragging; _ } = Sexp.Atom (Bool.to_string is_dragging)

      let combine left right =
        { is_dragging = left.is_dragging || right.is_dragging
        ; horizontal = right.horizontal
        }
    end

    let init _ _ = State.create ()

    let apply (state : State.t) (input : Input.t) =
      if not (Bool.equal state.is_dragging input.is_dragging)
      then (
        state.is_dragging <- input.is_dragging;
        set_body_drag input.is_dragging ~horizontal:input.horizontal)
    ;;

    let on_mount input state _ = apply state input
    let on_mount = `Schedule_immediately_after_this_dom_patch_completes on_mount
    let update ~old_input:_ ~new_input state _ = apply state new_input

    (* The handle is going away: whatever the gesture was doing, the body is
       not ours to keep. *)
    let destroy _ (state : State.t) _ =
      if state.is_dragging
      then (
        state.is_dragging <- false;
        set_body_drag false ~horizontal:true)
    ;;
  end

  module Hook = Vdom.Attr.Hooks.Make (T)

  let attr ~is_dragging ~horizontal () =
    Vdom.Attr.create_hook
      "astryx-resize-body-drag"
      (Hook.create { T.Input.is_dragging; horizontal })
  ;;
end

(* The persisted size, written when it changes. The write happens in the
   patch, which is where upstream's effect runs: after the render that
   produced the new size, never before it. *)
module Persist_hook = struct
  module T = struct
    module State = struct
      type t = { mutable written : (string * float * bool) option }

      let create () = { written = None }
    end

    module Input = struct
      type t =
        { key : string option
        ; size : float
        ; is_collapsed : bool
        }

      let sexp_of_t { key; size; is_collapsed } =
        Sexp.List
          [ Sexp.Atom (Option.value key ~default:"-none-")
          ; Sexp.Atom (fmt_num size)
          ; Sexp.Atom (Bool.to_string is_collapsed)
          ]
      ;;

      let combine _left right =
        { key = right.key; size = right.size; is_collapsed = right.is_collapsed }
      ;;
    end

    let init _ _ = State.create ()

    let write (state : State.t) (input : Input.t) =
      match input.key with
      | None -> ()
      | Some key ->
        let current = (key, input.size, input.is_collapsed) in
        if not (Poly.equal state.written (Some current))
        then (
          state.written <- Some current;
          (* The size that is saved is the expanded one, so a session that
             ends collapsed still restores the width it had. *)
          save_persisted key input.size input.is_collapsed)
    ;;

    let on_mount input state _ = write state input
    let on_mount = `Schedule_immediately_after_this_dom_patch_completes on_mount
    let update ~old_input:_ ~new_input state _ = write state new_input
    let destroy _ _ _ = ()
  end

  module Hook = Vdom.Attr.Hooks.Make (T)

  let attr ~key ~size ~is_collapsed () =
    Vdom.Attr.create_hook
      "astryx-resize-persist"
      (Hook.create { T.Input.key; size; is_collapsed })
  ;;
end

(* --------------------------------------------------------------------- region *)

(* The running gesture: the size its deltas are measured from, and the basis
   it is measured against. Frozen at pointer-down, released at pointer-up, so
   a container that resizes mid-drag cannot move the bound out from under the
   pointer. *)
type gesture =
  { start_size : float
  ; basis : float
  }

(* The region: the size a resizable panel holds, and the gesture surface the
   separator drives. Upstream splits this into [ResizableRegion] (the state the
   app reads) and [ResizableProps] (the object the handle is handed); the port
   keeps one record, because the two are the same thing seen from two sides. *)
type region =
  { size : float
  (** The current size in pixels. Zero while the region is collapsed, as
      upstream reports it. *)
  ; is_collapsed : bool
  ; min_size_px : float
  ; max_size_px : float
  (** The configured maximum. [Float.infinity] when the region is unbounded. *)
  ; effective_max_px : float option
  (** The maximum the separator reports as [aria-valuemax]: the configured
      maximum when there is one, otherwise the measured extent the region could
      fill - never below the size it currently reports. *)
  ; snaps : float list
  ; collapsed_size : float
  ; collapsible : bool
  ; direction : direction
  ; auto_save_id : string option
  ; on_resize_start : unit Effect.t
  ; on_resize_move : float -> unit Effect.t
  ; on_resize_end : unit Effect.t
  ; on_resize_cancel : unit Effect.t
  ; collapse : unit Effect.t
  ; expand : unit Effect.t
  ; resize : float -> unit Effect.t
  }

let (<+>) a b = Bonsai.map2 a b ~f:(fun a b -> (a, b))

(* [create] is upstream's [useResizable]. *)
let create
    ?default_size
    ?min_size
    ?max_size
    ?(direction = Horizontal)
    ?(collapsible = false)
    ?(collapsed_size = fallback_collapsed_size)
    ?(snaps = [])
    ?auto_save_id
    ?(default_is_collapsed = false)
    ?is_collapsed
    ?on_size_change
    ?on_collapse_change
    ?basis
    graph
  =
  let persisted = match auto_save_id with Some key -> load_persisted key | None -> None in
  (* Whether the caller supplied the basis decides what the region reports as
     its maximum when it is unbounded: a measured basis stands in, and the
     viewport's extent does otherwise. *)
  let has_basis = Option.is_some basis in
  (* A percentage default is resolved once, against the viewport basis, when
     the region is created - a default is a starting point, not a mode that
     tracks its basis afterwards. *)
  let creation_basis = window_extent false in
  let initial_size =
    match persisted with
    | Some { size = Some size; _ } -> size
    | _ -> resolve_size (Option.value default_size ~default:(Px fallback_size)) ~basis:creation_basis
  in
  let initial_collapsed =
    match persisted with
    | Some { is_collapsed = Some is_collapsed; _ } -> is_collapsed
    | _ -> default_is_collapsed
  in
  let size_state, set_size_state = Bonsai.state initial_size graph in
  let collapsed_state, set_collapsed_state = Bonsai.state initial_collapsed graph in
  let gesture_state, set_gesture_state = Bonsai.state None graph in
  let basis_state = match basis with Some b -> b | None -> Bonsai.return creation_basis in
  (* The optional arguments are nodes, and the chain below wants one type for
     each of them, so a node that was passed is lifted into the option the
     chain carries and one that was not becomes the empty option. *)
  let controlled_state =
    match is_collapsed with
    | Some controlled -> Bonsai.map controlled ~f:(fun value -> Some value)
    | None -> Bonsai.return None
  in
  let on_size_state =
    match on_size_change with
    | Some callback -> Bonsai.map callback ~f:(fun value -> Some value)
    | None -> Bonsai.return None
  in
  let on_collapse_state =
    match on_collapse_change with
    | Some callback -> Bonsai.map callback ~f:(fun value -> Some value)
    | None -> Bonsai.return None
  in
  let inputs =
    size_state
    <+> collapsed_state
    <+> basis_state
    <+> controlled_state
    <+> on_size_state
    <+> on_collapse_state
    <+> set_size_state
    <+> set_collapsed_state
    <+> gesture_state
    <+> set_gesture_state
  in
  Bonsai.map inputs
    ~f:(fun
      (((((((((size, uncontrolled_collapsed), basis), controlled_collapsed), on_size_change), on_collapse_change), set_size), set_collapsed), gesture), set_gesture)
      ->
      let is_controlled = Option.is_some controlled_collapsed in
      let is_collapsed =
        collapsible
        && (match controlled_collapsed with
            | Some controlled -> controlled
            | None -> uncontrolled_collapsed)
      in
      (* One basis per gesture: the bounds of a running gesture are measured
         against the basis it started with. *)
      let live_basis = basis in
      let start_size, basis =
        match gesture with
        | Some gesture -> gesture.start_size, gesture.basis
        | None -> (if is_collapsed then 0. else size), live_basis
      in
      let min_size_px = resolve_bound min_size ~basis ~fallback:fallback_min_size in
      let max_size_px = resolve_bound max_size ~basis ~fallback:Float.infinity in
      let clamped_size = clamp_size size min_size_px max_size_px snaps in
      let report_size value =
        match on_size_change with
        | None -> Bonsai.Effect.Ignore
        | Some cb -> cb value
      in
      let report_collapse value =
        match on_collapse_change with
        | None -> Bonsai.Effect.Ignore
        | Some cb -> cb value
      in
      (* A controlled caller owns the collapse state: the region reports the
         transition and changes nothing itself. *)
      let set_collapsed value = if is_controlled then Bonsai.Effect.Ignore else set_collapsed value in
      let on_resize_start =
        set_gesture
          (Some { start_size = (if is_collapsed then 0. else clamped_size); basis })
      in
      let on_resize_move delta =
        let raw = start_size +. delta in
        if collapsible && Float.(<) raw collapsed_size
        then (
          (* Past the collapse threshold the region collapses rather than
             shrinking below it. *)
          if not is_collapsed
          then
            Bonsai.Effect.Many
              [ set_collapsed true; report_collapse true; report_size 0. ]
          else Bonsai.Effect.Ignore)
        else (
          let expands = is_collapsed && Float.(>=) raw collapsed_size in
          let clamped = clamp_size raw min_size_px max_size_px snaps in
          Bonsai.Effect.Many
            ([ set_size clamped; report_size clamped ]
            @ (if expands then [ set_collapsed false; report_collapse false ] else [])))
      in
      (* Ending the gesture releases the frozen basis: a container that
         resized during the drag applies from here on. *)
      let on_resize_end = set_gesture None in
      (* A cancelled gesture is over too: the frozen basis has to come back,
         or every later percentage bound stays pinned to the size at grab
         time. *)
      let on_resize_cancel = on_resize_end in
      let collapse =
        if (not collapsible) || is_collapsed
        then Bonsai.Effect.Ignore
        else Bonsai.Effect.Many [ set_collapsed true; report_collapse true; report_size 0. ]
      in
      let expand =
        let was_collapsed = is_collapsed in
        Bonsai.Effect.Many
          ([ set_collapsed false ]
           @ (if was_collapsed then [ report_collapse false ] else [])
           @ [ report_size clamped_size ])
      in
      let resize new_size =
        (* An invalid programmatic size repairs nothing: it must not replace a
           legal selection with a number that reaches the paint and the
           ARIA. *)
        if (not (Float.is_finite new_size)) || Float.(<) new_size 0.
        then Bonsai.Effect.Ignore
        else (
          let clamped = clamp_size new_size min_size_px max_size_px snaps in
          let was_collapsed = is_collapsed in
          Bonsai.Effect.Many
            ([ set_size clamped ]
             @ (if was_collapsed then [ set_collapsed false; report_collapse false ] else [])
             @ [ report_size clamped ]))
      in
      (* The maximum the separator reports. A configured maximum wins. Otherwise
         the measured extent stands in - never below the size the region
         reports, so [aria-valuenow] can never exceed [aria-valuemax]. *)
      let effective_max_px =
        if Float.is_finite max_size_px
        then Some max_size_px
        else
          let measured =
            if has_basis
            then Some live_basis
            else
              Some
                (window_extent
                   (match direction with Horizontal -> false | Vertical -> true))
          in
          Option.map
            measured
            ~f:(fun measured ->
              Float.max measured (if is_collapsed then min_size_px else clamped_size))
      in
      { size = (if is_collapsed then 0. else clamped_size)
      ; is_collapsed
      ; min_size_px
      ; max_size_px
      ; effective_max_px
      ; snaps
      ; collapsed_size
      ; collapsible
      ; direction
      ; auto_save_id
      ; on_resize_start
      ; on_resize_move
      ; on_resize_end
      ; on_resize_cancel
      ; collapse
      ; expand
      ; resize
      })
;;

(* --------------------------------------------------------------------- handle *)

type drag =
  { pointer_id : int
  ; start_pos : float
  ; rtl : float
  }

(* The pill's side. 'auto' puts it on the panel's side and flips it when the
   panel collapses to nothing, so the grip stays reachable. *)
let resolve_pill_side (placement : pill_placement) ~(is_reversed : bool) ~(is_collapsed : bool) =
  match placement with
  | Start -> Start
  | End -> End
  | Center -> Center
  | Auto ->
    (* The panel's side: the start of the layout, or its end when the handle
       is reversed. A collapsed panel has no side of its own, so the grip
       moves to the other one and stays reachable. *)
    if is_reversed
    then (if is_collapsed then Start else End)
    else (if is_collapsed then End else Start)
;;

let side_name = function
  | Start -> "start"
  | End -> "end"
  | Center -> "center"
  | Auto -> "auto"
;;

(* The separator: the draggable divider between two resizable panels. *)
let handle_view
    ?id
    ?(attrs = [])
    ?(direction = Horizontal)
    ?(position = Inline)
    ?(is_reversed = false)
    ?(is_disabled = false)
    ?(has_divider = false)
    ?(is_always_visible = true)
    ?(pill_placement = Auto)
    ?(label = default_handle_label)
    ?children
    ~resizable
    graph
  =
  let id = Option.value id ~default:"astryx-resize-handle" in
  let dragging, set_dragging_state = Bonsai.state false graph in
  let hovered, set_hovered_state = Bonsai.state false graph in
  let focused, set_focused_state = Bonsai.state false graph in
  (* The pointer that owns the in-flight drag, plus the values its deltas are
     measured against. A ref, so a move does not re-render and so a gesture
     survives the re-render the region does. *)
  let drag : drag option ref = ref None in
  let horizontal = match direction with Horizontal -> true | Vertical -> false in
  let sign = if is_reversed then -1. else 1. in
  let inputs =
    resizable
    <+> dragging
    <+> hovered
    <+> focused
    <+> set_dragging_state
    <+> set_hovered_state
    <+> set_focused_state
  in
  Bonsai.map inputs
    ~f:(fun ((((((region, dragging), hovered), focused), set_dragging), set_hovered), set_focused) ->
      let is_interacting = hovered || focused in
      let side = resolve_pill_side pill_placement ~is_reversed ~is_collapsed:region.is_collapsed in
      let side_class = "astryx-resizable__" ^ side_name side in
      (* The rtl multiplier of the handle: the direction the layout runs in. *)
      let rtl_of ev =
        if not horizontal
        then 1.
        else
          match current_target (Obj.magic ev : _ Js.t) with
          | Some el -> if is_rtl el then -1. else 1.
          | None -> 1.
      in
      let on_pointer_down (ev : Dom_html.pointerEvent Js.t) : unit Effect.t =
        if is_disabled
        then Bonsai.Effect.Ignore
        else (
          Common.prevent_default ev;
          stop_propagation ev;
          let start_pos = if horizontal then client_x ev else client_y ev in
          let rtl = rtl_of ev in
          (match current_target (Obj.magic ev : _ Js.t) with
           | Some el -> capture_pointer el ev
           | None -> ());
          drag := Some { pointer_id = pointer_id ev; start_pos; rtl };
          Bonsai.Effect.Many [ set_dragging true; region.on_resize_start ])
      in
      let on_pointer_move (ev : Dom_html.pointerEvent Js.t) : unit Effect.t =
        match !drag with
        | None -> Bonsai.Effect.Ignore
        | Some current when not (Int.equal current.pointer_id (pointer_id ev)) -> Bonsai.Effect.Ignore
        | Some current ->
          let position = if horizontal then client_x ev else client_y ev in
          let delta = (position -. current.start_pos) *. current.rtl *. sign in
          region.on_resize_move delta
      in
      let on_pointer_up (ev : Dom_html.pointerEvent Js.t) : unit Effect.t =
        match !drag with
        | None -> Bonsai.Effect.Ignore
        | Some current when not (Int.equal current.pointer_id (pointer_id ev)) -> Bonsai.Effect.Ignore
        | Some _ ->
          drag := None;
          Bonsai.Effect.Many [ set_dragging false; region.on_resize_end ]
      in
      let toggle_collapse () = if region.is_collapsed then region.expand else region.collapse in
      let on_keydown (ev : Dom_html.keyboardEvent Js.t) : unit Effect.t =
        if is_disabled
        then Bonsai.Effect.Ignore
        else
          let key = Option.value (Common.string_prop (Obj.magic ev : _ Js.t) "key") ~default:"" in
          let is_shift = Common.bool_prop (Obj.magic ev : _ Js.t) "shiftKey" in
          let step = if is_shift then keyboard_large_step else keyboard_step in
          let rtl = rtl_of ev in
          let arrow_sign =
            if String.equal key "ArrowRight" || String.equal key "ArrowDown"
            then 1.
            else if String.equal key "ArrowLeft" || String.equal key "ArrowUp"
            then -1.
            else 0.
          in
          if Float.(<) arrow_sign 0. || Float.(>) arrow_sign 0.
          then (
            (* The pane's grow direction on this key: right and down grow
               unless the layout is reversed or, on the inline axis,
               right-to-left. *)
            let grows = Float.(>) (arrow_sign *. rtl *. sign) 0. in
            if region.is_collapsed
            then (
              (* A collapsed pane answers only the grow arrow: it opens one
                 step above its minimum, or at the collapse threshold when
                 that is larger. The shrink arrow is a no-op. *)
              if grows
              then
                let target = Float.max (region.min_size_px +. step) region.collapsed_size in
                Bonsai.Effect.Many
                  [ region.on_resize_start
                  ; region.on_resize_move (target -. region.size)
                  ; region.on_resize_end
                  ]
              else Bonsai.Effect.Ignore)
          else if not (List.is_empty region.snaps)
          then (
            (* With snap points the region can rest only on a point, so a
               pixel step would snap straight back: the arrow moves to the
               adjacent point in its direction instead (Shift, two points). *)
            let target =
              adjacent_snap_point
                ~snaps:region.snaps
                ~min:region.min_size_px
                ~max:region.max_size_px
                ~size:region.size
                ~direction:(if grows then 1 else -1)
                ~count:(if is_shift then 2 else 1)
            in
            Bonsai.Effect.Many
              [ region.on_resize_start
              ; region.on_resize_move (target -. region.size)
              ; region.on_resize_end
              ])
          else
            let move = arrow_sign *. step *. rtl *. sign in
            Bonsai.Effect.Many [ region.on_resize_start; region.on_resize_move move; region.on_resize_end ])
          else if String.equal key "Home"
          then
            Bonsai.Effect.Many
              [ region.on_resize_start
              ; region.on_resize_move (region.min_size_px -. region.size)
              ; region.on_resize_end
              ]
          else if String.equal key "End"
          then (
            (* Only a configured maximum is the region's own limit; the
               reported stand-in for an unbounded region is where the pane
               *could* reach, not where End may safely move it. *)
            if Float.is_finite region.max_size_px
            then
              Bonsai.Effect.Many
                [ region.on_resize_start
                ; region.on_resize_move (region.max_size_px -. region.size)
                ; region.on_resize_end
                ]
            else Bonsai.Effect.Ignore)
          else if String.equal key "Enter"
          then (if region.collapsible then toggle_collapse () else Bonsai.Effect.Ignore)
          else Bonsai.Effect.Ignore
      in
      let on_double_click (_ev : Dom_html.mouseEvent Js.t) : unit Effect.t =
        if is_disabled || not region.collapsible
        then Bonsai.Effect.Ignore
        else toggle_collapse ()
      in
      (* The grab zone: a wider, invisible target around the divider, biased
         onto the visible pill so the two are where the pointer expects them. *)
      let hit_area =
        Vdom.Node.div
          ~attrs:
            (Attr.class_
               ([ "astryx-resizable__hit-area"
                ; (if horizontal
                   then "astryx-resizable__hit-area--horizontal"
                   else "astryx-resizable__hit-area--vertical")
                ; side_class
                ]
               @ (if is_disabled then [ "astryx-resizable__hit-area--disabled" ] else []))
             @ [ Vdom.Attr.on_pointerdown on_pointer_down
               ; Vdom.Attr.on_pointermove on_pointer_move
               ; Vdom.Attr.on_pointerup on_pointer_up
               ; Vdom.Attr.on_pointerenter (fun _ -> set_hovered true)
               ; Vdom.Attr.on_pointerleave (fun _ ->
                   if dragging then Bonsai.Effect.Ignore else set_hovered false)
               ])
          []
      in
      (* The pill, or the caller's own grip in its place - upstream renders the
         children where the pill would be, not inside it. *)
      let grip =
        match children with
        | Some kids -> kids
        | None ->
          [ Vdom.Node.div
              ~attrs:
                (Attr.class_
                   ([ "astryx-resizable__pill"
                  ; "astryx-resize-handle-pill"
                  ; (if horizontal
                     then "astryx-resizable__pill--horizontal"
                     else "astryx-resizable__pill--vertical")
                  ; side_class
                  ; (if is_always_visible
                     then "astryx-resizable__pill--visible"
                     else "astryx-resizable__pill--hidden")
                  ]
                 @ (if is_interacting && not dragging then [ "astryx-resizable__pill--interacting" ] else [])
                 @ (if dragging then [ "astryx-resizable__pill--active" ] else [])))
            [] ]
      in
      let handle_classes =
        ([ "astryx-resizable__handle"
         ; (if horizontal
            then "astryx-resizable__handle--horizontal"
            else "astryx-resizable__handle--vertical")
         ]
         @ (match position with
            | Inline -> []
            | Overlay -> [ "astryx-resizable__handle--overlay" ])
         @ (if (not has_divider) && (match position with Inline -> true | Overlay -> false)
            then [ "astryx-resizable__handle--no-divider" ]
            else [])
         @ (if has_divider && is_interacting && not dragging
            then [ "astryx-resizable__handle--interacting" ]
            else [])
         @ (if has_divider && dragging then [ "astryx-resizable__handle--active" ] else [])
         @ (if is_disabled then [ "astryx-resizable__handle--disabled" ] else []))
      in
      let handle_attrs =
        [ Vdom.Attr.id id
        ; Vdom.Attr.create "role" "separator"
        ; Vdom.Attr.create "aria-orientation" (if horizontal then "vertical" else "horizontal")
        ; Vdom.Attr.create "aria-valuenow" (fmt_num (Float.max region.size region.min_size_px))
        ; Vdom.Attr.create "aria-valuemin" (fmt_num region.min_size_px)
        ; Vdom.Attr.create "aria-label" label
        ; Vdom.Attr.create "tabindex" (if is_disabled then "-1" else "0")
        ; Vdom.Attr.on_focus (fun _ -> set_focused true)
        ; Vdom.Attr.on_blur (fun _ -> set_focused false)
        ; Vdom.Attr.on_double_click on_double_click
        ; (* Keyboard resizing must fire from the focusable separator, not from
             a child: keydown fires on the focused element and bubbles up, so a
             handler on a descendant never runs. *)
          Vdom.Attr.on_keydown on_keydown
        ; Body_drag_hook.attr ~is_dragging:dragging ~horizontal ()
        ; Persist_hook.attr
            ~key:region.auto_save_id
            ~size:region.size
            ~is_collapsed:region.is_collapsed
            ()
        ]
        @ (match region.effective_max_px with
           | Some max_px -> [ Vdom.Attr.create "aria-valuemax" (fmt_num max_px) ]
           | None -> [])
        @ (* While the panel is collapsed its real size (0) sits below
             [aria-valuemin], which is invalid per WCAG 4.1.2: the value is
             clamped to the minimum and the true state is announced instead. *)
          (if region.is_collapsed
           then [ Vdom.Attr.create "aria-valuetext" collapsed_aria_text ]
           else [])
        @ (if is_disabled then [ Vdom.Attr.create "aria-disabled" "true" ] else [])
        @ (if dragging then [ Vdom.Attr.create "data-resizing" "true" ] else [])
      in
      Vdom.Node.div
        ~attrs:
          (handle_attrs
          @ Attr.class_ handle_classes
          @ Attr.data "component" "Resizable"
          @ attrs)
        (hit_area :: grip))
;;

(* ------------------------------------------------------------------ composed *)

(* The composed view: the resizable panel, the separator between it and the
   content, and the content itself. Upstream's stories build exactly this by
   hand around a [useResizable] region. *)
let view
    ?id
    ?(attrs = [])
    ?default_size
    ?min_size
    ?max_size
    ?(direction = Horizontal)
    ?(collapsible = false)
    ?(collapsed_size = fallback_collapsed_size)
    ?(snaps = [])
    ?auto_save_id
    ?(default_is_collapsed = false)
    ?is_collapsed
    ?on_size_change
    ?on_collapse_change
    ?basis
    ?(has_divider = true)
    ?(is_always_visible = true)
    ?(pill_placement = Auto)
    ?(is_reversed = false)
    ?(is_disabled = false)
    ?(label = default_handle_label)
    ?children
    ?(panel = fun _ -> [])
    ?(content = [])
    graph
  =
  let id = Option.value id ~default:"astryx-resizable" in
  let region =
    create
      ?default_size
      ?min_size
      ?max_size
      ~direction
      ~collapsible
      ~collapsed_size
      ~snaps
      ?auto_save_id
      ~default_is_collapsed
      ?is_collapsed
      ?on_size_change
      ?on_collapse_change
      ?basis
      graph
  in
  let handle =
    handle_view
      ~id:(id ^ "-handle")
      ~direction
      ~has_divider
      ~is_always_visible
      ~pill_placement
      ~is_reversed
      ~is_disabled
      ~label
      ?children
      ~resizable:region
      graph
  in
  let panel =
    Bonsai.map region ~f:(fun region ->
      let axis = match direction with Horizontal -> "width" | Vertical -> "height" in
      Vdom.Node.div
        ~attrs:
          (Attr.class_ [ "astryx-resizable__panel" ]
           @ Common.Attr.style [ (axis, fmt_num region.size ^ "px") ]
           @ (if region.is_collapsed then [ Vdom.Attr.create "hidden" "true" ] else []))
        (panel region.size))
  in
  let content_node =
    Vdom.Node.div ~attrs:(Attr.class_ [ "astryx-resizable__content" ]) content
  in
  let horizontal = match direction with Horizontal -> true | Vertical -> false in
  Bonsai.map2 panel handle ~f:(fun panel handle ->
    Vdom.Node.div
      ~attrs:
        (Attr.class_
           ([ "astryx-resizable" ]
            @ (if horizontal
               then [ "astryx-resizable--horizontal" ]
               else [ "astryx-resizable--vertical" ]))
         @ [ Vdom.Attr.id id ]
         @ attrs)
      [ panel; handle; content_node ])
;;
