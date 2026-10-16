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

    {2 Not ported, with reasons}

    - {b The hover delay} ([delay], 200 ms upstream). Opening the tooltip after a pause needs a timer
      whose callback can reach the component's state setter, and this release offers no such
      primitive: [Bonsai_web.Effect] has no timer, [Effect.after_display] is not exposed, and the
      [setTimeout]-plus-module-ref trick that the entry animation uses works only for a value that
      is *read* later, never for writing state back into the graph. So the port opens immediately on
      enter, which is the difference between a tooltip shown when a pointer crosses a row of icons
      and one shown when it stops on one. Worth a phase 2 with a real clock.
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

    Hover and focus both open it, and either leaving closes it, as upstream does. [is_open] makes the
    state the caller's: passing it disables the open/close events entirely, which is how a caller
    renders a tooltip that is open for a reason of its own. *)
