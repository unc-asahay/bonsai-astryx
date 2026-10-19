# Tokenizer

**Category:** Form Controls  |  **Group:** -  |  **Port status:** not started

Tokenizer is a multi-select input that lets users search, select, and manage
multiple items displayed as removable chips. Use it when users need to build
a set of selections from a searchable data source, like adding team members,
applying tags, or choosing filters.

## When to reach for it / when not to

- **Do:** Write a placeholder that tells users what they can search for, such as
  "Search people..." or "Add tags...", so the input is not a blank
  mystery.
- **Do:** Set maxEntries when the number of selections should be bounded, like
  limiting a review to 5 approvers.
- **Do:** Use hasCreate for free-form tagging where users need to enter values
  that do not exist in the search source.
- **Do:** Show validation status with the status prop so users know immediately
  when a selection is missing or invalid.
- **Don't:** Don't use Tokenizer for single-item selection; use Typeahead instead.
  Tokenizer is for building sets of two or more items.
- **Don't:** Avoid applying custom colors to individual tokens inside a Tokenizer;
  use the default token style for visual consistency across the set.
- **Don't:** Don't hide the label; every Tokenizer needs a visible label so users
  understand what they are selecting. Use isLabelHidden only when
  surrounding context makes the purpose obvious.
- **Don't:** Wrap a disabled Tokenizer in Tooltip to explain why it is disabled;
  disabled controls swallow the hover events the wrapper needs. Use the
  disabledMessage prop instead.

## Props

