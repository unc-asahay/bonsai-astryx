(** Breadcrumbs — a navigation trail: [<nav aria-label> > <ol>] of crumbs.

    Port of upstream [Breadcrumbs/Breadcrumbs.tsx]. The items are data
    (upstream's children): the container decides the auto-current crumb before
    the first render — the same observable contract as upstream's post-render
    DOM scan (last auto-candidate crumb becomes current when none is explicit).

    {2 Divergences (also recorded in [port.json])}

    - {b Data items, not children.} [items] is a [{!Breadcrumb_item.t} list];
      the variant and separator reach each crumb as arguments instead of through
      upstream's layer-scoped context (the port-wide named context gap). Stray
      children are impossible, and the marker contract is deterministic.
    - The separator defaults to ["/"]; in RTL ([dir="rtl"]) the slash is mirrored
      by CSS, not by a transform-rendering component.
    - [label] defaults to the English "Breadcrumb" (upstream runs it through its
      translation catalogue).
    - The version-stamped [data-astryx-component="Breadcrumbs"] (and
      [="BreadcrumbItem"]) markers are on the container and each [<li>]. *)

open! Core
open! Bonsai_web

type item = Breadcrumb_item.t
type variant = Breadcrumb_item.variant = Default | Supporting

val view
  :  ?id:string
  -> ?attrs:Vdom.Attr.t list
  -> ?separator:Vdom.Node.t
  -> ?variant:variant
  -> ?label:string
  -> items:item list
  -> unit
  -> Vdom.Node.t
(** [view ~items ()] renders the trail. [separator] is decorative
    ([aria-hidden]) and is hidden on the first crumb by CSS. *)
