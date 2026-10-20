(* Tokenizer — the multi-select field: token chips and a combobox input in one box.

   Port of upstream Tokenizer/Tokenizer.tsx and Tokenizer/useEndLaneReserve.ts.

   Upstream composes three components — Field, BaseTypeahead and Token — and keeps
   the parts that belong to it (the token row, the end lane, the overflow
   behaviour) in one file. This port does the same: the field chrome comes from
   the house {!Field}, the chips from the house {!Token}, and everything between
   them — the combobox, the suggestion list, the end lane, the announcements —
   is here.

   The design facts, in the order they shaped this file:

   1. {b The combobox is the control.} One native input stays mounted across
      adding, removing, clearing and reaching the maximum: upstream's FR1. At the
      maximum it is still there — zero-width and transparent — so its identity,
      its focus and its label never move.
   2. {b The suggestion list is a listbox, not a menu.} The input carries
      [role="combobox"], [aria-expanded], [aria-controls] and
      [aria-activedescendant]; the list carries [role="listbox"] and its rows
      [role="option"]. Focus never leaves the input: the highlight is an index,
      and the active option is named by id. Upstream's ARIA, kept exactly.
   3. {b The end lane is measured, not assumed.} The clear button, the end
      content and the busy spinner share one absolutely positioned lane at the
      field's inline end, and the input gives up the room it takes. Upstream
      measures the lane and publishes the width as a custom property; this port
      reserves the room with padding on the input's inline end, which is the
      same rule with less machinery (see "Divergences" in the .mli).
   4. {b The overflow behaviour is a measurement too.} A collapsed field shows
      the tokens that fit and a "+N more" indicator; the count comes from the
      real layout, through the house {!Common.Overflow_hook}, so it follows the
      width rather than a guess.

   Divergences from upstream are listed in the .mli. The short version: the
   search source is synchronous, the suggestion list is an ordinary absolutely
   positioned element rather than a top-layer popover, and the item type is
   {id, label} rather than a generic record. *)

(* This library's own Field, bound before the opens below. Core defines a module
   named Field as well (first-class fields), so after [open! Core] the
   unqualified name refers to Core's — and this module would silently fail to
   compile against it. Same arrangement text_input.ml and complex_selector.ml
   make. *)
module Field_ = Field

open! Core
open! Bonsai_web
open Js_of_ocaml

module Attr = Common.Attr

(* ------------------------------------------------------------------- types *)

