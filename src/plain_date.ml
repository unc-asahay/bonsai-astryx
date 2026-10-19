(* Plain_date — immutable calendar-date arithmetic.

   Port of upstream astryx utils/plainDate.ts (+ dateTypes.ts): the pure date
   foundation shared by Calendar, the Date fields and the month/week pickers.

   Model: an immutable { year; month; day } record, Gregorian only (upstream
   is Gregorian today). Arithmetic is pure; day counts run in UTC so DST
   shifts never add or drop a day. Host Date objects are reached through
   one evaluated helper, so years 0-99 stay as written (Date#setFullYear
   semantics), never reinterpreted as 1900-1999. *)

open! Core
open Js_of_ocaml

type t = { year : int; month : int; day : int }

(* The port's one host dependency: Date construction and Intl formatting,
   evaluated on the host (the same shape timestamp.ml uses). The date
   constructor keeps years 0-99 as written; the UTC one is used for day
   counts so DST never adds or drops a day. *)
let host_js : Js.Unsafe.any =
  Js.Unsafe.pure_js_expr
    "(function(){\n\
    function date(y,m,d){var x=new Date(0,0,1);x.setFullYear(y,m-1,d);return x;}\n\
    function utc(y,moi,d){var x=new Date(0);x.setUTCFullYear(y,moi,d);x.setUTCHours(0,0,0);return x.getTime();}\n\
    function fmt(loc,y,m,d,o){try{return new Intl.DateTimeFormat(loc||'en',JSON.parse(o)).format(new Date(y,m-1,d));}catch(e){return '';}}\n\
    function weekField(l){try{var n=new Intl.DisplayNames(l||'en',{type:'dateTimeField'}).of('weekOfYear');if(n&&n!=='')return n;}catch(e){}return 'week';}\n\
    function now(){var x=new Date();return {y:x.getFullYear(),m:x.getMonth()+1,d:x.getDate()};}\n\
    return {date:date,utc:utc,fmt:fmt,weekField:weekField,now:now};\n\
    })()"

let call name (args : Js.Unsafe.any list) : Js.Unsafe.any =
  Js.Unsafe.fun_call (Js.Unsafe.get host_js name) (Array.of_list args)

(* House numeric/string casts: the js_of_ocaml version in use has no
   [Js.Unsafe.to_*]; go through [Js.to_float]/[Js.to_string] like
   timestamp.ml. *)
