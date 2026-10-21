(* SideNav — the side navigation: a column of navigation items, with a heading
   area, a sticky top, a scrollable body, and a footer.

   Port of upstream's [packages/core/src/SideNav] — the container
   ([SideNav.tsx]), the heading ([SideNavHeading.tsx]), the item
   ([SideNavItem.tsx]) and the section ([SideNavSection.tsx]).

   Documented divergences:

   - The width is a number of pixels and the column is resized with the
     keyboard, through a separator that carries the value. Upstream resizes
     with a pointer drag on the same separator; the pointer drag is not
     implemented here, so the divider is operable with the arrow keys, Home
     and End, and says so in its label.

   - The collapsed column shows the items' icons and hides their labels. The
     labels stay in the DOM, so the items keep their accessible names.

   - Upstream's [handleRef] — an imperative handle for a collapse button
     rendered outside the column — has no counterpart in a Bonsai graph, and
     upstream's own comment says the controlled [collapsible] config is the
     way to do it, so the collapse button here takes the same state the
     column does.

   - Upstream's [as] prop chooses the element a link is rendered as. The
     house renders a link when there is an [href] and a button otherwise. *)

open! Core
open! Bonsai_web
open Js_of_ocaml

module Field_ = Field
module Attr = Common.Attr
module Icon = Icon
module Item = Item

(** The default width of the column, in pixels. *)
val default_width : float

(** The default bounds of the column's width, in pixels. *)
val default_min_width : float
val default_max_width : float

(** The width a drag or a key press moves the column by, in pixels. *)
val width_step : float

val view
  :  ?id:string
  -> ?attrs:Vdom.Attr.t list
  -> ?header:Vdom.Node.t list
  -> ?top_content:Vdom.Node.t Bonsai.t list
  -> ?footer:Vdom.Node.t list
  -> ?footer_icons:Vdom.Node.t list
  -> ?is_collapsible:bool
  -> ?default_is_collapsed:bool
  -> ?is_collapsed:bool Bonsai.t
  -> ?on_collapsed_change:(bool -> unit Effect.t) Bonsai.t
  -> ?is_resizable:bool
  -> ?default_width:float
  -> ?min_width:float
  -> ?max_width:float
  -> ?on_width_change:(float -> unit Effect.t) Bonsai.t
  -> ?children:Vdom.Node.t Bonsai.t list
  -> Bonsai.graph
  -> Vdom.Node.t Bonsai.t
(** [view ~children graph] renders the column.

    [header] is the heading area at the top, [top_content] is pinned below
    it, [children] is the scrollable body, [footer] sits above the icon bar
    and [footer_icons] is the icon bar at the bottom.

    The column collapses to an icon rail when [is_collapsible] is set. The
    collapsed state is either the application's ([is_collapsed] and
    [on_collapsed_change], both graphs) or the column's own
    ([default_is_collapsed]).

    The column is resized when [is_resizable] is set. The width is either
    the application's ([on_width_change]) or the column's own
    ([default_width]), and it is bounded by [min_width] and [max_width]. *)

val heading
  :  ?id:string
  -> ?attrs:Vdom.Attr.t list
  -> heading:string
  -> ?heading_href:string
  -> ?superheading:string
  -> ?subheading:string
  -> ?icon:string
  -> ?children:Vdom.Node.t list
  -> Bonsai.graph
  -> Vdom.Node.t
(** [heading ~heading graph] renders the heading area of the column.

    The superheading sits above the heading and the subheading below it;
    each may be a link of its own. *)

val item
  :  ?id:string
  -> ?attrs:Vdom.Attr.t list
  -> label:string
  -> ?icon:string
  -> ?selected_icon:string
  -> ?is_selected:bool
  -> ?is_disabled:bool
  -> ?href:string
  -> ?on_click:(Dom_html.mouseEvent Js.t -> unit Effect.t)
  -> ?end_content:Vdom.Node.t list
  -> ?actions:Vdom.Node.t list
  -> Bonsai.graph
  -> Vdom.Node.t Bonsai.t
(** [item ~label graph] renders one navigation item.

    The item is a link when it has an [href] and a button otherwise, and it
    reports a press through [on_click]. [selected_icon] replaces [icon] while
    the item is selected. [end_content] sits after the label and [actions] at
    the end of the row, and are only shown when the column is open. *)

val section
  :  ?id:string
  -> ?attrs:Vdom.Attr.t list
  -> title:string
  -> ?subtitle:string
  -> ?is_header_hidden:bool
  -> ?end_content:Vdom.Node.t list
  -> ?children:Vdom.Node.t Bonsai.t list
  -> Bonsai.graph
  -> Vdom.Node.t Bonsai.t
(** [section ~title ~children graph] renders a group of items under a title.

    The title and the optional subtitle are the group's header; it can be
    hidden with [is_header_hidden], and [end_content] sits at the end of the
    header. *)
