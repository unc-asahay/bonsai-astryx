(** A card whose whole surface is the action.

    It is {!Card} plus one visually-hidden interactive element - an [<a>] when there is an [href], a
    [<button>] when there is not - which carries the accessible name, so the surface itself needs no role.
    That is upstream's shape, and it means the card is reachable and operable as a link or a button by
    assistive technology while looking like a card.

    The click rules are shared with {!Selectable_card}: they are the same mechanism, extracted to
    [Common.Clickable_container] when this component became its second consumer. A surface click fires the
    action; a click on a nested interactive element is left to that element; and a click that ends a text
    selection does nothing.

    {2 Navigation runs through the same safe-url rule as the rest of the port}

    A surface click with an [href] navigates only when {!Common.is_safe_url} accepts it. Upstream says so
    explicitly - the href never passes through a framework, so the shared rule decides once, before the
    target, the modifier keys or the delegated anchor can pick a sink - and it is the same predicate the
    port's security control exports - and the {b attribute} is gated too, not only the navigation. That is a
    deliberate difference from copying the JSX: upstream hands the href to a framework link component and
    React vets the hrefs it writes as attributes, so a [javascript:] href never reaches its DOM. Nothing
    here passes through React, so an unvetted attribute would be a live sink even though this component's
    own click path refuses it. A refused href therefore renders {b inert} - no [href], [role="link"],
    [aria-disabled="true"] - following the rule the rest of this port already follows for a refused value.
    [target = "_blank"], or a ctrl/meta click, opens a new tab with [noopener]; otherwise the click sets
    [location.href]. A middle-click on the surface opens a new tab the way a browser does.

    {2 Divergences}

    - The touch press model is not ported, for the same reason and on the same terms as {!Selectable_card}:
      the contract attribute is emitted and the mouse press paints through [:active], and a touch press
      does not paint. Upstream's controller is [utils/pressFeedback.ts] plus its gesture module.
    - Upstream renders a {i framework} link component, which it takes from a React context so a Next.js
      style router can own client-side transitions. There is no context here, so the port renders a native
      [<a>]. Navigation is a real document navigation, not a client-side transition.
    - A disabled card keeps upstream's treatment - the anchor loses its [href], keeps [role="link"] and
      [aria-disabled], and drops out of the tab order - and its clicks are cancelled rather than ignored.
    - Upstream's [themeProps] marker becomes this port's [data-astryx-component]; the per-variant border and
      overlay colours are CSS classes here rather than compiled StyleX.
*)

open! Bonsai_web
open Js_of_ocaml

(** [view ~label children ()]. [label] is the accessible name of the hidden link or button. [on_click] takes
    the event, as upstream's does, and runs before navigation. *)
val view
  :  ?on_click:(Dom_html.mouseEvent Js.t -> unit Effect.t)
  -> ?href:string
  -> ?target:string
  -> ?is_disabled:bool
  -> ?padding:Common.Spacing.t
  -> ?variant:Card.variant
  -> ?elevation:Button.elevation
  -> ?width:Common.Size_value.t
  -> ?height:Common.Size_value.t
  -> ?max_width:Common.Size_value.t
  -> ?attrs:Vdom.Attr.t list
  -> label:string
  -> Vdom.Node.t list
  -> Vdom.Node.t
