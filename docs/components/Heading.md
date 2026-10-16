# Heading

**Category:** -  |  **Group:** -  |  **Port status:** not started

## When to reach for it / when not to


## Props

| prop | type | required | default | meaning |
| --- | --- | --- | --- | --- |
| `ref` | `React.Ref<HTMLHeadingElement> /** * Heading level (1-6). Determines the semantic HTML element (h1–h6). * Also determines visual styling unless `type` is set. */` | no | `` | Ref forwarded to the root element */ |
| `level` | `HeadingLevel /** * Display type variant. When set, overrides the visual styling from `level` * with display-scale sizing (larger, lighter weight, tighter line-height). * The `level` still determines the HTML element for accessibility. * * Use for hero banners, marketing headlines, and data callouts that need * heading semantics. * * @example * ``` * <Heading level={1} type="display-1">Hero Title</Heading> * <Heading level={2} type="display-2">$1.2M Revenue</Heading> * ``` */` | yes | `` | Heading level (1-6). Determines the semantic HTML element (h1–h6). Also determines visual styling unless `type` is set. / |
| `type` | `HeadingType /** * Explicit font-weight override. The active theme controls the numeric value * behind each name. When omitted, the selected visual type or heading level * supplies the default. */` | no | `` | Display type variant. When set, overrides the visual styling from `level` with display-scale sizing (larger, lighter weight, tighter line-height). The `level` still determines the HTML element for accessibility. Use for hero banners, marketing headlines, and data callouts that need heading semantics. @example ``` <Heading level={1} type="display-1">Hero Title</Heading> <Heading level={2} type="display-2">$1.2M Revenue</Heading> ``` / |
| `weight` | `TextWeight /** * Accessibility level override. When set, the `aria-level` will differ * from the visual `level`. Use this when the visual hierarchy doesn't * match the document outline (e.g., sidebar headings, reused components). * * @default Same as `level` * * @example * ``` * <Heading level={2} accessibilityLevel={3}>Sidebar Section</Heading> * ``` */` | no | `` | Explicit font-weight override. The active theme controls the numeric value behind each name. When omitted, the selected visual type or heading level supplies the default. / |
| `accessibilityLevel` | `HeadingLevel /** * Text color. * @default 'primary' */` | no | `Same as `level`` | Accessibility level override. When set, the `aria-level` will differ from the visual `level`. Use this when the visual hierarchy doesn't match the document outline (e.g., sidebar headings, reused components). @example ``` <Heading level={2} accessibilityLevel={3}>Sidebar Section</Heading> ``` / |
| `color` | `TextColor /** * Display type. Headings default to block. * Note: Silently overridden to 'block' when maxLines > 0 or hasCapsize is true. * @default 'block' */` | no | `'primary'` | Text color. / |
| `display` | `TextDisplay /** * Maximum lines before truncation. 0 = no truncation. * When set, shows tooltip on hover if content is truncated. * @default 0 */` | no | `'block'` | Display type. Headings default to block. Note: Silently overridden to 'block' when maxLines > 0 or hasCapsize is true. / |
| `maxLines` | `number /** * Control tooltip behavior for truncated text. * - `true` (default when maxLines > 0): show tooltip at default position * - `false`: disable tooltip * - Position value: show tooltip at specific position * @default true */` | no | `0` | Maximum lines before truncation. 0 = no truncation. When set, shows tooltip on hover if content is truncated. / |
| `hasTruncateTooltip` | `boolean \| LayerPlacement /** * Word break behavior for truncated text. * @default 'break-all' for maxLines=1, 'break-word' otherwise */` | no | `true` | Control tooltip behavior for truncated text. - `true` (default when maxLines > 0): show tooltip at default position - `false`: disable tooltip - Position value: show tooltip at specific position / |
| `wordBreak` | `WordBreak /** * Text wrapping behavior. */` | no | `'break-all' for maxLines=1, 'break-word' otherwise` | Word break behavior for truncated text. / |
| `textWrap` | `TextWrap /** * Text alignment (justification). Uses logical values (start/end) * for i18n/RTL compatibility. * @default 'start' */` | no | `` | Text wrapping behavior. / |
| `justify` | `TextJustify /** * Enable optical alignment (text-box-trim). * Forces block display. * @default false */` | no | `'start'` | Text alignment (justification). Uses logical values (start/end) for i18n/RTL compatibility. / |
| `hasCapsize` | `boolean /** * Strikethrough decoration. * @default false */` | no | `false` | Enable optical alignment (text-box-trim). Forces block display. / |
| `hasStrikethrough` | `boolean /** * Heading content */` | no | `false` | Strikethrough decoration. / |
| `children` | `ReactNode` | yes | `` | Heading content / |

## Retrieval keywords



---

Generated from `astryx/packages/core/src/Heading/Heading.doc.mjs` (MIT, https://github.com/facebook/astryx). Spec: no · upstream tests: no.

<!-- port-status:begin (generated by tools/gen-port-status.py) -->
## OCaml port

**Status:** ported in M1 — [`src/heading.ml`](../src/heading.ml)

**Module:** `Astryx.Heading` (open `Astryx`)

```ocaml
val view
  :  ?accessibility_level:level
  -> level:level
  -> ?weight:Text.weight
  -> ?color:Text.color
  -> ?display:Text.display
  -> ?max_lines:int
  -> ?justify:Common.Alignment.t
  -> ?has_strikethrough:bool
  -> Vdom.Node.t list
  -> Vdom.Node.t
```

Call it with the same prop names and defaults the upstream contract above documents; `Divergence` comments in the source record the few places the port deliberately differs (class names, and inline styles for per-instance numeric props).

<!-- port-status:end -->
