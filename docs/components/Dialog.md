# Dialog

**Category:** Overlay  |  **Group:** Dialog  |  **Port status:** not started

Dialog displays a modal overlay that blocks interaction with the page until
the user responds. Use it for delete confirmations, edit forms, terms
acceptance, or any decision that should not be skipped. For cases where you
want to show a dialog without managing open state, use the
`useImperativeDialog` hook: call `dialog.show(content)` and render
`dialog.element` in your tree.

## When to reach for it / when not to

- **Do:** Choose the right purpose: info for dismissable content, form to prevent
  accidental backdrop dismissal, required when the user must respond.
- **Do:** Include a clear title in the header so users immediately understand what
  the dialog is asking.
- **Do:** Use purpose="form" for dialogs with inputs so the user can't
  accidentally lose data by clicking the backdrop.
- **Do:** Keep dialogs focused on a single task; if the content grows beyond what
  fits, consider a full page instead.
- **Don't:** Use a dialog for simple messages that could be shown inline or as a
  toast notification.
- **Don't:** Nest dialogs inside other dialogs; restructure the flow into steps
  within a single dialog instead.
- **Don't:** Use the fullscreen variant for simple confirmations; it is meant for
  complex content like editors or long forms.

## Props

| prop | type | required | default | meaning |
| --- | --- | --- | --- | --- |
| `isOpen` | `boolean` | yes | `` | Whether the dialog is open. |
| `onOpenChange` | `(isOpen: boolean) => unknown` | yes | `` | Callback when dialog visibility changes. |
| `children` | `ReactNode` | yes | `` | Dialog content. |
| `width` | `number \| string` | no | `400` | Preferred width of the dialog in pixels or any CSS value. Standard dialogs clamp to their container and the dynamic viewport with spacing-token gutters so narrow viewports keep content on screen. |
| `maxHeight` | `number \| string` | no | `'75dvh'` | Maximum height of the dialog. Defaults to a dynamic viewport value so browser UI changes are reflected where supported. |
| `position` | `DialogPosition` | no | `` | Static position for the dialog; centered by default when omitted. Use logical `start`/`end` for inline offsets so positioned dialogs mirror correctly under RTL. |
| `variant` | `'standard' \| 'fullscreen'` | no | `'standard'` | Dialog variant: fullscreen expands to fill the entire viewport. |
| `purpose` | `'required' \| 'form' \| 'info'` | no | `'info'` | Controls dismissal behavior: required disables Escape and backdrop click; form disables backdrop click after interaction; info allows both. |
| `padding` | `0 \| 0.5 \| 1 \| 1.5 \| 2 \| 3 \| 4 \| 5 \| 6 \| 8 \| 10` | no | `` | Internal padding of the dialog using the spacing scale step. |
| `isInline` | `boolean` | no | `false` | Renders dialog content inline without the <dialog> element, backdrop, or modal behavior. For documentation previews and showcases only. |

## Anatomy

- `Header` (required) — Title, optional subtitle, and close button. The title receives focus on open and labels the dialog via aria-labelledby.
- `Body` (required) — The main content area: text, forms, lists, or any layout.
- `Footer` (optional) — Action buttons like Save/Cancel or Accept/Decline, aligned to the end.
- `Backdrop` (required) — Semi-transparent overlay behind the dialog that blocks page interaction.

## Retrieval keywords

`dialog`, `modal`, `popup`, `overlay`, `lightbox`, `alert`, `confirm`, `prompt`, `backdrop`, `focus trap`, `imperative`

---

Generated from `astryx/packages/core/src/Dialog/Dialog.doc.mjs` (MIT, https://github.com/facebook/astryx). Spec: yes · upstream tests: yes.
