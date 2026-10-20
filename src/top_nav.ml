open! Core
open! Bonsai_web

(* Upstream's TopNavItem. The anchor is always a plain <a>: upstream renders
   through useLinkComponent, which is a plain anchor unless a LinkProvider
   says otherwise, and there is no provider in this port. *)

module Item = struct
  let view
    ~label
    ?id
    ?href
    ?target
    ?rel
    ?icon
    ?is_selected
    ?is_disabled
    ?is_icon_only
    ?on_click
    ?attrs
    children =
    let is_selected = Option.value is_selected ~default:false in
    let is_disabled = Option.value is_disabled ~default:false in
    let is_icon_only = Option.value is_icon_only ~default:false in
    let class_names =
      [ "astryx-top-nav-item" ]
      @ (if is_selected then [ "astryx-top-nav-item--selected" ] else [])
      @ (if is_icon_only then [ "astryx-top-nav-item--icon-only" ] else [])
      @ (if is_disabled then [ "astryx-top-nav-item--disabled" ] else [])
    in
    let item_attrs =
      Common.Attr.class_ class_names
      @ Common.Attr.data "component" "TopNavItem"
      @ (match id with
        | Some id -> [ Vdom.Attr.create "id" id ]
        | None -> [])
      (* A disabled item drops the href and the target with it, so it cannot
         navigate and is out of the tab order. *)
      @ (match href with
        | Some href when not is_disabled -> [ Vdom.Attr.create "href" href ]
        | _ -> [])
      @ (match target with
        | Some target when not is_disabled -> [ Vdom.Attr.create "target" target ]
        | _ -> [])
      @ (match rel with
        | Some rel -> [ Vdom.Attr.create "rel" rel ]
        | None -> [])
      @ (if is_icon_only then [ Vdom.Attr.create "aria-label" label ] else [])
      @ (if is_selected then [ Vdom.Attr.create "aria-current" "page" ] else [])
      @ (if is_disabled then [ Vdom.Attr.create "aria-disabled" "true" ] else [])
      @ (if is_disabled then [ Vdom.Attr.create "tabindex" "-1" ] else [])
      (* The marker upstream's press controller answers; the controller itself
         is not ported. *)
      @ (if is_disabled then [] else [ Vdom.Attr.create "data-astryx-pressable" "" ])
      @ (match on_click with
        | Some on_click when not is_disabled -> [ Vdom.Attr.on_click on_click ]
        | _ -> [])
      @ Option.value attrs ~default:[]
    in
    let content =
      (match icon with
       | Some icon -> [ icon ]
       | None -> [])
      @ (if is_icon_only then
           []
         else if List.is_empty children then
           [ Vdom.Node.text label ]
         else
           children)
    in
    Vdom.Node.a ~attrs:item_attrs content
  ;;
end

(* Upstream's TopNavHeading. The boundary between "one link", "one trigger"
   and "independent links" is decided from the slots that are filled, exactly
   as upstream decides it. *)

