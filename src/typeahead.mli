(** Typeahead — a text field with a filtered list of suggestions.

    Upstream ships the family as three components: [BaseTypeahead] (the unstyled combobox),
    [Typeahead] (the styled field around it) and [TypeaheadItem] (the default row). The port keeps
    those three boundaries inside one module: {!Base} is the unstyled combobox, {!Item} is the
    default row, and [view] is the styled field.

    {2 What the component owns}

    The query text, the result list, the highlighted option and whether the list is open are the
    component's own state — upstream keeps exactly that in [BaseTypeahead]. The application owns
    the selection ([value] / [on_change]). The search itself is synchronous: a Bonsai effect
    cannot await the asynchronous work, so [source.search] answers a query at once.

    {2 The combobox semantics}

    The input is a [role="combobox"] that owns the listbox:

    - [aria-expanded] says whether the list is open, [aria-controls] points at the listbox, and
      [aria-autocomplete="list"] says the input completes from a list;
    - [aria-activedescendant] names the highlighted option, so {b focus stays in the input} while
      the highlight moves — the ARIA 1.2 combobox pattern, and the reason the options carry
      [tabindex="-1"] and are never focused;
    - the list is [role="listbox"], each row is [role="option"] with [aria-selected], and a
      grouped run of options is a [role="group"] with the group name as its label;
    - [aria-busy] is set while the application reports a search in flight.

    Upstream keeps the DOM focus in the input and moves the highlight with [aria-activedescendant],
    and so does the port — the keyboard contract is Arrow/Enter/Escape, not a roving tab stop.

    {2 Deliberate divergences from upstream}

    - {b The source is synchronous.} Upstream's [SearchSource.search] may return a promise, and
      upstream then owns the loading state, a generation counter that drops a stale response, and
      cancellation. A Bonsai effect cannot await a promise, so [search] here is a plain function
      of the query: it returns the items to show. Upstream's queries are debounced ([debounceMs],
      150ms by default); a Bonsai effect cannot await a timer either, so a query runs at once and
      there is no busy state, no spinner and no "loading" row. The application's share of the
      contract is [on_query_change] (the query to search for). Upstream's generation counter,
      [cancel] and [debounceMs] have no counterpart here and are not ported — the same contract
      the Tokenizer port settled on.
    - {b The list is drawn in place}, not in the platform's top layer: the port has no portal and
      no anchor-positioning engine, so the list is an absolutely positioned element beside the
      input, and it closes on blur, on Escape and on selection.
    - {b No [action] on an item.} Upstream declares the field and warns that the panel does not
      render it; the port has no field for it.
    - {b [auxiliary_data] is required} where upstream's is optional, and upstream's [element] still
      takes priority over [render_item] and over the default label rendering.
    - {b The selected value is not shown as a token.} Upstream's styled [Typeahead] collapses the
      input and shows the selection as a [Token] with an edit mode of its own; the port keeps the
      input, and reports the selection through the dropdown's selected row and the clear button.
    - {b No [disabled_message], [label_tooltip], [anchor_ref], [menu_width], [input_tab_index],
      [aria_described_by], [aria_labelled_by], [on_key_down] or [__query_entries].}
    - {b No busy-indicator lane.} Upstream's styled typeahead hands its spinner to a lane the
      field owns; the port renders the spinner in the input row.
    - The listbox and empty-state labels are English ("Search results", "No results found"); the
      port has no i18n catalogue.
    - Upstream measures [min_query_length] in grapheme clusters; the port counts UTF-16 code
      units. *)

open! Core
open! Bonsai_web

(** One suggestion. Upstream's [SearchableItem]: an id (the key and the identity of the selection),
    a label (the default rendering), the caller's own data, and an optional pre-rendered element
    that takes priority over [render_item] and over the default label rendering. *)
type 'a item =
  { id : string
  ; label : string
  ; group : string option  (** the group this option belongs under, if any *)
  ; auxiliary_data : 'a
  ; element : Vdom.Node.t option
  }

(** Where the suggestions come from. Upstream's [SearchSource], with the promise out of it: [search]
    is called with the current query and returns the items to show; [bootstrap] returns the items
    to show before anything has been typed. *)
