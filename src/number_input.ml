(* NumberInput — the draft-committing numeric field.

   Port of upstream NumberInput/NumberInput.tsx (+ numberParser.ts + numberInputCommit.ts).
   The text edit is held as a draft until an explicit commit boundary (blur or Enter):
   only valid drafts reach [on_change], an out-of-range draft clamps at [min]/[max],
   an empty draft clears (with [has_clear]) or reverts. Steppers, arrow keys and the
   wheel all step through [get_stepped_value] (upstream's exact integer/step/multiplier
   arithmetic), and the focused input shows the machine number in the locale's decimal
   separator so what the user sees mid-edit is what the parser reads back.

   Documented divergences (also in port.json):
   - [on_enter] / no [on_key_down] callback: upstream's onKeyDown hook is not exposed;
     the port keeps Enter and IME handling, a caller that needs raw keydown can rely on
     [attrs].
   - The invalid-number live region is a visually-hidden div carrying role=alert
     (Visually_hidden.view cannot take attrs).
   - No InputGroup context: upstream swaps in a VisuallyHidden label and hides the
     status box when rendered inside an InputGroup. Here a field is either inside an
     explicit [Input_group.view] or not; the caller passes [is_label_hidden] /
     no status. No status icon is rendered inside the wrapper (house Field renders the
     message box, as in TextInput).
   - Locale: optional [locale] (BCP 47). No locale means en-US symbols; grouping and
     digit-script support is provided by the host's Intl when [locale] is given.
   - The generated ids derive from [id] (id-desc/id-status/id-units/id-reason) rather
     than React useId, so markup is deterministic. *)

module Field_ = Field

open! Core
open! Bonsai_web
open Js_of_ocaml

module Attr = Common.Attr

type size = Input_types.size =
  | Sm
  | Md
  | Lg

type status_type = Input_types.status_type =
  | Warning
  | Error
  | Success

type status_variant = Field_status.placement =
  | Attached
  | Detached
  | Tooltip

type commit_decision =
  | Commit of float * bool (** value, did_clamp *)
  | Clear
  | Revert

let size_string = function
  | Sm -> "sm"
  | Md -> "md"
  | Lg -> "lg"
;;

let status_string = function
  | Warning -> "warning"
  | Error -> "error"
  | Success -> "success"
;;

let js_call (js : string) (args : Js.Unsafe.any array) : Js.Unsafe.any =
  Js.Unsafe.fun_call (Js.Unsafe.pure_js_expr js) args
;;

let js_call_str (js : string) (args : Js.Unsafe.any array) : string =
  Js.to_string (Js.Unsafe.coerce (js_call js args))
;;

let js_call_bool (js : string) (args : Js.Unsafe.any array) : bool =
  Js.to_bool (Js.Unsafe.coerce (js_call js args))
;;

let js_string (s : string) : Js.Unsafe.any = Js.Unsafe.inject (Js.string s)

(* ------------------------------------------------------------------ locale symbols *)

type symbols =
  { group : string
  ; decimal : string
  ; primary : int
  ; secondary : int
  }

let symbols_cache : (string, symbols) Hashtbl.t = Hashtbl.Poly.create ()

(* The host's Intl.NumberFormat describes the locale; a missing or broken Intl (or no
   locale) falls back to en-US: comma group, full-stop decimal, 3/3 group sizes. *)
let get_symbols (locale : string option) : symbols =
  let key = Option.value locale ~default:"" in
  match Hashtbl.Poly.find symbols_cache key with
  | Some symbols -> symbols
  | None ->
    let resolve =
      js_call
        "(function(locale){try{var f=new Intl.NumberFormat(locale||undefined);\
var g=f.formatToParts(12345.6);var d=f.formatToParts(11111111111);\
var ints=d.filter(function(p){return p.type==='integer';}).map(function(p){return p.value.length;});\
var has=ints.length>1;var grp=null,dec=null;for(var i=0;i<g.length;i++){if(g[i].type==='group')grp=g[i].value;if(g[i].type==='decimal')dec=g[i].value;}\
return {ok:1,group:(grp||',').normalize('NFKC'),decimal:(dec||'.').normalize('NFKC'),primary:String(has?ints[ints.length-1]:3),secondary:String(has?ints[ints.length-2]:3)};}\
catch(e){return {ok:0,group:'',decimal:'',primary:0,secondary:0};}})"
        [| js_string key |]
    in
    let symbols =
      if Js.to_bool (Js.Unsafe.get resolve "ok")
      then
        { group = Js.to_string (Js.Unsafe.get resolve "group")
        ; decimal = Js.to_string (Js.Unsafe.get resolve "decimal")
        ; primary = int_of_string (Js.to_string (Js.Unsafe.get resolve "primary"))
        ; secondary = int_of_string (Js.to_string (Js.Unsafe.get resolve "secondary"))
        }
      else { group = ","; decimal = "."; primary = 3; secondary = 3 }
    in
    Hashtbl.Poly.set symbols_cache ~key ~data:symbols;
    symbols
