open! Core
open! Bonsai_web

type variant =
  | Primary
  | Secondary
  | Ghost
  | Destructive

type size =
  | Sm
  | Md
  | Lg

type elevation =
  | E_none
  | Low
  | Med
  | High

type type_ =
  | Button
  | Submit
  | Reset

let variant_string = function
  | Primary -> "primary"
  | Secondary -> "secondary"
  | Ghost -> "ghost"
  | Destructive -> "destructive"
;;

let variant_class = function
  | Primary -> "astryx-button--primary"
  | Secondary -> "astryx-button--secondary"
  | Ghost -> "astryx-button--ghost"
  | Destructive -> "astryx-button--destructive"
;;

let size_class = function Sm -> "astryx-button--sm" | Md -> "astryx-button--md" | Lg -> "astryx-button--lg"

let elevation_class = function
  | E_none -> ""
  | Low -> "astryx-button--elevation-low"
  | Med -> "astryx-button--elevation-med"
  | High -> "astryx-button--elevation-high"
;;

let type_string = function Button -> "button" | Submit -> "submit" | Reset -> "reset"

let view
  ~label
  ?(variant = Secondary)
  ?(size = Md)
  ?(elevation = E_none)
  ?(type_ = Button)
  ?(is_loading = false)
  ?(is_disabled = false)
  ?(is_icon_only = false)
  ?icon
  ?width
  ?href
  ?target
  ?rel
  ?on_click
  children
  =
  let classes =
    [ "astryx-button"
    ; variant_class variant
    ; size_class size
    ; elevation_class elevation
    ; (if is_icon_only then "astryx-button--icon-only" else "")
    ; (if is_loading then "astryx-button--loading" else "")
    ; (if is_disabled then "astryx-button--disabled" else "")
    ]
  in
  let styles =
    [ "width", Option.value_map width ~default:"" ~f:Common.Size_value.to_css ]
  in
  (* The accessible name: visible text normally, aria-label when icon-only. *)
  let label_attrs =
    if is_icon_only then Common.Attr.aria "label" label else []
  in
  let state_attrs =
    if is_loading
    then Common.Attr.aria "busy" "true" @ Common.Attr.aria "disabled" "true"
    else if is_disabled
    then (* native disabled below; aria-disabled is implied *) []
    else []
  in
  let disabled_attrs = if is_disabled then [ Vdom.Attr.disabled ] else [] in
  let spinner =
    if is_loading
    then
      [ Vdom.Node.span
          ~attrs:(Common.Attr.class_ [ "astryx-spinner" ] @ Common.Attr.aria "hidden" "true")
          []
      ]
    else []
  in
  (* Announced once for assistive tech. It sits *after* the visible label so the
     accessible name reads "Save Loading" rather than "Loading Save" — the order
     a screen reader says it, and the order the user reads it. *)
  let loading_announcement =
    if is_loading
    then
      [ Vdom.Node.span
          ~attrs:(Common.Attr.class_ [ "astryx-visually-hidden" ])
          [ Vdom.Node.text "Loading" ]
      ]
    else []
  in
  let content =
    spinner
    @ (match icon with Some i -> [ i ] | None -> [])
    @ (if is_icon_only then [] else [ Vdom.Node.span ~attrs:[] [ Vdom.Node.text label ] ])
    @ loading_announcement
    @ children
  in
  let attrs =
    Common.Attr.class_ classes
    @ Common.Attr.data "component" "Button"
    @ Common.Attr.data "variant" (variant_string variant)
    @ label_attrs
    @ state_attrs
    @ disabled_attrs
    @ Common.Attr.style styles
    @ (match on_click with
       | Some f -> [ Vdom.Attr.on_click f ]
       | None -> [])
  in
  match href with
  | Some href ->
    let link_attrs =
      [ Vdom.Attr.href href ]
      @ (match target with Some t -> [ Vdom.Attr.create "target" t ] | None -> [])
      @ (match rel with Some r -> [ Vdom.Attr.create "rel" r ] | None -> [])
    in
    Vdom.Node.a ~attrs:(attrs @ link_attrs) content
  | None -> Vdom.Node.button ~attrs:(attrs @ [ Vdom.Attr.create "type" (type_string type_) ]) content
;;
