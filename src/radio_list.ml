(* This library's own Field, bound before the opens below: Core defines a module named Field as well
   (first-class fields), so after [open! Core] the unqualified name refers to Core's. Outside the
   library there is no ambiguity — the module is Astryx.Field. *)
module Field_ = Field

open! Core
open! Bonsai_web

module Attr = Common.Attr

type item =
  { value : string
  ; label : string
  ; description : string option
  ; is_disabled : bool
  }
[@@deriving sexp_of]

type orientation =
  | Vertical
  | Horizontal

let item_id id index = id ^ "-item-" ^ Int.to_string index
let item_description_id id index = item_id id index ^ "-description"

let view
      ?(attrs = [])
      ?(is_disabled = false)
      ?(is_label_hidden = false)
      ?(is_optional = false)
      ?(is_required = false)
      ?optionality
      ?label_icon
      ?description
      ?status
      ?(size = Indicator.Md)
      ?(orientation = Vertical)
      ~label
      ~id
      ~items
      ~value
      ~on_change
      ()
  =
  Bonsai.both value on_change
  |> Bonsai.map ~f:(fun (selected, on_change) ->
    let label_id = id ^ "-label" in
    let group_name = id ^ "-group" in
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
    (* Field renders the description and the status *outside* the group element, keyed off the
       control id (id ^ "-desc" / id ^ "-status"), so the group has to link them itself — otherwise a
       screen reader reading the radiogroup never reaches either. *)
    let field_description_id = id ^ "-desc" in
    let field_status_id = id ^ "-status" in
    let described_by =
      List.filter_opt
        [ (if Option.is_some description then Some field_description_id else None)
        ; (if Option.is_some status_message then Some field_status_id else None)
        ]
      |> String.concat ~sep:" "
    in
    let item_node index (item : item) =
      let item_id = item_id id index in
      let is_selected = String.equal item.value selected in
      let is_item_disabled = is_disabled || item.is_disabled in
      let item_description_id = item_description_id id index in
      let input_attrs =
        Attr.class_ [ "astryx-radio-list__input" ]
        @ [ Vdom.Attr.create "type" "radio"
          ; Vdom.Attr.create "id" item_id
          ; (* The name is what makes the radios one group: a native group gets roving focus, the
               arrow keys, and the browser's own "restore the last selection" behaviour for free. *)
            Vdom.Attr.create "name" group_name
          ; Vdom.Attr.create "value" item.value
          ; Vdom.Attr.checked_prop is_selected
          ]
        @ (if is_item_disabled then [ Vdom.Attr.create "disabled" "disabled" ] else [])
        @ (if is_required then [ Vdom.Attr.create "required" "required" ] else [])
        @ (match item.description with
           | Some _ -> Attr.aria "describedby" item_description_id
           | None -> [])
        @ [ Vdom.Attr.on_click (fun _ ->
              (* A radio click on the already-selected item changes nothing, and a native change
                 event would not fire either — reporting it would invite the application to re-run an
                 action the user did not ask for. *)
              if is_item_disabled || is_selected
              then Effect.Many []
              else on_change item.value)
          ]
      in
      let control =
        Vdom.Node.div
          ~attrs:(Attr.class_ [ "astryx-radio-list__control" ])
          [ Vdom.Node.input ~attrs:input_attrs ()
          ; Indicator.view
              ~kind:Indicator.Radio
              ~state:(if is_selected then Indicator.Checked else Indicator.Unchecked)
              ~size
              ~is_disabled:is_item_disabled
              ()
          ]
      in
      let label_node =
        Vdom.Node.label
          ~attrs:
            (Attr.class_ [ "astryx-radio-list__label" ]
             @ [ Vdom.Attr.create "for" item_id ])
          [ Vdom.Node.text item.label ]
      in
      let description_node =
        match item.description with
        | None -> []
        | Some text ->
          [ Vdom.Node.div
              ~attrs:
                (Attr.class_ [ "astryx-radio-list__description" ]
                 @ [ Vdom.Attr.create "id" item_description_id ])
              [ Vdom.Node.text text ]
          ]
      in
      Vdom.Node.div
        ~attrs:
          (Attr.class_
             ([ "astryx-radio-list__item" ]
              @ (if is_item_disabled then [ "astryx-radio-list__item--disabled" ] else [])
              @ (if is_item_disabled then [] else [ "astryx-indicator-scope" ])))
        [ control
        ; Vdom.Node.div
            ~attrs:(Attr.class_ [ "astryx-radio-list__label-wrapper" ])
            (label_node :: description_node)
        ]
    in
    let group =
      Vdom.Node.div
        ~attrs:
          (Attr.class_
             ([ "astryx-radio-list__group"
              ; (match orientation with
                 | Vertical -> "astryx-radio-list__group--vertical"
                 | Horizontal -> "astryx-radio-list__group--horizontal")
              ]
              @ (if is_disabled then [ "astryx-radio-list__group--disabled" ] else []))
           @ [ (* The group is this field's control, so it carries the id the label would point at
                (and which the item ids are derived from). *)
               Vdom.Attr.create "id" id
             ; Vdom.Attr.create "role" "radiogroup"
             ]
           (* data-* is how the parity harness reads an element's intent, so the component states its
              own name. The items below carry their own, which is what gives the contract generator
              something to count. *)
           @ Attr.data "component" "RadioList"
           (* The group names itself from the label Field rendered — which is why the label is a
              group label rather than a <label for> pointing at one radio. *)
           @ Attr.aria "labelledby" label_id
           @ (match status_type with
              | Some Input_types.Error -> Attr.aria "invalid" "true"
              | Some (_ : Input_types.status_type) | None -> [])
           @ (if is_required || (match optionality with Some Common.Optionality.Required -> true | _ -> false)
              then Attr.aria "required" "true"
              else [])
           @ (if String.is_empty described_by then [] else Attr.aria "describedby" described_by))
        (List.mapi items ~f:item_node)
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
      ~attrs
      ~children:[ group ]
      ())
;;
