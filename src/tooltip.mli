(** A short message attached to a trigger, shown while the trigger is hovered or focused.

    The tooltip owns the message and the anchor owns the association: the wrapper that holds the
    trigger is the element that points at the message with [aria-describedby], and it carries that
    attribute only while the tooltip is showing — upstream does the same, setting the attribute when
    the layer opens and restoring whatever was there when it closes.

    {2 The anchor is a wrapper, and why}

    Upstream targets the control element itself: it reads the wrapper's first child and merges
    [aria-describedby] onto it. The port cannot — a [Vdom] tree is a value, and a component cannot
    mutate a node its caller built — so the attribute goes on the wrapper the port owns, which is
    the element that {i is} the anchor in this tree. The DOM the caller sees is otherwise the same.

    {2 The hover delay, and how it stopped being a divergence}

    [delay_ms] is upstream's [delay], defaulting to the same 200 ms: hovering opens after the pause,
    focusing opens at once, and leaving closes at once and cancels a timer that has not fired.

    This was written down here as *not ported*, on the grounds that a timer's callback cannot reach a
    component's state setter. That was wrong. [Vdom.Attr.create_hook] exists, [Vdom.Attr.Hooks.Make]
    builds one, and a hook's input can carry a [unit Effect.t] that [Effect.Expert] runs — the focus
    hooks inside virtual_dom's own [attr.ml] are the worked example. {!Common.Delay_hook} is the
    port's version: its input says [Some delay] while the pointer is present and [None] the moment it
    leaves, so a changed input cancels rather than races. The lesson generalizes further than this
    component — it is also what lets {!Dialog} call [showModal] when a *value* changes rather than
    only when an event fires.

    {2 Not ported, with reasons}

    - {b TVision} ([touch] mode: whether a tap opens the tooltip). This port has no touch handling
      anywhere yet; a mode that is never exercised is a mode that is not ported.
    - {b The Layer}. Upstream positions through its [Layer] subsystem — a portal into the top layer,
      viewport-inset handling, flipping and an outlet. The port positions the message as an ordinary
      absolutely positioned element beside its anchor, which is the convention {!Dropdown_menu}
      already established and documents. The divergence that buys: an ancestor with [overflow:
      hidden] clips the message, and no stacking context is escaped. *)

open! Core
open! Bonsai_web

(** Where the message sits relative to its anchor. Upstream's [LayerPlacement]. *)
type placement =
  | Above
  | Below
  | Start
  | End

(** How the message lines up along that axis. Upstream's [LayerAlignment]. *)
type alignment =
  | Start
  | Center
  | End

val view
  :  ?attrs:Vdom.Attr.t list
  -> ?placement:placement
  -> ?alignment:alignment
  -> ?delay_ms:float
  -> ?is_open:bool
  -> id:string
  -> content:string
  -> trigger:Vdom.Node.t
  -> Bonsai.graph
  -> Vdom.Node.t Bonsai.t
(** [view ~id ~content ~trigger graph]. The graph is the last argument because the tooltip owns its
    own open/close state, the same shape {!Dropdown_menu.view} uses. [id] is the message element's id — the thing the anchor's
    [aria-describedby] points at, so it has to be unique on the page.

    [trigger] is the node the message is attached to. It is rendered inside a wrapper that is made
    [position: relative] so the message can be placed against it, and that wrapper is where
    [aria-describedby] appears for as long as the message is open.

    Hovering opens it after [delay_ms] (200 ms, as upstream); focusing opens it immediately, because
    a keyboard user has already committed to the control; leaving closes it and cancels a pending
    timer. [is_open] makes the state the caller's: passing it disables the open/close events
    entirely, which is how a caller renders a tooltip that is open for a reason of its own. *)
