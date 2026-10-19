# Porting brief — bonsai-astryx

How a component gets ported from `facebook/astryx` (React/StyleX) to
OCaml/Bonsai in this repo. Follow it exactly; the integrator merges your
files and runs the gates.

## Where things are

- **This repo**: `/home/noor/src/bonsai-astryx` (the target; you work in a
  worktree of it — see "Your worktree" below).
- **Upstream**: `/home/noor/src/astryx/packages/core/src/<Component>/` —
  the TypeScript source you are porting. `*.tsx` is the component,
  `hooks/` its logic, `*.styles.ts` the CSS.
- **The behaviour contract is upstream's own**: each component directory
  also has `<Name>.spec.md` (the contract: intent, public API, ARIA,
  accessibility and layout requirements) and `*.test.ts(x)` files (the
  expected behaviour, case by case). Read both. When the spec and the
  implementation disagree, the spec explains the intent and the tests
  show the expected behaviour — the port should satisfy the tests.
  `<Name>.doc.mjs` lists the props and variants, which is the fastest
  way to learn the public API.
- **Reference ports already in this repo**: `src/` holds every ported
  component. Read the closest ones before writing anything — they show the
  house style. `src/timestamp.ml` (host Intl, date/time), `src/outline.ml`
  (scroll-spy, delegated listeners), `src/hover_card.ml` (delayed open/close),
  `src/dropdown_menu.ml` (menus, popovers), `src/select.ml`-style field
  components, `src/number_input.ml` (controlled value + on_change).

## Your worktree

Your worktree is a separate checkout on a branch, created from `master` at
the time you started. Work ONLY inside it. Do not touch the main checkout
`/home/noor/src/bonsai-astryx` — the integrator owns it.

Build and check from the worktree root:

```
cd <your worktree>
opam exec -- dune build          # must be green
```

`node_modules` (jsdom) lives in the main checkout. If you need the node
gates, symlink it:

```
ln -sfn /home/noor/src/bonsai-astryx/node_modules <your worktree>/node_modules
```

## What you deliver (exactly these files, nothing else)

1. `src/<snake_name>.ml` — the implementation.
2. `src/<snake_name>.mli` — the signature. The public surface of the port.
3. `assets/parts/<snake_name>.css` — the component's CSS, and nothing else.
4. `examples/showcase/sec_<snake_name>.ml` — the showcase section
   (contract below).

Do NOT edit: `port.json`, `README.md`, `examples/showcase/showcase.ml`,
`assets/components.css`, `tools/visual/verify-browser.mjs`, `docs/**`,
`test/**`. The integrator merges those. Tell the integrator what to add
(see "Final report").

**One exception**: you MUST add exactly one line to `src/astryx.ml` —
`module Toast = Toast` (for your component) — because the showcase section
file refers to `Astryx.Toast` and your build must be green. That is a
one-line change in a file every port touches, so the integrator merges
these lines; make sure yours is the only change you make to that file.

`<snake_name>` is the module name: `Toast` -> `toast`,
`CodeBlock` -> `code_block`, `MobileNav` -> `mobile_nav`. The public path
is `Astryx.<Snake_name>` — but the integrator adds the `module X = X` line
to `src/astryx.ml`; you only create the files.

## House conventions (non-negotiable — the gates check these)

- **Library is effectively unwrapped**: a module named `List` would shadow
  `Stdlib`/`Core` project-wide. If upstream has a `List` component, name it
  `list.ml` but expose it as `Astryx.List_container` (see `src/list.ml`).
- **`src/common.mli` does not exist** — shared helpers live in `src/common.ml`
  and are re-exported through `Astryx.Common`. Read `src/common.ml` before
  writing your own helpers; it already has `Attr`, `Delay_hook`,
  `Interval_hook`, `List_focus`, `Size_value`, `Spacing`, `Alignment`, and
  friends.
- **Polymorphic `=` / `<>` are int-only** in this codebase. Use
  `Poly.equal`, `String.equal`, `Int.equal`, `Char.equal`,
  `Option.is_none`, `Float.(<=)`, `Float.(>)`.
- **Core is open** in most modules (`open! Core`): `String.strip` (not
  `trim`), `String.sub s ~pos ~len`, `Float.round_up` / `Float.round_down`
  (not `ceil`/`floor`), `List.is_empty`, `Char.to_int` (not `Char.code`).
  `Hashtbl.Poly.create ()` / `Hashtbl.Poly.find` / `.set` / `.mem`.
