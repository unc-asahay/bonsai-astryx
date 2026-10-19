(* TabList — a tab strip with the navigation or WAI-ARIA tabs pattern,
   overflow scrolling with edge fades and pointer arrows, and optional
   overflow menu triggers.

   Upstream: packages/core/src/TabList/{TabList,Tab,TabMenu,TabListContext}.tsx
   over hooks/useScrollOverflow.ts, hooks/useListFocus.ts, hooks/isRtlElement.ts,
   hooks/useKeyboardHint.ts and SizeContext/SizeContext.ts.

   The scroll machinery is the shared {!Scroll_overflow} module: the strip
   measures its own scroll geometry, reports into a Bonsai.state cell, and
   re-renders fades and arrows as it changes. Arrow press and selected-tab
   reveal drive the same native scroll API as upstream (RTL sign flip,
   'instant' reveal, CSS smooth behaviour for arrows, reduced-motion via the
   stylesheet).

   {2 Recorded divergences}

   - {b Data-driven API}: upstream reads [Tab]/[TabMenu] children through a
     React context. Bonsai has no React context and this library's house rule
     is data-driven models (DropdownMenu, Breadcrumbs, SegmentedControl), so
     [view] takes [items:item list] where [Tab] and [Menu] are records. The
     API surface (value/onChange/size/layout/role/overflow/full-bleed) is
     otherwise exactly upstream's.
   - {b Per-item consumer callbacks} ([TabProps.onClick], [TabMenuOption.icon]
     as a ReactNode): outside the data model — dropped.
   - {b Keyboard hint} (useKeyboardHint's ephemeral "Press Enter or Space"
     hint): out of scope, as with Toolbar.
   - {b Arrow axes}: upstream accepts ArrowUp/ArrowDown in addition to the
     horizontal arrows for the nav pattern (APG allowance). The house
     {!Common.List_focus} is single-axis; the port uses the horizontal axes
     (and Home/End), leaving Up/Down to the page, like a native tablist.
   - {b Touch press overlay} (usePressFeedback + the painted
     [--_press-paint-image] layer): the port uses CSS [background-color]
     [:hover]/[:active] only, as with the other controls.
   - {b Menu top layer}: the overflow menu opens in the host application's
     popover layer (house {!Popover}), not upstream's native popover free
     layer. Same visible contract: anchored below the trigger, light-dismissed,
     role="menu" menuitemradio items.

   {2 Accessibility}

   With [role] left unset the wrapper is a [<nav>] landmark marking the current
   tab with [aria-current="true"]. With [role="tablist"] the strip is a
   [role="tablist"], each tab is [role="tab"] with [aria-selected] and
   [aria-controls] (only when a [panel_id] is present — an aria-controls whose
   target does not exist is worse than none), and the roving tab stop is the
   selected tab. A [href] is ignored under the tabs pattern, exactly like
   upstream. The tab strip is a single Tab stop; arrow keys move focus over
   it via the shared {!Common.List_focus} hook, and the selected tab is
   always scrolled back into view on selection change. *)

open! Core
open! Bonsai_web
open Js_of_ocaml

type size =
  | Sm
  | Md
  | Lg
[@@deriving sexp_of]

type layout =
  | Hug
  | Fill
[@@deriving sexp_of]

type overflow =
  | Auto
  | Scroll
  | Visible
[@@deriving sexp_of]

type pattern =
  | Nav
  | Tabs
[@@deriving sexp_of]

type tab =
  { value : string
  ; label : string
  ; is_label_hidden : bool
  ; href : string option
  ; panel_id : string option
  ; icon : string option
  ; selected_icon : string option
  ; end_content : Vdom.Node.t option
  ; is_disabled : bool
  }
[@@deriving sexp_of]

type option_item =
  { value : string
  ; label : string
  ; icon : string option
  }
[@@deriving sexp_of]

type menu =
  { label : string
  ; options : option_item list
  }
[@@deriving sexp_of]

type item =
  | Tab of tab
  | Menu of menu
[@@deriving sexp_of]

let size_class = function Sm -> "sm" | Md -> "md" | Lg -> "lg"
let has_scroll = function Auto | Scroll -> true | Visible -> false
let pattern_of_role = function Some "tablist" -> Tabs | _ -> Nav

let tab_stop_selector = "[data-tab-value], [data-tab-menu]"
let tab_list_boundary = "[data-astryx-tab-list]"

