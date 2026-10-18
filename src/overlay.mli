(** Overlay — content on top of media with a scrim background and automatic
    theme inversion. Same shape as Tooltip: [children] is the base content,
    [content] is what appears on top.

    Upstream has two entry points: the [Overlay] component (a thin wrapper)
    and the [useOverlay] hook for applying overlay behavior to an existing
    container (Card). Both are ported: {!view} and {!use_overlay}.

    {2 The scrim}

    The scrim is an absolutely positioned flex column over the container
    (which the port makes [position: relative; overflow: clip]). It can fill
    the container ([Fill]) or run as a strip along the bottom or top edge
    ([Bottom]/[Top]), and its content can be aligned [Start]/[Center]/[End],
    defaulting to [End]. A dark or light scrim background is painted with the
    library tokens ([--color-overlay] for dark; a translucent white for
    light). [None] paints nothing.

    {2 Visibility, and how it is driven}

    - [Always] — always visible.
    - [Hover] / [Hover_or_focus] — plain CSS: revealed on pointer hover and
      on [:focus-within] inside the container. The hover half is guarded by
      [@media (hover: hover)] so a touch device never shows it; the focus half
      is not guarded.
    - [Focus] — [:focus-within] only.
    - An explicit [is_open] overrides all of the above (controlled mode); the
      scrim is then [inert] while closed, so its content cannot be focused.

    {2 Touch, and the named divergences}

    Upstream toggles hover overlays on touch devices: a tap on the container
    surface (not on a nested interactive element, not ending a text
    selection) opens/closes it, driven by [useSyncExternalStore] against
    [matchMedia("(hover: none)")] plus a [useClickableContainer] filter. The
    port keeps the behavior but implements it as a vdom hook (the house's
    equivalent of an external store): the container carries a hook that reads
    [matchMedia] at mount, subscribes to its [change] event, and holds a
    click listener that applies upstream's nested-interactive and
    text-selection checks in one JS call. The click toggle is attached for
    every container; it is inert unless [show_on] is a hover variant AND the
    device reports no hover.

    - [useClickableContainer]'s [onMouseUp] is not ported: it is upstream's
      middle-click navigation support, which only does anything when the
      container is a clickable card with an href. Overlay passes no href, so
      the handler is a no-op.
    - [ref]/[useMergedRefs] has no counterpart: the house component API does
      not forward refs. The container element is still reachable through the
      hook's ability to do DOM work; consumers that need the raw element are
      out of scope.
    - [themeProps] has no counterpart (the port styles by class and carries
      the house marker [data-astryx-component="Overlay"]).
    - [MediaTheme] is ported inline as a [display: contents] wrapper carrying
      [data-astryx-media="dark"|"light"]; since the house token set resolves
      through [light-dark()], the wrapper also sets [color-scheme] so the
      scrim content picks up the inverted palette. Upstream additionally lets
      a theme provider customize components per media side; there is no theme
      provider here, so only the token inversion is faithful.
    - The border-radius mirror from the first child onto the component's
      wrapper (upstream's [useIsomorphicLayoutEffect]) is ported as a vdom
      hook that reads [getComputedStyle] once after the DOM patch. *)

open! Core
open! Bonsai_web

(** Upstream [OverlayScrimMode]: [dark], [light], or [false] (no scrim and no
    theme inversion). *)
type mode =
  | Dark
  | Light
  | None
[@@deriving sexp_of]

(** Upstream [OverlayPosition]: where the scrim sits — inside the whole
    container ([Fill]) or along the bottom/top edge. *)
type position =
  | Fill
  | Bottom
  | Top
[@@deriving sexp_of]

(** Upstream [OverlayAlign]: how scrim content lines up. *)
type align =
  | Start
  | Center
  | End
[@@deriving sexp_of]

(** Upstream [OverlayShowOn] — CSS-driven visibility trigger. *)
type show_on =
  | Always
  | Hover
  | Hover_or_focus
  | Focus
[@@deriving sexp_of]

(** Result of {!use_overlay}. [container] attaches to the element that is
    being overlaid (sets the positioning classes and the touch hook), and the
    scrim — either pre-rendered ([element]) or built on demand with
    {!type: t}.render_overlay — goes inside it. *)
type t =
  { container : Vdom.Attr.t list
  ; element : Vdom.Node.t option
  ; render_overlay : Vdom.Node.t list -> Vdom.Node.t
  }

(** Apply overlay behavior to an existing container, without a wrapper.
    [content], when given, is pre-rendered as [element]; [render_overlay]
    builds a scrim on demand (same split as useTooltip). *)
val use_overlay
  :  ?show_on:show_on
  -> ?is_open:bool Bonsai.t
  -> ?scrim:mode
  -> ?position:position
  -> ?align:align
  -> ?content:Vdom.Node.t list
  -> Bonsai.graph
  -> t Bonsai.t

(** The [Overlay] component: a container div with the overlay classes, the
    [children], and the scrim containing [content]. [content] is required,
    as upstream. *)
val view
  :  ?attrs:Vdom.Attr.t list
  -> ?id:string
  -> ?show_on:show_on
  -> ?is_open:bool Bonsai.t
  -> ?scrim:mode
  -> ?position:position
  -> ?align:align
  -> ?children:Vdom.Node.t list
  -> content:Vdom.Node.t list
  -> Bonsai.graph
  -> Vdom.Node.t Bonsai.t
