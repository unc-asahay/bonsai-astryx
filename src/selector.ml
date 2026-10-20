(* Copyright (c) Meta Platforms, Inc. and affiliates.
   Ported to OCaml/Bonsai from the astryx Selector component.

   The design facts, in the order they shaped this file:

   1. The trigger is OURS. The component builds the control box, the button, the
      spinner, the clear button and the chevron, and the ARIA goes on the button
      it builds — the same arrangement {!Complex_selector} reached for, for the
      same reason: the trigger's ARIA is *state* (expanded, activedescendant,
      readonly, busy), so it cannot be handed in by a caller.
   2. The surface is the native popover mechanism, exactly as {!Popover} and
      {!Complex_selector} use it: [popover="auto"], the house's Layer_hook, and
      CSS anchor positioning against the trigger box. The panel is rendered in
      place — a sibling of the trigger inside the field — because this port has
      no outlet; the platform lifts it into the top layer.
   3. The focus stays on the trigger. The listbox carries the exposed semantics
      ([role="listbox"] on the list, [role="row"] on each row) and the
      highlight is reported with [aria-activedescendant] on whichever element
      holds the focus: the trigger normally, the search input when there is
      one. That is upstream's own arrangement (ARIA AR2), not a port decision.
   4. The typeahead runs on the model. Upstream's shared typeahead reads the
      rows' text out of the DOM; here the rows are never focused, so the
      matching runs over the row labels in the model instead.

   The one place this port diverges on purpose: the panel always opens *below*
   the trigger. Upstream pulls the panel up so the selected row sits over the
   trigger (its FR2) — that is an overlay alignment rather than a placement,
   and the house has no equivalent of it. *)

(* This library's own Field, bound before the opens below. Core defines a module
   named Field as well (first-class fields), so after [open! Core] the
   unqualified name refers to Core's — and this module would silently fail to
   compile against it. Same arrangement text_input.ml makes. *)
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

type indicator_position =
  | Start
  | End
;;

