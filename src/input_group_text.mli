(** A text adornment for an [Input_group].

    A fixed prefix or suffix that belongs to the group's surface rather than being a control inside it — a
    currency symbol, a unit, a domain, a protocol. It carries no behaviour; what makes it read as part of the
    group is CSS: the negative inline-start margin that removes the shared border's doubling, and the
    first/last-child corners, the same connected look [Button_group] uses. *)

open! Core
open! Bonsai_web

val view : ?attrs:Vdom.Attr.t list -> children:Vdom.Node.t list -> unit -> Vdom.Node.t
(** [view ~children ()]. Usually one of the first or last children of the group. *)
