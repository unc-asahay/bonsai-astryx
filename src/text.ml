(* Text — mirrors Astryx's Text/Text.tsx.

   Astryx maps each semantic [type_] to a type-scale token triple
   (--text-<type>-size|weight|leading), each [size] to a --font-size-* token
   (note the upstream quirk that size name [xsm] maps to --font-size-xs), and
   each [color] to a --color-text-* / --color-* token. [max_lines] turns on
   line clamping, which upstream does with -webkit-line-clamp + block display. *)

open! Core
open! Bonsai_web

type type_ =
  | Body
  | Large
  | Label
  | Supporting
  | Code
  | Display_1
  | Display_2
  | Display_3

type size =
  | Size_4xs
  | Size_3xs
  | Size_2xs
  | Xsm
  | Sm
  | Base
  | Lg
  | Xl
  | Size_2xl
  | Size_3xl
  | Size_4xl
  | Size_5xl

type color =
  | Primary
  | Secondary
  | Disabled
  | Placeholder
  | Accent
  | Inherit

type weight =
  | Normal
  | Medium
  | Semibold
  | Bold

type display =
  | Inline
  | Block

type element =
  | Span
  | P
  | Div
  | Label

let type_class = function
  | Body -> "astryx-text--type-body"
  | Large -> "astryx-text--type-large"
  | Label -> "astryx-text--type-label"
  | Supporting -> "astryx-text--type-supporting"
  | Code -> "astryx-text--type-code"
  | Display_1 -> "astryx-text--type-display-1"
  | Display_2 -> "astryx-text--type-display-2"
  | Display_3 -> "astryx-text--type-display-3"
;;

let size_class = function
  | Size_4xs -> "astryx-text--size-4xs"
  | Size_3xs -> "astryx-text--size-3xs"
  | Size_2xs -> "astryx-text--size-2xs"
  | Xsm -> "astryx-text--size-xsm"
  | Sm -> "astryx-text--size-sm"
  | Base -> "astryx-text--size-base"
  | Lg -> "astryx-text--size-lg"
  | Xl -> "astryx-text--size-xl"
  | Size_2xl -> "astryx-text--size-2xl"
  | Size_3xl -> "astryx-text--size-3xl"
  | Size_4xl -> "astryx-text--size-4xl"
  | Size_5xl -> "astryx-text--size-5xl"
;;

let color_class = function
  | Primary -> "astryx-text--color-primary"
  | Secondary -> "astryx-text--color-secondary"
  | Disabled -> "astryx-text--color-disabled"
  | Placeholder -> "astryx-text--color-placeholder"
  | Accent -> "astryx-text--color-accent"
  | Inherit -> "astryx-text--color-inherit"
;;

let weight_class = function
  | Normal -> "astryx-text--weight-normal"
  | Medium -> "astryx-text--weight-medium"
  | Semibold -> "astryx-text--weight-semibold"
  | Bold -> "astryx-text--weight-bold"
;;

let display_class = function Inline -> "astryx-text--inline" | Block -> "astryx-text--block"

let justify_class = Common.Alignment.text_justify_class

(* Upstream: color defaults to 'secondary' for the 'supporting' type, 'primary' otherwise. *)
let default_color type_ =
  match type_ with
  | Supporting -> Secondary
  | Body | Large | Label | Code | Display_1 | Display_2 | Display_3 -> Primary
;;

let view
  ?(type_ = Body)
  ?size
  ?color
  ?weight
  ?display
  ?(element = Span)
  ?max_lines
  ?justify
  ?(has_strikethrough = false)
  ?(has_tabular_numbers = false)
  ?id
  children
  =
  let color = Option.value color ~default:(default_color type_) in
  let clamped = Option.value_map max_lines ~default:false ~f:(fun n -> n > 0) in
  let classes =
    [ "astryx-text"
    ; type_class type_
    ; Option.value_map size ~default:"" ~f:size_class
    ; color_class color
    ; Option.value_map weight ~default:"" ~f:weight_class
    ; Option.value_map display ~default:"" ~f:display_class
    ; Option.value_map justify ~default:"" ~f:justify_class
    ; (if has_strikethrough then "astryx-text--strikethrough" else "")
    ; (if has_tabular_numbers then "astryx-text--tabular" else "")
    ; (if clamped then "astryx-text--clamped" else "")
    ]
  in
  let styles =
    [ ( "max-lines"
      , Option.value_map max_lines ~default:"" ~f:(fun n -> if n > 0 then Int.to_string n else "") )
    ]
  in
  let attrs =
    Common.Attr.class_ classes
    @ Common.Attr.data "component" "Text"
    @ (match id with Some id -> [ Vdom.Attr.id id ] | None -> [])
    @ Common.Attr.style styles
  in
  match element with
  | Span -> Vdom.Node.span ~attrs children
  | P -> Vdom.Node.p ~attrs children
  | Div -> Vdom.Node.div ~attrs children
  | Label -> Vdom.Node.label ~attrs children
;;
