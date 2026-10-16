(** The label and description group a form control hangs off.

    Upstream keeps this in its own module ([Field/FieldLabel.tsx]) because more than one control
    composes it directly: [Field] wraps a whole control, but [CheckboxInput] and [Switch] want the
    label *beside* their control rather than above it and so use this group on its own. The port
    had the same code inside [Field] as a private function; it is a component of its own, so it
    lives on its own — and it is the thing [Field] now renders through. *)

open! Core
open! Bonsai_web

val view
  :  ?label_icon:string
  -> ?label_id:string
  -> ?is_group_label:bool
  -> ?is_label_hidden:bool
  -> ?is_disabled:bool
  -> ?is_optional:bool
  -> ?is_required:bool
  -> ?description:string
  -> ?description_id:string
  -> ?attrs:Vdom.Attr.t list
  -> label:string
  -> input_id:string
  -> unit
  -> Vdom.Node.t
(** [view ~label ~input_id ()] — the label group: the label text, an optional icon before it, a
    Required/Optional marker after it, and the description below.

    [input_id] is the id of the control the label names; the label is a real [<label for>] pointing
    at it. With [is_group_label] the group is a [<span>] instead — a [<label>] names exactly one
    form control and cannot name a group, so a group label is referenced from
    [aria-labelledby] instead. That is the difference between naming a control and naming a set of
    them, and it is the only reason the two paths exist.

    [is_label_hidden] puts the whole group at [astryx-visually-hidden] rather than removing it: the
    label is still the control's accessible name, so it must stay in the accessibility tree while
    taking no layout space.

    [description] is a {i sibling} of the [<label>], never a child. Nesting it would fold the
    description into the control's accessible name — and then announce it twice, once as the name
    and again through [aria-describedby]. [description_id] is what a control points at, and is
    optional here because the caller that derives it (upstream derives it from the control's id,
    and so does {!Field}) already knows it.

    Not ported from upstream's FieldLabel: [labelTooltip] (an info icon at the end of the label,
    which needs the Tooltip component), and the clickable description that forwards a click to the
    control through upstream's [useInputContainer]. Both are real; neither is invented here. The
    form-level [defaultOptionality] context that decides whether a marker shows at all arrives with
    [FormLayout] — with no context to read, a marker means what it says. *)
