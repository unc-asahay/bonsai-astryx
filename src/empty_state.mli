(* EmptyState — a hand-port of Astryx's EmptyState/EmptyState.tsx.

   Three fidelity details that are easy to lose and were kept deliberately:

   1. The container carries role="status". An empty state appears *because* something
      changed (a search returned nothing, a list was cleared), so assistive tech should
      be told; upstream makes the whole block a live region and the port does the same.
   2. The icon is wrapped in a div with aria-hidden="true". The illustration is
      decoration — the title carries the meaning.
   3. The description renders as a <div>, never a <p>. Upstream's comment gives the
      reason: the description accepts arbitrary nodes, and a <p> cannot legally contain
      block children, which produces invalid markup and React hydration mismatches. The
      stylesheet sets margin: 0, so the appearance is unchanged.

   [heading_level] defaults to H3 upstream and here; the title is a real heading so it
   lands in the document outline. *)

open! Core
open! Bonsai_web

type heading_level =
  | H1
  | H2
  | H3
  | H4
  | H5
  | H6

val view
  :  ?description:Vdom.Node.t
  -> ?icon:Vdom.Node.t
  -> ?actions:Vdom.Node.t list
  -> ?heading_level:heading_level
  -> ?is_compact:bool
  -> ?attrs:Vdom.Attr.t list
  -> title:string
  -> unit
  -> Vdom.Node.t
