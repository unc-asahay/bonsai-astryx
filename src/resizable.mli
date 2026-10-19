(** Resizable — a resizable panel and the separator that resizes it.

    Upstream: packages/core/src/Resizable/ — [useResizable.ts] (the region
    hook), [ResizeHandle.tsx] (the separator) and [utils.ts] (the size
    vocabulary). Upstream ships a hook and a component; the port keeps both,
    because the split is the API:

    - {!create} is the hook. It owns the region's size, its bounds, its
      collapse state and its persistence, and returns a {!region} — the port's
      equivalent of upstream's [ResizableRegion] and its [ResizableProps] in
      one record.
    - {!handle_view} is the component. It renders the separator: the divider
      line, the wider invisible grab zone, the pill grip, the ARIA and the
      keyboard handling.
    - {!view} is the two composed into the panel / separator / content layout
      that upstream's stories build by hand.

    {2 The region}

    A region is a [Bonsai.t] of a {!region}: the graph recomputes the size
    whenever it changes, and the handle reads the value the way upstream's
    handle reads the props object it is handed.

    - {b The size} is in pixels and is clamped into the bounds on every
      change. With [~snaps] configured the region can only rest on a snap
      point — the nearest one to the requested size — so a pixel step would
      snap straight back.
    - {b The bounds}: [~min_size] and [~max_size] are pixel sizes or
      percentages of the [~basis]. A maximum may be unbounded (the default),
      in which case the region reports the extent it could fill as its
      [aria-valuemax] but does not clamp to it.
    - {b Collapse}: a [~collapsible] region collapses to zero when it is
      dragged below [~collapsed_size] (40px by default), and expands again
      when it is dragged back over that threshold. {!region.collapse} and
      {!region.expand} do the same thing programmatically, and expanding
      restores the size the region had before it collapsed.
    - {b Controlled collapse}: pass [~is_collapsed] and the caller owns the
      collapse state — the region reports the transition through
      [~on_collapse_change] and changes nothing itself.
    - {b Persistence}: with [~auto_save_id] the size and the collapse state
      are written to [localStorage] under upstream's [astryx-resizable:]
      prefix, and read back when the region is created.

    {2 The separator}

    - {b The ARIA}: the separator is [role=separator] with
      [aria-orientation] (a horizontal panel is separated by a vertical
      line), [aria-valuenow], [aria-valuemin], [aria-valuemax],
      [aria-valuetext] while the panel is collapsed, [aria-label] and
      [aria-disabled]. A collapsed panel's real size (0) sits below
      [aria-valuemin], which is invalid per WCAG 4.1.2, so the announced
      value is clamped to the minimum and the true state is announced
      through [aria-valuetext] instead.
    - {b The keyboard}: the separator is a tab stop ([tabindex=0], or -1 when
      it is disabled) and the arrow keys resize the panel by 10px (50px with
      Shift). Left and down shrink, right and up grow, except under a
      reversed layout or a right-to-left one, where they swap. [Home] moves
      the panel to its minimum and [End] to its configured maximum — not to
      the reported stand-in an unbounded region has. With snap points
      configured an arrow moves to the adjacent snap point instead of by a
      pixel. [Enter] toggles the collapse of a collapsible region.
    - {b The pointer}: the grab zone is a wider, invisible target around the
      divider that takes the pointer for the whole gesture, so a drag that
      crosses an embedded frame is not lost. The resize cursor is held over
      the body for the length of the gesture.
    - {b The pill}: the grip indicator sits on the panel's side by default and
      flips to the other side when the panel collapses, so it stays
      reachable. [~pill_placement] pins it instead, and [~is_always_visible:false]
      reveals it only on hover and focus.

    {2 Divergences from upstream}

    - {b The hook is a node, not a function call}: upstream's
      [useResizable] is called during render; the port's {!create} is a
      [Bonsai.t], so the region is a graph value and the callbacks it takes
      are nodes too.
    - {b No [containerRef]}: upstream observes the content box of a container
      element and resolves a percentage against it. The port takes the basis
      as a number ([~basis]) that the caller measures and feeds in, so a live
      container basis is the caller's to keep up to date. Without one, the
      basis is the viewport's width — upstream's released behaviour, which
      uses the window width on both axes.
    - {b A percentage default} is resolved once, against the viewport basis,
      when the region is created; the bounds keep following the basis.
    - {b No [pointercancel]}: the house vdom has no [on_pointercancel], so an
      interrupted gesture ends at the next pointer-up. A cancelled gesture
      still releases the frozen basis, through the region's
      [on_resize_cancel].
    - {b No theme props}: upstream's [themeProps('resize-handle')] and
      [themeProps('resize-handle-pill')] have no theme layer here. The pill
      carries upstream's [astryx-resize-handle-pill] class as well as the
      port's own, so a theme can still target it.
    - {b Labels are English}: upstream's [aria-label] and its "Collapsed"
      [aria-valuetext] come from a translator; the port spells them out.
    - {b No [ResizeHandle] props passthrough}: upstream spreads the rest of
      its props onto the separator; the port takes an [~attrs] list
      instead.

    {2 The pure helpers}

    Exposed for the same reason the other ports expose theirs: the
    arithmetic is testable without a DOM. *)

