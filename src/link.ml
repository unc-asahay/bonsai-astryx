open! Core
open! Bonsai_web

type as_ =
  href:string option
  -> to_:string option
  -> attrs:Vdom.Attr.t list
  -> children:Vdom.Node.t list
  -> Vdom.Node.t
;;

let default_new_tab_label = "(opens in new tab)"

let view
  ?as_
  ?label
  ?href
  ?rel
  ?target
  ?(has_underline = false)
  ?(is_disabled = false)
  ?(is_external_link = false)
  ?(new_tab_label = default_new_tab_label)
  ?(is_standalone = false)
  ?on_click
  ?type_
  ?size
  ?color
  ?weight
  ?display
  ?max_lines
  ?(attrs = [])
  children
  =
  let role = Interactive_role.of_inputs ~href ~has_on_click:(Option.is_some on_click) ~is_disabled in
  let renders_as_button = Interactive_role.renders_as_button role ~href in
  let handoff = Link_destination.resolve ~component:(if Option.is_some as_ then Custom else Anchor) ~href ~to_:None in
  let target, rel =
    if is_external_link then Target_and_rel.compute ~target:(Some "_blank") ~rel else Target_and_rel.compute ~target ~rel
  in
  let color_class = Text.color_class (Option.value color ~default:Text.Accent) in
  let classes =
    [ "astryx-link"; color_class ]
    @ (if has_underline then [ "astryx-link--underline" ] else [])
    @ (if is_standalone then [ "astryx-link--standalone" ] else [])
    @ (if is_disabled then [ "astryx-link--disabled" ] else [])
  in
  let content =
    [ Text.view ?type_ ?size ?color ?weight ?display ?max_lines children
    ; (if is_external_link && not renders_as_button
       then
         Vdom.Node.span
           ~attrs:(Common.Attr.class_ [ "astryx-link__icon" ])
           [ Icon.view ~size:Icon.Xsm ~color:Icon.Inherit ~name:"externalLink" ()
           ; Vdom.Node.span
               ~attrs:(Common.Attr.class_ [ "astryx-visually-hidden" ])
               [ Vdom.Node.text new_tab_label ]
           ]
       else Vdom.Node.none)
    ]
  in
  let label_attrs = Option.value_map label ~default:[] ~f:(fun l -> Common.Attr.aria "label" l) in
  (* The port-wide convention: every ported component stamps its own marker on ITS root so the
     contract tools (mountedComponents, the DOM gate, gen-visual-contract) can find it. Link
     missed this at M31, which silently dropped it from the appearance contract while the INDEX
     claimed otherwise - the stale-document class of bug this repo exists to catch. A custom
     [as_] component is excluded: it stamps its own marker (Button, RouterLink, ...) and would
     otherwise be mislabelled. *)
  let marker = Common.Attr.data "component" "Link" in
  let forwarded = attrs @ label_attrs in
  if renders_as_button
  then (
    (* `type="button"`, or a link rendered as a button inside a form would submit it. *)
    let click = Option.value on_click ~default:(fun _ -> Effect.Ignore) in
    Vdom.Node.create
      "button"
      ~attrs:
        (Common.Attr.class_ classes
         @ forwarded
         @ marker
         @ [ Vdom.Attr.create "type" "button"
           ; Vdom.Attr.on_click click
           ; (if is_disabled then Vdom.Attr.create "aria-disabled" "true" else Vdom.Attr.empty)
           ; (if is_disabled then Vdom.Attr.create "tabindex" "-1" else Vdom.Attr.empty)
           ])
      content)
  else if is_disabled
  then (
    (* A disabled link renders as a plain anchor with NO href: an href-less anchor is not focusable and
       exposes no link affordance, so neither programmatic focus + Enter, nor assistive-technology
       activation, nor middle-click can navigate. target/rel go with the href.
       The handler is upstream's: its docstring calls the preventDefault "a defensive guard against
       synthetic/programmatic clicks", since an href-less anchor has no navigation to block. It is not a
       substitute for omitting the href, and it replaces the caller's handler rather than joining it. *)
    let cancel event =
      Common.prevent_default event;
      Effect.Ignore
    in
    Vdom.Node.create
      "a"
      ~attrs:
        (Common.Attr.class_ classes
         @ forwarded
         @ marker
         @ [ Vdom.Attr.on_click cancel
           ; Vdom.Attr.create "aria-disabled" "true"
           ; Vdom.Attr.create "tabindex" "-1"
           ])
      content)
  else (
    match handoff with
    | Link_destination.Rejected ->
      (* One unsafe destination rejects the whole handoff: the anchor still renders, without it. *)
      Vdom.Node.create
        "a"
        ~attrs:(Common.Attr.class_ classes @ forwarded @ marker)
        content
    | Link_destination.Routed { href = routed_href; to_ = routed_to } ->
      let component = Option.value_exn as_ in
      component ~href:routed_href ~to_:routed_to ~attrs:(Common.Attr.class_ classes @ forwarded) ~children:content
    | Link_destination.Native native_href ->
      Vdom.Node.create
        "a"
        ~attrs:
          (Common.Attr.class_ classes
           @ forwarded
           @ marker
           @ Option.value_map native_href ~default:[] ~f:(fun h -> [ Vdom.Attr.href h ])
           @ Option.value_map target ~default:[] ~f:(fun t -> [ Vdom.Attr.create "target" t ])
           @ Option.value_map rel ~default:[] ~f:(fun r -> [ Vdom.Attr.create "rel" r ])
           @ Option.value_map on_click ~default:[] ~f:(fun h -> [ Vdom.Attr.on_click h ]))
        content)
;;
