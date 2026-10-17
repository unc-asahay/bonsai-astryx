open! Core

type t =
  | Link
  | Button
  | Inert

(* Step order is the specification. `is_disabled` excludes href at step 1 rather than downgrading a
   resolved link afterwards, so a disabled href falls through to the remaining steps - and with no
   onClick it lands on Inert, which is what makes a disabled link unfocusable rather than a link that
   silently does nothing. *)
let of_inputs ~href ~has_on_click ~is_disabled =
  if (not is_disabled) && Option.is_some href then Link
  else if has_on_click then Button
  else Inert
;;

let renders_as_button role ~href =
  match role with
  | Button -> true
  | Link -> false
  | Inert -> Option.is_none href
;;
