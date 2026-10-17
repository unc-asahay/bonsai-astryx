open! Core
open! Bonsai_web
open Js_of_ocaml

type variant =
  | Default
  | Destructive
;;

type item =
  { id : string
  ; label : string
  ; description : string option
  ; end_content : Vdom.Node.t option
  ; icon : string option
  ; variant : variant
  ; is_disabled : bool
  ; href : string option
  ; has_close_on_select : bool option
  }
;;

type entry =
  | Item of item
  | Divider
  | Heading of string
  | Group of
      { heading : string option
      ; items : item list
      }
;;

type el = Dom_html.element Js.t

(* ------------------------------------------------------------------ DOM ---- *)

let by_id (id : string) : el option =
  Js.Opt.to_option
    (Js.Unsafe.meth_call Dom_html.document "getElementById" [| Js.Unsafe.inject (Js.string id) |] : el Js.opt)
;;

let focus_el (el : el) =
  (* preventScroll, for the same reason upstream passes it: a row scrolled under a
     stationary pointer would be re-focused by the next pointer move, for ever. *)
  ignore
    (Js.Unsafe.meth_call
       el
       "focus"
       [| Js.Unsafe.inject (Js.Unsafe.obj [| "preventScroll", Js.Unsafe.inject Js._true |]) |])
;;

(* The generic JS readers now live in Common — Tooltip needs the same key lookup, and a second copy
   is how two components drift apart. Aliased here so the call sites below read unchanged. *)
let prop = Common.prop
let string_prop = Common.string_prop
let bool_prop = Common.bool_prop

(* A click event that carries no [button] field at all is not an unmodified left
   click: upstream reads [event.button !== 0] and [undefined] is not 0, so it does
   nothing. The value is resolved in one JS expression because reading an absent
   field as a number raises, and because the OCaml-side conversions will not accept
   a value that might be undefined. *)
let prop_int_js = "(function (o, n) { return typeof o[n] === 'number' ? o[n] : -1; })"

