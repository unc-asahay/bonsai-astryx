# IconButton

**Category:** Action  |  **Group:** Button  |  **Port status:** not started

A button that shows only an icon with no visible text. Use IconButton in
toolbars, table rows, and compact UI where space is tight and the icon is
universally understood.

## When to reach for it / when not to

- **Do:** Make the aria-label specific: a trash icon labeled "Delete conversation"
  is clearer than just "Delete" for screen readers.
- **Do:** Add a tooltip: even a gear icon can mean Settings, Preferences, or
  Configure.
- **Do:** Use ghost in toolbars and dense areas to reduce visual clutter.
- **Don't:** Use IconButton if the action isn't obvious from the icon alone; use
  Button with text.
- **Don't:** Skip the tooltip; label only reaches screen readers, sighted users need
  the hover hint.

## Props

| prop | type | required | default | meaning |
| --- | --- | --- | --- | --- |
| `label` | `string` | yes | `` | Accessible label. Used as aria-label (not rendered as visible text). |
| `icon` | `ReactNode` | yes | `` | Icon element rendered inside the button. An Astryx Icon with no explicit size defaults to sm for sm/md buttons and md for lg buttons. |
| `variant` | `'primary' \| 'secondary' \| 'ghost' \| 'destructive'` | no | `'secondary'` | Visual style variant. |
| `size` | `'sm' \| 'md' \| 'lg'` | no | `'md'` | Size variant. |
| `elevation` | `'none' \| 'low' \| 'med' \| 'high'` | no | `'none'` | Resting shadow depth. The most common FAB shape is an icon-only button, so raise it with `low`/`med`/`high` for a floating action button. `none` is the default flat button. |
| `isLoading` | `boolean` | no | `false` | Shows a loading spinner and blocks re-activation while staying focusable (aria-busy + aria-disabled, not native disabled). |
| `isDisabled` | `boolean` | no | `false` | Disables the button. |
| `tooltip` | `string` | no | `` | Tooltip text shown on hover. |
| `onClick` | `(e: MouseEvent) => void` | no | `` | Standard click handler. |
| `clickAction` | `(e: MouseEvent) => void \| Promise<void>` | no | `` | Async click handler with automatic loading state. |

## Accessibility contract

- **Essential icon or spinner arc** — 1.4.11 Non-text Contrast, needs 3:1 in Rest, Hover, Pointer down, Loading. IconButton has no visible label. Its icon must have at least 3:1 contrast with the button background in Rest, Hover, and Pointer down. The moving spinner arc must also meet 3:1 while loading.
- **Visible control boundary** — 1.4.11 Non-text Contrast, needs 3:1 if needed in Rest. The button edge needs 3:1 contrast only when users need it to see the control.
- **Keyboard focus indicator** — 1.4.11 Non-text Contrast, needs 3:1 in Focus visible. The focus outline must have at least 3:1 contrast with the area around the button. Check the red outline on destructive buttons too.
- **Disabled appearance** — 1.4.3 and 1.4.11 exceptions, needs Not required in Disabled. Disabled controls do not need to meet these contrast ratios.

## Retrieval keywords

`icon-button`, `icon`, `button`, `toolbar`, `action`, `compact`

---

Generated from `astryx/packages/core/src/IconButton/IconButton.doc.mjs` (MIT, https://github.com/facebook/astryx). Spec: no · upstream tests: no.
