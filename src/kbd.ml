open! Core
open! Bonsai_web
open Js_of_ocaml

module Attr = Common.Attr

(* Aliases, applied before anything else reads the key, so that "esc" and "return" reach the maps below
   as the names they are aliases for. *)
let key_aliases = [ "esc", "escape"; "return", "enter" ]

let split_keys keys =
  List.map (String.split keys ~on:'+') ~f:(fun part ->
    let part = String.lowercase (String.strip part) in
    Option.value (List.Assoc.find key_aliases part ~equal:String.equal) ~default:part)
;;

(* What the eye sees, and what a screen reader says. They are deliberately different: the glyphs are
   meaningless when announced, so the accessible name is built from words. `mod` appears in neither map
   — it is the one key whose name depends on the platform, so it is resolved rather than looked up. *)
let display_map =
  [ "ctrl", "⌃"
  ; "alt", "⌥"
  ; "shift", "⇧"
  ; "enter", "↵"
  ; "backspace", "⌫"
  ; "escape", "Esc"
  ; "tab", "⇥"
  ; "up", "↑"
  ; "down", "↓"
  ; "left", "←"
  ; "right", "→"
  ; "plus", "+"
  ]
;;

let label_map =
  [ "ctrl", "Control"
  ; "alt", "Alt"
  ; "shift", "Shift"
  ; "enter", "Enter"
  ; "backspace", "Backspace"
  ; "escape", "Escape"
  ; "tab", "Tab"
  ; "up", "Up arrow"
  ; "down", "Down arrow"
  ; "left", "Left arrow"
  ; "right", "Right arrow"
  ; "plus", "Plus"
  ]
;;

let key_display ~is_mac key =
  if String.equal key "mod"
  then (if is_mac then "⌘" else "Ctrl")
  else
    Option.value
      (List.Assoc.find display_map key ~equal:String.equal)
      ~default:(String.uppercase key)
;;

let key_label ~is_mac key =
  if String.equal key "mod"
  then (if is_mac then "Command" else "Control")
  else
    Option.value
      (List.Assoc.find label_map key ~equal:String.equal)
      ~default:(String.uppercase key)
;;

(* Upstream's detection, in upstream's order. The subtlety worth keeping: a client-hints platform of
   "" or "Unknown" is *no answer*, not a negative answer, so it falls through to the legacy check
   instead of concluding "not Apple". The client-hints test is case-insensitive; the legacy one is
   case-sensitive, as written upstream. *)
let is_apple_platform () =
  let nav = Js.Unsafe.pure_js_expr "navigator" in
  let named =
    match Js.Opt.to_option (Js.Unsafe.get nav "userAgentData" : _ Js.opt) with
    | None -> ""
    | Some ua_data ->
      Option.value_map (Common.string_prop ua_data "platform") ~default:"" ~f:String.strip
  in
  if (not (String.is_empty named)) && not (String.equal (String.lowercase named) "unknown")
  then String.is_substring (String.lowercase named) ~substring:"mac"
  else begin
    let legacy = Option.value (Common.string_prop nav "platform") ~default:"" in
    List.exists [ "Mac"; "iPhone"; "iPad"; "iPod" ] ~f:(fun name ->
      String.is_substring legacy ~substring:name)
  end
;;

let view ~keys ?(attrs = []) () =
  let is_mac = is_apple_platform () in
  let parts = split_keys keys in
  (* The name assistive technology gets: words, joined, for the whole shortcut — the caps themselves
     are hidden below, because "⌘" and "⇧" are announced as nothing useful. *)
  let accessible_name = String.concat ~sep:" + " (List.map parts ~f:(key_label ~is_mac)) in
  let cap key =
    Vdom.Node.create
      "kbd"
      ~attrs:(Attr.class_ [ "astryx-kbd__key" ] @ Attr.aria "hidden" "true")
      [ Vdom.Node.text (key_display ~is_mac key) ]
  in
  Vdom.Node.span
    ~attrs:
      (Attr.class_ [ "astryx-kbd" ]
       @ Attr.data "component" "Kbd"
       @ Attr.role "img"
       @ Attr.aria "label" accessible_name
       @ attrs)
    (List.map parts ~f:cap)
;;
