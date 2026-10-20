open! Core
open! Bonsai_web
open Js_of_ocaml

(** Port of upstream [ContextMenu]
    (packages/core/src/ContextMenu/ContextMenu.tsx), together with the parts of
    upstream DropdownMenu's phase 2 that ContextMenu builds on: the drill-in
    view stack ([useMenuDrillIn]), the overflow measurement ([useMenuOverflow]),
    the adaptive presentation ([useAdaptivePresentation]) and the touch action
    list ([MenuBottomSheetActionList]).

    See the .mli for the divergences from upstream. *)

type presentation =
  | Popover
  | Bottom_sheet
  | Adaptive

type variant =
  | Default
  | Destructive

type item =
  { id : string option
  ; label : string
  ; description : string option
  ; icon : string option
  ; end_content : Vdom.Node.t option
  ; variant : variant
  ; is_disabled : bool
  ; href : string option
  ; has_close_on_select : bool
  ; children : entry list option
  }

and entry =
  | Item of item
  | Divider
  | Section of { id : string option ; title : string option ; items : item list }

type trigger_as =
  | Div
  | Span

(* ------------------------------------------------------------------ *)
(* DropdownMenu phase-2 internals that ContextMenu builds on.          *)
(* ------------------------------------------------------------------ *)

(** Upstream [useMenuDrillIn]: the stack of views the menu has drilled into.
    A view is identified by its id, so drilling into the same view twice is a
    no-op, and the drilled-out rows are hidden rather than unmounted. *)
module Drill_in = struct
  type view =
    { id : string
    ; entries : entry list
    }

  type t = view list

  let empty = []

  let push stack view =
    if List.exists stack ~f:(fun (v : view) -> String.equal v.id view.id)
    then stack
    else stack @ [ view ]

  let pop = function
    | [] -> []
    | _ :: rest -> rest

  let current = function
    | [] -> None
    | view :: _ -> Some view

  let is_drill_ed stack = not (List.is_empty stack)
end

(** Upstream [useMenuOverflow]: a menu that scrolls needs to be pannable, a menu
    that fits does not. *)
module Overflow = struct
  let measure (menu : Dom_html.element Js.t) : bool =
    let scroll_height = (Js.Unsafe.get menu "scrollHeight" : int) in
    let client_height = (Js.Unsafe.get menu "clientHeight" : int) in
    scroll_height > client_height + 1
end

(** Upstream [useAdaptivePresentation]. *)
module Adaptive_presentation = struct
  let compact_touch_query = "(max-width: 768px) and (pointer: coarse)"

  let matches_compact_touch () : bool =
    try
      let window = Dom_html.window in
      let match_media = Js.Unsafe.get window "matchMedia" in
      let result =
        Js.Unsafe.call
          match_media
          (Js.Unsafe.get window "matchMedia")
          [| Js.Unsafe.inject compact_touch_query |]
      in
      Js.Unsafe.get result "matches" |> Js.to_bool
    with _ -> false

  let resolve presentation =
    match presentation with
    | Popover -> Popover
    | Bottom_sheet -> Bottom_sheet
    | Adaptive ->
      if matches_compact_touch () then Bottom_sheet else Popover
end

(* ------------------------------------------------------------------ *)
(* DOM helpers.                                                        *)
(* ------------------------------------------------------------------ *)

let class_attr class_name = Vdom.Attr.create "class" class_name

let style_attr declarations =
  let declarations =
    List.map declarations ~f:(fun (name, value) -> name ^ ": " ^ value)
  in
  Vdom.Attr.create "style" (String.concat ~sep:"; " declarations)

let element_by_id id : Dom_html.element Js.t option =
  let document = Dom_html.document in
  let get_element = Js.Unsafe.get document "getElementById" in
  let element =
    Js.Unsafe.call get_element document [| Js.Unsafe.inject id |]
  in
  if Option.is_none (Js.Opt.to_option element) then None
  else Some ((element : Dom_html.element Js.t))