(* The selected tab's ordinal among the strip's tab stops. Used to reveal the
   selected tab by index so no consumer string is ever interpolated into a
   selector. *)
let selected_tab_ordinal (items : item list) (value : string) =
  let seen = ref (-1) in
  let found = ref (-1) in
  List.iter items ~f:(function
    | Tab t ->
      incr seen;
      if String.equal t.value value then found := !seen
    | Menu _ -> ());
  !found
;;

(* ------------------------------------------------------------ reveal hook *)

(* Scrolling the selected tab back into view. Attached to the strip; [update]
   fires when the selected ordinal or the overflow mode changes (never on the
   strip's own scroll). Deduped on the value, so a re-render that does not
   change the selection does not scroll anything. *)
module Reveal_hook = struct
  module T = struct
    module State = struct
      type t = { mutable last : (int * bool) option }

      let create () = { last = None }
    end

    module Input = struct
      type t =
        { index : int
        ; has_scroll : bool
        }

      let sexp_of_t { index; has_scroll } =
        Sexp.List
          [ Sexp.Atom (Int.to_string index); Sexp.Atom (Bool.to_string has_scroll) ]
      ;;

      let combine left _ = left
    end

    let reveal_js =
      Js.Unsafe.eval_string
        "(function (strip, idx) { if (!strip || idx < 0 || typeof strip.scrollBy !== 'function') return; var stops = strip.querySelectorAll('[data-tab-value]'); var stop = stops[idx]; if (!stop) return; var sb = strip.getBoundingClientRect(); var tb = stop.getBoundingClientRect(); var inset = parseFloat(getComputedStyle(strip).scrollPaddingLeft) || 0; var pastEnd = tb.right - (sb.right - inset); var pastStart = tb.left - (sb.left + inset); var tooWide = tb.width > sb.width - 2 * inset; var rtl = getComputedStyle(strip).direction === 'rtl'; var delta = tooWide ? (rtl ? pastEnd : pastStart) : (pastEnd > 0 ? pastEnd : pastStart < 0 ? pastStart : 0); if (delta !== 0) strip.scrollBy({ left: delta, behavior: 'instant' }); })"
    ;;

    let reveal (input : Input.t) (state : State.t) (node : Dom_html.element Js.t) =
      match state.State.last with
      | Some last when Poly.equal last (input.index, input.has_scroll) -> ()
      | _ ->
        state.State.last <- Some (input.index, input.has_scroll);
        ignore
          (Js.Unsafe.fun_call reveal_js
             [| Js.Unsafe.inject node; Js.Unsafe.inject input.index |])
    ;;

    let init _ _ = State.create ()
    let on_mount input state node = reveal input state node
    let on_mount = `Schedule_immediately_after_this_dom_patch_completes on_mount
    let update ~old_input:_ ~new_input state node = reveal new_input state node
    let destroy _ _ _ = ()
  end

  module Hook = Vdom.Attr.Hooks.Make (T)

  let attr ~index ~has_scroll () =
    Vdom.Attr.create_hook
      "astryx-tab-reveal"
      (Hook.create { T.Input.index; has_scroll })
  ;;
end

(* ------------------------------------------------------- menu focus hook *)

(* Moving focus into the option list when the menu opens (APG menu-button
   focus-on-open), reusing the same focus machinery as DropdownMenu. [update]
   fires on the open edge only, so re-renders while open do not steal focus. *)
module Menu_focus_hook = struct
  module T = struct
    module State = struct
      type t = unit

      let create () = ()
    end

    module Input = struct
      type t = { is_open : bool }

      let sexp_of_t { is_open } = Sexp.List [ Sexp.Atom (Bool.to_string is_open) ]
      let combine left _ = left
    end

    let init _ _ = State.create ()
    let on_mount (input : Input.t) _ (node : Dom_html.element Js.t) =
      if input.is_open then ignore (Menu_focus.focus_first node)
    ;;
    let on_mount = `Schedule_immediately_after_this_dom_patch_completes on_mount
    let update ~old_input:(old_input : Input.t) ~new_input:(new_input : Input.t) _ (node : Dom_html.element Js.t) =
      if (not old_input.is_open) && new_input.is_open
      then ignore (Menu_focus.focus_first node)
    ;;
    let destroy _ _ _ = ()
  end

  module Hook = Vdom.Attr.Hooks.Make (T)

  let attr ~is_open () =
    Vdom.Attr.create_hook "astryx-tab-menu-focus" (Hook.create { T.Input.is_open })
  ;;
end

(* The nav-button page scroll. [dir] is -1 for start, 1 for end. RTL flips the
   physical delta; the strip's CSS scroll-behaviour (smooth, 'auto' under
   reduced motion) applies because no behavior is requested. *)