- **`Bonsai` API**: `Bonsai.map` / `map2` / `map3` only (no `map4`/`map5`),
  `Bonsai.return` (not `Bonsai.const`), `Bonsai.both`, `Bonsai.state graph
  ~init`, `Bonsai.effect`, `Bonsai.map`/`Bonsai.map2` take the graph first
  then `~f:`. `Bonsai.all` does not exist. `Bonsai_web.Vdom.Node.t` is the
  node type; the handler returns `-> Vdom.Node.t Bonsai.t`.
- **mli shape**: `val view : ?label:string -> ... -> Vdom.Node.t Bonsai.t`.
  Optional args are `?(x : t = default)`.
- **`Common.Attr.data "component" "Foo"`** returns a LIST of attrs — splice
  it with `@`. The rendered marker is `data-astryx-component="Foo"` and it
  is REQUIRED (the coverage scan counts it).
- **ids**: a fixed default id prefixed `astryx-`; showcase ids are prefixed
  `showcase-<component>-`.
- **duplicate `class` attributes** must be merged with `Common.Attr.class_`;
  two `class` attrs on one element is a bug.
- **HTML boolean attributes**: presence = true; omit the attribute when it
  does not apply.
- **No `on_pointercancel`** — use `on_pointerup` / `on_pointermove` /
  `on_pointerdown`.
- **No `^` operator** for JS property access — use `Js.Unsafe.meth_call`,
  `Js.Unsafe.get`, or a local helper. Note `Js.to_float` / `Js.to_string`
  need a `number t` / `js_string t`: coerce with `Js.Unsafe.coerce` first
  (see `src/timestamp.ml`).
- **JS helpers** are evaluated once on the host, not per call — see the
  `pure_js_expr` block in `src/timestamp.ml`.
- **`module Field_ = Field` must precede `open! Core` / `open! Bonsai_web`**
  if you alias a module before opening those.
- **`Text.view`** takes a list of nodes: `Text.view ~type_:Text.Label [ ... ]`.

## The showcase section contract

`examples/showcase/sec_<snake_name>.ml` is a module in the showcase
executable. It must expose exactly one function:

```ocaml
let demo (graph : Bonsai.graph) : Vdom.Node.t Bonsai.t
```

which returns the whole section node for your component. `Prelude` (in
`examples/showcase/prelude.ml`) gives you the shared helpers — `open Prelude`
and use them:

- `section ~id ~title ~note examples` -> the `<section>` wrapper. `~id` is
  the DOM id (kebab-case, e.g. `"code-block"`), `~title` is the display name
  (e.g. `"CodeBlock"`), `~note` one sentence about what the section shows.
- `ex name node` -> one example: `name` is the example's label (shown under
  it) and `node` the rendered tree.
- `chip s` -> a placeholder box for layout demos.
- `label s` -> a field label.

## Work smart — the budget is real

Three ports in the first batch ran out of iterations in research and
landed nothing. The fix, and it matters more than anything else in this
brief:

- **Start coding in the first quarter of your budget.** Read upstream's
  `.spec.md` and the component's *public surface* — its props, its
  exported types, its render structure — and then write code. Reading
  every upstream file before writing a line is what kills these ports:
  upstream's Selector is 2,120 lines and MultiSelector is 2,720, and a
  worker that reads all of it has nothing left to write with.
- **Write the `.mli` early.** It is the contract for the caller, it is
  the cheapest part of the port, and writing it first forces you to
  decide the shape of the thing.
- **Commit in stages.** If you are running out of iterations, commit what
  compiles and report exactly what is left. A committed, compiling
  partial port is worth more to the campaign than an uncommitted
  complete one: the integrator can finish it, and a half-port that
  builds is a far better hand-off than nothing.
- **Scope honestly.** Port the core faithfully. If upstream has surfaces
  you do not port, leave them out and say so in the `.mli` and in your
  report. Never fake a surface with a stub that renders nothing.

### The ceiling is iterations, not minutes

A Stepper port died at 84 minutes with a `.mli` on disk and no
implementation. The lesson is mechanical, and it is worth more than any
advice about what to read:

- **One batched call is one iteration; ten single calls are ten.** Use
  `execute_code` to grep ten files and print them in one go. A worker
  that reads house `.ml` files one at a time spends a third of its
  budget on the house API and lands nothing.
- **The `.mli` and the `.ml` are one commit.** An `.mli` with no `.ml`
  does not compile — dune fails the library — so a port that died
  between the two files left a worktree that cannot build. Write the
  `.mli` and the `.ml` in the same breath, then commit them together.
