# Button

**Category:** Action  |  **Group:** Button  |  **Port status:** not started

Button triggers an action when clicked. Use it for form submissions,
confirmations, navigation, or any interaction that needs a clear call to
action.

## When to reach for it / when not to

- **Do:** Reserve primary for the single most important action in the view. Use
  secondary or ghost for everything else based on emphasis.
- **Do:** Write labels that describe the action ("Save changes", "Delete account",
  "Send invite"), not vague labels like "OK" or "Click here".
- **Do:** Show a loading state for actions that take time, like saving or
  submitting, so the user knows it is working.
- **Do:** Always provide a label for icon-only buttons so screen readers can
  announce what the button does. Add a tooltip for sighted users.
- **Do:** For a dedicated icon-only button, use IconButton from
  '@astryxdesign/core/IconButton'. It is a separate component, not
  exported from '@astryxdesign/core/Button'.
- **Don't:** Place more than one primary button in the same view; this dilutes the
  visual hierarchy.
- **Don't:** Use the destructive variant without a confirmation step for irreversible
  actions like deleting data.
- **Don't:** Use a button for navigation. If it only takes the user to another page,
  use a link instead. Buttons are for actions like saving, deleting, or
  submitting.

## Props

| prop | type | required | default | meaning |
| --- | --- | --- | --- | --- |
| `label` | `string` | yes | `` | Accessible label. Rendered as visible text by default; used as aria-label when isIconOnly is true. |
| `variant` | `'primary' \| 'secondary' \| 'ghost' \| 'destructive'` | no | `'secondary'` | Visual style variant. |
| `size` | `'sm' \| 'md' \| 'lg'` | no | `'md'` | Size variant. |
| `elevation` | `'none' \| 'low' \| 'med' \| 'high'` | no | `'none'` | Resting shadow depth for floating buttons (e.g. a FAB). `none` is the default flat button; `low`/`med`/`high` map to the shadow token scale. Ignored inside a ButtonGroup, where elevation is owned by the group. |
| `type` | `'button' \| 'submit' \| 'reset'` | no | `'button'` | HTML button type attribute. |
| `name` | `string` | no | `` | HTML name attribute for form submission. |
| `value` | `string \| number \| readonly string[]` | no | `` | HTML value attribute for form submission. |
| `form` | `string` | no | `` | Associates the button with a form element by ID. |
| `isLoading` | `boolean` | no | `false` | Shows a loading spinner and blocks re-activation while staying focusable (aria-busy + aria-disabled, not native disabled, so keyboard focus is never dropped mid-action). Announces "Loading" via a live region. |
| `isInterruptible` | `boolean` | no | `false` | Keep the button clickable while a clickAction is pending: the spinner and aria-busy still show, but the button is not disabled and the action is not deduped, so a re-click lands and interrupts the in-flight action with a fresh one. |
| `isDisabled` | `boolean` | no | `false` | Disables the button. When a tooltip is present, uses aria-disabled instead of native disabled so the button stays focusable. |
| `icon` | `ReactNode` | no | `` | Icon element rendered before the label text. An Astryx Icon with no explicit size defaults to sm for sm/md buttons and md for lg buttons. |
| `isIconOnly` | `boolean` | no | `false` | When true, renders as a square icon-only button with label as aria-label. Requires icon. Tip: for a dedicated icon-only button component, use IconButton from '@astryxdesign/core/IconButton' instead. |
| `width` | `SizeValue` | no | `` | Width of the button. Numbers are treated as pixels, strings are used as-is (e.g., '100%' for a full-width button). By default the button sizes to its content, never grows past its container, and truncates its label with an ellipsis when a row is too narrow; icon-only buttons stay square. |
| `children` | `ReactNode` | no | `` | Optional override for visible text. When provided, displayed instead of label, but label is still required (it provides the accessible name). For most cases, just use label alone: <Button label="Save" />. |
| `endContent` | `ReactElement<IconProps> \| ReactElement<BadgeProps>` | no | `` | Trailing icon or badge rendered after the label. Ignored when isIconOnly is true. Color is inherited from the button variant. |
| `tooltip` | `string` | no | `` | Tooltip text shown on hover. |
| `onClick` | `(e: MouseEvent) => void` | no | `` | Standard click handler (passed through from ButtonHTMLAttributes). |
| `clickAction` | `(e: MouseEvent) => void \| Promise<void>` | no | `` | Async click handler. Shows loading state while the returned promise is pending. |
| `href` | `string` | no | `` | When provided, renders the button as a link element (<a> or custom link component). The destination follows the shared navigation rule described on the Link `href` prop. |
| `as` | `ComponentType` | no | `` | Custom link component to use when href is provided (e.g. Next.js Link). |
| `target` | `string` | no | `` | HTML target attribute when rendered as a link (e.g. "_blank"). |
| `rel` | `string` | no | `` | HTML rel attribute when rendered as a link (e.g. "noopener noreferrer"). |

