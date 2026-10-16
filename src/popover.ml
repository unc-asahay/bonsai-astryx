open! Core
open! Bonsai_web
open Js_of_ocaml

type placement =
  | Below
  | Above
  | Start
  | End

type alignment =
  | Align_start
  | Align_center
  | Align_end

type role =
  | Dialog
  | No_role

(* --------------------------------------------------------------------------------------------- *)
(* Focus: in on open, back on close                                                               *)
(* --------------------------------------------------------------------------------------------- *)
(* This is its own hook rather than part of the layer mechanism, because it is this component's rule
   and not the mechanism's: the mechanism knows a layer opened; only the popover knows where focus
   should land inside it.

   It runs on the *root*, which holds both the anchor and the surface, so it can find the trigger when
   focus has to go back. Two details are the whole of it:

   - the generated close button is not a candidate. It sits outside the content wrapper, and that is
     precisely what excludes it from initial focus: it is meant to be reachable by keyboard, not to be
     where focus lands.
   - focus is asked for on the next frame. The surface is display:none until the layer mechanism shows
     it, and the two hooks run in unspecified order after the same DOM patch - so focusing here and now
     would silently do nothing whenever this ran first. Same reason the dialog focuses after showModal. *)

module Autofocus_hook = struct
  module T = struct
    module State = struct
      type t = { mutable was_open : bool }

      let create () = { was_open = false }
    end

    module Input = struct
      type t =
        { is_open : bool
        ; has_autofocus : bool
        }

      let sexp_of_t { is_open; has_autofocus } =
        Sexp.List
          [ Sexp.Atom (Bool.to_string is_open); Sexp.Atom (Bool.to_string has_autofocus) ]
      ;;

      let combine left _ = left
    end

    let focusable_selector =
      "button, [href], input, select, textarea, [tabindex]:not([tabindex=\"-1\"])"
    ;;

    let query (el : Dom_html.element Js.t) (selector : string) : Dom_html.element Js.t option =
      Js.Opt.to_option
        (Js.Unsafe.meth_call el "querySelector" [| Js.Unsafe.inject (Js.string selector) |])
    ;;

    let focus (el : Dom_html.element Js.t) = ignore (Js.Unsafe.meth_call el "focus" [||])

    let contains (root : Dom_html.element Js.t) (el : Dom_html.element Js.t) : bool =
      Js.to_bool (Js.Unsafe.meth_call root "contains" [| Js.Unsafe.inject el |])
    ;;

    let active_element () : Dom_html.element Js.t =
      Js.Unsafe.get (Js.Unsafe.pure_js_expr "document") "activeElement"
    ;;

    let apply (state : State.t) (input : Input.t) (el : Dom_html.element Js.t) =
      let opened = input.is_open && not state.was_open in
      let closed = (not input.is_open) && state.was_open in
      state.was_open <- input.is_open;
      if opened && input.has_autofocus
      then (
        let target =
          match query el ".astryx-popover__content" with
          | Some content -> Option.first_some (query content focusable_selector) (Some el)
          | None -> Some el
        in
        Option.iter target ~f:(fun target ->
          Menu_focus.focus_on_next_frame (fun () -> focus target)))
      else if closed
      then (
        (* Back to the trigger, but only if focus was inside: a dismissal the person did not ask for
           must not yank focus out of wherever they had moved it to. *)
        let active = active_element () in
        if contains el active
        then (
          match query el ".astryx-popover__anchor" with
          | None -> ()
          | Some anchor -> Option.iter (query anchor "button, [role=\"button\"]") ~f:focus))
    ;;

    let init _ _ = State.create ()
    let on_mount input state el = apply state input el
    let on_mount = `Schedule_immediately_after_this_dom_patch_completes on_mount
    let update ~old_input:_ ~new_input state el = apply state new_input el
    let destroy _ _ _ = ()
  end

  module Hook = Vdom.Attr.Hooks.Make (T)

  let attr ~is_open ~has_autofocus () =
    Vdom.Attr.create_hook
      "astryx-popover-autofocus"
      (Hook.create { T.Input.is_open; has_autofocus })
  ;;
end

(* --------------------------------------------------------------------------------------------- *)
(* The component                                                                                  *)
(* --------------------------------------------------------------------------------------------- *)

let placement_class = function
  | Below -> "astryx-popover--below"
  | Above -> "astryx-popover--above"
  | Start -> "astryx-popover--start"
  | End -> "astryx-popover--end"
;;

let alignment_class = function
  | Align_start -> "astryx-popover--align-start"
  | Align_center -> "astryx-popover--align-center"
  | Align_end -> "astryx-popover--align-end"
;;

let view
  ?(attrs = [])
  ?(id = "astryx-popover")
  ?(placement = Below)
  ?(alignment = Align_start)
  ?(width = "auto")
  ?(padding = Common.Spacing.S3)
  ?label
  ?(role = Dialog)
  ?(is_modal = true)
  ?(has_close_button = true)
  ?(close_button_label = "Close popover")
  ?(has_auto_focus = true)
  ?(has_light_dismiss = true)
  ?(has_escape_dismiss = true)
  ?(is_enabled = true)
  ~trigger
  ~content
  ~is_open
  ~on_open_change
  ()
  =
  let surface_id = id ^ "-surface" in
  (* `popover="auto"` is what hands the platform light dismiss *and* Escape. They are one attribute, so
     asking for one without the other is not expressible: this takes the reading that keeps the surface
     alive until the application closes it, and the mli says so. *)
  let platform_dismisses = has_light_dismiss && has_escape_dismiss in
  let close () = on_open_change false in
  let trigger_wrapper =
    Vdom.Node.span
      ~attrs:
        (Common.Attr.class_ [ "astryx-popover__anchor" ]
         @ (if is_enabled
            then
              [ Common.Layer_trigger_hook.attr
                  ~controls:surface_id
                  ~is_open
                  ~on_toggle:(on_open_change (not is_open))
                  ()
              ]
            else []))
      [ trigger ]
  in
  let surface =
    Vdom.Node.div
      ~attrs:
        ([ Vdom.Attr.create "id" surface_id
         ; Vdom.Attr.create "popover" (if platform_dismisses then "auto" else "manual")
           (* Focusable so it can hold focus when a popover has no control of its own to give it to. *)
         ; Vdom.Attr.create "tabindex" "-1"
         ]
         @ (match role with
            | Dialog ->
              Vdom.Attr.create "role" "dialog"
              :: (if is_modal then [ Vdom.Attr.create "aria-modal" "true" ] else [])
            | No_role -> [])
         @ (match label with
            | Some label -> [ Vdom.Attr.create "aria-label" label ]
            | None -> [])
         @ Common.Attr.class_
             [ "astryx-popover"
             ; placement_class placement
             ; alignment_class alignment
             ; (if String.equal width "auto"
                then "astryx-popover--match-trigger"
                else "astryx-popover--custom-width")
             ; Printf.sprintf "astryx-popover--padding-%s" (Common.Spacing.step padding)
             ]
         @ Common.Attr.data "component" "Popover"
         @ [ Vdom.Attr.create
               "style"
               (Printf.sprintf
                  "--astryx-popover-padding: %s;%s"
                  (Common.Spacing.var padding)
                  (if String.equal width "auto"
                   then ""
                   else Printf.sprintf " --astryx-popover-width: %s;" width))
           ]
         @ [ Common.Layer_hook.attr ~is_open ~on_platform_close:(close ()) ])
      (Vdom.Node.div ~attrs:(Common.Attr.class_ [ "astryx-popover__content" ]) [ content ]
       :: (if has_close_button
           then
             [ Vdom.Node.button
                 ~attrs:
                   ([ Vdom.Attr.create "type" "button"
                    ; Vdom.Attr.create "aria-label" close_button_label
                    ; Vdom.Attr.on_click (fun _ -> close ())
                    ]
                    @ Common.Attr.class_ [ "astryx-popover__close" ])
                 []
             ]
           else []))
  in
  Vdom.Node.div
    ~attrs:
      (Common.Attr.class_ [ "astryx-popover__root" ]
       @ [ Autofocus_hook.attr ~is_open ~has_autofocus:has_auto_focus () ]
       @ Common.Attr.data "component" "Popover"
       @ attrs)
    [ trigger_wrapper; surface ]
;;
