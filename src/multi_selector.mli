(** MultiSelector — the multi-select field (upstream
    [packages/core/src/MultiSelector/MultiSelector.tsx], with its keyboard model in
    [MultiSelector/hooks.ts]).

    {2 What it is}

    A field that shows a summary of the values the application has chosen and, when opened, a
    list of options out of which several can be chosen at once. The selection model is a set
    of string values; the summary the field shows is either a count, the chosen labels, or a
    row of badges.

    {2 The selection model}

    The port is controlled, as upstream is: [value] is the current set of chosen values and
    [on_change] is called with the next set whenever the user toggles an option, clears the
    selection or selects everything. The port never holds the selection itself, so the
    application is the single source of truth for what is chosen.

    {2 The options list}

    [options] is a list of [option_item]s: plain options, dividers, and sections. A section's
    options sit under its title and the group is one [role="group"] in the listbox, labelled
    by the title, as upstream renders it. An option that is [is_disabled] is still listed and
    still announced, but it cannot be chosen.

    {2 The search field}

    With [has_search], the listbox gets a search box in its header and the option list is
    filtered by it, matching the option's label or value, case-insensitively, the way
    upstream filters.

    {2 The keyboard model}

    The port carries upstream's combobox keyboard model: the arrow keys move the highlight,
    Home/End (and PageUp/PageDown) jump to the first and last enabled option, Enter or Space
    toggles the highlighted option, Escape closes the list, and — when there is no search box
    — typing letters jumps to the option whose label starts with what was typed. The
    highlight is reported with [aria-activedescendant]; the DOM focus stays on the trigger,
    or on the search box when there is one.

    {2 Divergences from upstream}

    - {b The list is a native [popover] surface, not a portal.} The OCaml layer has no portal
      and no outlet, so a surface upstream draws in a portal is drawn in place: the listbox
      sits in the DOM next to the field and the platform's own [popover] mechanism promotes it
      to the top layer, dismisses it on an outside pointer press and on Escape, and anchors
      it to the trigger. This is the same mechanism {!Complex_selector} and {!Popover} stand
      on, not a new one.
    - {b No imperative [handleRef].} Bonsai has no imperative handle to hand out, so the port
      offers the same control as {!Complex_selector} and {!Dropdown_menu}: pass both
      [?is_open] and [?on_open_change] to drive the list, or neither to let it own its state.
      [?on_open_change] alone is an observation callback.
    - {b [changeAction] and the optimistic value are not ported.} Upstream commits with
      [useTransition] + [useOptimistic] so a slow action cannot fight the browser's echo. The
      standing house call (M48) is that a Bonsai effect cannot await the async action, so
      [?is_loading] replaces the pair: the application owns the async work and reports it
      with [is_loading], which drives the trigger spinner and [aria-busy]. [on_change] is
      called with the next value and nothing else.
    - {b [hasCreate] (the create row), the per-option [action] and the grid it turns the
      popup into, and [hasSelectAll] are not ported.} They are separate features with their
      own contracts (a create row needs a name from the caller; an action is a node the
      caller renders; select-all needs a tri-state row of its own). The port covers the
      field, the option list, the search field, the keyboard model, the open/close behaviour,
      the empty and disabled states and the chosen-values summary.
    - {b [renderTrigger] (the caller-rendered opener) is not ported}, for the same reason as
      in {!Complex_selector}: an opener the port does not own cannot be anchored to the
      surface.
    - {b [isReadOnly] is not ported}: it is a third trigger appearance (the value stays
      visible, the list never opens) and upstream's version is tied to its read-only chrome.
    - {b [renderOption] is not ported}: options are rendered by the port, from
      [option_data], so an option's [description] is the port's own text.
    - {b [presentation] (the bottom-sheet and adaptive forms) is not ported}: the port has
      the one surface upstream's default configuration uses.
    - {b The English strings are fixed} — placeholder ["Select..."], the search placeholder
      ["Search..."], the empty texts ["No options" / "No results"] — and there is no i18n
      provider. The press-feedback transform is the campaign-wide named omission: the
      [active] scale is reproduced, the data-astryx-press overlay is not.

    {2 A note on ids}

    [id] is the trigger button's id (upstream semantics — the field label points at it), and
    [listbox_id = id ^ "-listbox"], [search_id = id ^ "-search"], [label_id = id ^ "-label"]
    and the description/status ids [id ^ "-desc"] / [id ^ "-status"] are derived. Pass a
    distinct [id] per instance on a page. *)

