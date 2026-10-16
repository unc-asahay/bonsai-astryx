open! Core
open! Bonsai_web

type heading_level =
  | H1
  | H2
  | H3
  | H4
  | H5
  | H6

let heading_node ~level ~attrs children =
  match level with
  | H1 -> Vdom.Node.h1 ~attrs children
  | H2 -> Vdom.Node.h2 ~attrs children
  | H3 -> Vdom.Node.h3 ~attrs children
  | H4 -> Vdom.Node.h4 ~attrs children
  | H5 -> Vdom.Node.h5 ~attrs children
  | H6 -> Vdom.Node.h6 ~attrs children
;;

let view
  ?description
  ?icon
  ?(actions = [])
  ?(heading_level = H3)
  ?(is_compact = false)
  ?(attrs = [])
  ~title
  ()
  =
  let compact_class base = if is_compact then [ base ] else [] in
  let container_attrs =
    Common.Attr.class_
      ([ "astryx-empty-state" ] @ compact_class "astryx-empty-state--compact")
    @ Common.Attr.data "component" "EmptyState"
    @ (if is_compact then Common.Attr.data "variant" "compact" else [])
    (* role=status: the empty state is a change of state, so announce it. *)
    @ Common.Attr.role "status"
    @ attrs
  in
  let icon_block =
    match icon with
    | None -> []
    | Some icon -> [ Vdom.Node.div ~attrs:(Common.Attr.aria "hidden" "true") [ icon ] ]
  in
  let title_node =
    heading_node
      ~level:heading_level
      ~attrs:
        (Common.Attr.class_
           ([ "astryx-empty-state__title" ]
            @ compact_class "astryx-empty-state__title--compact"))
      [ Vdom.Node.text title ]
  in
  let description_nodes =
    match description with
    | None -> []
    | Some description ->
      (* A <div> on purpose — a <p> cannot legally contain block children. See the .mli. *)
      [ Vdom.Node.div
          ~attrs:
            (Common.Attr.class_
               ([ "astryx-empty-state__description" ]
                @ compact_class "astryx-empty-state__description--compact"))
          [ description ]
      ]
  in
  let text_group =
    Vdom.Node.div
      ~attrs:(Common.Attr.class_ [ "astryx-empty-state__text" ])
      (title_node :: description_nodes)
  in
  let actions_block =
    match actions with
    | [] -> []
    | actions ->
      [ Vdom.Node.div
          ~attrs:
            (Common.Attr.class_
               ([ "astryx-empty-state__actions" ]
                @ compact_class "astryx-empty-state__actions--compact"))
          actions
      ]
  in
  Vdom.Node.div ~attrs:container_attrs (icon_block @ [ text_group ] @ actions_block)
;;
