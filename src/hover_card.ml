(* Copyright (c) Meta Platforms, Inc. and affiliates.
   Ported to OCaml/Bonsai from the astryx HoverCard component.

   The trigger owns the anchor; the card is its hover/focus companion. Unlike
   {!Tooltip}, the card holds arbitrary interactive content and is a layer
   surface of its own (a named dialog when [label] is given, an unnamed group
   when it is not). *)

open! Core
open! Bonsai_web
open Js_of_ocaml

module Attr = Common.Attr

type placement =
  | Above
  | Below
  | Start
  | End

type alignment =
  | Start
  | Center
  | End

type focus_trigger =
  | Focus_auto
  | Focus_always
  | Focus_never

type hover_indication =
  | Indicate_auto
  | Indicate_show
  | Indicate_hide

let placement_class = function
  | Above -> "astryx-hover-card--above"
  | Below -> "astryx-hover-card--below"
  | Start -> "astryx-hover-card--start"
  | End -> "astryx-hover-card--end"
;;

let alignment_class = function
  | Start -> "astryx-hover-card--align-start"
  | Center -> "astryx-hover-card--align-center"
  | End -> "astryx-hover-card--align-end"
;;

let placement_name = function
  | Above -> "above"
  | Below -> "below"
  | Start -> "start"
  | End -> "end"
;;

let alignment_name = function
  | Start -> "start"
  | Center -> "center"
  | End -> "end"
;;

(* Upstream decides ['auto'] by asking the child whether it is text-only; here
   the trigger is a [Vdom.Node.t] value, so the same test is a pattern match on
   the [Text] constructor. *)
let is_text_only (node : Vdom.Node.t) =
  match node with
  | Vdom.Node.Text _ -> true
  | _ -> false
;;

(* The trigger and content are computations here, so a stateful trigger (the
   Timestamp <time> element, whose text and aria-label re-render with the
   clock) can be wrapped; [view] lifts the plain values onto it, and [view_t]
   takes them as computations. The composition below is shared. *)
