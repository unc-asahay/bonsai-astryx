# VStack

**Category:** -  |  **Group:** -  |  **Port status:** not started

## When to reach for it / when not to


## Props

| prop | type | required | default | meaning |
| --- | --- | --- | --- | --- |
| `ref` | `React.Ref<HTMLElement> /** * Horizontal alignment of items (cross-axis for vertical stack). * @default 'stretch' */` | no | `` | Ref forwarded to the root element */ |
| `hAlign` | `StackCrossAlignment /** * Vertical alignment of items (main-axis for vertical stack). * - `start`: Align to top * - `center`: Center items * - `end`: Align to bottom * - `between`: Space between items * - `around`: Space around items * - `evenly`: Even space distribution */` | no | `'stretch'` | Horizontal alignment of items (cross-axis for vertical stack). / |
| `vAlign` | `StackMainAlignment /** * Main-axis alignment alias. Maps to `vAlign` on VStack. * Mirrors CSS `justify-content` / Tailwind `justify-*`. */` | no | `` | Vertical alignment of items (main-axis for vertical stack). - `start`: Align to top - `center`: Center items - `end`: Align to bottom - `between`: Space between items - `around`: Space around items - `evenly`: Even space distribution / |
| `justify` | `StackMainAlignment /** * Cross-axis alignment alias. Maps to `hAlign` on VStack. * Mirrors CSS `align-items` / Tailwind `items-*`. */` | no | `` | Main-axis alignment alias. Maps to `vAlign` on VStack. Mirrors CSS `justify-content` / Tailwind `justify-*`. / |
| `align` | `StackCrossAlignment` | no | `` | Cross-axis alignment alias. Maps to `hAlign` on VStack. Mirrors CSS `align-items` / Tailwind `items-*`. / |

## Retrieval keywords



---

Generated from `astryx/packages/core/src/VStack/VStack.doc.mjs` (MIT, https://github.com/facebook/astryx). Spec: no · upstream tests: no.
