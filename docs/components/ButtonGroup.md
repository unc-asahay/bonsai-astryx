# ButtonGroup

**Category:** Action  |  **Group:** Button  |  **Port status:** not started

ButtonGroup joins related actions into a single connected control. Use it
when multiple buttons represent related choices or operations that belong
together visually, like copy/cut/paste, or undo/redo.

## When to reach for it / when not to

- **Do:** Group buttons that perform related actions on the same object, like
  copy, cut, paste on selected text.
- **Do:** Use the same variant for all buttons in a group so they look like a
  single connected unit.
- **Do:** Keep groups small (2–4 buttons). For more actions, use a Toolbar or
  DropdownMenu instead.
- **Don't:** Don't mix wildly different actions. A Save button next to a Delete
  button in the same group is confusing.
- **Don't:** Don't use ButtonGroup for navigation. Use SegmentedControl or TabList
  for switching between views.
- **Don't:** Don't nest ButtonGroups. If you need multiple groups, place them side by
  side with a gap.
- **Do:** Name the group for what its buttons act on. The label is the group's
  accessible name and a screen reader reads it before each member.
- **Do:** Keep the group a single Tab stop. Arrow keys move between members along
  the orientation, Home/End jump to the ends, and disabled members are
  skipped. This is the WAI-ARIA APG roving tabindex technique:
  https://www.w3.org/WAI/ARIA/apg/practices/keyboard-interface/#kbd_roving_tabindex
- **Don't:** Don't disable the group to show that an action is in flight. A disabled
  member drops focus, so a keyboard user loses their place; leave the
  group enabled and show progress on the button that started the work.

## Props

| prop | type | required | default | meaning |
| --- | --- | --- | --- | --- |
| `children` | `ReactNode` | yes | `` | Button or IconButton children. / |
| `label` | `string` | yes | `` | Accessible label for the group (used as aria-label). / |
| `orientation` | `ButtonGroupOrientation` | no | `'horizontal' /` | Orientation of the button group. |
| `size` | `ButtonSize` | no | `'md' /` | Default size for buttons in the group. Individual buttons can override this with their own `size` prop. |
| `elevation` | `Elevation` | no | `'none' /` | Resting elevation for the group. The connected buttons share one surface, so the shadow sits on the group and lifts them together. Use for a floating group of actions above content. |
| `isDisabled` | `boolean 'data-testid'?: string` | no | `false /` | Whether all buttons in the group are disabled. |

## Anatomy

- `Button` (required) — One or more Button or IconButton children that form the connected group.
- `Divider` (optional) — A thin border between buttons, rendered automatically by the group.

## Accessibility contract

- **Text label** — 1.4.3 Contrast (Minimum), needs 4.5:1 in Rest, Hover, Pointer down. Text in each button must have at least 4.5:1 contrast with its background in every state. For Hover and Pointer down, measure the final background after the overlay is applied.
- **Essential icon or spinner arc** — 1.4.11 Non-text Contrast, needs 3:1 in Icon only, Loading. An icon used instead of text must have at least 3:1 contrast with the button background. The moving spinner arc must also meet 3:1. An icon beside a visible label does not need its own check.
- **Visible control boundary** — 1.4.11 Non-text Contrast, needs 3:1 if needed in Rest. Some groups need a divider or edge to show each button. That divider or edge must have at least 3:1 contrast.
- **Keyboard focus indicator** — 1.4.11 Non-text Contrast, needs 3:1 in Focus visible. The focus outline must have at least 3:1 contrast with the area around it.
- **Disabled appearance** — 1.4.3 and 1.4.11 exceptions, needs Not required in Disabled. Disabled controls do not need to meet these contrast ratios.

## Retrieval keywords

`button-group`, `connected`, `split`, `toolbar`, `actions`, `grouped`, `buttons`

---

Generated from `astryx/packages/core/src/ButtonGroup/ButtonGroup.doc.mjs` (MIT, https://github.com/facebook/astryx). Spec: no · upstream tests: no.
