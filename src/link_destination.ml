open! Core

type component =
  | Anchor
  | Custom
;;

type handoff =
  | Rejected
  | Native of string option
  | Routed of
      { href : string option
      ; to_ : string option
      }

(* An absent destination is SAFE, which is the rule that would invert silently: upstream returns true for
   null and undefined, and a native Link passes no `to`. If this returned false, every plain link in the
   library would render with its destination dropped - no error, no warning, a link that looks like a link
   and goes nowhere. *)
let is_safe_destination destination =
  match destination with
  | None -> true
  | Some url -> Citation.is_safe_url url
;;

(* Upstream's order, and the order matters: the rejection is checked FIRST, so a custom component with one
   unsafe prop is rejected rather than routed, and the native branch below is only reached when both are
   safe. The `href` in the Rejected branch is deliberately not carried: upstream renders `createElement('a',
   { ref, ...rest })` - the destination is gone, including a good one. *)
let resolve ~component ~href ~to_ =
  if not (is_safe_destination href && is_safe_destination to_) then Rejected
  else (
    match component with
    | Anchor -> Native href
    (* upstream: createElement(Component, { href, to: to ?? href }) - so `to` defaults to `href`, and a
       custom component that was given only an href is still handed both. *)
    | Custom -> Routed { href; to_ = Option.first_some to_ href })
;;

