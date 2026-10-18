(* Thumbnail — mirrors Astryx's Thumbnail/Thumbnail.tsx: a square preview card for
   image attachments.

   Renders per state: a skeleton shimmer while the image loads (isLoading with
   no known source), the image on success, or a placeholder silhouette on
   failure / no source. An upload overlay (scrimmed spinner) shows while an
   existing source is still being processed, and an overlaid remove button
   appears when [on_remove] is set — revealed on hover/keyboard focus by
   default, or always shown.

   The error contract is per-*source*: one state cell remembers the exact
   [src] that failed, so a source that changes gets a fresh load attempt
   instead of inheriting the stale error. That is upstream's [erroredSrc]
   state, reproduced via [Bonsai.state] — the same cell and the same freshness
   test ([src <> errored]) that Avatar's image chain uses.

   Images without [alt] are explicitly decorative (alt="" + role=presentation +
   aria-hidden, matching Avatar): the accessible name then comes from [label]
   (or a caller-provided aria name), else the English "Thumbnail" fallback.
   That name is the group's [role=group] label, the remove button's name
   ("Remove <name>"), and the open button's name ("Open <name>").

   [label] also carries the hover name, as upstream wraps the thumbnail in a
   Tooltip with the same content. The port's Tooltip takes a static trigger,
   and a root computed from the image state cannot be one — the exact reason
   Avatar records for its own Tooltip. Following that precedent, [label] is
   surfaced through the native [title] attribute, which shows the same text on
   hover, and the [role=group] name carries it for assistive technology.

   Deliberate divergences (all recorded in docs/VERIFICATION.md):
   - No useTranslator: the fallback name and all aria strings are the English
     defaults.
   - No useDevWarning: the dev-only "unnamed image" warning is not ported.
   - No useContainerReveal controller: the remove button's hover reveal is
     plain CSS ([@media (hover: hover)] :hover plus :focus-within), so
     keyboard focus still reveals it; upstream's JS convenience arm is not
     ported.
   - No usePressFeedback: the interactive surface is a real <button>, so its
     press paints through the ordinary [:active]; no [data-astryx-press]
     machinery — the same divergence Clickable_card and Selectable_card
     record.
   - The label tooltip is the native [title] attribute, not the Tooltip
     component (see above) — same reason and same record as Avatar's.
*)

open! Core
open! Bonsai_web
open Js_of_ocaml

type show_remove_on =
  [ `Hover
  | `Always
  ]

let placeholder_svg =
  Vdom.Node.create_svg
    "svg"
    ~attrs:
      [ Vdom.Attr.create "width" "24"
      ; Vdom.Attr.create "height" "24"
      ; Vdom.Attr.create "viewBox" "0 0 24 24"
      ; Vdom.Attr.create "fill" "currentColor"
      ; Vdom.Attr.create "aria-hidden" "true"
      ]
    [ Vdom.Node.create_svg
        "path"
        ~attrs:
          [ Vdom.Attr.create
              "d"
              "M21 19V5a2 2 0 0 0-2-2H5a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2M8.5 13.5l2.5 3 3.5-4.5 4.5 6H5l3.5-5.5z"
          ]
        []
    ]
;;

