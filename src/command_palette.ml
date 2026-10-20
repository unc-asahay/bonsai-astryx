(* Copyright (c) Meta Platforms, Inc. and affiliates.
   Ported to OCaml/Bonsai from the astryx CommandPalette component
   (packages/core/src/CommandPalette/).

   The design facts, in the order they shaped this file:

   1. The COMMANDS are the application's. Upstream takes a [searchSource] — a
      function of the query that answers with items — and renders whatever it
      gets. The port takes the same shape as a [source] (search + bootstrap),
      and also lets the application own the result set outright, which is the
      path an asynchronous source takes.
   2. The SURFACE is the native popover mechanism, drawn in place: the house has
      no portal and no outlet, so a surface upstream draws in a portal is drawn
      where the component is. This is the same [popover="auto"] attribute, the
      same Layer_hook and the same CSS anchor positioning that {!Popover},
      {!Complex_selector} and {!Multi_selector} stand on — not a new mechanism.
   3. The FOCUS stays in the input. The active row is named with
      aria-activedescendant, so the highlight is an INDEX over the results, not
      a moving DOM focus. The field's own caret keys (Home, End, Space) stay
      native, and PageUp/PageDown are the sanctioned way to reach the first and
      the last command.
   4. There is NO CONTEXT. Upstream threads a React context through the family
      members; the port has none, so each member is a plain function of the
      values it needs, and the palette builds them the way upstream's
      [ItemRenderer] does.
*)

open! Core
open! Bonsai_web
open Js_of_ocaml

module Attr = Common.Attr

(* ------------------------------------------------------------------ the item *)

type item =
  { id : string
  ; label : string
  ; group : string option
  ; keywords : string list
  ; is_disabled : bool
  }
;;

type source =
  { search : string -> item list
  ; bootstrap : unit -> item list
  }
;;

