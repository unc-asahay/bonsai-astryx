(* Spinner — mirrors Astryx's Spinner/Spinner.tsx: an animated loading ring in
   four sizes and four shades.

   Geometry is computed here, not left to a stylesheet: the ring's diameter and
   stroke width live in the upstream SIZES table, the box adds a stroke width on
   each side, and the arc is ARC_FRACTION (0.375) of the circumference. The
   values are emitted as SVG presentation attributes (r, stroke-width,
   stroke-dasharray) exactly as the upstream no-stylesheet render does, so a
   render before the cascade still draws the right ring; the CSS layer then
   paints colors and moves the dash. The public geometry vars upstream registers
   (--spinner-diameter, --spinner-stroke-width, --spinner-arc-fraction, plus the
   box composition) are instead themeable in this port through the
   [--astryx-spinner-d] / [--astryx-spinner-w] pair and the per-size CSS rules
   that declare them: same override surface under a named theme rule, none of
   the CSS.registerProperty machinery (a browser-side registration this port
   does not run).

   Two render arrangements, upstream's order and shape:
   - no label: the span IS the status root; role=status, accessible name from
     ?aria_label or the English default 'Loading' (upstream's en source for
     @astryx.spinner.loading; no locale table is ported). A plain string label
     cannot name the status element when it lives on the wrapper, so the
     no-label branch always carries an explicit aria-label — upstream does the
     same (the namedByVisibleLabel case only exists in the labelled branch).
   - with a label: a <div> wrapper adds the label below (upstream's column
     layout); the spinner span STILL carries the theme target (size/shade
     classes and data attrs) in both branches - upstream moves the theme target
     to the wrapper when a label renders, but a single theme target keeps one
     themed rule working in both cases, so this port keeps it on the span. The
     inner spinner span also keeps role=status and is named by the visible
     label via aria-labelledby (label text) when there is no explicit
     aria_label - never both (WCAG 4.1.2, upstream's own comment). A non-string
     label (label_node) cannot be referenced, so it names the status element
     from ?aria_label or the default instead.

   Divergences, all recorded rather than dropped:
   - [xstyle]/[className]/[style] collapse into one [?attrs], port-wide.
   - No [useTranslator]: the default accessible name is the English 'Loading'.
   - No [useId]: [id] defaults to 'astryx-spinner' and callers who mount many
     spinners pass distinct ids; a repeated default id would make
     aria-labelledby ambiguous (upstream's useId would not).
   - No [syncRotationPhase] (Web Animations pinning): the port's CSS animation
     starts each ring at its own mount; the upstream phase pinning exists so
     spinners mounted seconds apart stay visually in phase.
   - No CSS.registerProperty for the resolved geometry vars; the CSS keyframes
     read the inline --astryx-spinner-circumference, which the port always
     emits as a <length> (never a bare number), so calc() arithmetic cannot be
     poisoned by a unitless 0.

   Sizes: sm (10px ring, 2px stroke), md (14/3), lg (18/3), xl (28/4) — the box
   is the ring plus the stroke on each side (xl draws a 28px ring in a 36px
   box). Shades: default (accent ring over track), subtle (secondary text),
   on_media (on-dark, translucent track) and inherit (currentColor both, with
   the track at 0.3 opacity). *)

open! Core
open! Bonsai_web

type size =
  | Sm
  | Md  (** the default *)
  | Lg
  | Xl

type shade =
  | Default  (** the default *)
  | Subtle
  | On_media
  | Inherit

let size_geometry = function
  | Sm -> (10., 2.)
  | Md -> (14., 3.)
  | Lg -> (18., 3.)
  | Xl -> (28., 4.)
;;

let size_string = function
  | Sm -> "sm"
  | Md -> "md"
  | Lg -> "lg"
  | Xl -> "xl"
;;

let shade_string = function
  | Default -> "default"
  | Subtle -> "subtle"
  | On_media -> "onMedia"
  | Inherit -> "inherit"
;;

(* 77/255 is upstream's 4D track alpha for onMedia, 0.3 the inherit track. *)
let track_opacity = function
  | Default -> 1.
  | Subtle -> 1.
  | On_media -> 0.3019607843137255
  | Inherit -> 0.3
;;

(* The fraction of the ring the moving arc covers: upstream's ARC_FRACTION. *)
let arc_fraction = 0.375;;

let pi = 3.141592653589793;;

let view
  ?(size = Md)
  ?(shade = Default)
  ?label
  ?label_node
  ?aria_label
  ?(id = "astryx-spinner")
  ?attrs
  ()
  =
  let diameter, border = size_geometry size in
  let frame = diameter +. border *. 2. in
  let circumference = pi *. diameter in
  let arc_length = circumference *. arc_fraction in
  let has_label = Option.is_some label || Option.is_some label_node in
  let label_id = id ^ "-label" in
  let label_is_plain_string = Option.is_some label in
  (* A visible string label names the status element through aria-labelledby;
     an explicit aria_label always wins; otherwise the localized-at-source
     default 'Loading' (upstream's @astryx.spinner.loading). *)
  let resolved_aria_label =
    match aria_label, label_is_plain_string with
    | Some a, _ -> Some a
    | None, false -> Some "Loading"
    | None, true -> None
  in
  let spinner_attrs =
    [ Vdom.Attr.create "role" "status" ]
    @ (match resolved_aria_label with
       | Some a -> Common.Attr.aria "label" a
       | None -> Common.Attr.aria "labelledby" label_id)
    @ Common.Attr.class_
        [ "astryx-spinner"
        ; sprintf "astryx-spinner--%s" (size_string size)
        ; sprintf "astryx-spinner--%s" (shade_string shade)
        ]
    @ Common.Attr.data "component" "Spinner"
    @ Common.Attr.data "size" (size_string size)
    @ Common.Attr.data "shade" (shade_string shade)
  in
  let circle_attrs radius stroke_width =
    [ Vdom.Attr.create "cx" "50%"
    ; Vdom.Attr.create "cy" "50%"
    ; Vdom.Attr.create "r" (sprintf "%g" radius)
    ; Vdom.Attr.create "stroke-width" (sprintf "%g" stroke_width)
    ]
  in
  let svg =
    Vdom.Node.create_svg
      "svg"
      ~attrs:
        ([ Vdom.Attr.create "width" (sprintf "%g" frame)
         ; Vdom.Attr.create "height" (sprintf "%g" frame)
         ; Vdom.Attr.class_ "astryx-spinner__ring"
         ]
        @ Common.Attr.aria "hidden" "true")
      [ (* track: the full circle under the arc *)
        Vdom.Node.create_svg
          "circle"
          ~attrs:
            (circle_attrs (diameter /. 2.) border
            @ [ Vdom.Attr.create "fill" "none"
              ; Vdom.Attr.create "stroke-opacity"
                  (sprintf "%g" (track_opacity shade))
              ; Vdom.Attr.create "class" "astryx-spinner__track"
              ])
          []
      ; (* arc: the same geometry, dashed to ARC_FRACTION of the ring, with a
           keyframes animation over stroke-dashoffset. The circumference is
           emitted inline as a <length> so the keyframe's calc() has a real
           length to negate (upstream registers the same var for the same
           reason). *)
        Vdom.Node.create_svg
          "circle"
          ~attrs:
            (circle_attrs (diameter /. 2.) border
            @ [ Vdom.Attr.create "fill" "none"
              ; Vdom.Attr.create "stroke-dasharray"
                  (sprintf "%g %g" arc_length (circumference -. arc_length))
              ; Vdom.Attr.create "class" "astryx-spinner__arc"
              ]
            @ Common.Attr.style
                [ ("--astryx-spinner-circumference", sprintf "%gpx" circumference)
                ])
          []
      ]
  in
  let spinner =
    Vdom.Node.span ~attrs:(spinner_attrs @ Option.value ~default:[] attrs) [ svg ]
  in
  if not has_label then spinner
  else
    Vdom.Node.div
      ~attrs:
        (Common.Attr.class_ [ "astryx-spinner-wrapper" ]
        @ Common.Attr.data "component" "Spinner"
        @ Common.Attr.data "size" (size_string size)
        @ Common.Attr.data "shade" (shade_string shade)
        @ Option.value ~default:[] attrs)
      ([ spinner ]
      @ (match label with
         | Some l ->
           [ Text.view
               ~id:label_id
               ~type_:Text.Body
               ~weight:Text.Bold
               [ Vdom.Node.text l ]
           ]
         | None ->
           (match label_node with Some n -> [ n ] | None -> [])
         ))
;;
