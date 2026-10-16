open! Core
open! Bonsai_web

module Attr = Common.Attr

type kind =
  | Check
  | Checkbox
  | Radio

type state =
  | Checked
  | Unchecked
  | Indeterminate

type size =
  | Sm
  | Md

let kind_string = function
  | Check -> "check"
  | Checkbox -> "checkbox"
  | Radio -> "radio"
;;

let state_string = function
  | Checked -> "checked"
  | Unchecked -> "unchecked"
  | Indeterminate -> "indeterminate"
;;

let size_string = function
  | Sm -> "sm"
  | Md -> "md"
;;

let is_checked = function
  | Checked -> true
  | Unchecked | Indeterminate -> false
;;

let is_on = function
  | Unchecked -> false
  | Checked | Indeterminate -> true
;;

(* Upstream's mark, at both sizes: one path, scaled by the viewBox. Every element inside <svg> has
   to come from [create_svg] — [create] builds an HTML element and an HTML "path" is a no-op, so a
   mistake here renders a box with nothing in it and nothing fails. *)
let checkmark () =
  Vdom.Node.create_svg
    "svg"
    ~attrs:
      (Attr.class_ [ "astryx-indicator__check" ]
       @ [ Vdom.Attr.create "viewBox" "0 0 10 10"
         ; Vdom.Attr.create "aria-hidden" "true"
         ; Vdom.Attr.create "focusable" "false"
         ])
    [ Vdom.Node.create_svg
        "path"
        ~attrs:
          [ Vdom.Attr.create "d" "M8.5 2.5L4 7.5L1.5 5"
          ; Vdom.Attr.create "stroke" "currentColor"
          ; Vdom.Attr.create "stroke-width" "1.5"
          ; Vdom.Attr.create "fill" "none"
          ; Vdom.Attr.create "stroke-linecap" "round"
          ; Vdom.Attr.create "stroke-linejoin" "round"
          ]
        []
    ]
;;

let dash () = Vdom.Node.span ~attrs:(Attr.class_ [ "astryx-indicator__dash" ]) []
let dot () = Vdom.Node.span ~attrs:(Attr.class_ [ "astryx-indicator__dot" ]) []

let view ~kind ~state ?(is_disabled = false) ?(attrs = []) ~size () =
  match kind with
  | Check ->
    (* A bare mark has no box, so there is nothing to draw when it is not on — upstream returns
       null rather than an empty span, and a layout that counts on the slot's box would be reading
       a node that is not there. *)
    if not (is_on state)
    then Vdom.Node.none
    else
      Icon.view
        ~name:"check"
        ~size:(match size with Sm -> Icon.Sm | Md -> Icon.Md)
        ~color:(if is_disabled then Icon.Disabled else Icon.Accent)
        (* Icon already sets this element's aria-hidden (it has no label) and its own
           data-astryx-component. Setting either again is not "combining attributes" — Vdom warns
           and one of the two silently wins — so the bare mark carries only what is its own. *)
        ~attrs:
          (Attr.class_ [ "astryx-indicator__mark" ]
           @ Attr.data "kind" (kind_string kind)
           @ Attr.data "state" (state_string state)
           @ attrs)
        ()
  | Checkbox ->
    Vdom.Node.span
      ~attrs:
        (Attr.class_
           ([ "astryx-indicator"; "astryx-indicator--checkbox"; "astryx-indicator--" ^ state_string state ]
            @ (if is_disabled then [ "astryx-indicator--disabled" ] else []))
         @ Attr.aria "hidden" "true"
         @ Attr.data "component" "Indicator"
         @ Attr.data "kind" (kind_string kind)
         @ Attr.data "state" (state_string state)
         @ Attr.data "size" (size_string size)
         @ attrs)
      ((if is_checked state then [ checkmark () ] else [])
       @ (match state with Indeterminate -> [ dash () ] | _ -> []))
  | Radio ->
    Vdom.Node.span
      ~attrs:
        (Attr.class_
           ([ "astryx-indicator"; "astryx-indicator--radio"; "astryx-indicator--" ^ state_string state ]
            @ (if is_disabled then [ "astryx-indicator--disabled" ] else []))
         @ Attr.aria "hidden" "true"
         @ Attr.data "component" "Indicator"
         @ Attr.data "kind" (kind_string kind)
         @ Attr.data "state" (state_string state)
         @ Attr.data "size" (size_string size)
         @ attrs)
      (if is_checked state then [ dot () ] else [])
;;
