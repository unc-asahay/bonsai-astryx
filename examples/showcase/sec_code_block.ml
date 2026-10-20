(* CodeBlock — the read-only code display.

   A code block shows one snippet: the code, an optional header (the file name
   and/or the language), an optional copy button, optional line numbers,
   optional soft wrapping, optional highlighted lines, a unified-diff mode and
   a collapsible body.

   The examples below are the component's real variants, not screenshots of
   them: the copy example counts the copies the component reports, and the
   collapsible example is long enough to earn its disclosure control. *)

open! Core
open! Bonsai_web

module Code_block = Astryx.Code_block
module Common = Astryx.Common

open Prelude

let demo (graph : Bonsai.graph) : Vdom.Node.t Bonsai.t =
  let ex_tree label tree = Bonsai.map tree ~f:(fun node -> ex label node) in
  (* How many times the copy button has fired, so the copy example shows the
     component's own callback rather than a static label. *)
  let copy_count, set_copy_count = Bonsai.state' 0 graph in
  let set_copy_count_f = Bonsai.map set_copy_count ~f:(fun f -> f) in
  let on_copy =
    Bonsai.map set_copy_count_f ~f:(fun set_copy_count -> fun () -> set_copy_count (fun n -> n + 1))
  in
  let copy_readout =
    Bonsai.map copy_count ~f:(fun count ->
      Vdom.Node.div ~attrs:[ Vdom.Attr.create "id" "showcase-code-block-copy-count" ]
        [ Vdom.Node.text (sprintf "copied: %d" count) ])
  in
  let js_code =
    "import {Button} from '@astryxdesign/core/Button';\n\
     \n\
     export function App() {\n\
     \  return <Button label=\"Hello\" variant=\"primary\" />;\n\
     }"
  in
  let tsx_code =
    "type Props = {\n\
     \  title: string;\n\
     \  onClose: () => void;\n\
     };\n\
     \n\
     export function Dialog({title, onClose}: Props) {\n\
     \  return (\n\
     \    <div role=\"dialog\" aria-label={title}>\n\
     \      <button onClick={onClose}>Close</button>\n\
     \    </div>\n\
     \  );\n\
     }"
  in
  let diff_code =
    "--- a/src/button.tsx\n\
     +++ b/src/button.tsx\n\
     @@ -12,7 +12,8 @@ export function Button({\n\
     -  const style = {padding: 8};\n\
     +  const style = {\n\
     +    padding: 8,\n\
     +  };\n\
     \  return <button style={style}>{label}</button>;\n\
     \ }"
  in
  let long_code =
    "const a = 1;\n\
     const b = 2;\n\
     const c = 3;\n\
     const d = 4;\n\
     const e = 5;\n\
     const f = 6;\n\
     const g = 7;\n\
     const h = 8;\n\
     const i = 9;\n\
     const j = 10;\n\
     const k = 11;\n\
     const l = 12;\n\
     return a + b + c + d + e + f + g + h + i + j + k + l;"
  in
  let default_block =
    Code_block.view ~id:"showcase-code-block-default" ~language:"javascript" ~code:js_code graph
  in
  let titled_block =
    Code_block.view
      ~id:"showcase-code-block-titled"
      ~language:"tsx"
      ~title:"dialog.tsx"
      ~code:tsx_code
      graph
  in
  let numbered_block =
    Code_block.view
      ~id:"showcase-code-block-numbered"
      ~language:"typescript"
      ~title:"dialog.tsx"
      ~has_line_numbers:true
      ~highlight_lines:[ 6; 7 ]
      ~code:tsx_code
      graph
  in
  let diff_block =
    Code_block.view
      ~id:"showcase-code-block-diff"
      ~language:"tsx"
      ~is_diff:true
      ~has_line_numbers:true
      ~code:diff_code
      graph
  in
  let wrapped_block =
    Code_block.view
      ~id:"showcase-code-block-wrapped"
      ~language:"tsx"
      ~title:"dialog.tsx"
      ~is_wrapped:true
      ~container:Code_block.Section
      ~width:"100%"
      ~code:tsx_code
      graph
  in
  let scrolling_block =
    Code_block.view
      ~id:"showcase-code-block-scrolling"
      ~language:"javascript"
      ~title:"long.js"
      ~max_height:(Common.Size_value.Px 160)
      ~code:long_code
      graph
  in
  let collapsible_block =
    Code_block.view
      ~id:"showcase-code-block-collapsible"
      ~language:"javascript"
      ~title:"long.js"
      ~is_collapsible:true
      ~collapsible_threshold:10
      ~code:long_code
      graph
  in
  let copy_block =
    Code_block.view
      ~id:"showcase-code-block-copy"
      ~language:"javascript"
      ~title:"app.js"
      ~on_copy
      ~code:js_code
      graph
  in
  let copy_example =
    Bonsai.map2 copy_block copy_readout ~f:(fun block readout ->
      Vdom.Node.div
        ~attrs:
          [ Vdom.Attr.create "id" "showcase-code-block-copy-example"
          ; Vdom.Attr.class_ "showcase-col"
          ]
        [ block; readout ])
  in
  let examples =
    [ ex_tree "a highlighted snippet" default_block
    ; ex_tree "a file title in the header" titled_block
    ; ex_tree "line numbers and a highlighted line" numbered_block
    ; ex_tree "a unified diff" diff_block
    ; ex_tree "wrapped, in a section container" wrapped_block
    ; ex_tree "a scrolling viewport" scrolling_block
    ; ex_tree "collapsible" collapsible_block
    ; ex_tree "the copy button reports the copy" copy_example
    ]
  in
  Bonsai.map (unwrap_all examples) ~f:(fun examples ->
    section
      ~id:"code-block"
      ~title:"CodeBlock"
      ~note:
        "A read-only code display. The code is syntax highlighted by the component's own \
         tokeniser and painted through spans; the header carries the file title and the \
         language. A long block can scroll inside its viewport or collapse into its header, \
         and a diff reads as one, with the glyph in its own column."
      examples)
;;
