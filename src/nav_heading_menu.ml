(* NavHeadingMenu — the body of a nav heading's popover.

   Upstream: facebook/astryx, packages/core/src/NavMenu — NavHeadingMenu.tsx
   (206 LOC), NavHeadingMenuItem.tsx (189 LOC), NavMenuContext.tsx (52 LOC),
   index.ts (18 LOC). ≈465 LOC toward this port's discipline.

   Scope decision recorded in the mli: this is the menu SURFACE only. The
   heading (SideNavHeading/TopNavHeading) that renders the split-button trigger
   and owns the popover is not ported yet, so the close callback comes in as an
   explicit [on_close] effect instead of through the NavHeadingCloseContext.

   Keyboard: Menu_focus (useListFocus + useTypeahead) with the items selector
   upstream uses ([role="menuitem"]:not([aria-disabled="true"])), Escape ->
   on_close, Enter/Space -> synthetic click activation on the focused row.
   The capture-phase cancellation machinery (onKeyDownCapture + WeakSet in
   NavHeadingMenu.tsx) exists to honor a caller onKeyDown prop; the port has no
   such prop, so it is omitted rather than half-present - every key this menu
   consumes is preventDefault-ed, which is the observable contract. *)

open! Core
open! Bonsai_web
open Js_of_ocaml

type size =
  | Sm
  | Md
  | Lg

type item =
  { id : string
  ; label : string
  ; description : string option
  ; icon : string option
  ; href : string option
  ; is_disabled : bool
  }

let size_class = function Sm -> "astryx-nav-heading-menu--sm" | Md -> "astryx-nav-heading-menu--md" | Lg -> "astryx-nav-heading-menu--lg"

let min_width_of_size = function
  | Sm -> 160
  | Md -> 200
  | Lg -> 240
;;

(* ------------------------------------------------------------ JS helpers --- *
   Same trick as dropdown_menu.ml: read props in one JS expression as a bool,
   since accessing an absent field as a number raises. *)

let prop_int_js = "(function (o, n) { return typeof o[n] === 'number' ? o[n] : -1; })"

