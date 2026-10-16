(** The title block of a dialog: what it is called, what it says, and its own close button.

    This is the component that *names* the dialog it sits in. Upstream gets that association from
    context — the header knows its parent and registers the title id with it. Context has no analogue
    here (a child is already built by the time the container sees it), so the id is an argument instead:
    pass the same string to {!Dialog.view}'s [~labelled_by] and the caller, who can see both, makes the
    association. That is the same trade {!Alert_dialog.view} makes by owning its own body outright.

    {2 The close button exists only if there is somewhere to report it}

    Upstream renders no close button when [onOpenChange] is absent, which is the right call: a control
    that cannot tell anyone it was pressed is a control that does nothing. So the button is present
    exactly when [~on_open_change] is, and that argument is a *tree* like every other callback here — a
    caller holding a state setter has no way to produce a plain function. That is why this view returns
    a [Bonsai.t] rather than a node, even in the case where no button is drawn.

    {2 Not ported, with the reason — and it is a real accessibility behaviour, not a flourish}

    Upstream focuses the title when a modal dialog opens, and suppresses that on inline previews. It
    matters because the platform does not do it for us: the focus delegate [showModal()] runs skips any
    element with [tabindex="-1"], so the browser lands on the first *tabbable* thing — the close button —
    and a screen reader announces "Close" rather than the dialog's name. The title is consequently
    reachable but not focused.

    The mechanism exists in this port: [Menu_focus.focus_on_next_frame] focuses an element, and
    {!Common.Delay_hook} established the hook shape for doing DOM work no event triggers. What is missing
    is the *moment* — the header does not know the dialog opened, and upstream learns it from context.
    The honest home for it is {!Dialog.view}, which does know (its hook already runs on open), and it is
    recorded here rather than approximated with a [focus_on_open] argument that would have no signal to
    act on. Until then the title is focusable and a caller can focus it deliberately. *)

open! Core
open! Bonsai_web

(** Upstream's [endContentEdgeCompensation]: which axes the end slot compensates on when a close action
    sits beside it. *)
type edge_compensation =
  | Inline
  | Block
  | All

val view
  :  title_id:string
  (** The id the heading carries. It is what names the dialog, so it must be the string the dialog was
      given as [~labelled_by]. *)
  -> title:Vdom.Node.t
  (** Inline content, non-empty: its text becomes the dialog's accessible name. *)
  -> ?subtitle:Vdom.Node.t
  -> ?on_open_change:(bool -> unit Effect.t) Bonsai.t
  (** Omit it and no close button is rendered; supply it and the button reports [false]. *)
  -> ?start_content:Vdom.Node.t
  -> ?end_content:Vdom.Node.t
  -> ?end_content_edge_compensation:edge_compensation
  -> ?has_divider:bool
  -> ?attrs:Vdom.Attr.t list
  -> unit
  -> Vdom.Node.t Bonsai.t
