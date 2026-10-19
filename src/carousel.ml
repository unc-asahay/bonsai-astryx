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
           Scroll_overflow.scroll_by_js
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
                    (Js.Unsafe.fun_call Scroll_overflow.wheel_js [| Js.Unsafe.inject scroller; Js.Unsafe.inject ev |]);
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
      Scroll_overflow.Overflow_hook.attr
      ~on_measured:(fun v ->
        set_overflow { start = v.start; end_ = v.end_; has = v.has })
      ())
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
