open! Core
open! Bonsai_web

type variant =
  | Section
  | Transparent
  | Muted

type side =
  | Top
  | Bottom
  | Start
  | End

let variant_class = function
  | Section -> "astryx-section--section"
  | Transparent -> "astryx-section--transparent"
  | Muted -> "astryx-section--muted"
;;

let side_class = function
  | Top -> "astryx-section--divider-top"
  | Bottom -> "astryx-section--divider-bottom"
  | Start -> "astryx-section--divider-start"
  | End -> "astryx-section--divider-end"
;;

let view
  ?(variant = Section)
  ?(dividers = [])
  ?width
  ?height
  ?max_width
  ?min_height
  ?(padding = Common.Spacing.S4)
  ?padding_inline
  ?padding_inline_start
  ?padding_inline_end
  ?padding_block
  ?padding_block_start
  ?padding_block_end
  children
  =
  let size name value = name, Option.value_map value ~default:"" ~f:Common.Size_value.to_css in
  let pad name value = name, Option.value_map value ~default:"" ~f:Common.Spacing.var in
  let styles =
    [ size "width" width
    ; size "height" height
    ; size "max-width" max_width
    ; size "min-height" min_height
    ; pad "padding" (Some padding)
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
      ([ "astryx-section"; variant_class variant ] @ List.map dividers ~f:side_class)
    @ Common.Attr.data "component" "Section"
    @ Common.Attr.data
        "variant"
        (match variant with
         | Section -> "section"
         | Transparent -> "transparent"
         | Muted -> "muted")
    @ Common.Attr.style styles
  in
  Vdom.Node.section ~attrs children
;;
