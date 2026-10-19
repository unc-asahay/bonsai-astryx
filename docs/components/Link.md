# Link

**Category:** Action  |  **Group:** -  |  **Port status:** not started

A styled anchor for inline and standalone text navigation. Supports external
links, underline variants, tooltips, and custom link components for router
integration. Use it for navigating between pages or to external URLs.

## When to reach for it / when not to

- **Do:** Write descriptive, concise link text that clearly communicates the
  destination.
- **Do:** Set `isStandalone` when the link appears outside of inline text, so it
  receives proper base font sizing.
- **Do:** Only set `label` when the link content is not descriptive text (e.g. an
  icon-only link). For text links, the visible text is already the
  accessible name; adding `label` overrides it for screen readers, which
  is harmful.
- **Don't:** Use Link for actions that do not navigate; use a Button instead.
- **Don't:** Use generic text like "click here" or "read more"; describe the
  destination.
- **Don't:** Set `label` on text links; `aria-label` prevents assistive technology
  from reading the actual link content.

## Props

| prop | type | required | default | meaning |
| --- | --- | --- | --- | --- |
| `as` | `LinkComponentType` | no | `` | Custom component to render instead of `<a>`. Overrides the provider-level default set by LinkProvider. Must accept href, className, style, and children props. Only used when href is provided. / |
| `label` | `string` | no | `` | Accessible label for the link. Used as aria-label when content is not self-descriptive (e.g. icon-only links). When children are text, this is unnecessary — the link text itself serves as the label. / |
| `href` | `string` | no | `` | Link destination URL. When undefined, renders as a `<button>` with link styling for semantic correctness and accessibility. / |
| `hasUnderline` | `boolean` | no | `false /` | Whether the link should always display an underline. When false, underline only appears on hover. |
| `isDisabled` | `boolean` | no | `false /` | Whether the link is disabled. A disabled link renders as a plain anchor without an href (and without target/rel/onClick), so it cannot be focused or activated — no navigation and no onClick, even via programmatic focus or assistive technology activation. |
| `isExternalLink` | `boolean` | no | `false /` | Whether the link opens in a new tab with an external link icon. When true, sets target="_blank" and rel="noopener noreferrer". |
| `newTabLabel` | `string` | no | `'(opens in new tab)' /` | Screen-reader text appended to an external link to announce that it opens in a new tab (the visual icon is decorative). Override for localization. |
| `target` | `string` | no | `` | Where to open the linked document. Overridden to "_blank" when isExternalLink is true. / |
| `rel` | `string` | no | `` | Link relationship (e.g. "noopener noreferrer"). Automatically includes "noopener noreferrer" when isExternalLink is true. / |
| `download` | `string \| boolean` | no | `` | Causes the browser to download the linked URL. A string value specifies the suggested filename. / |
| `referrerPolicy` | `React.HTMLAttributeReferrerPolicy` | no | `` | Referrer policy for the link. / |
| `onClick` | `React.MouseEventHandler<HTMLAnchorElement \| HTMLButtonElement>` | no | `` | Click handler. Fires before navigation (when href is set), or as the primary action (when href is undefined). / |
| `tooltip` | `string` | no | `` | Tooltip text to display on hover. / |
| `isStandalone` | `boolean` | no | `false /` | Whether the link is standalone (not inline within text). Applies base font sizing when true. |
| `type` | `TextType` | no | `'body' /` | Semantic text type for Text. Determines base typography. Use `type="inherit"` for inline links inside an existing `Text` element so the link adopts the surrounding text's size and line-height instead of imposing its own (e.g. a link within a `large` paragraph). |
| `size` | `TextSize` | no | `` | Explicit font size override. Forwarded to Text. / |
| `weight` | `TextWeight` | no | `` | Font weight override. Forwarded to Text. / |
| `color` | `TextColor` | no | `'accent' /` | Text color. Forwarded to Text. |
| `display` | `TextDisplay` | no | `'inline' /` | Display type for Text. Forwarded to Text. |
| `maxLines` | `number` | no | `0 /` | Maximum lines before truncation. Forwarded to Text. |
| `children` | `ReactNode` | yes | `` | Link content (required). / |

## Anatomy

- `Label` (required) — The visible text of the link.
- `Right icon` (optional) — Icon placed after the label to indicate an action affordance.
- `Left icon` (optional) — Icon placed before the label to represent meaning.

## Accessibility contract

- **Link text** — 1.4.3 Contrast (Minimum), needs 4.5:1 in Rest, Hover, Pointer down. Link text must have at least 4.5:1 contrast with the background behind it. For Pointer down, measure against the pressed overlay the link paints behind its text.

## Retrieval keywords

`link`, `anchor`, `href`, `hyperlink`, `navigation`, `url`, `external`, `textlink`

---

Generated from `astryx/packages/core/src/Link/Link.doc.mjs` (MIT, https://github.com/facebook/astryx). Spec: no · upstream tests: yes.

<!-- port-status:begin (generated by tools/gen-port-status.py) -->
## OCaml port

**Status:** ported in M31 — [`src/link.ml`](../src/link.ml)

**Module:** `Astryx.Link` (open `Astryx`)

```ocaml
val view
  :  ?as_:as_
  -> ?label:string
  -> ?href:string
  -> ?rel:string
  -> ?target:string
  -> ?has_underline:bool
  -> ?is_disabled:bool
  -> ?is_external_link:bool
  -> ?new_tab_label:string
  -> ?is_standalone:bool
  -> ?on_click:(Dom_html.mouseEvent Js.t -> unit Effect.t)
  -> ?type_:Text.type_
  -> ?size:Text.size
  -> ?color:Text.color
  -> ?weight:Text.weight
  -> ?display:Text.display
  -> ?max_lines:int
  -> ?attrs:Vdom.Attr.t list
  -> Vdom.Node.t list
  -> Vdom.Node.t
```

Call it with the same prop names and defaults the upstream contract above documents; `Divergence` comments in the source record the few places the port deliberately differs (class names, and inline styles for per-instance numeric props).

<!-- port-status:end -->
