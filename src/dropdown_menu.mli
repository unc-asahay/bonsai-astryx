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
  -> trigger_label:string
  -> on_select:(item -> unit Bonsai.Effect.t) Bonsai.t
  -> entries:entry list
  -> Bonsai.graph
  -> Vdom.Node.t Bonsai.t
(** [view ~trigger_label ~on_select ~entries graph].

    [on_select] is a *tree* rather than a plain function, because selecting a row
    normally updates the consumer's state: the setter is itself a tree in this
    release, so the caller maps over it and hands the result in. (Button takes a
    plain callback because it holds no state the callback would close over.)

    The trigger is a ported Button; [id] names the component and is the prefix
    of the trigger's and the menu's element ids, which is what the ARIA wiring
    (`aria-controls`, `aria-labelledby`) is built from. [menu_max_height] is
    upstream's pixel cap and defaults to 300. *)