let to_float (x : 'a) : float = Js.to_float (Js.Unsafe.coerce x)
let to_int (x : 'a) : int = to_float x |> int_of_float
let to_string (x : 'a) : string = Js.to_string (Js.Unsafe.coerce x)

let days_in_month (year : int) (month : int) : int =
  if month = 2 then
    let is_leap = (year mod 4 = 0 && year mod 100 <> 0) || year mod 400 = 0 in
    if is_leap then 29 else 28
  else
    match month with
    | 1 | 3 | 5 | 7 | 8 | 10 | 12 -> 31
    | 4 | 6 | 9 | 11 -> 30
    | _ -> 0

let create ~(year : int) ~(month : int) ~(day : int) : t =
  if year < 1 then
    invalid_arg (Printf.sprintf "Plain_date.create: year must be >= 1, got %d" year);
  if month < 1 || month > 12 then
    invalid_arg (Printf.sprintf "Plain_date.create: month must be 1-12, got %d" month);
  let max_day = days_in_month year month in
  if day < 1 || day > max_day then
    invalid_arg
      (Printf.sprintf "Plain_date.create: day must be 1-%d for %d-%02d, got %d"
         max_day year month day);
  { year; month; day }

let of_iso (str : string) : t =
  if String.length str <> 10 || (not (Char.equal (String.get str 4) '-')) || (not (Char.equal (String.get str 7) '-')) then
    invalid_arg (Printf.sprintf "Plain_date.of_iso: malformed %S" str);
  create
    ~year:(int_of_string (String.sub str ~pos:0 ~len:4))
    ~month:(int_of_string (String.sub str ~pos:5 ~len:2))
    ~day:(int_of_string (String.sub str ~pos:8 ~len:2))

let to_iso (pd : t) : string = Printf.sprintf "%04d-%02d-%02d" pd.year pd.month pd.day

let js_date (pd : t) : Js.Unsafe.any =
  call "date" [ Js.Unsafe.inject pd.year; Js.Unsafe.inject pd.month; Js.Unsafe.inject pd.day ]

let from_date (d : Js.Unsafe.any) : t =
  { year = Js.Unsafe.meth_call d "getFullYear" [||] |> to_int
  ; month = (Js.Unsafe.meth_call d "getMonth" [||] |> to_int) + 1
  ; day = Js.Unsafe.meth_call d "getDate" [||] |> to_int }

let today () : t =
  let o = call "now" [] in
  create
    ~year:(Js.Unsafe.get o "y" |> to_int)
    ~month:(Js.Unsafe.get o "m" |> to_int)
    ~day:(Js.Unsafe.get o "d" |> to_int)

let day_of_week (pd : t) : int = Js.Unsafe.meth_call (js_date pd) "getDay" [||] |> to_int

let add_months (pd : t) (n : int) : t =
  (* Pure month arithmetic with day clamping (Temporal.PlainDate.add
     semantics): Jan 31 + 1 month is Feb 28/29, never Mar 2/3. *)
  let total = (pd.year * 12) + (pd.month - 1) + n in
  (* Floor division, so a month count that runs below zero still lands in the
     right year (OCaml's / truncates toward zero). *)
  let year =
    let q = total / 12 in
    if total mod 12 < 0 then q - 1 else q
  in
  let month = (total - (year * 12)) + 1 in
  create ~year ~month ~day:(min pd.day (days_in_month year month))

let add_days (pd : t) (n : int) : t =
  let d = js_date pd in
  let cur = Js.Unsafe.meth_call d "getDate" [||] |> to_int in
  Js.Unsafe.meth_call d "setDate" [| Js.Unsafe.inject (cur + n) |] |> ignore;
  from_date d

let diff_days (a : t) (b : t) : int =
  (* Whole calendar days, UTC midnight; positive when [b] is after [a]. *)
  let utc pd =
    call "utc" [ Js.Unsafe.inject pd.year; Js.Unsafe.inject (pd.month - 1); Js.Unsafe.inject pd.day ]
    |> to_int
  in
  let ms_per_day = 24 * 60 * 60 * 1000 in
  (utc b - utc a) / ms_per_day

let compare (a : t) (b : t) : int =
  if a.year <> b.year then a.year - b.year
  else if a.month <> b.month then a.month - b.month
  else a.day - b.day

let is_before (a : t) (b : t) : bool = compare a b < 0
let is_after (a : t) (b : t) : bool = compare a b > 0
let is_equal (a : t) (b : t) : bool = compare a b = 0
let max (a : t) (b : t) : t = if compare a b >= 0 then a else b
let min (a : t) (b : t) : t = if compare a b <= 0 then a else b
let is_in_range (pd : t) ~(first : t) ~(last : t) : bool =
  compare pd first >= 0 && compare pd last <= 0
let set_first_of_month (pd : t) : t = { pd with day = 1 }

let set_start_of_week (pd : t) ~(week_starts_on : int) : t =
  let delta = (day_of_week pd - week_starts_on + 7) mod 7 in
  add_days pd (-delta)

let set_end_of_week_exclusive (pd : t) ~(week_starts_on : int) : t =
  add_days (set_start_of_week pd ~week_starts_on) 7

let get_week_number (pd : t) : int =
  let d = js_date pd in
  let day_num = Js.Unsafe.meth_call d "getDay" [||] |> to_int in
  let day_num = if day_num = 0 then 7 else day_num in
  let cur = Js.Unsafe.meth_call d "getDate" [||] |> to_int in
  Js.Unsafe.meth_call d "setDate" [| Js.Unsafe.inject (cur + (4 - day_num)) |] |> ignore;
  let y = Js.Unsafe.meth_call d "getFullYear" [||] |> to_int in
  let year_start = js_date { year = y; month = 1; day = 1 } in
  let ms =
    (Js.Unsafe.meth_call d "getTime" [||] |> to_float)
    -. (Js.Unsafe.meth_call year_start "getTime" [||] |> to_float)
  in
  int_of_float (Float.round_up ((ms /. 86400000.0 +. 1.0) /. 7.0))

(* ------------------------------------------------------------------ *)
(* Display formatting — host Intl, delegated like timestamp.ml. *)
(* ------------------------------------------------------------------ *)

let format ?(locale = "en") (pd : t) (options : string) : string =
  call "fmt"
    [ Js.Unsafe.inject locale; Js.Unsafe.inject pd.year; Js.Unsafe.inject pd.month
    ; Js.Unsafe.inject pd.day; Js.Unsafe.inject options ]
  |> to_string

let format_with_weekday ?locale pd =
  format ?locale pd "{\"weekday\":\"long\",\"year\":\"numeric\",\"month\":\"long\",\"day\":\"numeric\"}"

let format_short_with_weekday ?locale pd =
  format ?locale pd
    "{\"weekday\":\"short\",\"month\":\"short\",\"day\":\"numeric\",\"year\":\"numeric\"}"

let format_long ?locale pd =
  format ?locale pd "{\"year\":\"numeric\",\"month\":\"long\",\"day\":\"numeric\"}"

let format_month_year ?locale pd = format ?locale pd "{\"year\":\"numeric\",\"month\":\"long\"}"

let format_weekday_only ?locale pd = format ?locale pd "{\"weekday\":\"short\"}"

let format_month_only ?locale pd = format ?locale pd "{\"month\":\"long\"}"

let format_short ?locale pd = format ?locale pd "{\"month\":\"short\",\"day\":\"numeric\"}"

let format_short_with_year ?locale pd =
  format ?locale pd "{\"month\":\"short\",\"day\":\"numeric\",\"year\":\"numeric\"}"

let week_field_name ?(locale = "en") () : string =
  call "weekField" [ Js.Unsafe.inject locale ] |> to_string

(* Shared date-format vocabulary (DateInput + Timestamp). *)
type shared_format = [ `Date | `Date_long | `Date_weekday | `System_date ]

let format_shared ?(locale = "en") (pd : t) (fmt : shared_format) : string =
  match fmt with
  | `System_date -> to_iso pd
  | `Date -> format ~locale pd "{\"month\":\"short\",\"day\":\"numeric\",\"year\":\"numeric\"}"
  | `Date_long -> format ~locale pd "{\"year\":\"numeric\",\"month\":\"long\",\"day\":\"numeric\"}"
  | `Date_weekday ->
      format ~locale pd
        "{\"weekday\":\"short\",\"month\":\"short\",\"day\":\"numeric\",\"year\":\"numeric\"}"
