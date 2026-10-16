(** A multi-line text control: the same Field wrapper as {!Text_input}, with a [textarea] inside.

    Upstream's TextArea is TextInput's sibling in the input family — the same status, sizes,
    optional/required markers and description — so the two share {!Input_types} here and differ
    only in the control element and the props that element has (a row count, spell check). *)

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
  | Attached
  | Detached
  | Tooltip

val view
  :  ?description:string
  -> ?is_label_hidden:bool
  -> ?is_optional:bool
  -> ?is_required:bool
  -> ?is_disabled:bool
  -> ?is_read_only:bool
  -> ?placeholder:string
  -> ?status:Input_types.status
  -> ?status_variant:status_variant
  -> ?size:size
  -> ?width:Common.Size_value.t
  -> ?html_name:string
  -> ?auto_complete:string
  -> ?rows:int
  -> ?has_spell_check:bool
  -> ?attrs:Vdom.Attr.t list
  -> label:string
  -> id:string
  -> value:string Bonsai.t
  -> on_change:(string -> unit Effect.t) Bonsai.t
  -> unit
  -> Vdom.Node.t Bonsai.t
(** [view ~label ~id ~value ~on_change ()] — TextInput with a multi-line control.

    [rows] is the number of visible text rows and defaults to 3, as upstream does; the browser
    sizes the box from it, so the port does not need to measure text to give a textarea a height.
    [has_spell_check] defaults to [true], also upstream's default.

    The value is rendered as the control's child text rather than a [value] attribute, because
    browsers ignore that attribute on a [textarea] — the element's child {i is} its value. React
    hides the difference by treating [value] on a textarea as a property assignment; here the
    child text is the same DOM state, and Vdom diffs against the previous tree rather than the
    live DOM, so a re-render that did not change the value leaves what the user typed alone.

    [status] with no message is legal and common — the control takes the colour and the caller
    says nothing yet. In that case no message box is rendered and the status id is not referenced,
    exactly as upstream's [statusVariant !== 'tooltip' && status?.message] guard does.

    Not ported from upstream's TextArea: the loading spinner ([isLoading]), the clear button
    ([hasClear]) and auto-focus. Each is a real feature and each is honest work; none is needed by
    the base control, and half of one would be worse than none. *)
