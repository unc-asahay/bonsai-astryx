(** One term and its value: a row of {!Metadata_list}.

    The pair is returned as a [list] rather than as a single node because the two halves are separate children
    of the list grid. With inline labels the grid is two columns and the halves sit side by side; with stacked
    labels it is one column and they take a row each. A wrapper node would put both halves in one grid cell,
    and the layout the list already computed would not reach them.

    {2 Divergences}

    - Upstream reads the label position from a React context, which is how a child learns something its
      container decided. Here the list's grid decides instead, so no context travels between the two and this
      item has no position argument that could disagree with its list.
    - Upstream wraps a stacked pair in a flex column with a half-step gap. A grid row gap is a full step, so a
      stacked pair sits slightly further apart here. Recorded rather than discovered, in
      {!Metadata_list} the same way.
    - Upstream resolves the icon slot label through its i18n catalogue. The port has no catalogue, so [label]
      is a plain string.
*)
open! Core
open! Bonsai_web

val view
  :  ?attrs:Vdom.Attr.t list
  -> ?icon:Vdom.Node.t
  -> label:string
  -> children:Vdom.Node.t list
  -> unit
  -> Vdom.Node.t list
