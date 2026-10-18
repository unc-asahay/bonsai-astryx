open! Core
open! Bonsai_web
open Js_of_ocaml

type mode =
  | Dark
  | Light
  | None
[@@deriving sexp_of]

type position =
  | Fill
  | Bottom
  | Top
[@@deriving sexp_of]

type align =
  | Start
  | Center
  | End
[@@deriving sexp_of]

type show_on =
  | Always
  | Hover
  | Hover_or_focus
  | Focus
[@@deriving sexp_of]

let is_hover_mode = function Hover | Hover_or_focus -> true | Always | Focus -> false

(* ------------------------------------------------------------------ JS bits
   The questions upstream answers in TS are answered here in JS, with the house
   idiom (one [Js.Unsafe.eval_string], arguments injected). Each is asked at
   event/hook time, so nothing keeps a stale read of the DOM. *)

let is_touch_device () : bool =
  Js.Unsafe.fun_call
    (Js.Unsafe.eval_string
       "(function () { return (typeof window !== 'undefined' && window.matchMedia)\n\
        \       ? window.matchMedia('(hover: none)').matches : false; })")
    [||]
;;

(* Factories, built once. [make_overlay_click] is upstream's useClickableContainer
   onClick — walked in JS from the event target up to (excluding) the container
   root, honouring upstream's [INTERACTIVE_SELECTORS], plus the text-selection
   guard — because both rules are pure DOM questions and one call answers them. *)
let make_overlay_click =
  Js.Unsafe.eval_string
    "(function () { var sel = 'button,a,input,select,textarea,[role=button],[role=link],[role=checkbox],[role=radio],[role=switch],[role=tab],[role=menuitem],[role=option],[role=combobox],[role=listbox],[role=slider],[role=spinbutton],[data-pressable-container]';\n\
    \     return function (root, fire) {\n\
    \       return function (e) {\n\
    \         var t = e.target;\n\
    \         if (!t || t === root) { fire(); return; }\n\
    \         var cur = t;\n\
    \         while (cur && cur !== root && cur !== document.body) {\n\
    \           if (cur.matches && cur.matches(sel)) { return; }\n\
    \           cur = cur.parentElement;\n\
    \         }\n\
    \         var s = null;\n\
    \         try { s = document.getSelection(); } catch (err) {}\n\
    \         if (s && !s.isCollapsed && s.anchorNode && root.contains(s.anchorNode)) { return; }\n\
    \         fire();\n\
    \       }; }; })"
;;

let radius_sync =
  Js.Unsafe.eval_string
    "(function () {\n\
    \     return function (el) {\n\
    \       var fc = el.firstElementChild;\n\
    \       if (!fc) { return; }\n\
    \       try { var r = window.getComputedStyle(fc).borderRadius; }\n\
    \       catch (err) { return; }\n\
    \       if (r && r !== '0px') { el.style.borderRadius = r; }\n\
    \     }; })"
;;

(* -------------------------------------------------------- the touch + click hook
   Upstream uses useSyncExternalStore(matchMedia) + useClickableContainer; the
   port's equivalent for both is one vdom hook on the container. The listener
   registration runs once at mount; every re-render stores fresh inputs, so the
   callbacks (which read state at fire time) never act on a stale value. *)

