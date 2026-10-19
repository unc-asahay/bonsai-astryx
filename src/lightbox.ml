(* Lightbox — a fullscreen modal viewer for one image or a gallery.
   Upstream: packages/core/src/Lightbox/Lightbox.tsx (769 LOC), plus the
   state-mechanics of useLightbox.tsx.

   The surface is a native <dialog> opened with showModal(), exactly like
   Dialog: the top layer, the inert page behind and the focus trap are the
   browser's, and a hook puts the element in step with the is_open value
   (the DOM follows the value, the value is the truth). jsdom has no dialog
   behaviour at all, so structural checks mount the dialog closed and the
   live interaction checks live in the browser gate.

   What the port owns:
   - the gallery index (controlled or uncontrolled) with prev/next buttons
     and arrow keys that stay mounted and disabled at the edges, so driving to
     the boundary never unmounts the focused control;
   - the zoom/pan machine for images (double-click, Enter/Space, +/-; drag
     with pointer capture; arrow pan while zoomed) with zoom/pan cancelled on
     every media change and the transform written straight onto the image;
   - the dismissal matrix (Escape always, backdrop click, close button) with
     the drag-release guard: a pan drag that ends over the backdrop must not
     dismiss;
   - the polite live region that mirrors navigation and zoom changes, which
     are otherwise silent to assistive tech (a counter is visual only);
   - the page scroll lock (body overflow saved/restored, simple single-lock
     form) and focus restore to the trigger on close, both inside the hook.

   Named divergences are in lightbox.mli. *)

open! Core
open Js_of_ocaml
open! Bonsai_web

module Attr = Common.Attr

type media_type =
  | Image
  | Video

type media =
  { src : string
  ; alt : string
  ; caption : Vdom.Node.t option
  ; type_ : media_type
  }

let call = Common.call
let is_connected = Common.is_connected

(* ------------------------------------------------------------------ the hook *)

(* The modal state follows the *value*, and the open/close is a DOM operation no
   event handler can do: no vdom event fires when a caller decides to open.
   This is Dialog's hook shape (see dialog.ml) plus the lightbox-specific
   tracking: it notices when the rendered index changes and (a) resets the
   zoom/pan so the new item never paints at the previous item's zoom, and
   (b) mirrors the navigation in the polite live region — but only during an
   already-open session, never on mount, never on opening and never on close.
   It also saves/restores body overflow around the open window. *)
