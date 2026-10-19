(** NumberInput — the draft-committing numeric field.

    Port of upstream [NumberInput]. The text edit is held as a draft (a string, so
    "1,5" and "12.0" are both visible while typing) until an explicit commit boundary:
    blur or Enter. Only valid drafts reach [on_change]; an out-of-range draft clamps at
    [min]/[max] (upstream's exact policy), an empty draft clears (when [has_clear]) or
    reverts. Arrow keys, the wheel and the stepper buttons all step through the same
    arithmetic as upstream ([step], [min], [max], [is_integer_only], decimal-place
    rounding, -0 normalization).

    {2 Divergences (also recorded in [port.json])}

    - {b No [on_key_down].} Upstream exposes onKeyDown; this port keeps Enter and IME
      handling and reaches the rest through [attrs].
    - {b Locale via argument, not context.} Upstream reads the locale out of its i18n
      context; the port takes [?locale] (a BCP 47 tag) and resolves the grouping and
      decimal separators from the host Intl when it is available, falling back to en-US.
      The digit-script normalization is done through the host's Intl: non-ASCII decimal
      digits (Arabic-Indic, Devanagari, full-width …) are folded to ASCII before the
      algorithm runs, which is what lets "١٢٣" parse without shipping a table.
    - {b No InputGroup context.} Upstream swaps in a visually-hidden label inside an
      InputGroup; here a field is either inside an explicit [Input_group.view] or not
      (pass [is_label_hidden] yourself).
    - {b No in-wrapper status icon.} Upstream paints the status icon inside the control;
      the house [Field] renders the message box, as in [Text_input]. Passing [status]
      still colours the control (data-status/border class).
    - {b Fixed English labels.} "Toggle children"-style strings: "Invalid number",
      "Clear value", "Increase value"/"Decrease value" are fixed English (upstream
      resolves them through its i18n catalogue).
    - The live invalid-number region is a visually-hidden div with [role=alert] because
      {!Visually_hidden.view} cannot take attributes.
    - Generated ids derive from [id] ([id]-desc, [id]-status, [id]-units, [id]-reason)
      rather than React's [useId], so markup is deterministic and testable. *)

open! Core
open! Bonsai_web

type size = Input_types.size =
  | Sm
  | Md
  | Lg

type status_type = Input_types.status_type =
  | Warning
  | Error
  | Success

type status_variant = Field_status.placement =
  | Attached  (** the message is part of the field's surface, under the control — the default *)
  | Detached
  | Tooltip

val view
  :  ?id:string
  -> ?attrs:Vdom.Attr.t list
  -> label:string
  -> ?is_label_hidden:bool
  -> ?description:string
  -> ?is_optional:bool
  -> ?is_required:bool
  -> ?optionality:Common.Optionality.t
  -> ?is_disabled:bool
  -> ?is_read_only:bool
  -> ?disabled_message:string
  -> ?start_icon:string
  -> ?status:Input_types.status
  -> ?status_variant:status_variant
  -> ?size:size
  -> ?width:Common.Size_value.t
  -> ?html_name:string
  -> ?auto_complete:string
  -> ?placeholder:string
  -> ?label_tooltip:string
  -> ?min:float option
  -> ?max:float option
  -> ?step:float option
  -> ?format_value:(float -> string)
  -> ?is_wheel_enabled:bool
  -> ?has_number_steppers:bool
  -> ?units:string
  -> ?is_integer_only:bool
  -> ?has_clear:bool
  -> ?locale:string
  -> ?on_enter:(unit -> unit Effect.t)
  -> value:float option Bonsai.t
  -> on_change:(float option -> unit Effect.t) Bonsai.t
  -> Bonsai.graph
  -> Vdom.Node.t Bonsai.t
(** [view ~label ~value ~on_change graph].

    [value] is the committed value ([None] = empty); [on_change] fires only on commit
    boundaries (blur/Enter/steppers/clear) and never while the draft is invalid. With
    [has_clear] the callback also receives [None] when the user clears. [min]/[max]
    clamp a committed draft; stepping never passes them. [is_read_only] disables
    editing, the steppers and the wheel while keeping the value visible and submitted;
    [disabled_message] keeps the input focusable ([aria-disabled]) and shows the reason,
    like {!Slider}. Both are graph values on purpose: the DOM follows application state
    the same way [Text_input] does. *)
