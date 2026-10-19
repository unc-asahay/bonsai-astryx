(* Outline — a hand-port of Astryx's Outline/Outline.tsx (508 lines) and
   useScrollSpy.ts (467 lines), with types.ts.

   A table-of-contents navigation component for document headings. Outline
   accepts a flat `items` array and renders anchor links with indentation
   based on each heading level, plus a sliding indicator track that animates
   to the active item.

   When `active_id` is omitted it tracks scroll position (rAF-throttled,
   reading live heading positions, never stale caches) and marks the last
   heading whose top has passed its activation line — where `offset` (a fixed
   header overlaying the scroll root) plus the heading's own
   `scroll-margin-top` put it. It defaults to the first item at the top and
   the last at the bottom.

   Keyboard: the list is a single tab stop (roving tabindex, seated on the
   active heading while focus is outside), arrow keys move between headings,
   Home/End jump to the ends, and Enter/Space activate — one Tab, not one per
   heading. The arrow/Home/End machinery is {!Common.List_focus} (upstream's
   useListFocus), the same mechanism ButtonGroup and Toolbar share.

   {2 The mechanism}

   All dynamic behaviour lives in one vdom hook ({!Scroll_spy_hook}) attached
   to the root <nav>: it owns the scroll listeners, the programmatic scroll
   with settle detection, and the imperative DOM sync of the active state
   (aria-current + roving tabindex). The vdom renders structure and never
   re-renders for scroll — the hook writes the moving attributes straight to
   the DOM, the same stance Timer's clock and ComplexSelector's popover take.
   Click and Space are also delegated to the hook, so upstream's single
   navigation path stays single.

   {2 Divergences, named rather than hidden}

   - {b The link seam}. Upstream renders through [useLinkComponent], so an
     app can route its links. This port has no such context seam; the items
     are plain `<a href="#id">` anchors (the same standing DropdownMenu's row
     anchors take).
   - {b [scrollContainerRef]}. Upstream takes a React ref to the scroll
     container. Bonsai has no refs to pass across the component boundary, so
     the port accepts [scroll_container], a CSS selector resolved against
     [document] — the showcase uses it to scope an Outline to a split pane.
     Omitted, the nearest scrollable ancestor wins, as upstream.
   - {b Controlled state}. When [active_id] is provided the built-in
     scroll-spy is disabled (upstream's rule) and the hook posts
     [on_active_id_change] without touching the rendered state; the consumer
     drives the `items` tree to move the visual active state, or accepts the
     aria-current written by the hook.
   - {b themeProps}. The [themeProps('outline' | 'outline-item' |
     'outline-indicator')] seams have no counterpart, the standing of every
     previous milestone.
   - {b No markdown helpers}. Upstream also ships
     [parseOutlineFromMarkdown] / [useOutlineFromMarkdown] /
     [useOutlineFromDOM]. This milestone is the component + scroll-spy; the
     parsers are pure string work and come with their own milestone if a
     consumer needs them.
   - {b The indicator}. Upstream anchors the indicator to the active link
     with CSS [anchor-name] / [position-anchor] set from a style prop
     because React recomputes it. The vdom cannot know the active item here,
     so the anchor name is declared in CSS against [aria-current="location"]
     — same geometry, no imperative style.
   - {b [useDevWarning]}. Upstream console-warns on a known dev mistake; the
     port reports through [data-astryx-*] attributes instead (house standing).

   The scroll math (activation line == scroll landing == root top + offset +
   scroll-margin-top) is upstream's exactly, including the 1 px rounding
   tolerance, the at-bottom rule (last item), the 1200 ms settle fallback when
   [scrollend] never fires (Safari, or an already-in-position target), the
   wheel/touchmove/keyboard interruption path that resumes position tracking,
   and the modifier-chord rule that leaves a modified click to the browser. *)

open! Core
open! Bonsai_web
open Js_of_ocaml

type density =
  | Default
  | Compact

type item =
  { id : string
  ; label : string
  ; level : int
  }

(* -------------------------------------------------------------------------- *)
(* DOM helpers                                                                *)
(* -------------------------------------------------------------------------- *)

let get_element_by_id (id : string) : Dom_html.element Js.t option =
  let result =
    (Js.Unsafe.meth_call Dom_html.document "getElementById" [| Js.Unsafe.inject (Js.string id) |]
      : Dom_html.element Js.t Js.opt)
  in
  Js.Opt.to_option result
;;

let query_selector (selector : string) : Dom_html.element Js.t option =
  let result =
    (Js.Unsafe.meth_call Dom_html.document "querySelector" [| Js.Unsafe.inject (Js.string selector) |]
      : Dom_html.element Js.t Js.opt)
  in
  Js.Opt.to_option result
;;

(* [Dom.list_of_nodeList] is the conversion, not a hand-rolled one — the lesson
   Overflow_hook's version of this function cost a full browser run. *)
let children_of (container : Dom_html.element Js.t) (selector : string) : Dom_html.element Js.t list =
  let node_list =
    Js.Unsafe.meth_call container "querySelectorAll" [| Js.Unsafe.inject (Js.string selector) |]
  in
  Dom.list_of_nodeList (Js.Unsafe.coerce node_list) |> List.map ~f:Js.Unsafe.coerce
;;

let set_attr (el : Dom_html.element Js.t) (name : string) (value : string) =
  ignore
    (Js.Unsafe.meth_call
       el
       "setAttribute"
       [| Js.Unsafe.inject (Js.string name); Js.Unsafe.inject (Js.string value) |])
;;

let remove_attr (el : Dom_html.element Js.t) (name : string) =
  ignore (Js.Unsafe.meth_call el "removeAttribute" [| Js.Unsafe.inject (Js.string name) |])
;;

let get_attr (el : Dom_html.element Js.t) (name : string) : string option =
  let result =
    (Js.Unsafe.meth_call el "getAttribute" [| Js.Unsafe.inject (Js.string name) |]
      : Js.js_string Js.t Js.opt)
  in
  Js.Opt.to_option result |> Option.map ~f:Js.to_string
;;

let add_listener (el : _ Js.t) (kind : string) (listener : Js.Unsafe.any) =
  ignore
    (Js.Unsafe.meth_call
       el
       "addEventListener"
       [| Js.Unsafe.inject (Js.string kind); Js.Unsafe.inject listener |])
;;

let remove_listener (el : _ Js.t) (kind : string) (listener : Js.Unsafe.any) =
  ignore
    (Js.Unsafe.meth_call
       el
       "removeEventListener"
       [| Js.Unsafe.inject (Js.string kind); Js.Unsafe.inject listener |])
;;

let rect_top (el : Dom_html.element Js.t) : float =
  (Js.Unsafe.fun_call
     (Js.Unsafe.eval_string "(function (el) { return el.getBoundingClientRect().top; })")
     [| Js.Unsafe.inject el |]
    : float)
;;

let scroll_margin_top (el : Dom_html.element Js.t) : float =
  (Js.Unsafe.fun_call
     (Js.Unsafe.eval_string
        "(function (el) { var v = getComputedStyle(el)['scroll-margin-top']; var n = parseFloat(v); return isFinite(n) ? n : 0; })")
     [| Js.Unsafe.inject el |]
    : float)
;;

(* The nearest scrollable ancestor, or null (meaning: the viewport). *)
let scrollable_ancestor (el : Dom_html.element Js.t) : Dom_html.element Js.t option =
  let result =
    (Js.Unsafe.fun_call
       (Js.Unsafe.eval_string
          "(function (el) { var current = el ? el.parentElement : null; \
           while (current != null) { \
           var cs = getComputedStyle(current); var oy = cs.overflowY; \
           if ((oy === 'auto' || oy === 'scroll' || oy === 'overlay') \
           && current.scrollHeight > current.clientHeight) return current; \
           current = current.parentElement; } return null; })")
       [| Js.Unsafe.inject el |]
      : Dom_html.element Js.t Js.opt)
  in
  Js.Opt.to_option result
;;

let at_bottom (root : Dom_html.element Js.t option) : bool =
  (Js.Unsafe.fun_call
     (Js.Unsafe.eval_string
        "(function (root) { if (root != null) return root.scrollTop + root.clientHeight >= root.scrollHeight - 2; \
         return window.innerHeight + (window.scrollY || 0) >= document.documentElement.scrollHeight - 2; })")
     [| Js.Unsafe.inject (Option.value_map root ~default:(Js.Unsafe.inject Js.null) ~f:(fun r -> Js.Unsafe.inject r)) |]
    : bool)
;;

let scroll_into_view (el : Dom_html.element Js.t) =
  ignore
    (Js.Unsafe.fun_call
       (Js.Unsafe.eval_string
          "(function (el) { el.scrollIntoView({behavior: 'smooth', block: 'start'}); })")
       [| Js.Unsafe.inject el |])
;;

let scroll_by (target : _ Js.t) (delta_px : float) =
  ignore
    (Js.Unsafe.fun_call
       (Js.Unsafe.eval_string
          "(function (target, top) { target.scrollBy({top: top, behavior: 'smooth'}); })")
       [| Js.Unsafe.inject target; Js.Unsafe.inject (Js.number_of_float delta_px) |])
;;

let push_hash (id : string) =
  ignore
    (Js.Unsafe.fun_call
       (Js.Unsafe.eval_string "(function (id) { window.history.pushState(null, '', '#' + id); })")
       [| Js.Unsafe.inject (Js.string id) |])
;;

let active_element () : Dom_html.element Js.t =
  Js.Unsafe.get (Js.Unsafe.pure_js_expr "document") "activeElement"
;;

let nav_contains (nav : Dom_html.element Js.t) (el : Dom_html.element Js.t) : bool =
  (Js.Unsafe.fun_call
     (Js.Unsafe.eval_string "(function (nav, el) { return nav.contains(el); })")
     [| Js.Unsafe.inject nav; Js.Unsafe.inject el |]
    : bool)
;;

let closest_anchor_from (nav : Dom_html.element Js.t) (el : Dom_html.element Js.t) : string option =
  let result =
    (Js.Unsafe.fun_call
       (Js.Unsafe.eval_string
          "(function (nav, el) { \
           var a = el && el.closest ? el.closest('a[href]') : null; \
           if (!a || !nav.contains(a)) return null; \
           var href = a.getAttribute('href'); return href ? href : null; })")
       [| Js.Unsafe.inject nav; Js.Unsafe.inject el |]
      : Js.js_string Js.t Js.opt)
  in
  Js.Opt.to_option result |> Option.map ~f:Js.to_string
;;

let id_of_href (href : string) : string =
  if String.is_prefix href ~prefix:"#" then String.drop_prefix href 1 else href
;;

let has_modifier (ev : Dom_html.event Js.t) : bool =
  Common.bool_prop ev "metaKey" || Common.bool_prop ev "ctrlKey" || Common.bool_prop ev "shiftKey"
  || Common.bool_prop ev "altKey"
;;

let fire (effect : unit Effect.t) = Effect.Expert.handle_non_dom_event_exn effect

let is_scroll_key (key : string) : bool =
  List.exists [ "ArrowUp"; "ArrowDown"; "PageUp"; "PageDown"; "Home"; "End"; " "; "Spacebar" ] ~f:(fun k ->
    String.equal k key)
;;

(* -------------------------------------------------------------------------- *)
(* The scroll-spy hook                                                        *)
(* -------------------------------------------------------------------------- *)

module Scroll_spy_hook = struct
  module T = struct
    module Input = struct
      type t =
        { items : item list
        ; (* [Some] means controlled: built-in scroll-spy is disabled and the
             consumer owns the active state. *)
          active_id : string option
        ; offset : int
        ; has_scroll_on_click : bool
        ; scroll_container : string option
        ; on_active_id_change : (string -> unit Effect.t [@sexp.opaque])
        ; on_navigate_start : (string -> unit Effect.t [@sexp.opaque])
        ; on_navigate_end : (string -> unit Effect.t [@sexp.opaque])
        }

      (* Hand-written: this project's ppx set has no sexp deriver, and the
         interface wants one. Only the parts worth reading in a log are shown —
         an effect cannot be printed. *)
      let sexp_of_t { items; active_id; offset; has_scroll_on_click; scroll_container; _ } =
        Sexp.List
          [ Sexp.Atom (Int.to_string (List.length items))
          ; Sexp.Atom (Option.value active_id ~default:"-")
          ; Sexp.Atom (Int.to_string offset)
          ; Sexp.Atom (Bool.to_string has_scroll_on_click)
          ; Sexp.Atom (Option.value scroll_container ~default:"-")
          ]
      ;;

      let combine left _ = left
    end

    module State = struct
      type t =
        { (* The latest input, so listeners attached once stay current with the
             props (items can change under a mounted outline). *)
          mutable input : Input.t option
        ; (* The active item id (uncontrolled scroll-spy answer). *)
          mutable active : string option
        ; (* While true, scroll-spy ignores scroll updates because a navigation
             is driving a programmatic scroll. *)
          mutable suppress : bool
        ; mutable nav : Dom_html.element Js.t option
        ; mutable scroll_root : Dom_html.element Js.t option
        ; mutable raf : Js.Unsafe.any option
        ; mutable scroll_listener : Js.Unsafe.any option
        ; mutable resize_listener : Js.Unsafe.any option
        ; mutable nav_click : Js.Unsafe.any option
        ; mutable nav_key : Js.Unsafe.any option
        ; (* A navigation is in flight. *)
          mutable navigating : bool
        ; mutable settle_timer : Js.Unsafe.any option
        ; mutable settle_listeners : Js.Unsafe.any list
        }

      let create () =
        { input = None
        ; active = None
        ; suppress = false
        ; nav = None
        ; scroll_root = None
        ; raf = None
        ; scroll_listener = None
        ; resize_listener = None
        ; nav_click = None
        ; nav_key = None
        ; navigating = false
        ; settle_timer = None
        ; settle_listeners = []
        }
      ;;
    end

    (* --- scroll math --- *)

    (* The top of the scroll root in viewport coordinates (0 for the viewport). *)
    let get_root_top (root : Dom_html.element Js.t option) : float =
      Option.value_map root ~default:0.0 ~f:rect_top
    ;;

    let resolve_active (input : Input.t) (state : State.t) : string option =
      match input.items with
      | [] -> None
      | _ ->
        if at_bottom state.scroll_root
        then Some (List.last_exn input.items).id
        else (
          (* Where a heading comes to rest, in viewport coordinates: below the
             fixed header (offset) and below its own scroll-margin-top. This is
             the single source of truth shared by the activation line and the
             scroll landing. *)
          let resting_top (el : Dom_html.element Js.t) =
            get_root_top state.scroll_root +. float_of_int input.offset +. scroll_margin_top el
          in
          (* The active heading is the last one whose top has reached its
             activation line (headings are in document order). *)
          let rec scan acc = function
            | [] -> acc
            | item :: rest ->
              (match get_element_by_id item.id with
               | None -> scan acc rest
               | Some el ->
                 (* 1px of tolerance absorbs sub-pixel rounding after a scroll lands. *)
                 if Float.(rect_top el <= resting_top el +. 1.) then scan (Some item.id) rest else acc)
          in
          scan (Some (List.hd_exn input.items).id) input.items)
    ;;

    (* --- imperative DOM sync of the active state --- *)

    let sync_dom (input : Input.t) (state : State.t) =
      match state.nav with
      | None -> ()
      | Some nav ->
        (* WAI-ARIA seats the single tab stop on the active item, but only while
           focus is outside the list: once the reader has arrowed to an item the
           stop is theirs and scroll-spy must not yank it away. *)
        let focus_is_outside = not (nav_contains nav (active_element ())) in
        (* Controlled: the attribute mirrors the consumer's [active_id]. The port
           has no render path to stamp it on the vdom (the scroll-spy hook owns
           the DOM), so this is where the CSS anchor and the parity harness read
           the state upstream's render would have written. *)
        let active =
          match input.active_id with Some a -> Some a | None -> state.active
        in
        List.iter (children_of nav "a[href]") ~f:(fun link ->
          let id = Option.value_map (get_attr link "href") ~default:"#" ~f:id_of_href in
          let is_active = Option.equal String.equal (Some id) active in
          if is_active
          then (
            set_attr link "aria-current" "location";
            if focus_is_outside then set_attr link "tabindex" "0")
          else (
            remove_attr link "aria-current";
            if focus_is_outside then set_attr link "tabindex" "-1"))
    ;;

    let resolve_and_sync (input : Input.t) (state : State.t) =
      if not state.suppress
      then (
        let next = resolve_active input state in
        if not (Option.equal String.equal state.active next)
        then (
          state.active <- next;
          Option.iter next ~f:(fun id -> fire (input.on_active_id_change id)));
        sync_dom input state)
    ;;

    (* --- scroll listeners --- *)

    let cancel_raf (state : State.t) =
      Option.iter state.raf ~f:(fun handle ->
        ignore
          (Js.Unsafe.meth_call Dom_html.window "cancelAnimationFrame" [| Js.Unsafe.inject handle |]));
      state.raf <- None
    ;;

    let teardown_scroll (state : State.t) =
      (match state.scroll_root with
       | Some root ->
         Option.iter state.scroll_listener ~f:(fun l -> remove_listener root "scroll" l)
       | None -> Option.iter state.scroll_listener ~f:(fun l -> remove_listener Dom_html.window "scroll" l));
      Option.iter state.resize_listener ~f:(fun l -> remove_listener Dom_html.window "resize" l);
      cancel_raf state;
      state.scroll_listener <- None;
      state.resize_listener <- None
    ;;

    let arm_scroll (input : Input.t) (state : State.t) =
      teardown_scroll state;
      (* Controlled: the consumer owns the active state; there is nothing to track. *)
      if Option.is_some input.active_id
      then state.scroll_root <- None
      else (
        let scroll_root =
          match input.scroll_container with
          | Some selector -> query_selector selector
          | None -> Option.bind state.nav ~f:scrollable_ancestor
        in
        state.scroll_root <- scroll_root;
        let scroll_target =
          match scroll_root with Some r -> Js.Unsafe.coerce r | None -> Js.Unsafe.coerce Dom_html.window
        in
        let on_scroll () =
          match state.raf with
          | Some _ -> ()
          | None ->
            state.raf
            <- Some
                 (Js.Unsafe.meth_call
                    Dom_html.window
                    "requestAnimationFrame"
                    [| Js.Unsafe.inject
                         (Js.wrap_callback (fun () ->
                            (* The handle must be released BEFORE resolving: if
                               it stayed [Some] after the first callback, every
                               later scroll would be swallowed and the spy would
                               process exactly one resolution ever (caught by
                               the browser gate: scroll to the bottom, then back
                               to the top — the seat never returned). *)
                            state.raf <- None;
                            resolve_and_sync input state))
                     |])
        in
        state.scroll_listener <- Some (Js.Unsafe.inject (Js.wrap_callback on_scroll));
        state.resize_listener <- Some (Js.Unsafe.inject (Js.wrap_callback on_scroll));
        add_listener scroll_target "scroll" (Option.value_exn state.scroll_listener);
        add_listener Dom_html.window "resize" (Option.value_exn state.resize_listener);
        (* The initial resolution, exactly as upstream's effect runs update() at
           attach time — the indicator is right before the first scroll. *)
        resolve_and_sync input state)
    ;;

    (* --- navigation (the single path shared by click and keyboard) --- *)

    let cleanup_settle (state : State.t) =
      Option.iter state.settle_timer ~f:Common.clear_timeout;
      state.settle_timer <- None;
      (match state.scroll_root with
       | Some root ->
         List.iter state.settle_listeners ~f:(fun l -> remove_listener root "scrollend" l)
       | None -> List.iter state.settle_listeners ~f:(fun l -> remove_listener Dom_html.window "scrollend" l));
      List.iter state.settle_listeners ~f:(fun l -> remove_listener Dom_html.window "keydown" l);
      List.iter state.settle_listeners ~f:(fun l -> remove_listener Dom_html.window "wheel" l);
      List.iter state.settle_listeners ~f:(fun l -> remove_listener Dom_html.window "touchmove" l);
      state.settle_listeners <- [];
      state.navigating <- false
    ;;

    (* Bring the target to rest at the top of the scroll root, below any fixed
       header. With no [offset] this is the CSS-native path: scrollIntoView
       already honours scroll-margin-top and walks every scrollable ancestor.
       An [offset] describes a fixed header the browser cannot know about, so
       the landing is computed explicitly from the same number the activation
       line uses. *)
    let scroll_to_target (input : Input.t) (state : State.t) (target : Dom_html.element Js.t) =
      if input.offset = 0
      then scroll_into_view target
      else (
        let delta =
          rect_top target -. get_root_top state.scroll_root -. float_of_int input.offset
          -. scroll_margin_top target
        in
        scroll_by
          (match state.scroll_root with Some r -> Js.Unsafe.coerce r | None -> Js.Unsafe.coerce Dom_html.window)
          delta)
    ;;

    let scroll_to_id (input : Input.t) (state : State.t) (id : string) : bool =
      match get_element_by_id id with
      | None -> false
      | Some target ->
        (* A second navigation replaces the first: end the old one (balancing its
           onNavigateStart) without resuming tracking, since we are about to
           suppress it again anyway. *)
        (if state.navigating then cleanup_settle state);
        fire (input.on_navigate_start id);
        let is_controlled = Option.is_some input.active_id in
        (if is_controlled
         then fire (input.on_active_id_change id)
         else state.suppress <- true);
        if not input.has_scroll_on_click
        then (
          (* The consumer owns scrolling — the navigation is already at rest, so
             it resolves immediately (upstream: arrival effects fire even when
             hasScrollOnClick is false). *)
          if not is_controlled
          then (
            state.suppress <- false;
            state.active <- Some id;
            fire (input.on_active_id_change id);
            sync_dom input state);
          fire (input.on_navigate_end id))
        else (
          state.navigating <- true;
          let settled = ref false in
          (* End the navigation exactly once. [did_arrive] is false when the user
             took over with a manual scroll mid-flight. [on_navigate_end] fires
             either way, so every [on_navigate_start] is balanced — a consumer's
             "navigating" state can never leak. *)
          let finish ~(did_arrive : bool) ~(resume : bool) =
            if not !settled
            then (
              settled := true;
              cleanup_settle state;
              if not is_controlled
              then (
                state.suppress <- false;
                if did_arrive
                then (
                  state.active <- Some id;
                  fire (input.on_active_id_change id);
                  sync_dom input state)
                else if resume
                then (
                  (* Hand control back to scroll-position tracking. *)
                  cancel_raf state;
                  resolve_and_sync input state));
              fire (input.on_navigate_end id))
          in
          let on_settle () = finish ~did_arrive:true ~resume:true in
          let on_manual () = finish ~did_arrive:false ~resume:true in
          let on_key (ev : Dom_html.event Js.t) =
            (* A key the outline itself consumed (arrow roving, Space activation)
               is prevented, so the browser will not scroll — it is not a manual
               scroll intent and must not cancel the navigation it just began. *)
            let key = Option.value (Common.string_prop ev "key") ~default:"" in
            if (not (Common.bool_prop ev "defaultPrevented")) && is_scroll_key key
            then finish ~did_arrive:false ~resume:true
          in
          let scroll_target =
            match state.scroll_root with
            | Some r -> Js.Unsafe.coerce r
            | None -> Js.Unsafe.coerce Dom_html.window
          in
          (* Arm settle detection BEFORE scrolling, so an instant jump (a target
             already in position, or reduced motion collapsing the smooth scroll)
             cannot land before anyone is listening. *)
          let settle_on_scrollend = Js.Unsafe.inject (Js.wrap_callback on_settle) in
          let wheel_handler = Js.Unsafe.inject (Js.wrap_callback on_manual) in
          let touch_handler = Js.Unsafe.inject (Js.wrap_callback on_manual) in
          let key_handler = Js.Unsafe.inject (Js.wrap_callback on_key) in
          add_listener scroll_target "scrollend" settle_on_scrollend;
          add_listener Dom_html.window "wheel" wheel_handler;
          add_listener Dom_html.window "touchmove" touch_handler;
          add_listener Dom_html.window "keydown" key_handler;
          state.settle_listeners <- [ settle_on_scrollend; wheel_handler; touch_handler; key_handler ];
          state.settle_timer <- Some (Common.timeout on_settle 1200.);
          scroll_to_target input state target);
        true
    ;;

    (* --- delegated activation (click + Space) --- *)

    let on_click (state : State.t) (ev : Dom_html.event Js.t) =
      match state.input, state.nav with
      | Some input, Some nav ->
        let target : Dom_html.element Js.t = Js.Unsafe.get ev "target" in
        (match closest_anchor_from nav target with
         | None -> ()
         | Some href ->
           let id = id_of_href href in
           if Common.bool_prop ev "defaultPrevented" || has_modifier ev
           then ()
           else (
             (* No target in the DOM — lazily-rendered or virtualized content:
                leave the anchor to the browser's native fragment navigation. *)
             match get_element_by_id id with
             | None -> ()
             | Some _ ->
               Common.prevent_default ev;
               if scroll_to_id input state id then push_hash id))
      | Some _, None -> ()
      | None, _ -> ()
    ;;

    let on_space (state : State.t) (ev : Dom_html.event Js.t) =
      let key = Option.value (Common.string_prop ev "key") ~default:"" in
      if (not (String.equal key " " || String.equal key "Spacebar"))
         || Common.bool_prop ev "defaultPrevented"
         || has_modifier ev
      then ()
      else (
        match state.input, state.nav with
        | Some input, Some nav ->
          (* The focused link is the one being activated — Enter is a link's
             native activation and already clicks; Space is wired here to match
             the button-like affordance. *)
          (match closest_anchor_from nav (active_element ()) with
           | None -> ()
           | Some href ->
             let id = id_of_href href in
             (match get_element_by_id id with
              | None -> ()
              | Some _ ->
                Common.prevent_default ev;
                if scroll_to_id input state id then push_hash id))
        | Some _, None -> ()
        | None, _ -> ())
    ;;

    (* --- hook lifecycle --- *)

    let init _ _ = State.create ()

    let on_mount input (state : State.t) node =
      let nav : Dom_html.element Js.t = Js.Unsafe.coerce node in
      state.input <- Some input;
      state.nav <- Some nav;
      arm_scroll input state;
      (* Controlled initial state: [arm_scroll] skips the initial resolution for
         a consumer-owned active_id, so sync it explicitly — the attribute has
         to be right on first paint, not on first click. *)
      sync_dom input state;
      let click = Js.Unsafe.inject (Js.wrap_callback (fun ev -> on_click state ev)) in
      let key = Js.Unsafe.inject (Js.wrap_callback (fun ev -> on_space state ev)) in
      state.nav_click <- Some click;
      state.nav_key <- Some key;
      add_listener nav "click" click;
      add_listener nav "keydown" key
    ;;

    let on_mount = `Schedule_immediately_after_this_dom_patch_completes on_mount

    let update ~old_input:_ ~new_input (state : State.t) _ =
      state.input <- Some new_input;
      arm_scroll new_input state;
      sync_dom new_input state
    ;;

    let destroy _ (state : State.t) _node =
      teardown_scroll state;
      cleanup_settle state;
      (match state.nav with
       | None -> ()
       | Some nav ->
         Option.iter state.nav_click ~f:(fun l -> remove_listener nav "click" l);
         Option.iter state.nav_key ~f:(fun l -> remove_listener nav "keydown" l));
      state.nav <- None
    ;;
  end

  module Hook = Vdom.Attr.Hooks.Make (T)

  let attr (input : T.Input.t) : Vdom.Attr.t =
    Vdom.Attr.create_hook "astryx-scroll-spy" (Hook.create input)
  ;;
end

(* -------------------------------------------------------------------------- *)
(* View                                                                       *)
(* -------------------------------------------------------------------------- *)

let indent_class (level : int) : string =
  (* Upstream maps heading levels 1-6 to visual indent levels 1-4:
     Math.max(1, Math.min(4, level - 1 || 1)) — level 1 (h1) = indent 1,
     level 2 (h2) = indent 1, level 3 (h3) = indent 2, level 4 = 3,
     levels 5-6 = 4. *)
  let indent_level = Int.max 1 (Int.min 4 (max 1 (level - 1))) in
  sprintf "astryx-outline__link--indent-%d" indent_level
;;

let density_class = function
  | Default -> "astryx-outline__link--default"
  | Compact -> "astryx-outline__link--compact"
;;

let view
      ?(attrs = [])
      ?(id = "astryx-outline")
      ?active_id
      ?on_active_id_change
      ?(label = "Table of contents")
      ?(density = Default)
      ?on_navigate_start
      ?on_navigate_end
      ?(offset = 0)
      ?(has_scroll_on_click = true)
      ?scroll_container
      ~items
      (_graph : Bonsai.graph)
  =
  let active_id = Option.value active_id ~default:(Bonsai.return None) in
  let on_active_id_change =
    Option.value on_active_id_change ~default:(Bonsai.return (fun _ -> Bonsai.Effect.Ignore))
  in
  let on_navigate_start =
    Option.value on_navigate_start ~default:(Bonsai.return (fun _ -> Bonsai.Effect.Ignore))
  in
  let on_navigate_end =
    Option.value on_navigate_end ~default:(Bonsai.return (fun _ -> Bonsai.Effect.Ignore))
  in
  let callbacks =
    Bonsai.map3 on_active_id_change on_navigate_start on_navigate_end ~f:(fun a s e -> a, s, e)
  in
  let core = Bonsai.map2 items active_id ~f:(fun items active_id -> items, active_id) in
  let input_t =
    Bonsai.map2 core callbacks ~f:(fun (items, active_id) (on_active, on_start, on_end) ->
      { Scroll_spy_hook.T.Input.items
      ; active_id
      ; offset
      ; has_scroll_on_click
      ; scroll_container
      ; on_active_id_change = on_active
      ; on_navigate_start = on_start
      ; on_navigate_end = on_end
      })
  in
  Bonsai.map input_t ~f:(fun input ->
    let link item =
      let classes =
        [ "astryx-outline__link"; density_class density; indent_class item.level ]
      in
      Vdom.Node.a
        ~attrs:
          ([ Vdom.Attr.href ("#" ^ item.id)
           ; Vdom.Attr.create "tabindex" "-1"
           ]
          @ Common.Attr.class_ classes)
        [ Vdom.Node.span
            ~attrs:(Common.Attr.class_ [ "astryx-outline__label" ])
            [ Vdom.Node.text item.label ]
        ]
    in
    let nav_attrs =
      (Vdom.Attr.id id
      :: Vdom.Attr.create "aria-label" label
      :: Scroll_spy_hook.attr input
      :: Common.Attr.data "component" "Outline")
      @ Common.Attr.class_ [ "astryx-outline" ]
      @ attrs
    in
    Vdom.Node.nav
      ~attrs:nav_attrs
      [ Vdom.Node.ul
          ~attrs:
            (Common.Attr.role "list"
            @ Common.Attr.class_ [ "astryx-outline__list" ]
            @ [ Common.List_focus.attr
                   ~orientation:Common.List_focus.Vertical
                   ~item_selector:"a[href]"
                   ~boundary_selector:"ul.astryx-outline__list"
                   ~caret_guard:false
                   ~prefer_existing_stop:true
                   () ])
          (List.map input.items ~f:(fun item ->
             Vdom.Node.li
               ~attrs:(Common.Attr.class_ [ "astryx-outline__item" ])
               [ link item ]))
      ; Vdom.Node.div
          ~attrs:(Common.Attr.class_ [ "astryx-outline__track" ] @ Common.Attr.aria "hidden" "true")
          [ Vdom.Node.span ~attrs:(Common.Attr.class_ [ "astryx-outline__divider" ]) [] ]
      ; Vdom.Node.span
          ~attrs:
            (Common.Attr.class_ [ "astryx-outline__indicator" ] @ Common.Attr.aria "hidden" "true")
          []
      ])
;;
