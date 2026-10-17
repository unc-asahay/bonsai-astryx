(** Avatars, stacked and overlapping, as a group.

    {2 The overlap, and why it is a margin on every item}

    The overlap is upstream's [round(size * 0.25)], and it is applied as a negative inline-start margin to
    **every** item including the first - not as a negative margin on the container. Upstream says why: a
    negative container margin is defeated the moment a member is wrapped in something of its own, which is
    exactly what a Tooltip does. Every member takes the same offset instead, and the row is spaced by the
    flex gap.

    {2 What the group cannot do here, and why}

    Upstream's group provides its [size] and [shape] to its members through context, so setting them once on
    the group sizes the whole facepile. The port has no contexts by design - the same rule that left Toolbar's
    [SizeProvider] named as a divergence - so the caller passes the size and shape to each avatar, and the
    group's own [size] decides the one thing it can: the overlap. Named, not hidden.

    {2 Roving focus}

    A group is one tab stop with arrow keys between members, which the platform does not provide for buttons;
    it stands on [Common.List_focus], the mechanism ButtonGroup and Toolbar already share. A screen reader is
    told so through [aria-describedby], which is what upstream does as well.

    {2 Divergences}

    - [size] and [shape] are not propagated to the members (no contexts; see above).
    - Upstream's keyboard hint is translated; the port writes the English.
    - [themeProps] has no counterpart.
*)

open! Core
open! Bonsai_web

(** [view ?label ?overflow ?size ?shape ~avatars ()]. [avatars] are the members, already rendered and already
    sliced - upstream's group does not count what fits, its consumer slices and passes an [overflow] chip for
    the rest. [label] names the group. *)
val view
  :  ?attrs:Vdom.Attr.t list
  -> ?id:string
  -> ?label:string
  -> ?overflow:Vdom.Node.t
  -> ?size:Avatar.size
  -> ?shape:Avatar.shape
  -> avatars:Vdom.Node.t list
  -> unit
  -> Vdom.Node.t
