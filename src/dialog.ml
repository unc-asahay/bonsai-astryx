open! Core
open! Bonsai_web
open Js_of_ocaml

module Attr = Common.Attr

type variant =
  | Standard
  | Fullscreen

type purpose =
  | Info
  | Form
  | Required

type position =
  { top : string option
  ; bottom : string option
  ; start : string option
  ; end_ : string option
  }

(* jsdom has no dialog behaviour at all (showModal and close simply do not exist on its elements,
   which is why upstream's own isInline path exists and why this port checks before calling). A real
   browser has both. Calling through a missing method would throw where the structural gate runs. *)
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

(* The modal state follows the *value*, not an event: no vdom event fires when a caller decides to
   open a dialog, which is exactly the case Gate 23 opened up. The hook is given is_open on every
   update and puts the element in step with it, so a caller that ignores the close callback gets the
   dialog back — the DOM follows the value, the value is the truth. *)
(* The element a dialog asks to have focused when it opens, if it marks one. The platform's own focus
   delegate picks the first *tabbable* descendant — a close button, typically — so a dialog whose title
   is marked gets the title focused instead, and a screen reader hears the dialog's name rather than
   "Close". Upstream's DialogHeader focuses its title from context; here the marking is a data attribute
   and the focusing belongs to the hook that already runs on open, because that is the only place that
   knows the dialog opened at all. *)
let focus_target (el : Dom_html.element Js.t) : Dom_html.element Js.t option =
  let found : Dom_html.element Js.t Js.opt =
    Js.Unsafe.meth_call
      el
      "querySelector"
      [| Js.Unsafe.inject (Js.string "[data-astryx-focus-on-open]") |]
  in
  Js.Opt.to_option found
;;

module Dialog_hook = struct
  module T = struct
    module State = struct
      type t = { mutable trigger : Dom_html.element Js.t option }

      let create () = { trigger = None }
    end

    module Input = struct
      type t = { is_open : bool }

      let sexp_of_t { is_open } = Sexp.Atom (Bool.to_string is_open)
      let combine left _ = left
    end

    (* The state type is named because the record field is not in scope from outside its module. *)
    let apply (state : State.t) (input : Input.t) (el : Dom_html.element Js.t) =
      let is_open_now = Js.to_bool (Js.Unsafe.get el "open") in
      if input.is_open && not is_open_now
      then (
        (* Remembered before the modal takes focus, so it can be handed back on close — upstream
           captures the same element for the same reason (it also uses it as an animation origin,
           which this port does not). *)
        let active : Dom_html.element Js.t = Js.Unsafe.get Dom_html.document "activeElement" in
        state.trigger
          <- (if is_connected active then Some (Js.Unsafe.coerce active) else None);
        (* Also what puts the element in the top layer: the [open] attribute alone would be a
           non-modal dialog wearing a modal's name. *)
        call el "showModal";
        (* After showModal, deliberately: the platform has just chosen its own focus target, and this is
           the correction. A dialog that marks nothing keeps the platform's choice. *)
        (match focus_target el with
         | Some target -> ignore (Js.Unsafe.meth_call target "focus" [||])
         | None -> ()))
      else if (not input.is_open) && is_open_now
      then (
        call el "close";
        (match state.trigger with
         | Some trigger when is_connected trigger ->
           ignore (Js.Unsafe.meth_call trigger "focus" [||])
         | Some _ | None -> ());
        state.trigger <- None)
    ;;

    let init _ _ = State.create ()
    let on_mount input state el = apply state input el
    let on_mount = `Schedule_immediately_after_this_dom_patch_completes on_mount
    let update ~old_input:_ ~new_input state el = apply state new_input el
    let destroy _ (state : State.t) _ = state.trigger <- None
  end

  module Hook = Vdom.Attr.Hooks.Make (T)

  let attr ~is_open = Vdom.Attr.create_hook "astryx-dialog" (Hook.create { T.Input.is_open })
end

let purpose_name = function
  | Info -> "info"
  | Form -> "form"
  | Required -> "required"
;;

let style_of_position (position : position) =
  List.filter_opt
    [ Option.map position.top ~f:(fun v -> "top:" ^ v)
    ; Option.map position.bottom ~f:(fun v -> "bottom:" ^ v)
    ; Option.map position.start ~f:(fun v -> "inset-inline-start:" ^ v)
    ; Option.map position.end_ ~f:(fun v -> "inset-inline-end:" ^ v)
      (* Any explicit offset turns off the auto margins that centre the dialog. *)
    ; (match position with
       | { top = None; bottom = None; start = None; end_ = None } -> None
       | _ -> Some "margin:0")
    ]
  |> String.concat ~sep:";"
;;

let sizing_style ?width ?max_height () =
  List.filter_opt
    [ Option.map width ~f:(fun v -> "width:" ^ v)
    ; Option.map max_height ~f:(fun v -> "max-height:" ^ v)
    ]
  |> String.concat ~sep:";"
;;

let view
      ?(attrs = [])
      ?(is_inline = false)
      ?width
      ?max_height
      ?position
      ?(variant = Standard)
      ?(purpose = Info)
      ?padding
      ?labelled_by
      ?described_by
      ?role
      ~is_open
      ~on_open_change
      ~id
      ~children
      ()
  =
  (* A function of the resolved children, because they arrive as a tree: a container that composes
     this one and wires a callback into its own content (Alert_dialog does) cannot pass a plain list. *)
  let content children =
    Vdom.Node.div
      ~attrs:
        (Attr.class_ [ "astryx-dialog__inner" ]
         @ (match padding with
            | Some step -> [ Vdom.Attr.create "style" ("padding:var(--spacing-" ^ Common.Spacing.step step ^ ")") ]
            | None -> []))
      children
  in
  (* What names the dialog and what describes it. Both are arguments rather than context lookups: a
     child in this port is already built by the time the container sees it. *)
  let association_attrs =
    List.concat
      [ (match labelled_by with Some title_id -> Attr.aria "labelledby" title_id | None -> [])
      ; (match described_by with Some text_id -> Attr.aria "describedby" text_id | None -> [])
      ]
  in
  (* The role is derived from [purpose] unless the caller states one. Upstream's AlertDialog is the
     caller that does: it is built on the form purpose but is not a form, and its inline preview is not
     modal at all, so it asks for "group" there — an alertdialog role would promise an interruption and
     a focus trap it does not have. A default, not a verdict. *)
  let role_attr =
    Vdom.Attr.create "role"
      (Option.value role ~default:(match purpose with Required -> "alertdialog" | Info | Form -> "dialog"))
  in
  (* One style attribute, not two: virtual_dom merges attributes last-wins, so a second [style]
     would silently discard the first — which is exactly what happened to the position until the gate
     caught it. *)
  let surface_style =
    String.concat
      ~sep:";"
      (List.filter (sizing_style ?width ?max_height () :: [ Option.value_map position ~default:"" ~f:style_of_position ]) ~f:(fun part -> not (String.is_empty part)))
  in
  Bonsai.map2
    (Bonsai.map2 is_open on_open_change ~f:(fun is_open on_open_change -> is_open, on_open_change))
    children
    ~f:(fun (is_open, on_open_change) children ->
  let content = content children in
  if is_inline
  then
    (* The showcase path upstream documents: the same content as ordinary markup, with no top layer
       and no modal behaviour, so a gate without a browser can still read the structure. *)
    if not is_open
    then Vdom.Node.none
    else
      Vdom.Node.div
           ~attrs:
             (Attr.class_
                ([ "astryx-dialog__inline" ]
                 @ (match variant with Fullscreen -> [ "astryx-dialog--fullscreen" ] | Standard -> []))
              @ Attr.data "component" "Dialog"
              @ [ Vdom.Attr.create "id" id
                ; role_attr
                ; Vdom.Attr.create "data-purpose" (purpose_name purpose)
                ]
              @ association_attrs
              @ (if String.is_empty surface_style then [] else [ Vdom.Attr.create "style" surface_style ])
              @ attrs)
           [ content ]
  else
    Vdom.Node.create
        "dialog"
        ~attrs:
          (Attr.class_
             ([ "astryx-dialog" ]
              @ (match variant with Fullscreen -> [ "astryx-dialog--fullscreen" ] | Standard -> []))
           @ Attr.data "component" "Dialog"
           @ [ Vdom.Attr.create "id" id
             ; Vdom.Attr.create "aria-modal" "true"
             ; Vdom.Attr.create "data-purpose" (purpose_name purpose)
               (* Required is what makes it an alert dialog — a dialog that refuses every exit is one
                  the user has to answer. Upstream keys the role off purpose, not off a variant. *)
             ; role_attr
             ; Dialog_hook.attr ~is_open
             ; (* A click that lands on the dialog element itself is a click on ::backdrop: the
                  content sits inside it, so target and currentTarget differ for anything the user
                  actually aimed at. *)
               Vdom.Attr.on_click (fun ev ->
                 if phys_equal (Js.Unsafe.get ev "target") (Js.Unsafe.get ev "currentTarget")
                 then (
                   match purpose with
                   | Info -> on_open_change false
                   | Form | Required -> Effect.Many [])
                 else Effect.Many [])
             ; (* Anything that closes the dialog *inside* it comes back through here: a
                  <form method="dialog"> submit button, or a caller's own close() call. The platform
                  has a way to close a dialog without any JavaScript, and this is what reports it —
                  which is why the children can stay plain nodes and a caller never needs to hand the
                  setter down into the content. *)
               Vdom.Attr.on_close (fun _ -> on_open_change false)
             ; (* Escape. Required keeps the event: upstream's "never called automatically" purpose. *)
               Vdom.Attr.on_cancel (fun ev ->
                 (match purpose with
                  | Required -> Common.prevent_default ev
                  | Info | Form -> Common.prevent_default ev);
                 (match purpose with
                  | Required -> Effect.Many []
                  | Info | Form -> on_open_change false))
             ]
           @ association_attrs
           @ (if String.is_empty surface_style then [] else [ Vdom.Attr.create "style" surface_style ])
           @ attrs)
        [ content ])
;;
