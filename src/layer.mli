(** Layer — the shared geometry of the overlay family.

    Upstream's [Layer] is the app-level [LayerProvider] plus [useLayer]; the rendering
    half of [useLayer] assembles a [popover] surface — the native Popover API opens it
    (already proven in this port as {!Common.Layer_hook} / {!Common.Layer_trigger_hook}),
    CSS anchor positioning places it, and a viewport gutter/cap contract keeps it on
    screen. The placement maths in [useLayer.tsx] is mostly the fallback for engines
    without [showPopover]; this port has no fallback (stated in {!Popover}). What is left
    to port is the *rules* — and every rule is a pure function, so the gate can press
    both branches of the browser's anchor positioning without a browser.

    {2 The provider and the inset}

    Upstream threads the app-declared [inset] — a persistent bar floating over a
    viewport edge (a phone nav bar, a docked toolbar) — through React context, and every
    layer writes the values inline on itself. This port has no React context, so
    {!Provider.view} writes the same four custom properties on its own element and lets
    them inherit: the port's layers are in-place (no portal), so the gutter in
    [assets/components.css] reads [var(--astryx-layer-inset-*, 0px)] exactly as
    upstream's does — calc(max(spacing, env(safe-area-inset-X)) + declared).
    An edge that is not declared sets nothing, so it reads [0px] through the gutter's
    fallback. The provider is [display: contents]: it adds no box, and custom properties
    inherit through it.

    {2 The rules}

    - {!position_area}: the [position-area] for a placement/alignment pair, in the
      [self-*] keyword family. The family is upstream's choice and the port keeps the
      comment with it: the inline axis resolves against the layer's own direction, so it
      mirrors in RTL without placement-specific JS, and mixing physical keywords with
      [self-*] computes to [none] — which pins the layer to a viewport corner.
    - {!position_try_fallbacks}: flips first, then the named slide options; a centered
      layer keeps its one-sided spans ahead of the full span so it slides the least
      distance first. The slide names are {!slide_rule_name}s and are defined by the
      static sheet in [assets/components.css] ({!slide_rules_css}).
    - {!self_alignment}: while the anchor is out of view, an aligned layer pins its
      alignment [unsafe] toward the anchor instead of being squeezed into the narrowest
      strip at the viewport edge; a visible anchor or a centered layer stays on the
      browser's default. The port does not observe the anchor (no IntersectionObserver),
      so the value is the caller's to supply; the fixture presses both answers.
    - {!gutter_classes} / {!margin_classes}: which viewport edges keep the gutter, and
      the placement-axis margins — the anchor clearance on the edge facing the anchor,
      the gutter on the far edge. [offset] travels as [--_astryx-layer-clearance] too,
      which is how the slide rules keep the clearance when a slide lands.
    - {!surface_style} / {!surface_attrs}: the inline anchor wiring and the classes an
      anchored surface needs, composed from the rules above ([position-anchor],
      [position-area], [position-try-fallbacks], optional [align-self]/[justify-self] and
      clearance).

    {2 Named divergences}

    - **The slide rules ship in the stylesheet, not from JS.** Upstream installs the 24
      rules from a layout effect ([ensureSlideRules]); this port has no document handle
      at module scope, so the sheet is static in [assets/components.css].
      {!slide_rules_css} is the generator, and the component gate asserts the shipped
      file contains exactly what it returns.
    - **No dismissal stack.** Upstream's [layerStack.ts] dispatches Escape to one owner
      because its layers are [popover="manual"] with JS dismissal. This port's layers are
      [popover="auto"], and the platform's close watcher already owns "one Escape".
    - **No touch trigger.** [useTouchTrigger] / [isActionTrigger] are not ported — a
      touch model for hover-type layers, and the gates drive the mouse.
    - **{!Popover} keeps its own [placement]/[alignment] copies** for now. A later
      milestone re-exports these destructively, per the mechanism-owns-types rule.

    {2 Naming}

    [placement] and [alignment] are regular variants compared with [Poly.equal]
    (physical_axis is not a thing here — these are logical placements). *)

open! Core
open! Bonsai_web

type placement =
  | Below
  | Above
  | Start
  | End
