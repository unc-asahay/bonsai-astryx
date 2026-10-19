(* MobileNav — the mobile navigation drawer.

   Upstream: packages/core/src/MobileNav/MobileNav.tsx (709 LOC) and
   MobileNavToggle.tsx (the AppShell-aware hamburger, which needs the
   AppShell context this port does not have yet).

   The drawer is a native <dialog> opened with showModal(): the top layer, the
   inert page behind it, the focus trap and the ::backdrop are the browser's
   and are not written here. What the port owns is the rest of upstream's
   contract, and each piece of it exists for a reason upstream also gives:

   - the deferred close, so the slide-out can play before the dialog leaves the
     top layer. The delay is *derived* from the CSS hold rather than assumed,
     because the hold is a theme value and a close that lands on the hold's
     boundary leaves the page inert (#4290 upstream);
   - the focus restoration to the element that opened the drawer, which the
     browser does not reliably do — and which has to follow the native close,
     not the value that scheduled it, because the document is inert until then;
   - the side resolution, which reads the trigger's own position while the
     trigger is still the active element;
   - the scroll lock, and the scrollbar gutter that keeps the page from
     jumping sideways when the scrollbar it locked away was taking space;
   - the dismissal paths: the close button, the backdrop click and Escape.

   Named divergences are in mobile_nav.mli. *)

open! Core
open Js_of_ocaml
open! Bonsai_web

module Attr = Common.Attr

(* Which edge the drawer slides from. Upstream's [side]. *)
type side =
  | Start
  | End
  | Auto
(* [Auto] is resolved from the trigger: a toggle in the start half of the
    viewport opens the drawer from the start, anything else from the end. *)

(* The header of the drawer. Upstream's [header] prop is a ReactNode; the
   string case is special because it is rendered as a heading *and* names the
   drawer when no explicit label is given. *)
type header =
  | Title of string
  | Content of Vdom.Node.t

let default_id = "astryx-mobile-nav"
let default_width = 320
let close_label = "Close navigation"
let navigation_label = "Navigation"

(* Upstream's close timing. The longest the drawer waits before closing, and
   the fraction of the hold it closes at, so the close never lands on the
   hold's boundary. *)
let max_close_delay_ms = 250.
let close_within_hold = 0.6

let side_name = function
  | Start -> "start"
  | End -> "end"
  | Auto -> "auto"
;;

(* The side the drawer is at before it resolves one for itself: upstream's
   [useState] starts an auto drawer at the end. *)
let default_side_name = "end"

(* The header's own text, when it has one: a title names the drawer when no
   explicit label is given, and custom content does not. *)
let header_title = function
  | Some (Title text) -> Some text
  | Some (Content _) | None -> None
;;

let min_float a b = if Float.compare a b <= 0 then a else b

(* ---------------------------------------------------------------- durations *)

(* The longest prefix of [s] that reads as a number — JavaScript's
   parseFloat, which upstream's duration parser depends on: a browser
   serialises a computed <time> as "0.41s", and parseFloat("0.41s") is 0.41.
   A plain float parser would read the whole string as unparseable and lose
   every duration the browser actually reports. *)
let parse_leading_float (s : string) : float option =
  let len = String.length s in
  let rec loop i =
    if i <= 0
    then None
    else
      match Float.of_string_opt (String.sub s ~pos:0 ~len:i) with
      | Some value when Float.is_finite value -> Some value
      | Some _ | None -> loop (i - 1)
  in
  loop len
;;

(* The shortest duration in a `transition-duration` list, in ms; [None] if the
   list is unreadable. Upstream exports the same helper for its unit tests,
   and the port keeps it public for the same reason: it is the one piece of
   the close timing that can be checked without a browser. *)
let parse_shortest_duration_ms (value : string) : float option =
  let durations =
    String.split value ~on:','
    |> List.filter_map ~f:(fun part ->
           let trimmed = String.strip part in
           match parse_leading_float trimmed with
           | None -> None
           | Some ms ->
             if String.is_suffix trimmed ~suffix:"ms"
             then Some ms
             else if String.is_suffix trimmed ~suffix:"s"
             then Some (ms *. 1000.)
             else None)
  in
  match durations with
  | [] -> None
  | first :: rest -> Some (List.fold_left rest ~init:first ~f:min_float)
;;

(* ------------------------------------------------------------------ the DOM *)

let call = Common.call
let is_connected = Common.is_connected

(* The JS helpers are evaluated once on the host, not per call — see the
   pure_js_expr block in src/timestamp.ml. *)
let transition_duration_js =
  Js.Unsafe.pure_js_expr
    "(function (el) { return window.getComputedStyle(el).transitionDuration; })"
;;

(* The hold the drawer is rendered for: the display transition's duration, as
   the stylesheet computes it. Upstream reads the same thing, because the hold
   is a theme value — the shipped y2k theme sets it to 250ms — and a close
   scheduled on an assumed hold lands after the drawer stopped being
   rendered. *)
let transition_hold_ms (el : Dom_html.element Js.t) : float option =
  let value : Js.js_string Js.t Js.opt = Js.Unsafe.fun_call transition_duration_js [| Js.Unsafe.inject el |] in
  match Js.Opt.to_option value with
  | None -> None
  | Some text ->
    let text = Js.to_string text in
    if String.is_empty text then None else parse_shortest_duration_ms text
;;

(* How long to wait before closing the native dialog.
   The drawer is only rendered for as long as its display transition runs, and
   a dialog that closes after the drawer stopped being rendered leaves the
   page inert — so the close has to land inside that hold.

   The hold is the display transition's duration, and the display transition
   is deliberately NOT shortened under reduced motion: it is discrete, so a
   long hold animates nothing; it is only the window the close has to land
   inside. Shortening the visible transitions instead leaves this one
   untouched, and the close still lands inside it. *)
let resolve_close_delay_ms (hold : float option) : float =
  match hold with
  | None -> max_close_delay_ms
  | Some hold ->
    if Float.compare hold 0. <= 0 then 0. else min_float max_close_delay_ms (hold *. close_within_hold)
;;

let set_root_overflow (value : string) =
  let root : Dom_html.element Js.t = Js.Unsafe.get Dom_html.document "documentElement" in
  let style = Js.Unsafe.get root "style" in
  Js.Unsafe.set style "overflow" (Js.string value)
;;

let hold_scrollbar_gutter_js =
  Js.Unsafe.pure_js_expr
    {|(function (element) {
        var root = document.documentElement;
        var viewportWidth = root.clientWidth;
        if (viewportWidth === 0) {
          return { settle: function () {}, release: function () {} };
        }
        var previousGutter = root.style.scrollbarGutter;
        var previousPadding = element.style.paddingRight;
        var widthBefore = element.getBoundingClientRect().width;
        var held = false;
        var padded = false;
        var settled = false;
        if (window.innerWidth > viewportWidth) {
          root.style.scrollbarGutter = 'stable';
          held = true;
        }
        return {
          settle: function () {
            if (settled) { return; }
            settled = true;
            var grew = element.getBoundingClientRect().width - widthBefore;
            if (grew <= 0) { return; }
            var existing = parseFloat(window.getComputedStyle(element).paddingRight) || 0;
            element.style.paddingRight = (existing + grew) + 'px';
            padded = true;
          },
          release: function () {
            if (padded) {
              element.style.paddingRight = previousPadding;
              padded = false;
            }
            if (held) {
              root.style.scrollbarGutter = previousGutter;
              held = false;
            }
          }
        };
      })|}
;;

(* Upstream's holdScrollbarGutter. Locking the scroll hides the document's
   scrollbar; where that scrollbar was taking space, hiding it widens the
   layout viewport and the page jumps sideways behind the overlay. The gutter
   is held open instead — but only when the scrollbar really was taking
   space, because holding it on a page that never had one carves out 15px that
   was never reserved. *)
let hold_scrollbar_gutter (element : Dom_html.element Js.t) : Js.Unsafe.any =
  Js.Unsafe.fun_call hold_scrollbar_gutter_js [| Js.Unsafe.inject element |]
;;

let side_from_trigger_js =
  Js.Unsafe.pure_js_expr
    {|(function () {
        var trigger = document.activeElement;
        if (!trigger || trigger === document.body) { return "end"; }
        var rect = trigger.getBoundingClientRect();
        var center = rect.left + rect.width / 2;
        return center < window.innerWidth / 2 ? "start" : "end";
      })|}
;;

(* Which edge the drawer slides from when the side is [Auto]: the trigger's
   own position decides. Upstream reads the focused element, which is the
   trigger that was just clicked — so this is read at the moment the drawer
   opens, before the modal takes the focus away. *)
let side_from_trigger () : string =
  let value : Js.js_string Js.t = Js.Unsafe.fun_call side_from_trigger_js [||] in
  Js.to_string value
;;

let set_side_attr (el : Dom_html.element Js.t) (value : string) =
  ignore
    (Js.Unsafe.meth_call
       el
       "setAttribute"
       [| Js.Unsafe.inject (Js.string "data-astryx-side"); Js.Unsafe.inject (Js.string value) |])
;;

(* ------------------------------------------------------------------ the hook *)

(* The open/close of a native dialog is a DOM operation no event handler can
   perform: no vdom event fires when a caller decides to open the drawer.
   So the value drives it, and the hook puts the element in step — the same
   shape as Dialog's hook, with the drawer's own timing on top.

   The hook is updated on every patch of this element, so the work is done on
   the transitions only: an is_open flip, or a side that changed while the
   drawer is open. *)
module Mobile_nav_hook = struct
  module T = struct
    module State = struct
      type t =
        { (* The element that was focused when the drawer opened; the focus
             goes back to it once the native dialog has closed. *)
          mutable opener : Dom_html.element Js.t option
        ; (* The deferred close. It is a timer rather than a value because the
             close has to land inside the CSS hold, and the hold is measured. *)
          mutable close_timer : Js.Unsafe.any option
        ; (* True between "the value says closed" and "the dialog is closed".
             The reopen path depends on it: a drawer that is reopened while
             its close is pending never closed, so there is nothing to hand
             focus back from, and the close must not fire. *)
          mutable close_pending : bool
        ; mutable gutter : Js.Unsafe.any option
        ; mutable is_locked : bool
        }

      let create () =
        { opener = None
        ; close_timer = None
        ; close_pending = false
        ; gutter = None
        ; is_locked = false
        }
    end

    module Input = struct
      type t =
        { is_open : bool
        ; side : side
        }

      let sexp_of_t { is_open; side } =
        Sexp.List [ Sexp.Atom (Bool.to_string is_open); Sexp.Atom (side_name side) ]
      ;;

      let combine left _ = left
    end

    let cancel_close (state : State.t) =
      match state.close_timer with
      | Some id ->
        Common.clear_timeout id;
        state.close_timer <- None
      | None -> ()
    ;;

    (* The scroll lock, with the gutter taken *before* it: every mutation
       below can hide the scrollbar, and the gutter has to be measured while
       it is still there. *)
    let lock_page (state : State.t) =
      if not state.is_locked
      then (
        state.is_locked <- true;
        let root : Dom_html.element Js.t = Js.Unsafe.get Dom_html.document "documentElement" in
        let gutter = hold_scrollbar_gutter root in
        state.gutter <- Some gutter;
        set_root_overflow "clip";
        ignore (Js.Unsafe.meth_call gutter "settle" [||]))
    ;;

    let unlock_page (state : State.t) =
      if state.is_locked
      then (
        state.is_locked <- false;
        set_root_overflow "";
        match state.gutter with
        | Some gutter ->
          ignore (Js.Unsafe.meth_call gutter "release" [||]);
          state.gutter <- None
        | None -> ())
    ;;

    (* The opener is captured before the modal takes the focus, and only when
       there is a real one: focusing <body> would blur whatever a router moved
       focus to. *)
    let capture_opener (state : State.t) =
      let document = Dom_html.document in
      let active : Dom_html.element Js.t = Js.Unsafe.get document "activeElement" in
      let body : Dom_html.element Js.t = Js.Unsafe.get document "body" in
      state.opener
        <-
          (if
             (not (is_connected active))
             || phys_equal (Js.Unsafe.coerce active) (Js.Unsafe.coerce body)
           then None
           else Some active)
    ;;

    (* Focus is left alone when the opener has since left the DOM: a detached
       node cannot take focus. *)
    let restore_focus (state : State.t) =
      match state.opener with
      | Some opener ->
        state.opener <- None;
        if is_connected opener then ignore (Js.Unsafe.meth_call opener "focus" [||])
      | None -> ()
    ;;

    (* Close the native dialog, then return focus to the element that opened
       it. The order is load-bearing: while the modal dialog holds the top
       layer the rest of the document is inert and focus() on the opener is
       silently dropped. *)
    let finish_close (state : State.t) (el : Dom_html.element Js.t) =
      state.close_timer <- None;
      state.close_pending <- false;
      call el "close";
      restore_focus state
    ;;

    let apply (state : State.t) (input : Input.t) (el : Dom_html.element Js.t) =
      let dom_open = Js.to_bool (Js.Unsafe.get el "open") in
      if input.is_open
      then (
        (* A reopen while the close is still pending finds the dialog open: the
           pending close is cancelled, and the original opener is kept — the
           element that happens to be focused now is inside the drawer, and
           must not replace the one that opened it. *)
        if state.close_pending
        then (
          cancel_close state;
          state.close_pending <- false);
        lock_page state;
        if not dom_open
        then (
          capture_opener state;
          (* The side is resolved here, while the trigger is still the active
             element — upstream reads it in an effect of its own, declared
             before the open effect, for the same reason. *)
          (match input.side with
           | Start -> set_side_attr el "start"
           | End -> set_side_attr el "end"
           | Auto -> set_side_attr el (side_from_trigger ()));
          call el "showModal"))
      else if dom_open && not state.close_pending
      then (
        (* The close is deferred so the slide-out can play: the dialog has to
           stay in the top layer until the transform is most of the way out. *)
        state.close_pending <- true;
        unlock_page state;
        let delay = resolve_close_delay_ms (transition_hold_ms el) in
        state.close_timer <- Some (Common.timeout (fun () -> finish_close state el) delay))
    ;;

    let init _ _ = State.create ()

    let on_mount input state el = apply state input el
    let on_mount = `Schedule_immediately_after_this_dom_patch_completes on_mount

    let update ~old_input:(old_input : Input.t) ~new_input:(new_input : Input.t) (state : State.t) el =
      if not (Bool.equal old_input.is_open new_input.is_open)
      then apply state new_input el
      else if not (Poly.equal old_input.side new_input.side)
      then (
        (* A side that changes while the drawer is open moves it. It must not
           re-arm the pending close: the CSS hold runs from the commit that
           started the slide-out and does not restart, so a fresh full delay
           would land after the drawer had stopped being rendered. *)
        if new_input.is_open
        then
          match new_input.side with
          | Start -> set_side_attr el "start"
          | End -> set_side_attr el "end"
          | Auto -> ())
    ;;

    let destroy _ (state : State.t) el =
      cancel_close state;
      unlock_page state;
      (* A drawer that leaves the DOM while it is still open must not stay
         open: the next showModal() would be skipped and the document would
         stay blocked. *)
      if Js.to_bool (Js.Unsafe.get el "open")
      then (
        call el "close";
        restore_focus state)
    ;;
  end

  module Hook = Vdom.Attr.Hooks.Make (T)

  let attr ~is_open ~side () =
    Vdom.Attr.create_hook "astryx-mobile-nav" (Hook.create { T.Input.is_open; side })
  ;;
end

(* --------------------------------------------------------------------- view *)

let view
  ?(id = default_id)
  ?header
  ?(width = default_width)
  ?(side = Auto)
  ?label
  ?(is_inline = false)
  ?(attrs = [])
  ~is_open
  ~on_open_change
  ~children
  ()
  =
  Bonsai.map2
    (Bonsai.map2 is_open on_open_change ~f:(fun is_open on_open_change -> is_open, on_open_change))
    children
    ~f:(fun (is_open, on_open_change) children ->
           (* The accessible name: the caller's label, then the header's own
              text, then the generic name — upstream's own fallback chain. *)
           let aria_label =
             match label with
             | Some label -> label
             | None -> Option.value (header_title header) ~default:navigation_label
           in
           let header_nodes =
             match header with
             | None -> []
             | Some (Title text) -> [ Heading.view ~level:Heading.H2 [ Vdom.Node.text text ] ]
             | Some (Content node) -> [ node ]
           in
           let close_button =
             Button.view
               ~variant:Button.Ghost
               ~label:close_label
               ~is_icon_only:true
               ~icon:(Icon.view ~color:Icon.Inherit ~name:"close" ())
               ~on_click:(fun _ -> on_open_change false)
               []
           in
           let header_div =
             Vdom.Node.div
               ~attrs:
                 (Attr.class_
                    ([ "astryx-mobile-nav__header" ]
                     @ (if List.is_empty header_nodes
                        then [ "astryx-mobile-nav__header--no-title" ]
                        else [])))
               (header_nodes @ [ close_button ])
           in
           let content_div =
             Vdom.Node.div ~attrs:(Attr.class_ [ "astryx-mobile-nav__content" ]) children
           in
           let drawer =
             Vdom.Node.div
               ~attrs:
                 (Attr.class_ [ "astryx-mobile-nav__drawer" ]
                  @ [ (* The drawer takes the focus when the modal opens, so
                         that a screen reader reads the drawer's name rather
                         than the close button's. *)
                      Vdom.Attr.create "tabindex" "-1"
                    ]
                  @ Attr.style
                      [ ("width", "100%")
                      ; ("max-width", sprintf "%dpx" width)
                      ])
               [ header_div; content_div ]
           in
           let on_dialog_click (ev : Dom_html.mouseEvent Js.t) =
             (* A click that lands on the dialog element itself is a click on
                the backdrop: the drawer sits inside it, so anything the user
                aimed at has a different target. *)
             if phys_equal (Js.Unsafe.get ev "target") (Js.Unsafe.get ev "currentTarget")
             then on_open_change false
             else Effect.Many []
           in
           let on_cancel (ev : Dom_html.event Js.t) =
             (* The browser's own close watcher: Escape, or the platform's back
                gesture. Always prevented, so the browser cannot close a
                controlled dialog behind the application's back — the answer
                is ours to give. *)
             Common.prevent_default ev;
             on_open_change false
           in
           let root_classes =
             [ "astryx-mobile-nav" ]
             @ (if is_inline then [ "astryx-mobile-nav--inline" ] else [])
             @ (if is_open then [ "astryx-mobile-nav--open" ] else [])
             @ [ "astryx-mobile-nav--" ^ side_name side ]
           in
           let root_attrs =
             Attr.class_ root_classes
             @ Attr.data "component" "MobileNav"
             (* The side the drawer is at. For an auto drawer the hook writes
                the resolved edge here when it opens, so the stylesheet always
                reads one attribute for "which edge is this". *)
             @ Attr.data "side" (match side with Start -> "start" | End -> "end" | Auto -> default_side_name)
             @ [ Vdom.Attr.create "id" id
               ; Vdom.Attr.create "aria-label" aria_label
               ; Vdom.Attr.on_click on_dialog_click
               ; Vdom.Attr.on_cancel on_cancel
               ]
             @ (if is_inline
                then []
                else
                  [ Vdom.Attr.create "aria-modal" "true"
                  ; Mobile_nav_hook.attr ~is_open ~side ()
                  ])
             @ attrs
           in
           if is_inline
           then (
             (* The inline rendering: the same anatomy, with no top layer and
                no modal behaviour, so a page can show the drawer without four
                of them fighting over the viewport. *)
             if is_open then Vdom.Node.div ~attrs:root_attrs [ drawer ] else Vdom.Node.none)
           else Vdom.Node.create "dialog" ~attrs:root_attrs [ drawer ])
;;
