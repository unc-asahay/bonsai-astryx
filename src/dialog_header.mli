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

    {2 Focus on open, and why the platform's own choice is the wrong one}

    Upstream focuses the title when a modal dialog opens, and it is not a flourish: the focus delegate
    [showModal()] runs skips any element with [tabindex="-1"], so the browser's own choice is the first
    *tabbable* thing — the close button — and a screen reader would announce "Close" rather than the
    dialog's name. So the title is marked ([data-astryx-focus-on-open]) and {!Dialog.view}'s hook focuses
    it. The dialog is the only thing that knows it opened; upstream learns that from context, which has
    no analogue here.

    Two consequences worth stating: a dialog that marks nothing keeps the platform's choice, and an
    inline preview never runs the hook at all — which is how upstream suppresses the focus there too,
    arrived at rather than special-cased.
*)

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