open! Core
open! Bonsai_web

type variant =
  | Input  (** the field-input look — the default *)
  | Secondary  (** the secondary-button look: neutral fill, borderless *)
  | Ghost  (** the ghost-button look: borderless, transparent *)

type size = Input_types.size =
  | Sm
  | Md
  | Lg

type status = Input_types.status =
  { type_ : Field_status.type_
  ; message : string option
  }

type trigger_display =
  | Count  (** ["3 selected"] — how many values are chosen *)
  | Labels  (** the chosen labels, the first three then ["+N"] *)
  | Badges  (** a badge per chosen label, up to [max_badges], then ["+N"] *)

type indicator_position =
  | Start  (** the indicator leads the option's text *)
  | End  (** the indicator trails the option's text *)

type option_data =
  { value : string  (** the value this option contributes to the selection *)
  ; label : string option  (** the text shown for it; [value] when absent *)
  ; description : string option  (** the second line under the label *)
  ; is_disabled : bool  (** listed and announced, but not choosable *)
  }

type option_item =
  | Option of option_data
  | Divider
  | Section of section

and section =
  { title : string option  (** the group's heading; the group is unlabelled without one *)
  ; options : option_data list
  }

type selected_item =
  { value : string
  ; label : string
  }

val view
  :  ?attrs:Vdom.Attr.t list
  -> ?id:string
  -> ?is_open:bool Bonsai.t
  -> ?on_open_change:(bool -> unit Effect.t) Bonsai.t
  -> ?is_label_hidden:bool
  -> ?description:string
  -> ?is_optional:bool
  -> ?is_required:bool
  -> ?is_disabled:bool
  -> ?is_loading:bool
  -> ?status:status
  -> ?status_variant:Field_status.placement
  -> ?size:size
  -> ?variant:variant
  -> ?placeholder:string
  -> ?start_icon:string
  -> ?width:Common.Size_value.t
  -> ?has_search:bool
  -> ?search_placeholder:string
  -> ?has_clear:bool
  -> ?empty_text:string
  -> ?empty_search_text:string
  -> ?trigger_display:trigger_display
  -> ?max_badges:int
  -> ?format_value:(selected_item list -> string)
  -> ?indicator_position:indicator_position
  -> ?html_name:string
  -> ?is_default_open:bool
  -> label:string
  -> options:option_item list
  -> value:string list Bonsai.t
  -> on_change:(string list -> unit Effect.t) Bonsai.t
  -> Bonsai.graph
  -> Vdom.Node.t Bonsai.t
(** [view ~label ~options ~value ~on_change (graph)].

    Defaults, all upstream's: [size = Md], [variant = Input], [status_variant = Attached] —
    which upstream demotes to [Detached] for [Secondary]/[Ghost] selectors, and this port does
    the same. [is_loading = false], [has_search = false], [has_clear = false],
    [trigger_display = Count], [max_badges = 3], [indicator_position = Start],
    [is_default_open = false], placeholder ["Select..."], search placeholder ["Search..."],
    empty text ["No options"], empty search text ["No results"].

    [value] is the set of chosen values and [on_change] is called with the next set. [options]
    is the list the user chooses from — it is read on every render, so the application may
    change it.

    [?format_value] replaces the summary text for the [Count] and [Labels] displays; it is
    given the chosen items, each with the label the option list gives it. The [Badges]
    display ignores it, as upstream's does.

    [?html_name] names a hidden input per chosen value, so the selection submits with a form.
    The hidden inputs are disabled with the field, as upstream's are. *)
