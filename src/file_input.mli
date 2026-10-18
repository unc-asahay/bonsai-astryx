(** FileInput — a labelled file picker: a drop-zone or a compact control whose
    trigger is a real [<input type="file">] reached through a visually-hidden
    button.

    {2 What the port owns}

    - The {b trigger contract}: the container is a non-interactive surface that
      opens the picker on click, Enter and Space (the button answers Enter by
      itself, so the keydown handler on the trigger calls [click] only for
      Space — see the note in the implementation), with the
      {!Common.Clickable_container} rules: a click that ends a text selection is
      ignored, and a click on a nested clear button is left alone. The visible
      focus feedback is the container's [focus-within] border.
    - {b Validation} — [accept] (extensions, [type/*] wildcards, exact MIME),
      [max_size] and [max_files] (multiple only) — is pure and unit-tested in
      OCaml the way [Overflow_math] is; the first error becomes the Field's
      error status. Errors are announced by the {!Field_status} the derived
      status mounts (assertive), and a successful attach is announced politely
      through a persistent [role=status] live region ([forms-17]).
    - {b The reveal matrix}: dropzone drag-and-drop (dragenter/dragover set the
      drag-over state, dragleave only when the pointer actually exits, drop
      feeds {!validate_files}), compact vs dropzone content, a clear button
      (shown when files are selected and not busy), and a disabled reason shown
      as a tooltip above the container while the trigger stays focusable via
      [aria-disabled] so a screen-reader user can discover why the picker is
      blocked — opening stays blocked by the [is_disabled] guards.

    {2 The file representation, and the one named divergence}

    The port cannot hand out live [File] objects (there is no OCaml type for
    one, and nothing here stores a JS value in the application's state), so
    [on_change] delivers {!t} — name, size and MIME read off the DOM [File]; the
    native input still holds the real objects, and the picker, drag-drop and
    accept-filtering are the browser's. An application that needs the stream
    for an upload re-reads the file itself (the input's files are reachable on
    the element it named with [~input_id?] — no: the input is rendered inside
    the component, so the upload is driven from [on_change] with the metadata
    and a separate fetch of the application's own file). Stated plainly: this
    port validates and announces, and hands the application the metadata; the
    byte stream belongs to the application's own [File] source.

    {2 Controlled, like every other input}

    [value] is a {!Bonsai.t} and [on_change] produces an [Effect.t], so the DOM
    follows the application's state. Upstream's [useOptimistic] + [useTransition]
    pair exists to keep a slow async [changeAction] from fighting the browser's
    own echo; here the loading state is [is_loading], owned by the application,
    so there is no race to fight and [changeAction] is not ported — [is_busy] is
    [is_loading]. Named divergence.

    {2 Missing by design, with reasons}

    - {b [changeAction]}: needs the optimistic/transition pair (above) — do not
      pass an async callback; the application does its upload from [on_change]
      and flips [is_loading] itself.
    - {b [label_tooltip]}: {!Field} has no label-tooltip slot (named in
      {!Text_input}); the reason is the same.
    - {b The Layer}: the disabled-reason tooltip is the port's {!Tooltip},
      positioned in place, exactly as {!Tooltip} documents. *)

open! Core
open! Bonsai_web

(** [mode] — upstream's [FileInputMode]. *)
type mode =
  | Input  (** compact, inline, like a text input (default) *)
  | Dropzone  (** larger area with a dashed border and drag-and-drop *)

type status_type = Input_types.status_type =
  | Warning
  | Error
  | Success

type status_variant = Field_status.placement =
  | Attached
  | Detached
  | Tooltip

(** A selected file, as the port hands it to the application. *)
type t =
  { name : string
  ; size : int
  ; mime : string
  }
[@@deriving sexp_of]

(** Pure validation — unit-tested in OCaml, no DOM. [accept] is the HTML
    [accept] attribute format (".pdf,.doc", "image/*", "image/png"). The first
    error reported is the one upstream keeps ([errors[0]]). Returns the files
    that passed and the errors. *)
val validate_files
  :  ?accept:string
  -> ?max_size:int
  -> ?max_files:int
  -> ?is_multiple:bool
  -> t list
  -> t list * string list

val view
  :  ?mode:mode
  -> ?accept:string
  -> ?is_multiple:bool
  -> ?max_size:int
  -> ?max_files:int
  -> ?is_disabled:bool
  -> ?disabled_message:string
  -> ?is_required:bool
  -> ?is_optional:bool
  -> ?is_loading:bool
  -> ?status:Input_types.status
  -> ?status_variant:status_variant
  -> ?description:string
  -> ?placeholder:string
  -> ?width:Common.Size_value.t
  -> ?attrs:Vdom.Attr.t list
  -> ?id:string
  -> label:string
  -> value:t list option Bonsai.t
  -> on_change:(t list option -> unit Effect.t) Bonsai.t
  -> Bonsai.graph
  -> Vdom.Node.t Bonsai.t
(** [view ~label ~value ~on_change graph]. The container carries the
    [data-astryx-component="FileInput"] marker; the trigger button is visually
    hidden and carries the accessible name — [label] alone, or [label] with the
    selected file names when files are attached, so a screen-reader user
    refocusing the control can tell what is attached. *)
