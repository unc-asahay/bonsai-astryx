(* Copyright (c) Meta Platforms, Inc. and affiliates.
   Ported to OCaml/Bonsai from the astryx ComplexSelector component.

   The design facts, in the order they shaped this file:

   1. The trigger is OURS — the component builds the field, the control box, the
      button, the spinner and the chevron. Unlike {!Popover}, nothing is opaque,
      so there is no need for the layer-trigger hook that *finds* a button:
      the ARIA and the handlers go on the button we build (the same arrangement
      DropdownMenu reached for the same reason).
   2. The surface is the native popover mechanism, exactly as Popover uses it —
      the same [popover="auto"] attribute, the same Layer_hook, the same CSS
      anchor positioning. It is not composed *through* Popover, because that
      composition would inherit Popover's marker, its close button and its
      content class.
   3. The content is a render function, not a value: the application builds the
      selection surface from [value], [commit], [close] and [state] at render
      time. In Bonsai that is a plain function called from inside this
      component's own map, so it cannot own state — the mli says so.
*)

(* This library's own Field, bound before the opens below. Core defines a module named Field as
   well (first-class fields), so after [open! Core] the unqualified name refers to Core's — and
   this module would silently fail to compile against it. Outside the library there is no
   ambiguity: the module is Astryx.Field. Same arrangement text_input.ml makes. *)
module Field_ = Field

open! Core
open! Bonsai_web
open Js_of_ocaml

module Attr = Common.Attr

type variant =
  | Input
  | Secondary
  | Ghost
;;

type size = Input_types.size =
  | Sm
  | Md
  | Lg
;;

type status = Input_types.status =
  { type_ : Field_status.type_
  ; message : string option
  }
;;

type placement = Popover.placement =
  | Below
  | Above
  | Start
  | End
;;

type alignment = Popover.alignment =
  | Align_start
  | Align_center
  | Align_end
;;

type render_state =
  { is_open : bool
  ; is_busy : bool
  ; trigger_id : string
  ; content_id : string
  }
;;

(* ------------------------------------------------------------- DOM helpers *)

type el = Dom_html.element Js.t

let by_id (id : string) : el option =
  Js.Opt.to_option
    (Js.Unsafe.meth_call
       Dom_html.document
       "getElementById"
       [| Js.Unsafe.inject (Js.string id) |]
      : el Js.opt)
;;

let focus_el (el : el) =
  ignore
    (Js.Unsafe.meth_call
       el
       "focus"
       [| Js.Unsafe.inject (Js.Unsafe.obj [| "preventScroll", Js.Unsafe.inject Js._true |]) |])
;;