let view
  ?(attrs = [])
  ?src
  ?alt
  ?label
  ?on_remove
  ?on_click
  ?(is_loading = false)
  ?(is_disabled = false)
  ?(show_remove_on : show_remove_on = `Hover)
  ?(id = "astryx-thumbnail")
  ?(component_name = "Thumbnail")
  (graph : Bonsai.graph)
  =
  let errored_src, on_src_failed = Bonsai.state (None : string option) graph in
  let src_pair = Bonsai.both errored_src on_src_failed in
  let accessible_name =
    match (label, alt) with
    | Some l, Some a -> l ^ " — " ^ a
    | Some l, None -> l
    | None, Some a -> a
    | None, None -> "Thumbnail"
  in
  Bonsai.map src_pair ~f:(fun (errored_src, on_src_failed) ->
    let has_src = Option.is_some src in
    let show_image =
      match src, errored_src with
      | Some src, errored -> not (Option.equal String.equal errored (Some src))
      | None, _ -> false
    in
    let show_skeleton = is_loading && not has_src in
    let show_upload_overlay = is_loading && has_src in
    let show_placeholder = ((not is_loading) && not has_src) || (has_src && not show_image) in
    let is_interactive = Option.is_some on_click && not is_disabled && not is_loading in
    let has_remove = Option.is_some on_remove && not is_disabled in
    let is_hover_reveal =
      has_remove && (match show_remove_on with `Hover -> true | `Always -> false)
    in
    let decorative = Option.is_none alt in
    let image_content =
      (match src with
       | Some listed when show_image ->
         let img_attrs =
           [ Vdom.Attr.create "src" listed
           ; Vdom.Attr.create "alt" (Option.value alt ~default:"")
           ; Vdom.Attr.create "class" "astryx-thumbnail__img"
           ; Vdom.Attr.on_error (fun _ -> on_src_failed (Some listed))
           ]
           @
           (if decorative
            then
              [ Vdom.Attr.create "role" "presentation"
              ; Vdom.Attr.create "aria-hidden" "true"
              ]
            else [])
         in
         [ Vdom.Node.create "img" ~attrs:img_attrs [] ]
       | _ -> [])
      @
      (if show_skeleton then [ Skeleton.view ~radius:Skeleton.R2 () ] else [])
      @
      (if show_placeholder
       then
         [ Vdom.Node.div
             ~attrs:[ Vdom.Attr.create "class" "astryx-thumbnail__placeholder" ]
             [ placeholder_svg ]
         ]
       else [])
    in
    let open_button =
      if is_interactive
      then
        [ Vdom.Node.create
            "button"
            ~attrs:
              [ Vdom.Attr.create "type" "button"
              ; Vdom.Attr.create "class" "astryx-thumbnail__action"
              ; Vdom.Attr.create "aria-label" ("Open " ^ accessible_name)
              ; Vdom.Attr.on_click
                  (fun (e : Dom_html.mouseEvent Js.t) ->
                    match on_click with
                    | Some f -> f e
                    | None -> Effect.Ignore)
              ]
            image_content
        ]
      else image_content
    in
    let remove_button =
      if has_remove
      then
        let remove (e : Dom_html.mouseEvent Js.t) =
          ignore (Js.Unsafe.meth_call e "stopPropagation" [||]);
          match on_remove with
          | Some f -> f e
          | None -> Effect.Ignore
        in
        [ Vdom.Node.div
            ~attrs:
              (Common.Attr.class_
                 (if is_hover_reveal
                  then
                    [ "astryx-thumbnail__remove-slot"
                    ; "astryx-thumbnail__remove-slot--hover"
                    ]
                  else [ "astryx-thumbnail__remove-slot" ]))
            [ Button.view
                ~label:("Remove " ^ accessible_name)
                ~icon:(Icon.view ~size:Icon.Xsm ~name:"close" ())
                ~variant:Button.Secondary
                ~size:Button.Sm
                ~is_icon_only:true
                ~on_click:remove
                ~component_name:"Button"
                []
            ]
        ]
      else []
    in
    let inner =
      Vdom.Node.div
        ~attrs:
          (Common.Attr.class_
             (if is_interactive
              then
                [ "astryx-thumbnail__surface"
                ; "astryx-thumbnail__surface--interactive"
                ]
              else [ "astryx-thumbnail__surface" ])
           @ Common.Attr.data "component" component_name)
        (open_button
         @
         (if show_image
          then
            [ Vdom.Node.div
                ~attrs:[ Vdom.Attr.create "class" "astryx-thumbnail__inset-border" ]
                []
            ]
          else [])
         @
         (if show_upload_overlay
          then
            [ Vdom.Node.div
                ~attrs:[ Vdom.Attr.create "class" "astryx-thumbnail__upload-overlay" ]
                [ Spinner.view ~size:Spinner.Sm ~shade:Spinner.On_media () ]
            ]
          else [])
         @ remove_button)
    in
    let root_attrs =
      ([ Vdom.Attr.create "role" "group"
       ; Vdom.Attr.create "aria-label" accessible_name
       ; Vdom.Attr.id id
       ]
       @ Common.Attr.class_
           (if is_disabled
            then [ "astryx-thumbnail"; "astryx-thumbnail--disabled" ]
            else [ "astryx-thumbnail" ])
       @ (match label with Some l -> [ Vdom.Attr.create "title" l ] | None -> [])
       @ Common.Attr.data "component" component_name
       @ attrs)
    in
    Vdom.Node.div ~attrs:root_attrs [ inner ])
;;
