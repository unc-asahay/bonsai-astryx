# HStack

**Category:** -  |  **Group:** -  |  **Port status:** not started

## When to reach for it / when not to


## Props

| prop | type | required | default | meaning |
| --- | --- | --- | --- | --- |
| `ref` | `React.Ref<HTMLElement> /** * Horizontal alignment of items (main-axis for horizontal stack). * - `start`: Align to start (left in LTR) * - `center`: Center items * - `end`: Align to end (right in LTR) * - `between`: Space between items * - `around`: Space around items * - `evenly`: Even space distribution */` | no | `` | Ref forwarded to the root element */ |
| `hAlign` | `StackMainAlignment /** * Vertical alignment of items (cross-axis for horizontal stack). * @default 'stretch' */` | no | `` | Horizontal alignment of items (main-axis for horizontal stack). - `start`: Align to start (left in LTR) - `center`: Center items - `end`: Align to end (right in LTR) - `between`: Space between items - `around`: Space around items - `evenly`: Even space distribution / |
| `vAlign` | `StackCrossAlignment /** * Main-axis alignment alias. Maps to `hAlign` on HStack. * Mirrors CSS `justify-content` / Tailwind `justify-*`. */` | no | `'stretch'` | Vertical alignment of items (cross-axis for horizontal stack). / |
| `justify` | `StackMainAlignment /** * Cross-axis alignment alias. Maps to `vAlign` on HStack. * Mirrors CSS `align-items` / Tailwind `items-*`. */` | no | `` | Main-axis alignment alias. Maps to `hAlign` on HStack. Mirrors CSS `justify-content` / Tailwind `justify-*`. / |
| `align` | `StackCrossAlignment` | no | `` | Cross-axis alignment alias. Maps to `vAlign` on HStack. Mirrors CSS `align-items` / Tailwind `items-*`. / |

## Retrieval keywords



---

Generated from `astryx/packages/core/src/HStack/HStack.doc.mjs` (MIT, https://github.com/facebook/astryx). Spec: no · upstream tests: no.
