(** Tokenizer — a multi-select field: token chips and a combobox input in one box.

    Upstream composes three components — {!Field}, {!BaseTypeahead} and {!Token} — and keeps
    the parts that belong to it (the token row, the end lane, the overflow behaviour) in one
    file. This port does the same: the field chrome comes from the house {!Field}, the chips
    from the house {!Token}, and everything between them — the combobox, the suggestion list,
    the end lane, the announcements — is here.

    {2 What the component is for}

    A {i controlled} multi-select: the application holds the list of selected items, and the
    component reports every change to it. Upstream's [value]/[onChange] pair is exactly that,
    and this port keeps the shape: [value] and [on_change] are {!Bonsai.t}s, so a state setter
    is what the caller passes and the DOM follows the application's state.

    {2 The ARIA, which is the reason the component exists}

    - The input is the control: one native input stays mounted across adding, removing,
      clearing and reaching the maximum (upstream's FR1). At the maximum it is still there —
      zero-width and transparent — so its identity, its focus and its label never move.
    - The suggestion list is a {b listbox}, not a menu. The input carries [role="combobox"],
      [aria-expanded], [aria-controls] and [aria-activedescendant]; the list carries
      [role="listbox"] and its rows [role="option"]. Focus never leaves the input: the
      highlight is an index and the active option is named by id.
    - The selected set is announced: a token that appears or disappears is said in a polite
      live region, because neither the chip nor its remove button says anything by itself.
    - A disabled field with a [disabled_message] keeps its input focusable and blocks it with
      [aria-disabled] plus [readonly], and explains itself in a [role="tooltip"] bubble —
      upstream's reason is that a disabled control swallows the hover events an external
      tooltip would need.

    {2 The overflow}

    [token_overflow_behavior] decides what a field that is too narrow for its tokens does:

    - [Wrap] — the tokens wrap to as many lines as they need. Upstream's default.
    - [Unfocused_inline] — while the field is not focused, the row collapses to one line
      that ends in a "+N more" indicator.
    - [Unfocused_layer] — as [Unfocused_inline], and the expanded row is raised above its
      ancestors rather than being clipped by them.

    The count in the indicator is {b measured}, not guessed: the tokens are rendered into a
    hidden measurement container and the house {!Common.Overflow_hook} reports how many of
    them fit, so the answer follows the width of the field.

    {2 Divergences from upstream}

    These are the surfaces upstream has and this port does not, each with its reason.

    - {b The search source is synchronous.} Upstream's [searchSource] returns promises and
      its queries are debounced ([debounceMs], 150ms by default); this port's [source.search]
      is a plain function and a query runs at once. There is therefore no busy state: no
      spinner in the end lane, and no "loading" row in the menu. Upstream's
      [hasEntriesOnFocus] bootstrap is the synchronous case upstream supports already
      ([debounceMs] of 0), so it is ported in full.
    - {b No [renderToken] and no [renderItem].} Upstream lets the caller draw the chips and
      the menu rows; this port draws them with the house {!Token} and with a plain option row.
    - {b No [handleRef].} Upstream's imperative handle ([focusInput], [focusFirstToken],
      [focusLastToken], [clearInput], [selectAll]) is React ref machinery with no Bonsai
      equivalent.
    - {b No [labelTooltip], no [containerXstyle], no [controlXstyle] and no
      [containerStyle]/[controlStyle].} The label is {!Field}'s, and the port-wide [?attrs]
      is where extra attributes go.
    - {b The menu is not a top-layer surface, and the layer variant is not promoted to one.}
      The OCaml layer has no portal and no outlet, so the suggestion list is an ordinary
      absolutely positioned element below the field, and the [Unfocused_layer] variant raises
      the expanded row with CSS rather than with a top layer. Upstream's [menuWidth] is
      honoured as a fixed width; upstream's "the menu never shrinks below its anchor width"
      is the stylesheet's job here.
    - {b [empty_search_text] is a string, not a ReactNode}, so the dead end cannot carry a
      link or a create row. It is announced in the live region as the text it renders.
    - {b The end lane is in flow, not absolutely positioned.} Upstream pins the lane to the
      field's first row and measures it, publishing the width as a custom property the input
      spends as padding ([useEndLaneReserve]). This port keeps the lane on the first row by
      wrapping the tokens inside the content row instead of wrapping the whole control, so
      the lane is a flex sibling of that row: the input can never run under it, and no
      measurement is needed. The lane moves to the last row of tokens when the tokens wrap
      past it, which upstream's pinned lane does not.
    - {b The overflow indicator reads "+N more" in the port's own words}, as upstream's
      [overflowRenderer] does; upstream's own default is "+N".

    {2 What is not ported at all}

    Nothing upstream has is faked here: every surface above is either ported or named here
    as absent. *)

open! Core
open! Bonsai_web

type item =
  { id : string  (** the item's unique identifier; what a form submits *)
  ; label : string  (** what the token shows, and what the search matches on *)
  }

type source =
  { search : string -> item list  (** the results for a query *)
  ; bootstrap : item list  (** the results shown before anything is typed *)
  }

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

type overflow_behavior =
  | Wrap  (** the tokens wrap to as many lines as they need — upstream's default *)
  | Unfocused_inline  (** one line with "+N more" while the field is not focused *)
  | Unfocused_layer  (** as [Unfocused_inline], but the expanded row is raised above its ancestors *)

type change_type =
  | Add  (** an item from the search results was selected *)
  | Create  (** free text was committed as a new item *)
  | Remove  (** an item was removed, by its button, by Backspace or by the clear button *)
  | Reorder  (** the items changed order; upstream's type carries it, nothing here produces it *)

type change =
  { type_ : change_type  (** what happened *)
  ; item : item option  (** the item it happened to; [None] when there was none *)
  }

val view
  :  ?id:string
  -> ?attrs:Vdom.Attr.t list
  -> label:string
  -> ?is_label_hidden:bool
  -> ?description:string
  -> ?is_required:bool
  -> ?is_optional:bool
  -> ?status:Input_types.status
  -> ?status_variant:status_variant
  -> ?size:size
  -> ?width:Common.Size_value.t
  -> ?placeholder:string
  -> ?start_icon:string
  -> ?end_content:Vdom.Node.t
  -> ?has_clear:bool
  -> ?on_item_click:(item -> unit Effect.t) Bonsai.t
  -> ?has_create:bool
  -> ?has_entries_on_focus:bool
  -> ?has_auto_focus:bool
  -> ?is_disabled:bool
  -> ?disabled_message:string
  -> ?max_entries:int
  -> ?max_menu_items:int
  -> ?min_query_length:int
  -> ?menu_width:int
  -> ?empty_search_text:string
  -> ?token_overflow_behavior:overflow_behavior
  -> ?html_name:string
  -> ?on_change_query:(string -> unit Effect.t)
  -> ?on_focus:(unit -> unit Effect.t)
  -> ?on_blur:(unit -> unit Effect.t)
  -> value:item list Bonsai.t
  -> on_change:(item list -> change -> unit Effect.t) Bonsai.t
  -> source:source
  -> Bonsai.graph
  -> Vdom.Node.t Bonsai.t
(** [view ~label ~value ~on_change ~source graph].

    [value] is the selected set and [on_change] reports every change to it: the new list,
    and a [change] saying what happened and to which item. Both are {!Bonsai.t}s, so the
    common call site is a state setter and nothing else — the same reason
    {!TextInput} takes its [value] and [on_change] as {!Bonsai.t}s.

    [source] is where the menu's rows come from: [search] answers a query and [bootstrap]
    is what the field offers before anything is typed, which is what
    [has_entries_on_focus] shows on focus.

    The rest of the arguments are upstream's props under the house's names. [id] is the
    input's id; the description ([id ^ "-desc"]) and the status message
    ([id ^ "-status"]) hang off it, exactly as upstream derives them from [useId].

    [placeholder] is shown only while no item is selected, as upstream's is.
    [max_entries] bounds the set; the input stays mounted at the limit but is zero-width
    and transparent. [has_clear] puts a clear-all button in the end lane, [has_create]
    offers a "Create ..." row for text that matches nothing, and [has_entries_on_focus]
    shows the bootstrap results as soon as the field is focused.
    [min_query_length] is the shortest query worth searching; below it no search runs, and
    the "Create ..." row is still offered, being derived from the typed text rather than
    fetched for it. [max_menu_items] bounds the results (upstream's default is 10, and the
    "Create ..." row is offered on top of them). [menu_width] fixes the menu's width.
    [empty_search_text] is what the menu says when a search matched nothing.
    [token_overflow_behavior] is the overflow rule, and [html_name] is the form name: one
    hidden input per selected item id is rendered under it.

    [is_disabled] disables the input and the chips. With [disabled_message] the input stays
    focusable and blocked, and the message is shown on hover and on focus — upstream's
    alternative to wrapping a disabled control in a tooltip, which cannot work because a
    disabled control swallows the hover events. *)
