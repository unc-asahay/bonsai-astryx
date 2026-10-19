# ContextMenu

**Category:** Action  |  **Group:** ContextMenu  |  **Port status:** not started

A right-click context menu that appears at the cursor position. Use to
provide contextual actions for specific elements or regions without
cluttering the UI with visible buttons.

## When to reach for it / when not to

- **Do:** Keep menu items concise and action-oriented; users expect quick access
  to contextual actions.
- **Do:** Use sections and dividers to group related actions when the menu has
  many items.
- **Do:** Use `presentation="adaptive"` when right-click should remain
  cursor-positioned on desktop while long-press opens a reachable
  BottomSheet on compact touch devices.
- **Do:** Ensure all context menu actions are also accessible via other UI
  elements for keyboard-only users.
- **Do:** Keep a visible MoreMenu or equivalent trigger for important mobile
  actions; long-press must not be the only route.
- **Don't:** Use a ContextMenu as the only way to access important actions; not all
  users know to right-click.
- **Don't:** Place more than 10–12 items in a single menu without grouping them into
  sections.

## Props

| prop | type | required | default | meaning |
| --- | --- | --- | --- | --- |
| `children` | `ReactNode` | yes | `` | The trigger area: right-click on this content to open the menu. |
| `items` | `ContextMenuOption[]` | yes | `` | Array of menu entries. Each entry is one of: an action item `{label, onClick?, icon?, isDisabled?, variant?, items?}` (nested `items` open a flyout in popover presentation and drill into a new view in bottom-sheet presentation; variant `"destructive"` renders it in the error color), a divider `{type: "divider"}`, or a section `{type: "section", title?, items: [...action items]}`. |
| `menuContent` | `ReactNode` | no | `` | Custom JSX menu content for compound mode. Use instead of items for dynamic or stateful menus. |
| `menuWidth` | `number \| string` | no | `'160px'` | Custom menu width. |
| `size` | `'sm' \| 'md' \| 'lg'` | no | `'md'` | Size of menu items: controls padding density. |
| `label` | `string` | no | `'Context menu'` | Accessible name for the menu surface, announced when it opens. |
| `onOpenChange` | `(isOpen: boolean) => void` | no | `` | Callback fired when the menu opens or closes. |
| `presentation` | `'popover' \| 'bottom-sheet' \| 'adaptive'` | no | `'popover'` | Presentation policy. `popover` opens at the pointer position, `bottom-sheet` always uses an action sheet, and `adaptive` uses the BottomSheet at 768px and below when the primary pointer is coarse. |
| `isDisabled` | `boolean` | no | `false` | When true, right-click shows the native browser context menu instead. |
| `triggerXstyle` | `StyleXStyles \| StyleXStyles[]` | no | `` | Styles applied to the trigger wrapper. Accepts `stylex.create()` values, not inline style objects. |
| `triggerAs` | `'div' \| 'span'` | no | `'div'` | The element the trigger wrapper renders as. 'div' is a block; 'span' an inline wrapper, so a reference inside prose can own a context menu without breaking the text flow. |

## Anatomy

- `Trigger area` (required) — Caller-provided region that accepts right-click, keyboard context-menu, and long-press input.
- `Pointer menu surface` (optional) — Cursor-positioned menu panel used by the pointer presentation.
- `Pointer action row` (optional) — DropdownMenu-owned action, selectable option, or submenu row in the pointer presentation.
- `Touch sheet frame` (optional) — BottomSheet panel, content area, handle, and optional scrim that host touch actions.
- `Touch menu surface` (optional) — ContextMenu-owned content panel rendered inside the touch sheet frame.
- `Touch action list` (optional) — Spacious List that groups data-driven touch actions.
- `Touch action row` (optional) — ListItem button used for a data-driven action or drill-in entry in the touch presentation.

## Retrieval keywords

`contextmenu`, `right-click`, `menu`, `popover`, `actions`, `context`

---

Generated from `astryx/packages/core/src/ContextMenu/ContextMenu.doc.mjs` (MIT, https://github.com/facebook/astryx). Spec: yes · upstream tests: yes.
