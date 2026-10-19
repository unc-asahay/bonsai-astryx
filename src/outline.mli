(* Outline — a hand-port of Astryx's Outline/Outline.tsx (508 lines) and
   useScrollSpy.ts (467), with types.ts.

   A table-of-contents navigation component for document headings. Outline
   accepts a flat `items` array and renders anchor links with indentation
   based on each heading level, plus a sliding indicator track that animates
   to the active item.

   When [active_id] is omitted it tracks scroll position (rAF-throttled,
   reading live heading positions, never stale caches) and marks the last
   heading whose top has passed its activation line — where [offset] (a fixed
   header overlaying the scroll root) plus the heading's own
   [scroll-margin-top] put it. It defaults to the first item at the top and
   the last at the bottom.

   Keyboard: the list is a single tab stop (roving tabindex, seated on the
   active heading while focus is outside), arrow keys move between headings,
   Home/End jump to the ends, and Enter/Space activate — one Tab, not one per
   heading. The arrow/Home/End machinery is {!Common.List_focus} (upstream's
   useListFocus), the same mechanism ButtonGroup and Toolbar share.

   {2 Divergences, named rather than hidden}

   - {b The link seam}. Upstream renders through [useLinkComponent], so an app
     can route its links. This port has no such context seam; the items are
     plain `<a href="#id">` anchors (the standing DropdownMenu row anchors
     take).
   - {b [scrollContainerRef]}. Upstream takes a React ref to the scroll
     container. Bonsai has no refs to pass across the component boundary, so
     the port accepts [scroll_container], a CSS selector resolved against
     [document]. Omitted, the nearest scrollable ancestor wins, as upstream.
   - {b Controlled state}. When [active_id] is provided the built-in
     scroll-spy is disabled (upstream's rule) and the hook posts
     [on_active_id_change] without touching the rendered state; the consumer
     drives the `items` tree to move the visual active state, or accepts the
     aria-current written by the hook.
   - {b themeProps}. The [themeProps('outline' | 'outline-item' |
     'outline-indicator')] seams have no counterpart, the standing of every
     previous milestone.
   - {b No markdown helpers}. Upstream also ships [parseOutlineFromMarkdown] /
     [useOutlineFromMarkdown] / [useOutlineFromDOM]; this milestone is the
     component + scroll-spy.
   - {b The indicator}. The anchor-name that drives the indicator is declared
     in CSS against [aria-current="location"] rather than set as an inline
     style from React state — same geometry, no imperative style.
   - {b [useDevWarning]}. Upstream console-warns on a known dev mistake; the
     port reports through [data-astryx-*] attributes instead (house standing).

   The scroll math (activation line == scroll landing == root top + offset +
   scroll-margin-top) is upstream's exactly, including the 1 px rounding
   tolerance, the at-bottom rule (last item), the 1200 ms settle fallback, the
   wheel/touchmove/keyboard interruption path that resumes position tracking,
   and the modifier-chord rule that leaves a modified click to the browser. *)

open! Core
open! Bonsai_web

type density =
  | Default
  | Compact
(** [Compact] reduces the item padding for dense UIs. *)

type item =
  { id : string
  ; (* Unique ID, typically matching the target heading's DOM id. *)
    label : string
  ; (* Display text for the outline item. *)
    level : int
  }
(** A heading entry. [level] is the heading depth 1-6 and controls indentation. *)

val view
  :  ?attrs:Vdom.Attr.t list
  -> ?id:string
  -> ?active_id:string option Bonsai.t
  -> ?on_active_id_change:(string -> unit Bonsai.Effect.t) Bonsai.t
  -> ?label:string
  -> ?density:density
  -> ?on_navigate_start:(string -> unit Bonsai.Effect.t) Bonsai.t
  -> ?on_navigate_end:(string -> unit Bonsai.Effect.t) Bonsai.t
  -> ?offset:int
  -> ?has_scroll_on_click:bool
  -> ?scroll_container:string
  -> items:item list Bonsai.t
  -> Bonsai.graph
  -> Vdom.Node.t Bonsai.t
(** [view ~items graph] renders the outline.

    Defaults, all upstream's: [label = "Table of contents"],
    [density = Default], [offset = 0], [has_scroll_on_click = true].
    [active_id] omitted (and no [scroll_container]) means the port builds the
    scroll-spy: it finds the nearest scrollable ancestor of the outline and
    marks the active heading from scroll position, posting to
    [on_active_id_change] whenever the answer changes. [active_id] supplied
    disables the built-in tracking and the consumer owns the active state —
    [on_active_id_change] still fires from clicks on the items.

    [on_navigate_start] fires when a navigation begins (click, Space, or a
    controlled activation), and [on_navigate_end] fires exactly once per start
    — when the smooth scroll settles, when the user interrupts it, or
    immediately when [has_scroll_on_click = false] — so a paired navigating
    state can never leak.

    [scroll_container] is a CSS selector naming the scroll root to track when
    the content scrolls inside a split pane, modal, or dashboard panel rather
    than the viewport (upstream's [scrollContainerRef], selector instead of a
    ref — see the divergence note above). [offset] shifts both the activation
    line and the scroll landing by the same number of pixels, composing with
    each heading's own [scroll-margin-top] rather than replacing it.

    The rendered surface: a [nav[aria-label=label]] containing a [role=list]
    of [role=listitem] anchors — the active one marked [aria-current="location"]
    — plus a two-pixel indicator track. The indicator animates through CSS
    anchoring to the active link; the attribute (not a class) carries the
    state, so the visual contract reads [aria-current="location"] on exactly
    one link at a time. *)