let query_all (container : Dom_html.element Js.t) (selector : string) :
    Dom_html.element Js.t list =
  let query = Js.Unsafe.get container "querySelectorAll" in
  let found = Js.Unsafe.call query container [| Js.Unsafe.inject selector |] in
  if Option.is_none (Js.Opt.to_option found) then []
  else
    Array.to_list (Js.to_array found)
    |> List.map ~f:(fun element -> (element : Dom_html.element Js.t))

let focus_element (element : Dom_html.element Js.t) =
  Dom_html.focus element

let is_active (element : Dom_html.element Js.t) =
  let document = Dom_html.document in
  let active = Js.Unsafe.get document "activeElement" in
  (not (Option.is_none (Js.Opt.to_option active)))
  && (Js.Unsafe.equal active element
     || (Js.Unsafe.call (Js.Unsafe.get element "contains") element [| active |]
        |> Js.to_bool))

let prevent_default (event : Dom_html.event Js.t) = Common.prevent_default event

(* ------------------------------------------------------------------ *)
(* Rows.                                                                *)
(* ------------------------------------------------------------------ *)

let item_class = "astryx-context-menu__item"
let item_label_class = "astryx-context-menu__item-label"
let item_description_class = "astryx-context-menu__item-description"
let item_icon_class = "astryx-context-menu__item-icon"
let item_end_class = "astryx-context-menu__item-end"
let menu_class = "astryx-context-menu__menu"
let sheet_class = "astryx-context-menu__sheet"
let sheet_header_class = "astryx-context-menu__sheet-header"
let sheet_title_class = "astryx-context-menu__sheet-title"
let trigger_class = "astryx-context-menu__trigger"
let cursor_anchor_class = "astryx-context-menu__cursor-anchor"

let item_label_node item =
  Vdom.Node.create_element
    "span"
    [ class_attr item_label_class ]
    [ Vdom.Node.text item.label ]

let item_description_node item =
  match item.description with
  | None -> Vdom.Node.text ""
  | Some description ->
    Vdom.Node.create_element
      "span"
      [ class_attr item_description_class ]
      [ Vdom.Node.text description ]

let item_icon_node item =
  match item.icon with
  | None -> Vdom.Node.text ""
  | Some icon ->
    Vdom.Node.create_element
      "span"
      [ class_attr item_icon_class ]
      [ Vdom.Node.text icon ]

let item_end_node item =
  match item.children with
  | Some _ ->
    Vdom.Node.create_element
      "span"
      [ class_attr item_end_class ]
      [ Vdom.Node.text "›" ]
  | None ->
    (match item.end_content with
     | None -> Vdom.Node.text ""
     | Some content -> content)

let item_variant_class item =
  match item.variant with
  | Default -> []
  | Destructive -> [ "astryx-context-menu__item--destructive" ]

let row_attrs ~is_disabled ~has_children =
  [ Vdom.Attr.create "role" "menuitem"
  ; Vdom.Attr.create "tabindex" "-1"
  ; (if is_disabled
     then Vdom.Attr.create "aria-disabled" "true"
     else Vdom.Attr.create "aria-disabled" "false")
  ; (if has_children
     then Vdom.Attr.create "aria-haspopup" "true"
     else Vdom.Attr.create "aria-haspopup" "false")
  ]

(** A row of the pointer surface. Activating a row with children drills into
    them; activating any other row selects it. *)
let render_item ~on_activate ~on_drill item =
  let is_disabled = item.is_disabled in
  let children = item.children in
  let attrs =
    row_attrs ~is_disabled ~has_children:(Option.is_some children)
    @ item_variant_class item
    |> List.map ~f:class_attr
  in
  let activate _ =
    if is_disabled then Effect.ignore
    else
      match children with
      | Some _ -> on_drill item
      | None -> on_activate item
  in
  let attrs =
    match item.href with
    | Some href when Option.is_none children ->
      Vdom.Attr.create "href" href :: attrs
    | _ -> attrs
  in
  let content =
    [ item_icon_node item
    ; Vdom.Node.create_element
        "span"
        [ class_attr "astryx-context-menu__item-body" ]
        [ item_label_node item
        ; item_description_node item
        ]
    ; item_end_node item
    ]
  in
  Vdom.Node.create_element "div" (attrs @ [ Vdom.Attr.on_click activate ]) content

