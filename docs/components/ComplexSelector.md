# ComplexSelector

**Category:** Form Controls  |  **Group:** Selector  |  **Port status:** not started

Use ComplexSelector when a selection needs richer custom content than a
Selector option row. It is intentionally one component: ComplexSelector owns
the field, trigger, popover, focus restore, and changeAction flow, while the
content render prop owns the selector-specific accessible structure.

## When to reach for it / when not to

- **Do:** Use variant="secondary" beside secondary buttons, or variant="ghost"
  beside ghost buttons; add a startIcon when it helps identify the
  trigger. Use alignment="end" when a wide surface should align its end
  edge to the trigger.
- **Do:** For staged editors, keep draft state in the composed content and call
  the provided onChange helper only from Apply. Cancel or dismiss without
  committing.
- **Do:** Compose the dialog content from the appropriate accessible structure for
  the job: RadioList for a simple choice, Calendar/date inputs for date
  picking, TreeList or a searchable list for hierarchy, or a custom grid
  when two-dimensional arrow navigation is useful.
- **Do:** Use the provided onChange helper from children; it already calls both
  onChange and changeAction and updates optimistic busy state.
- **Do:** Call close() from custom content when a selection should dismiss the
  popup. Keep it open for multi-step content or freeform entry flows.
- **Do:** Use Astryx focus hooks for custom content: useGridFocus for
  two-dimensional grids, useTreeFocus through TreeList for hierarchies,
  and useListFocus for custom linear collections.
- **Do:** Evaluate custom content against WCAG 2.2: keyboard operation, focus
  visible/not obscured, names and roles, labels/instructions, target size,
  and contrast/non-text contrast are especially relevant for selector
  popovers.
- **Don't:** Do not rebuild trigger ARIA, popover focus management, or changeAction
  handling in product code.
- **Don't:** Do not use ComplexSelector for a plain single-column text list; use
  Selector instead.

## Props

