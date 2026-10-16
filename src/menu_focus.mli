(** Roving focus and typeahead for a menu.

    A port of upstream's [useListFocus] (vertical menu navigation) and
    [useTypeahead]. Both drive the DOM rather than a model: the highlight *is*
    DOM focus, rows are found by querying the container, and navigation moves
    focus instead of tracking an index. That is upstream's own design — "menus
    keep a single highlighted item by using DOM focus as the sole highlight
    source" — so the port keeps it. Nothing in the model can drift out of step
    with what is rendered, and hover, arrow keys and typeahead agree because they
    all end at the same [focus]. *)

open! Core
open Js_of_ocaml

type el = Dom_html.element Js.t

val item_selector : string
(** The focusable rows of one menu level, in DOM order:
    [\[role="menuitem"|"menuitemradio"|"menuitemcheckbox"\]:not(\[aria-disabled="true"\])].
    Disabled rows are excluded *by the query*, as upstream does it, so no index
    can ever point at a row that cannot take focus. *)

val items : el -> el list
(** [items container] — the rows belonging to that menu level. Rows under a
    hidden or inert ancestor inside the container are skipped (a view that a
    drill-in replaced), and so are rows whose nearest [role="menu"] is not the
    container, which keeps an inline flyout's rows out of its parent's order. *)

val current_index : el -> int
(** The index of the row that has focus, or [-1]. *)

val focus_index : el -> int -> unit
val focus_first : el -> bool
(** Whether a row was focused; [false] for an empty menu. *)

val focus_last : el -> bool

(** Run [focus_it] one frame from now. Both focus moves a menu needs have to wait for
    the DOM to settle: opening, because the row does not exist until the update that
    opens the menu has been rendered, and closing, because a browser hands focus to the
    body the moment the focused element is removed — which undoes a focus call made
    first. *)
val focus_on_next_frame : (unit -> unit) -> unit

val owns_event : el -> el -> bool
(** [owns_event container target] — whether a key event that reached [container]
    originated in this menu level rather than in a nested menu that shares
    [role="menu"] and has already handled it. A flyout renders inline, so its
    presses bubble; without this check focus would move twice, once per level. *)

val activate_row : el -> meta:bool -> ctrl:bool -> shift:bool -> alt:bool -> unit
(** [activate_row row ~meta ~ctrl ~shift ~alt] — activate a row from the
    keyboard. Upstream synthesizes a click carrying the key's modifiers (so
    ⌘-Enter on a link row opens it the way a ⌘-click would) with [detail] 0, the
    mark of a non-pointer activation. *)

val activate_current : container:el -> meta:bool -> ctrl:bool -> shift:bool -> alt:bool -> bool
(** [activate_current ~container …] — activate the row that has focus, if any.
    [false] when nothing is focused. *)

val is_modified_click : meta:bool -> ctrl:bool -> shift:bool -> alt:bool -> button:int -> bool
(** Whether a click carries a modifier or a non-primary button: on a link row the
    browser gives those a meaning of its own, so the row's own handler must not
    run and the menu must not close. *)

val handle_navigation : container:el -> key:string -> wrap:bool -> bool
(** [handle_navigation ~container ~key ~wrap] — ArrowDown / ArrowUp / Home / End
    against the container's rows. [true] when the key was one of those and was
    handled, so the caller can preventDefault it. *)

type typeahead
(** A pending typed buffer, with the inactivity timeout that clears it. Stateful
    on purpose: the buffer has to outlive a single key event. *)

val create_typeahead : ?reset_ms:int -> unit -> typeahead
(** [reset_ms] defaults to 750, upstream's value. *)

val reset : typeahead -> unit
(** Clear the buffer — the caller does this when the menu closes. *)

val handle_typeahead
  :  typeahead
  -> container:el
  -> key:string
  -> ctrl:bool
  -> meta:bool
  -> composing:bool
  -> bool
(** [handle_typeahead t ~container ~key ~ctrl ~meta ~composing] — [true] when the
    key was absorbed as a typeahead character, including when it matched no row:
    the character was consumed and must not also reach the page. The labels are
    the rows' own text, so a row's description is part of what it matches. *)
