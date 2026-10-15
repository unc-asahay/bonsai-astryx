open! Core
open! Bonsai_web

type variant =
  | Success
  | Warning
  | Error
  | Accent
  | Neutral

let variant_string = function
  | Success -> "success"
  | Warning -> "warning"
  | Error -> "error"
  | Accent -> "accent"
  | Neutral -> "neutral"
;;

let view ~variant ~label ?(is_pulsing = false) ?icon () =
  let attrs =
    Common.Attr.class_
      [ "astryx-status-dot"
      ; sprintf "astryx-status-dot--%s" (variant_string variant)
      ; (if is_pulsing then "astryx-status-dot--pulsing" else "")
      ]
    @ Common.Attr.data "component" "StatusDot"
    @ Common.Attr.data "variant" (variant_string variant)
    @ Common.Attr.role "img"
    @ Common.Attr.aria "label" label
  in
  Vdom.Node.span ~attrs (Option.to_list icon)
;;
