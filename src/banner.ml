(* Banner — a persistent status notification, ported from upstream
   Banner/Banner.tsx. See banner.mli for the contract and divergences. *)

open! Core
open! Bonsai_web

module Attr = Common.Attr

open Js_of_ocaml

type container =
  | Card
  | Section

type collapsible =
  | Never
  | Enabled of Use_collapsible.config

type el = Dom_html.element Js.t

(* ------------------------------------------------ small DOM helpers (local
   until a second consumer appears, per the port's rule for mechanisms) *)

let el_prop (obj : 'a Js.t) (name : string) : el option =
  Js.Opt.to_option (Common.prop obj name : el Js.opt)
;;

let contains (root : el) (node : el) : bool =
  Js.to_bool (Js.Unsafe.meth_call root "contains" [| Js.Unsafe.inject node |])
;;

let same (a : el) (b : el) : bool = phys_equal (Js.Unsafe.coerce a) (Js.Unsafe.coerce b)

let body () : el = Js.Unsafe.get Dom_html.document "body"

let active_element () : el option = el_prop Dom_html.document "activeElement"

let focus_if_connected (origin : el) : unit Effect.t =
  (* A disconnected element's [focus] is a no-op in the browser, so the
     upstream isConnected guard needs no separate check. *)
  Bonsai.Effect.of_thunk (fun () -> ignore (Js.Unsafe.meth_call origin "focus" [||]))
;;

(* ------------------------------------------------------------- statuses ---- *)

let status_header_class = function
  | "info" -> Some "astryx-banner__header--info"
  | "warning" -> Some "astryx-banner__header--warning"
  | "error" -> Some "astryx-banner__header--error"
  | "success" -> Some "astryx-banner__header--success"
  | _ -> None
;;

let status_icon_name = function
  | "info" -> Some "info"
  | "warning" -> Some "warning"
  | "error" -> Some "error"
  | "success" -> Some "success"
  | _ -> None
;;

let status_icon_color = function
  | "info" -> Some Icon.Accent
  | "warning" -> Some Icon.Warning
  | "error" -> Some Icon.Error
  | "success" -> Some Icon.Success
  | _ -> None
;;

let default_id = "astryx-banner"

let container_class = function Card -> "astryx-banner--card" | Section -> "astryx-banner--section"

let elevation_class = function
  | Button.E_none -> "astryx-banner--elevation-none"
  | Button.Low -> "astryx-banner--elevation-low"
  | Button.Med -> "astryx-banner--elevation-med"
  | Button.High -> "astryx-banner--elevation-high"
;;

(* A banner starts closed, unlike the hook's own default. The forced default is
   applied here, so Use_collapsible stays upstream's machine with upstream's
   defaults for everyone else. *)

let banner_config (config : Use_collapsible.config) : Use_collapsible.config =
  { config with
    default_is_open =
      (match config.default_is_open with None -> Some false | Some b -> Some b)
  }
;;

(* -------------------------------------------------------------- rendering -- *)

let view
  ?(attrs = [])
  ?(id = default_id)
  ?description
  ?icon
  ?(is_dismissable = false)
  ?on_dismiss
  ?(dismiss_label = "Dismiss")
  ?(expand_label = "Expand")
  ?(collapse_label = "Collapse")
  ?end_content
  ?(container = Card)
  ?(elevation = Button.E_none)
  ?(collapsible = Enabled { Use_collapsible.default_is_open = None; is_open = None; on_open_change = None })
  ~status
  ~title
  ?(children = [])
  graph
  =
  let is_dismissed, set_is_dismissed = Bonsai.state false graph in
  let origin, set_origin = Bonsai.state (None : el option) graph in
  let collapse =
    match collapsible with
    | Never -> Bonsai.return (false, false, (fun () -> Effect.Many []))
    | Enabled config ->
      Use_collapsible.component
        ~is_collapsible:true
        ~config:(banner_config config)
        graph
  in
  let handled =
    Bonsai.map2 is_dismissed set_is_dismissed ~f:(fun is_dismissed set_is_dismissed ->
        is_dismissed, set_is_dismissed)
  in
  let origin_handled =
    Bonsai.map2 origin set_origin ~f:(fun origin set_origin -> origin, set_origin)
  in
  Bonsai.map3 handled origin_handled collapse
    ~f:(fun (is_dismissed, set_is_dismissed) (origin, set_origin) (is_enabled, is_open, toggle) ->
      if is_dismissed
      then Vdom.Node.none
      else (
        let has_children = not (List.is_empty children) in
        let has_toggle = is_enabled && has_children in
        let show_end_area = Option.is_some end_content || is_dismissable || has_toggle in
        let show_content = has_children && (not is_enabled || is_open) in
        let is_card = match container with Card -> true | Section -> false in
        let is_single_line =
          Option.is_none description && (Option.is_some end_content || is_dismissable)
        in
        let content_id = sprintf "%s-content" id in
        let remember_candidate (candidate : el option) : unit Effect.t =
          match candidate with
          | None -> Effect.Ignore
          | Some el -> if same el (body ()) then Effect.Ignore else set_origin (Some el)
        in
        let on_focusin (ev : Dom_html.focusEvent Js.t) =
          match el_prop ev "currentTarget", el_prop ev "relatedTarget" with
          | Some root, Some related when not (contains root related) -> remember_candidate (Some related)
          | _ -> Effect.Ignore
        in
        let on_pointerdown (ev : Dom_html.pointerEvent Js.t) =
          match el_prop ev "currentTarget", active_element () with
          | Some root, Some active when not (contains root active) -> remember_candidate (Some active)
          | _ -> Effect.Ignore
        in
        let handle_dismiss () : unit Effect.t =
          let effects =
            [ set_is_dismissed true ]
            @ (match on_dismiss with Some f -> [ f () ] | None -> [])
          in
          let focus_back =
            match origin with Some el -> focus_if_connected el | None -> Effect.Ignore
          in
          Effect.Many (effects @ [ focus_back ])
        in
        (* The toggle exists only for a collapsible banner that has content to
           disclose; it is a ghost icon button carrying the disclosure
           attributes upstream puts on it. The chevron's classes ride on the
           Icon's own wrapper span, so the element a theme would target is the
           one that rotates. *)
        let toggle_button () =
          let chevron_class =
            Attr.class_
              ([ "astryx-banner__chevron" ]
               @ (if is_open then [ "astryx-banner__chevron--expanded" ] else []))
          in
          Button.view
            ~label:(if is_open then collapse_label else expand_label)
            ~variant:Button.Ghost
            ~size:Button.Sm
            ~is_icon_only:true
            ~icon:(Icon.view ~size:Icon.Sm ~color:Icon.Inherit ~attrs:chevron_class ~name:"chevronDown" ())
            ~on_click:(fun (_ : Dom_html.mouseEvent Js.t) -> toggle ())
            ~attrs:
              (Attr.aria "expanded" (if is_open then "true" else "false")
               @ (if show_content then Attr.aria "controls" content_id else []))
            []
        in
        let dismiss_button () =
          Button.view
            ~label:dismiss_label
            ~variant:Button.Ghost
            ~size:Button.Sm
            ~is_icon_only:true
            ~icon:(Icon.view ~size:Icon.Sm ~color:Icon.Inherit ~name:"close" ())
            ~on_click:(fun (_ : Dom_html.mouseEvent Js.t) -> handle_dismiss ())
            ~attrs:[ Vdom.Attr.create "title" dismiss_label ]
            []
        in
        let header_classes =
          Attr.class_
            ([ "astryx-banner__header" ]
             @ (match status_header_class status with Some c -> [ c ] | None -> [])
             @ [ (if is_single_line then "astryx-banner__header--centered" else "") ]
             @ (if is_card
                then
                  [ (if show_content
                     then "astryx-banner__header--card-with-content"
                     else "astryx-banner__header--card-standalone")
                  ]
                else []))
        in
        let end_area =
          if not show_end_area
          then []
          else
            [ Vdom.Node.div
                ~attrs:(Attr.class_ [ "astryx-banner__end" ])
                ((match end_content with Some c -> [ c ] | None -> [])
                 @ (if has_toggle then [ toggle_button () ] else [])
                 @ (if is_dismissable then [ dismiss_button () ] else []))
            ]
        in
        let description_el =
          match description with
          | Some d when not (List.is_empty d) ->
            [ Vdom.Node.div ~attrs:(Attr.class_ [ "astryx-banner__description" ]) d ]
          | _ -> []
        in
        let icon_el =
          match icon with
          | Some custom ->
            [ Vdom.Node.div
                ~attrs:(Attr.class_ [ "astryx-banner__icon" ] @ Attr.aria "hidden" "true")
                [ custom ]
            ]
          | None ->
            (match status_icon_name status with
             | None -> []
             | Some name ->
               [ Vdom.Node.div
                   ~attrs:(Attr.class_ [ "astryx-banner__icon" ] @ Attr.aria "hidden" "true")
                   [ Icon.view
                       ~size:Icon.Md
                       ~color:(Option.value (status_icon_color status) ~default:Icon.Inherit)
                       ~name
                       ()
                   ]
               ])
        in
        let content_area =
          if not show_content
          then []
          else
            [ Vdom.Node.div
                ~attrs:
                  (Attr.class_
                     ([ "astryx-banner__content" ]
                      @ (if is_card then [ "astryx-banner__content--card" ] else []))
                   @ (if has_toggle then [ Vdom.Attr.create "id" content_id ] else []))
                children
            ]
        in
        let root_classes =
          Attr.class_
            ([ "astryx-banner"
             ; container_class container
             ; elevation_class elevation
             ]
             @ [ (if is_card && (match elevation with Button.E_none -> false | _ -> true)
                 then "astryx-banner--rounded"
                 else "") ])
        in
        Vdom.Node.div
          ~attrs:
            (root_classes
             @ Common.Attr.data "component" "Banner"
             @ Common.Attr.data "status" status
             @ [ Vdom.Attr.create "id" id
               ; Vdom.Attr.on_focusin on_focusin
               ; Vdom.Attr.on_pointerdown on_pointerdown
               ]
             @ attrs)
          ([ Vdom.Node.div
               ~attrs:header_classes
               (icon_el
                @ [ Vdom.Node.div
                      ~attrs:
                        (Attr.class_
                           ([ "astryx-banner__body" ]
                            @ (if Option.is_some end_content then [ "astryx-banner__body--with-end" ] else [])))
                      ([ Vdom.Node.div ~attrs:(Attr.class_ [ "astryx-banner__title" ]) title ]
                       @ description_el)
                  ]
                @ end_area)
           ]
           @ content_area)))
;;