module Overlay_hook = struct
  module T = struct
    module State = struct
      type t =
        { mutable enabled : bool
        ; mutable is_open : bool
        ; mutable set_open : bool -> unit Effect.t
        ; mutable set_touch : bool -> unit Effect.t
        ; mutable click_listener : Js.Unsafe.any option
        ; mutable media_subscription : Js.Unsafe.any option
        }

      let create () =
        { enabled = false
        ; is_open = false
        ; set_open = (fun _ -> Effect.Ignore)
        ; set_touch = (fun _ -> Effect.Ignore)
        ; click_listener = None
        ; media_subscription = None
        }
      ;;
    end

    module Input = struct
      type t =
        { enabled : bool
        ; is_open : bool
        ; set_open : (bool -> unit Effect.t)[@sexp.opaque]
        ; set_touch : (bool -> unit Effect.t)[@sexp.opaque]
        }

      let sexp_of_t { enabled; is_open; _ } =
        Sexp.List [ Sexp.Atom "overlay"; Bool.sexp_of_t enabled; Bool.sexp_of_t is_open ]
      ;;

      let combine a b =
        { enabled = a.enabled && b.enabled
        ; is_open = b.is_open
        ; set_open = (fun v -> Effect.Many [ a.set_open v; b.set_open v ])
        ; set_touch = (fun v -> Effect.Many [ a.set_touch v; b.set_touch v ])
        }
      ;;
    end

    let init _ _ = State.create ()

    let refresh_touch (state : State.t) =
      Effect.Expert.handle_non_dom_event_exn (state.set_touch (is_touch_device ()))
    ;;

    let subscribe (state : State.t) =
      match state.media_subscription with
      | Some _ -> ()
      | None ->
        let report (state : State.t) =
          refresh_touch state
        in
        let set_callback = Js.wrap_callback (fun () -> report state) in
        let subscription =
          Js.Unsafe.fun_call
            (Js.Unsafe.eval_string
               "(function (set) {\n  var m = (typeof window !== 'undefined' && window.matchMedia)\n    ? window.matchMedia('(hover: none)') : null;\n  if (!m) { return null; }\n  var cb = function () { set(); };\n  try { m.addEventListener('change', cb); }\n  catch (e) { try { m.addListener(cb); } catch (e2) {} }\n  return { m: m, cb: cb }; })")
            [| Js.Unsafe.inject set_callback |]
        in
        (try state.media_subscription <- Some (Js.Unsafe.inject subscription) with _ -> ());
        (* Upstream's useSyncExternalStore calls getSnapshot on mount; the port's
           equivalent is the initial read here, since a change event only fires when
           the media condition *flips* — a touch device that starts as touch would
           otherwise never enable the toggle. *)
        refresh_touch state
    ;;

    let attach_listeners (state : State.t) (el : Dom_html.element Js.t) =
      match state.click_listener with
      | Some _ -> ()
      | None ->
        let fire =
          Js.wrap_callback (fun () ->
            if state.enabled
            then Effect.Expert.handle_non_dom_event_exn (state.set_open (not state.is_open)))
        in
        let listener =
          (* [make_overlay_click] is a factory that returns the [function (root, fire)]
             binder, so it takes two calls: () for the factory, then (el, fire) for the
             binder. A single call with (el, fire) hands the DOM the binder itself — its
             return value is the real handler, which is then discarded — so the click
             never reaches [fire]. One extra call. *)
          Js.Unsafe.fun_call
            (Js.Unsafe.fun_call make_overlay_click [||])
            [| Js.Unsafe.inject el; Js.Unsafe.inject fire |]
        in
        state.click_listener <- Some (Js.Unsafe.inject listener);
        ignore
          (Js.Unsafe.meth_call
             el
             "addEventListener"
             [| Js.Unsafe.inject (Js.string "click"); Js.Unsafe.inject listener |])
    ;;

    let apply (state : State.t) (input : Input.t) (el : Dom_html.element Js.t) =
      state.enabled <- input.enabled;
      state.is_open <- input.is_open;
      state.set_open <- input.set_open;
      state.set_touch <- input.set_touch;
      subscribe state;
      attach_listeners state el
    ;;

    let on_mount input state el = apply state input el
    let on_mount = `Schedule_immediately_after_this_dom_patch_completes on_mount
    let update ~old_input:_ ~new_input state el = apply state new_input el

    let destroy _ (state : State.t) el =
      (match state.click_listener with
       | None -> ()
       | Some listener ->
         ignore
           (Js.Unsafe.meth_call
              el
              "removeEventListener"
              [| Js.Unsafe.inject (Js.string "click"); Js.Unsafe.inject listener |]));
      state.click_listener <- None;
      (match state.media_subscription with
       | None -> ()
       | Some sub ->
         let m = Js.Unsafe.get sub "m" in
         let cb = Js.Unsafe.get sub "cb" in
         (try
            ignore
              (Js.Unsafe.meth_call
                 m
                 "removeEventListener"
                 [| Js.Unsafe.inject (Js.string "change"); Js.Unsafe.inject cb |])
          with _ -> ());
         (try
            ignore (Js.Unsafe.meth_call m "removeListener" [| Js.Unsafe.inject cb |])
          with _ -> ()));
      state.media_subscription <- None
    ;;
  end

  module Hook = Vdom.Attr.Hooks.Make (T)

  let attr ~enabled ~is_open ~set_open ~set_touch =
    Vdom.Attr.create_hook
      "astryx-overlay-touch"
      (Hook.create { T.Input.enabled; is_open; set_open; set_touch })
  ;;
end

(* --------------------------------------------------- the scrim, pure node *)
(* [visibility] is a list of the class suffixes that get appended to
   [astryx-overlay-scrim]. All states, including [is_controlled], are computed
   from the arguments so this function is a pure mapping. *)

let scrim_visibility ~show_on ~position ~is_open : string list =
  match is_open with
  | Some open_now ->
    (if open_now then [ "--visible" ] else [ "--hidden" ])
    @ (match position with
      | Fill -> []
      | Bottom -> [ (if open_now then "--visible-from-bottom" else "--hidden-bottom") ]
      | Top -> [ (if open_now then "--visible-from-top" else "--hidden-top") ])
  | None -> (
    match show_on with
    | Always ->
      [ "--visible" ]
      @ (match position with
        | Fill -> []
        | Bottom -> [ "--visible-from-bottom" ]
        | Top -> [ "--visible-from-top" ])
    | Hover | Hover_or_focus ->
      [ "--hover" ]
      @ (match position with
        | Fill -> []
        | Bottom -> [ "--hover-bottom" ]
        | Top -> [ "--hover-top" ])
    | Focus ->
      [ "--focus" ]
      @ (match position with
        | Fill -> []
        | Bottom -> [ "--focus-bottom" ]
        | Top -> [ "--focus-top" ]))
;;

let scrim_node ~mode ~position ~align ~show_on ~is_open ~content =
  let is_controlled = Option.is_some is_open in
  let open_now = Option.value is_open ~default:false in
  let classes =
    List.filter
      ~f:(Fn.non String.is_empty)
      ([ "astryx-overlay-scrim"
       ; (match position with
         | Fill -> "astryx-overlay-scrim--fill"
         | Bottom -> "astryx-overlay-scrim--bottom"
         | Top -> "astryx-overlay-scrim--top")
       ; (match align with
         | Start -> "astryx-overlay-scrim--align-start"
         | Center -> "astryx-overlay-scrim--align-center"
         | End -> "astryx-overlay-scrim--align-end")
       ; (match mode with
         | Dark -> "astryx-overlay-scrim--scrim-dark"
         | Light -> "astryx-overlay-scrim--scrim-light"
         | None -> "")
       ]
      @ List.map (scrim_visibility ~show_on ~position ~is_open) ~f:(fun s -> "astryx-overlay-scrim" ^ s))
  in
  (* MediaTheme, inline: a [display: contents] wrapper that flips [color-scheme]
     so the [light-dark()] token set resolves to the inverted palette. *)
  let content =
    match mode with
    | None -> content
    | Dark | Light ->
      [ Vdom.Node.div
          ~attrs:
            (Common.Attr.class_ [ "astryx-overlay-media" ]
            @ Common.Attr.data "media" (match mode with Dark -> "dark" | Light -> "light" | None -> ""))
          content ]
  in
  Vdom.Node.div
    ~attrs:
      (Common.Attr.class_ classes
      @ (if is_controlled && not open_now then [ Vdom.Attr.inert ] else []))
    content
;;

(* --------------------------------------------------------------- the hook *)
type t =
  { container : Vdom.Attr.t list
  ; element : Vdom.Node.t option
  ; render_overlay : Vdom.Node.t list -> Vdom.Node.t
  }

let use_overlay
    ?(show_on = Always)
    ?is_open
    ?(scrim = Dark)
    ?(position = Fill)
    ?(align = End)
    ?content
    graph
  =
  let touch_open, set_touch_open = Bonsai.state false graph in
  let is_touch, set_is_touch = Bonsai.state false graph in
  let enabled = Bonsai.map is_touch ~f:(fun t -> t && is_hover_mode show_on) in
  let hook_attr =
    let set_parts = Bonsai.map2 set_touch_open set_is_touch ~f:Tuple2.create in
    Bonsai.map3 enabled touch_open set_parts ~f:(fun enabled open_now (set_open, set_touch) ->
      Overlay_hook.attr ~enabled ~is_open:open_now ~set_open ~set_touch)
  in
  (* Upstream: consumer's isOpen > touch toggle > undefined (CSS-driven). *)
  let effective_is_open =
    match is_open with
    | Some is_open_bs -> Bonsai.map is_open_bs ~f:(fun open_now -> Some open_now)
    | None -> Bonsai.map2 enabled touch_open ~f:(fun enabled touch_open ->
        if enabled then Some touch_open else None)
  in
  let container =
    Bonsai.map hook_attr ~f:(fun hook_attr ->
      [ hook_attr ]
      @ Common.Attr.class_ [ "astryx-overlay" ]
      @ Common.Attr.data "component" "Overlay")
  in
  Bonsai.map2 container effective_is_open ~f:(fun container effective_is_open ->
    { container
    ; element =
        Option.map content ~f:(fun content ->
          scrim_node ~mode:scrim ~position ~align ~show_on ~is_open:effective_is_open ~content)
    ; render_overlay =
        (fun content ->
          scrim_node ~mode:scrim ~position ~align ~show_on ~is_open:effective_is_open ~content)
    })
;;

(* ---------------------------------------------- the component (thin wrapper)
   Upstream mirrors the first child's border-radius onto the wrapper with a
   layout effect; the port's version reads it once after the DOM patch. *)

module Radius_hook = struct
  module T = struct
    module State = struct
      type t = unit
    end

    module Input = struct
      type t = unit
      let sexp_of_t () = Sexp.Atom "radius"
      let combine () () = ()
    end

    let init _ _ = ()
    let apply el = ignore (Js.Unsafe.fun_call radius_sync [| Js.Unsafe.inject el |])
    let on_mount _ _ el = apply el
    let on_mount = `Schedule_immediately_after_this_dom_patch_completes on_mount
    let update ~old_input:_ ~new_input:() _ el = apply el
    let destroy _ _ _ = ()
  end

  module Hook = Vdom.Attr.Hooks.Make (T)
  let attr () = Vdom.Attr.create_hook "astryx-overlay-radius" (Hook.create ())
end

let view
    ?(attrs = [])
    ?id
    ?show_on
    ?is_open
    ?scrim
    ?position
    ?align
    ?(children = [])
    ~content
    graph
  =
  let overlay = use_overlay ?show_on ?is_open ?scrim ?position ?align ~content graph in
  Bonsai.map overlay ~f:(fun { container; element; render_overlay = _ } ->
    let id_attr = Option.map id ~f:(fun i -> Vdom.Attr.id i) in
    let to_list = function Some a -> [ a ] | None -> [] in
    Vdom.Node.div
      ~attrs:(container @ attrs @ to_list id_attr @ [ Radius_hook.attr () ])
      (children @ Option.value_map element ~default:[] ~f:List.singleton))
;;