(** Which side of the anchor the layer sits on, in logical terms: the block axis is
    [Above]/[Below], the inline axis [Start]/[End]. *)

type alignment =
  | Align_start
  | Align_center
  | Align_end
(** Alignment along the placement axis. *)

type side =
  | Same
  | Opposite
(** Which side of the trigger a slide option lands on. *)

type inset =
  { block_start : Common.Size_value.t option
  ; block_end : Common.Size_value.t option
  ; inline_start : Common.Size_value.t option
  ; inline_end : Common.Size_value.t option
  }
(** The app-declared inset, one field per viewport edge. {!Common.Size_value.Px} is
    pixels, {!Common.Size_value.Css} is a CSS length used as written; [None] on an edge
    sets nothing (the gutter's fallback reads [0px]). *)

type self_alignment =
  { property : [ `Align_self | `Justify_self ]
  ; value : string
  }
(** Upstream's [getSelfAlignment] answer: the CSS property to pin and the [unsafe]
    value. *)

val inset
  :  ?block_start:Common.Size_value.t
  -> ?block_end:Common.Size_value.t
  -> ?inline_start:Common.Size_value.t
  -> ?inline_end:Common.Size_value.t
  -> unit
  -> inset
(** Smart constructor for {!inset}; an omitted edge stays [None]. *)

val inset_properties : inset -> (string * string) list
(** The custom properties that carry a declared inset to the element whose gutter reads
    them — [--astryx-layer-inset-<edge>] for each declared edge, an undeclared edge set
    nothing. Mirrors upstream's [layerInsetProperties]. *)

val position_area : ?placement:placement -> ?alignment:alignment -> unit -> string
(** The [position-area] for a pair; defaults [Above] / [Align_center] as upstream.
    E.g. [Below, Align_start] is [self-block-end span-self-inline-end]. *)

val position_try_fallbacks : ?placement:placement -> ?alignment:alignment -> unit -> string
(** The [position-try-fallbacks] list: flips first, then the two named slide options
    (and, for a centered pair, the four one-sided spans in between). *)

val gutter_classes : placement:placement -> alignment:alignment -> string list
(** The alignment-axis gutter classes [+ astryx-layer--gutter-*]: the far viewport edge
    of the alignment axis, or both edges when centered. *)

val margin_classes : placement:placement -> offset:Common.Size_value.t option -> string list
(** The placement-axis margin class: [astryx-layer--far-<placement>] with no offset, or
    [astryx-layer--placement-<placement>] with one (the clearance then also travels as
    [--_astryx-layer-clearance]). *)

val self_alignment
  :  placement:placement
  -> alignment:alignment
  -> is_anchor_in_view:bool
  -> self_alignment option
(** [None] on a visible anchor or a centered pair. *)

val slide_rule_name : placement:placement -> alignment:alignment -> side:side -> string
(** The [@position-try] name, e.g. [--astryx-layer-slide-below-center-same]. *)

val slide_rules_css : unit -> string
(** The 24 slide rules as one CSS string, byte-identical to the sheet shipped in
    [assets/components.css]. *)

val surface_style
  :  placement:placement
  -> alignment:alignment
  -> anchor:string
  -> ?offset:Common.Size_value.t
  -> ?is_anchor_in_view:bool
  -> unit
  -> string
(** The inline style an anchored surface carries: [position-anchor], [position-area],
    [position-try-fallbacks], the self-alignment when it applies, and the clearance. *)

val surface_attrs
  :  placement:placement
  -> alignment:alignment
  -> anchor:string
  -> ?offset:Common.Size_value.t
  -> ?is_anchor_in_view:bool
  -> unit
  -> Vdom.Attr.t list
(** The full attribute set for an anchored surface: the [astryx-layer] base class, the
    margin and gutter classes, and {!surface_style}. [anchor] is the element's
    [anchor-name] value. *)

module Provider : sig
  val view
    :  ?attrs:Vdom.Attr.t list
    -> ?inset:inset
    -> Vdom.Node.t list
    -> Vdom.Node.t
  (** The app-level declaration. Sets [--astryx-layer-inset-*] for the edges given —
      inherited by every layer in the subtree — on a [display: contents] element, so it
      adds no box. Both {!Common.Layer_hook} surfaces and the toast viewport read the
      same properties. *)
end
