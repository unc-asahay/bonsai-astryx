open! Core
open! Bonsai_web

let default_label = "More"

(* Upstream's default is its own moreHorizontal icon. This port's icon set does not have one, so the default
   is the character - hidden from assistive technology, since the accessible name is the label. *)
let default_icon () =
  Vdom.Node.span
    ~attrs:
      [ Vdom.Attr.class_ "astryx-more-menu__glyph"
      ; Vdom.Attr.create "aria-hidden" "true"
      ]
    [ Vdom.Node.text "\xe2\x8b\xaf" ]
;;

let view
  ?(attrs = [])
  ?(id = "astryx-more-menu")
  ?(label = default_label)
  ?(variant = Button.Ghost)
  ?(size = Button.Md)
  ?icon
  ?(is_disabled = false)
  ?is_open
  ?on_open_change
  ~on_select
  ~items
  graph
  =
  Dropdown_menu.view
    ~attrs
    ~id
    ~is_disabled
    ~variant
    ~size
    ~is_icon_only:true
    ~icon:(Option.value icon ~default:(default_icon ()))
    ~trigger_component_name:"MoreMenu"
    ?is_open
    ?on_open_change
    ~trigger_label:label
    ~on_select
    ~entries:items
    graph
;;
