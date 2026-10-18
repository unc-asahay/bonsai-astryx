(** ScrollableArea — mirrors Astryx's ScrollableArea/ScrollableArea.tsx: a native
    scroll viewport with axis-aware accessibility.

    The root is the viewport. Its single child is a normal block content box
    with a 100% minimum size; children participate in that box rather than
    directly in the viewport's flex/grid layout. The viewport measures itself
    on mount and re-measures on every signal that can change the geometry
    (viewport and content resize, scroll, content mutations, window resize,
    focus), and publishes the measured state as [data-scroll-*] attributes,
    a [tabindex] (the viewport becomes a tab stop only while a requested axis
    is effectively scrollable), and the overflow/overscroll inline style.

    The four state cells that define the contract, per upstream:

    - {b axis} — which logical axis/axes may scroll: [\`Block], [\`Inline], [\`Both].
      A not-requested axis is reported inactive: not scrollable, and at both
      edges trivially.
    - {b overflow geometry} — content exceeds the client extent by more than
      upstream's 1px tolerance.
    - {b scroll edge state} — [at_start] / [at_end] per axis, normalised
      through the writing mode's reversal so logical edges are stable under RTL
      and vertical modes (see {!Scroll_math}).
    - {b keyboard access} — the viewport carries [role] and [aria-label]
      (from [label]) while it is a keyboard owner; [tabindex] is 0 when an
      effective axis exists, removed otherwise, and -1 when it had the tab
      stop and lost it but still holds focus (so focus is not dropped).

    {2 Divergences, recorded}

    - Upstream's hook (useScrollableArea) also offers a [contentOrViewport]
      keyboard-ownership mode, which attaches {!attachScrollKeyboardDelegation}
      — Tab-focus delegation from an overflowing viewport into its first
      sequential focusable. The ScrollableArea component itself always passes
      [owner: 'viewport'], where upstream attaches nothing, so this port ports
      the component and does not expose the hook mode: no delegation.
    - The measurement is the port's own observer set: ResizeObserver on
      viewport and content, scroll, window resize, MutationObserver on the
      content subtree and on viewport/content class-style attributes, focus
      and blur. Upstream additionally watches font loading, transitions and
      animations, and observes every ancestor's attributes; those signals are
      not ported. A class/style change on content or a resize still
      re-measures, which is the case that matters.
    - The port's overflow/overscroll values are set as direct inline styles
      ([overflow-x]/[overflow-y], [overscroll-behavior-x]/[overscroll-behavior-y]).
      Upstream routes them through stylex dynamic styles ([--x-overflowX]
      variables consumed by generated classes); the computed result is the
      same. The [data-scroll-*] attributes and [tabindex] are preserved
      exactly.
    - Caller attributes land through [attrs] (they compose before the owned
      attributes, so the owned ones win on conflict). Upstream merges caller
      [style] key-by-key with the hook's style; the port owns the single style
      attribute, so sizing is expressed through the [width]/[height]/[...]
      parameters rather than a caller style.
    - No [useTranslator]: [label] is required, as upstream's is. No
      [useDevWarning], no [xstyle]. *)

open! Core
open! Bonsai_web

type axis =
  [ `Block
  | `Inline
  | `Both
  ]

type role =
  [ `Group
  | `Region
  ]

type overscroll =
  [ `Allow
  | `Contain
  ]

type sticky_containment =
  [ `When_scrollable
  | `Always
  ]

(** [view ~label ?axis ?role ?overscroll ?width ?height ?max_width ?min_height
    ?sticky_containment ?padding ?padding_inline ?padding_inline_start
    ?padding_inline_end ?padding_block ?padding_block_start ?padding_block_end
    ?is_full_bleed graph children].

    [label] is the accessible name of the named scroll viewport (upstream
    requires it; defaults are not supplied). Padding is the shared spacing
    scale; per-side values override the broader ones exactly as upstream's
    stylex precedence does ([padding_inline] replaces both inline sides,
    then [padding_inline_start] / [padding_inline_end] replace their side,
    and the same for the block axis).

    [is_full_bleed] lets the viewport escape inherited container padding via
    the [--container-padding-*] variables — set on the content box for its
    descendants, and on any rich-text ancestor for the viewport, matching
    upstream's container system. *)
val view
  :  ?attrs:Vdom.Attr.t list
  -> ?id:string
  -> ?axis:axis
  -> label:string
  -> ?role:role
  -> ?overscroll:overscroll
  -> ?width:Common.Size_value.t
  -> ?height:Common.Size_value.t
  -> ?max_width:Common.Size_value.t
  -> ?min_height:Common.Size_value.t
  -> ?sticky_containment:sticky_containment
  -> ?padding:Common.Spacing.t
  -> ?padding_inline:Common.Spacing.t
  -> ?padding_inline_start:Common.Spacing.t
  -> ?padding_inline_end:Common.Spacing.t
  -> ?padding_block:Common.Spacing.t
  -> ?padding_block_start:Common.Spacing.t
  -> ?padding_block_end:Common.Spacing.t
  -> ?is_full_bleed:bool
  -> Bonsai.graph
  -> Vdom.Node.t list
  -> Vdom.Node.t Bonsai.t
