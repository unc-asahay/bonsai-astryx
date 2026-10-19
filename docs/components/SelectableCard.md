# SelectableCard

**Category:** Container  |  **Group:** Card  |  **Port status:** not started

A card that toggles between selected and unselected states with an accent
border. For navigation use ClickableCard.

## When to reach for it / when not to

- **Do:** Use for plan pickers, filter chips, or option grids.
- **Do:** For single-select track one ID; for multi-select use a Set.
- **Do:** When focused, toggle selection with Space or Enter.
- **Don't:** Use for navigation; use ClickableCard for that.

## Props

| prop | type | required | default | meaning |
| --- | --- | --- | --- | --- |
| `label` | `string` | yes | `` | Accessibility label. |
| `isSelected` | `boolean` | yes | `` | Controlled selection state. |
| `onChange` | `(isSelected: boolean) => void` | yes | `` | Called when toggled. |
| `isDisabled` | `boolean` | no | `false` | Disables the card. |
| `children` | `ReactNode` | no | `` | Card content. |
| `padding` | `0 \| 0.5 \| 1 \| 1.5 \| 2 \| 3 \| 4 \| 5 \| 6 \| 8 \| 10` | no | `4` | Inner padding. |
| `variant` | `'default' \| 'transparent' \| 'muted' \| 'blue' \| 'cyan' \| 'gray' \| 'green' \| 'orange' \| 'pink' \| 'purple' \| 'red' \| 'teal' \| 'yellow'` | no | `'default'` | Background color variant. |
| `elevation` | `'none' \| 'low' \| 'med' \| 'high'` | no | `'none'` | Resting shadow depth. The selection ring composes on top, so a selected card keeps its shadow. |
| `width` | `SizeValue` | no | `` | Card width. |
| `height` | `SizeValue` | no | `` | Card height. |
| `maxWidth` | `SizeValue` | no | `` | Maximum card width. |
| `xstyle` | `StyleXStyles` | no | `` | StyleX styles for layout customization (margins, positioning, sizing). Must be a stylex.create() value, not an inline style object like style={{}}. |

## Anatomy

- `Container` (required) — Interactive div with accent border on selection.
- `Content` (required) — Children rendered inside the card.

## Retrieval keywords

`card`, `selectable`, `toggle`, `checkbox`, `radio`, `selection`

---

Generated from `astryx/packages/core/src/SelectableCard/SelectableCard.doc.mjs` (MIT, https://github.com/facebook/astryx). Spec: no · upstream tests: no.
