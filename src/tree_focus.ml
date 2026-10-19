(** Roving focus + the WAI-ARIA tree keyboard model, for Tree_list.

    A port of upstream's [useTreeFocusInternal] (hooks/useTreeFocus.ts). The model
    differs from a linear list: ArrowUp/ArrowDown/Home/End roam linearly over the
    *visible* treeitems (collapsed subtrees are not rendered, so they are
    naturally excluded), while ArrowRight/ArrowLeft carry tree semantics
    (expand a collapsed parent / move to first child; collapse an expanded parent
    / move to its parent). Enter/Space activate the item's own inner action when
    it has one (the same row, never a descendant treeitem's), else toggle
    expansion.

    Everything works on the DOM rather than on a model — the same call upstream
    makes: focus is the highlight, rows are found by querying the container, and
    navigation moves focus instead of tracking an index. Expansion itself is a
    *click*: toggling from the keyboard dispatches a DOM click on the row's
    [data-tree-toggle] button (exactly what upstream's activateItem does for
    inner actions), so the OCaml handler that owns the expansion state runs and
    a re-render follows. No effect plumbing needs to leak into this module.

    Two behaviour details come straight from upstream and are easy to get wrong:

    - **Disabled rows stay in the order but are skipped.** Upstream matches them
      and then filters during navigation — a focus() on an inert row silently
      no-ops and navigation would freeze. [data-tree-disabled] (present means
      disabled) and [aria-disabled="true"] both count.
    - **Roving tabindex is a single tab stop.** Exactly one enabled treeitem
      carries [tabindex="0"]; the repair pass prefers an existing one (so the
      render can seed the active item with [is_selected]) and otherwise promotes
      the first enabled. The container's own focus handler calls [sync] to keep
      the stop pointing at whatever the user clicked. *)

open! Core
open Js_of_ocaml

type el = Dom_html.element Js.t

let js_string = Js_of_ocaml.Js.string

let call (obj : 'a Js.t) (name : string) (args : Js_of_ocaml.Js.Unsafe.any array) =
  Js_of_ocaml.Js.Unsafe.meth_call obj name args
;;

let get (obj : 'a Js.t) (name : string) = Js.Unsafe.get obj name

let query_all (container : el) (sel : string) : el list =
  let node_list : Dom.node Dom.nodeList Js.t =
    call container "querySelectorAll" [| Js.Unsafe.inject (js_string sel) |]
  in
  Dom.list_of_nodeList node_list
  |> List.filter_map ~f:(fun n -> Js.Opt.to_option (Dom_html.CoerceTo.element n))
;;

let closest (el : el) (sel : string) : el option =
  Js.Opt.to_option (call el "closest" [| Js.Unsafe.inject (js_string sel) |] : el Js.opt)
;;

let attr (el : el) (name : string) : string option =
  Option.map
    (Js.Opt.to_option
       (call el "getAttribute" [| Js.Unsafe.inject (js_string name) |] : Js.js_string Js.t Js.opt))
    ~f:Js.to_string
;;

let focus (el : el) =
  ignore
    (call
       el
       "focus"
       [| Js.Unsafe.inject (Js.Unsafe.obj [| "preventScroll", Js.Unsafe.inject Js._true |]) |])
;;

let text_content (el : el) : string =
  match Js.Opt.to_option (get el "textContent" : Js.js_string Js.t Js.opt) with
  | Some s -> Js.to_string s
  | None -> ""
;;

let current_element () : el option =
  Js.Opt.to_option (Js.Unsafe.get Dom_html.document "activeElement" : el Js.opt)
;;

(* The label a treeitem is matched by for typeahead: the text of the element its
   aria-labelledby points at (the label alone — the label span carries that id
   and the row never contributes its chevron, description or start content). *)
let labelled_text (el : el) : string =
  match attr el "aria-labelledby" with
  | Some ids ->
    String.split ids ~on:' '
    |> List.filter_map ~f:(fun id ->
      Js.Opt.to_option
      (call Dom_html.document "getElementById" [| Js.Unsafe.inject (js_string id) |] : Dom_html.element Js.t Js.opt)
    |> Option.map ~f:text_content)
    |> String.concat ~sep:" " |> String.strip
  | None -> String.strip (text_content el)
;;

let item_selector = "[role=\"treeitem\"]"

let items (container : el) : el list = query_all container item_selector

let is_disabled (el : el) : bool =
  match attr el "data-tree-disabled" with
  | Some _ -> true
  | None -> Poly.equal (attr el "aria-disabled") (Some "true")
;;

let level_of (el : el) : int =
  match attr el "aria-level" with
  | Some s -> ( try Int.of_string s with _ -> 1 )
  | None -> 1
;;

let expanded_of (el : el) : bool = Poly.equal (attr el "aria-expanded") (Some "true")

let collapsed_of (el : el) : bool = Poly.equal (attr el "aria-expanded") (Some "false")

let id_of (el : el) : string option = attr el "data-tree-id"

let is_rtl (el : el) : bool =
  Js.to_bool
    (Js.Unsafe.fun_call
       (Js.Unsafe.eval_string
          "(function (el) { var r = el.closest('[dir=\"rtl\"]'); if (r) return true; var d = el.ownerDocument; if (d && d.documentElement && d.documentElement.getAttribute) { return d.documentElement.getAttribute('dir') === 'rtl'; } return false; })")
       [| Js.Unsafe.inject el |])
;;

let set_tabindex (el : el) (value : int) =
  ignore
    (call el "setAttribute" [| Js.Unsafe.inject (js_string "tabindex"); Js.Unsafe.inject (js_string (Int.to_string value)) |])
;;

(* Exactly one enabled treeitem is tabbable: 0 on [target], -1 on every other
   visible treeitem (upstream's moveTabStop). *)
let move_tab_stop (container : el) (target : el) =
  List.iter (items container) ~f:(fun el -> set_tabindex el (if Poly.equal el target then 0 else -1))
;;

(* Repair the stop: prefer an existing tabindex=0 (the render may have seeded
   it), else the first enabled treeitem. *)
let sync (container : el) =
  let all = items container in
  let enabled = List.filter all ~f:(fun el -> not (is_disabled el)) in
  match enabled with
  | [] -> ()
  | first :: _ ->
    let current = List.find enabled ~f:(fun el -> Poly.equal (attr el "tabindex") (Some "0")) in
    move_tab_stop container (Option.value current ~default:first)
;;

(* Focus a treeitem, moving the roving stop first. *)
let focus_item (container : el) (el : el) =
  move_tab_stop container el;
  focus el
;;

let focus_first (container : el) =
  let rec go = function
    | [] -> false
    | el :: rest -> if is_disabled el then go rest else (focus_item container el; true)
  in
  go (items container)
;;

let focus_last (container : el) =
  let rec go = function
    | [] -> false
    | el :: rest -> if is_disabled el then go rest else (focus_item container el; true)
  in
  go (List.rev (items container))
;;

(* First enabled from [start] in direction [dir]; no wrap — a tree's linear roam
   clamps at the ends. *)
let focus_enabled_from (container : el) (start : int) (dir : int) =
  let all = items container in
  let n = List.length all in
  let rec go i =
    if i < 0 || i >= n
    then false
    else (
      let candidate = List.nth_exn all i in
      if is_disabled candidate then go (i + dir) else (focus_item container candidate; true))
  in
  go start
;;

let click_chevron (el : el) : bool =
  match query_all el "button[data-tree-toggle]" with
  | [] -> false
  | btn :: _ ->
    ignore (call btn "click" [||]);
    true
;;

(* Enter/Space activation: prefer the treeitem's own inner action (link or
   button), never a descendant treeitem's action inside an expanded group.
   Returns false when the row is disabled or has no action, so the caller can
   fall back to expansion toggling for a parent. *)
let activate (el : el) : bool =
  if is_disabled el
  then false
  else (
    match query_all el "a[href], button:not([data-tree-toggle])" with
    | [] -> false
    | first :: _ ->
      (match closest first "[role=\"treeitem\"]" with
       | Some owner when Poly.equal owner el -> ignore (call first "click" [||]); true
       | _ -> false))
;;

type typeahead = {
  mutable buffer : string;
  mutable expires_at : float;
  reset_ms : int;
}

let now_ms () : float =
  match Js.Opt.to_option (get Dom_html.window "performance" : Js.Unsafe.any Js.opt) with
  | None -> 0.
  | Some perf -> Js.to_float (call perf "now" [||])
;;

let create_typeahead ?(reset_ms = 500) () = { buffer = ""; expires_at = 0.; reset_ms }

let reset (t : typeahead) =
  t.buffer <- ""; t.expires_at <- 0.
;;

(* Typeahead is a printable single character that is not one of the navigation
   keys. Upstream's own wording: a repeat of the same character means "next
   match"; a longer buffer refines (so the current item stays in range); the
   match is the label (aria-labelledby text), never the row's whole text. *)
let handle_typeahead (t : typeahead) ~(container : el) ~(key : string) ~(ctrl : bool) ~(meta : bool) ~(alt : bool) : bool =
  let is_printable =
    String.length key = 1
    && not ctrl
    && not meta
    && not alt
    && (not (String.equal key " "))
    && (not (String.equal key "Enter"))
  in
  if not is_printable
  then false
  else (
    let rows = items container in
    if List.is_empty rows
    then false
    else (
      let now = now_ms () in
      if Float.(now > t.expires_at) then t.buffer <- "";
      let char = String.lowercase key in
      let is_repeat_same_char =
        (not (String.is_empty t.buffer))
        && List.for_all (String.to_list t.buffer) ~f:(fun c -> Char.equal c char.[0])
      in
      let next_buffer = if is_repeat_same_char then char else t.buffer ^ char in
      t.buffer <- next_buffer;
      t.expires_at <- now +. Float.of_int t.reset_ms;
      let labels = List.map rows ~f:labelled_text in
      let count = List.length labels in
      let current =
        match current_element () with
        | Some active -> (
          match closest active "[role=\"treeitem\"]" with
          | Some el -> Option.map (List.findi rows ~f:(fun _ row -> Poly.equal row el)) ~f:fst
          | None -> None)
        | None -> None
      in
      let start = Option.value current ~default:(-1) in
      let offset = if Option.is_some current && String.length next_buffer = 1 then 1 else 0 in
      let rec search i =
        if i >= count
        then ()
        else (
          let index = (start + offset + i + count) mod count in
          let label = String.lowercase (String.strip (List.nth_exn labels index)) in
          if String.is_prefix label ~prefix:next_buffer
          then focus_item container (List.nth_exn rows index)
          else search (i + 1))
      in
      (* The character was consumed as typeahead even when nothing matched; it
         must not also reach the page. *)
      search 0;
      true))
;;

let navigation_keys = [ "ArrowDown"; "ArrowUp"; "ArrowRight"; "ArrowLeft"; "Home"; "End"; "Enter"; " " ]

(* The tree keyboard model. Returns true when the event was handled (the caller
   should preventDefault). [toggle] names the row whose chevron button a
   navigation key should click — the button's own OCaml handler owns the actual
   expansion state, and a re-render follows. *)
let handle_key (container : el) (typeahead : typeahead) ~(key : string) ~(meta : bool) ~(ctrl : bool) ~(alt : bool) : bool =
  if List.mem navigation_keys key ~equal:String.equal
  then (
    let current =
      match current_element () with
      | Some active -> closest active "[role=\"treeitem\"]"
      | None -> None
    in
    let rows = items container in
    let current_index =
      match current with
      | None -> -1
      | Some el -> Option.value (List.findi rows ~f:(fun _ row -> Poly.equal row el) |> Option.map ~f:fst) ~default:(-1)
    in
    let key =
      if String.equal key "ArrowLeft" || String.equal key "ArrowRight"
      then if is_rtl container then if String.equal key "ArrowLeft" then "ArrowRight" else "ArrowLeft" else key
      else key
    in
    match key with
    | "ArrowDown" -> focus_enabled_from container (if current_index < 0 then 0 else current_index + 1) 1
    | "ArrowUp" -> focus_enabled_from container (if current_index < 0 then List.length rows - 1 else current_index - 1) (-1)
    | "Home" -> focus_first container
    | "End" -> focus_last container
    | "ArrowRight" -> (
      match current with
      | None -> false
      | Some el when collapsed_of el ->
        click_chevron el
      | Some el when expanded_of el -> (
        match List.nth rows (current_index + 1) with
        | Some next when level_of next > level_of el -> focus_item container next; true
        | _ -> false)
      | Some _ -> false)
    | "ArrowLeft" -> (
      match current with
      | None -> false
      | Some el when expanded_of el ->
        click_chevron el
      | Some el ->
        let current_level = level_of el in
        let rec go i =
          if i < 0
          then false
          else (
            let candidate = List.nth_exn rows i in
            if level_of candidate < current_level
            then (focus_item container candidate; true)
            else go (i - 1))
        in
        go (current_index - 1))
    | "Enter" | " " -> (
      match current with
      | None -> false
      | Some el when is_disabled el -> false
      | Some el -> if activate el then true else click_chevron el)
    | _ -> false)
  else if String.length key = 1
          && not (String.equal key " ")
          && not meta && not ctrl && not alt
  then handle_typeahead typeahead ~container ~key ~ctrl ~meta ~alt
  else false
;;