type 'a source =
  { search : string -> 'a item list
  ; bootstrap : unit -> 'a item list
  }

(** A source over a fixed list, matching on the label and on any extra keywords the caller
    supplies. Upstream's [createStaticSource]. *)
val create_static_source : ?keywords:('a item -> string list) -> 'a item list -> 'a source

(** The default row. Upstream's [TypeaheadItem]: the item's own element when it has one, and
    otherwise the label, an optional description, and an optional icon. *)
module Item : sig
  val view
    :  ?icon:Vdom.Node.t
    -> ?description:string
    -> ?is_disabled:bool
    -> 'a item
    -> Vdom.Node.t
end

(** The unstyled combobox. Upstream's [BaseTypeahead]: the input, the list, and the keyboard
    contract, with no field chrome around them. *)
module Base : sig
  val view
    :  ?id:string
    -> ?placeholder:string
    -> ?is_disabled:bool
    -> ?is_focusable_disabled:bool
    -> ?has_auto_focus:bool
    -> ?has_entries_on_focus:bool
    -> ?max_menu_items:int
    -> ?min_query_length:int
    -> ?empty_search_text:string
    -> ?render_item:('a item -> Vdom.Node.t)
    -> ?on_change:('a item option -> unit Effect.t) Bonsai.t
    -> ?on_query_change:(string -> unit Effect.t) Bonsai.t
    -> ?on_open_change:(bool -> unit Effect.t) Bonsai.t
    -> ?attrs:Vdom.Attr.t list
    -> source:'a source
    -> value:'a item option Bonsai.t
    -> Bonsai.graph
    -> Vdom.Node.t Bonsai.t
  (** [view ~source ~value graph].

      [source] is where the items come from and [value] is the selected item ([None] for nothing
      selected). [on_change] reports the new selection — [None] when the selection is cleared.
      [on_query_change] reports every query change, which is how an application learns what to
      search for. [on_open_change] reports the list opening and closing.

      [has_entries_on_focus] shows the source's bootstrap items when the input is focused and
      nothing has been typed. [max_menu_items] caps the list (upstream's default is 10) and
      [min_query_length] is the shortest query worth searching for (upstream's default is 1);
      below it nothing is searched and no menu is opened, so a query nobody searched for is never
      reported as a search that found nothing. [empty_search_text] is what the list shows when a
      search found nothing.

      A focusable-disabled input keeps [aria-disabled] and [readOnly] instead of the native
      [disabled], so a reason attached to it stays discoverable; the text cannot be changed, but
      an option that is already highlighted can still be selected with Enter. *)
end

(** The styled typeahead. Upstream's [Typeahead]: the field chrome, the input, and the list. *)
val view
  :  ?id:string
  -> ?description:string
  -> ?is_label_hidden:bool
  -> ?is_required:bool
  -> ?is_optional:bool
  -> ?status:Input_types.status
  -> ?status_variant:Field_status.placement
  -> ?start_icon:string
  -> ?width:Common.Size_value.t
  -> ?size:Input_types.size
  -> ?placeholder:string
  -> ?is_disabled:bool
  -> ?has_clear:bool
  -> ?has_auto_focus:bool
  -> ?has_entries_on_focus:bool
  -> ?max_menu_items:int
  -> ?min_query_length:int
  -> ?empty_search_text:string
  -> ?render_item:('a item -> Vdom.Node.t)
  -> ?on_change:('a item option -> unit Effect.t) Bonsai.t
  -> ?on_query_change:(string -> unit Effect.t) Bonsai.t
  -> ?on_open_change:(bool -> unit Effect.t) Bonsai.t
  -> ?attrs:Vdom.Attr.t list
  -> source:'a source
  -> value:'a item option Bonsai.t
  -> label:string
  -> Bonsai.graph
  -> Vdom.Node.t Bonsai.t
(** [view ~label ~source ~value graph].

    The field chrome is {!Field}'s (the label, the description and the status), and the control
    itself is the {!Base} combobox, so the two views behave identically.

    [start_icon] is an icon {i name} from the generated registry. [has_clear] shows a button that
    clears the selection ([on_change] with [None]); it shows only when there is a selection.
    [size] is the control's size. Everything else is {!Base}'s, and is documented there. *)
