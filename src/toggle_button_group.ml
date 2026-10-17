open! Core
open! Bonsai_web

type orientation =
  | Horizontal
  | Vertical

let orientation_class = function
  | Horizontal -> "astryx-toggle-button-group--horizontal"
  | Vertical -> "astryx-toggle-button-group--vertical"
;;

let view
  ?(attrs = [])
  ?(id = "astryx-toggle-button-group")
  ?(orientation = Horizontal)
  ~label
  ~buttons
  ()
  =
  Vdom.Node.div
    ~attrs:
      ([ Vdom.Attr.class_ "astryx-toggle-button-group"
       ; Vdom.Attr.class_ (orientation_class orientation)
       ; Vdom.Attr.id id
       ; Vdom.Attr.create "role" "group"
       ; Vdom.Attr.create "aria-label" label
       ; Vdom.Attr.create
           "aria-orientation"
           (match orientation with
            | Horizontal -> "horizontal"
            | Vertical -> "vertical")
       ]
       @ Common.Attr.data "component" "ToggleButtonGroup"
       @ attrs)
    buttons
;;
