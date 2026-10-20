(** BottomSheet — the mobile touch surface that rises from the bottom edge.

    Upstream: [packages/core/src/BottomSheet/] — [BottomSheet.tsx] (the standalone
    host), [BottomSheetPanel.tsx] (the panel), [snapOffsets.ts] (the detent
    geometry) and [useSheetGestures.ts] (the drag machinery).

    {2 What the browser does, and what the port does}

    A standalone sheet is a native [<dialog>]: with a scrim it is opened with
    [showModal()], without one with [show()] — upstream opens it the same way.
    The top layer, the inert page behind, the focus trap, the Escape [cancel]
    event and the [::backdrop] scrim are the platform's, and none of them is
    written here. What the port owns is what upstream owns around that: the
    drag handle and the detents it rests at, the dismissal matrix, the focus
    hand-back, and the entrance and exit motion.

    {2 The geometry}

    A sheet's travel is a distance from fully open, in pixels, and a detent is
    one of those distances. The sheet's own height is always the tallest stop,
    so the stops below it are the caller's {!snap_points}. The arithmetic that
    turns snap points into detents — the viewport-fraction resolution, the
    48px de-duplication, the peek rule, the scrim fade and the direction-clamped
    settle — is a port of upstream's [snapOffsets.ts], which is pure and is
    ported as such.

    A detent is expressed as the sheet's {e visible} height, the way upstream
    expresses it: {!Fraction} of the viewport, {!Percent} of it, or an absolute
    {!Px} height. A stop of a quarter of the sheet or less is a {e peek}: it
    slides below the viewport instead of reflowing to that sliver, and it is
    the only stop that thins the scrim.

    {2 Divergences, named rather than discovered}

    - {b No portal and no outlet.} Upstream's layer runtime can hoist a layer
      into a portal, and the OCaml Layer this port builds on has neither a
      portal nor an outlet, so a sheet is drawn where it is written. The
      native [<dialog>] still supplies the top layer — the platform's own, not
      a React portal — so the sheet is still modal, still traps focus and still
      dims the page. What is lost is the layer depth: a sheet opened over
      another layer does not know about it. (The {!Layer} port records the same
      divergence for the same reason.)
    - {b No shared dismissal stack.} Upstream routes Escape through a stack
      every layer joins, so a layer opened inside the sheet takes the press
      first, and a press during an IME composition is declined. This port has
      no stack: Escape always closes this sheet, and a composition is not
      consulted. (!Dialog} and {!Mobile_nav} record the same divergence.)
    - {b No switcher host.} Upstream's [BottomSheetSwitcher] gives several
      sheets one shared dialog; that is a separate component and is not
      ported here. This port has the standalone sheet only.
    - {b No mobile-keyboard accommodation.} Upstream's fully expanded tall
      sheet holds still while the on-screen keyboard opens and scrolls the
      focused control above it, reading the visual viewport. This port does
      not: the sheet is a fixed surface and the browser's own focus reveal is
      left in place.
    - {b The drag is pointer-only.} Upstream drives the sheet from a touch path
      and a pointer path, with a scroll handoff at the content's edge. This
      port drives it from pointer events only, so the handle drags on a mouse,
      a pen and a finger alike, and the content area does not hand a pull to
      the sheet.
    - {b A live drag re-renders.} Upstream writes the drag's transform
      straight to the element and renders nothing between the drag's first and
      last sample. This port keeps the offset in Bonsai state, so a drag
      re-renders the sheet as it moves. The result is the same; the cost is
      not.
    - {b No theme.} Upstream reads the theme's [bottom-sheet] padding and
      budget. This port has no theme layer, so the content box is inset by
      [var(--spacing-4)] unless [padding] says otherwise, and the height
      budgets are the upstream ones. *)

open! Core
open! Bonsai_web

(** How hard the sheet is to dismiss. Upstream's [DialogPurpose], with upstream's
    matrix: [Info] dismisses on Escape, on a scrim click and on a swipe;
    [Form] protects entered data by blocking the scrim click and the swipe but
    leaves Escape alone; [Required] blocks every implicit dismissal and makes
    the sheet an [alertdialog], because a sheet that refuses every exit is one
    the user has to answer. *)
type purpose =
  | Info
  | Form
  | Required

