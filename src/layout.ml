open! Core
open! Bonsai_web
open Js_of_ocaml

(* Layout — the five-slot primitive: header, start, content, end, footer,
   pored from facebook/astryx Layout (Layout.tsx, LayoutHeader.tsx,
   LayoutFooter.tsx, LayoutContent.tsx, LayoutPanel.tsx, padding.stylex.ts).

   Upstream threads three React contexts (area, slots-present, divider
   default). The port answers all three structurally or with one small vdom
   hook, so neither [graph] nor context plumbing leaks into the API:
   - area: the CSS sees which sibling slot a panel occupies
     ([astryx-layout__middle] first/last child), so no value travels.
   - slots-present: [:has] on the layout wrappers decides which edges of
     content and panel carry outer padding; same idea, no value.
   - divider default: [Layout.view] writes [data-astryx-default-dividers] on
     the inner element only when the argument is given — that is upstream's
     "context only exists when the prop is set" rule, so a nested layout that
     does not restate it inherits the nearest one — and each header/footer
     resolves it after the DOM patch with a hook that sets or removes
     [data-astryx-divider="true"] (a header/footer that passes [has_divider]
     explicitly skips the lookup, exactly like upstream's
     [hasDivider ?? ctx ?? false]). *)

type height =
  | Fill
  | Auto
[@@deriving sexp_of]

let spacing_var = Common.Spacing.var
let spacing_step = Common.Spacing.step

(* The container-padding variables a region publishes. The container system
   talks through inherited custom properties: a padded region announces its
   own inset and children (Section, Divider, Layout) compensate with negative
   margins or re-announce. *)
let container_pairs ~x ~y : (string * string) list =
  [ ("--container-padding-inline-start", x)
  ; ("--container-padding-inline-end", x)
  ; ("--container-padding-block-start", y)
  ; ("--container-padding-block-end", y)
  ]
;;

