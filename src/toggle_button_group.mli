(** Toggle buttons as one row.

    Upstream's group is compositional: it renders its children and provides the selection to them through a
    context, so each child asks the group whether it is selected. The port has no contexts by design, so the
    **caller owns the selection** and passes [is_pressed] to each button - which is also what makes the group
    itself a plain container with a name.

    {2 Divergences}

    - The selection is the caller's rather than provided by the group (no contexts; see above), and the group
      takes no [size]: upstream's supplies the members' size through the same context, and a port with no
      context would only be taking an argument it cannot use.
    - The port adds [aria-orientation] to the group. Upstream's group announces its [orientation] only through
      styling, and a group whose members stack should say so.
    - [themeProps] has no counterpart.
*)

open! Core
open! Bonsai_web

type orientation =
  | Horizontal
  | Vertical

(** [view ?orientation ?size ~label ~buttons ()]. [label] names the group; [buttons] are its members, already
    rendered and already carrying their own pressed state. *)
val view
  :  ?attrs:Vdom.Attr.t list
  -> ?id:string
  -> ?orientation:orientation
  -> label:string
  -> buttons:Vdom.Node.t list
  -> unit
  -> Vdom.Node.t
