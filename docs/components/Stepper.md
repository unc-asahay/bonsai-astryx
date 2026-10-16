# Stepper

**Category:** Navigation  |  **Group:** Stepper  |  **Port status:** not started

Steppers display progress through a sequence of logical and numbered steps.
Use them for multi-step workflows like forms, onboarding flows, or checkout
processes where users need to see their position and the steps ahead.
Rendered as an ordered list (not a navigation landmark).

## When to reach for it / when not to

- **Do:** Keep step labels short and descriptive: "Payment" not "Enter your
  payment information".
- **Do:** Use the vertical orientation when steps carry longer descriptions. A
  horizontal stepper handles narrow containers itself: once the frame
  gives each step less than horizontalOptions.minimumStepWidth (112px by
  default) it drops the labels for a segmented track and uses the
  configured collapsedVariant beneath it.
- **Do:** Set horizontalOptions.collapsedVariant to 'withLabel' when the page
  already supplies Back/Continue, or to 'hiddenLabel' when surrounding UI
  owns both the current-step heading and navigation and only a bare
  progress track is needed.
- **Do:** Provide onStepClick for non-linear workflows where users may need to
  revisit earlier steps.
- **Do:** Use status only to apply a semantic color
  (accent/success/warning/error); pass a custom icon for richer
  indicators.
- **Don't:** Use a stepper for fewer than 3 steps; a simple heading or progress bar
  works better.
- **Don't:** Use more than 7 steps; consider grouping related steps or using a
  different pattern.

## Props

| prop | type | required | default | meaning |
| --- | --- | --- | --- | --- |
| `activeStep` | `number` | yes | `` | Zero-based index of the active step. / |
| `children` | `ReactNode` | yes | `` | Step elements to render. / |
| `orientation` | `StepperOrientation` | no | `'horizontal' /` | Layout direction of the stepper. |
| `onStepClick` | `(index: number) => void` | no | `` | Called when a step is clicked, or when a compact summary control is used. Enables non-linear navigation. At compact horizontal widths, individual track nodes are presentational; when the collapsed variant includes summary controls, those controls skip disabled steps. / |
| `label` | `string` | no | `` | Accessible label describing the set of steps. Defaults to a translated "Progress" when unset. / |
| `density` | `'compact' \| 'balanced' \| 'spacious'` | no | `'balanced' /` | Controls density (padding) of all steps. |
| `indicatorPosition` | `StepperIndicatorPosition` | no | `'separated' /` | Controls where each step's indicator sits relative to the connector track. - 'separated': indicator lives in the label row, distinct from the progress bar (the original Astryx layout). - 'on-track': indicator is slotted into the connector line as a node on the track (the on-track indicator design). |
| `horizontalOptions` | `StepperHorizontalOptions` | no | `{minimumStepWidth: 112, collapsedVariant: 'withLabelAndControls'} /` | Options specific to the horizontal layout. `minimumStepWidth` controls the per-step collapse threshold; `collapsedVariant` selects a label with controls, a label alone, or a bare progress track. |

## Anatomy

- `Stepper` (required) — The ordered list holding the steps. Owns the orientation and the indicator placement the whole flow is laid out on.
- `Frame` (required) — The layout frame that groups the ordered steps with the optional compact summary shown at narrow widths.
- `Compact summary` (optional) — The optional row a horizontal Stepper adds directly beneath the track once it is too narrow to label every step. horizontalOptions.collapsedVariant chooses a label with Previous/Next controls, the label alone, or no row for a bare progress track. The on-track layout keeps its indicators on the rail instead of repeating the active indicator beside the label. Every step keeps its name in the accessible sequence at any width.
- `Step` (required) — One step in the flow, and the element carrying its status. Wraps the indicator, label, description, and the track segments belonging to it.
- `Progress bar` (required) — A 4px segmented bar per step. Filled for completed and active steps. Advancing one step grows the fill along the track it just covered, so the movement reads as progress rather than a bar changing color. Every other change applies at once: going back, jumping forward by more than one step, mounting mid-flow, and any change at all under prefers-reduced-motion. Where a span is drawn by more than one segment (the on-track layouts split it between two steps, three when a content slot sits between them), the segments run in track order at one constant speed, so the fill reads as a single line growing rather than pieces lighting in turn.
- `Connector` (optional) — The track drawn between indicators in the on-track layouts. Each connector paints an unfilled line and, over it, the accent fill covering the progress made. How many pieces a connector is drawn from is an implementation detail of the layout, not a themeable part; use --step-connector-gap to hold the track off the indicator.
- `Indicator` (optional) — A numbered badge, a check, or any custom icon. Controlled via the indicator prop.
- `Label` (required) — Text identifying the step.
- `Description` (optional) — Supporting text below the label with additional context.

## Retrieval keywords

`stepper`, `steps`, `wizard`, `workflow`, `progress`, `multi-step`, `form wizard`, `onboarding`

---

Generated from `astryx/packages/core/src/Stepper/Stepper.doc.mjs` (MIT, https://github.com/facebook/astryx). Spec: yes · upstream tests: no.

<!-- port-status:begin (generated by tools/gen-port-status.py) -->
## OCaml port

**Status:** not ported yet. The upstream contract above is the specification; see `docs/PORT-STATUS.md` for the milestone it is planned in.

<!-- port-status:end -->