;;

(* NFKC-normalize, drop zero-width joiner / bidi / BOM invisibles, and map every Unicode
   decimal digit to its ASCII value (each digit script lays its digits out consecutively,
   so walking back to the script's zero derives the value without a table). *)
let normalize_digits (text : string) : string =
  js_call_str
    "(function(s){var t=s.normalize('NFKC').replace(/[\\u200B-\\u200D\\u200E\\u200F\\u061C\\u2066-\\u2069\\uFEFF]/g,'');\
return t.replace(/\\p{Nd}/gu,function(d){var cp=d.codePointAt(0);var z=cp;while(z>0&&/\\p{Nd}/u.test(String.fromCodePoint(z-1))){--z;}return String.fromCodePoint(48+(cp-z));});})"
    [| js_string text |]
;;

let is_currency_char (c : string) : bool =
  js_call_bool "(function(c){return /^\\p{Sc}$/u.test(c);})" [| js_string c |]
;;

(* ------------------------------------------------------- small string helpers (utf8) *)

let contains_sub (s : string) (sub : string) : bool =
  let n = String.length s and nl = String.length sub in
  if nl = 0 then true
  else (
    let rec go i = if i + nl > n then false else if String.equal (String.sub s ~pos:i ~len:nl) sub then true else go (i + 1) in
    go 0)
;;

let index_of_sub (s : string) (sub : string) : int option =
  let n = String.length s and nl = String.length sub in
  if nl = 0 then Some 0
  else (
    let rec go i = if i + nl > n then None else if String.equal (String.sub s ~pos:i ~len:nl) sub then Some i else go (i + 1) in
    go 0)
;;

let split_sub (s : string) (sub : string) : string list =
  let n = String.length s and nl = String.length sub in
  if nl = 0 then [ s ]
  else (
    let rec go acc i =
      if i > n then List.rev acc
      else (
        match index_of_sub (String.sub s ~pos:i ~len:(n - i)) sub with
        | None -> List.rev ((String.sub s ~pos:i ~len:(n - i)) :: acc)
        | Some j -> go ((String.sub s ~pos:i ~len:j) :: acc) (i + j + nl))
    in
    go [] 0)
;;

(* Every character a locale writes between digits: comma, full stop, apostrophe, space,
   U+2019 (Swiss), U+066B/U+066C (Arabic). Bounded on purpose — a repeated arbitrary
   character would otherwise read as grouping. *)
let is_number_body (core : string) : bool =
  let n = String.length core in
  let rec go i =
    if i >= n then true
    else
      let b = Char.to_int core.[i] in
      if b >= Char.to_int '0' && b <= Char.to_int '9'
      then go (i + 1)
      else if b = Char.to_int ',' || b = Char.to_int '.' || b = Char.to_int '\'' || b = Char.to_int ' '
      then go (i + 1)
      else if i + 3 <= n
      then
        let triple = String.sub core ~pos:i ~len:3 in
        if String.equal triple "\xe2\x80\x99" || String.equal triple "\xd9\xab" || String.equal triple "\xd9\xac"
        then go (i + 3)
        else false
      else false
  in
  go 0
;;

let all_digits (s : string) : bool =
  String.length s = 0
  ||
  let n = String.length s in
  let rec go i = i >= n || (Char.to_int s.[i] >= Char.to_int '0' && Char.to_int s.[i] <= Char.to_int '9' && go (i + 1)) in
  go 0
;;

let is_machine_number (core : string) : bool =
  (* /^(?:\d+\.?\d*|\.\d+)$/ *)
  if String.equal core "" then false
  else
    let n = String.length core in
    let first_digit = Char.to_int core.[0] >= Char.to_int '0' && Char.to_int core.[0] <= Char.to_int '9' in
    let last_digit = Char.to_int core.[n - 1] >= Char.to_int '0' && Char.to_int core.[n - 1] <= Char.to_int '9' in
    if first_digit then (
      let dots = ref 0 in
      for i = 0 to n - 1 do
        (match core.[i] with
         | '.' -> incr dots
         | c when Char.to_int c >= Char.to_int '0' && Char.to_int c <= Char.to_int '9' -> ()
         | _ -> dots := 2)
      done;
      !dots <= 1 && last_digit)
    else last_digit
;;

let is_group_only_separator (separator : string) : bool =
  (* /^[\s\u2019]$/ *)
  String.equal separator "\xe2\x80\x99"
  || String.equal separator " "
  || String.equal separator "\t"
  || String.equal separator "\n"
;;

(* ------------------------------------------------------------------ the parser *)

(* Reduce a digits-and-separators string to a plain machine number under one candidate
   reading, or None when it is not well formed under that reading. *)
let read_under
      ~(core : string)
      ~(group : string)
      ~(decimal : string)
      ~(primary : int)
      ~(secondary : int)
      ~(min_groups : int)
  : string option
  =
  let int_text, frac =
    if not (String.equal decimal "") && contains_sub core decimal
    then (
      match index_of_sub core decimal with
      | None -> core, None
      | Some at ->
        let col = String.length decimal in
        let rest = String.sub core ~pos:(at + col) ~len:(String.length core - at - col) in
        if contains_sub rest decimal
        then core, Some ""
        else (String.sub core ~pos:0 ~len:at, Some rest))
    else core, None
  in
  match frac with
  | Some f when not (all_digits f) -> None
  | _ ->
    let digits =
      if not (String.equal group "") && contains_sub int_text group
      then
        let chunks = split_sub int_text group in
        let n_chunks = List.length chunks in
        if n_chunks - 1 < min_groups
        then None
        else if not (List.for_all chunks ~f:all_digits)
        then None
        else (
          let first = List.hd_exn chunks and last = List.last_exn chunks in
          if String.length last <> primary || String.length first > secondary
          then None
          else begin
          let middle =
            match chunks with
            | [] -> []
            | _ :: rest ->
              (* drop the last chunk too: only the inner groups must be secondary-sized *)
              (match List.rev rest with
               | [] -> []
               | _ :: rev_mid -> List.rev rev_mid)
          in
          if not (List.for_all middle ~f:(fun c -> String.length c = secondary))
          then None
          else Some (String.concat ~sep:"" chunks)
          end)
      else if all_digits int_text
      then Some int_text
      else None
    in
    (match digits with
     | None -> None
     | Some d when String.is_empty d && (Option.is_none frac || String.equal (Option.value_exn frac) "") -> None
     | Some d ->
       (match frac with None -> Some d | Some f -> Some (d ^ "." ^ f)))
;;

let strip_currency (text : string) : string =
  let t = String.strip text in
  if String.length t = 0 then t
  else
    let first = String.sub t ~pos:0 ~len:1 in
    let t = if is_currency_char first then String.strip (String.sub t ~pos:1 ~len:(String.length t - 1)) else t in
    if String.equal t "" then t
    else
      let last = String.sub t ~pos:(String.length t - 1) ~len:1 in
      if is_currency_char last then String.strip (String.sub t ~pos:0 ~len:(String.length t - 1)) else t
;;

let minus_prefixes = [ "\xe2\x88\x92"; "\xe2\x80\x92"; "\xe2\x80\x93"; "-" ]

let is_minus_at (s : string) (i : int) : bool =
  List.exists minus_prefixes ~f:(fun p -> i + String.length p <= String.length s && String.equal (String.sub s ~pos:i ~len:(String.length p)) p)
;;

let minus_len_at (s : string) (i : int) : int =
  match List.find minus_prefixes ~f:(fun p -> i + String.length p <= String.length s && String.equal (String.sub s ~pos:i ~len:(String.length p)) p) with
  | Some p -> String.length p
  | None -> 0
;;

let minus_len_at_end (s : string) : int =
  let n = String.length s in
  match List.find minus_prefixes ~f:(fun p -> String.length p <= n && String.equal (String.sub s ~pos:(n - String.length p) ~len:(String.length p)) p) with
  | Some p -> String.length p
  | None -> 0
;;

let parse_exponent (text : string) : int * string =
  (* split trailing [eE][+-]?digits -> (exponent, prefix) *)
  let n = String.length text in
  let rec digit_start i = if i >= 0 && Char.to_int text.[i] >= Char.to_int '0' && Char.to_int text.[i] <= Char.to_int '9' then digit_start (i - 1) else i + 1 in
  let d_end = n in
  let d_start = digit_start (n - 1) in
  if d_start = n then 0, text
  else
    let s_start =
      if d_start > 0 && (Char.equal text.[d_start - 1] '+' || is_minus_at text (d_start - 1))
      then d_start - 1
      else if d_start >= 1 && is_minus_at text (d_start - 1) then d_start - 1
      else d_start
    in
    let e_pos = s_start - 1 in
    if e_pos >= 0 && (Char.equal text.[e_pos] 'e' || Char.equal text.[e_pos] 'E')
    then (int_of_string (String.sub text ~pos:s_start ~len:(d_end - s_start)), String.sub text ~pos:0 ~len:e_pos)
    else 0, text
;;

(* Decode a string into UTF-8 characters (byte length from the leading byte, which is
   never a continuation: this library's alphabet is BMP-only). *)
let iter_utf8_chars (s : string) (f : string -> unit) : unit =
  let n = String.length s in
  let rec go i =
    if i >= n then ()
    else
      let b = Char.to_int s.[i] in
      let len =
        if b < 0x80 then 1 else if b < 0xE0 then 2 else if b < 0xF0 then 3 else 4
      in
      let len = Int.min len (n - i) in
      f (String.sub s ~pos:i ~len:len);
      go (i + len)
  in
  go 0
;;

let uniq_chars (s : string) : string list =
  let seen = Hashtbl.Poly.create () in
  let out = ref [] in
  iter_utf8_chars s (fun c ->
      if not (Hashtbl.Poly.mem seen c)
      then (
        Hashtbl.Poly.set seen ~key:c ~data:();
        out := c :: !out));
  List.rev !out
;;

let to_plain_number (core : string) (locale : string option) : string option =
  if not (is_number_body core) then None
  else
    let { group; decimal; primary; secondary } = get_symbols locale in
    let in_locale = read_under ~core ~group ~decimal ~primary ~secondary ~min_groups:1 in
    match in_locale with
    | Some v -> Some v
    | None ->
      if is_machine_number core then Some core
      else (
        (* A repeated separator with three digits after each occurrence can only be
           grouping — a decimal point appears once. *)
        let separators =
          List.filter (uniq_chars core) ~f:(fun c ->
              let b = Char.to_int c.[0] in
              not ((b >= Char.to_int '0' && b <= Char.to_int '9') || Char.equal c.[0] ' '))
        in
        match separators with
        | [] | [ _; _; _ ] | _ :: _ :: _ :: _ :: _ -> None
        | [ a; b ] ->
          (* two separators: try each as grouping, other must appear exactly once *)
          let try_read candidate other =
            let n_cand = List.length (split_sub core candidate) - 1 in
            let min_g = if is_group_only_separator candidate then 1 else 2 in
            if n_cand < min_g then None
            else if not (String.equal other "") && List.length (split_sub core other) - 1 <> 1 then None
            else if is_number_body core
            then read_under ~core ~group:candidate ~decimal:other ~primary:3 ~secondary:3 ~min_groups:min_g
            else None
          in
          (match try_read a b with Some _ as r -> r | None -> try_read b a)
        | [ single ] ->
          let n_cand = List.length (split_sub core single) - 1 in
          let min_g = if is_group_only_separator single then 1 else 2 in
          if n_cand < min_g then None else read_under ~core ~group:single ~decimal:"" ~primary:3 ~secondary:3 ~min_groups:min_g)
;;

let parse_locale_number (text : string) (locale : string option) : float option =
  let normalized = normalize_digits text in
  let rest = ref (String.strip normalized) in
  let sgn = ref 1 in
  let accounting =
    String.length !rest >= 2
    && Char.equal !rest.[0] '('
    && Char.equal !rest.[String.length !rest - 1] ')'
  in
  if accounting then (
    sgn := -1;
    rest := String.strip (String.sub !rest ~pos:1 ~len:(String.length !rest - 2)));
  rest := strip_currency !rest;
  let has_written_sgn = ref false in
  if String.length !rest > 0 && (Char.equal !rest.[0] '+' || is_minus_at !rest 0)
  then (
    has_written_sgn := true;
    if Char.equal !rest.[0] '+'
    then begin
      rest := String.strip (String.sub !rest ~pos:1 ~len:(String.length !rest - 1))
    end
    else begin
      sgn := Int.neg !sgn;
      let len = minus_len_at !rest 0 in
      rest := String.strip (String.sub !rest ~pos:len ~len:(String.length !rest - len))
    end)
  else if String.length !rest > 0 && is_minus_at !rest (String.length !rest - 1)
  then (
    has_written_sgn := true;
    sgn := Int.neg !sgn;
    let len = minus_len_at_end !rest in
    rest := String.strip (String.sub !rest ~pos:0 ~len:(String.length !rest - len)))
  else if String.length !rest > 0 && Char.equal !rest.[String.length !rest - 1] '+'
  then (
    has_written_sgn := true;
    rest := String.strip (String.sub !rest ~pos:0 ~len:(String.length !rest - 1)));
  if accounting && !has_written_sgn then None
  else (
    rest := strip_currency !rest;
    let exponent, core0 = parse_exponent !rest in
    let core = String.strip core0 in
    if String.is_empty core then None
    else (
      match to_plain_number core locale with
      | None -> None
      | Some plain ->
        let magnitude = float_of_string plain in
        if not (Float.is_finite magnitude) then None
        else
          let scaled =
            if exponent = 0
            then magnitude
            else float_of_string (Printf.sprintf "%.15g" (magnitude *. (10. ** float_of_int exponent)))
          in
          if not (Float.is_finite scaled) then None
          else
            let result = float_of_int !sgn *. scaled in
            if Float.equal result 0. then Some 0. else Some result))
;;

let parse_numeric_input (input : string) ~is_integer_only ~(locale : string option) : float option =
  let trimmed = String.strip input in
  if String.is_empty trimmed then None
  else (
    match parse_locale_number trimmed locale with
    | None -> None
    | Some v when not (Float.is_finite v) -> None
    | Some v when is_integer_only && not (Float.is_integer v) -> None
    | Some v -> Some v)
;;

let parse_number_input (input : string) ~(min : float option) ~(max : float option) ~is_integer_only ~(locale : string option) : float option =
  match parse_numeric_input input ~is_integer_only ~locale with
  | None -> None
  | Some v ->
    (match min with
     | Some m when Float.(<) v m -> None
     | _ ->
       (match max with
        | Some m when Float.(>) v m -> None
        | _ -> Some v))
;;

let resolve_number_input_commit
      (input : string)
      ~(min : float option)
      ~(max : float option)
      ~is_integer_only
      ~(locale : string option)
      ~has_clear
  : commit_decision
  =
  if String.is_empty (String.strip input) then if has_clear then Clear else Revert
  else (
    match parse_numeric_input input ~is_integer_only ~locale with
    | None -> Revert
    | Some value ->
      let min' =
        match min with
        | None -> None
        | Some m -> if is_integer_only then Some (Float.round_up m) else Some m
      in
      let max' =
        match max with
        | None -> None
        | Some m -> if is_integer_only then Some (Float.round_down m) else Some m
      in
      (match min', max' with
       | Some lo, Some hi when Float.(>) lo hi -> Revert
       | _ ->
         let committed =
           match min', max' with
           | Some lo, Some _ when Float.(<) value lo -> lo
           | Some _, Some hi when Float.(>) value hi -> hi
           | Some lo, None when Float.(<) value lo -> lo
           | None, Some hi when Float.(>) value hi -> hi
           | _ -> value
         in
         Commit (committed, not (Float.equal committed value))))
;;

let format_editable_number (value : float) (locale : string option) : string =
  let { decimal; _ } = get_symbols locale in
  if String.equal decimal "." then Float.to_string value
  else String.concat ~sep:decimal (String.split (Float.to_string value) ~on:'.')
;;

(* ------------------------------------------------------------------- stepping *)

let get_decimal_places (value : float) : int =
  let s = String.lowercase (Float.to_string value) in
  let mantissa, exponent =
    match String.split ~on:'e' s with
    | [ m; e ] -> m, int_of_string e
    | [ m ] -> m, 0
    | _ -> s, 0
  in
  let fraction = match String.split ~on:'.' mantissa with [ _; f ] -> String.length f | _ -> 0 in
  Int.max 0 (fraction - exponent)
;;

let get_effective_step (step : float option) (is_integer_only : bool) : float =
  match step with
  | None -> 1.
  | Some s when not (Float.is_finite s) || Float.(<=) s 0. || (is_integer_only && not (Float.is_integer s)) -> 1.
  | Some s -> s
;;

let get_stepped_value
      ~(current_value : float option)
      ~(direction : int)
      ~(min : float option)
      ~(max : float option)
      ~(step : float option)
      ~is_integer_only
  : float option
  =
  let effective_step = get_effective_step step is_integer_only in
  let step_base =
    match min with
    | Some m when (not is_integer_only) || Float.is_integer m -> m
    | _ -> 0.
  in
  let next_value =
    match current_value with
    | None ->
      let v = if direction = 1 then Option.value min ~default:0. else Option.value max ~default:0. in
      if is_integer_only then if direction = 1 then Float.round_up v else Float.round_down v else v
    | Some cv ->
      let step_position = (cv -. step_base) /. effective_step in
      let tolerance = 2.220446049250313e-16 *. Float.max 1. (Float.abs step_position) *. 4. in
      let next_step_position =
        if direction = 1
        then Float.round_down (step_position +. tolerance) +. 1.
        else Float.round_up (step_position -. tolerance) -. 1.
      in
      step_base +. (next_step_position *. effective_step)
  in
  let precision =
    Int.min 12
      (Int.max (get_decimal_places effective_step) (get_decimal_places step_base))
  in
  let next_value = float_of_string (Printf.sprintf "%.*f" precision next_value) in
  let next_value =
    match min with Some m -> Float.max m next_value | None -> next_value
  in
  let next_value =
    match max with Some m -> Float.min m next_value | None -> next_value
  in
  if not (Float.is_finite next_value) then current_value
  else if is_integer_only && not (Float.is_integer next_value) then current_value
  else if Float.equal next_value 0. then Some 0. else Some next_value
;;

(* ------------------------------------------------------------------ component *)

let is_ime_key_event (ev : Dom_html.keyboardEvent Js.t) =
  Js.to_bool
    (Js.Unsafe.fun_call
       (Js.Unsafe.pure_js_expr
          "(function(ev){return ev.isComposing === true || ev.keyCode === 229;})")
       [| Js.Unsafe.inject ev |])
;;

let focus_input (id : string) () =
  match Js.Opt.to_option (Js.Unsafe.meth_call Dom_html.document "getElementById" [| js_string id |]) with
  | Some el -> Js.Unsafe.meth_call el "focus" [| |]
  | None -> ()
;;

let view
      ?(id = "astryx-number-input")
      ?(attrs = [])
      ~label
      ?(is_label_hidden = false)
      ?description
      ?(is_optional = false)
      ?(is_required = false)
      ?optionality
      ?(is_disabled = false)
      ?(is_read_only = false)
      ?disabled_message
      ?start_icon
      ?status
      ?(status_variant = Attached)
      ?(size = Md)
      ?width
      ?html_name
      ?auto_complete
      ?placeholder
      ?(label_tooltip : string = "")
      ?(min : float option = None)
      ?(max : float option = None)
      ?(step : float option = None)
      ?format_value
      ?(is_wheel_enabled = true)
      ?(has_number_steppers = false)
      ?units
      ?(is_integer_only = false)
      ?(has_clear = false)
      ?locale
      ?on_enter
      ~value
      ~on_change
      graph =
  let _ = label_tooltip in
  let shows_disabled_message = is_disabled && Option.is_some disabled_message in
  let required_and_not_optional = is_required && not is_optional in
  let description_id = id ^ "-desc" in
  let message_id = id ^ "-status" in
  let units_id = id ^ "-units" in
  let reason_id = id ^ "-reason" in
  let has_status_message =
    match status with
    | Some { Input_types.message = Some m; _ } -> not (String.is_empty m)
    | _ -> false
  in
  let status_is_error =
    match status with Some { Input_types.type_ = Error; _ } -> true | _ -> false
  in

  let pending, set_pending = Bonsai.state None graph in
  let focused, set_focused = Bonsai.state false graph in
  let vc = Bonsai.both value on_change in
  let pf = Bonsai.both pending focused in
  let sf = Bonsai.both set_pending set_focused in
  Bonsai.map3 vc pf sf
    ~f:(fun (value_now, on_change_fn) (pending_now, focused_now) (set_pending_fn, set_focused_fn) ->
      (* committed text used at rest; pending text while editing; the raw machine number
         while focused so it stays editable. *)
      let formatted_value =
        match value_now with
        | None -> ""
        | Some v -> (match format_value with Some f -> f v | None -> Printf.sprintf "%g" v)
      in
      let display_value =
        match pending_now with
        | Some text -> text
        | None ->
          (match value_now with
           | None -> ""
           | Some v -> if focused_now then format_editable_number v locale else formatted_value)
      in
      let is_input_valid =
        match pending_now with
        | None -> true
        | Some p -> String.is_empty (String.strip p) || Option.is_some (parse_number_input p ~min ~max ~is_integer_only ~locale)
      in
      let commit_pending (trigger : [ `Blur | `Enter ]) : unit Bonsai.Effect.t =
        match pending_now with
        | None -> Bonsai.Effect.Many []
        | Some p ->
          let decision =
            resolve_number_input_commit p ~min ~max ~is_integer_only ~locale ~has_clear
          in
          let clear_effect =
            if Poly.equal trigger `Blur || (match decision with Commit (_, clamp) -> clamp | _ -> false)
            then [ set_pending_fn None ]
            else []
          in
          let value_effect =
            match decision with
            | Clear -> if has_clear && Option.is_some value_now then [ on_change_fn None ] else []
            | Commit (v, _) ->
              if not (Option.exists value_now ~f:(fun cv -> Float.equal cv v)) then [ on_change_fn (Some v) ] else []
            | Revert -> []
          in
          Bonsai.Effect.Many (clear_effect @ value_effect)
      in
      let value_for_stepping =
        match pending_now with
        | None -> value_now
        | Some p ->
          if String.is_empty (String.strip p)
          then None
          else (match parse_number_input p ~min ~max ~is_integer_only ~locale with Some v -> Some v | None -> value_now)
      in
      let get_next_value direction =
        get_stepped_value ~current_value:value_for_stepping ~direction ~min ~max ~step ~is_integer_only
      in
      let step_value direction : unit Bonsai.Effect.t =
        if is_disabled || is_read_only then Bonsai.Effect.Many []
        else (
          match get_next_value direction with
          | None -> Bonsai.Effect.Many []
          | Some next ->
            let changed =
              match value_now with
              | Some cv when Float.equal cv next -> Bonsai.Effect.Many []
              | _ -> on_change_fn (Some next)
            in
            Bonsai.Effect.Many [ set_pending_fn None; changed ])
      in
      let on_keydown (ev : Dom_html.keyboardEvent Js.t) : unit Bonsai.Effect.t =
        if is_ime_key_event ev then Bonsai.Effect.Many []
        else
          let meta = Common.bool_prop (Obj.magic ev : _ Js.t) "metaKey" in
          let ctrl = Common.bool_prop (Obj.magic ev : _ Js.t) "ctrlKey" in
          let shift = Common.bool_prop (Obj.magic ev : _ Js.t) "shiftKey" in
          let alt = Common.bool_prop (Obj.magic ev : _ Js.t) "altKey" in
          let key = Option.value (Common.string_prop (Obj.magic ev : _ Js.t) "key") ~default:"" in
          if (not meta) && not ctrl && not shift && not alt && (String.equal key "ArrowUp" || String.equal key "ArrowDown")
          then
            Bonsai.Effect.Many
              [ Bonsai.Effect.of_thunk (fun () -> Common.prevent_default ev)
              ; step_value (if String.equal key "ArrowUp" then 1 else -1)
              ]
          else if String.equal key "Enter"
          then
            Bonsai.Effect.Many
              [ commit_pending `Enter
              ; (match on_enter with Some f -> f () | None -> Bonsai.Effect.Many [])
              ]
          else Bonsai.Effect.Many []
      in
      let on_wheel (ev : Dom_html.wheelEvent Js.t) : unit Bonsai.Effect.t =
        let delta_y : float = Js.Unsafe.get ev "deltaY" in
        let meta = Common.bool_prop (Obj.magic ev : _ Js.t) "metaKey" in
        let ctrl = Common.bool_prop (Obj.magic ev : _ Js.t) "ctrlKey" in
        let shift = Common.bool_prop (Obj.magic ev : _ Js.t) "shiftKey" in
        let alt = Common.bool_prop (Obj.magic ev : _ Js.t) "altKey" in
        if (not is_wheel_enabled)
           || is_disabled
           || is_read_only
           || Float.equal delta_y 0.
           || meta || ctrl || shift || alt
        then Bonsai.Effect.Many []
        else
          Bonsai.Effect.Many
            [ Bonsai.Effect.of_thunk (fun () -> Common.prevent_default ev)
            ; step_value (if Float.(<) delta_y 0. then 1 else -1)
            ]
      in
      let can_increment = Option.equal Float.equal (get_next_value 1) value_for_stepping |> not in
      let can_decrement = Option.equal Float.equal (get_next_value (-1)) value_for_stepping |> not in
      let described_by =
        List.filter_opt
          [ (if Option.is_some description then Some description_id else None)
          ; (if has_status_message && not (Poly.equal status_variant Tooltip) then Some message_id else None)
          ; (if Option.is_some units then Some units_id else None)
          ; (if shows_disabled_message then Some reason_id else None)
          ]
        |> String.concat ~sep:" "
      in
      let input_attrs =
        [ Vdom.Attr.create "id" id ]
        @ [ Vdom.Attr.create "type" "text" ]
        @ [ Vdom.Attr.create "inputmode" (if is_integer_only then "numeric" else "decimal") ]
        @ [ Vdom.Attr.create "role" "spinbutton" ]
        @ [ Vdom.Attr.create "value" display_value ]
        @ (match html_name with
           | Some name when (not is_disabled) && Option.is_none format_value -> [ Vdom.Attr.create "name" name ]
           | _ -> [])
        @ (match auto_complete with
           | Some text -> [ Vdom.Attr.create "autocomplete" text ]
           | None -> [])
        @ (match placeholder with
           | Some text -> [ Vdom.Attr.create "placeholder" text ]
           | None -> [])
        @ (if is_disabled && not shows_disabled_message then [ Vdom.Attr.create "disabled" "disabled" ] else [])
        @ (if is_read_only || shows_disabled_message then [ Vdom.Attr.create "readonly" "readonly" ] else [])
        @ (if shows_disabled_message then Attr.aria "disabled" "true" else [])
        @ (match min with Some m -> Attr.aria "valuemin" (Printf.sprintf "%g" m) | None -> [])
        @ (match max with Some m -> Attr.aria "valuemax" (Printf.sprintf "%g" m) | None -> [])
        @ (match value_now with Some v -> Attr.aria "valuenow" (Printf.sprintf "%g" v) | None -> [])
        @ (match value_now, format_value with
           | Some v, Some f -> Attr.aria "valuetext" (f v)
           | _ -> [])
        @ (if String.is_empty described_by then [] else [ Vdom.Attr.create "aria-describedby" described_by ])
        @ (if required_and_not_optional then Attr.aria "required" "true" else [])
        @ (if status_is_error || not is_input_valid then Attr.aria "invalid" "true" else [])
        @ [ Vdom.Attr.on_input (fun _ value -> if is_disabled || is_read_only then Bonsai.Effect.Many [] else set_pending_fn (Some value)) ]
        @ [ Vdom.Attr.on_focus (fun _ -> set_focused_fn true) ]
        @ [ Vdom.Attr.on_blur (fun _ -> Bonsai.Effect.Many [ commit_pending `Blur; set_focused_fn false ]) ]
        @ [ Vdom.Attr.on_keydown on_keydown ]
        @ [ Vdom.Attr.on_wheel on_wheel ]
        @ Attr.class_ [ "astryx-number-input__input" ]
      in
      let start_icon_nodes =
        match start_icon with
        | None -> []
        | Some name ->
          [ Vdom.Node.span ~attrs:(Attr.class_ [ "astryx-number-input__start-icon" ]) [ Icon.view ~name ~size:Icon.Sm ~color:Icon.Secondary () ] ]
      in
      let units_node =
        match units with
        | None -> []
        | Some text ->
          [ Vdom.Node.span ~attrs:(Attr.class_ [ "astryx-number-input__units" ] @ [ Vdom.Attr.id units_id ]) [ Vdom.Node.text text ] ]
      in
      let invalid_alert =
        if not is_input_valid
        then
          [ Vdom.Node.div
              ~attrs:
                (Attr.class_ [ "astryx-number-input__invalid-alert"; "astryx-visually-hidden" ]
                 @ Attr.role "alert"
                 @ [ Vdom.Attr.create "aria-live" "assertive" ])
              [ Vdom.Node.text "Invalid number" ]
          ]
        else []
      in
      let clear_button =
        if has_clear && Option.is_some value_now && not is_disabled && not is_read_only
        then
          [ Vdom.Node.button
              ~attrs:
                (Attr.class_ [ "astryx-number-input__clear" ]
                 @ Attr.aria "label" "Clear value"
                 @ [ Vdom.Attr.on_click (fun _ ->
                       Bonsai.Effect.Many
                         [ set_pending_fn None
                         ; on_change_fn None
                         ; Bonsai.Effect.of_thunk (fun () -> focus_input id ())
                         ]) ])
              [ Icon.view ~name:"close" ~size:Icon.Sm ~color:Icon.Secondary () ]
          ]
        else []
      in
      let stepper_button ~direction ~is_increment label =
        let can = if direction = 1 then can_increment else can_decrement in
        let disabled = is_disabled || is_read_only || not can in
        Vdom.Node.button
          ~attrs:
            (Attr.class_
               ([ "astryx-number-input__stepper" ]
                @ (if is_increment then [ "astryx-number-input__stepper--increment" ] else [ "astryx-number-input__stepper--decrement" ])
                @ if disabled then [ "astryx-number-input__stepper--disabled" ] else [])
             @ [ Vdom.Attr.create "tabindex" "-1" ]
             @ Attr.aria "label" label
             @ (if disabled then Attr.aria "disabled" "true" else [])
             @ [ Vdom.Attr.on_pointerdown (fun ev -> Bonsai.Effect.of_thunk (fun () -> Common.prevent_default ev)) ]
             @ [ Vdom.Attr.on_click (fun _ ->
                   Bonsai.Effect.Many [ Bonsai.Effect.of_thunk (fun () -> focus_input id ()); step_value direction ]) ])
          [ Icon.view ~name:"numberInput:stepperDown" ~size:Icon.Xsm ~color:Icon.Inherit () ]
      in
      let steppers =
        if has_number_steppers
        then
          [ Vdom.Node.div
              ~attrs:(Attr.class_ [ "astryx-number-input__steppers" ])
              [ stepper_button ~direction:1 ~is_increment:true "Increase value"
              ; stepper_button ~direction:(-1) ~is_increment:false "Decrease value"
              ]
          ]
        else []
      in
      let hidden_input =
        match html_name with
        | Some name when Option.is_some format_value && not is_disabled ->
          [ Vdom.Node.create
              "input"
              ~attrs:
                [ Vdom.Attr.create "type" "hidden"
                ; Vdom.Attr.create "name" name
                ; Vdom.Attr.create "value"
                    (match value_now with None -> "" | Some v -> Printf.sprintf "%g" v)
                ]
              []
          ]
        | _ -> []
      in
      let reason_nodes =
        if shows_disabled_message
        then
          [ Vdom.Node.div
              ~attrs:(Attr.class_ [ "astryx-number-input__disabled-reason" ] @ [ Vdom.Attr.id reason_id ])
              [ Vdom.Node.text (Option.value_exn disabled_message) ]
          ]
        else []
      in
      let wrapper_attrs =
        Attr.class_
          ([ "astryx-number-input" ; "astryx-number-input--" ^ size_string size ]
           @ (if is_disabled then [ "astryx-number-input--disabled" ] else [])
           @ (if is_read_only then [ "astryx-number-input--readonly" ] else [])
           @ (match status with
              | Some { Input_types.type_; _ } -> [ "astryx-number-input--" ^ status_string type_ ]
              | None -> []))
        @ Attr.data "component" "NumberInput"
        @ Attr.data "size" (size_string size)
        @ (match status with
           | Some { Input_types.type_; _ } -> Attr.data "status" (status_string type_)
           | None -> [])
        @ (if is_disabled then Attr.data "disabled" "true" else [])
        @ (if is_read_only then Attr.data "readonly" "true" else [])
        @ (if has_number_steppers then Attr.data "steppers" "true" else [])
        @ (if is_integer_only then Attr.data "integer" "true" else [])
        @ attrs
      in
      let wrapper =
        Vdom.Node.div ~attrs:wrapper_attrs
          (start_icon_nodes
           @ [ Vdom.Node.input ~attrs:input_attrs () ]
           @ hidden_input
           @ units_node
           @ invalid_alert
           @ clear_button
           @ steppers
           @ reason_nodes)
      in
      let required_nodes =
        if required_and_not_optional
        then [ Vdom.Node.span ~attrs:[ Vdom.Attr.class_ "astryx-visually-hidden"; Vdom.Attr.id (id ^ "-required") ] [ Vdom.Node.text "Required" ] ]
        else []
      in
      Field_.view
        ~label
        ~input_id:id
        ~is_label_hidden
        ?description
        ~is_optional
        ~is_required
        ?optionality
        ~is_disabled
        ?status
        ~status_variant
        ?width
        ~children:(wrapper :: required_nodes)
        ())
;;
