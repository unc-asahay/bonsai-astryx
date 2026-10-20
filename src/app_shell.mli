(** AppShell — the application frame: a header, a side panel and a main content
    area, with responsive collapse and a mobile drawer.

    Upstream: [packages/core/src/AppShell/AppShell.tsx]. AppShell is the
    top-level wrapper for an application: it composes {!Layout} and gives the
    navigation slots their frame, their backgrounds and their responsive
    behaviour.

    {2 The slots}

    - [top_nav] — the top navigation. Upstream takes a ReactNode and wraps it
      in a render context so the navigation knows how it is being displayed.
    - [side_nav] — the side navigation. Same shape.
    - [banner] — a system-wide announcement, above the top navigation.
    - [children] — the main content.

    {2 The render modes, and the contexts they replace}

    Upstream threads four React contexts: {b AppShellMobileContext} (the
    mobile state), {b SideNavRenderContext}, {b TopNavRenderContext} and
    {b TopNavMobileContentContext}. A port has no context to provide, so the
    two render contexts become {e arguments}: the navigation slots are
    functions of the mode they are being rendered in.

    - {!side_nav_mode}: [Default] is the inline panel; [Drawer] is the mobile
      drawer; [Drawer_content] is the side navigation as it appears inside
      the top navigation's own drawer; [Topbar] is the collapsed mobile top
      bar.
    - {!top_nav_mode}: [Default] is the desktop header; [Mobile_bar] is the
      collapsed mobile header; [Drawer] is the combined mobile drawer.

    A caller that has no interest in a mode renders the same node for all of
    them. Upstream's {b TopNavMobileContentContext} carried the side
    navigation into the top navigation's drawer; here the drawer content is
    composed by the shell and handed to the top navigation as
    {!top_nav_render.drawer_content}, so the side navigation is rendered once
    and in one place.

    {2 The mobile state}

    Upstream's {b AppShellMobileContext} carried the mobile state to
    {!MobileNavToggle} and to the drawer. This port has no context, so:

    - the shell owns the drawer's open state — controlled by
      [config.is_open] when given, and internal otherwise;
    - the shell renders the toggle itself (upstream exports it from
      {!MobileNav}; the toggle is part of the shell's frame here);
    - the shell renders the auto-generated drawer itself, using
      {!Mobile_nav}. Upstream's drawer is rendered by the navigation
      components, which are not ported yet — so the shell owns it, and the
      drawer content is the navigation slot in [Drawer] mode.

    {2 Divergences from upstream}

    - {b No React context}, for the reasons above. The two render contexts
      are explicit arguments; the mobile state is explicit state.
    - {b The theme is not consulted.} Upstream resolves the breakpoint
      through the nearest theme's [__adaptations.widthBreakpoints]; this port
      has no theme layer and uses Astryx's default width-breakpoint map
      (sm 640, md 768, lg 1024, xl 1280, 2xl 1536).
    - {b The labels are the English catalog strings.} There is no i18n layer
      in this repository, so the skip link, the mobile bar and the toggle
      carry upstream's English text rather than a translated one.
    - {b The shell renders the drawer and the toggle}, where upstream leaves
      the drawer to the navigation components and exports the toggle from
      {!MobileNav}. The {b mobile_nav = Custom} form is the escape hatch: a
      caller who wants to own the drawer and the toggle passes its own
      element and the shell renders nothing but the slots.
    - {b No React Activity.} Upstream keeps the drawer mounted and toggles
      its visibility with [<Activity>]; here the drawer is mounted below the
      breakpoint and the open state drives {!Mobile_nav}.
    - {b No [ref] forwarding} and no [className] / [style] / [xstyle]: the
      house component API takes [attrs] instead. *)

open! Core
open! Bonsai_web

(** The navigation background style.

    - [Wash] — the navigation areas use the body background, no dividers.
    - [Surface] — the navigation areas use the surface background, no
      dividers.
    - [Section] — the navigation and the content are divided.
    - [Elevated] — the navigation uses the body background and the content
      sits on an elevated surface with a rounded corner. *)
type variant =
  | Wash
  | Surface
  | Section
  | Elevated
[@@deriving sexp_of]

(** Upstream's [height] prop: [Fill] (the shell fills the viewport and the
    content scrolls inside it, the default) or [Auto] (the shell grows with
    its content and the page scrolls as a whole). *)
type height =
  | Fill
  | Auto
[@@deriving sexp_of]

