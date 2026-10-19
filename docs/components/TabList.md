# TabList

**Category:** Navigation  |  **Group:** Tabs  |  **Port status:** not started

TabList provides tab-style navigation for organizing content into
categorized sections. Use it to let users switch between related views
without leaving the page, with overflow items handled by a built-in "more"
menu.

## When to reach for it / when not to

- **Do:** Keep tab labels short and descriptive so users can quickly scan
  available sections.
- **Do:** Leave overflow handling on: a strip narrower than its tabs scrolls, and
  the selected tab is kept in view. Use TabMenu when you want a curated
  group of extra options rather than a scrolling strip.
- **Do:** When using hasDivider with action buttons alongside tabs, match the
  Button size to the TabList size (both md, both sm); the divided tab
  strip reserves space so tabs and same-size buttons align to a shared
  baseline above the rail.
- **Do:** Reach for role="tablist" when the strip switches panels in place, and
  give each tab a panelId pointing at the panel it opens: that link is how
  a screen reader gets from a tab to its content. Leave it off for
  navigation between views.
- **Do:** Set isFullBleed to stretch a tab bar inside a padded LayoutHeader, Card,
  or Section to the container's inline content edges, instead of reaching
  for negative-margin CSS.
- **Don't:** Use tabs for sequential steps or workflows; use a stepper or wizard
  pattern instead.
- **Don't:** Place more than 6–8 visible tabs before the overflow menu; prioritize
  the most important categories.
- **Don't:** Confuse TabList with SegmentedControl or ToggleButton. TabList is for
  navigation between views. SegmentedControl and ToggleButton are input
  controls: SegmentedControl always has exactly one selected option, while
  ToggleButton can be toggled on or off.

## Props

| prop | type | required | default | meaning |
| --- | --- | --- | --- | --- |
| `value` | `string` | yes | `` | The currently selected tab value. |
| `onChange` | `(value: string) => void` | yes | `` | Callback fired when a tab is selected. |
| `size` | `'sm' \| 'md' \| 'lg'` | no | `'md'` | Size variant applied to all child tabs. |
| `layout` | `'hug' \| 'fill'` | no | `'hug'` | Layout mode for tab sizing. 'hug': each tab hugs its content width. 'fill': tabs stretch equally to fill the container width. |
| `hasDivider` | `boolean` | no | `false` | Whether to show a bottom border divider under the tab list. |
| `isFullBleed` | `boolean` | no | `false` | Makes the tab strip escape its parent's container padding, extending to the container's content edges (cancels the nearest padded Layout container's --container-padding-* custom properties with negative margins). The inner strip pads back by the portion of the container inset that is not already supplied by the first or last tab stop, keeping edge labels aligned while a hasDivider underline spans the full content width. Matches Divider's isFullBleed: inline (start/end) edges only; block-edge docking stays with the surrounding layout. |
| `role` | `AriaRole` | no | `` | ARIA role for the strip. 'tablist' asks for the WAI-ARIA tabs pattern: role="tablist" / role="tab" and aria-selected, with each tab pointing at the panel it controls via its panelId; only tabs may live in a tablist strip, and an href on a tab is ignored there. Left unset, the strip is a nav landmark marking the current tab with aria-current. Any other value is passed through to the element unchanged. |
| `overflow` | `'auto' \| 'scroll' \| 'visible'` | no | `'auto'` | What happens when the tabs are wider than the strip. 'auto' lets the component choose, which today always scrolls. 'scroll' scrolls the tabs horizontally, with edge fades and arrow affordances for pointers that can hover. 'visible' turns overflow handling off and lets the tabs spill out of the strip. The selected tab is always scrolled back into view. |
| `children` | `ReactNode` | yes | `` | Tab and TabMenu items to render inside the strip. |
| `xstyle` | `StyleXStyles` | no | `` | StyleX styles for layout customization (margins, positioning, sizing). Must be a stylex.create() value: not an inline style object like style={{}}. |

## Anatomy

- `Left Content` (optional) — Most important area; hugs content width.
- `Center-Fill Content` (optional) — Stretches to fill available space.
- `Right Content` (optional) — Hugs content width.

## Accessibility contract

- **Tab label** — 1.4.3 Contrast (Minimum), needs 4.5:1 in Rest, Hover, Pointer down, Selected. Each label must have at least 4.5:1 contrast with the tab surface behind it. For Hover and Pointer down, measure the final background after the overlay layer is applied.

## Retrieval keywords

`tabs`, `tabbar`, `tabstrip`, `navigation`, `tabpanel`, `tabgroup`, `segmented`, `navtabs`, `tab`

---

Generated from `astryx/packages/core/src/TabList/TabList.doc.mjs` (MIT, https://github.com/facebook/astryx). Spec: yes · upstream tests: yes.
