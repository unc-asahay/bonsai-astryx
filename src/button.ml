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
  ?(component_name = "Button")
  ?attrs
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
  (* Content is wrapped, and the wrapper is hidden from assistive tech while loading.
     Upstream does exactly this: during load the visible content is replaced by the
     spinner, so a screen reader must not still read the label — the live region below
     carries the state instead. Without the aria-hidden, a busy "Save" button is
     announced as "Save" while its label is not on screen. *)
  let content =
    spinner
    @ (match icon with Some i -> [ i ] | None -> [])
    @ (if is_icon_only then [] else [ Vdom.Node.span ~attrs:[ Vdom.Attr.class_ "astryx-button__label" ] [ Vdom.Node.text label ] ])
    @ children
  in
  let content_attrs =
    Common.Attr.class_ [ "astryx-button__content" ]
    @ (if is_loading then Common.Attr.aria "hidden" "true" else [])
  in
  let content_wrapper = Vdom.Node.span ~attrs:content_attrs content in
  (* The live region is always in the DOM (upstream renders it unconditionally with an
     empty string when idle): a live region has to exist before its content changes for
     the change to be announced at all. It sits after the visible label so the reading
     order is "Save Loading" rather than "Loading Save". *)
  let live_region =
    Vdom.Node.span
      ~attrs:
        (Common.Attr.class_ [ "astryx-visually-hidden" ]
         @ Common.Attr.role "status"
         @ Common.Attr.aria "live" "polite")
      [ Vdom.Node.text (if is_loading then "Loading" else "") ]
  in
  let content = [ content_wrapper; live_region ] in
  let attrs =
    Common.Attr.class_ classes
    @ Common.Attr.data "component" component_name
    @ Common.Attr.data "variant" (variant_string variant)
    @ label_attrs
    @ state_attrs
    @ disabled_attrs
    @ Common.Attr.style styles
    @ (match on_click with
       | Some f -> [ Vdom.Attr.on_click f ]
       | None -> [])
    (* Caller attributes last, so a consumer can override anything above — the same
       precedence upstream gives host props (its Button extends BaseProps). *)
    @ Option.value attrs ~default:[]
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
