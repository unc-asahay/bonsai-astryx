(* This library's own Field, bound before the opens below: Core defines a module named Field as well
   (first-class fields), so after [open! Core] the unqualified name refers to Core's. Outside the
   library there is no ambiguity — the module is Astryx.Field. *)
module Field_ = Field

open! Core
open! Bonsai_web

module Attr = Common.Attr

open Js_of_ocaml

type item =
  { value : string
  ; label : string
  ; description : string option
  ; is_disabled : bool
  ; is_loading : bool
  ; end_content : Vdom.Node.t option
  }

let item_id id index = id ^ "-item-" ^ Int.to_string index
let item_checkbox_id id index = item_id id index ^ "-checkbox"
let item_description_id id index = item_id id index ^ "-description"

(* The row's click delegation needs the same small DOM set Item uses; the functions are kept local
   until a second consumer appears, per the port's rule for mechanisms. *)
let el_of (ev : 'a Js.t) : Dom_html.element Js.t option =
  match Js.Opt.to_option (Common.prop ev "currentTarget" : Dom_html.element Js.t Js.opt) with
  | Some el -> Some el
  | None -> None
;;

let target_of (ev : 'a Js.t) : Dom_html.element Js.t option =
  match Js.Opt.to_option (Common.prop ev "target" : Dom_html.element Js.t Js.opt) with
  | Some el -> Some el
  | None -> None
;;

let query_selector (el : Dom_html.element Js.t) (selector : string) : Dom_html.element Js.t option =
  Js.Opt.to_option
    (Js.Unsafe.meth_call el "querySelector" [| Js.Unsafe.inject (Js.string selector) |])
;;

let native_click (el : Dom_html.element Js.t) : unit =
  try Js.Unsafe.meth_call el "click" [||] with _ -> ()
;;

let stop_propagation (ev : 'a Js.t) : unit =
  try Js.Unsafe.meth_call ev "stopPropagation" [||] with _ -> ()
;;

let density_data : List_container.density -> string = function
  | List_container.Compact -> "compact"
  | List_container.Balanced -> "balanced"
  | List_container.Spacious -> "spacious"
;;

let checkbox_size : List_container.density -> Indicator.size = function
  | List_container.Compact -> Indicator.Sm
  | List_container.Balanced | List_container.Spacious -> Indicator.Md
;;

let view
      ?(attrs = [])
      ?(is_disabled = false)
      ?disabled_message
      ?(is_read_only = false)
      ?(is_label_hidden = false)
      ?(is_optional = false)
      ?(is_required = false)
      ?optionality
      ?label_icon
      ?description
      ?status
      ?width
      ?(density = List_container.Balanced)
      ?(has_dividers = false)
      ~label
      ~id
      ~items
      ~value
      ~on_change
      ()
  =
  Bonsai.map2 value on_change ~f:(fun value on_change ->
    let label_id = id ^ "-label" in
    let status_message =
      match status with
      | Some { Input_types.message = Some message; _ } -> Some message
      | Some { message = None; _ } | None -> None
    in
    let status_type =
      match status with
      | Some { Input_types.type_ = type_; _ } -> Some type_
      | None -> None
    in
    (* Field renders the description and the status outside the group element, keyed off the control
       id (id ^ "-desc" / id ^ "-status"), so the group has to link them itself. *)
    let field_description_id = id ^ "-desc" in
    let field_status_id = id ^ "-status" in
    let reason_id = id ^ "-disabled-message" in
    let described_by =
      List.filter_opt
        [ (if Option.is_some description then Some field_description_id else None)
        ; (if Option.is_some status_message then Some field_status_id else None)
        ; (if Option.is_some disabled_message then Some reason_id else None)
        ]
      |> String.concat ~sep:" "
    in
    let item_node index (item : item) =
      let row_id = item_id id index in
      let checkbox_id = item_checkbox_id id index in
      let description_id = item_description_id id index in
      let is_checked = List.exists value ~f:(fun v -> String.equal v item.value) in
      let is_item_disabled = is_disabled || item.is_disabled in
      let focusable_disabled = is_disabled && Option.is_some disabled_message in
      let on_toggle (state : Checkbox_input.value) =
        match state with
        | Checked ->
          on_change
            (if is_checked then value else value @ [ item.value ])
        | Unchecked ->
          on_change (List.filter value ~f:(fun v -> not (String.equal v item.value)))
        | Indeterminate -> Effect.Many []
      in
      (* The checkbox is the row's single keyboard control, so it carries the row's label as a
         hidden label; the visible label below is plain text (a second [<label for>] would name the
         checkbox twice), and a row-surface click proxies to the input — upstream's
         useClickableContainer. *)
      let checkbox =
        Checkbox_input.render
          ~label:item.label
          ~id:checkbox_id
          ~is_label_hidden:true
          ~value:(if is_checked then Checkbox_input.Checked else Checkbox_input.Unchecked)
          ~on_change:on_toggle
          ~is_disabled:is_item_disabled
          ~is_focusable_disabled:focusable_disabled
          ~is_read_only
          ~is_loading:item.is_loading
          ?described_by:(match item.description with Some _ -> Some description_id | None -> None)
          ~size:(checkbox_size density)
          ()
      in
      let row_surface_click ev =
        match (el_of ev, target_of ev) with
        | Some row, Some target ->
          (* Clicks on the row's surface (its padding, its label text, its description) are clicks
             on the checkbox. Everything the checkbox itself refuses — native-disabled, focusable-
             disabled, read-only, loading — is refused inside the input's own handler, so a
             delegated click only ever does what a direct click would have done. *)
          if Common.Clickable_container.has_text_selection row
          then Effect.Many []
          else if Common.Clickable_container.is_interactive_target ~root:row ~target
          then Effect.Many []
          else (
            (match query_selector row "input" with
             | Some input ->
               native_click input;
               stop_propagation ev
             | None -> ());
            Effect.Many [])
        | _ -> Effect.Many []
      in
      let label_node =
        Vdom.Node.span
          ~attrs:(Attr.class_ [ "astryx-checkbox-list__label" ])
          [ Vdom.Node.text item.label ]
      in
      let description_node =
        match item.description with
        | None -> []
        | Some text ->
          [ Vdom.Node.div
              ~attrs:
                (Attr.class_ [ "astryx-checkbox-list__description" ]
                 @ [ Vdom.Attr.create "id" description_id ])
              [ Vdom.Node.text text ]
          ]
      in
      let end_node =
        match item.end_content with Some node -> [ node ] | None -> []
      in
      Vdom.Node.li
        ~attrs:
          (Attr.class_
             ([ "astryx-checkbox-list__item" ]
              @ (if is_item_disabled then [ "astryx-checkbox-list__item--disabled" ] else [])
              @ (if is_checked && not is_item_disabled && not is_read_only
                 then [ "astryx-checkbox-list__item--selected" ]
                 else []))
           @ [ Vdom.Attr.create "id" row_id ]
           @ (if item.is_loading then Attr.aria "busy" "true" else [])
           @ [ Vdom.Attr.on_click row_surface_click ])
        [ checkbox
        ; Vdom.Node.div
            ~attrs:(Attr.class_ [ "astryx-checkbox-list__body" ])
            (label_node :: description_node)
        ; (match end_node with
           | [] -> Vdom.Node.none
           | _ ->
             Vdom.Node.div
               ~attrs:(Attr.class_ [ "astryx-checkbox-list__end" ])
               end_node)
        ]
    in
    let list =
      Vdom.Node.ul
        ~attrs:
          (Attr.class_ [ "astryx-checkbox-list__list" ]
           @ [ Vdom.Attr.create "role" "list" ]
           @ Attr.data "density" (density_data density)
           @ Attr.data "dividers" (Bool.to_string has_dividers)
           @ (if has_dividers
              then Attr.class_ [ "astryx-checkbox-list__list--dividers" ]
              else []))
        (List.mapi items ~f:item_node)
    in
    let reason_node =
      match (is_disabled, disabled_message) with
      | true, Some message ->
        [ Vdom.Node.div
            ~attrs:
              (Attr.class_ [ "astryx-disabled-message" ]
               @ [ Vdom.Attr.create "id" reason_id
                 ; Vdom.Attr.create "role" "tooltip"
                 ])
            [ Vdom.Node.text message ]
        ]
      | _ -> []
    in
    let group =
      Vdom.Node.div
        ~attrs:
          (Attr.class_
             ([ "astryx-checkbox-list__group" ]
              @ (if is_disabled then [ "astryx-checkbox-list__group--disabled" ] else []))
           @ [ (* The group is this field's control, so it carries the id the label would point at
                  (and which the row ids are derived from). *)
               Vdom.Attr.create "id" id
             ; Vdom.Attr.create "role" "group"
             ]
           @ Attr.data "component" "CheckboxList"
           (* The group names itself from the label Field rendered — which is why the label is a
              group label rather than a [<label for>] pointing at one checkbox. *)
           @ Attr.aria "labelledby" label_id
           @ (match status_type with
              | Some Input_types.Error -> Attr.aria "invalid" "true"
              | Some (_ : Input_types.status_type) | None -> [])
           @ (if is_required || (match optionality with Some Common.Optionality.Required -> true | _ -> false)
              then Attr.aria "required" "true"
              else [])
           @ (if String.is_empty described_by then [] else Attr.aria "describedby" described_by))
        (list :: reason_node)
    in
    Field_.view
      ?optionality
      ~label
      ~input_id:id
      ~label_id
      ~is_group_label:true
      ~is_label_hidden
      ~is_disabled
      ~is_optional
      ~is_required
      ?label_icon
      ?description
      ?status
      ~status_variant:Field_status.Detached
      ?width
      ~attrs
      ~children:[ group ]
      ())
;;