type item =
  { id : string  (** the item's unique identifier; what a form submits *)
  ; label : string  (** what the token shows, and what the search matches on *)
  }

type source =
  { search : string -> item list  (** the results for a query *)
  ; bootstrap : item list  (** the results shown before anything is typed *)
  }

type size = Input_types.size =
  | Sm
  | Md
  | Lg
;;

type status_type = Input_types.status_type =
  | Warning
  | Error
  | Success
;;

type status_variant = Field_status.placement =
  | Attached
  | Detached
  | Tooltip
;;

type overflow_behavior =
  (* Upstream's 'none' is called [Wrap] here: a constructor named [None] would
     shadow [option]'s [None] for every line of this module — the same trap the
     library's unwrapped-module rule is about, one level down. *)
  | Wrap  (** the tokens wrap to as many lines as they need — upstream's default *)
  | Unfocused_inline  (** one line with "+N more" while the field is not focused *)
  | Unfocused_layer  (** as [Unfocused_inline], but the expanded row is an overlay *)
;;

type change_type =
  | Add  (** an item from the search results was selected *)
  | Create  (** free text was committed as a new item *)
  | Remove  (** an item was removed, by its button, by Backspace or by the clear button *)
  | Reorder  (** the items changed order; upstream's type carries it, nothing here produces it *)
;;

type change =
  { type_ : change_type  (** what happened *)
  ; item : item option  (** the item it happened to; [None] when there was none *)
  }

(* What the suggestion list shows: an item the search found, or the "Create"
   entry the typed text derives. *)
type entry =
  | Found of item
  | New of string
;;

(* The component's own state. One record rather than six, because the events
   that change it change several fields at once (a selection clears the query
   and the highlight together), and a functional update cannot lose a field the
   way six independent setters can. *)
type local =
  { query : string  (** what is in the input *)
  ; searched : string  (** the query the results were produced for *)
  ; is_open : bool  (** the suggestion list is showing *)
  ; highlighted : int  (** the highlighted option; [-1] is none *)
  ; focused : bool  (** focus is inside the field *)
  ; announcement : string  (** what the live region last said *)
  ; last_change : change_type option  (** the change the announcement was about *)
  ; reason_open : bool  (** the disabled-reason bubble is showing *)
  ; autofocus_pending : bool  (** the mount-time focus has not happened yet *)
  }
;;

(* ----------------------------------------------------------- small helpers *)

let size_string = function
  | Sm -> "sm"
  | Md -> "md"
  | Lg -> "lg"
;;

(* The chip's own size scale. The two types have the same three steps but are
   not the same type, so the conversion is written down once. *)
let token_size = function
  | Sm -> Token.Sm
  | Md -> Token.Md
  | Lg -> Token.Lg
;;

let status_string = function
  | Warning -> "warning"
  | Error -> "error"
  | Success -> "success"
;;

let overflow_string = function
  | Wrap -> "none"
  | Unfocused_inline -> "unfocused-inline"
  | Unfocused_layer -> "unfocused-layer"
;;

let change_type_string = function
  | Add -> "add"
  | Create -> "create"
  | Remove -> "remove"
  | Reorder -> "reorder"
;;

(* Upstream stops the clear button's click from reaching the field, so that
   clearing does not also re-focus the input through the wrapper's own click. *)
let stop_propagation (obj : 'a Js.t) = ignore (Js.Unsafe.meth_call obj "stopPropagation" [||])

let by_id (id : string) : Dom_html.element Js.t option =
  Js.Opt.to_option
    (Js.Unsafe.meth_call
       Dom_html.document
       "getElementById"
       [| Js.Unsafe.inject (Js.string id) |]
      : Dom_html.element Js.t Js.opt)
;;

let contains ~(ancestor : Dom_html.element Js.t) (node : Dom_html.element Js.t) : bool =
  Js.to_bool (Js.Unsafe.meth_call ancestor "contains" [| Js.Unsafe.inject node |])
;;

(* The item the keyboard lands on is the one the results list holds at that
   index; [-1] means "none", which is how the listbox says so too. *)
let nth_or_none (items : 'a list) (index : int) : 'a option =
  if index < 0 then None
  else
    let rec go i rest =
      match rest with
      | [] -> None
      | head :: tail -> if i = 0 then Some head else go (i - 1) tail
    in
    go index items
;;

(* --------------------------------------------------------------- the view *)

let view
      ?(id = "astryx-tokenizer")
      ?(attrs = [])
      ~label
      ?(is_label_hidden = false)
      ?description
      ?(is_required = false)
      ?(is_optional = false)
      ?status
      ?(status_variant = Field_status.Attached)
      ?(size = Md)
      ?width
      ?placeholder
      ?start_icon
      ?end_content
      ?(has_clear = false)
      ?(has_create = false)
      ?(has_entries_on_focus = false)
      ?(has_auto_focus = false)
      ?(is_disabled = false)
      ?disabled_message
      ?max_entries
      ?max_menu_items
      ?(min_query_length = 1)
      ?menu_width
      ?(empty_search_text = "No results found")
      ?(token_overflow_behavior = Wrap)
      ?html_name
      ?on_change_query
      ?on_focus
      ?on_blur
      ~value
      ~on_change
      ~source
      (graph : Bonsai.graph)
  =
  (* The component's own state. One record rather than six, because the events
     that change it change several fields at once (a selection clears the query
     and the highlight together), and a functional update cannot lose a field the
     way six independent setters can. *)
  let local, set_local =
    Bonsai.state'
      { query = ""
      ; searched = ""
      ; is_open = false
      ; highlighted = -1
      ; focused = false
      ; announcement = ""
      ; last_change = None
      ; reason_open = false
      ; autofocus_pending = has_auto_focus
      }
      graph
  in
  (* How many tokens the collapsed row can show. [max_int] means "not measured
     yet", which shows them all: the first paint is never collapsed-then-
     expanded, and the measurement that follows decides. *)
  let visible_count, set_visible_count = Bonsai.state Int.max_value graph in
  let state = Bonsai.map2 local set_local ~f:(fun local set_local -> (local, set_local)) in
  let counts = Bonsai.map2 visible_count set_visible_count ~f:(fun c s -> (c, s)) in
  let controlled = Bonsai.map2 value on_change ~f:(fun v c -> (v, c)) in
  Bonsai.map3 state counts controlled
    ~f:(fun (local, set_local) (visible_count, set_visible_count) (value, on_change) ->
      let group_id = id ^ "-group" in
      let listbox_id = id ^ "-listbox" in
      let reason_id = id ^ "-reason" in
      let option_id index = sprintf "%s-option-%d" listbox_id index in
      (* The two ids the house Field points at: the description and the status
         message. Field derives them from the input's id, so they agree. *)
      let description_id = id ^ "-desc" in
      let message_id = id ^ "-status" in
      let is_at_max =
        match max_entries with
        | Some max -> List.length value >= max
        | None -> false
      in
      let shows_disabled_message = is_disabled && Option.is_some disabled_message in
      (* ------------------------------------------------------------ the results *)
      let selected_ids = List.map value ~f:(fun (item : item) -> item.id) in
      let selected_labels = List.map value ~f:(fun (item : item) -> String.lowercase item.label) in
      let is_selected_id candidate =
        List.exists selected_ids ~f:(fun id -> String.equal id candidate)
      in
      (* The entries the list shows for a pair of queries. [query] is what is in
         the input; [searched] is the query the results were produced for. The two
         differ only while a search is in flight. *)
      let compute_entries ~(query : string) ~(searched : string) : entry list =
        if is_at_max then []
        else
          let trimmed = String.strip query in
          (* Upstream's isBelowMinQueryLength: a query that is too short to search
             is not searched, and the list shows nothing for it. *)
          let below_threshold =
            String.length query > 0 && String.length query < min_query_length
          in
          (* The "Create X" entry. It is derived from the typed text, so it costs
             no fetch and is available even when the query is too short to
             search — but it is not offered for something already selected, by id
             or by label. *)
          let create_entry (results : item list) =
            if not has_create || String.is_empty trimmed then None
            else if
              is_selected_id trimmed
              || List.exists
                   selected_labels
                   ~f:(fun label -> String.equal label (String.lowercase trimmed))
              || List.exists
                   results
                   ~f:(fun (item : item) ->
                     String.equal
                       (String.lowercase item.label)
                       (String.lowercase trimmed))
            then None
            else Some (New trimmed)
          in
          if (String.length query = 0 && not has_entries_on_focus) || below_threshold then
            (match create_entry [] with None -> [] | Some entry -> [ entry ])
          else
            let found =
              if String.length query > 0 then source.search searched else source.bootstrap
            in
            let found = List.filter found ~f:(fun (item : item) -> not (is_selected_id item.id)) in
            let found =
              match max_menu_items with
              | Some max -> List.take found max
              | None -> found
            in
            let entries = List.map found ~f:(fun (item : item) -> Found item) in
            (match create_entry found with None -> entries | Some entry -> entries @ [ entry ])
      in
      let entries = compute_entries ~query:local.query ~searched:local.searched in
      (* Whether a search actually ran: the empty state reports "no results"
         only for a query somebody looked for. *)
      let did_search =
        (String.length local.query > 0 || has_entries_on_focus)
        && not (String.length local.query > 0 && String.length local.query < min_query_length)
      in
      let has_content =
        List.length entries > 0 || (did_search && not (String.is_empty empty_search_text))
      in
      (* FR15: the retained popup closes, and its active descendant goes with
         it, when no eligible choice remains, the maximum is reached, or the
         control is disabled. The last two are terminal states of the control
         rather than of the content, so they are checked here: the content
         alone would keep the popup open at the maximum, because the empty
         state is content. *)
      let is_open =
        local.is_open && has_content && not is_at_max && not is_disabled
      in
      let highlighted =
        if is_open && local.highlighted >= 0 && local.highlighted < List.length entries
        then local.highlighted
        else -1
      in
      (* ------------------------------------------------------------ the actions *)
      (* The announcement and the change it is about are recorded together, so
         the live region can say what it is saying about - which is what the
         browser gate reads to tell an add from a remove. *)
      let announce ?change_type text =
        set_local (fun l ->
          { l with announcement = text; last_change = change_type })
      in
      let focus_input () =
        Effect.of_thunk (fun () ->
          match by_id id with
          | None -> ()
          | Some el -> ignore (Js.Unsafe.meth_call el "focus" [||]))
      in
      let remove_item (item : item) =
        Effect.Many
          [ on_change
              (List.filter value ~f:(fun (v : item) -> not (String.equal v.id item.id)))
              { type_ = Remove; item = Some item }
          ; announce ~change_type:Remove (sprintf "Removed %s" item.label)
          ; focus_input () ]
      in
      let clear_all () =
        match List.rev value with
        | [] -> Effect.Many []
        | last :: _ ->
          Effect.Many
            [ on_change [] { type_ = Remove; item = Some last }
            ; focus_input () ]
      in
      (* Selecting an entry. Upstream clears the query and closes the list; the
         one exception is the bootstrap cohort (an empty query with
         [has_entries_on_focus]), where the list stays open on the next
         remaining choice — upstream's FR14. *)
      let select_entry (entry : entry) =
        match entry with
        | Found item ->
          if is_at_max || is_selected_id item.id then Effect.Many []
          else
            let remaining =
              List.filter entries ~f:(fun (e : entry) ->
                match e with
                | Found other -> not (String.equal other.id item.id)
                | New _ -> true)
            in
            let keep_open =
              has_entries_on_focus
              && String.length local.query = 0
              && List.length remaining > 0
            in
            (* The active option advances to the next remaining choice in
               displayed order; when the committed choice was the last one, the
               nearest preceding choice becomes active. Both are the same rule
               read from the index of the committed choice in the list it was
               chosen from: the choice after it keeps that index in the
               remaining list, and the choice before it takes index - 1. *)
            let committed_index = local.highlighted in
            let next_highlight =
              if not keep_open then -1
              else if committed_index >= List.length remaining then List.length remaining - 1
              else Int.max committed_index 0
            in
            Effect.Many
              [ on_change (value @ [ item ]) { type_ = Add; item = Some item }
              ; announce ~change_type:Add (sprintf "Added %s" item.label)
              ; set_local (fun l ->
                  { l with
                    query = ""
                  ; searched = ""
                  ; is_open = keep_open
                  ; highlighted = next_highlight
                  })
              ; focus_input () ]
        | New text ->
          if is_at_max then Effect.Many []
          else if
            is_selected_id text
            || List.exists
                 selected_labels
                 ~f:(fun label -> String.equal label (String.lowercase text))
          then Effect.Many []
          else
            (* A created item names itself: its id is the text, and so is its
               label. *)
            let item = { id = text; label = text } in
            Effect.Many
              [ on_change (value @ [ item ]) { type_ = Create; item = Some item }
              ; announce ~change_type:Create (sprintf "Added %s" text)
              ; set_local (fun l ->
                  { l with
                    query = ""
                  ; searched = ""
                  ; is_open = false
                  ; highlighted = -1
                  })
              ; focus_input () ]
      in
      (* ------------------------------------------------------------ the input *)
      let on_input (text : string) =
        if is_disabled then Effect.Many []
        else
          let new_entries = compute_entries ~query:text ~searched:text in
          Effect.Many
            [ set_local (fun l ->
                { l with
                  query = text
                ; searched = text
                ; is_open = List.length new_entries > 0
                ; highlighted = if List.length new_entries > 0 then 0 else -1
                })
            ; (match on_change_query with
               | Some f -> f text
               | None -> Effect.Many [])
            ]
      in
      let move_highlight delta =
        let count = List.length entries in
        if count = 0 then Effect.Many []
        else
          let next =
            if highlighted < 0 then (if delta > 0 then 0 else count - 1)
            else (highlighted + delta + count) mod count
          in
          set_local (fun l -> { l with highlighted = next })
      in
      let on_keydown (ev : Dom_html.keyboardEvent Js.t) =
        let key = Option.value (Common.string_prop (Obj.magic ev : _ Js.t) "key") ~default:"" in
        if is_disabled then Effect.Many []
        else
          match key with
          | "Backspace" ->
            (* Backspace on an empty input removes the last token. *)
            if String.length local.query = 0 && List.length value > 0 then (
              Common.prevent_default ev;
              match List.rev value with
              | [] -> Effect.Many []
              | last :: _ -> remove_item last)
            else Effect.Many []
          | "ArrowDown" ->
            Common.prevent_default ev;
            if is_open then move_highlight 1
            else if List.length entries > 0 then
              set_local (fun l -> { l with is_open = true; highlighted = 0 })
            else Effect.Many []
          | "ArrowUp" ->
            Common.prevent_default ev;
            if is_open then move_highlight (-1)
            else if List.length entries > 0 then
              set_local (fun l -> { l with is_open = true; highlighted = 0 })
            else Effect.Many []
          | "Home" ->
            if is_open && List.length entries > 0 then (
              Common.prevent_default ev;
              set_local (fun l -> { l with highlighted = 0 }))
            else Effect.Many []
          | "End" ->
            if is_open && List.length entries > 0 then (
              Common.prevent_default ev;
              set_local (fun l -> { l with highlighted = List.length entries - 1 }))
            else Effect.Many []
          | "Enter" ->
            (match nth_or_none entries highlighted with
             | Some entry ->
               Common.prevent_default ev;
               select_entry entry
             | None -> Effect.Many [])
          | "Escape" ->
            if is_open then (
              Common.prevent_default ev;
              set_local (fun l -> { l with is_open = false; highlighted = -1 }))
            else Effect.Many []
          | "Tab" ->
            (* The list closes as the focus leaves, but not by hiding a
               top-layer surface under the focus move. *)
            set_local (fun l -> { l with is_open = false; highlighted = -1 })
          | _ -> Effect.Many []
      in
      (* ------------------------------------------------------------ the focus *)
      let related_target (ev : Dom_html.focusEvent Js.t) =
        Js.Opt.to_option (Js.Unsafe.get ev "relatedTarget" : Dom_html.element Js.t Js.opt)
      in
      let inside_group node =
        match by_id group_id with
        | None -> false
        | Some group -> contains ~ancestor:group node
      in
      let on_focusin (ev : Dom_html.focusEvent Js.t) =
        let came_from_outside =
          match related_target ev with
          | Some target -> not (inside_group target)
          | None -> true
        in
        let open_effect =
          if came_from_outside && has_entries_on_focus && String.length local.query = 0 then
            let new_entries = compute_entries ~query:"" ~searched:"" in
            if List.length new_entries > 0 then
              [ set_local (fun l -> { l with focused = true; is_open = true; highlighted = 0 }) ]
            else [ set_local (fun l -> { l with focused = true }) ]
          else [ set_local (fun l -> { l with focused = true }) ]
        in
        Effect.Many
          (open_effect
           @ (if came_from_outside then
                (match on_focus with Some f -> [ f () ] | None -> [])
              else [])
           @ (if shows_disabled_message && not local.reason_open
              then [ set_local (fun l -> { l with reason_open = true }) ]
              else []))
      in
      let on_focusout (ev : Dom_html.focusEvent Js.t) =
        match related_target ev with
        | Some target when inside_group target -> Effect.Many []
        | _ ->
          Effect.Many
            ([ set_local (fun l ->
                 { l with
                   focused = false
                 ; is_open = false
                 ; highlighted = -1
                 ; reason_open = false
                 }) ]
            @ (match on_blur with Some f -> [ f () ] | None -> []))
      in
      let on_group_click (_ : Dom_html.mouseEvent Js.t) =
        if is_disabled then Effect.Many [] else focus_input ()
      in
      let on_mouseenter (_ : Dom_html.mouseEvent Js.t) =
        if shows_disabled_message then set_local (fun l -> { l with reason_open = true })
        else Effect.Many []
      in
      let on_mouseleave (_ : Dom_html.mouseEvent Js.t) =
        if local.reason_open then set_local (fun l -> { l with reason_open = false })
        else Effect.Many []
      in
      (* ------------------------------------------------------------- the chips *)
      let token_node (item : item) =
        Vdom.Node.span
          ~key:("token:" ^ item.id)
          ~attrs:(Attr.class_ [ "astryx-tokenizer__token" ])
          [ Token.view
              ~size:(token_size size)
              ~is_disabled
              ?on_remove:(if is_disabled then None else Some (fun _ -> remove_item item))
              item.label ]
      in
      (* The collapsed row: the tokens that fit, and the indicator for the rest.
         The count is measured, so it follows the width of the field. *)
      let is_truncated =
        (not local.focused)
        && (match token_overflow_behavior with
            | Wrap -> false
            | Unfocused_inline | Unfocused_layer -> true)
        && List.length value > 0
      in
      let shown_count =
        if is_truncated then Int.min visible_count (List.length value) else List.length value
      in
      let hidden_count = List.length value - shown_count in
      let shown_items = List.take value shown_count in
      let overflow_indicator count =
        Vdom.Node.span
          ~attrs:(Attr.class_ [ "astryx-tokenizer__overflow" ])
          [ Vdom.Node.text (sprintf "+%d more" count) ]
      in
      (* The hidden twin of the row: every token and the indicator, measured.
         It is never seen and always measurable, which is what the hook needs. *)
      let measure_attr =
        Common.Overflow_hook.attr
          ~selector:".astryx-tokenizer__token"
          ~indicator_selector:".astryx-tokenizer__overflow"
          ~min_visible_items:0
          ~collapse_from:Overflow_math.End
          ~on_measured:(fun (count, _rows) -> set_visible_count count)
          ()
      in
      let measurement =
        Vdom.Node.div
          ~attrs:(Attr.class_ [ "astryx-tokenizer__measure" ] @ [ measure_attr ])
          (List.map value ~f:token_node @ [ overflow_indicator (List.length value) ])
      in
      (* -------------------------------------------------------- the listbox *)
      let option_node index (entry : entry) =
        let text =
          match entry with
          | Found item -> item.label
          | New text -> sprintf "Create \"%s\"" text
        in
        Vdom.Node.div
          ~key:(sprintf "option:%d" index)
          ~attrs:
            ([ Vdom.Attr.id (option_id index)
             ; Vdom.Attr.create "role" "option"
             ; Vdom.Attr.create "aria-selected" "false"
             ; Vdom.Attr.create "tabindex" "-1"
             ]
            @ Attr.class_
                ([ "astryx-tokenizer__option" ]
                 @ (if index = highlighted then [ "astryx-tokenizer__option--highlighted" ] else [])
                 @ (match entry with New _ -> [ "astryx-tokenizer__option--new" ] | Found _ -> []))
            @ [ Vdom.Attr.on_click (fun _ -> select_entry entry)
              ; Vdom.Attr.on_mouseenter (fun _ -> set_local (fun l -> { l with highlighted = index }))
              ])
          [ Vdom.Node.text text ]
      in
      let listbox =
        Vdom.Node.div
          ~attrs:
            ([ Vdom.Attr.id listbox_id
             ; Vdom.Attr.create "role" "listbox"
             ; Vdom.Attr.create "aria-label" "Search results"
             ]
            @ Attr.class_ [ "astryx-tokenizer__listbox" ]
            @ (if is_open then [] else [ Vdom.Attr.create "hidden" "hidden" ])
            @ (match menu_width with
               | Some width -> Attr.style [ ("width", sprintf "%dpx" width) ]
               | None -> []))
          (if not is_open then []
           else if List.length entries = 0 then
             [ Vdom.Node.div
                 ~attrs:
                   (Attr.class_ [ "astryx-tokenizer__empty" ]
                    @ [ Vdom.Attr.create "role" "option"; Vdom.Attr.create "aria-disabled" "true" ])
                 [ Vdom.Node.text empty_search_text ] ]
           else List.mapi entries ~f:(fun index entry -> option_node index entry))
      in
      (* ------------------------------------------------------------ the input *)
      let described_by =
        List.filter_opt
          [ (if Option.is_some description then Some description_id else None)
          ; (match status with
             | Some { Input_types.message = Some message; _ } when not (String.is_empty message) ->
               Some message_id
             | _ -> None)
          ; (if local.reason_open then Some reason_id else None)
          ]
        |> String.concat ~sep:" "
      in
      let is_effectively_required = is_required && not is_optional in
      let input_attrs =
        [ Vdom.Attr.id id ]
        @ [ Vdom.Attr.create "type" "text" ]
        @ [ Vdom.Attr.create "role" "combobox" ]
        @ [ Vdom.Attr.create "aria-expanded" (Bool.to_string is_open) ]
        @ [ Vdom.Attr.create "aria-controls" listbox_id ]
        @ [ Vdom.Attr.create "aria-autocomplete" "list" ]
        @ [ Vdom.Attr.create "autocomplete" "off" ]
        (* Upstream's placeholder is shown only while nothing is selected: once
           there are tokens, the input sits after them and the placeholder would
           describe a field that is not empty. *)
        @ (match placeholder with
           | Some text when List.is_empty value -> [ Vdom.Attr.create "placeholder" text ]
           | _ -> [])
        (* The value is a PROPERTY, not an attribute: an attribute cannot clear
           a field the user has typed into, and the query is cleared every time
           a token is selected. The property is set only when it differs, so the
           caret does not move while typing. *)
        @ [ Vdom.Attr.value local.query ]
        @ (if highlighted >= 0 then [ Vdom.Attr.create "aria-activedescendant" (option_id highlighted) ] else [])
        @ (if String.is_empty described_by then [] else [ Vdom.Attr.create "aria-describedby" described_by ])
        @ (if is_effectively_required then Attr.aria "required" "true" else [])
        @ (match status with
           | Some { Input_types.type_ = Error; _ } -> Attr.aria "invalid" "true"
           | _ -> [])
        @ (if is_disabled && not shows_disabled_message then [ Vdom.Attr.disabled ] else [])
        @ (if shows_disabled_message
           then [ Vdom.Attr.readonly ] @ Attr.aria "disabled" "true"
           else [])
        @ [ Vdom.Attr.on_input (fun _ text -> on_input text) ]
        @ [ Vdom.Attr.on_keydown on_keydown ]
        @ Attr.class_
            ([ "astryx-tokenizer__input" ]
             @ (if is_at_max then [ "astryx-tokenizer__input--at-max" ] else []))
      in
      (* The mount-time focus, once: the flag is cleared by the effect, so a
         later re-render cannot take the focus back. *)
      let autofocus_attr =
        if local.autofocus_pending then
          [ Common.Delay_hook.attr
              ~delay_ms:(Some 0.)
              ~on_elapsed:
                (Effect.Many
                   [ set_local (fun l -> { l with autofocus_pending = false })
                   ; focus_input () ])
          ]
        else []
      in
      (* ------------------------------------------------------- the end lane *)
      let clear_button =
        if has_clear && List.length value > 0 && not is_disabled then
          [ Vdom.Node.button
              ~attrs:
                (Attr.class_ [ "astryx-tokenizer__clear" ]
                 @ Attr.aria "label" "Clear all"
                 @ [ Vdom.Attr.create "type" "button"
                   ; Vdom.Attr.on_click (fun ev ->
                         stop_propagation ev;
                         clear_all ()) ])
              [ Icon.view ~name:"close" ~size:Icon.Xsm ~color:Icon.Secondary () ] ]
        else []
      in
      let end_lane =
        let children = Option.to_list end_content @ clear_button in
        match children with
        | [] -> []
        | _ ->
          [ Vdom.Node.div ~attrs:(Attr.class_ [ "astryx-tokenizer__end-lane" ]) children ]
      in
      let start_icon_node =
        match start_icon with
        | None -> []
        | Some name ->
          [ Vdom.Node.span
              ~attrs:(Attr.class_ [ "astryx-tokenizer__start-icon" ])
              [ Icon.view ~name ~size:Icon.Sm ~color:Icon.Secondary () ] ]
      in
      (* The hidden form carriers: one entry per selected item, under the name
         the caller chose. A disabled control does not submit, and neither do
         its carriers. *)
      let hidden_inputs =
        match html_name with
        | None -> []
        | Some name ->
          List.map value ~f:(fun (item : item) ->
            Vdom.Node.create
              "input"
              ~attrs:
                ([ Vdom.Attr.create "type" "hidden"
                 ; Vdom.Attr.create "name" name
                 ; Vdom.Attr.create "value" item.id
                 ]
                @ (if is_disabled then [ Vdom.Attr.disabled ] else []))
              [])
      in
      (* The live region: a token that appears or disappears is announced, since
         neither the chip nor its remove button says anything by itself. *)
      let live_region =
        Vdom.Node.div
          ~attrs:
            (Attr.class_ [ "astryx-visually-hidden" ]
             @ [ Vdom.Attr.create "aria-live" "polite"; Vdom.Attr.create "role" "status" ]
             @ (match local.last_change with
                | Some type_ -> Attr.data "change" (change_type_string type_)
                | None -> []))
          [ Vdom.Node.text local.announcement ]
      in
      let reason_bubble =
        if shows_disabled_message && local.reason_open then
          [ Vdom.Node.div
              ~attrs:
                (Attr.class_ [ "astryx-tokenizer__reason" ]
                 @ [ Vdom.Attr.id reason_id; Vdom.Attr.create "role" "tooltip" ])
              [ Vdom.Node.text (Option.value_exn disabled_message) ] ]
        else []
      in
      (* ------------------------------------------------------------- assembly *)
      (* The visible row: the tokens that fit, the indicator for the ones that do
         not, and the input. The indicator is here and not only in the
         measurement container, because the measurement container is never seen. *)
      let visible_indicator =
        if is_truncated && hidden_count > 0 then [ overflow_indicator hidden_count ] else []
      in
      let content =
        Vdom.Node.div
          ~attrs:(Attr.class_ [ "astryx-tokenizer__content" ])
          (start_icon_node
           @ List.map shown_items ~f:token_node
           @ visible_indicator
           @ [ Vdom.Node.input ~key:"input" ~attrs:input_attrs () ])
      in
      let wrapper_attrs =
        Attr.class_
          ([ "astryx-tokenizer" ]
           @ [ sprintf "astryx-tokenizer--%s" (size_string size) ]
           @ (if is_disabled then [ "astryx-tokenizer--disabled" ] else [])
           @ (match status with
              | Some { Input_types.type_; _ } -> [ "astryx-tokenizer--" ^ status_string type_ ]
              | None -> [])
           @ (if is_truncated then [ "astryx-tokenizer--truncated" ] else [])
           (* The menu is a child of the field, so the field is what has to
              stack above the fields that follow it: a z-index on the menu
              alone cannot lift it out of its parent's stacking context. *)
           @ (if is_open then [ "astryx-tokenizer--menu-open" ] else [])
           @ (match token_overflow_behavior with
              | Unfocused_layer -> [ "astryx-tokenizer--layer" ]
              | Wrap | Unfocused_inline -> [])
           @ (match token_overflow_behavior with
              | Unfocused_layer when local.focused -> [ "astryx-tokenizer--expanded" ]
              | Unfocused_layer | Wrap | Unfocused_inline -> []))
        @ Attr.data "component" "Tokenizer"
        @ Attr.data "size" (size_string size)
        @ Attr.data "overflow" (overflow_string token_overflow_behavior)
        @ (match status with
           | Some { Input_types.type_; _ } -> Attr.data "status" (status_string type_)
           | None -> [])
        @ (if is_disabled then Attr.data "disabled" "true" else [])
        @ (if has_clear then Attr.data "clear" "true" else [])
        @ (if has_create then Attr.data "create" "true" else [])
        @ [ Vdom.Attr.id group_id
          ; Vdom.Attr.create "role" "group"
          ; Vdom.Attr.create "aria-label" label
          ; Vdom.Attr.on_click on_group_click
          ; Vdom.Attr.on_focusin on_focusin
          ; Vdom.Attr.on_focusout on_focusout
          ; Vdom.Attr.on_mouseenter on_mouseenter
          ; Vdom.Attr.on_mouseleave on_mouseleave
          ]
        @ autofocus_attr
        @ attrs
      in
      let wrapper =
        Vdom.Node.div
          ~attrs:wrapper_attrs
          ((if is_truncated then [ measurement ] else [])
           @ [ content ]
           @ hidden_inputs
           @ end_lane
           @ [ listbox ]
           @ [ live_region ]
           @ reason_bubble)
      in
      Field_.view
        ~label
        ~input_id:id
        ~is_label_hidden
        ?description
        ~is_optional
        ~is_required
        ~is_disabled
        ?status
        ~status_variant
        ?width
        ~children:[ wrapper ]
        ())
;;
