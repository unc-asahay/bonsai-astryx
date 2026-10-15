open! Core
open! Bonsai_web

type level =
  | H1
  | H2
  | H3
  | H4
  | H5
  | H6

let to_int = function H1 -> 1 | H2 -> 2 | H3 -> 3 | H4 -> 4 | H5 -> 5 | H6 -> 6
let level_class l = sprintf "astryx-heading--%d" (to_int l)

let view
  ?accessibility_level
  ~level
  ?weight
  ?color
  ?display
  ?max_lines
  ?justify
  ?(has_strikethrough = false)
  children
  =
  let clamped = Option.value_map max_lines ~default:false ~f:(fun n -> n > 0) in
  let classes =
    [ "astryx-heading"
    ; level_class level
    ; Option.value_map weight ~default:"" ~f:Text.weight_class
    ; Option.value_map color ~default:"" ~f:Text.color_class
    ; Option.value_map display ~default:"" ~f:Text.display_class
    ; Option.value_map justify ~default:"" ~f:Text.justify_class
    ; (if has_strikethrough then "astryx-text--strikethrough" else "")
    ; (if clamped then "astryx-text--clamped" else "")
    ]
  in
  let styles =
    [ ( "max-lines"
      , Option.value_map max_lines ~default:"" ~f:(fun n -> if n > 0 then Int.to_string n else "") )
    ]
  in
  let attrs =
    Common.Attr.class_ classes
    @ Common.Attr.data "component" "Heading"
    @ Common.Attr.data "level" (Int.to_string (to_int level))
    (* aria-level is only emitted when it diverges from the element's own level,
       which is what upstream's accessibilityLevel is for. *)
    @ (match accessibility_level with
       | Some l when not (Int.equal (to_int l) (to_int level)) ->
         Common.Attr.aria "level" (Int.to_string (to_int l))
       | Some _ | None -> [])
    @ Common.Attr.style styles
  in
  let node = match level with
    | H1 -> Vdom.Node.h1
    | H2 -> Vdom.Node.h2
    | H3 -> Vdom.Node.h3
    | H4 -> Vdom.Node.h4
    | H5 -> Vdom.Node.h5
    | H6 -> Vdom.Node.h6
  in
  node ~attrs children
;;