let int_prop (obj : 'a Js.t) (name : string) : int =
  let number : Js.number_t =
    Js.Unsafe.fun_call
      (Js.Unsafe.pure_js_expr prop_int_js)
      [| Js.Unsafe.inject obj; Js.Unsafe.inject (Js.string name) |]
  in
  int_of_float (Js.to_float number)
;;

let prop (obj : 'a Js.t) (name : string) = Js.Unsafe.get obj name

let el_prop (obj : 'a Js.t) (name : string) : Dom_html.element Js.t option =
  Js.Opt.to_option (prop obj name : Dom_html.element Js.t Js.opt)
;;

let prevent_default (obj : 'a Js.t) = ignore (Js.Unsafe.meth_call obj "preventDefault" [||])

let key_of (ev : Dom_html.keyboardEvent Js.t) : string =
  Option.value (Common.string_prop ev "key") ~default:""
;;

let modifiers (ev : 'a Js.t) =
  Common.bool_prop ev "metaKey", Common.bool_prop ev "ctrlKey", Common.bool_prop ev "shiftKey", Common.bool_prop ev "altKey"
;;

(* ------------------------------------------------------------- rendering ---- *)

let row_attrs ~(item : item) ~(on_select : item -> unit Bonsai.Effect.t) ~(on_close : unit Bonsai.Effect.t) : Vdom.Attr.t list =
  let on_click (ev : Dom_html.mouseEvent Js.t) =
    if item.is_disabled
    then Bonsai.Effect.Ignore
    else (
      let meta, ctrl, shift, alt = modifiers ev in
      if Menu_focus.is_modified_click ~meta ~ctrl ~shift ~alt ~button:(int_prop ev "button")
      then Bonsai.Effect.Ignore
      else Bonsai.Effect.Many [ on_select item; on_close ])
  in
  Common.Attr.class_
    ([ "astryx-nav-heading-menu__item" ]
     @ (if item.is_disabled then [ "astryx-nav-heading-menu__item--disabled" ] else []))
  @ Common.Attr.data "target" "nav-heading-menu-item"
  @ Common.Attr.data "menu-item" item.id
  @ [ Vdom.Attr.create "role" "menuitem" ]
  @ [ Vdom.Attr.create "tabindex" "-1" ]
  @ (if item.is_disabled then [ Vdom.Attr.create "aria-disabled" "true" ] else [])
  @ [ Vdom.Attr.on_click on_click ]
  @ (match item.href with Some href -> [ Vdom.Attr.href href ] | None -> [])
;;

let row_node ~(item : item) ~(on_select : item -> unit Bonsai.Effect.t) ~(on_close : unit Bonsai.Effect.t) : Vdom.Node.t =
  let content =
    (match item.icon with
     | Some name ->
       [ Vdom.Node.span
           ~attrs:(Common.Attr.class_ [ "astryx-nav-heading-menu__icon" ] @ Common.Attr.aria "hidden" "true")
           [ Icon.view ~name ~size:Icon.Sm () ]
       ]
     | None -> [])
    @ [ Vdom.Node.span
          ~attrs:(Common.Attr.class_ [ "astryx-nav-heading-menu__body" ])
          ([ Vdom.Node.span
               ~attrs:(Common.Attr.class_ [ "astryx-nav-heading-menu__label" ])
               [ Vdom.Node.text item.label ]
           ]
           @ (match item.description with
              | Some description ->
                [ Vdom.Node.span
                    ~attrs:(Common.Attr.class_ [ "astryx-nav-heading-menu__description" ])
                    [ Vdom.Node.text description ]
                ]
              | None -> []))
      ]
  in
  (* A row with an href IS the anchor; role=menuitem stays so the menu is one
     menu, and a modified click keeps the browser's meaning. Same as
     DropdownMenu's rows. *)
  match item.href with
  | Some _ -> Vdom.Node.a ~attrs:(row_attrs ~item ~on_select ~on_close) content
  | None -> Vdom.Node.div ~attrs:(row_attrs ~item ~on_select ~on_close) content
;;

let view
  ?(attrs = [])
  ?(id = "astryx-nav-heading-menu")
  ?(size = Md)
  ?min_width
  ?(on_close = Bonsai.return Bonsai.Effect.Ignore)
  ~on_select
  ~items
  _graph
  =
  (* One typeahead buffer per component instance; only reset when Escape or an
     activation closes the surface. *)
  let typeahead = Menu_focus.create_typeahead () in
  let size_style =
    let px = Option.value min_width ~default:(min_width_of_size size) in
    [ Vdom.Attr.create "min-width" (string_of_int px ^ "px") ]
  in
  Bonsai.map2 on_select on_close ~f:(fun on_select on_close ->
    let reset_buffer () = Menu_focus.reset typeahead in
    let menu_keydown (ev : Dom_html.keyboardEvent Js.t) =
      let key = key_of ev in
      let meta, ctrl, shift, alt = modifiers ev in
      let composing = Common.bool_prop ev "isComposing" in
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
            reset_buffer ();
            on_close
          | "Enter" | " " ->
            (* Items without an href have no native activation; this synthesizes
               the click upstream's listKeyDown performs. *)
            prevent_default ev;
            Bonsai.Effect.of_thunk (fun () ->
              let activated = Menu_focus.activate_current ~container ~meta ~ctrl ~shift ~alt in
              if activated then reset_buffer ())
          | "Tab" ->
            (* Nothing to cycle through: leave the surface. *)
            reset_buffer ();
            Bonsai.Effect.Ignore
          | _ ->
            if Menu_focus.handle_navigation ~container ~key ~wrap:true
            then (
              prevent_default ev;
              Bonsai.Effect.Ignore)
            else Bonsai.Effect.Ignore)
    in
    Vdom.Node.div
      ~attrs:
        (Common.Attr.class_
           ([ "astryx-nav-heading-menu" ] @ [ size_class size ])
         @ Common.Attr.data "component" "NavHeadingMenu"
         @ Common.Attr.data "size"
             (match size with Sm -> "sm" | Md -> "md" | Lg -> "lg")
         @ [ Vdom.Attr.id id; Vdom.Attr.create "role" "menu" ]
         @ [ Vdom.Attr.on_keydown menu_keydown ]
         @ size_style
         @ attrs)
      (List.map items ~f:(fun item -> row_node ~item ~on_select ~on_close)))
;;
