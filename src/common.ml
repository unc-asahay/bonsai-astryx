(* Shared vocabulary for the port: spacing steps, size values, class names and
   the small CSS helpers the components share.

   Divergence from upstream, recorded deliberately: Astryx compiles StyleX to
   atomic CSS at build time. This port emits BEM-ish class names for structure
   and variants (so parity tests can compare them) and inline [style] attributes
   for the numeric props (gap, padding, width, height), which are per-instance
   values rather than reusable rules. The token *values* are the upstream ones —
   see src/tokens.ml and assets/tokens.css, both generated. *)

open! Core
open! Bonsai_web
open Js_of_ocaml

module Spacing = struct
  (* Astryx's numeric spacing scale: 0, 0.5, 1, 1.5, 2, 3, 4, 5, 6, 8, 10.
     Token names use a dash for the half step: --spacing-0-5. *)
  type t =
    | S0
    | S0_5
    | S1
    | S1_5
    | S2
    | S3
    | S4
    | S5
    | S6
    | S8
    | S10
  [@@deriving sexp_of]

  let step = function
    | S0 -> "0"
    | S0_5 -> "0-5"
    | S1 -> "1"
    | S1_5 -> "1-5"
    | S2 -> "2"
    | S3 -> "3"
    | S4 -> "4"
    | S5 -> "5"
    | S6 -> "6"
    | S8 -> "8"
    | S10 -> "10"
  ;;

  let var t = sprintf "var(--spacing-%s)" (step t)

  let all = [ S0; S0_5; S1; S1_5; S2; S3; S4; S5; S6; S8; S10 ]
end

(* Which state a form treats as its default. Upstream declares this in FormLayout.tsx and passes it
   down through React context; the port puts the value here, next to the other shared value types,
   because the controls and the layout both need it and neither should own the other. *)
(* Generic property reads on a JS object. A DOM event's fields are untyped from OCaml's side, and a
   missing one has to come back as a value rather than raising — so these are the only places that
   reach for [Js.Unsafe.get]. *)
