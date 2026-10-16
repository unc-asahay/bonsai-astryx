# DropdownMenu

**Category:** Action  |  **Group:** DropdownMenu  |  **Port status:** not started

A dropdown menu that displays a list of actionable items in a popup
triggered by a button. Use to present action options as a next step in a
process, or to offer contextual actions without cluttering the interface.
Like the menus of macOS and iOS, the row under the pointer when it is
released is the row that acts, the highlight follows a held mouse or finger,
a mouse opens it on press and can drag straight into it, and a finger held
on the trigger opens it with the finger down.

## When to reach for it / when not to

- **Do:** Keep menu items concise and action-oriented so users can scan options
  quickly.
- **Do:** Use sections and dividers to group related actions when the menu has
  many items.
- **Do:** For a short, flat action set, use presentation="bottom-sheet" when
  product policy calls for a modal touch surface.
- **Do:** Use presentation="adaptive" when the same short action set should remain
  anchored on pointer layouts and become a BottomSheet on compact
  coarse-pointer layouts.
- **Do:** For a hierarchy that cannot fit as adjacent flyouts on a compact touch
  surface, a product may explicitly use a drill-in interaction with a Back
  action.
- **Do:** Choose presentation explicitly in product code. A compact,
  coarse-pointer, hover-free media query is one useful policy, but
  DropdownMenu does not impose a universal device breakpoint.
- **Do:** When the content is no longer a short list of immediate actions,
  reevaluate the interaction and choose a component that matches the
  actual task; content traits alone do not determine the component.
- **Don't:** Use a DropdownMenu for navigation; use a navigation component instead.
- **Don't:** Place more than 10–12 items in a single menu without grouping them into
  sections.

## Props

| prop | type | required | default | meaning |
| --- | --- | --- | --- | --- |
| `button` | `DropdownMenuButtonProps` | no | `{ label: 'Menu' }` | Props for the trigger button (Button props except onClick). Mutually exclusive with `trigger`. |
| `renderTrigger` | `(props: DropdownMenuTriggerProps) => ReactNode` | no | `` | Render the control the menu hangs off — an IconButton, a chip, an avatar, a list row — instead of the built-in Button. Spread the given props onto it: they carry the press model (a mouse opens on press-down, a held finger opens with the finger down), the keyboard opens, the toggle click, and `aria-haspopup`/`aria-expanded`/`aria-controls`/`id`; the menu is then named by that control through `aria-labelledby`. Mutually exclusive with `button`. |
| `items` | `DropdownMenuOption[]` | yes | `` | Array of menu entries. Each entry is one of: an action item `{label, onClick?, href?, target?, rel?, icon?, description?, endContent?, isDisabled?, variant?, hasCloseOnSelect?, id?}` (`href` makes the row a real link, so a modified click keeps the browser's meaning; variant `"destructive"` renders it in the error color; `endContent` holds trailing content such as a keyboard-shortcut hint; `id` is the row's stable React key, needed only when the array reorders or filters), a divider `{type: "divider"}`, or a section `{type: "section", title?, id?, items: [...action items]}`. |
| `presentation` | `'popover' \| 'bottom-sheet' \| 'adaptive'` | no | `'popover'` | Presentation surface for data-driven items. 'popover' stays anchored, 'bottom-sheet' always renders the actions in a modal BottomSheet, and 'adaptive' uses a BottomSheet on compact coarse-pointer layouts while remaining anchored elsewhere. Compound children currently support popover only. |
| `isMenuOpen` | `boolean` | no | `` | Controlled open state for the menu. Mounting with true renders the menu open without moving focus into it; focus moves to the first item only when the menu opens after mount. |
| `onOpenChange` | `(isOpen: boolean) => void` | no | `` | Callback fired when the open state changes. |
| `menuWidth` | `number \| string` | no | `` | Minimum width for the popover presentation. Length values may grow for content; intrinsic and CSS-wide keywords select the preferred inline size. Every form is capped to the available viewport space. Defaults to matching the trigger width up to that cap. |
| `menuMaxHeight` | `number` | no | `` | Maximum height in pixels for the popover presentation, for a menu that must fit its rows. Lifts the default 300px cap; the viewport still bounds it. |
| `header` | `ReactNode` | no | `` | Content above the rows and outside the menu itself — a filter field, a toggle. A menu holds only its rows, so a control that is not a row goes here or in `footer`, never among the rows. It keeps its own keys and presses. With a header or footer the popover is a modal dialog around the menu: Tab and Shift+Tab move through the header, the menu and the footer and wrap at either end, and Escape closes. The bottom sheet shows it above the actions. |
| `footer` | `ReactNode` | no | `` | Content below the rows and outside the menu itself — a "Create" button. Tab from the menu moves into it, and Tab past its last control wraps to the start of the dialog (see `header`). The bottom sheet shows it below the actions. |
| `placement` | `'above' \| 'below' \| 'start' \| 'end'` | no | `'below'` | Popover placement relative to the trigger. Ignored by the bottom-sheet presentation. Logical: start/end resolve against the menu's own inherited direction (RTL mirrors). |
| `alignment` | `'start' \| 'center' \| 'end'` | no | `'start'` | Popover alignment along the placement axis. Ignored by the bottom-sheet presentation. Logical: start/end follow the menu's own inherited direction (RTL mirrors). |
| `onClick` | `() => void` | no | `` | Callback fired for accepted trigger activation. The trailing click from the same press that light-dismissed the menu is ignored. |
| `hasChevron` | `boolean` | no | `true` | Whether to show a chevron icon on the trigger button. Set to false for icon-only triggers. |
| `children` | `ReactNode` | no | `` | Compound-mode menu content: DropdownMenuItem, DropdownMenuDivider, DropdownMenuSubMenu (a flyout on a laptop, a drilled-in view with a Back row on a phone), and the selectable items. Mutually exclusive with `items`. |

