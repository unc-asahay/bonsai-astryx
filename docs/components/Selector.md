# Selector

**Category:** Form Controls  |  **Group:** Selector  |  **Port status:** not started

A dropdown selector for choosing a single value from a list of options.
Supports labels, validation, descriptions, and required/optional states. Use
it in forms and settings when presenting a moderate number of options.
Keyboard typeahead matches a native select: typing on the focused closed
trigger selects the matching option directly, repeated presses cycle through
options sharing a first letter, and spaces count as match characters ("new
y" reaches "New York"). With the menu open, typing moves the highlight and
Enter commits. With hasSearch, typing on the closed trigger opens the popup
and seeds the search input.

## When to reach for it / when not to

- **Do:** Provide a visible label so users understand what they are selecting.
- **Do:** Use sections and dividers to organize options when the list exceeds ~8
  items.
- **Do:** Use renderOption for custom option rows. Do not pass SelectorOption
  directly as JSX children.
- **Do:** Set a meaningful placeholder that hints at the expected selection (e.g.
  "Choose a country" not "Select...").
- **Do:** Use inside InputGroup only when the selector needs a short prefix or
  suffix addon as part of one decorated input surface.
- **Do:** Use variant="secondary" when a selector sits in a nav or toolbar beside
  secondary buttons or a segmented control, so it shares their treatment
  instead of reading as a form field. Use variant="ghost" when a selector
  sits in a toolbar with ghost buttons. If validation status is needed
  there, prefer statusVariant="tooltip" so the toolbar height stays
  compact.
- **Do:** Use presentation="adaptive" when the selector should become a bottom
  sheet on compact touch screens.
- **Don't:** Use for action menus; use Dropdown Menu for triggering commands or
  navigation.
- **Don't:** Use when there are only two options; use a SegmentedControl or radio
  buttons instead.
- **Don't:** Use Selector for navigation; links should be links, not dropdown
  options.
- **Don't:** Use for yes/no or on/off choices; use Switch or CheckboxInput instead.
- **Don't:** Put more than ~20 options without sections; consider Typeahead for large
  lists.
- **Don't:** Wrap a disabled Selector in Tooltip to explain why it is disabled;
  disabled triggers swallow the hover events the wrapper needs. Use the
  disabledMessage prop instead.

## Props

| prop | type | required | default | meaning |
| --- | --- | --- | --- | --- |
| `label` | `string` | yes | `` | Label text for accessibility. |
| `options` | `SelectorOption[]` | yes | `` | Array of items: strings, objects with value/label/description/icon/disabled, dividers ({type: "divider"}), or sections ({type: "section", title, options}). |
| `value` | `string` | no | `` | Currently selected value. |
| `onChange` | `(value: string) => void` | no | `` | Callback fired when the selection changes. |
| `hasClear` | `boolean` | no | `false` | Shows a clear (×) button when a value is selected. When true, onChange also accepts null to signal the user cleared the selection. |
| `hasSearch` | `boolean` | no | `false` | Whether to show a search input for filtering options. As the user types, the match count (or "No results found") is announced to screen readers via a polite live region. The search field has built-in affordances: a leading magnifier icon and, once a query is typed, a trailing clear (✕) button that resets the query and returns focus to the input. |
| `searchPlaceholder` | `string` | no | `'Search...'` | Placeholder text for the search input. |
| `emptyText` | `ReactNode` | no | `'No options'` | Content shown in the dropdown panel when there are no options to show, and announced in a polite live region when the panel opens. The announcement is the text this content renders, read from the DOM, so an element is announced as written and aria-hidden parts are left out of both. Not shown while isLoading. |
| `emptySearchText` | `ReactNode` | no | `'No results found'` | Content shown in the dropdown panel when a search query matches no options, and announced in a polite live region at the same time. The announcement is the text this content renders, read from the DOM, so an element is announced as written and aria-hidden parts are left out of both. |
| `placeholder` | `string` | no | `'Select...'` | Placeholder text shown when no value is selected. |
| `size` | `'sm' \| 'md' \| 'lg'` | no | `'md'` | Size variant for the selector. |
| `variant` | `'input' \| 'secondary' \| 'ghost'` | no | `'input'` | Visual trigger style. input is the bordered input treatment for forms; secondary matches the secondary buttons of the active theme (borderless and neutral-filled by default) for navs and toolbars; ghost is borderless and transparent, matching ghost buttons for toolbar usage. |
| `isDisabled` | `boolean` | no | `false` | Disables the selector. |
| `isReadOnly` | `boolean` | no | `false` | Makes the selector read-only: the selected value stays visible, focusable, and included in form submission, and retains its combobox identity with aria-readonly. The selection surface, clear action, and disclosure indicator are removed. Unlike isDisabled, the control is not dimmed. isDisabled takes precedence when both are set. |
| `htmlName` | `string` | no | `` | The HTML name attribute for form submissions. Renders a hidden input carrying the selected value, like a native select. |
| `disabledMessage` | `string` | no | `` | Explains why the selector is disabled. With isDisabled, shows a tooltip on hover/keyboard focus and keeps the trigger focusable via aria-disabled (activation stays blocked). Use this instead of wrapping a disabled Selector in Tooltip. Disabled controls swallow the hover events an external Tooltip needs. |
| `isLabelHidden` | `boolean` | no | `false` | Visually hides the label while keeping it accessible. |
| `description` | `string` | no | `` | Helper text displayed below the label. |
| `isOptional` | `boolean` | no | `false` | Marks the field as optional. |
| `isRequired` | `boolean` | no | `false` | Marks the field as required. |
| `status` | `{type: 'error' \| 'warning' \| 'success', message?: string}` | no | `` | Validation status with an optional message. |
| `statusVariant` | `'attached' \| 'detached' \| 'tooltip'` | no | `'attached' for input selectors; 'detached' for secondary and ghost selectors` | How the status message is placed relative to the input. attached overlaps directly below the bordered input and is only valid for the input variant; secondary and ghost selectors detach attached status messages by default. Use tooltip for compact toolbar controls. |
| `renderOption` | `(option: SelectorOptionData) => ReactNode` | no | `` | Custom render function for each selectable option in the dropdown. Use this instead of JSX children; dividers and sections are rendered by the selector. |
| `renderValue` | `(option: SelectorOptionData) => ReactNode` | no | `` | Custom render function for the selected option inside the closed trigger. A one-line value follows the active size token, including compact or wide spacing scales with icons or a clear control. Padding accommodates the trigger line box, and each extra line grows the control by one line (28/32/36 for one line and 48/52/56 for two with the default tokens). Content inherits the trigger line height; content that sets a larger font should set its own line height so the trigger grows to fit it. Inside an InputGroup the group owns the row height: a SelectorOption folds onto one line and ellipsizes, and any taller node is cut off at the row. |
| `indicatorPosition` | `'start' \| 'end'` | no | `'end'` | Which logical edge of the option row carries a rendered selection mark. An empty mark consumes no space, so selected and unselected labels may shift or have different available width. end is the house convention shared with Typeahead and CommandPalette. |
| `presentation` | `'popover' \| 'bottom-sheet' \| 'adaptive'` | no | `'popover'` | How the option list is presented. adaptive uses a bottom sheet on compact touch screens and an anchored popover otherwise. |
| `width` | `SizeValue` | no | `` | Width of the field (number = pixels, string used as-is, e.g. "100%"). Sizes the whole field (label, control, and status) so they stay aligned. Without a width the field follows its displayed value and can shrink with its row (the value truncates) instead of overflowing it; use `<HStack wrap="wrap">` for filter bars so selectors move to a second line on phones. |
| `startIcon` | `IconType \| ReactNode` | no | `` | Icon displayed at the start of the selector trigger. |
| `isLoading` | `boolean` | no | `false` | Shows a loading spinner in the trigger. |
| `onClick` | `(event: MouseEvent) => void` | no | `` | Click handler on the trigger button. Runs before the selector toggles its surface; preventDefault() does not keep it closed. |
| `onFocus` | `(event: FocusEvent) => void` | no | `` | Focus handler on the trigger button. Runs before the selector's own focus handling. |
| `onKeyDown` | `(event: KeyboardEvent) => void` | no | `` | Key handler on the trigger button. Runs after the built-in keyboard model and is skipped for keys it handles and cancels. |
| `containerXstyle` | `StyleXStyles` | no | `` | StyleX styles for the field container (label, control, and status together). No effect inside InputGroup (style the InputGroup instead) or in a `horizontal-labels` FormLayout. Root `xstyle`, `className`, and `style` are not accepted. |
| `containerClassName` | `string` | no | `` | Class name for the field container. Same targeting as `containerXstyle`. |
| `containerStyle` | `CSSProperties` | no | `` | Inline styles for the field container. Same targeting as `containerXstyle`. |
| `controlXstyle` | `StyleXStyles` | no | `` | StyleX styles for the visual control box: the element that paints the border and background and holds the value, icons, and end controls. Never the trigger button itself. |
| `controlClassName` | `string` | no | `` | Class name for the visual control box. |
| `controlStyle` | `CSSProperties` | no | `` | Inline styles for the visual control box. |

## Anatomy

- `Field` (optional) — Standalone Field shell that provides the label and optional supporting content; omitted inside InputGroup.
- `Trigger` (required) — Painted control that displays the current selection or placeholder and opens the selection surface when editable.
- `Icon-rendered start icon` (optional) — Optional leading semantic icon or icon component rendered through Icon.
- `Caller-rendered start content` (optional) — Optional arbitrary React content rendered directly at the start of the trigger.
- `Trigger clear button` (optional) — Shared clear action that removes the selected value when hasClear is enabled.
- `Status icon` (optional) — Status glyph shown in place of the disclosure indicator for attached or tooltip status.
- `Indicator icon` (optional) — Trailing chevron shown when status presentation does not replace it; reflects collapsed or expanded state.
- `Search row` (optional) — Panel header with a borderless search input and optional clear action.
- `Search icon` (optional) — Leading magnifier rendered through Icon inside the search row.
- `Search clear button` (optional) — Shared clear action shown in the search row while a query is present.
- `Option row` (optional) — Selectable row for one supplied option.
- `SelectorOption-rendered content` (optional) — Option content rendered with SelectorOption, either by the default renderer or by renderOption when it returns SelectorOption.
- `Bare caller-rendered option content` (optional) — Arbitrary content returned directly by renderOption without opting into SelectorOption.
- `Option selection indicator` (optional) — Resolved selection mark rendered for each option in its checked or unchecked state. Its layout space collapses when the resolved indicator draws nothing.
- `Option divider` (optional) — Divider supplied in the public options data to separate adjacent option groups.
- `Section heading` (optional) — Visible heading for a labeled group of option rows.
- `Empty state` (optional) — Message shown when the shared panel content has no options or no search matches.
- `Pointer popup` (optional) — Anchored painted surface that hosts the shared panel content for popover presentation.
- `Touch sheet heading` (optional) — Heading above the shared panel content in bottom-sheet presentation.
- `Touch sheet` (optional) — BottomSheet surface that hosts the same panel content for bottom-sheet presentation.

## Retrieval keywords

`selector`, `select`, `dropdown`, `combobox`, `picker`, `listbox`, `chooser`, `autocomplete`, `option`, `selectmenu`

---

Generated from `astryx/packages/core/src/Selector/Selector.doc.mjs` (MIT, https://github.com/facebook/astryx). Spec: yes · upstream tests: yes.

<!-- port-status:begin (generated by tools/gen-port-status.py) -->
## OCaml port

**Status:** ported in M73 — [`src/selector.ml`](../src/selector.ml)

**Module:** `Astryx.selector` (open `Astryx`)

```ocaml
val view
  :  ?attrs:Vdom.Attr.t list
  -> ?id:string
  -> ?is_label_hidden:bool
  -> ?description:string
  -> ?is_optional:bool
  -> ?is_required:bool
  -> ?is_disabled:bool
  -> ?is_read_only:bool
  -> ?disabled_message:string
  -> ?is_loading:bool
  -> ?status:status
  -> ?status_variant:Field_status.placement
  -> ?size:size
  -> ?variant:variant
  -> ?placeholder:string
  -> ?start_icon:string
  -> ?width:Common.Size_value.t
  -> ?html_name:string
  -> ?has_clear:bool
  -> ?has_search:bool
  -> ?search_placeholder:string
  -> ?empty_text:string
  -> ?empty_search_text:string
  -> ?indicator_position:indicator_position
  -> ?is_default_open:bool
  -> ?render_option:(option_data -> Vdom.Node.t)
  -> ?render_value:(option_data -> Vdom.Node.t)
  -> label:string
  -> options:row list
  -> value:string option Bonsai.t
  -> on_change:(string option -> unit Effect.t) Bonsai.t
  -> Bonsai.graph
  -> Vdom.Node.t Bonsai.t
```

Call it with the same prop names and defaults the upstream contract above documents; `Divergence` comments in the source record the few places the port deliberately differs (class names, and inline styles for per-instance numeric props).

<!-- port-status:end -->