let prop (obj : 'a Js.t) (name : string) = Js.Unsafe.get obj name

(* Generic DOM helpers live here rather than in whichever component needed them first: the second
   copy is how two components drift. *)
let prevent_default (obj : 'a Js.t) = ignore (Js.Unsafe.meth_call obj "preventDefault" [||])

let string_prop (obj : 'a Js.t) (name : string) : string option =
  Option.map (Js.Opt.to_option (prop obj name : Js.js_string Js.t Js.opt)) ~f:Js.to_string
;;

let bool_prop (obj : 'a Js.t) (name : string) : bool = Js.to_bool (prop obj name)

module Optionality = struct
  type t =
    | Optional
    | Required
end

module Size_value = struct
  (* Astryx: numbers are pixels, strings are used as-is. *)
  type t =
    | Px of int
    | Css of string

  let to_css = function
    | Px n -> sprintf "%dpx" n
    | Css s -> s
  ;;
end

(* Shared by Stack, Text and Heading. Astryx types these as one union whose legal
   values differ per axis: the main axis takes start|center|end|between|around|
   evenly, the cross axis takes start|center|end|stretch. Values that are illegal
   for the axis they land on fall back to that axis's neutral value. *)
module Alignment = struct
  type t =
    | Start
    | Center
    | End
    | Stretch
    | Between
    | Around
    | Evenly

  let to_string = function
    | Start -> "start"
    | Center -> "center"
    | End -> "end"
    | Stretch -> "stretch"
    | Between -> "between"
    | Around -> "around"
    | Evenly -> "evenly"
  ;;

  (* Cross axis: start | center | end | stretch. *)
  let cross_class = function
    | Start | Between -> "astryx-align--start"
    | Center | Around -> "astryx-align--center"
    | End | Evenly -> "astryx-align--end"
    | Stretch -> "astryx-align--stretch"
  ;;

  (* Main axis: start | center | end | between | around | evenly. *)
  let main_class = function
    | Start -> "astryx-justify--start"
    | Center -> "astryx-justify--center"
    | End -> "astryx-justify--end"
    | Between -> "astryx-justify--between"
    | Around -> "astryx-justify--around"
    | Evenly -> "astryx-justify--evenly"
    | Stretch -> "astryx-justify--start"
  ;;

  (* Text justification accepts only the cross-axis subset. *)
  let text_justify_class = function
    | Start -> "astryx-text--justify-start"
    | Center -> "astryx-text--justify-center"
    | End -> "astryx-text--justify-end"
    | Stretch | Between | Around | Evenly -> ""
  ;;
end

module Css = struct
  let of_pairs pairs = String.concat ~sep:"; " (List.map pairs ~f:(fun (k, v) -> sprintf "%s: %s" k v))
end

module Attr = struct
  let class_list classes = String.concat ~sep:" " (List.filter classes ~f:(Fn.non String.is_empty))

  (* [style] with empty pairs omitted, so an unstyled element carries no attribute. *)
  let style pairs =
    let pairs = List.filter pairs ~f:(fun (_, v) -> not (String.is_empty v)) in
    match pairs with
    | [] -> []
    | _ -> [ Vdom.Attr.create "style" (Css.of_pairs pairs) ]
  ;;

  let class_ classes =
    let s = class_list classes in
    if String.is_empty s then [] else [ Vdom.Attr.class_ s ]
  ;;

  let aria name value = [ Vdom.Attr.create (sprintf "aria-%s" name) value ]
  let aria_opt name = function Some v -> aria name v | None -> []
  let role r = [ Vdom.Attr.create "role" r ]

  (* data-* attributes are how the parity harness reads an element's intent, so
     every ported component states its own name and the props it received. *)
  let data name value = [ Vdom.Attr.create (sprintf "data-astryx-%s" name) value ]
end

(* A vdom hook is the only way to do DOM work that is not triggered by an event. Two things had
   been blamed on their absence — "there is no timer that can write back into the graph", and the
   overlay pillar's need to call showModal()/close() when a *value* changes — and both are wrong:
   Vdom.Attr.create_hook exists, Hooks.Make builds one, and a hook's input can carry a
   [unit Ui_effect.t] that Effect.Expert runs. The focus hooks in virtual_dom's own attr.ml are the
   worked example this follows. *)

let timeout (f : unit -> unit) (delay_ms : float) : Js.Unsafe.any =
  Js.Unsafe.meth_call
    Dom_html.window
    "setTimeout"
    (* Order matters: setTimeout takes (callback, delay). Passing the delay first is silently a
       no-op — the browser coerces it and never calls anything, which is exactly how this looked
       for one debugging round. *)
    [| Js.Unsafe.inject (Js.wrap_callback f); Js.Unsafe.inject (Js.number_of_float delay_ms) |]
;;

let clear_timeout (id : Js.Unsafe.any) : unit =
  ignore (Js.Unsafe.meth_call Dom_html.window "clearTimeout" [| Js.Unsafe.inject id |])
;;

(* Fires its effect once, [delay_ms] after the node it is attached to appears. Cancelled if the node
   is destroyed first, and restarted if the input changes — which is what a hover delay needs: the
   pointer leaving before the delay elapses must cancel the timer, not race it. *)
module Delay_hook = struct
  module T = struct
    module State = struct
      type t = { mutable id : Js.Unsafe.any option }

      let create () = { id = None }
    end

    module Input = struct
      type t =
        { (* [None] cancels: an input change is how a caller says "never mind", which is what a
             pointer leaving before the delay elapses has to say. *)
          delay_ms : float option
        ; on_elapsed : (unit Effect.t[@sexp.opaque])
        }

      (* Written by hand: this project's ppx list has no sexp deriver, and the interface wants one
         (an effect cannot be printed, so only the delay is worth showing). *)
      let sexp_of_t { delay_ms; _ } =
        Sexp.Atom (Option.value_map delay_ms ~default:"cancelled" ~f:Float.to_string)
      ;;

      let combine left right =
        { left with on_elapsed = Effect.Many [ left.on_elapsed; right.on_elapsed ] }
      ;;
    end

    let init _ _ = State.create ()
    let cancel state = Option.iter state.State.id ~f:clear_timeout

    let start state (input : Input.t) =
      cancel state;
      match input.delay_ms with
      | None -> ()
      | Some delay_ms ->
        state.id
          <- Some
               (timeout
                  (fun () ->
                    state.id <- None;
                    Effect.Expert.handle_non_dom_event_exn input.on_elapsed)
                  delay_ms)
    ;;

    let on_mount input state _ = start state input
    let on_mount = `Schedule_immediately_after_this_dom_patch_completes on_mount
    let update ~old_input:_ ~new_input state _ = start state new_input
    let destroy _ state _ = cancel state
  end

  (* The hook API is re-exported under Vdom.Attr; bonsai_web_components' own element-size hooks
     build theirs the same way. *)
  module Hook = Vdom.Attr.Hooks.Make (T)

  let attr ~delay_ms ~on_elapsed =
    Vdom.Attr.create_hook "astryx-delay" (Hook.create { T.Input.delay_ms; on_elapsed })
  ;;

  let cancel = attr ~delay_ms:None ~on_elapsed:Effect.Ignore
end

(* ------------------------------------------------------------------------------------ DOM helpers *)

let is_function : Js.Unsafe.any -> bool =
  (* Parenthesised: eval_string evaluates a *statement*, and a bare function expression is a syntax
     error there. *)
  Js.Unsafe.eval_string "(function (x) { return typeof x === 'function'; })"
;;

let has_method (el : Dom_html.element Js.t) (name : string) : bool =
  is_function (Js.Unsafe.get el name)
;;

let call (el : Dom_html.element Js.t) (name : string) : unit =
  if has_method el name then ignore (Js.Unsafe.meth_call el name [||])
;;

let is_connected (el : Dom_html.element Js.t) : bool =
  Js.to_bool (Js.Unsafe.get el "isConnected")
;;

(* ---------------------------------------------------------------------------------- the layer hook *)

(* Drives a native popover layer off a Bonsai boolean, and reports back when the *platform* closes it.

   Worth knowing before reading: a `popover="auto"` layer is dismissed by the platform itself — a
   pointer-down outside it, or Escape — and when that happens no handler of ours has run, so the value
   saying "open" is now a lie. The hook listens for the platform's own `toggle` event and reports it,
   which is the difference between a controlled component and one that quietly drifts.

   Three ordering rules, all of them learned from upstream or from the platform:

   - `hidePopover()` fires `toggle` as well, so the state is updated *before* the call: a close we
     asked for is not news, and only a close the application did not ask for is reported.
   - `showPopover()` throws if it is called while a toggle is already in progress, so it is never
     called from inside the event handler.
   - Escape is not ours to intercept. A `popover="auto"` layer closes on Escape because that is what
     the platform does with one; a caller that wants explicit-dismiss-only must render the layer with
     `popover="manual"` instead, and then the platform will leave it alone.

   jsdom has no Popover API at all, so `has_method el "showPopover"` is the guard that lets the
   component gate mount this at all. Where it is missing, the element keeps its attribute and nothing
   else happens — which is what an unsupporting browser does with it anyway. *)

module Layer_hook = struct
  module T = struct
    module State = struct
      type t =
        { mutable listener : Js.Unsafe.any option
        ; (* What the application believes. Kept here, not read back off the DOM, so that our own
             show/hide can be told apart from the platform's. *)
          mutable is_open : bool
        }

      let create () = { listener = None; is_open = false }
    end

    module Input = struct
      type t =
        { is_open : bool
        ; on_platform_close : (unit Effect.t[@sexp.opaque])
        }

      let sexp_of_t { is_open; on_platform_close = _ } = Sexp.Atom (Bool.to_string is_open)

      let combine left _ = left
    end

    (* `:popover-open` is the question "is this layer actually up?", which is not the same as the value
       the caller holds — the platform can have taken it down since. *)
    let platform_open (el : Dom_html.element Js.t) : bool =
      Js.Unsafe.meth_call
        el
        "matches"
        [| Js.Unsafe.inject (Js.string ":popover-open") |]
    ;;

    let attach (state : State.t) (input : Input.t) (el : Dom_html.element Js.t) =
      match state.listener with
      | Some _ -> ()
      | None ->
        let listener =
          Js.wrap_callback (fun (event : Dom_html.event Js.t) ->
            let new_state =
              Option.value_map
                (Js.Opt.to_option
                   (Js.Unsafe.get event "newState" : Js.js_string Js.t Js.opt))
                ~default:""
                ~f:Js.to_string
            in
            (* A close we ran ourselves has already moved the state, so this only fires for the
               platform's own dismissal — the case where nothing else in the application knows. *)
            if String.equal new_state "closed" && state.is_open
            then (
              state.is_open <- false;
              Effect.Expert.handle_non_dom_event_exn input.on_platform_close))
        in
        state.listener <- Some (Js.Unsafe.inject listener);
        ignore
          (Js.Unsafe.meth_call
             el
             "addEventListener"
             [| Js.Unsafe.inject (Js.string "toggle"); Js.Unsafe.inject listener |])
    ;;

    let apply (state : State.t) (input : Input.t) (el : Dom_html.element Js.t) =
      attach state input el;
      (* Before the call, deliberately: see the note above about hidePopover firing toggle. *)
      state.is_open <- input.is_open;
      if has_method el "showPopover"
      then (
        let open_now = platform_open el in
        if input.is_open && not open_now
        then call el "showPopover"
        else if (not input.is_open) && open_now
        then call el "hidePopover")
    ;;

    let init _ _ = State.create ()
    let on_mount input state el = apply state input el
    let on_mount = `Schedule_immediately_after_this_dom_patch_completes on_mount
    let update ~old_input:_ ~new_input state el = apply state new_input el

    let destroy _ (state : State.t) el =
      match state.listener with
      | None -> ()
      | Some listener ->
        state.listener <- None;
        ignore
          (Js.Unsafe.meth_call
             el
             "removeEventListener"
             [| Js.Unsafe.inject (Js.string "toggle"); Js.Unsafe.inject listener |])
    ;;
  end

  module Hook = Vdom.Attr.Hooks.Make (T)

  let attr ~is_open ~on_platform_close =
    Vdom.Attr.create_hook "astryx-layer" (Hook.create { T.Input.is_open; on_platform_close })
  ;;
end

(* ------------------------------------------------------------- the layer's trigger, wired up *)

(* Upstream does not ask the caller to write the trigger's ARIA. It *finds* the trigger — the first
   `button, [role="button"]` among its children — and applies `aria-haspopup`, `aria-expanded` and
   `aria-controls` to it, plus the click that toggles the layer. Porting that faithfully means the same
   imperative step here, because `aria-expanded` is *state*: an attribute passed in by the caller could
   only ever be a snapshot, and would go stale the first time the layer opened.

   One subtlety worth keeping, straight from upstream: the keydown path is attached **only** to something
   that is not a native `<button>`. A real button synthesizes a click from Enter and Space, so adding a
   keydown handler for it would toggle the layer twice. A `role="button"` div gets no such synthesis,
   which is exactly the case upstream handles explicitly. *)

module Layer_trigger_hook = struct
  module T = struct
    module State = struct
      type t =
        { (* The latest input, not the one captured when the listener was attached: the caller's effect
             is rebuilt on every render, and a stale closure would act on an old value. *)
          mutable on_toggle : (unit Effect.t[@sexp.opaque])
        ; mutable click_listener : Js.Unsafe.any option
        ; mutable key_listener : Js.Unsafe.any option
        }

      let create () =
        { on_toggle = Effect.Ignore; click_listener = None; key_listener = None }
      ;;
    end

    module Input = struct
      type t =
        { is_open : bool
        ; controls : string
        ; haspopup : string
        ; on_toggle : (unit Effect.t[@sexp.opaque])
        }

      let sexp_of_t { is_open; controls; haspopup; on_toggle = _ } =
        Sexp.List
          [ Sexp.Atom (Bool.to_string is_open)
          ; Sexp.Atom controls
          ; Sexp.Atom haspopup
          ]
      ;;

      let combine left _ = left
    end

    let get_string (obj : 'a) (name : string) : string =
      Option.value_map
        (Js.Opt.to_option (Js.Unsafe.get obj name : Js.js_string Js.t Js.opt))
        ~default:""
        ~f:Js.to_string
    ;;

    (* The first button among the children, which is what upstream looks for. *)
    let find_button (el : Dom_html.element Js.t) : Dom_html.element Js.t option =
      let found : Dom_html.element Js.t Js.opt =
        Js.Unsafe.meth_call
          el
          "querySelector"
          [| Js.Unsafe.inject (Js.string "button, [role=\"button\"]") |]
      in
      Js.Opt.to_option found
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

    let listen (state : State.t) (button : Dom_html.element Js.t) =
      match state.click_listener with
      | Some _ -> ()
      | None ->
        let click =
          Js.wrap_callback (fun _ ->
            Effect.Expert.handle_non_dom_event_exn state.on_toggle)
        in
        state.click_listener <- Some (Js.Unsafe.inject click);
        add_listener button "click" (Js.Unsafe.inject click);
        (* A native button already produces a click from Enter and Space; anything else does not. *)
        let is_native_button = String.equal (get_string button "tagName") "BUTTON" in
        let role =
          Option.value_map
            (Js.Opt.to_option
               (Js.Unsafe.meth_call
                  button
                  "getAttribute"
                  [| Js.Unsafe.inject (Js.string "role") |]
                : Js.js_string Js.t Js.opt))
            ~default:""
            ~f:Js.to_string
        in
        (* Both halves of upstream's condition: a native button needs no keydown at all, and a
           non-button that never claimed the role has no keyboard contract to honour. *)
        if (not is_native_button) && String.equal role "button"
        then (
          let key =
            Js.wrap_callback (fun (event : Dom_html.event Js.t) ->
              let key = get_string event "key" in
              if String.equal key "Enter" || String.equal key " "
              then (
                ignore (Js.Unsafe.meth_call event "preventDefault" [||]);
                Effect.Expert.handle_non_dom_event_exn state.on_toggle))
          in
          state.key_listener <- Some (Js.Unsafe.inject key);
          add_listener button "keydown" (Js.Unsafe.inject key))
    ;;

    let apply (state : State.t) (input : Input.t) (el : Dom_html.element Js.t) =
      (* Stored before anything can fire: the listeners read it, and they outlive this call. *)
      state.on_toggle <- input.on_toggle;
      match find_button el with
      | None -> ()
      | Some button ->
        set_attr button "aria-haspopup" input.haspopup;
        set_attr button "aria-expanded" (Bool.to_string input.is_open);
        set_attr button "aria-controls" input.controls;
        listen state button
    ;;

    let init _ _ = State.create ()
    let on_mount input state el = apply state input el
    let on_mount = `Schedule_immediately_after_this_dom_patch_completes on_mount
    let update ~old_input:_ ~new_input state el = apply state new_input el

    let destroy _ (state : State.t) el =
      (match find_button el with
       | None -> ()
       | Some button ->
         (match state.click_listener with
          | None -> ()
          | Some listener -> remove_listener button "click" listener);
         (match state.key_listener with
          | None -> ()
          | Some listener -> remove_listener button "keydown" listener));
      state.click_listener <- None;
      state.key_listener <- None
    ;;
  end

  module Hook = Vdom.Attr.Hooks.Make (T)

  (* [haspopup] is upstream's `triggerProps['aria-haspopup']`: "dialog" when the layer is one, "true"
     otherwise. It is an argument rather than a constant because the caller knows which it is. *)
  let attr ~controls ~is_open ~on_toggle ?(haspopup = "dialog") () =
    Vdom.Attr.create_hook
      "astryx-layer-trigger"
      (Hook.create { T.Input.is_open; controls; haspopup; on_toggle })
  ;;
end

(* The first consumer's values, and the defaults. Named rather than written twice, because "ButtonGroup's
   item set" is a fact about ButtonGroup that happens to be the default here. *)
let button_group_item_selector = "button, a[href], [tabindex]"
let button_group_boundary_selector = "[popover], [role=\"group\"]"

module List_focus = struct
  (* The mechanism's own axis. A consumer whose own type is this shape re-exports it destructively so the
     two are the same type rather than convertible - Button_group is one. *)
  type orientation =
    | Horizontal
    | Vertical
  (* Hand-written because the hook functor needs it and this project has no sexp deriver. *)
  let sexp_of_orientation = function
    | Horizontal -> Sexp.Atom "horizontal"
    | Vertical -> Sexp.Atom "vertical"
  ;;
  module T = struct
    module State = struct
      type t =
        { (* Read when a key arrives, not when the listener was attached: the orientation is an input
             and can change under a mounted group. *)
          mutable orientation : orientation
        ; mutable item_selector : string
        ; mutable boundary_selector : string
        ; mutable caret_guard : bool
        ; mutable key_listener : Js.Unsafe.any option
        ; mutable focus_listener : Js.Unsafe.any option
        }

      let create () =
        { orientation = Horizontal
        ; item_selector = button_group_item_selector
        ; boundary_selector = button_group_boundary_selector
        ; caret_guard = false
        ; key_listener = None
        ; focus_listener = None
        }
      ;;
    end

    module Input = struct
      type t =
        { orientation : orientation
        ; (* Which descendants are members. ButtonGroup's set and a toolbar's differ, and neither can be
             inferred from the container. *)
          item_selector : string
        ; (* What counts as "inside this widget" when a key is pressed: the nearest ancestor matching this,
             walking up from the event target, must be the element this hook is attached to. It is how a
             member's own open layer keeps its arrow keys, and how a toolbar inside a toolbar behaves. *)
          boundary_selector : string
        ; (* True to leave a text input's arrow keys to its caret unless the caret is at the edge the key
             moves toward. A toolbar can contain inputs; a button group cannot, which is why this defaults
             off and why the default is what keeps the first consumer's behaviour intact. *)
          caret_guard : bool
        }

      let sexp_of_t { orientation; item_selector; boundary_selector; caret_guard } =
        Sexp.List
          [ sexp_of_orientation orientation
          ; Sexp.Atom item_selector
          ; Sexp.Atom boundary_selector
          ; Sexp.Atom (Bool.to_string caret_guard)
          ]
      ;;

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
    (* The selector is an argument rather than baked into the JS: evaluating a built string per key event
       would be the cost of a dynamic selector, and `closest` takes one as an argument anyway. The
       comparison is made in JS and handed back as a bool, because this Js_of_ocaml does not expose Js.Opt
       and a boxed option is not worth reaching for. *)
    let owns_key (state : State.t) (root : Dom_html.element Js.t) (target : Dom_html.element Js.t) : bool =
      let js =
        Js.Unsafe.eval_string
          "(function (target, root, selector) { return target.closest(selector) === root; })"
      in
      Js.Unsafe.fun_call
        js
        [| Js.Unsafe.inject target
         ; Js.Unsafe.inject root
         ; Js.Unsafe.inject (Js.string state.boundary_selector)
        |]
    ;;

    let active_element () : Dom_html.element Js.t =
      Js.Unsafe.get (Js.Unsafe.pure_js_expr "document") "activeElement"
    ;;

    let same (a : Dom_html.element Js.t) (b : Dom_html.element Js.t) : bool =
      phys_equal (Js.Unsafe.coerce a) (Js.Unsafe.coerce b)
    ;;

    let focus (el : Dom_html.element Js.t) = ignore (Js.Unsafe.meth_call el "focus" [||])

    let items (state : State.t) (el : Dom_html.element Js.t) : Dom_html.element Js.t list =
      let nodes =
        Js.Unsafe.meth_call
          el
          "querySelectorAll"
          [| Js.Unsafe.inject (Js.string state.item_selector) |]
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

    let enabled state el = List.filter (items state el) ~f:(fun item -> not (is_disabled item))

    let move_tab_stop (state : State.t) (el : Dom_html.element Js.t) (stop : Dom_html.element Js.t) =
      List.iter (items state el) ~f:(fun item ->
        set_attr item "tabindex" (if same item stop then "0" else "-1"))
    ;;

    (* Which member is the tab stop. The focused member wins if there is one, so a re-render cannot
       drag the stop back to the first item while the person is standing on the third. *)
    let stamp (state : State.t) (el : Dom_html.element Js.t) =
      let candidates = items state el in
      let active = active_element () in
      let stop =
        match List.find candidates ~f:(fun item -> same item active) with
        | Some focused -> Some focused
        | None -> List.find candidates ~f:(fun item -> not (is_disabled item))
      in
      match stop with
      | None -> ()
      | Some stop -> move_tab_stop state el stop
    ;;

    let keys = function
      | Horizontal -> "ArrowRight", "ArrowLeft"
      | Vertical -> "ArrowDown", "ArrowUp"
    ;;

    (* True when the key belongs to a caret rather than to the widget. An input inside a toolbar is the case
       this exists for: an arrow at the end of the text should leave the input, an arrow in the middle of it
       should move the caret. Only inputs and contenteditable regions are considered - a textarea keeps its
       own arrows for its own lines, and a checkbox has no caret to guard. *)
    let caret_keeps_key (state : State.t) ~(forward : bool) (target : Dom_html.element Js.t) : bool =
      if not state.caret_guard
      then false
      else (
        let js =
          Js.Unsafe.eval_string
            "(function (el, forward) { var tag = el.tagName; if (tag !== 'INPUT' && el.isContentEditable !== true) { return false; } if (el.type === 'checkbox' || el.type === 'radio' || el.type === 'range') { return false; } var start = el.selectionStart; var end = el.selectionEnd; if (start === null || end === null) { return false; } if (start !== end) { return true; } var length = (el.value || '').length; return forward ? start < length : start > 0; })"
        in
        (Js.Unsafe.fun_call js [| Js.Unsafe.inject target; Js.Unsafe.inject (Js.bool forward) |] : bool))
    ;;

    let move (el : Dom_html.element Js.t) (state : State.t) (event : Dom_html.event Js.t) =
      let key = get_string event "key" in
      let forward, backward = keys state.orientation in
      let is key' = String.equal key key' in
      if is forward || is backward || is "Home" || is "End"
      then (
        let target : Dom_html.element Js.t = Js.Unsafe.get event "target" in
        if caret_keeps_key state ~forward:(is forward) target
        then ()
        else if owns_key state el target
        then (
          match enabled state el with
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
               move_tab_stop state el item)))
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
            if not (is_disabled target) then move_tab_stop state el target)
        in
        state.focus_listener <- Some (Js.Unsafe.inject on_focus);
        add_listener el "focusin" (Js.Unsafe.inject on_focus)
    ;;

    let apply (state : State.t) (input : Input.t) (el : Dom_html.element Js.t) =
      state.orientation <- input.orientation;
      state.item_selector <- input.item_selector;
      state.boundary_selector <- input.boundary_selector;
      state.caret_guard <- input.caret_guard;
      stamp state el;
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

  let attr
    ~orientation
    ?(item_selector = button_group_item_selector)
    ?(boundary_selector = button_group_boundary_selector)
    ?(caret_guard = false)
    ()
    =
    Vdom.Attr.create_hook
      "astryx-list-focus"
      (Hook.create { T.Input.orientation; item_selector; boundary_selector; caret_guard })
  ;;
end
