(** CodeBlock — a code display with syntax highlighting, an optional header bar
    (file title and/or language label), an optional copy-to-clipboard button,
    optional line numbers, optional soft wrapping, highlighted lines, a
    unified-diff mode and a collapsible header.

    Ported from Astryx's [CodeBlock/CodeBlock.tsx]. The public surface mirrors
    upstream's props one for one, except for the three that only exist to
    configure upstream's own theming and tokenising ([tokenizer],
    [syntax_theme] and [highlight_mode] — see "Divergences, recorded"); the
    OCaml names are the snake_case forms of upstream's camelCase props, and
    the defaults are upstream's.

    {2 Props}

    - [code] — the code to display. Required, as upstream's is.
    - [language] — the language, used for the header label and to pick the
      tokeniser (default ["plaintext"], upstream's).
    - [title] — the file name / title shown in the header.
    - [has_language_label] — show the language name in the header (default
      [true], upstream's).
    - [has_line_numbers] — show the line-number gutter (default [false],
      upstream's).
    - [highlight_lines] — 1-based line numbers to highlight.
    - [is_diff] — treat [code] as a unified diff and render it as one
      (default [false], upstream's).
    - [has_copy_button] — show the copy button (default [true], upstream's).
    - [on_copy] — an effect run when the copy button is pressed and the text
      has been handed to the clipboard. Upstream's [onCopy] is a plain
      callback; the house shape for a callback with effects is an effect, and
      it is a graph value ([Bonsai.t]) so the caller can wire its own state —
      the same shape [Toast]'s [on_dismiss] takes.
    - [is_wrapped] — soft-wrap long lines instead of scrolling them
      (default [false], upstream's).
    - [max_height] — the maximum height of the code viewport; the code
      scrolls inside it. Unset by default, as upstream's is.
    - [is_collapsible] — allow the block to collapse when the code is longer
      than [collapsible_threshold] lines (default [false], upstream's).
    - [collapsible_threshold] — the line count above which the block is
      collapsible (default 10, upstream's).
    - [size] — [Sm] or [Md] (default [Md], upstream's).
    - [width] — the CSS width of the block (default ["fit-content"],
      upstream's).
    - [container] — [Card] or [Section] (default [Card], upstream's).

    {2 Divergences, recorded}

    - {b Syntax highlighting.} Upstream ships a per-language tokeniser and
      paints the result through the CSS Custom Highlight API
      ([CSS.highlights]) when the browser supports it, falling back to spans.
      This port implements its own tokeniser in {!Code_block} (see the
      "Tokenizer" section of [code_block.ml] for the exact language list and
      the rules it applies) and paints the result with spans, which is
      upstream's own fallback path. The colours come from the house semantic
      tokens; upstream's syntax theme ([theme/syntax/tokens.ts]) has no
      equivalent in this repository, so the port uses the nearest semantic
      token per token class and documents the mapping below.

      {3 Token class to house colour}

      {[
        [comment]     [text-secondary]
        [string]      [success]
        [number]      [warning]
        [constant]    [warning]
        [attribute]   [warning]
        [function]    [accent]
        [keyword]     [accent]
        [tag]         [accent]
        [type]        [text-primary]
        [variable]    [text-primary]
        [property]    [text-primary]
        [operator]    [text-secondary]
        [punctuation] [text-secondary]
      ]}

      The diff rows take the muted house surfaces ([success-muted] for an
      added line, [error-muted] for a removed one, [background-muted] for a
      hunk header) in place of upstream's syntax-theme surfaces, and a
      highlighted line takes [accent-muted] as upstream's does.

    - {b Highlighting ranges.} Upstream can also express [highlight_lines] as
      highlight ranges (the [highlightRanges.ts] module). The port expresses
      them as a marked line, which is the same information in a form the DOM
      can carry.

    - {b The theming and tokenising props.} Upstream takes a [tokenizer]
      override, a per-instance [syntax_theme] and a [highlight_mode] that
      picks between the CSS Custom Highlight API and spans. None of the three
      is ported: the tokeniser is the port's own (see above), the syntax
      theme has no equivalent in this repository, and the port always paints
      with spans, which is upstream's own fallback path.

    - {b Scrolling.} The house {!Scrollable_area} component takes static
      children, and the code is a plain string here, so the port renders its
      own scroll viewport with the same accessibility contract upstream's
      [useScrollableArea] gives it: [role="group"], an [aria-label] and
      [tabindex="0"]. The measurement-driven [data-scroll-*] attributes and
      the tab-stop hysteresis of the house component are not ported.

    - {b Clipboard.} Upstream uses a shared [useClipboard] hook. The port
      carries its own copy helper inside {!Code_block} (upstream's hook is not
      part of the ported surface), writes through [navigator.clipboard] with a
      [document.execCommand] fallback, and reverts the "copied" state after
      1500 ms — the house clipboard timing ([Timestamp]). *)

open! Core
open! Bonsai_web

(** The size of the code text and the header, mirroring upstream's [size]
    prop. *)
type size =
  | Sm
  | Md

(** The container the block sits in, mirroring upstream's [container] prop. *)
type container =
  | Card
  | Section

val view
  :  ?attrs:Vdom.Attr.t list
  -> ?id:string
  -> ?language:string
  -> ?title:string
  -> ?has_language_label:bool
  -> ?has_line_numbers:bool
  -> ?highlight_lines:int list
  -> ?is_diff:bool
  -> ?has_copy_button:bool
  -> ?on_copy:(unit -> unit Effect.t) Bonsai.t
  -> ?is_wrapped:bool
  -> ?max_height:Common.Size_value.t
  -> ?is_collapsible:bool
  -> ?collapsible_threshold:int
  -> ?size:size
  -> ?width:string
  -> ?container:container
  -> code:string
  -> Bonsai.graph
  -> Vdom.Node.t Bonsai.t
