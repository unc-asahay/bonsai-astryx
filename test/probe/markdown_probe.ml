(* A probe for the Markdown parser: it renders a document and says so. If the
   parser does not return, the probe hangs — so the probe is the guard against
   a parser that loops. The markup itself is checked by the component test,
   which runs in a document. *)

let failures = ref 0
let checks = ref 0

let check label condition =
  incr checks;
  if not condition then
    (incr failures;
     Printf.printf "  FAIL %s\n%!" label)
;;

(* The documents the probe renders. Between them they hold every block
   type, and the blocks follow one another, so the parser has to hand each
   block the lines that belong to the next one. *)
let sources =
  [ ("a heading", "# A heading\n")
  ; ( "a paragraph"
    , "A paragraph with **strong text**, *emphasis*, ~~strikethrough~~ and\n`inline code`. A [link](https://example.com/docs).\n"
    )
  ; ("a list", "- A first item\n- A second item\n")
  ; ("an ordered list", "1. The first step\n2. The second step\n")
  ; ("a quote", "> A block quote.\n")
  ; ("a fence", "```\nlet add a b = a + b\n```\n")
  ; ("a fence with a language", "```ocaml\nlet add a b = a + b\n```\n")
  ; ("a link", "A [link](https://example.com/docs).\n")
  ; ("a rejected destination", "A [bad](javascript:alert(1)) link.\n")
  ; ("an image", "A ![the alt text](image.png) image.\n")
  ; ("a break", "A paragraph.\n\n---\n\nAnother paragraph.\n")
  ; ("a list then a quote", "- item\n\n> A block quote.\n")
  ; ("a list then a fence", "- item\n\n```\ncode\n```\n")
  ; ("a quote then a list", "> A block quote.\n\n- item\n")
  ; ("a list then a paragraph", "- item\n\nA paragraph.\n")
  ; ("a paragraph then a list", "A paragraph.\n\n- item\n")
  ; ( "the whole document"
    , {|
# A heading

A paragraph with **strong text**, *emphasis*, ~~strikethrough~~ and
`inline code`. A [link](https://example.com/docs).

- A first item
- A second item

1. The first step
2. The second step

> A block quote.

```
let add a b = a + b
```
|}
    )
  ]
;;

let () =
  List.iter
    (fun (name, source) ->
      let node = Astryx.Markdown.view ~id:"md-probe" ~source () in
      check ("the document renders: " ^ name) true;
      ignore node)
    sources;
  Printf.printf "%d checks, %d failure(s)\n%!" !checks !failures;
  if !failures > 0 then exit 1
