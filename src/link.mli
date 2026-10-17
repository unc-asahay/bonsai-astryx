(** A styled link: sometimes an anchor, sometimes a button, sometimes inert.

    Composed from four verified mechanisms rather than reimplemented here: [Link_destination] decides
    whether the destination may be handed on, [Interactive_role] decides which ELEMENT this is,
    [Target_and_rel] normalizes the new-tab attributes, and [Text] carries the typography.

    Two divergences, both recorded rather than silently dropped:

    - **No [tooltip] prop.** Upstream wraps the link in its Tooltip when one is given. The ported
      [Tooltip.view] takes a graph and returns a [Bonsai.t], so accepting a tooltip here would make every
      link stateful - including the ones in pure trees - for a prop most links do not pass. Wrap the link
      in [Astryx.Tooltip.view] instead; the composition is one line and the state is then the caller's.
    - **No [LinkProvider].** Upstream resolves a custom link component through a React context. A dynamic
      scope cannot reach children the caller already built, which is the same fact that makes
      [Form_layout] take [?optionality] per field. The component is passed per link.

    The three rendering branches are upstream's, in upstream's order, and the ORDER is the reason two of
    them exist at all: disabled is checked after the button branch, so a disabled link with an [on_click]
    is still a button. *)

open! Core
open! Bonsai_web
open Js_of_ocaml

(** A caller-supplied link component: upstream's [as]. It receives the resolved href and [to] (which
    defaults to the href - see [Link_destination.Routed]) plus the attributes and children. *)
type as_ =
  href:string option
  -> to_:string option
  -> attrs:Vdom.Attr.t list
  -> children:Vdom.Node.t list
  -> Vdom.Node.t

val view
  :  ?as_:as_
  -> ?label:string
  -> ?href:string
  -> ?rel:string
  -> ?target:string
  -> ?has_underline:bool
  -> ?is_disabled:bool
  -> ?is_external_link:bool
  -> ?new_tab_label:string
  -> ?is_standalone:bool
  -> ?on_click:(Dom_html.mouseEvent Js.t -> unit Effect.t)
  -> ?type_:Text.type_
  -> ?size:Text.size
  -> ?color:Text.color
  -> ?weight:Text.weight
  -> ?display:Text.display
  -> ?max_lines:int
  -> ?attrs:Vdom.Attr.t list
  -> Vdom.Node.t list
  -> Vdom.Node.t
