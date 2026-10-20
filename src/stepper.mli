open! Core
open! Bonsai_web

(** The Stepper — a multi-step flow control.

    A stepper shows an ordered sequence of steps, marks the current one, and
    draws the connectors between them so the flow's progress is visible. It is
    upstream's [Stepper]/[Step] pair, flattened into one data-driven component
    because Bonsai has no parent/child component context: the steps are a
    plain list and the current step is a value the caller owns.

    {2 Example}

    {[
      let stepper =
        Stepper.view
          ~active_step:(Bonsai.state 0 |> ...)
          ~steps:
            [ { Stepper.label = "Account"; description = None; ... } ]
          ~on_step_click
          graph
    ]} *)

(** Which way the steps run. *)
type orientation =
  | Horizontal
  | Vertical

(** How much room each step takes. Compact is for a dense list, balanced is
    the default, spacious is for a full-page flow. *)
type density =
  | Compact
  | Balanced
  | Spacious

(** Where the indicator sits relative to the connector.

    - [Separated] (the default) puts the indicator beside the step's text and
      the connector in its own row.
    - [On_track] puts the indicator on the connector itself, so the step's
      text hangs off the track. *)
type indicator_position =
  | Separated
  | On_track

(** The state of a step, as reported by the caller. [Accent] is the neutral
    in-progress state; the other three recolour the indicator and announce
    themselves to assistive technology. *)
type status =
  | Accent
  | Success
  | Warning
  | Error

(** What is drawn in the step's indicator.

    - [Auto] (the default) shows the step's number until the step is complete,
      and a tick once it is.
    - [Number] always shows the step's number.
    - [None] draws no indicator.
    - [Custom] draws the given node. *)
type indicator =
  | Auto
  | Number
  | None
  | Custom of Vdom.Node.t

(** What a collapsed (narrow) horizontal stepper keeps on screen.

    - [With_label_and_controls] (the default) shows the current step's name
      between Previous and Next buttons.
    - [With_label] shows the current step's name and nothing else.
    - [Hidden_label] shows only the track; the step's name is left to the
      accessible list. *)
type collapsed_variant =
  | With_label_and_controls
  | With_label
  | Hidden_label

(** The horizontal stepper's responsive behaviour. *)
type horizontal_options =
  {
    (** The narrowest a step may become, in CSS pixels, before the stepper
        collapses. Upstream's default is 112. *)
    minimum_step_width : int
  ; collapsed_variant : collapsed_variant
  }

(** One step of the flow. *)
type step =
  {
    (** The step's name. Always present, and always in the DOM — a collapsed
        stepper hides it visually, not from the accessible list. *)
    label : string
  ; description : string option
  ; status : status option
  ; is_disabled : bool
  ; is_optional : bool
  ; end_content : Vdom.Node.t option
  ; indicator : indicator option
  ; density : density option (** Overrides the stepper's density for this step. *)
  ; content : Vdom.Node.t list (** The step's body. *)
  }

(** [view] renders a stepper.

    @param active_step the index of the current step. The caller owns it: the
      stepper never moves itself, it only reports a click through
      [on_step_click].
    @param on_step_click called with the index of a clicked step. When it is
      absent the steps are not clickable and the stepper is linear.
    @param orientation which way the steps run.
    @param label the stepper's accessible name. Defaults to "Progress".
    @param density the stepper's density.
    @param indicator_position where the indicator sits.
    @param horizontal_options the horizontal stepper's responsive behaviour.
    @param attrs attributes for the root element.
    @param id the root element's id. *)
val view
  :  ?attrs:Vdom.Attr.t list
  -> ?id:string
  -> ?orientation:orientation
  -> ?label:string
  -> ?density:density
  -> ?indicator_position:indicator_position
  -> ?horizontal_options:horizontal_options
  -> ?on_step_click:(int -> unit Effect.t) Bonsai.t
  -> active_step:int Bonsai.t
  -> steps:step list
  -> Bonsai.graph
  -> Vdom.Node.t Bonsai.t

(** {2 Divergences from upstream}

    - Upstream splits the component into [Stepper] and [Step] and lets the
      steps register themselves with their parent through React context. There
      is no such context in Bonsai, so the steps are a list passed to
      [view] and the current step is a value the caller owns.

    - Upstream's [Stepper] takes [onStepClick] as an optional callback and
      decides whether a step is clickable from whether that callback is
      present. Here [on_step_click] is optional in the same way and its
      presence is read when the graph is built.

    - Upstream's compact mode is driven by a [ResizeObserver] on the stepper's
      own root, and the width it measures decides what is rendered — not just
      what is hidden. The same measurement is made here.

    - Upstream's summary row is a portal target that the active step writes
      into. There is no portal in Bonsai, so the summary is rendered by the
      stepper itself from the same step data.

    - Upstream reads its strings from the [@astryx.stepper.*] and
      [@astryx.step.*] translation namespaces. This library has no
      translation layer, so the strings are spelled out here in English:
      "Progress", "Previous step", "Next step", "Optional", and the
      per-status announcements ("completed", "warning", "error"). *)