module Heading = struct
  let view
    ?id
    ?logo
    ?logo_label
    ?heading
    ?heading_href
    ?superheading
    ?superheading_href
    ?subheading
    ?subheading_href
    ?header_end_content
    ?menu
    ?is_menu_open
    ?on_menu_open_change
    ?attrs
    () =
    let show_chevron = Option.is_some menu in
    let has_any_href =
      Option.is_some heading_href || Option.is_some superheading_href || Option.is_some subheading_href
    in
    let is_whole_heading_link =
      Option.is_some heading_href
      && not show_chevron
      && not (Option.is_some superheading_href)
      && not (Option.is_some subheading_href)
    in
    let is_whole_heading_trigger = show_chevron && not has_any_href in
    let logo_link_label =
      match logo_label with
      | Some logo_label -> logo_label
      | None -> Option.value heading ~default:""
    in
    let root_attrs =
      Common.Attr.class_ [ "astryx-top-nav-heading" ]
      @ Common.Attr.data "component" "TopNavHeading"
      @ (match id with
        | Some id -> [ Vdom.Attr.create "id" id ]
        | None -> [])
      @ Option.value attrs ~default:[]
    in
    let logo_span =
      match logo with
      | None -> []
      | Some logo ->
        [ Vdom.Node.span ~attrs:(Common.Attr.class_ [ "astryx-top-nav-heading__logo" ]) [ logo ] ]
    in
    let logo_anchor ~href ~label =
      match logo with
      | None -> []
      | Some logo ->
        [ Vdom.Node.a
            ~attrs:
              (Common.Attr.class_ [ "astryx-top-nav-heading__logo" ]
              @ [ Vdom.Attr.create "href" href
                ; Vdom.Attr.create "aria-label" label ])
            [ logo ]
        ]
    in
    let text_or_link ~class_names ~text ~href ~with_links =
      match (with_links, href) with
      | true, Some href ->
        [ Vdom.Node.a
            ~attrs:
              (Common.Attr.class_ (class_names @ [ "astryx-top-nav-heading__link" ])
              @ [ Vdom.Attr.create "href" href ])
            [ Vdom.Node.text text ]
        ]
      | _ -> [ Vdom.Node.span ~attrs:(Common.Attr.class_ class_names) [ Vdom.Node.text text ] ]
    in
    let text_container ~with_links ~inline_chevron =
      let superheading_nodes =
        match superheading with
        | None -> []
        | Some text ->
          text_or_link
            ~class_names:[ "astryx-top-nav-heading__superheading" ]
            ~text
            ~href:superheading_href
            ~with_links
      in
      let heading_nodes =
        match heading with
        | None -> []
        | Some text ->
          text_or_link
            ~class_names:[ "astryx-top-nav-heading__heading" ]
            ~text
            ~href:heading_href
            ~with_links
      in
      let subheading_nodes =
        match subheading with
        | None -> []
        | Some text ->
          text_or_link
            ~class_names:[ "astryx-top-nav-heading__subheading" ]
            ~text
            ~href:subheading_href
            ~with_links
      in
      let heading_row =
        Vdom.Node.span ~attrs:(Common.Attr.class_ [ "astryx-top-nav-heading__heading-row" ])
          (heading_nodes
          @ (match inline_chevron with
            | Some chevron -> [ chevron ]
            | None -> []))
      in
      Vdom.Node.span ~attrs:(Common.Attr.class_ [ "astryx-top-nav-heading__text" ])
        (superheading_nodes @ [ heading_row ] @ subheading_nodes)
    in
    let chevron_glyph ~flipped =
      Vdom.Node.span
        ~attrs:
          (Common.Attr.class_
             ([ "astryx-top-nav-heading__chevron" ]
             @ (if flipped then [ "astryx-top-nav-heading__chevron--flipped" ] else [])))
        [ Icon.view ~name:"chevronDown" () ]
    in
    let header_end_nodes =
      match header_end_content with
      | None -> []
      | Some content ->
        [ Vdom.Node.span ~attrs:(Common.Attr.class_ [ "astryx-top-nav-heading__header-end" ]) [ content ] ]
    in
    let on_menu_open_change =
      match on_menu_open_change with
      | Some on_menu_open_change -> on_menu_open_change
      | None -> fun (_ : bool) -> Effect.Ignore
    in
    (* The chevron is the popover's trigger, and the popover owns the
       aria-haspopup/expanded/controls relationship and the click that
       toggles. The popover's own heading is a close affordance, not a second
       trigger. *)
    let popover_node =
      match menu with
      | None -> None
      | Some menu ->
        let popover_heading =
          Vdom.Node.button
            ~attrs:
              (Common.Attr.class_ [ "astryx-top-nav-heading__popover-heading" ]
              @ [ Vdom.Attr.create "type" "button"
                ; Vdom.Attr.on_click (fun _ -> on_menu_open_change false) ])
            (logo_span
            @ [ text_container ~with_links:false ~inline_chevron:(Some (chevron_glyph ~flipped:true)) ])
        in
        let menu_region =
          Vdom.Node.div
            ~attrs:
              (Common.Attr.class_ [ "astryx-top-nav-heading__menu" ]
              @ [ Vdom.Attr.create "role" "menu"
                ; Vdom.Attr.create "aria-label" (Option.value heading ~default:"Navigation menu") ])
            menu
        in
        Some
          (Popover.view
             ~role:Popover.No_role
             ~has_close_button:false
             ~is_modal:false
             ~placement:Popover.Below
             ~alignment:Popover.Align_start
             ~label:"Navigation menu"
             ~trigger:
               (Vdom.Node.button
                  ~attrs:
                    (Common.Attr.class_ [ "astryx-top-nav-heading__chevron-button" ]
                    @ [ Vdom.Attr.create "type" "button"
                      ; Vdom.Attr.create "aria-label" "Open menu" ])
                  [ chevron_glyph ~flipped:false ])
             ~content:
               (Vdom.Node.div
                  ~attrs:(Common.Attr.class_ [ "astryx-top-nav-heading__popover" ])
                  [ popover_heading ; menu_region ])
             ~is_open:(Option.value is_menu_open ~default:false)
             ~on_open_change:on_menu_open_change
             ())
    in
    if Option.is_none heading && not show_chevron then
      (* A logo on its own. *)
      (match heading_href with
       | Some href ->
         Vdom.Node.a
           ~attrs:
             (root_attrs
             @ [ Vdom.Attr.create "href" href ]
             @ (match logo_label with
               | Some logo_label -> [ Vdom.Attr.create "aria-label" logo_label ]
               | None -> []))
           logo_span
       | None -> Vdom.Node.div ~attrs:root_attrs logo_span)
    else if is_whole_heading_link then
      (* The whole heading is one link. *)
      Vdom.Node.a
        ~attrs:(root_attrs @ [ Vdom.Attr.create "href" (Option.value heading_href ~default:"") ])
        (logo_span
        @ [ text_container ~with_links:false ~inline_chevron:None ]
        @ header_end_nodes)
    else if is_whole_heading_trigger then
      (* The heading carries the menu's trigger. *)
      Vdom.Node.div
        ~attrs:root_attrs
        (logo_span
        @ [ text_container ~with_links:false ~inline_chevron:popover_node ]
        @ header_end_nodes)
    else if show_chevron && has_any_href then
      (* The links are independent; the chevron opens the menu. *)
      Vdom.Node.div
        ~attrs:root_attrs
        ((match heading_href with
          | Some href -> logo_anchor ~href ~label:logo_link_label
          | None -> logo_span)
        @ [ text_container ~with_links:true ~inline_chevron:popover_node ]
        @ header_end_nodes)
    else if has_any_href then
      (* Each link stands on its own. *)
      Vdom.Node.div
        ~attrs:root_attrs
        ((match heading_href with
          | Some href -> logo_anchor ~href ~label:logo_link_label
          | None -> logo_span)
        @ [ text_container ~with_links:true ~inline_chevron:None ]
        @ header_end_nodes)
    else
      Vdom.Node.div
        ~attrs:root_attrs
        (logo_span
        @ [ text_container ~with_links:false ~inline_chevron:None ]
        @ header_end_nodes)
  ;;
end

(* Upstream's TopNav, in its default mode: the full bar. *)

let view ?id ?label ?heading ?start_content ?center_content ?end_content ?attrs children =
  let label = Option.value label ~default:"Top navigation" in
  (* Upstream's children are an alias for startContent, and startContent wins
     when both are given. *)
  let start_content =
    match start_content with
    | Some start_content -> start_content
    | None -> children
  in
  let has_center_content = Option.is_some center_content in
  let class_names =
    [ "astryx-top-nav" ] @ (if has_center_content then [ "astryx-top-nav--grid" ] else [])
  in
  let nav_attrs =
    Common.Attr.class_ class_names
    @ Common.Attr.data "component" "TopNav"
    @ [ Vdom.Attr.create "role" "navigation"
      ; Vdom.Attr.create "aria-label" label ]
    @ (match id with
      | Some id -> [ Vdom.Attr.create "id" id ]
      | None -> [])
    @ Option.value attrs ~default:[]
  in
  let heading_nodes =
    match heading with
    | None -> []
    | Some heading ->
      [ Vdom.Node.div ~attrs:(Common.Attr.class_ [ "astryx-top-nav__heading" ]) [ heading ] ]
  in
  let start_nodes =
    if List.is_empty start_content then
      []
    else
      [ Vdom.Node.div ~attrs:(Common.Attr.class_ [ "astryx-top-nav__start" ]) start_content ]
  in
  let left_section =
    Vdom.Node.div
      ~attrs:(Common.Attr.class_ [ "astryx-top-nav__left-section" ])
      (heading_nodes @ start_nodes)
  in
  let center_nodes =
    match center_content with
    | None -> []
    | Some content ->
      [ Vdom.Node.div ~attrs:(Common.Attr.class_ [ "astryx-top-nav__center" ]) content ]
  in
  let end_nodes =
    if has_center_content then
      (* With a center slot the bar is a three-column grid, and the end slot
         sits in the third column whatever it measures. *)
      [ Vdom.Node.div
          ~attrs:(Common.Attr.class_ [ "astryx-top-nav__right" ])
          (Option.value end_content ~default:[]) ]
    else
      (match end_content with
       | None -> []
       | Some content ->
         [ Vdom.Node.div ~attrs:(Common.Attr.class_ [ "astryx-top-nav__end" ]) content ])
  in
  Vdom.Node.nav ~attrs:nav_attrs (left_section :: (center_nodes @ end_nodes))
;;
