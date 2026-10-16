(** A labelled group of related controls that reads as one field.

    {2 The label names the group, not a control}

    It is the same [label] / [description] / [status] surface as any other field, with two differences that
    follow from there being no single control to attach them to: the label points at the *container*
    ([aria-labelledby] on the group) and the status message is [Detached], sitting below the group rather
    than against a control's edge. The port's [Field] already carries both — [is_group_label] omits the
    label's [for] attribute, and [Detached] is one of its three placements — which is why this component is
    thin rather than a mechanism of its own.

    {2 The two things upstream passes down through React context, and what becomes of them here}

    [InputGroupContext] tells each child "you are inside a group", which in React is how a nested input knows
    to render without its own label. This port does not reproduce that, and the difference is worth stating
    exactly: [Text_input.view] *requires* a label, so a control placed inside a group here carries a visually
    hidden empty one rather than none at all. That is a named divergence, not an equivalent — the group's own
    label is what names the control, and the inner label contributes nothing but exists.

    [SizeProvider] is the same story from the other side. In React the group's size reaches the children
    through the context; here the children are built by the caller, who knows the size they want, while the
    group carries its own size as a class so that its box is the right height and [align-items: stretch]
    makes the children fill it.

    So React's ambient context re-enters through the DOM in this port — as [aria-*] on the container and CSS
    on the box — and nowhere else. This is the same shape as the connected look in [Button_group]: a child
    is built before its container sees it, so anything the container would have told the child has to be
    either the caller's decision or CSS. *)

open! Core
open! Bonsai_web

type size = Input_types.size =
  | Sm  (** the control height the group's box takes, from the shared size scale *)
  | Md
  | Lg

(** [view ~id ~label ~children ()].

    [id] is the caller's, and the port derives from it: the group's own element is [id ^ "-group"] and the
    label that names it is [id ^ "-label"]. Upstream generates these with [useId], which React keeps opaque;
    asking the caller is the same convention every input in this port already follows for [input_id], and it
    keeps rendered markup deterministic.

    [children] are the controls. When one of them is an input that would carry its own label, omitting that
    label is the caller's job — see the note above on [InputGroupContext].

    Not ported, and named rather than approximated:

    - [labelTooltip], for the same reason [Field_label] does not carry it — the label tooltip is a deferred
      divergence of the port, and a group label is a label.
    - the [aria-describedby] upstream puts on the group element. It names the description and the status
      message so that reaching the group announces both; this port's [Field] renders those elements without
      handing their ids back, so the link cannot be made from here. Inventing an id that carries no element
      would be worse than its absence: a reference that resolves to nothing is announced as nothing. *)
val view
  :  ?attrs:Vdom.Attr.t list
  -> ?is_label_hidden:bool
  -> ?description:string
  -> ?is_optional:bool
  -> ?is_required:bool
  -> ?is_disabled:bool
  -> ?size:size
  -> ?status:Input_types.status
  -> id:string
  -> label:string
  -> children:Vdom.Node.t list
  -> unit
  -> Vdom.Node.t
