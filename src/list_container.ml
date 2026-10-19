(* List — a vertical list of rows. Port of upstream List/List.tsx + ListContext.tsx;
   the row is List_item.ml. *)

open! Core
open! Bonsai_web

type density =
  | Compact
  | Balanced
  | Spacious

type marker_style =
  | No_marker
  | Disc
  | Circle
  | Decimal

(* A unique id for the header/label pairing when the caller gave none: the
   aria-labelledby link needs two ids on one page, and more than one list may
   carry a header. The caller's id wins when present. *)
let header_counter = ref 0

let gen_header_id () =
  incr header_counter;
  sprintf "astryx-list-header-%d" !header_counter
;;

let density_name = function
  | Compact -> "compact"
  | Balanced -> "balanced"
  | Spacious -> "spacious"
;;

let marker_name = function
  | No_marker -> None
  | Disc -> Some "disc"
  | Circle -> Some "circle"
  | Decimal -> Some "decimal"
;;

let item_id id = match id with Some s -> [ Vdom.Attr.id s ] | None -> []

let view
    ?(attrs = [])
    ?id
    ?(density = Balanced)
    ?(has_dividers = false)
    ?(list_style = No_marker)
    ?start
    ?header
    ?edge_compensation
    ~items
    () =
  let header_id = gen_header_id () in
  (* The counter: reset on the list so the first row is 1, or [start] when the
     caller asked for something else. A custom-property-free inline override
     (upstream's dynamic counterStart class does exactly this value). *)
  let counter_style =
    match list_style, start with
    | Decimal, Some s when Int.(<>) s 1 ->
      Common.Attr.style [ ("counter-reset", sprintf "astryx-list %d" (s - 1)) ]
    | Decimal, _ -> Common.Attr.class_ [ "astryx-list--with-counter" ]
    | _ -> []
  in
  let list_attrs =
    Common.Attr.class_ ([ "astryx-list" ] @ [ sprintf "astryx-list--density-%s" (density_name density) ])
    @ Common.Attr.data "component" "List"
    @ Common.Attr.data "density" (density_name density)
    @ (if has_dividers then Common.Attr.data "dividers" "true" else [])
    @ (match marker_name list_style with
       | Some m -> Common.Attr.data "marker" m
       | None -> [])
    @ (match edge_compensation with
       | Some `Inline -> Common.Attr.data "edge" "inline"
       | None -> [])
    @ (match header with
       | Some _ -> Common.Attr.aria "labelledby" header_id
       | None -> [])
    @ (match list_style, start with
       | Decimal, Some s when Int.(<>) s 1 ->
         [ Vdom.Attr.create "start" (string_of_int s) ]
       | _ -> [])
    @ Common.Attr.role "list"
    @ counter_style
    @ item_id id
    @ attrs
  in
  let list_node =
    if Poly.equal list_style Decimal
    then Vdom.Node.ol ~attrs:list_attrs items
    else Vdom.Node.ul ~attrs:list_attrs items
  in
  match header with
  | None -> list_node
  | Some h ->
    (* Upstream wraps: a plain header above the list, associated through
       aria-labelledby, with the header's own box under the list's control. *)
    Vdom.Node.div
      ~attrs:(Common.Attr.class_ [ "astryx-list__wrap" ])
      [ Vdom.Node.div
          ~attrs:
            (Common.Attr.class_ [ "astryx-list__header" ]
             @ [ Vdom.Attr.id header_id ])
          [ h ]
      ; list_node
      ]
;;
