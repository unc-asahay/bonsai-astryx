(* Compiles the snippets that tools/mcp/astryx-mcp.mjs serves to agents.

   A snippet "copied from the demo" is a promise. Any snippet whose text is NOT a verbatim
   copy of something already compiled in examples/demo or examples/showcase is reproduced
   here, so `dune build` is what makes the claim true: if a snippet drifts from the API,
   this stops compiling and the build goes red.

   Add one function per such snippet, with a heading naming its key in snippets.json. *)

open! Core
open! Bonsai_web
module Dm = Astryx.Dropdown_menu

(* --- snippets.json / DropdownMenu --- *)
let dropdown_menu (graph : Bonsai.graph) : Vdom.Node.t Bonsai.t =
  (* the menu is a state machine, so it takes the graph and a callback tree *)
  let selected, set_selected = Bonsai.state (None : string option) graph in
  let on_select =
    Bonsai.map set_selected ~f:(fun set_selected (item : Dm.item) ->
      set_selected (Some item.id))
  in
  let entries : Dm.entry list =
    [ Dm.Item
        { Dm.id = "open"
        ; label = "Open"
        ; description = None
        ; end_content = Some (Vdom.Node.text "\xe2\x8c\x980")
        ; icon = Some "success"
        ; variant = Dm.Default
        ; is_disabled = false
        ; href = None
        ; has_close_on_select = None
        }
    ; Dm.Divider
    ; Dm.Item
        { Dm.id = "duplicate"
        ; label = "Duplicate"
        ; description = None
        ; end_content = None
        ; icon = None
        ; variant = Dm.Default
        ; is_disabled = true (* cannot take focus, so the arrow keys skip it *)
        ; href = None
        ; has_close_on_select = None
        }
    ; Dm.Heading "Danger zone"
    ]
  in
  let menu = Dm.view ~id:"menu-file" ~trigger_label:"File" ~on_select ~entries graph in
  Bonsai.map2 selected menu ~f:(fun _selected menu -> menu)
;;

(* --- snippets.json / Field --- *)
let field () : Vdom.Node.t =
  (* Field is the wrapper: the control goes in as children. *)
  Astryx.Field.view
    ~label:"Full name"
    ~input_id:"name"
    ~description:"As it should appear on an invoice."
    ~is_required:true
    ~children:[ Vdom.Node.input ~attrs:[ Vdom.Attr.id "name" ] () ]
    ()
;;

(* --- snippets.json / TextInput --- *)
let text_input (graph : Bonsai.graph) : Vdom.Node.t Bonsai.t =
  (* value and on_change are values in the graph, so a state setter goes straight in *)
  let name, set_name = Bonsai.state "" graph in
  Astryx.TextInput.view
    ~label:"Full name"
    ~id:"name"
    ~description:"As it should appear on an invoice."
    ~is_required:true
    ~status:{ Astryx.Input_types.type_ = Astryx.Input_types.Error; message = Some "That name is taken." }
    ~value:name
    ~on_change:(Bonsai.map set_name ~f:(fun set value -> set value))
    ()
;;

let () =
  ignore (dropdown_menu : Bonsai.graph -> Vdom.Node.t Bonsai.t);
  ignore (field : unit -> Vdom.Node.t);
  ignore (text_input : Bonsai.graph -> Vdom.Node.t Bonsai.t)
;;
