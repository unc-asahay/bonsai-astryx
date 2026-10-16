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

let placement_class = function
  | Above -> "astryx-tooltip--above"
  | Below -> "astryx-tooltip--below"
  | Start -> "astryx-tooltip--start"
  | End -> "astryx-tooltip--end"
;;

let alignment_class = function
  | Start -> "astryx-tooltip--align-start"
  | Center -> "astryx-tooltip--align-center"
  | End -> "astryx-tooltip--align-end"
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

let view
      ?(attrs = [])
      ?(placement = Above)
      ?(alignment = Center)
      ?is_open
      ~id
      ~content
      ~trigger
      (graph : Bonsai.graph)
  =
  let uncontrolled, set_uncontrolled = Bonsai.state false graph in
  (* [is_open] is upstream's controlled [open]: when given, it replaces the hover/focus state *and*
     the events stop driving anything, so the caller owns the answer. *)
  let open_state =
    match is_open with
    | Some value -> Bonsai.return (value, fun (_ : bool) -> Effect.Many [])
    | None -> Bonsai.map2 uncontrolled set_uncontrolled ~f:(fun value set -> value, set)
  in
  Bonsai.map open_state ~f:(fun (is_open, set_open) ->
    let key_is_escape (event : Dom_html.keyboardEvent Js.t) =
      String.equal (Option.value (Common.string_prop event "key") ~default:"") "Escape"
    in
    let anchor_attrs =
      Attr.class_ [ "astryx-tooltip-anchor" ]
      @ Attr.data "component" "Tooltip"
      @ Attr.data "placement" (placement_name placement)
      (* Present only while the message is showing, as upstream's is: it sets the attribute when the
         layer opens and restores whatever was there when it closes. *)
      @ (if is_open then Attr.aria "describedby" id else [])
      @ [ Vdom.Attr.on_mouseenter (fun _ -> set_open true)
        ; Vdom.Attr.on_mouseleave (fun _ -> set_open false)
        ; Vdom.Attr.on_focusin (fun _ -> set_open true)
        ; Vdom.Attr.on_focusout (fun _ -> set_open false)
        ; Vdom.Attr.on_keydown (fun event ->
            if key_is_escape event then set_open false else Effect.Many [])
        ]
      @ attrs
    in
    let message =
      (* Nothing is rendered while closed — upstream does not mount the layer either, so the message
         is not in the DOM to be found by a selector, a screen reader or a test. *)
      if is_open
      then
        [ Vdom.Node.div
            ~attrs:
              (Attr.class_
                 [ "astryx-tooltip"; placement_class placement; alignment_class alignment ]
               @ [ Vdom.Attr.create "role" "tooltip"; Vdom.Attr.create "id" id ]
               @ Attr.data "component" "Tooltip"
               @ Attr.data "placement" (placement_name placement)
               @ Attr.data "alignment" (alignment_name alignment))
            [ Vdom.Node.text content ]
        ]
      else []
    in
    Vdom.Node.span ~attrs:anchor_attrs (trigger :: message))
;;
