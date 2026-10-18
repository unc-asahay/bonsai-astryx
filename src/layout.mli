(** Layout — the five-slot primitive: header, start, content, end, footer.

    A [Layout] arranges its regions like a doc frame: an optional header on
    top, a middle row (optional start panel / content / optional end panel),
    and an optional footer on the bottom. [height] decides whether the layout
    fills its container with the content area scrolling ([Fill], the default)
    or grows with its content ([Auto]).

    {2 API shape}

    Four small views compose the regions: {!header}, {!footer}, {!panel} and
    {!content}. They are plain node builders — no [graph] — because none of
    them hold state; a caller passes the node to the matching slot argument:
    [Layout.view ~header:(Layout.header ()) ~content:(Layout.content ()) ()].

    {2 The slot context problem, named}

    Upstream threads three React contexts so a region knows which slot it
    occupies and what the layout's defaults are:
    - {b area} — panel's divider sits on the side facing the content, so the
      panel needs to know start vs end. The port answers it structurally: the
      panel is the middle row's {i first} or {i last} child, so the CSS picks
      the side with [:first-child] / [:last-child] and no value travels at all.
    - {b slots present} — header/footer/start/end presence decides which edges
      of content and panel carry outer padding. Again structural: the CSS asks
      [:has] on the layout's inner and middle wrappers.
    - {b divider default} — [default_has_dividers] on the layout, inherited
      when nested layouts do not restate it, falls through to [false]. The
      port carries it as [data-astryx-default-dividers] on the {i inner}
      element, emitted only when the argument is given — that is upstream's
      "context only exists when the prop is set" rule, so nested inheritance
      works — and each header/footer resolves it with a small vdom hook that
      writes [data-astryx-divider="true"] on the element, or removes the
      attribute, after each patch. [has_divider] given explicitly skips the
      look-up. The one visible difference from upstream: the attribute appears
      one patch after mount, and only in a browser/jSDOM that runs vdom hooks.

    {2 Named divergences}

    - [ref] forwarding is not part of the house component API.
    - [themeProps] has no counterpart; the port carries the house marker
      [data-astryx-component].
    - [LayoutPanel.resizable] (the [useResizable] hook) is not ported —
      Resizable is not yet in the port. The [width] argument is used instead;
      a caller that needs a resize handle must manage it itself.
    - The padding values are inline (the house's per-instance rule) rather
      than StyleX atomic classes; [data-astryx-padding] carries the step for
      the harness.
    - [overflow: clip] is the base of content/panel exactly as upstream, with
      [is_scrollable] promoting it to [auto].

    {2 Content width}

    [content_width] takes {!Common.Size_value.t}: [Px] for numbers (treated as
    pixels), [Css] for strings used as written. The width applies to header,
    content, footer and panel frames via [--layout-content-width]; content is
    centred ([margin-inline: auto]) when narrower than the space. Widths that
    can take part in the alignment arithmetic (pixel/length/calc/min/max/clamp
    values) get the internal path: with one panel the panel stays on the
    content-width frame while the content extends to the opposite open edge;
    percentage and intrinsic values take the constrained path where the
    composition stays centred. *)

open! Core
open! Bonsai_web

(** Upstream [LayoutHeight]: [fill] (content scrolls internally, default) or
    [auto] (layout grows with content). *)
type height =
  | Fill
  | Auto
[@@deriving sexp_of]

(** The five-slot frame. [content] wins over [children] when both are given
    (upstream's [content ?? children]); with neither, an empty shell renders.
    [default_has_dividers] applies to headers/footers that do not pass
    [has_divider] themselves, and cascades to nested layouts that do not
    restate it. [padding] is a spacing step applied to this layout's own
    regions, not inherited by nested layouts; [S0] is full-bleed. *)
val view
  :  ?attrs:Vdom.Attr.t list
  -> ?id:string
  -> ?content:Vdom.Node.t
  -> ?content_width:Common.Size_value.t
  -> ?default_has_dividers:bool
  -> ?end_:Vdom.Node.t
  -> ?footer:Vdom.Node.t
  -> ?header:Vdom.Node.t
  -> ?height:height
  -> ?padding:Common.Spacing.t
  -> ?children:Vdom.Node.t list
  -> ?start:Vdom.Node.t
  -> unit
  -> Vdom.Node.t

(** Top bar. [has_divider] adds the themed bottom border; when [None] the
    nearest [Layout.view]'s [default_has_dividers] decides, then [false]. The
    [role] should be [banner] only for a site-wide header; [label] names the
    landmark. [padding_block_end] overrides only the bottom edge of [padding]
    (a tab strip that should dock on the divider). [height] is a length
    ([Px] or a CSS string). *)
val header
  :  ?attrs:Vdom.Attr.t list
  -> ?id:string
  -> ?has_divider:bool
  -> ?height:Common.Size_value.t
  -> ?label:string
  -> ?padding:Common.Spacing.t
  -> ?padding_block_end:Common.Spacing.t
  -> ?role:string
  -> Vdom.Node.t list
  -> unit
  -> Vdom.Node.t

(** Bottom bar; [has_divider] draws the top border under the same default
    rules; [role] should be [contentinfo] only site-wide. *)
val footer
  :  ?attrs:Vdom.Attr.t list
  -> ?id:string
  -> ?has_divider:bool
  -> ?height:Common.Size_value.t
  -> ?label:string
  -> ?padding:Common.Spacing.t
  -> ?role:string
  -> Vdom.Node.t list
  -> unit
  -> Vdom.Node.t

(** Scrollable content area. The divider/padding interplay is automatic: with
    a header or footer present and no divider, the facing padding collapses so
    the visual flow is seamless; with no header/footer at all, the outer
    padding goes on the container edge. [is_scrollable] is [true] by default;
    set [false] for auto-height layouts where sticky positioning needs the
    parent to scroll. [role] should be [main] only for the page's primary
    content. *)
val content
  :  ?attrs:Vdom.Attr.t list
  -> ?id:string
  -> ?is_scrollable:bool
  -> ?label:string
  -> ?padding:Common.Spacing.t
  -> ?role:string
  -> Vdom.Node.t list
  -> unit
  -> Vdom.Node.t

(** Side panel for the start/end slots. The divider side is structural — the
    CSS sees which sibling slot this is — so only [has_divider] matters;
    without one, the facing spacing collapses into the content. [width] is a
    length; [is_scrollable] defaults [true]. [role] should be [navigation] or
    [complementary] only for top-level layouts. *)
val panel
  :  ?attrs:Vdom.Attr.t list
  -> ?id:string
  -> ?has_divider:bool
  -> ?is_scrollable:bool
  -> ?label:string
  -> ?padding:Common.Spacing.t
  -> ?role:string
  -> ?width:Common.Size_value.t
  -> Vdom.Node.t list
  -> unit
  -> Vdom.Node.t