(** A row of the touch surface. Upstream keeps [List] ownership for these rows;
    this port renders plain buttons instead (see the .mli). *)
let render_action_item ~on_activate ~on_drill item =
  let is_disabled = item.is_disabled in
  let children = item.children in
  let activate _ =
    if is_disabled then Effect.ignore
    else
      match children with
      | Some _ -> on_drill item
      | None -> on_activate item
  in
  let attrs =
    [ class_attr item_class
    ; Vdom.Attr.create "type" "button"
    ; Vdom.Attr.create "tabindex" "-1"
    ; (if is_disabled
       then Vdom.Attr.create "aria-disabled" "true"
       else Vdom.Attr.create "aria-disabled" "false")
    ; Vdom.Attr.on_click activate
    ]
    @ item_variant_class item
    |> List.map ~f:class_attr
  in
  let content =
    [ item_icon_node item
    ; Vdom.Node.create_element
        "span"
        [ class_attr "astryx-context-menu__item-body" ]
        [ item_label_node item
        ; item_description_node item
        ]
    ; item_end_node item
    ]
  in
  Vdom.Node.create_element "button" attrs content

let render_divider () =
  Vdom.Node.create_element
    "div"
    [ class_attr "astryx-context-menu__divider"
    ; Vdom.Attr.create "role" "separator"
    ]
    [ Vdom.Node.text "" ]

let render_section ~on_activate ~on_drill { id = _; title; items } =
  let heading =
    match title with
    | None -> Vdom.Node.text ""
    | Some title ->
      Vdom.Node.create_element
        "div"
        [ class_attr "astryx-context-menu__section-heading"
        ; Vdom.Attr.create "aria-hidden" "true"
        ]
        [ Vdom.Node.text title ]
  in
  let rows =
    List.map
      (fun item -> render_item ~on_activate ~on_drill item)
      items
  in
  Vdom.Node.create_element
    "div"
    [ class_attr "astryx-context-menu__section"
    ; Vdom.Attr.create "role" "group"
    ; (match title with
       | None -> Vdom.Attr.create "aria-label" ""
       | Some title -> Vdom.Attr.create "aria-label" title)
    ]
    (heading :: rows)

let render_entries ~on_activate ~on_drill entries =
  List.map
    (fun entry ->
      match entry with
      | Item item -> render_item ~on_activate ~on_drill item
      | Divider -> render_divider ()
      | Section section ->
        render_section ~on_activate ~on_drill section)
    entries

let render_action_entries ~on_activate ~on_drill entries =
  List.map
    (fun entry ->
      match entry with
      | Item item -> render_action_item ~on_activate ~on_drill item
      | Divider -> render_divider ()
      | Section section ->
        let heading =
          match section.title with
          | None -> Vdom.Node.text ""
          | Some title ->
            Vdom.Node.create_element
              "div"
              [ class_attr "astryx-context-menu__section-heading" ]
              [ Vdom.Node.text title ]
        in
        let rows =
          List.map
            (fun item -> render_action_item ~on_activate ~on_drill item)
            section.items
        in
        Vdom.Node.create_element
          "div"
          [ class_attr "astryx-context-menu__section"
          ; Vdom.Attr.create "role" "group"
          ]
          (heading :: rows))
    entries

(* ------------------------------------------------------------------ *)
(* The view.                                                            *)
(* ------------------------------------------------------------------ *)

