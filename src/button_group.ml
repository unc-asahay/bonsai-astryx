open! Core
open! Bonsai_web
open Js_of_ocaml

type orientation =
  | Horizontal
  | Vertical

type elevation =
  | None_
  | Low
  | Med
  | High

(* Hand-written because the hook functor needs it and this project has no sexp deriver. *)
let sexp_of_orientation = function
  | Horizontal -> Sexp.Atom "horizontal"
  | Vertical -> Sexp.Atom "vertical"
;;

(* --------------------------------------------------------------------------------------------- *)
(* The roving tab stop                                                                            *)
(* --------------------------------------------------------------------------------------------- *)
(* A group of buttons is one tab stop, and the platform does not give us that: unlike a radio group
   there is no native element whose members share a name. So the group implements the APG roving
   tabindex technique directly, and every arrow movement rewrites `tabindex` on the members — the
   focused one becomes 0, the rest -1, which is what makes the next Tab leave the group instead of
   walking through it.

   Upstream gets this from `useListFocus` with `hasRovingTabIndex: true`. Two of its three settings
   are copied verbatim below, because both are load-bearing:

   - the item selector is `button, a[href], [tabindex]` and must not key off a tabindex *value*: the
     roving stamps one on every item, so `[tabindex="0"]` would drop each member the moment it is
     stamped -1. `a[href]` catches a member rendered as a link.
   - the boundary is `[role="group"], [popover]`, and the nearest one to the key event must be the
     group's own root. A member's layer renders inline inside the group (the layer mechanism does not
     portal it), so a key pressed in an open menu bubbles here; naming the group's own root is also
     what keeps a group *inside* a Popover working, since bailing on any `[popover]` ancestor would
     swallow every arrow key the group owns. *)

