open! Core
open! Bonsai_web
open Js_of_ocaml

type size =
  | Sm
  | Md
  | Lg
[@@deriving sexp_of]

type item =
  { value : string
  ; label : string
  ; is_label_hidden : bool
  ; icon : Vdom.Node.t option
  ; is_disabled : bool
  }
[@@deriving sexp_of]

(* The value of the radio that just received focus, when the focus really moved *within* the group
   (relatedTarget is inside this container) and the target is an enabled segment. Upstream answers
   the same two questions - the [isFocusWithin] boundary check and the [closest('[role=radio]')]
   search that blocks nested-labels from re-firing the change - in a focus-spanning event handler;
   one [focusin] handler on the container is the boundary, so both questions are asked in JS where
   the DOM is, and handed back as an option. *)
let focused_value (ev : Dom_html.focusEvent Js.t) : string option =
  let js =
    Js.Unsafe.eval_string
      "(function (ev) { var cur = ev.currentTarget; var rel = ev.relatedTarget; if (!cur || !rel || !cur.contains(rel)) return null; var t = ev.target; var r = t && t.closest ? t.closest('[role=\"radio\"][data-astryx-value]') : null; if (!r || r.getAttribute('aria-disabled') === 'true') return null; return r.getAttribute('data-astryx-value'); })"
  in
  Option.map
    (Js.Opt.to_option
       (Js.Unsafe.fun_call js [| Js.Unsafe.inject ev |] : Js.js_string Js.t Js.opt))
    ~f:Js.to_string
;;

let size_class = function
  | Sm -> "sm"
  | Md -> "md"
  | Lg -> "lg"
;;

(* The house disabled-message bubble, byte-for-byte the CheckboxInput/TextInput shape (M13): the
   reason exists as long as the control is disabled, so [role=tooltip] is a name and not a promise. *)
let message_bubble ~id ~content : Vdom.Node.t =
  Vdom.Node.div
    ~attrs:
      (Common.Attr.class_ [ "astryx-disabled-message" ]
       @ [ Vdom.Attr.create "role" "tooltip"; Vdom.Attr.create "id" id ]
       @ Common.Attr.data "component" "DisabledMessage")
    [ Vdom.Node.text content ]
;;

(* One segment. [tabindex] is the selection-follows-focus contract the roving hook reads: 0 on the
   selected segment (or, per upstream's [keepsSelectedFocusable], on the selected one while the whole
   control is disabled with a reason - a disabled segment you can land on by Tab so the reason is
   discoverable, but never by arrow), -1 elsewhere. *)
let segment ~(item : item) ~(is_selected : bool) ~(group_disabled : bool)
  ~(keeps_selected_focusable : bool) ~(size : size) ~(layout : [ `Hug | `Fill ])
  ~(on_change : string -> unit Bonsai.Effect.t) : Vdom.Node.t =
  let is_item_disabled = group_disabled || item.is_disabled in
  let tabindex =
    if (is_selected && not is_item_disabled) || (keeps_selected_focusable && is_selected)
    then 0
    else -1
  in
  let class_ =
    Common.Attr.class_
      ([ "astryx-segmented-control__item" ]
       @ (match layout with
         | `Hug -> []
         | `Fill -> [ "astryx-segmented-control__item--fill" ])
       @ [ "astryx-segmented-control__item--" ^ size_class size ]
       @ (if is_selected then [ "astryx-segmented-control__item--selected" ] else [])
       @ (if is_item_disabled then [ "astryx-segmented-control__item--disabled" ] else [])
       @ (if item.is_label_hidden then [ "astryx-segmented-control__item--icon-only" ] else []))
  in
  let role = [ Vdom.Attr.create "role" "radio" ] in
  let checked = [ Vdom.Attr.create "aria-checked" (Bool.to_string is_selected) ] in
  let aria_disabled = if is_item_disabled then [ Vdom.Attr.create "aria-disabled" "true" ] else [] in
  let aria_label =
    if item.is_label_hidden then [ Vdom.Attr.create "aria-label" item.label ] else []
  in
  let on_click =
    if is_item_disabled || is_selected
    then Vdom.Attr.on_click (fun _ -> Bonsai.Effect.Ignore)
    else Vdom.Attr.on_click (fun _ -> on_change item.value)
  in
  let content =
    (match item.icon with
     | Some icon ->
       [ Vdom.Node.span
           ~attrs:
             (Common.Attr.class_ [ "astryx-segmented-control__item-icon" ]
              @ [ Vdom.Attr.create "aria-hidden" "true" ])
           [ icon ] ]
     | None -> [])
    @ (if item.is_label_hidden
       then []
       else [ Vdom.Node.div
                ~attrs:(Common.Attr.class_ [ "astryx-segmented-control__item-label" ])
                [ Vdom.Node.text item.label ] ])
  in
  Vdom.Node.button
    ~attrs:
      (class_
       @ role
       @ checked
       @ aria_disabled
       @ aria_label
       @ [ Vdom.Attr.create "type" "button"
         ; Vdom.Attr.create "tabindex" (Int.to_string tabindex)
         ; Vdom.Attr.create "data-astryx-value" item.value
         ]
       @ [ on_click ])
    content
