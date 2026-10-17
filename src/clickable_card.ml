open! Core
open! Bonsai_web
open Js_of_ocaml

(* The container rules are the extracted mechanism, shared with Selectable_card. *)
module K = Common.Clickable_container

(* Navigation is decided in one JS call on purpose. This Js_of_ocaml exposes neither Js.Opt nor a bool
   coercion, so reading ctrlKey/metaKey one field at a time is exactly where that bites - and the port
   already uses this shape for the roving key check. Returns whether it navigated, so a caller can tell a
   refused href from a taken one. *)
let navigate ~event ~href ~target =
  let js =
    Js.Unsafe.eval_string
      "(function (event, href, target, safe) {\
       if (!safe) return false;\
       var newTab = target === '_blank' || event.ctrlKey === true || event.metaKey === true;\
       if (newTab) { window.open(href, '_blank', 'noopener'); return true; }\
       window.location.href = href; return true; })"
  in
  Js.Unsafe.fun_call
    js
    [| Js.Unsafe.inject event
     ; Js.Unsafe.inject (Js.string href)
     ; Js.Unsafe.inject (Js.string (Option.value target ~default:""))
     ; Js.Unsafe.inject (Citation.is_safe_url href)
    |]
;;

let open_in_new_tab href =
  let js =
    Js.Unsafe.eval_string
      "(function (href) { window.open(href, '_blank', 'noopener'); })"
  in
  (* Annotated: Js.Unsafe.fun_call answers `'a`, and an unannotated call reads as a non-returning
     statement (warning 21, which is an error here). *)
  let (_ : unit) = Js.Unsafe.fun_call js [| Js.Unsafe.inject (Js.string href) |] in
  ()
;;

let view
  ?on_click
  ?href
  ?target
  ?(is_disabled = false)
  ?padding
  ?variant
  ?elevation
  ?width
  ?height
  ?max_width
  ?(attrs = [])
  ~label
  children
  =
  let surface_click (event : Dom_html.mouseEvent Js.t) =
    let root = Js.Unsafe.get event "currentTarget" in
    let target_el = Js.Unsafe.get event "target" in
    if is_disabled
    then Effect.Ignore
    else if K.has_text_selection root
    then Effect.Ignore
    else if K.is_interactive_target ~root ~target:target_el
    then Effect.Ignore
    else (
      let after_handler =
        match on_click with
        | None -> Effect.Ignore
        | Some handler -> handler event
      in
      match href with
      | None -> after_handler
      | Some href ->
        (* A refused href does not navigate, and that is a decision rather than a failure: the caller's
           handler above still ran. *)
        if Citation.is_safe_url href
        then (
          let (_ : bool) = navigate ~event ~href ~target in
          after_handler)
        else after_handler)
  in
  let surface_mouse_up (event : Dom_html.mouseEvent Js.t) =
    if is_disabled
    then Effect.Ignore
    else (
      (* Read in JS: a mouse event's button is a number, and this is the same shape as the port's own
         roving-key check - one evaluator, the comparison made in JS, the answer handed back. *)
      let button =
        (Js.Unsafe.fun_call
           (Js.Unsafe.eval_string
              "(function (e) { return typeof e.button === 'number' ? e.button : -1; })")
           [| Js.Unsafe.inject event |]
         : int)
      in
      match href with
      | Some href when button = 1 && Citation.is_safe_url href ->
        let root = Js.Unsafe.get event "currentTarget" in
        let target_el = Js.Unsafe.get event "target" in
        if phys_equal target_el root || not (K.is_interactive_target ~root ~target:target_el)
        then (
          open_in_new_tab href;
          Effect.Ignore)
        else Effect.Ignore
      | _ -> Effect.Ignore)
  in
  let interactive =
    match href with
    | Some href ->
      (* The attribute is gated as well as the navigation, and that is a deliberate difference from
         copying the JSX: upstream hands the href to a framework link component, and React vets the hrefs
         it writes as attributes. Nothing here passes through React, so if this port wrote the attribute
         unvetted, a javascript: href would be a live sink even though its own click path refuses it. A
         refused value therefore renders inert - no href, role="link", aria-disabled - which is the rule
         the rest of this port already follows: a refused value renders inert rather than disappearing. *)
      let usable = (not is_disabled) && Citation.is_safe_url href in
      Vdom.Node.create
        "a"
        ~attrs:
          (Common.Attr.class_ [ "astryx-visually-hidden"; "astryx-clickable-card__link" ]
           (* The name goes on unconditionally, as upstream puts it on its link component: this element
              has no content of its own, so without it the card's only interactive node is an unnamed
              link - and it is the element a screen reader announces, not the div around it. *)
           @ Common.Attr.aria "label" label
           @ (if usable
              then [ Vdom.Attr.create "href" href; Vdom.Attr.create "tabindex" "0" ]
              else
                Common.Attr.aria "disabled" "true"
                @ [ Vdom.Attr.create "role" "link"; Vdom.Attr.create "tabindex" "-1" ])
           @ [ Vdom.Attr.create "target" (Option.value target ~default:"_self") ])
        []
    | None ->
      (* No href: the action is a button, and its own click is the caller's handler. *)
      Vdom.Node.button
        ~attrs:
          (Common.Attr.class_ [ "astryx-visually-hidden"; "astryx-clickable-card__button" ]
           @ [ Vdom.Attr.create "type" "button" ]
           @ Common.Attr.aria "label" label
           @ (if is_disabled then [ Vdom.Attr.create "disabled" "" ] else []))
        []
  in
  Card.view
    ?padding
    ?variant
    ?elevation
    ?width
    ?height
    ?max_width
    ~component_name:"ClickableCard"
    ~attrs:
      (Common.Attr.class_
         [ "astryx-clickable-card"
         ; (match variant with Some Card.Default | None -> "astryx-clickable-card--bordered" | Some _ -> "astryx-clickable-card--borderless")
         ; (if is_disabled then "astryx-clickable-card--disabled" else "")
         ]
       @ Common.Attr.data "pressable-container" "true"
       @ (if is_disabled then [] else [ Vdom.Attr.create "data-astryx-pressable" "" ])
       @ [ Vdom.Attr.on_click surface_click; Vdom.Attr.on_mouseup surface_mouse_up ]
       @ attrs)
    (interactive :: children)
;;