module Roving_hook = struct
  module T = struct
    module State = struct
      type t =
        { (* Read when a key arrives, not when the listener was attached: the orientation is an input
             and can change under a mounted group. *)
          mutable orientation : orientation
        ; mutable key_listener : Js.Unsafe.any option
        ; mutable focus_listener : Js.Unsafe.any option
        }

      let create () =
        { orientation = Horizontal; key_listener = None; focus_listener = None }
      ;;
    end

    module Input = struct
      type t = { orientation : orientation }

      let sexp_of_t { orientation } = sexp_of_orientation orientation
      let combine left _ = left
    end

    let get_string (obj : 'a) (name : string) : string =
      Option.value_map
        (Js.Opt.to_option (Js.Unsafe.get obj name : Js.js_string Js.t Js.opt))
        ~default:""
        ~f:Js.to_string
    ;;

    let set_attr (el : Dom_html.element Js.t) (name : string) (value : string) =
      ignore
        (Js.Unsafe.meth_call
           el
           "setAttribute"
           [| Js.Unsafe.inject (Js.string name); Js.Unsafe.inject (Js.string value) |])
    ;;

    let add_listener (el : Dom_html.element Js.t) (kind : string) (listener : Js.Unsafe.any) =
      ignore
        (Js.Unsafe.meth_call
           el
           "addEventListener"
           [| Js.Unsafe.inject (Js.string kind); Js.Unsafe.inject listener |])
    ;;

    let remove_listener (el : Dom_html.element Js.t) (kind : string) (listener : Js.Unsafe.any) =
      ignore
        (Js.Unsafe.meth_call
           el
           "removeEventListener"
           [| Js.Unsafe.inject (Js.string kind); Js.Unsafe.inject listener |])
    ;;

    (* Both questions are asked in JS rather than through `Js.Unsafe.get` into an OCaml bool: a `div`
       has no `.disabled` property, and `undefined` read as a bool is not a false. Same idiom the DOM
       helper for the layer trigger uses. *)
    let is_disabled : Dom_html.element Js.t -> bool =
      Js.Unsafe.eval_string
        "(function (el) { return el.disabled === true || el.getAttribute('aria-disabled') === 'true'; })"
    ;;

    (* True when the nearest boundary above the event target is the group's own root - upstream's
       boundary rule, and the thing that keeps a member's open layer from losing its arrow keys. *)
    let owns_key : Dom_html.element Js.t -> Dom_html.element Js.t -> bool =
      Js.Unsafe.eval_string
        "(function (root, target) { return target.closest('[popover], [role=\"group\"]') === root; })"
    ;;

    let active_element () : Dom_html.element Js.t =
      Js.Unsafe.get (Js.Unsafe.pure_js_expr "document") "activeElement"
    ;;

    let same (a : Dom_html.element Js.t) (b : Dom_html.element Js.t) : bool =
      phys_equal (Js.Unsafe.coerce a) (Js.Unsafe.coerce b)
    ;;

    let focus (el : Dom_html.element Js.t) = ignore (Js.Unsafe.meth_call el "focus" [||])

    let items (el : Dom_html.element Js.t) : Dom_html.element Js.t list =
      let nodes =
        Js.Unsafe.meth_call
          el
          "querySelectorAll"
          [| Js.Unsafe.inject (Js.string "button, a[href], [tabindex]") |]
      in
      let array =
        Js.Unsafe.meth_call
          (Js.Unsafe.pure_js_expr "Array")
          "from"
          [| Js.Unsafe.inject nodes |]
      in
      let length : int = Js.Unsafe.get array "length" in
      List.init length ~f:(fun i -> Js.Unsafe.get array i)
    ;;

    let enabled el = List.filter (items el) ~f:(fun item -> not (is_disabled item))

    let move_tab_stop (el : Dom_html.element Js.t) (stop : Dom_html.element Js.t) =
      List.iter (items el) ~f:(fun item ->
        set_attr item "tabindex" (if same item stop then "0" else "-1"))
    ;;

    (* Which member is the tab stop. The focused member wins if there is one, so a re-render cannot
       drag the stop back to the first item while the person is standing on the third. *)
    let stamp (el : Dom_html.element Js.t) =
      let candidates = items el in
      let active = active_element () in
      let stop =
        match List.find candidates ~f:(fun item -> same item active) with
        | Some focused -> Some focused
        | None -> List.find candidates ~f:(fun item -> not (is_disabled item))
      in
      match stop with
      | None -> ()
      | Some stop -> move_tab_stop el stop
    ;;

    let keys = function
      | Horizontal -> "ArrowRight", "ArrowLeft"
      | Vertical -> "ArrowDown", "ArrowUp"
    ;;

    let move (el : Dom_html.element Js.t) (state : State.t) (event : Dom_html.event Js.t) =
      let key = get_string event "key" in
      let forward, backward = keys state.orientation in
      let is key' = String.equal key key' in
      if is forward || is backward || is "Home" || is "End"
      then (
        let target : Dom_html.element Js.t = Js.Unsafe.get event "target" in
        if owns_key el target
        then (
          match enabled el with
          | [] -> ()
          | candidates ->
            let active = active_element () in
            let position =
              List.findi candidates ~f:(fun _ item -> same item active)
              |> Option.map ~f:fst
            in
            let count = List.length candidates in
            let index =
              if is "Home"
              then 0
              else if is "End"
              then count - 1
              else (
                (* Off the group entirely: forward enters at the first member, backward at the last. *)
                let current =
                  Option.value position ~default:(if is forward then -1 else 0)
                in
                let delta = if is forward then 1 else -1 in
                ((current + delta) mod count + count) mod count)
            in
            (match List.nth candidates index with
             | None -> ()
             | Some item ->
               ignore (Js.Unsafe.meth_call event "preventDefault" [||]);
               focus item;
               move_tab_stop el item)))
    ;;

    let listen (state : State.t) (el : Dom_html.element Js.t) =
      match state.key_listener with
      | Some _ -> ()
      | None ->
        let on_key =
          Js.wrap_callback (fun (event : Dom_html.event Js.t) -> move el state event)
        in
        state.key_listener <- Some (Js.Unsafe.inject on_key);
        add_listener el "keydown" (Js.Unsafe.inject on_key);
        (* Focus *into* the group is a roving move too: the member that receives it becomes the stop. *)
        let on_focus =
          Js.wrap_callback (fun (event : Dom_html.event Js.t) ->
            let target : Dom_html.element Js.t = Js.Unsafe.get event "target" in
            if not (is_disabled target) then move_tab_stop el target)
        in
        state.focus_listener <- Some (Js.Unsafe.inject on_focus);
        add_listener el "focusin" (Js.Unsafe.inject on_focus)
    ;;

    let apply (state : State.t) (input : Input.t) (el : Dom_html.element Js.t) =
      state.orientation <- input.orientation;
      stamp el;
      listen state el
    ;;

    let init _ _ = State.create ()
    let on_mount input state el = apply state input el
    let on_mount = `Schedule_immediately_after_this_dom_patch_completes on_mount
    let update ~old_input:_ ~new_input state el = apply state new_input el

    let destroy _ (state : State.t) el =
      (match state.key_listener with
       | None -> ()
       | Some listener -> remove_listener el "keydown" listener);
      (match state.focus_listener with
       | None -> ()
       | Some listener -> remove_listener el "focusin" listener);
      state.key_listener <- None;
      state.focus_listener <- None
    ;;
  end

  module Hook = Vdom.Attr.Hooks.Make (T)

  let attr ~orientation () =
    Vdom.Attr.create_hook "astryx-button-group-roving" (Hook.create { T.Input.orientation })
  ;;
end

(* --------------------------------------------------------------------------------------------- *)
(* The group                                                                                      *)
(* --------------------------------------------------------------------------------------------- *)

let elevation_class = function
  | None_ -> "astryx-button-group--elevation-none"
  | Low -> "astryx-button-group--elevation-low"
  | Med -> "astryx-button-group--elevation-med"
  | High -> "astryx-button-group--elevation-high"
;;

let view
  ?(attrs = [])
  ?(orientation = Horizontal)
  ?(elevation = None_)
  ?(is_disabled = false)
  ~label
  ~children
  ()
  =
  Vdom.Node.div
      ~attrs:
      (Common.Attr.class_
         [ "astryx-button-group"
         ; (match orientation with
            | Horizontal -> "astryx-button-group--horizontal"
            | Vertical -> "astryx-button-group--vertical")
         ; elevation_class elevation
         ]
       @ [ Vdom.Attr.create "role" "group"; Vdom.Attr.create "aria-label" label ]
       @ (if is_disabled then [ Vdom.Attr.create "aria-disabled" "true" ] else [])
       @ Common.Attr.data "component" "ButtonGroup"
       @ [ Roving_hook.attr ~orientation () ]
       @ attrs)
    children
;;