let view_impl
      ?(attrs = [])
      ?(placement = Above)
      ?(alignment = Center)
      ?(delay_ms = 300.0)
      ?(hide_delay_ms = 200.0)
      ?(focus_trigger = Focus_auto)
      ?(is_enabled = true)
      ?label
      ?on_open_change
      ?(has_hover_indication = Indicate_auto)
      ?is_open
      ?(is_default_open = false)
      ~id
      ~trigger_t
      ~content_t
      (graph : Bonsai.graph)
  =
  (* The open cell is shared with the controlled case: [is_open] replaces the
     value and the events stop driving it, exactly as Tooltip does. *)
  let base_open, set_base_open = Bonsai.state is_default_open graph in
  let controlled = Option.is_some is_open in
  let open_state =
    match is_open with
    | Some value -> Bonsai.return (value, fun (_ : bool) -> Effect.Many [])
    | None -> Bonsai.map2 base_open set_base_open ~f:(fun value set -> value, set)
  in
  let hovering, set_hovering = Bonsai.state false graph in
  let hovering_content, set_hovering_content = Bonsai.state false graph in
  let focused, set_focused = Bonsai.state false graph in
  let hovering_state = Bonsai.map2 hovering set_hovering ~f:(fun value set -> value, set) in
  let content_state = Bonsai.map2 hovering_content set_hovering_content ~f:(fun value set -> value, set) in
  let focused_state = Bonsai.map2 focused set_focused ~f:(fun value set -> value, set) in
  let core_state =
    Bonsai.map2 open_state hovering_state
      ~f:(fun (is_open, set_open) (hovering, set_hovering) -> (is_open, set_open, hovering, set_hovering))
  in
  let core_state =
    Bonsai.map2 core_state content_state
      ~f:(fun (is_open, set_open, hovering, set_hovering) (hovering_content, set_hovering_content) ->
        (is_open, set_open, hovering, set_hovering, hovering_content, set_hovering_content))
  in
  let trigger_content =
    Bonsai.map2 trigger_t content_t ~f:(fun trigger content -> trigger, content)
  in
  Bonsai.map2
    (Bonsai.map2 core_state focused_state ~f:(fun a b -> a, b))
    trigger_content
    ~f:(fun
      ((is_open, set_open, hovering, set_hovering, hovering_content, set_hovering_content), (focused, set_focused))
      (trigger, content) ->
        let open_effect =
          Effect.Many
            [ set_open true
            ; Option.value_map on_open_change ~default:Effect.Ignore ~f:(fun cb -> cb true)
            ]
        in
        let close_effect =
          Effect.Many
            [ set_open false
            ; Option.value_map on_open_change ~default:Effect.Ignore ~f:(fun cb -> cb false)
            ]
        in
        let key_is_escape (event : Dom_html.keyboardEvent Js.t) =
          String.equal (Option.value (Common.string_prop event "key") ~default:"") "Escape"
        in
        (* The show delay belongs to hover only: focusing opens immediately, as
           Tooltip does, because a keyboard user has already committed. The
           hook's input returns to [None] the moment the pointer leaves, which
           cancels rather than races. Controlled cards never schedule: the
           caller owns the answer. *)
        (* One hook, both directions: virtual_dom keys hook attrs by name and
           combines same-named hooks, so a show-hook and a hide-hook on one
           element would fuse into a single timer that runs both effects at
           once (net: never opens). The input therefore says which timer is
           live, and the elapsed effect matches it. *)
        let show_cond = hovering && not is_open && is_enabled in
        let hide_cond =
          is_open && not hovering && not hovering_content && not focused && is_enabled
        in
        let delay_attr =
          if controlled
          then Common.Delay_hook.cancel
          else
            Common.Delay_hook.attr
              ~delay_ms:
                (if show_cond
                 then Some delay_ms
                 else if hide_cond
                 then Some hide_delay_ms
                 else None)
              ~on_elapsed:(if show_cond then open_effect else close_effect)
        in
        let mouse_attrs =
          if is_enabled
          then
            [ Vdom.Attr.on_mouseenter (fun _ -> set_hovering true)
            ; Vdom.Attr.on_mouseleave (fun _ -> set_hovering false)
            ]
          else []
        in
        let focus_attrs =
          if is_enabled && not controlled
          then
            [ Vdom.Attr.on_focusin (fun _ -> Effect.Many [ set_focused true; open_effect ])
            ; Vdom.Attr.on_focusout (fun _ -> set_focused false)
            ]
          else []
        in
        (* [Auto] attaches focus listeners on any trigger. Upstream answers
           from the child's DOM focusability; a [Vdom] tree cannot, so the port
           reads [auto] as [always] — the wrapper carries [tabindex=0] itself
           when the trigger is text-only, and an element child's focusin
           bubbles up to the wrapper it is wrapped in. See the mli. *)
        let attach_focus =
          match focus_trigger with
          | Focus_always | Focus_auto -> true
          | Focus_never -> false
        in
        let focus_attrs = if attach_focus then focus_attrs else [] in
        let indication_class =
          match has_hover_indication with
          | Indicate_show -> [ "astryx-hover-card--indication" ]
          | Indicate_hide -> []
          | Indicate_auto ->
            if is_text_only trigger then [ "astryx-hover-card--indication" ] else []
        in
        let base_classes =
          [ "astryx-hover-card-anchor"
          ; if is_text_only trigger
            then "astryx-hover-card-anchor--inline"
            else "astryx-hover-card-anchor--contents"
          ]
        in
        let wrapper_attrs =
          Attr.class_ (List.append base_classes indication_class)
          @ Attr.data "component" "HoverCard"
          @ Attr.data "placement" (placement_name placement)
          @ Attr.data "alignment" (alignment_name alignment)
          @ (match label with
             | Some _ ->
               Attr.aria "haspopup" "dialog"
               @ (if is_open then Attr.aria "controls" id else [])
             | None -> if is_open then Attr.aria "describedby" id else [])
          @ (if is_text_only trigger then [ Vdom.Attr.tabindex 0 ] else [])
          @ mouse_attrs
          @ focus_attrs
          @ [ Vdom.Attr.on_keydown (fun event ->
                if key_is_escape event then close_effect else Effect.Many [])

            ; delay_attr
            ]
          @ attrs
        in
        let surface_attrs =
          Attr.class_ [ "astryx-hover-card"; placement_class placement; alignment_class alignment ]
          @ [ Vdom.Attr.create
                "role"
                (match label with Some _ -> "dialog" | None -> "group")
            ; Vdom.Attr.create "id" id
            ]
          @ (match label with Some l -> [ Vdom.Attr.create "aria-label" l ] | None -> [])
          @ Attr.data "component" "HoverCard"
          @ Attr.data "placement" (placement_name placement)
          @ Attr.data "alignment" (alignment_name alignment)
        in
        let content_attrs =
          Attr.class_ [ "astryx-hover-card__content" ]
          @ [ Vdom.Attr.on_mouseenter (fun _ -> set_hovering_content true)
            ; Vdom.Attr.on_mouseleave (fun _ -> set_hovering_content false)
            ; Vdom.Attr.on_focusin (fun _ -> set_focused true)
            ; Vdom.Attr.on_focusout (fun _ -> set_focused false)
            ; Vdom.Attr.on_keydown (fun event ->
                if key_is_escape event then close_effect else Effect.Many [])
            ]
        in
        (* Nothing is mounted while closed: there is no surface to find in the
           DOM, which is what keeps [aria-controls]/[aria-describedby] honest. *)
        let surface =
          if is_open
          then
            [ Vdom.Node.div ~attrs:surface_attrs
                [ Vdom.Node.div ~attrs:content_attrs [ content ] ]
            ]
          else []
        in
        Vdom.Node.span ~attrs:wrapper_attrs (trigger :: surface))
