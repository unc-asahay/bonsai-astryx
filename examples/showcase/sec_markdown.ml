(* Markdown — the markdown document.

   The document is parsed when the tree is built, so the examples below
   are pure renderings of a source string. They show the block syntax,
   the inline syntax, a link with a click handler, a fenced code block
   with the house code override, and a document with the house's own
   class added to its root. *)

open! Core
open! Bonsai_web

module Markdown = Astryx.Markdown

open Prelude

let demo (graph : Bonsai.graph) : Vdom.Node.t Bonsai.t =
  let plain =
    Bonsai.return
      (Markdown.view
         ~source:
           {|
# The release notes

A paragraph with **strong text**, *emphasis*, ~~strikethrough~~ and
`inline code`. A [link to the house](https://github.com/unc-asahay/bonsai-astryx).

- A first item
- A second item
  - A nested item
- A third item

1. The first step
2. The second step

> A block quote, in the house's own component.

---
|}
         ())
  in
  let code_block =
    Bonsai.return
      (Markdown.view
         ~source:
           {|
```ocaml
let add a b = a + b
let mul a b = a * b
```
|}
         ())
  in
  let with_code_override =
    Bonsai.return
      (Markdown.view
         ~code_block:(fun { code; language } ->
           Vdom.Node.div
             ~attrs:
               [ Vdom.Attr.class_ "astryx-code-block"
               ; Vdom.Attr.create "data-astryx-language"
                 (Option.value language ~default:"text")
               ]
             [ Vdom.Node.pre
                 ~attrs:[ Vdom.Attr.class_ "astryx-code-block__pre" ]
                 [ Vdom.Node.code ~attrs:[] [ Vdom.Node.text code ] ] ])
         ~source:
           {|
```ocaml
let add a b = a + b
```
|}
         ())
  in
  let with_class =
    Bonsai.return
      (Markdown.view
         ~class_:"astryx-markdown--narrow"
         ~source:"A document with the house's class on its root.\n"
         ())
  in
  let with_a_rejected_link =
    Bonsai.return
      (Markdown.view
         ~source:
           "A link the policy rejects: [click me](javascript:alert(1)). It renders as plain text.\n"
         ())
  in
  (* The link that reports where it goes. The document is built inside the
     map over the setter, so the click handler closes over the setter
     itself rather than over a tree. *)
  let link_click =
    let clicked, set_clicked = Bonsai.state' ("" : string) graph in
    let document =
      Bonsai.map set_clicked ~f:(fun set_clicked ->
          Markdown.view
            ~on_link_click:(fun destination ->
              Markdown.Follow (set_clicked (fun _ -> destination)))
            ~source:
              "A link that reports where it goes: [the repository](https://github.com/unc-asahay/bonsai-astryx).\n"
            ())
    in
    let readout =
      Bonsai.map clicked ~f:(fun destination ->
          Vdom.Node.div
            ~attrs:[ Vdom.Attr.create "id" "showcase-markdown-link-readout" ]
            [ Vdom.Node.text
                (if String.equal destination ""
                 then "no link was activated"
                 else "activated " ^ destination) ])
    in
    Bonsai.both document readout
    |> Bonsai.map ~f:(fun (document, readout) ->
           Vdom.Node.div ~attrs:[ Vdom.Attr.class_ "showcase-col" ] [ document; readout ])
  in
  let examples =
    [ ("a document", plain)
    ; ("a fenced code block", code_block)
    ; ("a code block the house renders", with_code_override)
    ; ("a document with a class on its root", with_class)
    ; ("a link the policy rejects", with_a_rejected_link)
    ; ("a link that reports where it goes", link_click)
    ]
  in
  let rendered =
    List.map
      ~f:(fun (label, tree) -> Bonsai.map tree ~f:(fun node -> ex label node))
      examples
  in
  let all =
    List.fold rendered ~init:(Bonsai.return []) ~f:(fun acc tree ->
      Bonsai.both acc tree |> Bonsai.map ~f:(fun (acc, tree) -> tree :: acc))
    |> Bonsai.map ~f:List.rev
  in
  Bonsai.map all ~f:(fun examples ->
      section
        ~id:"markdown"
        ~title:"Markdown"
        ~note:
          "A markdown document: the block syntax, the inline syntax, the house's own heading, code and quote, and the house's link policy."
        examples)
;;
