(** Deciding whether a link's destination may be handed to a router, or to a browser at all.

    This is upstream's [createSafeLink] as a pure decision, separated from the rendering that acts on it.
    It is separated because the rules below are the part that fails silently: every one of them produces a
    link that compiles, looks right and does the wrong thing, and none of them is visible in a screenshot.

    The sourced rules, all from [utils/safeUrl.ts] and [useLinkComponent.ts]:

    - **An absent destination is not an unsafe one.** Upstream returns true for [null] and [undefined]
      ("Absent destinations remain absent"). This is load-bearing in both directions: a native
      [<Link href="/x">] passes no [to], so if absent meant unsafe every ordinary link in the library
      would render with no destination at all.
    - **Both props are checked, and one failure rejects the whole handoff** - "not just one prop or a
      fallback value". So a rejected handoff drops a perfectly good [href] as well. It is the handoff that
      is rejected, not the offending prop.
    - **A custom component is given [to], defaulting to [href]**, unless it was passed explicitly.
    - A non-string non-object destination is rejected upstream. In this port [?href] is a [string option],
      so those shapes are unrepresentable rather than rejected - a difference in kind, not in coverage. *)

open! Core

(** Which component the destination is being resolved for. Upstream writes this branch as
    [`Component === 'a'`], where [Component] is the resolved value of [as], then the provider, then the
    native anchor. This port has no provider (a dynamic scope cannot reach already-built children), so the
    caller passes whether it resolved to the native anchor. *)
type component =
  | Anchor
  | Custom

(** What the destination decision resolves to. *)
type handoff =
  | Rejected
      (** At least one destination was unsafe. The caller renders a plain anchor with NO destination -
          so this is also reached when one prop is unsafe and the other is perfectly good. *)
  | Native of string option
      (** The native-anchor branch: [None] when neither prop was given, so the caller emits no [href]
          attribute at all, as React does for [href={undefined}]. *)
  | Routed of
      { href : string option
      ; to_ : string option
      }
      (** A custom component's handoff. [to_] defaults to [href]; both are [None] only if both props were
          absent. *)

(** [resolve ~href ~to_] is upstream's three-way branch, in upstream's order. *)
val resolve : component:component -> href:string option -> to_:string option -> handoff

(** One destination's verdict, exposed so the port's own test can pin the absent-vs-unsafe distinction
    separately from the branch it feeds. *)
val is_safe_destination : string option -> bool
