(** Carousel — a horizontal scroll container with edge-fade overflow indication
    and optional prev/next controls.

    Upstream: packages/core/src/Carousel/Carousel.tsx (727 LOC) over
    {v hooks/useScrollOverflow.ts} and {v hooks/isRtlElement.ts}.

    The container measures its own scroll geometry with a vdom hook attached to
    the scroller (the house pattern from {!Scrollable_area}), and re-renders the
    edge-fade/button state as the geometry changes. Items are data: each one is
    wrapped in a slide group. {b Divergences} (see the .ml header for the full
    accounting): no imperative handle (Bonsai has no ref API; the built-in
    buttons replicate scrollNext/scrollPrev semantics), no post-commit focus
    handoff when a nav button disables under the user, the button overlay
    renders inline instead of on the popup top layer, and labels are English
    (i18n not ported). *)

open! Core
open! Bonsai_web

val view
  :  ?id:string
  -> ?attrs:Vdom.Attr.t list
  -> ?gap:Common.Spacing.t
  (** Gap between items — upstream's spacing-scale values 0, 0.5, 1, 1.5, 2, 3, 4.
      Default: [S1]. *)
  -> ?has_buttons:bool
  (** Show prev/next pills when the content scrolls. Default: [true]. *)
  -> ?has_edge_fade:bool
  (** Gradient fade at overflowing edges. Default: [true]. *)
  -> ?has_loop:bool
  (** Wrap-around scrolling at the edges (only while the content overflows).
      Default: [false]. *)
  -> ?has_snap:bool
  (** [scroll-snap] on the items. Default: [false]. *)
  -> ?padding:Common.Spacing.t
  (** Inline padding inside the scroll area, up to [S10]. *)
  -> ?aria_label:string
  (** Accessible name of the labelled region. Default: ["Carousel"]. *)
  -> items:Vdom.Node.t list
  -> Bonsai.graph
  -> Vdom.Node.t Bonsai.t
(** [view ~items graph] renders one carousel: a labelled region containing a
    keyboard-focusable horizontal scroller ([aria-roledescription="carousel"]),
    one [role="group"] / [aria-roledescription="slide"] wrapper per item named
    [Slide N of M], and (unless [~has_buttons:false]) prev/next pills wired to
    the same native-scroll machinery as upstream — RTL-aware, reduced-motion
    aware, and wrap-aware under [~has_loop:true]. *)
