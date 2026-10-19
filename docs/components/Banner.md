# Banner

**Category:** Feedback & Status  |  **Group:** -  |  **Port status:** not started

Banner shows a persistent message at the top of a page or section. Use it
for form errors, system updates, maintenance notices, or success
confirmations that the user needs to see until they act on it.

## When to reach for it / when not to

- **Do:** Pick a status that matches the message: info for updates, warning for
  caution, error for problems, success for confirmations.
- **Do:** Use the card container inside page content and the section container for
  full-width messages that span the entire page.
- **Do:** Make info and success banners dismissable. Keep error banners visible
  until the user fixes the issue.
- **Do:** Keep titles short and scannable: "Payment failed" not "There was a
  problem processing your most recent payment."
- **Don't:** Use Banner for short-lived messages that disappear on their own; use
  Toast instead.
- **Don't:** Stack multiple banners with the same status; combine related messages
  into one banner.
- **Do:** Set collapsible={false} when the user needs the content to act on the
  message, like the list of fields that failed validation. Keep the
  default toggle when the detail is long enough to bury the banner's own
  message.
- **Do:** Banner status controls color and icon only; it does not create a live
  region. Announce async outcomes from the transition handler with
  useAnnounce. Add an explicit role="status" only when the visible banner
  is intended as a persistent semantic mirror; reserve role="alert" for
  genuinely urgent, interruptive content.
- **Don't:** Rely on the status color or icon alone to carry meaning; say which
  status it is in the title text, because the icon is decorative to a
  screen reader.

## Props

| prop | type | required | default | meaning |
| --- | --- | --- | --- | --- |
| `status` | `'info' \| 'warning' \| 'error' \| 'success'` | yes | `` | Status type controlling icon and color. |
| `title` | `ReactNode` | yes | `` | Title text or ReactNode displayed in the header. |
| `description` | `ReactNode` | no | `` | Description text rendered below the title in the header. |
| `icon` | `ReactNode` | no | `` | Override the default status icon. |
| `isDismissable` | `boolean` | no | `false` | Whether the banner can be dismissed by the user. |
| `onDismiss` | `() => void` | no | `` | Called when the dismiss button is clicked; banner hides itself regardless of whether this is provided. |
| `dismissLabel` | `string` | no | `` | Accessible name and visible tooltip for the dismiss button (pass it already translated). Defaults to "Dismiss <title>" for a string title, so stacked banners are distinguishable; set it when the title is a ReactNode. |
| `endContent` | `ReactNode` | no | `` | Action content rendered in the header area, end-aligned. Wraps to its own row below the text when the header is too narrow to hold both. |
| `container` | `'card' \| 'section'` | no | `'card'` | Container type: card has border-radius; section is full-width with no border-radius for page-level use. |
| `elevation` | `'none' \| 'low' \| 'med' \| 'high'` | no | `'none'` | Resting shadow depth. Use for a floating banner that hovers above content; `none` is the default inline banner. A `card`-container banner rounds its shadow to match. |
| `children` | `ReactNode` | no | `` | Content rendered in the card-background area below the colored header. Sits behind an expand/collapse toggle unless `collapsible={false}`. |
| `collapsible` | `boolean \| {defaultIsOpen?: boolean; isOpen?: boolean; onOpenChange?: (isOpen: boolean) => void}` | no | `true` | Whether the content area (children) sits behind an expand/collapse toggle in the header. On by default, starting collapsed. `false` opts out: children are always visible with no toggle. `{defaultIsOpen: true}` starts open; `{isOpen, onOpenChange}` is controlled. Takes the same CollapsibleConfig as Collapsible. |
| `xstyle` | `StyleXStyles` | no | `` | StyleX styles for layout customization (margins, positioning, sizing). Must be a stylex.create() value, not an inline style object like style={{}}. |

## Anatomy

- `Banner frame` (required) — Outer frame that groups the status surface and optional content surface. It carries whole-banner elevation and, for elevated card banners, the radius that shapes that silhouette.
- `Status surface` (required) — The primary painted surface. It communicates status and contains the icon, title, description, actions, and controls.
- `Icon` (required) — Automatically set based on the status (info, warning, error, success).
- `Title` (required) — The main message. Always required.
- `Description` (optional) — Additional detail below the title.
- `Action button` (optional) — A button for the user to act on the message, like "Review" or "Retry".
- `Dismiss button` (optional) — Lets the user close the banner. Enabled by setting isDismissable.
- `Content surface` (optional) — Secondary surface for extra detail below the status surface, like a list of errors. Sits behind an expand/collapse toggle by default; set collapsible={false} to keep it visible.

## Retrieval keywords

`banner`, `alert`, `notification`, `callout`, `notice`, `status`, `message`, `info`, `warning`, `error`, `success`, `toast`

---

Generated from `astryx/packages/core/src/Banner/Banner.doc.mjs` (MIT, https://github.com/facebook/astryx). Spec: yes · upstream tests: no.

<!-- port-status:begin (generated by tools/gen-port-status.py) -->
## OCaml port

**Status:** ported in M49 — [`src/banner.ml`](../src/banner.ml)

**Module:** `Astryx.Banner` (open `Astryx`)

```ocaml
val view
  :  ?attrs:Vdom.Attr.t list
  -> ?id:string
  -> ?description:Vdom.Node.t list
  -> ?icon:Vdom.Node.t
```

Call it with the same prop names and defaults the upstream contract above documents; `Divergence` comments in the source record the few places the port deliberately differs (class names, and inline styles for per-instance numeric props).

<!-- port-status:end -->
