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
