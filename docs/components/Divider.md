# Divider

**Category:** Layout  |  **Group:** -  |  **Port status:** not started

A visual separator that divides content into distinct sections. Use to
create clear boundaries between groups of related content, or to demarcate
interactive regions within a layout.

## When to reach for it / when not to

- **Do:** Use subtle dividers between related content sections and strong dividers
  for high-contrast boundaries.
- **Do:** Add a label to the divider when sections need a visible category
  heading.
- **Don't:** Overuse dividers; rely on spacing and layout to separate content when
  possible.

## Props

| prop | type | required | default | meaning |
| --- | --- | --- | --- | --- |
| `orientation` | `'horizontal' \| 'vertical'` | no | `'horizontal'` | Orientation of the divider. |
| `label` | `ReactNode` | no | `` | Optional label centered on the divider. Numeric zero is preserved; null, booleans, and empty strings render no label. |
| `variant` | `'subtle' \| 'strong'` | no | `'subtle'` | Visual weight of the divider line. |
| `isFullBleed` | `boolean` | no | `false` | Extend the divider to container edges with negative margins. |
| `xstyle` | `StyleXStyles` | no | `` | StyleX styles for layout customization (margins, positioning, sizing). Must be a stylex.create() value, not an inline style object like style={{}}. |

## Anatomy

- `Divider group` (required) — Separator group that arranges one or two rules around an optional label.
- `Rule` (required) — Painted line segment; a second segment renders when a label is present.
- `Label` (optional) — Optional content displayed between two rule segments.

## Retrieval keywords

`divider`, `separator`, `hr`, `rule`, `line`, `border`, `spacer`, `horizontal rule`

---

Generated from `astryx/packages/core/src/Divider/Divider.doc.mjs` (MIT, https://github.com/facebook/astryx). Spec: yes · upstream tests: no.