## Anatomy

- `Trigger button` (required) — Button that opens and closes the selected menu presentation.
- `Trigger indicator icon` (optional) — Optional trailing chevron shown by a labeled trigger when hasChevron is enabled.
- `Pointer menu surface` (optional) — Anchored top-level or nested menu panel used by the pointer presentation.
- `Pointer action row` (optional) — Action, selectable option, or submenu trigger row in an anchored menu.
- `Icon-rendered item icon` (optional) — Optional semantic or component icon rendered through Icon at the start of an action row.
- `Caller-rendered item start content` (optional) — Optional arbitrary React content rendered directly at the start of an action row.
- `Checkbox indicator` (optional) — Decorative shared checkbox indicator for a checkbox action row.
- `Radio indicator` (optional) — Decorative shared radio indicator with an additional menu-owned target.
- `Pointer section heading` (optional) — Heading that labels a group of rows in an anchored menu: a data-driven section or a compound DropdownMenuGroup.
- `Pointer divider` (optional) — Divider between groups in an anchored menu.
- `Pointer submenu indicator icon` (optional) — Trailing chevron that identifies an action row as a nested flyout trigger.
- `Touch sheet frame` (optional) — BottomSheet panel, content area, handle, and optional scrim that host touch actions.
- `Touch menu surface` (optional) — Menu-owned content panel rendered inside the touch sheet frame.
- `Touch heading` (optional) — Current action-sheet title, updated when a nested action view is opened.
- `Touch action list` (optional) — Spacious List that groups actions in the touch presentation.
- `Touch action row` (optional) — ListItem button used for an action or drill-in entry in the touch presentation.
- `Touch divider` (optional) — Divider between action groups in the touch presentation.

## Retrieval keywords

`dropdown`, `menu`, `popover`, `select`, `actions`, `contextmenu`, `overflow`, `kebab`, `menubutton`

---

Generated from `astryx/packages/core/src/DropdownMenu/DropdownMenu.doc.mjs` (MIT, https://github.com/facebook/astryx). Spec: yes · upstream tests: yes.

<!-- port-status:begin (generated by tools/gen-port-status.py) -->
## OCaml port

**Status:** ported in M10 — [`src/dropdown_menu.ml`](../src/dropdown_menu.ml)

**Module:** `Astryx.Dropdown_menu` (open `Astryx`)

```ocaml
val view
  :  ?attrs:Vdom.Attr.t list
  -> ?id:string
  -> ?is_disabled:bool
  -> ?menu_max_height:int
  -> trigger_label:string
  -> on_select:(item -> unit Bonsai.Effect.t) Bonsai.t
  -> entries:entry list
  -> Bonsai.graph
  -> Vdom.Node.t Bonsai.t
```

Call it with the same prop names and defaults the upstream contract above documents; `Divergence` comments in the source record the few places the port deliberately differs (class names, and inline styles for per-instance numeric props).

<!-- port-status:end -->
