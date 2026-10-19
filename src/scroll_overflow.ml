(* Scroll_overflow — shared scroll-geometry measurement for horizontal
   scroll containers (Carousel, TabList, ...).

   Upstream: hooks/useScrollOverflow.ts and hooks/isRtlElement.ts. Both
   consumers (Carousel, TabList) track whether a strip overflows, whether it
   is scrolled to the start, and whether it is scrolled to the end, plus the
   two scroll drivers (the nav-button scroll with RTL sign flip / wrap-around
   / reduced-motion arithmetic, and the Shift+wheel mapping).

   The measurement + listener hook mirrors the house pattern from
   Scrollable_area's hook: measures immediately on mount, and re-measures on
   every signal that can change the geometry (scroll, resize, ResizeObserver,
   mutations, load, transitions). Reports only on change, so a measurement
   that lands on the same state does not re-render. Teardown is one JS
   closure. *)

open! Core
open! Bonsai_web
open Js_of_ocaml

type overflow =
  { start : bool
  ; end_ : bool
  ; has : bool
  }
[@@deriving equal, sexp_of]

let inactive_overflow = { start = false; end_ = false; has = false }

module Overflow_hook = struct
  module T = struct
    module State = struct
      type t =
        { mutable teardown : Js.Unsafe.any option
        ; mutable last : overflow option
        }

      let create () = { teardown = None; last = None }
    end

    module Input = struct
      type t = { on_measured : (overflow -> unit Effect.t)[@sexp.opaque] }

      let sexp_of_t _ = Sexp.Atom "scroll-overflow"

      let combine left right =
        { on_measured =
            (fun value -> Effect.Many [ left.on_measured value; right.on_measured value ])
        }
      ;;
    end

    let measure (node : Dom_html.element Js.t) : overflow option =
      (* One JS read for all the geometry is a single crossing. The 1px
         tolerance is upstream's: it absorbs sub-pixel layout noise and the
         clip/rounding of fractional positions. *)
      let js =
        Js.Unsafe.eval_string
          "(function (el) { return { sl: el.scrollLeft, sw: el.scrollWidth, cw: \
           el.clientWidth, conn: el.isConnected }; })"
      in
      let raw = Js.Unsafe.fun_call js [| Js.Unsafe.inject node |] in
      let int_ f = (Js.Unsafe.get raw f : int) in
      let conn = Js.to_bool (Js.Unsafe.get raw "conn") in
      if not conn || int_ "cw" <= 0
      then None
      else
        let tolerance = 1 in
        let sl = int_ "sl" in
        let sw = int_ "sw" in
        let cw = int_ "cw" in
        let max_scroll = sw - cw in
        Some
          { start = abs sl > tolerance
          ; end_ = abs sl < max_scroll - tolerance
          ; has = sw > cw + tolerance
          }
    ;;

    let report (input : Input.t) state value =
      match state.State.last with
      | Some last when Poly.equal last value -> ()
      | _ ->
        state.State.last <- Some value;
        Effect.Expert.handle_non_dom_event_exn (input.on_measured value)
    ;;

    let measure_and_report (input : Input.t) state node =
      match measure node with
      | Some value -> report input state value
      | None -> ()
    ;;

    let init _ _ = State.create ()

    let on_mount input state node =
      measure_and_report input state node;
      (* Same coverage as Scrollable_area's listener set: the geometry can
         change from a scroll, a resize, a reflow (RO), a styling/class/dir
         change (MutationObserver up the whole ancestor chain), or a loaded
         image/transition. A scroll is measured even when the container is
         hidden; a hidden container's layout read answers zeros anyway and the
         report keeps the last valid state. *)
      let js =
        Js.Unsafe.eval_string
          "(function (el, fire) { var disposers = []; var raf = (typeof \
           requestAnimationFrame === 'undefined') ? null : requestAnimationFrame; \
           var frame = null; var schedule = function () { if (frame != null) return; \
           if (raf) frame = raf(function () { frame = null; fire(); }); else fire(); }; \
           var content = el.firstElementChild; var on = function (target, type, fn, \
           opts) { target.addEventListener(type, fn, opts); disposers.push(function () \
           { target.removeEventListener(type, fn, opts); }); }; on(el, 'scroll', \
           schedule, { passive: true }); on(window, 'resize', schedule); if (typeof \
           ResizeObserver !== 'undefined') { var ro = new ResizeObserver(schedule); \
           ro.observe(el); if (content) ro.observe(content); disposers.push(function () \
           { ro.disconnect(); }); } if (typeof MutationObserver !== 'undefined') { var \
           mo = new MutationObserver(schedule); mo.observe(el, { attributes: true, \
           attributeFilter: ['class', 'dir', 'hidden', 'style'] }); if (content) \
           mo.observe(content, { attributes: true, attributeFilter: ['class', 'dir', \
           'hidden', 'style'], characterData: true, childList: true, subtree: true }); \
           var a = el.parentElement; while (a) { mo.observe(a, { attributes: true, \
           attributeFilter: ['class', 'dir', 'hidden', 'style'] }); a = a.parentElement; \
           } disposers.push(function () { mo.disconnect(); }); } if (content) { \
           on(content, 'load', schedule, true); on(content, 'transitionend', \
           schedule); on(content, 'animationend', schedule); } on(el, \
           'transitionend', schedule); on(el, 'animationend', schedule); return function \
           () { for (var i = 0; i < disposers.length; i++) disposers[i](); }; })"
      in
      let fire = Js.wrap_callback (fun () -> measure_and_report input state node) in
      state.State.teardown
        <- Some (Js.Unsafe.fun_call js [| Js.Unsafe.inject node; Js.Unsafe.inject fire |])
    ;;

    let on_mount = `Schedule_immediately_after_this_dom_patch_completes on_mount

    let update ~old_input:_ ~new_input state node = measure_and_report new_input state node
    let destroy _ state _ =
      (match state.State.teardown with
       | None -> ()
       | Some teardown -> ignore (Js.Unsafe.fun_call teardown [||] : unit));
      state.State.teardown <- None
    ;;
  end

  module Hook = Vdom.Attr.Hooks.Make (T)

  let attr ~on_measured () =
    Vdom.Attr.create_hook "astryx-scroll-overflow" (Hook.create { T.Input.on_measured })
  ;;
end

(* One crossing for the whole button/wrap arithmetic: RTL sign, wrap-around
   overshoot, step size (one viewport minus half the first item, at least one
   item), reduced-motion behaviour. Straight mirror of upstream's scrollBy. *)
let scroll_by_js =
  Js.Unsafe.eval_string
    "(function (el, logicalDir, wrap, atStart, atEnd, hasOverflow) { if (!el) \
     return; if (typeof el.scrollBy !== 'function') return; var rtl = \
     getComputedStyle(el).direction === 'rtl'; var sign = rtl ? -1 : 1; var rm = \
     (typeof window !== 'undefined' && typeof window.matchMedia === 'function' \
     && window.matchMedia('(prefers-reduced-motion: reduce)').matches); var \
     behavior = rm ? 'auto' : 'smooth'; if (wrap && hasOverflow) { var atEdge = \
     (logicalDir === 1 && !atEnd) || (logicalDir === -1 && !atStart); if (atEdge) \
     { el.scrollBy({ left: sign * -logicalDir * el.scrollWidth, behavior: behavior }); \
     return; } } var first = el.firstElementChild; var itemWidth = first ? \
     first.offsetWidth : 0; var amount = el.clientWidth - itemWidth * 0.5; \
     el.scrollBy({ left: sign * logicalDir * Math.max(amount, itemWidth), \
     behavior: behavior }); })"
;;

(* Shift + vertical wheel => horizontal scroll, and only then: the longstanding
   mouse convention. Trackpads emit deltaX natively and are never intercepted. *)
let wheel_js =
  Js.Unsafe.eval_string
    "(function (el, ev) { if (!ev.shiftKey || ev.deltaY === 0 || ev.deltaX !== 0) \
     return; if (el.scrollWidth <= el.clientWidth) return; ev.preventDefault(); \
     el.scrollBy({ left: ev.deltaY, behavior: 'auto' }); })"
;;

(* Upstream's isRtlElement: the element's computed direction, lazily (the
   caller drives this on keydown or click, never on render). Null-safe. *)
let is_rtl (el : Dom_html.element Js.t) : bool =
  let js = Js.Unsafe.eval_string "(function (el) { return el && getComputedStyle(el).direction === 'rtl'; })" in
  (Js.Unsafe.fun_call js [| Js.Unsafe.inject el |] : bool)
;;
