(** Icon — one SVG glyph, rendered from the generated registry.

    Upstream's {!Icon} resolves a string name against an icon registry and wraps the
    result in a styled span. This port keeps that shape: the glyph data is *generated*
    from upstream's {v defaultIcons.tsx} by [tools/extract-icons.mjs] (see
    {!Icon_data}), and this module is only the renderer plus the a11y contract.

    {2 Accessibility}

    Upstream's rule, reproduced exactly:

    - a non-empty [label] makes the icon meaningful: [role="img"] plus [aria-label] on
      the wrapper span, and no [aria-hidden];
    - an omitted or empty [label] leaves it decorative: [aria-hidden="true"];
    - [attrs] are applied last, so a caller's own [aria-hidden] / [role] / [aria-label]
      always wins.

    The inner [<svg>] carries [aria-hidden="true"] from the generated data in both
    cases — that is upstream's own attribute, not a decision made here.

    {2 A note on sizes}

    Upstream's size styles set width and height in rem on the span; its glyphs are
    [1em] wide. Those two only agree if the same value is also the [font-size], so each
    size class in [assets/components.css] sets all three. Without that, every size
    renders at the inherited font-size and the scale silently does nothing. *)

open! Core
open! Bonsai_web

type size =
  | Xsm  (** 0.75rem *)
  | Sm  (** 1rem *)
  | Md  (** 1.25rem — the default *)
  | Lg  (** 1.5rem *)

type color =
  | Primary
  | Secondary
  | Tertiary
  | Disabled
  | Accent
  | Success
  | Error
  | Warning
  | Blue
  | Red
  | Green
  | Gray
  | Cyan
  | Inherit  (** takes the surrounding text colour — upstream's [color: 'inherit'] *)

val names : string list
(** Every icon name in the generated registry, in upstream's registry order. *)

val view
  :  ?size:size
  -> ?color:color
  -> ?label:string
  -> ?attrs:Vdom.Attr.t list
  -> name:string
  -> unit
  -> Vdom.Node.t
(** [view ~name ()] renders one icon.

    An unknown [name] renders an empty span carrying
    [data-astryx-icon-missing="<name>"] rather than nothing at all: a name typo should
    be visible in a test or a screenshot instead of silently producing a blank space.
    (Upstream warns on the console in development; a data attribute is assertable.) *)
