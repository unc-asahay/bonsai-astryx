# Stack

**Category:** Layout  |  **Group:** Layout  |  **Port status:** not started

Stack arranges items in a row or column with consistent spacing. Use the gap
prop to control the space between items.

## When to reach for it / when not to

- **Do:** Use the gap prop for spacing between items; don't add margins manually.
- **Do:** Use StackItem with size="fill" to make one item stretch and fill the
  leftover space.
- **Don't:** Nest stacks inside stacks; try wrap="wrap" first to let items flow to
  the next line.

## Props

| prop | type | required | default | meaning |
| --- | --- | --- | --- | --- |
| `direction` | `StackDirection` | no | `'vertical' /` | Direction of the stack layout. - `horizontal`: Items flow left-to-right (like HStack) - `vertical`: Items flow top-to-bottom (like VStack) |
| `hAlign` | `StackAlignment` | no | `` | Horizontal alignment of items. - When `direction='horizontal'`: controls main-axis (justify-content). Accepts: `'start' \| 'center' \| 'end' \| 'between' \| 'around' \| 'evenly'` - When `direction='vertical'`: controls cross-axis (align-items). Accepts: `'start' \| 'center' \| 'end' \| 'stretch'` / |
| `vAlign` | `StackAlignment` | no | `` | Vertical alignment of items. - When `direction='horizontal'`: controls cross-axis (align-items). Accepts: `'start' \| 'center' \| 'end' \| 'stretch'` - When `direction='vertical'`: controls main-axis (justify-content). Accepts: `'start' \| 'center' \| 'end' \| 'between' \| 'around' \| 'evenly'` / |
| `justify` | `StackMainAlignment` | no | `` | Main-axis alignment alias. Resolves based on `direction`: - `horizontal` → `hAlign` (justify-content) - `vertical` → `vAlign` (justify-content) Mirrors CSS `justify-content` / Tailwind `justify-*`. / |
| `align` | `StackCrossAlignment` | no | `` | Cross-axis alignment alias. Resolves based on `direction`: - `horizontal` → `vAlign` (align-items) - `vertical` → `hAlign` (align-items) Mirrors CSS `align-items` / Tailwind `items-*`. / |
| `width` | `SizeValue` | no | `` | Width of the stack container. Numbers are treated as pixels, strings are used as-is (e.g., '100%'). / |
| `height` | `SizeValue` | no | `` | Height of the stack container. Numbers are treated as pixels, strings are used as-is (e.g., '100%'). / |
| `maxWidth` | `SizeValue` | no | `` | Maximum width of the stack container. Numbers are treated as pixels, strings are used as-is (e.g., '100%'). / |
| `minHeight` | `SizeValue` | no | `` | Minimum height of the stack container. Numbers are treated as pixels, strings are used as-is (e.g., '100%'). / |
| `gap` | `SpacingStep` | no | `` | Spacing between items. Accepts numeric spacing steps: 0, 0.5, 1, 1.5, 2, 3, 4, 5, 6, 8, 10. / |
| `padding` | `SpacingStep` | no | `` | Inner padding on all sides, using the spacing scale. Accepts numeric spacing steps: 0, 0.5, 1, 1.5, 2, 3, 4, 5, 6, 8, 10. Matches the `padding` prop on `Card`, `LayoutContent`, and `LayoutPanel`. / |
| `paddingInline` | `SpacingStep` | no | `` | Inline (horizontal) padding, using the spacing scale. Overrides `padding` on the inline axis when both are set. / |
| `paddingInlineStart` | `SpacingStep` | no | `` | Inline-start padding, using the spacing scale. Logical: the left edge in LTR, the right edge in RTL. Overrides `paddingInline` and `padding` on that edge only. / |
| `paddingInlineEnd` | `SpacingStep` | no | `` | Inline-end padding, using the spacing scale. Logical: the right edge in LTR, the left edge in RTL. Overrides `paddingInline` and `padding` on that edge only. / |
| `paddingBlock` | `SpacingStep` | no | `` | Block (vertical) padding, using the spacing scale. Overrides `padding` on the block axis when both are set. / |
| `paddingBlockStart` | `SpacingStep` | no | `` | Block-start (top) padding, using the spacing scale. Overrides `paddingBlock` and `padding` on that edge only. / |
| `paddingBlockEnd` | `SpacingStep` | no | `` | Block-end (bottom) padding, using the spacing scale. Overrides `paddingBlock` and `padding` on that edge only. / |
| `isScrollable` | `boolean` | no | `false /` | Enables scrollable overflow (`overflow: auto`) for the stack. Matches the `isScrollable` prop on `LayoutContent` and `LayoutPanel`. When the stack is itself a flex child that should scroll, pair it with a parent `StackItem size="fill" isScrollable` (StackItem applies the `min-height: 0` reset that flex scroll regions require). |
| `wrap` | `StackWrap` | no | `'nowrap' /` | Whether items should wrap. - `nowrap`: Items stay on one line (default) - `wrap`: Items wrap to next line - `wrap-reverse`: Items wrap to previous line |
| `as` | `ElementType` | no | `'div' /` | The element type to render. |
| `children` | `ReactNode` | no | `` | Content to render inside the stack. / |

## Anatomy

- `Stack container` (required) — Layout container that arranges content along one flex axis.
- `Item` (optional) — Optional StackItem wrapper that controls one item in the stack.
- `Content` (optional) — Caller-supplied content rendered by a Stack or StackItem.

## Retrieval keywords

`stack`, `hstack`, `vstack`, `flexbox`, `flex`, `spacing`, `gap`, `horizontal`, `vertical`, `row`, `column`

---

Generated from `astryx/packages/core/src/Stack/Stack.doc.mjs` (MIT, https://github.com/facebook/astryx). Spec: yes · upstream tests: no.

<!-- port-status:begin (generated by tools/gen-port-status.py) -->
## OCaml port

**Status:** ported in M1 — [`src/stack.ml`](../src/stack.ml)

**Module:** `Astryx.Stack` (open `Astryx`)

```ocaml
val view
  :  ?direction:direction
  -> ?h_align:Common.Alignment.t
  -> ?v_align:Common.Alignment.t
  -> ?justify:Common.Alignment.t
  -> ?align:Common.Alignment.t
  -> ?gap:Common.Spacing.t
  -> ?padding:Common.Spacing.t
  -> ?padding_inline:Common.Spacing.t
  -> ?padding_block:Common.Spacing.t
  -> ?width:Common.Size_value.t
  -> ?height:Common.Size_value.t
  -> ?max_width:Common.Size_value.t
  -> ?min_height:Common.Size_value.t
  -> ?is_scrollable:bool
  -> ?wrap:bool
  -> Vdom.Node.t list
  -> Vdom.Node.t
```

Call it with the same prop names and defaults the upstream contract above documents; `Divergence` comments in the source record the few places the port deliberately differs (class names, and inline styles for per-instance numeric props).

<!-- port-status:end -->
