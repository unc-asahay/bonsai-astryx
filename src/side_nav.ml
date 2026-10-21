(* SideNav — the side navigation: a column of navigation items, with a heading
   area, a sticky top, a scrollable body, and a footer.

   Port of upstream's [packages/core/src/SideNav] — the container
   ([SideNav.tsx]), the heading ([SideNavHeading.tsx]), the item
   ([SideNavItem.tsx]) and the section ([SideNavSection.tsx]). The
   divergences are in the interface. *)

open! Core
open! Bonsai_web
open Js_of_ocaml

module Field_ = Field
module Attr = Common.Attr
module Icon = Icon
module Item = Item

let default_width = 260.
let default_min_width = 180.
let default_max_width = 480.
let width_step = 16.

(* The width is bounded, and it is a whole number of pixels: a column that
   is 260.4 pixels wide is a column that is 260 pixels wide. *)
let clamp_width width ~min ~max =
  let width = Float.round width in
  if Float.compare width min < 0 then min else if Float.compare width max > 0 then max else width
;;

(* A list of trees into one tree of a list of nodes. The house's Bonsai has
   no list combinator, so the trees are combined pairwise and read back by
   position. *)
let combine (trees : Vdom.Node.t Bonsai.t list) =
  List.fold trees ~init:(Bonsai.return []) ~f:(fun acc tree ->
    Bonsai.both acc tree |> Bonsai.map ~f:(fun (acc, tree) -> tree :: acc))
  |> Bonsai.map ~f:List.rev
;;

