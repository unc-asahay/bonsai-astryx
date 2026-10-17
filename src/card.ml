open! Core
open! Bonsai_web

type variant =
  | Default
  | Transparent
  | Muted
  | Blue
  | Cyan
  | Gray
  | Green
  | Orange
  | Pink
  | Purple
  | Red
  | Teal
  | Yellow

let variant_of_string = function
  | "default" -> Default
  | "transparent" -> Transparent
  | "muted" -> Muted
  | "blue" -> Blue
  | "cyan" -> Cyan
  | "gray" -> Gray
  | "green" -> Green
  | "orange" -> Orange
  | "pink" -> Pink
  | "purple" -> Purple
  | "red" -> Red
  | "teal" -> Teal
  | "yellow" -> Yellow
  | other -> failwithf "Card: unknown variant %s" other ()
;;

let variant_class = function
  | Default -> ""
  | Transparent -> "astryx-card--transparent"
  | Muted -> "astryx-card--muted"
  | Blue -> "astryx-card--blue"
  | Cyan -> "astryx-card--cyan"
  | Gray -> "astryx-card--gray"
  | Green -> "astryx-card--green"
  | Orange -> "astryx-card--orange"
  | Pink -> "astryx-card--pink"
  | Purple -> "astryx-card--purple"
  | Red -> "astryx-card--red"
  | Teal -> "astryx-card--teal"
  | Yellow -> "astryx-card--yellow"
;;

let view
  ?(variant = Default)
  ?(elevation = Button.E_none)
  ?padding
  ?width
  ?height
  ?max_width
  ?min_height
  ?(component_name = "Card")
  ?(attrs = [])
  children
  =
  let elevation_class =
    match elevation with
    | Button.E_none -> ""
    | Low -> "astryx-card--elevation-low"
    | Med -> "astryx-card--elevation-med"
    | High -> "astryx-card--elevation-high"
  in
  let classes =
    [ "astryx-card"
    ; variant_class variant
    ; elevation_class
    ; (match padding with Some _ -> "astryx-card--padded" | None -> "")
    ]
  in
  let styles =
    [ "padding", Option.value_map padding ~default:"" ~f:Common.Spacing.var
    ; "width", Option.value_map width ~default:"" ~f:Common.Size_value.to_css
    ; "height", Option.value_map height ~default:"" ~f:Common.Size_value.to_css
    ; "max-width", Option.value_map max_width ~default:"" ~f:Common.Size_value.to_css
    ; "min-height", Option.value_map min_height ~default:"" ~f:Common.Size_value.to_css
    ]
  in
  Vdom.Node.div
    ~attrs:
      (Common.Attr.class_ classes
       @ Common.Attr.data "component" component_name
       @ Common.Attr.style styles
       @ attrs)
    children
;;
