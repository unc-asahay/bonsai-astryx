# MultiSelector

**Category:** Form Controls  |  **Group:** Selector  |  **Port status:** not started

A checkbox dropdown for selecting multiple values from a list. Selected
items can display as a count, labels, or badges. Use it for filtering or
when presenting a finite set of options where multiple choices are needed.

## When to reach for it / when not to

- **Do:** Use for a moderate, finite set of options where multiple choices are
  needed.
- **Do:** Enable search filtering when the list exceeds ~15 options.
- **Do:** Use renderOption for custom option rows; the checkbox affordance remains
  owned by MultiSelector.
- **Do:** Enable select-all when most users will want all or nearly all options
  selected.
- **Do:** Use inside InputGroup only when the control needs a short prefix or
  suffix addon as part of one decorated input surface; prefer count or
  labels trigger display so the group stays single-line.
- **Do:** Use variant="secondary" when a multi-selector sits beside secondary
  buttons or segmented controls, and variant="ghost" when it sits beside
  ghost buttons. If validation status is needed there, prefer
  statusVariant="tooltip" so the toolbar height stays compact.
- **Do:** Use presentation="adaptive" when the multi-selector should become a
  bottom sheet on compact touch screens.
- **Don't:** Use for single-value selection; use Selector instead.
- **Don't:** Show more than ~20 options without enabling search.
- **Don't:** Wrap a disabled MultiSelector in Tooltip to explain why it is disabled;
  disabled triggers swallow the hover events the wrapper needs. Use the
  disabledMessage prop instead.

## Props

