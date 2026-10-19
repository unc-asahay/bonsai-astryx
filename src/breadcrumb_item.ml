(* BreadcrumbItem — one crumb of an Astryx.Breadcrumbs trail.
   Port of upstream Breadcrumbs/BreadcrumbItem.tsx.

   The container supplies the variant and the separator explicitly rather than
   throughupstream's layer-scoped context (the port-wide named context gap), and
   the container computes the auto-"current" crumb before rendering because
   Bonsai has no post-render DOM effect to inspect the list with — the observable
   contract is the same (the last crumb that does not opt out, given no explicit
   current, carries aria-current="page" on its content element).

   Named gaps, as upstream names them too:
   - the `menu` prop (a crumb whose popover reuses the DropdownMenu item
     pipeline) is NOT ported: this port's Dropdown_menu is a complete menu button,
     not a row renderer, and faking half a popover would be worse than the named
     absence. A crumb with a menu supplied is a plain link/button/spans.
   - `as` (a custom framework link component) has no counterpart under a plain
     <a>; href is vetted by the port's safe-url predicate (a refused URL renders
     with no href, per Clickable_card).
   - start_icon is a Vdom.Node (upstream takes any ReactNode). *)

open! Core
open! Bonsai_web
module Attr = Common.Attr

type variant =
  | Default
  | Supporting

type t =
  { label : Vdom.Node.t list
  ; href : string option
  ; on_click : (unit -> unit Bonsai.Effect.t) option
  ; start_icon : Vdom.Node.t option
  ; is_current : bool option
  ; attrs : Vdom.Attr.t list
  }

let item
    ?(attrs = [])
    ?href
    ?on_click
    ?start_icon
    ?(is_current = None)
    ~label
    ()
  : t
  =
  { label; href; on_click; start_icon; is_current; attrs }
;;

let is_supporting = function Default -> false | Supporting -> true

let size_class variant =
  if is_supporting variant then "astryx-breadcrumb-item--supporting" else ""
;;

let separator_node (separator : Vdom.Node.t) : Vdom.Node.t =
  Vdom.Node.span
    ~attrs:
      (Attr.class_ [ "astryx-breadcrumb-item__separator" ]
       @ Attr.aria "hidden" "true"
       @ Attr.data "separator" "true")
    [ separator ]
;;

let view
    ~(variant : variant)
    ~(separator : Vdom.Node.t)
    ~(is_auto_current : bool)
    (i : t)
  : Vdom.Node.t
  =
  let is_current =
    match i.is_current with Some b -> b | None -> is_auto_current
  in
  let link_class =
    match variant with
    | Default -> [ "astryx-breadcrumb-item__link" ]
    | Supporting -> [ "astryx-breadcrumb-item__link"; "astryx-breadcrumb-item__link--supporting" ]
  in
  let content =
    (match i.start_icon with
     | Some icon ->
       [ Vdom.Node.span ~attrs:(Attr.class_ [ "astryx-breadcrumb-item__icon" ]) [ icon ] ]
     | None -> [])
    @ i.label
  in
  let content_class = size_class variant in
  let li_attrs =
    Attr.class_
      ([ "astryx-breadcrumb-item" ]
       @ (if is_supporting variant then [ "astryx-breadcrumb-item--supporting" ] else [])
       @ (if is_current then [ "astryx-breadcrumb-item--current" ] else []))
    @ Attr.data "component" "BreadcrumbItem"
    @ Attr.data "variant" (if is_supporting variant then "supporting" else "default")
    @ Attr.data "current" (Bool.to_string is_current)
    @ i.attrs
  in
  let content_node =
    if is_current
    then
      Vdom.Node.span
        ~attrs:
          (Attr.class_ [ "astryx-breadcrumb-item__content"; content_class; "astryx-breadcrumb-item__content--current" ]
           @ Attr.aria "current" "page")
        content
    else
      match i.href with
      | Some url ->
        let href_attrs =
          if Citation.is_safe_url url then [ Vdom.Attr.href url ] else []
        in
        let click_attrs =
          match i.on_click with
          | Some f -> [ Vdom.Attr.on_click (fun _ -> f ()) ]
          | None -> []
        in
        Vdom.Node.a ~attrs:(Attr.class_ link_class @ href_attrs @ click_attrs) content
      | None ->
        (match i.on_click with
         | Some f ->
           Vdom.Node.button
             ~attrs:
               (Attr.class_ (link_class @ [ "astryx-breadcrumb-item__button-reset" ])
                @ [ Vdom.Attr.create "type" "button" ]
                @ [ Vdom.Attr.on_click (fun _ -> f ()) ])
             content
         | None ->
           Vdom.Node.span
             ~attrs:
               (Attr.class_
                  [ "astryx-breadcrumb-item__content"; content_class; "astryx-breadcrumb-item__content--current" ])
             content)
  in
  Vdom.Node.li ~attrs:li_attrs [ separator_node separator; content_node ]
;;
