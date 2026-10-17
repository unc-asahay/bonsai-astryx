open! Core
open! Bonsai_web
open Js_of_ocaml

(* The rules for a clickable container became a mechanism when Clickable_card arrived as the second
   consumer of exactly this logic, so they live in Common now. The names are re-bound here rather
   than qualified at every call site, which is what keeps this component's own checks meaningful:
   they pass unchanged, and that is the evidence the move changed no behaviour. *)
module Clickable_container = Common.Clickable_container
let is_interactive_target = Clickable_container.is_interactive_target
let has_text_selection = Clickable_container.has_text_selection

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
