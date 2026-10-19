# Carousel

**Category:** Container  |  **Group:** -  |  **Port status:** not started

Carousel scrolls a row of items horizontally when they overflow the
available width. Use it for card grids, image galleries, product lists, or
any set of items that should be browsable without taking up the full page.

## When to reach for it / when not to

- **Do:** Enable scroll-snap when each item should land precisely at the start
  edge, like a gallery or product list.
- **Do:** Reach for hasLoop on small, cyclable sets like a photo gallery, where
  wrapping past the last item back to the first feels natural.
- **Do:** Always provide an aria-label that describes what the carousel contains,
  like "Featured products" or "Team members".
- **Do:** Carousel implements the WAI-ARIA APG carousel pattern
  (https://www.w3.org/WAI/ARIA/apg/patterns/carousel/) without
  auto-rotation: the region is labelled and carries
  aria-roledescription="carousel", each item is a group named "Slide N of
  M", and the scroll container is a tab stop so keyboard users can pan it
  with the arrow keys.
- **Do:** Use a consistent gap and item width so the carousel looks intentional,
  not like content overflowing by accident.
- **Do:** Trust the built-in navigation: trackpad users can swipe horizontally,
  and mouse users can hold Shift while scrolling the wheel to move through
  items.
- **Don't:** Use a carousel for content every user must see. Not everyone scrolls
  horizontally, so put critical content above the fold.
- **Don't:** Auto-advance items. Let the user scroll at their own pace.
- **Don't:** Nest carousels. A carousel inside a carousel is confusing and breaks
  keyboard navigation.

## Props

| prop | type | required | default | meaning |
| --- | --- | --- | --- | --- |
| `children` | `ReactNode` | yes | `` | Carousel items rendered in a horizontal scroll container. |
| `gap` | `0 \| 0.5 \| 1 \| 1.5 \| 2 \| 3 \| 4` | no | `1` | Gap between items using the spacing token scale. |
| `hasButtons` | `boolean` | no | `true` | Show prev/next navigation buttons when content is scrollable. |
| `hasEdgeFade` | `boolean` | no | `true` | Show a gradient edge-fade mask when content overflows, signalling that more items exist off-screen. |
| `hasLoop` | `boolean` | no | `false` | Wrap-around scrolling: next at the end scrolls to the start, prev at the start scrolls to the end. Buttons stay visible at both edges. Only engages when content overflows. |
| `hasSnap` | `boolean` | no | `false` | Enable scroll-snap so each child snaps to the start edge. |
| `padding` | `0 \| 0.5 \| 1 \| 1.5 \| 2 \| 3 \| 4 \| 5 \| 6 \| 8 \| 10` | no | `` | Inline padding inside the scroll container, with matching scroll-padding so snap points align to the content edge. |
| `aria-label` | `string` | no | `'Carousel'` | Accessible label for the carousel region. |
| `ref` | `React.Ref<HTMLDivElement>` | no | `` | Ref forwarded to the root element. |
| `handleRef` | `React.Ref<CarouselHandle>` | no | `` | Imperative handle exposing scrollNext(), scrollPrev(), scrollTo(index), canScrollNext(), and canScrollPrev() for programmatic scroll control. |
| `xstyle` | `StyleXStyles` | no | `` | StyleX styles for layout customization (margins, positioning, sizing). Must be a stylex.create() value. |
| `className` | `string` | no | `` | CSS class name for the root element. Prefer xstyle for styling. |
| `style` | `CSSProperties` | no | `` | Inline styles for the root element. Prefer xstyle. |
| `data-testid` | `string` | no | `` | Test selector for automated testing frameworks. |

## Anatomy

- `Scroll container` (required) — The horizontal overflow area that holds all items.
- `Items` (required) — The children rendered in a row inside the scroll container. With hasSnap, each item snaps to the start edge.
- `Fade edges` (optional) — Gradient fades on the left and right edges that indicate more content is available. Enabled by default, disable with hasEdgeFade={false}.
- `Navigation buttons` (optional) — Prev/next buttons that appear when the content can scroll in that direction. Enabled by default, disable with hasButtons={false}.

## Retrieval keywords

`carousel`, `slider`, `scroll`, `gallery`, `filmstrip`, `swiper`, `horizontal`, `overflow`, `snap`

---

Generated from `astryx/packages/core/src/Carousel/Carousel.doc.mjs` (MIT, https://github.com/facebook/astryx). Spec: no · upstream tests: yes.
