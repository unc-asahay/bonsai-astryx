open! Core
open! Bonsai_web

module Attr = Common.Attr

(* Upstream's AlertDialog is its own component with its own body, so — unlike Dialog, whose caller owns
   the header — this one owns both the title and the description elements and therefore the two ids the
   dialog points at. *)
type variant = Button.variant

let view
    ~title
    ~description
    ~action_label
    ?(cancel_label = "Cancel")
    ?action_variant
    ?(is_action_loading = false)
    ?width
    ?(is_inline = false)
    ~on_action
    ~is_open
    ~on_open_change
    ~id
    ()
  =
  let title_id = id ^ "-title" in
  let description_id = id ^ "-description" in
  let children =
    Bonsai.map2 on_action on_open_change ~f:(fun on_action on_open_change ->
      (* The id has to be on *something*, and this port's presentational components own their own
         attributes — the same rule as Icon — so the wrappers carry them. aria-labelledby takes any
         element, so pointing the dialog at a wrapper that contains the heading is exact rather than a
         workaround: what it names is the text inside it. *)
      let heading =
        Vdom.Node.div
          ~attrs:[ Vdom.Attr.create "id" title_id ]
          [ Heading.view ~level:Heading.H2 [ Vdom.Node.text title ] ]
      in
      let description_el =
        Text.view ~type_:Text.Body ~color:Text.Secondary ~id:description_id
          [ Vdom.Node.text description ]
      in
      let cancel =
        Button.view
          ~variant:Button.Secondary
          ~label:cancel_label
          ~attrs:[ Vdom.Attr.create "id" (id ^ "-cancel") ]
          ~on_click:(fun _ -> on_open_change false)
          []
      in
      let action =
        Button.view
          ?variant:action_variant
          ~label:action_label
          ~is_loading:is_action_loading
          ~attrs:[ Vdom.Attr.create "id" (id ^ "-action") ]
          ~on_click:(fun _ -> on_action)
          []
      in
      (* The order below is the desktop one. Reversing it on a narrow screen — rather than reading the
         viewport here and swapping — is a CSS rule, and one rule does what upstream does with a media
         query in JavaScript. See alert_dialog.mli. *)
      let actions =
        Vdom.Node.div
          ~attrs:(Attr.class_ [ "astryx-alert-dialog__actions" ])
          [ cancel; action ]
      in
      (* A root of its own. Compositing Dialog means the marked element would otherwise be Dialog's —
         the appearance contract, the DOM gate and the showcase all identify a component by its own
         marker, and upstream's AlertDialog has its own styled root too (themeProps('alert-dialog')). *)
      [ Vdom.Node.div
          ~attrs:(Attr.class_ [ "astryx-alert-dialog" ] @ Attr.data "component" "AlertDialog")
          [ heading; description_el; actions ]
      ])
  in
  Dialog.view
    ~purpose:Dialog.Form
    ~role:(if is_inline then "group" else "alertdialog")
    ~labelled_by:title_id
    ~described_by:description_id
    ?width
    ~variant:Dialog.Standard
    ~is_inline
    ~is_open
    ~on_open_change
    ~id
    ~children
    ()
;;
