(* Showcase helpers shared by the showcase page and the per-component section
   modules (sec_*.ml).

   These live in their own module so each component's showcase section can be
   a separate file — parallel ports then touch disjoint files instead of all
   fighting over one 6.5k-line showcase.ml.

   The markup is load-bearing: sections carry [data-showcase-component] and
   examples carry [data-example], and the browser gate addresses the page
   through those attributes. Do not change them without changing the gate. *)

open! Core
open! Bonsai_web

module Text = Astryx.Text

(* A placeholder box, so layout demos have something to lay out. Not a component;
   it deliberately has no data-astryx-component attribute, so component counts in
   the harness stay meaningful. *)
let chip s = Vdom.Node.span ~attrs:[ Vdom.Attr.class_ "chip" ] [ Vdom.Node.text s ]

let ex name node =
  Vdom.Node.div
    ~attrs:[ Vdom.Attr.class_ "ex"; Vdom.Attr.create "data-example" name ]
    [ Vdom.Node.div ~attrs:[ Vdom.Attr.class_ "ex-render" ] [ node ]
    ; Vdom.Node.div ~attrs:[ Vdom.Attr.class_ "ex-name" ] [ Vdom.Node.text name ]
    ]
;;

let section ~id ~title ~note examples =
  Vdom.Node.section
    ~attrs:
      [ Vdom.Attr.class_ "sec"
      ; Vdom.Attr.create "id" id
      ; Vdom.Attr.create "data-showcase-component" title
      ]
    [ Vdom.Node.h2 ~attrs:[ Vdom.Attr.class_ "sec-title" ] [ Vdom.Node.text title ]
    ; Vdom.Node.p ~attrs:[ Vdom.Attr.class_ "sec-note" ] [ Vdom.Node.text note ]
    ; Vdom.Node.div ~attrs:[ Vdom.Attr.class_ "sec-body" ] examples
    ]
;;

let label s = Astryx.Text.view ~type_:Text.Label [ Vdom.Node.text s ]

(* Every section renders values in the graph, and a section can only render unwrapped nodes. This
   Bonsai offers map2/both rather than a list combinator, so the trees are combined pairwise and
   read back by position: the names next to [nth] below make the order checkable at a glance, and a
   missing example fails loudly instead of quietly rendering the wrong node. *)
let unwrap_all nodes =
  List.fold nodes ~init:(Bonsai.return []) ~f:(fun acc node ->
    Bonsai.both acc node |> Bonsai.map ~f:(fun (acc, node) -> node :: acc))
  |> Bonsai.map ~f:List.rev
;;
