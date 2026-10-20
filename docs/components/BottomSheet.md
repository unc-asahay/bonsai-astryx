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

**Status:** ported in M74 — [`src/bottom_sheet.ml`](../src/bottom_sheet.ml)

**Module:** `Astryx.bottom_sheet` (open `Astryx`)

```ocaml
val view
  :  ?id:string
  (** The id of the sheet's host element. Defaults to ["astryx-bottom-sheet"]. *)
  -> ?attrs:Vdom.Attr.t list
  (** Extra attributes for the host element. They are applied last, so a
      consumer can override anything above. *)
  -> label:string
  (** The accessible name of the sheet. Upstream requires it — the sheet has no
      built-in heading to derive one from — and so does this port. *)
  -> ?purpose:purpose
  (** How hard the sheet is to dismiss. Defaults to [Info]. *)
  -> ?height:height
  (** The sheet's height budget. Defaults to [Capped]. *)
  -> ?snap_points:snap_point list
  (** The extra heights the sheet can rest at when it is dragged. Defaults to
      none, which gives a sheet that only opens and closes. *)
  -> ?has_scrim:bool
  (** Whether the sheet has a scrim. With one (the default) the sheet is
      modal: the page behind is inert and a click on the scrim dismisses it
      when the [purpose] allows. Without one the sheet is shown non-modally
      and the page behind stays live. *)
  -> ?padding:Common.Spacing.t
  (** The inset of the sheet's content box, on the spacing scale. Upstream's
      default — the theme's [bottom-sheet] padding, or [var(--spacing-4)] —
      is what this port uses when no padding is given. *)
  -> ?final_focus_id:string
  (** The id of the element that receives focus when the sheet closes. Without
      one, the focus goes back to whatever was focused when the sheet opened,
      which is what upstream does with its trigger. *)
  -> ?is_inline:bool
  (** Render the sheet as ordinary markup: no top layer, no modal behaviour, no
      scrim, and the panel visible where it is written. This is the showcase
      path — a page can show several sheets at once, and a gate without a
      browser can still read the structure. *)
  -> is_open:bool Bonsai.t
  (** Whether the sheet is open. The sheet never opens or closes itself: it
      follows this value, and reports every dismissal through
      [on_open_change]. *)
  -> on_open_change:(bool -> unit Effect.t) Bonsai.t
  (** Called when the sheet should close — Escape (unless the [purpose] is
      [Required]), a click on the scrim (only for [Info]), a swipe past the
      dismiss threshold (only for [Info]), or anything the caller's own content
      does. The caller owns the value, so the sheet closes when [is_open]
      becomes false and not before. *)
  -> children:Vdom.Node.t list Bonsai.t
  (** The sheet's content, in the sheet's scrolling content area. *)
  -> Bonsai.graph
  (** The graph the sheet's own state lives in: the drag it is in and the
      detent it rests at. *)
  -> Vdom.Node.t Bonsai.t
```

Call it with the same prop names and defaults the upstream contract above documents; `Divergence` comments in the source record the few places the port deliberately differs (class names, and inline styles for per-instance numeric props).

<!-- port-status:end -->
