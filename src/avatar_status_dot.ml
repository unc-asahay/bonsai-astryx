open! Core
open! Bonsai_web

type variant =
  | Success
  | Neutral
  | Error

type tier =
  | Small
  | Medium
  | Large

(* Upstream's ladder, and the reason the small tier has no glyph: at 10 px with a 1 px border there is no field
   left to draw into. *)
let tier_metrics = function
  | Small -> 10, 1, 0
  | Medium -> 20, 2, 12
  | Large -> 32, 4, 18
;;

let variant_class = function
  | Success -> "astryx-avatar-status-dot--success"
  | Neutral -> "astryx-avatar-status-dot--neutral"
  | Error -> "astryx-avatar-status-dot--error"
;;

(* The house SVG convention, the one src/icon.ml uses: create_svg, and xmlns among the attributes. *)
let svg_attrs size =
  [ Vdom.Attr.create "xmlns" "http://www.w3.org/2000/svg"
  ; Vdom.Attr.create "viewBox" "0 0 24 24"
  ; Vdom.Attr.create "width" (Int.to_string size)
  ; Vdom.Attr.create "height" (Int.to_string size)
  ; Vdom.Attr.create "fill" "none"
  ; Vdom.Attr.create "stroke" "currentColor"
  ; Vdom.Attr.create "stroke-width" "3"
  ; Vdom.Attr.create "stroke-linecap" "round"
  ; Vdom.Attr.create "stroke-linejoin" "round"
  ; Vdom.Attr.create "aria-hidden" "true"
  ]
;;

(* The built-in glyph for each variant: a check for success, and a bar for both of the others - upstream's
   error is "a red dot with a minus bar", and neutral's mark is the same bar in a quieter colour. *)
let built_in_glyph variant size =
  let path =
    match variant with
    | Success -> "M20 6L9 17l-5-5"
    | Neutral | Error -> "M6 12h12"
  in
  Vdom.Node.create_svg
    "svg"
    ~attrs:(svg_attrs size)
    [ Vdom.Node.create_svg "path" ~attrs:[ Vdom.Attr.create "d" path ] [] ]
;;

let view ?(attrs = []) ?(variant = Success) ?label ?icon ?(tier = Medium) () =
  let dot_size, border_width, icon_size = tier_metrics tier in
  let glyph =
    match icon with
    | Some icon -> Some icon
    | None -> if icon_size = 0 then None else Some (built_in_glyph variant icon_size)
  in
  let aria =
    match label with
    | Some label -> [ Vdom.Attr.create "role" "img"; Vdom.Attr.create "aria-label" label ]
    | None -> [ Vdom.Attr.create "aria-hidden" "true" ]
  in
  Vdom.Node.div
    ~attrs:
      ([ Vdom.Attr.class_ "astryx-avatar-status-dot"
       ; Vdom.Attr.class_ (variant_class variant)
       ; Vdom.Attr.create "data-tier"
           (match tier with
            | Small -> "small"
            | Medium -> "medium"
            | Large -> "large")
       ; Vdom.Attr.create
           "style"
           (sprintf
              "width:%dpx;height:%dpx;border-width:%dpx"
              dot_size
              dot_size
              border_width)
       ]
       (* Common.Attr.data is a list, where Vdom.Attr.class_ is a single attr - the pair of them have caught me
          in both directions now. *)
       @ Common.Attr.data "component" "AvatarStatusDot"
       @ aria
       @ attrs)
    (match glyph with
     | None -> []
     | Some glyph -> [ glyph ])
;;