(* Per-instance padding values are inline because that is the house rule.
   [padding_pairs spacing] writes the two outer-edge variables an explicit
   layout padding needs, so this layout's regions bleed against it. *)
let padding_pairs (p : Common.Spacing.t) : (string * string) list =
  let v = spacing_var p in
  [ ("--layout-padding-own-outer-x", v); ("--layout-padding-own-outer-y", v) ]
;;

let is_zero (p : Common.Spacing.t) = Poly.equal p Common.Spacing.S0

(* ------------------------------------------------------------ divider hook
   [data-astryx-divider="true"] is resolved in the DOM for the default path:
   walk up to the nearest [data-astryx-default-dividers] (the layout inner),
   exactly like upstream's context. An explicit value from the header/footer
   itself wins. *)

let divider_resolve =
  Js.Unsafe.eval_string
    "(function () {\n\
    \  return function (el, explicit) {\n\
    \    var resolved = false;\n\
    \    if (explicit === 'true') { resolved = true; }\n\
    \    else if (explicit === 'false') { resolved = false; }\n\
    \    else {\n\
    \      var d = el.closest('[data-astryx-default-dividers]');\n\
    \      if (d) { resolved = d.getAttribute('data-astryx-default-dividers') === 'true'; }\n\
    \    }\n\
    \    if (resolved) { el.setAttribute('data-astryx-divider', 'true'); }\n\
    \    else { el.removeAttribute('data-astryx-divider'); }\n\
    \  };\n\
    })()"
;;

module Divider_hook = struct
  module T = struct
    module State = struct
      type t = unit
    end

    (* "true" / "false" = explicit; "" = inherit the nearest layout default. *)
    module Input = struct
      type t = string

      let sexp_of_t s = Sexp.Atom s
      let combine _ later = later
    end

    let init _ _ = ()
    let apply ~input el = ignore (Js.Unsafe.fun_call divider_resolve [| Js.Unsafe.inject el; Js.Unsafe.inject (Js.string input) |])
    let on_mount input _state el = apply ~input el
    let on_mount = `Schedule_immediately_after_this_dom_patch_completes on_mount

    let update ~old_input:_ ~new_input:input _state el = apply ~input el
    let destroy _ _ _ = ()
  end

  module Hook = Vdom.Attr.Hooks.Make (T)

  let attr (explicit : string) = Vdom.Attr.create_hook "astryx-layout-divider" (Hook.create explicit)
end

(* ------------------------------------------------------------- attrs glue *)
let base_attrs ?(attrs = []) ?id name classes style_pairs =
  attrs
  @ (match id with Some i -> [ Vdom.Attr.id i ] | None -> [])
  @ Common.Attr.data "component" name
  @ Common.Attr.class_ classes
  @ Common.Attr.style style_pairs
;;

let div attrs children = Vdom.Node.div ~attrs children
;;

let aria_landmark ?role ?label () : Vdom.Attr.t list =
  let role_attr = match role with Some r -> Common.Attr.role r | None -> [] in
  role_attr @ Common.Attr.aria_opt "label" label
;;

(* The root of a region: identity attributes, then the class set. *)
let region_attr ?(attrs = []) ?id ?role ?label name classes =
  let id_attr = match id with Some i -> [ Vdom.Attr.id i ] | None -> [] in
  attrs @ id_attr
  @ Common.Attr.data "component" name
  @ aria_landmark ?role ?label ()
  @ Common.Attr.class_ classes
;;

(* ---------------------------------------------------------------- header *)
let header
    ?(attrs = [])
    ?id
    ?has_divider
    ?height
    ?label
    ?padding
    ?padding_block_end
    ?role
    children
    ()
  =
  let explicit =
    match has_divider with Some true -> "true" | Some false -> "false" | None -> ""
  in
  let divider_attr =
    match has_divider with
    | Some true -> [ Vdom.Attr.create "data-astryx-divider" "true" ]
    | _ -> [ Divider_hook.attr explicit ]
  in
  let size_style = match height with Some h -> [ ("height", Common.Size_value.to_css h) ] | None -> [] in
  let inner_style =
    match padding with
    | Some p ->
      [ ("padding", spacing_var p) ]
      @ container_pairs ~x:(spacing_var p) ~y:(spacing_var p)
      @ (match padding_block_end with
        | Some be ->
          [ ("padding-block-end", spacing_var be); ("--container-padding-block-end", spacing_var be) ]
        | None -> [])
    | None ->
      (match padding_block_end with
       | Some be ->
         [ ("padding-block-end", spacing_var be); ("--container-padding-block-end", spacing_var be) ]
       | None -> [])
  in
  div
    (region_attr ?id ?role ?label ~attrs "LayoutHeader" [ "astryx-layout-header" ]
     @ divider_attr
     @ Common.Attr.style size_style)
    [ div
        (Common.Attr.class_ [ "astryx-layout-header__inner" ] @ Common.Attr.style inner_style)
        children
    ]
;;

(* ---------------------------------------------------------------- footer *)
let footer
    ?(attrs = [])
    ?id
    ?has_divider
    ?height
    ?label
    ?padding
    ?role
    children
    ()
  =
  let explicit =
    match has_divider with Some true -> "true" | Some false -> "false" | None -> ""
  in
  let divider_attr =
    match has_divider with
    | Some true -> [ Vdom.Attr.create "data-astryx-divider" "true" ]
    | _ -> [ Divider_hook.attr explicit ]
  in
  let size_style = match height with Some h -> [ ("height", Common.Size_value.to_css h) ] | None -> [] in
  let inner_style =
    match padding with
    | Some p ->
      [ ("padding", spacing_var p) ]
      @ container_pairs ~x:(spacing_var p) ~y:(spacing_var p)
    | None -> []
  in
  div
    (region_attr ?id ?role ?label ~attrs "LayoutFooter" [ "astryx-layout-footer" ]
     @ divider_attr
     @ Common.Attr.style size_style)
    [ div
        (Common.Attr.class_ [ "astryx-layout-footer__inner" ] @ Common.Attr.style inner_style)
        children
    ]
;;

(* ----------------------------------------------------------------- panel *)
let panel
    ?(attrs = [])
    ?id
    ?(has_divider = false)
    ?is_scrollable
    ?label
    ?padding
    ?role
    ?width
    children
    ()
  =
  let classes =
    (if has_divider then [ "astryx-layout-panel--has-divider" ] else [])
    @ (if Option.value_map is_scrollable ~default:true ~f:(fun b -> b) then [ "astryx-layout-panel--scrollable" ] else [])
  in
  let size_style = match width with Some w -> [ ("width", Common.Size_value.to_css w) ] | None -> [] in
  let padding_attr = match padding with Some p -> Common.Attr.data "padding" (spacing_step p) | None -> [] in
  let inner_style =
    match padding with
    | Some p -> [ ("padding", spacing_var p) ] @ container_pairs ~x:(spacing_var p) ~y:(spacing_var p)
    | None -> []
  in
  div
    (region_attr ?id ?role ?label ~attrs "LayoutPanel" ("astryx-layout-panel" :: classes)
     @ Common.Attr.style size_style
     @ padding_attr)
    [ div
        (Common.Attr.class_ [ "astryx-layout-panel__inner" ] @ Common.Attr.style inner_style)
        children
    ]
;;

(* --------------------------------------------------------------- content *)
let content
    ?(attrs = [])
    ?id
    ?(is_scrollable = true)
    ?label
    ?padding
    ?role
    children
    ()
  =
  let classes =
    if is_scrollable then [ "astryx-layout-content--scrollable" ] else [ "astryx-layout-content--clip" ]
  in
  let padding_attr = match padding with Some p -> Common.Attr.data "padding" (spacing_step p) | None -> [] in
  let inner_style =
    match padding with
    | Some p -> [ ("padding", spacing_var p) ] @ container_pairs ~x:(spacing_var p) ~y:(spacing_var p)
    | None -> []
  in
  div
    (region_attr ?id ?role ?label ~attrs "LayoutContent" (("astryx-layout-content" :: classes) @ [])
     @ padding_attr)
    [ div
        (Common.Attr.class_ [ "astryx-layout-content__inner" ] @ Common.Attr.style inner_style)
        children
    ]
;;

(* --------------------------------------------------------- the layout view *)
(* Upstream's [supportsInternalContentWidthAlignment]: values that can sit in
   the CSS arithmetic get the internal path; percentages, bare var() and
   intrinsic keywords get the constrained fallback. *)
let is_digit c = let n = Char.to_int c in n >= 48 && n <= 57
let is_lowercase c = let n = Char.to_int c in n >= 97 && n <= 122

let all_lower s =
  let ok = ref true in
  String.iter s ~f:(fun c -> if not (is_lowercase c) then ok := false);
  !ok
;;

let length_pattern (s : string) : bool =
  let n = String.length s in
  if Int.equal n 0 then false
  else begin
    let i = ref 0 in
    if Char.equal (String.get s 0) '-' then i := 1;
    let digits = ref 0 in
    let seen_dot = ref false in
    while !i < n && (is_digit (String.get s !i) || (Char.equal (String.get s !i) '.' && not !seen_dot)) do
      (if Char.equal (String.get s !i) '.' then seen_dot := true else incr digits);
      incr i
    done;
    if Int.equal !digits 0 || !i >= n then false
    else
      let rest = String.sub s ~pos:!i ~len:(n - !i) in
      all_lower rest
  end
;;

let supports_internal_content_width (w : Common.Size_value.t) : bool =
  match w with
  | Px _ -> true
  | Css s -> (
    let s = String.strip s |> String.lowercase in
    if String.is_empty s || String.contains s '%' then false
    else if String.equal s "0" then true
    else if
      String.is_prefix s ~prefix:"calc("
      || String.is_prefix s ~prefix:"min("
      || String.is_prefix s ~prefix:"max("
      || String.is_prefix s ~prefix:"clamp("
    then true
    else length_pattern s)
;;

let view
    ?(attrs = [])
    ?id
    ?content
    ?content_width
    ?default_has_dividers
    ?end_
    ?footer
    ?header
    ?height
    ?padding
    ?(children = [])
    ?start
    ()
  =
  let is_fill =
    match height with None | Some Fill -> true | Some Auto -> false
  in
  let resolved_content = match content with Some c -> [ c ] | None -> children in
  let has_start = Option.is_some start in
  let has_end = Option.is_some end_ in
  let has_both = has_start && has_end in
  let has_single = not (Bool.equal has_start has_end) in
  let internal =
    match content_width with Some w -> supports_internal_content_width w | None -> false
  in
  let width_to_css = Option.map content_width ~f:Common.Size_value.to_css in
  let inner_pairs =
    container_pairs ~x:"0px" ~y:"0px"
    @ [ ("--layout-content-width", "100cqi"); ("--layout-alignment-width", "100cqi") ]
    @ [ ("--layout-padding-own-outer-x", "initial"); ("--layout-padding-own-outer-y", "initial") ]
    @ (match padding with Some p -> padding_pairs p | None -> [])
    @ (match width_to_css with
      | Some w -> [ ("--layout-content-width", w) ]
      | None -> [])
    @ (if internal then
         match width_to_css with Some w -> [ ("--layout-alignment-width", w) ] | None -> []
       else [])
  in
  let inner_classes =
    [ "astryx-layout__inner"; (if is_fill then "astryx-layout__inner--fill" else "astryx-layout__inner--auto") ]
    @ (match padding with Some p when is_zero p -> [ "astryx-layout__inner--full-bleed" ] | _ -> [])
  in
  let inner_attrs =
    Common.Attr.class_ inner_classes
    @ Common.Attr.style inner_pairs
    @ (match default_has_dividers with
      | Some b -> Common.Attr.data "default-dividers" (if b then "true" else "false")
      | None -> [])
  in
  let middle_classes =
    ([ "astryx-layout__middle" ]
    @ (if internal && not has_both then [ "astryx-layout__middle--query" ] else [])
    @ (if internal && has_single then [ "astryx-layout__middle--single-panel" ] else [])
    @ (if internal && has_start && not has_end then [ "astryx-layout__middle--start-gutter" ] else [])
    @ (if internal && not has_start && has_end then [ "astryx-layout__middle--end-gutter" ] else [])
    @ (match content_width with
      | Some _ when not internal || has_both -> [ "astryx-layout__middle--content-lane" ]
      | _ -> []))
  in
  let middle_style =
    match content_width with
    | Some cw when (not internal) || has_both ->
      [ ("width", "100%")
      ; ("max-width", Common.Size_value.to_css cw)
      ; ("margin-inline", "auto")
      ]
    | _ -> []
  in
  let column_classes =
    [ "astryx-layout__column" ]
    @ (if internal && not has_start && not has_end then [ "astryx-layout__column--single-column" ] else [])
  in
  let slot node = match node with Some n -> [ n ] | None -> [] in
  div
    (base_attrs ?id ~attrs "Layout" [ "astryx-layout"; (if is_fill then "astryx-layout--fill" else "astryx-layout--auto") ] []
     @ Common.Attr.data "height" (if is_fill then "fill" else "auto"))
    [ div inner_attrs
        ((match header with Some h -> [ h ] | None -> [])
        @ [ div
              (Common.Attr.class_ middle_classes @ Common.Attr.style middle_style)
              (slot start
              @ [ div (Common.Attr.class_ column_classes) resolved_content ]
              @ slot end_)
          ]
        @ (match footer with Some f -> [ f ] | None -> []))
    ]
;;