open! Core
open! Bonsai_web

type direction =
  | Horizontal
  | Vertical

type position =
  | Inline
  | Overlay

type pill_placement =
  | Start
  | End
  | Center
  | Auto

(** The one pixel bound a percentage carries: a floor ([At_least]) or a
    ceiling ([At_most]), never both. *)
type percent_bound =
  | At_least of float
  | At_most of float

(** A size: pixels, or a percentage of the region's basis with one pixel
    bound. *)
type size =
  | Px of float
  | Percent of { value : float ; bound : percent_bound }

(** [percent ~value ~bound] is upstream's [percent] helper: a percentage with
    exactly one pixel floor or ceiling. *)
val percent : value:float -> bound:percent_bound -> size

(** The region: the size a resizable panel holds, and the gesture surface the
    separator drives. *)
type region =
  { size : float
  (** The current size in pixels. Zero while the region is collapsed, as
      upstream reports it. *)
  ; is_collapsed : bool
  ; min_size_px : float
  ; max_size_px : float
  (** The configured maximum. [Float.infinity] when the region is unbounded. *)
  ; effective_max_px : float option
  (** The maximum the separator reports as [aria-valuemax]: the configured
      maximum when there is one, otherwise the measured extent the region
      could fill — never below the size it currently reports. *)
  ; snaps : float list
  ; collapsed_size : float
  ; collapsible : bool
  ; direction : direction
  ; auto_save_id : string option
  ; on_resize_start : unit Effect.t
  (** Freeze the size the gesture's deltas are measured from, and the basis
      they are measured against. *)
  ; on_resize_move : float -> unit Effect.t
  (** Report a delta, in pixels, since the gesture started. *)
  ; on_resize_end : unit Effect.t
  (** End the gesture and release the frozen basis. *)
  ; on_resize_cancel : unit Effect.t
  ; collapse : unit Effect.t
  ; expand : unit Effect.t
  ; resize : float -> unit Effect.t
  (** Select a size in pixels, clamped into the bounds. An invalid size is
      ignored. *)
  ; pending_step : float ref
  (** The keyboard steps that have been handled but are not in the model
      yet. Key repeat delivers several events before the next render, and
      each of them is measured against the size the region had when it was
      handled - so the steps accumulate and the last event carries the
      whole total, and holding the arrow key keeps growing the region. *)
  ; pending_snap : int ref
  (** The same, for the snap points: how many snap points the keyboard has
      moved since the model last caught up. *)
  }

(** [create] is upstream's [useResizable]: the region, its size and the
    gesture the separator drives.

    - [~default_size] the initial size (250px by default). A persisted size
      wins over it.
    - [~min_size] the smallest size the region takes (50px by default).
    - [~max_size] the largest size the region takes. Unbounded by default.
    - [~direction] the axis the region resizes along. It must match the
      direction given to {!handle_view}.
    - [~collapsible] whether the region can collapse to nothing.
    - [~collapsed_size] the size at which a drag collapses the region (40px
      by default).
    - [~snaps] the pixel sizes the region may rest on.
    - [~auto_save_id] the [localStorage] key the size and the collapse state
      are persisted under.
    - [~default_is_collapsed] the initial collapse state, when the region is
      collapsible and uncontrolled.
    - [~is_collapsed] the controlled collapse state. When it is given, the
      caller owns the state: [collapse] and [expand] report through
      [~on_collapse_change] and change nothing themselves.
    - [~on_size_change] called with the new size, in pixels, on every change.
    - [~on_collapse_change] called with the new collapse state.
    - [~basis] the number a percentage size is a share of. The viewport's
      width by default. *)
