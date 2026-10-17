open! Core
open! Bonsai_web

type collapse_from = Overflow_math.collapse_from =
  | Start
  | End
;;

let item_class = "astryx-overflow-list__item"
let indicator_class = "astryx-overflow-list__indicator"

let view
  ?max_visible_items
  ?max_rows
  ?(min_visible_items = 0)
  ?(gap = Common.Spacing.S0)
  ?(collapse_from = End)
  ?(overflow_label = fun hidden -> "+" ^ Int.to_string hidden)
  ?(attrs = [])
  ~items
  graph
  ()
  =
  let item_count = List.length items in
  (* Everything is shown until a measurement says otherwise, and the hook's first measurement always
     reports - so the first paint is never collapsed-then-expanded. *)
  let visible_count, set_visible_count = Bonsai.state item_count graph in
  (* The setter is itself a [Bonsai.t], so the hook's attribute - and therefore the measurement
     container - is built under a map rather than called directly. *)
  let measure_attr =
    Bonsai.map set_visible_count ~f:(fun set_visible_count ->
      Common.Overflow_hook.attr
        ~selector:("." ^ item_class)
        ~indicator_selector:("." ^ indicator_class)
        ~min_visible_items
        ?max_visible_items
        ?max_rows
        ~collapse_from
        ~on_measured:(fun (count, _rows) -> set_visible_count count)
        ())
  in
  let hidden_count = Bonsai.map visible_count ~f:(fun visible -> Int.max 0 (item_count - visible)) in
  let wrap_item node = Vdom.Node.div ~attrs:[ Vdom.Attr.class_ item_class ] [ node ] in
  let indicator hidden =
    Vdom.Node.span
      ~attrs:[ Vdom.Attr.class_ indicator_class ]
      [ Vdom.Node.text (overflow_label hidden) ]
  in
  (* The hidden container measures with the widest label the indicator can carry, so the reserved
     width is never less than what the visible row will need. *)
  let measurement =
    Bonsai.map measure_attr ~f:(fun measure_attr ->
      Vdom.Node.div
        ~attrs:[ Vdom.Attr.class_ "astryx-overflow-list__measure"; measure_attr ]
        (List.map items ~f:wrap_item @ [ indicator item_count ]))
  in
  let row =
    Bonsai.map hidden_count ~f:(fun hidden ->
      let visible = item_count - hidden in
      let shown =
        match collapse_from with
        | End -> List.take items visible
        | Start -> List.drop items (item_count - visible)
      in
      let children =
        List.map shown ~f:wrap_item @ if hidden > 0 then [ indicator hidden ] else []
      in
      Vdom.Node.div
        ~attrs:
          [ Vdom.Attr.class_ "astryx-overflow-list__row"
          ; Vdom.Attr.create "style" ("gap: var(--spacing-" ^ Common.Spacing.step gap ^ ")")
          ]
        children)
  in
  Bonsai.map2 measurement row ~f:(fun measurement row ->
    Vdom.Node.div
      ~attrs:
        (Vdom.Attr.class_ "astryx-overflow-list"
         :: (Common.Attr.data "component" "OverflowList" @ attrs))
      [ measurement; row ])
;;
