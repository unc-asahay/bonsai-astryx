(** Item — the universal row: start/end slots, a label and a description, and the
    interactive paths (click, link, delegated control, parent-owned role).

    Port of upstream `Item/Item.tsx` + `Item/ItemSwipeLayer.tsx` + `Item/useSwipeAction.ts`.
    The row is a single DOM element ([div], [li], [span] or a [Custom] node) whose
    content is a marker, start slot, label + description, end slot. The interactive
    paths are exclusive: [on_click] (button or div), [href] (invisible anchor),
    [interactive_selector] (delegation — the row becomes a live region for a nested
    control), or a parent-owned [role] (the row passes clicks upward; the label and
    description render as spans, invisible, so a parent menu/select can read text).

    Swipe layer: [swipe_actions] give the row a leading and trailing action set
    (touch only, like upstream). A drag claims the inline axis, reveals the panels,
    and the gestures are the upstream ones: drag past the commit threshold (or fling)
    fires the outermost action and slides the whole row out; [Reveal] settles at half
    the panel width with the panels live (the row content is inert, Escape/outside
    pointer closes, focused controls in the row are clicked when it closes); [Commit]
    settles at the panel width with the actions presentational and aria-hidden so they
    can be reached by the platform's own gestures.

    Divergences from upstream (explicit, not silent):
    - No React key: [swipe_action] has no [id]; the label identifies an action.
    - The panels live as out-of-flow children of the row itself, instead of being
      swapped in through a portal; the DOM shape the row had before the split stays
      the same, and the swipe markup only exists on rows that actually have actions.
    - Native wiring is limited to three listeners vdom cannot express (pointercancel,
      a non-passive touchmove, and the document-level pointerdown that closes a
      resting row). Everything else — including pointer capture — goes through the
      pointer attrs, like [Slider].
    - The media query ([prefers-reduced-motion]) is read at settle time rather than
      subscribed; a change mid-gesture is equivalent in practice.
    - Click suppression: a drag suppresses the synthetic click that follows it in the
      row's own click handler (upstream suppresses at capture on the container).
    - No [id] attribute on the row itself; use [attrs] for a caller-owned id.
    - Invisible links are plain anchors (no link-component resolution); use [as_]
      [Custom] plus [href] for a custom link root, exactly like upstream's
      isLinkRoot. *)
open! Core
open! Bonsai_web
open Js_of_ocaml

type align = Center | Start
type density = Compact | Balanced | Spacious
type layout = Stacked | Inline
type swipe_action_variant = Neutral | Accent | Destructive
type swipe_behavior = Reveal | Commit
type side = Leading | Trailing
type phase = Idle | Dragging | Settling | Resting | Held

type as_ =
  | Div
  | Li
  | Span
  | Custom of (Vdom.Attr.t list -> Vdom.Node.t list -> Vdom.Node.t)

type swipe_action =
  { label : string
  ; icon : Vdom.Node.t option
  ; on_activate : unit -> unit Effect.t
  ; is_disabled : bool
  ; variant : swipe_action_variant
  ; has_removal : bool
  }

type swipe_actions =
  { leading : swipe_action list
  ; trailing : swipe_action list
  }

(** The mirrored swipe state; reported to the graph so consumers can observe it. *)
type view_state =
  { phase : phase
  ; side : side
  ; is_armed : bool
  }

val view :
     ?as_:as_
  -> ?marker:Vdom.Node.t
  -> ?start_content:Vdom.Node.t
  -> ?description:Vdom.Node.t
  -> ?end_content:Vdom.Node.t
  -> ?align:align
  -> ?density:density
  -> ?label_lines:int
  -> ?description_lines:int
  -> ?layout:layout
  -> ?on_click:(Dom_html.mouseEvent Js.t -> unit Effect.t)
  -> ?interactive_selector:string
  -> ?href:string
  -> ?target:string
  -> ?rel:string
  -> ?is_highlighted:bool
  -> ?is_selected:bool
  -> ?is_disabled:bool
  -> ?swipe_actions:swipe_actions
  -> ?swipe_behavior:swipe_behavior
  -> ?role:string
  -> ?description_id:string
  -> ?attrs:Vdom.Attr.t list
  -> label:Vdom.Node.t
  -> Bonsai.graph
  -> Vdom.Node.t Bonsai.t
