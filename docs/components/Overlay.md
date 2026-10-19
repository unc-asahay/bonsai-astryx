# Overlay

**Category:** Overlay  |  **Group:** Overlay  |  **Port status:** not started

Overlay layers action or supporting content over media, cards, video, or
other bounded surfaces with an optional scrim and reveal behavior.

## When to reach for it / when not to

- **Do:** Use overlays for short, contextual actions or labels that belong
  directly to the underlying media or surface.
- **Do:** Keep overlay content compact so it remains legible over the scrim and
  does not obscure important visual information.
- **Don't:** Do not use Overlay for floating content anchored outside the surface.
  Use Popover, Tooltip, or Dialog for those patterns.

## Props

| prop | type | required | default | meaning |
| --- | --- | --- | --- | --- |
| `content` | `ReactNode` | yes | `` | Content rendered inside the overlay scrim. |
| `children` | `ReactNode` | no | `` | Base content such as an image, video, card, or media surface that the overlay sits on top of. |
| `showOn` | `'hover' \| 'always' \| 'focus' \| 'hover-or-focus'` | no | `'always'` | Visibility trigger. Hover mode also reveals on focus for keyboard accessibility; hover-or-focus is an alias for hover. |
| `isOpen` | `boolean` | no | `` | Controlled visibility override. When set, this takes precedence over showOn and touch toggle behavior. |
| `scrim` | `'dark' \| 'light' \| false` | no | `'dark'` | Scrim background mode. Set to false to render overlay content without a scrim background. |
| `position` | `'fill' \| 'bottom' \| 'top'` | no | `'fill'` | Where the scrim appears within the base surface. |
| `align` | `'start' \| 'center' \| 'end'` | no | `'end'` | Alignment of the overlay content within the scrim. |
| `xstyle` | `StyleXStyles` | no | `` | StyleX styles for layout customization (margins, positioning, sizing). Must be a stylex.create() value, not an inline style object like style={{}}. |
| `className` | `string` | no | `` | CSS class name(s) appended to the root element. Prefer xstyle for styling when possible. |
| `style` | `React.CSSProperties` | no | `` | Inline styles applied to the root element. Prefer xstyle for design-system styling. |
| `ref` | `Ref<HTMLDivElement>` | no | `` | Ref forwarded to the overlay root element. |

## Anatomy

- `Base content` (optional) — The media, card, or bounded surface that the overlay sits on top of.
- `Scrim` (optional) — Optional dark or light overlay background that improves content contrast.
- `Overlay content` (required) — Actions, labels, or supporting content rendered above the base surface.

## Retrieval keywords

`overlay`, `scrim`, `media`, `hover`, `focus`, `image`, `card`

---

Generated from `astryx/packages/core/src/Overlay/Overlay.doc.mjs` (MIT, https://github.com/facebook/astryx). Spec: no · upstream tests: no.
