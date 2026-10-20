(* BottomSheet — the mobile touch surface that rises from the bottom edge.

   Upstream: packages/core/src/BottomSheet/ — BottomSheet.tsx (the host),
   BottomSheetPanel.tsx (the panel), snapOffsets.ts (the detent geometry) and
   useSheetGestures.ts (the drag machinery).

   What the browser does, and what the port does:

   - The host is a native <dialog>: with a scrim it is opened with showModal(),
     without one with show(). The top layer, the inert page behind, the focus
     trap, the Escape [cancel] event and the ::backdrop scrim are the
     platform's, and none of them is written here.
   - The port owns what upstream owns around that: the drag handle and the
     detents it rests at, the dismissal matrix, the focus hand-back, and the
     entrance motion.

   The geometry is upstream's, ported as such: a detent is a distance from
   fully open, in pixels, and the arithmetic that turns snap points into
   detents is [Geometry] below — upstream's snapOffsets.ts, which is pure.

   Named divergences are in bottom_sheet.mli. *)

open! Core
open! Bonsai_web
open Js_of_ocaml

module Attr = Common.Attr

(* ------------------------------------------------------------------ types *)

(* How hard the sheet is to dismiss. Upstream's [DialogPurpose], with upstream's
   matrix: [Info] dismisses on Escape, on a scrim click and on a swipe;
   [Form] protects entered data by blocking the scrim click and the swipe but
   leaves Escape alone; [Required] blocks every implicit dismissal and makes
   the sheet an [alertdialog]. *)
type purpose =
  | Info
  | Form
  | Required

(* How tall the sheet is. Upstream's [BottomSheetHeight] plus its numeric and
   CSS-length forms. *)
type height =
  | Hug
  | Capped
  | Tall
  | Custom of Common.Size_value.t

(* A height the sheet can rest at when it is dragged, as the sheet's visible
   height. Upstream's [BottomSheetSnapPoint], which is a number or a string;
   here the three forms upstream accepts are three constructors. *)
type snap_point =
  | Fraction of float
  | Percent of float
  | Px of int

(* ---------------------------------------------------------------- geometry *)