val create
  :  ?default_size:size
  -> ?min_size:size
  -> ?max_size:size
  -> ?direction:direction
  -> ?collapsible:bool
  -> ?collapsed_size:float
  -> ?snaps:float list
  -> ?auto_save_id:string
  -> ?default_is_collapsed:bool
  -> ?is_collapsed:bool Bonsai.t
  -> ?on_size_change:(float -> unit Effect.t) Bonsai.t
  -> ?on_collapse_change:(bool -> unit Effect.t) Bonsai.t
  -> ?basis:float Bonsai.t
  -> Bonsai.graph
  -> region Bonsai.t

(** The separator between two resizable panels.

    - [~id] the element's id.
    - [~attrs] extra attributes for the separator.
    - [~direction] the axis the panels are laid out along. It must match the
      direction of the region.
    - [~position] [Inline] puts the separator in the flow between the
      panels; [Overlay] positions it absolutely inside a panel, for a parent
      that clips its overflow.
    - [~is_reversed] reverses the drag direction, for a handle that controls
      a panel on its end side.
    - [~is_disabled] makes the separator inert: no drag, no keyboard, and
      [aria-disabled] with [tabindex=-1].
    - [~has_divider] draws the 1px divider line. The line is the separator;
      the grab zone around it is invisible.
    - [~is_always_visible] shows the pill at rest. With [false] it appears
      on hover and focus only.
    - [~pill_placement] which side of the divider the pill sits on.
    - [~label] the separator's accessible name ("Resize handle" by
      default).
    - [~children] replaces the pill with the caller's own grip. *)
val handle_view
  :  ?id:string
  -> ?attrs:Vdom.Attr.t list
  -> ?direction:direction
  -> ?position:position
  -> ?is_reversed:bool
  -> ?is_disabled:bool
  -> ?has_divider:bool
  -> ?is_always_visible:bool
  -> ?pill_placement:pill_placement
  -> ?label:string
  -> ?children:Vdom.Node.t list
  -> resizable:region Bonsai.t
  -> Bonsai.graph
  -> Vdom.Node.t Bonsai.t

(** The composed view: the resizable panel, the separator between it and the
    content, and the content itself.

    Takes the region's configuration (the same arguments as {!create}) and the
    separator's own ([~has_divider], [~is_always_visible], [~pill_placement],
    [~is_reversed], [~is_disabled], [~label]).

    - [~panel] the content of the resizable side, as a function of the
      region's current size in pixels.
    - [~content] the content of the other side. *)
val view
  :  ?id:string
  -> ?attrs:Vdom.Attr.t list
  -> ?default_size:size
  -> ?min_size:size
  -> ?max_size:size
  -> ?direction:direction
  -> ?collapsible:bool
  -> ?collapsed_size:float
  -> ?snaps:float list
  -> ?auto_save_id:string
  -> ?default_is_collapsed:bool
  -> ?is_collapsed:bool Bonsai.t
  -> ?on_size_change:(float -> unit Effect.t) Bonsai.t
  -> ?on_collapse_change:(bool -> unit Effect.t) Bonsai.t
  -> ?basis:float Bonsai.t
  -> ?has_divider:bool
  -> ?is_always_visible:bool
  -> ?pill_placement:pill_placement
  -> ?is_reversed:bool
  -> ?is_disabled:bool
  -> ?label:string
  -> ?children:Vdom.Node.t list
  -> ?panel:(float -> Vdom.Node.t list)
  -> ?content:Vdom.Node.t list
  -> Bonsai.graph
  -> Vdom.Node.t Bonsai.t

(** {2 Pure helpers — no DOM.} *)

(** [clamp_size size min max snaps] is upstream's [clampSize]: the size
    clamped into the bounds, and snapped to the nearest snap point when there
    are any. *)
val clamp_size : float -> float -> float -> float list -> float

(** [resolve_size size ~basis] resolves a size against its basis: pixels are
    themselves, a percentage is a rounded share of the basis with its one
    pixel bound applied. *)
val resolve_size : size -> basis:float -> float

(** [adjacent_snap_point ~snaps ~min ~max ~size ~direction ~count] is the
    snap point [count] points away from the region's current size ([direction]
    grows, [-1] shrinks). *)
val adjacent_snap_point
  :  snaps:float list
  -> min:float
  -> max:float
  -> size:float
  -> direction:int
  -> count:int
  -> float
