(** Which element a polymorphic component should render as.

    Ported from [hooks/useInteractiveRole.ts], whose docstring is the specification and whose priority
    order is the whole point:

    +1. [href] -> [Link] - navigation always wins, unless disabled.
    +2. [onClick] -> [Button] - explicit interactivity.
    +3. an interactive trigger context -> [Button] (implicit, via a parent).
    +4. otherwise -> [Inert].

    Step 3 has no port: it is a React context, and this port's containers cannot reach children the
    caller already built (the reason [Form_layout] takes [?optionality] per field instead of a default).
    Upstream's docstring says step 3 exists so that "components that consume this hook never need updating
    when new trigger contexts are added"; here a component becomes a trigger by taking an [on_click],
    which is step 2. Named as a divergence rather than silently dropped.

    The rule that is easy to lose, and that a disabled link depends on: **a disabled [href] is excluded
    at step 1**, so it does not merely stay a link without a destination - it resolves through the
    REMAINING steps. A disabled [href] with no [onClick] is [Inert], not [Link].

    [Clickable_card] does not use this, and the reason is worth stating: it always renders an anchor with
    the href gated ([role="link"] plus [aria-disabled] when refused), so adopting this would change its
    markup rather than move it. Extracting a mechanism is a move whose proof is the existing suites
    passing unchanged; this would not be one. *)

open! Core

type t =
  | Link
  | Button
  | Inert

(** [of_inputs ~href ~has_on_click ~is_disabled] applies the four steps in order. *)
val of_inputs : href:string option -> has_on_click:bool -> is_disabled:bool -> t

(** Upstream's [renderAsButton], which is not the same as [t = Button]: an [Inert] link with no href
    renders as a button (there is an [onClick] to honour and nothing to navigate to), while an [Inert]
    link WITH an href renders as a plain anchor with no destination. *)
val renders_as_button : t -> href:string option -> bool
