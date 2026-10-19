# OverflowList

**Category:** Table & List  |  **Group:** -  |  **Port status:** not started

A horizontal list that automatically hides items when they exceed the
available width. Use OverflowList for breadcrumbs, toolbars, tag lists, or
any row that needs to collapse gracefully at smaller sizes.

## When to reach for it / when not to

- **Do:** Provide a meaningful overflowRenderer: a "+N more" badge, a dropdown, or
  a count indicator.
- **Do:** When the row already has its own menu, use onOverflowChange to feed the
  collapsed items into it instead of adding a second anchor with
  overflowRenderer.
- **Do:** Set minVisibleItems to keep key items visible, and maxVisibleItems to
  cap the row at a fixed count regardless of available width.
- **Do:** Use maxRows to let items wrap onto a bounded number of rows (e.g. a
  two-row tag cloud) before collapsing the rest into the indicator.
- **Don't:** Use OverflowList for a vertical stack; horizontal multi-row wrap is
  supported via maxRows, but items still flow left-to-right, not
  top-to-bottom.

## Props

| prop | type | required | default | meaning |
| --- | --- | --- | --- | --- |
| `children` | `ReactNode` | yes | `` | Items to render. Each child should be a single element. |
| `overflowRenderer` | `(overflowItems: OverflowItem[]) => ReactNode` | no | `` | Render function for the overflow indicator. Receives the list of hidden items (each with child and index). Only called when items are overflowing. |
| `onOverflowChange` | `(overflowItems: OverflowItem[]) => void` | no | `` | Called whenever the collapsed set changes: with the collapsed items once something collapses, and with an empty array once the row widens back out. Membership and order changes report even when the count stays the same; unrelated re-renders and callback identity changes do not. Silent while nothing overflows, including on mount. Use stable React keys for dynamic items. |
| `gap` | `0 \| 0.5 \| 1 \| 1.5 \| 2 \| 3 \| 4 \| 5 \| 6 \| 8 \| 10` | no | `2` | Gap between items as a spacing token step (0, 0.5, 1, 1.5, 2, 3, 4, 5, 6, 8, 10). |
| `minVisibleItems` | `number` | no | `0` | Minimum number of items to always show, even when overflowing. |
| `maxVisibleItems` | `number` | no | `undefined (no cap)` | Maximum number of items to ever show, even when they all fit. The ceiling partner to minVisibleItems; extra items collapse into the overflow indicator. If less than minVisibleItems, the floor wins. |
| `maxRows` | `number` | no | `undefined (single line)` | Wrap items across up to this many rows before collapsing the rest into the overflow indicator. A number, not a boolean. Leave undefined (or set 1) for single-line behavior. Assumes uniform row height. |
| `collapseFrom` | `'start' \| 'end'` | no | `'end'` | Which end to collapse items from when overflow occurs. |
| `behavior` | `'observeSelf' \| 'observeParent'` | no | `'observeSelf'` | Controls which element is measured for available width. 'observeSelf' uses the container's own width. 'observeParent' observes the parent element, useful when the list should stay content-sized while still detecting available space. |
| `xstyle` | `StyleXStyles` | no | `` | StyleX styles for layout customization (margins, positioning, sizing). Must be a stylex.create() value, not an inline style object. |

## Anatomy

- `List` (required) — Visible horizontal list container for the currently shown content.
- `Items` (required) — Caller-supplied items selected for visible display by the current width and count limits.
- `Overflow indicator` (optional) — Optional caller-rendered indicator for items collapsed by width or count limits.

## Retrieval keywords

`overflow`, `truncate`, `collapse`, `breadcrumb`, `toolbar`, `tag-list`, `pill-list`, `more`, `clamp`, `responsive`

---

Generated from `astryx/packages/core/src/OverflowList/OverflowList.doc.mjs` (MIT, https://github.com/facebook/astryx). Spec: yes · upstream tests: no.