(** How tall the sheet is. Upstream's [BottomSheetHeight] plus its numeric and
    CSS-length forms.

    - [Hug] fits its content, up to 92% of the viewport.
    - [Capped] is a scrolling mid-height panel, about 62% of the viewport.
    - [Tall] is a near-full panel, about 92% of the viewport.
    - [Custom] is a height of the caller's: {!Common.Size_value.Px} in pixels,
      {!Common.Size_value.Css} as a CSS length. *)
type height =
  | Hug
  | Capped
  | Tall
  | Custom of Common.Size_value.t

(** A height the sheet can rest at when it is dragged, as the sheet's visible
    height. Upstream's [BottomSheetSnapPoint], which is a number or a string;
    here the three forms upstream accepts are three constructors.

    - {!Fraction} of the viewport, in [(0, 1)] — [Fraction 0.5] is half the
      screen, and it tracks a rotation or a window resize.
    - {!Percent} of the viewport, the same thing in the spelling CSS uses.
    - {!Px}, an absolute height that does not scale.

    The sheet's own height is always the tallest stop, so a sheet with no snap
    points opens and closes and springs back from a drag. *)
type snap_point =
  | Fraction of float
  | Percent of float
  | Px of int

val view
  :  ?id:string
  (** The id of the sheet's host element. Defaults to ["astryx-bottom-sheet"]. *)
  -> ?attrs:Vdom.Attr.t list
  (** Extra attributes for the host element. They are applied last, so a
      consumer can override anything above. *)
  -> label:string
  (** The accessible name of the sheet. Upstream requires it — the sheet has no
      built-in heading to derive one from — and so does this port. *)
  -> ?purpose:purpose
  (** How hard the sheet is to dismiss. Defaults to [Info]. *)
  -> ?height:height
  (** The sheet's height budget. Defaults to [Capped]. *)
  -> ?snap_points:snap_point list
  (** The extra heights the sheet can rest at when it is dragged. Defaults to
      none, which gives a sheet that only opens and closes. *)
  -> ?has_scrim:bool
  (** Whether the sheet has a scrim. With one (the default) the sheet is
      modal: the page behind is inert and a click on the scrim dismisses it
      when the [purpose] allows. Without one the sheet is shown non-modally
      and the page behind stays live. *)
  -> ?padding:Common.Spacing.t
  (** The inset of the sheet's content box, on the spacing scale. Upstream's
      default — the theme's [bottom-sheet] padding, or [var(--spacing-4)] —
      is what this port uses when no padding is given. *)
  -> ?final_focus_id:string
  (** The id of the element that receives focus when the sheet closes. Without
      one, the focus goes back to whatever was focused when the sheet opened,
      which is what upstream does with its trigger. *)
  -> ?is_inline:bool
  (** Render the sheet as ordinary markup: no top layer, no modal behaviour, no
      scrim, and the panel visible where it is written. This is the showcase
      path — a page can show several sheets at once, and a gate without a
      browser can still read the structure. *)
  -> is_open:bool Bonsai.t
  (** Whether the sheet is open. The sheet never opens or closes itself: it
      follows this value, and reports every dismissal through
      [on_open_change]. *)
  -> on_open_change:(bool -> unit Effect.t) Bonsai.t
  (** Called when the sheet should close — Escape (unless the [purpose] is
      [Required]), a click on the scrim (only for [Info]), a swipe past the
      dismiss threshold (only for [Info]), or anything the caller's own content
      does. The caller owns the value, so the sheet closes when [is_open]
      becomes false and not before. *)
  -> children:Vdom.Node.t list Bonsai.t
  (** The sheet's content, in the sheet's scrolling content area. *)
  -> Bonsai.graph
  (** The graph the sheet's own state lives in: the drag it is in and the
      detent it rests at. *)
  -> Vdom.Node.t Bonsai.t
(** [view ~label ~is_open ~on_open_change ~children graph].

    Both [is_open] and [on_open_change] are trees, and they have to be: a
    caller holding a state setter cannot produce either as a plain value, and
    the node cannot be built before the value is known. [children] is a tree
    for the same reason.

    The focus moves into the sheet when it opens — onto a descendant marked
    [data-astryx-focus-on-open] if there is one, otherwise onto the sheet
    itself — and back to the element that had it when the sheet closes. The
    sheet traps the focus while it is open, because a modal surface does; that
    is the platform's focus trap, not a hand-written one. *)
