(** A button that stays down: a formatting toggle, a filter chip, a favourite.

    It is the port's Button with a pressed state, which is upstream's shape too - upstream's ToggleButton wraps
    its own Button and adds three things: [aria-pressed], an icon that swaps when pressed, and a width
    reservation.

    {2 The width reservation: named, not implemented}

    A pressed label is drawn heavier than a resting one, and heavier text is wider - so without something to
    stop it, a row of toggles shuffles sideways every time one goes down. Upstream reserves the pressed width
    with a second copy of the label stacked in the same grid cell as the real one, so the cell is already as
    wide as it will ever need to be.

    The port cannot do that through this Button, because the Button owns its own label: the two copies have to
    share a cell, and the label is not something the caller of [Button.view] can interpose a grid around. So
    the reservation is absent rather than faked - a hidden in-flow copy would widen the button instead of
    reserving it, which is worse than the shuffle it was meant to prevent.

    {2 Icon-only, and the tooltip that comes with it}

    An icon-only toggle has no visible label, so its name has to be its label, and upstream adds an automatic
    tooltip from the same string. The port sets a [title] instead of using the Tooltip component, for the
    reason Avatar gives and one more: the port's Tooltip needs a graph, and this view has to be a *pure*
    function of its value. [is_pressed] is state the caller re-renders on, and a view that reached for the graph
    could not be re-run when that state changed - so the whole component is a function of nodes, which is also
    what lets the jsdom gate render it.

    {2 Divergences}

    - Upstream keeps its pressed context in a layer-scoped context, so a toggle inside a menu picks up that
      menu's scope. The port has no contexts by design, so [is_pressed] and [on_pressed_change] are the
      caller's - the same shape DropdownMenu's controlled open has.
    - Upstream's [onPressedChange] receives the new value; the port takes the new value as an effect, which is
      the port's convention for handlers.
    - [themeProps] has no counterpart (the port styles by class).
*)

open! Core
open! Bonsai_web

(** [view ~label ?is_pressed ?on_pressed_change ?pressed_icon ?tooltip ... ()]. [label] is required: it is
    the visible text, or - when [is_icon_only] - the accessible name and the tooltip. [pressed_icon] replaces
    [icon] while pressed, which is upstream's outline-to-filled swap. *)
val view
  :  ?attrs:Vdom.Attr.t list
  -> ?id:string
  -> ?is_pressed:bool
  -> ?on_pressed_change:(bool -> unit Effect.t)
  -> ?size:Button.size
  -> ?variant:Button.variant
  -> ?elevation:Button.elevation
  -> ?is_disabled:bool
  -> ?is_loading:bool
  -> ?icon:Vdom.Node.t
  -> ?is_icon_only:bool
  -> ?pressed_icon:Vdom.Node.t
  -> ?tooltip:string
  -> ?children:Vdom.Node.t list
  -> label:string
  -> unit
  -> Vdom.Node.t
