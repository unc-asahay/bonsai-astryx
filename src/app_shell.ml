(* AppShell — the application frame: a header, a side panel and a main content
   area, with responsive collapse and a mobile drawer.

   Upstream: packages/core/src/AppShell/AppShell.tsx.

   The shape of this module follows the .mli, which is the contract: the two
   upstream render contexts become arguments, and the upstream mobile context
   becomes explicit state the shell owns.

   {2 What the shell owns}

   - The drawer's open state. Controlled by [config.is_open] when the caller
     gives it, internal otherwise; [config.on_open_change] is told about every
     change in either case.
   - The width breakpoint. A matchMedia subscription decides whether the shell
     is in its mobile or its wide layout.
   - The header measurement the auto-height mode needs: the sticky side panel
     is offset by the height of the header, which only the browser knows.

   {2 Named divergences}

   - No React context. The side navigation is a function of the mode it is
     rendered in; the top navigation is a function of the mode and of the
     drawer content it owns.
   - No theme layer. The width breakpoints are Astryx's defaults.
   - The labels are upstream's English catalog strings.
   - The shell renders the drawer and the toggle. [mobile_nav = Custom] is the
     escape hatch for a caller who wants to own both.
   - The drawer is mounted below the breakpoint rather than kept mounted with
     its visibility toggled. *)

open! Core
open! Bonsai_web
open Js_of_ocaml

type variant =
  | Wash
  | Surface
  | Section
  | Elevated
[@@deriving sexp_of]

type height =
  | Fill
  | Auto
[@@deriving sexp_of]

type breakpoint =
  | Sm
  | Md
  | Lg
  | Xl
  | Xxl
  | Never
[@@deriving sexp_of]

type side_nav_mode =
  | Default
  | Drawer
  | Drawer_content
  | Topbar
[@@deriving sexp_of]

type top_nav_mode =
  | Default
  | Mobile_bar
  | Drawer
[@@deriving sexp_of]

type top_nav_render =
  { mode : top_nav_mode
  ; drawer_content : Vdom.Node.t option
  }

type mobile_nav =
  | Disabled
  | Config of config
  | Custom of Vdom.Node.t

and config =
  { has_toggle : bool
  ; is_open : bool Bonsai.t option
  ; on_open_change : (bool -> unit Effect.t) Bonsai.t option
  ; content : Vdom.Node.t option
  ; breakpoint : breakpoint
  ; default_is_mobile : bool
  }

(* Upstream's defaults for the mobile navigation: the toggle is on, the
   breakpoint is md, and the first render assumes the wide layout. *)
let default_config =
  { has_toggle = true
  ; is_open = None
  ; on_open_change = None
  ; content = None
  ; breakpoint = Md
  ; default_is_mobile = false
  }
;;

(* Astryx's default width-breakpoint map: sm 640, md 768, lg 1024, xl 1280,
   2xl 1536. *)
let breakpoint_width = function
  | Sm -> 640
  | Md -> 768
  | Lg -> 1024
  | Xl -> 1280
  | Xxl -> 1536
  | Never -> 0
;;

let breakpoint_query (b : breakpoint) : string option =
  match b with
  | Never -> None
  | b ->
      Some
        (Printf.sprintf
           "(max-width: %fpx)"
           (float_of_int (breakpoint_width b) -. 0.02))
;;

let variant_name = function
  | Wash -> "wash"
  | Surface -> "surface"
  | Section -> "section"
  | Elevated -> "elevated"
;;

