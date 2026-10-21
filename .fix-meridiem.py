import re

p = "src/time_input.ml"
s = open(p).read()

old = """let meridiem_of s =
  let n = String.length s in
  let ends_with suffix =
    let m = String.length suffix in
    if n < m then false
    else String.equal (String.sub s ~pos:(n - m) ~len:m) suffix
  in
  if ends_with "pm" || ends_with "p.m." || ends_with "p.m" || ends_with "p." || ends_with "p"
  then Some `PM
  else if ends_with "am" || ends_with "a.m." || ends_with "a.m" || ends_with "a." || ends_with "a"
  then Some `AM
  else None
;;

(* Remove the meridiem suffix, along with the space before it. *)
let strip_meridiem s =
  let n = String.length s in
  let rec last_non_space i =
    if i < 0 then None
    else
      match s.[i] with
      | ' ' | '\\t' -> last_non_space (i - 1)
      | _ -> Some i
  in
  match last_non_space (n - 1) with
  | None -> s
  | Some i -> String.sub s ~pos:0 ~len:i |> String.strip
;;"""

new = '''(* Where the meridiem starts in a typed entry, if it has one. Upstream accepts
   "p", "pm", "p.m", "p.m." and the "a" spellings. The longest spelling the
   entry ends with is the meridiem, so "2:30 p.m." does not keep a stray "p."
   behind, and "2:30 p" does not keep a stray "p". *)
let meridiem_start s =
  let n = String.length s in
  let ends_with suffix =
    let m = String.length suffix in
    if n < m then false
    else String.equal (String.sub s ~pos:(n - m) ~len:m) suffix
  in
  let rec find = function
    | [] -> None
    | spelling :: rest ->
      if ends_with spelling then Some (n - String.length spelling) else find rest
  in
  find [ "p.m."; "a.m."; "p.m"; "a.m"; "pm"; "am"; "p."; "a."; "p"; "a" ]
;;

(* The meridiem a typed entry ends with. The detection is derived from the
   same match as the removal, so the two can never disagree — a dotted
   meridiem used to skip the twelve-to-twenty-four conversion and parse
   twelve hours off. *)
let meridiem_of s =
  match meridiem_start s with
  | None -> None
  | Some start ->
    let m = String.sub s ~pos:start ~len:(String.length s - start) in
    if String.equal m "a" || String.equal m "am" || String.equal m "a." || String.equal m "a.m"
       || String.equal m "a.m."
    then Some `AM
    else Some `PM
;;

(* Remove the meridiem suffix, along with the space before it. An entry with
   no meridiem is only trimmed: the earlier version cut the last character
   off every entry, so "14:30" was read as "14:3" and committed as 14:03. *)
let strip_meridiem s =
  match meridiem_start s with
  | None -> String.strip s
  | Some start -> String.sub s ~pos:0 ~len:start |> String.strip
;;'''

assert old in s, "MISS the old meridiem code"
s = s.replace(old, new, 1)
open(p, "w").write(s)
print("replaced the meridiem handling")
