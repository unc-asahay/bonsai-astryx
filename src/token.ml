open! Core
open Bonsai_web
open Js_of_ocaml

type size =
  | Sm
  | Md
  | Lg

type color =
  | Default
  | Red
  | Orange
  | Yellow
  | Green
  | Teal
  | Cyan
  | Blue
  | Purple
  | Pink
  | Gray
;;

let size_string = function
  | Sm -> "sm"
  | Md -> "md"
  | Lg -> "lg"
;;

let color_string = function
  | Default -> "default"
  | Red -> "red"
  | Orange -> "orange"
  | Yellow -> "yellow"
  | Green -> "green"
  | Teal -> "teal"
  | Cyan -> "cyan"
  | Blue -> "blue"
  | Purple -> "purple"
  | Pink -> "pink"
  | Gray -> "gray"
;;

(* Framed the same way as [Common.prevent_default]: js_of_ocaml's object types do not name
   [stopPropagation] on every event flavour this handler can receive, so the call is made by name.
   Upstream stops propagation on the remove click so dismissing a token never also reaches an
   enclosing handler; the container's own [closest] guard would already skip it, and this keeps the
   stronger promise both. *)
let stop_propagation (obj : 'a Js.t) = ignore (Js.Unsafe.meth_call obj "stopPropagation" [||])

let view
  ?(size = Md)
  ?(color = Default)
  ?icon
  ?end_content
  ?(is_disabled = false)
  ?(is_label_hidden = false)
  ?description
  ?href
  ?on_click
  ?on_remove
  ?(attrs = [])
  label
  =
  (* Branch order begins here: the resolved role, not the presence of a prop, decides whether this
     is a link at all - a disabled href falls through to the steps below (see Interactive_role). *)
  let role = Interactive_role.of_inputs ~href ~has_on_click:(Option.is_some on_click) ~is_disabled in
  let shared =
    (if is_label_hidden then Common.Attr.aria "label" label else [])
    @ Common.Attr.aria_opt "description" description
  in
  let label_node =
    let classes =
      "astryx-token__label"
      :: (if is_label_hidden then [ "astryx-token__label--hidden" ] else [])
    in
    Vdom.Node.span ~attrs:(Common.Attr.class_ classes) [ Vdom.Node.text label ]
  in
  let remove_button =
    Option.value_map on_remove ~default:Vdom.Node.none ~f:(fun remove ->
      Vdom.Node.create
        "button"
        ~attrs:
          (Common.Attr.class_ [ "astryx-token__remove" ]
           @ Common.Attr.aria "label" (sprintf "Remove %s" label)
           @ [ Vdom.Attr.create "type" "button"
             ; Vdom.Attr.on_click (fun event ->
                 stop_propagation event;
                 remove event)
             ; (if is_disabled then Vdom.Attr.disabled else Vdom.Attr.empty)
             ])
        [ Icon.view ~size:Icon.Xsm ~color:Icon.Inherit ~name:"close" () ])
  in
  (* themeProps('token', {color, size}): upstream reflects visual props as data-* attributes next to
     the stable component class; this port's namespace carries them (data-astryx-color/-size), which
     is the convention every other port here follows. The pressable marker is upstream's constant
     [pressableProps] - marker only; the controller that answers it is not ported. *)
  let surface ~interactive =
    Common.Attr.data "component" "Token"
    @ Common.Attr.data "color" (color_string color)
    @ Common.Attr.data "size" (size_string size)
    @ (if interactive && not is_disabled then [ Vdom.Attr.create "data-astryx-pressable" "" ] else [])
    @ attrs
    @ shared
  in
  let root_classes ~interactive =
    [ "astryx-token"
    ; sprintf "astryx-token--%s" (size_string size)
    ; sprintf "astryx-token--%s" (color_string color)
    ]
    @ (if interactive then [ "astryx-token--interactive" ] else [])
    @ (if is_disabled then [ "astryx-token--disabled" ] else [])
  in
  (* The href shares the port's safe-destination contract with Link and Citation: one unsafe
     destination renders the same markup without it. *)
  let href_attrs =
    match Link_destination.resolve ~component:Link_destination.Anchor ~href ~to_:None with
    | Link_destination.Native (Some h) -> [ Vdom.Attr.href h ]
    | Link_destination.Native None | Link_destination.Rejected -> []
    (* [Routed] only exists for a caller-supplied component, and a token has none. *)
    | Link_destination.Routed _ -> []
  in
  let content_children =
    Option.to_list icon @ [ label_node ] @ Option.to_list end_content @ [ remove_button ]
  in
  match (role : Interactive_role.t) with
  | Link ->
    (match on_remove with
     | None ->
      (* Branch 1: the anchor is the root. Upstream attaches no onClick here - role priority has
         decided navigation, and a click handler on this branch would never be reached in React's
         own wiring either; the caller's [on_click] is honoured only on the branches below. *)
      Vdom.Node.create
        "a"
        ~attrs:
          (Common.Attr.class_ (root_classes ~interactive:true)
           @ surface ~interactive:true
           @ href_attrs
           @ (if is_disabled then [ Vdom.Attr.create "aria-disabled" "true" ] else []))
        content_children
     | Some _ ->
      (* Branch 2a: a button cannot nest inside an anchor, so the link and the remove button become
         siblings under a span that carries the focus-within outline instead of the link's own. *)
      let inner_link =
        Vdom.Node.create
          "a"
          ~attrs:
            (Common.Attr.class_ [ "astryx-token__invisible-button" ]
             @ href_attrs
             @ (if is_disabled then [ Vdom.Attr.create "aria-disabled" "true" ] else []))
          [ label_node ]
      in
      Vdom.Node.create
        "span"
        ~attrs:
          (Common.Attr.class_ (root_classes ~interactive:true @ [ "astryx-token--container" ])
           @ surface ~interactive:true)
        (Option.to_list icon @ [ inner_link ] @ Option.to_list end_content @ [ remove_button ]))
  | Button | Inert ->
    (match on_click with
     | Some click ->
      (* Branch 2b: real button semantics under a visible span. The root handler is upstream's
         exact guard - clicks originating inside any button/anchor belong to that element, not to
         the container - and disappears entirely when disabled. *)
      let container_click event =
        let target : Dom_html.element Js.t = Js.Unsafe.meth_call event "target" [||] in
        (* The cast lands by annotating the call itself - [Js.Unsafe.coerce] in this js_of_ocaml
           only maps [Js.t] to [Js.t], so it cannot carry a value into the opt world; [Menu_focus]'s
           [closest] does it the same way. Upstream's guard in one line: targets inside any
           button/anchor belong to that element, not to the container. *)
        let inside =
          Js.Opt.to_option
            (Js.Unsafe.meth_call target "closest" [| Js.Unsafe.inject (Js.string "button, a") |]
             : Dom_html.element Js.t Js.Opt.t)
        in
        match inside with
        | Some _ -> Effect.Ignore
        | None -> click event
      in
      let invisible_button =
        Vdom.Node.create
          "button"
          ~attrs:
            (Common.Attr.class_ [ "astryx-token__invisible-button" ]
             @ [ Vdom.Attr.create "type" "button"; Vdom.Attr.on_click click ]
             @ (if is_disabled then [ Vdom.Attr.disabled ] else []))
          [ label_node ]
      in
      Vdom.Node.create
        "span"
        ~attrs:
          (Common.Attr.class_ (root_classes ~interactive:true @ [ "astryx-token--container" ])
           @ surface ~interactive:true
           @ (if is_disabled then [] else [ Vdom.Attr.on_click container_click ]))
        (Option.to_list icon
         @ [ invisible_button ]
         @ Option.to_list end_content
         @ [ remove_button ])
     | None ->
      (* Branch 3: nothing interactive, so no interactive modifier and no handlers. *)
      Vdom.Node.create "span" ~attrs:(Common.Attr.class_ (root_classes ~interactive:false) @ surface ~interactive:false) content_children)
;;