- **One `write_file` for the whole implementation.** Not one per
  function. A thousand-line file written in four calls is four
  iterations; written in one, it is one.
- **Build and commit before you add the showcase section.** The section
  is what the integrator wires; the implementation is what the component
  *is*. If you are out of budget, be out of budget on the section.

## House facts that will save you an hour

- `Bonsai.graph` appears in signatures; a handler returns
  `-> Vdom.Node.t Bonsai.t`.
- `Bonsai.map`, `Bonsai.map2`, `Bonsai.map3` and `Bonsai.both` exist.
  `Bonsai.all`, `Bonsai.map4` and `Bonsai.map5` do not.
- `Bonsai.state` takes a `graph` argument; `Bonsai.map` does not.
  `Bonsai.state'` takes a function of the previous state — that is how
  you read the CURRENT value at effect time, which matters when several
  events arrive before the next render.
- `Bonsai.return`, not `Bonsai.const`.
- Polymorphic `=` / `<>` are int-only here: use `Poly.equal`,
  `String.equal`, `Int.equal`, `Option.is_none`, `Float.equal`.
- `String.strip`, not `String.trim`. `String.concat ~sep:""`.
  `String.sub s ~pos ~len`.
- `Float.round_up` / `Float.round_down`. `Char.to_int`.
  `Hashtbl.Poly.create` / `find` / `set` / `mem`.
- `Common.Attr.data` returns a list and needs `@` to splice.
- `Text.view` takes a list of nodes.
- Merge duplicate class names with `Common.Attr.class_`; there is no
  reactive `src`.
- Every component element needs `data-astryx-component` — the visual
  and coverage contracts key off it.
- Module aliases must come before `open!`. The library is effectively
  unwrapped, so never shadow `List`.
- `Visually_hidden.view` has no `~attrs`.
- The vdom has no `on_pointercancel`; use pointer down / move / up.
- There is no `^` operator for JS access: use `Js.Unsafe.meth_call`,
  `Js.Unsafe.get`, `Common.prop`, or a local helper. `Js.Unsafe.any` is
  the dynamic JS type in this `js_of_ocaml` version; house JS helpers
  use `pure_js_expr` for a function and `Js.Unsafe.eval_string` for a
  value that has to be read at call time.
- One `Common.Delay_hook.attr` per element with a unified input: two
  same-named delay hooks fuse incorrectly.

## House rules that will bite

- The showcase section is a GRAPH. `ex` takes a rendered node; `ex_tree`
  (defined locally in the demo) takes a graph; `join_all` combines them.
  A `Vdom.Node.t Bonsai.t` cannot go into a node list — use
  `Bonsai.map` / `Bonsai.map2` / `Bonsai.map3`.
- **Dune does not compile a showcase section until something references
  it.** A green `dune build` in your worktree does NOT prove your section
  compiles. Wire your section into `examples/showcase/showcase.ml` in
  your worktree, build, fix, then `git checkout --` that file. This is
  not optional: two ports shipped broken sections because they skipped
  it.
- The OCaml Layer has no portal and no outlet, so anything upstream draws
  in a portal is drawn in place. Say so in the `.mli`, the way
  `src/layer.mli` documents the same divergence.
- `data-astryx-component` is required on the component's root.

## Final report

Your report is what the integrator acts on. Give it:

1. **Files created** (paths) and the exact `src/astryx.ml` line to add.
2. **The public API** — the signatures, so the integrator can wire the
   showcase section without reading the implementation.
3. **The example count** and the label of each example.
4. **The browser-gate check snippet**: a `check(...)` block for
   `tools/visual/verify-browser.mjs`, inside `if (mode === "showcase")`,
   asserting the behaviour that only a real browser can see (a click
   into Bonsai state, a keypress, a measured size). Four to eight real
   checks beat twenty shallow ones.
5. **Divergences from upstream**, and what you did NOT port.
6. **The commit SHA.**

## Rules for the section

