# MoreMenu

**Category:** Action  |  **Group:** -  |  **Port status:** not started

MoreMenu is a three-dot button that opens a list of actions. Use it for
secondary actions that don't need to be always visible, like in table rows,
card headers, or toolbars.

## When to reach for it / when not to

- **Do:** Use for overflow or secondary actions; keep primary actions visible
  outside the menu.
- **Do:** Use dividers or sections to group related actions when the menu has many
  items.
- **Do:** Use `presentation="adaptive"` when the visible overflow trigger should
  open a thumb-reachable BottomSheet on compact touch devices.
- **Don't:** Hide primary actions inside a MoreMenu; they should be directly visible.

## Props

| prop | type | required | default | meaning |
| --- | --- | --- | --- | --- |
| `items` | `DropdownMenuOption[]` | yes | `` | Menu items: data array of actions, dividers, and sections. Same type as DropdownMenu items prop. |
| `label` | `string` | no | `'More options'` | Accessible label for the trigger button (aria-label) and tooltip text. |
| `variant` | `ButtonVariant` | no | `'ghost'` | Visual style variant of the trigger button. |
| `size` | `ButtonSize` | no | `'md'` | Size of the trigger button. |
| `icon` | `ReactNode` | no | `` | Override the default three-dot icon. Accepts any ReactNode. |
| `isDisabled` | `boolean` | no | `false` | Whether the menu trigger is disabled. |
| `placement` | `'above' \| 'below' \| 'start' \| 'end'` | no | `'below'` | Position of the menu relative to the trigger. Logical: start/end resolve against the menu's own inherited direction (RTL mirrors). |
| `alignment` | `'start' \| 'center' \| 'end'` | no | `'start'` | Alignment along the placement axis. Use 'end' to align the menu with the trigger's trailing edge, which is usually what an overflow menu wants. |
| `presentation` | `'popover' \| 'bottom-sheet' \| 'adaptive'` | no | `'popover'` | Presentation policy forwarded to DropdownMenu. `adaptive` keeps the anchored popover on pointer-based layouts and uses a BottomSheet at 768px and below when the primary pointer is coarse. |
| `onOpenChange` | `(isOpen: boolean) => void` | no | `` | Callback fired when the menu opens or closes. |
| `xstyle` | `StyleXStyles` | no | `` | StyleX styles for layout customization (margins, positioning, sizing). Must be a stylex.create() value, not an inline style object like style={{}}. |

## Anatomy

- `Trigger button` (required) — Icon-only Button that provides the visible overflow-menu entry point.
- `Icon-resolved trigger icon` (optional) — Default semantic three-dot artwork resolved from the active Icon registry.
- `Caller-rendered trigger content` (optional) — Arbitrary React content supplied directly as the trigger icon override.
- `Menu surface` (required) — DropdownMenu panel that also carries MoreMenu’s current public target.
- `Pointer action row` (optional) — Action or nested-action trigger row rendered by DropdownMenu in the anchored presentation.
- `Touch action row` (optional) — ListItem button rendered by DropdownMenu in the BottomSheet presentation.

## Retrieval keywords

`moremenu`, `overflow`, `kebab`, `dotmenu`, `threedot`, `ellipsis`, `dropdown`, `contextmenu`, `actionmenu`

---

Generated from `astryx/packages/core/src/MoreMenu/MoreMenu.doc.mjs` (MIT, https://github.com/facebook/astryx). Spec: yes · upstream tests: no.
