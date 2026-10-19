(** MobileNav — the slide-out drawer for mobile navigation.

    Upstream: [packages/core/src/MobileNav/MobileNav.tsx]. The mobile
    counterpart to SideNav: it accepts the same children (SideNavSection,
    SideNavItem, or anything else), and it is the drawer those components are
    shown in on a narrow viewport.

    {2 What the browser does, and what the port does}

    The drawer is a native [<dialog>] opened with [showModal()], exactly as
    upstream opens it: the top layer, the inert page behind it, the focus trap
    and the [::backdrop] are the platform's, and none of them is written here.
    What the port owns is everything upstream owns around that:

    - {b The deferred close.} The drawer slides out before the dialog leaves
      the top layer, so the native close is deferred. The delay is not a
      constant: it is derived from the CSS hold the drawer is rendered for
      (the display transition's duration, as the stylesheet computes it),
      because the hold is a theme value and a close that lands on the hold's
      boundary leaves the document inert. Upstream derives it the same way,
      and for the same reason.
    - {b The focus restoration.} Browsers are supposed to restore focus when a
      modal dialog closes, and are observed not to. The drawer captures the
      element that was focused when it opened and refocuses it — after the
      native close, never before, because the document is inert until then.
    - {b The side.} With [Auto], the edge is resolved from the trigger's own
      position: a toggle in the start half of the viewport opens the drawer
      from the start, anything else from the end.
    - {b The scroll lock}, and the scrollbar gutter that keeps the page from
      jumping sideways when the scrollbar it locked away was taking space.
    - {b The dismissal paths}: the close button, a click on the backdrop, and
      Escape (the platform's [cancel] event, which is always prevented so the
      browser cannot close a controlled dialog behind the application's back).

    {2 Divergences from upstream}

    - {b No AppShell context.} Upstream reads [isOpen] and [onOpenChange] from
      the AppShell when they are not given, and exports a
      [MobileNavToggle] that reads the same context. This port has neither:
      [is_open] and [on_open_change] are required arguments, and there is no
      toggle component. A caller wires a button to [on_open_change] itself.
    - {b No shared dismissal stack.} Upstream routes Escape through a stack
      shared by every layer, so a drawer opened over another layer takes the
      press and nothing behind it closes, and a press during an IME
      composition is declined. This port has no stack: Escape always closes
      this drawer. (The [Layer] port records the same divergence for the same
      reason.)
    - {b The resolved side lives in the DOM.} Upstream keeps it in React
      state. Here it is written to [data-astryx-side] on the root by the hook
      that opens the drawer, because the resolution has to happen at the
      moment the drawer opens — while the trigger is still the focused
      element — and a value that arrives a render later would move the drawer
      after it had already appeared.
    - {b [is_inline] is an addition.} Upstream has no such prop. It renders
      the same anatomy as ordinary markup, with no top layer and no modal
      behaviour, so a page can show the drawer without several of them
      fighting over the viewport — the same reason {!Dialog.view} has one. A
      closed inline drawer renders nothing.
    - {b No layer depth or content boundary.} Upstream wraps the drawer in
      React context providers; they render no markup, and a port has no
      context to provide.
    - {b The width.} Upstream writes [width: 100vw; max-width: Npx] on the
      drawer; the port writes [width: 100%; max-width: Npx], which resolves
      to the same thing inside the full-viewport dialog and also gives the
      inline rendering a width to resolve against. *)

open! Core
open! Bonsai_web

(** Which edge the drawer slides from. Upstream's [side] prop.

    - [Start] — the inline-start edge (left in a left-to-right page).
    - [End] — the inline-end edge (right in a left-to-right page).
    - [Auto] — the edge the trigger decides: a trigger in the start half of
      the viewport opens the drawer from the start, anything else from the
      end. The resolution happens when the drawer opens, while the trigger is
      still the focused element. *)
type side =
  | Start
  | End
  | Auto

(** The header of the drawer. Upstream's [header] prop is a ReactNode, and
    the string case is special: it is rendered as a level-two heading, and it
    names the drawer when no explicit label is given. *)
type header =
  | Title of string
      (** A plain text heading, rendered as a level-two heading. *)
  | Content of Vdom.Node.t
      (** Arbitrary content — a logo, a search field, a heading of the
          caller's own. It does not name the drawer: [label] does that. *)

val parse_shortest_duration_ms : string -> float option
(** The shortest duration in a [transition-duration] list, in milliseconds;
    [None] when the list cannot be read.

    Upstream exports the same helper for its unit tests, and the port keeps
    it public for the same reason: it is the one piece of the close timing
    that can be checked without a browser. A browser serialises a computed
    [<time>] in seconds — an authored [410ms] reads back as ["0.41s"] — and a
    list as ["0.41s, 0.12s"], so both units and the unreadable case are
    covered here.

    [parse_shortest_duration_ms "0.41s"] = [Some 410.]
    [parse_shortest_duration_ms "410ms"] = [Some 410.]
    [parse_shortest_duration_ms "0.41s, 0.12s"] = [Some 120.]
    [parse_shortest_duration_ms "var(--x)"] = [None] *)

val view
  :  ?id:string
  (** The id of the root element. Defaults to ["astryx-mobile-nav"]. *)
  -> ?header:header
  (** The header of the drawer: a title, or content of the caller's own.
      Without one the header holds the close button alone. *)
  -> ?width:int
  (** The width of the drawer, in pixels. Defaults to [320]. *)
  -> ?side:side
  (** Which edge the drawer slides from. Defaults to [Auto]. *)
  -> ?label:string
  (** The accessible name of the drawer. Defaults to the header's own text,
      and to ["Navigation"] when there is no header text — upstream's own
      fallback chain. *)
  -> ?is_inline:bool
  (** Render the drawer as ordinary markup: no top layer, no modal behaviour,
      no scroll lock, and nothing at all when the drawer is closed. This is
      the showcase path — a page can show several drawers at once. *)
  -> ?attrs:Vdom.Attr.t list
  (** Extra attributes for the root element. They are applied last, so a
      consumer can override anything above. *)
  -> is_open:bool Bonsai.t
  (** Whether the drawer is open. The drawer never opens or closes itself: it
      follows this value, and reports every dismissal through
      [on_open_change]. *)
  -> on_open_change:(bool -> unit Effect.t) Bonsai.t
  (** Called when the drawer should close — the close button, a backdrop
      click, or Escape. The caller owns the value, so the drawer closes when
      [is_open] becomes false and not before. *)
  -> children:Vdom.Node.t list Bonsai.t
  (** The drawer's content: SideNavSection/SideNavItem, or anything else. *)
  -> unit
  -> Vdom.Node.t Bonsai.t
(** [view ~is_open ~on_open_change ~children ()].

    Both [is_open] and [on_open_change] are trees, and they have to be: a
    caller holding a state setter cannot produce either as a plain value, and
    the node cannot be built before the value is known. [children] is a tree
    for the same reason.

    The close is deferred by the drawer itself: [is_open] becoming false
    starts the slide-out, and the native close follows a moment later, so the
    drawer is still in the top layer while it slides away. The focus goes
    back to the element that was focused when the drawer opened, and only
    after that close. *)
