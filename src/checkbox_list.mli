(** Checkbox_list — several choices at once, with the group's own label.

    Port of upstream [CheckboxList/CheckboxList.tsx] + [CheckboxListItem.tsx]. Like
    {!Radio_list}, the group is a form field: the label is a {i group} label (a
    [<span>] the group names itself from with [aria-labelledby]) and the status
    message sits below the whole set, because the label describes the set, not any
    one control. [{!Field}] renders both, with [is_group_label] and the status
    [Detached] — the exact composition Radio_list uses.

    The rows are [<li>]s carrying a [Checkbox_input] (its label hidden) plus the
    item's label, description and end content. The checkbox stays the row's single
    keyboard control, as upstream demands (WCAG 4.1.2 / APG checkbox pattern); a
    click anywhere on the row's surface delegates to the same control —
    upstream's [useClickableContainer], implemented here as the same small click
    delegation [Item] uses. The visible label is [<span>] text, never a second
    [<label for>]: the checkbox is named by its own hidden label exactly once,
    and row-surface clicks activate it, which is upstream's arrangement.

    {2 Collection mode}

    [value] is the list of selected values and [on_change] reports the new list;
    both are {!Bonsai.t}s. Each checkbox's checked property derives from [value]
    — never the other way round — so the application stays the source of truth,
    as [{!Checkbox_input.view}] documents for a single box. Toggling an item
    reports [value] with it added or removed; nothing else is reported. The
    caller's order is preserved: a newly selected value is *appended*, never
    re-sorted, so a readout the application renders from the list is stable.

    {2 Divergences (stated rather than hidden)}

    - {b Items are data, not composed children} — the same decision [Radio_list]
      made. The port has no React context through which a child the caller built
      could read the value array, and a context is not something a statically
      typed tree needs to fake.
    - {b [changeAction] is not ported.} It is an async React form action (the
      promise settles the item's spinner). A Bonsai effect cannot await a promise;
      the port takes [?is_loading] per item instead — the same in-checkbox
      spinner, with the in-flight state owned by the application.
    - {b The rows are built by this component} (as [Radio_list] builds its own)
      rather than through [List_item]/[Item.view]: a row's checkbox is driven by
      the list's value tree, and [List_item]'s start slot is a static node — a
      component cannot be called inside the [Bonsai.map] that holds the plain
      value. [density] and [has_dividers] are therefore declared as data
      attributes on the list element and styled by this component's CSS, the same
      data-driven route [List_container] uses to reach its rows, with upstream's
      defaults (balanced / false).
    - {b The standalone [CheckboxListItem]} (a select-all item inside a plain
      [List], driven by [isChecked]/[onCheck]) is not ported: its row is the same
      dynamic row and upstream keeps it as a separate exported component. When a
      consumer needs it, extract the row builder the way [Menu_focus] was.
    - {b No [onClick] on an item.} Upstream's consumer click; the checkbox is the
      row's action and row-surface clicks delegate to it.
    - {b A rich (ReactNode) label is not ported} — [label] is a string and gets
      single-line truncation, upstream's own rule for a plain string.
    - {b No [xstyle]/[className]/[style]}, per the port's class convention;
      [width] sizes the whole field through [Field], as upstream.
    - {b Fixed English text} where upstream resolves i18n: the loading spinner's
      "Loading" ([Spinner]'s own label). *)

open! Core
open! Bonsai_web

type item =
  { value : string
  ; label : string
  ; description : string option
  ; is_disabled : bool
  ; is_loading : bool
  ; end_content : Vdom.Node.t option
  }

val view
  :  ?attrs:Vdom.Attr.t list
  -> ?is_disabled:bool
  -> ?disabled_message:string
  -> ?is_read_only:bool
  -> ?is_label_hidden:bool
  -> ?is_optional:bool
  -> ?is_required:bool
  -> ?optionality:Common.Optionality.t
  -> ?label_icon:string
  -> ?description:string
  -> ?status:Input_types.status
  -> ?width:Common.Size_value.t
  -> ?density:List_container.density
  -> ?has_dividers:bool
  -> label:string
  -> id:string
  -> items:item list
  -> value:string list Bonsai.t
  -> on_change:(string list -> unit Effect.t) Bonsai.t
  -> unit
  -> Vdom.Node.t Bonsai.t
(** [view ~label ~id ~items ~value ~on_change ()]. [id] is the group's base id: it names the
    group element, and the rows derive theirs from it ([id ^ "-item-0"], … with
    [^ "-checkbox"] and [^ "-description"]).

    [disabled_message] explains {i why the whole group} is disabled (upstream's [disabledMessage]);
    it keeps every checkbox focusable ([aria-disabled] rather than the native attribute, so a
    reason can be discovered by keyboard and AT) and mounts one tooltip bubble, shown on hover and
    focus of the group — the house pattern [Slider] and [Checkbox_input] use. Toggling stays
    blocked. [is_read_only] disables toggling for the whole set while keeping focus,
    [item.is_disabled] is the per-item disabled flag and [item.is_loading] the per-item spinner.

    [items] is a plain list, so every variant a gate wants to prove is one call: collection mode
    with [value]/[on_change], group-disabled with and without the message, a loading item, and a
    described item. *)