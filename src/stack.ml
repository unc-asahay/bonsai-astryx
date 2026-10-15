(* Stack — layout primitive mirroring Astryx's Stack/Stack.tsx.

   Upstream alignment semantics, reproduced exactly:
     hAlign  with direction=horizontal -> main axis (justify-content)
     hAlign  with direction=vertical   -> cross axis (align-items)
     vAlign  with direction=horizontal -> cross axis (align-items)
     vAlign  with direction=vertical   -> main axis (justify-content)
     justify -> main-axis alias, wins over hAlign/vAlign
     align   -> cross-axis alias, wins over hAlign/vAlign

   Alignment values live in Common.Alignment, shared with Text and Heading so
   there is exactly one union to reason about. *)

open! Core
open! Bonsai_web

type direction =
  | Horizontal
  | Vertical

(* Alias for readability; the constructors live in Common.Alignment. *)
type align = Common.Alignment.t

let direction_class = function Horizontal -> "astryx-stack--horizontal" | Vertical -> ""

let view
  ?(direction = Vertical)
  ?h_align
  ?v_align
  ?justify
  ?align
  ?gap
  ?padding
  ?padding_inline
  ?padding_block
  ?width
  ?height
  ?max_width
  ?min_height
  ?(is_scrollable = false)
  ?(wrap = false)
  children
  =
  let is_horizontal =
    match direction with
    | Horizontal -> true
    | Vertical -> false
  in
  (* hAlign/vAlign resolve per direction; the justify/align aliases win. *)
  let main_axis, cross_axis = if is_horizontal then h_align, v_align else v_align, h_align in
  let main = Option.first_some justify main_axis
  and cross = Option.first_some align cross_axis in
  let classes =
    [ "astryx-stack"
    ; direction_class direction
    ; (if wrap then "astryx-stack--wrap" else "")
    ; (if is_scrollable then "astryx-stack--scrollable" else "")
    ; Option.value_map cross ~default:"" ~f:Common.Alignment.cross_class
    ; Option.value_map main ~default:"" ~f:Common.Alignment.main_class
    ]
  in
  let styles =
    [ "gap", Option.value_map gap ~default:"" ~f:Common.Spacing.var
    ; "padding", Option.value_map padding ~default:"" ~f:Common.Spacing.var
    ; "padding-inline", Option.value_map padding_inline ~default:"" ~f:Common.Spacing.var
    ; "padding-block", Option.value_map padding_block ~default:"" ~f:Common.Spacing.var
    ; "width", Option.value_map width ~default:"" ~f:Common.Size_value.to_css
    ; "height", Option.value_map height ~default:"" ~f:Common.Size_value.to_css
    ; "max-width", Option.value_map max_width ~default:"" ~f:Common.Size_value.to_css
    ; "min-height", Option.value_map min_height ~default:"" ~f:Common.Size_value.to_css
    ]
  in
  let attrs =
    Common.Attr.class_ classes
    @ Common.Attr.data "component" "Stack"
    @ Common.Attr.data
        "direction"
        (match direction with
         | Horizontal -> "horizontal"
         | Vertical -> "vertical")
    @ Common.Attr.style styles
  in
  Vdom.Node.div ~attrs children
;;
