open! Core
open! Bonsai_web

let view ?(attrs = []) ?icon ~label ~children () =
  let label_children =
    match icon with
    | None -> [ Vdom.Node.text label ]
    | Some icon ->
      (* The icon gets an element of its own so the gap between it and the text is the label styling done,
         not something the text itself has to carry. *)
      [ Vdom.Node.span ~attrs:[ Vdom.Attr.class_ "astryx-metadata-list__icon" ] [ icon ]
      ; Vdom.Node.text label
      ]
  in
  [ Vdom.Node.dt
      ~attrs:
        ([ Vdom.Attr.class_ "astryx-metadata-list__label" ]
         @ Common.Attr.data "component" "MetadataListItem"
         @ attrs)
      label_children
  ; Vdom.Node.dd ~attrs:[ Vdom.Attr.class_ "astryx-metadata-list__value" ] children
  ]
;;
