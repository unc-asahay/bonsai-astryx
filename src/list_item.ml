(* List_item — a row of an Astryx.List: an <li> Item. Port of upstream
   List/ListItem.tsx composed on top of Item (M44). *)

open! Core
open! Bonsai_web

(* The marker the row always carries; the list's stylesheet decides whether it
   shows and as what — its own class is the hook the list's data attributes
   drive, and outside a marker list it is display:none, so a Marker_none list
   has no phantom gap. *)
let marker_span () =
  Vdom.Node.span ~attrs:(Common.Attr.class_ [ "astryx-list-item__marker" ]) []
;;

let view
    ?id
    ?start_content
    ?end_content
    ?on_click
    ?interactive_selector
    ?href
    ?target
    ?rel
    ?(is_disabled = false)
    ?(is_selected = false)
    ?swipe_actions
    ?(swipe_behavior = Item.Reveal)
    ?description_id
    ?(attrs = [])
    ~label
    ?description
    graph =
  Item.view
    ~as_:Item.Li
    ~marker:(marker_span ())
    ?start_content
    ?description
    ?end_content
    ?on_click
    ?interactive_selector
    ?href
    ?target
    ?rel
    ~is_selected
    ~is_disabled
    ?swipe_actions
    ~swipe_behavior
    ~attrs:
      (attrs
       @ (match id with Some s -> [ Vdom.Attr.id s ] | None -> []))
    ?description_id
    ~label
    graph
;;
