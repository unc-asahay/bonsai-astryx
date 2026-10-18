(* Thumbnail — mirrors Astryx's Thumbnail/Thumbnail.tsx: a square preview card for
   image attachments. See [thumbnail.ml] for the error-state contract and every
   recorded divergence. *)

open! Core
open! Bonsai_web
open Js_of_ocaml

type show_remove_on =
  [ `Hover  (** the default: revealed on hover and keyboard focus *)
  | `Always
  ]

(** [view ~src ~alt ?label ?on_remove ?on_click ... graph]. The graph is the
    last argument because the thumbnail owns the failed-source state, the same
    shape every stateful component here takes. [on_remove] shows the overlaid
    remove button; [on_click] makes the thumbnail interactive; [is_loading]
    shows a skeleton (no source) or an upload overlay (with source). *)
val view
  :  ?attrs:Vdom.Attr.t list
  -> ?src:string
  -> ?alt:string
  -> ?label:string
  -> ?on_remove:(Dom_html.mouseEvent Js.t -> unit Effect.t)
  -> ?on_click:(Dom_html.mouseEvent Js.t -> unit Effect.t)
  -> ?is_loading:bool
  -> ?is_disabled:bool
  -> ?show_remove_on:show_remove_on
  -> ?id:string
  -> ?component_name:string
  -> Bonsai.graph
  -> Vdom.Node.t Bonsai.t
