# Indicator

**Category:** Form Controls  |  **Group:** Indicator  |  **Port status:** not started

Indicators are the componentized selection visuals shared by CheckboxInput,
RadioList, and menu selection rows. They are decorative: the owning
component keeps the input, role, accessible name, focus, and keyboard
behavior, while the indicator turns state into a picture. That split is what
makes them themeable: restyle one through its class targets, or replace the
component outright.

## When to reach for it / when not to

- **Do:** Reach for the canonical `components['checkbox-indicator']` override
  first. Replacing the component is the heavier path, for when the shape
  itself is wrong.
- **Do:** Match the shipped replacement-content branch with
  `isRenderable(children)`, not `children != null` or `children ?? mark`.
  The helper is deliberately shallow: it excludes nullish values,
  booleans, and the empty string, while React elements and containers take
  the replacement path even when their descendants render nothing. The
  owning control passes `children={isBusy && <Spinner/>}`, so a nullish
  check deletes the state mark whenever that value is `false` (#4893).
- **Do:** A replacement must set aria-hidden. The owning control provides the role
  and accessible name; a visible indicator would be announced twice.
- **Do:** Use theme tokens for every color, radius, and border width in a
  replacement. Run `npx @astryxdesign/cli docs tokens` for the set.
- **Do:** Render a single root ELEMENT, and let it keep the border-radius you want
  the focus ring to follow. A control whose real input is visually hidden
  cannot show focus on that input, so the owner paints the standard ring
  onto the indicator element itself at focus time (useIndicatorFocusRing),
  and `outline` then picks up that element's radius. A replacement needs
  no cooperation and can forget nothing: the ring is never missing (WCAG
  2.4.7), it is only the wrong shape if the root has no radius of its own.
  Do not draw a focus ring yourself; the owner already did.
- **Don't:** Thread hover or pressed state in as props. Interaction state reaches an
  indicator through the owner's CSS ancestor marker, so hovering the row
  tints the control with no props involved.
- **Don't:** Assume you are only mounted when selected. The host renders its
  indicator unconditionally and passes `state`, in every state; that is
  what lets a replacement draw where the default draws nothing (a radio's
  empty circle on an unchosen row). Drawing nothing in a state is a
  decision the indicator makes, not one the host makes for it.

## Props

| prop | type | required | default | meaning |
| --- | --- | --- | --- | --- |
| `state` | `IndicatorState<F>` | yes | `` | Which state to draw. The state space is fixed by the family. */ |
| `size` | `IndicatorSize` | no | `'md' /` | Control size. |
| `isDisabled` | `boolean` | no | `false /` | Whether the owning control is disabled. Purely visual — the owner still owns the actual disabled semantics. |
| `children` | `ReactNode` | no | `` | Content rendered inside the indicator chrome *instead of* the state mark. CheckboxInput uses this to show a loading Spinner inside the box while a change action is pending. / |

## Anatomy

- `Chrome (checkbox, radio)` (required) — The persistent box or circle rendered by CheckboxIndicator and RadioIndicator in every state. CheckIndicator is the state mark itself and intentionally owns no chrome.
- `State mark` (optional) — The checkmark, indeterminate bar, or radio dot shown inside the chrome for the current state.

## Retrieval keywords

`indicator`, `checkbox`, `radio`, `control`, `selection`, `mark`, `tick`, `themeable`, `swap`

---

Generated from `astryx/packages/core/src/Indicator/Indicator.doc.mjs` (MIT, https://github.com/facebook/astryx). Spec: no · upstream tests: no.