| prop | type | required | default | meaning |
| --- | --- | --- | --- | --- |
| `label` | `string` | yes | `` | Label text for the multi-selector (always rendered for accessibility). / |
| `onClick` | `React.MouseEventHandler<HTMLElement>` | no | `` | Click handler on the trigger (or, with `renderTrigger`, the caller's control). It runs after the built-in toggle and cannot cancel it. / |
| `onFocus` | `React.FocusEventHandler<HTMLElement>` | no | `` | Focus handler on the trigger. It runs before the selector's own focus handling. / |
| `onKeyDown` | `React.KeyboardEventHandler<HTMLElement>` | no | `` | Key handler on the trigger. It runs after the built-in keyboard model and is skipped for keys that model handles and cancels. / |
| `isLabelHidden` | `boolean` | no | `false /` | Whether to visually hide the label (still accessible to screen readers). |
| `description` | `string` | no | `` | Description text displayed between the label and selector. / |
| `isOptional` | `boolean` | no | `false /` | Whether the field is optional. Mutually exclusive with isRequired. |
| `isRequired` | `boolean` | no | `false /` | Whether the field is required. Mutually exclusive with isOptional. |
| `isDisabled` | `boolean` | no | `false /` | Whether the selector is disabled. |
| `isReadOnly` | `boolean` | no | `false /` | Whether the selector is read-only. The selected values stay visible, focusable, and included in form submission, and retain their combobox identity with `aria-readonly`. The selection surface and editing affordances are removed. Unlike `isDisabled`, a read-only selector is not dimmed and stays in the tab order. `isDisabled` takes precedence when both are set. |
| `disabledMessage` | `string` | no | `` | Explains why the selector is disabled. When set together with `isDisabled`, the selector shows a tooltip with this text on hover and keyboard focus, and the trigger stays focusable (via `aria-disabled`) so the reason is discoverable by keyboard and assistive technology. Activation stays blocked. Use this instead of wrapping a disabled selector in `Tooltip` — disabled controls don't emit the pointer events an external tooltip needs. @example ``` <MultiSelector label="Columns" options={columns} value={selected} onChange={setSelected} isDisabled disabledMessage="Select a table first" /> ``` / |
| `options` | `T[]` | yes | `` | The options to display in the selector. Can be strings, objects, dividers, or sections. / |
| `value` | `string[]` | yes | `` | The currently selected values. / |
| `htmlName` | `string` | no | `` | The HTML name attribute for form submissions. When set, hidden inputs carry one entry per selected value under this name, matching how a native multi-select serializes. / |
| `onChange` | `(value: string[], change?: MultiSelectorChange) => void` | yes | `` | Callback when selection changes. A creation (`hasCreate`) arrives with a descriptor as the second argument and the typed text appended to `value`; the caller adds the matching option and accepts the value in the same update. Every other change passes no descriptor. / |
| `changeAction` | `(value: string[]) => void \| Promise<void>` | no | `` | Async action on change. Fires after onChange. / |
| `isLoading` | `boolean` | no | `false /` | Whether the selector is in a loading state. |
| `placeholder` | `string` | no | `'Select...' /` | Placeholder text when no value is selected. |
| `size` | `MultiSelectorSize` | no | `'md' /` | The size of the selector. |
| `variant` | `MultiSelectorVariant` | no | `'input' /` | Visual style of the selector trigger. - 'input': bordered input-style trigger for forms - 'secondary': matches the theme's secondary buttons (borderless and neutral-filled by default) - 'ghost': borderless, transparent trigger matching ghost buttons |
| `status` | `MultiSelectorStatus` | no | `` | Status indicator for the selector. / |
| `statusVariant` | `FieldStatusVariant` | no | `'attached' for input selectors; 'detached' for secondary and ghost selectors /` | How the status message is placed relative to the input. - 'attached': message overlaps directly below the bordered input (input variant only) - 'detached': message floats below as a separate element with spacing - 'tooltip': message is exposed from the on-field status icon |
| `width` | `SizeValue` | no | `` | Width of the field. Numbers are treated as pixels, strings are used as-is (e.g. `'100%'`). Sizes the whole field (label, control, and status) so they stay aligned, unlike setting width via `controlXstyle`/`controlClassName`/`controlStyle`. / |
| `labelTooltip` | `string` | no | `` | Tooltip text to display in an info icon at the end of the label. / |
| `startIcon` | `ReactNode \| IconType` | no | `` | Icon displayed at the start of the selector trigger. / |
| `hasClear` | `boolean` | no | `false /` | Whether to show a clear button when values are selected. When clicked, resets the value to an empty array and returns focus to the trigger. |
| `hasSelectAll` | `boolean` | no | `false /` | Whether to show a "Select all" checkbox. |
| `selectAllLabel` | `string` | no | `'Select all' /` | Label for the select-all checkbox. |
| `hasSearch` | `boolean` | no | `false /` | Whether to show a search input. |
| `searchPlaceholder` | `string` | no | `'Search...' /` | Placeholder text for the search input. |
| `emptyText` | `ReactNode` | no | `'No options' /` | Content shown in the panel when there are no options to show, and announced in a polite live region when the panel opens. Not shown while `isLoading` — the options have not arrived yet. |
| `emptySearchText` | `ReactNode` | no | `'No results found' /` | Content shown in the panel when a search query matches no options, and announced in a polite live region at the same time. The panel message is `role="presentation"`, so the live region is the only route to assistive tech. It announces the text this content renders, read from the DOM, so an element is announced as written and anything marked `aria-hidden` is left out of both. |
| `hasCreate` | `boolean` | no | `false /` | With `hasSearch`, offer a `Create "<query>"` row first in the list when the trimmed query equals no option's label under the search's own matching (case-insensitive). Picking it, or Enter with nothing highlighted, calls `onChange` with the query appended to `value` and a `{type: 'create', query}` descriptor, then clears the search. The caller MUST add an option for the new value in that same update; the component does not mint options. Nothing is offered while `isLoading`. Setting this without `hasSearch` warns in development and offers nothing. |
| `triggerDisplay` | `'count' \| 'labels' \| 'badges'` | no | `'count' /` | How to display selected items in the trigger. - 'count': "3 selected" - 'labels': "Name, Email, +3" - 'badges': [Name] [Email] +2 |
| `formatValue` | `(items: MultiSelectorSelectedItem[]) => string` | no | `items => `${items.length} selected` for 'count', "A, B, C, +N" for 'labels' /` | Formats the trigger text when triggerDisplay is 'count' or 'labels'. Receives the selected items (value plus resolved label, in selection order) and returns the full trigger text; the count is `items.length`. Not called when nothing is selected — the placeholder shows instead — and not called for triggerDisplay 'badges', which renders Badge elements rather than text. |
| `maxBadges` | `number` | no | `3 /` | Maximum number of badges to show before showing "+N". Only used when triggerDisplay is 'badges'. |
| `renderOption` | `(option: MultiSelectorOptionData) => ReactNode` | no | `` | Custom render function for options. Only called for selectable options (not dividers/sections or the select-all row). / |
| `indicatorPosition` | `IndicatorPosition` | no | `'start' /` | Which edge of the option row carries the checkbox. |
| `presentation` | `MultiSelectorPresentation` | no | `'popover' /` | How the option list is presented. - 'popover': anchored to the trigger - 'bottom-sheet': modal sheet suited to compact touch screens - 'adaptive': bottom sheet on compact coarse-pointer screens, otherwise popover |
| `isDefaultOpen` | `boolean` | no | `false /` | Whether the dropdown starts open on mount. Useful for showcases and previews. |
| `renderTrigger` | `(props: MultiSelectorRenderTriggerProps) => ReactNode` | no | `` | Render the control the panel hangs off — a glyph in a list row, a chip, an icon button — instead of the selector's own field and button. Spread the given props onto it; the listbox is then anchored to and labelled by that control, and `label` names the listbox for assistive technology. The field chrome (`Field`, status, clear button, spinner) is not rendered; the caller owns the opener. Pair with `handleRef` to open the panel from a keystroke elsewhere. Hover and pressed paint stay yours. The open state reaches your control as `aria-expanded` on the given props, so style it from the rendered attribute. A pressed look keyed to `:active` is not a substitute: `:active` does not behave the same under a coarse pointer, which is why menu rows drop coarse-pointer `:active` paint entirely. A read-only selector has no panel to open, so the disclosure attributes and the opening handlers are withheld: your control reports `aria-expanded="false"` and points at nothing. @example ``` <MultiSelector label="Labels" renderTrigger={props => <IconButton icon="tag" label="Labels" {...props} />} … /> ``` @example ``` // Styling the open state from the rendered attribute: // .my-trigger[aria-expanded='true'] { background: var(--color-overlay-pressed); } ``` / |
| `handleRef` | `React.Ref<MultiSelectorHandle>` | no | `` | Imperative handle for opening and closing the panel. Prefer `handleRef` over mirroring open state in the parent — the selector owns its visibility, and imperative calls avoid the focus-management pitfalls of syncing an external `isOpen` prop. / |
| `onOpenChange` | `(isOpen: boolean) => void 'data-testid'?: string` | no | `` | Called whenever the panel opens or closes, however it happened — the trigger, the keyboard, a light dismiss, Escape, or the imperative handle. / |

## Anatomy

- `Field` (optional) — Standalone Field shell that provides the label and optional supporting content; omitted inside InputGroup.
- `Trigger` (required) — Painted control that displays the current selection or placeholder and opens the selection surface when editable.
- `Icon-rendered start icon` (optional) — Optional leading semantic icon or icon component rendered through Icon.
- `Caller-rendered start content` (optional) — Optional arbitrary React content rendered directly at the start of the trigger.
- `Trigger clear button` (optional) — Shared clear action that removes every selected value when hasClear is enabled.
- `Status icon` (optional) — Status glyph shown in place of the disclosure indicator for attached or tooltip status.
- `Indicator icon` (optional) — Trailing chevron shown when status presentation does not replace it; reflects collapsed or expanded state.
- `Search row` (optional) — Panel header with a borderless search input and optional clear action.
- `Search icon` (optional) — Leading magnifier rendered through Icon inside the search row.
- `Search clear button` (optional) — Shared clear action shown in the search row while a query is present.
- `Option row` (optional) — Selectable row for an option or the optional select-all choice.
- `Option checkbox indicator` (optional) — CheckboxInput indicator that presents each row’s selected, unselected, or indeterminate state.
- `Option divider` (optional) — Divider supplied in the public options data to separate adjacent option groups.
- `Section heading` (optional) — Visible heading for a labeled group of option rows.
- `Empty state` (optional) — Message shown when the shared panel content has no options or no search matches.
- `Pointer popup` (optional) — Anchored painted surface that hosts the shared panel content for popover presentation.
- `Touch sheet heading` (optional) — Heading above the shared panel content in bottom-sheet presentation.
- `Touch sheet` (optional) — BottomSheet surface that hosts the same panel content for bottom-sheet presentation.

## Retrieval keywords

`multiselect`, `checkbox`, `dropdown`, `multi`, `picker`, `checklist`, `facet`, `filter`, `select`

---

Generated from `astryx/packages/core/src/MultiSelector/MultiSelector.doc.mjs` (MIT, https://github.com/facebook/astryx). Spec: yes · upstream tests: yes.

<!-- port-status:begin (generated by tools/gen-port-status.py) -->
## OCaml port

**Status:** not ported yet. The upstream contract above is the specification; see `docs/PORT-STATUS.md` for the milestone it is planned in.

<!-- port-status:end -->