;;

(* [view]: the trigger and content are plain values, the common case — a
   static span, a panel. *)

let view
      ?(attrs = [])
      ?(placement = Above)
      ?(alignment = Center)
      ?(delay_ms = 300.0)
      ?(hide_delay_ms = 200.0)
      ?(focus_trigger = Focus_auto)
      ?(is_enabled = true)
      ?label
      ?on_open_change
      ?(has_hover_indication = Indicate_auto)
      ?is_open
      ?(is_default_open = false)
      ~id
      ~trigger
      ~content
      (graph : Bonsai.graph)
  =
  view_impl
    ~attrs
    ~placement
    ~alignment
    ~delay_ms
    ~hide_delay_ms
    ~focus_trigger
    ~is_enabled
    ?label
    ?on_open_change
    ~has_hover_indication
    ?is_open
    ~is_default_open
    ~id
    ~trigger_t:(Bonsai.return trigger)
    ~content_t:(Bonsai.return content)
    graph
;;

(* [view_t]: the trigger and content are computations, for the stateful
   trigger (a <time> whose text re-renders with the clock). Same behaviour,
   same DOM — the difference is only where the values come from. *)

let view_t
      ?(attrs = [])
      ?(placement = Above)
      ?(alignment = Center)
      ?(delay_ms = 300.0)
      ?(hide_delay_ms = 200.0)
      ?(focus_trigger = Focus_auto)
      ?(is_enabled = true)
      ?label
      ?on_open_change
      ?(has_hover_indication = Indicate_auto)
      ?is_open
      ?(is_default_open = false)
      ~id
      ~trigger_t
      ~content_t
      (graph : Bonsai.graph)
  =
  view_impl
    ~attrs
    ~placement
    ~alignment
    ~delay_ms
    ~hide_delay_ms
    ~focus_trigger
    ~is_enabled
    ?label
    ?on_open_change
    ~has_hover_indication
    ?is_open
    ~is_default_open
    ~id
    ~trigger_t
    ~content_t
    graph
;;
