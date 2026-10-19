(** BreadcrumbItem — one crumb of an [Astryx.Breadcrumbs] trail.

    Port of upstream [Breadcrumbs/BreadcrumbItem.tsx]. The trail container passes
    the variant and the separator explicitly (upstream's layer-scoped context is
    the port-wide named gap, like every other context) and computes the
    auto-"current" crumb before rendering — the observable contract is the same:
    with no explicit current crumb, the last crumb that did not opt out carries
    [aria-current="page"] on its content element.

    {2 Not ported, and named here}

    - {b [menu].} A crumb whose popover reuses the DropdownMenu item pipeline is
      not ported: this port's [{!Astryx.Dropdown_menu}] is a complete menu-button,
      not a row renderer, so a menu crumb falls back to a plain link/button/span.
      Match it with a separate menu if the trail needs one.
    - {b [as].} A custom framework link component has no counterpart; [href]
      renders a plain [<a>], vetted by the port's safe-url predicate (a refused
      URL renders with no href, per {!Astryx.Clickable_card}).
    - [start_icon] is a [Vdom.Node.t] (upstream accepts any ReactNode), and
      [label] is a node list rather than React children. *)

open! Core
open! Bonsai_web

type variant =
  | Default
  | Supporting

type t =
  { label : Vdom.Node.t list
  ; href : string option
  ; on_click : (unit -> unit Bonsai.Effect.t) option
  ; start_icon : Vdom.Node.t option
  ; is_current : bool option
  ; attrs : Vdom.Attr.t list
  }

val item
  :  ?attrs:Vdom.Attr.t list
  -> ?href:string
  -> ?on_click:(unit -> unit Bonsai.Effect.t)
  -> ?start_icon:Vdom.Node.t
  -> ?is_current:bool option
  -> label:Vdom.Node.t list
  -> unit
  -> t
(** [item ~label ()]. [is_current] has upstream's three states: [Some true] marks
    the crumb as the current page, [Some false] opts out of auto-detection, and
    [None] leaves it an auto-candidate. [on_click] works with or without [href]. *)

val view
  :  variant:variant
  -> separator:Vdom.Node.t
  -> is_auto_current:bool
  -> t
  -> Vdom.Node.t
(** [view ~variant ~separator ~is_auto_current item] — the container's wiring;
    use it directly (supplying the context yourself) to build a trail without the
    container, or let [Astryx.Breadcrumbs.view] do both. *)
