# Avatar

**Category:** Content  |  **Group:** Avatar  |  **Port status:** not started

Avatar represents a person or team with a profile photo, initials, or a
default icon. Use it in comment headers, contact lists, chat messages, user
cards, and anywhere you need to identify someone visually.

## When to reach for it / when not to

- **Do:** Always pass a name so the avatar can show initials if the photo fails to
  load, and so screen readers can announce who it represents.
- **Do:** Pick a size that matches the context: xsm or sm for inline mentions, md
  or lg for lists and cards, xl for profile headers.
- **Do:** Add a status dot when knowing someone's availability matters, like in
  chat or team views.
- **Do:** When wrapping an Avatar in your own Tooltip or HoverCard, set
  tooltip={false} so the built-in name tooltip does not overlap yours.
- **Do:** Give every interactive avatar (href or onClick) a name or alt. It is the
  control's accessible name, and it warns in development when it is
  missing.
- **Don't:** Rely on a status label to name an interactive avatar. "Online" says
  nothing about where the link goes.
- **Don't:** Use Avatar for logos, product images, or anything that isn't a person or
  team. Use an image or icon instead.
- **Don't:** Use xstyle or className to override shape. Use the shape prop instead so
  themes can control it globally.

## Props

| prop | type | required | default | meaning |
| --- | --- | --- | --- | --- |
| `src` | `string` | no | `` | Primary image source URL. |
| `fallbackSrc` | `string` | no | `` | Fallback image when primary fails. |
| `name` | `string` | no | `` | User name for initials and alt text. |
| `alt` | `string` | no | `` | Alt text (falls back to name). |
| `size` | `'xsm' \| 'sm' \| 'md' \| 'lg' \| 'xl' \| number` | no | `'md'` | Avatar size. Use a named size ('xsm' 20px, 'sm' 24px, 'md' 36px, 'lg' 48px, 'xl' 128px) or a numeric pixel value. Avatar shares Icon's abbreviated scale, but its tiers are larger because avatars align with media rather than glyphs. Inside an AvatarGroup the group's size wins and this prop is ignored. |
| `shape` | `'circle' \| 'rounded' \| 'square'` | no | `'circle'` | Shape variant of the avatar. 'circle' (default) stays fully round. 'rounded' uses the element radius token so it matches UI corner rounding and can be set globally via theme. 'square' has no radius. Status dot positioning adapts automatically: 4-o'clock on circle, bottom-right corner on rounded/square. |
| `status` | `ReactNode` | no | `` | Corner content for status indicators. AvatarStatusDot reports its `label` to the avatar, which composes it into the accessible name (e.g. "Jane Doe, Online") so screen readers announce the status. Reporting goes through context, so it still works when the dot sits inside a wrapper component of your own. |
| `tooltip` | `string \| boolean` | no | `true` | Tooltip shown on hover and keyboard focus. Omitted or true shows the avatar's name; a string shows that text instead; false shows no tooltip. Not auto-disabled when wrapped in your own Tooltip/HoverCard. Set tooltip={false} if you supply your own overlay. No tooltip is shown when tooltip is true/omitted and there is no name. |
| `href` | `string` | no | `` | When set, the avatar renders as an interactive link (`<a>` or a custom link component) pointing here. This follows the same element-swap rule as Button. Requires a meaningful accessible name via `alt` or `name`: an interactive avatar without one warns in development. Inside an AvatarGroup, interactive avatars share a single Tab stop and are reached with arrow keys. |
| `as` | `ElementType` | no | `` | Custom link component used when `href` is set (e.g. `next/link`). Overrides the provider-level LinkProvider default. Only applies with `href`. |
| `target` | `string` | no | `` | Link target attribute. Only applies with `href`. |
| `rel` | `string` | no | `` | Link rel attribute. Only applies with `href`. |
| `onClick` | `(e: MouseEvent) => void` | no | `` | Click handler. When set without `href`, the avatar renders as a focusable `<button type="button">`. Requires a meaningful accessible name via `alt` or `name`: an interactive avatar without one warns in development. |

## Anatomy

- `Photo` (optional) — The profile image, loaded from the src URL. Shown when available.
- `Initials` (optional) — The first letter, digit or emoji of the first and last words of the name; punctuation is skipped. Shown when no photo is available. A name with no letters, digits or emoji shows the default icon instead.
- `Default icon` (optional) — A generic person silhouette. Shown when there is no photo or name.
- `Status dot` (optional) — A small indicator in the bottom-right corner showing availability (online, away, busy). Each variant pairs colour with a distinct shape so status does not rely on colour alone.

## Retrieval keywords

`avatar`, `profile`, `user`, `photo`, `thumbnail`, `initials`, `gravatar`, `pfp`, `userpic`

---

Generated from `astryx/packages/core/src/Avatar/Avatar.doc.mjs` (MIT, https://github.com/facebook/astryx). Spec: no · upstream tests: no.