| prop | type | required | default | meaning |
| --- | --- | --- | --- | --- |
| `label` | `string` | yes | `` | Accessible label for the input. |
| `searchSource` | `SearchSource<T>` | yes | `` | Data source providing search and bootstrap methods for populating the dropdown. |
| `value` | `T[]` | yes | `` | Array of currently selected items. |
| `onChange` | `(items: T[], change: TokenizerChange<T>) => void` | yes | `` | Called when selection changes. The change argument includes the affected item and type ('add' \| 'create' \| 'remove' \| 'reorder'). Additions and removals (including Backspace on an empty input) are announced to screen readers via a polite live region. |
| `placeholder` | `string` | no | `` | Input placeholder text. Only shown when no tokens are selected. |
| `maxEntries` | `number` | no | `` | Maximum number of selections allowed. Input is hidden when the limit is reached. |
| `hasClear` | `boolean` | no | `false` | Show a clear-all button for bulk removal of all tokens. |
| `renderToken` | `(item: T, onRemove: () => void) => ReactNode` | no | `` | Custom render function for selected tokens. Default renders Token with label and onRemove. |
| `renderItem` | `(item: T) => ReactNode` | no | `` | Custom render function for dropdown items. Default renders TypeaheadItem. |
| `isDisabled` | `boolean` | no | `false` | Disables the input and all token interactions. |
| `htmlName` | `string` | no | `` | The HTML name attribute for form submissions. Renders one hidden input per selected item id. |
| `disabledMessage` | `string` | no | `` | Explains why the tokenizer is disabled. With isDisabled, shows a tooltip on hover/keyboard focus and keeps the input focusable via aria-disabled (input stays blocked). Use this instead of wrapping a disabled Tokenizer in Tooltip. Disabled controls swallow the hover events an external Tooltip needs. |
| `status` | `{type: 'warning' \| 'error' \| 'success', message?: string}` | no | `` | Validation status object with type and message for error/warning/success states. |
| `statusVariant` | `'attached' \| 'detached' \| 'tooltip'` | no | `'attached'` | How the status message is placed relative to the input. attached overlaps directly below the input (bordered treatment); detached floats below as a separate element with spacing; tooltip reveals the message in an info-tip button. |
| `isLabelHidden` | `boolean` | no | `false` | Visually hides the label while keeping it accessible. |
| `description` | `string` | no | `` | Helper text displayed below the label. |
| `isRequired` | `boolean` | no | `false` | Marks the field as required. |
| `isOptional` | `boolean` | no | `false` | Shows an optional indicator on the label. |
| `labelTooltip` | `string` | no | `` | Tooltip text shown on the label. |
| `hasEntriesOnFocus` | `boolean` | no | `false` | Show bootstrap results on focus before typing. |
| `maxMenuItems` | `number` | no | `10` | Maximum number of search results to display. The hasCreate entry is offered on top of them, so a menu can show one more than this. |
| `menuWidth` | `number` | no | `` | Fixed dropdown width in pixels. The menu never shrinks below its anchor width. |
| `minQueryLength` | `number` | no | `1` | Minimum query length before the search source is queried. Below it no search runs, and the menu stays closed — unless hasCreate is set, in which case the "Create ..." entry is still offered, being derived from the typed text rather than fetched for it. |
| `emptySearchText` | `ReactNode` | no | `'No results found'` | Content shown when the query matched nothing. Takes a ReactNode, so the dead end can carry a link or a create row. Announced in a polite live region as the text it renders, read from the DOM; aria-hidden parts stay out of both, and content that renders no text announces nothing. null counts as not given, like undefined, and falls through to the default; pass an empty string to render nothing. |
| `hasAutoFocus` | `boolean` | no | `false` | Auto-focus the input on mount. |
| `size` | `'sm' \| 'md' \| 'lg'` | no | `'md'` | Input and token size. |
| `debounceMs` | `number` | no | `150` | Debounce delay in ms before triggering search. Set to 0 for synchronous sources. |
| `hasCreate` | `boolean` | no | `false` | Allow users to create new tokens from free-text input. When true, a "Create" option appears in the dropdown for typed text that doesn't match existing results. The onChange change type is 'create' for these items. |
| `onChangeQuery` | `(query: string) => void` | no | `` | Callback fired when the search query text changes. |
| `startIcon` | `ReactNode \| IconType` | no | `` | Icon to display at the start of the input, before any tokens. Accepts a semantic icon name, an SVG icon component, or a ReactNode directly. |
| `endContent` | `ReactNode` | no | `` | Content to display at the end of the input row. Useful for buttons, result counts, or other controls. |
| `handleRef` | `React.Ref<TokenizerHandle>` | no | `` | Imperative handle exposing focusInput(), focusFirstToken(), focusLastToken(), clearInput(), and selectAll(). |
| `width` | `SizeValue` | no | `` | Width of the field (number = pixels, string used as-is, e.g. "100%"). Sizes the whole field (label, control, and status) so they stay aligned. |
| `tokenOverflowBehavior` | `'none' \| 'unfocusedInline' \| 'unfocusedLayer'` | no | `'none'` | Controls how tokens overflow when the container is too narrow. |
| `onFocus` | `(e: FocusEvent<HTMLInputElement>) => void` | no | `` | Fires when focus enters the tokenizer input. |
| `onBlur` | `(e: FocusEvent<HTMLInputElement>) => void` | no | `` | Fires when focus leaves the tokenizer input. |
| `containerXstyle` | `StyleXStyles` | no | `` | StyleX styles for the field container (label, control, and status together). No effect inside InputGroup (style the InputGroup instead) or in a `horizontal-labels` FormLayout. Root `xstyle`, `className`, and `style` are not accepted. |
| `containerClassName` | `string` | no | `` | Class name for the field container. Same targeting as `containerXstyle`. |
| `containerStyle` | `CSSProperties` | no | `` | Inline styles for the field container. Same targeting as `containerXstyle`. |
| `controlXstyle` | `StyleXStyles` | no | `` | StyleX styles for the visual control box: the element that paints the border and background and holds icons and end controls. Never the native input. |
| `controlClassName` | `string` | no | `` | Class name for the visual control box. |
| `controlStyle` | `CSSProperties` | no | `` | Inline styles for the visual control box. |

## Anatomy

- `Label` (required) — The visible text above the input describing what the user is selecting. Also used as the accessible name.
- `Token chips` (optional) — Removable chips representing each selected item. Each chip shows a label and a remove button.
- `Search input` (required) — The text input where users type to search the data source. Hides when maxEntries is reached.
- `Dropdown menu` (optional) — The search results list that appears below the input as the user types.
- `Spinner` (optional) — Loading indicator shown at the end of the field while a search is in flight.
- `End content` (optional) — A trailing slot after the input for action buttons, counts, or other controls.
- `Clear button` (optional) — A button that removes all selected tokens at once. Shown when hasClear is true and tokens are present.

## Retrieval keywords

`tokenizer`, `multiselect`, `multi-select`, `chips`, `tags`, `combobox`, `autocomplete`, `taginput`, `chipinput`

---

Generated from `astryx/packages/core/src/Tokenizer/Tokenizer.doc.mjs` (MIT, https://github.com/facebook/astryx). Spec: yes · upstream tests: no.