let view
    ?(attrs = [])
    ?(id = "astryx-context-menu")
    ?(label = "Context menu")
    ?(presentation = Popover)
    ?(trigger_as = Div)
    ?(is_disabled = false)
    ?(menu_width = "160px")
    ?on_open_change
    ?on_select
    ~trigger
    ~entries
    (graph : Bonsai.graph)
  : Vdom.Node.t Bonsai.t =
  let is_open, set_open = Bonsai.state false graph in
  let drill, set_drill = Bonsai.state Drill_in.empty graph in
  let has_overflow, set_has_overflow = Bonsai.state false graph in
  let anchor, set_anchor = Bonsai.state (0., 0.) graph in
  let on_open_change =
    match on_open_change with
    | None -> Bonsai.return (fun _ -> Effect.ignore)
    | Some on_open_change -> on_open_change
  in
  let on_select =
    match on_select with
    | None -> Bonsai.return (fun _ -> Effect.ignore)
    | Some on_select -> on_select
  in
  let menu_id = id ^ "-menu" in
  (* The typeahead buffer lives outside the render: it is a property of the
     menu, not of a frame. *)
  let typeahead = ref ("", 0.) in
  let reset_typeahead () = typeahead := ("", 0.) in
  let state = Bonsai.map2 is_open drill ~f:(fun open_ drill -> (open_, drill)) in
  let state =
    Bonsai.map2 state has_overflow ~f:(fun (open_, drill) overflow ->
      (open_, drill, overflow))
  in
  let state =
    Bonsai.map2 state anchor ~f:(fun (open_, drill, overflow) anchor ->
      (open_, drill, overflow, anchor))
  in
  let state =
    Bonsai.map2 state on_open_change ~f:(fun (open_, drill, overflow, anchor) f ->
      (open_, drill, overflow, anchor, f))
  in
  let state =
    Bonsai.map2 state on_select ~f:(fun (open_, drill, overflow, anchor, f) g ->
      (open_, drill, overflow, anchor, f, g))
  in
  Bonsai.map2 state (Bonsai.return ()) ~f:(fun
    ( open_
    , drill
    , has_overflow
    , anchor
    , on_open_change
    , on_select
    ) () ->
      let close () =
        set_drill Drill_in.empty;
        reset_typeahead ();
        Effect.many [ set_open false; on_open_change false ]
      in
      let open_at ~x ~y =
        set_anchor (x, y);
        set_drill Drill_in.empty;
        reset_typeahead ();
        Effect.many [ set_open true; on_open_change true ]
      in
      let select item =
        let selected = on_select item in
        if item.has_close_on_select then Effect.many [ selected; close () ]
        else selected
      in
      let drill_into item =
        match item.children with
        | None -> Effect.ignore
        | Some children ->
          let view =
            { Drill_in.id = (match item.id with
                | Some id -> id
                | None -> item.label)
            ; entries = children
            }
          in
          reset_typeahead ();
          set_drill (Drill_in.push drill view)
      in
      let current_entries =
        match Drill_in.current drill with
        | None -> entries
        | Some view -> view.entries
      in
      let current_title =
        match Drill_in.current drill with
        | None -> label
        | Some view ->
          (match List.find_opt (fun entry ->
               match entry with
               | Item item ->
                 item.id = Some view.id
                   || (Option.is_none item.id && item.label = view.id)
               | Divider | Section _ -> false)
             view.entries with
           | Some (Item item) -> item.label
           | _ -> label)
      in
      let items_of container =
        query_all container ".astryx-context-menu__item"
      in
      let focus_index container index =
        let items = items_of container in
        if List.is_empty items then ()
        else
          let index = if index < 0 then 0 else index in
          let index = index mod List.length items in
          (match List.nth items index with
           | None -> ()
           | Some item -> focus_element item)
      in
      let focused_index container =
        let items = items_of container in
        List.find_index (fun item -> is_active item) items
      in
      let page_size container =
        let client_height = (Js.Unsafe.get container "clientHeight" : int) in
        let items = items_of container in
        let row_height =
          match items with
          | [] -> 0
          | first :: _ ->
            let height = (Js.Unsafe.get first "offsetHeight" : int) in
            if height <= 0 then 0 else height
        in
        if row_height <= 0 then 1
        else max 1 (client_height / row_height)
      in
      let move container delta =
        match focused_index container with
        | None -> focus_index container 0
        | Some index ->
          let items = items_of container in
          let count = List.length items in
          if count = 0 then ()
          else
            let index = (index + delta + count) mod count in
            focus_index container index
      in
      let typeahead_match container key =
        let now = Js.Date.now () in
        let buffer, last = !typeahead in
        let buffer =
          if now -. last > 1. then key else buffer ^ key
        in
        typeahead := (buffer, now);
        let needle = String.lowercase buffer in
        let items = items_of container in
        let label_of item =
          let label = Js.Unsafe.get item "textContent" in
          Js.to_string label |> String.lowercase
        in
        let rec find = function
          | [] -> None
          | item :: rest ->
            if String.starts_with ~prefix:needle (label_of item) then Some item
            else find rest
        in
        (match find items with
         | None -> ()
         | Some item -> focus_element item)
      in
      let activate_focused container =
        match focused_index container with
        | None -> Effect.ignore
        | Some index ->
          let items = items_of container in
          (match List.nth items index with
           | None -> Effect.ignore
           | Some element ->
             let role = Js.Unsafe.get element "getAttribute" in
             let role =
               Js.Unsafe.call role element [| Js.Unsafe.string "role" |]
               |> Js.to_string
             in
             if role = "menuitem" then
               (match element##click with
                | _ -> Effect.ignore)
             else Effect.ignore)
      in
      let handle_key_down event =
        let key = event##key in
        if Drill_in.is_drill_ed drill && key = "Escape" then
          (prevent_default event;
           reset_typeahead ();
           set_drill (Drill_in.pop drill);
           Effect.ignore)
        else if key = "Escape" then
          (prevent_default event; close ())
        else if key = "Tab" then close ()
        else if key = "Enter" || key = " " then
          (prevent_default event;
           if event##repeat then Effect.ignore
           else
             match element_by_id menu_id with
             | None -> Effect.ignore
             | Some container -> activate_focused container)
        else if key = "ArrowDown" then
          (prevent_default event;
           match element_by_id menu_id with
           | None -> Effect.ignore
           | Some container -> move container 1)
        else if key = "ArrowUp" then
          (prevent_default event;
           match element_by_id menu_id with
           | None -> Effect.ignore
           | Some container -> move container (-1))
        else if key = "Home" then
          (prevent_default event;
           match element_by_id menu_id with
           | None -> Effect.ignore
           | Some container -> focus_index container 0)
        else if key = "End" then
          (prevent_default event;
           match element_by_id menu_id with
           | None -> Effect.ignore
           | Some container ->
             focus_index container (List.length (items_of container) - 1))
        else if key = "PageDown" then
          (prevent_default event;
           match element_by_id menu_id with
           | None -> Effect.ignore
           | Some container -> move container (page_size container))
        else if key = "PageUp" then
          (prevent_default event;
           match element_by_id menu_id with
           | None -> Effect.ignore
           | Some container -> move container (-page_size container))
        else if String.length key = 1 && String.for_all (fun c -> Char.code c >= 32) key
        then
          (prevent_default event;
           match element_by_id menu_id with
           | None -> Effect.ignore
           | Some container -> typeahead_match container key)
        else Effect.ignore
      in
      let handle_context_menu event =
        if is_disabled then Effect.ignore
        else
          (prevent_default event;
           let rect =
             match element_by_id id with
             | None -> None
             | Some element -> Some (element##getBoundingClientRect ())
           in
           let keyboard_invoked =
             event##clientX = 0 && event##clientY = 0 && event##detail = 0
           in
           let x, y =
             match rect with
             | None -> (0., 0.)
             | Some rect ->
               if keyboard_invoked then (0., rect##height)
               else
                 ( float_of_int event##clientX -. rect##left
                 , float_of_int event##clientY -. rect##top )
           in
           open_at ~x ~y)
      in
      let measure_overflow () =
        match element_by_id menu_id with
        | None -> ()
        | Some container ->
          let overflow = Overflow.measure container in
          set_has_overflow overflow
      in
      let trigger_element =
        let tag = match trigger_as with Div -> "div" | Span -> "span" in
        Vdom.Node.create_element
          tag
          (attrs
          @ [ class_attr trigger_class
            ; Vdom.Attr.create "data-astryx-target" "context-menu-trigger"
            ; Vdom.Attr.on_contextmenu handle_context_menu
            ])
          [ trigger
          ; Vdom.Node.create_element
              "span"
              [ class_attr cursor_anchor_class
              ; Vdom.Attr.create "aria-hidden" "true"
              ; style_attr
                  [ ("left", Printf.sprintf "%gpx" (fst anchor))
                  ; ("top", Printf.sprintf "%gpx" (snd anchor))
                  ]
              ]
              [ Vdom.Node.text "" ]
          ]
      in
      let surface =
        if not open_ then Vdom.Node.text ""
        else
          let resolved = Adaptive_presentation.resolve presentation in
          match resolved with
          | Popover ->
            let rows =
              render_entries ~on_activate:select ~on_drill:drill_into current_entries
            in
            Vdom.Node.create_element
              "div"
              [ class_attr menu_class
              ; Vdom.Attr.create "role" "menu"
              ; Vdom.Attr.create "id" menu_id
              ; Vdom.Attr.create "tabindex" "-1"
              ; Vdom.Attr.create "aria-label" label
              ; Vdom.Attr.create "data-astryx-target" "context-menu"
              ; Vdom.Attr.on_keydown handle_key_down
              ; Vdom.Attr.on_contextmenu (fun event ->
                  prevent_default event;
                  Effect.ignore)
              ; style_attr
                  [ ("position", "absolute")
                  ; ("left", Printf.sprintf "%gpx" (fst anchor))
                  ; ("top", Printf.sprintf "%gpx" (snd anchor))
                  ; ("min-width", menu_width)
                  ; ("max-height", "300px")
                  ; ("overflow-y", "auto")
                  ; ( "touch-action"
                    , if has_overflow then "pan-y pinch-zoom" else "pinch-zoom" )
                  ; ( "overscroll-behavior"
                    , if has_overflow then "contain" else "auto" )
                  ]
              ]
              rows
          | Bottom_sheet ->
            let rows =
              render_action_entries
                ~on_activate:select
                ~on_drill:drill_into
                current_entries
            in
            let back_button =
              if not (Drill_in.is_drill_ed drill) then Vdom.Node.text ""
              else
                Vdom.Node.create_element
                  "button"
                  [ class_attr "astryx-context-menu__back"
                  ; Vdom.Attr.create "type" "button"
                  ; Vdom.Attr.on_click (fun _ ->
                      reset_typeahead ();
                      set_drill (Drill_in.pop drill);
                      Effect.ignore)
                  ]
                  [ Vdom.Node.text "‹" ]
            in
            let title_node =
              Vdom.Node.create_element
                "h3"
                [ class_attr sheet_title_class
                ; Vdom.Attr.create "tabindex" "-1"
                ]
                [ Vdom.Node.text current_title ]
            in
            Vdom.Node.create_element
              "div"
              [ class_attr sheet_class
              ; Vdom.Attr.create "id" menu_id
              ; Vdom.Attr.create "tabindex" "0"
              ; Vdom.Attr.create "data-autofocus" ""
              ; Vdom.Attr.create "data-astryx-target" "context-menu"
              ; Vdom.Attr.on_keydown handle_key_down
              ; style_attr
                  [ ("position", "fixed")
                  ; ("left", "0")
                  ; ("right", "0")
                  ; ("bottom", "0")
                  ; ("max-height", "70vh")
                  ; ("overflow-y", "auto")
                  ]
              ]
              [ Vdom.Node.create_element
                  "div"
                  [ class_attr sheet_header_class ]
                  [ back_button; title_node ]
              ; Vdom.Node.create_element "div" [] rows
              ]
      in
      let surface =
        if open_ then
          (match element_by_id menu_id with
           | None -> surface
           | Some _ -> surface)
        else surface
      in
      Vdom.Node.create_element
        "div"
        [ class_attr "astryx-context-menu" ]
        [ trigger_element; surface ])
