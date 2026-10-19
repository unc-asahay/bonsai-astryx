# CodeBlock

**Category:** Content  |  **Group:** -  |  **Port status:** not started

CodeBlock renders syntax-highlighted code with line numbers, a copy button,
and optional collapsible sections. Use CodeBlock for multi-line snippets
like source files, terminal commands, and configuration examples. Use Code
for inline references to function names, variables, or CLI flags within body
text.

## When to reach for it / when not to

- **Do:** Set the language prop to match the code content so syntax highlighting
  is accurate. Use "plaintext" when the language is unknown.
- **Do:** Add a title when the code represents a file. It gives readers context
  and appears in the header bar alongside the copy button.
- **Do:** Use Code for short inline references like function names or CLI flags,
  and CodeBlock for standalone multi-line snippets.
- **Don't:** Enable line numbers on short snippets (under 5 lines) where they add
  clutter without helping navigation.
- **Don't:** Nest a code block inside a scrollable container. Use the maxHeight prop
  instead, which handles overflow natively.

## Props

| prop | type | required | default | meaning |
| --- | --- | --- | --- | --- |
| `code` | `string` | yes | `` | The code string to display. |
| `language` | `string` | no | `'plaintext'` | Language for syntax highlighting. Use "plaintext" to disable. |
| `title` | `string` | no | `` | Filename or label shown in the header bar. |
| `hasLanguageLabel` | `boolean` | no | `true` | Show the language name in the header bar. Hidden when language is "plaintext". |
| `hasLineNumbers` | `boolean` | no | `false` | Show a line number gutter. |
| `highlightLines` | `number[]` | no | `` | 1-indexed line numbers to highlight. |
| `isDiff` | `boolean` | no | `false` | Render the code as a unified diff over `language`: lines starting with + are added, - removed, @@ is a hunk header (a `--- `/`+++ ` file-header pair directly before one is a header too), anything else is context. The language label reads `diff` or `<language> diff`. The glyph sits in its own column and the rest of each line keeps syntax highlighting; copy returns the exact source. Markdown ```diff and ```diff-<lang> fences set this. |
| `hasCopyButton` | `boolean` | no | `true` | Show a copy-to-clipboard button. |
| `onCopy` | `() => void` | no | `` | Callback after the code is copied. |
| `isWrapped` | `boolean` | no | `false` | Wrap long lines instead of enabling horizontal scroll. |
| `maxHeight` | `number \| string` | no | `` | Max height before the block scrolls vertically. |
| `size` | `'sm' \| 'md'` | no | `'md'` | Text size variant. |
| `width` | `string` | no | `'fit-content'` | Width of the code block. Any CSS width value. 'fit-content' (default) shrinks to longest line. '100%' fills parent width. |
| `container` | `'card' \| 'section'` | no | `'card'` | Container presentation style. 'card' (default): border and radius with the muted syntax background for a standalone card look. 'section': no border or radius and a transparent background so the block blends into the card or panel it's embedded in. |
| `tokenizer` | `(code: string, language: string) => Array<{type: string; start: number; end: number}>` | no | `` | Custom tokenizer override for unsupported languages. |
| `syntaxTheme` | `SyntaxThemeDefinition` | no | `` | Per-instance syntax theme override. Shorthand for wrapping the block in <SyntaxTheme theme={...}>. Accepts a preset from @astryxdesign/core/theme/syntax or a theme created with defineSyntaxTheme(). Defaults to the nearest SyntaxTheme ancestor or the theme-level syntax colors. |
| `highlightMode` | `'auto' \| 'ranges' \| 'spans'` | no | `'auto'` | Syntax highlighting rendering mode. |
| `isCollapsible` | `boolean` | no | `false` | Allow collapsing the code body into just the header bar. Starts expanded; a visible header becomes clickable when the code exceeds collapsibleThreshold lines. Headerless blocks never collapse, and removing the header expands a previously collapsed block. |
| `collapsibleThreshold` | `number` | no | `10` | Minimum number of lines before the collapse toggle appears. Below this threshold the code block renders normally even when isCollapsible is true. |
| `ref` | `React.Ref<HTMLPreElement>` | no | `` | Ref forwarded to the root code-block element. |
| `xstyle` | `StyleXStyles` | no | `` | StyleX styles for layout customization. Must be a stylex.create() value. |
| `className` | `string` | no | `` | CSS class name for the root element. Prefer xstyle for styling. |
| `style` | `CSSProperties` | no | `` | Inline styles. Prefer xstyle for StyleX-optimized styling. |
| `data-testid` | `string` | no | `` | Test selector for automated testing frameworks. |

## Anatomy

- `Header Bar` (optional) — Shows the title, visible language label, and copy button when a header is present. A title or visible language label creates the header; the copy button alone floats at the top-end of a headerless block.
- `Header Title` (optional) — Groups the optional title, visible language label, and collapsible chevron inside the header bar.
- `Line Numbers` (optional) — Numbered gutter along the left edge. Enable with hasLineNumbers.
- `Code Body` (required) — The syntax-highlighted code content.
- `Highlighted Lines` (optional) — Background accent on specific lines to draw attention.
- `Copy Button` (optional) — Copies the code string to the clipboard. Shown by default.

## Retrieval keywords

`code`, `syntax`, `highlight`, `snippet`, `prism`, `shiki`, `pre`, `monospace`, `codeblock`, `inline`

---

Generated from `astryx/packages/core/src/CodeBlock/CodeBlock.doc.mjs` (MIT, https://github.com/facebook/astryx). Spec: yes · upstream tests: yes.
