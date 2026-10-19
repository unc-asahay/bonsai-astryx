(** Tree_list: a data-driven tree view.

    Port of upstream [TreeList/TreeList.tsx + TreeListItem.tsx +
    TreeListBranches.tsx + TreeListTypes.ts] as [Astryx.Tree_list]. The list is
    a recursive [item] value; expansion is internal state seeded from per-item
    [is_expanded], and later user toggles are held as an override association
    keyed by id (upstream's expandedKeysOverride).

    The tree keyboard model (APG, upstream's useTreeFocusInternal) lives in
    Tree_focus: ArrowUp/ArrowDown/Home/End roam the *visible* treeitems (a
    collapsed subtree is not rendered, so it is naturally excluded), ArrowRight
    expands a collapsed parent or moves to its first child, ArrowLeft collapses
    an expanded parent or moves to its parent, Enter/Space activate the row's
    own inner action (never a descendant treeitem's) and fall back to toggling,
    and printable characters typeahead against the label. Exactly one treeitem
    is the single tab stop.

    Named divergences (recorded in port.json): [on_click] is [unit -> unit]
    (house API) rather than a DOM event; the "Toggle children" label is English
    (upstream i18n); per-item [xstyle]/[className]/[style] have no counterpart
    (no stylex in this port) — wrap [label]/[start_content]/[end_content]
    instead; the indent levers use the port's own spacing tokens.

    The component is stateful (expansion override), so it takes a [graph]: the
    jsdom harness renders it but interaction checks mostly live in the browser
    gate. *)

open! Core
open! Bonsai_web
open! Js_of_ocaml

type density =
  | Compact
  | Balanced
  | Spacious

type variant =
  | Line_guides
  | No_guides

type item = {
  id : string;
  label : Vdom.Node.t;
  description : string option;
  start_content : Vdom.Node.t option;
  end_content : Vdom.Node.t option;
  children : item list;
  on_click : (unit -> unit) option;
  href : string option;
  target : string option;
  is_disabled : bool;
  is_selected : bool;
  is_expanded : bool;
}

type config = {
  id : string option;
  density : density;
  variant : variant;
  header : Vdom.Node.t list option;
  attrs : Vdom.Attr.t list;
  items : item list;
}

let el_prop (obj : 'a Js.t) (name : string) : Dom_html.element Js.t option =
  Js.Opt.to_option (Js.Unsafe.get obj name : Dom_html.element Js.t Js.opt)
;;

let density_name = function
  | Compact -> "compact"
  | Balanced -> "balanced"
  | Spacious -> "spacious"
;;

let variant_name = function
  | Line_guides -> "lineGuides"
  | No_guides -> "noGuides"
;;

let has_children (item : item) = not (List.is_empty item.children)

let toggle_label = "Toggle children"
let label_id_of id = sprintf "astryx-tree-list-label-%s" id
let description_id_of id = sprintf "astryx-tree-list-desc-%s" id

(* First selected enabled item in document order, else the first enabled item,
   else the first item — upstream's findInitialTabbableId. *)
let initial_tabbable_id (items : item list) : string option =
  let first_enabled = ref None in
  let rec walk (items : item list) : string option =
    List.find_map items ~f:(fun item ->
      if item.is_selected && not item.is_disabled
      then Some item.id
      else (
        if not item.is_disabled && Option.is_none !first_enabled
        then first_enabled := Some item.id;
        if List.is_empty item.children
        then None
        else walk item.children))
  in
  match walk items with
  | Some id -> Some id
  | None -> !first_enabled
;;

(* Whether the tree contains ANY expandable item, checked once at the root (any
   expandable descendant forces its whole ancestor chain to be expandable, so
   this is equivalent to "the root group has an expandable item" — upstream's
   own reasoning). A leaf reserves the chevron column only when this holds. *)
let has_expandable (items : item list) = List.exists items ~f:has_children

module Tree_branches = struct
  let margin = "calc(var(--spacing-2) + var(--spacing-0-5))"

  (* Guide lines: a container column with a 1px line. [ancestors] holds the
     "is last" flags of each enclosing level; [is_last] is this row's own. The
     current row's connector occupies [level - 1], which the ancestor loop
     skips (the connector is rendered separately with its own terminus style). *)
  let render ~(ancestors : bool list) ~(is_last : bool) ~(level : int) : Vdom.Node.t list =
    let branch (offset : string) (full : bool) =
      Vdom.Node.div
        ~attrs:
          (Common.Attr.class_ [ "astryx-tree-list__branch" ]
           @ Common.Attr.style [ "insetInlineStart", offset ]
           @ [ Vdom.Attr.create "aria-hidden" "true" ])
        [ Vdom.Node.div
            ~attrs:
              (Common.Attr.class_
                 [ "astryx-tree-list__guide"
                 ; if full then "astryx-tree-list__guide--full" else "astryx-tree-list__guide--last"
                 ])
            []
        ]
    in
    let ancestor_lines =
      List.mapi ancestors ~f:(fun idx ancestor_is_last ->
        if ancestor_is_last || idx = level - 1
        then []
        else [ branch (sprintf "calc(%s + %d * var(--tree-list-indent))" margin idx) true ])
      |> List.concat
    in
    if level = 0
    then ancestor_lines
    else ancestor_lines @ [ branch (sprintf "calc(%s + %d * var(--tree-list-indent))" margin (level - 1)) (not is_last) ]
  ;;
end

let render config (overrides : (string * bool) list) (set_overrides : (string * bool) list -> unit Effect.t) : Vdom.Node.t =
  let typeahead = Tree_focus.create_typeahead () in
  let initial = initial_tabbable_id config.items in
  let expandable = has_expandable config.items in
  let header_counter = ref 0 in

  let keydown (ev : Dom_html.keyboardEvent Js.t) =
    let key = Option.value (Common.string_prop ev "key") ~default:"" in
    let meta = Common.bool_prop ev "metaKey" in
    let ctrl = Common.bool_prop ev "ctrlKey" in
    let alt = Common.bool_prop ev "altKey" in
    match el_prop ev "currentTarget" with
    | None -> Effect.Ignore
    | Some container ->
      if Tree_focus.handle_key container typeahead ~key ~meta ~ctrl ~alt
      then (
        Common.prevent_default ev;
        Effect.Ignore)
      else Effect.Ignore
  in

  let focus_sync (ev : Dom_html.focusEvent Js.t) =
    match el_prop ev "currentTarget" with
    | None -> Effect.Ignore
    | Some container ->
      Tree_focus.sync container;
      Effect.Ignore
  in

  let rec render_items ~(ancestors : bool list) ~(level : int) (items : item list) : Vdom.Node.t list =
    let count = List.length items in
    List.mapi items ~f:(fun index (item : item) ->
      let pos = index + 1 in
      let is_last = Int.equal index (count - 1) in
      let is_expanded =
        match List.Assoc.find overrides item.id ~equal:String.equal with
        | Some b -> b
        | None -> item.is_expanded
      in
      let hc = has_children item in
      let reserves = (not hc) && expandable in
      let indent =
        if reserves
        then sprintf "calc(%d * var(--tree-list-indent) + var(--spacing-4) + var(--spacing-2))" level
        else sprintf "calc(%d * var(--tree-list-indent))" level
      in
      let label_id = label_id_of item.id in
      let desc_id = description_id_of item.id in
      let tabbable =
        (not item.is_disabled)
        && Option.value_map initial ~default:false ~f:(fun id -> String.equal id item.id)
      in
      let toggle () =
        let next =
          if is_expanded
          then List.Assoc.remove overrides ~equal:String.equal item.id
          else List.Assoc.add overrides ~equal:String.equal item.id true
        in
        set_overrides next
      in
      let row_clickable = Option.is_some item.on_click || (hc && Option.is_none item.on_click) in
      let click_handler =
        if not row_clickable
        then None
        else
          Some
            (fun (ev : Dom_html.mouseEvent Js.t) ->
              match el_prop ev "target" with
              | Some target ->
                (match Tree_focus.closest target "button, a, input, select, textarea" with
                 | Some _ -> Effect.Ignore
                 | None ->
                   if item.is_disabled
                   then Effect.Ignore
                   else (
                     match item.on_click with
                     | Some f ->
                       f ();
                       Effect.Ignore
                     | None -> toggle ()))
              | None -> Effect.Ignore)
      in
      let action_basic_attrs =
        [ Vdom.Attr.create "aria-labelledby" label_id ]
        @ (match item.description with Some _ -> [ Vdom.Attr.create "aria-describedby" desc_id ] | None -> [])
        @ (if item.is_disabled then [ Vdom.Attr.create "aria-disabled" "true" ] else [])
        @ [ Vdom.Attr.create "tabindex" "-1" ]
      in
      let label_and_description =
        Vdom.Node.span
          ~attrs:
            (Common.Attr.class_ [ "astryx-tree-list__label" ]
             @ Common.Attr.data "selected" (if item.is_selected then "true" else "false")
             @ [ Vdom.Attr.id label_id ])
          [ item.label ]
        :: (match item.description with
           | Some desc ->
             [ Vdom.Node.span
                 ~attrs:(Common.Attr.class_ [ "astryx-tree-list__description" ] @ [ Vdom.Attr.id desc_id ])
                 [ Vdom.Node.text desc ]
             ]
           | None -> [])
      in
      let inner_content =
        match item.href with
        | Some href ->
          Vdom.Node.a
            ~attrs:
              (Common.Attr.class_ [ "astryx-tree-list__action" ]
               @ action_basic_attrs
               @ [ Vdom.Attr.create "href" href ]
               @ (match item.target with Some t -> [ Vdom.Attr.create "target" t ] | None -> []))
            label_and_description
        | None -> (
          match item.on_click with
          | Some f ->
            Vdom.Node.button
              ~attrs:
                (Common.Attr.class_ [ "astryx-tree-list__action" ]
                 @ action_basic_attrs
                 @ [ Vdom.Attr.create "type" "button" ]
                 @ [ Vdom.Attr.on_click (fun (_ : Dom_html.mouseEvent Js.t) ->
                        f ();
                        Effect.Ignore)
                   ])
              label_and_description
          | None -> (
            match item.description with
            | Some _ ->
              Vdom.Node.div ~attrs:(Common.Attr.class_ [ "astryx-tree-list__content-text" ]) label_and_description
            | None ->
              Vdom.Node.span ~attrs:(Common.Attr.class_ [ "astryx-tree-list__content-text" ]) label_and_description))
      in
      let chevron =
        if hc
        then
          Some
            (Vdom.Node.button
               ~attrs:
                 (Common.Attr.class_
                    ([ "astryx-tree-list__chevron"
                     ; if is_expanded
                       then "astryx-tree-list__chevron--expanded"
                       else "astryx-tree-list__chevron--collapsed"
                     ])
                  @ [ Vdom.Attr.create "data-tree-toggle" ""
                    ; Vdom.Attr.create "type" "button"
                    ; Vdom.Attr.create "aria-expanded" (if is_expanded then "true" else "false")
                    ; Vdom.Attr.create "aria-label" toggle_label
                    ; Vdom.Attr.create "tabindex" "-1"
                    ; Vdom.Attr.on_click (fun (_ : Dom_html.mouseEvent Js.t) -> toggle ())
                    ]
                  @ (if item.is_disabled then [ Vdom.Attr.create "disabled" "true" ] else []))
               [ Icon.view ~size:Icon.Sm ~color:Icon.Inherit ~name:"chevronRight" () ])
        else None
      in
      let content_attrs =
        Common.Attr.class_
          ([ "astryx-tree-list__content"
           ; sprintf "astryx-tree-list__content--%s" (density_name config.density)
           ]
           @ (if item.is_selected then [ "astryx-tree-list__content--selected" ] else [])
           @ (if item.is_disabled then [ "astryx-tree-list__content--disabled" ] else [])
           @ (if row_clickable then [ "astryx-tree-list__content--interactive" ] else []))
        @ Common.Attr.style [ "--_tree-indent", indent ]
        @ (match click_handler with Some h -> [ Vdom.Attr.on_click h ] | None -> [])
      in
      let row_attrs =
        Common.Attr.class_ [ "astryx-tree-list__item" ]
        @ Common.Attr.role "treeitem"
        @ [ Vdom.Attr.create "aria-labelledby" label_id ]
        @ (match item.description with Some _ -> [ Vdom.Attr.create "aria-describedby" desc_id ] | None -> [])
        @ (if hc then [ Vdom.Attr.create "aria-expanded" (if is_expanded then "true" else "false") ] else [])
        @ (if item.is_selected then [ Vdom.Attr.create "aria-selected" "true" ] else [])
        @ (if item.is_disabled then [ Vdom.Attr.create "aria-disabled" "true" ] else [])
        @ [ Vdom.Attr.create "aria-level" (Int.to_string (level + 1))
          ; Vdom.Attr.create "aria-posinset" (Int.to_string pos)
          ; Vdom.Attr.create "aria-setsize" (Int.to_string count)
          ; Vdom.Attr.create "tabindex" (if tabbable then "0" else "-1")
          ; Vdom.Attr.create "data-tree-id" item.id
          ; Vdom.Attr.create "data-tree-level" (Int.to_string (level + 1)) ]
        @ (if item.is_disabled then [ Vdom.Attr.create "data-tree-disabled" "true" ] else [])
      in
      let inner_nodes =
        (match chevron with Some n -> [ n ] | None -> [])
        @ (match item.start_content with Some n -> [ n ] | None -> [])
        @ [ inner_content ]
        @ (match item.end_content with Some n -> [ n ] | None -> [])
      in
      let children_nodes =
        if is_expanded && hc
        then
          [ Vdom.Node.ul
              ~attrs:(Common.Attr.class_ [ "astryx-tree-list__children" ] @ Common.Attr.role "group")
              (render_items ~ancestors:(ancestors @ [ is_last ]) ~level:(level + 1) item.children)
          ]
        else []
      in
      Vdom.Node.li
        ~attrs:row_attrs
        ((if Poly.equal config.variant No_guides
          then []
          else Tree_branches.render ~ancestors ~is_last ~level)
         @ [ Vdom.Node.div
               ~attrs:(Common.Attr.class_ [ "astryx-tree-list__row-wrapper" ])
               [ Vdom.Node.div ~attrs:content_attrs inner_nodes ]
           ]
         @ children_nodes))
  in

  let header_id = sprintf "astryx-tree-list-header-%d" (incr header_counter; !header_counter) in
  let list_attrs =
    Common.Attr.class_ [ "astryx-tree-list__list" ]
    @ Common.Attr.role "tree"
    @ (match config.header with
       | Some _ -> [ Vdom.Attr.create "aria-labelledby" header_id ]
       | None -> [])
    @ [ Vdom.Attr.on_keydown keydown; Vdom.Attr.on_focus focus_sync ]
  in
  let root_children =
    (match config.header with
     | Some h ->
       [ Vdom.Node.div ~attrs:(Common.Attr.class_ [ "astryx-tree-list__header" ] @ [ Vdom.Attr.id header_id ]) h ]
     | None -> [])
    @ [ Vdom.Node.ul ~attrs:list_attrs (render_items ~ancestors:[] ~level:0 config.items) ]
  in
  Vdom.Node.div
    ~attrs:
      (Common.Attr.class_ [ "astryx-tree-list" ]
       @ Common.Attr.data "component" "TreeList"
       @ Common.Attr.data "density" (density_name config.density)
       @ Common.Attr.data "variant" (variant_name config.variant)
       @ Common.Attr.style
           [ "--tree-list-indent", "var(--spacing-4)"; "--tree-list-row-gap", "var(--spacing-0-5)" ]
       @ (match config.id with Some id -> [ Vdom.Attr.id id ] | None -> [])
       @ config.attrs)
    root_children
;;
let view ?id ?(attrs = []) ?(density = Balanced) ?(variant = Line_guides) ?header ~items graph =
  let config = { id; density; variant; header; attrs; items } in
  let overrides, set_overrides = Bonsai.state ([] : (string * bool) list) graph in
  Bonsai.map2 overrides set_overrides ~f:(fun overrides set_overrides -> render config overrides set_overrides)
;;

