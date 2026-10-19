# Text

**Category:** Content  |  **Group:** -  |  **Port status:** not started

Text renders styled body text and headings from the theme. Use Text with a
semantic type for body copy, labels, and captions, and Heading for section
titles that output the correct h1–h6 element.

## When to reach for it / when not to

- **Do:** Pick a semantic type (body, label, supporting, large, code) instead of
  manually setting size and weight; the theme handles the details.
- **Do:** Set accessibilityLevel on Heading when the visual level differs from the
  document outline so screen readers announce the correct hierarchy.
- **Do:** Use maxLines with a number to truncate long content; a tooltip appears
  automatically on hover so no text is lost.
- **Do:** Enable hasTabularNumbers for columns of numeric data so digits align
  vertically across rows.
- **Don't:** Override size and weight when a semantic type already matches; extra
  overrides fight the theme and break when themes change.
- **Don't:** Skip heading levels in the document outline; go h1 then h2 then h3,
  never h1 then h3.
- **Don't:** Use raw HTML tags like <p>, <h1>–<h6>, or <span> for text; Text and
  Heading apply the correct theme tokens automatically.
- **Don't:** Pass a `variant` prop; Text does not have a `variant` prop. Use `type`
  for semantic styling (body, label, large, supporting, code) or use
  Heading for headings.
- **Don't:** Use Text for headings; use Heading with a `level` prop (1–6) for section
  titles and headings.

## Props

| prop | type | required | default | meaning |
| --- | --- | --- | --- | --- |
| `type` | `'body' \| 'large' \| 'label' \| 'supporting' \| 'code' \| 'display-1' \| 'display-2' \| 'display-3' \| 'inherit'` | no | `'body'` | Semantic text type. Determines size, weight, and line-height from the theme. 'inherit' takes all three from the surrounding text instead. Themes may add custom types. Note: this prop is called `type`, not `variant`. |
| `children` | `ReactNode` | yes | `` | Text content. |
| `size` | `'4xs' \| '3xs' \| '2xs' \| 'xsm' \| 'sm' \| 'base' \| 'lg' \| 'xl' \| '2xl' \| '3xl' \| '4xl'` | no | `` | Explicit font size override. Overrides the size from `type` but preserves other type properties. Prefer using `type` alone. |
| `color` | `'primary' \| 'secondary' \| 'disabled' \| 'placeholder' \| 'accent' \| 'inherit'` | no | `` | Text color. Defaults to 'secondary' for the 'supporting' type, 'primary' for all others. Themes may add custom colors. |
| `weight` | `'normal' \| 'medium' \| 'semibold' \| 'bold'` | no | `` | Font weight override. |
| `display` | `'inline' \| 'block'` | no | `'inline'` | Display type. Silently overridden to 'block' when maxLines > 0 or hasCapsize is true. |
| `as` | `'span' \| 'p' \| 'div' \| 'label'` | no | `'span'` | HTML element to render. |
| `maxLines` | `number` | no | `0` | Maximum lines before truncation. 0 means no truncation. When set, shows a tooltip on hover if content is truncated. |
| `hasTruncateTooltip` | `boolean \| 'above' \| 'below' \| 'start' \| 'end'` | no | `true` | Controls tooltip behavior for truncated text. true shows the tooltip at the default position, false disables it, or a placement string ('above' \| 'below' \| 'start' \| 'end') sets a specific position. |
| `wordBreak` | `'break-word' \| 'break-all'` | no | `` | Word break behavior when truncating. Defaults to 'break-all' for single-line truncation, 'break-word' otherwise. |
| `textWrap` | `'wrap' \| 'nowrap' \| 'balance' \| 'pretty'` | no | `` | Text wrapping behavior. |
| `justify` | `'start' \| 'center' \| 'end'` | no | `'start'` | Text alignment (justification). Uses logical values (start/end) for i18n/RTL compatibility. |
| `hasCapsize` | `boolean` | no | `false` | Enable optical alignment using text-box-trim. Forces block display. |
| `hasStrikethrough` | `boolean` | no | `false` | Apply strikethrough text decoration. |
| `hasTabularNumbers` | `boolean` | no | `false` | Use tabular (monospace) numbers for aligned numeric data. |
| `id` | `string` | no | `` | HTML id attribute. |
| `xstyle` | `StyleXStyles` | no | `` | StyleX styles for layout customization (margins, positioning, sizing). Must be a stylex.create() value: not an inline style object like style={{}}. |

## Anatomy

- `Text` (required) — Polymorphic text element that renders the supplied content with themed typography.
- `Heading` (optional) — Referenced Heading member that renders the supplied content as a semantic h1–h6 element.
- `Truncation tooltip` (optional) — Tooltip-owned surface available only when Text or Heading is measured as truncated and truncation tooltips are enabled.

## Retrieval keywords

`text`, `typography`, `label`, `paragraph`, `heading`, `caption`, `font`, `body`, `subtitle`

---

Generated from `astryx/packages/core/src/Text/Text.doc.mjs` (MIT, https://github.com/facebook/astryx). Spec: yes · upstream tests: no.
