(** CommandPalette — a modal command list: a search field, a filtered list of commands grouped by
    section, keyboard navigation, and the commands an application registers.

    Port of upstream [packages/core/src/CommandPalette/] (the root plus [CommandPaletteInput],
    [CommandPaletteList], [CommandPaletteItem], [CommandPaletteGroup], [CommandPaletteFooter] and
    [CommandPaletteEmpty]).

    {2 What it is}

    A surface the application opens, holding a text field and the results that field filters. The
    commands come from the application: upstream takes a [searchSource] — a function of the query
    that returns items — and the port takes the same shape, as a [source]. The palette owns the
    query, the highlight and the open state; the application owns the commands and, when it wants
    them, the selected value.

    {2 The surface}

    A native [popover] element, drawn in place: the house has no portal and no outlet, so a surface
    upstream draws in a portal is drawn where the component is. The platform owns the top layer, the
    outside-pointer dismissal, Escape and the CSS anchor positioning — the same mechanism
    {!Popover}, {!Complex_selector} and {!Multi_selector} stand on, not a new one. The surface is
    [role="dialog"] and [aria-modal="true"], labelled by [label].

    {2 The list}

    The results are a listbox: the container carries [role="listbox"] and a label, and every row is
    a [role="option"] with [aria-selected]. A row also carries [data-value] (the command's id) and
    [aria-disabled] when the command cannot be run.

    The listbox role is present {e only while there are selectable results}. An empty palette — the
    bootstrap state, or a query that matched nothing — shows the empty state instead, and the field
    then carries [aria-expanded="false"] with no [aria-controls] and no [aria-activedescendant]: an
    empty listbox is an interactive popup with nothing in it, which is upstream's rule and this
    port's.

    {2 The announcements}

    Upstream writes its announcements into one polite live region the application owns. The port
    has no such registry, so the palette hosts its own — the way the house's other components do —
    and it announces the result count ("2 results", "1 result"), the rendered empty text when a
    query matched nothing, and "Loading" while a search is in flight. Nothing is announced when
    the palette opens on its bootstrap list.

    {2 The field}

    The field keeps the DOM focus. The active row is named with [aria-activedescendant] on the
    field, which points at the option's id — so the keyboard model is an index over the results, not
    a moving DOM focus. The field is [role="combobox"] with [aria-autocomplete="list"], and it has a
    real accessible name ([input_label]), which is never its placeholder.

    {2 The keyboard model}

    Upstream's, on the results the palette is showing:

    - {b ArrowDown} / {b ArrowUp} move the highlight to the next / previous command that can be run;
    - {b PageUp} / {b PageDown} jump to the first / last runnable command;
    - {b Home} and {b End} are left to the field: they move the caret, as an editable combobox wants;
    - {b Enter} runs the highlighted command — and closes the palette;
    - {b Space} types;
    - {b Escape} closes the palette (the platform's own dismissal, for the modal surface; the inline
      one closes it itself);
    - {b Tab} closes the palette;
    - a key that is part of an IME composition is never read as a command.

    {2 The search model}

    A [source] is a pair of functions: [search] answers a query, [bootstrap] answers the empty one.
    {!create_static_source} builds one from a list, matching the way upstream's [createStaticSource]
    does — a case-insensitive substring of the label, or of one of the item's keywords.

    An application whose search is not synchronous owns the results itself: it passes [results] and
    [on_query_change], and the palette renders what it is given without filtering. [is_busy] then
    drives the spinner in the field.

    {2 Divergences from upstream}

    - {b There is no context.} Upstream threads a React context through the family members; the port
      passes each member the values it needs as plain arguments, so every member is usable on its
      own and the palette builds them the way upstream's [ItemRenderer] does.
    - {b The surface is a native popover, drawn in place}, not a modal [dialog] element and not a
      portal — the house has neither. [is_inline] draws it in the flow instead, which is upstream's
      documentation-preview mode.
    - {b The empty state is announced, not live.} Upstream's empty state is ordinary content and
      its text reaches the screen reader through the announcement; the port does the same, so the
      empty text is never a live region of its own.
    - {b The source is synchronous.} Upstream's source may answer with a promise; a Bonsai effect
      cannot await one, so an asynchronous source is the application's, through [results] and
      [on_query_change].
    - {b The closing of the palette keeps the selected value.} Upstream clears its internal
      selection as it closes, which discards the very selection the close was reporting; the port
      keeps it and resets only the query and the highlight.
    - {b The English strings are fixed} — the dialog label, the field's name, the placeholders, the
      empty texts and the footer's hints — and there is no i18n provider.
    - {b [renderItem] takes a plain function} ([item -> is_selected -> node]) instead of a ReactNode:
      it is called while the palette renders, so it cannot own state. Buttons and links must not be
      nested inside it, exactly as upstream says.
    - The press-feedback transform is the campaign-wide named omission: the [active] scale is
      reproduced, the data-astryx-press overlay is not.

    {2 A note on ids}

    [id] is the surface's id; the field is [id ^ "-input"], the list is [id ^ "-list"] and a row is
    [id ^ "-list-item-N"]. Pass a distinct [id] per instance on a page. *)

open! Core
open! Bonsai_web
open Js_of_ocaml

(** A command the palette can show. Upstream's [SearchableItem], narrowed to what the palette
    actually reads: the id it is selected and navigated by, the label it shows, the section it is
    grouped under, the extra terms it is searched by, and whether it can be run. *)
type item =
  { id : string
  ; label : string
  ; group : string option  (** the section heading this command belongs under; [None] puts it in the ungrouped run *)
  ; keywords : string list  (** extra terms the search matches, beside the label *)
  ; is_disabled : bool  (** listed and announced, but not runnable *)
  }

(** Where the commands come from: upstream's [SearchSource], without the promise. [search] answers a
    query, [bootstrap] answers the empty one — the set the palette shows when it opens. *)
type source =
  { search : string -> item list
  ; bootstrap : unit -> item list
  }

val create_static_source : ?keywords:(item -> string list) -> item list -> source
(** A source over a fixed list of commands, matching the way upstream's [createStaticSource] does: a
    case-insensitive substring of the label, or of one of the item's keywords. [keywords] supplies
    the extra terms for one item; without it only the label is matched. *)

module Input : sig
  val view
    :  ?attrs:Vdom.Attr.t list
    -> ?id:string
    -> ?label:string
    -> ?placeholder:string
    -> ?is_busy:bool
    -> ?has_auto_focus:bool
    -> ?list_id:string
    -> ?active_descendant_id:string
    -> ?is_expanded:bool
    -> value:string
    -> on_change:(string -> unit Effect.t)
    -> ?on_key_down:(Dom_html.keyboardEvent Js.t -> unit Effect.t)
    -> unit
    -> Vdom.Node.t
  (** The search field: a search glyph, the text field, and — while a search is in flight — the
      spinner. The field is [role="combobox"] with [aria-autocomplete="list"], named by [label]
      (never by its placeholder). It always states whether the list of results is open
      ([aria-expanded]), and it carries [aria-controls] and [aria-activedescendant] only when the
      list they name has something in it.

      [has_auto_focus] focuses the field when it mounts; the palette focuses it when it opens
      instead, and passes [false] here. *)
end

module List_box : sig
  val view
    :  ?attrs:Vdom.Attr.t list
    -> ?id:string
    -> ?label:string
    -> ?has_listbox:bool
    -> children:Vdom.Node.t list
    -> unit
    -> Vdom.Node.t
  (** The results container. It is a listbox — [role="listbox"] with a label — while it holds
      runnable results ([has_listbox = true]); with nothing in it the role is left off, so an empty
      results area is not an interactive popup. This is upstream's [CommandPaletteList]. *)
end

module Item : sig
  val view
    :  ?attrs:Vdom.Attr.t list
    -> ?id:string
    -> value:string
    -> ?is_selected:bool
    -> ?is_highlighted:bool
    -> ?is_disabled:bool
    -> ?on_select:(string -> unit Effect.t)
    -> ?on_hover:(string -> unit Effect.t)
    -> children:Vdom.Node.t list
    -> unit
    -> Vdom.Node.t
  (** One command. It is a [role="option"] with [aria-selected], [data-value] and — when it cannot
      be run — [aria-disabled]. The highlight is the palette's own: the field keeps the focus and
      names this row with [aria-activedescendant]. This is upstream's [CommandPaletteItem]. *)
end

module Group : sig
  val view
    :  ?attrs:Vdom.Attr.t list
    -> heading:string
    -> children:Vdom.Node.t list
    -> unit
    -> Vdom.Node.t
  (** A section of commands: a [role="group"] labelled by its heading. The heading itself is
      [aria-hidden] — the group already carries it. This is upstream's [CommandPaletteGroup]. *)
end

module Footer : sig
  val view
    :  ?attrs:Vdom.Attr.t list
    -> ?children:Vdom.Node.t list
    -> unit
    -> Vdom.Node.t
  (** The footer. Without children it shows the keyboard hints: the arrows to navigate, Enter to
      select, Escape to close. This is upstream's [CommandPaletteFooter]. *)
end

module Empty : sig
  val view
    :  ?attrs:Vdom.Attr.t list
    -> children:Vdom.Node.t list
    -> unit
    -> Vdom.Node.t
  (** The empty state, shown when the palette has nothing to list. It carries no listbox or option
      semantics: the empty area is ordinary content. This is upstream's [CommandPaletteEmpty]. *)
end

val view
  :  ?attrs:Vdom.Attr.t list
  -> ?id:string
  -> ?is_open:bool Bonsai.t
  -> ?on_open_change:(bool -> unit Effect.t) Bonsai.t
  -> ?label:string
  -> ?input_label:string
  -> ?placeholder:string
  -> ?empty_search_text:string
  -> ?empty_bootstrap_text:string
  -> ?is_busy:bool
  -> ?is_inline:bool
  -> ?has_auto_focus:bool
  -> ?width:Common.Size_value.t
  -> ?max_height:Common.Size_value.t
  -> ?value:string Bonsai.t
  -> ?on_value_change:(string -> unit Effect.t) Bonsai.t
  -> ?render_item:(item -> bool -> Vdom.Node.t)
  -> ?source:source
  -> ?results:item list Bonsai.t
  -> ?on_query_change:(string -> unit Effect.t) Bonsai.t
  -> Bonsai.graph
  -> Vdom.Node.t Bonsai.t
(** [view ~source () (graph)] — the palette.

    {2 Opening}

    Pass both [?is_open] and [?on_open_change] to drive the palette from the application, or
    neither to let it own its state; [?on_open_change] alone observes it. [?is_open] without
    [?on_open_change] has no setter to answer it and is refused — the same shape
    {!Complex_selector} and {!Multi_selector} use.

    {2 The commands}

    [?source] is where the commands come from. [?results] replaces it: the application owns the
    result set and is told about every query through [?on_query_change], which is the path an
    asynchronous source takes. When both are given, [results] wins.

    {2 The selection}

    [?value] is the selected command's id — the picker mode. It is the application's to hold; the
    palette reports every choice through [?on_value_change]. Without [?value] the palette holds the
    selection itself.

    {2 Defaults}

    All upstream's: the dialog label ["Command palette"], the field's name ["Search commands"], the
    placeholder ["Search…"], the empty texts ["No results"] and ["Type to search"], the width
    [640] and the maximum height [480].

    {2 A note on what is drawn}

    The surface is a native [popover] element with the platform's own dismissal; the field is
    focused when the palette opens, and Escape closes it. With [?is_inline] the surface is drawn in
    the flow instead, for a documentation preview, and Escape closes it itself. *)