let int_prop (obj : 'a Js.t) (name : string) : int =
  let number : Js.number_t =
    Js.Unsafe.fun_call
      (Js.Unsafe.pure_js_expr prop_int_js)
      [| Js.Unsafe.inject obj; Js.Unsafe.inject (Js.string name) |]
  in
  int_of_float (Js.to_float number)
;;

let el_prop (obj : 'a Js.t) (name : string) : el option =
  Js.Opt.to_option (prop obj name : el Js.opt)
;;

let prevent_default (obj : 'a Js.t) = ignore (Js.Unsafe.meth_call obj "preventDefault" [||])

let contains ~(ancestor : el) (node : el) : bool =
  Js.to_bool (Js.Unsafe.meth_call ancestor "contains" [| Js.Unsafe.inject node |])
;;

let key_of (ev : Dom_html.keyboardEvent Js.t) : string =
  Option.value (string_prop ev "key") ~default:""
;;

let modifiers (ev : 'a Js.t) = bool_prop ev "metaKey", bool_prop ev "ctrlKey", bool_prop ev "shiftKey", bool_prop ev "altKey"

(* ---------------------------------------------------------------- model ---- *)


(* ------------------------------------------------------------- rendering ---- *)

let row_attrs
      ~(on_select : item -> unit Bonsai.Effect.t)
      ~(close : unit Bonsai.Effect.t)
      (item : item)
  : Vdom.Attr.t list
  =
  let on_click (ev : Dom_html.mouseEvent Js.t) =
    if item.is_disabled
    then Bonsai.Effect.Ignore
    else (
      let meta, ctrl, shift, alt = modifiers ev in
      if Menu_focus.is_modified_click ~meta ~ctrl ~shift ~alt ~button:(int_prop ev "button")
      then
        (* A modified click belongs to the browser: on a link row it means a new tab
           or a download, and neither running the handler nor closing the menu is
           ours to do. *)
        Bonsai.Effect.Ignore
      else Bonsai.Effect.Many [ on_select item; close ])
  in
  let on_pointermove (ev : Dom_html.pointerEvent Js.t) =
    if item.is_disabled
    then Bonsai.Effect.Ignore
    else if not (String.equal (Option.value (string_prop ev "pointerType") ~default:"") "mouse")
    then
      (* Touch and pen have no hover: focusing on their move would make the row
         under the finger the highlight for no reason the user can see. *)
      Bonsai.Effect.Ignore
    else
      Bonsai.Effect.of_thunk (fun () ->
        match el_prop ev "currentTarget", el_prop Dom_html.document "activeElement" with
        | Some row, Some active when not (contains ~ancestor:row active) -> focus_el row
        | _ -> ())
  in
  Common.Attr.class_
    ([ "astryx-dropdown__item" ]
     @ (match item.variant with
        | Default -> []
        | Destructive -> [ "astryx-dropdown__item--destructive" ]))
  @ Common.Attr.data "target" "dropdown-menu-item"
  @ Common.Attr.data "menu-item" item.id
  @ [ Vdom.Attr.create "role" "menuitem" ]
  @ [ Vdom.Attr.create "tabindex" "-1" ]
  @ (if item.is_disabled then [ Vdom.Attr.create "aria-disabled" "true" ] else [])
  @ [ Vdom.Attr.on_click on_click; Vdom.Attr.on_pointermove on_pointermove ]
  @ (match item.href with Some href -> [ Vdom.Attr.href href ] | None -> [])
;;

let row_node
      ~(on_select : item -> unit Bonsai.Effect.t)
      ~(close : unit Bonsai.Effect.t)
      (item : item)
  : Vdom.Node.t
  =
  let content =
    (match item.icon with
     | Some name ->
       [ Vdom.Node.span
           ~attrs:(Common.Attr.class_ [ "astryx-dropdown__item-icon" ] @ Common.Attr.aria "hidden" "true")
           [ Icon.view ~name ~size:Icon.Sm () ]
       ]
     | None -> [])
    @ [ Vdom.Node.span
          ~attrs:(Common.Attr.class_ [ "astryx-dropdown__item-body" ])
          ([ Vdom.Node.span
               ~attrs:(Common.Attr.class_ [ "astryx-dropdown__item-label" ])
               [ Vdom.Node.text item.label ]
           ]
           @ (match item.description with
              | Some description ->
                [ Vdom.Node.span
                    ~attrs:(Common.Attr.class_ [ "astryx-dropdown__item-description" ])
                    [ Vdom.Node.text description ]
                ]
              | None -> []))
      ]
    @ (match item.end_content with
       | Some end_content ->
         [ Vdom.Node.span ~attrs:(Common.Attr.class_ [ "astryx-dropdown__item-end" ]) [ end_content ] ]
       | None -> [])
  in
  let attrs = row_attrs ~on_select ~close item in
  (* A row with an href *is* the anchor, so the browser's own link meaning (⌘-click,
     middle click) survives; the row keeps role=menuitem so the menu stays one menu
     ([FR10], [AR2]). *)
  match item.href with
  | Some _ -> Vdom.Node.a ~attrs content
  | None -> Vdom.Node.div ~attrs content
;;

let heading_node ~(id : string) (text : string) : Vdom.Node.t =
  Vdom.Node.div
    ~attrs:
      (Common.Attr.class_ [ "astryx-dropdown__heading" ]
       @ Common.Attr.data "target" "dropdown-menu-section-heading"
       @ [ Vdom.Attr.id id ])
    [ Vdom.Node.text text ]
;;

let divider_node () : Vdom.Node.t =
  Vdom.Node.div
    ~attrs:
      (Common.Attr.class_ [ "astryx-dropdown__divider" ]
       @ Common.Attr.data "target" "dropdown-menu-divider"
       @ [ Vdom.Attr.create "role" "separator" ])
    []
;;

let group_node ~(heading_id : string) ~(heading : string option) ~(rows : Vdom.Node.t list) : Vdom.Node.t =
  (* One role=group named by its heading ([FR14]); an untitled group is unnamed
     rather than labelled by nothing. *)
  let attrs =
    Common.Attr.class_ [ "astryx-dropdown__group" ]
    @ [ Vdom.Attr.create "role" "group" ]
    @ (match heading with
       | Some _ -> [ Vdom.Attr.create "aria-labelledby" heading_id ]
       | None -> [])
  in
  Vdom.Node.div
    ~attrs
    ((match heading with
      | Some text -> [ heading_node ~id:heading_id text ]
      | None -> [])
     @ rows)
;;

(* ------------------------------------------------------------------ view ---- *)

(* [is_open] and [on_open_change] are what make the menu controllable, and they come as a pair or not at
   all. With neither, the menu owns its state exactly as before; with both, the caller does. Half a pair is
   worth raising rather than quietly filling in: a caller who passes only [is_open] means to control the
   menu, and would otherwise get one that ignores what they passed. *)
let view
      ?(attrs = [])
      ?(id = "astryx-dropdown-menu")
      ?(is_disabled = false)
      ?(menu_max_height = 300)
      ?variant
      ?size
      ?icon
      ?is_icon_only
      ?(trigger_component_name = "Button")
      ?is_open
      ?on_open_change
      ~trigger_label
      ~on_select
      ~entries
      (graph : Bonsai.graph)
  =
  let open_, set_open =
    match is_open, on_open_change with
    | Some is_open, Some on_open_change -> is_open, on_open_change
    | None, None ->
      let is_open, set_open = Bonsai.state false graph in
      is_open, set_open
    | Some _, None | None, Some _ ->
      raise_s
        (Sexp.Atom
           "Dropdown_menu.view: is_open and on_open_change control the menu together - pass both or             neither")
  in
  (* One typeahead buffer per component, cleared whenever the menu closes. *)
  let typeahead = Menu_focus.create_typeahead () in
  let trigger_id = id ^ "-trigger" in
  let menu_id = id ^ "-menu" in
  let open_state = Bonsai.map2 open_ set_open ~f:(fun value setter -> value, setter) in
  Bonsai.map2 open_state on_select ~f:(fun (open_, set_open) on_select ->
    let reset_buffer () = Menu_focus.reset typeahead in
    (* Returning focus has to wait for the update that removes the focused row: a
       browser hands focus to the body as soon as the focused element is gone, so a
       focus call made first is undone by it. *)
    let return_focus () =
      Bonsai.Effect.of_thunk (fun () ->
        Menu_focus.focus_on_next_frame (fun () -> Option.iter (by_id trigger_id) ~f:focus_el))
    in
    let close_and_return_focus () =
      (* Escape and choosing a row both mean "dismissed on purpose": unlike a click
         elsewhere, focus comes back to the trigger. *)
      reset_buffer ();
      Bonsai.Effect.Many [ set_open false; return_focus () ]
    in
    (* A row closes through the same path, so selecting one hands focus back too. *)
    let close = close_and_return_focus () in
    (* Opening moves focus into the menu — the first enabled row, or the last when the
       trigger was opened with ArrowUp ([FR12]). The row does not exist until the update
       that opens the menu has rendered, so this is scheduled for the next frame. *)
    let open_and_focus ~last =
      Bonsai.Effect.Many
        [ set_open true
        ; Bonsai.Effect.of_thunk (fun () ->
            Menu_focus.focus_on_next_frame (fun () ->
              Option.iter (by_id menu_id) ~f:(fun container ->
                ignore
                  ((if last then Menu_focus.focus_last else Menu_focus.focus_first) container
                   : bool))))
        ]
    in
    let trigger_click (_ : Dom_html.mouseEvent Js.t) =
      if is_disabled
      then Bonsai.Effect.Ignore
      else if open_
      then close_and_return_focus ()
      else open_and_focus ~last:false
    in
    let trigger_keydown (ev : Dom_html.keyboardEvent Js.t) =
      let key = key_of ev in
      if is_disabled
      then Bonsai.Effect.Ignore
      else (
        match key with
        | "ArrowDown" ->
          prevent_default ev;
          open_and_focus ~last:false
        | "ArrowUp" ->
          prevent_default ev;
          open_and_focus ~last:true
        | "Enter" | " " ->
          (* Opens, and suppresses the synthesized click so the menu does not open
             and immediately close. *)
          if open_
          then Bonsai.Effect.Ignore
          else (
            prevent_default ev;
            open_and_focus ~last:false)
        | "Escape" -> if open_ then close_and_return_focus () else Bonsai.Effect.Ignore
        | _ -> Bonsai.Effect.Ignore)
    in
    let menu_keydown (ev : Dom_html.keyboardEvent Js.t) =
      let key = key_of ev in
      let meta, ctrl, shift, alt = modifiers ev in
      let composing = bool_prop ev "isComposing" in
      match el_prop ev "currentTarget" with
      | None -> Bonsai.Effect.Ignore
      | Some container ->
        (* A nested menu's presses bubble up here after that level handled them. *)
        let owned =
          match el_prop ev "target" with
          | Some target -> Menu_focus.owns_event container target
          | None -> true
        in
        if not owned
        then Bonsai.Effect.Ignore
        else if Menu_focus.handle_typeahead typeahead ~container ~key ~ctrl ~meta ~composing
        then (
          prevent_default ev;
          Bonsai.Effect.Ignore)
        else (
          match key with
          | "Escape" ->
            prevent_default ev;
            close_and_return_focus ()
          | "Tab" ->
            (* Without a header or footer there is nothing to cycle through, so Tab
               closes the menu and the browser continues from wherever focus lands
               ([FR15]). *)
            reset_buffer ();
            set_open false
          | "Enter" | " " ->
            prevent_default ev;
            Bonsai.Effect.of_thunk (fun () ->
              ignore (Menu_focus.activate_current ~container ~meta ~ctrl ~shift ~alt))
          | _ ->
            if Menu_focus.handle_navigation ~container ~key ~wrap:true
            then (
              prevent_default ev;
              Bonsai.Effect.Ignore)
            else Bonsai.Effect.Ignore)
    in
    let wrapper_focusout (ev : Dom_html.focusEvent Js.t) =
      (* Dismissal follows focus: focus moving outside the trigger-and-menu subtree
         is the user going elsewhere, so the menu closes and focus stays where they
         put it ([FR6]). *)
      if not open_
      then Bonsai.Effect.Ignore
      else (
        match el_prop ev "currentTarget" with
        | None -> Bonsai.Effect.Ignore
        | Some wrapper ->
          (match el_prop ev "relatedTarget" with
           | None ->
             reset_buffer ();
             set_open false
           | Some related ->
             if contains ~ancestor:wrapper related
             then Bonsai.Effect.Ignore
             else (
               reset_buffer ();
               set_open false)))
    in
    let rows =
      List.mapi entries ~f:(fun index entry ->
        match entry with
        | Item item -> [ row_node ~on_select ~close item ]
        | Divider -> [ divider_node () ]
        | Heading text -> [ heading_node ~id:(sprintf "%s-heading-%d" menu_id index) text ]
        | Group { heading; items } ->
          [ group_node
              ~heading_id:(sprintf "%s-heading-%d" menu_id index)
              ~heading
              ~rows:(List.map items ~f:(fun item -> row_node ~on_select ~close item))
          ])
      |> List.concat
    in
    let trigger =
      Button.view
        ~label:trigger_label
        ~is_disabled
        ?variant
        ?size
        ?icon
        ?is_icon_only
        (* A menu that delegates its trigger names itself, the same way IconButton does: the marker is how
           every tool here finds a component, so a wrapper that could not name itself would be invisible. *)
        ~component_name:trigger_component_name
        ~attrs:
          [ Vdom.Attr.id trigger_id
          ; Vdom.Attr.create "aria-haspopup" "menu"
          ; Vdom.Attr.create "aria-expanded" (Bool.to_string open_)
          ; Vdom.Attr.create "aria-controls" menu_id
          ; Vdom.Attr.on_click trigger_click
          ; Vdom.Attr.on_keydown trigger_keydown
          ]
        []
    in
    (* The menu element is always present so [aria-controls] never dangles; its rows
       only exist while the menu is open, which is what makes the focus attribute on
       the target row activate on open. *)
    let menu =
      Vdom.Node.div
        ~attrs:
          (Common.Attr.class_ [ "astryx-dropdown__menu" ]
           @ Common.Attr.data "target" "dropdown-menu"
           @ [ Vdom.Attr.id menu_id
             ; Vdom.Attr.create "role" "menu"
             ; Vdom.Attr.create "aria-labelledby" trigger_id
             ; Vdom.Attr.create "tabindex" "-1"
             ; Vdom.Attr.create "style" (sprintf "max-height:%dpx" menu_max_height)
             ; Vdom.Attr.on_keydown menu_keydown
             ])
        (if open_ then rows else [])
    in
    Vdom.Node.div
      ~attrs:
        (Common.Attr.class_ [ "astryx-dropdown" ]
         @ Common.Attr.data "component" "DropdownMenu"
         @ [ Vdom.Attr.id id; Vdom.Attr.on_focusout wrapper_focusout ]
         @ attrs)
      [ trigger
      ; Vdom.Node.div
          ~attrs:
            (Common.Attr.class_ [ "astryx-dropdown__popover" ]
             @ Common.Attr.data "state" (if open_ then "open" else "closed")
             @ (if open_ then [] else [ Vdom.Attr.create "hidden" "hidden" ]))
          [ menu ]
      ])
;;
