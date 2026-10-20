(** Typeahead — a text field with a filtered list of suggestions.

    Upstream ships the family as three components: [BaseTypeahead] (the unstyled combobox),
    [Typeahead] (the styled field around it) and [TypeaheadItem] (the default row). The port
    keeps those three boundaries inside one module: {!Base} is the unstyled combobox, {!Item}
    is the default row, and [view] is the styled field.

    The query text, the result list, the highlighted option and whether the list is open are
    the component's own state. The application owns the selection ([value] / [on_change]).

    The search source is synchronous: [search] is a plain function of the query. There is no
    debounce and no busy state, because there is never a search in flight to report — the
    same contract the Tokenizer port settled on. *)

(* This library's own Field, bound before the opens below. Core defines a module named Field as
   well (first-class fields), so after [open! Core] the unqualified name refers to Core's — and
   this module would silently fail to compile against it. *)
module Field_ = Field

open! Core
open! Bonsai_web
open Js_of_ocaml

type 'a item =
  { id : string
  ; label : string
  ; group : string option
  ; auxiliary_data : 'a
  ; element : Vdom.Node.t option
  }

type 'a source =
  { search : string -> 'a item list
  ; bootstrap : unit -> 'a item list
  }

(* A substring test that does not depend on [Str] or on a Core helper's argument order. *)
let contains_substring ~needle haystack =
  let needle_length = String.length needle in
  let haystack_length = String.length haystack in
  if needle_length = 0 then
    true
  else if needle_length > haystack_length then
    false
  else
    let found = ref false in
    let index = ref 0 in
    while (not !found) && !index <= haystack_length - needle_length do
      if String.equal (String.sub haystack ~pos:!index ~len:needle_length) needle then
        found := true
      else
        incr index
    done;
    !found

let create_static_source ?keywords items =
  let keywords =
    match keywords with
    | Some keywords -> keywords
    | None -> (fun (_ : 'a item) -> [])
  in
  let matches item query =
    let query = String.lowercase query in
    String.equal query ""
    || List.exists
         (String.lowercase item.label :: keywords item)
         ~f:(fun keyword -> contains_substring ~needle:query (String.lowercase keyword))
  in
  { search = (fun query -> List.filter items ~f:(fun item -> matches item query))
  ; bootstrap = (fun () -> items)
  }

module Item = struct
  let view ?icon ?description ?(is_disabled = false) item =
    let icon_node =
      match icon with
      | Some icon ->
        Some
          (Vdom.Node.create "div"
             ~attrs:[ Vdom.Attr.class_ "astryx-typeahead-item__icon" ]
             [ icon ])
      | None -> None
    in
    let description_node =
      match description with
      | Some description ->
        Some
          (Vdom.Node.create "div"
             ~attrs:[ Vdom.Attr.class_ "astryx-typeahead-item__description" ]
             [ Vdom.Node.text description ])
      | None -> None
    in
    let body =
      match item.element with
      | Some element -> element
      | None ->
        Vdom.Node.create "div"
          ~attrs:[ Vdom.Attr.class_ "astryx-typeahead-item__content" ]
          (List.filter_map
             [ icon_node
             ; Some
               (Vdom.Node.create "div"
                  ~attrs:[ Vdom.Attr.class_ "astryx-typeahead-item__label" ]
                  [ Vdom.Node.text item.label ])
             ; description_node
             ]
             ~f:(fun node -> node))
    in
    Vdom.Node.create "div"
      ~attrs:
        [ Vdom.Attr.class_
            ("astryx-typeahead-item"
            ^ if is_disabled then " astryx-typeahead-item--disabled" else "")
        ]
      [ body ]
end

(* The shared implementation. {!Base.view} and the styled [view] are the same control with
   different chrome, so the state machine lives here and both call it. *)
module Internal = struct
  type 'a state =
    { query : string  (** the text in the input *)
    ; results : 'a item list  (** the items the menu shows right now *)
    ; highlighted : int  (** the index of the highlighted option, [-1] for none *)
    ; is_open : bool  (** whether the menu is open *)
    ; has_searched : bool  (** whether the current query was searched for *)
    }

  type 'a env =
    { model : 'a state
    ; value : 'a item option
    ; set_model : 'a state -> unit Effect.t
    ; on_change : 'a item option -> unit Effect.t
    ; on_query_change : string -> unit Effect.t
    ; on_open_change : bool -> unit Effect.t
    }

  let view
      ?id
      ?placeholder
      ?(is_disabled = false)
      ?(is_focusable_disabled = false)
      ?(has_auto_focus = false)
      ?(has_entries_on_focus = true)
      ?(max_menu_items = 10)
      ?(min_query_length = 1)
      ?(empty_search_text = "No results found")
      ?(has_clear = false)
      ?start_icon
      ?render_item
      ?on_change
      ?on_query_change
      ?on_open_change
      ~(attrs : Vdom.Attr.t list)
      ~(source : 'a source)
      ~(value : 'a item option Bonsai.t)
      (graph : Bonsai.graph)
    : Vdom.Node.t Bonsai.t =
    let initial =
      { query = ""; results = []; highlighted = -1; is_open = false; has_searched = false }
    in
    let model, set_model_tree = Bonsai.state initial graph in
    (* The setter is a tree; the environment wants the plain function. *)
    let set_model = Bonsai.map set_model_tree ~f:(fun f -> f) in
    let listbox_id =
      match id with
      | Some id -> id ^ "-listbox"
      | None -> "astryx-typeahead-listbox"
    in
    let input_id =
      match id with
      | Some id -> id ^ "-input"
      | None -> "astryx-typeahead-input"
    in
    let option_id index = listbox_id ^ "-option-" ^ string_of_int index in
    (* The callbacks arrive as trees. The environment wants the plain functions, so each
       optional tree becomes either the caller's function or a no-op. *)
    let no_change (_ : 'a item option) = Effect.Ignore in
    let no_query_change (_ : string) = Effect.Ignore in
    let no_open_change (_ : bool) = Effect.Ignore in
    let on_change_f =
      match on_change with
      | None -> Bonsai.return no_change
      | Some tree -> Bonsai.map tree ~f:(fun f -> f)
    in
    let on_query_change_f =
      match on_query_change with
      | None -> Bonsai.return no_query_change
      | Some tree -> Bonsai.map tree ~f:(fun f -> f)
    in
    let on_open_change_f =
      match on_open_change with
      | None -> Bonsai.return no_open_change
      | Some tree -> Bonsai.map tree ~f:(fun f -> f)
    in
    let env =
      let env =
        Bonsai.map2 model value ~f:(fun model value ->
          { model
          ; value
          ; set_model = (fun (_ : 'a state) -> Effect.Ignore)
          ; on_change = no_change
          ; on_query_change = no_query_change
          ; on_open_change = no_open_change
          })
      in
      let env =
        Bonsai.map2 env set_model ~f:(fun env set_model -> { env with set_model })
      in
      let env = Bonsai.map2 env on_change_f ~f:(fun env on_change -> { env with on_change }) in
      let env =
        Bonsai.map2 env on_query_change_f ~f:(fun env on_query_change ->
            { env with on_query_change })
      in
      let env =
        Bonsai.map2 env on_open_change_f ~f:(fun env on_open_change ->
            { env with on_open_change })
      in
      env
    in
    let report_open env is_open = env.on_open_change is_open in
    let apply env next extra =
      let effects =
        [ env.set_model next ]
        @ (if not (Bool.equal next.is_open env.model.is_open) then
             [ report_open env next.is_open ]
           else [])
        @ extra
      in
      Effect.Many effects
    in
    let close env =
      let state = env.model in
      if state.is_open then apply env { state with is_open = false } [] else Effect.Ignore
    in
    let query_changed env text =
      let next =
        if String.length text < min_query_length then
          { query = text; results = []; highlighted = -1; is_open = false; has_searched = false }
        else
          { query = text
          ; results = List.take (source.search text) max_menu_items
          ; highlighted = -1
          ; is_open = true
          ; has_searched = true
          }
      in
      apply env next [ env.on_query_change text ]
    in
    let focused env =
      let state = env.model in
      if state.is_open then
        Effect.Ignore
      else
        let results =
          if state.has_searched then
            state.results
          else if has_entries_on_focus then
            List.take (source.bootstrap ()) max_menu_items
          else
            []
        in
        apply env { state with results; is_open = true; highlighted = -1 } []
    in
    let move_highlight env delta =
      let state = env.model in
      let count = List.length state.results in
      if count = 0 then
        Effect.Ignore
      else
        let next =
          if state.highlighted < 0 then
            if delta > 0 then 0 else count - 1
          else
            (state.highlighted + delta + count) mod count
        in
        env.set_model { env.model with highlighted = next }
    in
    let select env item =
      let next =
        { query = item.label
        ; results = []
        ; highlighted = -1
        ; is_open = false
        ; has_searched = false
        }
      in
      apply env next [ env.on_change (Some item) ]
    in
    let clear env =
      let next =
        { query = ""
        ; results = []
        ; highlighted = -1
        ; is_open = false
        ; has_searched = false
        }
      in
      apply env next [ env.on_change None ]
    in
    let keydown env event =
      let key = Js.Unsafe.get event "key" in
      match key with
      | "ArrowDown" -> move_highlight env 1
      | "ArrowUp" -> move_highlight env (-1)
      | "Home" ->
        if List.length env.model.results = 0 then
          Effect.Ignore
        else
          env.set_model { env.model with highlighted = 0 }
      | "End" ->
        let count = List.length env.model.results in
        if count = 0 then
          Effect.Ignore
        else
          env.set_model { env.model with highlighted = count - 1 }
      | "Enter" ->
        (match List.nth env.model.results env.model.highlighted with
         | Some item -> select env item
         | None -> Effect.Ignore)
      | "Escape" -> close env
      | _ -> Effect.Ignore
    in
    let render env =
      let state = env.model in
      let option_node index item =
        let is_highlighted = state.highlighted = index in
        let is_selected =
          match env.value with
          | Some value -> String.equal value.id item.id
          | None -> false
        in
        let content =
          match render_item with
          | Some render_item -> render_item item
          | None -> Item.view item
        in
        Vdom.Node.create "div"
          ~attrs:
            [ Vdom.Attr.id (option_id index)
            ; Vdom.Attr.role "option"
            ; Vdom.Attr.class_
                ("astryx-typeahead__option"
                ^ if is_highlighted then " astryx-typeahead__option--highlighted" else "")
            ; Vdom.Attr.create "aria-selected" (Bool.to_string is_selected)
            ; Vdom.Attr.tabindex (-1)
            ; Vdom.Attr.on_mousedown (fun event ->
                Common.prevent_default event;
                Effect.Ignore)
            ; Vdom.Attr.on_click (fun _ -> select env item)
            ]
          [ content ]
      in
      let indexed = List.mapi state.results ~f:(fun index item -> (index, item)) in
      let rec group_runs finished current_group current_items rest =
        match rest with
        | [] ->
          List.rev
            (match current_items with
             | [] -> finished
             | _ -> (current_group, current_items) :: finished)
        | (index, item) :: tail ->
          (match current_items with
           | [] -> group_runs finished item.group [ (index, item) ] tail
           | (_, first) :: _ ->
             if Option.equal String.equal first.group item.group then
               group_runs finished current_group (current_items @ [ (index, item) ]) tail
             else
               group_runs
                 ((current_group, current_items) :: finished)
                 item.group [ (index, item) ] tail)
      in
      let runs = group_runs [] None [] indexed in
      let rec render_runs runs =
        match runs with
        | [] -> []
        | (group, items) :: rest ->
          let options = List.map items ~f:(fun (index, item) -> option_node index item) in
          let children =
            match group with
            | Some group ->
              [ Vdom.Node.create "div"
                  ~attrs:
                    [ Vdom.Attr.role "group"
                    ; Vdom.Attr.create "aria-label" group
                    ; Vdom.Attr.class_ "astryx-typeahead__group"
                    ]
                  options
              ]
            | None -> options
          in
          children @ render_runs rest
      in
      let menu =
        match state.results with
        | [] ->
          if state.has_searched then
            [ Vdom.Node.create "div"
                ~attrs:[ Vdom.Attr.class_ "astryx-typeahead__empty" ]
                [ Vdom.Node.text empty_search_text ]
            ]
          else []
        | _ -> render_runs runs
      in
      let listbox =
        Vdom.Node.create "div"
          ~attrs:
            [ Vdom.Attr.id listbox_id
            ; Vdom.Attr.role "listbox"
            ; Vdom.Attr.class_ "astryx-typeahead__listbox"
            ; Vdom.Attr.create "aria-label" "Search results"
            ]
          menu
      in
      let input_attrs =
        [ Vdom.Attr.id input_id
        ; Vdom.Attr.class_ "astryx-typeahead__input"
        ; Vdom.Attr.value state.query
        ; Vdom.Attr.role "combobox"
        ; Vdom.Attr.create "aria-expanded" (Bool.to_string state.is_open)
        ; Vdom.Attr.create "aria-controls" listbox_id
        ; Vdom.Attr.create "aria-autocomplete" "list"
        ]
        @ (if state.highlighted >= 0 then
             [ Vdom.Attr.create "aria-activedescendant" (option_id state.highlighted) ]
           else [])
        @ (match placeholder with
           | Some placeholder -> [ Vdom.Attr.placeholder placeholder ]
           | None -> [])
        @ (if is_disabled then [ Vdom.Attr.disabled' true ] else [])
        @ (if is_focusable_disabled then [ Vdom.Attr.create "aria-disabled" "true" ] else [])
        @ (if is_focusable_disabled then [ Vdom.Attr.readonly ] else [])
        @ (if has_auto_focus then [ Vdom.Attr.autofocus true ] else [])
        @ [ Vdom.Attr.on_input (fun _ text -> query_changed env text)
          ; Vdom.Attr.on_focus (fun _ -> focused env)
          ; Vdom.Attr.on_blur (fun _ -> close env)
          ; Vdom.Attr.on_keydown (fun event -> keydown env event)
          ]
        @ attrs
      in
      let input = Vdom.Node.create "input" ~attrs:input_attrs [] in
      let clear_button =
        match env.value with
        | None -> []
        | Some _ ->
          if not has_clear then
            []
          else
            [ Vdom.Node.create "button"
                ~attrs:
                  [ Vdom.Attr.type_ "button"
                  ; Vdom.Attr.class_ "astryx-typeahead__clear"
                  ; Vdom.Attr.create "aria-label" "Clear"
                  ; Vdom.Attr.on_click (fun _ -> clear env)
                  ]
                [ Vdom.Node.text "×" ]
            ]
      in
      let start_icon_node =
        match start_icon with
        | None -> []
        | Some start_icon ->
          [ Vdom.Node.create "div"
              ~attrs:[ Vdom.Attr.class_ "astryx-typeahead__start-icon" ]
              [ Icon.view ~name:start_icon () ]
          ]
      in
      let announcement =
        match state.results with
        | [] -> (if state.has_searched then "No results found" else "")
        | results -> string_of_int (List.length results) ^ " results available"
      in
      Vdom.Node.create "div"
        ~attrs:[ Vdom.Attr.class_ "astryx-typeahead" ]
        [ Vdom.Node.create "div"
            ~attrs:[ Vdom.Attr.class_ "astryx-typeahead__control" ]
            (start_icon_node @ [ input ] @ clear_button)
        ; listbox
        ; Vdom.Node.create "div"
            ~attrs:
              [ Vdom.Attr.class_ "astryx-typeahead__live-region"
              ; Vdom.Attr.create "aria-live" "polite"
              ]
            [ Vdom.Node.text announcement ]
        ]
    in
    Bonsai.map env ~f:render
end

module Base = struct
  let view
      ?id
      ?placeholder
      ?(is_disabled = false)
      ?(is_focusable_disabled = false)
      ?(has_auto_focus = false)
      ?(has_entries_on_focus = true)
      ?(max_menu_items = 10)
      ?(min_query_length = 1)
      ?(empty_search_text = "No results found")
      ?render_item
      ?on_change
      ?on_query_change
      ?on_open_change
      ?(attrs : Vdom.Attr.t list option)
      ~(source : 'a source)
      ~(value : 'a item option Bonsai.t)
      (graph : Bonsai.graph)
    : Vdom.Node.t Bonsai.t =
    Internal.view
      ?id
      ?placeholder
      ~is_disabled
      ~is_focusable_disabled
      ~has_auto_focus
      ~has_entries_on_focus
      ~max_menu_items
      ~min_query_length
      ~empty_search_text
      ?render_item
      ?on_change
      ?on_query_change
      ?on_open_change
      ~attrs:(Option.value ~default:[] attrs)
      ~source
      ~value
      graph
end

let view
    ?id
    ?description
    ?(is_label_hidden = false)
    ?(is_required = false)
    ?(is_optional = false)
    ?status
    ?status_variant
    ?start_icon
    ?width
    ?(size = Input_types.Md)
    ?placeholder
    ?(is_disabled = false)
    ?(has_clear = false)
    ?(has_auto_focus = false)
    ?(has_entries_on_focus = true)
    ?(max_menu_items = 10)
    ?(min_query_length = 1)
    ?(empty_search_text = "No results found")
    ?render_item
    ?on_change
    ?on_query_change
    ?on_open_change
    ?(attrs : Vdom.Attr.t list option)
    ~(source : 'a source)
    ~(value : 'a item option Bonsai.t)
    ~(label : string)
    (graph : Bonsai.graph)
  : Vdom.Node.t Bonsai.t =
  (* The input's id has to be the same in the field's label and in the
     control, so it is derived once, here, and the same way the control
     derives it. *)
  let input_id =
    match id with
    | Some id -> id ^ "-input"
    | None -> "astryx-typeahead-input"
  in
  let control =
    Internal.view
      ?id
      ?placeholder
      ~is_disabled
      ~has_auto_focus
      ~has_entries_on_focus
      ~max_menu_items
      ~min_query_length
      ~empty_search_text
      ~has_clear
      ?start_icon
      ?render_item
      ?on_change
      ?on_query_change
      ?on_open_change
      ~attrs:(Option.value ~default:[] attrs)
      ~source
      ~value
      graph
  in
  let control =
    Bonsai.map control ~f:(fun control ->
        Vdom.Node.create "div"
          ~attrs:
            [ Vdom.Attr.class_
                ("astryx-typeahead--"
                ^ (match size with
                   | Input_types.Sm -> "sm"
                   | Input_types.Md -> "md"
                   | Input_types.Lg -> "lg"))
            ]
          [ control ])
  in
  (* The field chrome. The control is a tree and Field.view wants a plain node, so the label
     group is built here and the two are joined with a map. *)
  let description_id = input_id ^ "-desc" in
  let marker =
    if is_required then
      [ Vdom.Node.span
          ~attrs:(Common.Attr.class_ [ "astryx-field__marker" ])
          [ Vdom.Node.text "*" ] ]
    else if is_optional then
      [ Vdom.Node.span
          ~attrs:(Common.Attr.class_ [ "astryx-field__marker" ])
          [ Vdom.Node.text "(optional)" ] ]
    else []
  in
  let label_node =
    Vdom.Node.label
      ~attrs:
        ([ Vdom.Attr.create "for" input_id ]
         @ Common.Attr.class_ [ "astryx-field__label" ])
      ([ Vdom.Node.text label ] @ marker)
  in
  let description_node =
    match description with
    | Some description ->
      Some
        (Vdom.Node.create "div"
           ~attrs:
             ([ Vdom.Attr.id description_id ]
              @ Common.Attr.class_ [ "astryx-field__description" ])
           [ Vdom.Node.text description ])
    | None -> None
  in
  let label_group =
    Vdom.Node.create "div"
      ~attrs:(Common.Attr.class_ [ "astryx-field__label-group" ])
      ((if is_label_hidden then [] else [ label_node ]) @ Option.to_list description_node)
  in
  let status_node =
    match status with
    | Some { Input_types.type_ = _; message = None } -> None
    | Some { Input_types.type_ = _; message = Some message } ->
      Some
        (Vdom.Node.create "div"
           ~attrs:
             ([ Vdom.Attr.id (input_id ^ "-status") ]
              @ Common.Attr.class_ [ "astryx-field__input-status" ]
              @ Common.Attr.aria "live" "polite")
           [ Vdom.Node.text message ])
    | None -> None
  in
  let root_attrs =
    Common.Attr.class_
      ([ "astryx-field" ] @ (if is_label_hidden then [] else [ "astryx-field--labeled" ]))
    @ Common.Attr.data "component" "Typeahead"
    @ (match width with
       | None -> []
       | Some width -> Common.Attr.style [ ("width", Common.Size_value.to_css width) ])
    @ Option.value ~default:[] attrs
  in
  (* An attached status sits behind the control's bottom edge; a detached one follows it. *)
  let is_attached =
    match status_variant with
    | Some Field_status.Attached -> true
    | Some Field_status.Detached | Some Field_status.Tooltip | None -> false
  in
  let control =
    Bonsai.map control ~f:(fun control ->
        if is_attached then
          Vdom.Node.create "div"
            ~attrs:(Common.Attr.class_ [ "astryx-field__input-status" ])
            ([ control ] @ Option.to_list status_node)
        else
          control)
  in
  Bonsai.map control ~f:(fun control ->
      Vdom.Node.create "div"
        ~attrs:root_attrs
        ([ label_group; control ]
         @ (if is_attached then [] else Option.to_list status_node)))
