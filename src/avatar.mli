(** A person or thing, as a picture with a fallback.

    {2 The accessible name, and what the role does to the status}

    An avatar with a name is [role="img"] with that name; an avatar with neither a name nor a labelled status is
    [role="presentation"] and [aria-hidden="true"], rather than announcing a meaningless generic "Avatar". A
    consumer's own [aria-label], [role] or [aria-hidden] always wins.

    The status is the interesting part. A [role="img"] root prunes its descendants' semantics, so a status dot
    inside an avatar is unreadable on its own - which is why the avatar composes the status's label into its own
    accessible name, as "Jane Doe, Online". Upstream reads that label off the status element's props at runtime;
    OCaml cannot, so the port takes it as [status_label].

    {2 Four states, and the one that is easy to get wrong}

    With an image: the image. When the image fails: [fallback_src], if there is one. When there is neither: the
    initials derived from [name] (first and last word's first letter, upper-cased). And when the name yields no
    initials at all, the default icon - not an empty plate, which is what "no initials" would otherwise render.

    {2 Divergences}

    - Upstream reads the status label off the element's props. The port takes [status_label] instead, because a
      node cannot be inspected after it is built.
    - Upstream's i18n joins the name and the status label with a translated separator; the port uses ", ".
    - Upstream's [onClick] renders the avatar as a [<button type="button">]; the port takes [on_click] as a
      [unit Effect.t] and renders the same button, but it does not implement upstream's link-component seam
      ([as]) - a caller's router-aware link is not something the port can be handed.
    - [themeProps] has no counterpart (the port styles by class), and the avatar group's size and shape overrides
      arrive with [AvatarGroup], not here.
    - The image's error chain needs state, so [view] returns a [Bonsai.t] and the jsdom gate cannot render it:
      this component's checks live in the browser gate.
    - Upstream's hover tooltip is the Tooltip component. The port's Tooltip takes a *static* trigger, and the
      avatar's root is computed from its image state, so the two cannot meet without widening Tooltip's
      interface. The port uses a [title] attribute instead, which shows the same thing on hover; the accessible
      name is unaffected by it, which is upstream's split as well - the tooltip prefers the name, the name
      prefers [alt]. Named rather than hidden.
*)

open! Core
open! Bonsai_web

(** The avatar's outline. Upstream's default is [Circle]. *)
type shape =
  | Circle
  | Rounded
  | Square

(** How big the avatar is. Upstream's named sizes are five - 20, 24, 36, 48 and 128 pixels - and it also
    accepts a number, which the port writes inline rather than through the stylesheet. *)
type size =
  | Xsm
  | Sm
  | Md
  | Lg
  | Xl
  | Numeric of int

(** What happens on hover. Upstream's [tooltip] takes [false], a string, or [true]; [true] and an omitted
    tooltip both mean "use the name". *)
type tooltip =
  | No_tooltip
  | Tooltip_text of string
  | Tooltip_from_name

(** [view ?alt ?name ?src ?fallback_src ?size ?shape ?status ?status_label ?tooltip ?href graph ()].

    [alt] names the avatar; it falls back to [name]. [name] is what derives the initials and what the visible
    tooltip shows, which is why the tooltip and the accessible name can differ. [src] is the image and
    [fallback_src] the one tried once [src] has failed. [status_label] is the status's own label, composed into
    the accessible name.

    [href] (with [target] and [rel]) renders an [<a>]; [on_click] without [href] renders a focusable
    [<button type="button">]. Either way the avatar needs a meaningful name, or the button announces nothing. *)
val view
  :  ?attrs:Vdom.Attr.t list
  -> ?id:string
  -> ?alt:string
  -> ?fallback_src:string
  -> ?name:string
  -> ?size:size
  -> ?shape:shape
  -> ?src:string
  -> ?status:Vdom.Node.t
  -> ?status_label:string
  -> ?tooltip:tooltip
  -> ?href:string
  -> ?target:string
  -> ?rel:string
  -> ?on_click:unit Effect.t
  -> Bonsai.graph
  -> unit
  -> Vdom.Node.t Bonsai.t