(* The breakpoint subscription. The media query only fires when the condition
   *flips*, so the first value has to be read on mount — the same thing
   upstream's useSyncExternalStore does with getSnapshot. *)
module Breakpoint_hook = struct
  module T = struct
    module State = struct
      type t =
        { mutable set_is_mobile : bool -> unit Effect.t
        ; mutable subscription : Js.Unsafe.any option
        }

      let create () =
        { set_is_mobile = (fun _ -> Effect.Ignore); subscription = None }
      ;;
    end

    module Input = struct
      type t =
        { query : string
        ; is_mobile : bool
        ; set_is_mobile : (bool -> unit Effect.t)[@sexp.opaque]
        }

      let sexp_of_t { query; is_mobile; _ } =
        Sexp.List [ Sexp.Atom "app-shell-breakpoint"; Sexp.Atom query; Bool.sexp_of_t is_mobile ]
      ;;

      let combine a b =
        { query = b.query
        ; is_mobile = b.is_mobile
        ; set_is_mobile = (fun v -> Effect.Many [ a.set_is_mobile v; b.set_is_mobile v ])
        }
      ;;
    end

    let init _ _ = State.create ()

    let report (state : State.t) (is_mobile : bool) =
      Effect.Expert.handle_non_dom_event_exn (state.set_is_mobile is_mobile)
    ;;

    let subscribe (state : State.t) (query : string) =
      match state.subscription with
      | Some _ -> ()
      | None ->
          let set_callback = Js.wrap_callback (fun (v : int) -> report state (v <> 0)) in
          let subscription =
            Js.Unsafe.fun_call
              (Js.Unsafe.eval_string
                 "(function (query, set) {\n  \
                  var m = (typeof window !== 'undefined' && window.matchMedia)\n    \
                  ? window.matchMedia(query) : null;\n  \
                  if (!m) { return null; }\n  \
                  var cb = function () { set(m.matches ? 1 : 0); };\n  \
                  try { m.addEventListener('change', cb); }\n  \
                  catch (e) { try { m.addListener(cb); } catch (e2) {} }\n  \
                  set(m.matches ? 1 : 0);\n  \
                  return { m: m, cb: cb }; })")
              [| Js.Unsafe.inject (Js.string query); Js.Unsafe.inject set_callback |]
          in
          (try state.subscription <- Some (Js.Unsafe.inject subscription) with _ -> ())
    ;;

    let apply (state : State.t) (input : Input.t) (_el : Dom_html.element Js.t) =
      state.set_is_mobile <- input.set_is_mobile;
      subscribe state input.query
    ;;

    let on_mount input state el = apply state input el
    let on_mount = `Schedule_immediately_after_this_dom_patch_completes on_mount
    let update ~old_input:_ ~new_input state el = apply state new_input el

    let destroy _ (state : State.t) (_el : Dom_html.element Js.t) =
      state.subscription <- None
    ;;
  end

  module Hook = Vdom.Attr.Hooks.Make (T)

  let attr ~query ~is_mobile ~set_is_mobile =
    Vdom.Attr.create_hook
      "astryx-app-shell-breakpoint"
      (Hook.create { T.Input.query; is_mobile; set_is_mobile })
  ;;
end

(* The header measurement. The auto-height mode pins the side panel below the
   header, and the offset is the header's height — which only the browser
   knows, so it is measured with a ResizeObserver and reported into the
   graph. *)
module Header_height_hook = struct
  module T = struct
    module State = struct
      type t =
        { mutable set_height : int -> unit Effect.t
        ; mutable observer : Js.Unsafe.any option
        }

      let create () = { set_height = (fun _ -> Effect.Ignore); observer = None }
      ;;
    end

    module Input = struct
      type t =
        { set_height : (int -> unit Effect.t)[@sexp.opaque] }

      let sexp_of_t _ = Sexp.List [ Sexp.Atom "app-shell-header-height" ]
      ;;

      let combine a b =
        { set_height = (fun v -> Effect.Many [ a.set_height v; b.set_height v ]) }
      ;;
    end

    let init _ _ = State.create ()

    let report (state : State.t) (height : int) =
      Effect.Expert.handle_non_dom_event_exn (state.set_height height)
    ;;

    let observe (state : State.t) (el : Dom_html.element Js.t) =
      match state.observer with
      | Some _ -> ()
      | None ->
          let set_callback = Js.wrap_callback (fun (v : int) -> report state v) in
          let observer =
            Js.Unsafe.fun_call
              (Js.Unsafe.eval_string
                 "(function (el, set) {\n  \
                  if (typeof ResizeObserver === 'undefined') { return null; }\n  \
                  var ro = new ResizeObserver(function (entries) {\n    \
                  for (var i = 0; i < entries.length; i++) {\n      \
                  set(Math.round(entries[i].contentRect.height));\n    \
                  }\n  });\n  \
                  ro.observe(el);\n  \
                  return ro; })")
              [| Js.Unsafe.inject el; Js.Unsafe.inject set_callback |]
          in
          (try state.observer <- Some (Js.Unsafe.inject observer) with _ -> ())
    ;;

    let apply (state : State.t) (input : Input.t) (el : Dom_html.element Js.t) =
      state.set_height <- input.set_height;
      observe state el
    ;;

    let on_mount input state el = apply state input el
    let on_mount = `Schedule_immediately_after_this_dom_patch_completes on_mount
    let update ~old_input:_ ~new_input state el = apply state new_input el

    let destroy _ (state : State.t) (_el : Dom_html.element Js.t) =
      state.observer <- None
    ;;
  end

  module Hook = Vdom.Attr.Hooks.Make (T)

  let attr ~set_height =
    Vdom.Attr.create_hook "astryx-app-shell-header-height" (Hook.create { T.Input.set_height })
  ;;
end

let view
    ?(attrs = [])
    ?(id = "astryx-app-shell")
    ?(variant = Elevated)
    ?(height = Fill)
    ?(content_padding = Common.Spacing.S0)
    ?banner
    ?side_nav
    ?top_nav
    ?(mobile_nav = Config default_config)
    ~(children : Vdom.Node.t list)
    (graph : Bonsai.graph)
    : Vdom.Node.t Bonsai.t =
  let config =
    match mobile_nav with
    | Config c -> c
    | Disabled | Custom _ -> default_config
  in
  let custom_node =
    match mobile_nav with
    | Custom node -> Some node
    | _ -> None
  in
  (* Disabled: no mobile navigation at all. Custom: the caller owns the drawer
     and the toggle, so the shell renders neither. *)
  let shell_owns_drawer =
    match mobile_nav with
    | Config _ -> true
    | Disabled | Custom _ -> false
  in
  let has_top_nav = Option.is_some top_nav in
  let has_side_nav = Option.is_some side_nav in
  (* Section divides the navigation from the content; the other variants do
     not. *)
  let nav_has_dividers = Poly.equal variant Section in
  let is_fill = Poly.equal height Fill in
  (* --- the mobile state --- *)
  let query = breakpoint_query config.breakpoint in
  let default_is_mobile =
    match query with
    | None -> false
    | Some _ -> config.default_is_mobile
  in
  let is_mobile, set_is_mobile = Bonsai.state default_is_mobile graph in
  (* --- the drawer's open state --- *)
  let open_state, set_open_state = Bonsai.state false graph in
  let (is_open, set_open_to) =
    match config.is_open with
    | Some is_open ->
        (* Controlled: the caller owns the value; the shell only reports. *)
        let report =
          match config.on_open_change with
          | Some on_open_change -> Bonsai.map on_open_change ~f:(fun f -> fun v -> f v)
          | None -> Bonsai.return (fun (_ : bool) -> Effect.Ignore)
        in
        (is_open, report)
    | None ->
        (* Uncontrolled: the shell owns the value, and reports in addition. *)
        let report =
          match config.on_open_change with
          | Some on_open_change -> Bonsai.map on_open_change ~f:(fun f -> Some f)
          | None -> Bonsai.return None
        in
        let set_open_to =
          Bonsai.map2 set_open_state report ~f:(fun set_open_state report ->
            fun v ->
              Effect.Many
                ([ set_open_state v ]
                @ (match report with
                   | None -> []
                   | Some f -> [ f v ])))
        in
        (open_state, set_open_to)
  in
  (* --- the header measurement --- *)
  let header_height, set_header_height = Bonsai.state 0 graph in
  (* --- the drawer's content --- *)
  let drawer_children =
    match config.content with
    | Some content -> [ content ]
    | None ->
        (match top_nav with
         | Some top_nav ->
             let drawer_content =
               match side_nav with
               | Some side_nav -> Some (side_nav Drawer_content)
               | None -> None
             in
             [ top_nav { mode = Drawer; drawer_content } ]
         | None ->
             (match side_nav with
              | Some side_nav -> [ side_nav Drawer ]
              | None -> []))
  in
  let drawer =
    match shell_owns_drawer with
    | false -> None
    | true ->
        Some
          (Mobile_nav.view
             ~id:(id ^ "-mobile-nav")
             ~header:(Mobile_nav.Title "Navigation")
             ~is_open
             ~on_open_change:set_open_to
             ~children:(Bonsai.return drawer_children)
             ())
  in
  (* The state the shell's frame is built from. The setters travel with the
     values they set: a setter is a tree, not a plain function. *)
  let state =
    let a = Bonsai.map3 is_mobile is_open set_open_to ~f:(fun is_mobile is_open set_open_to ->
        (is_mobile, is_open, set_open_to))
    in
    let b = Bonsai.map2 a set_is_mobile ~f:(fun (is_mobile, is_open, set_open_to) set_is_mobile ->
        (is_mobile, is_open, set_open_to, set_is_mobile))
    in
    let c = Bonsai.map2 b header_height ~f:(fun (is_mobile, is_open, set_open_to, set_is_mobile) header_height ->
        (is_mobile, is_open, set_open_to, set_is_mobile, header_height))
    in
    Bonsai.map2 c set_header_height
      ~f:(fun (is_mobile, is_open, set_open_to, set_is_mobile, header_height) set_header_height ->
        (is_mobile, is_open, set_open_to, set_is_mobile, header_height, set_header_height))
  in
  let build
      (is_mobile, is_open, set_open_to, set_is_mobile, header_height, set_header_height)
      drawer_node
    =
    (* The toggle: the hamburger that opens the drawer. It is the shell's,
       because upstream exports it from MobileNav and the shell is what owns
       the drawer. *)
    let toggle =
      if is_mobile && config.has_toggle && shell_owns_drawer then
        Some
          (Vdom.Node.div
             ~attrs:(Common.Attr.class_ [ "astryx-app-shell__toggle" ])
             [ Button.view
                 ~label:"Open navigation"
                 ~variant:Button.Ghost
                 ~is_icon_only:true
                 ~icon:(Icon.view ~name:"menu" ())
                 ~on_click:(fun _ -> set_open_to (not is_open))
                 ~attrs:
                   (Common.Attr.aria "expanded" (if is_open then "true" else "false")
                   @ Common.Attr.aria "controls" (id ^ "-mobile-nav"))
                 [] ])
      else None
    in
    (* The header: the banner, the top navigation and the toggle. *)
    let header_content =
      if has_top_nav || Option.is_some banner then
        Some
          (Layout.header
             ~role:"banner"
             ~padding:Common.Spacing.S0
             ~has_divider:(nav_has_dividers && has_top_nav)
             ~attrs:
               (Common.Attr.class_ [ "astryx-app-shell__header" ]
               @ (if is_fill
                  then []
                  else [ Header_height_hook.attr ~set_height:set_header_height ]))
             ((match banner with
               | Some banner ->
                   [ Vdom.Node.div ~attrs:(Common.Attr.class_ [ "astryx-app-shell__banner" ]) [ banner ] ]
               | None -> [])
              @ (match top_nav with
                 | Some top_nav ->
                     let mode =
                       if is_mobile && shell_owns_drawer then Mobile_bar else Default
                     in
                     let drawer_content =
                       match side_nav with
                       | Some side_nav -> Some (side_nav Drawer_content)
                       | None -> None
                     in
                     [ top_nav { mode; drawer_content } ]
                 | None -> [])
              @ (match toggle with
                 | Some toggle -> [ toggle ]
                 | None -> []))
             ())
      else None
    in
    (* The auto mobile top bar: the side navigation's collapsed form, for the
       layout that has no top navigation to carry the toggle. *)
    let auto_mobile_top_bar =
      if is_mobile && config.has_toggle && shell_owns_drawer && not has_top_nav && has_side_nav then
        Some
          (Layout.header
             ?role:(if Option.is_some header_content then None else Some "banner")
             ~padding:Common.Spacing.S0
             ~has_divider:nav_has_dividers
             ~attrs:(Common.Attr.class_ [ "astryx-app-shell__header" ])
             [ Vdom.Node.div
                 ~attrs:
                   (Common.Attr.class_ [ "astryx-app-shell__mobile-bar" ]
                   @ Common.Attr.role "navigation"
                   @ Common.Attr.aria "label" "Mobile navigation")
                 ((match side_nav with
                   | Some side_nav -> [ side_nav Topbar ]
                   | None -> [])
                  @ (match toggle with
                     | Some toggle -> [ toggle ]
                     | None -> [])) ]
             ())
      else None
    in
    let header =
      match header_content, auto_mobile_top_bar with
      | Some header, None -> Some header
      | None, Some mobile_bar -> Some mobile_bar
      | None, None -> None
      | Some header, Some mobile_bar -> Some (Vdom.Node.fragment [ header; mobile_bar ])
    in
    (* The side panel: the side navigation, inline, in the wide layout only. *)
    let panel =
      match side_nav with
      | Some side_nav when not is_mobile ->
          Some
            (Layout.panel
               ~padding:Common.Spacing.S0
               ~has_divider:nav_has_dividers
               ~is_scrollable:is_fill
               ~attrs:(Common.Attr.class_ [ "astryx-app-shell__panel" ])
               [ side_nav Default ]
               ())
      | _ -> None
    in
    (* The main content: focusable, but never tabbable — the skip link is
       what puts focus here. *)
    let main_content =
      Layout.content
        ~id:"astryx-app-shell-main"
        ~role:"main"
        ~padding:content_padding
        ~is_scrollable:is_fill
        ~attrs:(Common.Attr.class_ [ "astryx-app-shell__content" ] @ [ Vdom.Attr.tabindex (-1) ])
        children
        ()
    in
    let layout =
      Layout.view
        ~height:(match height with Fill -> Layout.Fill | Auto -> Layout.Auto)
        ~padding:Common.Spacing.S0
        ?header
        ?start:panel
        ~content:main_content
        ()
    in
    let skip_link =
      Vdom.Node.a
        ~attrs:
          (Vdom.Attr.href "#astryx-app-shell-main"
          :: Common.Attr.class_ [ "astryx-app-shell__skip-link" ]
          @ [ Vdom.Attr.on_click (fun _ ->
              let focused =
                Js.Unsafe.fun_call
                  (Js.Unsafe.eval_string
                     "(function () { var el = document.getElementById('astryx-app-shell-main'); if (el) { el.focus(); } })")
                  [||]
              in
              ignore focused;
              Effect.Ignore) ])
        [ Vdom.Node.text "Skip to content" ]
    in
    let root_attrs =
      ([ Vdom.Attr.id id ]
      @ Common.Attr.data "component" "AppShell"
      @ Common.Attr.data "variant" (variant_name variant)
      @ Common.Attr.data "height" (if is_fill then "fill" else "auto")
      @ Common.Attr.class_
          [ "astryx-app-shell"
          ; "astryx-app-shell--" ^ variant_name variant
          ; "astryx-app-shell--" ^ (if is_fill then "fill" else "auto")
          ])
      @ (match query with
         | Some query -> [ Breakpoint_hook.attr ~query ~is_mobile ~set_is_mobile ]
         | None -> [])
      @ (match height with
         | Auto ->
             Common.Attr.style
               [ "--_app-shell-header-height", string_of_int header_height ^ "px" ]
         | Fill -> [])
      @ attrs
    in
    let root_children =
      [ skip_link; layout ]
      @ (match drawer_node with
         | Some drawer when is_mobile -> [ drawer ]
         | _ -> [])
      @ (match custom_node with
         | Some node -> [ node ]
         | None -> [])
    in
    Vdom.Node.div ~attrs:root_attrs root_children
  in
  match drawer with
  | None -> Bonsai.map state ~f:(fun (is_mobile, is_open, set_open_to, set_is_mobile, header_height, set_header_height) -> build (is_mobile, is_open, set_open_to, set_is_mobile, header_height, set_header_height) None)
  | Some drawer ->
      Bonsai.map2 state drawer ~f:(fun (is_mobile, is_open, set_open_to, set_is_mobile, header_height, set_header_height) drawer ->
        build (is_mobile, is_open, set_open_to, set_is_mobile, header_height, set_header_height) (Some drawer))
;;
