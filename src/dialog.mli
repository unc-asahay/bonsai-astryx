(** A modal surface built on the platform's own [<dialog>] element.

    This is the first component of the overlay pillar that gets its behaviour from the browser rather
    than reimplementing it. A [<dialog>] opened with [showModal()] is put in the top layer, made
    inert outside, given a real focus trap, closed by Escape, and drawn over a [::backdrop]; none of
    that is written here, and upstream reaches for the same element for the same reason.

    {2 Why the state lives in a value and the DOM call lives in a hook}

    [is_open] is the caller's, as upstream's [isOpen] is: the dialog does not own whether it is on
    screen. But [showModal]/[close] are DOM calls that must follow that value, and no event fires
    when a caller changes their own state — which is the case Gate 23 exists for. {!Common.Delay_hook}
    showed the mechanism (a vdom hook whose input carries the value), and this module uses it
    directly: the hook compares the input it is given on each update and opens or closes to match. A
    dialog that only opened inside a click handler could not be closed by the application, and one
    that rendered the [open] attribute would be a non-modal dialog wearing a modal's name.

    {2 Dismissal is three behaviours, not one}

    Upstream's [purpose] is a matrix and each cell is a decision about the user:

    - [Info] (the default) — Escape closes it and a backdrop click closes it.
    - [Form] — Escape closes it, a backdrop click does not. A half-filled form should not be lost to
      a stray click.
    - [Required] — neither closes it, and the element carries [role="alertdialog"] instead of
      nothing, because a dialog that refuses every exit is a dialog the user must answer.

    The port keeps that shape exactly, including that [Required] rather than [Info] is what makes it
    an alert dialog.

    {2 Divergences, named rather than discovered}

    - {b The Layer}. Upstream runs a modal outlet, a scroll lock, a depth context and a directional
      open animation sourced from the element that triggered it. None of that is ported: this dialog
      is positioned by CSS and the browser's own top layer. What that costs is the depth stack (two
      dialogs do not know about each other), the scroll lock on the page behind, and the directional
      animation. The focus restoration upstream does is ported, because it is a behaviour rather than
      a flourish.
    - {b [is_inline]} is kept because upstream documents it as the showcase path, and in a port it
      earns its keep twice: it renders the same content as ordinary markup with no top layer, which
      is the only way a jsdom gate can say anything about the structure at all. Upstream returns null
      when an inline dialog is closed; the port renders nothing.

    {2 Sizing}

    [width] and [max_height] are CSS strings here rather than numbers-or-strings: upstream turns a
    number into pixels, and the port leaves that to the caller so the type says what it means. *)

open! Core
open! Bonsai_web

(** Upstream's [DialogVariant]. [Fullscreen] ignores [width], [max_height] and [position]. *)
type variant =
  | Standard
  | Fullscreen

(** How hard the dialog is to dismiss. Upstream's [DialogPurpose]. *)
type purpose =
  | Info
  | Form
  | Required

(** A static place on screen. Each field is a CSS length ("2rem", "10%"); [None] means "auto", which
    is what keeps the dialog centred. Upstream's [DialogPosition], whose [start]/[end] are logical
    rather than left/right so they follow the writing direction. *)
type position =
  { top : string option
  ; bottom : string option
  ; start : string option
  ; end_ : string option
  }

val view
  :  ?attrs:Vdom.Attr.t list
  -> ?is_inline:bool
  -> ?width:string
  -> ?max_height:string
  -> ?position:position
  -> ?variant:variant
  -> ?purpose:purpose
  -> ?padding:Common.Spacing.t
  -> ?labelled_by:string
  -> is_open:bool Bonsai.t
  -> on_open_change:(bool -> unit Effect.t) Bonsai.t
  -> id:string
  -> children:Vdom.Node.t list
  -> unit
  -> Vdom.Node.t Bonsai.t
(** [view ~is_open ~on_open_change ~id ~children ()]. No graph, unlike {!Tooltip.view}: the DOM side
    is a *hook*, which is an attribute rather than a state, so nothing here needs one.

    Both [is_open] and [on_open_change] are trees, and they have to be: a caller holding a state
    setter cannot produce either as a plain value, and the node cannot be built before the value is
    known. That is the same constraint {!Dropdown_menu.view} meets by taking the graph, met here by
    taking the pair and mapping it.

    [on_open_change] is how every path out of the dialog is reported: Escape (unless [purpose] is
    [Required]), a backdrop click (only for [Info]), and anything the caller's own content does. It is
    the *caller* who actually closes the dialog, by setting their [is_open] to false — the dialog
    never closes itself, so there is one source of truth.

    [labelled_by] names the element that titles the dialog, which the platform requires of a modal:
    upstream wires this automatically when a [DialogHeader] is among its children, reading a React
    context. A port has no such context — a child here is already built when the container sees it —
    so it is an argument, and the reasoning is the same one recorded for [Form_layout]'s optionality.
    Pass the title element's id. *)