type option_data =
  { value : string  (** the option's value; what [on_change] reports *)
  ; label : string option  (** the option's label; [value] when absent *)
  ; description : Vdom.Node.t option  (** a second line under the label *)
  ; icon : string option  (** an icon {i name}, rendered at the row's start *)
  ; is_disabled : bool  (** a disabled row cannot be picked or highlighted *)
  }
;;

type section =
  { title : string option  (** the group's name; the heading is drawn from it *)
  ; options : option_data list
  }
;;

(* The smart constructor comes before the union of the same name on purpose: the
   union shadows the standard [row] from here on, and the constructor's
   [~label] argument is an ordinary optional string. When no label is given the
   field stays empty and the row falls back to its value where it is drawn. *)
let row ~value ?label ?description ?icon ?(is_disabled = false) () =
  { value
  ; label
  ; description
  ; icon
  ; is_disabled
  }
;;

type row =
  | Row of option_data  (** a selectable row *)
  | Divider  (** a rule between rows; hidden from assistive technology *)
  | Section of section  (** a titled group of rows *)
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

(* ------------------------------------------------------------- class names *)

let variant_class = function
  | Input -> None
  | Secondary -> Some "astryx-selector--secondary"
  | Ghost -> Some "astryx-selector--ghost"
;;

let size_name = function
  | Sm -> "sm"
  | Md -> "md"
  | Lg -> "lg"
;;

let status_class (type_ : Field_status.type_) =
  match type_ with
  | Field_status.Warning -> Some "astryx-selector--warning"
  | Field_status.Error -> Some "astryx-selector--error"
  | Field_status.Success -> Some "astryx-selector--success"
;;

(* ------------------------------------------------------------- the model *)

(* The component owns three things upstream keeps in React state: whether the
   panel is open, which row is highlighted, and the search query. The typeahead
   buffer is upstream's own (a ref with a timer), so it is kept with a stamp
   instead — the same 750ms of inactivity upstream waits for, without a timer. *)
type model =
  { is_open : bool
  ; highlight : int  (** the flat index of the highlighted row; [-1] for none *)
  ; query : string  (** the search query *)
  ; typeahead : string  (** the typed-ahead prefix *)
  ; typeahead_at : float  (** when it was last typed, in milliseconds *)
  }
;;

(* What the panel renders, in render order. The flat index travels with each
   row because it is the row's identity: it names the element (the id the
   trigger's [aria-activedescendant] points at) and it is the highlight's
   position. One index space for both, so the two can never drift apart. *)
type visible =
  | Visible_row of option_data * int
  | Visible_divider
  | Visible_group of string option * (option_data * int) list
;;

let label_of (data : option_data) : string =
  Option.value data.label ~default:data.value
;;

(* Upstream's own filter: a case-insensitive substring match on the label. *)
let matches_query (data : option_data) (query : string) : bool =
  String.is_empty query
  || String.is_substring
       (String.lowercase (label_of data))
       ~substring:(String.lowercase query)
;;

(* The rows the panel shows, in render order. A section whose rows are all
   filtered out disappears with its heading, and a divider is dropped while
   searching — upstream's own rules, for the same reasons: a heading standing
   over nothing, and a divider orphaned by the filtering. *)
let build_visible (query : string) (options : row list) : visible list =
  let counter = ref 0 in
  let next_index () =
    let index = !counter in
    incr counter;
    index
  in
  let rec go (options : row list) (acc : visible list) =
    match options with
    | [] -> List.rev acc
    | Row data :: rest ->
      if not (matches_query data query)
      then go rest acc
      else go rest (Visible_row (data, next_index ()) :: acc)
    | Divider :: rest ->
      if String.is_empty query then go rest (Visible_divider :: acc) else go rest acc
    | Section section :: rest ->
      let rows =
        List.filter_map
          ~f:(fun data ->
            if matches_query data query
            then Some (data, next_index ())
            else None)
          section.options
      in
      if List.is_empty rows then go rest acc else go rest (Visible_group (section.title, rows) :: acc)
  in
  go options []
;;

(* The flat row list the keyboard walks: every visible row, in order, with its
   flat index. Sections contribute their rows in place; dividers contribute
   nothing — they are not rows and cannot be highlighted. *)
let visible_rows (visible : visible list) : (option_data * int) list =
  List.concat_map
    ~f:(function
      | Visible_row (data, index) -> [ (data, index) ]
      | Visible_group (_, rows) -> rows
      | Visible_divider -> [])
    visible
;;

(* [String.starts_with] without the library-version question: the house's Core
   and the stdlib spell this differently, and the behaviour is one line. *)
let starts_with (prefix : string) (s : string) : bool =
  let n = String.length prefix in
  String.length s >= n && String.equal (String.sub s ~pos:0 ~len:n) prefix
;;

(* ------------------------------------------------------------------- view *)

let view
      ?(attrs = [])
      ?(id = "astryx-selector")
      ?(is_label_hidden = false)
      ?description
      ?(is_optional = false)
      ?(is_required = false)
      ?(is_disabled = false)
      ?(is_read_only = false)
      ?disabled_message
      ?(is_loading = false)
      ?status
      ?(status_variant = Field_status.Attached)
      ?(size = Md)
      ?(variant = Input)
      ?(placeholder = "Select...")
      ?start_icon
      ?width
      ?html_name
      ?(has_clear = false)
      ?(has_search = false)
      ?(search_placeholder = "Search...")
      ?(empty_text = "No options")
      ?(empty_search_text = "No results found")
      ?(indicator_position = End)
      ?(is_default_open = false)
      ?render_option
      ?render_value
      ~label
      ~options
      ~value
      ~on_change
      (graph : Bonsai.graph)
  =
  let trigger_id = id in
  let listbox_id = id ^ "-listbox" in
  let panel_id = id ^ "-panel" in
  let label_id = id ^ "-label" in
  let description_id = id ^ "-desc" in
  let disabled_message_id = id ^ "-disabled-message" in
  let search_id = id ^ "-search" in
  let clear_id = id ^ "-clear" in
  let item_id index = listbox_id ^ "-item-" ^ string_of_int index in
  let initial_model =
    { is_open = is_default_open
    ; highlight = -1
    ; query = ""
    ; typeahead = ""
    ; typeahead_at = 0.0
    }
  in
  let model, set_model = Bonsai.state' initial_model graph in
  let value_and_change = Bonsai.map2 value on_change ~f:(fun value on_change -> (value, on_change)) in
  Bonsai.map3 model set_model value_and_change
    ~f:(fun model set_model (value, on_change) ->
    (* ------------------------------------------------------- the rows *)
    let visible = build_visible model.query options in
    let rows = visible_rows visible in
    let enabled_rows = List.filter ~f:(fun (data, _) -> not data.is_disabled) rows in
    (* The selected row is looked up in *all* the options, not in the
       visible ones: the trigger shows the selection even while the query
       filters it out of the panel. *)
    let all_options =
      List.concat_map
        ~f:(function
          | Row data -> [ data ]
          | Section section -> section.options
          | Divider -> [])
        options
    in
    let selected_option =
      match value with
      | None -> None
      | Some chosen -> List.find ~f:(fun data -> String.equal data.value chosen) all_options
    in
    let selected_index =
      match value with
      | None -> -1
      | Some chosen -> (
        match List.find ~f:(fun (data, _) -> String.equal data.value chosen) rows with
        | Some (_, index) -> index
        | None -> -1)
    in
    (* -------------------------------------------------- state transitions *)
    let set_highlight index = set_model (fun m -> { m with highlight = index }) in
    let close () =
      Effect.Many
        [ set_model
            (fun _m ->
              ({ is_open = false
               ; highlight = -1
               ; query = ""
               ; typeahead = ""
               ; typeahead_at = 0.0
               } : model))
        (* Upstream restores the focus to the trigger on every hide: the trigger
           is the anchor of the whole widget, and a focus that fell to the body
           with the panel is a focus nobody can find again. *)
        ; Effect.of_thunk (fun () ->
            Menu_focus.focus_on_next_frame (fun () ->
              Option.iter (by_id trigger_id) ~f:focus_el))
        ]
    in
    let focus_search () =
      Menu_focus.focus_on_next_frame (fun () -> Option.iter (by_id search_id) ~f:focus_el)
    in
    let open_panel () =
      let highlight =
        if has_search
        then -1
        else if selected_index >= 0
        then selected_index
        else (
          match enabled_rows with
          | (_, index) :: _ -> index
          | [] -> -1)
      in
      Effect.Many
        [ set_model
            (fun _m ->
              ({ is_open = true
               ; highlight
               ; query = ""
               ; typeahead = ""
               ; typeahead_at = 0.0
               } : model))
        (* With a search row, the focus moves into the search input on open —
           upstream's own arrangement, and the reason the search input is the
           combobox while the panel is up. *)
        ; if has_search then Effect.of_thunk focus_search else Effect.Ignore
        ]
    in
    let toggle () = if model.is_open then close () else open_panel () in
    let select_value chosen =
      Effect.Many [ on_change (Some chosen); close () ]
    in
    let clear_value () = on_change None in
    (* The platform took the surface down (Escape, an outside pointer). *)
    let platform_close () =
      Effect.Many
        [ set_model
            (fun _m ->
              ({ is_open = false
               ; highlight = -1
               ; query = ""
               ; typeahead = ""
               ; typeahead_at = 0.0
               } : model))
        ; Effect.of_thunk (fun () ->
            Menu_focus.focus_on_next_frame (fun () ->
              Option.iter (by_id trigger_id) ~f:focus_el))
        ]
    in
    (* ------------------------------------------------- keyboard navigation *)
    let next_enabled () =
      match enabled_rows with
      | [] -> None
      | _ -> (
        match List.find ~f:(fun (_, index) -> index > model.highlight) enabled_rows with
        | Some (_, index) -> Some index
        | None -> (
          match List.rev enabled_rows with
          | (_, index) :: _ -> Some index
          | [] -> None))
    in
    let prev_enabled () =
      match enabled_rows with
      | [] -> None
      | _ -> (
        match List.find ~f:(fun (_, index) -> index < model.highlight) (List.rev enabled_rows) with
        | Some (_, index) -> Some index
        | None -> (
          match enabled_rows with
          | (_, index) :: _ -> Some index
          | [] -> None))
    in
    let first_enabled () = match enabled_rows with (_, index) :: _ -> Some index | [] -> None in
    let last_enabled () =
      match List.rev enabled_rows with (_, index) :: _ -> Some index | [] -> None
    in
    (* The typeahead: a typed prefix moves the highlight to the next row whose
       label starts with it. Upstream's shared hook does the same over the
       DOM's text; here it runs over the model. The same character repeated
       cycles through the matches rather than digging deeper, and a pause of
       750ms starts a fresh prefix — upstream's own rules. *)
    let typeahead (key : string) =
      let rows_array = Array.of_list rows in
      let count = Array.length rows_array in
      if count = 0
      then Effect.Ignore
      else (
        let char = String.lowercase key in
        let now = Js.to_float (Js.Unsafe.coerce (Js.Unsafe.pure_js_expr "Date.now()")) in
        let buffer =
          if Float.compare (now -. model.typeahead_at) 750. > 0
          then char
          else if
            String.is_empty model.typeahead
            || not (String.equal model.typeahead char)
          then model.typeahead ^ char
          else char
        in
        let start = if model.highlight >= 0 then model.highlight else 0 in
        let offset = if model.highlight >= 0 && String.length buffer = 1 then 1 else 0 in
        let rec find i =
          if i >= count
          then None
          else
            let position = (start + offset + i) mod count in
            let (data, index) = rows_array.(position) in
            if data.is_disabled
            then find (i + 1)
            else if starts_with buffer (String.lowercase (String.strip (label_of data)))
            then Some index
            else find (i + 1)
        in
        match find 0 with
        | Some index ->
          set_model (fun m -> { m with highlight = index; typeahead = buffer; typeahead_at = now })
        | None -> set_model (fun m -> { m with typeahead = buffer; typeahead_at = now }))
    in
    (* One key handler, shared by the trigger and the search input. The search
       input differs in two ways, both upstream's: Home and End stay with the
       caret (the editable-combobox pattern), and a space types a space. *)
    let handle_key (ev : Dom_html.keyboardEvent Js.t) ~(is_search_input : bool) : unit Effect.t =
      if is_disabled
      then Effect.Ignore
      else
        let key = key_of ev in
        match key with
        | "ArrowDown" ->
          Common.prevent_default ev;
          if model.is_open
          then (
            match next_enabled () with
            | Some index -> set_highlight index
            | None -> Effect.Ignore)
          else open_panel ()
        | "ArrowUp" ->
          Common.prevent_default ev;
          if model.is_open
          then (
            match prev_enabled () with
            | Some index -> set_highlight index
            | None -> Effect.Ignore)
          else
            (* Opening upwards lands on the last row — upstream's own rule. *)
            Effect.Many
              [ open_panel ()
              ; (match last_enabled () with
                 | Some index -> set_highlight index
                 | None -> Effect.Ignore)
              ]
        | "Enter" ->
          Common.prevent_default ev;
          if model.is_open
          then (
            (* The highlight is the flat index of the row, so the row is
               looked up by that index rather than taken from the head of
               the list — the highlighted row is rarely the first one. *)
            match List.find ~f:(fun (_, index) -> index = model.highlight) rows with
            | Some (data, _) when not data.is_disabled -> select_value data.value
            | _ -> Effect.Ignore)
          else open_panel ()
        | " " ->
          if is_search_input
          then Effect.Ignore
          else if not (String.is_empty model.typeahead)
          then (
            (* A space in the middle of a typeahead extends the prefix rather
               than activating the row — upstream's rule, and the reason a
               multi-word label can be typed. *)
            Common.prevent_default ev;
            typeahead key)
          else if model.is_open
          then (
            Common.prevent_default ev;
            match rows with
            | (data, index) :: _ when index = model.highlight && not data.is_disabled ->
              select_value data.value
            | _ -> Effect.Ignore)
          else Effect.Ignore
        | "Escape" ->
          if model.is_open
          then (
            Common.prevent_default ev;
            close ())
          else Effect.Ignore
        | "Tab" ->
          (* The focus is leaving the widget: the panel closes, and the focus
             is not held back. *)
          if model.is_open then close () else Effect.Ignore
        | "Home" ->
          if is_search_input || not model.is_open
          then Effect.Ignore
          else (
            Common.prevent_default ev;
            match first_enabled () with
            | Some index -> set_highlight index
            | None -> Effect.Ignore)
        | "End" ->
          if is_search_input || not model.is_open
          then Effect.Ignore
          else (
            Common.prevent_default ev;
            match last_enabled () with
            | Some index -> set_highlight index
            | None -> Effect.Ignore)
        | "PageUp" ->
          if not model.is_open
          then Effect.Ignore
          else (
            Common.prevent_default ev;
            match first_enabled () with
            | Some index -> set_highlight index
            | None -> Effect.Ignore)
        | "PageDown" ->
          if not model.is_open
          then Effect.Ignore
          else (
            Common.prevent_default ev;
            match last_enabled () with
            | Some index -> set_highlight index
            | None -> Effect.Ignore)
        | "Delete" | "Backspace" ->
          (* The keyboard equivalent of the clear button: clearing is not
             mouse-only. Only the closed, non-searching trigger clears — while
             the panel is open the arrow keys own the interaction, and with a
             search row these keys belong to the query. *)
          if
            (not has_search)
            && (not model.is_open)
            && has_clear
            && Option.is_some value
          then (
            Common.prevent_default ev;
            clear_value ())
          else Effect.Ignore
        | _ ->
          (* A printable character. With a search row it seeds the query and
             opens the panel; without one it is the typeahead. *)
          if
            String.length key = 1
            && not (Common.bool_prop ev "ctrlKey")
            && not (Common.bool_prop ev "metaKey")
            && not (Common.bool_prop ev "isComposing")
          then (
            Common.prevent_default ev;
            if has_search
            then (
              if model.is_open
              then Effect.Ignore
              else
                Effect.Many
                  [ open_panel ()
                  ; set_model (fun m -> { m with query = key })
                  ])
            else typeahead key)
          else Effect.Ignore
    in
    (* ------------------------------------------------------------ the trigger *)
    let trigger_value_content =
      match selected_option, render_value with
      | Some data, Some render -> render data
      | Some data, None ->
        let icon_nodes =
          match data.icon, start_icon with
          | Some name, None -> [ Icon.view ~name ~size:Icon.Sm ~color:Icon.Secondary () ]
          | _ -> []
        in
        Vdom.Node.span
          ~attrs:(Attr.class_ [ "astryx-selector__value" ])
          (icon_nodes
          @ [ Vdom.Node.span
                ~attrs:(Attr.class_ [ "astryx-selector__trigger-text" ])
                [ Vdom.Node.text (label_of data) ]
            ])
      | None, _ ->
        Vdom.Node.span
          ~attrs:(Attr.class_ [ "astryx-selector__trigger-text"; "astryx-selector__placeholder" ])
          [ Vdom.Node.text placeholder ]
    in
    let is_effectively_required = is_required && not is_optional in
    (* With a disabled message the trigger keeps its focusability through
       [aria-disabled], so the reason is discoverable; activation stays
       blocked either way. *)
    let shows_disabled_message = is_disabled && Option.is_some disabled_message in
    let described_by =
      List.filter_opt
        [ (if Option.is_some description then Some description_id else None)
        ; (if Option.is_some disabled_message then Some disabled_message_id else None)
        ]
      |> String.concat ~sep:" "
    in
    let trigger_attrs =
      [ Vdom.Attr.id trigger_id
      ; Vdom.Attr.class_ "astryx-selector__trigger"
      ; Vdom.Attr.create "type" "button"
      ; Vdom.Attr.create "aria-expanded" (Bool.to_string (model.is_open && not is_read_only))
      ; Vdom.Attr.create "aria-labelledby" label_id
      ]
      (* A read-only trigger has no surface, so it advertises no popup and owns no
         listbox — upstream's own arrangement. *)
      @ (if is_read_only
         then []
         else
           [ Vdom.Attr.create "aria-haspopup" "listbox"; Vdom.Attr.create "aria-controls" listbox_id ])
      (* The combobox role belongs to the trigger until a search row takes it
         over — upstream's own rule, and the reason the trigger's identity
         does not change when the panel opens. *)
      @ (if has_search && not is_read_only
         then []
         else [ Vdom.Attr.role "combobox" ])
      @ (if is_read_only then [ Vdom.Attr.create "aria-readonly" "true" ] else [])
      @ (if is_effectively_required then [ Vdom.Attr.create "aria-required" "true" ] else [])
      @ (match status with
         | Some { Input_types.type_ = Field_status.Error; _ } ->
           [ Vdom.Attr.create "aria-invalid" "true" ]
         | _ -> [])
      @ (if is_loading then [ Vdom.Attr.create "aria-busy" "true" ] else [])
      @ (if shows_disabled_message then [ Vdom.Attr.create "aria-disabled" "true" ] else [])
      @ (if is_disabled && not shows_disabled_message
         then [ Vdom.Attr.create "disabled" "disabled" ]
         else [])
      @ (if String.is_empty described_by
         then []
         else [ Vdom.Attr.create "aria-describedby" described_by ])
      (* The highlighted row is named by the element that holds the focus. *)
      @ (if model.is_open && model.highlight >= 0 && not has_search && not is_read_only
         then [ Vdom.Attr.create "aria-activedescendant" (item_id model.highlight) ]
         else [])
      @ [ Vdom.Attr.on_click (fun _ -> if is_disabled || is_read_only then Effect.Ignore else toggle ())
        ; Vdom.Attr.on_keydown (fun ev -> handle_key ev ~is_search_input:false)
        ]
    in
    let trigger_button =
      Vdom.Node.button ~attrs:trigger_attrs [ trigger_value_content ]
    in
    let clear_button =
      Vdom.Node.button
        ~attrs:
          ([ Vdom.Attr.id clear_id
           ; Vdom.Attr.create "type" "button"
           ; Vdom.Attr.create "aria-label" ("Clear " ^ label)
           ; Vdom.Attr.class_ "astryx-selector__clear"
           ; Vdom.Attr.on_click (fun _ -> if is_disabled then Effect.Ignore else clear_value ())
           ])
        [ Vdom.Node.span ~attrs:(Attr.class_ [ "astryx-selector__clear-glyph" ]) [ Vdom.Node.text "✕" ] ]
    in
    let hidden_input =
      match html_name with
      | None -> []
      | Some name ->
        (* The way a native select serializes: the value rides along under a
           name, and a disabled control is excluded from the submission. *)
        [ Vdom.Node.input
            ~attrs:
              ([ Vdom.Attr.create "type" "hidden"
               ; Vdom.Attr.name name
               ; Vdom.Attr.value_attr (Option.value value ~default:"")
               ]
              @ (if is_disabled then [ Vdom.Attr.create "disabled" "disabled" ] else []))
            ()
        ]
    in
    let control_box_children =
      (match start_icon with
       | Some name ->
         [ Vdom.Node.span
             ~attrs:(Attr.class_ [ "astryx-selector__start-icon" ])
             [ Icon.view ~name ~size:Icon.Sm ~color:Icon.Secondary () ]
         ]
       | None -> [])
      @ [ trigger_button ]
      @ hidden_input
      @ (if is_loading
         then
           [ Vdom.Node.span
               ~attrs:(Attr.class_ [ "astryx-selector__spinner" ])
               [ Spinner.view ~size:Spinner.Sm () ]
           ]
         else [])
      @ (if has_clear && Option.is_some value && not is_read_only then [ clear_button ] else [])
      @ (if is_read_only
         then []
         else
           [ Icon.view
               ~name:"chevronDown"
               ~size:Icon.Sm
               ~color:Icon.Secondary
               ~attrs:
                 (Attr.class_
                    ([ "astryx-selector__indicator" ]
                     @ (if model.is_open
                        then [ "astryx-selector__indicator--open" ]
                        else [])))
               ()
           ])
    in
    let control_box_attrs =
      Attr.class_
        (List.filter_opt
           ([ Some "astryx-selector"
            ; variant_class variant
            ; Option.bind status ~f:(fun { Input_types.type_; _ } -> status_class type_)
            ; (if is_disabled then Some "astryx-selector--disabled" else None)
            ; (if Option.is_none value then Some "astryx-selector--placeholder" else None)
            ]))
      @ Attr.data "component" "Selector"
      @ [ Vdom.Attr.create "data-astryx-size" (size_name size) ]
      @ attrs
    in
    let control_box = Vdom.Node.div ~attrs:control_box_attrs control_box_children in
    (* ------------------------------------------------------------ the panel *)
    let render_row (data : option_data) (index : int) =
      let is_selected =
        match value with
        | Some chosen -> String.equal data.value chosen
        | None -> false
      in
      let is_highlighted = model.is_open && model.highlight = index in
      let mark =
        Vdom.Node.span
          ~attrs:(Attr.class_ [ "astryx-selector__option-mark" ])
          [ Indicator.view
              ~kind:Indicator.Check
              ~state:(if is_selected then Indicator.Checked else Indicator.Unchecked)
              ~is_disabled:data.is_disabled
              ~size:Indicator.Sm
              ()
          ]
      in
      let content =
        match render_option with
        | Some render -> render data
        | None ->
          let icon_nodes =
            match data.icon with
            | Some name -> [ Icon.view ~name ~size:Icon.Sm ~color:Icon.Secondary () ]
            | None -> []
          in
          Vdom.Node.span
            ~attrs:(Attr.class_ [ "astryx-selector__option-content" ])
            (icon_nodes
            @ [ Vdom.Node.span
                  ~attrs:(Attr.class_ [ "astryx-selector__option-label" ])
                  [ Vdom.Node.text (label_of data) ]
              ]
            @ (match data.description with
               | Some node ->
                 [ Vdom.Node.div
                     ~attrs:(Attr.class_ [ "astryx-selector__option-description" ])
                     [ node ]
                 ]
               | None -> []))
      in
      let row_children =
        match indicator_position with
        | Start -> [ mark; content ]
        | End -> [ content; mark ]
      in
      Vdom.Node.div
        ~attrs:
          ([ Vdom.Attr.id (item_id index)
           ; Vdom.Attr.role "row"
           ; Vdom.Attr.create "aria-selected" (Bool.to_string is_selected)
           ; Vdom.Attr.create "aria-disabled" (Bool.to_string data.is_disabled)
           ]
          @ Attr.class_
              ([ "astryx-selector__option" ]
               @ (if is_selected then [ "astryx-selector__option--selected" ] else [])
               @ (if is_highlighted then [ "astryx-selector__option--highlighted" ] else [])
               @ (if data.is_disabled then [ "astryx-selector__option--disabled" ] else []))
          @ [ Vdom.Attr.on_click (fun _ ->
                if data.is_disabled then Effect.Ignore else select_value data.value)
            ; Vdom.Attr.on_mouseenter (fun _ ->
                if data.is_disabled then Effect.Ignore else set_highlight index)
            ])
        row_children
    in
    let render_visible =
      List.concat_map
        ~f:(function
          | Visible_row (data, index) -> [ render_row data index ]
          | Visible_divider ->
            (* A divider carries no information the options do not, so it is
               hidden from the accessibility tree entirely rather than
               exposing a role the listbox does not allow. *)
            [ Vdom.Node.div
                ~attrs:
                  [ Vdom.Attr.create "aria-hidden" "true"
                  ; Vdom.Attr.class_ "astryx-selector__divider"
                  ]
                []
            ]
          | Visible_group (title, rows) ->
            (* The heading is inside the group and hidden: the group already
               carries the title as its accessible name, so exposing the text
               again would announce it twice. *)
            let heading =
              match title with
              | None -> []
              | Some text ->
                [ Vdom.Node.div
                    ~attrs:
                      [ Vdom.Attr.create "aria-hidden" "true"
                      ; Vdom.Attr.class_ "astryx-selector__group-title"
                      ]
                    [ Vdom.Node.text text ]
                ]
            in
            [ Vdom.Node.div
                ~attrs:
                  ([ Vdom.Attr.role "group" ]
                  @ (match title with
                     | Some text -> [ Vdom.Attr.create "aria-label" text ]
                     | None -> [])
                  @ Attr.class_ [ "astryx-selector__group" ])
                (heading @ List.map ~f:(fun (data, index) -> render_row data index) rows)
            ])
        visible
    in
    let list_content =
      if List.is_empty rows
      then
        (* While the options have not arrived the component cannot claim there
           are none: the trigger's spinner covers that case. *)
        if is_loading
        then []
        else
          [ Vdom.Node.div
              ~attrs:
                [ Vdom.Attr.role "presentation"
                ; Vdom.Attr.class_ "astryx-selector__empty"
                ]
              [ Vdom.Node.text
                  (if String.is_empty model.query then empty_text else empty_search_text)
              ]
          ]
      else render_visible
    in
    let search_row =
      Vdom.Node.div
        ~attrs:(Attr.class_ [ "astryx-selector__search-row" ])
        [ Vdom.Node.input
            ~attrs:
              ([ Vdom.Attr.id search_id
               ; Vdom.Attr.type_ "text"
               ; Vdom.Attr.role "combobox"
               ; Vdom.Attr.create "aria-expanded" (Bool.to_string model.is_open)
               ; Vdom.Attr.create "aria-controls" listbox_id
               ; Vdom.Attr.create "aria-autocomplete" "list"
               ; Vdom.Attr.create "aria-label" search_placeholder
               ; Vdom.Attr.placeholder search_placeholder
               ; Vdom.Attr.value model.query
               ]
              @ (if model.is_open && model.highlight >= 0
                 then [ Vdom.Attr.create "aria-activedescendant" (item_id model.highlight) ]
                 else [])
              @ [ Vdom.Attr.on_input (fun _ev text ->
                    set_model (fun m -> { m with query = text; highlight = -1 }))
                ; Vdom.Attr.on_keydown (fun ev -> handle_key ev ~is_search_input:true)
                ])
            ()
        ]
    in
    let listbox =
      Vdom.Node.div
        ~attrs:
          ([ Vdom.Attr.id listbox_id
           ; Vdom.Attr.role "listbox"
           ; Vdom.Attr.create "aria-labelledby" trigger_id
           ]
          @ (if model.is_open && model.highlight >= 0 && not has_search
             then [ Vdom.Attr.create "aria-activedescendant" (item_id model.highlight) ]
             else [])
          @ Attr.class_ [ "astryx-selector__list" ])
        list_content
    in
    let panel =
      Vdom.Node.div
        ~attrs:
          ([ Vdom.Attr.id panel_id
           ; Vdom.Attr.create "popover" "auto"
           ]
          @ Attr.class_ [ "astryx-selector__panel" ]
          @ [ Common.Layer_hook.attr ~is_open:model.is_open ~on_platform_close:(platform_close ()) ])
        [ Vdom.Node.div
            ~attrs:(Attr.class_ [ "astryx-selector__content" ])
            ((if has_search then [ search_row ] else []) @ [ listbox ])
        ]
    in
    (* The read-only trigger keeps its value, its name and its focusability,
       and loses the surface, the clear button and the disclosure indicator. *)
    let children =
      [ control_box ]
      @ (if is_read_only then [] else [ panel ])
    in
    Field_.view
      ~is_label_hidden
      ?description
      ~is_optional
      ~is_required
      ~is_disabled
      ?status
      ~status_variant:
        (if (not (Poly.equal variant Input)) && Poly.equal status_variant Field_status.Attached
         then Field_status.Detached
         else status_variant)
      ?width
      ~label
      ~input_id:trigger_id
      ~label_id
      ~children
      ())
