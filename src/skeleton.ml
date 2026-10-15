open! Core
open! Bonsai_web

type radius =
  | R_none
  | R0
  | R1
  | R2
  | R3
  | R4
  | Rounded

let radius_class = function
  | R_none -> "astryx-skeleton--radius-none"
  | R0 -> "astryx-skeleton--radius-0"
  | R1 -> "astryx-skeleton--radius-1"
  | R2 -> "astryx-skeleton--radius-2"
  | R3 -> "astryx-skeleton--radius-3"
  | R4 -> "astryx-skeleton--radius-4"
  | Rounded -> "astryx-skeleton--radius-rounded"
;;

let view ?width ?height ?radius ?index () =
  let styles =
    [ "width", Option.value_map width ~default:"" ~f:Common.Size_value.to_css
    ; "height", Option.value_map height ~default:"" ~f:Common.Size_value.to_css
    ; (* upstream staggers the shimmer by index; the delay is index * 80ms *)
      ( "animation-delay"
      , Option.value_map index ~default:"" ~f:(fun i -> sprintf "calc(var(--skeleton-stagger, 80ms) * %d)" i)
      )
    ]
  in
  Vdom.Node.div
    ~attrs:
      (Common.Attr.class_
         [ "astryx-skeleton"; Option.value_map radius ~default:"" ~f:radius_class ]
       @ Common.Attr.data "component" "Skeleton"
       @ Common.Attr.aria "hidden" "true"
       @ Common.Attr.style styles)
    []
;;
