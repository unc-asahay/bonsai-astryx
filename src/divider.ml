open! Core
open! Bonsai_web

type orientation =
  | Horizontal
  | Vertical

type variant =
  | Subtle
  | Strong

let view ?(orientation = Horizontal) ?(variant = Subtle) ?label ?(is_full_bleed = false) () =
  let classes =
    [ "astryx-divider"
    ; (match orientation with Vertical -> "astryx-divider--vertical" | Horizontal -> "")
    ; (match variant with Strong -> "astryx-divider--strong" | Subtle -> "")
    ; (if is_full_bleed then "astryx-divider--full-bleed" else "")
    ; (match label with Some _ -> "astryx-divider--labelled" | None -> "")
    ]
  in
  let attrs =
    Common.Attr.class_ classes
    @ Common.Attr.data "component" "Divider"
    @ Common.Attr.role "separator"
    @ Common.Attr.aria
        "orientation"
        (match orientation with Horizontal -> "horizontal" | Vertical -> "vertical")
  in
  match label with
  | None -> Vdom.Node.div ~attrs []
  | Some label ->
    Vdom.Node.div
      ~attrs
      [ Vdom.Node.div ~attrs:[ Vdom.Attr.class_ "astryx-divider__label" ] [ label ] ]
;;
