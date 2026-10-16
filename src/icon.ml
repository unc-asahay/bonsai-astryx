open! Core
open! Bonsai_web

type size =
  | Xsm
  | Sm
  | Md
  | Lg

type color =
  | Primary
  | Secondary
  | Tertiary
  | Disabled
  | Accent
  | Success
  | Error
  | Warning
  | Blue
  | Red
  | Green
  | Gray
  | Cyan
  | Inherit

let names : string list = Icon_data.names

let size_class = function
  | Xsm -> "astryx-icon--xsm"
  | Sm -> "astryx-icon--sm"
  | Md -> "astryx-icon--md"
  | Lg -> "astryx-icon--lg"
;;

let color_class = function
  | Primary -> "astryx-icon--primary"
  | Secondary -> "astryx-icon--secondary"
  | Tertiary -> "astryx-icon--tertiary"
  | Disabled -> "astryx-icon--disabled"
  | Accent -> "astryx-icon--accent"
  | Success -> "astryx-icon--success"
  | Error -> "astryx-icon--error"
  | Warning -> "astryx-icon--warning"
  | Blue -> "astryx-icon--blue"
  | Red -> "astryx-icon--red"
  | Green -> "astryx-icon--green"
  | Gray -> "astryx-icon--gray"
  | Cyan -> "astryx-icon--cyan"
  | Inherit -> "astryx-icon--inherit"
;;

let attrs_of (pairs : (string * string) list) =
  List.map pairs ~f:(fun (name, value) -> Vdom.Attr.create name value)
;;

(* Every element inside <svg> must be created via [create_svg]. [create] builds an HTML
   element, and an HTML "path" is a no-op: the page would show nothing at all. This is
   the single easiest way to get an icon set that compiles and renders blank. *)
let svg_child (child : Icon_data.el) =
  Vdom.Node.create_svg child.tag ~attrs:(attrs_of child.attrs) []
;;

let glyph (data : Icon_data.t) =
  Vdom.Node.create_svg
    "svg"
    ~attrs:(attrs_of data.svg_attrs)
    (List.map data.children ~f:svg_child)
;;

let view ?(size = Md) ?color ?label ?(attrs = []) ~name () =
  let found = Icon_data.find name in
  let aria =
    match label with
    | Some label when not (String.is_empty label) ->
      [ Vdom.Attr.create "role" "img"; Vdom.Attr.create "aria-label" label ]
    | Some _ | None -> [ Vdom.Attr.create "aria-hidden" "true" ]
  in
  let missing =
    match found with
    | Some _ -> []
    | None -> [ Vdom.Attr.create "data-astryx-icon-missing" name ]
  in
  Vdom.Node.span
    ~attrs:
      (Common.Attr.class_
         ([ "astryx-icon"; size_class size ] @ Option.to_list (Option.map color ~f:color_class))
       @ Common.Attr.data "component" "Icon"
       @ aria
       @ missing
       @ attrs)
    (Option.to_list (Option.map found ~f:glyph))
;;
