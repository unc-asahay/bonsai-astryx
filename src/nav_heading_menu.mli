(** A trigger-less menu that is a nav heading's popover body.

    NavHeadingMenu is upstream's container for the actions of a nav heading
    (SideNavHeading / TopNavHeading pass it as their [menu] prop): a
    [role="menu"] surface whose rows are [NavHeadingMenuItem], with the whole
    APG Menu surface keyboard contract — ArrowDown/ArrowUp, Home/End, typeahead,
    Escape, Enter/Space activation — driven by {!Menu_focus}, the port of
    upstream's [useListFocus] + [useTypeahead] that DropdownMenu already
    exercises.

    The trigger and the popover itself are NOT this component and are NOT
    ported yet: upstream's headings render a split button whose popover opens
    on a separate action, and that pose belongs to the heading components. What
    the menu owns here is the surface: role, rows, keyboard, sizes.

    {2 The close callback}

    Upstream injects [closeMenu] through the [NavHeadingCloseContext] that the
    heading provides, so an item click and Escape both dismiss the popover the
    caller opened. This port has no React context, so [on_close] is an explicit
    [Bonsai.Effect.t] argument (the same shape DropdownMenu's close takes); the
    caller — the future heading, or a showcase that owns an open flag — decides
    what closing means. [on_close] defaults to [Bonsai.Effect.Ignore].

    {2 Divergences}

    - No React context: [size] and [on_close] are explicit on [view] rather
      than read by the items, because in this port an item is a record, not a
      graph — see {!item}.
    - Upstream's capture-phase cancellation ([onKeyDownCapture] + a WeakSet of
      prevented native events) exists to honor a caller's [onKeyDown] prop.
      The port has no keydown prop to honor yet, so the cancelling machinery is
      absent rather than half-present (the surface still prevents default on
      every key it consumes).
    - [href] rows are real anchors exactly as DropdownMenu's rows are; a
      modified click keeps the browser's meaning ([Menu_focus.is_modified_click],
      activation, [FR10]).
    - [label]/[description]/[icon] are strings or icon names like the port's
      Icon set (upstream accepts a ReactNode and an IconType). Pass a rendered
      node by using the public [Astryx] node combinators for anything richer.
    - The marker is [NavHeadingMenu] on the surface.

    Keyboard contract per [Menu_focus]: rows are
    [role="menuitem"]:not([aria-disabled="true"]), arrows move DOM focus with
    wrap, Home/End jump, typeahead matches against the rows' own text (with the
    menu closed by Escape), and Enter/Space on a focused row activates it (a
    synthetic click with [detail] 0). Disabled rows are excluded by the query
    so they can never take focus.
*)

open! Core
open! Bonsai_web

type size =
  | Sm
  | Md
  | Lg
(** Controls the surface min-width and the items' padding. *)

type item =
  { id : string
  ; label : string
  ; description : string option
  ; (* An icon name from the port's icon set, rendered before the label. *)
    icon : string option
  ; (* When present the row IS the anchor (role=menuitem on the <a>), so a
       modified click keeps the browser's meaning. *)
    href : string option
  ; is_disabled : bool
  }
(** A row. [id] is what [on_select] receives. *)

val view
  :  ?attrs:Vdom.Attr.t list
  -> ?id:string
  -> ?size:size
  -> ?min_width:int
  -> ?on_close:(unit Bonsai.Effect.t) Bonsai.t
  -> on_select:(item -> unit Bonsai.Effect.t) Bonsai.t
  -> items:item list
  -> Bonsai.graph
  -> Vdom.Node.t Bonsai.t
(** [view ~on_select ~items graph] — the [role="menu"] surface. [min_width]
    overrides the size defaults (160/200/240px). [on_select] receives the row's
    [id]; every activation also runs [on_close], matching upstream's
    select-then-close through the close context. Escape also runs [on_close]. *)
