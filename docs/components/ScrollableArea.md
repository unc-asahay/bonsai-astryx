# ScrollableArea

**Category:** Layout  |  **Group:** -  |  **Port status:** not started

Provides a native scroll viewport and a real observed content box. The
viewport enters the tab order only while a requested logical axis is
effectively scrollable, and containment applies only to effective axes.

## When to reach for it / when not to

- **Do:** Give every area a concise label that identifies the content keyboard
  users will scroll.
- **Do:** Choose `inline`, `block`, or `both` from content intent; the component
  maps the logical axes through writing mode and direction.
- **Do:** Keep the default `overscroll="allow"` for nested areas unless the
  interaction deliberately needs containment.
- **Do:** Use `useScrollableArea` instead when a component already owns both a
  viewport and a suitable content box, or when children must remain direct
  flex/grid items or retain a definite percentage block-size basis.
- **Do:** ScrollableArea owns one normal block content box with a 100% minimum
  size. Inline and both-axis modes use max-content inline sizing, so
  intrinsic inline layout is intentionally wider than the viewport.
- **Do:** Use logical padding props on the content box so nested full-bleed
  components receive the same inset geometry.
- **Do:** Set `isFullBleed` only when the viewport itself should reach an ancestor
  container edge; it is off by default.
- **Do:** Set `stickyContainment="always"` only when a fitting viewport should
  intentionally remain a Sticky boundary.
- **Don't:** Hide the native scrollbar without another visible and operable overflow
  affordance.
- **Don't:** Add another overflow wrapper around ScrollableArea; one native viewport
  should own scrolling.

## Props

| prop | type | required | default | meaning |
| --- | --- | --- | --- | --- |
| `axis` | `'inline' \| 'block' \| 'both'` | no | `'block'` | Logical axis or axes where native scrolling is allowed. |
| `label` | `string` | yes | `` | Accessible name for the viewport when it becomes keyboard scrollable. |
| `role` | `'group' \| 'region'` | no | `'group'` | Semantics for the named viewport. |
| `overscroll` | `'allow' \| 'contain'` | no | `'allow'` | Whether effective axes continue scrolling an ancestor at their edge. |
| `width` | `SizeValue` | no | `` | Width of the viewport; a number is interpreted as pixels, a string is used as-is. |
| `height` | `SizeValue` | no | `` | Height of the viewport; a number is interpreted as pixels, a string is used as-is. |
| `maxWidth` | `SizeValue` | no | `` | Maximum width of the viewport. |
| `minHeight` | `SizeValue` | no | `` | Minimum height of the viewport. |
| `stickyContainment` | `'whenScrollable' \| 'always'` | no | `'whenScrollable'` | Whether fitting content passes Sticky ownership to an outer container or deliberately keeps this viewport as the CSS Sticky boundary. |
| `padding` | `0 \| 0.5 \| 1 \| 1.5 \| 2 \| 3 \| 4 \| 5 \| 6 \| 8 \| 10` | no | `0` | Content padding on every logical edge; publishes matching inset geometry. |
| `paddingInline` | `0 \| 0.5 \| 1 \| 1.5 \| 2 \| 3 \| 4 \| 5 \| 6 \| 8 \| 10` | no | `` | Logical inline-axis content padding; overrides `padding` on that axis. |
| `paddingInlineStart` | `0 \| 0.5 \| 1 \| 1.5 \| 2 \| 3 \| 4 \| 5 \| 6 \| 8 \| 10` | no | `` | Logical inline-start content padding; overrides broader padding values. |
| `paddingInlineEnd` | `0 \| 0.5 \| 1 \| 1.5 \| 2 \| 3 \| 4 \| 5 \| 6 \| 8 \| 10` | no | `` | Logical inline-end content padding; overrides broader padding values. |
| `paddingBlock` | `0 \| 0.5 \| 1 \| 1.5 \| 2 \| 3 \| 4 \| 5 \| 6 \| 8 \| 10` | no | `` | Logical block-axis content padding; overrides `padding` on that axis. |
| `paddingBlockStart` | `0 \| 0.5 \| 1 \| 1.5 \| 2 \| 3 \| 4 \| 5 \| 6 \| 8 \| 10` | no | `` | Logical block-start content padding; overrides broader padding values. |
| `paddingBlockEnd` | `0 \| 0.5 \| 1 \| 1.5 \| 2 \| 3 \| 4 \| 5 \| 6 \| 8 \| 10` | no | `` | Logical block-end content padding; overrides broader padding values. |
| `isFullBleed` | `boolean` | no | `false` | Lets the viewport escape inherited container padding without changing content padding. |
| `children` | `ReactNode` | no | `` | Content rendered inside the observed content box. |
| `xstyle` | `StyleXStyles` | no | `` | StyleX sizing and native scrollbar presentation overrides for the viewport. |

## Anatomy

- `Viewport` (required) — The root native scroll container, accessible name owner, focus target while effective, and `astryx-scrollable-area` theme target.
- `Content box` (required) — A real inner layout box observed together with the viewport. For inline scrolling it uses max-content inline sizing with a 100% minimum.

## Retrieval keywords

`scroll`, `overflow`, `viewport`, `logical axis`, `keyboard`, `overscroll`, `sticky`, `scrollbar`, `padding`, `full bleed`

---

Generated from `astryx/packages/core/src/ScrollableArea/ScrollableArea.doc.mjs` (MIT, https://github.com/facebook/astryx). Spec: yes · upstream tests: no.
