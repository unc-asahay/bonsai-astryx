(** Normalizing an anchor's [target] and [rel], for the one case that needs it.

    Ported from [Link/computeTargetAndRel.ts]. A [target] other than [_blank] is returned untouched: there
    is nothing to protect. `_blank` is the case that needs it, because a new browsing context can reach
    back at the opening document through [window.opener], so [noopener] and [noreferrer] are appended if
    they are not already there.

    Two details that a reimplementation gets wrong by being helpful:

    - **The caller's [rel] is preserved and the additions go on the end**, so [nofollow] becomes
      [nofollow noopener noreferrer] rather than being replaced. Order is the caller's.
    - **The membership test is case-sensitive**, because upstream compares raw tokens. [NOOPENER] is not
      [noopener], so it is appended rather than recognized. That is upstream's behaviour, not a decision
      here; it is pinned by a case so a future "fix" has to argue with the test.

    Whitespace is normalized as a side effect of splitting: [  spaced   out  ] becomes [spaced out], and
    then the additions. *)

open! Core

(** [compute ~target ~rel] is upstream's function. *)
val compute : target:string option -> rel:string option -> string option * string option
