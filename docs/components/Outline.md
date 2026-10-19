# Outline

**Category:** Navigation  |  **Group:** Outline  |  **Port status:** not started

A table-of-contents sidebar for documentation pages, help centers, wikis,
and long settings pages. Use it for navigation within a single page, not for
app routes. Features a sliding indicator track that animates to the active
heading. The list is a single tab stop: arrow keys move between headings,
Home/End jump to the ends, and Enter/Space activate.

## When to reach for it / when not to

- **Do:** Pass a flat ordered list of headings and let level control indentation.
- **Do:** Use activeId when custom scroll logic owns the active section.
- **Do:** Use density="compact" in dense sidebars where vertical space is tight.
- **Do:** Use useOutlineFromMarkdown or useOutlineFromDOM when headings are
  generated from content. For linkable Markdown headings, pass the same
  createMarkdownHeadingLinks() entry to Markdown and Outline; configure
  headingIdPrefix on that plugin for multiple roots.
- **Do:** Pass scrollContainerRef when the content scrolls in a split pane, modal,
  or panel instead of the viewport.
- **Do:** Set offset to the height of a fixed header that overlays the content, so
  headings land below it instead of underneath it.
- **Don't:** Use Outline for application navigation - use SideNav or TopNav for
  routes.
- **Don't:** Use Outline for expandable hierarchy - use TreeList when nodes need
  expand and collapse.
- **Don't:** Rely on onNavigateEnd to mean "arrived" - it also fires when the user
  interrupts the scroll.

## Props

| prop | type | required | default | meaning |
| --- | --- | --- | --- | --- |
| `items` | `OutlineItem[]` | yes | `` | Ordered list of heading items to render. */ |
| `activeId` | `string` | no | `` | ID of the currently active item. When provided, disables built-in scroll-spy. */ |
| `onActiveIdChange` | `(id: string) => void` | no | `` | Called when the active item changes from scroll-spy or click. */ |
| `label` | `string` | no | `'Table of contents' */` | Accessible label for the nav landmark. |
| `density` | `'default' \| 'compact'` | no | `'default' /` | Density variant controlling item padding. - 'default': Standard spacing (default) - 'compact': Reduced spacing for dense UIs |
| `onNavigateStart` | `(id: string) => void` | no | `` | Called when navigation to an item begins, before the scroll starts. Receives the item `id`. Pair with `onNavigateEnd` to drive an arrival effect (flash, ring, pulse) on the target heading. / |
| `onNavigateEnd` | `(id: string) => void` | no | `` | Called once when navigation to an item resolves — when the smooth scroll settles, or immediately-ish when reduced motion turns it into a jump. Fires exactly once for every `onNavigateStart`, including when the user interrupts the scroll by scrolling manually, so a "navigating" state can never leak. It does not fire if the Outline unmounts mid-scroll. / |
| `offset` | `number` | no | `0 /` | Height in px of a fixed header overlaying the top of the scroll root. Shifts both the activation line *and* the scroll landing by the same amount, so a heading activates exactly where navigating to it puts it — below the header rather than hidden underneath it. It composes with each heading's own `scroll-margin-top` (the header, then the breathing room below it) rather than replacing it. When nothing overlays the content, leave this at 0 and let `scroll-margin-top` do the work — the browser already honors it. |
| `scrollContainerRef` | `React.RefObject<HTMLElement \| null>` | no | `` | Scroll container to track, instead of auto-detecting the nearest scrollable ancestor. Use this when the content scrolls inside a split pane, modal, or dashboard panel rather than the viewport. / |
| `hasScrollOnClick` | `boolean 'data-testid'?: string` | no | `true /` | Whether activating an item smooth-scrolls to it. Set to false to own the scrolling yourself (virtualized content, a router) — the Outline still updates the active item, the hash, and the navigate callbacks, but performs no scroll and suppresses the anchor's default jump. |

## Anatomy

- `Outline` (required) — Navigation container for the same-page heading links and indicator.
- `Heading link` (required) — Anchor for one heading, indented by level and marked when active.
- `Label` (required) — Heading text displayed inside its heading link.
- `Indicator track` (required) — Painted vertical rule behind the active indicator.
- `Active indicator` (required) — Sliding bar positioned beside the currently active heading link.

## Retrieval keywords

`outline`, `table of contents`, `toc`, `heading navigation`, `scroll spy`, `documentation`, `anchors`, `sliding indicator`

---

Generated from `astryx/packages/core/src/Outline/Outline.doc.mjs` (MIT, https://github.com/facebook/astryx). Spec: yes · upstream tests: no.
