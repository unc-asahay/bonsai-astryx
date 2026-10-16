(** The types every field-composed input shares.

    Upstream keeps these in [Field/types.ts] under [Input*] names: one status type, one set of
    three sizes, and one status record — used by TextInput, TextArea, DatePicker, TimePicker and
    the rest. Sharing them here rather than letting each control declare a private copy is what
    stops two inputs from disagreeing about what [lg] means, or about whether a status is allowed
    to carry no message at all.

    [status_type] is {!Field_status.type_} rather than a second union with the same three
    constructors: upstream's [InputStatusType] and its FieldStatus type carry the same strings, and
    a port that declared both would need a conversion function whose only purpose is to move a
    value from one spelling of itself to the other. *)

open! Core

(** Standard size options for input components. *)
type size =
  | Sm
  | Md
  | Lg

(** The validation state of an input. *)
type status_type = Field_status.type_ =
  | Warning
  | Error
  | Success

(** A status *is* its type plus a message that may be absent.

    The absent case is not an edge case: upstream renders the coloured border and the status
    indicator without a message box when there is nothing to say yet, which is how a form marks
    a field invalid before the user has typed enough for a reason. A port that required a message
    would push callers into inventing one. *)
type status =
  { type_ : status_type
  ; message : string option
  }