| prop | type | required | default | meaning |
| --- | --- | --- | --- | --- |
| `label` | `string` | yes | `` | Label text for accessibility and the field label. */ |
| `onClick` | `React.MouseEventHandler<HTMLElement>` | no | `` | Click handler on the trigger. It runs before the popup opens; call `preventDefault()` to keep the popup closed. A press elsewhere in the control box goes through the trigger, so it reaches this handler too. With `renderTrigger` it lands on the caller's control and runs after the built-in toggle, which it cannot cancel. / |
| `onKeyDown` | `React.KeyboardEventHandler<HTMLElement>` | no | `` | Key handler on the trigger. It runs after the built-in handling and receives every key, including the ArrowDown that opens the popup. With `renderTrigger` it lands on the caller's control, runs after the built-in handling, and is skipped for keys that handling cancels. / |
| `value` | `Value` | yes | `` | Current controlled value. */ |
| `onChange` | `(value: Value) => void` | no | `` | Called when custom content commits a new value. */ |
| `changeAction` | `(value: Value) => void \| Promise<void>` | no | `` | Optional async action after onChange; drives optimistic UI. */ |
| `children` | `( value: Value onChange: (value: Value) => void close: () => void state: ComplexSelectorRenderState ) => ReactNode` | yes | `` | Custom selector surface content rendered inside a dialog popover. */ |
| `triggerLabel` | `ReactNode` | no | `` | Label/content shown in the closed trigger. */ |
| `placeholder` | `ReactNode` | no | `` | Placeholder shown when triggerLabel is omitted. */ |
| `isLabelHidden` | `boolean` | no | `` | Whether to visually hide the field label. */ |
| `description` | `string` | no | `` | Helper text displayed below the label. */ |
| `isOptional` | `boolean` | no | `` | Marks the field optional. */ |
| `isRequired` | `boolean` | no | `` | Marks the field required. */ |
| `isDisabled` | `boolean` | no | `` | Disables the selector. */ |
| `isLoading` | `boolean` | no | `` | Shows loading state on the trigger. */ |
| `status` | `ComplexSelectorStatus` | no | `` | Validation status. */ |
| `statusVariant` | `FieldStatusVariant` | no | `'attached' for input selectors; 'detached' for secondary and ghost selectors /` | How the status message is placed relative to the input. - 'attached': message overlaps directly below the input (bordered treatment; detached when variant is secondary or ghost) - 'detached': message floats below as a separate element with spacing - 'tooltip': no message box; the status icon becomes a focusable info-tip button that reveals the message on hover, keyboard focus, or tap |
| `labelTooltip` | `string` | no | `` | Tooltip text displayed next to the label. */ |
| `size` | `ComplexSelectorSize` | no | `` | Trigger and field size. */ |
| `variant` | `ComplexSelectorVariant` | no | `` | Visual trigger style. Secondary matches secondary buttons; ghost matches ghost buttons. / |
| `startIcon` | `ReactNode \| IconType` | no | `` | Icon displayed at the start of the trigger. */ |
| `width` | `SizeValue` | no | `` | Width of the field. */ |
| `placement` | `LayerPlacement` | no | `` | Popup placement. */ |
| `alignment` | `LayerAlignment` | no | `` | Popup alignment along the placement axis. */ |
| `handleRef` | `React.Ref<ComplexSelectorHandle>` | no | `` | Imperative handle for programmatic open/close control. Exposes open, close, toggle, and the isOpen query. Use this instead of mirroring open state in the parent — the selector owns its visibility. / |
| `renderTrigger` | `(props: ComplexSelectorRenderTriggerProps) => ReactNode` | no | `` | Render the control the popup hangs off — a glyph in a list row, a chip, an icon button — instead of the selector's own field and button. Spread the given props onto it; the popup is then anchored to that control and still labelled by `label`. The field chrome (`Field`, status, spinner, chevron) is not rendered; the caller owns the opener. Pair with `handleRef` to open the popup from a keystroke elsewhere. Hover and pressed paint stay yours. The open state reaches your control as `aria-expanded` on the given props, so style it from the rendered attribute. A pressed look keyed to `:active` is not a substitute: `:active` does not behave the same under a coarse pointer, which is why menu rows drop coarse-pointer `:active` paint entirely. @example ``` <ComplexSelector label="Assignee" renderTrigger={props => <IconButton icon="user" label="Assign" {...props} />} /> ``` @example ``` // Styling the open state from the rendered attribute: // .my-trigger[aria-expanded='true'] { background: var(--color-overlay-pressed); } ``` / |
| `onOpenChange` | `(isOpen: boolean) => void` | no | `` | Called whenever the selector surface opens or closes, however it happened — the trigger, the keyboard, a light dismiss, Escape, content that calls `close()`, or the imperative handle. Pair it with `handleRef` to drive the surface from outside without mirroring its state. / |
| `contentXstyle` | `StyleXStyles 'data-testid'?: string` | no | `` | StyleX styles for the popup content container. */ |

## Anatomy

- `Field` (required) — Field shell that provides the label and optional supporting field content.
- `Trigger` (required) — Control that displays the current value or placeholder and opens the popup.
- `Icon-rendered start icon` (optional) — Optional leading semantic icon or icon component rendered through Icon.
- `Caller-rendered start content` (optional) — Optional arbitrary React content rendered directly at the start of the trigger.
- `Indicator icon` (required) — Trailing chevron that rotates to reflect whether the popup is open.
- `Popup` (required) — Mounted dialog surface that is painted and shown while open and hidden while closed.

## Retrieval keywords

`selector`, `picker`, `popover`, `dialog`, `custom`, `rich`, `matrix`, `grid`

---

Generated from `astryx/packages/core/src/ComplexSelector/ComplexSelector.doc.mjs` (MIT, https://github.com/facebook/astryx). Spec: yes · upstream tests: no.
