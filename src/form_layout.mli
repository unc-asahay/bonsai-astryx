(** The spatial layout for a group of form fields.

    Upstream's [FormLayout] does two jobs: it arranges fields (vertical, horizontal in equal
    columns, or labels-to-the-left) and it supplies the form's [defaultOptionality] through React
    context, which decides whether a field shows an optional/required marker at all.

    The port keeps the first job and makes the second one an argument on the fields themselves
    ([?optionality] on {!Field}, {!Field_label} and every control). That is not laziness about
    context: a context has to be *active while the child is constructed*, and here a child is a
    [Vdom.Node.t Bonsai.t] that the caller has already built before this function is applied — see
    the note at the end.

    What is faithful is the rule itself: only the exception is marked. A field that restates the
    form's default shows nothing, a field that deviates shows its own marker, and — the part that
    is easy to lose — a layout default changes [aria-required] but {b never} the native [required]
    attribute, so choosing a default cannot switch on the browser's own validation. *)

open! Core
open! Bonsai_web

type direction =
  | Vertical
  | Horizontal
  | Horizontal_labels

(** Which state the form treats as its default. Upstream declares this type in FormLayout.tsx; the
    value itself lives in {!Common.Optionality} so the controls can take it without depending on the
    layout, and it is re-exported here because this is the module a caller reaches for it from. *)
type optionality = Common.Optionality.t =
  | Optional
  | Required

val view
  :  ?attrs:Vdom.Attr.t list
  -> ?direction:direction
  -> children:Vdom.Node.t list
  -> unit
  -> Vdom.Node.t
(** [view ~direction ~children ()]. Renders a [div] — not a [form], because submission is a separate
    concern, exactly as upstream notes.

    [Horizontal] lays the children out in equal-width columns and [Horizontal_labels] puts labels to
    the left of their controls (collapsing to a stack on a narrow container). Both are CSS; the
    component only names the intent.

    {2 Why [defaultOptionality] is not an argument here}

    Upstream threads it through context, and the obvious port would be [Bonsai.Dynamic_scope]. It
    does not work out: a dynamic scope applies to computations built *inside* it, and [children]
    arrives as trees that were already built by the caller. Accepting `~default_optionality` here
    and having it reach nothing would be the worst outcome — an argument that looks load-bearing
    and is not — so it is absent and the fields take their [?optionality] directly. *)
