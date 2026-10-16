(** A layer anchored to its trigger, opened and dismissed by the platform.

    {2 What is not code in this port}

    Upstream positions and dismisses a popover with the native Popover API — [popover="auto"] and
    [showPopover]\{source: trigger\} — so the platform owns the top layer, outside-click dismissal, Escape
    and CSS anchor positioning. This component is a wrapper around that mechanism, which was ported and
    proven on its own first (Gate 29/30). The 46 KB of placement maths in upstream's [useLayer] is mostly
    the fallback for engines without [showPopover]; this port has no fallback and says so here rather than
    shipping a second, untested positioning engine.

    {2 The trigger is wired by the mechanism, not by the caller}

    [trigger] must contain a [<button>] or [[role="button"]], and the popover finds it — applying
    [aria-haspopup], [aria-expanded] and [aria-controls], plus the click that toggles. That is not
    convenience: [aria-expanded] is state, so an attribute handed in by a caller could only be a snapshot
    and would go stale the first time the layer opened. Upstream additionally accepts a render prop for
    triggers it cannot find; a language without render props gets no equivalent here, so **that mode is not
    ported** — give the trigger a real button and this mode is unnecessary.

    {2 Focus}

    Focus enters the first genuine control in [content]; a popover with none falls back to its own labelled
    surface (the surface is focusable, [tabindex="-1"], so it can hold it). The generated close button sits
    *outside* the content wrapper, which is exactly what excludes it from initial focus: it is reachable by
    keyboard, just not where focus lands. Closing returns focus to the trigger if focus was inside.

    {2 Named rather than approximated}

    - **[width] does not clamp against the viewport.** Upstream measures the room and flips or slides; this
      port hands the width to CSS and states the difference. [width] unset means "match the trigger", which
      CSS anchor sizing does natively — no measurement, and no JavaScript to get it wrong.
    - **No modal focus trap.** [is_modal] is announced with [aria-modal] and nothing is trapped: Tab can
      leave the surface. The platform owns the top layer here, but it does not own the trap.
    - **[anchorRef] (sibling) mode is not ported** — the trigger is always wrapped. *)

open! Core
open! Bonsai_web

type placement =
  | Below
  | Above
  | Start
  | End
(** Which side of the trigger the surface opens on. *)

type alignment =
  | Align_start
  | Align_center
  | Align_end
(** Alignment along the placement axis. *)

type role =
  | Dialog
  | No_role
(** [Dialog] stamps [role="dialog"] (and [aria-modal] when [is_modal]); [No_role] is for content that
    owns its own role, such as a menu or a listbox. *)

val view
  :  ?attrs:Vdom.Attr.t list
  -> ?id:string
  -> ?placement:placement
  -> ?alignment:alignment
  -> ?width:string
  -> ?padding:Common.Spacing.t
  -> ?label:string
  -> ?role:role
  -> ?is_modal:bool
  -> ?has_close_button:bool
  -> ?close_button_label:string
  -> ?has_auto_focus:bool
  -> ?has_light_dismiss:bool
  -> ?has_escape_dismiss:bool
  -> ?is_enabled:bool
  -> trigger:Vdom.Node.t
  -> content:Vdom.Node.t
  -> is_open:bool
  -> on_open_change:(bool -> unit Effect.t)
  -> unit
  -> Vdom.Node.t
(** [view ~trigger ~content ~is_open ~on_open_change ()].

    [is_open] is the application's value and [on_open_change] is how the application hears about a
    dismissal it did not perform — the platform closes an [auto] layer on an outside click or Escape, and
    without this the value would sit there saying open while the surface was gone, which is the trap the
    layer mechanism exists to prevent.

    Defaults, all upstream's: [placement = Below], [alignment = Align_start], [padding] the middle step,
    [role = Dialog], [is_modal = true], [has_auto_focus = true], a close button labelled
    ["Close popover"], and both dismissals on. Pass [~has_light_dismiss:false] for a surface that stays
    until it is explicitly dismissed — that is a [popover] *attribute* meaning, not a flag this port
    implements, so there is no code path that decides to ignore Escape. *)
