# Item

**Category:** Table & List  |  **Group:** Item  |  **Port status:** not started

A single, flexible item primitive that unifies the "start content + label +
description + end content" pattern across Astryx. Use it wherever you need a
structured row: dropdown menus, selectors, contact lists, notifications,
file browsers, and activity feeds.

## When to reach for it / when not to

- **Do:** Use named slots (startContent, label, description, endContent) for the
  common layout. These cover the 80% case.
- **Do:** Use density="compact" for menus and dense lists, "balanced" for standard
  rows, and "spacious" for roomier layouts.
- **Do:** Set labelLines and descriptionLines to control truncation when content
  length varies.
- **Do:** Use align="start" when start or end content is taller than a single line
  of text.
- **Do:** Give a swipe action a second home in the row (a menu or a button in
  endContent): the swipe is a touch accelerator, and a verb reachable only
  by swipe is unreachable by keyboard and by mouse.
- **Don't:** Don't nest interactive elements (buttons, links) inside an interactive
  Item; it creates confusing focus and click targets.
- **Don't:** Don't use Item for navigation between views; use proper navigation
  components instead.
- **Don't:** Don't add read/unread or inbox-specific behavior directly; compose a
  thin wrapper like PreviewItem instead.

## Props

| prop | type | required | default | meaning |
| --- | --- | --- | --- | --- |
| `as` | `'div' \| 'li' \| 'span' \| React.ElementType` | no | `'div' /` | What the root renders as: an HTML element, or a component for a caller that needs the root to be something else. A menu row that navigates passes the application's link component here, so the row's root IS the anchor and a modified or middle click keeps the browser's meaning. Give a component only when the row carries a `role`, so the parent owns keyboard access and the row adds no second tab stop; and only when no interactive node sits in `startContent` or `endContent`, since a control nested inside an anchor is invalid. |
| `marker` | `ReactNode` | no | `` | Marker rendered before startContent as a direct flex child. Use for list bullets/counters that need custom baseline alignment. / |
| `startContent` | `ReactNode` | no | `` | Content rendered before the label/description area. Use for leading icons, avatars, or checkboxes. / |
| `label` | `ReactNode` | yes | `` | Primary text identifying this item. Required. Accepts string (auto-styled) or ReactNode (for rich content). / |
| `description` | `ReactNode` | no | `` | Secondary text — subtitle, description, or supporting info. / |
| `endContent` | `ReactNode` | no | `` | Content rendered after the label/description area. Use for badges, metadata, timestamps, or action buttons. / |
| `align` | `ItemAlign` | no | `'center' /` | Vertical alignment of the start/end content slots. |
| `density` | `ItemDensity` | no | `'balanced' /` | Density: "compact" (4px block padding), "balanced" (8px block padding), or "spacious" (12px block and inline padding). |
| `labelLines` | `number` | no | `` | Max lines before label truncates. When set, overflow is hidden and text-overflow: ellipsis is applied. / |
| `descriptionLines` | `number` | no | `` | Max lines before description truncates. When set, overflow is hidden and text-overflow: ellipsis is applied. / |
| `layout` | `'stacked' \| 'inline'` | no | `'stacked' /` | How the label and description sit together. `stacked` puts the description on its own line below the label; `inline` keeps both on one line, with the description ellipsizing first, so the row fits a fixed-height host. |
| `onClick` | `(event: React.MouseEvent) => void` | no | `` | Click handler. Makes the item clickable with button semantics. / |
| `interactiveRef` | `React.RefObject<HTMLElement \| null>` | no | `` | Ref to a nested control inside the item (e.g. a checkbox in `startContent`) that already provides the item's keyboard access and action. When set, the item becomes an enlarged click/tap target that delegates surface clicks to that control via the `useClickableContainer` pattern: it renders no invisible button/anchor, so the row adds no second tab stop (WCAG 4.1.2 — one focusable control per option). Clicks on the control itself, and on any other nested interactive element, are left to that element. Mutually exclusive with `onClick`/`href` — when `interactiveRef` is set those are ignored (the nested control is the sole action). / |
| `href` | `string` | no | `` | Link URL. Makes the item a link via an invisible anchor element. A row whose root is already a link component (see `as`) carries the address on that root instead, and no invisible anchor is rendered. / |
| `target` | `'_blank' \| '_self'` | no | `` | Link target (e.g., '_blank'). Only used with href. / |
| `rel` | `string` | no | `` | Link relationship. Automatically includes noopener noreferrer when target is "_blank". / |
| `isHighlighted` | `boolean` | no | `false /` | Highlighted state (hover/keyboard focus appearance). |
| `isSelected` | `boolean` | no | `false /` | Selected state. Always applies the selected visual styling. When `role` permits it (option, tab, row, gridcell, columnheader, rowheader, treeitem) the state is exposed as `aria-selected`; otherwise (e.g. a listitem or a bare div, where `aria-selected` is invalid ARIA) it falls back to `aria-current="true"` so assistive tech is still told which item is selected. A consumer-provided `aria-current` always wins. |
| `isDisabled` | `boolean` | no | `false /` | Disabled state. |
| `swipeActions` | `ItemSwipeActions` | no | `` | Swipe actions for touch: the verbs a sideways drag uncovers on each side, declared as data so the row paints the panel from them. A coarse pointer drags the row aside and uncovers the side's panel; a mouse never starts the drag, and a mostly vertical drag stays the scroller's. The gesture is a touch accelerator and never a row's only path to a verb: a verb reachable only by swipe is unreachable by keyboard and by mouse, so every entry must also be reachable through the row's own content (a menu or a button in `endContent`). Available on a row whose role permits interactive descendants — a `listitem`, a row with no role — and not served on one whose role forbids them (`option`, `menuitem*`, a row that is the enlarged target of a native radio). The element containing the rows clips in the inline axis (`overflow-inline: clip`): `List` does; any other host does it once. The gesture and its panels are loaded on demand, the first time a row has swipe actions, so a row without them ships none of it; a row with them is drawn at once and becomes swipeable as soon as that module has loaded. / |
| `swipeBehavior` | `ItemSwipeBehavior 'data-testid'?: string` | no | `'reveal' /` | What a swipe does: `reveal` rests the row open with every entry tappable and fires the outermost on a long drag; `commit` slides the row out and fires the outermost on release. `commit` fits one entry per side. |

## Anatomy

- `Marker` (optional) — Optional list bullet/counter rendered before start content.
- `Start content` (optional) — Leading visual: avatar, icon, image, or checkbox.
- `Label` (required) — Primary text identifying the item.
- `Description` (optional) — Secondary supporting text below the label.
- `End content` (optional) — End-aligned content: badges, timestamps, or action buttons.

## Retrieval keywords

`item`, `list-item`, `media-object`, `row`, `cell`, `entity`, `contact`, `notification`, `preview`

---

Generated from `astryx/packages/core/src/Item/Item.doc.mjs` (MIT, https://github.com/facebook/astryx). Spec: no · upstream tests: yes.

<!-- port-status:begin (generated by tools/gen-port-status.py) -->
## OCaml port

**Status:** not ported yet. The upstream contract above is the specification; see `docs/PORT-STATUS.md` for the milestone it is planned in.

<!-- port-status:end -->
