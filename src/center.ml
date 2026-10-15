open! Core
open! Bonsai_web

type axis =
  | Both
  | Horizontal
  | Vertical

let axis_class = function
  | Both -> "astryx-center--both"
  | Horizontal -> "astryx-center--horizontal"
  | Vertical -> "astryx-center--vertical"
;;

let view
  ?(axis = Both)
  ?width
  ?height
  ?max_width
  ?min_height
  ?padding
  ?padding_inline
  ?padding_inline_start
  ?padding_inline_end
  ?padding_block
  ?padding_block_start
  ?padding_block_end
  ?(is_inline = false)
  children
  =
  let size name value = name, Option.value_map value ~default:"" ~f:Common.Size_value.to_css in
  let pad name value = name, Option.value_map value ~default:"" ~f:Common.Spacing.var in
  (* Ordered least- to most-specific: CSS applies later declarations over
     earlier ones, which reproduces upstream's precedence rule. *)
  let styles =
    [ size "width" width
    ; size "height" height
    ; size "max-width" max_width
    ; size "min-height" min_height
    ; pad "padding" padding
    ; pad "padding-inline" padding_inline
    ; pad "padding-block" padding_block
    ; pad "padding-inline-start" padding_inline_start
    ; pad "padding-inline-end" padding_inline_end
    ; pad "padding-block-start" padding_block_start
    ; pad "padding-block-end" padding_block_end
    ]
  in
  let attrs =
    Common.Attr.class_
      [ "astryx-center"; axis_class axis; (if is_inline then "astryx-center--inline" else "") ]
    @ Common.Attr.data "component" "Center"
    @ Common.Attr.data
        "axis"
        (match axis with
         | Both -> "both"
         | Horizontal -> "horizontal"
         | Vertical -> "vertical")
    @ Common.Attr.style styles
  in
  Vdom.Node.div ~attrs children
;;
