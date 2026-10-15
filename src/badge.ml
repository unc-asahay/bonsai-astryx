open! Core
open! Bonsai_web

type variant =
  | Neutral
  | Info
  | Success
  | Warning
  | Error
  | Blue
  | Cyan
  | Green
  | Orange
  | Pink
  | Purple
  | Red
  | Teal
  | Yellow

let variant_string = function
  | Neutral -> "neutral"
  | Info -> "info"
  | Success -> "success"
  | Warning -> "warning"
  | Error -> "error"
  | Blue -> "blue"
  | Cyan -> "cyan"
  | Green -> "green"
  | Orange -> "orange"
  | Pink -> "pink"
  | Purple -> "purple"
  | Red -> "red"
  | Teal -> "teal"
  | Yellow -> "yellow"
;;

let variant_class = function
  | Neutral -> "astryx-badge--neutral"
  | Info -> "astryx-badge--info"
  | Success -> "astryx-badge--success"
  | Warning -> "astryx-badge--warning"
  | Error -> "astryx-badge--error"
  | Blue -> "astryx-badge--blue"
  | Cyan -> "astryx-badge--cyan"
  | Green -> "astryx-badge--green"
  | Orange -> "astryx-badge--orange"
  | Pink -> "astryx-badge--pink"
  | Purple -> "astryx-badge--purple"
  | Red -> "astryx-badge--red"
  | Teal -> "astryx-badge--teal"
  | Yellow -> "astryx-badge--yellow"
;;

let view ?(variant = Neutral) ?icon label =
  let attrs =
    Common.Attr.class_ [ "astryx-badge"; variant_class variant ]
    @ Common.Attr.data "component" "Badge"
    @ Common.Attr.data "variant" (variant_string variant)
  in
  Vdom.Node.span
    ~attrs
    (Option.to_list icon @ [ Vdom.Node.span ~attrs:[] [ Vdom.Node.text label ] ])
;;
