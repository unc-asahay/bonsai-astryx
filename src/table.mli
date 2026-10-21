(** Table — structured data in rows and columns.

    Upstream's [Table] is a plugin pipeline: a data-driven core ([data] plus
    [columns]) with sorting, selection, pagination, filtering, tree data and
    sticky columns arriving as named plugins. This port is the {b core}: one
    table with a column header row, body rows, an optional row-header column,
    optional sorting, optional row selection, and the three densities. The
    plugin pipeline itself is not ported — see {2 Divergences}.

    {2 Anatomy}

    - a [<table>] root, carrying [data-astryx-component="Table"];
    - a header row in a [<thead>], one [<th scope="col">] per column;
    - body rows in a [<tbody>], one cell per column: a [<td>], or a
      [<th scope="row">] for the column marked [is_row_header];
    - a sort control in the header of a sortable column: a real [<button>]
      that cycles that column between ascending, descending and unsorted;
    - a selection column, when selection is on: a checkbox per row, and a
      select-all checkbox in the header.

    {2 The data model}

    A table is a list of [column]s and a list of [row]s. A column names
    itself with a [key] and a header label; a row names itself with a [key]
    and carries one [cell] per column, in the columns' order. A cell holds
    the nodes to render and, optionally, the string its column sorts on.

    {2 Sorting}

    The sort state is a [sort option]: the sorted column and its direction,
    or [None] when nothing is sorted. Clicking a sortable column's control
    cycles that column ascending -> descending -> unsorted, and clicking
    another column starts that column ascending — upstream's cycle, kept.

    Sorting is a presentation concern here: the table sorts the rows it is
    given, and the caller owns the {e state} of the sort, not the ordering.
    [?sort] is the controlled form (the caller owns the state; the table
    reports every change through [?on_sort_change]). Without it the table
    keeps the state internally, seeded by [?default_sort].

    {2 Selection}

    Selection is off unless [?is_selectable] is set. The selected rows are
    named by their row keys. [?selected] is the controlled form; without it
    the table keeps the selection internally, seeded by [?default_selected].
    A selected row carries [aria-selected="true"], and the header's
    select-all checkbox is indeterminate when the selection is partial.

    {2 Accessibility}

    The header cells are [<th scope="col">], and a row-header column's cells
    are [<th scope="row">], so a screen reader can say which column a cell
    belongs to and which row it heads. The sorted column's header carries
    [aria-sort]; the sort control is a real [<button>], so the keyboard
    reaches it. The selection boxes are real checkboxes with hidden labels
    that name the row they select.

    {2 Divergences (stated rather than hidden)}

    - {b No plugin pipeline} — upstream's [plugins] prop and the whole
      [TablePlugin] transform pipeline are not ported. Sorting and selection
      are the two plugin behaviours that became part of the core here.
    - {b No virtualisation} — the table renders every row it is given. A
      windowed or paginated data set must be handed over page by page, and
      upstream's [rowIndexStart]/[rowCount] props (the ARIA row ordinals
      that go with it) are not ported either.
    - {b No column resize} — upstream's column-resize plugin is not ported;
      a column's width is whatever its content and the table's own layout
      give it.
    - {b No column grouping} — upstream's grouped-rows plugin is not ported.
    - {b No sticky columns} — upstream's sticky-columns plugin is not
      ported. [?has_sticky_header] is a different thing and is this port's
      own: see below.
    - {b No column widths} — upstream's [ColumnWidth] ([proportional()],
      [pixel()]) is not ported.
    - {b No children mode} — upstream composes a table out of [TableHeader],
      [TableBody], [TableFooter], [TableRow] and [TableCell]; this port is
      data-driven only.
    - {b No scroll region} — upstream wraps the table in a horizontally
      scrolling region that takes keyboard focus; this port renders the
      table on its own.
    - {b No [dividers]/[isStriped]/[hasHover]/[verticalAlign]/[textOverflow]}
      — those upstream props are not ported, so the table always has row
      dividers and no striped or hover wash.
    - {b No empty state} — an empty data set renders an empty [<tbody>],
      not upstream's [EmptyState].
    - {b No pagination, filtering, tree data, row expansion, row status,
      column settings, context menu, or selection toolbar} — each is an
      upstream plugin or a separate upstream component, and none is ported
      here.
    - {b A header is a string} — upstream's column header is a node
      ([header?: ReactNode]); here it is a label.
    - {b Sorting compares strings} — a cell's [sort_value] is a string and
      the comparison is [String.compare]. Upstream sorts by the row value
      and leaves the comparison to the application.
    - {b [?has_sticky_header] is this port's own} — upstream's [Table] has
      no sticky-header prop (its sticky behaviour is the sticky-columns
      plugin, which is not ported); this one sticks the header row to the
      top of the nearest scrolling ancestor.
    - {b The row-header column is this port's own} — upstream exposes
      [scope] per cell; here a column carries [is_row_header] and its body
      cells are rendered as [<th scope="row">]. *)

open! Core
open! Bonsai_web

type density =
  | Compact  (** the tightest of the three: the least padding per cell *)
  | Balanced  (** the default *)
  | Spacious  (** the loosest: the most padding per cell *)

type align =
  | Start  (** the default: text starts at the inline start of the cell *)
  | Center  (** text is centred in the cell *)
  | End  (** text ends at the inline end of the cell *)

type sort_direction =
  | Ascending
  | Descending

type sort = { column_key : string; direction : sort_direction }
(** Which column is sorted, and in which direction. *)

type cell = { content : Vdom.Node.t list; sort_value : string option }
(** One body cell. [content] is what the cell shows; [sort_value] is the
    string the column sorts on when it is sorted. A cell without one sorts
    as the empty string. *)

type row = { key : string; cells : cell list }
(** One body row. [key] names the row (it is what selection names) and
    [cells] holds one cell per column, in the columns' order. *)

type column =
  { key : string
  ; header : string
  ; align : align
  ; is_row_header : bool
  (** when set, the column's body cells are [<th scope="row">] — the cells
      that head their row, rather than cells that belong to a column. *)
  ; is_sortable : bool
  (** when set, the column's header carries a sort control. *)
  }

val view
  :  ?attrs:Vdom.Attr.t list
  -> ?id:string
  -> ?density:density
  -> ?is_selectable:bool
  -> ?has_sticky_header:bool
  -> ?sort:sort option Bonsai.t
  -> ?default_sort:sort option
  -> ?on_sort_change:(sort option -> unit Effect.t) Bonsai.t
  -> ?selected:string list Bonsai.t
  -> ?default_selected:string list
  -> ?on_selection_change:(string list -> unit Effect.t) Bonsai.t
  -> columns:column list
  -> rows:row list
  -> Bonsai.graph
  -> Vdom.Node.t Bonsai.t
(** [view ~columns ~rows ()]: the table.

    [columns] are the column definitions and [rows] the body rows; every
    row carries one cell per column, in the columns' order. [density] is
    [Balanced] by default and sets the cell padding.

    [is_selectable] turns the selection column on: a checkbox per row, a
    select-all checkbox in the header, and [aria-selected] on the selected
    rows. The selection is controlled by [?selected] (a list of row keys) or
    kept internally, seeded by [?default_selected]; [?on_selection_change]
    reports every change either way.

    [?sort] (a [sort option]) controls the sort; without it the table keeps
    the sort internally, seeded by [?default_sort], and [?on_sort_change]
    reports every change. Only a column with [is_sortable] offers the
    control, but a sort may name any column.

    [?has_sticky_header] sticks the header row to the top of the nearest
    scrolling ancestor. *)
