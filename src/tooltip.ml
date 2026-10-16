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
      ?(delay_ms = 200.0)
      ?is_open
      ~id
      ~content
      ~trigger
      (graph : Bonsai.graph)
  =
  let uncontrolled, set_uncontrolled = Bonsai.state false graph in
  (* Hover opens after a delay; focus opens at once, and closes are always immediate. *)
  let hovering, set_hovering = Bonsai.state false graph in
  (* The setter is a tree as well as the value, so the pair is mapped like any other value. *)
  let hover_state = Bonsai.map2 hovering set_hovering ~f:(fun value set -> value, set) in
  (* [is_open] is upstream's controlled [open]: when given, it replaces the hover/focus state *and*
     the events stop driving anything, so the caller owns the answer. *)
  let open_state =
    match is_open with
    | Some value -> Bonsai.return (value, fun (_ : bool) -> Effect.Many [])
    | None -> Bonsai.map2 uncontrolled set_uncontrolled ~f:(fun value set -> value, set)
  in
  Bonsai.map2 open_state hover_state ~f:(fun (is_open, set_open) (hovering, set_hovering) ->
    (* The timer lives in a vdom hook: its input says [Some delay] while the pointer is here and
       [None] the moment it leaves, and a changed input cancels the previous timer. That is what
       makes "left before the delay elapsed" a cancel rather than a race. Upstream's 200 ms default
       is the default here too. *)
    let delay_attr =
      Common.Delay_hook.attr
        ~delay_ms:(if hovering then Some delay_ms else None)
        ~on_elapsed:(set_open true)
    in
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
      @ [ delay_attr
        ; Vdom.Attr.on_mouseenter (fun _ -> set_hovering true)
        ; (* Leaving closes at once, and cancels a timer that has not fired yet. *)
          Vdom.Attr.on_mouseleave (fun _ -> Effect.Many [ set_hovering false; set_open false ])
        ; (* Keyboard is not made to wait: focus opens now, and drops any pending hover timer. *)
          Vdom.Attr.on_focusin (fun _ -> Effect.Many [ set_hovering false; set_open true ])
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
