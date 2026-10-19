(* Breadcrumbs — the navigation trail. Port of upstream
   Breadcrumbs/Breadcrumbs.tsx with the items as data (upstream's children),
   because the auto-current crumb must be known before the first render and the
   container decides it the same way upstream's post-render DOM scan does. *)

open! Core
open! Bonsai_web
module Attr = Common.Attr

type item = Breadcrumb_item.t
type variant = Breadcrumb_item.variant = Default | Supporting

let default_separator = Vdom.Node.text "/"

let view
    ?id
    ?(attrs = [])
    ?(separator = default_separator)
    ?(variant = Default)
    ?(label = "Breadcrumb")
    ~items
    ()
  : Vdom.Node.t
  =
  (* Upstream: the last auto-candidate crumb becomes current when no crumb says
     so explicitly. If any crumb is Some true, no auto. *)
  let has_explicit_current =
    List.exists items ~f:(fun i ->
        match i.Breadcrumb_item.is_current with Some true -> true | _ -> false)
  in
  let auto_index : int option =
    if has_explicit_current
    then None
    else (
      let rec find acc = function
        | [] -> None
        | [ i ] ->
          (match i.Breadcrumb_item.is_current with
           | None -> Some acc
           | Some _ -> None)
        | _ :: rest -> find (acc + 1) rest
      in
      find 0 items)
  in
  let row_view idx (i : item) : Vdom.Node.t =
    Breadcrumb_item.view ~variant ~separator ~is_auto_current:(Poly.equal (Some idx) auto_index) i
  in
  let nav_attrs =
    Attr.class_ [ "astryx-breadcrumbs" ]
    @ Attr.aria "label" label
    @ Attr.data "component" "Breadcrumbs"
    @ Attr.data "variant" (match variant with Default -> "default" | Supporting -> "supporting")
    @ (match id with Some s -> [ Vdom.Attr.id s ] | None -> [])
    @ attrs
  in
  Vdom.Node.nav
    ~attrs:nav_attrs
    [ Vdom.Node.ol
        ~attrs:(Attr.class_ [ "astryx-breadcrumbs__list" ])
        (List.mapi items ~f:row_view)
    ]
;;
