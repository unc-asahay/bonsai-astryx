(* Markdown — renders a markdown document.

   A scoped port of upstream's [Markdown] component: the block and inline
   syntax a document needs, upstream's DOM shape, and upstream's URL
   policy. The document is parsed when the tree is built, so [view] is a
   pure builder like [Text.view] and [Code.view] — it takes the source and
   returns the rendered node.

   {1 What it renders}

   ATX headings, paragraphs, emphasis / strong emphasis / strikethrough,
   inline code, fenced code blocks, ordered and unordered lists, block
   quotes, thematic breaks (horizontal rules), links, and image alt text.

   {1 How it renders it}

   - The root is a [<div role="document">] — upstream's root role.
   - A paragraph is a [<div role="paragraph">], not a [<p>]: upstream
     renders paragraphs as divs because inline content can include
     block-level nodes and a <p> would reparent them. The role keeps the
     paragraph in the accessibility tree.
   - A heading is the house [Heading] component, so the markdown headings
     carry the house type scale. A markdown [#] is always an [<h1>].
   - Inline code is the house [Code] component (a real [<code>] element).
   - A block quote is the house [Blockquote] component.
   - A thematic break is a real [<hr>].
   - A list is a real [<ul>] / [<ol>] with [<li>] children. The marker
     style follows the nesting depth the way upstream's list markers do:
     disc / circle / square for unordered lists, decimal / lower-alpha /
     lower-roman for ordered ones.
   - A link is a plain anchor. An internal destination stays in the page;
     an external one (http / https) opens in a new tab with
     [rel="noopener noreferrer"], as upstream does. A destination the
     house's link policy rejects renders as plain text and never reaches
     the host's handler.
   - An image renders as its alt text in brackets — the shape upstream
     uses for an image whose URL its policy rejects. This port never
     renders an <img> and never fetches an image URL.

   Raw HTML is not a gap between the two: upstream does not parse raw
   HTML either (it is an explicit upstream non-goal), so HTML in the
   source is shown as text here too, and never becomes markup.

   {1 Surfaces upstream has and this port does not}

   Each of these upstream surfaces is deliberately not ported, and the
   reason is given with it.

   - {b Tables.} Upstream owns a GFM table block with cell alignment, a
     content-derived floor per column, and a scroll region that owns the
     table's horizontal overflow, accessible name and tab stop (upstream's
     DEC-6). This house has no table component to hand that contract to,
     and a table built out of plain markup would be a different surface
     wearing the same name, so no table is parsed or rendered here.
   - {b Images.} Upstream owns a block image and an inline image, under a
     URL policy stricter than the link one (every [data:] URL is
     rejected), with an alt-text fallback. This port renders no image at
     all: an image's alt text appears in brackets, so nothing pretends to
     be a picture and no image URL is fetched.
   - {b Task lists.} Upstream renders a task-list item through its
     checkbox surface, and each item keeps its own state at every nesting
     level. This house has no checkbox surface to hand that to, so a
     "[ ]" item is an ordinary list item whose text starts with the
     marker.
   - {b Character references.} Upstream decodes named and numeric
     character references in plain text, against a named-reference table
     it keeps private. This port leaves references as written.
   - {b Math.} Upstream recognises [$…$] and [$$…$$] when the host
     supplies a math renderer, and hands the expression over as inert
     text. This port has no math-renderer contract, so dollar text stays
     literal.
   - {b Citations.} Upstream renders citation chips for [id] and 【id】
     markers against a host-supplied source table, in a label or a number
     style. This port has no citation surface, so those markers stay as
     text.
   - {b Plugins, inline plugins, frontmatter and the remark adapter.}
     Upstream's extension protocol (syntax → immutable transform →
     renderer), its inline-plugin rewriting, its typed frontmatter
     metadata and its remark compatibility adapter are all part of the
     upstream plugin pipeline. This port parses a document and nothing
     else: there is no extension seam, no frontmatter metadata and no
     remark adapter.
   - {b Autolinking.} Upstream's [autolink: 'gfm'] option turns bare
     URLs, [www.] hosts, angle-bracketed URLs and email addresses into
     links. This port links only the destinations the source writes as
     links.
   - {b Streaming.} Upstream's [isStreaming] mode parses incrementally
     and fades each chunk in. This port parses the whole document at
     once.
   - {b Heading permalinks and heading-id projection.} Upstream's
     heading-links plugin gives every heading a collision-safe id and a
     copyable permalink, shared with its Outline utilities. This port's
     headings carry neither.
   - {b Custom component overrides.} Upstream's [components] prop
     replaces the heading, paragraph, code, inline-code, math, link,
     image, blockquote, hr and citation parts. This port keeps one narrow
     override — the code block — and nothing else.

   These upstream props are not ported either, because they are outside
   this port's scope: [display] (the document is always block-level),
   [density], [headingLevelStart], [contentWidth] / [contentAlign],
   [sources] / [citationStyle], [plugins] / [inlinePlugins], [autolink],
   [components] beyond the code block, [xstyle] / [style] and
   [data-testid]. Upstream's [className] is ported as [?class_], and
   upstream's internal link component has no counterpart here: an internal
   destination is a plain anchor.

   {1 Divergences from upstream}

   - A list is plain list markup rather than the house [List_container]
     and its interactive rows: upstream's markdown list is static prose,
     not a list of interactive item rows, so it carries no row chrome
     (no dividers, no edge compensation, no swipe layer).
   - A fenced code block renders as preformatted text in the house code
     style, with the fence's language recorded on the element. There is no
     syntax highlighting, no copy button and no line numbers.

*)

open! Core
open! Bonsai_web

(** A fenced code block, as the parser found it: the code without the
    fence, and the fence's info string (the language), when it had one. *)
type code_block =
  { code : string
  ; language : string option
  }

(** What the host does when one of the document's links is activated.

    Upstream's [onLinkClick] returns false to cancel the browser's default
    navigation and undefined to let it happen. The port splits the two:
    the constructor says what happens to the navigation, and the effect
    says what the host does about it. *)
type link_click =
  | Follow of unit Effect.t
      (** The browser follows the destination; the effect runs. *)
  | Prevent of unit Effect.t
      (** The default navigation is cancelled; the effect runs. *)

(** [view ?id ?class_ ?code_block ?on_link_click ~source ()] renders [source]
    as a markdown document.

    - [?id] is the id of the root element.
    - [?class_] is added to the root element's class (upstream's
      [className]).
    - [?code_block] replaces the default rendering of a fenced code block
      (upstream's code component override, narrowed to the code block).
    - [?on_link_click] is called with the destination of a link that is
      activated. It is never called for a rejected destination, because a
      rejected destination renders as plain text. *)
val view
  :  ?id:string
  -> ?class_:string
  -> ?code_block:(code_block -> Vdom.Node.t)
  -> ?on_link_click:(string -> link_click)
  -> source:string
  -> unit
  -> Vdom.Node.t
