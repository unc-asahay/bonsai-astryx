(* Toast — mirrors Astryx's Toast/Toast.tsx, ToastViewport.tsx, types.ts,
   useToast.tsx and useToastGesture.ts.

   {1 What this is}

   A toast is a transient notification. The system has three parts:

   - the *card* — one notification, with its live region, its body, its
     trailing slot, its dismiss control, its auto-hide timer and the
     swipe-to-dismiss gesture;
   - the *viewport* — the fixed stack the cards live in: where it sits, how
     many cards show at once, how a card enters and leaves, how a new toast
     is announced, and where the F6 key sends the focus;
   - the *list* — the toasts themselves, which the *application* owns.

   {2 The list belongs to the application}

   Upstream keeps the list inside the viewport's React context, and
   [useToast] hands the application a [show] function. A React context can
   hold a list that grows while the component is mounted; a Bonsai graph
   cannot - its shape is fixed when the graph is built. So the application
   holds the list and hands it to the viewport as a value:

   {[
     let toasts, set_toasts = Bonsai.state' [] graph in
     let on_dismiss =
       Bonsai.map2 toasts set_toasts ~f:(fun toasts set_toasts ->
         fun id _reason ->
           set_toasts (fun toasts ->
             List.filter toasts ~f:(fun (entry : Toast.entry) ->
               not (String.equal entry.id id))))
     in
     Astryx.Toast.viewport ~toasts ~on_dismiss graph
   ]}

   [Toast.add] is the port of upstream's [addToast]: it honours the unique id
   and the collision behaviour, so the application's [show] is one line.
   [Bonsai.state'] rather than [Bonsai.state] is what makes a dismissal safe
   when two toasts go at once: the updater sees the list as it is when the
   effect runs, not as it was when the callback was built.

   The viewport tells the application when a toast should leave the list -
   when it has been dismissed *and* its exit animation is over. The card
   never touches the list itself.

   {1 Accessibility}

   Reproduced from upstream, not approximated:

   - the card is a live region: [role="status"] with [aria-live="polite"]
     for an info toast, [role="alert"] with [aria-live="assertive"] for an
     error one, and [aria-atomic="true"] on both;
   - the viewport mounts two *empty* live regions on the document body and
     writes the text of a new toast into them afterwards. A live region that
     is created together with its content is "born with content", and many
     screen readers do not announce that - this is upstream's
     [useAnnounce], and the guarantee is the reason for the extra regions;
   - only the body is announced. The trailing slot is reachable with F6, and
     reading it aloud would say the dismiss control's name twice;
   - F6 moves the focus into the newest toast and remembers where it came
     from, so the focus can be handed back when the last toast goes;
   - the dismiss control is a labelled button ("Dismiss notification"), so
     the card can always be closed from the keyboard.

   {1 Keyboard}

   The card itself has no key handling of its own: the dismiss control is a
   real button, and the viewport's F6 shortcut is the only shortcut. The
   swipe gesture is a pointer gesture, not a keyboard one, and upstream's
   [useToastGesture] offers no keyboard equivalent either.

   {1 Divergences from upstream}

   - *No portal.* Upstream mounts the viewport through a Layer, so the stack
     floats above the page from a portal. This port's [Layer] has no portal
     - layers render in place - so the viewport is a [position: fixed]
     element wherever the application puts it. This is a standing divergence
     of the port, not of this component; see {!Astryx.Layer}.
   - *No theme.* Upstream wraps the card in a MediaTheme, which measures the
     surface and picks the readable side of it. This port has no theme layer
     and no media query plumbing, so the card uses the inverted surface
     tokens directly: [light-dark()] on the background and the matching
     on-dark/on-light text token.
   - *No module-owned registry.* Upstream's [useToast] works without a
     provider by falling back to a module-level default viewport. The port
     has no global state: the application owns the list, and mounts the
     viewport it wants. See "The list belongs to the application" above.
   - *No SSR guard.* Upstream's [useToast] returns a no-op before the window
     exists. The port renders in the browser only.
   - *The auto-hide notification is relayed.* The timer fires outside any
     event handler, so the standalone card passes the dismissal through a
     value the graph holds and the notification runs when that value changes.
     The callback the application sees is the one from the render in which
     the toast was dismissed.
   - *The list has no creation time.* Upstream's entry records one; nothing
     in the ported behaviour reads the clock, so the port does not keep it. *)

open! Core
open! Bonsai_web

type type_ =
  | Info
  | Error
(** The toast's status. Upstream's [ToastType]: it picks the surface colour
    and, for [Error], the assertive live region. *)

type position =
  | Top_end
  | Top_start
  | Bottom_end
  | Bottom_start
(** Where the stack sits. Upstream's [ToastPosition], and a *logical* one:
    "start" is the left in a left-to-right document and the right in a
    right-to-left one. *)

type dismiss_reason =
  | Auto
  | Manual
(** Why a toast went away. Upstream's [ToastDismissReason]. [Auto] is the
    timer running out; [Manual] is the dismiss control, or a swipe. *)

type collision_behavior =
  | Overwrite
  | Ignore
(** What happens when a toast arrives with a [unique_id] that is already in
    the list. Upstream's [ToastCollisionBehavior]. *)

type options =
  { body : Vdom.Node.t
  ; type_ : type_
  ; is_auto_hide : bool
  ; auto_hide_duration : float
  ; end_content : Vdom.Node.t option
  ; unique_id : string option
  ; collision_behavior : collision_behavior
  ; on_hide : (dismiss_reason -> unit Effect.t) option
  }
(** One toast's settings. Upstream's [ToastOptions].

    - [body]: the toast's content.
    - [type_]: [Info] (polite) or [Error] (assertive).
    - [is_auto_hide]: whether the toast dismisses itself. Upstream's default
      is per type: an info toast is transient, an error toast is not.
    - [auto_hide_duration]: milliseconds on the clock. The clock pauses
      while the pointer or the focus is on the toast, and while the window
      is not focused, and it always keeps at least a second.
    - [end_content]: a trailing slot, next to the dismiss control. It is
      reachable with F6 but is not announced.
    - [unique_id]: the toast's identity for collision purposes. It is not
      the DOM id.
    - [collision_behavior]: what a new toast with a [unique_id] already in
      the list does. See {!add}.
    - [on_hide]: called when the toast is dismissed - when it is dismissed,
      not when its exit animation is over. *)

type entry =
  { id : string
  ; options : options
  }
(** One toast in the list: its identity plus its settings. Upstream's
    [ToastEntry] (whose [createdAt] the port does not need - nothing in the
    ported behaviour reads the clock). *)

type content =
  { body : Vdom.Node.t
  ; end_content : Vdom.Node.t option
  ; type_ : type_
  ; is_auto_hide : bool
  ; auto_hide_duration : float
  ; dismiss : (unit -> unit Effect.t)
  }
(** What a custom renderer is handed. Upstream's [ToastContentRenderProps]:
    the toast's own content and settings, plus the [dismiss] callback the
    renderer wires to whichever control should close the toast. *)

val options
  :  ?body:Vdom.Node.t
  -> ?type_:type_
  -> ?is_auto_hide:bool
  -> ?auto_hide_duration:float
  -> ?end_content:Vdom.Node.t
  -> ?unique_id:string
  -> ?collision_behavior:collision_behavior
  -> ?on_hide:(dismiss_reason -> unit Effect.t)
  -> unit
  -> options
(** One toast's settings, with upstream's defaults: [type_] is [Info], the
    auto-hide follows the type (on for [Info], off for [Error]), the
    duration is five seconds, and a new toast overwrites the one holding
    its unique id. *)

val entry : ?id:string -> options -> entry
(** One toast, with an identity. The id is what the viewport's rows are keyed
    by, and what a dismissal names. Without one the toast gets a fresh
    [astryx-toast-N] id. *)

val add : entry list -> entry -> entry list
(** Upstream's [addToast]: the list with the toast added.

    A toast without a [unique_id] is appended. A toast with one either
    replaces the toast already holding that id - in place, so the new entry
    takes the old one's seat in the stack - or is dropped, depending on the
    collision behaviour. *)

val remove : entry list -> string -> entry list
(** The other half of upstream's [removeToast]: the list without the toast
    with that id. *)

val view
  :  ?attrs:Vdom.Attr.t list
  -> ?id:string
  -> ?type_:type_
  -> ?body:Vdom.Node.t
  -> ?end_content:Vdom.Node.t
  -> ?is_auto_hide:bool
  -> ?auto_hide_duration:float
  -> ?is_exiting:bool
  -> ?render_content:(content -> Vdom.Node.t)
  -> ?on_dismiss:(dismiss_reason -> unit Effect.t) Bonsai.t
  -> Bonsai.graph
  -> Vdom.Node.t Bonsai.t
(** One toast, on its own. Upstream's [Toast], which upstream exports "for
    inline rendering in previews and documentation".

    The card is a live region ([role="status"] for an info toast,
    [role="alert"] for an error one), and it carries the dismiss control
    unless [render_content] replaces the content: upstream does not inject a
    fallback control into custom content, so a custom renderer is given the
    [dismiss] callback and wires it up itself.

    The auto-hide timer pauses while the pointer or the focus is on the card,
    and while the window is not focused. The card can be swiped away with a
    finger or a pen - a drag towards the card's own edge dismisses it, and
    the card follows the finger while it is being dragged.

    [on_dismiss] is called with the reason: [Auto] when the timer runs out,
    [Manual] when the dismiss control is used or the card is swiped. The
    card does not hide itself - the caller decides what a dismissed toast
    does. [is_exiting] is the caller's way of playing the exit animation
    before it takes the toast away. *)

val viewport
  :  ?attrs:Vdom.Attr.t list
  -> ?id:string
  -> ?position:position
  -> ?max_visible:int
  -> ?label:string
  -> toasts:entry list Bonsai.t
  -> on_dismiss:(string -> dismiss_reason -> unit Effect.t) Bonsai.t
  -> Bonsai.graph
  -> Vdom.Node.t Bonsai.t
(** The stack the toasts live in. Upstream's [ToastViewport].

    [toasts] is the application's list, oldest first: the viewport shows the
    last [max_visible] of them, and the newest is the one nearest the
    [position] corner. [on_dismiss] is called with the toast's id and the
    reason when the toast should leave the list - which is after its exit
    animation, not when it is dismissed. The application removes the toast
    then.

    The viewport is a [role="region"] with an accessible name while there
    are toasts to show, and it is not one when there are none. It writes the
    text of a new toast into a live region, and F6 moves the focus into the
    newest toast.

    The viewport renders in place, not in a portal: see "Divergences from
    upstream". *)
