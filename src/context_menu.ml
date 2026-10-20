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
  | Section of section

and section =
  { id : string option
  ; title : string option
  ; items : item list
  }

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
      let result =
        Js.Unsafe.meth_call window "matchMedia" [| Js.Unsafe.inject compact_touch_query |]
      in
      Js.Unsafe.get result "matches" |> Js.to_bool
    with _ -> false

  (* The presentation the menu is actually drawn in: the adaptive one has
     already been resolved against the pointer by the time it gets here. *)
  type resolved =
    | Resolved_popover
    | Resolved_bottom_sheet

  let resolve presentation =
    match presentation with
    | Popover -> Resolved_popover
    | Bottom_sheet -> Resolved_bottom_sheet
    | Adaptive ->
      if matches_compact_touch () then Resolved_bottom_sheet else Resolved_popover
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

(* The next frame: the menu is only in the document after the patch that
   opened it, so the measurement waits for the browser to lay it out. *)
let next_frame (f : unit -> unit) =
  ignore
    (Js.Unsafe.fun_call
       (Js.Unsafe.pure_js_expr "requestAnimationFrame")
       [| Js.Unsafe.inject (Js.wrap_callback (fun (_ : float) -> f ())) |])
;;

(* The clock, in milliseconds. *)
let now_ms () : float =
  Js.Unsafe.fun_call
    (Js.Unsafe.eval_string
       "(function () { return (typeof performance !== 'undefined' && performance.now) \
        ? performance.now() : Date.now(); })")
    [||]
;;

let focus_element (element : Dom_html.element Js.t) =
  Dom_html.focus element

let is_active (element : Dom_html.element Js.t) =
  let document = Dom_html.document in
  let active = Js.Unsafe.get document "activeElement" in
  (not (Option.is_none (Js.Opt.to_option active)))
  && (Js.strict_equals active element
     || (Js.Unsafe.call (Js.Unsafe.get element "contains") element [| active |]
        |> Js.to_bool))

let prevent_default (event : 'a Js.t) = Common.prevent_default event

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
  Vdom.Node.create "span" ~attrs:[ class_attr item_label_class ] [ Vdom.Node.text item.label ]

let item_description_node item =
  match item.description with
  | None -> Vdom.Node.text ""
  | Some description ->
    Vdom.Node.create "span" ~attrs:[ class_attr item_description_class ] [ Vdom.Node.text description ]

let item_icon_node item =
  match item.icon with
  | None -> Vdom.Node.text ""
  | Some icon ->
    Vdom.Node.create "span" ~attrs:[ class_attr item_icon_class ] [ Vdom.Node.text icon ]

let item_end_node item =
  match item.children with
  | Some _ ->
    Vdom.Node.create "span" ~attrs:[ class_attr item_end_class ] [ Vdom.Node.text "›" ]
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
let render_item ~on_activate ~on_drill (item : item) =
  let is_disabled = item.is_disabled in
  let children = item.children in
  let attrs =
    (row_attrs ~is_disabled ~has_children:(Option.is_some children)
    @ List.map ~f:class_attr (item_variant_class item))
  in
  let activate _ =
    if is_disabled then Effect.Ignore
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
    ; Vdom.Node.create "span" ~attrs:[ class_attr "astryx-context-menu__item-body" ] [ item_label_node item
        ; item_description_node item
        ]
    ; item_end_node item
    ]
  in
  Vdom.Node.create "div" ~attrs:(attrs @ [ Vdom.Attr.on_click activate ]) content

(** A row of the touch surface. Upstream keeps [List] ownership for these rows;
    this port renders plain buttons instead (see the .mli). *)
let render_action_item ~on_activate ~on_drill item =
  let is_disabled = item.is_disabled in
  let children = item.children in
  let activate _ =
    if is_disabled then Effect.Ignore
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
    @ List.map ~f:class_attr (item_variant_class item)
  in
  let content =
    [ item_icon_node item
    ; Vdom.Node.create "span" ~attrs:[ class_attr "astryx-context-menu__item-body" ] [ item_label_node item
        ; item_description_node item
        ]
    ; item_end_node item
    ]
  in
  Vdom.Node.create "button" ~attrs content

let render_divider () =
  Vdom.Node.create "div" ~attrs:[ class_attr "astryx-context-menu__divider"
    ; Vdom.Attr.create "role" "separator"
    ] [ Vdom.Node.text "" ]

