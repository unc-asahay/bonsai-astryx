(** List — a vertical list of rows, with the shared row contract decided on the list.

    Port of upstream `List/List.tsx` + `List/ListItem.tsx` + `List/ListContext.tsx`.
    The list is a real semantic container — [<ul>] or [<ol>] with [role="list"] —
    and every row is an [<li>] that is an [Item] (the marker/start/label/end row
    from M44), which is what gives the row the invisible-button/invisible-anchor
    interactive patterns and the swipe layer.

    {2 What the list decides, and how it reaches the rows}

    Upstream threads density, dividers, marker style and edge compensation through
    React context. This port has no contexts by design (the rule that left
    Toolbar's [SizeProvider] and AvatarGroup's size/shape propagation as named
    divergences), so the list decides those four things as *its own styles* and
    the rows follow through the CSS — the same container-decides path MetadataList
    uses. Concretely the list writes four attributes on its own element
    ([data-astryx-density], [data-astryx-dividers], [data-astryx-marker],
    [data-astryx-edge]) and [assets/components.css] styles the rows inside it:
    padding from density, the divider borders (and zero radius), the
    custom-rendered markers (CSS counters for [decimal], exactly upstream's
    mechanism), and the inline edge-compensation margins (which read
    [--_item-inset-inline] — the same variable Item derives its padding from — so
    density and theme overrides move both together, as upstream's comment demands;
    each edge clamps against its own [--container-padding-inline-*] with a 0px
    fallback, so a full-bleed surface leaves the row in place). The marker span
    the row always carries is [display:none] outside a marker list, which is why
    a [No_marker] list has no phantom gap; a [Disc]/[Circle]/[Decimal] list shows
    it. Because the styles target rows as *direct children*
    ([.astryx-list > .astryx-item]), a List nested inside a row later will scope
    its own styles correctly.

    [ListMarkerScope] is NOT ported — it exists for Markdown's nested lists and
    task items, and Markdown is not ported. The six marker kinds it would
    introduce are nevertheless all shipped in the stylesheet (disc, circle,
    square, decimal, lower-alpha, lower-roman), reachable through the data
    attribute, so the scope can arrive without touching this CSS.

    {2 The row}

    See [Astryx.List_item] for the row, which composes [Item.view] with [as_:Li].

    {2 Divergences}

    - No contexts by design (see above); the four list decisions are carried by the
      list's own CSS/attributes, so the rows need no per-row arguments at all.
    - [themeProps] has no counterpart.
    - [data-testid] is not ported; use [~attrs] for a caller-owned attribute.
    - [ListMarkerScope] deferred (Markdown not ported).

    The list itself is stateless — a pure [Vdom.Node.t] builder like [Center] or
    [Avatar_group]. *)
open! Core
open! Bonsai_web

type density =
  | Compact
  | Balanced
  | Spacious

(** The public marker styles (upstream [ListMarkerStyle]). [No_marker] is a
    [<ul>] with no markers rendered. *)
type marker_style =
  | No_marker
  | Disc
  | Circle
  | Decimal

(** [view ?attrs ?id ?density ?has_dividers ?list_style ?start ?header
    ?edge_compensation ~items ()]. The rows are already-built nodes ([List_item]s
    or anything else; the list does not constrain them, only styles direct-child
    rows that carry [.astryx-item]). [header] is rendered above the list and the
    list announces it with [aria-labelledby]. [start] (ordered lists only) sets
    both the CSS counter start and the [<ol>]'s [start] attribute. *)
val view
  :  ?attrs:Vdom.Attr.t list
  -> ?id:string
  -> ?density:density
  -> ?has_dividers:bool
  -> ?list_style:marker_style
  -> ?start:int
  -> ?header:Vdom.Node.t
  -> ?edge_compensation:[ `Inline ]
  -> items:Vdom.Node.t list
  -> unit
  -> Vdom.Node.t
