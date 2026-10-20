(** Selector — the single-value combobox: a closed trigger that opens a listbox of options.

    Port of upstream `Selector/Selector.tsx` (+ `types.ts`, `utils.ts`, `hooks.ts`).

    The trigger is a real form control: a [<button role="combobox">] carrying the selected
    value, inside the house {!Field} (so the label, the description and the status message
    are the field's), and the selection surface is a listbox that hangs off it.

    {2 The shape of the widget}

    - The trigger is {b ours}. The component builds the control box, the button, the spinner,
      the clear button and the chevron, and the ARIA goes on the button it builds — the same
      arrangement {!Complex_selector} reached for.
    - The surface is the {b native [popover] mechanism}, exactly as {!Popover} and
      {!Complex_selector} stand on: the platform owns the top layer, the outside-pointer
      dismissal, Escape and the CSS anchor positioning against the trigger box. {b This port
      has no portal}: upstream renders the surface through a React portal, so the panel is
      rendered {b in place} — as a sibling of the trigger inside the field — and the platform
      lifts it to the top layer, which is what the house's other layers do. There is no
      outlet, so a caller who needs the panel somewhere else cannot have it there.
    - The listbox is the exposed semantics: [role="listbox"] on the panel's list, [role="row"]
      on each row, and the trigger keeps DOM focus while the list is open, reporting the
      highlighted row through [aria-activedescendant] — the combobox relationship upstream
      keeps (ARIA AR2).

    {2 The selection model}

    One value, chosen from the options. Upstream's ownership boundary is explicit about it:
    "Multi-value selection; MultiSelector owns it." This port keeps that boundary — the
    multiple-selection surface is a different component upstream, and it is {b not} ported
    here. What is shared is the row model ([option_data]), so a future multi-selector can
    be built on the same records.

    {2 Divergences from upstream, each recorded where it is decided}

    - {b The value contract is [string option], not upstream's discriminated union.} Upstream
      splits its props into a non-clearable shape ([value?: string]) and a clearable one
      ([value: string | null]); this port has one shape: [value : string option Bonsai. The row union is named [row], not [option], because this module's own type would otherwise shadow the standard option from the point it is declared on.t]
      ([None] is the placeholder state) and [on_change : (string option -> unit Effect.t)
      Bonsai.t], which receives [None] when the value is cleared. Clearing is only reachable
      with [~has_clear], so a non-clearable selector's [on_change] never sees [None].
    - {b The selected-item overlay alignment is not ported} (upstream's FR2: with no explicit
      placement, the panel is pulled up so the {e selected} row sits over the trigger, macOS
      style). This port opens the panel {e below} the trigger, with the house's anchor
      positioning. [~placement] is not offered either, because upstream's placement values are
      layer placements this port has no equivalent of.
    - {b Only the anchored popover presentation is ported.} Upstream's [presentation] prop
      chooses between an anchored popover, a modal bottom sheet, and [adaptive] (the sheet on
      a compact coarse-pointer screen, the popover elsewhere). The house has no bottom sheet
      and no coarse-pointer policy, so the panel is always the anchored popover.
    - {b [~disabled_message] is announced, not hovered.} Upstream puts the reason in a Tooltip
      on the control box. This port has no tooltip on the trigger, so the message is rendered
      as a visually-hidden description the trigger points at, and the trigger stays focusable
      through [aria-disabled] (upstream's own rule for a disabled control with a reason).
    - {b The typeahead runs on the model, not the DOM.} Upstream's shared typeahead reads the
      rows' text out of the DOM; this port matches the row labels in the model, because the
      listbox keeps DOM focus on the trigger and the rows are never focused.
    - {b No [changeAction] / optimistic value.} Upstream commits with a transition and an
      optimistic value so a slow action cannot fight the browser's echo. The standing house
      call (M48) is that a Bonsai effect cannot await the async action, so [~is_loading]
      replaces the pair: the application owns the async work and reports it with
      [~is_loading], which drives the trigger's spinner and [aria-busy].
    - {b [~render_option] and [~render_value] take the row record}, not a node tree: the
      port's icons are {i names} (the generated registry), not nodes.
    - The English strings are fixed: ["Select..."], ["Search..."], ["No options"] and
      ["No results found"] are upstream's own en catalogue. There is no i18n catalogue in this
      port. *)

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

type indicator_position =
  | Start  (** the mark is drawn at the row's logical start *)
  | End  (** the mark is drawn at the row's logical end — the default *)

type option_data =
  { value : string  (** the option's value; what [on_change] reports *)
  ; label : string option  (** the option's label; [value] when absent *)
  ; description : Vdom.Node.t option  (** a second line under the label *)
  ; icon : string option  (** an icon {i name}, rendered at the row's start *)
  ; is_disabled : bool  (** a disabled row cannot be picked or highlighted *)
  }

type section =
  { title : string option  (** the group's name; the heading is drawn from it *)
  ; options : option_data list
  }

type row =
  | Row of option_data  (** a selectable row *)
  | Divider  (** a rule between rows; hidden from assistive technology *)
  | Section of section  (** a titled group of rows *)

val row
  :  value:string
  -> ?label:string
  -> ?description:Vdom.Node.t
  -> ?icon:string
  -> ?is_disabled:bool
  -> unit
  -> option_data
(** [row ~value ()] builds a selectable row.

    [label] defaults to [value] (upstream's own normalization), [description] is a node
    rendered under the label, [icon] is an icon {i name} from the generated registry, and
    [is_disabled] makes the row unpickable. *)

val view
  :  ?attrs:Vdom.Attr.t list
  -> ?id:string
  -> ?is_label_hidden:bool
  -> ?description:string
  -> ?is_optional:bool
  -> ?is_required:bool
  -> ?is_disabled:bool
  -> ?is_read_only:bool
  -> ?disabled_message:string
  -> ?is_loading:bool
  -> ?status:status
  -> ?status_variant:Field_status.placement
  -> ?size:size
  -> ?variant:variant
  -> ?placeholder:string
  -> ?start_icon:string
  -> ?width:Common.Size_value.t
  -> ?html_name:string
  -> ?has_clear:bool
  -> ?has_search:bool
  -> ?search_placeholder:string
  -> ?empty_text:string
  -> ?empty_search_text:string
  -> ?indicator_position:indicator_position
  -> ?is_default_open:bool
  -> ?render_option:(option_data -> Vdom.Node.t)
  -> ?render_value:(option_data -> Vdom.Node.t)
  -> label:string
  -> options:row list
  -> value:string option Bonsai.t
  -> on_change:(string option -> unit Effect.t) Bonsai.t
  -> Bonsai.graph
  -> Vdom.Node.t Bonsai.t
(** [view ~options ~value ~on_change ()?>... (graph)].

    Defaults, all upstream's: [size = Md], [variant = Input], [indicator_position = End],
    [status_variant = Attached] — which upstream demotes to [Detached] for the
    [Secondary]/[Ghost] triggers, and this port does the same. [placeholder = "Select..."],
    [search_placeholder = "Search..."], [empty_text = "No options"],
    [empty_search_text = "No results found"], [is_loading = false], [is_default_open = false].

        [label] is the field's own label, as upstream's is: it names the control, and the
    field renders it (or hides it, with [~is_label_hidden]).

[value] is the controlled selection: [None] shows the placeholder. [on_change] receives
    the new value ([None] for a clear). The component owns its open state, its highlight and
    its search query.

    [~has_search] adds a search row to the panel: the query filters the rows (a
    case-insensitive substring match on the label), the search input is the combobox while
    the panel is open, and it takes the focus when the panel opens.

    [~has_clear] adds a clear button to the trigger, shown only while a value is selected.

    [~is_read_only] keeps the value visible, focusable and submittable while removing the
    selection surface, the clear button and the disclosure indicator; the trigger keeps
    [role="combobox"] and reports [aria-readonly="true"].

    [~disabled_message] explains why a disabled selector is disabled. The message is
    announced (a visually-hidden description the trigger points at) rather than hovered, and
    the trigger stays focusable through [aria-disabled]; activation stays blocked.

    [~html_name] adds a hidden input carrying the selected value under that name, the way a
    native select serializes.

    [~render_option] replaces a row's content (the row keeps its role, its selection state,
    its disabled state and its navigation); [~render_value] replaces the closed trigger's
    rendering of the selected row. *)
