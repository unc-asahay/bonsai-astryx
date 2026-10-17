(** A bar of related controls with one tab stop and arrow keys inside it.

    {2 What makes it a Toolbar and not a row of buttons}

    Three things, and each is checked somewhere:

    - it is a [role="toolbar"] named by [label], so it is announced as one region rather than as the loose
      controls inside it;
    - navigation inside it is the {i same} roving tab stop [Button_group] uses — now a mechanism
      ([Common.List_focus]) rather than a loop, so a member's own open layer keeps its arrow keys;
    - and an input inside it keeps its arrows: the caret guard leaves the key to the caret unless the caret
      is already at the edge the key moves toward. That is what lets a toolbar contain a search field.

    {2 The size is not passed down}

    Upstream threads [size] to children through [SizeContext]; here the box takes the size scale's height and
    the caller builds its children knowing the size it wants — the same named divergence as [Input_group].
    React's ambient context re-enters through the DOM and nowhere else.

    Not ported, and named rather than approximated:

    - [useKeyboardHint], upstream's ephemeral arrow-key hint for sighted keyboard users. The roving behaviour
      it explains is ported; the hint is discoverability polish, and its own building blocks ([Kbd] and the
      layer mechanism) are already here, so it would be a small self-contained follow-up.
    - edge compensation, which lets a ghost button at a toolbar's end sit flush against a container's edge.

    [role], [aria-label] and [aria-orientation] are stripped from the incoming props and set here, so a
    Toolbar cannot be handed a role that contradicts the behaviour inside it. *)

open! Core
open! Bonsai_web

type size = Input_types.size =
  | Sm
  | Md
  | Lg

type orientation = Common.List_focus.orientation =
  | Horizontal  (** one row: the left and right arrows move between members *)
  | Vertical

(** [view ~label ?start_content ?center_content ?end_content ()].

    [center_content] switches the layout from a flex row to a three-column grid, so the centre slot is
    centred against the toolbar rather than against whatever happens to be in the other slots. [gap] is a
    step of the shared spacing scale, applied within each slot.

    This component holds no caller state, so it needs no graph argument: an interactive toolbar's members
    bring their own. *)
val view
  :  ?attrs:Vdom.Attr.t list
  -> ?size:size
  -> ?gap:Common.Spacing.t
  -> ?orientation:orientation
  -> ?variant:Section.variant
  -> ?dividers:Section.side list
  -> ?start_content:Vdom.Node.t list
  -> ?center_content:Vdom.Node.t list
  -> ?end_content:Vdom.Node.t list
  -> label:string
  -> unit
  -> Vdom.Node.t
