open! Core
open! Bonsai_web
open Js_of_ocaml

(* What appears between the previous and next controls. *)
type variant =
  | Pages
  | Count
  | Compact
  | Dots
  | Input
  | None_

(* The size of the controls. *)
type size =
  | Sm
  | Md

(* One slot in the page range: a page number, or an ellipsis. *)
type range_item =
  | Page of int
  | Ellipsis

(* The English strings upstream reads from the @astryx.pagination.* translation
   namespace. This library has no translation layer, so they are here. *)
let label_default = "Pagination"
let first_label = "Go to first page"
let last_label = "Go to last page"
let previous_label = "Go to previous page"
let next_label = "Go to next page"
let page_indicators_label = "Page indicators"
let go_to_page_input_label = "Go to page"
let page_label_default = "Page"

let previous_by_label step =
  if step = 1 then sprintf "Go back %d page" step
  else sprintf "Go back %d pages" step

let next_by_label step =
  if step = 1 then sprintf "Go forward %d page" step
  else sprintf "Go forward %d pages" step

let go_to_page_label page = sprintf "Go to page %d" page
let count_label ~from_ ~to_ ~total = sprintf "%d–%d of %d" from_ to_ total
let page_of_total_label ~current ~total = sprintf "Page %d of %d" current total
let page_announce_label ~current = sprintf "Page %d" current
let of_total_pages_label total = sprintf "/ %d" total

(* Upstream's generatePageRange. The docstring's example is out of date; the
   implementation and its tests are the contract. *)
let generate_page_range ~current_page ~total_pages ~sibling_count =
  let total_slots = 5 + (2 * sibling_count) in
  if total_pages <= total_slots
  then List.init total_pages ~f:(fun i -> Page (i + 1))
  else
    let left_sibling_index = max (current_page - sibling_count) 1 in
    let right_sibling_index = min (current_page + sibling_count) total_pages in
    let show_left_ellipsis = left_sibling_index > 2 in
    let show_right_ellipsis = right_sibling_index < total_pages - 1 in
    if (not show_left_ellipsis) && show_right_ellipsis
    then
      (* Near the start: show more pages on the left. *)
      let left_range = 3 + (2 * sibling_count) in
      List.init left_range ~f:(fun i -> Page (i + 1)) @ [ Ellipsis; Page total_pages ]
    else if show_left_ellipsis && (not show_right_ellipsis)
    then
      (* Near the end: show more pages on the right. *)
      let right_range = 3 + (2 * sibling_count) in
      Page 1
      :: Ellipsis
      :: List.init right_range ~f:(fun i -> Page (total_pages - right_range + 1 + i))
    else
      (* In the middle: an ellipsis on each side. *)
      Page 1
      :: Ellipsis
      :: (List.init (right_sibling_index - left_sibling_index + 1) ~f:(fun i ->
             Page (left_sibling_index + i)))
      @ [ Ellipsis; Page total_pages ]
;;

