(** Field — the wrapper that gives a control its label, description and status.

    Every input in the library renders through [Field], which is why the accessible wiring lives
    here rather than in each control:

    - the label is a real [<label for=input_id>] with the label text inside it, so the control is
      named natively;
    - the description is a {i sibling} [<span id=input_id-desc>] inside the label group, and the
      control points at it with [aria-describedby]. Putting it inside the [<label>] instead would
      fold it into the control's accessible name and announce it twice;
    - [is_label_hidden] hides the label from sight and keeps it for assistive technology, using
      the same [astryx-visually-hidden] class {!Visually_hidden} emits — not a second mechanism.

    {2 Where the status message goes}

    [status_variant] decides {i placement}, not whether the message is spoken. [Attached] (the
    default) sits under the control as part of the field's own surface; [Detached] sits below the
    field with its own spacing, which is the right choice for a checkbox or a switch, where there
    is no border to overlap; and [Tooltip] renders {b no message box at all} — the message is
    announced on its own, at the urgency {!Field_status} would have used, so a screen-reader user
    hears the status in every variant.

    {2 Deliberate divergences from upstream}

    - {b No [label_tooltip].} Upstream renders its Tooltip component there. Tooltip is not ported,
      so the argument does not exist here rather than being accepted and ignored.
    - {b No [FormLayout] context.} Upstream resolves the effective required state for
      [aria-required] against a surrounding [FormLayout]'s [defaultOptionality]. With no such
      context in this port, required is exactly [is_required], and [is_optional] wins when both
      are set — which is also what upstream does, after warning about it.
    - {b No horizontal-labels layout.} Upstream drives it from [FormLayoutContext]; it belongs
      with [FormLayout] rather than here.
    - The required/optional marker is the English source text ("Required" / "Optional"). Upstream
      resolves it through its i18n catalogue; the port has no catalogue yet. *)

open! Core
open! Bonsai_web

type status_type = Input_types.status_type =
  | Warning
  | Error
  | Success

type status_variant = Field_status.placement =
  | Attached  (** the message is part of the field's surface, under the control — the default *)
  | Detached  (** the message sits below the field with its own spacing *)
  | Tooltip  (** no message box: the message is announced, not shown *)

(** Upstream's [SizeValue], shared with every control that takes a width — which is why this is
    [Common.Size_value.t] and not a type of Field's own. *)
type width = Common.Size_value.t =
  | Px of int  (** upstream treats a number as pixels *)
  | Css of string  (** anything else, e.g. "100%", used as written *)

val view
  :  ?is_label_hidden:bool
  -> ?description:string
  -> ?is_optional:bool
  -> ?is_required:bool
  -> ?is_disabled:bool
  -> ?label_icon:string
  -> ?status:Input_types.status
  -> ?status_variant:status_variant
  -> ?width:width
  -> ?label_id:string
  -> ?is_group_label:bool
  -> ?attrs:Vdom.Attr.t list
  -> label:string
  -> input_id:string
  -> children:Vdom.Node.t list
  -> unit
  -> Vdom.Node.t
(** [view ~label ~input_id ~children ()].

    [input_id] is the id of the {i control} the label points at; [label_id] is the id put {i on}
    the label element, for a group of controls that names itself with [aria-labelledby].
    [is_group_label] renders the label as a [<span>] instead of a [<label>]: a [<label>] names one
    control and cannot name a group. [status] is [(type_, message)], and [label_icon] is an icon
    {i name} (the port's icons come from a generated registry, so it takes a name where upstream
    accepts a node). *)
