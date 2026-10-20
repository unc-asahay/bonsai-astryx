(* Copyright (c) Meta Platforms, Inc. and affiliates.
   Ported to OCaml/Bonsai from the astryx MultiSelector component.

   The design facts, in the order they shaped this file:

   1. The SELECTION is the application's. Upstream's MultiSelector takes the chosen
      values and hands the next set back; the port does the same, so the
      application is the single source of truth for what is chosen. Everything
      else - the search box, the highlight, the typeahead buffer - is the
      component's own state, because none of it is the application's business.
   2. The trigger is OURS. The component builds the field, the control box, the
      button, the spinner, the clear button and the chevron, so the ARIA and the
      handlers go on the button we build (the arrangement Complex_selector and
      Dropdown_menu reached for).
   3. The list is a native popover surface, exactly as Popover and
      Complex_selector use it: the same [popover="auto"] attribute, the same
      Layer_hook, the same CSS anchor positioning. The house has no portal, so
      the list is drawn in place.
   4. The keyboard model is upstream's useMultiCombobox: an index over the
      filtered options, reported with aria-activedescendant, with the DOM focus
      staying on the trigger (or on the search box when there is one).
*)

(* This library's own Field, bound before the opens below. Core defines a module
   named Field as well (first-class fields), so after [open! Core] the
   unqualified name would refer to Core's. *)
module Field_ = Field

open! Core
open! Bonsai_web
open Js_of_ocaml

module Attr = Common.Attr

type variant =
  | Input
  | Secondary
  | Ghost
;;

type size = Input_types.size =
  | Sm
  | Md
  | Lg
;;

type status = Input_types.status =
  { type_ : Field_status.type_
  ; message : string option
  }
;;

type trigger_display =
  | Count
  | Labels
  | Badges
;;

type indicator_position =
  | Start
  | End
;;

type option_data =
  { value : string
  ; label : string option
  ; description : string option
  ; is_disabled : bool
  }

type option_item =
  | Option of option_data
  | Divider
  | Section of section

and section =
  { title : string option
  ; options : option_data list
  }
;;

type selected_item =
  { value : string
  ; label : string
  }
;;

(* ------------------------------------------------------------- DOM helpers *)

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
  ignore
    (Js.Unsafe.meth_call
       el
       "focus"
       [| Js.Unsafe.inject (Js.Unsafe.obj [| "preventScroll", Js.Unsafe.inject Js._true |]) |])
;;

let key_of (ev : Dom_html.keyboardEvent Js.t) : string =
  Option.value (Common.string_prop ev "key") ~default:""
;;

(* Upstream scrolls the highlighted option into view as the highlight moves. *)
let scroll_into_view (el : el) =
  ignore
    (Js.Unsafe.fun_call
       (Js.Unsafe.eval_string
          "(function (el) { el.scrollIntoView({block: 'nearest'}); })")
       [| Js.Unsafe.inject el |])
;;

(* --------------------------------------------------------------- utilities *)

let size_string = function
  | Sm -> "sm"
  | Md -> "md"
  | Lg -> "lg"
;;

let status_string = function
  | Field_status.Warning -> "warning"
  | Field_status.Error -> "error"
  | Field_status.Success -> "success"
;;

let status_icon_name = function
  | Field_status.Warning -> "warning"
  | Field_status.Error -> "error"
  | Field_status.Success -> "success"
;;

let status_icon_color = function
  | Field_status.Warning -> Icon.Warning
  | Field_status.Error -> Icon.Error
  | Field_status.Success -> Icon.Success
;;

(* Upstream's normalizeOption: an option's label falls back to its value. *)
let label_of (o : option_data) : string = Option.value o.label ~default:o.value

(* A case-insensitive substring test - the shape of upstream's filter, which
   matches the option's label (or its value, when it has no label) against the
   query. *)
let contains_ci ~(haystack : string) ~(needle : string) : bool =
  String.is_substring (String.lowercase haystack) ~substring:(String.lowercase needle)
;;

let matches_query (o : option_data) (query : string) : bool =
  String.is_empty query
  || contains_ci ~haystack:(String.lowercase (label_of o)) ~needle:(String.lowercase query)
;;

(* The options list, grouped the way upstream groups it: a run of plain options
   is one group, a divider separates groups, and a section is a group of its own. *)
type group =
  | Group_flat of option_data list
  | Group_divider
  | Group_section of string option * option_data list
;;

let groups_of (options : option_item list) : group list =
  let rec go pending acc = function
    | [] ->
      let acc =
        match List.rev pending with
        | [] -> acc
        | items -> Group_flat items :: acc
      in
      List.rev acc
    | Option o :: rest -> go (o :: pending) acc rest
    | Divider :: rest ->
      (* The pending run comes BEFORE the divider in the list, so it is pushed
         first: the accumulator is in reverse order. *)
      let acc =
        match List.rev pending with
        | [] -> acc
        | items -> Group_flat items :: acc
      in
      go [] (Group_divider :: acc) rest
    | Section s :: rest ->
      let acc =
        match List.rev pending with
        | [] -> acc
        | items -> Group_flat items :: acc
      in
      go [] (Group_section (s.title, s.options) :: acc) rest
  in
  go [] [] options
;;

(* Upstream orders the options of each group with the ones already chosen (at the
   moment the list opened) first; the rest keep their declared order. *)
let order_group ~(selected_at_open : string list) (items : option_data list) =
  let is_selected (o : option_data) =
    List.exists selected_at_open ~f:(fun v -> String.equal o.value v)
  in
  let selected, rest = List.partition_tf items ~f:is_selected in
  selected @ rest
;;

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

let take n (items : 'a list) : 'a list =
  let rec go n acc = function
    | _ when n <= 0 -> List.rev acc
    | [] -> List.rev acc
    | x :: rest -> go (n - 1) (x :: acc) rest
  in
  go n [] items
;;

(* The list's own state: the search query, the highlight, the typeahead buffer
   and the snapshot of the selection taken when the list opened. *)
type panel_state =
  { search_query : string
  ; highlighted : int
  ; typeahead : string
  ; typeahead_at : float
  ; selected_at_open : string list
  ; announcement : string
  }

let initial_panel_state =
  { search_query = ""
  ; highlighted = -1
  ; typeahead = ""
  ; typeahead_at = 0.
  ; selected_at_open = []
  ; announcement = ""
  }
;;

let now_ms () : float = Js.to_float (Js.Unsafe.coerce (Js.Unsafe.eval_string "Date.now()"))

(* ------------------------------------------------------------------- view *)

let view
      ?(attrs = [])
      ?(id = "astryx-multi-selector")
      ?is_open
      ?on_open_change
      ?(is_label_hidden = false)
      ?description
      ?(is_optional = false)
      ?(is_required = false)
      ?(is_disabled = false)
      ?(is_loading = false)
      ?status
      ?(status_variant = Field_status.Attached)
      ?(size = Md)
      ?(variant = Input)
      ?(placeholder = "Select...")
      ?start_icon
      ?width
      ?(has_search = false)
      ?(search_placeholder = "Search...")
      ?(has_clear = false)
      ?(empty_text = "No options")
      ?(empty_search_text = "No results")
      ?(trigger_display = Count)
      ?(max_badges = 3)
      ?format_value
      ?(indicator_position = Start)
      ?html_name
      ?(is_default_open = false)
      ~label
      ~options
      ~value
      ~on_change
      (graph : Bonsai.graph)
  =
  (* The open state and how it is controlled: both given -> the caller owns it;
     neither -> the list owns its state; [on_open_change] alone -> the list owns
     its state and reports. The same shape Complex_selector and Dropdown_menu
     use. *)
  let open_state =
    match is_open, on_open_change with
    | Some is_open, Some on_open_change ->
      Bonsai.map2 is_open on_open_change ~f:(fun is_open on_open_change ->
        (is_open, on_open_change, (fun (_ : bool) -> Effect.Ignore)))
    | None, None ->
      let is_open, set_open = Bonsai.state is_default_open graph in
      Bonsai.map2 is_open set_open ~f:(fun is_open set_open ->
        (is_open, set_open, (fun (_ : bool) -> Effect.Ignore)))
    | None, Some on_open_change ->
      let is_open, set_open = Bonsai.state is_default_open graph in
      Bonsai.map2 is_open (Bonsai.map2 set_open on_open_change ~f:(fun a b -> a, b))
        ~f:(fun is_open (set_open, observe) -> (is_open, set_open, observe))
    | Some _, None ->
      raise_s
        (Sexp.Atom
           "Multi_selector.view: is_open without on_open_change - the pair controls the list \
            together, or the list owns its state (pass on_open_change alone to observe)")
  in
  (* The list's own state. [state'] rather than [state]: the keyboard model
     reads the CURRENT highlight when the effect runs, so two arrow presses that
     arrive before the next render move two rows, not one. *)
  let panel, set_panel = Bonsai.state' initial_panel_state graph in
  let combined =
    Bonsai.map2
      (Bonsai.both value on_change)
      (Bonsai.both open_state (Bonsai.both panel set_panel))
      ~f:(fun (value, on_change) ((is_open, set_open, observe), (panel, set_panel)) ->
        (value, on_change, is_open, set_open, observe, panel, set_panel))
  in
  Bonsai.map combined ~f:(fun (value, on_change, is_open, set_open, observe, panel, set_panel) ->
      let trigger_id = id in
      let listbox_id = id ^ "-listbox" in
      let search_id = id ^ "-search" in
      let label_id = id ^ "-label" in
      let popover_id = id ^ "-popover" in
      let description_id = trigger_id ^ "-desc" in
      let status_id = trigger_id ^ "-status" in
      (* Upstream's groups: a run of plain options, a divider, or a section. *)
      let groups = groups_of options in
      (* Every option, in declaration order - what the summary looks a label up
         in, and what the selection count is measured against. *)
      let all_options =
        List.concat_map groups ~f:(function
          | Group_flat items -> items
          | Group_divider -> []
          | Group_section (_, items) -> items)
      in
      (* The options the list shows, in the order it shows them: each group's
         matching options, the already-chosen ones first. This is upstream's
         sortedItems, and it is the index space the keyboard model walks and
         aria-activedescendant names. *)
      let group_items (items : option_data list) =
        items
        |> List.filter ~f:(fun o -> matches_query o panel.search_query)
        |> order_group ~selected_at_open:panel.selected_at_open
      in
      let selectable =
        List.concat_map groups ~f:(function
          | Group_flat items -> group_items items
          | Group_divider -> []
          | Group_section (_, items) -> group_items items)
      in
      let enabled_indices =
        List.mapi selectable ~f:(fun i o -> (i, o))
        |> List.filter_map ~f:(fun (i, o) -> if o.is_disabled then None else Some i)
      in
      let position_of index (indices : int list) =
        let rec go i = function
          | [] -> -1
          | x :: rest -> if Int.equal x index then i else go (i + 1) rest
        in
        go 0 indices
      in
      (* The chosen values, with the labels the option list gives them. *)
      let selected_items =
        List.map
          ~f:(fun v ->
            let label =
              match List.find_map all_options ~f:(fun o ->
                if String.equal o.value v then Some o else None) with
              | Some o -> label_of o
              | None -> v
            in
            { value = v; label })
          value
      in
      let selected_labels = List.map selected_items ~f:(fun s -> s.label) in
      let count_text =
        match format_value with
        | Some format -> format selected_items
        | None -> string_of_int (List.length value) ^ " selected"
      in
      let labels_text =
        let displayed = take 3 selected_labels in
        let remaining = List.length selected_labels - List.length displayed in
        let text = String.concat ~sep:", " displayed in
        if remaining > 0 then text ^ (", +" ^ string_of_int remaining) else text
      in
      let labels_text =
        match format_value with
        | Some format -> format selected_items
        | None -> labels_text
      in
      let badges_nodes =
        let displayed = take max_badges selected_labels in
        let remaining = List.length selected_labels - List.length displayed in
        (List.map displayed ~f:(fun l -> Badge.view ~variant:Badge.Neutral l))
        @ (if remaining > 0
           then
             [ Vdom.Node.span
                 ~attrs:(Attr.class_ [ "astryx-multi-selector__trigger-overflow" ])
                 [ Vdom.Node.text ("+" ^ string_of_int remaining) ]
             ]
           else [])
      in
      let active_descendant_id =
        if is_open && panel.highlighted >= 0
        then listbox_id ^ "-item-" ^ string_of_int panel.highlighted
        else ""
      in
      (* --- the effects --- *)
      let toggle (v : string) =
        let next =
          if List.exists value ~f:(fun x -> String.equal x v)
          then List.filter value ~f:(fun x -> not (String.equal x v))
          else value @ [ v ]
        in
        let selectable_count = List.length all_options in
        let chosen =
          List.length
            (List.filter
               next
               ~f:(fun x -> List.exists all_options ~f:(fun o -> String.equal o.value x)))
        in
        let announcement =
          if chosen = 0 then "Selection cleared"
          else if selectable_count > 0 && chosen = selectable_count then "All selected"
          else string_of_int chosen ^ " of " ^ string_of_int selectable_count ^ " selected"
        in
        Effect.Many [ on_change next; set_panel (fun p -> { p with announcement }) ]
      in
      let clear () =
        Effect.Many
          [ on_change []; set_panel (fun p -> { p with announcement = "Selection cleared" }) ]
      in
      let reset_panel () =
        set_panel (fun p ->
            { p with
              search_query = ""
            ; highlighted = -1
            ; selected_at_open = []
            ; announcement = ""
            })
      in
      (* The search box holds the query in the DOM; the model holds it too, so
         the list can filter on it. Clearing the model has to clear the box
         with it, or the box would keep text the list no longer filters by. *)
      let clear_search_box () =
        Effect.of_thunk (fun () ->
            match by_id search_id with
            | Some el ->
              ignore
                (Js.Unsafe.meth_call el "value" [| Js.Unsafe.inject (Js.string "") |])
            | None -> ())
      in
      let open_effect =
        Effect.Many
          [ set_open true
          ; observe true
          ; set_panel (fun p -> { p with selected_at_open = value })
          ; (if has_search
             then
               Effect.of_thunk (fun () ->
                   Menu_focus.focus_on_next_frame (fun () ->
                       Option.iter (by_id search_id) ~f:focus_el))
               else Effect.Ignore)
          ]
      in
      let close_effect =
        Effect.Many
          [ set_open false
          ; observe false
          ; reset_panel ()
          ; clear_search_box ()
          ; Effect.of_thunk (fun () ->
              Menu_focus.focus_on_next_frame (fun () ->
                  Option.iter (by_id trigger_id) ~f:focus_el))
          ]
      in
      let platform_close_effect = close_effect in
      (* Upstream's trigger click: open, or close and reset. *)
      let trigger_click (_ : Dom_html.mouseEvent Js.t) =
        if is_disabled then Effect.Ignore
        else if is_open then close_effect
        else
          Effect.Many
            [ open_effect
            ; set_panel (fun p -> { p with highlighted = if has_search then -1 else 0 })
            ]
      in
      (* Upstream's keyboard model, over the options the list is showing. *)
      let model_keydown (ev : Dom_html.keyboardEvent Js.t) : unit Effect.t =
        let key = key_of ev in
        if is_disabled then Effect.Ignore
        else
          match key with
          | "ArrowDown" ->
            Common.prevent_default ev;
            if is_open then
              set_panel (fun p ->
                let position = position_of p.highlighted enabled_indices in
                let next = Int.min (position + 1) (List.length enabled_indices - 1) in
                match nth_opt enabled_indices next with
                | Some i -> { p with highlighted = i }
                | None -> p)
            else
              Effect.Many [ open_effect; set_panel (fun p -> { p with highlighted = 0 }) ]
          | "ArrowUp" ->
            Common.prevent_default ev;
            if is_open then
              set_panel (fun p ->
                let position = position_of p.highlighted enabled_indices in
                let previous = Int.max (position - 1) 0 in
                match nth_opt enabled_indices previous with
                | Some i -> { p with highlighted = i }
                | None -> p)
            else
              Effect.Many
                [ open_effect
                ; set_panel (fun p -> { p with highlighted = List.length selectable - 1 })
                ]
          | "Enter" | " " ->
            (* Space belongs to the search box when there is one. *)
            if String.equal key " " && has_search then Effect.Ignore
            else (
              Common.prevent_default ev;
              if is_open then
                (match nth_opt selectable panel.highlighted with
                | Some o when not o.is_disabled -> toggle o.value
                | _ -> Effect.Ignore)
              else
                Effect.Many
                  [ open_effect
                  ; set_panel (fun p -> { p with highlighted = if has_search then -1 else 0 })
                  ])
          | "Tab" -> if is_open then close_effect else Effect.Ignore
          | "Escape" ->
            if is_open then
              (
                Common.prevent_default ev;
                close_effect)
            else Effect.Ignore
          | "Home" | "PageUp" ->
            Common.prevent_default ev;
            if is_open then
              (match enabled_indices with
              | first :: _ -> set_panel (fun p -> { p with highlighted = first })
              | [] -> Effect.Ignore)
            else Effect.Ignore
          | "End" | "PageDown" ->
            Common.prevent_default ev;
            if is_open then
              (match List.rev enabled_indices with
              | last :: _ -> set_panel (fun p -> { p with highlighted = last })
              | [] -> Effect.Ignore)
            else Effect.Ignore
          | "Delete" | "Backspace" ->
            (* The keyboard equivalent of the clear button. *)
            if (not has_search) && (not is_open) && has_clear && not (List.is_empty value) then
              (
                Common.prevent_default ev;
                clear ())
            else Effect.Ignore
          | _ ->
            (* Typeahead: the letters typed jump to the option that starts with
               them. It only applies when there is no search box - the search box
               filters the list instead. *)
            if (not has_search) && String.length key = 1 then
              let now = now_ms () in
              let buffer =
                if Float.(now -. panel.typeahead_at > 500.) then key
                else String.lowercase (panel.typeahead ^ key)
              in
              let match_index =
                List.findi
                  selectable
                  ~f:(fun _ o ->
                    (not o.is_disabled)
                    && String.is_prefix
                         (String.lowercase (label_of o))
                         ~prefix:(String.lowercase buffer))
              in
              Effect.Many
                [ set_panel (fun p -> { p with typeahead = buffer; typeahead_at = now })
                ; (match match_index with
                  | Some (i, _) ->
                    Effect.Many
                      [ (if not is_open then open_effect else Effect.Ignore)
                      ; set_panel (fun p -> { p with highlighted = i })
                      ]
                  | None -> Effect.Ignore)
                ]
            else Effect.Ignore
      in
      (* The search box forwards the keys that belong to the list; Space and
         Home/End stay in the box, as the APG editable combobox wants. *)
      let search_keydown (ev : Dom_html.keyboardEvent Js.t) : unit Effect.t =
        let key = key_of ev in
        match key with
        | "ArrowDown" | "ArrowUp" | "PageUp" | "PageDown" | "Enter" | "Escape" ->
          model_keydown ev
        | _ -> Effect.Ignore
      in
      let set_query (query : string) =
        let count =
          List.length (List.filter all_options ~f:(fun o -> matches_query o query))
        in
        set_panel (fun p ->
            { p with
              search_query = query
            ; announcement = (if String.is_empty query then "" else string_of_int count ^ " results")
            })
      in
      (* --- the DOM --- *)
      let effective_status_variant =
        match variant with
        | Input -> status_variant
        | Secondary | Ghost -> Field_status.Detached
      in
      let is_effectively_required = is_required && not is_optional in
      let status_message =
        match status with
        | Some { Input_types.message = Some message; _ } when not (String.is_empty message) ->
          Some message
        | _ -> None
      in
      let described_by =
        List.filter_opt
          [ (if Option.is_some description then Some description_id else None)
          ; (match status_message with
             | Some _ -> Some status_id
             | None -> None)
          ]
        |> String.concat ~sep:" "
      in
      let trigger_content =
        if List.is_empty value then
          [ Vdom.Node.span
              ~attrs:
                (Attr.class_
                   [ "astryx-multi-selector__trigger-text"
                   ; "astryx-multi-selector__placeholder"
                   ])
              [ Vdom.Node.text placeholder ]
          ]
        else
          match trigger_display with
          | Count ->
            [ Vdom.Node.span
                ~attrs:(Attr.class_ [ "astryx-multi-selector__trigger-text" ])
                [ Vdom.Node.text count_text ]
            ]
          | Labels ->
            [ Vdom.Node.span
                ~attrs:(Attr.class_ [ "astryx-multi-selector__trigger-text" ])
                [ Vdom.Node.text labels_text ]
            ]
          | Badges ->
            [ Vdom.Node.span
                ~attrs:(Attr.class_ [ "astryx-multi-selector__trigger-badges" ])
                badges_nodes
            ]
      in
      let trigger_button =
        Vdom.Node.button
          ~attrs:
            ([ Vdom.Attr.id trigger_id
             ; Vdom.Attr.create "type" "button"
             ; Vdom.Attr.create "aria-haspopup" "listbox"
             ; Vdom.Attr.create "aria-expanded" (Bool.to_string is_open)
             ; Vdom.Attr.create "aria-controls" listbox_id
             ; Vdom.Attr.create "aria-labelledby" label_id
             ]
             @ (if has_search then [] else [ Vdom.Attr.create "role" "combobox" ])
             @ (if String.is_empty active_descendant_id || has_search
                then []
                else [ Vdom.Attr.create "aria-activedescendant" active_descendant_id ])
             @ (if is_effectively_required then [ Vdom.Attr.create "aria-required" "true" ] else [])
             @ (match status with
                | Some { Input_types.type_ = Error; _ } -> [ Vdom.Attr.create "aria-invalid" "true" ]
                | _ -> [])
             @ (if is_loading then [ Vdom.Attr.create "aria-busy" "true" ] else [])
             @ (if String.is_empty described_by then [] else [ Vdom.Attr.create "aria-describedby" described_by ])
             @ (if is_disabled then [ Vdom.Attr.create "disabled" "disabled" ] else [])
             @ [ Vdom.Attr.on_click trigger_click
               ; Vdom.Attr.on_keydown model_keydown
               ])
          [ Vdom.Node.span
              ~attrs:(Attr.class_ [ "astryx-multi-selector__trigger-content" ])
              trigger_content
          ]
      in
      let clear_button =
        if has_clear && (not (List.is_empty value)) && not is_disabled then
          [ Vdom.Node.button
              ~attrs:
                [ Vdom.Attr.create "type" "button"
                ; Vdom.Attr.class_ "astryx-multi-selector__clear"
                ; Vdom.Attr.create "aria-label" ("Clear " ^ label)
                ; Vdom.Attr.on_click (fun (_ : Dom_html.mouseEvent Js.t) -> clear ())
                ]
              [ Icon.view ~name:"close" ~size:Icon.Xsm ~color:Icon.Secondary () ]
          ]
        else []
      in
      let indicator_node =
        match status with
        | Some { Input_types.type_ = type_; _ }
          when (match status_variant with
                | Field_status.Detached -> false
                | Field_status.Attached | Field_status.Tooltip -> true) ->
          [ Vdom.Node.span
              ~attrs:(Attr.class_ [ "astryx-multi-selector__status-icon" ])
              [ Icon.view
                  ~name:(status_icon_name type_)
                  ~size:Icon.Sm
                  ~color:(status_icon_color type_)
                  ()
              ]
          ]
        | _ ->
          [ Icon.view
              ~name:"chevronDown"
              ~size:Icon.Sm
              ~color:Icon.Secondary
              ~attrs:
                (Attr.class_
                   ([ "astryx-multi-selector__indicator" ]
                   @ (if is_open then [ "astryx-multi-selector__indicator--open" ] else [])))
              ()
          ]
      in
      let control_box_attrs =
        Attr.class_
          ([ "astryx-multi-selector" ]
           @ (match variant with
              | Input -> []
              | Secondary -> [ "astryx-multi-selector--secondary" ]
              | Ghost -> [ "astryx-multi-selector--ghost" ])
           @ (match status with
              | Some { Input_types.type_; _ } -> [ "astryx-multi-selector--" ^ status_string type_ ]
              | None -> [])
           @ (if is_disabled then [ "astryx-multi-selector--disabled" ] else [])
           @ (if List.is_empty value then [ "astryx-multi-selector--placeholder" ] else []))
        @ Attr.data "component" "MultiSelector"
        @ [ Vdom.Attr.create "data-astryx-size" (size_string size) ]
        @ attrs
      in
      let control_box =
        Vdom.Node.div
          ~attrs:control_box_attrs
          ((match start_icon with
            | Some name ->
              [ Vdom.Node.span
                  ~attrs:(Attr.class_ [ "astryx-multi-selector__start-icon" ])
                  [ Icon.view ~name ~size:Icon.Sm ~color:Icon.Secondary () ]
              ]
            | None -> [])
          @ [ trigger_button ]
          @ (match html_name with
             | Some name ->
               List.map
                 ~f:(fun v ->
                   let attrs =
                     [ Vdom.Attr.create "type" "hidden"
                     ; Vdom.Attr.create "name" name
                     ; Vdom.Attr.create "value" v
                     ]
                     @ (if is_disabled then [ Vdom.Attr.create "disabled" "disabled" ] else [])
                   in
                   Vdom.Node.input ~attrs ())
                 value
             | None -> [])
          @ (if is_loading
             then
               [ Vdom.Node.span
                   ~attrs:(Attr.class_ [ "astryx-multi-selector__spinner" ])
                   [ Spinner.view ~size:Spinner.Sm () ]
               ]
             else [])
          @ clear_button
          @ indicator_node)
      in
      (* Upstream's option row: the indicator is decorative - the row itself
         carries the selection state through aria-selected - so the checkbox is
         rendered inert, the way upstream renders it. *)
      let option_checkbox (o : option_data) (is_selected : bool) (index : int) =
        Vdom.Node.div
          ~attrs:
            (Attr.class_ [ "astryx-multi-selector__option-checkbox" ]
             @ [ Vdom.Attr.create "inert" "true" ])
          [ Checkbox_input.render
              ~label:""
              ~is_label_hidden:true
              ~id:(listbox_id ^ "-checkbox-" ^ string_of_int index)
              ~value:(if is_selected then Indicator.Checked else Indicator.Unchecked)
              ~on_change:(fun (_ : Indicator.state) -> Effect.Ignore)
              ~is_disabled:o.is_disabled
              ~size:(match size with Sm -> Indicator.Sm | Md | Lg -> Indicator.Md)
              ()
          ]
      in
      let option_row (o : option_data) (index : int) =
        let item_id = listbox_id ^ "-item-" ^ string_of_int index in
        let is_selected = List.exists value ~f:(fun v -> String.equal o.value v) in
        let is_highlighted = Int.equal panel.highlighted index in
        let indicator =
          let at_start =
            match indicator_position with
            | Start -> true
            | End -> false
          in
          if at_start then [ option_checkbox o is_selected index ] else []
        in
        let indicator =
          let at_end =
            match indicator_position with
            | End -> true
            | Start -> false
          in
          if at_end then [ option_checkbox o is_selected index ] else indicator
        in
        let option_row_attrs =
          Attr.class_
            ([ "astryx-multi-selector__option" ]
             @ (if is_highlighted then [ "astryx-multi-selector__option--highlighted" ] else [])
             @ (if o.is_disabled then [ "astryx-multi-selector__option--disabled" ] else []))
          @ [ Vdom.Attr.id item_id
            ; Vdom.Attr.create "role" "option"
            ; Vdom.Attr.create "aria-selected" (Bool.to_string is_selected)
            ; Vdom.Attr.create "aria-disabled" (Bool.to_string o.is_disabled)
            ; Vdom.Attr.on_click (fun (_ : Dom_html.mouseEvent Js.t) ->
                if o.is_disabled then Effect.Ignore else toggle o.value)
            ; Vdom.Attr.on_mouseenter (fun (_ : Dom_html.mouseEvent Js.t) ->
                if o.is_disabled then Effect.Ignore
                else
                  Effect.Many
                    [ set_panel (fun p -> { p with highlighted = index })
                    ; Effect.of_thunk (fun () ->
                        Option.iter (by_id item_id) ~f:scroll_into_view)
                    ])
            ]
        in
        Vdom.Node.div
          ~attrs:option_row_attrs
          (indicator
          @ [ Vdom.Node.span
                ~attrs:(Attr.class_ [ "astryx-multi-selector__option-label" ])
                [ Vdom.Node.text (label_of o) ]
            ]
          @ (match o.description with
             | Some description ->
               [ Vdom.Node.span
                   ~attrs:(Attr.class_ [ "astryx-multi-selector__option-description" ])
                   [ Vdom.Node.text description ]
               ]
             | None -> []))
      in
      let option_nodes =
        let index = ref 0 in
        let nodes = ref [] in
        let add node = nodes := node :: !nodes in
        let add_option o =
          let node = option_row o !index in
          add node;
          incr index;
          node
        in
        (* A section's rows live INSIDE the section's group, so they are made
           here but not added to the list: adding them would render the row
           twice, and the second copy would carry the same id. *)
        let make_option o =
          let node = option_row o !index in
          incr index;
          node
        in
        let divider_node () =
          (* A divider between two groups would orphan itself once the search
             filters its neighbours out, so it goes while searching. *)
          if not (String.is_empty panel.search_query) then None
          else
            Some
              (Vdom.Node.div
                 ~attrs:
                   [ Vdom.Attr.create "aria-hidden" "true"
                   ; Vdom.Attr.class_ "astryx-multi-selector__divider"
                   ]
                 [ Divider.view () ])
        in
        let section_node title items =
          let rows = List.map items ~f:make_option in
          let heading =
            match title with
            | Some t ->
              [ Vdom.Node.div
                  ~attrs:
                    [ Vdom.Attr.create "aria-hidden" "true"
                    ; Vdom.Attr.class_ "astryx-multi-selector__section-heading"
                    ]
                  [ Vdom.Node.text t ]
              ]
            | None -> []
          in
          let attrs =
            [ Vdom.Attr.create "role" "group" ]
            @ (match title with
               | Some t -> [ Vdom.Attr.create "aria-label" t ]
               | None -> [])
            @ Attr.class_ [ "astryx-multi-selector__section" ]
          in
          [ Vdom.Node.div ~attrs (heading @ List.rev rows) ]
        in
        List.iter
          groups
          ~f:(fun group ->
            match group with
            | Group_flat items ->
              List.iter (group_items items) ~f:(fun o -> ignore (add_option o))
            | Group_divider ->
              (match divider_node () with
              | Some node -> add node
              | None -> ())
            | Group_section (title, items) ->
              let items = group_items items in
              if not (List.is_empty items) then
                List.iter (section_node title items) ~f:(fun node -> add node));
        List.rev !nodes
      in
      let listbox_children =
        if List.length selectable = 0 && not is_loading then
          [ Vdom.Node.div
              ~attrs:
                ([ Vdom.Attr.create "role" "presentation" ]
                @ Attr.class_ [ "astryx-multi-selector__empty" ])
              [ Vdom.Node.text
                  (if String.is_empty panel.search_query then empty_text else empty_search_text)
              ]
          ]
        else option_nodes
      in
      let listbox_attrs =
        Attr.class_ [ "astryx-multi-selector__listbox" ]
        @ [ Vdom.Attr.id listbox_id
          ; Vdom.Attr.create "role" "listbox"
          ; Vdom.Attr.create "aria-multiselectable" "true"
          ; Vdom.Attr.create "aria-labelledby" trigger_id
          ]
        @ (if String.is_empty active_descendant_id || has_search
           then []
           else [ Vdom.Attr.create "aria-activedescendant" active_descendant_id ])
      in
      let listbox =
        Vdom.Node.div
          ~attrs:listbox_attrs
          listbox_children
      in
      let search_row =
        if not has_search then []
        else
          [ Vdom.Node.div
              ~attrs:(Attr.class_ [ "astryx-multi-selector__search" ])
              [ Vdom.Node.span
                  ~attrs:(Attr.class_ [ "astryx-multi-selector__search-icon" ])
                  [ Icon.view ~name:"search" ~size:Icon.Sm ~color:Icon.Secondary () ]
              ; Vdom.Node.input
                  ~attrs:
                    ([ Vdom.Attr.id search_id
                     ; Vdom.Attr.create "type" "text"
                     ; Vdom.Attr.create "role" "combobox"
                     ; Vdom.Attr.create "aria-expanded" (Bool.to_string is_open)
                     ; Vdom.Attr.create "aria-controls" listbox_id
                     ; Vdom.Attr.create "aria-autocomplete" "list"
                     ; Vdom.Attr.create "aria-label" "Search options"
                     ; Vdom.Attr.create "placeholder" search_placeholder
                     ; Vdom.Attr.value panel.search_query
                     ; Vdom.Attr.on_input (fun (_ : Dom_html.event Js.t) v -> set_query v)
                     ; Vdom.Attr.on_keydown search_keydown
                     ])
                  ()
              ]
          ]
      in
      let popup =
        Vdom.Node.div
          ~attrs:
            ([ Vdom.Attr.id popover_id
             ; Vdom.Attr.create "popover" "auto"
             ; Vdom.Attr.create "role" "none"
             ]
             @ Attr.class_ [ "astryx-multi-selector__popover" ]
             @ [ Common.Layer_hook.attr ~is_open ~on_platform_close:platform_close_effect ])
          (search_row
          @ (if has_search then [ Divider.view () ] else [])
          @ [ listbox ])
      in
      (* Upstream announces the selection count and the result count through the
         application's announcer. The port has no announcer to write to, so it
         hosts its own polite live region, the way the house's other components
         do. *)
      let announcement_node =
        Vdom.Node.div
          ~attrs:
            [ Vdom.Attr.class_ "astryx-visually-hidden"
            ; Vdom.Attr.create "role" "status"
            ]
          [ Vdom.Node.text panel.announcement ]
      in
      Field_.view
        ~is_label_hidden
        ?description
        ~is_optional
        ~is_required
        ~is_disabled
        ?status
        ~status_variant:effective_status_variant
        ?width
        ~label
        ~input_id:trigger_id
        ~label_id
        ~children:[ control_box; popup; announcement_node ]
        ())
;;
