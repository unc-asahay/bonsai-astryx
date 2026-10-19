(** The collapsible state machine, ported from upstream
    [Collapsible/useCollapsible.ts].

    Banner drives its disclosure from this one hook, and Collapsible will too,
    so a banner's expand/collapse is configured exactly like the component that
    owns the name — upstream's stated reason for sharing the hook rather than a
    Banner-only vocabulary.

    Three modes, decided by [config] exactly as upstream decides by whether
    [isOpen] was provided:

    - {b Controlled}: [is_open] carries the state; [toggle] only reports
      [on_open_change] and never mutates anything here.
    - {b Uncontrolled}: the internal state, seeded from [default_is_open]
      (default [true] — upstream's) is the source of truth; [on_open_change],
      when present, fires {i in addition to} the internal update, because it is
      a notification and not a signal of control.
    - {b Disabled}: [is_collapsible = false]; [is_enabled] is false and the rest
      is inert. Upstream still creates its state unconditionally — so does this
      port, same shape as [Metadata_list].

    {2 Divergence}

    Upstream also reads [CollapsibleGroupContext]: inside a group, a hook with a
    [value] defers entirely to the group. This port has no React context and
    does not fake one, so group-controlled mode is not expressible here:
    [value] is not accepted. A collapsible rendered where upstream would be
    group-controlled manages itself instead. When [CollapsibleGroup] is ported,
    its own value flow will decide whether this hook grows a group parameter. *)

open! Core
open! Bonsai_web

type config =
  { default_is_open : bool option
  ; is_open : bool Bonsai.t option
  ; on_open_change : (bool -> unit Effect.t) Bonsai.t option
  }

val component
  :  ?config:config
  -> is_collapsible:bool
  -> Bonsai.graph
  -> (bool * bool * (unit -> unit Effect.t)) Bonsai.t
(** [component ~is_collapsible ?config graph] returns
    [{v is_enabled, is_open, toggle v}]: whether collapsible behaviour is on at
    all, the current open state from whichever source owns it, and a toggle that
    drives that source. *)
