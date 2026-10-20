# Pagination

**Category:** Navigation  |  **Group:** -  |  **Port status:** not started

Pagination lets users step through pages of content. Place it below a table,
list, or card grid so users can move forward and backward through results.
Pick a variant to match the context: numbered pages for data tables, a count
for large lists, compact for tight spaces, or dots for carousels.

## When to reach for it / when not to

- **Do:** Place pagination below the content it controls so users see results
  before navigating.
- **Do:** Use the pages variant for data tables where users need to jump to a
  specific page.
- **Do:** Use the count variant with a page size selector when users need to
  control how many items they see at once.
- **Do:** Use the dots variant for carousels and walkthroughs where the total is
  small and position matters more than a number.
- **Do:** Pass totalItems when the total is known so users can see how much
  content remains.
- **Don't:** Show pagination when all items fit on a single page; there is nothing to
  paginate.
- **Don't:** Use the dots variant for more than about 10 pages; the dots become too
  small to be useful.
- **Don't:** Place pagination above the content; users expect it at the bottom.

## Props

| prop | type | required | default | meaning |
| --- | --- | --- | --- | --- |
| `page` | `number` | yes | `` | Current page number (1-based). Page 1 is the first page. |
| `onChange` | `(page: number) => void` | yes | `` | Called when the page changes. |
| `changeAction` | `(page: number) => void \| Promise<void>` | no | `` | Async action on page change. Fires after onChange and uses React transitions for built-in loading state. |
| `totalItems` | `number` | no | `` | Total number of items. Used to calculate page count. Takes precedence over totalPages if both provided. |
| `totalPages` | `number` | no | `` | Total number of pages. Use when you know page count but not item count. |
| `hasMore` | `boolean` | no | `` | Whether more pages exist after the current one. Use for cursor-based pagination where total is unknown. |
| `pageSize` | `number` | no | `10` | Number of items per page. Coerced to a positive integer; non-finite values fall back to the default. |
| `pageSizeOptions` | `number[]` | no | `` | Available page size options. Shows a page size selector dropdown when provided. |
| `onPageSizeChange` | `(pageSize: number) => void` | no | `` | Called when the page size changes. Automatically resets to page 1. |
| `variant` | `'pages' \| 'count' \| 'compact' \| 'dots' \| 'input' \| 'none'` | no | `'pages'` | Visual variant controlling what appears between prev/next buttons. 'pages' shows page number buttons with ellipsis, 'count' shows 'X-Y of Z' text, 'compact' shows 'Page X of Y' (add first/last buttons with hasFirstLast), 'dots' shows dot indicators, 'input' shows an editable page-number box with a leading label ('Page [ n ] / N') flanked by first/last buttons by default (the box needs a known total to clamp against, so it is disabled in cursor/hasMore mode), 'none' shows just prev/next buttons. |
| `pageLabel` | `string` | no | `` | The noun rendered before the editable box in the 'input' variant, e.g. 'Page' or 'Row'. Navigation is always page-based (via onChange); this only relabels the box. Defaults to the localized 'Page'. |
| `hasFirstLast` | `boolean` | no | `true for 'input'; false for 'compact'` | Whether to show first/last («/») double-chevron buttons flanking prev/next. Applies to the 'input' variant (shown unless false) and the 'compact' variant (shown only when true); other variants ignore it. Omitted when the page count is unknown (cursor/hasMore pagination). |
| `step` | `number` | no | `1` | Number of pages the previous/next buttons advance per click. Clamped to the valid page range, so a step that would overshoot lands on the first/last page. When greater than 1, the buttons' accessible names reflect the stride. Non-integer or values < 1 fall back to 1. |
| `siblingCount` | `number` | no | `1` | Number of page buttons to show on each side of the current page. Only applies when variant='pages'. |
| `size` | `'sm' \| 'md'` | no | `'md'` | Size of the pagination controls. |
| `isDisabled` | `boolean` | no | `false` | Whether the component is disabled. |
| `label` | `string` | no | `'Pagination'` | Accessible label for the navigation landmark. |
| `xstyle` | `StyleXStyles` | no | `` | StyleX styles for layout customization (margins, positioning, sizing). Must be a stylex.create() value, not an inline style object like style={{}}. |

## Anatomy

- `Pagination` (required) — Navigation landmark containing the current paging controls and optional page-size selector.
- `Page-size selector` (optional) — Optional Selector for choosing how many items appear per page.
- `First/last buttons` (optional) — Optional Button controls that jump to the first or last known page.
- `Previous/next buttons` (required) — Button controls that move backward or forward through the pages.
- `Page number button` (optional) — Button for one directly selectable page in the numbered presentation.
- `Ellipsis` (optional) — Visual omission marker between non-adjacent page-number buttons.
- `Count readout` (optional) — Text showing the current item range and total item count.
- `Compact readout` (optional) — Text showing the current page and total page count.
- `Dot` (optional) — Page indicator control that reflects and changes the active page.
- `Page input label` (optional) — Leading visible label for the editable page-number field.
- `Page input` (optional) — NumberInput used to enter a page directly.
- `Page input total` (optional) — Trailing text showing the known total page count.

## Retrieval keywords

`pagination`, `pager`, `paginator`, `pagenavigation`, `paging`, `paginate`, `pages`, `pagecontrol`

---

Generated from `astryx/packages/core/src/Pagination/Pagination.doc.mjs` (MIT, https://github.com/facebook/astryx). Spec: yes · upstream tests: no.

<!-- port-status:begin (generated by tools/gen-port-status.py) -->
## OCaml port

**Status:** ported in M68 — [`src/pagination.ml`](../src/pagination.ml)

**Module:** `Astryx.pagination` (open `Astryx`)

```ocaml
val view
  :  ?attrs:Vdom.Attr.t list
  -> ?id:string
  -> ?variant:variant
  -> ?size:size
  -> ?label:string
  -> ?total_items:int
  -> ?total_pages:int
  -> ?has_more:bool
  -> ?page_size:int
  -> ?page_label:string
  -> ?has_first_last:bool
  -> ?step:int
  -> ?sibling_count:int
  -> ?is_disabled:bool
  -> on_change:(int -> unit Effect.t) Bonsai.t
  -> page:int Bonsai.t
  -> Bonsai.graph
  -> Vdom.Node.t Bonsai.t
```

Call it with the same prop names and defaults the upstream contract above documents; `Divergence` comments in the source record the few places the port deliberately differs (class names, and inline styles for per-instance numeric props).

<!-- port-status:end -->
