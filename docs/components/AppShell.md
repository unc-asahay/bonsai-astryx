# AppShell

**Category:** Layout  |  **Group:** AppShell  |  **Port status:** not started

AppShell is the page shell for an application. It provides slots for top
navigation, side navigation, banners, and main content. Use it as the root
wrapper for every page. It handles responsive mobile navigation and
skip-to-content automatically. Configure side nav collapse on SideNav with
its collapsible prop.

## When to reach for it / when not to

- **Do:** Choose the right height: use "fill" for dashboards with internal
  scrolling and "auto" for pages that grow with content.
- **Do:** Set `contentPadding` based on content type: 4 for forms and settings, 0
  for tables and dashboards.
- **Do:** Give every nav slot an accessible name. AppShell renders TopNav and
  SideNav as separate navigation landmarks, and a screen reader lists them
  by name, so pass `label` to each one.
- **Do:** Start the page heading inside `children`. AppShell owns the skip link,
  the banner landmark and the main landmark, but it renders no heading, so
  the first heading in the content area is the page h1.
- **Don't:** Nest one AppShell inside another; it's the outermost layout frame.
- **Don't:** Use for sub-page layouts; use Layout for content areas within AppShell.
- **Don't:** Add your own skip link or <main> element. AppShell already renders both,
  and a second main landmark makes the first ambiguous.

## Props

| prop | type | required | default | meaning |
| --- | --- | --- | --- | --- |
| `children` | `ReactNode` | no | `` | Main content area, rendered inside a <main> element. |
| `contentPadding` | `0 \| 0.5 \| 1 \| 1.5 \| 2 \| 3 \| 4 \| 5 \| 6 \| 8 \| 10` | no | `0` | Padding for the main content area. Set based on the dominant content pattern: 4 (16px) for forms/settings/text, 0 for dashboards/maps/tables. Override individual sections with Section. |
| `topNav` | `ReactNode` | no | `` | Top navigation slot, typically TopNav. |
| `sideNav` | `ReactNode` | no | `` | Side navigation slot, typically SideNav. |
| `mobileNav` | `ReactNode` | no | `` | Mobile navigation configuration. Accepts false (disable), a config object (tune auto behavior), or ReactNode (full custom drawer). The config object is {hasToggle?: boolean, isOpen?: boolean, onOpenChange?: (isOpen: boolean) => void, content?: ReactNode, breakpoint?: 'sm' \| 'md' \| 'lg' \| 'xl' \| '2xl' \| 'none', defaultIsMobile?: boolean}; breakpoint defaults to 'md', resolves through the nearest Theme's widthBreakpoints, and switches to the wider layout at equality. 'none' is always non-mobile and ignores defaultIsMobile. |
| `banner` | `ReactNode` | no | `` | Banner slot for system-wide announcements, placed above the topNav. |
| `height` | `'fill' \| 'auto'` | no | `'fill'` | Height behavior: 'fill' makes the shell fill the viewport (100dvh) with independent scroll containers; 'auto' lets the shell grow with content and uses sticky positioning for nav. |
| `variant` | `'wash' \| 'surface' \| 'section' \| 'elevated'` | no | `'elevated'` | Navigation background style controlling how nav areas contrast with content. 'wash' uses wash background, 'surface' uses surface background, 'section' adds dividers between nav and content, 'elevated' uses wash nav with elevated surface content and border radius. |
| `xstyle` | `StyleXStyles` | no | `` | StyleX styles for layout customization (margins, positioning, sizing). Must be a stylex.create() value, not an inline style object like style={{}}. |

## Anatomy

- `Page shell` (required) — Outermost application frame that owns page-level navigation, responsive shell behavior, and the main content landmark.
- `Skip link` (required) — First focusable element on the page. Visually hidden until focused, then moves focus to the main content area.
- `Banner` (optional) — The banner slot, for system-wide announcements. Renders above the top nav, inside the banner landmark.
- `Top navigation` (optional) — The topNav slot, typically TopNav. Below the mobile breakpoint it becomes a compact bar carrying the nav toggle.
- `Side navigation` (optional) — The sideNav slot, typically SideNav. Inline above the breakpoint, moved into the mobile drawer below it.
- `Main content` (required) — children, rendered in the main landmark. Scrolls internally when height is fill, and with the page when it is auto.
- `Mobile nav drawer` (optional) — Generated below the breakpoint from the nav slots unless mobileNav disables or replaces it. A modal dialog: it traps focus and returns focus to the toggle on close.

## Retrieval keywords

`appshell`, `layout`, `scaffold`, `sidebar`, `sidenav`, `topnav`, `header`, `navigation`, `dashboard`, `shell`, `page`, `frame`

---

Generated from `astryx/packages/core/src/AppShell/AppShell.doc.mjs` (MIT, https://github.com/facebook/astryx). Spec: no · upstream tests: no.
