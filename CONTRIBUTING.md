# Contributing

Thanks for helping. This project is deliberately boring about process, because the
thing that makes a port trustworthy is consistency, not cleverness.

## Setting up a toolchain

Two upstream traps will cost you an hour if you hit them blind:

1. **Use OCaml 5.2.1, not 5.3+.** OCaml 5.3 made `effect` a reserved keyword, and
   the Jane Street `v0.18~preview` sources use `effect` as an ordinary identifier
   (`ui_effect/src/ui_effect.ml`, `src/global_listeners.ml`). On 5.3+ the preview
   cannot compile; 5.2.1 predates the keyword and satisfies the packages'
   `ocaml >= 5.1` constraint.

2. **`bonsai_web` / `ppx_html` only exist in Jane Street's own opam repository**
   (the main opam repo has `bonsai`, `virtual_dom`, `incr_dom`, `ppx_css` up to
   the v0.17 release, but not the web packages).

```sh
opam switch create bonsai-ui ocaml-base-compiler.5.2.1 -y
eval "$(opam env --switch=bonsai-ui --set-switch)"
opam repo add janestreet https://github.com/janestreet/opam-repository.git --rank 1
opam update
opam install dune js_of_ocaml js_of_ocaml-ppx ppx_html \
            bonsai_web bonsai_web_components bonsai_web_test
```

If `bonsai_web` fails with a syntax error on `include ./<module>__generated`,
that is the dune/`include`-shorthand issue — pin dune below the version that
broke it (`opam install dune.3.23.1`) and retry.

Regenerating the reference corpus needs node ≥ 20 and pnpm, for the upstream
Storybook (screenshots) only.

## Regenerating instead of editing

Everything under `docs/` and `docs/visual/` is generated. Never hand-edit it; CI
fails when the committed corpus differs from what the generators produce from the
pinned upstream commit. Change a generator, or the pin, and regenerate.

```sh
node tools/extract-docs.mjs               # upstream *.doc.mjs      -> registry.json
python3 tools/extract-source-contracts.py # TypeScript props        -> registry.json
python3 tools/gen-references.py           # registry.json           -> docs/components/*.md
node tools/visual/capture.mjs --storybook-dir apps/storybook/dist   # screenshots + measurements
python3 tools/gen-visual-references.py    # captures                -> docs/visual/*.md, tokens.json
```

## Porting a component — the procedure

Work one component at a time, in this order. Do not skip step 1; most rework comes
from guessing the contract.

1. **Read the contract.** `docs/components/<Name>.md` for props/usage/a11y, the
   upstream `packages/core/src/<Name>/<Name>.tsx` for behaviour, `<Name>.spec.md`
   if present, and the colocated `__tests__/` for edge cases (focus order, IME
   handling, empty states).
2. **Write the `.mli` first.** The signature is the contract you are promising:
   labelled arguments, variant types for enum props, `Bonsai.t` for anything
   stateful. Enum props become OCaml variants — never loose strings.
3. **Implement, minimal and honest.** Use Bonsai primitives (`Bonsai.state`,
   `Bonsai.return`, `let%arr`, `Edge.on_change`) rather than re-inventing React
   patterns. If a prop cannot be supported, omit it and record it as a divergence.
4. **Compile.** `dune build` is a hard gate: no warnings-as-errors bypass.
5. **Parity test.** Add the component to `test/parity/` with the states the
   upstream stories cover. The harness renders both implementations and compares
   DOM structure, class names, ARIA attributes and a screenshot.
6. **Accessibility assertions.** Encode the criteria from the contract file as
   assertions (`aria-busy` while loading, focus retained, roles present).
7. **Record status.** Set the component's `port.json` entry to `ported` or
   `partial`, list divergences, and regenerate the references.
8. **Submit** with the parity output attached: the test names, what was compared,
   and any accepted visual differences with a reason.

### Divergences are first-class

React-only props (`children`, render props, `as`, Next.js `Link` integration) have
no Bonsai equivalent. Do not fake them. Document them in the component's
`## Divergence` section so the reference corpus stays truthful, and so an agent
reading it does not emit impossible code.

## Style

- `.mli` before `.ml`; keep signatures small and stable.
- Variants over strings; labelled arguments over positional.
- Layout through the library's own primitives (`Stack`, `Grid`, `Card`) rather
  than ad-hoc CSS.
- Tests are evidence: a parity test that cannot fail is not a test.

## Reporting

Useful bug reports contain the component name, the recipe or snippet, the
expected vs actual rendering, and — best of all — a failing parity test.
