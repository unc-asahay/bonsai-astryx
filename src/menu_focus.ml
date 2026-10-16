(** Roving focus and typeahead for a menu.

    A port of upstream's [useListFocus] (vertical menu navigation) and
    [useTypeahead]. Both work on the DOM rather than on a model: the highlight
    *is* DOM focus, the rows are found by querying the container, and navigation
    moves focus instead of tracking an index. That is upstream's own design —
    "menus keep a single highlighted item by using DOM focus as the sole
    highlight source" — so the port keeps it. There is no item list in the model
    that could drift out of step with what is rendered, and hover, arrow keys and
    typeahead all agree because they all end at the same [focus].

    Two behaviours here are easy to get subtly wrong and are worth naming:

    - **Disabled rows leave the order entirely.** Upstream's selector excludes
      [aria-disabled="true"] from the query rather than filtering during
      navigation, so no index can ever point at a row that cannot take focus.
      A [focus] on such a row silently does nothing and navigation would freeze.
    - **The deviating key must be judged by its author.** A row that is a link
      and a checkbox row are both reachable through the same order, and the
      [aria-disabled] check has to happen here rather than in the caller. *)

open! Core
open Js_of_ocaml

type el = Dom_html.element Js.t

let js = Js_of_ocaml.Js.string

(* The typed js_of_ocaml interface does not cover every DOM method used here
   (and its [element] class types differ between releases), so the handful of
   unavoidable calls go through [Js.Unsafe] with the cast made explicit. *)
