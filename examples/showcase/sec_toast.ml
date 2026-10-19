(* Toast — the transient notification card, and the viewport that stacks them.

   The card is a single notification; the viewport is the top-level element an
   application mounts once and feeds with toasts. Upstream keeps the two apart
   the same way: a toast is a value, not something the component owns.

   This port has no portal, so the viewport renders where the application puts
   it rather than being hoisted to the document body. The examples below mount
   it inside the example box; it is positioned against the viewport, so it
   still reads as a floating stack. *)

open! Core
open! Bonsai_web

module Toast = Astryx.Toast
module Button = Astryx.Button

open Prelude

let demo (graph : Bonsai.graph) : Vdom.Node.t Bonsai.t =
  let ex_tree label tree = Bonsai.map tree ~f:(fun node -> ex label node) in
  (* What the last dismissal was, so the difference between the automatic
     timeout and a deliberate dismiss is visible. *)
  let dismissed, set_dismissed = Bonsai.state (None : Toast.dismiss_reason option) graph in
  let set_dismissed_f = Bonsai.map set_dismissed ~f:(fun f -> f) in
  let dismissed_readout =
    Bonsai.map dismissed ~f:(fun dismissed ->
      Vdom.Node.div ~attrs:[ Vdom.Attr.create "id" "showcase-toast-dismissed" ]
        [ Vdom.Node.text
            (match dismissed with
             | Some Toast.Auto -> "dismissed: auto"
             | Some Toast.Manual -> "dismissed: manual"
             | None -> "dismissed: -")
        ])
  in
  (* A card with a body, an optional trailing control, and a dismissal
     callback. *)
  let card ?id ?type_ ?body ?end_content ?is_auto_hide ?render_content () =
    Toast.view
      ?id
      ?type_
      ?body
      ?end_content
      ?is_auto_hide
      ?render_content
      ~on_dismiss:(Bonsai.map set_dismissed_f ~f:(fun set_dismissed -> fun reason -> set_dismissed (Some reason)))
      graph
  in
  let info_card = card ~id:"showcase-toast-info" ~type_:Toast.Info ~body:(Vdom.Node.text "Saved successfully") () in
  let error_card =
    card
      ~id:"showcase-toast-error"
      ~type_:Toast.Error
      ~body:(Vdom.Node.text "The upload failed. Try again.")
      ~is_auto_hide:false
      ()
  in
  let action_card =
    card
      ~id:"showcase-toast-action"
      ~type_:Toast.Info
      ~body:(Vdom.Node.text "Message archived")
      ~end_content:(Button.view ~label:"Undo" ~variant:Button.Ghost [])
      ()
  in
  let custom_card =
    card
      ~id:"showcase-toast-custom"
      ~type_:Toast.Info
      ~render_content:(fun content ->
        Vdom.Node.div
          ~attrs:[ Vdom.Attr.class_ "toast-custom" ]
          [ Vdom.Node.div ~attrs:[ Vdom.Attr.class_ "toast-custom__title" ] [ Vdom.Node.text "Custom body" ]
          ; Vdom.Node.div ~attrs:[ Vdom.Attr.class_ "toast-custom__body" ] [ content.body ]
          ])
      ()
  in
  (* The viewport's toasts are a value the application owns: a list the
     application adds to and takes from. *)
  let toasts, set_toasts = Bonsai.state' ([] : Toast.entry list) graph in
  let set_toasts_f = Bonsai.map set_toasts ~f:(fun f -> f) in
  let on_dismiss =
    Bonsai.map2 toasts set_toasts_f ~f:(fun _toasts set_toasts ->
      fun id _reason ->
        set_toasts (fun toasts ->
          List.filter toasts ~f:(fun (entry : Toast.entry) -> not (String.equal entry.id id))))
  in
  let show_toast ?unique_id ~label ~body () =
    Bonsai.map set_toasts_f ~f:(fun set_toasts ->
      Button.view
        ~label
        ~on_click:(fun _ ->
          set_toasts (fun toasts ->
            Toast.add
              toasts
              (Toast.entry
                 (Toast.options ~body:(Vdom.Node.text body) ?unique_id ()))))
        [])
  in
  let show_button = show_toast ~label:"Show a toast" ~body:"Saved successfully" () in
  (* The same unique id: the second toast replaces the first instead of
     stacking behind it. *)
  let show_again_button =
    show_toast ~unique_id:"showcase-toast-save" ~label:"Show it again" ~body:"Saved again" ()
  in
  let count_readout =
    Bonsai.map toasts ~f:(fun toasts ->
      Vdom.Node.div ~attrs:[ Vdom.Attr.create "id" "showcase-toast-count" ]
        [ Vdom.Node.text (sprintf "toasts: %d" (List.length toasts)) ])
  in
  let viewport =
    Toast.viewport
      ~id:"showcase-toast-viewport"
      ~position:Toast.Bottom_end
      ~toasts
      ~on_dismiss
      graph
  in
  let viewport_example =
    Bonsai.map3 show_button count_readout viewport ~f:(fun button count viewport ->
      Vdom.Node.div ~attrs:[ Vdom.Attr.create "id" "showcase-toast-viewport-example" ] [ button; count; viewport ])
  in
  let unique_example =
    Bonsai.map3 show_again_button count_readout dismissed_readout ~f:(fun button count dismissed ->
      Vdom.Node.div ~attrs:[ Vdom.Attr.create "id" "showcase-toast-unique-example" ] [ button; count; dismissed ])
  in
  let examples =
    [ ex_tree "info: transient, dismissable" info_card
    ; ex_tree "error: assertive, stays until dismissed" error_card
    ; ex_tree "with a trailing action" action_card
    ; ex_tree "custom body" custom_card
    ; ex_tree "the viewport: a live stack" viewport_example
    ; ex_tree "the viewport: the same unique id replaces the toast" unique_example
    ]
  in
  Bonsai.map (unwrap_all examples) ~f:(fun examples ->
    section
      ~id:"toast"
      ~title:"Toast"
      ~note:
        "A transient notification. The card is a live region — polite for info, assertive for \
         error — and it dismisses itself after the auto-hide delay unless the pointer or the \
         keyboard is on it, in which case the countdown waits. The viewport is the top-level \
         element an application mounts once: it holds the stack, takes the new toasts at the \
         end, and hands the focus on when the toast that had it leaves. Upstream mounts that \
         viewport through a portal; this port has no portal, so the viewport renders where the \
         application puts it."
      examples)
;;
