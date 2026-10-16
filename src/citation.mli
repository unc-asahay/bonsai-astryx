(* Citation — a hand-port of Astryx's Citation/Citation.tsx.

   A footnote marker: a small pill holding a source label and a number, rendered as a
   link when the source has a usable URL and as inert text when it does not.

   The security-relevant part of this component is the URL check, and it is ported
   literally rather than approximated — see [is_safe_url], which is exported so the
   behaviour can be asserted directly instead of only through a rendered attribute.

   Two upstream behaviours worth naming:

   - A refused URL does not remove the citation. It simply has no href: the pill renders
     as a span instead of an anchor, so the reader still sees the source.
   - The element's accessible name comes entirely from aria-label
     ("Citation {number}: {title}"), and the source icon is aria-hidden, so nothing is
     announced twice.

   i18n: upstream renders that label through its translator
   (@astryx.citation.label). The port has no i18n layer, so the English default from
   upstream's own catalog is inlined verbatim — "Citation {number}: {title}". *)

open! Core
open! Bonsai_web

type variant =
  | Label
  | Number

type source

(* [title] is the visible label, [url] the destination (checked before use), [src] an
   image URL for the source's favicon, and [icon] a caller-supplied node (an Astryx icon
   or any SVG) which takes precedence over [src]. *)
val source
  :  ?title:string
  -> ?url:string
  -> ?src:string
  -> ?icon:Vdom.Node.t
  -> unit
  -> source

val view
  :  ?variant:variant
  -> ?attrs:Vdom.Attr.t list
  -> source:source
  -> number:int
  -> unit
  -> Vdom.Node.t

(* True when [url] is safe to put in an href. Exported because a security control that is
   only observable through rendered markup is a control nobody tests. *)
val is_safe_url : string -> bool
