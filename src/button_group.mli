(** Buttons joined into one surface: shared edges, one tab stop, arrows to move between members.

    {2 The connected look is CSS here, because there is no context to write it into}

    Upstream's children read a [ButtonGroupContext] and style themselves — which is how a member that
    renders its own layer (a Button with a tooltip, a DropdownMenu) still gets the right edges. This port
    has no context: a child is built before its container sees it. So the edges are drawn by CSS from the
    group, and the rule targets the *button inside* each child rather than the child itself, for exactly
    upstream's reason — a member with a layer renders a wrapper, so [> .astryx-button] would miss it and
    the group would lose its end caps. Upstream hit the same wall and moved those rules out of the group
    and into [Button.tsx]; the port arrives at the same place from the other side.

    {2 One tab stop is behaviour, and it is not free}

    The group is a single tab stop: Tab reaches the group, arrows move *within* it along the orientation,
    Home and End jump to the ends, the ends wrap, and disabled members are skipped. That is the APG
    roving-tabindex technique, and unlike a radio group the platform does **not** provide it for buttons
    — so this component implements it, in the hook at the bottom of the implementation. Every arrow
    movement rewrites [tabindex] on the members: the focused one becomes [0] and the rest [-1], which is
    what makes the next Tab leave the group instead of walking through it.

    {2 Two things are not ported, and are named rather than approximated}

    - **[size] does not propagate.** Upstream's group provides a size through a context and the members
      inherit it unless they override it. With no context, every member states its own size; a group whose
      buttons disagree will look like it, and the showcase shows what that means.
    - **No member may be a layer *owner* that swallows arrows** beyond what the boundary rule handles:
      arrow keys are handled on the group and a member's own layer (a tooltip, a menu) stops propagation
      at its own root, as upstream's [boundarySelector] does. *)

open! Core
open! Bonsai_web

type orientation =
  | Horizontal
  | Vertical
(** Upstream's [ButtonGroupOrientation]. *)

type elevation =
  | None_
  | Low
  | Med
  | High
(** The group's resting shadow. The members share one surface, so the shadow sits on the wrapper and
    lifts them as a unit. *)

val view
  :  ?attrs:Vdom.Attr.t list
  -> ?orientation:orientation
  -> ?elevation:elevation
  -> ?is_disabled:bool
  -> label:string
  -> children:Vdom.Node.t list
  -> unit
  -> Vdom.Node.t
(** [view ~label ~children graph] — one [role="group"] naming itself with [label], containing [children].

    [is_disabled] is announced with [aria-disabled] and, unlike upstream's context-driven version, does
    not reach into the members: a disabled group that silently disabled its buttons would be doing
    something to them the caller cannot see. Disable the members you mean to disable. *)
