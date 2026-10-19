(** List_item — a row of an [Astryx.List]: an [<li>] [Item].

    Composes [Item.view] with [as_:Li], so the row gets the marker, start slot,
    label + description, end slot and the interactive paths (click, link,
    delegated control, swipe layer) exactly as [Item] defines them. The list
    below decides density, dividers, markers and edge compensation through its
    own styles — see [Astryx.List] — so this row takes none of it.

    [label] and [description] take Vdom nodes and a *string* node gets
    single-line truncation automatically (Item's own rule; upstream does the same
    for a plain string). A rich node gets no wrapping constraints — again
    upstream's rule.

    The one API difference from upstream: [interactiveRef] is a React ref to a
    nested control; this port's equivalent — the delegation mechanism Item already
    has — is [interactive_selector], the selector naming the control, so the
    caller names the control by selector rather than by ref.

    Divergences (named rather than silent):

    - upstream's [use(ListContext)] is replaced by the list's CSS (see [List]).
    - [themeProps ('list-item')] has no counterpart.
    - [interactiveRef] -> [interactive_selector] (above). *)
open! Core
open! Bonsai_web
open Js_of_ocaml

(** [view ?id ?start_content ?end_content ?on_click ?interactive_selector ?href
    ?target ?rel ?is_disabled ?is_selected ?swipe_actions ?swipe_behavior
    ?description_id ?attrs ~label ?description graph]. [description_id] names the
    row's description element, for a control inside the row that wants to point at
    it with [aria-describedby] — the id is derived by [Item] when it is omitted. *)
val view
  :  ?id:string
  -> ?start_content:Vdom.Node.t
  -> ?end_content:Vdom.Node.t
  -> ?on_click:(Dom_html.mouseEvent Js.t -> unit Effect.t)
  -> ?interactive_selector:string
  -> ?href:string
  -> ?target:string
  -> ?rel:string
  -> ?is_disabled:bool
  -> ?is_selected:bool
  -> ?swipe_actions:Item.swipe_actions
  -> ?swipe_behavior:Item.swipe_behavior
  -> ?description_id:string
  -> ?attrs:Vdom.Attr.t list
  -> label:Vdom.Node.t
  -> ?description:Vdom.Node.t
  -> Bonsai.graph
  -> Vdom.Node.t Bonsai.t
