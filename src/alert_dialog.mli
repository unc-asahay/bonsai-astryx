(** A confirmation dialog: a [Dialog] with a purpose, a subject and two answers.

    Upstream builds this on [Dialog] with [purpose="form"] and then overrides the role, which is the
    interesting part of the contract and the reason {!Dialog.view} takes [~role]: an alert dialog has no
    "close" — it has an answer — but the same component is also used as a non-modal inline preview, and
    an [alertdialog] role there would promise an interruption, a focus trap and an inert page behind it
    that the preview does not have. So the role is [alertdialog] when modal and [group] when inline.

    {2 What is an argument here and what is not}

    [~title] and [~description] are the two things the dialog names and describes itself from, so they
    arrive as strings and the component builds the elements and the ids that point at them. That is
    closer to upstream than {!Dialog.view}'s [~labelled_by], and for the same reason turned around:
    Dialogue's caller owns the header, so it owns the id; here the component owns the whole body, so it
    owns both ids and the association. A description that is only visual is one assistive technology
    never reads — it is wired into [aria-describedby], not merely rendered.

    {2 The small-screen order is CSS, not JavaScript}

    Upstream reads the viewport with [useMediaQuery('(max-width: 640px)')] and swaps the two buttons
    when it matches. The port writes one CSS rule instead ([column-reverse] below 640px), which is the
    same behaviour without a re-render on every resize. It is a divergence in mechanism, not in
    behaviour, and it is recorded here because the port cannot run a media query in Bonsai at all.

    {2 Not ported, with the reason}

    [useImperativeAlertDialog] — upstream's [alertDialog.confirm(options)] returning a promise. It needs
    a handle concept: code that is not a Bonsai view asking a mounted component a question. The port has
    no such concept, and inventing one for a single component would be the port's decision rather than
    upstream's. Named here rather than quietly left out. *)

open! Core
open! Bonsai_web

type variant = Button.variant

val view
  :  title:string
  -> description:string
  -> action_label:string
  -> ?cancel_label:string
  -> ?action_variant:variant
  -> ?is_action_loading:bool
  -> ?width:string
  -> ?is_inline:bool
  -> on_action:unit Effect.t Bonsai.t
  -> is_open:bool Bonsai.t
  -> on_open_change:(bool -> unit Ui_effect.t) Bonsai.t
  -> id:string
  -> unit
  -> Vdom.Node.t Bonsai.t