;;

let view
  ?(attrs = [])
  ?(id = "astryx-segmented-control")
  ?(size = Md)
  ?(layout = `Hug)
  ?(is_disabled = false)
  ?disabled_message
  ~label
  ~value
  ~on_change
  ~items
  _graph
  =
  Bonsai.map2 on_change value ~f:(fun on_change value ->
      let keeps_selected_focusable = is_disabled && Option.is_some disabled_message in
      let disabled_message_id = id ^ "-disabled-message" in
      let control_attrs =
        Common.Attr.class_
          ([ "astryx-segmented-control"
           ; "astryx-segmented-control--" ^ size_class size
           ]
           @ (match layout with
             | `Hug -> []
             | `Fill -> [ "astryx-segmented-control--fill" ])
           @ (if is_disabled then [ "astryx-segmented-control--disabled" ] else [])
           @ (if is_disabled && Option.is_some disabled_message
              then [ "astryx-segmented-control--disabled-with-message" ]
              else []))
        @ Common.Attr.data "component" "SegmentedControl"
        @ Common.Attr.data "value" value
        @ [ Vdom.Attr.create "role" "radiogroup"
          ; Vdom.Attr.create "aria-label" label
          ; Vdom.Attr.create "id" id
          ]
        @ (if is_disabled then [ Vdom.Attr.create "aria-disabled" "true" ] else [])
        @ (if Option.is_some disabled_message
           then
             [ Vdom.Attr.create "aria-describedby" disabled_message_id ]
           else [])
        @ [ Vdom.Attr.on_focusin (fun ev ->
                match focused_value ev with
                | None -> Bonsai.Effect.Ignore
                | Some candidate when is_disabled || String.equal candidate value ->
                  Bonsai.Effect.Ignore
                | Some candidate -> on_change candidate)
          ]
        @ [ Common.List_focus.attr
              ~orientation:Common.List_focus.Horizontal
              ~item_selector:"[role=\"radio\"]:not([aria-disabled=\"true\"])"
              ~boundary_selector:"[role=\"radiogroup\"]"
              ~prefer_existing_stop:true
              ()
          ]
        @ attrs
      in
      let segments =
        List.map items ~f:(fun item ->
            segment
              ~item
              ~is_selected:(String.equal item.value value)
              ~group_disabled:is_disabled
              ~keeps_selected_focusable
              ~size
              ~layout
              ~on_change)
      in
      let message =
        match disabled_message with
        | Some content when is_disabled -> [ message_bubble ~id:disabled_message_id ~content ]
        | Some _ | None -> []
      in
      let control = Vdom.Node.div ~attrs:control_attrs segments in
      (* The reason bubble is a sibling of the track, not a child: the track is a flex row and a
         bubble inside it would ride beside the last segment. The wrapper is a plain block that
         presents the same two nodes the way a Field does for the other controls. *)
      Vdom.Node.div
        ~attrs:(Common.Attr.class_ [ "astryx-segmented-control-wrap" ])
        (control :: message))
;;
