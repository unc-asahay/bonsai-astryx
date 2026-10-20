(** The upstream TopNav family: the bar, its items and its heading.

    {1 What upstream has and this port does not}

    - {b The context-driven render modes}. Upstream's bar reads its shape from
      [TopNavRenderContext]: [default] (the full bar), [mobile-bar] (heading
      plus a drawer toggle) and [drawer] (the items rendered vertically inside
      a MobileNav). The context is React's, the house has no equivalent, and
      the mobile-bar mode additionally needs upstream's [MobileNavToggle],
      which the house's {!Mobile_nav} does not carry. This port renders the
      [default] mode — the full bar — and leaves the other two to the caller:
      the house's {!Mobile_nav} is the drawer, and a caller that wants the
      mobile bar composes the heading and the end slot itself.

    - {b The router link}. Upstream's item and heading render through
      [useLinkComponent], a plain [<a>] unless a [LinkProvider] says
      otherwise. There is no provider here, so both render plain anchors.

    - {b The press-feedback controller}. Upstream's items carry
      [data-astryx-pressable] and a controller that answers it; the marker is
      here, the controller is not — it is not ported anywhere in the house yet.

    - {b Hover-to-open on the heading's menu}. Upstream's heading menu opens on
      hover, with a grace period and a click guard. This port opens it from
      the chevron, and the platform's light dismiss and Escape close it — the
      same contract {!Popover.view} offers.

    The strings are upstream's en-US defaults: ["Top navigation"] for the
    landmark, ["Open menu"] for the chevron, ["Navigation menu"] for the menu
    region.

    Every root carries [data-astryx-component]. *)

open! Core
open! Bonsai_web
open Js_of_ocaml

module Item : sig
  (** A navigation item for the bar's start slot.

      It renders an anchor. A disabled item drops the href and the target with
      it, so it cannot navigate and leaves the tab order; upstream renders it
      as a plain anchor for the same reason. An icon-only item carries the
      label as its accessible name and shows no text. *)

  val view
    :  label:string
    (** The item's label: the visible text, or the accessible name when
        [is_icon_only] is set. Upstream requires it. *)
    -> ?id:string
    -> ?href:string
    -> ?target:string
    -> ?rel:string
    -> ?icon:Vdom.Node.t
    (** An icon rendered before the label. *)
    -> ?is_selected:bool
    (** Whether the item is the current page. It carries [aria-current="page"]
        and the selected fill. *)
    -> ?is_disabled:bool
    (** Whether the item is disabled: no href, [aria-disabled], and out of the
        tab order. *)
    -> ?is_icon_only:bool
    (** Whether the item shows only its icon, with the label as its accessible
        name. *)
    -> ?on_click:(Dom_html.mouseEvent Js.t -> unit Effect.t)
    -> ?attrs:Vdom.Attr.t list
    -> Vdom.Node.t list
    (** Content rendered in place of the label. *)
    -> Vdom.Node.t
end

module Heading : sig
  (** The product/suite/account heading for the bar's heading slot.

      Upstream decides the interaction boundary from the slots that are
      filled, and this port keeps that decision:

      - no text and no menu: a logo on its own;
      - a heading link and nothing else: the whole heading is one link;
      - a menu and no links: the heading carries the menu's trigger;
      - a menu and links: the links are independent, the chevron opens the
        menu;
      - links and no menu: each link stands on its own.

      The menu opens from the chevron. Upstream opens it on hover as well; see
      the note at the top of the module. The caller owns the open flag, the way
      it owns the flag for {!Popover.view} and {!Mobile_nav.view}. *)

  val view
    :  ?id:string
    -> ?logo:Vdom.Node.t
    (** A logo rendered before the heading. *)
    -> ?logo_label:string
    (** The accessible name of the logo when it is a link and has no text of
        its own. Defaults to the heading. *)
    -> ?heading:string
    (** The product or suite name. *)
    -> ?heading_href:string
    (** Makes the heading a link. *)
    -> ?superheading:string
    (** Text above the heading. *)
    -> ?superheading_href:string
    (** Makes the superheading a link. *)
    -> ?subheading:string
    (** Text below the heading. *)
    -> ?subheading_href:string
    (** Makes the subheading a link. *)
    -> ?header_end_content:Vdom.Node.t
    (** Content rendered at the trailing edge of the heading. *)
    -> ?menu:Vdom.Node.t list
    (** The menu's items. They are rendered in a [role="menu"] region; the
        items themselves carry [role="menuitem"]. *)
    -> ?is_menu_open:bool
    (** Whether the menu is open. The heading never opens or closes it: it
        follows this value, and reports every dismissal through
        [on_menu_open_change]. *)
    -> ?on_menu_open_change:(bool -> unit Effect.t)
    -> ?attrs:Vdom.Attr.t list
    -> unit
    -> Vdom.Node.t
end

val view
  :  ?id:string
  -> ?label:string
  (** The accessible name of the navigation landmark. Defaults to
      ["Top navigation"]. *)
  -> ?heading:Vdom.Node.t
  (** The heading slot, at the left edge of the bar. *)
  -> ?start_content:Vdom.Node.t list
  (** The start slot, after the heading and left-aligned: navigation items or
      breadcrumbs. *)
  -> ?center_content:Vdom.Node.t list
  (** The center slot, horizontally centered. When it is filled the bar lays
      out as a three-column grid, so the center stays centered whatever the
      start and end slots measure. *)
  -> ?end_content:Vdom.Node.t list
  (** The end slot, at the right edge: search, icons, a profile. *)
  -> ?attrs:Vdom.Attr.t list
  -> Vdom.Node.t list
  (** An alias for [start_content], as upstream's children are. When both are
      given, [start_content] wins and these are ignored. *)
  -> Vdom.Node.t
(** The bar: a [role="navigation"] landmark with the four slots above. *)
