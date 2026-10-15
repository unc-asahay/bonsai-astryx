# PowerSearch

**Category:** Form Controls  |  **Group:** -  |  **Port status:** not started

PowerSearch is a structured filter bar where each token represents a field,
operator, and value. Use it for complex multi-dimensional filtering when
users need to combine multiple search criteria. For simple single-field
search, use a text input instead.

## When to reach for it / when not to

- **Do:** Define clear, descriptive field names and aliases so users can quickly
  find the filter they need.
- **Do:** Provide a result count to give users feedback on how their filters
  affect the data set.
- **Don't:** Use PowerSearch for simple keyword searches; a standard text input is
  more appropriate for single-field lookups.
- **Don't:** Wrap a disabled PowerSearch in Tooltip to explain why it is disabled;
  disabled controls swallow the hover events the wrapper needs. Use the
  disabledMessage prop instead.

## Props

| prop | type | required | default | meaning |
| --- | --- | --- | --- | --- |
| `config` | `PowerSearchConfig` | yes | `` | Configuration defining available fields, operators, and their value types. |
| `filters` | `ReadonlyArray<PowerSearchFilter>` | yes | `` | Currently active filters. |
| `onChange` | `(filters: ReadonlyArray<PowerSearchFilter>, changeType: 'add' \| 'edit' \| 'remove', index: number) => void` | yes | `` | Called when filters change. changeType is 'add', 'edit', or 'remove'. index is the affected filter's position. |
| `label` | `string` | no | `'Search'` | Accessible label for the search input. |
| `isLabelHidden` | `boolean` | no | `true` | Visually hides the label while keeping it accessible. |
| `placeholder` | `string` | no | `'Search...'` | Placeholder text shown when no filters are selected. |
| `hasAutoFocus` | `boolean` | no | `false` | Auto-focus the input on mount. |
| `hasClear` | `boolean` | no | `true` | Show a clear-all button for removing all filters. |
| `isReadOnly` | `boolean` | no | `false` | Prevent adding, editing, or removing filters. |
| `isDisabled` | `boolean` | no | `false` | Disables the entire component. |
| `disabledMessage` | `string` | no | `` | Explains why the search is disabled. With isDisabled, shows a tooltip on hover/keyboard focus and keeps the input focusable via aria-disabled (input stays blocked). Use this instead of wrapping a disabled PowerSearch in Tooltip. Disabled controls swallow the hover events an external Tooltip needs. |
| `status` | `{type: 'warning' \| 'error' \| 'success', message?: string}` | no | `` | Validation status object with type and optional message. |
| `startIcon` | `ReactNode \| IconType` | no | `` | Icon to display at the start of the input, before any filter tokens. Forwarded to the internal Tokenizer. Accepts a semantic icon name, an SVG icon component, or a ReactNode directly. |
| `statusVariant` | `'attached' \| 'detached'` | no | `'attached'` | How the status message is placed relative to the input. attached overlaps directly below the input (bordered treatment); detached floats below as a separate element with spacing. |
| `maxTokenLength` | `number` | no | `40` | Max character length for filter value display in tokens. |
| `maxOperatorMenuItems` | `number` | no | `10` | Maximum suggestions shown in string and entity value typeaheads. Does not affect the main field search menu or enum value menus. |
| `maxSearchResults` | `number` | no | `10` | Max ranked results for a non-empty query. Does not affect a field value editor. Browsing with an empty query shows up to 1,000 fields. |
| `menuWidth` | `number` | no | `` | Width in pixels for the main field/search menu. Does not affect field value editors. |
| `popoverSaveButtonLabel` | `string` | no | `'Apply'` | Label for the save button in the edit popover. |
| `timezoneID` | `string` | no | `` | Timezone ID for date formatting (e.g. "America/New_York"). |
| `handleRef` | `Ref<PowerSearchHandle>` | no | `` | Imperative handle with focusTypeahead() and blurTypeahead() methods. |
| `endContent` | `ReactNode` | no | `` | Content to display at the end of the input row. Useful for action buttons or other controls. |
| `resultCount` | `number \| string` | no | `` | Number of results matching the current filters. When a number, formatted as "N results". When a string, displayed as-is. Changes are announced to screen readers via a polite live region. |
| `size` | `'sm' \| 'md' \| 'lg'` | no | `'md'` | Size of the search input and tokens. |
| `menuWidth` | `number` | no | `` | Maximum width for the operator/value dropdown menu in pixels. |
| `maxOperatorMenuItems` | `number` | no | `` | Maximum number of items displayed in the operator dropdown. |
| `tokenOverflowBehavior` | `'none' \| 'unfocusedInline' \| 'unfocusedLayer'` | no | `'none'` | Controls how tokens overflow when the container is too narrow. Forwarded to Tokenizer. |
| `onFocus` | `(e: React.FocusEvent) => void` | no | `` | Fires when focus enters the search input. |
| `onBlur` | `(e: React.FocusEvent) => void` | no | `` | Fires when focus leaves the search input. |
| `xstyle` | `StyleXStyles` | no | `` | StyleX styles for layout customization. Must be a stylex.create() value. |

## Retrieval keywords

`powersearch`, `search`, `searchbar`, `filter`, `filterbar`, `faceted`, `querybuilder`, `structured`, `omnibar`

---

Generated from `astryx/packages/core/src/PowerSearch/PowerSearch.doc.mjs` (MIT, https://github.com/facebook/astryx). Spec: yes · upstream tests: no.

<!-- port-status:begin (generated by tools/gen-port-status.py) -->
## OCaml port

**Status:** not ported yet. The upstream contract above is the specification; see `docs/PORT-STATUS.md` for the milestone it is planned in.

<!-- port-status:end -->
