# Table

**Category:** Table & List  |  **Group:** Table  |  **Port status:** not started

Table displays structured data in rows and columns with consistent
dimensionality. It supports rich cell content, sorting, selection,
pagination, and column management through a composable plugin system. Use
Table for data sets with uniform structure; for simpler or inconsistent
data, consider a list or card layout instead.

## When to reach for it / when not to

- **Do:** Use density and divider variants to match the information density and
  scanning needs of your data.
- **Do:** Compose rich cell content with Astryx components like Badge, StatusDot,
  and Avatar via renderCell.
- **Do:** In children mode, put every row inside TableHeader, TableBody, or
  TableFooter. <table> cannot contain a <tr> directly: the HTML parser
  inserts an implied <tbody> for server-rendered markup and React does not
  on the client, so unwrapped rows mismatch on hydration.
- **Do:** Omit width for equal flexible columns with a compact 60px readability
  floor. Give one column its own floor with proportional(1, {minWidth}),
  weight columns with proportional(n), and fix widths with pixel(); the
  Table scroll region activates when the combined floors no longer fit.
- **Do:** Use the data-driven API from React Server Components: proportional(),
  pixel(), and column definitions without function props are server-safe.
  Columns using renderCell (or any function prop) need the table wrapped
  in a "use client" component, since functions cannot cross the
  server-client boundary.
- **Don't:** Use a table for data without consistent columns. Use a list or card
  layout for heterogeneous content.
- **Don't:** Enable every plugin at once. Add only the features your use case
  requires to keep the interface focused.
- **Don't:** Rely on the 60px omitted-width floor when a text-heavy column needs more
  room; set proportional(1, {minWidth}) on that column instead.

## Props

| prop | type | required | default | meaning |
| --- | --- | --- | --- | --- |
| `data` | `T[]` | no | `` | Array of data items to render as rows. T must extend Record<string, unknown> (use `interface MyRow extends Record<string, unknown>` for custom types). |
| `columns` | `TableColumn<T>[]` | no | `` | Column definitions: each column has {key, header, width?, align?, renderCell?}. The `header` field sets the column heading text. If omitted, columns are auto-generated from data object keys. The `width` field is typed as `ColumnWidth` (not a number); use `proportional(n)` or `pixel(n)` helpers imported from `@astryxdesign/core/Table`. Omitting `width` keeps an equal flexible share with a compact 60px readability floor. To give one column a different floor, set `width: proportional(1, {minWidth: 80})`; its `minWidth` replaces the 60px floor for that column. Example: `width: pixel(120)` for 120px fixed, `width: proportional(1)` for a flexible column with a 120px default minimum. |
| `idKey` | `(keyof T & string) \| ((item: T) => string \| number)` | no | `` | Row key for React reconciliation. Pass a property name string or a function. Falls back to row index if omitted. |
| `density` | `'compact' \| 'balanced' \| 'spacious'` | no | `'balanced'` | Row density controlling cell padding and font size. |
| `dividers` | `'rows' \| 'columns' \| 'grid' \| 'none'` | no | `'rows'` | Divider style rendered between cells. |
| `isStriped` | `boolean` | no | `false` | Applies a background wash to even-numbered rows. |
| `hasHover` | `boolean` | no | `false` | Applies a hover highlight background to rows on pointer devices. |
| `verticalAlign` | `'middle' \| 'top' \| 'bottom'` | no | `'middle'` | Vertical alignment for body row cells. Controls `vertical-align` on the `<td>` elements. |
| `textOverflow` | `'wrap' \| 'truncate'` | no | `'wrap'` | How body cell text behaves when it exceeds the column width. 'wrap' lets text wrap and the row grow taller; 'truncate' clips with an ellipsis (default-rendered cells show a tooltip on hover when truncated). Header cells always truncate. |
| `plugins` | `Record<string, TablePlugin<T>>` | no | `` | Named plugins that extend table behavior via the transform pipeline. Converted to an ordered array internally. |
| `rowIndexStart` | `number` | no | `1` | ARIA row index (1-based) for the first rendered body row. The row ordinal is an accessibility concern independent of any visible index column, so setting this (or rowCount) makes the table emit aria-rowindex on body rows and aria-rowcount on the table. For a paginated/windowed view, pass the offset of the first visible row (e.g. (page - 1) * pageSize + 1) so aria-rowindex reflects position in the full dataset. Data-driven mode only. |
| `rowCount` | `number` | no | `` | Total number of body rows across all pages/windows, used for aria-rowcount so assistive tech can announce "row X of Y" against the full dataset. When omitted but rowIndexStart is set (windowed view with an unknown total), aria-rowcount is set to -1 per the ARIA unknown-count convention. Data-driven mode only. |
| `children` | `ReactNode` | no | `` | Children mode: compose the table yourself from TableHeader / TableBody / TableFooter, each holding TableRow and TableCell, instead of using data-driven rendering. The children are passed straight to the <table>, so the section is yours to supply. A TableRow placed directly in Table emits <table><tr>, which is invalid HTML and mismatches on hydration (the parser inserts an implied <tbody> for server-rendered markup; React does not on the client). Data-driven mode renders the sections for you. |
| `xstyle` | `StyleXStyles` | no | `` | StyleX styles for layout customization (margins, positioning, sizing). Must be a stylex.create() value: not an inline style object like style={{}}. |

## Anatomy

- `Table` (required) — Semantic table element that groups the table sections, rows, and cells.
- `Scroll region` (required) — Outer region that scrolls horizontally, enters the keyboard order, and contains overscroll only while the columns overflow.
- `Header section` (optional) — Column-heading section generated when data-driven columns are present or supplied with TableHeader in children mode.
- `Column header cell` (optional) — Cell that identifies one column and may contain sorting or bulk-selection controls.
- `Sort control` (optional) — Button that wraps a sortable column label and changes that column's sort direction.
- `Sort indicator glyph` (optional) — Directional symbol rendered by Icon inside a Sort control.
- `Sort priority` (optional) — Number shown for a sorted column when multi-column sorting is active.
- `Selection control` (optional) — CheckboxInput rendered in the header and selectable body rows by the selection plugin.
- `Body section` (required) — Section containing data rows or the current empty state; data-driven mode renders it automatically.
- `Row` (optional) — Repeated TableRow that groups cells in a standard header, body, or footer row.
- `Cell` (optional) — TableCell containing one value or caller-provided content in a standard body or footer row.
- `Default empty state` (optional) — Compact EmptyState shown for an empty data array unless it is replaced or disabled.
- `Expansion control` (optional) — Button in a leading cell that expands or collapses one expandable row.
- `Expansion glyph` (optional) — Directional symbol rendered by Icon inside an Expansion control.
- `Expanded detail panel` (optional) — Detail row and spanning cell rendered below an expanded row around caller-provided content.
- `Footer section` (optional) — Optional summary or totals section supplied with TableFooter in children mode.

## Retrieval keywords

`table`, `datatable`, `datagrid`, `spreadsheet`, `sorting`, `virtualized`, `columns`, `rows`, `selection`, `pinning`

---

Generated from `astryx/packages/core/src/Table/Table.doc.mjs` (MIT, https://github.com/facebook/astryx). Spec: yes · upstream tests: yes.
