(* This library's own Field, bound before the opens below. Core defines a module named Field as
   well (first-class fields), so after [open! Core] the unqualified name refers to Core's — and
   this module would silently fail to compile against it. Outside the library there is no
   ambiguity: the module is Astryx.Field. *)
module Field_ = Field

open! Core
open! Bonsai_web

module Attr = Common.Attr

type size = Input_types.size =
  | Sm
  | Md
  | Lg

type status_type = Input_types.status_type =
  | Warning
  | Error
  | Success

type status_variant = Field_status.placement =
  | Attached
  | Detached
  | Tooltip

let size_string = function
  | Sm -> "sm"
  | Md -> "md"
  | Lg -> "lg"
;;

let status_string = function
  | Warning -> "warning"
  | Error -> "error"
  | Success -> "success"
;;

let view
      ?description
      ?(is_label_hidden = false)
      ?(is_optional = false)
      ?(is_required = false)
      ?(is_disabled = false)
      ?(is_read_only = false)
      ?placeholder
      ?status
      ?(status_variant = Attached)
      ?(size = Md)
      ?width
      ?html_name
      ?auto_complete
      ?(rows = 3)
      ?(has_spell_check = true)
      ?(attrs = [])
      ~label
      ~id
      ~value
      ~on_change
      ()
  =
  Bonsai.map2 value on_change ~f:(fun value on_change ->
    let description_id = id ^ "-desc" in
    let message_id = id ^ "-status" in
    (* Only the text that is really rendered is referenced, so a status without a message leaves
       the control with nothing dangling in aria-describedby. *)
    let status_message =
      match status with
      | Some { Input_types.message = Some message; _ } when not (String.is_empty message) ->
        Some message
      | _ -> None
    in
    let described_by =
      List.filter_opt
        [ (if Option.is_some description then Some description_id else None)
        ; Option.map status_message ~f:(fun _ -> message_id)
        ]
      |> String.concat ~sep:" "
    in
    let effectively_required = is_required && not is_optional in
    let input_attrs =
      [ Vdom.Attr.create "id" id ]
      (* A disabled control does not submit, so it carries no name — same as upstream. *)
      @ (match html_name with
         | Some name when not is_disabled -> [ Vdom.Attr.create "name" name ]
         | _ -> [])
      @ (match placeholder with
         | Some text -> [ Vdom.Attr.create "placeholder" text ]
         | None -> [])
      @ (match auto_complete with
         | Some text -> [ Vdom.Attr.create "autocomplete" text ]
         | None -> [])
      @ [ Vdom.Attr.create "rows" (Int.to_string rows) ]
      @ [ Vdom.Attr.create "spellcheck" (if has_spell_check then "true" else "false") ]
      @ (if is_disabled then [ Vdom.Attr.create "disabled" "disabled" ] else [])
      @ (if is_read_only then [ Vdom.Attr.create "readonly" "readonly" ] else [])
      @ (if String.is_empty described_by
         then []
         else [ Vdom.Attr.create "aria-describedby" described_by ])
      @ (if effectively_required then Attr.aria "required" "true" else [])
      @ (match status with
         | Some { Input_types.type_ = Error; message = _ } -> Attr.aria "invalid" "true"
         | _ -> [])
      @ [ Vdom.Attr.on_input (fun _ value ->
            (* The DOM already refuses edits to a disabled or read-only control; the guard is
               here so a programmatic event cannot change a value the caller forbade. *)
            if is_disabled || is_read_only then Effect.Many [] else on_change value)
        ]
      @ Attr.class_ [ "astryx-text-area__input" ]
    in
    let wrapper_attrs =
      Attr.class_
        ([ "astryx-text-area" ]
         @ (if is_disabled then [ "astryx-text-area--disabled" ] else [])
         @ (match status with
            | Some { Input_types.type_; message = _ } ->
              [ "astryx-text-area--" ^ status_string type_ ]
            | None -> []))
      @ Attr.data "component" "TextArea"
      @ Attr.data "size" (size_string size)
      @ Attr.data "rows" (Int.to_string rows)
      @ (match status with
         | Some { Input_types.type_; message = _ } -> Attr.data "status" (status_string type_)
         | None -> [])
      @ (if is_disabled then Attr.data "disabled" "true" else [])
      @ (if is_read_only then Attr.data "readonly" "true" else [])
      @ attrs
    in
    Field_.view
      ~label
      ~input_id:id
      ?description
      ~is_label_hidden
      ~is_optional
      ~is_required
      ~is_disabled
      ?status
      ~status_variant
      ?width
      ~children:
        [ Vdom.Node.div
            ~attrs:wrapper_attrs
            [ Vdom.Node.textarea ~attrs:input_attrs [ Vdom.Node.text value ] ]
        ]
      ())
;;
