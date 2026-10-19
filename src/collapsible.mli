(** Collapsible — hides and reveals content behind a disclosure trigger.

    Port of upstream [Collapsible] (Collapsible.tsx + CollapsibleGroup.tsx +
    CollapsibleGroupContext.tsx) as one module with two views: [view] is the
    single disclosure unit, [view_group] is the accordion coordinator. The
    coverage entry is the directory, as with Avatar/AvatarStatusDot.

    {2 View — one disclosure unit}

    A root [<div>] carrying a full-width [<button>] trigger (label + chevron)
    and a content [<div>] that hides with [display: none] rather than
    unmounting — upstream's choice, kept: the controlled content stays in the
    DOM so [aria-controls] never dangles and the caller's node identity is
    stable. The trigger carries [aria-expanded] and [aria-controls]; the
    closed state is still a real [<button>] the keyboard can reach.

    The state machine is [{!Use_collapsible}], the same hook Banner drives, so
    a collapsible's disclosure is configured exactly like the hook:
    [{v is_open v}] is controlled (the caller owns the state, [toggle] only
    reports [on_open_change]), otherwise the internal state seeded from
    [default_is_open] (default {b true} — upstream's) is the source of truth
    and [on_open_change] is a notification.

    {2 View_group — the accordion coordinator}

    Upstream coordinates items through a React context: a [Collapsible] with a
    [value] inside a [CollapsibleGroup] defers its open state to the group,
    and the group's [isOpen]/[toggle] reach the item through the context. This
    port has no React context and does not fake one, so the group is {b
    data-driven} instead — the same judgment TreeList made for its
    expansion state: each [item] carries its [value], [trigger], [children]
    and disabled state, the group owns the open set and renders the rows. The
    context has no counterpart, and consequently the "a [Collapsible] used
    inside a [Group] defers itself" flow is expressible only in the group's
    own vocabulary; [value] on [view] is therefore not accepted.

    [mode] is [Single] (default, one item open — opening a closed one closes
    the others, toggling the open one closes it) or [Multiple] (each item
    toggles independently). [value] is the controlled open set (a list; at most
    one element in [Single] mode), [default_value] seeds the uncontrolled
    state, [on_change] reports every change. {i Divergence:} upstream's
    [onChange] returns a [string] in single mode ("", not []) — this port
    reports the open set as a [string list] either way, so an empty list means
    nothing open.

    [has_dividers] gives the accordion row chrome: a wrapper [<div>] in a
    column and each row's own hairline (border-block-start, suppressed on
    [:first-child]) — upstream's reason for the wrapper is that StyleX has no
    child selectors, and the same is true here, so the row draws its own
    divider. [density] (default [Balanced] when dividers are shown, otherwise
    [None]) pads the rows; [chevron_position] is the rows' default, and an
    [item]'s own choice still wins.

    {2 Accessibility}

    The trigger is the system-wide disabled convention: [aria-disabled] with
    [tabindex="-1"] (never the native [disabled] attribute, which would
    swallow a wrapping tooltip's hover), and the activation is guarded in the
    click handler. [aria-expanded]/[aria-controls] link the trigger to its
    content region (the disclosure pattern). The chevron is decorative: the
    Icon is [aria-hidden] by default (no label), so the screen reader hears
    the trigger text and the expanded state only.

    {2 Divergences (stated rather than hidden)}

    - {b No [themeProps]} — upstream's [collapsible], [collapsible-trigger],
      [collapsible-content] and [collapsible-group] theme targets are not
      ported; the port styles by class, as every other component here.
    - {b No [usePressFeedback]} — the touch press model is a named omission
      everywhere in this port (as M28 recorded): the mouse arm is [':active']
      and a touch press does not paint. The contract attribute is emitted and
      the row's pressed overlay is CSS-only.
    - {b [id] is caller-scoped, not [useId]} (as Banner). Pass a distinct id
      per collapsible; the content id is [<id>-content] and the group's row
      content ids are [<id>-<value>-content].
    - {b The group always renders its wrapper} — upstream is DOM-less without
      [has_dividers]; here the coordinator is a [<div>] with no chrome, which
      is the port's cost of a coordinator that owns the rows.
    - {b [on_change] shape} — see above.
    - No i18n: nothing needs translating (the chevron is not labelled). *)

open! Core
open! Bonsai_web

type chevron_position =
  | Start  (** a leading disclosure arrow: points into the row when closed (mirrored under RTL), down when open *)
  | End  (** a trailing indicator: down when closed, up when open (default) *)

type density =
  | Compact
  | Balanced
  | Spacious

type mode =
  | Single  (** at most one item open (default) *)
  | Multiple  (** items toggle independently *)

type item = {
  value : string;
  trigger : Vdom.Node.t;
  children : Vdom.Node.t list;
  is_disabled : bool;
  chevron_position : chevron_position option;
}

val view
  :  ?attrs:Vdom.Attr.t list
  -> ?id:string
  -> ?is_open:bool Bonsai.t
  -> ?is_disabled:bool
  -> ?default_is_open:bool
  -> ?on_open_change:(bool -> unit Effect.t) Bonsai.t
  -> ?chevron_position:chevron_position
  -> trigger:Vdom.Node.t
  -> ?children:Vdom.Node.t list
  -> Bonsai.graph
  -> Vdom.Node.t Bonsai.t
(** [view ~trigger ()]: the standalone disclosure unit. [trigger] is always
    visible; [children] collapse. [is_open] switches to controlled mode;
    [default_is_open] seeds the uncontrolled state (default [true]);
    [on_open_change] reports toggles in both modes; [is_disabled] blocks
    activation and keeps the content in its open state; [chevron_position] is
    [End] by default. *)

val view_group
  :  ?attrs:Vdom.Attr.t list
  -> ?id:string
  -> ?mode:mode
  -> ?value:string list Bonsai.t
  -> ?default_value:string list
  -> ?on_change:(string list -> unit Effect.t) Bonsai.t
  -> ?has_dividers:bool
  -> ?density:density
  -> ?chevron_position:chevron_position
  -> items:item list
  -> Bonsai.graph
  -> Vdom.Node.t Bonsai.t
(** [view_group ~items ()]: the accordion. [items] are the rows (see the
    [item] record); the group owns the open set and the rows report through
    it. [value] is controlled open state, [default_value] seeds the
    uncontrolled state, [on_change] reports, [has_dividers]/[density]/
    [chevron_position] are the group chrome. *)
