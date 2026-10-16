open! Core
open! Bonsai_web

let view
  ~label
  ~icon
  ?variant
  ?size
  ?elevation
  ?type_
  ?is_loading
  ?is_disabled
  ?width
  ?href
  ?target
  ?rel
  ?on_click
  ()
  =
  Button.view
    ~label
    ~icon
    ~is_icon_only:true
    (* Its own name and its own class: this component is a Button in behaviour, but it is its own thing
       to every tool that identifies a component by its marker — the appearance contract, the DOM gate
       and the showcase. Without them, IconButton was the one ported component with no appearance page
       and the reason was invisible. Upstream styles it as its own component too (themeProps). *)
    ~component_name:"IconButton"
    ~attrs:[ Vdom.Attr.create "class" "astryx-icon-button" ]
    ?variant
    ?size
    ?elevation
    ?type_
    ?is_loading
    ?is_disabled
    ?width
    ?href
    ?target
    ?rel
    ?on_click
    []
;;
