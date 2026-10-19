(** A checkbox whose label sits beside it.

    Upstream builds this out of the pieces rather than out of [Field], because a checkbox's label is
    a *row* partner of the control, not a heading above it: it composes [FieldLabel] and
    [FieldStatus] itself, and so does this.

    There are three values, not two. [Indeterminate] is the box that stands for a group of choices
    that disagree — it is drawn as a bar rather than a tick, which is the only reason the type has a
    third case at all. *)

open! Core
open! Bonsai_web

type value = Indicator.state =
  | Checked
  | Unchecked
  | Indeterminate

val view
  :  ?attrs:Vdom.Attr.t list
  -> ?is_disabled:bool
  -> ?disabled_message:string
(** Why a disabled control is disabled. With a message the control drops the native [disabled]
    attribute for [aria-disabled] plus [form=""], which keeps it focusable — a natively disabled
    button receives no pointer events and takes no focus, so it can never explain itself — and the
    message joins its [aria-describedby] for as long as it is disabled, not only while hovered. The
    bubble itself is shown on hover and focus by CSS, so this needs no state. *)

  -> ?is_read_only:bool
  -> ?is_loading:bool
(** A spinner replaces the box while an application action is in flight (upstream's [isBusy]).
    Clicks are cancelled (a click would otherwise toggle underneath the spinner) and the input
    carries [aria-busy="true"]; the checked state is untouched. Purely presentational — the
    application owns the in-flight state, as it does for [Slider]. *)

  -> ?is_label_hidden:bool
  -> ?is_optional:bool
  -> ?is_required:bool
  -> ?optionality:Common.Optionality.t
  -> ?label_icon:string
  -> ?description:string
  -> ?description_id:string
  -> ?described_by:string
(** Merges an extra id into the control's [aria-describedby]. This is how a control inside a row
    points at the row's own description (CheckboxListItem) without owning it. *)

  -> ?status:Input_types.status
  -> ?size:Indicator.size
  -> label:string
  -> id:string
  -> value:value Bonsai.t
  -> on_change:(value -> unit Effect.t) Bonsai.t
  -> unit
  -> Vdom.Node.t Bonsai.t
(** [view ~label ~id ~value ~on_change ()]. [id] is the control's id, and the label is a real
    [<label for>] pointing at it, so clicking the label toggles the box.

    [value] and [on_change] are both {!Bonsai.t}s, and that pairing is the point: [value] drives the
    DOM's [checked] *property*, so the box cannot get out of step with the application, and a toggle
    reports the value the click produced. Both details below are load-bearing and both are invisible
    until they are wrong:

    - [indeterminate] is a DOM **property**, set the same way [checked] is. There is no attribute for
      it; an [indeterminate] attribute renders a box that simply looks unchecked.
    - There is deliberately **no** [aria-checked="mixed"]. The native property is the authoritative
      mixed state and a second source of truth can disagree with it, so upstream dropped the ARIA
      state and this port must not helpfully add it back. The tests assert that it is absent.

    A click is what toggles it, and the value the click produces is derived from [value] rather than
    read back out of the DOM — [Indeterminate] and [Unchecked] both become [Checked], which is what
    the browser does natively when you click a group's half-selected parent. Keyboard reaches it
    because Space on a focused checkbox *is* a click; the real-browser gate tabs to it and presses
    Space rather than assuming that.

    A *read-only* box still takes focus and still fires clicks, so the click is canceled rather
    than ignored: a checkbox's checkedness is set before the click is dispatched and reverted when
    the event is canceled, so canceling is both immediate and native. Merely ignoring the click
    would leave the box visibly checked — no re-render follows a value that did not change, so
    nothing would put the property back.

    [size] is [Indicator.size] rather than [Input_types.size] on purpose: a checkbox is only drawn at
    two sizes — the box it draws is 20px or 24px — and upstream's own [CheckboxInputSize] is exactly
    that pair, even though the fields that hold a value accept three.

    Not ported here, each for a reason: [changeAction] (a React form action, and an async one:
    a Bonsai effect cannot await a promise — the loading state is [is_loading] instead), and the
    [disabledMessage] *tooltip* (the bubble is CSS-shown exactly as upstream does; the delayed
    hover Tooltip behind upstream's [disabledMessage] is this port's own [Tooltip], which a
    caller composes when it wants the delayed behaviour).

{2 The plain-value renderer}

    [render] is the same control built from plain values instead of {!Bonsai.t}s. It is the
    mechanism [Checkbox_list] uses to place a checkbox inside a row it builds inside a
    [Bonsai.map] — a place where components cannot be called. It is public because a second
    consumer appeared; the component's own gate is what proves the move changed nothing. *)

val render
  :  ?attrs:Vdom.Attr.t list
  -> ?is_disabled:bool
  -> ?disabled_message:string
  -> ?is_read_only:bool
  -> ?is_loading:bool
  -> ?is_focusable_disabled:bool
  -> ?is_label_hidden:bool
  -> ?is_optional:bool
  -> ?is_required:bool
  -> ?optionality:Common.Optionality.t
  -> ?label_icon:string
  -> ?description:string
  -> ?description_id:string
  -> ?described_by:string
  -> ?status:Input_types.status
  -> ?size:Indicator.size
  -> label:string
  -> id:string
  -> value:value
  -> on_change:(value -> unit Effect.t)
  -> unit
  -> Vdom.Node.t
(** [render ~label ~id ~value ~on_change ()]: the same control as [view] with the values already
    unwrapped. [value] is the control's state and [on_change] the effect it runs on a useful click.
    [is_focusable_disabled] makes a disabled checkbox keep keyboard focus ([aria-disabled] and
    [form=""] instead of the native attribute) without mounting a second reason bubble — the
    [Checkbox_list] group-disabled case, where one message describes the whole set. *)