(* Upstream's createStaticSource: a case-insensitive substring of the label, or
   of one of the item's keywords. The empty query answers with everything. *)
let create_static_source ?keywords items =
  let get_keywords = keywords in
  { search =
      (fun query ->
        let lower = String.lowercase (String.strip query) in
        if String.is_empty lower
        then items
        else
          List.filter items ~f:(fun item ->
              String.is_substring (String.lowercase item.label) ~substring:lower
              || List.exists item.keywords ~f:(fun keyword ->
                     String.is_substring (String.lowercase keyword) ~substring:lower)
              || (match get_keywords with
                  | Some f ->
                    List.exists (f item) ~f:(fun keyword ->
                        String.is_substring (String.lowercase keyword) ~substring:lower)
                  | None -> false)))
  ; bootstrap = (fun () -> items)
  }
;;

(* ----------------------------------------------------------------- DOM bits *)

type el = Dom_html.element Js.t

let by_id (id : string) : el option =
  Js.Opt.to_option
    (Js.Unsafe.meth_call
       Dom_html.document
       "getElementById"
       [| Js.Unsafe.inject (Js.string id) |]
      : el Js.opt)
;;

let focus_el (el : el) =
  ignore (Js.Unsafe.meth_call el "focus" [||])
;;

let key_of (ev : Dom_html.keyboardEvent Js.t) : string =
  Option.value (Common.string_prop ev "key") ~default:""
;;

(* Upstream's isImeKeyEvent: a keydown that is part of an IME conversion
   carries isComposing, or the legacy 229 keyCode. Enter pressed to commit a
   conversion must not also select a command. *)
let is_ime_key_event (ev : Dom_html.keyboardEvent Js.t) =
  Js.to_bool
    (Js.Unsafe.fun_call
       (Js.Unsafe.pure_js_expr
          "(function(ev){return ev.isComposing === true || ev.keyCode === 229;})")
       [| Js.Unsafe.inject ev |])
;;

let scroll_into_view (el : el) =
  ignore
    (Js.Unsafe.fun_call
       (Js.Unsafe.eval_string "(function (el) { el.scrollIntoView({block: 'nearest'}); })")
       [| Js.Unsafe.inject el |])
;;

(* The next frame, once the state write has been patched into the DOM. *)
let next_frame (f : unit -> unit) =
  ignore
    (Js.Unsafe.fun_call
       (Js.Unsafe.pure_js_expr "requestAnimationFrame")
       [| Js.Unsafe.inject (Js.wrap_callback (fun (_ : float) -> f ())) |])
;;

(* ------------------------------------------------------- the grouping rules *)

(* Upstream groups by [auxiliaryData.group], preserving the order the groups
   first appear in, and puts the ungrouped items at the END. The order matters:
   it is the DOM order, and the DOM order is the index space the keyboard model
   walks and aria-activedescendant names.

   The groups are an association list, so the order they first appear in is the
   order they are kept in — a map would sort them, and the order is the
   contract. *)
let partition (items : item list) =
  let groups = ref [] in
  let ungrouped = ref [] in
  List.iter items ~f:(fun item ->
      match item.group with
      | None -> ungrouped := item :: !ungrouped
      | Some group ->
        let rec add = function
          | [] -> [ (group, [ item ]) ]
          | (name, group_items) :: rest ->
            if String.equal name group then (name, item :: group_items) :: rest else (name, group_items) :: add rest
        in
        groups := add !groups);
  ( List.map (List.rev !groups) ~f:(fun (group, group_items) -> (group, List.rev group_items))
  , List.rev !ungrouped )
;;

(* ------------------------------------------------------------- the family *)

(* The field takes the focus when it mounts, if it is asked to. One frame late:
   the surface is display:none until the layer mechanism shows it, and the hooks
   run in unspecified order after the same DOM patch — so focusing here and now
   would silently do nothing whenever this ran first. Same reason as Popover's. *)
module Autofocus_hook = struct
  module T = struct
    module State = struct
      type t = { mutable has_focused : bool }

      let create () = { has_focused = false }
    end

    module Input = struct
      type t = { has_auto_focus : bool }

      let sexp_of_t { has_auto_focus } = Sexp.Atom (Bool.to_string has_auto_focus)
      ;;

      let combine left _ = left
    end

    let apply (state : State.t) (input : Input.t) (el : Dom_html.element Js.t) =
      if input.has_auto_focus && not state.has_focused
      then (
        state.has_focused <- true;
        next_frame (fun () -> focus_el el))
    ;;

    let init _ _ = State.create ()
    let on_mount input state el = apply state input el
    let on_mount = `Schedule_immediately_after_this_dom_patch_completes on_mount
    let update ~old_input:_ ~new_input state el = apply state new_input el
    let destroy _ _ _ = ()
  end

  module Hook = Vdom.Attr.Hooks.Make (T)

  let attr ~has_auto_focus () =
    Vdom.Attr.create_hook
      "astryx-command-palette-autofocus"
      (Hook.create { T.Input.has_auto_focus })
  ;;
end

module Input = struct
  let view
        ?(attrs = [])
        ?(id = "astryx-command-palette-input")
        ?(label = "Search commands")
        ?(placeholder = "Search…")
        ?(is_busy = false)
        ?(has_auto_focus = true)
        ?list_id
        ?active_descendant_id
        ?(is_expanded = false)
        ~value
        ~on_change
        ?on_key_down
        ()
    =
    let input_attrs =
      [ Vdom.Attr.id id
      ; Vdom.Attr.create "type" "text"
      ; (* The field is the combobox: it drives the list of results whether or
           not that list currently has anything in it. *)
        Vdom.Attr.create "role" "combobox"
      ; Vdom.Attr.create "aria-expanded" (Bool.to_string is_expanded)
      ; Vdom.Attr.create "aria-autocomplete" "list"
      ; (* The placeholder is never the field's name. *)
        Vdom.Attr.create "aria-label" label
      ; Vdom.Attr.create "placeholder" placeholder
      ; (* The property, not the attribute: the query is the palette's state, and
           the field has to show it even after the user has typed — a dirty
           input ignores its value attribute. *)
        Vdom.Attr.value value
      ; Vdom.Attr.on_input (fun (_ : Dom_html.event Js.t) new_value -> on_change new_value)
      ; Autofocus_hook.attr ~has_auto_focus ()
      ]
      @ (match list_id with
         | Some list_id -> [ Vdom.Attr.create "aria-controls" list_id ]
         | None -> [])
      @ (match active_descendant_id with
         | Some active_descendant_id ->
           [ Vdom.Attr.create "aria-activedescendant" active_descendant_id ]
         | None -> [])
      @ (match on_key_down with
         | Some on_key_down -> [ Vdom.Attr.on_keydown on_key_down ]
         | None -> [])
    in
    Vdom.Node.div
      ~attrs:
        (Attr.class_ [ "astryx-command-palette__input" ]
         @ Attr.data "component" "CommandPaletteInput"
         @ attrs)
      [ Vdom.Node.span
          ~attrs:(Attr.class_ [ "astryx-command-palette__input-icon" ])
          [ Icon.view ~name:"search" ~size:Icon.Sm ~color:Icon.Secondary () ]
      ; Vdom.Node.input ~attrs:input_attrs ()
      ; Vdom.Node.span
          ~attrs:(Attr.class_ [ "astryx-command-palette__input-end" ])
          (if is_busy
           then [ Vdom.Node.span ~attrs:(Attr.class_ [ "astryx-command-palette__spinner" ])
                    [ Spinner.view ~size:Spinner.Sm () ]
                ]
           else [])
      ]
end

module List_box = struct
  let view ?(attrs = []) ?(id = "astryx-command-palette-list") ?(label = "Commands")
      ?(has_listbox = true) ~children () =
    let list_attrs =
      Attr.class_ [ "astryx-command-palette__list" ]
      @ Attr.data "component" "CommandPaletteList"
      @ [ Vdom.Attr.id id ]
      (* The listbox role is present only while the list holds selectable
         results: an empty listbox is an interactive popup with nothing in it. *)
      @ (if has_listbox
         then
           [ Vdom.Attr.create "role" "listbox"
           ; Vdom.Attr.create "aria-label" label
           ]
         else [])
      @ attrs
    in
    Vdom.Node.div ~attrs:list_attrs children
end

module Item = struct
  let view
        ?(attrs = [])
        ?id
        ~value
        ?(is_selected = false)
        ?(is_highlighted = false)
        ?(is_disabled = false)
        ?on_select
        ?on_hover
        ~children
        ()
    =
    let item_attrs =
      Attr.class_
        ([ "astryx-command-palette__item" ]
         @ (if is_highlighted then [ "astryx-command-palette__item--highlighted" ] else [])
         @ (if is_selected then [ "astryx-command-palette__item--selected" ] else [])
         @ (if is_disabled then [ "astryx-command-palette__item--disabled" ] else []))
      @ Attr.data "component" "CommandPaletteItem"
      @ [ Vdom.Attr.create "role" "option"
        ; Vdom.Attr.create "aria-selected" (Bool.to_string is_selected)
        ; Vdom.Attr.create "data-value" value
        ]
      @ (match id with
         | Some id -> [ Vdom.Attr.id id ]
         | None -> [])
      @ (if is_disabled then [ Vdom.Attr.create "aria-disabled" "true" ] else [])
      @ (match on_select with
         | Some on_select -> [ Vdom.Attr.on_click (fun (_ : Dom_html.mouseEvent Js.t) -> on_select value) ]
         | None -> [])
      @ (match on_hover with
         | Some on_hover ->
           [ Vdom.Attr.on_mouseenter (fun (_ : Dom_html.mouseEvent Js.t) -> on_hover value) ]
         | None -> [])
      @ attrs
    in
    Vdom.Node.div ~attrs:item_attrs children
end

module Group = struct
  let view ?(attrs = []) ~heading ~children () =
    let group_attrs =
      Attr.class_ [ "astryx-command-palette__group" ]
      @ Attr.data "component" "CommandPaletteGroup"
      @ [ Vdom.Attr.create "role" "group"
        ; Vdom.Attr.create "aria-label" heading
        ]
      @ attrs
    in
    Vdom.Node.div
      ~attrs:group_attrs
      (Vdom.Node.div
         ~attrs:
           (Attr.class_ [ "astryx-command-palette__group-heading" ]
            @ [ Vdom.Attr.create "aria-hidden" "true" ])
         [ Vdom.Node.text heading ]
       :: children)
end

module Footer = struct
  let view ?(attrs = []) ?children () =
    let hint (keys : string list) (text : string) =
      Vdom.Node.span
        ~attrs:(Attr.class_ [ "astryx-command-palette__hint" ])
        (List.map keys ~f:(fun key -> Kbd.view ~keys:key ())
         @ [ Vdom.Node.text text ])
    in
    let content =
      match children with
      | Some children -> children
      | None ->
        [ hint [ "up"; "down" ] "to navigate"
        ; hint [ "enter" ] "to select"
        ; hint [ "escape" ] "to close"
        ]
    in
    Vdom.Node.div
      ~attrs:
        (Attr.class_ [ "astryx-command-palette__footer" ]
         @ Attr.data "component" "CommandPaletteFooter"
         @ attrs)
      content
end

module Empty = struct
  let view ?(attrs = []) ~children () =
    Vdom.Node.div
      ~attrs:
        (Attr.class_ [ "astryx-command-palette__empty" ]
         @ Attr.data "component" "CommandPaletteEmpty"
         @ attrs)
      children
end

(* --------------------------------------------------- the focus on the field *)

(* The field takes the focus when the palette opens, one frame late: the surface
   is display:none until the layer mechanism shows it, and the two hooks run in
   unspecified order after the same DOM patch — so focusing here and now would
   silently do nothing whenever this ran first. Same reason as Popover's. *)
module Open_focus_hook = struct
  module T = struct
    module State = struct
      type t = { mutable was_open : bool }

      let create () = { was_open = false }
    end

    module Input = struct
      type t =
        { is_open : bool
        ; input_id : string
        }

      let sexp_of_t { is_open; input_id } =
        Sexp.List [ Sexp.Atom (Bool.to_string is_open); Sexp.Atom input_id ]
      ;;

      let combine left _ = left
    end

    let apply (state : State.t) (input : Input.t) =
      let opened = input.is_open && not state.was_open in
      state.was_open <- input.is_open;
      if opened
      then
        Effect.Expert.handle_non_dom_event_exn
          (Effect.of_thunk (fun () ->
               next_frame (fun () ->
                   Option.iter (by_id input.input_id) ~f:focus_el)))
    ;;

    let init _ _ = State.create ()
    let on_mount input state _el = apply state input
    let on_mount = `Schedule_immediately_after_this_dom_patch_completes on_mount
    let update ~old_input:_ ~new_input state _el = apply state new_input
    let destroy _ _ _ = ()
  end

  module Hook = Vdom.Attr.Hooks.Make (T)

  let attr ~is_open ~input_id () =
    Vdom.Attr.create_hook
      "astryx-command-palette-open-focus"
      (Hook.create { T.Input.is_open; input_id })
  ;;
end

(* ------------------------------------------------------------------ the view *)

type state =
  { query : string
  ; highlighted : int
  ; selected : string
  }

let initial_state = { query = ""; highlighted = -1; selected = "" }

(* [List.nth_opt] is not in this Core, and the keyboard model needs it to walk
   the enabled indices without raising. *)
let nth_opt (items : 'a list) (index : int) : 'a option =
  let rec go i = function
    | [] -> None
    | x :: _ when Int.equal i index -> Some x
    | _ :: rest -> go (i + 1) rest
  in
  if index < 0 then None else go 0 items
;;

let view
      ?(attrs = [])
      ?(id = "astryx-command-palette")
      ?is_open
      ?on_open_change
      ?(label = "Command palette")
      ?(input_label = "Search commands")
      ?(placeholder = "Search…")
      ?(empty_search_text = "No results")
      ?(empty_bootstrap_text = "Type to search")
      ?(is_busy = false)
      ?(is_inline = false)
      ?(has_auto_focus = true)
      ?(width = Common.Size_value.Px 640)
      ?(max_height = Common.Size_value.Px 480)
      ?value
      ?on_value_change
      ?render_item
      ?source
      ?results
      ?on_query_change
      (graph : Bonsai.graph)
  =
  (* The open state and how it is controlled: both given -> the caller owns it;
     neither -> the palette owns its state; [on_open_change] alone -> the
     palette owns its state and reports. [is_open] alone has no setter to
     answer it, so it is refused rather than silently ignored. Same shape
     Complex_selector and Multi_selector use. *)
  let open_state =
    match is_open, on_open_change with
    | Some is_open, Some on_open_change ->
      Bonsai.map2 is_open on_open_change ~f:(fun is_open on_open_change ->
        (is_open, on_open_change, (fun (_ : bool) -> Effect.Ignore)))
    | None, None ->
      let is_open, set_open = Bonsai.state false graph in
      Bonsai.map2 is_open set_open ~f:(fun is_open set_open ->
        (is_open, set_open, (fun (_ : bool) -> Effect.Ignore)))
    | None, Some on_open_change ->
      let is_open, set_open = Bonsai.state false graph in
      Bonsai.map2 is_open (Bonsai.map2 set_open on_open_change ~f:(fun a b -> a, b))
        ~f:(fun is_open (set_open, observe) -> (is_open, set_open, observe))
    | Some _, None ->
      raise_s
        (Sexp.Atom
           "Command_palette.view: is_open without on_open_change - the pair controls the palette \
            together, or the palette owns its state (pass on_open_change alone to observe)")
  in
  let state, set_state = Bonsai.state' initial_state graph in
  let value_t =
    match value with
    | None -> Bonsai.return None
    | Some value -> Bonsai.map value ~f:(fun value -> Some value)
  in
  let results_t =
    match results with
    | None -> Bonsai.return None
    | Some results -> Bonsai.map results ~f:(fun results -> Some results)
  in
  (* The application's callbacks come in as graphs of a function, the way the
     house's other components take them: a state setter wires straight in. *)
  let on_value_change_t =
    match on_value_change with
    | Some on_value_change -> on_value_change
    | None -> Bonsai.return (fun (_ : string) -> Effect.Ignore)
  in
  let on_query_change_t =
    match on_query_change with
    | Some on_query_change -> on_query_change
    | None -> Bonsai.return (fun (_ : string) -> Effect.Ignore)
  in
  let combined =
    Bonsai.map3
      (Bonsai.both open_state (Bonsai.both state set_state))
      (Bonsai.both value_t results_t)
      (Bonsai.both on_value_change_t on_query_change_t)
      ~f:
        (fun
          ((is_open, set_open, observe), (state, set_state))
          (value, results)
          (on_value_change, on_query_change) ->
          ( is_open
          , set_open
          , observe
          , state
          , set_state
          , value
          , results
          , on_value_change
          , on_query_change ))
  in
  Bonsai.map combined
    ~f:
      (fun
        ( is_open
        , set_open
        , observe
        , state
        , set_state
        , value
        , results
        , on_value_change
        , on_query_change ) ->
      let input_id = id ^ "-input" in
      let list_id = id ^ "-list" in
      (* The commands. An application-owned result set wins over the source: it
         is the path an asynchronous source takes, and the palette renders what
         it is given without filtering. *)
      let items =
        match results with
        | Some results -> results
        | None ->
          (match source with
           | None -> []
           | Some source ->
             if String.is_empty state.query then source.bootstrap () else source.search state.query)
      in
      let groups, ungrouped = partition items in
      (* The selectable items in DOM order: the groups in the order they first
         appear, then the ungrouped ones. This is the index space the keyboard
         model walks and aria-activedescendant names, so it has to match what is
         rendered, exactly. *)
      let selectable =
        List.concat_map groups ~f:(fun (_group, group_items) -> group_items) @ ungrouped
      in
      let enabled_indices =
        List.mapi selectable ~f:(fun index item -> (index, item))
        |> List.filter_map ~f:(fun (index, item) -> if item.is_disabled then None else Some index)
      in
      (* With nothing chosen yet, the first result is the highlighted one — upstream's
         own rule, and the reason the palette can be driven with the arrow keys
         without a first press to put the highlight somewhere. The state keeps the
         user's own choice; this is what the state means when it has none. *)
      let default_highlight = match enabled_indices with first :: _ -> first | [] -> -1 in
      let effective_highlight =
        if state.highlighted < 0 then default_highlight else state.highlighted
      in
      let position_of (index : int) (indices : int list) =
        let rec go position = function
          | [] -> -1
          | x :: rest -> if Int.equal x index then position else go (position + 1) rest
        in
        go 0 indices
      in
      let selected_value = Option.value value ~default:state.selected in
      (* --- the effects --- *)
      let clear_input_value () =
        (* The field is a controlled input, and the DOM keeps what the person
           typed; clearing the query means clearing the field with it, or the
           palette would reopen showing the last query. *)
        Effect.of_thunk (fun () ->
            match by_id input_id with
            | Some el ->
              ignore (Js.Unsafe.meth_call el "value" [| Js.Unsafe.inject (Js.string "") |])
            | None -> ())
      in
      let close_effect =
        Effect.Many
          [ set_open false
          ; observe false
          ; set_state (fun _state ->
              { query = ""; highlighted = -1; selected = "" })
          ; clear_input_value ()
          ]
      in
      let select (selected : string) =
        Effect.Many
          [ on_value_change selected
          ; set_state (fun state -> { state with selected; highlighted = -1 })
          ; close_effect
          ]
      in
      let move_highlight (index : int) =
        Effect.Many
          [ set_state (fun state -> { state with highlighted = index })
          ; (* The highlighted row is scrolled into view, but only for a KEYBOARD
               move: a pointer that re-highlights under itself would scroll the
               list out from under the pointer, forever. *)
            Effect.of_thunk (fun () ->
                next_frame (fun () ->
                    Option.iter
                      (by_id (list_id ^ "-item-" ^ string_of_int index))
                      ~f:scroll_into_view))
          ]
      in
      let set_query (query : string) =
        Effect.Many
          [ (* A highlight belongs to the query that created it: it is cleared
               before the new results are exposed, so aria-activedescendant never
               names a different command at the same index. *)
            set_state (fun state -> { state with query; highlighted = -1 })
          ; on_query_change query
          ]
      in
      (* --- the keyboard model --- *)
      let handle_key_down (ev : Dom_html.keyboardEvent Js.t) : unit Effect.t =
        if is_ime_key_event ev
        then Effect.Ignore
        else
          let key = key_of ev in
          match key with
          | "ArrowDown" ->
            Common.prevent_default ev;
            let position = position_of effective_highlight enabled_indices in
            let next = Int.min (position + 1) (List.length enabled_indices - 1) in
            (match nth_opt enabled_indices next with
             | Some index -> move_highlight index
             | None -> Effect.Ignore)
          | "ArrowUp" ->
            Common.prevent_default ev;
            let position = position_of effective_highlight enabled_indices in
            let previous = Int.max (position - 1) 0 in
            (match nth_opt enabled_indices previous with
             | Some index -> move_highlight index
             | None -> Effect.Ignore)
          | "PageUp" ->
            Common.prevent_default ev;
            (match enabled_indices with
             | first :: _ -> move_highlight first
             | [] -> Effect.Ignore)
          | "PageDown" ->
            Common.prevent_default ev;
            (match List.rev enabled_indices with
             | last :: _ -> move_highlight last
             | [] -> Effect.Ignore)
          | "Enter" ->
            Common.prevent_default ev;
            (match nth_opt selectable effective_highlight with
             | Some item when not item.is_disabled -> select item.id
             | _ -> Effect.Ignore)
          | "Escape" ->
            (* The modal palette leaves Escape to the platform, which closes the
               surface; the inline one is not a layer, so it closes itself. *)
            if is_inline
            then (
              Common.prevent_default ev;
              close_effect)
            else Effect.Ignore
          | "Home" | "End" | " " -> Effect.Ignore
          | "Tab" -> close_effect
          | _ -> Effect.Ignore
      in
      (* --- the DOM --- *)
      let item_node (item : item) (index : int) =
        let content =
          match render_item with
          | Some render_item -> [ render_item item (String.equal selected_value item.id) ]
          | None -> [ Vdom.Node.text item.label ]
        in
        Item.view
          ~id:(list_id ^ "-item-" ^ string_of_int index)
          ~value:item.id
          ~is_selected:(String.equal selected_value item.id)
          ~is_highlighted:(Int.equal effective_highlight index)
          ~is_disabled:item.is_disabled
          ~on_select:(fun _ -> select item.id)
          ~on_hover:(fun _ ->
              if item.is_disabled
              then Effect.Ignore
              else set_state (fun state -> { state with highlighted = index }))
          ~children:content
          ()
      in
      (* The rows, in DOM order, with the index each one has in the flat list:
         the grouped rows first (group by group), then the ungrouped ones. The
         index is the row's place in the flat list, because that is what the
         keyboard model walks and what aria-activedescendant names. *)
      let group_nodes =
        let rec go index = function
          | [] -> []
          | (group, group_items) :: rest ->
            let rows =
              List.mapi group_items ~f:(fun offset item -> item_node item (index + offset))
            in
            let next_index = index + List.length group_items in
            Group.view ~heading:group ~children:rows () :: go next_index rest
        in
        go 0 groups
      in
      let ungrouped_nodes =
        let base_index = List.length (List.concat_map groups ~f:(fun (_g, its) -> its)) in
        List.mapi ungrouped ~f:(fun offset item -> item_node item (base_index + offset))
      in
      let has_listbox = not (List.is_empty selectable) in
      let active_descendant_id =
        if has_listbox && effective_highlight >= 0
           && effective_highlight < List.length selectable
        then Some (list_id ^ "-item-" ^ string_of_int effective_highlight)
        else None
      in
      let is_empty_state = not has_listbox in
      let empty_text =
        if String.is_empty state.query then empty_bootstrap_text else empty_search_text
      in
      (* The announcements. Upstream writes them into one polite live region
         the application owns; the port has no such registry, so the palette
         hosts its own, the way the house's other components do. The count is
         announced for a query that matched, the rendered empty text for one
         that matched nothing, and nothing at all when the palette opens on
         its bootstrap list. *)
      let announcement =
        if is_busy
        then "Loading"
        else if String.is_empty state.query
        then ""
        else
          let count = List.length selectable in
          if Int.equal count 0
          then empty_text
          else if Int.equal count 1
          then "1 result"
          else string_of_int count ^ " results"
      in
      let announcement_node =
        Vdom.Node.div
          ~attrs:
            [ Vdom.Attr.class_ "astryx-visually-hidden"
            ; Vdom.Attr.create "role" "status"
            ; Vdom.Attr.create "aria-live" "polite"
            ; Vdom.Attr.create "aria-atomic" "true"
            ; Vdom.Attr.create "data-astryx-live-region" "polite"
            ]
          [ Vdom.Node.text announcement ]
      in
      let list_children =
        if is_empty_state then [ Empty.view ~children:[ Vdom.Node.text empty_text ] () ]
        else group_nodes @ ungrouped_nodes
      in
      let header =
        Vdom.Node.div
          ~attrs:(Attr.class_ [ "astryx-command-palette__header" ])
          [ Input.view
              ~id:input_id
              ~label:input_label
              ~placeholder
              ~is_busy
              (* The palette focuses the field when it OPENS; the field's own
                 mount-time focus would take it while the palette is closed. *)
              ~has_auto_focus:false
              ?list_id:(if has_listbox then Some list_id else None)
              ?active_descendant_id
              ~is_expanded:(is_open && has_listbox)
              ~value:state.query
              ~on_change:set_query
              ~on_key_down:handle_key_down
              ()
          ]
      in
      let list =
        List_box.view ~id:list_id ~has_listbox ~children:list_children ()
      in
      let footer =
        Vdom.Node.div
          ~attrs:(Attr.class_ [ "astryx-command-palette__footer-wrap" ])
          [ Footer.view () ]
      in
      let style =
        Printf.sprintf
          "--astryx-command-palette-width: %s; --astryx-command-palette-max-height: %s;"
          (Common.Size_value.to_css width)
          (Common.Size_value.to_css max_height)
      in
      let surface_attrs =
        [ Vdom.Attr.id id
        ; Vdom.Attr.create "role" "dialog"
        ; Vdom.Attr.create "aria-label" label
        ; Vdom.Attr.create "style" style
        ]
        @ (if is_inline
           then []
           else
             [ Vdom.Attr.create "popover" "auto"
             ; Vdom.Attr.create "aria-modal" "true"
             ])
        @ Attr.class_
            ([ "astryx-command-palette" ]
             @ (if is_inline then [ "astryx-command-palette--inline" ] else [])
             @ (if is_open
                then []
                else [ "astryx-command-palette--closed" ]))
        @ Attr.data "component" "CommandPalette"
        @ (if is_inline
           then []
           else [ Common.Layer_hook.attr ~is_open ~on_platform_close:close_effect ])
        @ (if has_auto_focus && not is_inline
           then [ Open_focus_hook.attr ~is_open ~input_id () ]
           else [])
        @ attrs
      in
      Vdom.Node.div ~attrs:surface_attrs [ header; list; footer; announcement_node ])
;;

(* -------------------------------------------------------------- the footer *)

(* The footer module is defined after the view because the view builds it; the
   module is bound above and used here. *)