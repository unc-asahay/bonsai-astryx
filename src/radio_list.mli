(** A group of radios: one choice out of several, with the group's own label.

    Upstream composes [`Field`] here rather than [`FieldLabel`] — unlike a checkbox, a radio group *is*
    a form field: the label describes the set, not any one control, so it is rendered as a group label
    (a [`<span>`] the group names itself from with [aria-labelledby]) and the status message sits
    below the whole set.

    The keyboard is the reason this component is cheaper than its 1,781 lines suggest. A *native* radio
    group already implements roving focus and arrow-key selection: radios sharing a [name] are one tab
    stop, the arrows move between them **and select**, and the browser restores the last selection when
    focus returns to the group. Upstream re-implements some of that by hand; the port does not need to,
    and the real-browser gate presses the keys rather than trusting the claim.

    One difference from upstream, stated rather than hidden: upstream renders each item's label as a
    plain [`<span>`] and points the input at it with [aria-labelledby], because its event delegation
    would make a real [`<label for>`] fire the change twice. The port has no delegation, so its items
    use a real [`<label for>`] — which names the radio the same way *and* makes the label clickable. *)

open! Core
open! Bonsai_web

type item =
  { value : string
  ; label : string
  ; description : string option
  ; is_disabled : bool
  }
[@@deriving sexp_of]

type orientation =
  | Vertical
  | Horizontal

val view
  :  ?attrs:Vdom.Attr.t list
  -> ?is_disabled:bool
  -> ?is_label_hidden:bool
  -> ?is_optional:bool
  -> ?is_required:bool
  -> ?label_icon:string
  -> ?description:string
  -> ?status:Input_types.status
  -> ?size:Indicator.size
  -> ?orientation:orientation
  -> label:string
  -> id:string
  -> items:item list
  -> value:string Bonsai.t
  -> on_change:(string -> unit Effect.t) Bonsai.t
  -> unit
  -> Vdom.Node.t Bonsai.t
(** [view ~label ~id ~items ~value ~on_change ()]. [id] is the group's base id: it names the group
    element, the radios inside it ([id ^ "-item-0"], …) and the ids the description and status are
    linked by.

    The description's id is [id ^ "-desc"] and the status message's is [id ^ "-status"], because
    [`Field`] renders both and owns those ids; the group points at them rather than the caller having
    to name them.

    [value] and [on_change] are both {!Bonsai.t}s. [value] drives each radio's [checked] *property*, so
    the selection cannot drift from the application's, and a click reports the value of the radio that
    was chosen.

    Clicking the radio that is *already* selected changes nothing and reports nothing — a native
    [change] event does not fire when the checkedness did not change, and reporting it anyway would
    invite an application to re-run an action the user did not ask for.

    Not ported, each for a reason: the disabled-message tooltip and the group's `defaultOptionality`
    (which belongs to [`Form_layout`]); upstream's [`RadioListItem`] is a separate component that talks
    to its list through React context, and the port takes the items as data instead — the same shape,
    since a context is not something a statically-typed tree needs to fake. *)
