(** A switch: an on/off toggle drawn as a track and a thumb.

    Upstream builds it the same way it builds [CheckboxInput] — [FieldLabel] and [FieldStatus]
    composed directly, because the label is a *row partner* of the control rather than a heading
    above it — and the port does the same. What it is *not* is a checkbox with different paint: the
    control is a native checkbox carrying `role="switch"`, which is the pattern that gives a
    screen-reader user "switch, on" instead of "checkbox, checked", and it is why the markup here
    looks the way it does.

    A switch has two values, not three. Everything a third state would say is said better by a
    checkbox, so there is no [Indeterminate] here. *)

open! Core
open! Bonsai_web

val view
  :  ?attrs:Vdom.Attr.t list
  -> ?is_disabled:bool
  -> ?is_label_hidden:bool
  -> ?is_optional:bool
  -> ?is_required:bool
  -> ?label_icon:string
  -> ?description:string
  -> ?description_id:string
  -> ?status:Input_types.status
  -> ?size:Indicator.size
  -> label:string
  -> id:string
  -> value:bool Bonsai.t
  -> on_change:(bool -> unit Effect.t) Bonsai.t
  -> unit
  -> Vdom.Node.t Bonsai.t
(** [view ~label ~id ~value ~on_change ()]. [value] drives the DOM's [checked] property, so the
    thumb cannot get out of step with the application's state, and a click reports the value it
    produced.

    Two details are deliberate rather than accidental:

    - There is **no** [aria-checked]. The input is a native checkbox, so its checkedness is already
      exposed and mapped; a second declaration can disagree with it. Upstream omits it and the tests
      assert its absence, exactly as they do for [CheckboxInput]'s mixed state.
    - The track is [aria-hidden]. It is the paint, not the control: the input underneath owns the
      role, the name, the state and the focus.

    [size] is [Indicator.size] — the pair the track is drawn at, 32×20 or 40×24 — because upstream's
    own [SwitchSize] is that pair.

    A *disabled* switch is natively disabled, so the browser refuses the click and there is nothing
    to undo; upstream's one focusable-disabled path (a disabled control that stays reachable so its
    reason can be read) arrives with the tooltip, and when it does, this control will need the
    canceled click that [Checkbox_input] already has.

    Not ported, each for a reason: [isBusy] and the spinner in the thumb (no [Spinner] yet),
    [changeAction] (a React form action), the [disabledMessage] tooltip, and read-only — upstream has
    no such prop for a switch. *)
