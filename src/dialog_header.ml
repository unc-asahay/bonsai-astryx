open! Core
open! Bonsai_web

module Attr = Common.Attr

type edge_compensation =
  | Inline
  | Block
  | All

let compensation_class = function
  | Inline -> "astryx-dialog-header--compensate-inline"
  | Block -> "astryx-dialog-header--compensate-block"
  | All -> "astryx-dialog-header--compensate-all"
;;

(* The title is a real heading carrying the id the dialog names itself from. tabindex="-1" makes it
   focusable *programmatically* without putting it in the tab order — which is what upstream wants it
   for, and is also why the platform's own focus delegate skips it (see the .mli). *)
let title_el ~title_id ~title =
  Vdom.Node.create
    "h2"
    ~attrs:
      (Attr.class_ [ "astryx-dialog-header__title" ]
       @ [ Vdom.Attr.create "id" title_id; Vdom.Attr.create "tabindex" "-1" ])
    [ title ]
;;

let slot name content =
  Option.value_map content ~default:[] ~f:(fun content ->
    [ Vdom.Node.div ~attrs:(Attr.class_ [ name ]) [ content ] ])
;;

let close_button ~on_open_change =
  Option.value_map on_open_change ~default:[] ~f:(fun on_open_change ->
    [ Icon_button.view
        ~label:"Close"
        ~icon:(Icon.view ~name:"close" ())
        ~on_click:(fun _ -> on_open_change false)
        ()
    ])
;;

let view
    ~title_id
    ~title
    ?subtitle
    ?on_open_change
    ?start_content
    ?end_content
    ?end_content_edge_compensation
    ?(has_divider = false)
    ?attrs
    ()
  =
  let structure (resolved : (bool -> unit Effect.t) option) =
    Vdom.Node.create
      "div"
      ~attrs:
        (Attr.class_
           ([ "astryx-dialog-header" ]
            @ (if has_divider then [ "astryx-dialog-header--divider" ] else [])
            @ (match end_content_edge_compensation with
               | None -> []
               | Some compensation -> [ compensation_class compensation ]))
         @ Attr.data "component" "DialogHeader"
         @ Option.value attrs ~default:[])
      ([ title_el ~title_id ~title ]
       @ slot "astryx-dialog-header__subtitle" subtitle
       @ slot "astryx-dialog-header__start" start_content
       @ slot "astryx-dialog-header__end" end_content
       @ close_button ~on_open_change:resolved)
  in
  match on_open_change with
  | None -> Bonsai.return (structure None)
  | Some on_open_change -> Bonsai.map on_open_change ~f:(fun resolved -> structure (Some resolved))
;;
