(** The dot that sits on an avatar to say what state its owner is in.

    {2 Three tiers, and why the size is not the dot's business}

    The dot's diameter follows the avatar's size - 10 px beside a small avatar, 20 beside a medium one, 32
    beside a large - along with its border width and the size of the glyph drawn inside it. The port takes the
    [tier] directly rather than an avatar size, so the mapping from avatar size to tier lives in exactly one
    place: the avatar.

    {2 The label, and a divergence worth naming}

    Upstream gives the dot a [label] that is announced one of two ways: a dot rendered on its own exposes
    [role="img"] with that label, while a dot inside an avatar is pruned by the avatar's own [role="img"] - so
    the avatar *reads the label off the dot element's props* and composes it into its own accessible name.

    Reading an element's props back at runtime is not something OCaml can do, so the port takes the label as an
    argument on the avatar ([Avatar.view]'s [status_label]) and the dot is decorative whenever the avatar knows
    the label. A dot rendered on its own still names itself.

    {2 Divergences}

    - Upstream exposes [themeProps] for the theme layer; the port styles by class.
    - The tier ladder is upstream's (10/20/32 with borders 1/2/4 and glyphs of 0/12/18); the glyphs at the small
      tier are not drawn, because there is no room for them to be legible.
*)

open! Core
open! Bonsai_web

(** Which state the dot reports. The colours are upstream's [success], [neutral] and [error]; upstream also
    carries a base style every variant builds on, which is not a variant a caller can ask for. *)
type variant =
  | Success
  | Neutral
  | Error

(** How large the dot is, which follows the avatar it sits on. *)
type tier =
  | Small
  | Medium
  | Large

(** [view ?variant ?label ?icon ?tier ()] is the dot. [label] names it when it is rendered on its own; a dot
    whose label the avatar already carries is decorative and should be given no label here.

    [icon] replaces the built-in glyph - a check for [Success], a bar for [Error], a bar for [Neutral]. An icon
    that renders nothing suppresses the glyph, which is a thing a caller may genuinely want. *)
val view
  :  ?attrs:Vdom.Attr.t list
  -> ?variant:variant
  -> ?label:string
  -> ?icon:Vdom.Node.t
  -> ?tier:tier
  -> unit
  -> Vdom.Node.t
