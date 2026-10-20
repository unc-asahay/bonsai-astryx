(** Port of upstream [ContextMenu]
    (packages/core/src/ContextMenu/ContextMenu.tsx).

    Upstream's ContextMenu is a right-click menu: right-clicking the trigger
    opens a DropdownMenu-shaped surface *at the pointer*, and a row that
    carries children drills into them in place of the surface's rows.

    This port carries the pieces of upstream DropdownMenu's phase 2 that
    ContextMenu depends on - the drill-in view stack, the overflow
    measurement, the adaptive presentation and the touch action list - so the
    surface can be built without landing all of DropdownMenu. They live in
    this module rather than in {!Dropdown_menu} because DropdownMenu's
    phase-1 surface is still landing separately; when it does, these move to
    it.

    {2 Divergences from upstream}

    - Upstream renders the pointer surface into a [Layer] (a portal) and the
      touch presentation into a [BottomSheet]. Neither the layer portal nor
      [Bottom_sheet] is ported yet, so this port renders the surface in place,
      next to the trigger, and renders the touch presentation as a plain
      bottom-anchored panel. See {!presentation}.
    - Upstream's touch rows keep [List] ownership ([ListItem] rows inside a
      [List]). This port renders the same menu rows in the touch panel, so
      one keyboard model serves both presentations.
    - Upstream's pointer sub-menu opens as a fly-out next to its row. This
      port drills in instead: the sub-menu replaces the rows of the surface,
      and Escape steps back out one level.
    - Upstream's overflow handling does *not* fold the rest of the menu into
      a sub-menu; it only switches the surface's touch-action between
      panning and pinch-zoom. This port does the same.
    - Upstream resolves the adaptive presentation reactively to the media
      query. This port resolves it when it renders.
    - Upstream opens a sub-menu on long-press for touch devices. Touch
      events are not available in the house's virtual-dom version, so only
      the right-click and the keyboard invocation are ported. *)

open! Bonsai_web

(** How the menu presents itself.

    - [Popover] renders the surface next to the pointer.
    - [Bottom_sheet] renders the touch presentation: a bottom-anchored panel
      with a heading, whose rows are action buttons.
    - [Adaptive] picks [Bottom_sheet] on compact touch devices (the media
      query [(max-width: 768px) and (pointer: coarse)]) and [Popover]
      everywhere else. Upstream resolves this reactively; this port resolves
      it when it renders. *)
type presentation =
  | Popover
  | Bottom_sheet
  | Adaptive

(** How an item reads. [Destructive] paints the row in the error colour. *)
type variant =
  | Default
  | Destructive

(** A row of the menu.

    [children] turns the row into a sub-menu: activating it drills into
    [children] instead of selecting the row. [has_close_on_select] is false
    for a row that keeps the menu open after it is chosen - upstream's
    [hasCloseOnSelect: false], which is what a link row wants. *)
type item =
  { id : string option
  ; label : string
  ; description : string option
  ; icon : string option
  ; end_content : Vdom.Node.t option
  ; variant : variant
  ; is_disabled : bool
  ; href : string option
  ; has_close_on_select : bool
  ; children : entry list option
  }

(** A row of the menu. A [Section] groups its items under a heading. *)
and entry =
  | Item of item
  | Divider
  | Section of section

and section =
  { id : string option
  ; title : string option
  ; items : item list
  }

(** The element the menu attaches to. [Span] renders an inline trigger that
    still owns a box, matching upstream's [triggerAs]. *)
type trigger_as =
  | Div
  | Span

(** The right-click menu.

    [trigger] is the content the menu is attached to; right-clicking it (or
    invoking it from the keyboard) opens the menu at the pointer. [entries] are
    the rows of the menu. [on_select] is called with the row that was chosen;
    [on_open_change] reports the menu opening and closing. *)
val view
  :  ?attrs:Vdom.Attr.t list
  -> ?id:string
  -> ?label:string
  -> ?presentation:presentation
  -> ?trigger_as:trigger_as
  -> ?is_disabled:bool
  -> ?menu_width:string
  -> ?on_open_change:(bool -> unit Bonsai.Effect.t) Bonsai.t
  -> ?on_select:(item -> unit Bonsai.Effect.t) Bonsai.t
  -> trigger:Vdom.Node.t
  -> entries:entry list
  -> Bonsai.graph
  -> Vdom.Node.t Bonsai.t
