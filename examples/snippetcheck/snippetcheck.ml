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

(* --- snippets.json / TextArea --- *)
let text_area (graph : Bonsai.graph) : Vdom.Node.t Bonsai.t =
  (* rows is the height; there is no value attribute to set - the text goes in as the child *)
  let draft, set_draft = Bonsai.state "" graph in
  Astryx.TextArea.view
    ~label:"Release notes"
    ~id:"release-notes"
    ~description:"Markdown is fine; the review step renders it."
    ~is_required:true
    ~rows:4
    ~placeholder:"What changed?"
    ~value:draft
    ~on_change:(Bonsai.map set_draft ~f:(fun set value -> set value))
    ()
;;

let () =
  ignore (dropdown_menu : Bonsai.graph -> Vdom.Node.t Bonsai.t);
  ignore (field : unit -> Vdom.Node.t);
  ignore (text_input : Bonsai.graph -> Vdom.Node.t Bonsai.t);
  ignore (text_area : Bonsai.graph -> Vdom.Node.t Bonsai.t)

;;

(* --- snippets.json / Tooltip --- *)
let tooltip (graph : Bonsai.graph) : Vdom.Node.t Bonsai.t =
  (* the tooltip owns its open state, so it takes the graph; the trigger is any node *)
  Astryx.Tooltip.view
    ~id:"delete-tooltip"
    ~content:"Deletes the draft, not the published version."
    ~trigger:(Astryx.Button.view ~variant:Astryx.Button.Destructive ~label:"Delete" [])
    graph
;;

(* --- snippets.json / FormLayout --- *)
let form_layout () : Vdom.Node.t Bonsai.t =
  (* a layout is stateless AND takes plain nodes, so the field trees are resolved first — the
     container cannot reach into a child that is still a Bonsai.t, which is the same moment that
     keeps upstream's context from having an analogue here *)
  let field label id =
    Astryx.Text_input.view
      ~label
      ~id
      ~value:(Bonsai.return "")
      ~on_change:(Bonsai.return (fun (_ : string) -> Effect.Many []))
      ()
  in
  Bonsai.map2 (field "Email" "snippet-form-email") (field "Name" "snippet-form-name")
    ~f:(fun email name ->
    Astryx.Form_layout.view
      ~direction:Astryx.Form_layout.Horizontal
      ~children:[ email; name; Astryx.Button.view ~label:"Save" [] ]
      ())
;;

(* A dialog's two arguments are trees straight from the state — the component returns a tree itself,
   so wrapping it in a map2 would nest one tree inside another. The children stay plain nodes, which
   is why a close button inside needs no callback: <form method="dialog"> closes it, and the
   component reports that through on_open_change. *)
let dialog (graph : Bonsai.graph) =
  let is_open, set_is_open = Bonsai.state false graph in
  let heading =
    Vdom.Node.div ~attrs:[ Vdom.Attr.create "id" "snippet-dialog-title" ] [ Vdom.Node.text "Settings" ]
  in
  let body = Vdom.Node.div [ Vdom.Node.text "Body" ] in
  let save_form =
    Vdom.Node.create "form" ~attrs:[ Vdom.Attr.create "method" "dialog" ]
      [ Astryx.Button.view ~label:"Save" [] ]
  in
  Astryx.Dialog.view
    ~purpose:Astryx.Dialog.Info
    ~labelled_by:"snippet-dialog-title"
    ~is_open
    ~on_open_change:(Bonsai.map set_is_open ~f:(fun set_is_open value -> set_is_open value))
    ~id:"snippet-dialog"
    ~children:(Bonsai.return [ heading; body; save_form ])
    ()
;;

let () =
  ignore (tooltip : Bonsai.graph -> Vdom.Node.t Bonsai.t);
  ignore (form_layout : unit -> Vdom.Node.t Bonsai.t);
  ignore (dialog : Bonsai.graph -> Vdom.Node.t Bonsai.t)
