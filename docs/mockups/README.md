# Mockups

A mockup here is a **declarative screen recipe**, not a drawing. One recipe
renders three ways:

| renderer | output | use |
| --- | --- | --- |
| `tools/mockup/render.mjs --format html` | static HTML + CSS using measured design tokens | review a layout, screenshot it, hand to a reviewer |
| `tools/mockup/render.mjs --format prompt` | text-to-image prompt + negative prompt | generate a concept image of the screen |
| `tools/mockup/render.mjs --format bonsai` | OCaml skeleton using ported components only | start the real implementation |

Because the recipe names real library components, a mockup can't drift into
screens that the library cannot build: `render.mjs --format bonsai` refuses any
component whose port status is not `ported` / `partial`.

## Recipe format

```jsonc
{
  "id": "settings-page",
  "title": "Account settings",
  "intent": "Change profile details and notification preferences",
  "theme": "neutral",
  "viewport": { "w": 900, "h": 700 },

  // one tree: containers and components, mirroring the component library's names
  "root": {
    "component": "Stack",
    "props": { "direction": "vertical", "gap": "lg" },
    "children": [
      { "component": "Heading", "props": { "level": 1, "text": "Account settings" } },
      { "component": "Card", "children": [
        { "component": "TextInput", "props": { "label": "Full name", "value": "Ada Lovelace" } }
      ]}
    ]
  },

  "imagePrompt": {
    "subject": "a settings screen for a developer tool",
    "composition": "single column, generous whitespace, left-aligned",
    "mood": "calm, utilitarian"
  },

  "notes": ["Only one primary action in the view."]
}
```

### Rules the renderers enforce

1. **Component names must exist** in `registry.json`; unknown names are an error,
   not a silent `<div>`.
2. **Props must exist** for that component, with values matching the documented
   type where it is an enum. An invented prop is a hard error — this is what
   keeps mockups honest.
3. **Layout goes through layout primitives** (`Stack`, `Grid`, `Card`,
   `Section`, `AppShell`), not free-form coordinates, so a mockup stays
   expressible in Bonsai.
4. **Density and colour come from `tokens.json`**, so a mockup uses the measured
   palette and spacing rather than arbitrary values.

## Recipes in this directory

- `login.json` — sign-in screen, single primary action
- `settings-page.json` — profile + preferences
- `confirm-destructive.json` — confirmation dialog over a dimmed page
- `empty-state.json` — first-run / nothing-here screen
- `data-table.json` — list view with toolbar, filters and pagination
