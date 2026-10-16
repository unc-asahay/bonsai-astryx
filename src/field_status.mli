(** FieldStatus — the message strip under a form control.

    Two variants, and the difference is bigger than it looks:

    - [Attached] (the default) overlaps the control above it: a negative top margin, the
      bottom corners rounded, and {b [pointer-events: none]} so the overlap cannot steal a
      click meant for the control underneath. It renders the message as bare text.
    - [Detached] sits below the control with a normal gap and renders an icon plus the
      message.

    {2 Announcing}

    Upstream announces through a shared announcer context: [assertive] when the status is
    an error, [polite] otherwise. Bonsai has no announcer context, so the equivalent here
    is a role on the container itself — [alert] for an error, [status] otherwise. That
    announces the message that is already on screen exactly once, with the same urgency,
    and avoids a second copy of the text in a hidden region (which would double-announce).

    {2 The entry animation}

    [useEntryAnimation('slideDown')] upstream, so an element that mounts {i after} the
    first paint animates in and one present at first paint does not. That decision needs
    the graph — see {!Entry_animation} — which is why this component, like upstream's, is
    not a pure function. *)

open! Core
open! Bonsai_web

type type_ =
  | Warning
  | Error
  | Success

type variant =
  | Attached
  | Detached

val view
  :  ?variant:variant
  -> ?attrs:Vdom.Attr.t list
  -> type_:type_
  -> message:string
  -> unit
  -> Vdom.Node.t
(** [view ~type_ ~message ()]. The message is a plain string: upstream's prop is a
    [string], and it is announced, so it is not a node. *)
