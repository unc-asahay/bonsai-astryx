(** A card that toggles between selected and unselected, with a visually-hidden checkbox carrying the
    state.

    It composes {!Card} for its looks and adds selection on top, the way upstream does. The card surface is
    a plain [<div>] - {b no} role and {b no} tabindex on it - and a visually-hidden [<input type="checkbox">]
    inside provides the role, the accessible name and the checked state. That is upstream's design and it is
    worth keeping: the container holds no semantics of its own to get wrong, and native checkbox behaviour
    (Space toggles, the focus ring, the form association) comes for free.

    Selection is {b controlled}. [is_selected] is the current value and [on_change] is told the next one;
    the component keeps no state of its own, which also makes its view a plain node rather than a
    [Bonsai.t] and lets the jsdom gate render it. Manage the state outside: a single value for radio-style
    selection or a set for multi-select, exactly as upstream's composition hint says.

    {2 Clicking the surface is proxied to the checkbox}

    A click that lands on the card but not on a nested control toggles the selection. A click that lands on
    a nested button, link or other interactive element is left alone so it does not fire twice - that is
    upstream's [INTERACTIVE_SELECTORS] rule, ported. A click that ends a text selection is also ignored, so
    dragging to select the card's text never changes the selection.

    {2 Divergences}

    - The touch press model is {b not} ported. Upstream's [usePressFeedback] installs a document-level
      controller ([utils/pressFeedback.ts], 461 lines, plus its gesture module and the CSS arms that read
      it) that writes [data-astryx-press="on"]/["fading"] on the surface while a finger press is believed,
      with an onset delay and cancels for travel and scroll. This port emits the contract attribute
      ([data-astryx-pressable]) and paints the mouse press through [:active], and a touch press does not
      paint. Porting the model is a campaign on the scale of [Layer], not a milestone.
    - Upstream proxies a genuine surface click by dispatching a synthetic click on the hidden checkbox so a
      framework link or control can handle it. There is no framework here to hand the event to, so the port
      calls [on_change] with the next value directly. The observable behaviour is the same.
    - The clickable container's navigation paths ([href], [target="_blank"], the middle-click open, the
      ctrl/meta modifier branches, the safe-url rule) belong to [Clickable_card] upstream, which shares the
      same hook. They are absent here because [Selectable_card] has no [href].
    - Upstream's [themeProps] marker becomes this port's [data-astryx-component] plus a [data-astryx-selected]
      attribute; the per-variant selected colours are CSS classes here rather than compiled StyleX.
*)

open! Bonsai_web

(** [view ~label ~is_selected ~on_change children ()]. [label] is the accessible name - it becomes the hidden
    checkbox's [aria-label], so it is required. A disabled card stays in the tab order and reports
    [aria-disabled], the same choice upstream makes, so it can still explain itself. *)
val view
  :  ?is_disabled:bool
  -> ?padding:Common.Spacing.t
  -> ?variant:Card.variant
  -> ?elevation:Button.elevation
  -> ?width:Common.Size_value.t
  -> ?height:Common.Size_value.t
  -> ?max_width:Common.Size_value.t
  -> ?attrs:Vdom.Attr.t list
  -> label:string
  -> is_selected:bool
  -> on_change:(bool -> unit Effect.t)
  -> Vdom.Node.t list
  -> Vdom.Node.t
