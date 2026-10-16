(** Entry animations — upstream's [useEntryAnimation] hook.

    Upstream sets a module-level flag in the next animation frame and reads it once, when
    the component first renders. The consequence is deliberate and easy to miss:
    {b an element present on the first paint does not animate}; only one that mounts later
    does. Without that rule the whole page animates in on load.

    This is that mechanism, reproduced with the same schedule: a flag flipped in the first
    animation frame after the bundle loads, read when a component is built.

    {2 Known divergence}

    Upstream captures the flag per {i instance} (a [useState] initialiser), so a component
    that re-renders later keeps its original decision. Here the flag is read when the view
    is built, so a view rebuilt for an unrelated reason after the first frame will acquire
    the animation class and animate late. Reaching per-instance capture in Bonsai needs the
    component to be graph-aware; that was judged not worth turning every user of this module
    into a graph-aware component. It is recorded in [docs/VERIFICATION.md] rather than
    quietly ignored. *)

open! Core
open! Bonsai_web

type preset =
  | Slide_down
  | Slide_up
  | Fade_in
  | Scale_in

val class_ : preset -> string
(** The CSS class for a preset, e.g. [astryx-enter--slide-down]. *)

val animate : unit -> bool
(** [false] until the app has displayed its first frame, then [true]. Read it when building
    a component to decide whether that component should animate in. *)