(* Upstream's snapOffsets.ts, ported as such. It is pure — no React, no DOM —
   and upstream keeps it that way so the geometry can be unit-tested without a
   browser. This port keeps that shape: every function here is a function of
   its arguments.

   A detent is an offset in px from the fully-open position (0 = fully open,
   larger = more collapsed). A snap point is a *visible height*; the sheet's own
   height is the tallest stop, so the stops below it are the caller's. *)
module Geometry = struct
  (* Detents whose resting offsets land within this many px of each other are
     treated as the same stop (the taller one wins). *)
  let detent_dedup_px = 48.

  (* Largest share of the fully open sheet the shortest stop may fill and still
     be a peek. Above it the stop is a working surface. *)
  let peek_max_height_ratio = 0.25

  (* The scrim thins to a glance at a peek, but never vanishes: a modal sheet
     keeps the background inert, and a fully clear backdrop reads as
     "interactive" when it is not. *)
  let min_peek_scrim_opacity = 0.3

  (* Resolve one snap point to a visible height in px, or [None] when it is not
     a snap point this sheet can honor. The viewport only scales the result, so
     validity is independent of it. *)
  let parse_snap_point (point : snap_point) ~(viewport_px : float) : float option =
    match point with
    | Fraction fraction ->
      if Float.(>) fraction 0. && Float.(<=) fraction 1. then Some (fraction *. viewport_px) else None
    | Percent percent ->
      if Float.(>) percent 0. then Some ((percent /. 100.) *. viewport_px) else None
    | Px px -> if px > 0 then Some (float_of_int px) else None
  ;;

  (* Resolve snap points to candidate visible heights in px, dropping the ones
     this sheet cannot honor. Upstream returns the bare heights; this port
     keeps each height with the point it came from, so a resting place can
     name the stop it is and be found again after the viewport changes. *)
  let resolve_snap_points
        (points : snap_point list)
        ~(viewport_px : float)
    : (float * snap_point) list
    =
    List.filter_map
      ~f:(fun (point : snap_point) ->
        match parse_snap_point point ~viewport_px with
        | Some height -> Some (height, point)
        | None -> None)
      points
  ;;

  (* Given the sheet's full height (px, as rendered fully open) and a set of
     candidate detent *visible heights* (px), return the resting offsets from
     fully-open, ascending and de-duplicated.

     - 0 (fully open) is always the first detent.
     - Only heights strictly shorter than the sheet become collapsed detents.
     - Offsets closer than [dedup_px] collapse to the smaller (taller) one. *)
  let compute_detent_offsets
        ~(sheet_height : float)
        ~(detent_heights : float list)
        ~(dedup_px : float)
    : float list
    =
    let collapsed =
      List.filter_map
        ~f:(fun height ->
          if Float.(>) height 0. && Float.(<) height sheet_height
          then Some (sheet_height -. height)
          else None)
        detent_heights
    in
    let ascending = List.sort ~compare:Float.compare (0. :: collapsed) in
    let rec dedup kept = function
      | [] -> List.rev kept
      | offset :: rest ->
        (match kept with
         | last :: _ when Float.(<) (offset -. last) dedup_px -> dedup kept rest
         | _ -> dedup (offset :: kept) rest)
    in
    dedup [] ascending
  ;;

  (* Nearest value in [offsets] to [value]. *)
  let nearest_offset (value : float) (offsets : float list) : float =
    match offsets with
    | [] -> value
    | first :: rest ->
      List.fold_left
        rest
        ~init:first
        ~f:(fun best offset ->
          if Float.(<) (Float.abs (offset -. value)) (Float.abs (best -. value)) then offset else best)
  ;;

  (* The peek detent's offset, or [None] when this sheet has no peek.

     A peek is the shortest stop AND a sliver — at most
     [peek_max_height_ratio] of the fully open sheet. It is the one detent the
     sheet does not express as layout height: at a sliver there is nothing
     useful to lay out, so it keeps the full layout height and slides below
     the viewport instead. *)
  let peek_offset_for ~(offsets : float list) ~(visible_sheet_height : float) : float option =
    match List.rev offsets with
    | [] | [ _ ] -> None
    | shortest :: _ ->
      let height_at_shortest = visible_sheet_height -. shortest in
      if Float.(<=) height_at_shortest (peek_max_height_ratio *. visible_sheet_height)
      then Some shortest
      else None
  ;;

  (* Scrim opacity (1 = fully visible) for a drag/settle [offset].

     The scrim is full down to the shortest stop that is still a working
     surface, and only thins past it — onto a peek, where it holds at
     [min_peek_scrim_opacity], or out through the dismiss overshoot, where it
     clears completely because the sheet is leaving. *)
  let scrim_opacity_for_offset
        ~(offset : float)
        ~(offsets : float list)
        ~(dismiss_offset : float)
        ~(peek_offset : float option)
    : float
    =
    let has_peek = Option.is_some peek_offset in
    (* The last stop that is still a working surface: the peek's neighbour
       when there is a peek, the shortest stop itself otherwise. *)
    let fade_start =
      match List.rev offsets with
      | [] -> 0.
      | last :: rest -> if has_peek then (match rest with [] -> 0. | second :: _ -> second) else last
    in
    let fade_end = match peek_offset with Some peek -> peek | None -> dismiss_offset in
    let floor = match peek_offset with Some _ -> min_peek_scrim_opacity | None -> 0. in
    if Float.(<=) offset fade_start
    then 1.
    else if Float.(>=) offset fade_end
    then floor
    else if Float.(<=) (fade_end -. fade_start) 0.
    then floor
    else 1. -. (1. -. floor) *. ((offset -. fade_start) /. (fade_end -. fade_start))
  ;;

  (* Settle target for a released drag. Restricts candidates to the drag
     direction so a committed drag never snaps back past where it started (a
     down-drag settles at/below the start, an up-drag at/above), then picks the
     nearest remaining detent. [dir]: 1 = dragged down, -1 = up, 0 = neither. *)
  let resolve_settle_offset
        ~(value : float)
        ~(offsets : float list)
        ~(dir : int)
        ~(base_offset : float)
    : float
    =
    let candidates =
      if dir > 0
      then
        let downward = List.filter offsets ~f:(fun offset -> Float.(>=) offset base_offset) in
        if List.is_empty downward then offsets else downward
      else if dir < 0
      then
        let upward = List.filter offsets ~f:(fun offset -> Float.(<=) offset base_offset) in
        if List.is_empty upward then offsets else upward
      else offsets
    in
    nearest_offset value candidates
  ;;
end

(* ----------------------------------------------------------------- budgets *)

(* Upstream's height budgets, as CSS. [hug] fits its content, [capped] is a
   scrolling mid-height panel and [tall] is a near-full panel. *)
let panel_height_css (height : height) : string =
  match height with
  | Hug -> "fit-content"
  | Capped -> "62dvh"
  | Tall -> "92dvh"
  | Custom size -> Common.Size_value.to_css size
;;

(* The height the *body* takes when the sheet is fully open. Only [hug]
   differs from the panel: a hugging sheet's height is its content's, so its
   body is not given a height at all. *)
let body_height_css (height : height) : string =
  match height with
  | Hug -> "auto"
  | Capped -> "62dvh"
  | Tall -> "92dvh"
  | Custom size -> Common.Size_value.to_css size
;;

(* A snap point as the CSS length of the sheet's visible height at it. *)
let snap_height_css (point : snap_point) : string =
  match point with
  | Fraction fraction -> sprintf "%.4gdvh" (fraction *. 100.)
  | Percent percent -> sprintf "%.4gdvh" percent
  | Px px -> sprintf "%dpx" px
;;

(* ----------------------------------------------------------------- detents *)

(* One resting place of the sheet.

   [travel] is the distance from fully open, in px — the thing a drag moves and
   the thing a detent is. [layout] is the part of that travel the sheet gives
   up as layout height; the rest is a transform. A peek gives up none: it
   keeps the full layout height and slides below the viewport. *)
type detent =
  { travel : float
  ; layout : float
  ; visible_px : float
  ; body_css : string
  ; snap : snap_point option
  ; is_peek : bool
  }

let fully_open_detent ~(sheet_px : float) ~(body_css : string) : detent =
  { travel = 0.; layout = 0.; visible_px = sheet_px; body_css; snap = None; is_peek = false }
;;

(* The sheet's resting places, shortest visible height last.

   A snap point that is not shorter than the sheet itself is not a stop: the
   fully-open detent already covers it. Near-identical stops collapse to the
   taller one, and the shortest stop is a peek when it is a sliver of the
   sheet. *)
let resolve_detents
      ~(sheet_px : float)
      ~(viewport_px : float)
      ~(snap_points : snap_point list)
      ~(body_css : string)
    : detent list
    =
  if Float.(<=) sheet_px 0.
  then [ fully_open_detent ~sheet_px ~body_css ]
  else
    (* The stops the caller asked for, resolved against the viewport, each with
       the point that asked for it. A stop that is not shorter than the sheet
       is not a stop: the fully-open detent already covers it. *)
    let candidates =
      List.filter_map
        ~f:(fun (height, point) ->
          if Float.(>) height 0. && Float.(<) height sheet_px then Some (height, point) else None)
        (Geometry.resolve_snap_points snap_points ~viewport_px)
    in
    (* Upstream's own arithmetic: the resting offsets, ascending, with the
       near-identical ones collapsed onto the taller of the pair. *)
    let offsets =
      Geometry.compute_detent_offsets
        ~sheet_height:sheet_px
        ~detent_heights:(List.map candidates ~f:(fun (height, _) -> height))
        ~dedup_px:Geometry.detent_dedup_px
    in
    (* The peek is the shortest stop, and only when it is a sliver of the
       sheet — upstream's rule, applied to the offsets it just computed. *)
    let peek_offset = Geometry.peek_offset_for ~offsets ~visible_sheet_height:sheet_px in
    (* Ascending offset, so the fully-open stop comes first and the shortest
       last. *)
    let by_offset =
      List.sort
        ~compare:(fun (a, _) (b, _) -> Float.compare (sheet_px -. a) (sheet_px -. b))
        candidates
    in
    let collapsed =
      List.fold_left
        by_offset
        ~init:[]
        ~f:(fun acc (height, point) ->
          let offset = sheet_px -. height in
          (* A stop upstream's de-duplication dropped, or a second stop at an
             offset one already has, is not a stop. *)
          if
            (not (List.exists offsets ~f:(fun kept -> Float.equal kept offset)))
            || List.exists acc ~f:(fun (detent : detent) -> Float.equal detent.travel offset)
          then acc
          else
            let is_peek = match peek_offset with Some peek -> Float.equal peek offset | None -> false in
            let detent =
              { travel = offset
              ; (* A peek gives up none of its height: it keeps the full
                   layout height and slides below the viewport instead. *)
                layout = (if is_peek then 0. else offset)
              ; visible_px = height
              ; body_css = (if is_peek then body_css else snap_height_css point)
              ; snap = Some point
              ; is_peek
              }
            in
            detent :: acc)
      |> List.rev
    in
    fully_open_detent ~sheet_px ~body_css :: collapsed
;;

(* ------------------------------------------------------------------- state *)

(* The drag the sheet is in. The numbers the drag needs to be rendered: where
   it started from, and how far it has come. *)
type drag_state =
  { base_travel : float
  ; base_layout : float
  ; base_body_css : string
  ; active : float
  }

(* The sheet's own state: the height it was measured at, the detent it rests
   at, and the drag it is in. *)
type sheet_state =
  { sheet_px : float
  ; resting : snap_point option
  ; drag : drag_state option
  }

let initial_state : sheet_state = { sheet_px = 0.; resting = None; drag = None }

(* ------------------------------------------------------------------ the DOM *)

(* A pointer event's fields are untyped from OCaml's side, so they are read
   through the same accessors the other ports use. *)
let client_y (ev : Dom_html.pointerEvent Js.t) : float = Js.Unsafe.get ev "clientY"
let pointer_id (ev : Dom_html.pointerEvent Js.t) : int = Js.Unsafe.get ev "pointerId"
let time_stamp (ev : Dom_html.pointerEvent Js.t) : float = Js.Unsafe.get ev "timeStamp"

let current_target (ev : _ Js.t) : Dom_html.element Js.t option =
  match Js.Opt.to_option (Common.prop ev "currentTarget" : Dom_html.element Js.t Js.opt) with
  | Some el -> Some el
  | None -> None
;;

(* An element by its id, for the focus hand-back. *)
let element_by_id (id : string) : Dom_html.element Js.t option =
  Js.Opt.to_option
    (Js.Unsafe.meth_call
       Dom_html.document
       "getElementById"
       [| Js.Unsafe.inject (Js.string id) |]
      : Dom_html.element Js.t Js.opt)
;;

let stop_propagation (ev : _ Js.t) : unit =
  ignore (Js.Unsafe.meth_call ev "stopPropagation" [||])
;;

(* The gesture takes the pointer for its whole length: without capture the
   browser re-hit-tests every move. *)
let capture_pointer (el : Dom_html.element Js.t) (ev : Dom_html.pointerEvent Js.t) : unit =
  match Js.Opt.to_option (Js.Unsafe.get el "setPointerCapture") with
  | None -> ()
  | Some _ -> Js.Unsafe.meth_call el "setPointerCapture" [| Js.Unsafe.inject (pointer_id ev) |]
;;

(* The layout viewport's height, the box the height budgets and the snap points
   are written against. A keyboard does not shrink it, which is what upstream
   reads too. *)
let viewport_height_px () : float =
  let js =
    Js.Unsafe.eval_string "(function () { return typeof window === 'undefined' ? 0 : window.innerHeight; })"
  in
  (Js.Unsafe.fun_call js [||] : float)
;;

(* The sheet's body, as a CSS height. The body is what carries the sheet's
   visible height: the panel around it keeps the sheet's own height so the
   area above a collapsed sheet stays transparent. *)
let body_element_height_px (el : Dom_html.element Js.t) : float =
  let rect = Js.Unsafe.meth_call el "getBoundingClientRect" [||] in
  (Js.Unsafe.get rect "height" : float)
;;

(* The focus target: a descendant marked [data-astryx-focus-on-open] if there is
   one, the sheet's body otherwise. The house marks it the same way the dialog
   does, and the marking is read by the hook that already runs on open. *)
let focus_target (dialog : Dom_html.element Js.t) : Dom_html.element Js.t option =
  let body =
    match
      Js.Opt.to_option
        (Js.Unsafe.meth_call
           dialog
           "querySelector"
           [| Js.Unsafe.inject (Js.string ".astryx-bottom-sheet__body") |]
         : Dom_html.element Js.t Js.opt)
    with
    | Some el -> Some el
    | None -> None
  in
  match body with
  | None -> None
  | Some body ->
    let found =
      Js.Opt.to_option
        (Js.Unsafe.meth_call
           body
           "querySelector"
           [| Js.Unsafe.inject (Js.string "[data-astryx-focus-on-open]") |]
         : Dom_html.element Js.t Js.opt)
    in
    (match found with Some _ -> found | None -> Some body)
;;

(* The hook that drives the native dialog: it opens and closes the element,
   moves the focus in and hands it back, and reports the sheet's measured
   height back into the graph.

   The modal state follows the *value*, not an event: no vdom event fires when
   a caller decides to open a sheet. The hook is given is_open on every update
   and puts the element in step with it, so a caller that ignores the close
   callback gets the sheet back — the DOM follows the value, the value is the
   truth. *)
module Sheet_hook = struct
  module T = struct
    module State = struct
      type t = { mutable trigger : Dom_html.element Js.t option; mutable last_height : float }

      let create () = { trigger = None; last_height = 0. }
    end

    module Input = struct
      type t =
        { is_open : bool
        ; has_scrim : bool
        ; should_measure : bool
        ; (* An inline sheet is ordinary markup, not a native dialog: it has no
             top layer to open and no modal state to close, so the hook only
             measures it. *)
          is_inline : bool
        ; (* Where the focus goes when the sheet closes: the element with this
             id if there is one, and otherwise the element that had the focus
             when it opened. *)
          final_focus_id : string option
        ; on_measured : (float -> unit Effect.t)[@sexp.opaque]
        }

      let sexp_of_t { is_open; _ } = Sexp.Atom (Bool.to_string is_open)

      let combine left right =
        { left with on_measured = fun px -> Effect.Many [ left.on_measured px; right.on_measured px ] }
      ;;
    end

    let report (input : Input.t) (state : State.t) (value : float) : unit =
      match state.State.last_height with
      | last when Float.equal last value -> ()
      | _ ->
        state.last_height <- value;
        Effect.Expert.handle_non_dom_event_exn (input.on_measured value)
    ;;

    let apply (state : State.t) (input : Input.t) (el : Dom_html.element Js.t) : unit =
      let is_open_now = Js.to_bool (Js.Unsafe.get el "open") in
      if input.is_inline
      then ()
      else if input.is_open && not is_open_now
      then (
        (* Remembered before the modal takes focus, so it can be handed back on
           close — upstream captures the same element for the same reason. *)
        let active : Dom_html.element Js.t = Js.Unsafe.get Dom_html.document "activeElement" in
        state.trigger
          <- (if Common.is_connected active then Some (Js.Unsafe.coerce active) else None);
        (* Also what puts the element in the top layer: the [open] attribute
           alone would be a non-modal dialog wearing a modal's name. *)
        if input.has_scrim then Common.call el "showModal" else Common.call el "show";
        (* After the opening, deliberately: the platform has just chosen its own
           focus target, and this is the correction. *)
        (match focus_target el with
         | Some target -> ignore (Js.Unsafe.meth_call target "focus" [||])
         | None -> ()))
      else if (not input.is_open) && is_open_now
      then (
        Common.call el "close";
        (* Upstream's hand-back: the named element if there is one, and
           otherwise whatever had the focus when the sheet opened. *)
        (match input.final_focus_id with
         | Some id ->
           (match element_by_id id with
            | Some target when Common.is_connected target -> ignore (Js.Unsafe.meth_call target "focus" [||])
            | Some _ | None -> ())
         | None ->
           (match state.trigger with
            | Some trigger when Common.is_connected trigger -> ignore (Js.Unsafe.meth_call trigger "focus" [||])
            | Some _ | None -> ()));
        state.trigger <- None);
      (* The sheet's own height, measured while it is fully open: the body's
         height then *is* the height the detents are measured against. *)
      if input.should_measure
      then
        match
          Js.Opt.to_option
            (Js.Unsafe.meth_call
               el
               "querySelector"
               [| Js.Unsafe.inject (Js.string ".astryx-bottom-sheet__body") |]
             : Dom_html.element Js.t Js.opt)
        with
        | Some body -> report input state (body_element_height_px body)
        | None -> ()
    ;;

    let init _ _ = State.create ()
    let on_mount input state el = apply state input el
    let on_mount = `Schedule_immediately_after_this_dom_patch_completes on_mount
    let update ~old_input:_ ~new_input state el = apply state new_input el
    let destroy _ (state : State.t) _ =
      state.trigger <- None;
      state.last_height <- 0.
  end

  module Hook = Vdom.Attr.Hooks.Make (T)

  let attr ~is_open ~has_scrim ~should_measure ~is_inline ~final_focus_id ~on_measured =
    Vdom.Attr.create_hook
      "astryx-bottom-sheet"
      (Hook.create
         { T.Input.is_open; has_scrim; should_measure; is_inline; final_focus_id; on_measured })
  ;;
end

(* ------------------------------------------------------------------- view *)

let purpose_name = function
  | Info -> "info"
  | Form -> "form"
  | Required -> "required"
;;

(* The detent the sheet rests at right now: the one its state names, or the
   fully-open one when the named stop is not a stop any more. *)
let resting_detent (state : sheet_state) (detents : detent list) : detent =
  match state.resting with
  | None -> (match detents with [] -> fully_open_detent ~sheet_px:0. ~body_css:"auto" | first :: _ -> first)
  | Some point ->
    (match
       List.find_map
         detents
         ~f:(fun (detent : detent) ->
           if Poly.equal detent.snap (Some point) then Some detent else None)
     with
     | Some detent -> detent
     | None -> (match detents with [] -> fully_open_detent ~sheet_px:0. ~body_css:"auto" | first :: _ -> first))
;;

let view
      ?(id = "astryx-bottom-sheet")
      ?(attrs = [])
      ~label
      ?(purpose = Info)
      ?(height = Capped)
      ?(snap_points = [])
      ?(has_scrim = true)
      ?padding
      ?final_focus_id
      ?(is_inline = false)
      ~is_open
      ~on_open_change
      ~children
      (graph : Bonsai.graph)
    : Vdom.Node.t Bonsai.t
    =
  let state, set_state = Bonsai.state' initial_state graph in
  let panel_css = panel_height_css height in
  let body_full_css = body_height_css height in
  let on_open_change_f = Bonsai.map on_open_change ~f:(fun f -> f) in
  Bonsai.map2
    (Bonsai.map3 state is_open on_open_change_f ~f:(fun state is_open on_open_change ->
         (state, is_open, on_open_change)))
    (Bonsai.map2 children set_state ~f:(fun children set_state -> (children, set_state)))
    ~f:(fun (state, is_open, on_open_change) (children, set_state) ->
      let viewport_px = viewport_height_px () in
      let detents =
        resolve_detents
          ~sheet_px:state.sheet_px
          ~viewport_px
          ~snap_points
          ~body_css:body_full_css
      in
      let offsets = List.map detents ~f:(fun (detent : detent) -> detent.travel) in
      let base = resting_detent state detents in
      let max_travel = (match List.rev detents with [] -> 0. | last :: _ -> last.travel) in
      let shortest_visible =
        (match List.rev detents with [] -> 0. | last :: _ -> last.visible_px)
      in
      let dismiss_offset = max_travel +. (shortest_visible *. 0.4) in
      (* The peek is the shortest stop when it is a sliver of the sheet. The
         detents already know which one it is, so the scrim reads it from
         there rather than resolving it a second time. *)
      let peek_offset =
        List.find_map detents ~f:(fun (detent : detent) -> if detent.is_peek then Some detent.travel else None)
      in
      (* The travel the sheet is showing right now: the live one while it is
         dragged, the resting one otherwise. *)
      let active_travel = match state.drag with Some drag -> drag.active | None -> base.travel in
      (* The travel is split across two properties: the layout height the
         scrolling area gives up, and the remainder as a transform. While the
         sheet is in motion it is pinned, so the content cannot reflow out from
         under the finger. *)
      let body_css, translation =
        match state.drag with
        | None -> (base.body_css, base.travel -. base.layout)
        | Some drag ->
          (* The travel is split across two properties: the layout height the
             scrolling area gives up, and the remainder as a transform. While
             the sheet is in motion it is pinned, so the content cannot
             reflow out from under the finger. *)
          let layout = if Float.(<) drag.active drag.base_travel then 0. else drag.base_layout in
          let body_css = if Float.equal layout 0. then body_full_css else drag.base_body_css in
          (body_css, drag.active -. layout)
      in
      let scrim_opacity =
        Geometry.scrim_opacity_for_offset
          ~offset:active_travel
          ~offsets
          ~dismiss_offset
          ~peek_offset
      in
      (* The gesture's own bookkeeping. A ref, so a move does not have to
         re-render to be measured, and so a gesture survives the re-render the
         offset itself causes. *)
      let drag_ref : (int * float * float * float) option ref = ref None in
      let start_y = ref 0. in
      let last_y = ref 0. in
      let last_t = ref 0. in
      let velocity = ref 0. in
      let on_pointer_down (ev : Dom_html.pointerEvent Js.t) : unit Effect.t =
        Common.prevent_default ev;
        stop_propagation ev;
        (match current_target (Obj.magic ev : _ Js.t) with
         | Some el -> capture_pointer el ev
         | None -> ());
        let y = client_y ev in
        start_y := y;
        last_y := y;
        last_t := time_stamp ev;
        velocity := 0.;
        drag_ref := Some (pointer_id ev, y, y, time_stamp ev);
        Effect.Many
          [ set_state
              (fun state ->
                { state
                with
                drag =
                  Some
                    { base_travel = base.travel
                    ; base_layout = base.layout
                    ; base_body_css = base.body_css
                    ; active = base.travel
                    }})
              ]
      in
      let on_pointer_move (ev : Dom_html.pointerEvent Js.t) : unit Effect.t =
        match !drag_ref with
        | None -> Effect.Ignore
        | Some (id, _, _, _) when not (Int.equal id (pointer_id ev)) -> Effect.Ignore
        | Some (_, _, _, _) ->
          let y = client_y ev in
          let t = time_stamp ev in
          let span = t -. !last_t in
          let measured = if Float.(>) span 0. then (y -. !last_y) /. span else !velocity in
          last_y := y;
          last_t := t;
          velocity := measured;
          let delta = y -. !start_y in
          let raw = base.travel +. delta in
          (* Up past fully open: a damped rubber band that springs back on
             release. Past the last detent there is no magnet, so a drag to
             close is not fought. *)
          let next = if Float.(<) raw 0. then Float.max (-48.) (raw *. 0.3) else raw in
          Effect.Many
            [ set_state
                (fun state ->
                  match state.drag with
                  | Some drag -> { state with drag = Some { drag with active = next } }
                  | None -> state)
            ]
      in
      let settle (target : detent) : unit Effect.t =
        Effect.Many [ set_state (fun state -> { state with resting = target.snap; drag = None }) ]
      in
      let on_pointer_up (ev : Dom_html.pointerEvent Js.t) : unit Effect.t =
        match !drag_ref with
        | None -> Effect.Ignore
        | Some (id, _, _, _) when not (Int.equal id (pointer_id ev)) -> Effect.Ignore
        | Some _ ->
          drag_ref := None;
          let delta = client_y ev -. !start_y in
          let offset = Float.max 0. (base.travel +. delta) in
          let dir = if Float.equal delta 0. then 0 else if Float.(>) delta 0. then 1 else -1 in
          (* A finger that rested before lifting released nothing in motion. *)
          let speed = if Float.(<) (time_stamp ev -. !last_t) 100. then !velocity else 0. in
          (* A throw coasts further than the finger did. *)
          let projected = if Float.(>) (Float.abs delta) 48. then offset +. (speed *. 499.) else offset in
          if dir > 0 && Float.(>) projected dismiss_offset
          then
            match purpose with
            | Info ->
              (* Past the dismiss line the sheet leaves; a sheet that protects
                 its content settles at its lowest stop instead. *)
              Effect.Many [ set_state (fun state -> { state with drag = None }); on_open_change false ]
            | Form | Required ->
              (match List.rev detents with
               | [] -> Effect.Ignore
               | last :: _ -> settle last)
          else
            let target =
              Geometry.resolve_settle_offset
                ~value:(Float.max 0. (Float.min projected max_travel))
                ~offsets
                ~dir
                ~base_offset:base.travel
            in
            (match
               List.find_map
                 detents
                 ~f:(fun (detent : detent) ->
                   if Float.equal detent.travel target then Some detent else None)
             with
             | Some detent -> settle detent
             | None -> (match detents with [] -> Effect.Ignore | first :: _ -> settle first))
      in
      (* The content box's inset. Upstream's default is the theme's
         bottom-sheet padding, then --spacing-4 — the dialog's default. *)
      let content_style =
        match padding with
        | Some step -> sprintf "padding:%s" (Common.Spacing.var step)
        | None -> "padding:var(--spacing-4)"
      in
      let handle_pill = Vdom.Node.div ~attrs:[ Vdom.Attr.class_ "astryx-bottom-sheet__handle-pill" ] [] in
      let handle =
        Vdom.Node.div
          ~attrs:
            [ Vdom.Attr.class_ "astryx-bottom-sheet__handle"
            ; Vdom.Attr.create "aria-hidden" "true"
            ; Vdom.Attr.on_pointerdown on_pointer_down
            ; Vdom.Attr.on_pointermove on_pointer_move
            ; Vdom.Attr.on_pointerup on_pointer_up
            ]
          [ handle_pill ]
      in
      let content =
        Vdom.Node.div
          ~attrs:
            [ Vdom.Attr.class_ "astryx-bottom-sheet__content"
            ; Vdom.Attr.create "style" content_style
            ]
          children
      in
      let body =
        Vdom.Node.div
          ~attrs:
            [ Vdom.Attr.class_ "astryx-bottom-sheet__body"
            ; Vdom.Attr.create "tabindex" "-1"
            ; Vdom.Attr.create "style"
                (sprintf
                   "height:%s;transform:translateY(%spx)"
                   body_css
                   (Printf.sprintf "%.2f" translation))
            ]
          [ handle; content ]
      in
      let panel =
        Vdom.Node.div
          ~attrs:
            [ Vdom.Attr.class_ "astryx-bottom-sheet__panel"
            ; Vdom.Attr.create "style" (sprintf "height:%s" panel_css)
            ]
          [ body ]
      in
      let positioner = Vdom.Node.div ~attrs:[ Vdom.Attr.class_ "astryx-bottom-sheet__positioner" ] [ panel ] in
      (* The scrim is the dialog's own ::backdrop, and its opacity follows the
         sheet: full at every working stop, thinning only onto a peek. *)
      let scrim_style = sprintf "--_sheet-scrim-opacity:%.3f" scrim_opacity in
      let role_attr =
        Vdom.Attr.create "role" (match purpose with Required -> "alertdialog" | Info | Form -> "dialog")
      in
      let on_measured =
        fun (px : float) ->
          set_state (fun state ->
            if Float.equal state.sheet_px px then state else { state with sheet_px = px })
      in
      if is_inline
      then
        (* The showcase path: ordinary markup, no top layer, no modal behaviour
           and no scrim, so a page can show several sheets at once and a gate
           without a browser can still read the structure. *)
        if not is_open
        then Vdom.Node.none
        else
          Vdom.Node.div
            ~attrs:
              (Attr.class_ [ "astryx-bottom-sheet"; "astryx-bottom-sheet--inline" ]
               @ Attr.data "component" "BottomSheet"
               @ [ Vdom.Attr.create "id" id
                 ; Vdom.Attr.create "aria-label" label
                 ; role_attr
                 ; Vdom.Attr.create "data-purpose" (purpose_name purpose)
                 ]
               @ attrs
              @ [ Sheet_hook.attr
                    ~is_open
                    ~has_scrim:false
                    ~should_measure:
                      (is_open && Option.is_none state.resting && Option.is_none state.drag)
                    ~is_inline:true
                    ~final_focus_id
                    ~on_measured ])
            [ positioner ]
      else
        Vdom.Node.create
          "dialog"
          ~attrs:
            (Attr.class_
               ([ "astryx-bottom-sheet" ]
                @ (if has_scrim then [ "astryx-bottom-sheet--scrim" ] else [ "astryx-bottom-sheet--non-modal" ]))
             @ Attr.data "component" "BottomSheet"
             @ [ Vdom.Attr.create "id" id
               ; Vdom.Attr.create "aria-label" label
               ; Vdom.Attr.create "aria-modal" (if has_scrim then "true" else "false")
               ; Vdom.Attr.create "data-purpose" (purpose_name purpose)
               ; role_attr
               ; Vdom.Attr.create "style" scrim_style
               ; Sheet_hook.attr
                   ~is_open
                   ~has_scrim
                   ~should_measure:(is_open && Option.is_none state.resting && Option.is_none state.drag)
                   ~is_inline:false
                   ~final_focus_id
                   ~on_measured
               ; (* A click that lands on the dialog element itself is a click on
                    ::backdrop: the sheet sits inside it, so target and
                    currentTarget differ for anything the user actually aimed
                    at. *)
                 Vdom.Attr.on_click (fun ev ->
                   if phys_equal (Js.Unsafe.get ev "target") (Js.Unsafe.get ev "currentTarget")
                   then (
                     match purpose with
                     | Info when has_scrim -> on_open_change false
                     | Form | Required | Info -> Effect.Many [])
                   else Effect.Many [])
               ; (* Escape. Required keeps the event: upstream's "never called
                    automatically" purpose. *)
                 Vdom.Attr.on_cancel (fun ev ->
                   Common.prevent_default ev;
                   match purpose with
                   | Required -> Effect.Many []
                   | Info | Form -> on_open_change false)
               ])
          [ positioner ])
;;