let view
    ?attrs
    ?id
    ?variant
    ?size
    ?label
    ?total_items
    ?total_pages
    ?has_more
    ?page_size
    ?page_label
    ?has_first_last
    ?step
    ?sibling_count
    ?is_disabled
    ~on_change
    ~page
    graph =
  let variant = Option.value variant ~default:Pages in
  let size = Option.value size ~default:Md in
  let label = Option.value label ~default:label_default in
  let page_label = Option.value page_label ~default:page_label_default in
  let page_size = max 1 (Option.value page_size ~default:10) in
  let step = if Option.value step ~default:1 < 1 then 1 else Option.value step ~default:1 in
  let sibling_count = max 0 (Option.value sibling_count ~default:1) in
  let is_disabled = Option.value is_disabled ~default:false in
  let has_more = Option.value has_more ~default:false in
  (* The page count comes from the total pages when they are given, and from
     the item count otherwise. *)
  let computed_total_pages =
    match total_pages with
    | Some n -> Some n
    | None ->
      (match total_items with
       | Some items -> Some (((items + page_size) - 1) / page_size)
       | None -> None)
  in
  (* Upstream renders nothing at all when there is nothing to paginate. *)
  let is_empty =
    (match total_items with Some items -> items <= 0 | None -> false)
    || (match computed_total_pages with Some n -> n <= 0 | None -> false)
  in
  let button_size = match size with Sm -> Button.Sm | Md -> Button.Md in
  let icon_size = match size with Sm -> Icon.Sm | Md -> Icon.Md in
  let icon name = Icon.view ~name ~size:icon_size () in
  let previous_label = if step > 1 then previous_by_label step else previous_label in
  let next_label = if step > 1 then next_by_label step else next_label in
  (* The number input of the Input variant. It is built here, off the graph,
     because a component cannot be built inside a map. *)
  let number_input =
    Number_input.view
      ~label:go_to_page_input_label
      ~is_label_hidden:true
      ~is_disabled
      ~min:(Some 1.)
      ~max:
        (match computed_total_pages with
         | Some n -> Some (float_of_int n)
         | None -> None)
      ~is_integer_only:true
      ~size:(match size with Sm -> Number_input.Sm | Md -> Number_input.Md)
      ~value:(Bonsai.map page ~f:(fun p -> Some (float_of_int p)))
      ~on_change:
        (Bonsai.map on_change ~f:(fun on_change ->
             fun value ->
               on_change (max 1 (int_of_float (Option.value value ~default:1.)))))
      graph
  in
  Bonsai.map3 page on_change number_input ~f:(fun page on_change number_input ->
      if is_empty
      then Vdom.Node.none
      else
        let has_previous = page > 1 in
        let has_next =
          match computed_total_pages with
          | Some n -> page < n
          | None -> has_more
        in
        (* A step that would go past the end lands on the first or the last
           page. *)
        let first_page = 1 in
        let last_page = match computed_total_pages with Some n -> n | None -> page in
        let previous_page = max first_page (page - step) in
        let next_page = min last_page (page + step) in
        let go p = on_change p in
        let control_button ~label ~icon ~is_disabled ~on_click =
          Button.view
            ~label
            ~variant:Button.Ghost
            ~size:button_size
            ~icon
            ~is_icon_only:true
            ~is_disabled
            ~on_click:(fun (_ : Dom_html.mouseEvent Js.t) -> on_click ())
            []
        in
        let first_button =
          match computed_total_pages with
          | Some _ ->
            Some
              (control_button
                 ~label:first_label
                 ~icon:(icon "chevronsLeft")
                 ~is_disabled:(is_disabled || not has_previous)
                 ~on_click:(fun () -> go first_page))
          | None -> None
        in
        let last_button =
          match computed_total_pages with
          | Some _ ->
            Some
              (control_button
                 ~label:last_label
                 ~icon:(icon "chevronsRight")
                 ~is_disabled:(is_disabled || not has_next)
                 ~on_click:(fun () -> go last_page))
          | None -> None
        in
        let previous_button =
          control_button
            ~label:previous_label
            ~icon:(icon "chevronLeft")
            ~is_disabled:(is_disabled || not has_previous)
            ~on_click:(fun () -> go previous_page)
        in
        let next_button =
          control_button
            ~label:next_label
            ~icon:(icon "chevronRight")
            ~is_disabled:(is_disabled || not has_next)
            ~on_click:(fun () -> go next_page)
        in
        (* The indicator: what appears between the two controls. *)
        let indicator =
          match variant with
          | Pages ->
            (match computed_total_pages with
             | None -> Vdom.Node.none
             | Some total ->
               let range =
                 generate_page_range ~current_page:page ~total_pages:total ~sibling_count
               in
               Vdom.Node.div
                 ~attrs:
                   (Common.Attr.class_ [ "astryx-pagination__pages" ]
                   @ Common.Attr.role "list")
                 (List.map
                    range
                    ~f:(fun item ->
                      match item with
                      | Ellipsis ->
                        Vdom.Node.span
                          ~attrs:
                            (Common.Attr.aria "hidden" "true"
                            @ Common.Attr.class_ [ "astryx-pagination__ellipsis" ])
                          [ Vdom.Node.text "…" ]
                      | Page n ->
                        let is_active = n = page in
                        Vdom.Node.li
                          ~attrs:(Common.Attr.role "listitem")
                          [ Button.view
                              ~label:(string_of_int n)
                              ~variant:Button.Ghost
                              ~size:button_size
                              ~is_disabled
                              ~attrs:
                                (if is_active
                                 then Common.Attr.aria "current" "page"
                                 else [])
                              ~on_click:(fun (_ : Dom_html.mouseEvent Js.t) -> go n)
                              [] ])))
          | Count ->
            (match total_items with
             | None -> Vdom.Node.none
             | Some total ->
               let from_ = ((page - 1) * page_size) + 1 in
               let to_ = min (page * page_size) total in
               Vdom.Node.span
                 ~attrs:(Common.Attr.class_ [ "astryx-pagination__info" ])
                 [ Text.view
                     ~type_:Text.Body
                     ~size:Text.Sm
                     ~color:Text.Secondary
                     [ Vdom.Node.text (count_label ~from_ ~to_ ~total) ] ])
          | Compact ->
            (match computed_total_pages with
             | None -> Vdom.Node.none
             | Some total ->
               Vdom.Node.span
                 ~attrs:(Common.Attr.class_ [ "astryx-pagination__info" ])
                 [ Text.view
                     ~type_:Text.Body
                     ~size:Text.Sm
                     ~color:Text.Secondary
                     [ Vdom.Node.text (page_of_total_label ~current:page ~total) ] ])
          | Dots ->
            (match computed_total_pages with
             | None -> Vdom.Node.none
             | Some total ->
               Vdom.Node.div
                 ~attrs:
                   (Common.Attr.role "group"
                   @ Common.Attr.aria "label" page_indicators_label
                   @ Common.Attr.class_ [ "astryx-pagination__dots" ])
                 (List.init total ~f:(fun i ->
                      let n = i + 1 in
                      let is_active = n = page in
                      Vdom.Node.button
                        ~attrs:
                          ([ Vdom.Attr.type_ "button"
                           ; Vdom.Attr.create "data-page" (string_of_int n)
                           ; Vdom.Attr.tabindex (if is_active then 0 else -1)
                           ; Vdom.Attr.on_click
                               (fun (_ : Dom_html.mouseEvent Js.t) -> go n)
                           ]
                           @ Common.Attr.aria "label" (go_to_page_label n)
                           @ Common.Attr.class_
                               [ "astryx-pagination__dot"
                               ; if is_active then "astryx-pagination__dot--active" else ""
                               ])
                        [])))
          | Input ->
            let input_children =
              [ Vdom.Node.span
                  ~attrs:
                    (Common.Attr.aria "hidden" "true"
                    @ Common.Attr.class_ [ "astryx-pagination__input-label" ])
                  [ Vdom.Node.text page_label ]
              ; number_input ]
              @ (match computed_total_pages with
                 | Some total ->
                   [ Vdom.Node.span
                       ~attrs:(Common.Attr.class_ [ "astryx-pagination__input-total" ])
                       [ Vdom.Node.text (of_total_pages_label total) ] ]
                 | None -> [])
            in
            Vdom.Node.span
              ~attrs:(Common.Attr.class_ [ "astryx-pagination__input" ])
              input_children
          | None_ -> Vdom.Node.none
        in
        (* The first and last controls are shown by default in the Input
           variant and only on request in the Compact one; the other variants
           ignore them. They need a known page count, so they are left out
           when the total is unknown. *)
        let has_first_last =
          match variant with
          | Input -> (match has_first_last with Some b -> b | None -> true)
          | Compact -> (match has_first_last with Some b -> b | None -> false)
          | _ -> false
        in
        let show_first_last = has_first_last && Option.is_some computed_total_pages in
        let controls_children =
          (if show_first_last
           then
             (match first_button with
              | Some b -> [ b ]
              | None -> [])
           else [])
          @ [ previous_button ]
          @ [ indicator ]
          @ [ next_button ]
          @ (if show_first_last
             then
               (match last_button with
                | Some b -> [ b ]
                | None -> [])
             else [])
        in
        let controls =
          Vdom.Node.div
            ~attrs:(Common.Attr.class_ [ "astryx-pagination__controls" ])
            controls_children
        in
        (* The announcement: the page that is current, in a polite live
           region, so the change is read out. *)
        let announcement =
          match computed_total_pages with
          | Some total -> page_of_total_label ~current:page ~total
          | None -> page_announce_label ~current:page
        in
        Vdom.Node.nav
          ~attrs:
            (Common.Attr.class_ [ "astryx-pagination" ]
            @ (match id with Some id -> [ Vdom.Attr.id id ] | None -> [])
            @ Common.Attr.aria "label" label
            @ Common.Attr.data "component" "Pagination"
            @ (Option.value attrs ~default:[]))
          [ controls
          ; Visually_hidden.view
              ~element:Visually_hidden.Div
              [ Vdom.Node.div
                  ~attrs:
                    ([ Vdom.Attr.role "status" ]
                    @ Common.Attr.aria "live" "polite"
                    @ Common.Attr.class_ [ "astryx-pagination__announcement" ])
                  [ Vdom.Node.text announcement ] ]
          ])
;;
