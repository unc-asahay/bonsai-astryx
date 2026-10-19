(* Carousel — a horizontal scroll container with edge-fade overflow
   indication and optional prev/next controls.

   Upstream: packages/core/src/Carousel/Carousel.tsx (727 LOC) over
   hooks/useScrollOverflow.ts (152) and hooks/isRtlElement.ts (27).

   The scroll machinery is exactly upstream's: the container measures its own
   scroll geometry (a vdom hook attached to the scroller — the house pattern
   from Scrollable_area's Scroll_hook), reports into a Bonsai.state cell, and
   re-renders the edge-fade/button state as it changes. Buttons and the
   Shift+wheel mapping drive the same native scroll API as upstream, with the
   same RTL sign flip, the same wrap-around arithmetic (overshoot by the full
   scroll width and let the browser clamp), and the same reduced-motion
   behaviour ('auto').

   {2 Recorded divergences}

   - {b Imperative handle} (upstream [handleRef]: scrollNext/scrollPrev/scrollTo
     + canScroll queries) is not modelled: Bonsai exposes no ref/handle API.
     The built-in buttons provide the same scroll semantics, and
     [scrollTo] had no built-in caller upstream; a consumer that needs
     programmatic control can drive the DOM directly.
   - {b Focus handoff}: upstream redirects focus to the opposite button when a
     nav button disables under the user (a post-commit React effect over refs).
     Bonsai has no post-commit effect, so the port accepts the browser default:
     a disabled control is blurred and focus is not redirected. The buttons
     stay mounted and are removed from the tab order while disabled, matching
     upstream's visibility/disabled contract.
   - {b Top layer}: upstream renders the button overlay on the popup top layer
     (useLayer) so it escapes ancestor clipping. The port renders the overlay
     inline, absolutely positioned over the root with the same visual contract
     (centred pills at each edge, hidden-at-edge behavior). Carousels mounted
     inside a container that clips absolutely-positioned children get the
     overlay clipped — the port documents this instead of shipping a second
     layer protocol for it.
   - {b i18n}: the three labels (region label, scroll-left, scroll-right) are
     English strings; upstream reads them from its translator with the same
     English fallbacks.

   {2 Accessibility}

   Same contract as upstream: the root is a labelled region with
   [aria-roledescription="carousel"], each item wrapper is a group with
   [aria-roledescription="slide"] named [Slide N of M] on the 1-based item
   number, and the scroller is keyboard focusable (tabIndex 0). Adds
   [data-astryx-*] attributes for the showcase and tests, per house style. *)

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

(* The measurement + listener hook for the scroller. Attaches to the scroller
   element, measures immediately on mount, and re-measures on every signal
   that can change the geometry (scroll, resize, ResizeObserver, mutations,
   load, transitions). Reports only on change, so a measurement that lands on
   the same state does not re-render. Teardown is one JS closure. *)
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

      let sexp_of_t _ = Sexp.Atom "carousel-overflow"

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
    Vdom.Attr.create_hook "astryx-carousel-overflow" (Hook.create { T.Input.on_measured })
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

let scroller_of (ev : 'a Js.t) : Dom_html.element Js.t option =
  (* The click's currentTarget is the nav button, which is not the scroller;
     the scroller is a sibling inside the same root. Find it via the root, so
     multiple carousels on one page stay independent. *)
  let btn : Dom_html.element Js.t = Js.Unsafe.coerce (Common.prop ev "currentTarget") in
  let found =
    Js.Unsafe.meth_call btn "closest" [| Js.Unsafe.inject (Js.string ".astryx-carousel") |]
  in
  match Js.Opt.to_option found with
  | None -> None
  | Some root ->
    let node =
      Js.Unsafe.meth_call
        root
        "querySelector"
        [| Js.Unsafe.inject (Js.string ".astryx-carousel__scroller") |]
    in
    Js.Opt.to_option node
;;

let slide (index : int) (total : int) (item : Vdom.Node.t) : Vdom.Node.t =
  Vdom.Node.div
    ~attrs:
      (Common.Attr.class_ [ "astryx-carousel__item" ]
       @ [ Vdom.Attr.create "role" "group"
         ; Vdom.Attr.create "aria-roledescription" "slide"
         ; Vdom.Attr.create
             "aria-label"
             (sprintf "Slide %d of %d" (index + 1) total)
         ])
    [ item ]
;;

let scroll_click ~has_loop ~overflow ~dir () =
  Vdom.Attr.on_click (fun ev ->
    match scroller_of ev with
    | None -> Effect.Ignore
    | Some scroller ->
      ignore
        (Js.Unsafe.fun_call
           scroll_by_js
           [| Js.Unsafe.inject scroller
            ; Js.Unsafe.inject dir
            ; Js.Unsafe.inject (Js.bool has_loop)
            ; Js.Unsafe.inject (Js.bool overflow.start)
            ; Js.Unsafe.inject (Js.bool overflow.end_)
            ; Js.Unsafe.inject (Js.bool overflow.has)
            |]);
      Effect.Ignore)
;;

let nav_pill
  ~side
  ~can
  ~label
  ~icon_name
  ~click_attr
  : Vdom.Node.t
  =
  let pill_class =
    [ "astryx-carousel__pill" ]
    @ (if can then [] else [ "astryx-carousel__pill--hidden" ])
  in
  Vdom.Node.div
    ~attrs:
      (Common.Attr.class_
         [ if String.equal side "start"
           then "astryx-carousel__pill--start"
           else "astryx-carousel__pill--end"
         ])
    [ Vdom.Node.div
        ~attrs:(Common.Attr.class_ pill_class)
        [ Button.view
            ~label
            ~variant:Button.Ghost
            ~size:Button.Sm
            ~is_icon_only:true
            ~is_disabled:(not can)
            ~icon:
              (Icon.view
                 ~size:Icon.Xsm
                 ~attrs:(Common.Attr.class_ [ "astryx-carousel__nav-icon" ])
                 ~name:icon_name
                 ())
            ~attrs:
              [ Vdom.Attr.create "data-astryx-nav" side
              ; click_attr
              ]
            [] ]
      ]
;;

let view_inner
  ?id
  ?(attrs = [])
  ~gap
  ~has_buttons
  ~has_edge_fade
  ~has_loop
  ~has_snap
  ?padding
  ~aria_label
  ~(overflow : overflow)
  ~hook_attr
  ~items
  ()
  =
  let can_scroll_start = (has_loop && overflow.has) || overflow.start in
  let can_scroll_end = (has_loop && overflow.has) || overflow.end_ in
  let fade_mode =
    if not has_edge_fade
    then None
    else if (has_loop && overflow.has) || (overflow.start && overflow.end_)
    then Some "both"
    else if overflow.start
    then Some "start"
    else if overflow.end_
    then Some "end"
    else None
  in
  let controls =
    if not has_buttons
    then []
    else
      [ Vdom.Node.div
          ~attrs:
            (Common.Attr.class_ [ "astryx-carousel__controls" ]
             @ [ Vdom.Attr.create "data-astryx-controls" "" ])
          [ nav_pill
              ~side:"start"
              ~can:can_scroll_start
              ~label:"Scroll left"
              ~icon_name:"chevronLeft"
              ~click_attr:(scroll_click ~has_loop ~overflow ~dir:(-1) ())
          ; nav_pill
              ~side:"end"
              ~can:can_scroll_end
              ~label:"Scroll right"
              ~icon_name:"chevronRight"
              ~click_attr:(scroll_click ~has_loop ~overflow ~dir:1 ())
          ] ]
  in
  Vdom.Node.div
    ~attrs:
      (Common.Attr.class_ [ "astryx-carousel" ]
       @ [ Vdom.Attr.create "role" "region"
         ; Vdom.Attr.create "aria-roledescription" "carousel"
         ; Vdom.Attr.create "aria-label" aria_label
         ; Vdom.Attr.create "id" (Option.value id ~default:"astryx-carousel")
         ]
       @ Common.Attr.data "component" "Carousel"
       @ attrs)
    ( [ Vdom.Node.div
        ~attrs:
          (Common.Attr.class_ [ "astryx-carousel__scroller" ]
           @ [ Vdom.Attr.create "tabindex" "0" ]
           @ Common.Attr.data "gap" (Common.Spacing.step gap)
           @ (match padding with
             | Some p -> Common.Attr.data "padding" (Common.Spacing.step p)
             | None -> [])
           @ (match fade_mode with
             | Some mode -> Common.Attr.data "fade" mode
             | None -> [])
           @ (if has_snap then Common.Attr.data "snap" "" else [])
           @ [ Vdom.Attr.on_wheel (fun ev ->
                  let scroller : Dom_html.element Js.t =
                    Js.Unsafe.coerce (Common.prop ev "currentTarget")
                  in
                  ignore
                    (Js.Unsafe.fun_call wheel_js [| Js.Unsafe.inject scroller; Js.Unsafe.inject ev |]);
                  Effect.Ignore)
             ]
           @ [ hook_attr ])
        (List.mapi items ~f:(fun i item -> slide i (List.length items) item))
      ] @ controls )

let view
  ?id
  ?attrs
  ?(gap = Common.Spacing.S1)
  ?(has_buttons = true)
  ?(has_edge_fade = true)
  ?(has_loop = false)
  ?(has_snap = false)
  ?padding
  ?(aria_label = "Carousel")
  ~items
  (graph : Bonsai.graph)
  =
  let overflow, set_overflow = Bonsai.state inactive_overflow graph in
  let hook_attr =
    Bonsai.map set_overflow ~f:(fun set_overflow ->
      Overflow_hook.attr ~on_measured:(fun v -> set_overflow v) ())
  in
  Bonsai.map2
    overflow
    hook_attr
    ~f:(fun overflow hook_attr ->
      view_inner
        ?id
        ?attrs
        ~gap
        ~has_buttons
        ~has_edge_fade
        ~has_loop
        ~has_snap
        ?padding
        ~aria_label
        ~overflow
        ~hook_attr
        ~items
        ())
;;
