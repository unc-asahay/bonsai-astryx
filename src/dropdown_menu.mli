(** DropdownMenu — the menu-button core.

    Phase 1 of upstream's DropdownMenu: what the spec calls the APG Menu Button
    pattern (`AR4`). An anchored trigger that opens a `role="menu"` surface of
    rows, with roving focus, Home/End, typeahead, Escape, and Enter/Space
    activation. Sub-menus, the touch bottom sheet, and the header/footer dialog
    mode are later phases and are deliberately absent rather than half-present.

    Two decisions worth knowing before reading the code:

    - **The surface is an explicit element, not a native popover.** Upstream
      renders its menu in a native `popover="auto"` layer, which brings light
      dismissal — and, with it, a stray click on the opening release that
      upstream needs a whole press model to suppress. This port shows and hides
      an ordinary positioned element and dismisses on Escape and on focus
      leaving the component. The observable contract is the same; the top-layer
      mechanics and the press model are phase 2.
    - **Dismissal follows focus.** A menu opened with a pointer closes when
      focus leaves the trigger-and-menu subtree, which also means a click on a
      focusable control outside keeps focus where the user clicked — the
      behaviour `FR6` asks for — without a document-level listener. *)

open! Core
open! Bonsai_web

type variant =
  | Default
  | Destructive
(** [Destructive] colours the label, description and icon as an error. *)

type item =
  { id : string
  ; label : string
  ; description : string option
  ; (* Content rendered after the label/description, right-aligned — upstream's
       [endContent], which is how a keyboard hint (⌘K) reaches a row. *)
    end_content : Vdom.Node.t option
  ; icon : string option
  ; variant : variant
  ; is_disabled : bool
  ; (* When present the row *is* the anchor (`role="menuitem"` on the `<a>`), so a
       modified click keeps the browser's meaning (`FR10`). *)
    href : string option
  ; (* Whether selecting this row closes the menu. [None] means the default, which
       is to close. *)
    has_close_on_select : bool option
  }
(** A row. [id] is what [on_select] receives. *)

type entry =
  | Item of item
  | Divider
  | Heading of string
  | Group of
      { heading : string option
      ; items : item list
      }
(** [Group] is one `role="group"`, named through the heading when there is one
    (`FR14`); an untitled group is an unnamed group. *)

val view
  :  ?attrs:Vdom.Attr.t list
  -> ?id:string
  -> ?is_disabled:bool
  -> ?menu_max_height:int
  -> ?variant:Button.variant
  -> ?size:Button.size
  -> ?icon:Vdom.Node.t
  -> ?is_icon_only:bool
  -> ?trigger_component_name:string
  -> ?is_open:bool Bonsai.t
  -> ?on_open_change:(bool -> unit Bonsai.Effect.t) Bonsai.t
  -> trigger_label:string
  -> on_select:(item -> unit Bonsai.Effect.t) Bonsai.t
  -> entries:entry list
  -> Bonsai.graph
  -> Vdom.Node.t Bonsai.t
(** [view ~trigger_label ~on_select ~entries graph].

    {2 The trigger is a ported Button, configured here}

    [variant], [size], [icon] and [is_icon_only] are handed to the trigger's Button, so a menu whose
    trigger is a bare icon glyph needs nothing but those. [trigger_component_name] is for a component that
    *delegates* to this one: the marker names the thing the user sees, so a wrapper passes its own name and
    stays visible to the tools that look for markers, exactly as IconButton does.

    {2 Controlled and uncontrolled}

    [is_open] and [on_open_change] come as a pair or not at all. Pass both and the caller owns the state -
    opening, closing and everything the menu does in response report through [on_open_change]; pass neither
    and the menu owns it, which is what it has always done. Passing exactly one raises, because a caller
    who passes [is_open] alone means to control the menu and would otherwise get one that ignores it.

    {2 Not ported, and named here}

    - upstream's trigger takes a **tooltip** (MoreMenu hands it the same string as the label). The port's
      Tooltip is a separate component a caller can wrap around this one; nothing here renders one.
    - upstream's trigger renders a **chevron** unless [hasChevron] is false. The port's trigger renders
      none, in either case. Every menu currently built here wants no chevron, so the gap is named rather
      than filled with a glyph nobody asked for.
    - upstream's [placement], [alignment] and [presentation] choose where the layer surface sits. The port
      positions the menu from CSS on its own class.

    [on_select] is a *tree* rather than a plain function, because selecting a row
    normally updates the consumer's state: the setter is itself a tree in this
    release, so the caller maps over it and hands the result in. (Button takes a
    plain callback because it holds no state the callback would close over.)

    The trigger is a ported Button; [id] names the component and is the prefix
    of the trigger's and the menu's element ids, which is what the ARIA wiring
    (`aria-controls`, `aria-labelledby`) is built from. [menu_max_height] is
    upstream's pixel cap and defaults to 300. *)
