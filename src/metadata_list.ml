open! Core
open! Bonsai_web

type columns =
  | Single
  | Multi
  | Fixed of int
;;

type label_position =
  | Start
  | Top
;;

type orientation = Common.List_focus.orientation =
  | Horizontal
  | Vertical
;;

let default_id = "astryx-metadata-list"

let is_multi_column = function
  | Single -> false
  | Multi -> true
  | Fixed n -> n > 1
;;

(* One column of terms means the pairs stack; the count in the class name is whether the grid is single or
   auto-filling, which is the same choice for the stacked and the inline layouts. *)
let grid_class ~is_horizontal ~is_stacked ~columns =
  let shape =
    match columns with
    | Single | Fixed 1 -> "single"
    | Multi | Fixed _ -> "multi"
  in
  if is_horizontal
  then "astryx-metadata-list__grid--horizontal"
  else if is_stacked
  then sprintf "astryx-metadata-list__grid--stacked-%s" shape
  else sprintf "astryx-metadata-list__grid--%s" shape
;;

let view
  ?(attrs = [])
  ?(id = default_id)
  ?title
  ?(columns = Single)
  ?label_position
  ?label_width
  ?(orientation = Vertical)
  ?max_num_of_items
  ?(show_all_label = "Show all")
  ?(show_less_label = "Show less")
  ~items
  graph
  =
  let is_show_all, set_is_show_all = Bonsai.state false graph in
  (* The setter comes back as a computation holding a function, so the pair is brought into the view together
     rather than the setter being applied from outside it. Same shape as dropdown_menu.ml. *)
  let show_all_state =
    Bonsai.map2 is_show_all set_is_show_all ~f:(fun value setter -> value, setter)
  in
  Bonsai.map2 show_all_state items ~f:(fun (is_show_all, set_is_show_all) items ->
    let is_horizontal =
      match orientation with
      | Horizontal -> true
      | Vertical -> false
    in
    let is_stacked =
      match label_position with
      | Some position -> (match position with Start -> false | Top -> true)
      | None -> is_horizontal || is_multi_column columns
    in
    (* Only an explicit count and a fixed term width need a template; everything else is in the class. *)
    let grid_template =
      if is_horizontal
      then None
      else (
        match columns, label_width with
        | Fixed n, _ when n > 1 ->
          Some
            (if is_stacked
             then sprintf "repeat(%d, 1fr)" n
             else sprintf "repeat(%d, auto minmax(0, 1fr))" n)
        | _, Some width when not is_stacked -> Some (sprintf "%s minmax(0, 1fr)" width)
        | _, _ -> None)
    in
    let effective_max =
      match is_horizontal, max_num_of_items with
      | true, _ -> None
      | false, value -> value
    in
    let is_exceed_max =
      match effective_max with
      | None -> false
      | Some max ->
        if max <= 0
        then
          raise_s
            (Sexp.Atom
               (sprintf "Metadata_list.view: max_num_of_items must be positive (%d given)" max))
        else List.length items > max
    in
    let visible =
      match effective_max with
      | Some max when is_exceed_max && not is_show_all -> List.take items max
      | _ -> items
    in
    let content_id = id ^ "-content" in
    let title_node =
      match title with
      | None -> []
      | Some title ->
        [ Vdom.Node.div ~attrs:[ Vdom.Attr.class_ "astryx-metadata-list__title" ] [ title ] ]
    in
    let dl =
      Vdom.Node.dl
        ~attrs:
          ([ Vdom.Attr.class_
               (String.concat
                  ~sep:" "
                  [ "astryx-metadata-list__grid"
                  ; grid_class ~is_horizontal ~is_stacked ~columns
                  ])
           ; Vdom.Attr.create "id" content_id
           ]
           @ (match grid_template with
              | None -> []
              | Some template ->
                [ Vdom.Attr.create "style" (sprintf "grid-template-columns: %s" template) ]))
        (List.concat visible)
    in
    let toggle =
      if not is_exceed_max
      then []
      else
        [ Vdom.Node.button
            ~attrs:
              [ Vdom.Attr.class_ "astryx-metadata-list__toggle"
              ; Vdom.Attr.create "type" "button"
              ; Vdom.Attr.create "aria-controls" content_id
              ; Vdom.Attr.on_click (fun _ -> set_is_show_all (not is_show_all))
              ]
            [ Vdom.Node.text (if is_show_all then show_less_label else show_all_label) ]
        ]
    in
    Vdom.Node.div
      ~attrs:
        ([ Vdom.Attr.class_ "astryx-metadata-list"; Vdom.Attr.create "id" id ]
         @ Common.Attr.data "component" "MetadataList"
         @ attrs)
      (title_node @ [ dl ] @ toggle))
;;
