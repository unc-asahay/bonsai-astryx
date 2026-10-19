(** A hover/focus companion: content that appears beside its trigger while the
    trigger (or the card itself) is hovered or focused.

    [Tooltip] is a short text note; this component is for interactive content —
    an info panel with links, a mini profile, a set of actions. Where a tooltip
    is [role="tooltip"], a hover card is [role="dialog"] when [label] gives it a
    name, and [role="group"] when it stays unnamed — a group may validly be
    unnamed, an unnamed dialog may not, which is upstream's rule and this
    port's.

    {2 The grey areas upstream asks the DOM to answer}

    Upstream attaches its listeners to the trigger's first child and reads that
    child's focusability, answers outside-click dismissal through the platform's
    layer stack, and mutates the child's ARIA attributes at runtime. A [Vdom]
    tree is a value — the port can neither mutate a node its caller built nor
    query focusability of a node that does not exist yet — so:

    - The ARIA relationship ([aria-haspopup], [aria-controls],
      [aria-describedby]) goes on the wrapper the port owns, exactly as
      {!Tooltip.anchor} does. The DOM is otherwise the same.
    - [focus_trigger = Focus_auto] reads as [Focus_always]: an element child's
      [focusin] bubbles to the wrapper, and a text-only trigger carries
      [tabindex=0] in the wrapper, so either way focus reaches the wrapper.
    - There is no outside-click dismissal and no top-layer portal. The card is
      an ordinary absolutely positioned element beside its anchor, the
      convention {!Tooltip} and {!Dropdown_menu} established; an ancestor with
      [overflow: hidden] can clip it.

    {2 Not ported, with reasons}

    - {b Touch}. [touch_trigger] (\'auto' / \'tap' / \'none') deliberately
      changes what a tap does on a touch pointer, and this port has no touch
      handling anywhere yet — a mode that is never exercised is a mode that is
      not ported. (Same standing as {!Tooltip}.) The synthesized [mouseenter] a
      tap produces therefore opens the card after [delay_ms], which is one
      hover card per tap on a touch device.
    - {b Focus restore after Escape}. Closing returns focus to the trigger in
      upstream; this port's closing is state, and focus travels with the DOM,
      so the focus that was on the card is lost to [<body>]. {!Tooltip} has the
      same standing.
    - {b Auto-hide when the pointer is between trigger and card}. The card
      [hide_delay_ms] (200 ms) is what bridges the gap — the card stays where
      it is while the pointer walks the gap, and this port keeps that by
      treating the pointer as present while the [hide_delay_ms] timer has not
      fired. *)

open! Core
open! Bonsai_web

type placement =
  | Above
  | Below
  | Start
  | End
(** Which side of the trigger the card opens on. [Above] is upstream's default. *)

type alignment =
  | Start
  | Center
  | End
(** Alignment along the placement axis. [Center] is upstream's default. *)

type focus_trigger =
  | Focus_auto
  | Focus_always
  | Focus_never
(** [Focus_auto] is upstream's [auto]: attach focus listeners. The port cannot
    test focusability of a node that has not been DOM-ed, so it reads as
    [Focus_always] — see the note above. [Focus_never] detaches, for a
    composite widget that owns its own focus model. *)

type hover_indication =
  | Indicate_auto
  | Indicate_show
  | Indicate_hide
(** [Indicate_auto] is upstream's [auto]: the dashed underline is shown for
    text-only triggers, which the port detects by pattern-matching the trigger
    [Vdom.Node.t]. [Indicate_show]/[Indicate_hide] force it on or off. *)

val view
  :  ?attrs:Vdom.Attr.t list
  -> ?placement:placement
  -> ?alignment:alignment
  -> ?delay_ms:float
  -> ?hide_delay_ms:float
  -> ?focus_trigger:focus_trigger
  -> ?is_enabled:bool
  -> ?label:string
  -> ?on_open_change:(bool -> unit Effect.t)
  -> ?has_hover_indication:hover_indication
  -> ?is_open:bool
  -> ?is_default_open:bool
  -> id:string
  -> trigger:Vdom.Node.t
  -> content:Vdom.Node.t
  -> Bonsai.graph
  -> Vdom.Node.t Bonsai.t
(** [view ~id ~trigger ~content graph] renders [trigger] inside a wrapper that
    owns the ARIA relationship, and — while the card is open — the card beside
    it, positioned from [placement]/[alignment].

    [id] is the card's element id, the thing [aria-controls]/[aria-describedby]
    points at; it must be unique on the page.

    Hovering opens after [delay_ms] (300 ms, upstream's default); focusing opens
    at once and immediately, because a keyboard user has already committed to
    the control; leaving closes after [hide_delay_ms] (200 ms), and a pointer
    or focus that lands on the card keeps it open.

    [is_open] makes the state the caller's: passing it disables the
    hover/focus events entirely, and [on_open_change] reports an Escape
    dismissal (with [false]) that the caller did not perform. [is_default_open]
    opens the card on mount, uncontrolled. *)
