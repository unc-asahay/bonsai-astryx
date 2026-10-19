(** Lightbox — a fullscreen view of one media item.
    Upstream: packages/core/src/Lightbox/Lightbox.tsx (769 LOC) +
    useLightbox.tsx (157). *)

open! Core
open! Bonsai_web

type media_type =
  | Image
  | Video

type media =
  { src : string
  ; alt : string
  ; caption : Vdom.Node.t option
  ; type_ : media_type
  }

val view
  :  ?attrs:Vdom.Attr.t list
  -> ?index:int Bonsai.t
  (** Controlled gallery index. When given, the caller owns the position and the
      component only reports [~on_index_change]. Default: uncontrolled. *)
  -> ?default_index:int
  (** Starting index when uncontrolled. Default: [0]. *)
  -> ?on_index_change:(int -> unit Effect.t) Bonsai.t
  -> ?has_zoom:bool
  (** Enable zoom (double-click / Enter / Space / [=+] / [-]) and pan
      (drag, arrow keys while zoomed) on images. Default: [false]. Video never
      zooms. *)
  -> ?has_auto_play:bool
  (** Autoplay a video when the lightbox opens. Default: [false]. *)
  -> is_open:bool Bonsai.t
  -> on_open_change:(bool -> unit Effect.t) Bonsai.t
  -> media:media list
  -> Bonsai.graph
  -> Vdom.Node.t Bonsai.t
(** [view ~is_open ~on_open_change ~media graph] renders one lightbox on a
    native [<dialog>] opened with [showModal ()] — the top layer, the inert
    page behind and the focus trap are the platform's, as they are for
    [Dialog]. [media] is one item or a gallery; in gallery mode prev/next
    buttons, the arrow keys and the counter are live.

    {b Divergences} (named, not approximated):
    - [useLightbox] is not ported: upstream's hook is state plus spreadable
      trigger props, and in this port the caller owns [is_open] /
      [on_index_change] directly and builds its own trigger — a plain
      [Button] already carries the role/tabindex/aria-haspopup contract the
      hook would return.
    - The layer-dismissal stack is not ported: [Escape] always closes (as
      [Dialog]'s own dismissal matrix does) rather than only when this
      lightbox is top-most.
    - i18n is not ported: the aria-label fallback, the counter announce
      strings and the zoom announce strings are English, as the rest of the
      port's labels are.
    - The page scroll lock is the simple kind: [overflow] on [body] is saved
      and restored, without upstream's nested-lock counter (one lightbox is
      the assumption, as one dialog is).
    - Zoom/pan transform is written as an inline [style] on the image, the
      same dynamic-style mechanism upstream uses; no other style exists on
      that element to collide with. *)