module Lightbox_hook = struct
  module T = struct
    module State = struct
      type t =
        { mutable trigger : Dom_html.element Js.t option
        ; mutable last_index : int
        ; mutable was_open : bool
        ; mutable body_overflow : string option
        }

      let create () = { trigger = None; last_index = 0; was_open = false; body_overflow = None }
    end

    module Input = struct
      type t =
        { is_open : bool
        ; index : int
        ; on_reset : unit Effect.t
        ; on_announce : unit Effect.t
        }

      let sexp_of_t _ = Sexp.Atom "lightbox"

      let combine left right =
        { is_open = left.is_open
        ; index = left.index
        ; on_reset = Effect.Many [ left.on_reset; right.on_reset ]
        ; on_announce = Effect.Many [ left.on_announce; right.on_announce ]
        }
      ;;
    end

    let lock_page (state : State.t) =
      match state.body_overflow with
      | Some _ -> ()
      | None ->
        let body = Js.Unsafe.get Dom_html.document "body" in
        let style = Js.Unsafe.get body "style" in
        state.body_overflow
          <- Some (Js.to_string (Js.Unsafe.get style "overflow"));
        Js.Unsafe.set style "overflow" (Js.string "hidden")
    ;;

    let unlock_page (state : State.t) =
      match state.body_overflow with
      | None -> ()
      | Some saved ->
        let body = Js.Unsafe.get Dom_html.document "body" in
        let style = Js.Unsafe.get body "style" in
        Js.Unsafe.set style "overflow" (Js.string saved);
        state.body_overflow <- None
    ;;

    let apply (state : State.t) (input : Input.t) (el : Dom_html.element Js.t) =
      let is_open_now = Js.to_bool (Js.Unsafe.get el "open") in
      if input.is_open && not is_open_now
      then (
        (* Remembered before the modal takes focus, so it can be handed back on
           close — upstream captures the same element for the same reason. *)
        let active : Dom_html.element Js.t = Js.Unsafe.get Dom_html.document "activeElement" in
        state.trigger
          <- (if is_connected active then Some (Js.Unsafe.coerce active) else None);
        call el "showModal";
        lock_page state)
      else if (not input.is_open) && is_open_now
      then (
        call el "close";
        unlock_page state;
        (match state.trigger with
         | Some trigger when is_connected trigger ->
           ignore (Js.Unsafe.meth_call trigger "focus" [||])
         | Some _ | None -> ());
        state.trigger <- None);
      (* Reset/announce tracking. The comparisons are against the last *rendered*
         input, so a re-render that leaves index alone is a no-op — which is
         what keeps the reset effect from looping (it re-renders). *)
      if input.is_open
      then (
        if not state.was_open
        then (
          if state.last_index <> input.index
          then Effect.Expert.handle_non_dom_event_exn input.on_reset)
        else if state.last_index <> input.index
        then
          Effect.Expert.handle_non_dom_event_exn
            (Effect.Many [ input.on_reset; input.on_announce ]);
        state.last_index <- input.index;
        state.was_open <- true)
      else state.was_open <- false
    ;;

    let init _ _ = State.create ()

    let on_mount input state el = apply state input el
    let on_mount = `Schedule_immediately_after_this_dom_patch_completes on_mount
    let update ~old_input:_ ~new_input state el = apply state new_input el

    let destroy _ (state : State.t) _ =
      unlock_page state;
      state.trigger <- None
    ;;
  end

  module Hook = Vdom.Attr.Hooks.Make (T)

  let attr ~is_open ~index ~on_reset ~on_announce () =
    Vdom.Attr.create_hook "astryx-lightbox" (Hook.create { T.Input.is_open; index; on_reset; on_announce })
  ;;
end

(* ------------------------------------------------------------------ helpers *)

let client_x (ev : Dom_html.pointerEvent Js.t) : float = Js.Unsafe.get ev "clientX"
let client_y (ev : Dom_html.pointerEvent Js.t) : float = Js.Unsafe.get ev "clientY"
let pointer_id (ev : Dom_html.pointerEvent Js.t) : int = Js.Unsafe.get ev "pointerId"

let capture_pointer (el : Dom_html.element Js.t) (ev : Dom_html.pointerEvent Js.t) =
  match Js.Opt.to_option (Js.Unsafe.get el "setPointerCapture") with
  | None -> ()
  | Some _ -> Js.Unsafe.meth_call el "setPointerCapture" [| Js.Unsafe.inject (pointer_id ev) |]
;;

let key_of (ev : Dom_html.keyboardEvent Js.t) : string =
  Option.value (Common.string_prop (Obj.magic ev : _ Js.t) "key") ~default:""
;;

let is_pan_key (key : string) : bool =
  String.equal key "ArrowLeft"
  || String.equal key "ArrowRight"
  || String.equal key "ArrowUp"
  || String.equal key "ArrowDown"
;;

(* Pan distance per arrow press; offsets move the viewport in the arrow's
   direction (pressing ArrowRight reveals content to the right, so the image
   itself shifts left — negative x). *)
let pan_offset key =
  match key with
  | "ArrowLeft" -> 50., 0.
  | "ArrowRight" -> -50., 0.
  | "ArrowUp" -> 0., 50.
  | "ArrowDown" -> 0., -50.
  | _ -> 0., 0.
;;

(* --------------------------------------------------------------------- view *)

type view_state =
  { zoom : int
  ; pan_x : float
  ; pan_y : float
  ; dragging : bool
  ; message : string option
  }

let initial_view_state = { zoom = 1; pan_x = 0.; pan_y = 0.; dragging = false; message = None }

let view
  ?(id = "astryx-lightbox")
  ?(attrs = [])
  ?index
  ?(default_index = 0)
  ?on_index_change
  ?(has_zoom = false)
  ?(has_auto_play = false)
  ~is_open
  ~on_open_change
  ~(media : media list)
  graph
  =
  let controlled = Option.is_some index in
  let internal_index, set_internal = Bonsai.state default_index graph in
  let vs, set_vs = Bonsai.state initial_view_state graph in
  let effective_index = Option.value_map index ~default:internal_index ~f:Fn.id in
  let on_index_change =
    match on_index_change with
    | Some f -> f
    | None -> Bonsai.return (fun (_ : int) -> Effect.Many [])
  in
  (* A [Both] p2/p3 tree: trees compose pairwise (Cont has no map4), so the
     args are bundled, then de-bundled in the map. The view state, its setter
     and the internal-index setter ride along, exactly as Slider bundles its
     [set_dragging]. *)
  let args_input =
    Bonsai.both (Bonsai.both is_open effective_index)
      (Bonsai.both on_index_change on_open_change)
  in
  Bonsai.both (Bonsai.both args_input (Bonsai.both vs set_vs)) set_internal
  |> Bonsai.map
       ~f:(fun ((((is_open, index), (on_index_change, on_open_change)), (vs, set_vs)),
                set_internal) ->
         let count = List.length media in
         let item =
           if count = 0
           then None
           else Some (List.nth_exn media (min index (count - 1)))
         in
         match item with
         | None ->
           (* Upstream renders nothing when there is no media. *)
           Vdom.Node.none
         | Some item ->
           let is_video = Poly.equal item.type_ Video in
           let is_gallery = count > 1 in
           let is_zoom_target = has_zoom && not is_video in
           let zoomed = is_zoom_target && vs.zoom > 1 in
           let can_prev = is_gallery && index > 0 in
           let can_next = is_gallery && index < count - 1 in
           let media_label =
             if String.is_empty item.alt then "Media viewer" else item.alt
           in
           (* The live-region text for a media change: the alt names it, the
              position keeps the reading in step with the counter. *)
           let nav_message =
             let position = sprintf "%d of %d" (index + 1) count in
             if String.is_empty item.alt
             then sprintf "Image %s" position
             else sprintf "%s, %s" item.alt position
           in
           let reset = set_vs { vs with zoom = 1; pan_x = 0.; pan_y = 0.; dragging = false } in
           let announce = set_vs { vs with message = Some nav_message } in
           let goto delta =
             let next = index + delta in
             if next < 0 || next >= count || next = index
             then Effect.Many []
             else
               Effect.Many
                 [ (if controlled then Effect.Many [] else set_internal next)
                 ; on_index_change next
                 ]
           in
           let toggle_zoom () =
             if not is_zoom_target
             then Effect.Many []
             else if vs.zoom <= 1
             then
               set_vs
                 { vs with zoom = 2; pan_x = 0.; pan_y = 0.; message = Some "Zoomed in" }
             else set_vs
                 { vs with zoom = 1; pan_x = 0.; pan_y = 0.; message = Some "Zoomed out" }
           in
           let on_keydown (ev : Dom_html.keyboardEvent Js.t) =
             let key = key_of ev in
             let consumed () = Common.prevent_default ev in
             if is_zoom_target
             then (
               if String.equal key "+" || String.equal key "="
               then (
                 consumed ();
                 (if vs.zoom <= 1
                  then toggle_zoom ()
                  else Effect.Many []))
               else if String.equal key "-"
               then (
                 consumed ();
                 (if vs.zoom > 1
                  then toggle_zoom ()
                  else Effect.Many []))
               else if zoomed && is_pan_key key
               then (
                 consumed ();
                 let dx, dy = pan_offset key in
                 set_vs { vs with pan_x = vs.pan_x +. dx; pan_y = vs.pan_y +. dy })
               else (
                 match key with
                 | "ArrowLeft" when not zoomed ->
                   consumed ();
                   goto (-1)
                 | "ArrowRight" when not zoomed ->
                   consumed ();
                   goto 1
                 | _ -> Effect.Many []))
             else (
               match key with
               | "ArrowLeft" ->
                 consumed ();
                 goto (-1)
               | "ArrowRight" ->
                 consumed ();
                 goto 1
               | _ -> Effect.Many [])
           in
           let on_wrapper_keydown (ev : Dom_html.keyboardEvent Js.t) =
             let key = key_of ev in
             if String.equal key "Enter" || String.equal key " "
             then (
               Common.prevent_default ev;
               toggle_zoom ())
             else Effect.Many []
           in
           (* Pan by drag: pointer capture on the wrapper, positions taken
              from the drag's start (absolute, so no drift), and a did-drag
              flag the backdrop click handler consumes so releasing a drag
              over the backdrop does not dismiss. *)
           let drag_start = ref None in
           let did_drag = ref false in
           let on_pointer_down (ev : Dom_html.pointerEvent Js.t) =
             if is_video || (not is_zoom_target) || vs.zoom <= 1
             then Effect.Many []
             else (
               let x, y = client_x ev, client_y ev in
               drag_start := Some (x, y, vs.pan_x, vs.pan_y);
               did_drag := false;
               (match Js.Opt.to_option (Js.Unsafe.get ev "currentTarget") with
                | Some el -> capture_pointer (Obj.magic el : Dom_html.element Js.t) ev
                | None -> ());
               set_vs { vs with dragging = true })
           in
           let on_pointer_move (ev : Dom_html.pointerEvent Js.t) =
             match !drag_start with
             | None -> Effect.Many []
             | Some (x0, y0, pan_x0, pan_y0) ->
               did_drag := true;
               set_vs
                 { vs with
                   pan_x = pan_x0 +. (client_x ev -. x0)
                 ; pan_y = pan_y0 +. (client_y ev -. y0)
                 }
           in
           let on_pointer_up (_ev : Dom_html.pointerEvent Js.t) =
             if Option.is_none !drag_start
             then Effect.Many []
             else (
               drag_start := None;
               if vs.dragging then set_vs { vs with dragging = false } else Effect.Many [])
           in
           let on_click (ev : Dom_html.mouseEvent Js.t) =
             if !did_drag
             then (
               did_drag := false;
               Effect.Many [])
             else
               let target = Js.Unsafe.get ev "target" in
               let is_dialog = phys_equal target (Js.Unsafe.get ev "currentTarget") in
               let is_container =
                 Js.to_bool
                   (Js.Unsafe.get (Js.Unsafe.get target "dataset") "astryxLightboxContent")
               in
               if is_dialog || is_container then on_open_change false else Effect.Many []
           in
           let on_cancel (ev : Dom_html.event Js.t) =
             Common.prevent_default ev;
             (* Escape always closes, as Dialog's dismissal matrix does. *)
             on_open_change false
           in
           let transform =
             if not zoomed
             then None
             else
               Some
                 (sprintf
                    "scale(%d) translate(%fpx, %fpx)"
                    vs.zoom
                    (vs.pan_x /. float_of_int vs.zoom)
                    (vs.pan_y /. float_of_int vs.zoom))
           in
           let icon_button ~classes ~label ~icon_name ~on_click ~is_disabled =
             Button.view
               ~label
               ~variant:Button.Ghost
               ~size:Button.Sm
               ~is_icon_only:true
               ~is_disabled
               ~icon:
                 (Icon.view
                    ~size:Icon.Sm
                    ~attrs:(Attr.class_ [ "astryx-lightbox__nav-icon" ])
                    ~name:icon_name
                    ())
               ~component_name:"IconButton"
               ~attrs:(Attr.class_ classes @ [ Vdom.Attr.on_click on_click ])
               []
           in
           let close_button =
             icon_button
               ~classes:[ "astryx-lightbox__close"; "astryx-lightbox__control" ]
               ~label:"Close"
               ~icon_name:"close"
               ~on_click:(fun _ -> on_open_change false)
               ~is_disabled:false
           in
           let prev_button =
             icon_button
               ~classes:
                 [ "astryx-lightbox__nav"
                 ; "astryx-lightbox__nav--prev"
                 ; "astryx-lightbox__control"
                 ]
               ~label:"Previous"
               ~icon_name:"chevronLeft"
               ~on_click:(fun _ -> goto (-1))
               ~is_disabled:(not can_prev)
           in
           let next_button =
             icon_button
               ~classes:
                 [ "astryx-lightbox__nav"
                 ; "astryx-lightbox__nav--next"
                 ; "astryx-lightbox__control"
                 ]
               ~label:"Next"
               ~icon_name:"chevronRight"
               ~on_click:(fun _ -> goto 1)
               ~is_disabled:(not can_next)
           in
           let media_node =
             if is_video
             then
               Vdom.Node.create
                 "video"
                 ~attrs:
                   (Attr.class_ [ "astryx-lightbox__video" ]
                    @ [ Vdom.Attr.create "src" item.src
                      ; Vdom.Attr.create "aria-label" item.alt
                      ; Vdom.Attr.create "controls" ""
                      ]
                    @ (if has_auto_play then [ Vdom.Attr.create "autoplay" "" ] else []))
                 []
             else
               Vdom.Node.create
                 "img"
                 ~attrs:
                   (Attr.class_
                      ( "astryx-lightbox__image"
                      :: (if vs.dragging then [ "astryx-lightbox__image--dragging" ] else []) )
                    @ [ Vdom.Attr.create "src" item.src
                      ; Vdom.Attr.create "alt" item.alt
                      ; Vdom.Attr.create "draggable" "false"
                      ]
                    @ (match transform with
                       | Some t -> [ Vdom.Attr.create "style" ("transform:" ^ t) ]
                       | None -> []))
                 []
           in
           let wrapper =
             Attr.class_
               ( "astryx-lightbox__wrapper"
               :: (if is_zoom_target
                   then
                     [ (if not zoomed
                        then "astryx-lightbox__wrapper--zoomable"
                        else if vs.dragging
                        then "astryx-lightbox__wrapper--dragging"
                        else "astryx-lightbox__wrapper--zoomed")
                     ]
                   else []) )
             @ (if is_zoom_target
                then
                  [ Vdom.Attr.create "role" "button"
                  ; Vdom.Attr.create "tabindex" "0"
                  ; Vdom.Attr.create "aria-pressed" (Bool.to_string zoomed)
                  ; Vdom.Attr.create "aria-label" "Zoom"
                  ; Vdom.Attr.on_keydown on_wrapper_keydown
                  ]
                else [])
             @ (if is_video
                then [ Vdom.Attr.create "data-astryx-lightbox-media" "" ]
                else
                  [ Vdom.Attr.create "data-astryx-lightbox-media" ""
                  ; Vdom.Attr.on_double_click (fun _ -> toggle_zoom ())
                  ; Vdom.Attr.on_pointerdown on_pointer_down
                  ; Vdom.Attr.on_pointermove on_pointer_move
                  ; Vdom.Attr.on_pointerup on_pointer_up
                  ])
           in
           let media_group =
             Vdom.Node.div
               ~attrs:(Attr.class_ [ "astryx-lightbox__media-group" ])
               (Vdom.Node.div ~attrs:wrapper [ media_node ]
                :: (match item.caption with
                    | Some cap ->
                      [ Vdom.Node.div
                          ~attrs:(Attr.class_ [ "astryx-lightbox__caption" ])
                          [ cap ]
                      ]
                    | None -> []))
           in
           let counter =
             Vdom.Node.div
               ~attrs:
                 (Attr.class_ [ "astryx-lightbox__counter" ]
                  @ [ Vdom.Attr.create "aria-hidden" "true" ])
               [ Vdom.Node.text (sprintf "%d / %d" (index + 1) count) ]
           in
           let announcer =
             Vdom.Node.span
               ~attrs:
                 (Attr.class_ [ "astryx-visually-hidden" ]
                  @ Attr.role "status"
                  @ Common.Attr.aria "live" "polite")
               (match vs.message with
                | Some m -> [ Vdom.Node.text m ]
                | None -> [])
           in
           let dialog_attrs =
             Attr.class_ [ "astryx-lightbox" ]
             @ Attr.data "component" "Lightbox"
             @ [ Vdom.Attr.id id
               ; Vdom.Attr.create "aria-label" media_label
               ; Lightbox_hook.attr ~is_open ~index ~on_reset:reset ~on_announce:announce ()
               ; Vdom.Attr.on_keydown on_keydown
               ; Vdom.Attr.on_click on_click
               ; Vdom.Attr.on_cancel on_cancel
               ]
             @ attrs
           in
           Vdom.Node.create
             "dialog"
             ~attrs:dialog_attrs
             [ Vdom.Node.div
                 ~attrs:
                   (Attr.class_ [ "astryx-lightbox__container" ]
                    @ [ Vdom.Attr.create "data-astryx-lightbox-content" "" ])
                 (close_button
                  :: (if is_gallery then prev_button else Vdom.Node.none)
                  :: [ media_group
                     ; (if is_gallery then next_button else Vdom.Node.none)
                     ; (if is_gallery then counter else Vdom.Node.none)
                     ; announcer
                     ])
             ])
;;
