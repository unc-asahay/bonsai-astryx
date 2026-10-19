(** TabList — a tab strip with navigation or WAI-ARIA tabs semantics, overflow
    scrolling with edge fades and pointer-only arrows, and optional overflow
    menu triggers.

    Upstream: packages/core/src/TabList/TabList.tsx (Tab + TabMenu +
    TabListContext) over hooks/useScrollOverflow.ts, useListFocus.ts,
    isRtlElement.ts, useKeyboardHint.ts and SizeContext. The scroll machinery
    is the shared {!Scroll_overflow}; roving-tabindex focus is the shared
    {!Common.List_focus}; the overflow menu opens in the house {!Popover}
    layer.

    {2 Semantics}

    With [role] left unset the wrapper is a [<nav>] landmark (the strip marks
    the current tab with [aria-current="true"]). With [role="tablist"] the
    strip is [role="tablist"] and each [Tab] is [role="tab"] with
    [aria-selected] and [aria-controls] (only when the record has a
    [panel_id]); a [href] is ignored there, exactly like upstream. Any other
    [role] value is passed through. The strip is a single Tab stop — the
    selected tab carries [tabindex="0"] and arrow keys move focus over the
    tabs and menu triggers via the shared roving-focus hook; Enter/Space
    activate the focused control natively.

    {2 Recorded divergences}

    - {b Data-driven}: upstream's [Tab]/[TabMenu] children communicate through
      a React context; here [view] takes [items:item list] (house rule, as
      with DropdownMenu/SegmentedControl).
    - {b Vertical arrows}: upstream accepts ArrowUp/ArrowDown as well (APG
      allowance for nav strips); the house focus hook is single-axis, so the
      port uses the horizontal axes plus Home/End.
    - {b No consumer per-tab callbacks} ([onClick]/[endContent] as ReactNode
      is kept, [onClick] drop), no keyboard hint, no touch-press overlay —
      CSS [background-color] [:hover]/[:active] instead.
    - {b Menu layer}: overflow menus open in the house [Popover] layer with
      the same visible contract (below the trigger, light-dismissed,
      [role="menu"] of [menuitemradio]).

    {2 Accessibility}

    Arrow scrolling is pointer-only (the arrows are hidden from AT and the tab
    order); keyboard users scroll by arrowing along the strip, and the
    selected tab is always scrolled fully back into view on selection change
    ([behavior: 'instant'], overriding the CSS smooth scroll — upstream's own
    reason). *)

open! Core
open! Bonsai_web

type size =
  | Sm
  | Md
  | Lg
[@@deriving sexp_of]

type layout =
  | Hug
  | Fill
[@@deriving sexp_of]

type overflow =
  | Auto
  | Scroll
  | Visible
[@@deriving sexp_of]

type tab =
  { value : string
  ; label : string
  ; is_label_hidden : bool
  ; href : string option
  ; panel_id : string option
  ; icon : string option
  ; selected_icon : string option
  ; end_content : Vdom.Node.t option
  ; is_disabled : bool
  }
[@@deriving sexp_of]

type option_item =
  { value : string
  ; label : string
  ; icon : string option
  }
[@@deriving sexp_of]

type menu =
  { label : string
  ; options : option_item list
  }
[@@deriving sexp_of]

type item =
  | Tab of tab
  | Menu of menu
[@@deriving sexp_of]

val view
  :  ?attrs:Vdom.Attr.t list
  -> ?id:string
  -> ?size:size
  -> ?layout:layout
  -> ?has_divider:bool
  -> ?is_full_bleed:bool
  -> ?role:string
  -> ?overflow:overflow
  -> ?aria_label:string
  -> ?aria_labelledby:string
  -> value:string Bonsai.t
  -> on_change:(string -> unit Effect.t) Bonsai.t
  -> items:item list
  -> Bonsai.graph
  -> Vdom.Node.t Bonsai.t
(** [view ~value ~on_change ~items graph]. [value] is called with the string
    that selects the tab; [on_change] reports selection (clicks, menu
    activation). See the module comment for the semantics and the recorded
    divergences. *)