let page_js =
  Js.Unsafe.eval_string
    "(function (strip, dir) { if (!strip || typeof strip.scrollBy !== 'function') return; var rtl = getComputedStyle(strip).direction === 'rtl'; var sign = rtl ? -1 : 1; strip.scrollBy({ left: sign * dir * strip.clientWidth * 0.8 }); })"
;;

let scroll_page_click (strip_el : Dom_html.element Js.t) dir () =
  ignore (Js.Unsafe.fun_call page_js [| Js.Unsafe.inject strip_el; Js.Unsafe.inject dir |]);
  Effect.Ignore
;;

(* The strip element is the hook target; an arrow button is a sibling inside
   the same root. *)
let strip_of (ev : 'a Js.t) : Dom_html.element Js.t option =
  let btn : Dom_html.element Js.t = Js.Unsafe.coerce (Common.prop ev "currentTarget") in
  match Js.Opt.to_option (Js.Unsafe.meth_call btn "closest" [| Js.Unsafe.inject (Js.string "[data-astryx-tab-list]") |]) with
  | None -> None
  | Some root ->
    Js.Opt.to_option
      (Js.Unsafe.meth_call root "querySelector" [| Js.Unsafe.inject (Js.string ".astryx-tab-list__strip") |])
;;

let view
  ?attrs
  ?(id = "astryx-tab-list")
  ?(size = Md)
  ?(layout = Hug)
  ?(has_divider = false)
  ?(is_full_bleed = false)
  ?role
  ?(overflow = Auto)
  ?aria_label
  ?aria_labelledby
  ~(value : string Bonsai.t)
  ~(on_change : (string -> unit Effect.t) Bonsai.t)
  ~(items : item list)
  (graph : Bonsai.graph)
  =
  let pattern = pattern_of_role role in
  let scroll_enabled = has_scroll overflow in
  let is_tabs_pattern = Poly.equal pattern Tabs in
  let overflow_state, set_overflow = Bonsai.state Scroll_overflow.inactive_overflow graph in
  let menu_open, set_menu_open = Bonsai.state (None : int option) graph in
  let open_state = Bonsai.map2 overflow_state set_overflow ~f:(fun ov set -> ov, set) in
  let menu_state = Bonsai.map2 menu_open set_menu_open ~f:(fun mo set -> mo, set) in
  let value_state = Bonsai.map2 value on_change ~f:(fun v f -> v, f) in
  Bonsai.map3 open_state menu_state value_state ~f:(fun (ov, set_ov) (mo, set_mo) (v, on_select) ->
    (* The strip classes restate upstream's bleed/inset arithmetic; the CSS
       owns the geometry (padding/margins cancel, masks, divider rail). *)
    let fade_class =
      if not scroll_enabled
      then []
      else if ov.start && ov.end_ then [ "astryx-tab-list__strip--fade-both" ]
      else if ov.start then [ "astryx-tab-list__strip--fade-start" ]
      else if ov.end_ then [ "astryx-tab-list__strip--fade-end" ]
      else []
    in
    let strip_classes =
      [ "astryx-tab-list__strip" ]
      @ (if scroll_enabled then [ "astryx-tab-list__strip--scroll" ] else [])
      @ (if is_full_bleed then [ "astryx-tab-list__strip--full-bleed" ] else [])
      @ fade_class
    in
    let nav_classes =
      [ "astryx-tab-list" ]
      @ [ Printf.sprintf "astryx-tab-list--%s" (size_class size) ]
      @ (match layout with Hug -> [] | Fill -> [ "astryx-tab-list--fill" ])
      @ (if has_divider then [ "astryx-tab-list--divider" ] else [])
      @ (if is_full_bleed then [ "astryx-tab-list--full-bleed" ] else [])
    in
    let strip_attr =
      Common.Attr.class_ strip_classes
      @ (if is_tabs_pattern
         then
           [ Vdom.Attr.create "role" "tablist" ]
           @ (match aria_label with
             | Some label -> [ Vdom.Attr.create "aria-label" label ]
             | None -> [])
           @ (match aria_labelledby with
             | Some id -> [ Vdom.Attr.create "aria-labelledby" id ]
             | None -> [])
         else [])
      @ [ Reveal_hook.attr ~index:(selected_tab_ordinal items v) ~has_scroll:scroll_enabled () ]
      @ (if scroll_enabled
         then [ Scroll_overflow.Overflow_hook.attr ~on_measured:(fun m -> set_ov m) () ]
         else [])
    in
    let tab_node (t : tab) =
      let selected = String.equal t.value v in
      let disabled = t.is_disabled in
      let is_link = Option.is_some t.href && not is_tabs_pattern in
      let icon_name = if selected && Option.is_some t.selected_icon then t.selected_icon else t.icon in
      let base_classes =
        [ "astryx-tab" ]
        @ [ Printf.sprintf "astryx-tab--%s" (size_class size) ]
        @ (if selected then [ "astryx-tab--selected" ] else [])
        @ (match layout with Hug -> [] | Fill -> [ "astryx-tab--fill" ])
        @ (if disabled then [ "astryx-tab--disabled" ] else [])
      in
      let attrs =
        Common.Attr.class_ base_classes
        @ [ Vdom.Attr.create "data-tab-value" t.value
          ; Vdom.Attr.create "tabindex" (if selected then "0" else "-1")
          ]
        @ (match pattern with
          | Tabs ->
            [ Vdom.Attr.create "role" "tab"; Vdom.Attr.create "aria-selected" (Bool.to_string selected) ]
            @ (match t.panel_id with
              | Some pid -> [ Vdom.Attr.create "aria-controls" pid ]
              | None -> [])
          | Nav -> if selected then [ Vdom.Attr.create "aria-current" "true" ] else [])
        @ (if t.is_label_hidden
           then [ Vdom.Attr.create "aria-label" t.label ] else [])
        @ (if disabled
           then [ Vdom.Attr.create "aria-disabled" "true" ] else [])
        @ [ Vdom.Attr.on_click (fun ev ->
                if disabled
                then (
                  Common.prevent_default ev;
                  Effect.Ignore)
                else on_select t.value)
          ]
      in
      let icon_node =
        match icon_name with
        | Some name ->
          [ Vdom.Node.span
              ~attrs:(Common.Attr.class_ [ "astryx-tab__icon" ])
              [ Icon.view ~name ~size:Sm ~color:Inherit () ]
          ]
        | None -> []
      in
      let label_node =
        if t.is_label_hidden || String.equal t.label ""
        then []
        else
          [ Vdom.Node.span
              ~attrs:(Common.Attr.class_ [ "astryx-tab__label" ])
              [ Vdom.Node.span
                  ~attrs:(Common.Attr.class_ [ "astryx-tab__label-text" ])
                  [ Vdom.Node.text t.label ]
              ; Vdom.Node.span
                  ~attrs:
                    (Common.Attr.class_ [ "astryx-tab__label-sizer" ]
                     @ [ Vdom.Attr.create "aria-hidden" "true" ])
                  [ Vdom.Node.text t.label ]
              ]
          ]
      in
      let end_node =
        match t.end_content with
        | Some node ->
          [ Vdom.Node.span ~attrs:(Common.Attr.class_ [ "astryx-tab__end" ]) [ node ] ]
        | None -> []
      in
      let indicator =
        Vdom.Node.span
          ~attrs:
            (Common.Attr.class_
               [ "astryx-tab__indicator"
               ; (if selected then "astryx-tab__indicator--selected" else "astryx-tab__indicator--idle")
               ])
          []
      in
      let content = icon_node @ label_node @ end_node @ [ indicator ] in
      if is_link
      then
        Vdom.Node.a
          ~attrs:
            (attrs
             @ (if disabled
                then []
                else
                  match t.href with
                  | Some href -> [ Vdom.Attr.href href ]
                  | None -> []))
          content
      else Vdom.Node.button ~attrs:(Vdom.Attr.create "type" "button" :: attrs) content
    in
    let menu_id i = Printf.sprintf "%s-%d" id i in
    let menu_surface_id i = menu_id i ^ "-surface" in
    let menu_node (i : int) (m : menu) =
      let has_selected = List.exists m.options ~f:(fun o -> String.equal o.value v) in
      let open_ = Poly.equal mo (Some i) in
      let toggle () = set_mo (if open_ then None else Some i) in
      let trigger =
        Vdom.Node.button
          ~attrs:
            (Common.Attr.class_
               ([ "astryx-tab"; "astryx-tab--" ^ size_class size; "astryx-tab-menu__trigger" ]
                @ (if has_selected then [ "astryx-tab--selected" ] else []))
             @ [ Vdom.Attr.create "type" "button"
               ; Vdom.Attr.create "data-tab-menu" ""
               ; Vdom.Attr.create "aria-haspopup" "menu"
               ; Vdom.Attr.create "aria-expanded" (Bool.to_string open_)
               ; Vdom.Attr.create "aria-controls" (menu_surface_id i)
               ; Vdom.Attr.create "tabindex" (if has_selected then "0" else "-1")
               ; Vdom.Attr.on_click (fun _ -> toggle ())
               ])
          ([ Vdom.Node.span
               ~attrs:(Common.Attr.class_ [ "astryx-tab__label" ])
               [ Vdom.Node.span
                   ~attrs:(Common.Attr.class_ [ "astryx-tab__label-text" ])
                   [ Vdom.Node.text m.label ]
               ; Vdom.Node.span
                   ~attrs:
                     (Common.Attr.class_ [ "astryx-tab__label-sizer" ]
                      @ [ Vdom.Attr.create "aria-hidden" "true" ])
                   [ Vdom.Node.text m.label ]
               ]
           ; Vdom.Node.span
               ~attrs:(Common.Attr.class_ [ "astryx-tab-menu__chevron" ])
               [ Icon.view
                   ~name:"chevronDown"
                   ~size:Sm
                   ~color:Inherit
                   ~attrs:
                     (Common.Attr.class_
                        [ (if open_ then "astryx-tab-menu__chevron-icon--open" else "astryx-tab-menu__chevron-icon") ])
                   ()
               ]
           ]
           @ (if has_selected
              then
                [ Vdom.Node.span
                    ~attrs:(Common.Attr.class_ [ "astryx-tab__indicator"; "astryx-tab__indicator--selected" ])
                    []
                ]
              else []))
      in
      let option_keydown (o : option_item) (ev : Dom_html.keyboardEvent Js.t) =
        let key = Option.value (Common.string_prop ev "key") ~default:"" in
        if String.equal key "Enter" || String.equal key " "
        then (
          Common.prevent_default ev;
          Effect.Many [ on_select o.value; set_mo None ])
        else Effect.Ignore
      in
      let menu_keydown (ev : Dom_html.keyboardEvent Js.t) =
        let key = Option.value (Common.string_prop ev "key") ~default:"" in
        match key with
        | "Tab" ->
          (* Tab leaves the menu: close, and let the browser's default move
             focus on from the trigger. The native popover returns focus to
             the trigger when the surface hides. *)
          set_mo None
        | "Escape" ->
          (* The platform popover closes on Escape and reports via
             on_open_change; nothing to do here. *)
          Effect.Ignore
        | "ArrowDown" | "ArrowUp" | "ArrowLeft" | "ArrowRight" | "Home" | "End" ->
          Common.prevent_default ev;
          (match Js.Opt.to_option (Common.prop ev "currentTarget" : Dom_html.element Js.t Js.opt) with
           | None -> Effect.Ignore
           | Some container ->
             ignore (Menu_focus.handle_navigation ~container ~key ~wrap:false);
             Effect.Ignore)
        | _ -> Effect.Ignore
      in
      let content =
        Vdom.Node.div
          ~attrs:
            (Common.Attr.class_ [ "astryx-tab-menu__dropdown" ]
             @ [ Vdom.Attr.create "role" "menu"
               ; Vdom.Attr.create "aria-label" m.label
               ; Vdom.Attr.on_keydown menu_keydown
               ; Menu_focus_hook.attr ~is_open:open_ ()
               ])
          (Vdom.Node.span
             ~attrs:
               (Common.Attr.class_ [ "astryx-tab-menu__heading" ]
                @ [ Vdom.Attr.create "role" "presentation" ])
             [ Vdom.Node.text m.label ]
           :: List.map m.options ~f:(fun o ->
                let o_selected = String.equal o.value v in
                Vdom.Node.div
                  ~attrs:
                    (Common.Attr.class_
                       [ "astryx-tab-menu__item"
                       ; (if o_selected then "astryx-tab-menu__item--selected" else "")
                       ]
                     @ [ Vdom.Attr.create "role" "menuitemradio"
                       ; Vdom.Attr.create "tabindex" "-1"
                       ; Vdom.Attr.create "aria-checked" (Bool.to_string o_selected)
                       ; Vdom.Attr.on_click (fun _ ->
                             Effect.Many [ on_select o.value; set_mo None ])
                       ; Vdom.Attr.on_keydown (option_keydown o)
                       ])
                  ([ Vdom.Node.span
                       ~attrs:(Common.Attr.class_ [ "astryx-tab-menu__item-content" ])
                       ((match o.icon with
                         | Some name -> [ Icon.view ~name ~size:Sm ~color:Secondary () ]
                         | None -> [])
                        @ [ Vdom.Node.text o.label ])
                   ]
                   @ (if o_selected
                      then [ Icon.view ~name:"check" ~size:Sm ~color:Accent () ]
                      else [])))
          )
      in
      Popover.view
        ~id:(menu_id i)
        ~placement:Popover.Below
        ~alignment:Popover.Align_start
        ~role:Popover.No_role
        ~has_light_dismiss:true
        ~has_escape_dismiss:true
        ~has_close_button:false
        ~has_auto_focus:false
        ~trigger
        ~content
        ~is_open:open_
        ~on_open_change:(fun b -> set_mo (if b then Some i else None))
        ()
    in
    let items_nodes =
      List.mapi items ~f:(fun i -> function
        | Tab t -> tab_node t
        | Menu m -> menu_node i m)
    in
    let arrow side dir =
      let can = match side with `Start -> ov.start | `End -> ov.end_ in
      if not scroll_enabled || not can
      then Vdom.Node.none
      else
        Vdom.Node.button
          ~attrs:
            (Common.Attr.class_
               [ "astryx-tab-list__arrow"
               ; (match side with `Start -> "astryx-tab-list__arrow--start" | `End -> "astryx-tab-list__arrow--end")
               ; Printf.sprintf "astryx-tab-list__arrow--%s" (size_class size)
               ]
             @ [ Vdom.Attr.create "type" "button"
               ; Vdom.Attr.create "aria-hidden" "true"
               ; Vdom.Attr.create "tabindex" "-1"
               ; Vdom.Attr.on_mousedown (fun ev ->
                     Common.prevent_default ev;
                     Effect.Ignore)
               ; Vdom.Attr.on_click (fun ev ->
                     match strip_of ev with
                     | None -> Effect.Ignore
                     | Some strip -> scroll_page_click strip dir ())
               ])
          [ Icon.view
              ~name:(match side with `Start -> "chevronLeft" | `End -> "chevronRight")
              ~size:Sm
              ~color:Inherit
              ~attrs:(Common.Attr.class_ [ "astryx-tab-list__icon--mirror" ])
              ()
          ]
    in
    let wrapper_attrs =
      Common.Attr.class_ nav_classes
      @ [ Vdom.Attr.id id
        ; Vdom.Attr.create "data-astryx-tab-list" ""
        ]
      @ Common.Attr.data "component" "TabList"
      @ [ Common.List_focus.attr
            ~orientation:Common.List_focus.Horizontal
            ~item_selector:tab_stop_selector
            ~boundary_selector:tab_list_boundary
            ~prefer_existing_stop:true
            ()
        ]
    in
    (* role and name: tablist asserts everything on the strip; a nav landmark
       takes the label on the wrapper; any other role is passed through. *)
    let wrapper_attrs =
      match role with
      | Some "tablist" -> wrapper_attrs
      | Some other ->
        wrapper_attrs @ [ Vdom.Attr.create "role" other ]
        @ (match aria_label with
          | Some label -> [ Vdom.Attr.create "aria-label" label ]
          | None -> [])
        @ (match aria_labelledby with
          | Some id -> [ Vdom.Attr.create "aria-labelledby" id ]
          | None -> [])
      | None ->
        wrapper_attrs
        @ (match aria_label with
          | Some label -> [ Vdom.Attr.create "aria-label" label ]
          | None -> [])
        @ (match aria_labelledby with
          | Some id -> [ Vdom.Attr.create "aria-labelledby" id ]
          | None -> [])
    in
    let strip =
      Vdom.Node.div ~attrs:strip_attr items_nodes
    in
    let wrapper_el =
      if is_tabs_pattern
      then Vdom.Node.div
      else Vdom.Node.nav
    in
    wrapper_el
      ~attrs:
        (wrapper_attrs
         @ (match attrs with Some a -> a | None -> []))
      ([ strip
       ; arrow `Start (-1)
       ; arrow `End 1
       ]))
;;