- A section is a GRAPH, not a node: the component is stateful, so the
  examples are graphs that have to be combined before they are wrapped.
  The house pattern (see any `*_demo` in `examples/showcase/showcase.ml`):

  ```ocaml
  let demo (graph : Bonsai.graph) : Vdom.Node.t Bonsai.t =
    let ex_tree label tree = Bonsai.map tree ~f:(fun node -> ex label node) in
    let examples =
      [ ex_tree "Default" (Toast.view ~graph)
      ; ex_tree "With action" (Toast.view ~action:(Some ...) ~graph)
      ]
    in
    let nodes = join_all examples in
    Bonsai.map nodes ~f:(fun nodes ->
      section ~id:"toast" ~title:"Toast" ~note:"What this section shows." nodes)
  ```

  - `ex` takes a rendered NODE (`Vdom.Node.t`); `ex_tree` (defined locally in
    the demo, as above) takes a GRAPH and maps it to an `ex`.
  - `join_all` combines the example graphs into one list of nodes. Define it
    locally in your demo the way the other demos do:

    ```ocaml
    let join_all (trees : Vdom.Node.t Bonsai.t list) =
      List.fold trees ~init:(Bonsai.return []) ~f:(fun acc tree ->
        Bonsai.both acc tree |> Bonsai.map ~f:(fun (acc, tree) -> tree :: acc))
      |> Bonsai.map ~f:List.rev
    ;;
    ```

  - `section ~id ~title ~note examples` then takes the list of nodes.
- Render **at least 4 examples**, covering the component's real variants
  (default, disabled, loading, error, size variants, controlled vs
  uncontrolled — whatever upstream actually supports). Upstream's own
  stories/demos are the best guide to what the variants are.
- Every example must be real: the actual component, with real state where
  the component has it (controlled value wired to a `Bonsai.state`, so the
  section shows the component working).
- Use the public API only (`Astryx.<Name>`), like the rest of the showcase.
- Give each example a distinct DOM id (`showcase-<component>-<variant>`) so
  the browser gate can address it.
- The file must compile as part of the showcase executable:

```
opam exec -- dune build examples/showcase/sec_<snake_name>.bc.js
```

## CSS contract

`assets/parts/<snake_name>.css` holds only your component's rules. The
integrator concatenates it into `assets/components.css`. Rules are
namespaced under the component's class (e.g. `.astryx-code-block`), use the
design tokens already in `assets/tokens.css` (`var(--spacing-4)`,
`var(--text-primary)`, `var(--duration-medium)`, `var(--text-supporting-size)`,
…) rather than raw values, and never restyle global elements.

## The browser-gate check snippet

The integrator splices your checks into `tools/visual/verify-browser.mjs`.
Write them as a single block that follows the file's conventions exactly
(read the file's existing blocks first):

```js
if (mode === "showcase") {
  const codeBlockSection = await page.$("section[data-showcase-component='CodeBlock']");
  check("the CodeBlock section renders", codeBlockSection !== null, ...);
  // ... more checks, using page.click / page.keyboard / page.waitForFunction
}
```

- `mode === "showcase"` guard is REQUIRED: the gate also runs against the
  demo page, which has no per-component sections.
- Use `check(label, condition, detail)`; the label must read as a
  sentence.
- In `waitForFunction` predicates, test the element FIRST:
  `() => { const el = document.getElementById("x"); return el !== null && ...; }`
  — never `el?.closest(...) !== null`, which is true when `el` is undefined.
- Give 4-8 checks that prove the component actually works in a browser
  (renders, responds to a real click, shows state, closes, etc.).

## Quality bar

- **Port the real thing.** Follow upstream's behaviour, semantics, ARIA
  roles, keyboard handling, and variants. If upstream has a behaviour you
  deliberately do not port, say so in the `.mli` (the repo's convention is
  a "Divergences from upstream" paragraph) and in your final report.
- **No stubs, no TODOs, no placeholder rendering.** If a part of upstream is
  too large to port faithfully, port the rest properly and document exactly
  what you left out.
- The `.mli` must document the public API, not just its types.
- `dune build` green in your worktree before you report.
- Read the upstream `.styles.ts` and port the styles that matter; the
  showcase is judged on how close it looks to upstream's demos.

## Final report (the integrator works from this)

Report, in this order:

1. **Files created** (paths).
2. **The exact `src/astryx.ml` line** to add (e.g. `module Toast = Toast`).
3. **The port.json entry** to add, as JSON:
   `{"class": "B", "component": "Toast", "file": "src/toast.ml", "milestone": "M59", "module": "Astryx.Toast"}`
   (`class` A/B/C by tier: A = leaf/simple, B = mid, C = complex — use C for
   anything with popovers/menus/roving focus, like Dialog, DropdownMenu,
   ComplexSelector, Outline).
4. **Showcase section facts**: the section `~id`, `~title`, the number of
   examples, and each example's label and DOM id — the integrator's gate
   counts depend on them.
5. **The browser-gate check snippet** (the fenced block, ready to paste).
6. **Divergences from upstream** (or "none").
7. **Anything the integrator must know**: extra CSS files, new shared
   helpers you needed but could not put in `src/common.ml` (say what and
   where you put it), and known rough edges.
