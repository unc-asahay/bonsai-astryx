(** The decorative selection visuals: a checkbox box, a radio circle, and a bare check mark.

    Upstream resolves these through a registry keyed by name — [useIndicator('checkbox')] — so a
    theme can replace one wholesale. The port has no theme system yet, so this module *is* the
    registry's default entry for every kind, and a theme seam would sit in front of it rather than
    inside it.

    All of them are decorative: each renders [aria-hidden] and owns no input, role or focus
    behaviour. The control that composes one keeps the semantics and paints the focus ring onto it
    — which is why the hover rules are scoped to the owning control's element and not to the
    indicator. *)

open! Core
open! Bonsai_web

type kind =
  | Check
  | Checkbox
  | Radio

type state =
  | Checked
  | Unchecked
  | Indeterminate

type size =
  | Sm
  | Md

val view
  :  kind:kind
  -> state:state
  -> ?is_disabled:bool
  -> ?attrs:Vdom.Attr.t list
  -> size:size
  -> unit
  -> Vdom.Node.t
(** [view ~kind ~state ()] renders 20px (sm) or 24px (md) of selection visual.

    [Checkbox] draws a square box with a check mark when [Checked] and a bar when [Indeterminate] —
    the bar is why the third state exists at all, since a box that is neither empty nor ticked is
    the only way to say "some of these". [Radio] draws a circle that is visible in *both* states,
    empty when unchecked, because a radio's emptiness is information: it says this option exists and
    is not chosen. [Check] renders nothing when unchecked — a bare mark has no box to be empty — and
    otherwise the port's own [check] glyph.

    [is_disabled] dims the visual and, for an unchecked box, uses the muted surface instead of the
    raised one; upstream keeps those two rules separate and so does this. *)
