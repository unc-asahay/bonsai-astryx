(* Numeric probe for Plain_date — runs under node (dune exec) to check the
   arithmetic against known values. Not part of the shipped library. *)

open Astryx

let p = Printf.sprintf "%04d-%02d-%02d"

let check name got want =
  let ok = String.equal got want in
  Printf.printf "%-46s got=%-14s want=%-14s %s\n" name got want (if ok then "ok" else "FAIL")

let () =
  (* ISO round trip *)
  let d = Plain_date.of_iso "2026-03-21" in
  check "of_iso/to_iso" (Plain_date.to_iso d) "2026-03-21";
  (* day of week: 2026-03-21 is a Saturday (6) *)
  check "day_of_week 2026-03-21" (string_of_int (Plain_date.day_of_week d)) "6";
  (* leap year rules *)
  check "days_in_month 2024-02" (string_of_int (Plain_date.days_in_month 2024 2)) "29";
  check "days_in_month 2026-02" (string_of_int (Plain_date.days_in_month 2026 2)) "28";
  check "days_in_month 1900-02" (string_of_int (Plain_date.days_in_month 1900 2)) "28";
  check "days_in_month 2000-02" (string_of_int (Plain_date.days_in_month 2000 2)) "29";
  (* add_months clamps the day *)
  let jan31 = Plain_date.create ~year:2026 ~month:1 ~day:31 in
  check "add_months Jan31 +1" (Plain_date.to_iso (Plain_date.add_months jan31 1)) "2026-02-28";
  let jan31_leap = Plain_date.create ~year:2024 ~month:1 ~day:31 in
  check "add_months Jan31 +1 (leap)" (Plain_date.to_iso (Plain_date.add_months jan31_leap 1)) "2024-02-29";
  check "add_months Jan31 -1" (Plain_date.to_iso (Plain_date.add_months jan31 (-1))) "2025-12-31";
  check "add_months Dec +1" (Plain_date.to_iso (Plain_date.add_months (Plain_date.create ~year:2026 ~month:12 ~day:15) 1)) "2027-01-15";
  (* add_days crosses a month and a year *)
  check "add_days 2026-12-31 +1" (Plain_date.to_iso (Plain_date.add_days (Plain_date.of_iso "2026-12-31") 1)) "2027-01-01";
  check "add_days 2026-01-01 -1" (Plain_date.to_iso (Plain_date.add_days (Plain_date.of_iso "2026-01-01") (-1))) "2025-12-31";
  check "add_days 2024-02-28 +1 (leap)" (Plain_date.to_iso (Plain_date.add_days (Plain_date.of_iso "2024-02-28") 1)) "2024-02-29";
  (* diff_days *)
  check "diff_days 2026-03-21 -> 2026-03-22" (string_of_int (Plain_date.diff_days (Plain_date.of_iso "2026-03-21") (Plain_date.of_iso "2026-03-22"))) "1";
  check "diff_days 2026-03-22 -> 2026-03-21" (string_of_int (Plain_date.diff_days (Plain_date.of_iso "2026-03-22") (Plain_date.of_iso "2026-03-21"))) "-1";
  check "diff_days across a year" (string_of_int (Plain_date.diff_days (Plain_date.of_iso "2025-12-31") (Plain_date.of_iso "2026-01-01"))) "1";
  check "diff_days 2024 leap span" (string_of_int (Plain_date.diff_days (Plain_date.of_iso "2024-02-28") (Plain_date.of_iso "2024-03-01"))) "2";
  (* comparisons *)
  check "is_before" (string_of_bool (Plain_date.is_before (Plain_date.of_iso "2026-01-01") (Plain_date.of_iso "2026-01-02"))) "true";
  check "is_in_range" (string_of_bool (Plain_date.is_in_range (Plain_date.of_iso "2026-01-02") ~first:(Plain_date.of_iso "2026-01-01") ~last:(Plain_date.of_iso "2026-01-31"))) "true";
  check "is_in_range outside" (string_of_bool (Plain_date.is_in_range (Plain_date.of_iso "2026-02-01") ~first:(Plain_date.of_iso "2026-01-01") ~last:(Plain_date.of_iso "2026-01-31"))) "false";
  (* week helpers: 2026-03-21 is a Saturday; week starting Sunday -> 2026-03-15 *)
  check "set_start_of_week (Sun)" (Plain_date.to_iso (Plain_date.set_start_of_week d ~week_starts_on:0)) "2026-03-15";
  check "set_start_of_week (Mon)" (Plain_date.to_iso (Plain_date.set_start_of_week d ~week_starts_on:1)) "2026-03-16";
  check "set_end_of_week_exclusive" (Plain_date.to_iso (Plain_date.set_end_of_week_exclusive d ~week_starts_on:0)) "2026-03-22";
  (* ISO week numbers: 2026-01-01 is a Thursday -> week 1; 2026-03-21 -> week 12 *)
  check "week_number 2026-01-01" (string_of_int (Plain_date.get_week_number (Plain_date.of_iso "2026-01-01"))) "1";
  check "week_number 2026-03-21" (string_of_int (Plain_date.get_week_number d)) "12";
  check "week_number 2027-01-01 (Friday, 2026-W53)" (string_of_int (Plain_date.get_week_number (Plain_date.of_iso "2027-01-01"))) "53";
  (* formatting through the host Intl *)
  check "format_long" (Plain_date.format_long d) "March 21, 2026";
  check "format_with_weekday" (Plain_date.format_with_weekday d) "Saturday, March 21, 2026";
  check "format_short_with_year" (Plain_date.format_short_with_year d) "Mar 21, 2026";
  check "format_month_year" (Plain_date.format_month_year d) "March 2026";
  check "format_shared System_date" (Plain_date.format_shared d `System_date) "2026-03-21";
  check "week_field_name" (Plain_date.week_field_name ()) "week";
  (* today is sane *)
  let t = Plain_date.today () in
  Printf.printf "today = %s (dow %d)\n" (Plain_date.to_iso t) (Plain_date.day_of_week t);
  ignore p
