# Token

**Category:** Content  |  **Group:** -  |  **Port status:** not started

Token is a small, inline element for representing discrete pieces of
associated data, like tags, categories, or selections. Use it to label
content, show active filters, or represent removable items like selected
recipients in a compose field.

## When to reach for it / when not to

- **Do:** Use color to distinguish categories (for example, green for "Active",
  red for "Blocked", blue for "In Review") so users can scan status at a
  glance.
- **Do:** Provide an onRemove callback when tokens represent user selections that
  can be undone, like filters or multi-select values.
- **Do:** Add a leading icon when it helps identify the token type faster, like a
  person icon for user tokens or a tag icon for labels.
- **Do:** Keep labels short: one to three words. Tokens truncate with ellipsis
  when the text overflows.
- **Don't:** Don't use tokens for primary actions or navigation; use Button or Link
  instead. Tokens are for displaying metadata, not triggering workflows.
- **Don't:** Don't hide the label unless the icon alone is universally understood. A
  color dot without text is ambiguous.
- **Don't:** Don't mix too many colors in one token group. Stick to two or three
  meaningful colors so the palette stays scannable.

## Props

| prop | type | required | default | meaning |
| --- | --- | --- | --- | --- |
| `label` | `string` | yes | `` | Text label displayed inside the token. |
| `size` | `'sm' \| 'md' \| 'lg'` | no | `'md'` | The size of the token. |
| `color` | `'default' \| 'red' \| 'orange' \| 'yellow' \| 'green' \| 'teal' \| 'cyan' \| 'blue' \| 'purple' \| 'pink' \| 'gray'` | no | `'default'` | Color variant of the token. |
| `icon` | `ReactNode` | no | `` | Optional icon rendered before the label. |
| `isDisabled` | `boolean` | no | `false` | Whether the token is disabled; reduces opacity and blocks interactions. |
| `onRemove` | `(e: React.MouseEvent) => void` | no | `` | Callback fired when the remove button is clicked. When provided, an X button is rendered inside the token. |
| `onClick` | `(e: React.MouseEvent) => void` | no | `` | Click handler. When provided, the token renders as a <span> container with an invisible <button> inside for accessibility. |
| `href` | `string` | no | `` | Link URL. When provided, the token renders as an <a> element. The destination follows the shared navigation rule described on the Link `href` prop. |
| `description` | `string` | no | `` | Accessible description applied via aria-description on the root element. |
| `endContent` | `ReactNode` | no | `` | Content rendered after the label and before the remove button. |
| `isLabelHidden` | `boolean` | no | `false` | Visually hides the label using a screen-reader-only clip technique; the label remains accessible. |
| `xstyle` | `StyleXStyles` | no | `` | StyleX styles for layout customization (margins, positioning, sizing). Must be a stylex.create() value, not an inline style object like style={{}}. |

## Anatomy

- `Icon` (optional) — A leading icon that identifies the token type, like a user avatar or category symbol.
- `Label` (required) — The visible text. Also used as the accessible name when isLabelHidden is true.
- `End content` (optional) — Trailing content after the label, like a count badge or status dot.
- `Remove button` (optional) — An X button that appears when onRemove is provided, letting users dismiss the token.

## Retrieval keywords

`token`, `chip`, `tag`, `pill`, `label`, `removable`, `dismissible`, `filter chip`, `closable`

---

Generated from `astryx/packages/core/src/Token/Token.doc.mjs` (MIT, https://github.com/facebook/astryx). Spec: no · upstream tests: no.
