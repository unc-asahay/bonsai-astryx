(* Scroll_overflow — shared scroll-geometry measurement for horizontal
   scroll containers (Carousel, TabList, ...).

   Upstream: hooks/useScrollOverflow.ts + hooks/isRtlElement.ts. *)

open! Core
open! Bonsai_web
open Js_of_ocaml

type overflow =
  { start : bool
  ; end_ : bool
  ; has : bool
  }
[@@deriving equal, sexp_of]

val inactive_overflow : overflow

module Overflow_hook : sig
  (** [attr ~on_measured ()] measures the element it is attached to (the
      scroller) on mount and on every geometry signal, reporting [overflow]
      only when the answer changes. Register the returned attribute on the
      scroller element. *)
  val attr
    :  on_measured:(overflow -> unit Effect.t)
    -> unit
    -> Vdom.Attr.t
end

(** One crossing for the button/wrap arithmetic: RTL sign, wrap-around
    overshoot, step size (one viewport minus half the first item), and
    reduced-motion behaviour. [logical_dir] is -1 for start, 1 for end. *)
val scroll_by_js
  :  Dom_html.element Js.t
  -> int
  -> bool
  -> bool
  -> bool
  -> bool
  -> unit
  Js.t

(** Shift + vertical wheel => horizontal scroll. Returns the native event's
    [preventDefault] effect. *)
val wheel_js : Dom_html.element Js.t -> 'event Js.t -> unit Js.t

(** Upstream's isRtlElement: an element's computed text direction. *)
val is_rtl : Dom_html.element Js.t -> bool
