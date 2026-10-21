(* Numeric probe for TimeInput — runs under node (dune exec) to check the
   parser and the formatter against known values. Not part of the shipped
   library.

   The parser is the component's contract: upstream's timeParser, which
   accepts a typed entry with or without a meridiem, with or without a
   colon, and reads the hour onto the twenty-four hour clock. *)

open Astryx

let failures = ref 0

let check name got want =
  let ok = String.equal got want in
  if not ok then incr failures;
  Printf.printf "%-46s got=%-14s want=%-14s %s\n" name got want (if ok then "ok" else "FAIL")

let iso_of parsed =
  match parsed with
  | None -> "None"
  | Some t -> Time_input.to_iso t

let check_parse name text want =
  check name (iso_of (Time_input.parse_time_input text)) want

let time text =
  match Time_input.of_iso text with
  | Some t -> t
  | None -> failwith ("of_iso " ^ text ^ " returned None")

let () =
  (* A plain twenty-four hour entry, with and without a colon. *)
  check_parse "parse 14:30" "14:30" "14:30";
  check_parse "parse 1430" "1430" "14:30";
  check_parse "parse 9:15" "9:15" "09:15";
  check_parse "parse 09:15" "09:15" "09:15";
  check_parse "parse 23:59" "23:59" "23:59";
  (* Seconds, packed and not. *)
  check_parse "parse 14:30:45" "14:30:45" "14:30";
  check_parse "parse 143000 (no seconds wanted)" "143000" "14:30";
  check
    "parse 14:30:45 (seconds wanted)"
    (match Time_input.parse_time_input ~include_seconds:true "14:30:45" with
     | None -> "None"
     | Some t -> Time_input.to_iso ~include_seconds:true t)
    "14:30:45";
  (* A meridiem, in the spellings upstream accepts. *)
  check_parse "parse 2:30 PM" "2:30 PM" "14:30";
  check_parse "parse 2:30pm" "2:30pm" "14:30";
  check_parse "parse 2:30 p.m." "2:30 p.m." "14:30";
  check_parse "parse 2:30 p.m" "2:30 p.m" "14:30";
  check_parse "parse 9:15 AM" "9:15 AM" "09:15";
  check_parse "parse 12:00 AM" "12:00 AM" "00:00";
  check_parse "parse 12:00 PM" "12:00 PM" "12:00";
  check_parse "parse 12:30 AM" "12:30 AM" "00:30";
  check_parse "parse 2 PM (2 in the afternoon)" "2 PM" "14:00";
  check_parse "parse 2pm" "2pm" "14:00";
  (* What cannot be read. *)
  check_parse "parse 25:00" "25:00" "None";
  check_parse "parse 12:60" "12:60" "None";
  check_parse "parse 13:00 PM" "13:00 PM" "None";
  check_parse "parse empty" "" "None";
  check_parse "parse nonsense" "half past two" "None";
  (* The formatter. *)
  let two_thirty = time "14:30" in
  check
    "format 12h 14:30"
    (Time_input.format_display_time Time_input.H12 two_thirty)
    "2:30 PM";
  check
    "format 12h 00:30"
    (Time_input.format_display_time Time_input.H12 (time "00:30"))
    "12:30 AM";
  check
    "format 12h 12:00"
    (Time_input.format_display_time Time_input.H12 (time "12:00"))
    "12:00 PM";
  check
    "format 24h 14:30"
    (Time_input.format_display_time Time_input.H24 two_thirty)
    "14:30";
  (* Stepping. *)
  check
    "adjust 14:30 +60"
    (Time_input.to_iso (Time_input.adjust_time two_thirty ~delta_minutes:60))
    "15:30";
  check
    "adjust 23:30 +60 (wraps midnight)"
    (Time_input.to_iso (Time_input.adjust_time (time "23:30") ~delta_minutes:60))
    "00:30";
  check
    "adjust 00:30 -60 (wraps back)"
    (Time_input.to_iso (Time_input.adjust_time (time "00:30") ~delta_minutes:(-60)))
    "23:30";
  (* The range check. *)
  check
    "in range 12:00"
    (string_of_bool
       (Time_input.is_time_in_range (time "12:00")
          ~min:(Some (time "09:00"))
          ~max:(Some (time "17:00"))))
    "true";
  check
    "out of range 08:00"
    (string_of_bool
       (Time_input.is_time_in_range (time "08:00")
          ~min:(Some (time "09:00"))
          ~max:(Some (time "17:00"))))
    "false";
  check
    "in range, no bounds"
    (string_of_bool
       (Time_input.is_time_in_range (time "03:00") ~min:None ~max:None))
    "true";
  if !failures > 0 then begin
    Printf.printf "\n%d check(s) FAILED\n" !failures;
    exit 1
  end;
  print_endline "\nall time input checks passed"
