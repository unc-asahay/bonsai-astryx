(* This library's own Field, bound before the opens below. Core defines a module named Field as
   well (first-class fields), so after [open! Core] the unqualified name refers to Core's — and
   this module would silently fail to compile against it. Outside the library there is no
   ambiguity: the module is Astryx.Field. *)
module Field_ = Field

open! Core
open! Bonsai_web
open Js_of_ocaml

module Attr = Common.Attr

type type_ =
  | Text
  | Password
  | Email

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

let type_string = function
  | Text -> "text"
  | Password -> "password"
  | Email -> "email"
;;

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

(* Upstream's isImeKeyEvent: a keydown that is part of an IME conversion carries isComposing or
   the legacy 229 keyCode. Pressing Enter to commit a conversion must not also fire on_enter. *)
let is_ime_key_event (ev : Dom_html.keyboardEvent Js.t) =
  Js.to_bool
    (Js.Unsafe.fun_call
       (Js.Unsafe.pure_js_expr
          "(function(ev){return ev.isComposing === true || ev.keyCode === 229;})")
       [| Js.Unsafe.inject ev |])
;;

let enter_attr ~on_enter =
  [ Vdom.Attr.on_keydown (fun (ev : Dom_html.keyboardEvent Js.t) ->
      let key = Js.to_string (Js.Unsafe.get ev "key") in
      if String.equal key "Enter" && not (is_ime_key_event ev) then on_enter else Effect.Many [])
  ]
;;

let view
      ?(type_ = Text)
      ?description
      ?(is_label_hidden = false)
      ?(is_optional = false)
      ?(is_required = false)
      ?optionality
      ?(is_disabled = false)
      ?(is_read_only = false)
      ?placeholder
      ?start_icon
      ?status
      ?(status_variant = Attached)
      ?(size = Md)
      ?width
      ?html_name
      ?auto_complete
      ?on_enter
      ?(attrs = [])
      ~label
      ~id
      ~value
      ~on_change
      ()
  =
  (* Both callbacks are values in the graph, so the node is assembled from the unwrapped
     value, the unwrapped change handler and the unwrapped enter effect. *)
  Bonsai.map2
    (Bonsai.both value on_change)
    (Option.value on_enter ~default:(Bonsai.return (Effect.Many [])))
    ~f:(fun (value, on_change) on_enter ->
      let description_id = id ^ "-desc" in
      let message_id = id ^ "-status" in
      (* Only the text that is really rendered is referenced: a dangling aria-describedby is
         announced as nothing at best, and some screen readers read the id itself at worst. *)
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
      (* Upstream's useResolvedRequired: an explicit isOptional wins, and otherwise the field is
         required if it says so *or* the form's default says so. A layout default never sets the
         native [required] attribute — only [aria-required] — so it cannot turn on the browser's own
         validation. *)
      let effectively_required =
        (not is_optional)
        && (is_required
            || match optionality with
               | Some Common.Optionality.Required -> true
               | _ -> false)
      in
      let input_attrs =
        [ Vdom.Attr.create "id" id ]
        @ [ Vdom.Attr.create "type" (type_string type_) ]
        @ [ Vdom.Attr.create "value" value ]
        (* A disabled input does not submit, so it carries no name — same as upstream. *)
        @ (match html_name with
           | Some name when not is_disabled -> [ Vdom.Attr.create "name" name ]
           | _ -> [])
        @ (match placeholder with
           | Some text -> [ Vdom.Attr.create "placeholder" text ]
           | None -> [])
        @ (match auto_complete with
           | Some text -> [ Vdom.Attr.create "autocomplete" text ]
           | None -> [])
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
              (* The DOM already refuses keystrokes into a disabled or read-only input; the guard
                 is here so a programmatic event cannot change a value the caller forbade. *)
              if is_disabled || is_read_only then Effect.Many [] else on_change value)
          ]
        @ enter_attr ~on_enter
        @ Attr.class_ [ "astryx-text-input__input" ]
      in
      let wrapper_attrs =
        Attr.class_
          ([ "astryx-text-input" ]
           @ (if is_disabled then [ "astryx-text-input--disabled" ] else [])
           @ (match status with
            | Some { Input_types.type_; message = _ } ->
              [ "astryx-text-input--" ^ status_string type_ ]
              | None -> []))
        @ Attr.data "component" "TextInput"
        @ Attr.data "size" (size_string size)
        @ (match status with
         | Some { Input_types.type_; message = _ } -> Attr.data "status" (status_string type_)
           | None -> [])
        @ (if is_disabled then Attr.data "disabled" "true" else [])
        @ (if is_read_only then Attr.data "readonly" "true" else [])
        @ attrs
      in
      let start_icon =
        match start_icon with
        | None -> []
        | Some name ->
          [ Vdom.Node.span
              ~attrs:(Attr.class_ [ "astryx-text-input__start-icon" ])
              [ Icon.view ~name ~size:Icon.Sm ~color:Icon.Secondary () ]
          ]
      in
      Field_.view
      ?optionality
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
              (start_icon @ [ Vdom.Node.input ~attrs:input_attrs () ])
          ]
      ())
;;