(* The style the column's width is written into. Upstream writes the width
   into the root's inline style, and so does this. *)
let width_style width =
  Vdom.Attr.create "style" (Printf.sprintf "width: %.0fpx" width)
;;

let view
  ?id
  ?(attrs = [])
  ?(header = [])
  ?(top_content = [])
  ?(footer = [])
  ?(footer_icons = [])
  ?(is_collapsible = false)
  ?(default_is_collapsed = false)
  ?is_collapsed
  ?on_collapsed_change
  ?(is_resizable = false)
  ?(default_width = default_width)
  ?(min_width = default_min_width)
  ?(max_width = default_max_width)
  ?on_width_change
  ?(children = [])
  graph
  =
  let id = Option.value id ~default:"astryx-side-nav" in
  (* The collapsed state and the width are each either the application's or
     the column's own, in the house's controlled/uncontrolled pattern. *)
  let collapsed_state, set_collapsed = Bonsai.state default_is_collapsed graph in
  let report_collapsed =
    match on_collapsed_change with
    | Some tree -> tree
    | None -> Bonsai.return (fun (_ : bool) -> Effect.Ignore)
  in
  let report_width =
    match on_width_change with
    | Some tree -> tree
    | None -> Bonsai.return (fun (_ : float) -> Effect.Ignore)
  in
  (* The collapsed state is either the application's or the column's own. In
     the controlled case the column never writes its own state: it reports
     the change and the application writes the new state. *)
  let collapsed_tree =
    match is_collapsed with
    | Some controlled ->
      Bonsai.map2 controlled report_collapsed
        ~f:(fun value report -> (value, report, (fun (_ : bool) -> Effect.Ignore)))
    | None ->
      Bonsai.map3 collapsed_state report_collapsed set_collapsed
        ~f:(fun value report set -> (value, report, set))
  in
  let width_state, set_width = Bonsai.state default_width graph in
  let width_tree =
    Bonsai.map3 width_state report_width set_width ~f:(fun value report set -> (value, report, set))
  in
  (* The body and the pinned area hold items, which are graphs. *)
  let parts_tree =
    Bonsai.map2 (combine children) (combine top_content) ~f:(fun body top -> (body, top))
  in
  Bonsai.map3 collapsed_tree width_tree parts_tree
    ~f:(fun
          (collapsed, report_collapsed, set_collapsed)
          (width, report_width, set_width)
          (body_nodes, top_nodes) ->
        let width = clamp_width width ~min:min_width ~max:max_width in
        let collapsed = collapsed && is_collapsible in
        (* The collapse button, and the separator that resizes the column. *)
        let collapse_button =
          if not is_collapsible
          then []
          else
            [ Vdom.Node.button
                ~attrs:
                  (Attr.class_ [ "astryx-side-nav__collapse" ]
                   @ Attr.aria "label" (if collapsed then "Expand the navigation" else "Collapse the navigation")
                   @ Attr.aria "expanded" (if collapsed then "false" else "true")
                   @ [ Vdom.Attr.on_click (fun _ ->
                         let next = not collapsed in
                         Effect.Many [ set_collapsed next; report_collapsed next ]) ])
                [ Icon.view ~name:"menu" ~size:Icon.Sm () ]
            ]
        in
        let handle =
          if not is_resizable
          then []
          else
            [ Vdom.Node.div
                ~attrs:
                  (Attr.class_ [ "astryx-side-nav__handle" ]
                   @ Attr.role "separator"
                   @ Attr.aria "orientation" "vertical"
                   @ Attr.aria "valuenow" (Int.to_string (int_of_float (Float.round width)))
                   @ Attr.aria "valuemin" (Int.to_string (int_of_float (Float.round min_width)))
                   @ Attr.aria "valuemax" (Int.to_string (int_of_float (Float.round max_width)))
                   @ Attr.aria "label" "Resize the navigation"
                   @ [ Vdom.Attr.tabindex 0
                     ; Vdom.Attr.on_keydown (fun (ev : Dom_html.keyboardEvent Js.t) ->
                         let key = Js.Unsafe.get ev "key" |> Js.to_string in
                         let step =
                           if String.equal key "ArrowLeft" then Some (-.width_step)
                           else if String.equal key "ArrowRight" then Some width_step
                           else if String.equal key "Home" then Some (min_width -. width)
                           else if String.equal key "End" then Some (max_width -. width)
                           else None
                         in
                         match step with
                         | None -> Effect.Ignore
                         | Some step ->
                           let next = clamp_width (width +. step) ~min:min_width ~max:max_width in
                           Effect.Many [ set_width next; report_width next ])
                     ])
                []
            ]
        in
        let region title content =
          match content with
          | [] -> []
          | _ ->
            [ Vdom.Node.div
                ~attrs:(Attr.class_ [ "astryx-side-nav__region" ] @ Attr.aria "label" title)
                content ]
        in
        let root_attrs =
          Attr.class_
            ([ "astryx-side-nav" ]
             @ (if collapsed then [ "astryx-side-nav--collapsed" ] else []))
          @ Attr.data "component" "SideNav"
          @ [ Vdom.Attr.id id ]
          @ Attr.data "collapsed" (if collapsed then "true" else "false")
          @ Attr.data "resizable" (if is_resizable then "true" else "false")
          @ (if is_resizable then [ width_style width ] else [])
          @ attrs
        in
        Vdom.Node.nav
          ~attrs:root_attrs
          (region "Heading" header
           @ (if List.is_empty top_nodes then [] else region "Pinned" top_nodes)
           @ [ Vdom.Node.div ~attrs:(Attr.class_ [ "astryx-side-nav__body" ]) body_nodes ]
           @ region "Footer" footer
           @ region "Footer icons" footer_icons
           @ collapse_button
           @ handle))
;;

let heading
  ?id
  ?(attrs = [])
  ~heading
  ?heading_href
  ?superheading
  ?subheading
  ?icon
  ?(children = [])
  _graph
  =
  let id = Option.value id ~default:"astryx-side-nav-heading" in
  let link ?href content =
    match href with
    | None -> content
    | Some href ->
      [ Vdom.Node.a
          ~attrs:[ Vdom.Attr.href href; Vdom.Attr.class_ "astryx-side-nav__heading-link" ]
          content ]
  in
  let text_node text = Vdom.Node.text text in
  let superheading_nodes =
    match superheading with
    | None -> []
    | Some text -> [ Vdom.Node.div ~attrs:(Attr.class_ [ "astryx-side-nav__superheading" ]) (link ?href:None [ text_node text ]) ]
  in
  let heading_nodes =
    [ Vdom.Node.div
        ~attrs:(Attr.class_ [ "astryx-side-nav__heading-text" ])
        (link ?href:heading_href [ text_node heading ]) ]
  in
  let subheading_nodes =
    match subheading with
    | None -> []
    | Some text -> [ Vdom.Node.div ~attrs:(Attr.class_ [ "astryx-side-nav__subheading" ]) [ text_node text ] ]
  in
  let icon_nodes =
    match icon with
    | None -> []
    | Some name -> [ Vdom.Node.span ~attrs:(Attr.class_ [ "astryx-side-nav__heading-icon" ]) [ Icon.view ~name ~size:Icon.Sm () ] ]
  in
  Vdom.Node.div
    ~attrs:
      (Attr.class_ [ "astryx-side-nav__heading" ]
       @ Attr.data "side-nav-heading" "true"
       @ [ Vdom.Attr.id id ]
       @ attrs)
    (icon_nodes @ superheading_nodes @ heading_nodes @ subheading_nodes @ children)
;;

let item
  ?id
  ?(attrs = [])
  ~label
  ?icon
  ?selected_icon
  ?(is_selected = false)
  ?(is_disabled = false)
  ?href
  ?on_click
  ?(end_content = [])
  ?(actions = [])
  graph
  =
  let id = Option.value id ~default:"astryx-side-nav-item" in
  (* The selected icon replaces the icon while the item is selected; the
     selected icon is optional, so the icon is used when there is none. *)
  let icon_name =
    if is_selected
    then
      match selected_icon with
      | Some name -> Some name
      | None -> icon
    else icon
  in
  let start_content =
    match icon_name with
    | None -> Vdom.Node.text ""
    | Some name -> Vdom.Node.span ~attrs:(Attr.class_ [ "astryx-side-nav__item-icon" ]) [ Icon.view ~name ~size:Icon.Md () ]
  in
  let end_nodes =
    if List.is_empty end_content && List.is_empty actions
    then Vdom.Node.text ""
    else Vdom.Node.div ~attrs:(Attr.class_ [ "astryx-side-nav__item-end" ]) (end_content @ actions)
  in
  let item_attrs =
    Attr.class_
      ([ "astryx-side-nav__item" ]
       @ (if is_selected then [ "astryx-side-nav__item--selected" ] else [])
       @ (if is_disabled then [ "astryx-side-nav__item--disabled" ] else []))
    @ Attr.data "side-nav-item" "true"
    @ [ Vdom.Attr.id id ]
    @ attrs
  in
  Item.view
    ~start_content
    ~end_content:end_nodes
    ~label:(Vdom.Node.text label)
    ~is_selected
    ~is_disabled
    ?href
    ?on_click
    ~attrs:item_attrs
    graph
;;

let section
  ?id
  ?(attrs = [])
  ~title
  ?subtitle
  ?(is_header_hidden = false)
  ?(end_content = [])
  ?(children = [])
  _graph
  =
  let id = Option.value id ~default:"astryx-side-nav-section" in
  let header =
    if is_header_hidden
    then []
    else
      [ Vdom.Node.div
          ~attrs:(Attr.class_ [ "astryx-side-nav__section-header" ])
          [ Vdom.Node.div
              ~attrs:(Attr.class_ [ "astryx-side-nav__section-title" ])
              [ Vdom.Node.text title ] ] ]
      @ (match subtitle with
         | None -> []
         | Some text ->
           [ Vdom.Node.div
               ~attrs:(Attr.class_ [ "astryx-side-nav__section-subtitle" ])
               [ Vdom.Node.text text ] ])
      @ (if List.is_empty end_content
         then []
         else [ Vdom.Node.div ~attrs:(Attr.class_ [ "astryx-side-nav__section-end" ]) end_content ])
  in
  (* The group's items are graphs, so the group is a graph too. *)
  Bonsai.map (combine children) ~f:(fun body ->
      Vdom.Node.div
        ~attrs:
          (Attr.class_ [ "astryx-side-nav__section" ]
           @ Attr.data "side-nav-section" "true"
           @ [ Vdom.Attr.id id ]
           @ attrs)
        (header @ body))
;;
