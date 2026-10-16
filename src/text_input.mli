(** TextInput — a labelled text field: the port's first real form control, and the shape every
    other input in the library takes.

    It is deliberately {b not} a copy of upstream's prop list. What is here is what a controlled
    input actually needs in Bonsai, and what is missing is missing for a stated reason:

    - [value] is a {!Bonsai.t}, so the DOM follows the application's state, and [on_change]
      produces an [Effect.t] rather than calling back into React. Upstream's [useOptimistic] +
      [useTransition] pair exists to keep a slow [changeAction] from fighting the browser's own
      echo of the keystroke; a Bonsai state setter has no such race, so the port has no
      equivalent — the value it renders is the value the application holds.
    - The label, description and status are {!Field}'s, not this module's: the input renders the
      control and points at them with [aria-describedby]. That is also why the tooltip placement
      still announces: the id the input references belongs to the announcement {!Field} renders.

    {2 The ARIA wiring, which is the reason this component exists in a port}

    - the label is associated natively ([<label for>]) and is {b not} also named with
      [aria-labelledby] — upstream's [getInputARIA] returns [undefined] for a standalone input,
      because naming a control twice is how a screen reader announces it twice;
    - [aria-describedby] lists the description and the status message in that order, each only
      when it is really rendered;
    - [aria-required] is [is_required] unless [is_optional] is also set, in which case optional
      wins — the visible marker and the announced state therefore agree;
    - [aria-invalid] is set only for an error status, not for a warning.

    {2 Deliberate divergences from upstream}

    - {b No [isLoading] spinner, no [changeAction], no InputGroup membership, no
      [disabledMessage] tooltip, no [hasClear]}, and no [label_tooltip]. Each needs a component
      or a context this port does not have yet (Spinner, Tooltip, InputGroup); they are absent
      rather than accepted and ignored.
    - [on_enter] fires on Enter and is suppressed while an IME is composing, as upstream's is:
      pressing Enter to commit a Japanese/Chinese/Korean conversion must not also submit. *)

open! Core
open! Bonsai_web

type type_ =
  | Text
  | Password
  | Email

type size =
  | Sm
  | Md
  | Lg

type status_type = Field_status.type_ =
  | Warning
  | Error
  | Success

type status_variant = Field_status.placement =
  | Attached
  | Detached
  | Tooltip

val view
  :  ?type_:type_
  -> ?description:string
  -> ?is_label_hidden:bool
  -> ?is_optional:bool
  -> ?is_required:bool
  -> ?is_disabled:bool
  -> ?is_read_only:bool
  -> ?placeholder:string
  -> ?start_icon:string
  -> ?status:status_type * string
  -> ?status_variant:status_variant
  -> ?size:size
  -> ?width:Common.Size_value.t
  -> ?html_name:string
  -> ?auto_complete:string
  -> ?on_enter:unit Effect.t Bonsai.t
  -> ?attrs:Vdom.Attr.t list
  -> label:string
  -> id:string
  -> value:string Bonsai.t
  -> on_change:(string -> unit Effect.t) Bonsai.t
  -> unit
  -> Vdom.Node.t Bonsai.t
(** [view ~label ~id ~value ~on_change ()]. [id] is the control's id; the label, the description
    ([id ^ "-desc"]) and the status message ([id ^ "-status"]) all hang off it, exactly as
    upstream derives them from [useId]. [start_icon] is an icon {i name} from the generated
    registry.

    Both [value] and [on_change] are {!Bonsai.t}s, and that is deliberate: a state setter in
    Bonsai is itself a value in the graph, so accepting it directly is what keeps the common call
    site a single expression. A plain function there would force the caller to wrap the whole
    input in a [Bonsai.map] over the setter — and since [view] already returns a [Bonsai.t] that
    wrap produces a {i tree of a tree}, which then has to be unwrapped again before the node can
    be rendered. [on_enter] is a {!Bonsai.t} for the same reason, even when it is a constant: a
    submit that reads the field's own state is the normal case, and an effect built outside the
    graph cannot read it. *)
