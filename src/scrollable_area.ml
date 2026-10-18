(* ScrollableArea — a native scroll viewport with axis-aware accessibility.

   Upstream: packages/core/src/ScrollableArea/ScrollableArea.tsx (260 LOC) over
   hooks/useScrollableArea.ts (the component passes [owner: 'viewport'], so
   keyboard delegation — scrollKeyboardDelegation.ts — is never attached and is
   NOT in this port's scope; see scrollable_area.mli for the recorded
   divergences).

   The component is stateful in one thing: the measured state of the viewport.
   Like Overflow_list, the measurement is a vdom hook attached to the viewport
   element (the only DOM work not triggered by an event), and the hook reports
   into a [Bonsai.state] cell. The initial state before the first measurement
   is inactive: no tabindex, no scrollable flags, both axes at start/end.

   The geometry arithmetic is [Scroll_math] — pure, mirroring upstream's
   scrollGeometry.ts. This module owns: the axis policy (what is requested vs
   inactive), the physical decomposition of the overflow style (upstream
   computes physical overflowX/overflowY from the writing-mode mapping), and
   the DOM contract (data-scroll-* attributes, tabindex, role, aria-label). *)

open! Core
open! Bonsai_web
open Js_of_ocaml

type axis =
  [ `Block
  | `Inline
  | `Both
  ]
[@@deriving equal, sexp_of]

type role =
  [ `Group
  | `Region
  ]
[@@deriving equal, sexp_of]

type overscroll =
  [ `Allow
  | `Contain
  ]
[@@deriving equal, sexp_of]

type sticky_containment =
  [ `When_scrollable
  | `Always
  ]
[@@deriving equal, sexp_of]

let axis_name = function `Block -> "block" | `Inline -> "inline" | `Both -> "both"
let role_name = function `Group -> "group" | `Region -> "region"

let axis_requests_inline = function
  | `Inline | `Both -> true
  | `Block -> false
;;

let axis_requests_block = function
  | `Block | `Both -> true
  | `Inline -> false
;;

(* The hook's report: the measured state plus the writing-mode mapping that
   turns it into physical CSS, and whether the viewport itself currently holds
   focus (upstream reads [document.activeElement === viewport] at render time;
   the port lets the hook report it, because the port's render is not allowed
   to read the DOM). *)
type measured =
  { inline : Scroll_math.axis_state
  ; block : Scroll_math.axis_state
  ; overflow_inline : bool
  ; overflow_block : bool
  ; mapping : Scroll_math.mapping
  ; focused : bool
  }
[@@deriving equal, sexp_of]

let inactive_measured =
  { inline = Scroll_math.inactive_axis_state
  ; block = Scroll_math.inactive_axis_state
  ; overflow_inline = false
  ; overflow_block = false
  ; mapping = Scroll_math.mapping_of ~writing_mode:"horizontal-tb" ~direction:"ltr"
  ; focused = false
  }
;;

(* The measurement hook. Same shape as Common.Overflow_hook: it attaches to the
   element it measures (the viewport), measures immediately on mount, and
   re-measures on every signal that can change the geometry. It reports only on
   change, so a measurement that lands on an unchanged state does not re-render.
   The teardown is one JS closure that removes every listener and disconnects
   every observer, so destroy cannot leak a list of observers. *)
module Scroll_hook = struct
  module T = struct
    module State = struct
      type t =
        { (* The teardown closure returned by the setup JS; [None] only between
             create and mount. *)
          mutable teardown : Js.Unsafe.any option
        ; (* The last answer reported, which is what makes the report
             conditional. *)
          mutable last : measured option
        }

      let create () = { teardown = None; last = None }
    end

    module Input = struct
      type t =
        { axis : axis
        ; on_measured : (measured -> unit Effect.t[@sexp.opaque])
        }

      let sexp_of_t { axis; _ } = Sexp.List [ Sexp.Atom (axis_name axis) ]

      let combine left right =
        { left with
          on_measured =
            (fun value -> Effect.Many [ left.on_measured value; right.on_measured value ])
        }
      ;;
    end

    (* One JS read for all the geometry. Reading it as a JS object and pulling
       fields by name is a single crossing instead of thirteen, and it keeps the
       arithmetic (which axis, which extent, which edge) in [Scroll_math] where
       it is testable. *)
    let measure_js =
      Js.Unsafe.eval_string
        "(function (el) { var cs = getComputedStyle(el); return { cw: el.clientWidth, \
         ch: el.clientHeight, sw: el.scrollWidth, sh: el.scrollHeight, sl: \
         el.scrollLeft, st: el.scrollTop, ox: cs.overflowX, oy: cs.overflowY, wm: \
         cs.writingMode, dir: cs.direction, disp: cs.display, conn: el.isConnected, \
         foc: (el.ownerDocument || document).activeElement === el }; })"
    ;;

    (* Physical extents for one logical axis, per the mapping. On an unrequested
       axis the answer is the inactive state: such an axis is never scrollable
       and reports both edges trivially at rest — upstream's INACTIVE_AXIS_STATE,
       which still emits data-scroll-inline-start/end and block-start/end. *)
    let measure (input : Input.t) node =
      let el : Dom_html.element Js.t = Js.Unsafe.coerce node in
      let raw = Js.Unsafe.fun_call measure_js [| Js.Unsafe.inject el |] in
      let int_ f = (Js.Unsafe.get raw f : int) in
      let str f = Js.to_string (Js.Unsafe.get raw f : Js.js_string Js.t) in
      let bool_ f = Js.to_bool (Js.Unsafe.get raw f) in
      if not (bool_ "conn")
         || String.equal (str "disp") "none"
         || int_ "cw" <= 0
         || int_ "ch" <= 0
      then None
      else
        let mapping =
          Scroll_math.mapping_of ~writing_mode:(str "wm") ~direction:(str "dir")
        in
        let extents logical =
          let physical =
            match logical with `Inline -> mapping.inline | `Block -> mapping.block
          in
          match physical with
          | Scroll_math.X ->
            int_ "cw", int_ "sw", int_ "sl", str "ox", mapping.inline_reversed
          | Scroll_math.Y ->
            int_ "ch", int_ "sh", int_ "st", str "oy", mapping.block_reversed
        in
        let overflow_of logical =
          let client, content, _offset, _overflow, _rev = extents logical in
          Scroll_math.overflow_geometry ~client_extent:client ~content_extent:content
        in
        let state_of logical =
          let client, content, offset, overflow, reversed = extents logical in
          Scroll_math.scroll_axis
            ~client_extent:client
            ~content_extent:content
            ~offset
            ~overflow
            ~reversed
        in
        Some
          { inline =
              (if axis_requests_inline input.axis then state_of `Inline
               else Scroll_math.inactive_axis_state)
          ; block =
              (if axis_requests_block input.axis then state_of `Block
               else Scroll_math.inactive_axis_state)
          ; overflow_inline =
              (if axis_requests_inline input.axis then overflow_of `Inline else false)
          ; overflow_block =
              (if axis_requests_block input.axis then overflow_of `Block else false)
          ; mapping
          ; focused = bool_ "foc"
          }
    ;;

    let report (input : Input.t) state value =
      match state.State.last with
      | Some last when Poly.equal last value -> ()
      | _ ->
        state.last <- Some value;
        Effect.Expert.handle_non_dom_event_exn (input.on_measured value)
    ;;

    let measure_and_report (input : Input.t) state node =
      (match measure input node with
       | Some value -> report input state value
       | None ->
         (* Unmeasurable (hidden, disconnected, zero-size): keep the last valid
            state, as upstream does — an unknown viewport is not a fitting one. *)
         ())
    ;;

    let init _ _ = State.create ()

    let on_mount input state node =
      measure_and_report input state node;
      let js =
        Js.Unsafe.eval_string
          "(function (el, fire) { var disposers = []; var raf = (typeof \
           requestAnimationFrame === 'undefined') ? null : requestAnimationFrame; \
           var frame = null; var schedule = function () { if (frame != null) return; \
           if (raf) frame = raf(function () { frame = null; fire(); }); else fire(); }; \
           var content = el.firstElementChild; \
           var on = function (target, type, fn, opts) { target.addEventListener(type, \
           fn, opts); disposers.push(function () { target.removeEventListener(type, \
           fn, opts); }); }; \
           on(el, 'scroll', schedule, { passive: true }); on(window, 'resize', \
           schedule); on(el, 'focus', schedule); on(el, 'blur', schedule); \
           if (typeof ResizeObserver !== 'undefined') { var ro = new \
           ResizeObserver(schedule); ro.observe(el); if (content) ro.observe(content); \
           disposers.push(function () { ro.disconnect(); }); } \
           if (typeof MutationObserver !== 'undefined') { var mo = new \
           MutationObserver(schedule); mo.observe(el, { attributes: true, \
           attributeFilter: ['class', 'dir', 'hidden', 'style'] }); if (content) \
           mo.observe(content, { attributes: true, attributeFilter: ['class', 'dir', \
           'hidden', 'style'], characterData: true, childList: true, subtree: true \
           }); var a = el.parentElement; while (a) { mo.observe(a, { attributes: true, \
           attributeFilter: ['class', 'dir', 'hidden', 'style'] }); a = \
           a.parentElement; } disposers.push(function () { mo.disconnect(); }); } \
           if (content) { on(content, 'load', schedule, true); \
           on(content, 'transitionend', schedule); on(content, 'animationend', \
           schedule); } on(el, 'transitionend', schedule); on(el, 'animationend', \
           schedule); return function () { for (var i = 0; i < disposers.length; i++) \
           disposers[i](); }; })"
      in
      let fire = Js.wrap_callback (fun () -> measure_and_report input state node) in
      state.State.teardown
        <- Some (Js.Unsafe.fun_call js [| Js.Unsafe.inject (Js.Unsafe.coerce node); Js.Unsafe.inject fire |])
    ;;

    let on_mount = `Schedule_immediately_after_this_dom_patch_completes on_mount

    let update ~old_input:_ ~new_input state node = measure_and_report new_input state node
    let destroy _ state _ =
      (match state.State.teardown with
       | None -> ()
       | Some teardown ->
         let (_ : unit) = Js.Unsafe.fun_call teardown [||] in
         ());
      state.State.teardown <- None
    ;;
  end

  module Hook = Vdom.Attr.Hooks.Make (T)

  let attr ~axis ~on_measured () =
    Vdom.Attr.create_hook "astryx-scrollable-area" (Hook.create { T.Input.axis; on_measured })
  ;;
end

(* The overflow policy, mirroring upstream's getViewportProps arithmetic exactly:
   - a viewport "contains sticky" while an axis overflows, or always when asked;
   - a containing viewport scrolls on the axes that overflow (or on all
     requested axes when containment is unconditional), and hides the rest;
   - a non-containing viewport is clipped on both axes.
   The physical split is upstream's too: logical overflow is decomposed into
   overflowX/overflowY through the writing-mode mapping. *)
let overflow_pairs (m : measured) ~axis ~sticky_containment =
  let mapping = m.mapping in
  let requested_x =
    (axis_requests_inline axis && Poly.equal mapping.inline Scroll_math.X)
    || (axis_requests_block axis && Poly.equal mapping.block Scroll_math.X)
  in
  let requested_y =
    (axis_requests_inline axis && Poly.equal mapping.inline Scroll_math.Y)
    || (axis_requests_block axis && Poly.equal mapping.block Scroll_math.Y)
  in
  let overflowing_x =
    (m.overflow_inline && Poly.equal mapping.inline Scroll_math.X)
    || (m.overflow_block && Poly.equal mapping.block Scroll_math.X)
  in
  let overflowing_y =
    (m.overflow_inline && Poly.equal mapping.inline Scroll_math.Y)
    || (m.overflow_block && Poly.equal mapping.block Scroll_math.Y)
  in
  let contains_sticky =
    overflowing_x || overflowing_y || Poly.equal sticky_containment `Always
  in
  let scrolls_on_x =
    match sticky_containment with
    | `Always -> requested_x
    | `When_scrollable -> overflowing_x
  in
  let scrolls_on_y =
    match sticky_containment with
    | `Always -> requested_y
    | `When_scrollable -> overflowing_y
  in
  let overflow_x =
    if contains_sticky then (if scrolls_on_x then "auto" else "hidden") else "clip"
  in
  let overflow_y =
    if contains_sticky then (if scrolls_on_y then "auto" else "hidden") else "clip"
  in
  [ "overflow-x", overflow_x; "overflow-y", overflow_y ]
;;

(* Overscroll is behavior the viewport owns on its REQUESTED axes only: a
   contained axis is 'contain', an allowed one is 'auto'; an unrequested axis is
   left alone (upstream preserves the caller's value; the port has no caller
   style to preserve, so unrequested axes are simply not emitted). *)
let overscroll_pairs (m : measured) ~axis ~overscroll =
  let mapping = m.mapping in
  let emit physical scrollable =
    (match physical with
     | Scroll_math.X ->
       "overscroll-behavior-x"
       , (if Poly.equal overscroll `Contain && scrollable then "contain" else "auto")
     | Scroll_math.Y ->
       "overscroll-behavior-y"
       , (if Poly.equal overscroll `Contain && scrollable then "contain" else "auto"))
  in
  let pairs =
    if axis_requests_inline axis
    then [ emit mapping.inline m.inline.is_scrollable ]
    else []
  in
  let pairs =
    if axis_requests_block axis
    then pairs @ [ emit mapping.block m.block.is_scrollable ]
    else pairs
  in
  pairs
;;

let view
  ?(attrs = [])
  ?(id = "astryx-scrollable-area")
  ?(axis = `Block)
  ~label
  ?(role = `Group)
  ?(overscroll = `Allow)
  ?width
  ?height
  ?max_width
  ?min_height
  ?(sticky_containment = `When_scrollable)
  ?(padding = Common.Spacing.S0)
  ?padding_inline
  ?padding_inline_start
  ?padding_inline_end
  ?padding_block
  ?padding_block_start
  ?padding_block_end
  ?(is_full_bleed = false)
  (graph : Bonsai.graph)
  children
  =
  let measured, set_measured = Bonsai.state inactive_measured graph in
  (* The setter is itself a [Bonsai.t], so the hook's attribute — and therefore
     the measured element — is built under a map rather than called directly,
     exactly as Overflow_list does. *)
  let measure_attr =
    Bonsai.map set_measured ~f:(fun set_measured ->
      Scroll_hook.attr ~axis ~on_measured:(fun m -> set_measured m) ())
  in
  let size name value = name, Option.value_map value ~default:"" ~f:Common.Size_value.to_css in
  let pad name value = name, Option.value_map value ~default:"" ~f:Common.Spacing.var in
  let container_pad name value = name, Option.value_map value ~default:"" ~f:Common.Spacing.var in
  (* Upstream's stylex precedence: the most specific prop wins per side.
     padding < padding_inline < padding_inline_start/end on the inline axis, and
     the same on the block axis. The container vars mirror it side by side, so
     descendants that escape to full-bleed see the same resolved value. *)
  let inline_start = Option.value padding_inline_start ~default:(Option.value padding_inline ~default:padding) in
  let inline_end = Option.value padding_inline_end ~default:(Option.value padding_inline ~default:padding) in
  let block_start = Option.value padding_block_start ~default:(Option.value padding_block ~default:padding) in
  let block_end = Option.value padding_block_end ~default:(Option.value padding_block ~default:padding) in
  let content_style =
    [ pad "padding-inline-start" (Some inline_start)
    ; pad "padding-inline-end" (Some inline_end)
    ; pad "padding-block-start" (Some block_start)
    ; pad "padding-block-end" (Some block_end)
    ; container_pad "--container-padding-inline-start" (Some inline_start)
    ; container_pad "--container-padding-inline-end" (Some inline_end)
    ; container_pad "--container-padding-block-start" (Some block_start)
    ; container_pad "--container-padding-block-end" (Some block_end)
    ]
  in
  let viewport (m : measured) (hook_attr : Vdom.Attr.t) =
    let has_effective_axis = m.inline.is_scrollable || m.block.is_scrollable in
    let tabindex =
      if has_effective_axis
      then [ Vdom.Attr.create "tabindex" "0" ]
      else if m.focused
      then [ Vdom.Attr.create "tabindex" "-1" ]
      else []
    in
    let scrollable (name : string) (axis_state : Scroll_math.axis_state) =
      if axis_state.is_scrollable
      then [ Vdom.Attr.create (sprintf "data-scrollable-%s" name) "true" ]
      else []
    in
    let edge (name : string) (axis_state : Scroll_math.axis_state) =
      (* Inactive axes are at both edges (atStart/atEnd true) and still emit,
         exactly as upstream: state is INACTIVE_AXIS_STATE with both edges at
         rest. The scrollable-* flag is what distinguishes them. *)
      List.filter_opt
        [ (if axis_state.at_start then Some (Vdom.Attr.create (sprintf "data-scroll-%s-start" name) "true") else None)
        ; (if axis_state.at_end then Some (Vdom.Attr.create (sprintf "data-scroll-%s-end" name) "true") else None)
        ]
    in
    let classes =
      [ "astryx-scrollable-area" ]
      @ (if is_full_bleed then [ "astryx-scrollable-area--full-bleed" ] else [])
    in
    let size_style =
      [ size "width" width
      ; size "height" height
      ; size "max-width" max_width
      ; size "min-height" min_height
      ]
    in
    let hook_data =
      Vdom.Attr.create "data-scroll-axis" (axis_name axis)
      :: (scrollable "inline" m.inline @ scrollable "block" m.block)
      @ (edge "inline" m.inline @ edge "block" m.block)
    in
    let content_attrs =
      Common.Attr.class_
        ([ "astryx-scrollable-area__content" ]
         @ (if Poly.equal axis `Block
           then []
           else [ "astryx-scrollable-area__content--inline-overflow" ]))
      @ [ Vdom.Attr.create "data-scroll-content" "" ]
      @ Common.Attr.style content_style
    in
    Vdom.Node.div
      ~attrs:
        (Common.Attr.class_ classes
         @ [ Vdom.Attr.create "id" id ]
         @ Common.Attr.data "component" "ScrollableArea"
         @ Common.Attr.data "axis" (axis_name axis)
         @ hook_data
         @ Common.Attr.role (role_name role)
         @ Common.Attr.aria "label" label
         @ tabindex
         @ attrs
         @ Common.Attr.style (size_style @ overflow_pairs m ~axis ~sticky_containment @ overscroll_pairs m ~axis ~overscroll)
         @ [ hook_attr ])
      [ Vdom.Node.div ~attrs:content_attrs children ]
  in
  Bonsai.map2 measured measure_attr ~f:viewport
;;