(** The named width point below which the shell collapses to the mobile
    layout. [Never] disables the mobile layout entirely. Upstream's
    [AppShellBreakpoint]. *)
type breakpoint =
  | Sm
  | Md
  | Lg
  | Xl
  | Xxl
  | Never
[@@deriving sexp_of]

(** How the side navigation is being rendered. Upstream's
    [SideNavRenderContext]. *)
type side_nav_mode =
  | Default
      (** The inline panel beside the content. *)
  | Drawer
      (** The mobile drawer. *)
  | Drawer_content
      (** Inside the top navigation's own drawer. *)
  | Topbar
      (** The collapsed mobile top bar. *)
[@@deriving sexp_of]

(** How the top navigation is being rendered. Upstream's
    [TopNavRenderContext]. *)
type top_nav_mode =
  | Default
      (** The desktop header. *)
  | Mobile_bar
      (** The collapsed mobile header. *)
  | Drawer
      (** The combined mobile drawer. *)
[@@deriving sexp_of]

(** What the top navigation is being asked to render. Upstream's
    [TopNavRenderContext] and [TopNavMobileContentContext] together. *)
type top_nav_render =
  { mode : top_nav_mode
  ; drawer_content : Vdom.Node.t option
        (** The side navigation, rendered in [Drawer_content] mode, for a top
            navigation that owns the drawer. [None] when there is no side
            navigation. *)
  }

(** The mobile navigation.

    - [Disabled] — upstream's [mobileNav={false}]: no mobile navigation at
      all.
    - [Config] — the auto behaviour, with upstream's [MobileNavConfig].
    - [Custom] — upstream's ReactNode form: the caller supplies the whole
      element (a {!Mobile_nav}, typically) and owns the open state and the
      toggle. The shell renders it as it is. *)
type mobile_nav =
  | Disabled
  | Config of config
  | Custom of Vdom.Node.t

and config =
  { has_toggle : bool
        (** Whether the shell renders the hamburger toggle itself. Upstream's
            [hasToggle]; [true] by default. *)
  ; is_open : bool Bonsai.t option
        (** The controlled open state. When given, the shell does not manage
            the state itself and only reports changes. *)
  ; on_open_change : (bool -> unit Effect.t) Bonsai.t option
        (** Called when the drawer should open or close. It is called in
            addition to the internal update, in the uncontrolled case. *)
  ; content : Vdom.Node.t option
        (** The caller's own drawer content, replacing the auto-generated
            one. Upstream's [content]. *)
  ; breakpoint : breakpoint
        (** The width point below which the shell collapses to the mobile
            layout. Upstream's [breakpoint]; [Md] by default. *)
  ; default_is_mobile : bool
        (** The server-rendered assumption: whether the first render should
            assume the mobile layout. Upstream's [defaultIsMobile]; [false] by
            default. Ignored when the [breakpoint] is [Never], which is always
            the wide layout. *)
  }

val view
  :  ?attrs:Vdom.Attr.t list
  -> ?id:string
  (** The id of the root element. Defaults to ["astryx-app-shell"]. *)
  -> ?variant:variant
  (** The navigation background style. Defaults to [Elevated]. *)
  -> ?height:height
  (** Whether the shell fills the viewport or grows with its content.
      Defaults to [Fill]. *)
  -> ?content_padding:Common.Spacing.t
  (** The padding of the main content area. Defaults to [S0], full bleed. *)
  -> ?banner:Vdom.Node.t
  (** A system-wide announcement, rendered above the top navigation. *)
  -> ?side_nav:(side_nav_mode -> Vdom.Node.t)
  (** The side navigation, and what it renders as in each mode. Omit it when
      the page has no side navigation. *)
  -> ?top_nav:(top_nav_render -> Vdom.Node.t)
  (** The top navigation, and what it renders as in each mode. Omit it when
      the page has no top navigation. *)
  -> ?mobile_nav:mobile_nav
  (** The mobile navigation. Defaults to [Config] with upstream's defaults. *)
  -> children:Vdom.Node.t list
  (** The main content. *)
  -> Bonsai.graph
  -> Vdom.Node.t Bonsai.t
(** [view ~children ()] renders the shell.

    The root element carries [data-astryx-component="AppShell"], and the
    main content carries the id [astryx-app-shell-main] that the skip link
    points at. The skip link is the first focusable element in the shell, and
    activating it moves focus to the main content, which is focusable but
    never tabbable.

    The shell is a graph because the mobile state lives in it: the drawer
    open state, the width breakpoint, and the measurements the auto-height
    mode needs. *)