let el_prop (obj : 'a Js.t) (name : string) : el option =
  Js.Opt.to_option (Common.prop obj name : el Js.opt)
;;

let contains ~(ancestor : el) (node : el) : bool =
  Js.to_bool (Js.Unsafe.meth_call ancestor "contains" [| Js.Unsafe.inject node |])
;;

let key_of (ev : Dom_html.keyboardEvent Js.t) : string =
  Option.value (Common.string_prop ev "key") ~default:""
;;

let focusable_selector =
  "button, [href], input, select, textarea, [tabindex]:not([tabindex=\"-1\"])"
;;

(* ------------------------------------------------------------- class names *)

let variant_class = function
  | Input -> None
  | Secondary -> Some "astryx-complex-selector--secondary"
  | Ghost -> Some "astryx-complex-selector--ghost"
;;

let status_class (type_ : Input_types.status_type) =
  match type_ with
  | Input_types.Warning -> Some "astryx-complex-selector--warning"
  | Input_types.Error -> Some "astryx-complex-selector--error"
  | Input_types.Success -> Some "astryx-complex-selector--success"
;;

let size_name = function
  | Sm -> "sm"
  | Md -> "md"
  | Lg -> "lg"
;;

let placement_class = function
  | Below -> "astryx-complex-selector__popover--below"
  | Above -> "astryx-complex-selector__popover--above"
  | Start -> "astryx-complex-selector__popover--start"
  | End -> "astryx-complex-selector__popover--end"
;;

let alignment_class = function
  | Align_start -> "astryx-complex-selector__popover--align-start"
  | Align_center -> "astryx-complex-selector__popover--align-center"
  | Align_end -> "astryx-complex-selector__popover--align-end"
;;

(* Upstream applies [layerAnimations[placement]] to the layer unconditionally; the
   house [Entry_animation] presets cover the vertical and fade cases but have no
   horizontal slide, so [Start]/[End] fall back to the fade-in (named in the
   CSS block). *)
let enter_class = function
  | Below -> Entry_animation.class_ Entry_animation.Slide_down
  | Above -> Entry_animation.class_ Entry_animation.Slide_up
  | Start | End -> Entry_animation.class_ Entry_animation.Fade_in
;;

(* ------------------------------------------------------------------- view *)

let view
      ?(attrs = [])
      ?(id = "astryx-complex-selector")
      ?is_open
      ?on_open_change
      ?on_click
      ?on_key_down
      ?(is_label_hidden = false)
      ?description
      ?(is_optional = false)
      ?(is_required = false)
      ?(is_disabled = false)
      ?(is_loading = false)
      ?status
      ?(status_variant = Field_status.Attached)
      ?(size = Md)
      ?(variant = Input)
      ?start_icon
      ?width
      ?(placement = Below)
      ?(alignment = Align_start)
      ?trigger_label
      ?(placeholder = "Choose...")
      ~label
      ~value
      ?on_change
      ~children
      (graph : Bonsai.graph)
  =
  (* Open state and how it is controlled: both given -> the caller owns it; neither ->
     the selector owns its state (upstream's normal case); [on_open_change] alone is
     the observation callback upstream offers. [is_open] alone has no setter to answer
     it, so it is refused rather than silently ignored. Same shape DropdownMenu uses. *)
  let open_state =
    match is_open, on_open_change with
    | Some is_open, Some on_open_change ->
      Bonsai.map2 is_open on_open_change ~f:(fun is_open on_open_change ->
        (is_open, on_open_change, (fun (_ : bool) -> Effect.Ignore)))
    | None, None ->
      let is_open, set_open = Bonsai.state false graph in
      Bonsai.map2 is_open set_open ~f:(fun is_open set_open ->
        (is_open, set_open, (fun (_ : bool) -> Effect.Ignore)))
    | None, Some on_open_change ->
      let is_open, set_open = Bonsai.state false graph in
      Bonsai.map2 is_open (Bonsai.map2 set_open on_open_change ~f:(fun a b -> a, b))
        ~f:(fun is_open (set_open, observe) -> (is_open, set_open, observe))
    | Some _, None ->
      raise_s
        (Sexp.Atom
           "Complex_selector.view: is_open without on_open_change - the pair controls the \
            selector together, or the selector owns its state (pass on_open_change alone to \
            observe)")
  in
  let trigger_id = id in
  let content_id = id ^ "-content" in
  let label_id = id ^ "-label" in
  let description_id = id ^ "-desc" in
  let message_id = id ^ "-status" in
  let is_busy = is_loading in
  (* The trigger label is a computation: upstream builds triggerContent from the
     caller's state in render, and a Bonsai caller derives it the same way. A
     plain string here would be frozen at first render. *)
  let trigger_label_ =
    Option.value_map trigger_label
      ~default:(Bonsai.return None)
      ~f:(fun t -> Bonsai.map t ~f:Option.some)
  in
  let effective_status_variant =
    if (not (Poly.equal variant Input)) && Poly.equal status_variant Field_status.Attached
    then Field_status.Detached
    else status_variant
  in
  let value_state =
    Bonsai.map3
      value
      (Option.value on_change ~default:(Bonsai.return (fun (_ : 'v) -> Effect.Many [])))
      trigger_label_
      ~f:(fun value on_change trigger_label_opt -> (value, on_change, trigger_label_opt))
  in
  Bonsai.map2 open_state value_state
    ~f:(fun (is_open, set_open, observe) (value, on_change, trigger_label_opt) ->
    (* Opening moves focus into the popup's first focusable control (or the surface
       itself — it is tabindex=-1 for exactly that), one frame late: the surface is
       display:none until the layer mechanism shows it, and both hooks run right
       after the same DOM patch in unspecified order. Same reason as Popover's. *)
    let focus_content () =
      Menu_focus.focus_on_next_frame (fun () ->
        match by_id content_id with
        | None -> ()
        | Some content ->
          let target =
            Option.first_some
              (Js.Opt.to_option
                 (Js.Unsafe.meth_call
                    content
                    "querySelector"
                    [| Js.Unsafe.inject (Js.string focusable_selector) |]
                   : el Js.opt))
              (Some content)
          in
          Option.iter target ~f:focus_el)
    in
    let open_effect =
      Effect.Many
        [ set_open true; observe true; Effect.of_thunk focus_content ]
    in
    let close_effect = Effect.Many [ set_open false; observe false ] in
    (* The platform took the surface down (Escape, outside pointer). Upstream restores
       focus to the trigger on every hide, and so does this port: the trigger is the
       anchor of the whole widget. *)
    let platform_close_effect =
      Effect.Many
        [ set_open false
        ; observe false
        ; Effect.of_thunk (fun () ->
            Menu_focus.focus_on_next_frame (fun () ->
              Option.iter (by_id trigger_id) ~f:focus_el))
        ]
    in
    let commit_value (next : 'v) = on_change next in
    let close () = close_effect in
    (* The trigger click: a caller's onClick runs first and may call preventDefault to
       keep the popup closed — upstream's composeEventHandlers contract. Only when a
       caller actually provided one is defaultPrevented read (the jsdom harness cannot
       fabricate that field). *)
    let trigger_click (ev : Dom_html.mouseEvent Js.t) =
      let toggle =
        if is_disabled then Effect.Ignore else if is_open then close_effect else open_effect
      in
      match on_click with
      | None -> toggle
      | Some on_click ->
        let caller = on_click ev in
        if Common.bool_prop ev "defaultPrevented"
        then caller
        else Effect.Many [ caller; toggle ]
    in
    (* ArrowDown opens, as upstream's own button does; the caller's onKeyDown sees every
       key afterwards. *)
    let trigger_keydown (ev : Dom_html.keyboardEvent Js.t) =
      let ours =
        if is_disabled
        then Effect.Ignore
        else if String.equal (key_of ev) "ArrowDown" && not is_open
        then (
          Common.prevent_default ev;
          open_effect)
        else Effect.Ignore
      in
      match on_key_down with
      | Some on_key_down -> Effect.Many [ ours; on_key_down ev ]
      | None -> ours
    in
    (* A press on the box but not on the button routes through the trigger, so the
       caller's onClick sees it too (upstream's handleControlBoxClick). The button is
       found by id: it is the control the label points at, so the id is known. *)
    let control_box_click (ev : Dom_html.mouseEvent Js.t) =
      match by_id trigger_id with
      | None -> Effect.Ignore
      | Some button ->
        (match el_prop ev "target" with
         | Some target when contains ~ancestor:button target -> Effect.Ignore
         | _ ->
           Effect.of_thunk (fun () ->
             ignore (Js.Unsafe.meth_call button "click" [||])))
    in
    let described_by =
      List.filter_opt
        [ (if Option.is_some description then Some description_id else None)
        ; (match status with
           | Some { Input_types.type_ = _; message = Some _ } -> Some message_id
           | _ -> None)
        ]
      |> String.concat ~sep:" "
    in
    let described_by_attr =
      if String.is_empty described_by
      then []
      else [ Vdom.Attr.create "aria-describedby" described_by ]
    in
    (* The rule is Field's, and upstream's after it: is_optional wins over is_required
       when both are given, and required is only ever aria-required — never the native
       attribute, which would turn on the browser's own validation. *)
    let is_effectively_required = is_required && not is_optional in
    let button_attrs =
      [ Vdom.Attr.id trigger_id
      ; Vdom.Attr.create "type" "button"
      ; Vdom.Attr.create "aria-haspopup" "dialog"
      ; Vdom.Attr.create "aria-expanded" (Bool.to_string is_open)
      ; Vdom.Attr.create "aria-controls" content_id
      ; Vdom.Attr.create "aria-labelledby" label_id
      ]
      @ (if is_effectively_required then [ Vdom.Attr.create "aria-required" "true" ] else [])
      @ (match status with
         | Some { Input_types.type_ = Error; _ } -> [ Vdom.Attr.create "aria-invalid" "true" ]
         | _ -> [])
      @ (if is_busy then [ Vdom.Attr.create "aria-busy" "true" ] else [])
      @ described_by_attr
      @ (if is_disabled then [ Vdom.Attr.create "disabled" "disabled" ] else [])
      @ [ Vdom.Attr.on_click trigger_click; Vdom.Attr.on_keydown trigger_keydown ]
    in
    let trigger_label_span =
      Vdom.Node.span
        ~attrs:
          (Attr.class_
             ([ "astryx-complex-selector__trigger-text" ]
              @ (if Option.is_none trigger_label_opt
                 then [ "astryx-complex-selector__placeholder" ]
                 else [])))
        [ Vdom.Node.text (Option.value trigger_label_opt ~default:placeholder) ]
    in
    let control_box_attrs =
      Attr.class_
        (List.filter_opt
           ([ Some "astryx-complex-selector"
            ; variant_class variant
            ; Option.bind status ~f:(fun { Input_types.type_; _ } -> status_class type_)
            ; (if is_disabled then Some "astryx-complex-selector--disabled" else None)
            ; (if Option.is_none trigger_label_opt
               then Some "astryx-complex-selector--placeholder"
               else None)
            ]))
      @ Attr.data "component" "ComplexSelector"
      @ [ Vdom.Attr.create "data-astryx-size" (size_name size) ]
      @ [ Vdom.Attr.on_click control_box_click ]
      @ attrs
    in
    let control_box =
      let children_nodes =
        (match start_icon with
         | Some name ->
           [ Vdom.Node.span
               ~attrs:(Attr.class_ [ "astryx-complex-selector__start-icon" ])
               [ Icon.view ~name ~size:Icon.Sm ~color:Icon.Secondary () ]
           ]
         | None -> [])
        @ [ Vdom.Node.button ~attrs:button_attrs [ trigger_label_span ] ]
        @ (if is_busy
           then
             [ Vdom.Node.span
                 ~attrs:(Attr.class_ [ "astryx-complex-selector__spinner" ])
                 [ Spinner.view ~size:Spinner.Sm () ]
             ]
           else [])
        @ [ Icon.view
              ~name:"chevronDown"
              ~size:Icon.Sm
              ~color:Icon.Secondary
              ~attrs:
                (Attr.class_
                   ([ "astryx-complex-selector__indicator" ]
                    @ (if is_open
                       then [ "astryx-complex-selector__indicator--open" ]
                       else [])))
              ()
          ]
      in
      Vdom.Node.div ~attrs:control_box_attrs children_nodes
    in
    let popup =
      let content =
        children value commit_value close { is_open; is_busy; trigger_id; content_id }
      in
      Vdom.Node.div
        ~attrs:
          ([ Vdom.Attr.create "id" content_id
           ; Vdom.Attr.create "popover" "auto"
           ; Vdom.Attr.create "role" "dialog"
           ; Vdom.Attr.create "aria-modal" "true"
           ; Vdom.Attr.create "aria-label" label
           ; Vdom.Attr.create "tabindex" "-1"
           ]
           @ Attr.class_
               ([ "astryx-complex-selector__popover"
                ; placement_class placement
                ; alignment_class alignment
                ; enter_class placement
                ])
           @ [ Common.Layer_hook.attr ~is_open ~on_platform_close:platform_close_effect ])
        [ Vdom.Node.div ~attrs:(Attr.class_ [ "astryx-complex-selector__content" ]) content ]
    in
    Field_.view
      ~is_label_hidden
      ?description
      ~is_optional
      ~is_required
      ~is_disabled
      ?status
      ~status_variant:effective_status_variant
      ?width
      ~label
      ~input_id:trigger_id
      ~label_id
      ~children:[ control_box; popup ]
      ())
;;
