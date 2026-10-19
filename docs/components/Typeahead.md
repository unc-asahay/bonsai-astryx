# Typeahead

**Category:** Form Controls  |  **Group:** Typeahead  |  **Port status:** not started

A searchable input for selecting a single item from a large or dynamic
dataset. Results appear as the user types, with support for async data
sources, debounced search, and custom item rendering. Use it when the option
list is too large for a Selector dropdown.

## When to reach for it / when not to

- **Do:** Provide descriptive placeholder text that hints at what users can search
  for.
- **Do:** Show suggestions on focus when users benefit from seeing popular or
  recent options before typing.
- **Do:** Add a search delay for remote data sources to avoid excessive network
  requests.
- **Do:** Use inside InputGroup when the typeahead needs a single-line prefix or
  suffix addon.
- **Don't:** Use for short, static option lists; use Selector for better
  discoverability.
- **Don't:** Use for multi-selection; use Tokenizer instead.
- **Don't:** Place multiple Typeaheads adjacent to each other without clear labels
  differentiating them.
- **Don't:** Wrap a disabled Typeahead in Tooltip to explain why it is disabled;
  disabled triggers swallow the hover events the wrapper needs. Use the
  disabledMessage prop instead.

## Props

| prop | type | required | default | meaning |
| --- | --- | --- | --- | --- |
| `label` | `string` | yes | `` | Accessible label for the input. |
| `searchSource` | `SearchSource<T>` | yes | `` | Data source providing search and bootstrap methods for populating the dropdown. |
| `value` | `T \| null` | yes | `` | Currently selected item, or null if nothing is selected. |
| `onChange` | `(item: T \| null) => void` | yes | `` | Called when the selection changes. |
| `placeholder` | `string` | no | `` | Input placeholder text. |
| `hasEntriesOnFocus` | `boolean` | no | `false` | Show bootstrap results on focus before typing. |
| `hasClear` | `boolean` | no | `true` | Show clear button to deselect the current value. |
| `isDisabled` | `boolean` | no | `false` | Disables the input. |
| `disabledMessage` | `string` | no | `` | Explains why the input is disabled. With isDisabled, shows a tooltip on hover/keyboard focus and keeps the field focusable via aria-disabled (activation stays blocked). Use this instead of wrapping a disabled Typeahead in Tooltip. Disabled controls swallow the hover events an external Tooltip needs. |
| `maxMenuItems` | `number` | no | `10` | Maximum number of dropdown items to display. |
| `minQueryLength` | `number` | no | `1` | Minimum query length before the search source is queried. Below it no search runs and the menu stays closed. |
| `status` | `{type: 'warning' \| 'error' \| 'success', message?: string}` | no | `` | Validation status object with type and message for error/warning/success states. |
| `statusVariant` | `'attached' \| 'detached' \| 'tooltip'` | no | `'attached'` | How the status message is placed relative to the input. attached overlaps directly below the input (bordered treatment); detached floats below as a separate element with spacing; tooltip reveals the message in an info-tip button. |
| `renderItem` | `(item: T) => ReactNode` | no | `` | Custom render function for dropdown items. Default renders TypeaheadItem. |
| `isLabelHidden` | `boolean` | no | `false` | Visually hides the label while keeping it accessible. |
| `description` | `string` | no | `` | Helper text displayed below the label. |
| `isRequired` | `boolean` | no | `false` | Marks the field as required. |
| `isOptional` | `boolean` | no | `false` | Shows an optional indicator on the label. |
| `labelTooltip` | `string` | no | `` | Tooltip text shown on the label. |
| `emptySearchText` | `ReactNode` | no | `'No results found'` | Content shown when the query matched nothing. Takes a ReactNode, so the dead end can carry a link or a create row. Announced in a polite live region as the text it renders, read from the DOM; aria-hidden parts stay out of both, and content that renders no text announces nothing. null counts as not given, like undefined, and falls through to the default; pass an empty string to render nothing. |
| `hasAutoFocus` | `boolean` | no | `false` | Auto-focus the input on mount. |
| `size` | `'sm' \| 'md' \| 'lg'` | no | `'md'` | Input and token size. |
| `debounceMs` | `number` | no | `150` | Debounce delay in ms before triggering search. Set to 0 for synchronous sources. |
| `onChangeQuery` | `(query: string) => void` | no | `` | Callback fired when the search query text changes. |
| `onOpenChange` | `(isOpen: boolean) => void` | no | `` | Callback when the dropdown opens or closes. |
| `width` | `SizeValue` | no | `` | Width of the field (number = pixels, string used as-is, e.g. "100%"). Sizes the whole field (label, control, and status) so they stay aligned. |
| `startIcon` | `IconType \| ReactNode` | no | `` | SVG icon component displayed at the start of the input. |
| `containerXstyle` | `StyleXStyles` | no | `` | StyleX styles for the field container (label, control, and status together). No effect inside InputGroup (style the InputGroup instead) or in a `horizontal-labels` FormLayout. Root `xstyle`, `className`, and `style` are not accepted. |
| `containerClassName` | `string` | no | `` | Class name for the field container. Same targeting as `containerXstyle`. |
| `containerStyle` | `CSSProperties` | no | `` | Inline styles for the field container. Same targeting as `containerXstyle`. |
| `controlXstyle` | `StyleXStyles` | no | `` | StyleX styles for the visual control box: the element that paints the border and background and holds icons and end controls. Never the native input. |
| `controlClassName` | `string` | no | `` | Class name for the visual control box. |
| `controlStyle` | `CSSProperties` | no | `` | Inline styles for the visual control box. |

## Anatomy

- `Field` (optional) — Standalone Field shell that provides the label and optional supporting content; omitted inside InputGroup.
- `Input surface` (required) — Painted control surface containing the editable input or the selected token.
- `Icon-rendered start icon` (optional) — Optional leading semantic icon or icon component rendered through Icon.
- `Caller-rendered start content` (optional) — Optional arbitrary React content rendered directly at the start of the input surface.
- `Selected token` (optional) — Token that presents the selected item while the control is not in edit mode.
- `Spinner` (optional) — Loading indicator shown at the end of the input surface while a search is in flight.
- `Clear button` (optional) — Shared clear action that removes the selected item when hasClear is enabled.
- `Dropdown` (optional) — Anchored listbox surface containing the current search results.
- `Empty state` (optional) — Message shown after a completed search returns no results.
- `Result row` (optional) — Stable option wrapper that owns highlight, selection, pointer, and keyboard behavior.
- `Default item content` (optional) — Standard TypeaheadItem label and supporting content rendered inside a result row when renderItem and item.element are absent.
- `Caller-rendered item content` (optional) — Caller-owned result content supplied through renderItem or item.element inside the stable result row.
- `Result group heading` (optional) — Visible heading for a labeled group of result rows.
- `Selected result state` (optional) — Selected styling and trailing check presented on the current result row.

## Retrieval keywords

`typeahead`, `autocomplete`, `combobox`, `searchbox`, `autosuggest`, `select`, `dropdown`, `lookup`, `searchable`, `suggestion`, `picker`

---

Generated from `astryx/packages/core/src/Typeahead/Typeahead.doc.mjs` (MIT, https://github.com/facebook/astryx). Spec: yes · upstream tests: no.
