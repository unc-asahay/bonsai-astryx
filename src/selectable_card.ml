open! Core
open! Bonsai_web
open Js_of_ocaml

(* Upstream exports this list from its hook so that several interaction utilities share one definition of
   "interactive target" rather than hand-rolling divergent ones. The port has it here because Selectable_card
   is its first consumer; it moves to Common when Clickable_card - the second - lands, which is the rule this
   port follows for every mechanism. *)
let interactive_selectors =
  String.concat
    ~sep:","
    [ "button"
    ; "a"
    ; "input"
    ; "select"
    ; "textarea"
    ; "[role=\"button\"]"
    ; "[role=\"link\"]"
    ; "[role=\"checkbox\"]"
    ; "[role=\"radio\"]"
    ; "[role=\"switch\"]"
    ; "[role=\"tab\"]"
    ; "[role=\"menuitem\"]"
    ; "[role=\"option\"]"
    ; "[role=\"combobox\"]"
    ; "[role=\"listbox\"]"
    ; "[role=\"slider\"]"
    ; "[role=\"spinbutton\"]"
    ; "[data-pressable-container]"
    ]
;;

(* The container itself carries data-pressable-container, and that attribute is in the selector list, so a
   child's closest() finds the root - which is why the comparison against the root is not decoration: it is
   what keeps the surface's own clicks from counting as interactive. A *nested* clickable container (a card
   inside a card) does count, which is the reason the attribute is in the list at all. *)
let is_interactive_target ~root ~target =
  let js =
    Js.Unsafe.eval_string
      "(function (target, root, selector) { if (target === root) return false; \
       var found = target.closest(selector); return found !== null && found !== root && root.contains(found); })"
  in
  Js.Unsafe.fun_call
    js
    [| Js.Unsafe.inject target
     ; Js.Unsafe.inject root
     ; Js.Unsafe.inject (Js.string interactive_selectors)
    |]
;;

(* A drag that ends on the card is a selection, not a click. Only a non-collapsed selection anchored inside
   this element counts, so selecting text elsewhere on the page does not swallow the click. *)
let has_text_selection el =
  let js =
    Js.Unsafe.eval_string
      "(function (el) { var sel = el.ownerDocument.getSelection(); \
       if (!sel || sel.isCollapsed || sel.rangeCount === 0) return false; return el.contains(sel.anchorNode); })"
  in
  Js.Unsafe.fun_call js [| Js.Unsafe.inject el |]
;;

let view
  ?(is_disabled = false)
  ?padding
  ?variant
  ?elevation
  ?width
  ?height
  ?max_width
  ?(attrs = [])
  ~label
  ~is_selected
  ~on_change
  children
  =
  let toggle = on_change (not is_selected) in
  let surface_click (event : Dom_html.mouseEvent Js.t) =
    let root = Js.Unsafe.get event "currentTarget" in
    let target = Js.Unsafe.get event "target" in
    if is_disabled
    then Effect.Ignore
    else if has_text_selection root
    then Effect.Ignore
    else if is_interactive_target ~root ~target
    then Effect.Ignore
    else toggle
  in
  (* Enter toggles, Space does not need to: a native checkbox already answers Space, and adding it here
     would toggle twice. Upstream makes the same distinction, and it is why this handler exists at all. *)
  let checkbox_keydown (event : Dom_html.keyboardEvent Js.t) =
    (* Common.string_prop answers an option: a property that is absent is not the empty string. *)
    let key = Common.string_prop event "key" in
    let is k = Option.value_map key ~default:false ~f:(String.equal k) in
    if is_disabled
    then (
      if is " " || is "Enter"
      then (
        Common.prevent_default event;
        Effect.Ignore)
      else Effect.Ignore)
    else if is "Enter"
    then (
      Common.prevent_default event;
      toggle)
    else Effect.Ignore
  in
  let checkbox =
    Vdom.Node.input
      ~attrs:
        (Common.Attr.class_ [ "astryx-visually-hidden"; "astryx-selectable-card__input" ]
         @ [ Vdom.Attr.create "type" "checkbox"
           ; Vdom.Attr.checked_prop is_selected
           ; Vdom.Attr.on_change (fun _ _ -> if is_disabled then Effect.Ignore else toggle)
           ; Vdom.Attr.on_keydown checkbox_keydown
           ]
         @ Common.Attr.aria "label" label
         @ (if is_disabled then Common.Attr.aria "disabled" "true" else []))
      ()
  in
  Card.view
    ?padding
    ?variant
    ?elevation
    ?width
    ?height
    ?max_width
    ~component_name:"SelectableCard"
    ~attrs:
      (Common.Attr.class_
         [ "astryx-selectable-card"
         ; (if is_selected then "astryx-selectable-card--selected" else "")
         ; (if is_disabled then "astryx-selectable-card--disabled" else "")
         ]
       @ Common.Attr.data "selected" (if is_selected then "true" else "false")
       @ Common.Attr.data "pressable-container" "true"
       @ (if is_disabled then [] else [ Vdom.Attr.create "data-astryx-pressable" "" ])
       @ [ Vdom.Attr.on_click surface_click ]
       @ attrs)
    (checkbox :: children)
;;
