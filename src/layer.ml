(* Layer — the shared geometry of the overlay family.

   Upstream's [Layer] is the app-level [LayerProvider] plus [useLayer], whose rendering
   half assembles a [popover] surface: the native Popover API opens it, CSS anchor
   positioning places it, and a viewport gutter/cap contract keeps it on screen. The
   placement maths in useLayer.tsx is mostly the fallback for engines without
   [showPopover]; this port has no fallback (stated in [popover.mli]) and proved the
   mechanism half in [Common.Layer_hook] / [Common.Layer_trigger_hook]. What is left to
   port is the *rules* — and every rule here is a pure function, so the gate can press
   both branches of the browser's anchor positioning without a browser. *)

open! Core
open! Bonsai_web

type placement =
  | Below
  | Above
  | Start
  | End
[@@deriving sexp_of]

type alignment =
  | Align_start
  | Align_center
  | Align_end

type side =
  | Same
  | Opposite

type inset =
  { block_start : Common.Size_value.t option
  ; block_end : Common.Size_value.t option
  ; inline_start : Common.Size_value.t option
  ; inline_end : Common.Size_value.t option
  }

type self_alignment =
  { property : [ `Align_self | `Justify_self ]
  ; value : string
  }

let placement_str = function
  | Below -> "below"
  | Above -> "above"
  | Start -> "start"
  | End -> "end"
;;

let alignment_str = function
  | Align_start -> "start"
  | Align_center -> "center"
  | Align_end -> "end"
;;

let inset ?block_start ?block_end ?inline_start ?inline_end () =
  { block_start; block_end; inline_start; inline_end }
;;

(* Upstream layerInset.ts: one custom property per declared edge; an undeclared edge
   sets nothing, so it reads [0px] through the gutter's fallback exactly as it does with
   no provider at all. A number is pixels, a string a CSS length. *)
let inset_properties { block_start; block_end; inline_start; inline_end } =
  let edge prop edge =
    Option.map edge ~f:(fun value ->
      (prop, Common.Size_value.to_css value))
  in
  List.filter_opt
    [ edge "--astryx-layer-inset-block-start" block_start
    ; edge "--astryx-layer-inset-block-end" block_end
    ; edge "--astryx-layer-inset-inline-start" inline_start
    ; edge "--astryx-layer-inset-inline-end" inline_end
    ]
;;

(* Upstream getPositionArea. The [self-*] keyword family is deliberate: the inline axis
   resolves against the layer's own direction, so it mirrors in RTL without
   placement-specific JS; the block axis must come from the same family, because mixing
   physical keywords with [self-*] computes to [none] and pins the layer to a viewport
   corner. Ported verbatim; the comment is upstream's, kept with the code. *)
let position_area ?(placement = Above) ?(alignment = Align_center) () =
  match placement, alignment with
  | Above, Align_start -> "self-block-start span-self-inline-end"
  | Above, Align_end -> "self-block-start span-self-inline-start"
  | Above, Align_center -> "self-block-start"
  | Below, Align_start -> "self-block-end span-self-inline-end"
  | Below, Align_end -> "self-block-end span-self-inline-start"
  | Below, Align_center -> "self-block-end"
  | Start, Align_start -> "self-inline-start span-self-block-end"
  | Start, Align_end -> "self-inline-start span-self-block-start"
  | Start, Align_center -> "self-inline-start"
  | End, Align_start -> "self-inline-end span-self-block-end"
  | End, Align_end -> "self-inline-end span-self-block-start"
  | End, Align_center -> "self-inline-end"
;;

let slide_rule_name ~placement ~alignment ~side =
  Printf.sprintf
    "--astryx-layer-slide-%s-%s-%s"
    (placement_str placement)
    (alignment_str alignment)
    (match side with Same -> "same" | Opposite -> "opposite")
;;

(* Upstream getPositionTryFallbacks: flips first, then the named slide options (the
   [@position-try] sheet in assets/components.css); a centered layer keeps its one-sided
   spans ahead of the full span so it slides the least distance first. *)
let position_try_fallbacks ?(placement = Above) ?(alignment = Align_center) () =
  let flips = "flip-block, flip-inline, flip-block flip-inline" in
  let slides =
    Printf.sprintf
      "%s, %s"
      (slide_rule_name ~placement ~alignment ~side:Same)
      (slide_rule_name ~placement ~alignment ~side:Opposite)
  in
  if not (Poly.equal alignment Align_center)
  then Printf.sprintf "%s, %s" flips slides
  else if Poly.equal placement Above || Poly.equal placement Below
  then (
    let same, opposite =
      if Poly.equal placement Above then "top", "bottom" else "bottom", "top"
    in
    Printf.sprintf
      "%s, %s span-left, %s span-right, %s span-left, %s span-right, %s"
      flips same same opposite opposite slides)
  else (
    let same, opposite =
      if Poly.equal placement Start then "left", "right" else "right", "left"
    in
    Printf.sprintf
      "%s, %s span-top, %s span-bottom, %s span-top, %s span-bottom, %s"
      flips same same opposite opposite slides)
;;

(* Upstream getSelfAlignment: while the anchor is out of view, an aligned layer pins its
   alignment [unsafe] toward the anchor instead of being squeezed into the narrowest
   strip at the viewport edge; a visible anchor or a centered layer stays on the
   browser's default. The port does not observe the anchor (no IntersectionObserver), so
   the caller supplies the answer; both branches are pressed in the fixture. *)
let self_alignment ~placement ~alignment ~is_anchor_in_view =
  if is_anchor_in_view || Poly.equal alignment Align_center
  then None
  else (
    let edge =
      if Poly.equal alignment Align_start then "unsafe self-start" else "unsafe self-end"
    in
    match placement with
    | Above | Below -> Some { property = `Justify_self; value = edge }
    | Start | End -> Some { property = `Align_self; value = edge })
;;

(* Upstream getGutterStyles: the far viewport edge of the alignment axis — one edge for
   an aligned layer, both for a centered one. The classes read the gutter from
   assets/components.css. *)
let gutter_classes ~placement ~alignment =
  match placement, alignment with
  | Above, Align_start | Below, Align_start -> [ "astryx-layer--gutter-inline-end" ]
  | Above, Align_end | Below, Align_end -> [ "astryx-layer--gutter-inline-start" ]
  | Above, Align_center | Below, Align_center ->
    [ "astryx-layer--gutter-inline-start"; "astryx-layer--gutter-inline-end" ]
  | Start, Align_start | End, Align_start -> [ "astryx-layer--gutter-block-end" ]
  | Start, Align_end | End, Align_end -> [ "astryx-layer--gutter-block-start" ]
  | Start, Align_center | End, Align_center ->
    [ "astryx-layer--gutter-block-start"; "astryx-layer--gutter-block-end" ]
;;

(* Upstream's placement-margin styles (styles.far* when no offset, styles.placement*
   when one is given). The margin box is what a position option must fit, and the
   browser's overflow shift keeps it inside the viewport, so the clearance stays on the
   anchor-facing edge and the gutter on the far edge. *)
let margin_classes ~placement ~offset =
  [ match offset with
    | None -> Printf.sprintf "astryx-layer--far-%s" (placement_str placement)
    | Some _ -> Printf.sprintf "astryx-layer--placement-%s" (placement_str placement)
  ]
;;

let surface_style ~placement ~alignment ~anchor ?offset ?(is_anchor_in_view = true) () =
  let parts =
    [ Some (Printf.sprintf "position-anchor:%s" anchor)
    ; Some (Printf.sprintf "position-area:%s" (position_area ~placement ~alignment ()))
    ; Some
        (Printf.sprintf
           "position-try-fallbacks:%s"
           (position_try_fallbacks ~placement ~alignment ()))
    ; Option.map
        (self_alignment ~placement ~alignment ~is_anchor_in_view)
        ~f:(fun { property; value } ->
          Printf.sprintf
            "%s:%s"
            (match property with
             | `Align_self -> "align-self"
             | `Justify_self -> "justify-self")
            value)
    ; Option.map offset ~f:(fun offset ->
        Printf.sprintf
          "--_astryx-layer-clearance:%s"
          (Common.Size_value.to_css offset))
    ]
  in
  String.concat ~sep:";" (List.filter_opt parts)
;;

let surface_attrs ~placement ~alignment ~anchor ?offset ?(is_anchor_in_view = true) () =
  let classes =
    "astryx-layer"
    :: (gutter_classes ~placement ~alignment @ margin_classes ~placement ~offset)
  in
  Common.Attr.class_ classes
  @ [ Vdom.Attr.create
        "style"
        (surface_style ~placement ~alignment ~anchor ?offset ~is_anchor_in_view ())
    ]
;;

(* ------------------------------------------------------------------ the slide rules
   layerSlideRules.ts: the four sides, three alignments, two sides = 24 static
   [@position-try] options. The sheet is the port's own because the port has no document
   handle to install one from (upstream's ensureSlideRules) — see the .mli. *)
let clearance = "var(--_astryx-layer-clearance, 0px)"

let spacing = "var(--spacing-4)"

let inset_block_start = "var(--astryx-layer-inset-block-start, 0px)"

let inset_block_end = "var(--astryx-layer-inset-block-end, 0px)"

let inset_inline_start = "var(--astryx-layer-inset-inline-start, 0px)"

let inset_inline_end = "var(--astryx-layer-inset-inline-end, 0px)"

let gutter_block =
  Printf.sprintf
    "calc(max(%s, env(safe-area-inset-top, 0px), env(safe-area-inset-bottom, 0px)) + max(%s, %s))"
    spacing inset_block_start inset_block_end
;;

let gutter_inline =
  Printf.sprintf
    "calc(max(%s, env(safe-area-inset-left, 0px), env(safe-area-inset-right, 0px)) + max(%s, %s))"
    spacing inset_inline_start inset_inline_end
;;

let gutter_block_fallback =
  Printf.sprintf "calc(%s + max(%s, %s))" spacing inset_block_start inset_block_end
;;

let gutter_inline_fallback =
  Printf.sprintf "calc(%s + max(%s, %s))" spacing inset_inline_start inset_inline_end
;;

(* Two declarations, env()-less fallback first — upstream's stylex.firstThatWorks pair. *)
let block_gutter property =
  Printf.sprintf
    "%s:%s;%s:%s;"
    property gutter_block_fallback property gutter_block
;;

let inline_gutter property =
  Printf.sprintf
    "%s:%s;%s:%s;"
    property gutter_inline_fallback property gutter_inline
;;

let area_for = function
  | Above -> "self-block-start span-all"
  | Below -> "self-block-end span-all"
  | Start -> "self-inline-start span-all"
  | End -> "self-inline-end span-all"
;;

let opposite = function
  | Above -> Below
  | Below -> Above
  | Start -> End
  | End -> Start
;;

let placement_margins = function
  | Above ->
    Printf.sprintf "margin-block-end:%s;%s" clearance (block_gutter "margin-block-start")
  | Below ->
    Printf.sprintf "margin-block-start:%s;%s" clearance (block_gutter "margin-block-end")
  | Start ->
    Printf.sprintf "margin-inline-end:%s;%s" clearance (inline_gutter "margin-inline-start")
  | End ->
    Printf.sprintf "margin-inline-start:%s;%s" clearance (inline_gutter "margin-inline-end")
;;

let alignment_margins = function
  | Above | Below ->
    Printf.sprintf
      "%s%sinset-inline-start:0;inset-inline-end:0;"
      (inline_gutter "margin-inline-start")
      (inline_gutter "margin-inline-end")
  | Start | End ->
    Printf.sprintf
      "%s%sinset-block-start:0;inset-block-end:0;"
      (block_gutter "margin-block-start")
      (block_gutter "margin-block-end")
;;

let rule placement alignment side =
  let landing =
    if Poly.equal side Same then placement else opposite placement
  in
  Printf.sprintf
    "@position-try %s{position-area:%s;%s%s}"
    (slide_rule_name ~placement ~alignment ~side)
    (area_for landing)
    (placement_margins landing)
    (alignment_margins landing)
;;

let slide_rules_css () =
  let buffer = Buffer.create 4096 in
  List.iter [ Above; Below; Start; End ] ~f:(fun placement ->
    List.iter [ Align_start; Align_center; Align_end ] ~f:(fun alignment ->
      List.iter [ Same; Opposite ] ~f:(fun side ->
        Buffer.add_string buffer (rule placement alignment side))));
  Buffer.contents buffer
;;

module Provider = struct
  (* Upstream's LayerProvider threads [inset] through React context and every layer
     writes the values inline on itself. The port has no context, so the provider writes
     the custom properties on its own element and lets them inherit: the port's layers
     are in-place (no portal), so the gutter reads them exactly as upstream's does. The
     provider adds no box ([display: contents] keeps inheritance working while leaving
     layout alone); an edge that is not declared sets nothing, so it reads [0px] through
     the gutter's fallback. *)
  let view ?(attrs = []) ?inset children =
    Vdom.Node.div
      ~attrs:
        (Common.Attr.class_ [ "astryx-layer-provider" ]
         @ Common.Attr.style
             (match inset with
             | None -> [ ("display", "contents") ]
             | Some inset -> ("display", "contents") :: inset_properties inset)
         @ attrs)
      children
  ;;
end
