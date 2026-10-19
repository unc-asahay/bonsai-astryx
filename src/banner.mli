(** Banner — a persistent status notification (info, warning, error, success).

    Port of upstream [Banner/Banner.tsx]. Two-part visual structure: the colored
    status header (icon, title, description, actions) and an optional
    card-background content area for richer children. The port's own judgment
    held for the slots, as upstream's does: title and description are
    [{!Vdom.Node.t} list]s — never [{!Vdom.Node.p}] — because a [<p>] cannot
    legally contain block-level children, and these slots take arbitrary
    content.

    {2 Status}

    [status] is a string, mirroring upstream's extensible [BannerStatus] (a
    theme package augments the status map with a new key, and this port cannot
    express module augmentation, so the status leaves the type system and the
    lookups stay partial). A status the port does not know falls through to the
    base visual treatment: no status fill and no default glyph. Status never
    chooses a live-region role — callers pass [role] through [attrs] when the
    semantics are appropriate, exactly as upstream says.

    {2 Disclosure}

    Children are collapsible by default: a toggle appears in the header end
    area and the content starts {b closed}. [collapsible = Never] pins the
    content open with no toggle, no [aria-expanded] and no [aria-controls], and
    the content region stays mounted. Everything else goes through
    [{!Use_collapsible}], so a banner's disclosure is configured exactly like
    [Collapsible]'s. {i Banner's one departure from the hook's defaults: it
    starts closed, not open} — the message lives in the header and the content
    is supplementary (upstream's stated rationale, reproduced here as
    [default_is_open = false] when the caller leaves it unspecified).

    {2 Dismissal}

    [is_dismissable] mounts a close button in the end area. The banner removes
    itself even when [on_dismiss] is absent — the dismissal is owned here, not
    by the caller — and [on_dismiss], when present, fires alongside it. Before
    the banner disappears, focus is handed back to the element it came from
    (recorded on [focusin] and [pointerdown capture]), so a keyboard user is
    not dropped on [<body>]: the same handoff [Toast_viewport] makes. The
    origin is kept only when it is outside the banner and is not [body], and is
    refocused only if it is still connected.

    {2 Divergences (stated rather than hidden)}

    - {b No [themeProps]} — upstream's [banner-frame], [banner], [banner-icon],
      [banner-description] and [banner-content] theme targets are not ported;
      the port styles by class, as every other component here.
    - {b Fixed English labels} where upstream resolves i18n. The dismiss
      control's default label is [dismiss_label] (default ["Dismiss"]).
      Upstream interpolates the title into it ([{v Dismiss {title} v}]) so
      stacked banners are told apart; this port has no ReactNode-to-text, so a
      caller with a string title should pass the full label (e.g.
      ["Dismiss Updates"]) and the default names only the action. The
      expand/collapse labels are [expand_label]/[collapse_label], English
      defaults.
    - {b [id] is caller-scoped, not [useId]}. Pass a distinct id per banner.
      [aria-controls] links the toggle to [<id>-content] only while the content
      is mounted, so no dangling reference exists (upstream guards the same
      way).
    - {b Unknown statuses render without the default glyph or fill} — the
      partial lookup, not an error.
    - [className]/[style]/[xstyle] are not modelled, per the port's class
      convention; [attrs] carries caller attributes last. *)

open! Core
open! Bonsai_web

type container =
  | Card
  | Section

type collapsible =
  | Never
  | Enabled of Use_collapsible.config
(** [Never] pins the content open with no toggle. [Enabled config] is the
    hook's machine: [config.default_is_open] is forced to [false] when the
    caller leaves it at [None] (see the disclosure section), [config.is_open]
    switches to controlled mode, [config.on_open_change] reports toggles. *)

val view
  :  ?attrs:Vdom.Attr.t list
  -> ?id:string
  -> ?description:Vdom.Node.t list
  -> ?icon:Vdom.Node.t
  -> ?is_dismissable:bool
  -> ?on_dismiss:(unit -> unit Effect.t)
  -> ?dismiss_label:string
  -> ?expand_label:string
  -> ?collapse_label:string
  -> ?end_content:Vdom.Node.t
  -> ?container:container
  -> ?elevation:Button.elevation
  -> ?collapsible:collapsible
  -> status:string
  -> title:Vdom.Node.t list
  -> ?children:Vdom.Node.t list
  -> Bonsai.graph
  -> Vdom.Node.t Bonsai.t
(** [view ~status ~title ()]. [status] is a string (see above); [title] is the
    header's primary line; [description] the supporting line; [icon] overrides
    the status's default glyph (the port never injects attributes into a caller
    node, so a custom icon keeps its own styling); [end_content] is the
    end-aligned action row (typically a [Button]); [container] is [Card]
    (rounded, standalone) or [Section] (full-width, square); [elevation] is the
    resting shadow, [E_none] by default.

    The default status glyphs are [info]/[warning]/[error]/[success] with the
    matching color, and the icon wrapper is [aria-hidden]: the message is the
    title and description text, and a screen reader does not need the glyph
    named twice. The header is the color surface; the content area is the card
    surface below it. *)
