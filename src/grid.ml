open! Core
open! Bonsai_web

type repeat =
  | Fill
  | Fit

type columns =
  | Fixed of int
  | Responsive of int * repeat

let columns_css = function
  | Fixed n when n > 0 -> sprintf "repeat(%d, 1fr)" n
  | Fixed _ -> "1fr"
  | Responsive (min_width, Fill) ->
    sprintf "repeat(auto-fill, minmax(%dpx, 1fr))" min_width
  | Responsive (min_width, Fit) -> sprintf "repeat(auto-fit, minmax(%dpx, 1fr))" min_width
;;

let align_class = function
  | Common.Alignment.Start | Common.Alignment.Between -> "astryx-grid--align-start"
  | Center | Around -> "astryx-grid--align-center"
  | End | Evenly -> "astryx-grid--align-end"
  | Stretch -> "astryx-grid--align-stretch"
;;

let justify_class = function
  | Common.Alignment.Start | Between -> "astryx-grid--justify-start"
  | Center | Around -> "astryx-grid--justify-center"
  | End | Evenly -> "astryx-grid--justify-end"
  | Stretch -> "astryx-grid--justify-stretch"
;;

let view
  ?(columns = Fixed 1)
  ?gap
  ?row_gap
  ?column_gap
  ?(align = Common.Alignment.Stretch)
  ?(justify = Common.Alignment.Stretch)
  ?width
  ?height
  ?max_width
  ?min_height
  children
  =
  let style name value = name, Option.value_map value ~default:"" ~f:Common.Size_value.to_css in
  (* named `space`, not `gap`, so it does not shadow the `gap` argument *)
  let space name value = name, Option.value_map value ~default:"" ~f:Common.Spacing.var in
  (* Track sizes are open-ended strings, so they go inline; upstream puts them in
     a CSS variable + class so consumer styles can win, which this port does not
     yet support (documented in the divergence note above). *)
  let styles =
    [ "grid-template-columns", columns_css columns
    ; space "gap" gap
    ; space "row-gap" row_gap
    ; space "column-gap" column_gap
    ; style "width" width
    ; style "height" height
    ; style "max-width" max_width
    ; style "min-height" min_height
    ]
  in
  let attrs =
    Common.Attr.class_ [ "astryx-grid"; align_class align; justify_class justify ]
    @ Common.Attr.data "component" "Grid"
    @ Common.Attr.data "columns" (columns_css columns)
    @ Common.Attr.style styles
  in
  Vdom.Node.div ~attrs children
;;
