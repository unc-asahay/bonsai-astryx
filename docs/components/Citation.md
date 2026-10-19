# Citation

**Category:** Content  |  **Group:** Citation  |  **Port status:** not started

Citations display inline references to external sources. Use them to
attribute information within AI-generated responses, articles, or anywhere
provenance and source links are needed.

## When to reach for it / when not to

- **Do:** Use the label variant when the source title adds meaningful context for
  the reader.
- **Do:** Use the number variant for compact inline references within body text,
  like footnotes.
- **Don't:** Mix label and number variants in the same paragraph. Pick one style per
  context for visual consistency.

## Props

| prop | type | required | default | meaning |
| --- | --- | --- | --- | --- |
| `source` | `CitationSource` | yes | `` | The citation source object containing title, url, an optional image src, and an optional icon node. The url follows the shared navigation rule described on the Link `href` prop; rejected destinations leave the citation visible without navigation. Image src uses separate resource handling. |
| `number` | `number` | yes | `` | The display index for this citation. |
| `variant` | `'label' \| 'number'` | no | `'label'` | Display style: a label chip showing the source title or a compact numbered badge. |

## Anatomy

- `Container` (required) — The root wrapper. Accepted source URLs render an anchor; missing or rejected URLs render an inert span.
- `Icon` (optional) — An optional source icon shown before the label text. Accepts a favicon/logo image URL (via source.src) or a React node such as an Astryx <Icon>. Only available in the label variant.
- `Label text` (optional) — The source title, truncated with ellipsis when it exceeds the max width. Shown in the label variant.
- `Number` (optional) — The citation index displayed as a superscript badge. Shown in the number variant.

## Retrieval keywords



---

Generated from `astryx/packages/core/src/Citation/Citation.doc.mjs` (MIT, https://github.com/facebook/astryx). Spec: yes · upstream tests: no.
