(* Spinner — mirrors Astryx's Spinner/Spinner.tsx: an animated loading indicator.
   See [spinner.ml] for the geometry contract and every recorded divergence. *)

open! Core
open! Bonsai_web

type size =
  | Sm
  | Md  (** the default *)
  | Lg
  | Xl

type shade =
  | Default  (** the default *)
  | Subtle
  | On_media
  | Inherit

val view
  :  ?size:size
  -> ?shade:shade
  -> ?label:string
  -> ?label_node:Vdom.Node.t
  -> ?aria_label:string
  -> ?id:string
  -> ?attrs:Vdom.Attr.t list
  -> unit
  -> Vdom.Node.t