## Anatomy

- `Icon` (optional) — A leading icon that reinforces the label, like a trash icon on a Delete button.
- `Label` (required) — The visible text describing the action. Also used as the accessible name.
- `End content` (optional) — A trailing badge or icon after the label, like a notification count or dropdown arrow.
- `Spinner` (optional) — Replaces the icon during loading to show the action is in progress.

## Accessibility contract

- **Text label** — 1.4.3 Contrast (Minimum), needs 4.5:1 in Rest, Hover, Pointer down. Button text must have at least 4.5:1 contrast with the button background in every state. For Hover and Pointer down, measure the final background after the overlay is applied.
- **Essential icon or spinner arc** — 1.4.11 Non-text Contrast, needs 3:1 in Icon only, Loading. An icon used instead of text must have at least 3:1 contrast with the button background. The moving spinner arc must also meet 3:1. An icon beside a visible label does not need its own check.
- **Badge text** — 1.4.3 Contrast (Minimum), needs 4.5:1 in Rest, Hover, Pointer down. Badge text inside a button must have at least 4.5:1 contrast with the Badge background. Check all 14 built-in Badge colors in Rest, Hover, and Pointer down on page and surface backgrounds. This covers 336 pairs per mode. Check custom end content separately.
- **Visible control boundary** — 1.4.11 Non-text Contrast, needs 3:1 if needed in Rest. The button edge needs 3:1 contrast only when users need it to see the control. A text-only button can rely on its label.
- **Keyboard focus indicator** — 1.4.11 Non-text Contrast, needs 3:1 in Focus visible. The focus outline needs at least 3:1 contrast with the area around the button. Check every style. Destructive buttons use a red outline.
- **Disabled appearance** — 1.4.3 and 1.4.11 exceptions, needs Not required in Disabled. Disabled controls do not need to meet these contrast ratios.

## Retrieval keywords

`button`, `btn`, `cta`, `submit`, `action`, `loading`, `primary`, `secondary`, `ghost`, `destructive`, `danger`

---

Generated from `astryx/packages/core/src/Button/Button.doc.mjs` (MIT, https://github.com/facebook/astryx). Spec: no · upstream tests: yes.

<!-- port-status:begin (generated by tools/gen-port-status.py) -->
## OCaml port

**Status:** ported in M1 — [`src/button.ml`](../src/button.ml)

**Module:** `Astryx.Button` (open `Astryx`)

```ocaml
val view
  :  label:string
  -> ?variant:variant
  -> ?size:size
  -> ?elevation:elevation
  -> ?type_:type_
  -> ?is_loading:bool
  -> ?is_disabled:bool
  -> ?is_icon_only:bool
  -> ?icon:Vdom.Node.t
```

Call it with the same prop names and defaults the upstream contract above documents; `Divergence` comments in the source record the few places the port deliberately differs (class names, and inline styles for per-instance numeric props).

<!-- port-status:end -->
