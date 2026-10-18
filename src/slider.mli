(** Slider — a labelled numeric control for a value or a range, thumb on a 4px rail.

    {2 What the port owns}

    - {b The geometry}: the rail, fill and thumbs travel through an inset of half a
      thumb at each end — the geometry a native range input uses — so the thumb stays
      inside the box at min and max instead of overhanging it, and the fill and marks
      map through the same inset. Pointer positions invert that mapping
      ({!travel_fraction}), so the thumb tracks the pointer that grabbed it.
    - {b The interaction}: pointer-down anywhere on the track moves the nearest (or, for
      a direct press on a thumb, that) thumb and captures the pointer, move updates
      while the drag runs, up/cancel ends it and fires [on_change_end]. Keyboard on a
      thumb: arrows (direction-aware on a horizontal track under RTL), PageUp/PageDown
      (10 steps), Home/End (the bounds themselves — Home lands exactly on [min] and End
      exactly on [max] even when [max] is off the step grid). Value changes are clamped
      to [min, max] and snapped to the step grid with binary-error rounding, so
      [0 + 3 * 0.1] is [0.3], not [0.30000000000000004].
    - {b Range mode}: two thumbs, a [role=group] container named by the Field label
      (each thumb keeps "Minimum value"/"Maximum value"), a fill between the thumbs,
      and [min_steps_between_thumbs] enforced on both drag and keyboard so the thumbs
      never cross.
    - {b Disabled}: [is_disabled] + [disabled_message] keeps the spec's discoverability
      contract — the thumb stays focusable ([aria-disabled], [tabindex=0]) while the
      reason shows as a tooltip above the track on hover/focus, and every value change
      stays blocked by the [is_disabled] guards. Without a message, a disabled thumb is
      [tabindex=-1].
    - {b ARIA}: the thumb is [role=slider] with correct [aria-valuemin/max/now] (in
      range mode bounded by the sibling plus the min gap), [aria-orientation],
      [aria-invalid] for an error status, and [aria-label="Minimum value"|…] +
      [aria-labelledby] pointing at the group label. [aria-required] is not a supported
      property of [role=slider] in WAI-ARIA 1.2, so a required slider points its
      [aria-describedby] at a visually hidden "Required" span instead (mirroring the
      Field label's indicator).
    - {b Marks}: [marks] render as 2×8px ticks at their [inset_position], filled-colour
      inside the filled region (at or behind the thumb in single mode, between the
      thumbs in range mode), with optional labels beneath. A click on a mark snaps to
      that mark's value — a label like "100" is a wide target, and pointer arithmetic
      would be off by one pixel's worth of width.

    {2 Named divergences}

    - {b No pointer-event JS wrappers}: the house vdom has [on_pointerdown/move/up/cancel]
      directly, and the port keeps the drag state in the Bonsai graph rather than in a
      React ref; the pressed thumb is painted through a [--pressed] class, and the
      keyboard-only focus ring through a [--keyboard-focus] class (the house convention
      for "the user's last interaction was the keyboard", where upstream gates
      [:focus-visible] on an interaction-modality store).
    - {b No [ref]}, no [React.] IDs beyond the passed [~id] and the derived
      [-desc]/[-status] ids the house Field already generates; the value tooltip is the
      house {!Tooltip} (a static, graph-owned bubble above the thumb, opened on drag).
    - {b RTL} is detected from the track's computed [direction] on pointer events (lazy,
      exactly as upstream); the CSS centers the thumb with logical [inset-inline-start].
    - {b [html_name]}: hidden inputs carry each thumb's value for form submission, and
      are [disabled] when the slider is disabled — mirroring that disabled native
      controls are excluded from submission.
    - {b No [valueDisplay=none] partial}: [No_value] renders the uncontrolled bubbles
      off, like upstream's [valueDisplay = 'none']. *)

open! Core
open! Bonsai_web

type orientation =
  | Horizontal
  | Vertical

type value_display =
  | Tooltip
  | Text
  | No_value

type mark =
  { value : float
  ; label : string option
  }

(** A [Single] value or a [Range] pair, in [min, max] order. *)
type t =
  | Single of float
  | Range of float * float

(** [view ~label ~value ~on_change graph]. [value] is the current value; [on_change]
    receives the value after every change during a drag or keyboard interaction, and
    [on_change_end] fires once when the interaction ends. Both are [Bonsai.t] so the
    application owns the state, as with the other house controls. *)
val view
  :  ?id:string
  -> ?attrs:Vdom.Attr.t list
  -> label:string
  -> ?is_label_hidden:bool
  -> ?description:string
  -> ?is_disabled:bool
  -> ?disabled_message:string
  -> ?is_required:bool
  -> ?is_optional:bool
  -> ?status:Input_types.status
  -> ?width:Common.Size_value.t
  -> ?label_tooltip:string
  -> ?min:float
  -> ?max:float
  -> ?step:float
  -> ?orientation:orientation
  -> ?format_value:(float -> string)
  -> ?value_display:value_display
  -> ?marks:mark list
  -> ?html_name:string
  -> ?min_steps_between_thumbs:int
  -> value:t Bonsai.t
  -> on_change:(t -> unit Effect.t) Bonsai.t
  -> ?on_change_end:(t -> unit Effect.t) Bonsai.t
  -> Bonsai.graph
  -> Vdom.Node.t Bonsai.t

(** {2 Pure helpers — unit-tested in OCaml, no DOM.} *)

val clamp : float -> float -> float -> float

val get_decimal_precision : float -> int

val snap_to_step : float -> float -> float -> float

val get_percent : float -> float -> float -> float

val travel_fraction : float -> float -> float

(** [inset_position percent] is a [calc(…% ± …px)] string: half a thumb inset at the
    ends, shrinking linearly so the thumb stays inside the box. *)
val inset_position : float -> string

(** [inset_span from to] is the distance between two inset positions. *)
val inset_span : float -> float -> string

val css_length : float -> float -> string

val get_value_from_position
  :  orientation:orientation
  -> min:float
  -> max:float
  -> step:float
  -> width:float
  -> height:float
  -> client_x:float
  -> client_y:float
  -> is_rtl:bool
  -> float

(** [update_range ~min ~max ~step ~min_gap ~thumb_index ~new_val v0 v1] applies the
    gap/bounds rules and returns the new pair. *)
val update_range
  :  min:float
  -> max:float
  -> min_gap:float
  -> thumb_index:int
  -> new_val:float
  -> float
  -> float
  -> float * float