let render_section ~on_activate ~on_drill (section : section) =
  let { id = _; title; items } = section in
  let heading =
    match title with
    | None -> Vdom.Node.text ""
    | Some title ->
      Vdom.Node.create "div" ~attrs:[ class_attr "astryx-context-menu__section-heading"
        ; Vdom.Attr.create "aria-hidden" "true"
        ] [ Vdom.Node.text title ]
  in
  let rows =
    List.map
      ~f:(fun item -> render_item ~on_activate ~on_drill item)
      items
  in
  Vdom.Node.create "div" ~attrs:[ class_attr "astryx-context-menu__section"
    ; Vdom.Attr.create "role" "group"
    ; (match title with
       | None -> Vdom.Attr.create "aria-label" ""
       | Some title -> Vdom.Attr.create "aria-label" title)
    ] (heading :: rows)

let render_entries ~on_activate ~on_drill entries =
  List.map
    ~f:(fun entry ->
      match entry with
      | Item item -> render_item ~on_activate ~on_drill item
      | Divider -> render_divider ()
      | Section section ->
        render_section ~on_activate ~on_drill section)
    entries

let render_action_entries ~on_activate ~on_drill entries =
  List.map
    ~f:(fun entry ->
      match entry with
      | Item item -> render_action_item ~on_activate ~on_drill item
      | Divider -> render_divider ()
      | Section section ->
        let heading =
          match section.title with
          | None -> Vdom.Node.text ""
          | Some title ->
            Vdom.Node.create "div" ~attrs:[ class_attr "astryx-context-menu__section-heading" ] [ Vdom.Node.text title ]
        in
        let rows =
          List.map
            ~f:(fun item -> render_action_item ~on_activate ~on_drill item)
            section.items
        in
        Vdom.Node.create "div" ~attrs:[ class_attr "astryx-context-menu__section"
          ; Vdom.Attr.create "role" "group"
          ] (heading :: rows))
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
  let anchor, set_anchor = Bonsai.state (0., 0.) graph in
  let on_open_change =
    match on_open_change with
    | None -> Bonsai.return (fun _ -> Effect.Ignore)
    | Some on_open_change -> on_open_change
  in
  let on_select =
    match on_select with
    | None -> Bonsai.return (fun _ -> Effect.Ignore)
    | Some on_select -> on_select
  in
  let menu_id = id ^ "-menu" in
  (* The typeahead buffer lives outside the render: it is a property of the
     menu, not of a frame. *)
  let typeahead = ref ("", 0.) in
  let reset_typeahead () = typeahead := ("", 0.) in
  let state = Bonsai.map2 is_open drill ~f:(fun open_ drill -> (open_, drill)) in
  let state =
    Bonsai.map2 state anchor ~f:(fun (open_, drill) anchor -> (open_, drill, anchor))
  in
  let state =
    Bonsai.map2 state on_open_change ~f:(fun (open_, drill, anchor) f ->
      (open_, drill, anchor, f))
  in
  let state =
    Bonsai.map2 state on_select ~f:(fun (open_, drill, anchor, f) g ->
      (open_, drill, anchor, f, g))
  in
  (* The setters are trees as well as the values, so they travel with the
     state: a setter is only a function once it has been read out of its
     tree. *)
  let state =
    Bonsai.map2 state (Bonsai.map2 set_open set_drill ~f:(fun o d -> (o, d)))
      ~f:(fun (open_, drill, anchor, f, g) (set_open, set_drill) ->
        (open_, drill, anchor, f, g, set_open, set_drill))
  in
  let state =
    Bonsai.map2 state set_anchor ~f:(fun
      (open_, drill, anchor, f, g, set_open, set_drill) set_anchor ->
        (open_, drill, anchor, f, g, set_open, set_drill, set_anchor))
  in
  Bonsai.map2 state (Bonsai.return ()) ~f:(fun
    ( open_
    , drill
    , anchor
    , on_open_change
    , on_select
    , set_open
    , set_drill
    , set_anchor
    ) () ->
      (* Whether the menu scrolls: a menu that is taller than its box can be
         panned, a menu that fits does not need to be. Upstream measures this
         in a layout effect and keeps the answer in React state; here the
         measurement is taken in the browser, on the menu itself, once the
         menu is in the document — the two style properties it decides are
         the menu's own, so they are written to the menu. *)
      let measure_overflow () =
        match element_by_id menu_id with
        | None -> ()
        | Some container ->
          let overflow = Overflow.measure container in
          let style = Js.Unsafe.get container "style" in
          let set_property name value =
            ignore
              (Js.Unsafe.meth_call style "setProperty"
                 [| Js.Unsafe.inject name; Js.Unsafe.inject value |])
          in
          set_property
            "touch-action"
            (if overflow then "pan-y pinch-zoom" else "pinch-zoom");
          set_property "overscroll-behavior" (if overflow then "contain" else "auto")
      in
      let close () =
        reset_typeahead ();
        Effect.Many [ set_drill Drill_in.empty; set_open false; on_open_change false ]
      in
      let open_at ~x ~y =
        reset_typeahead ();
        Effect.Many
          [ set_anchor (x, y)
          ; set_drill Drill_in.empty
          ; set_open true
          ; on_open_change true
          ; Effect.of_thunk (fun () -> next_frame (fun () -> measure_overflow ()))
          ]
      in
      let select item =
        let selected = on_select item in
        if item.has_close_on_select then Effect.Many [ selected; close () ]
        else selected
      in
      let drill_into item =
        match item.children with
        | None -> Effect.Ignore
        | Some children ->
          let view =
            { Drill_in.id = (match item.id with
                | Some id -> id
                | None -> item.label)
            ; entries = children
            }
          in
          reset_typeahead ();
          Effect.Many [ set_drill (Drill_in.push drill view) ]
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
          (match List.find ~f:(fun entry ->
               match entry with
               | Item item ->
                 (match item.id with
                  | Some id -> String.equal id view.id
                  | None -> false)
                   || (Option.is_none item.id && String.equal item.label view.id)
               | Divider | Section _ -> false)
             view.entries with
           | Some (Item item) -> item.label
           | _ -> label)
      in
      let items_of container =
        query_all container ".astryx-context-menu__item"
      in
      (* Focus the row at [index], wrapping around the ends. The effect is
         the focus itself: a row cannot be focused before the browser has
         laid the menu out, so the focus is an effect, not a call. *)
      let focus_index container index =
        let items = items_of container in
        if List.is_empty items then Effect.Ignore
        else
          let index = if index < 0 then 0 else index in
          let index = index mod List.length items in
          (match List.nth items index with
           | None -> Effect.Ignore
           | Some item -> Effect.of_thunk (fun () -> focus_element item))
      in
      let focused_index container =
        let items = items_of container in
        (* The index of the focused row, if the menu has one. *)
        let rec loop index = function
          | [] -> None
          | item :: rest -> if is_active item then Some index else loop (index + 1) rest
        in
        loop 0 items
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
          if count = 0 then Effect.Ignore
          else
            let index = (index + delta + count) mod count in
            focus_index container index
      in
      let typeahead_match container key =
        let now = now_ms () in
        let buffer, last = !typeahead in
        let buffer =
          if Float.(>) (now -. last) 1. then key else buffer ^ key
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
            if String.is_prefix (label_of item) ~prefix:needle then Some item
            else find rest
        in
        (match find items with
         | None -> Effect.Ignore
         | Some item -> Effect.of_thunk (fun () -> focus_element item))
      in
      let activate_focused container =
        match focused_index container with
        | None -> Effect.Ignore
        | Some index ->
          let items = items_of container in
          (match List.nth items index with
           | None -> Effect.Ignore
           | Some element ->
             let role = Js.Unsafe.get element "getAttribute" in
             let role =
               Js.Unsafe.call role element [| Js.Unsafe.inject "role" |]
               |> Js.to_string
             in
             if String.equal role "menuitem" then
               (ignore (Js.Unsafe.meth_call element "click" [||]); Effect.Ignore)
             else Effect.Ignore)
      in
      let handle_key_down (event : Dom_html.keyboardEvent Js.t) =
        let key = Js.Unsafe.get event "key" |> Js.to_string in
        if Drill_in.is_drill_ed drill && String.equal key "Escape" then
          (prevent_default event;
           reset_typeahead ();
           Effect.Many [ set_drill (Drill_in.pop drill) ])
        else if String.equal key "Escape" then
          (prevent_default event; close ())
        else if String.equal key "Tab" then close ()
        else if String.equal key "Enter" || String.equal key " " then
          (prevent_default event;
           if Js.Unsafe.get event "repeat" |> Js.to_bool then Effect.Ignore
           else
             match element_by_id menu_id with
             | None -> Effect.Ignore
             | Some container -> activate_focused container)
        else if String.equal key "ArrowDown" then
          (prevent_default event;
           match element_by_id menu_id with
           | None -> Effect.Ignore
           | Some container -> move container 1)
        else if String.equal key "ArrowUp" then
          (prevent_default event;
           match element_by_id menu_id with
           | None -> Effect.Ignore
           | Some container -> move container (-1))
        else if String.equal key "Home" then
          (prevent_default event;
           match element_by_id menu_id with
           | None -> Effect.Ignore
           | Some container -> focus_index container 0)
        else if String.equal key "End" then
          (prevent_default event;
           match element_by_id menu_id with
           | None -> Effect.Ignore
           | Some container ->
             focus_index container (List.length (items_of container) - 1))
        else if String.equal key "PageDown" then
          (prevent_default event;
           match element_by_id menu_id with
           | None -> Effect.Ignore
           | Some container -> move container (page_size container))
        else if String.equal key "PageUp" then
          (prevent_default event;
           match element_by_id menu_id with
           | None -> Effect.Ignore
           | Some container -> move container (-page_size container))
        else if String.length key = 1 && String.for_all ~f:(fun c -> Char.to_int c >= 32) key
        then
          (prevent_default event;
           match element_by_id menu_id with
           | None -> Effect.Ignore
           | Some container -> typeahead_match container key)
        else Effect.Ignore
      in
      let handle_context_menu (event : Dom_html.mouseEvent Js.t) =
        if is_disabled then Effect.Ignore
        else
          (prevent_default event;
           let rect =
             match element_by_id id with
             | None -> None
             | Some element ->
               Some (Js.Unsafe.meth_call element "getBoundingClientRect" [||])
           in
           let keyboard_invoked =
             (Js.Unsafe.get event "clientX" : int) = 0
             && (Js.Unsafe.get event "clientY" : int) = 0
             && (Js.Unsafe.get event "detail" : int) = 0
           in
           let x, y =
             match rect with
             | None -> (0., 0.)
             | Some rect ->
               if keyboard_invoked then (0., (Js.Unsafe.get rect "height" : float))
               else
                 ( (Js.Unsafe.get event "clientX" : float) -. (Js.Unsafe.get rect "left" : float)
                 , (Js.Unsafe.get event "clientY" : float) -. (Js.Unsafe.get rect "top" : float) )
           in
           open_at ~x ~y)
      in
      let trigger_element =
        let tag = match trigger_as with Div -> "div" | Span -> "span" in
        Vdom.Node.create
          tag
          ~attrs:(attrs
          @ [ class_attr trigger_class
            ; Vdom.Attr.create "data-astryx-target" "context-menu-trigger"
            ; Vdom.Attr.on_contextmenu handle_context_menu
            ])
          [ trigger
          ; Vdom.Node.create "span" ~attrs:[ class_attr cursor_anchor_class
              ; Vdom.Attr.create "aria-hidden" "true"
              ; style_attr
                  [ ("left", Printf.sprintf "%gpx" (fst anchor))
                  ; ("top", Printf.sprintf "%gpx" (snd anchor))
                  ] ]
              [ Vdom.Node.text "" ]
          ]
      in
      let surface =
        if not open_ then Vdom.Node.text ""
        else
          let resolved = Adaptive_presentation.resolve presentation in
          match resolved with
          | Adaptive_presentation.Resolved_popover ->
            let rows =
              render_entries ~on_activate:select ~on_drill:drill_into current_entries
            in
            Vdom.Node.create "div" ~attrs:[ class_attr menu_class
              ; Vdom.Attr.create "role" "menu"
              ; Vdom.Attr.create "id" menu_id
              ; Vdom.Attr.create "tabindex" "-1"
              ; Vdom.Attr.create "aria-label" label
              ; Vdom.Attr.create "data-astryx-target" "context-menu"
              ; Vdom.Attr.on_keydown handle_key_down
              ; Vdom.Attr.on_contextmenu (fun event ->
                  prevent_default event;
                  Effect.Ignore)
              ; style_attr
                  [ ("position", "absolute")
                  ; ("left", Printf.sprintf "%gpx" (fst anchor))
                  ; ("top", Printf.sprintf "%gpx" (snd anchor))
                  ; ("min-width", menu_width)
                  ; ("max-height", "300px")
                  ; ("overflow-y", "auto")
                  ] ]
              rows
          | Adaptive_presentation.Resolved_bottom_sheet ->
            let rows =
              render_action_entries
                ~on_activate:select
                ~on_drill:drill_into
                current_entries
            in
            let back_button =
              if not (Drill_in.is_drill_ed drill) then Vdom.Node.text ""
              else
                Vdom.Node.create "button" ~attrs:[ class_attr "astryx-context-menu__back"
                  ; Vdom.Attr.create "type" "button"
                  ; Vdom.Attr.on_click (fun _ ->
                      reset_typeahead ();
                      Effect.Many [ set_drill (Drill_in.pop drill) ])
                  ] [ Vdom.Node.text "‹" ]
            in
            let title_node =
              Vdom.Node.create "h3" ~attrs:[ class_attr sheet_title_class
                ; Vdom.Attr.create "tabindex" "-1"
                ] [ Vdom.Node.text current_title ]
            in
            Vdom.Node.create "div" ~attrs:[ class_attr sheet_class
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
                  ] ]
              [ Vdom.Node.create "div" ~attrs:[ class_attr sheet_header_class ] [ back_button; title_node ]
              ; Vdom.Node.create "div" ~attrs:[] rows
              ]
      in
      let surface =
        if open_ then
          (match element_by_id menu_id with
           | None -> surface
           | Some _ -> surface)
        else surface
      in
      Vdom.Node.create "div" ~attrs:[ class_attr "astryx-context-menu" ] [ trigger_element; surface ])
