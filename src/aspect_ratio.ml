open! Core
open! Bonsai_web

type shape =
  | Rectangle
  | Ellipse

type fit =
  | Cover
  | Contain
  | Center

let shape_class = function
  | Rectangle -> ""
  | Ellipse -> "astryx-aspect-ratio--ellipse"
;;

let shape_data = function
  | Rectangle -> "rectangle"
  | Ellipse -> "ellipse"
;;

let fit_data = function
  | Cover -> "cover"
  | Contain -> "contain"
  | Center -> "center"
;;

let view ?(shape = Rectangle) ?fit ~ratio children =
  let child_attrs =
    Common.Attr.class_
      [ "astryx-aspect-ratio__child"
      ; (match fit with Some Center -> "astryx-aspect-ratio__child--center" | _ -> "")
      ]
    @ (match fit with
       | None -> []
       | Some fit -> Common.Attr.data "aspect-ratio-override" (fit_data fit))
  in
  Vdom.Node.div
    ~attrs:
      (Common.Attr.class_ [ "astryx-aspect-ratio"; shape_class shape ]
       @ Common.Attr.data "component" "AspectRatio"
       @ Common.Attr.data "shape" (shape_data shape)
       (* The ratio goes out as a CSS custom property, with the actual
          `aspect-ratio` declaration living in components.css. Deliberate: an
          inline `aspect-ratio` would outrank every consumer class, and upstream
          keeps the ratio overridable on purpose — that is how a responsive ratio
          is set (@media / @container / a plain unlayered rule). *)
       @ Common.Attr.style [ "--astryx-aspect-ratio", sprintf "%g" ratio ])
    [ Vdom.Node.div ~attrs:child_attrs children ]
;;