let call (obj : 'a Js.t) (name : string) (args : Js_of_ocaml.Js.Unsafe.any array) =
  Js_of_ocaml.Js.Unsafe.meth_call obj name args

let get (obj : 'a Js.t) (name : string) = Js.Unsafe.get obj name

let query_all (container : el) (sel : string) : el list =
  let node_list : Dom.node Dom.nodeList Js.t = call container "querySelectorAll" [| Js.Unsafe.inject (js sel) |] in
  Dom.list_of_nodeList node_list |> List.filter_map ~f:(fun n -> Js.Opt.to_option (Dom_html.CoerceTo.element n))

let closest (el : el) (sel : string) : el option =
  Js.Opt.to_option (call el "closest" [| Js.Unsafe.inject (js sel) |] : el Js.opt)

let attr (el : el) (name : string) : string option =
  (* getAttribute answers null for a missing attribute, which the annotated
     return type keeps as [None] rather than the string "null". *)
  Option.map (Js.Opt.to_option (call el "getAttribute" [| Js.Unsafe.inject (js name) |] : Js.js_string Js.t Js.opt))
    ~f:Js.to_string

let focus (el : el) =
  (* preventScroll: focusing an off-screen row would scroll it under a
     stationary pointer, whose next pointerenter focuses it again — a runaway
     auto-scroll loop, which is upstream's stated reason for the flag. *)
  ignore
    (call
       el
       "focus"
       [| Js.Unsafe.inject (Js.Unsafe.obj [| "preventScroll", Js.Unsafe.inject Js._true |]) |])

let focus_on_next_frame (focus_it : unit -> unit) =
  (* Focus lands one frame late, and for both directions of a menu this is the only
     moment it can land at all.

     Opening: the row does not exist until the update that opens the menu has been
     rendered. Closing: a browser moves focus to the body the moment the focused
     element is removed, so a focus call made before that update is undone by it.

     [Effect.Focus.on_activate] is the documented way to focus a newly mounted element,
     and it is what this port first used — but it runs when a *computation* is
     activated, and a menu that renders its rows on a state change keeps that
     computation alive from the first paint, so it fires at the wrong moment: once, when
     the menu was still closed. Hence a frame. *)
  ignore
    (Js.Unsafe.fun_call
       (Js.Unsafe.pure_js_expr "requestAnimationFrame")
       [| Js.Unsafe.inject (Js.wrap_callback focus_it) |])
;;

let text_content (el : el) : string =
  match Js.Opt.to_option (get el "textContent" : Js.js_string Js.t Js.opt) with
  | Some s -> Js.to_string s
  | None -> ""

(* The three roles a focusable menu row can carry. Kept as a list of selectors,
   built once, so the selector string and the disabled rule cannot drift apart. *)
let roles = [ "menuitem"; "menuitemradio"; "menuitemcheckbox" ]

let item_selector =
  List.map roles ~f:(sprintf "[role=\"%s\"]:not([aria-disabled=\"true\"])") |> String.concat ~sep:","

let is_disabled (el : el) =
  match attr el "aria-disabled" with
  | Some "true" -> true
  | _ ->
    (match Js.Opt.to_option (get el "disabled" : bool Js.t Js.opt) with
     | Some b -> Js.to_bool b
     | None -> false)
    || Js.to_bool (call el "hasAttribute" [| Js.Unsafe.inject (js "disabled") |])

(** A row under a hidden or inert ancestor that is itself inside the container
    cannot take focus — a drilled-in view replaced it — so it leaves the order. *)
let is_hidden_within (el : el) (container : el) =
  match Js.Opt.to_option (get el "parentElement" : el Js.opt) with
  | None -> false
  | Some parent -> (
    match closest parent "[hidden],[inert]" with
    | None -> false
    | Some hidden ->
      (not (Js.to_bool (call hidden "isSameNode" [| Js.Unsafe.inject container |])))
      && Js.to_bool (call container "contains" [| Js.Unsafe.inject hidden |]) )

let items (container : el) : el list =
  query_all container item_selector
  |> List.filter ~f:(fun el -> not (is_hidden_within el container))
  (* A nested menu's rows are DOM descendants of ours (flyouts render inline,
     not in a portal), so keep only rows whose nearest [role="menu"] is us. *)
  |> List.filter ~f:(fun el ->
    match closest el "[role=\"menu\"]" with
    | None -> false
    | Some owner -> Js_of_ocaml.Js.to_bool (call owner "isSameNode" [| Js_of_ocaml.Js.Unsafe.inject container |]))

let active_element () : el option =
  Js.Opt.to_option (get Dom_html.document "activeElement" : el Js.opt)

let current_index (container : el) : int =
  let active = active_element () in
  match active with
  | None -> -1
  | Some active ->
    List.findi (items container) ~f:(fun _ el ->
      Js_of_ocaml.Js.to_bool (call el "isSameNode" [| Js_of_ocaml.Js.Unsafe.inject active |])
      || Js_of_ocaml.Js.to_bool (call el "contains" [| Js_of_ocaml.Js.Unsafe.inject active |]))
    |> Option.map ~f:fst
    |> Option.value ~default:(-1)

(** The row that currently has focus, or [None] — the same source of truth that
    [current_index] uses, but returning the element so a caller can act on it. *)
let focused_item (container : el) : el option =
  match active_element () with
  | None -> None
  | Some active ->
    List.find (items container) ~f:(fun el ->
      Js_of_ocaml.Js.to_bool (call el "isSameNode" [| Js_of_ocaml.Js.Unsafe.inject active |])
      || Js_of_ocaml.Js.to_bool (call el "contains" [| Js_of_ocaml.Js.Unsafe.inject active |]))

let focus_index (container : el) (index : int) =
  match List.nth (items container) index with
  | Some el -> focus el
  | None -> ()

let focus_first (container : el) : bool =
  match items container with
  | [] -> false
  | el :: _ ->
    focus el;
    true

let focus_last (container : el) : bool =
  match List.rev (items container) with
  | [] -> false
  | el :: _ ->
    focus el;
    true

let js_bool b = if b then Js._true else Js._false

(** Activate a row from the keyboard: a synthesized click that carries the key's
    modifiers, so a ⌘-Enter on a row that is a link opens it the way a ⌘-click
    would. [detail] stays 0 — the mark of a non-pointer activation, which is what
    the row's own handlers can test to tell a keyboard activation from a click. *)
let activate_row (el : el) ~(meta : bool) ~(ctrl : bool) ~(shift : bool) ~(alt : bool) : unit =
  let event : Js.Unsafe.any =
    Js.Unsafe.new_obj
      (Js.Unsafe.pure_js_expr "MouseEvent")
      [| Js.Unsafe.inject (Js.string "click")
       ; Js.Unsafe.inject
           (Js.Unsafe.obj
              [| "bubbles", Js.Unsafe.inject Js._true
               ; "cancelable", Js.Unsafe.inject Js._true
               ; "composed", Js.Unsafe.inject Js._true
               ; "detail", Js.Unsafe.inject (Js.number_of_float 0.)
               ; "metaKey", Js.Unsafe.inject (js_bool meta)
               ; "ctrlKey", Js.Unsafe.inject (js_bool ctrl)
               ; "shiftKey", Js.Unsafe.inject (js_bool shift)
               ; "altKey", Js.Unsafe.inject (js_bool alt)
              |])
      |]
  in
  ignore (call el "dispatchEvent" [| Js.Unsafe.inject event |])

(** Activate the row that currently has focus, if any. [true] when a row was
    activated. *)
let activate_current ~(container : el) ~(meta : bool) ~(ctrl : bool) ~(shift : bool) ~(alt : bool) : bool =
  match focused_item container with
  | None -> false
  | Some row ->
    activate_row row ~meta ~ctrl ~shift ~alt;
    true

(** Whether a click carried a modifier or a non-primary button. On a row that is
    a link the browser gives those a meaning of its own — a new tab, a download —
    which the row must leave alone. *)
let is_modified_click ~(meta : bool) ~(ctrl : bool) ~(shift : bool) ~(alt : bool) ~(button : int) : bool =
  meta || ctrl || shift || alt || button <> 0

(** Does this key event belong to this level, or did it bubble out of a nested
    menu that already handled it? Handled twice, focus would move twice. *)
let owns_event (container : el) (target : el) : bool =
  match closest target "[role=\"menu\"]" with
  | None -> true
  | Some owner -> Js_of_ocaml.Js.to_bool (call owner "isSameNode" [| Js_of_ocaml.Js.Unsafe.inject container |])

let handle_navigation ~(container : el) ~(key : string) ~(wrap : bool) : bool =
  let items = items container in
  if List.is_empty items then false
  else (
    let count = List.length items in
    let current = current_index container in
    let step_from start step =
      (* Walk at most [count] steps so a menu whose every row is unreachable
         terminates instead of spinning. *)
      let rec go index fuel =
        if fuel = 0 then None
        else (
          let index =
            if index < 0 || index >= count
            then (if wrap then (index + count) mod count else -1)
            else index
          in
          if index = -1 then None
          else (
            match List.nth items index with
            | Some el when not (is_disabled el) -> Some index
            | _ -> go (index + step) (fuel - 1)))
      in
      go start (count + 1)
    in
    let move target =
      Option.iter target ~f:(fun index ->
        (match List.nth items index with
         | Some el -> focus el
         | None -> ()));
      true
    in
    match key with
    | "ArrowDown" -> move (step_from (if current = -1 then 0 else current + 1) 1)
    | "ArrowUp" -> move (step_from (if current = -1 then count - 1 else current - 1) (-1))
    | "Home" -> if focus_first container then true else false
    | "End" -> if focus_last container then true else false
    | _ -> false)

type typeahead = {
  mutable buffer : string;
  mutable expires_at : float;
  reset_ms : int;
}

let now_ms () : float =
  match Js.Opt.to_option (get Dom_html.window "performance" : Js.Unsafe.any Js.opt) with
  | None -> 0.
  | Some perf -> Js.to_float (call perf "now" [||])

let create_typeahead ?(reset_ms = 750) () = { buffer = ""; expires_at = 0.; reset_ms }

let reset (t : typeahead) =
  t.buffer <- "";
  t.expires_at <- 0.

let handle_typeahead (t : typeahead) ~(container : el) ~(key : string) ~(ctrl : bool) ~(meta : bool) ~(composing : bool) : bool =
  (* A bare space is activation in a menu, not typeahead — but once the user is
     mid-word it extends the query. A chorded space is neither. *)
  let is_space_mid_type = String.equal key " " && (not ctrl) && (not meta) && (not composing) && not (String.is_empty t.buffer) in
  let is_printable =
    (* Alt is deliberately not excluded: Option+letter composes a printable
       character on macOS, and a real chord still carries ctrl or meta (AltGr
       sets ctrl on Windows and Linux). *)
    String.length key = 1 && (not ctrl) && (not meta) && (not composing) && not (String.equal key " ")
  in
  if not (is_printable || is_space_mid_type)
  then false
  else (
    let labels = items container in
    if List.is_empty labels then false
    else (
      let now = now_ms () in
      if Float.(now > t.expires_at) then t.buffer <- "";
      let char = String.lowercase key in
      (* Pressing the same character again cycles to the next match rather than
         filtering deeper — the APG behaviour. *)
      let is_repeat_same_char =
        (not (String.is_empty t.buffer)) && String.for_all t.buffer ~f:(Char.equal char.[0])
      in
      let next_buffer = if is_repeat_same_char then char else t.buffer ^ char in
      t.buffer <- next_buffer;
      t.expires_at <- now +. Float.of_int t.reset_ms;
      let labels = List.map labels ~f:text_content in
      let count = List.length labels in
      let current = current_index container in
      let has_current = current >= 0 in
      let start = if has_current then current else 0 in
      (* A single-character search starts *after* the current row, so pressing a
         letter walks to the next row starting with it instead of re-matching
         the one already highlighted. A longer buffer is refining, so the
         current row stays in range. *)
      let offset = if has_current && String.length next_buffer = 1 then 1 else 0 in
      let rec search i =
        if i >= count
        then ()
        else (
          let index = (start + offset + i + count) mod count in
          let label = String.lowercase (String.strip (List.nth_exn labels index)) in
          if String.is_prefix label ~prefix:next_buffer
          then focus_index container index
          else search (i + 1))
      in
      (* Upstream returns true even when nothing matched: the character was
         consumed as typeahead and must not also reach the page. *)
      search 0;
      true))
