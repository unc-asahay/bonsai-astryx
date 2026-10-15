# BottomSheet

**Category:** Overlay  |  **Group:** BottomSheet  |  **Port status:** not started

A mobile touch surface for filters, actions, forms, and detail views that
should rise from the bottom of the viewport; use BottomSheetSwitcher for
multi-step flows.

## When to reach for it / when not to

- **Do:** Use for mobile-first surfaces (filters, share sheets, quick actions)
  where the content should rise from the bottom edge.
- **Do:** Pick the starting height that fits the content: 'hug' for short bounded
  content, 'capped' for lists, and 'tall' for forms or streaming/resizing
  content.
- **Do:** Use purpose='form' to protect entered data from scrim clicks and swipes
  while keeping Escape available; reserve purpose='required' for flows
  that must end through an explicit action.
- **Don't:** Don't make the sheet content overly long. Consider breaking it into
  steps and using Bottom Sheet Switcher.

## Props

| prop | type | required | default | meaning |
| --- | --- | --- | --- | --- |
| `isOpen` | `boolean` | no | `` | Whether a standalone sheet is open. Fully controlled; pair with onOpenChange. Omit inside BottomSheetSwitcher. |
| `onOpenChange` | `(isOpen: boolean) => void` | no | `` | For a standalone sheet, called when it requests an open-state change. Automatic calls follow purpose: info dismisses on Escape, scrim click, or swipe; form dismisses on Escape only; required never dismisses implicitly. Omit inside BottomSheetSwitcher. |
| `finalFocusRef` | `RefObject<HTMLElement \| null>` | no | `` | Optional explicit focus-return target for a standalone sheet. Use when the opener can remount or the active element is not a reliable trigger, such as an adaptive presentation switch. Omit inside BottomSheetSwitcher. |
| `purpose` | `'required' \| 'form' \| 'info'` | no | `'info'` | Controls implicit dismissal behavior, matching Dialog. info allows Escape, scrim click, and swipe-to-dismiss. form protects entered data by blocking scrim click and swipe while allowing Escape. required blocks every implicit dismissal path and uses role='alertdialog'. Explicit controls may still update the controlled state. Works for standalone and BottomSheetSwitcher-managed sheets. |
| `sheetId` | `string` | no | `` | Unique ID for this sheet inside BottomSheetSwitcher. The switcher opens it when activeSheet matches. Omit isOpen and onOpenChange when sheetId is used. |
| `label` | `string` | yes | `` | Accessible label for the sheet. Required; the sheet has no built-in heading to derive a name from. |
| `children` | `ReactNode` | yes | `` | Sheet content in a scrollable area. The named body is keyboard reachable while overflowing. Forward Tab entry may move directly to the first native link or button; input controls, composite widgets, and nested scroll areas retain the body stop. Shift+Tab from a delegated first child skips the body. Fitting content adds no body stop. The internal observed content box preserves block flow and percentage heights. If it includes a text-entry control that can bring up the mobile keyboard, use height='tall' and keep the sheet fully expanded while editing. |
| `padding` | `0 \| 0.5 \| 1 \| 1.5 \| 2 \| 3 \| 4 \| 5 \| 6 \| 8 \| 10` | no | `` | Internal padding of the sheet content using the spacing scale, matching Dialog. When omitted, uses the theme default for bottom sheets (--spacing-4 unless the theme sets padding on bottom-sheet). A lone Section child escapes the padding, and bleed children such as Table and Divider compensate against it. Use 0 for edge-to-edge content that supplies its own inset. |
| `height` | `'hug' \| 'capped' \| 'tall' \| number \| string` | no | `'capped'` | How tall the sheet is. Named budgets: 'hug' fits its content up to 92% of the viewport, 'capped' is a scrolling mid-height panel (~62%), and 'tall' is a pinned near-full panel (~92%) for content that streams in. Or pass a number (px) / CSS length for a custom budget. Give snapPoints to let the user drag between heights. On shorter viewports the sheet fills the available height. Only a fully expanded 'tall' sheet provides mobile-keyboard accommodation: it stays put and scrolls each focused control above the keyboard. Hug, Capped, numeric and CSS-length heights never do, and a Tall sheet stops doing it the moment the user drags it to a shorter detent, resuming when they drag it back. Outside that state the sheet neither moves nor adds keyboard scroll space, and the browser's own focus reveal is left in place; on iOS that reveal can shift the whole page. |
| `snapPoints` | `ReadonlyArray<number \| string>` | no | `` | Extra heights the sheet can rest at when dragged; its own height is always the tallest stop, and omitting this gives a sheet that only opens and closes. Each stop is the sheet's visible height: a number is a viewport fraction (0.5 is half the screen), '50%' the same in CSS, '320px' an absolute length. A stop of a quarter of the sheet or less is a peek: it slides away instead of reflowing, and thins the scrim. |
| `hasScrim` | `boolean` | no | `true` | For a standalone BottomSheet, whether to render a scrim, the semi-transparent overlay that covers and blocks the background. true (default) uses showModal(): top layer, focus trap, ::backdrop scrim, body scroll lock, and tap-scrim-to-dismiss when purpose='info', with the background inert. false uses show() with no scrim, leaving the page behind interactive and scrollable. For a multi-step flow, configure hasScrim on BottomSheetSwitcher instead; it owns one shared dialog across every child. |

## Anatomy

- `Sheet panel` (required) — Painted surface that rises from the bottom edge and contains the sheet.
- `Content area` (required) — Padded, scrollable container that presents the caller-provided sheet content.
- `Handle` (required) — Decorative grab affordance and drag region at the top of the panel.
- `Scrim` (optional) — Backdrop that dims and blocks the page in a scrim-backed presentation.

## Retrieval keywords

`bottom sheet`, `sheet`, `mobile`, `touch`, `drag`, `swipe`, `snap point`, `detent`, `resize`, `dismiss`, `grab handle`, `dialog`, `overlay`, `modal`, `form`, `mobile keyboard`, `visual viewport`

---

Generated from `astryx/packages/core/src/BottomSheet/BottomSheet.doc.mjs` (MIT, https://github.com/facebook/astryx). Spec: yes · upstream tests: yes.

<!-- port-status:begin (generated by tools/gen-port-status.py) -->
## OCaml port

**Status:** not ported yet. The upstream contract above is the specification; see `docs/PORT-STATUS.md` for the milestone it is planned in.

<!-- port-status:end -->
