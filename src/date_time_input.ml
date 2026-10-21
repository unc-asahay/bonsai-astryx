(* DateTimeInput — a date and a time in one field.

   Port of upstream's [packages/core/src/DateTimeInput]. The behaviour contract
   is upstream's own: [DateTimeInput.spec.md] (intent, ARIA, FR1–FR5) and
   [DateTimeInput.test.tsx] (case by case).

   {2 What the port is}

   One field, one label, two segments: a date segment (a text field and a
   calendar button that opens the month grid in a popover) and a time segment
   (a text field that takes typed time, and arrow-key stepping). The two
   halves make one value — a date and a time of day — so the field is
   committed as a unit: a datetime exists only once both halves do.

   The date half speaks the house's date type ([Astryx.Plain_date.t]) and the
   time half a house-local [time] record, so the value this component carries
   is a [date_time] — not upstream's ISO string. [Date_time.of_iso] and
   [Date_time.to_iso] convert at the boundary, exactly as
   [Plain_date.of_iso] / [Plain_date.to_iso] do for a plain date.

   The [Divergences] section of [date_time_input.mli] records where this
   differs from upstream; the ones that shape the code here are: no timezone
   (a [date_time] is a wall-clock reading, and the house has no zone
   infrastructure), no native or touch surfaces (the props do not exist
   rather than being ignored), and no preset-time dropdown (the time field is
   the typed field upstream's own pointer surface uses). *)

module Field_ = Field
module Calendar_ = Calendar

open! Core
open! Bonsai_web
open! Js_of_ocaml

(* ------------------------------------------------------------------ types *)

type time =
  { hour : int  (** 0-23 *)
  ; minute : int  (** 0-59 *)
  ; second : int  (** 0-59 *)
  }

type date_time =
  { date : Plain_date.t
  ; time : time
  }

type hour_format =
  | H12
  | H24

type time_increment =
  | Minute_1
  | Minute_5
  | Minute_10
  | Minute_15
  | Minute_30

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

(* ------------------------------------------------------------------- time *)

let pad2 n = if n < 10 then "0" ^ string_of_int n else string_of_int n

(* [String.split] from Base drops the empty pieces, which would silently turn
   "12::30" into a two-field time. This keeps every field. *)
let split_char (c : char) (s : string) : string list =
  let n = String.length s in
  let rec go pos acc =
    match String.index_from s pos c with
    | None -> List.rev (String.sub s ~pos ~len:(n - pos) :: acc)
    | Some i -> go (i + 1) (String.sub s ~pos ~len:(i - pos) :: acc)
  in
  go 0 []

let format_time_24h ~has_seconds (t : time) : string =
  if has_seconds
  then Printf.sprintf "%s:%s:%s" (pad2 t.hour) (pad2 t.minute) (pad2 t.second)
  else Printf.sprintf "%s:%s" (pad2 t.hour) (pad2 t.minute)

let format_time_12h ~has_seconds (t : time) : string =
  let hour12 = if t.hour = 0 then 12 else if t.hour > 12 then t.hour - 12 else t.hour in
  let meridiem = if t.hour < 12 then "AM" else "PM" in
  if has_seconds
  then Printf.sprintf "%d:%s:%s %s" hour12 (pad2 t.minute) (pad2 t.second) meridiem
  else Printf.sprintf "%d:%s %s" hour12 (pad2 t.minute) meridiem

let compare_time (a : time) (b : time) : int =
  Int.compare
    (((a.hour * 60) + a.minute) * 60 + a.second)
    (((b.hour * 60) + b.minute) * 60 + b.second)

let adjust_time (t : time) (delta_minutes : int) : time =
  (* The double modulo is upstream's: it wraps in both directions in O(1). *)
  let total = (((t.hour * 60) + t.minute + delta_minutes) mod (24 * 60) + (24 * 60)) mod (24 * 60) in
  { t with hour = total / 60; minute = total mod 60 }

let increment_minutes (increment : time_increment) : int =
  match increment with
  | Minute_1 -> 1
  | Minute_5 -> 5
  | Minute_10 -> 10
  | Minute_15 -> 15
  | Minute_30 -> 30

let parse_iso_time (s : string) : time option =
  let valid hour minute second =
    hour >= 0 && hour <= 23 && minute >= 0 && minute <= 59 && second >= 0 && second <= 59
  in
  match split_char ':' s with
  | [ h; m ] ->
    (match (Int.of_string_opt h, Int.of_string_opt m) with
     | Some hour, Some minute when valid hour minute 0 -> Some { hour; minute; second = 0 }
     | _ -> None)
  | [ h; m; sec ] ->
    (match (Int.of_string_opt h, Int.of_string_opt m, Int.of_string_opt sec) with
     | Some hour, Some minute, Some second when valid hour minute second -> Some { hour; minute; second }
     | _ -> None)
  | _ -> None

type meridiem =
  | No_meridiem
  | Am
  | Pm

(* Upstream's meridiem detection ([/p\.?m?\.?\s*$/i] and its AM twin) accepts
   "2pm", "2 p.m." and even a bare "2p"; the detection and the removal are
   derived from one another so a dotted meridiem cannot skip the 12h-to-24h
   conversion — which is the bug upstream's comment describes. *)
let strip_meridiem (s : string) : string * meridiem =
  let n = String.length s in
  if n = 0 then (s, No_meridiem)
  else
    let body len meridiem = (String.strip (String.sub s ~pos:0 ~len:len), meridiem) in
    match s.[n - 1] with
    | 'm' when n >= 2 && (Char.equal s.[n - 2] 'p' || Char.equal s.[n - 2] 'a') ->
      body (n - 2) (if Char.equal s.[n - 2] 'p' then Pm else Am)
    | 'm' when n >= 3 && Char.equal s.[n - 2] '.' && (Char.equal s.[n - 3] 'p' || Char.equal s.[n - 3] 'a') ->
      body (n - 3) (if Char.equal s.[n - 3] 'p' then Pm else Am)
    | ('p' | 'a') -> body (n - 1) (if Char.equal s.[n - 1] 'p' then Pm else Am)
    | _ -> (s, No_meridiem)

(* Upstream's parseTimeInput: "2:30 PM", "2:30pm", "14:30", "1430", "2pm",
   "143000". The seconds are parsed but not required. *)
let parse_time_input (input : string) : time option =
  let lowered = String.lowercase (String.strip input) in
  if String.is_empty lowered then None
  else
    let lowered =
      let n = String.length lowered in
      if n > 0 && Char.equal lowered.[n - 1] '.' then String.strip (String.sub lowered ~pos:0 ~len:(n - 1)) else lowered
    in
    let body, meridiem = strip_meridiem lowered in
    let body = String.strip body in
    let to_24 hour =
      match meridiem with
      | No_meridiem -> if hour >= 0 && hour <= 23 then Some hour else None
      | Am | Pm ->
        if hour < 1 || hour > 12 then None
        else if Poly.equal meridiem Pm && not (Int.equal hour 12) then Some (hour + 12)
        else if Poly.equal meridiem Am && Int.equal hour 12 then Some 0
        else Some hour
    in
    let is_digits s =
      String.length s > 0
      &&
      let ok = ref true in
      String.iter ~f:(fun c -> if Char.compare c '0' < 0 || Char.compare c '9' > 0 then ok := false) s;
      !ok
    in
    let n = String.length body in
    if is_digits body then
      match n with
      | 1 | 2 ->
        (match Int.of_string_opt body with
         | Some hour -> (match to_24 hour with Some hour -> Some { hour; minute = 0; second = 0 } | None -> None)
         | None -> None)
      | 4 ->
        (match (Int.of_string_opt (String.sub body ~pos:0 ~len:2), Int.of_string_opt (String.sub body ~pos:2 ~len:2)) with
         | Some hour, Some minute ->
           (match to_24 hour with
            | Some hour when minute <= 59 -> Some { hour; minute; second = 0 }
            | _ -> None)
         | _ -> None)
      | 6 ->
        (match
           ( Int.of_string_opt (String.sub body ~pos:0 ~len:2)
           , Int.of_string_opt (String.sub body ~pos:2 ~len:2)
           , Int.of_string_opt (String.sub body ~pos:4 ~len:2) )
         with
         | Some hour, Some minute, Some second ->
           (match to_24 hour with
            | Some hour when minute <= 59 && second <= 59 -> Some { hour; minute; second }
            | _ -> None)
         | _ -> None)
      | _ -> None
    else if String.contains body ':' then
      (match parse_iso_time body with
       | Some t -> (match to_24 t.hour with Some hour -> Some { t with hour } | None -> None)
       | None -> None)
    else None

(* ------------------------------------------------------------------- date *)

let month_names =
  [| "january"; "february"; "march"; "april"; "may"; "june"; "july"; "august"; "september"; "october"; "november"
   ; "december"
  |]

let month_of_name (name : string) : int option =
  let name = String.lowercase name in
  let rec loop i =
    if i >= 12 then None
    else
      let full = month_names.(i) in
      let matches =
        String.equal name full
        ||
        (String.length name >= 3
        && String.length name <= String.length full
        && String.equal (String.sub full ~pos:0 ~len:(String.length name)) name)
      in
      if matches then Some (i + 1) else loop (i + 1)
  in
  loop 0

let try_make_date ~year ~month ~day =
  try Some (Plain_date.create ~year ~month ~day) with Invalid_argument _ -> None

(* Upstream's parseDateInput, narrowed to the forms a plain text field can
   carry: the ISO date, the numeric "M/D/YYYY", and the month-name forms. *)
let parse_date_input (input : string) : Plain_date.t option =
  let trimmed = String.strip input in
  if String.is_empty trimmed then None
  else
    let is_digits s =
      String.length s > 0
      &&
      let ok = ref true in
      String.iter ~f:(fun c -> if Char.compare c '0' < 0 || Char.compare c '9' > 0 then ok := false) s;
      !ok
    in
    let words s = List.filter ~f:(fun w -> not (String.is_empty w)) (split_char ' ' s) in
    let try_iso () =
      match split_char '-' trimmed with
      | [ y; m; d ] when is_digits y && is_digits m && is_digits d && String.length y = 4 ->
        (match (Int.of_string_opt y, Int.of_string_opt m, Int.of_string_opt d) with
         | Some year, Some month, Some day -> try_make_date ~year ~month ~day
         | _ -> None)
      | _ -> None
    in
    let try_numeric sep =
      match split_char sep trimmed with
      | [ m; d; y ] when is_digits m && is_digits d && is_digits y && String.length y = 4 ->
        (match (Int.of_string_opt m, Int.of_string_opt d, Int.of_string_opt y) with
         | Some month, Some day, Some year -> try_make_date ~year ~month ~day
         | _ -> None)
      | _ -> None
    in
    let try_named ~month_first =
      let cleaned =
        String.concat ~sep:" " (words (String.concat ~sep:" " (List.map ~f:(fun part -> String.strip part) (split_char ',' trimmed))))
      in
      match words cleaned with
      | [ a; b; c ] when month_first ->
        (match (month_of_name a, Int.of_string_opt b, Int.of_string_opt c) with
         | Some month, Some day, Some year -> try_make_date ~year ~month ~day
         | _ -> None)
      | [ a; b; c ] ->
        (match (Int.of_string_opt a, month_of_name b, Int.of_string_opt c) with
         | Some day, Some month, Some year -> try_make_date ~year ~month ~day
         | _ -> None)
      | _ -> None
    in
    let rec first_of fs =
      match fs with
      | [] -> None
      | f :: rest -> (match f () with Some _ as result -> result | None -> first_of rest)
    in
    first_of
      [ try_iso
      ; (fun () -> try_numeric '/')
      ; (fun () -> try_numeric '-')
      ; (fun () -> try_named ~month_first:true)
      ; (fun () -> try_named ~month_first:false)
      ]

(* --------------------------------------------------------- the ISO bridge *)

module Date_time = struct
  let of_iso (s : string) : date_time option =
    let split =
      match String.index s 'T' with
      | Some i -> Some i
      | None -> String.index s ' '
    in
    match split with
    | None -> None
    | Some i ->
      let date_part = String.sub s ~pos:0 ~len:i in
      let time_part = String.sub s ~pos:(i + 1) ~len:(String.length s - i - 1) in
      let date = try Some (Plain_date.of_iso date_part) with Invalid_argument _ -> None in
      (match (date, parse_iso_time time_part) with
       | Some date, Some time -> Some { date; time }
       | _ -> None)

  let to_iso (dt : date_time) : string =
    let has_seconds = not (Int.equal dt.time.second 0) in
    Plain_date.to_iso dt.date ^ "T" ^ format_time_24h ~has_seconds dt.time
end

(* ------------------------------------------------------------------ clock *)

(* The host's current local time, read at call time: upstream's
   getDefaultTime, used when a date is picked before a time exists. *)
let now () : time =
  let read =
    try
      Some
        (Js.Unsafe.eval_string
           "(function(){var d=new Date();return {h:d.getHours(),m:d.getMinutes(),s:d.getSeconds()};})()")
    with _ -> None
  in
  let number name =
    match read with
    | None -> 0
    | Some o -> (try int_of_float (Js.to_float (Js.Unsafe.get o name)) with _ -> 0)
  in
  { hour = number "h"; minute = number "m"; second = number "s" }

(* ------------------------------------------------------------------ model *)

type model =
  { date_draft : string option  (** the typed date text, not yet committed *)
  ; time_draft : string option  (** the typed time text, not yet committed *)
  ; is_calendar_open : bool
  ; value : date_time option  (** the uncontrolled value *)
  ; announce : string option  (** the polite live region's message *)
  }

(* ------------------------------------------------------------- js helpers *)

let js_property (ev : 'a) name : string =
  Js.to_string (Js.Unsafe.coerce (Js.Unsafe.get (Obj.magic ev : Js.Unsafe.any) name))

let js_prevent_default (ev : 'a) : unit =
  ignore (Js.Unsafe.meth_call (Obj.magic ev : Js.Unsafe.any) "preventDefault" [||])

(* ------------------------------------------------------------------ view *)

let view
    ?id
    ?(attrs = [])
    ~label
    ?(is_label_hidden = false)
    ?description
    ?(is_optional = false)
    ?(is_required = false)
    ?(is_disabled = false)
    ?disabled_message
    ?value
    ?(default_value = None)
    ?on_change
    ?min
    ?max
    ?(date_constraints = [])
    ?(has_seconds = false)
    ?(hour_format = H12)
    ?(time_increment = Minute_1)
    ?(has_clear = false)
    ?(placeholder = "Select a date")
    ?(time_placeholder = "Select a time")
    ?time_label
    ?(size = Md)
    ?status
    ?(status_variant = Attached)
    ?width
    ?(number_of_months = 1)
    ?(week_starts_on = 0)
    ?(locale = "en")
    graph
  : Vdom.Node.t Bonsai.t =
  let id = Option.value id ~default:"astryx-date-time-input" in
  let date_input_id = id ^ "-date" in
  let time_input_id = id ^ "-time" in
  let description_id = date_input_id ^ "-desc" in
  let status_id = date_input_id ^ "-status" in
  let is_controlled = Option.is_some value in
  let effective_description = match description with Some d -> Some d | None -> disabled_message in
  let is_effectively_required = is_required && not is_optional in
  let shows_disabled_message = is_disabled && Option.is_some disabled_message in
  let resolved_time_label = Option.value time_label ~default:(label ^ " time") in
  let initial_model =
    { date_draft = None
    ; time_draft = None
    ; is_calendar_open = false
    ; value = default_value
    ; announce = None
    }
  in
  let model, set_model = Bonsai.state' initial_model graph in
  let set_model_f = Bonsai.map set_model ~f:(fun f -> f) in
  let controlled_value = match value with Some v -> v | None -> Bonsai.return None in
  let caller_on_change =
    match on_change with
    | Some f -> f
    | None -> Bonsai.return (fun (_ : date_time option) -> Effect.Ignore)
  in
  let context =
    let with_model =
      Bonsai.map3 model set_model_f controlled_value ~f:(fun model set controlled -> (model, set, controlled))
    in
    Bonsai.map2 with_model caller_on_change ~f:(fun (model, set, controlled) on_change ->
        (model, set, controlled, on_change))
  in
  let value_tree =
    Bonsai.map context ~f:(fun (model, _set, controlled, _on_change) ->
        if is_controlled then controlled else model.value)
  in
  let calendar_value =
    Bonsai.map value_tree ~f:(fun value -> Option.map value ~f:(fun dt -> Calendar_.Single_date dt.date))
  in
  let calendar_on_change =
    Bonsai.map context ~f:(fun (model, set, _controlled, on_change) ->
        fun (selection : Calendar_.selection) ->
          match selection with
          | Calendar_.Date_range _ -> Effect.Ignore
          | Calendar_.Single_date date ->
            let time =
              match model.value with
              | Some dt -> dt.time
              | None ->
                (match model.time_draft with
                 | Some text -> (match parse_time_input text with Some t -> t | None -> now ())
                 | None -> now ())
            in
            Effect.Many
              [ on_change (Some { date; time })
              ; set (fun m -> { m with date_draft = None; is_calendar_open = false })
              ])
  in
  let min_date = Option.map min ~f:(fun dt -> dt.date) in
  let max_date = Option.map max ~f:(fun dt -> dt.date) in
  let calendar_tree =
    Calendar_.view
      ~mode:Calendar_.Single
      ~value:calendar_value
      ~on_change:calendar_on_change
      ?min:min_date
      ?max:max_date
      ~date_constraints
      ~number_of_months
      ~week_starts_on
      ~locale
      graph
  in
  Bonsai.map2 context calendar_tree ~f:(fun (model, set, controlled, on_change) calendar_node ->
      let value = if is_controlled then controlled else model.value in
      let format_display (t : time) =
        match hour_format with
        | H12 -> format_time_12h ~has_seconds t
        | H24 -> format_time_24h ~has_seconds t
      in
      let date_display =
        match model.date_draft with
        | Some text -> text
        | None -> (match value with Some dt -> Plain_date.format_long ~locale dt.date | None -> "")
      in
      let time_display =
        match model.time_draft with
        | Some text -> text
        | None -> (match value with Some dt -> format_display dt.time | None -> "")
      in
      let date_is_enabled (date : Plain_date.t) : bool =
        let after_min = match min with Some m -> not (Plain_date.is_before date m.date) | None -> true in
        let before_max = match max with Some m -> not (Plain_date.is_after date m.date) | None -> true in
        after_min && before_max && List.for_all date_constraints ~f:(fun f -> f date)
      in
      (* Upstream: a time bound applies on the boundary date only. *)
      let time_min =
        match (min, value) with
        | Some m, Some v when Plain_date.is_equal v.date m.date -> Some m.time
        | _ -> None
      in
      let time_max =
        match (max, value) with
        | Some m, Some v when Plain_date.is_equal v.date m.date -> Some m.time
        | _ -> None
      in
      let time_is_in_range (t : time) : bool =
        (match time_min with Some m -> compare_time t m >= 0 | None -> true)
        && (match time_max with Some m -> compare_time t m <= 0 | None -> true)
      in
      let current_time () : time =
        match value with
        | Some dt -> dt.time
        | None ->
          (match model.time_draft with
           | Some text -> (match parse_time_input text with Some t -> t | None -> now ())
           | None -> now ())
      in
      let fire_change (new_value : date_time option) : unit Effect.t =
        Effect.Many [ on_change new_value; set (fun m -> { m with value = new_value }) ]
      in
      let date_draft_is_valid =
        match model.date_draft with
        | Some text ->
          let trimmed = String.strip text in
          if String.is_empty trimmed then true else Option.is_some (parse_date_input trimmed)
        | None -> true
      in
      let time_draft_is_valid =
        match model.time_draft with
        | Some text ->
          let trimmed = String.strip text in
          if String.is_empty trimmed then true
          else (match parse_time_input trimmed with Some t -> time_is_in_range t | None -> false)
        | None -> true
      in
      let handle_date_input (text : string) : unit Effect.t =
        let draft = [ set (fun m -> { m with date_draft = Some text }) ] in
        match parse_date_input (String.strip text) with
        | Some date when date_is_enabled date ->
          (match value with
           | Some v when not (Plain_date.is_equal date v.date) ->
             Effect.Many (draft @ [ fire_change (Some { date; time = current_time () }) ])
           | _ -> Effect.Many draft)
        | _ -> Effect.Many draft
      in
      let commit_date_draft () : unit Effect.t =
        match model.date_draft with
        | None -> Effect.Ignore
        | Some text ->
          let trimmed = String.strip text in
          if String.is_empty trimmed then
            Effect.Many
              [ fire_change None
              ; set (fun m -> { m with date_draft = None; time_draft = None })
              ]
          else
            (match parse_date_input trimmed with
             | Some date when date_is_enabled date ->
               (match value with
                | Some v when not (Plain_date.is_equal date v.date) ->
                  Effect.Many
                    [ fire_change (Some { date; time = current_time () })
                    ; set (fun m -> { m with date_draft = None })
                    ]
                | _ -> set (fun m -> { m with date_draft = None }))
             | _ -> set (fun m -> { m with date_draft = None }))
      in
      let commit_time_draft () : unit Effect.t =
        match model.time_draft with
        | None -> Effect.Ignore
        | Some text ->
          let trimmed = String.strip text in
          if String.is_empty trimmed then
            Effect.Many [ fire_change None; set (fun m -> { m with time_draft = None; date_draft = None }) ]
          else
            (match parse_time_input trimmed with
             | Some t when time_is_in_range t ->
               (match value with
                | Some v ->
                  Effect.Many
                    [ fire_change (Some { date = v.date; time = t })
                    ; set (fun m -> { m with time_draft = None })
                    ]
                | None -> set (fun m -> { m with time_draft = None }))
             | _ -> set (fun m -> { m with time_draft = None }))
      in
      let handle_time_input (text : string) : unit Effect.t =
        let draft = [ set (fun m -> { m with time_draft = Some text }) ] in
        match parse_time_input (String.strip text) with
        | Some t when time_is_in_range t ->
          (match value with
           | Some v when not (Poly.equal t v.time) ->
             Effect.Many (draft @ [ fire_change (Some { date = v.date; time = t }) ])
           | _ -> Effect.Many draft)
        | _ -> Effect.Many draft
      in
      let step_time (delta : int) : unit Effect.t =
        match value with
        | Some v ->
          let stepped = adjust_time v.time delta in
          if time_is_in_range stepped then
            Effect.Many
              [ fire_change (Some { date = v.date; time = stepped })
              ; set (fun m -> { m with time_draft = Some (format_display stepped); announce = Some (format_display stepped) })
              ]
          else Effect.Ignore
        | None -> Effect.Ignore
      in
      let open_calendar () : unit Effect.t =
        if is_disabled then Effect.Ignore else set (fun m -> { m with is_calendar_open = true })
      in
      let close_calendar () : unit Effect.t = set (fun m -> { m with is_calendar_open = false }) in
      let on_open_change (open_ : bool) : unit Effect.t =
        set (fun m -> { m with is_calendar_open = open_ })
      in
      let handle_clear () : unit Effect.t =
        Effect.Many
          [ fire_change None
          ; set (fun m -> { m with date_draft = None; time_draft = None; announce = None })
          ]
      in
      let described_by =
        List.filter_map
          ~f:(fun x -> x)
          [ (match effective_description with Some _ -> Some description_id | None -> None)
          ; (match status with
             | Some { Input_types.message = Some m; _ } when not (String.is_empty m) -> Some status_id
             | Some _ -> None
             | None -> None)
          ]
        |> String.concat ~sep:" "
      in
      let has_described_by = not (String.is_empty described_by) in
      let disabled_attrs =
        if shows_disabled_message
        then [ Vdom.Attr.create "aria-disabled" "true"; Vdom.Attr.create "readonly" "readonly" ]
        else if is_disabled then [ Vdom.Attr.create "disabled" "disabled" ]
        else []
      in
      let date_input_attrs =
        List.concat
          [ [ Vdom.Attr.create "id" date_input_id
            ; Vdom.Attr.create "type" "text"
            ; Vdom.Attr.value date_display
            ; Vdom.Attr.placeholder placeholder
            ; Vdom.Attr.role "combobox"
            ; Vdom.Attr.create "aria-haspopup" "dialog"
            ; Vdom.Attr.create "aria-expanded" (if model.is_calendar_open then "true" else "false")
            ; Vdom.Attr.create "aria-autocomplete" "none"
            ; Vdom.Attr.create "autocomplete" "off"
            ]
          ; (if is_effectively_required then [ Vdom.Attr.create "aria-required" "true" ] else [])
          ; (if (match status with Some s -> Poly.equal s.type_ Error | None -> false)
                || not date_draft_is_valid
             then [ Vdom.Attr.create "aria-invalid" "true" ]
             else [])
          ; (if has_described_by then [ Vdom.Attr.create "aria-describedby" described_by ] else [])
          ; disabled_attrs
          ; [ Vdom.Attr.on_input (fun _ text -> handle_date_input text)
            ; Vdom.Attr.on_blur (fun _ -> commit_date_draft ())
            ; Vdom.Attr.on_click (fun _ -> open_calendar ())
            ; Vdom.Attr.on_keydown (fun ev ->
                  let key = js_property ev "key" in
                  if String.equal key "ArrowDown" then
                    (js_prevent_default ev;
                     if model.is_calendar_open then Effect.Ignore else open_calendar ())
                  else if String.equal key "Escape" then
                    (js_prevent_default ev; close_calendar ())
                  else if String.equal key "Enter" then
                    (js_prevent_default ev; commit_date_draft ())
                  else Effect.Ignore)
            ]
          ]
      in
      let time_input_attrs =
        List.concat
          [ [ Vdom.Attr.create "id" time_input_id
            ; Vdom.Attr.create "type" "text"
            ; Vdom.Attr.value time_display
            ; Vdom.Attr.placeholder time_placeholder
            ]
          ; Common.Attr.aria "label" resolved_time_label
          ; (if is_effectively_required then [ Vdom.Attr.create "aria-required" "true" ] else [])
          ; (if (match status with Some s -> Poly.equal s.type_ Error | None -> false)
                || not time_draft_is_valid
             then [ Vdom.Attr.create "aria-invalid" "true" ]
             else [])
          ; (if has_described_by then [ Vdom.Attr.create "aria-describedby" described_by ] else [])
          ; disabled_attrs
          ; [ Vdom.Attr.on_input (fun _ text -> handle_time_input text)
            ; Vdom.Attr.on_blur (fun _ -> commit_time_draft ())
            ; Vdom.Attr.on_keydown (fun ev ->
                  let key = js_property ev "key" in
                  if String.equal key "ArrowUp" then
                    (js_prevent_default ev; step_time (increment_minutes time_increment))
                  else if String.equal key "ArrowDown" then
                    (js_prevent_default ev; step_time (-increment_minutes time_increment))
                  else if String.equal key "Enter" then
                    (js_prevent_default ev; commit_time_draft ())
                  else Effect.Ignore)
            ]
          ]
      in
      let segment_attrs kind =
        Common.Attr.class_
          [ "astryx-date-time-input__segment"
          ; "astryx-date-time-input__segment--" ^ kind
          ; (match status with
             | Some s -> "astryx-date-time-input__segment--" ^ (match s.type_ with Warning -> "warning" | Error -> "error" | Success -> "success")
             | None -> "")
          ; (if is_disabled then "astryx-date-time-input__segment--disabled" else "")
          ]
        @ [ Vdom.Attr.create "data-astryx-size" (match size with Sm -> "sm" | Md -> "md" | Lg -> "lg") ]
      in
      let date_segment =
        Vdom.Node.div ~attrs:(segment_attrs "date")
          [ Vdom.Node.button
              ~attrs:
                (Common.Attr.class_ [ "astryx-date-time-input__calendar-button" ]
                @ [ Vdom.Attr.create "type" "button" ]
                @ Common.Attr.aria
                    "label"
                    (if model.is_calendar_open then "Close calendar" else "Open calendar")
                @ (if is_disabled then [ Vdom.Attr.create "disabled" "disabled" ] else []))
              [ Icon.view ~name:"calendar" ~size:Icon.Sm ~color:Icon.Secondary () ]
          ; Vdom.Node.input ~attrs:date_input_attrs ()
          ]
      in
      let time_segment =
        Vdom.Node.div ~attrs:(segment_attrs "time")
          [ Vdom.Node.span
              ~attrs:(Common.Attr.class_ [ "astryx-date-time-input__icon" ])
              [ Icon.view ~name:"clock" ~size:Icon.Sm ~color:Icon.Secondary () ]
          ; Vdom.Node.input ~attrs:time_input_attrs ()
          ]
      in
      let clear_button =
        match (has_clear, value) with
        | true, Some _ when not is_disabled ->
          Some
            (Vdom.Node.button
               ~attrs:
                 (Common.Attr.class_ [ "astryx-date-time-input__clear-button" ]
                 @ [ Vdom.Attr.create "type" "button" ]
                 @ Common.Attr.aria "label" ("Clear " ^ label)
                 @ [ Vdom.Attr.on_click (fun _ -> handle_clear ()) ])
               [ Vdom.Node.text "×" ])
        | _ -> None
      in
      let popover =
        Popover.view
          ~id:(id ^ "-calendar")
          ~label:"Select a date"
          ~close_button_label:"Close calendar"
          ~role:Popover.Dialog
          ~is_modal:false
          ~has_auto_focus:true
          ~has_light_dismiss:true
          ~has_escape_dismiss:true
          ~trigger:date_segment
          ~content:calendar_node
          ~is_open:model.is_calendar_open
          ~on_open_change
          ()
      in
      let live_regions =
        [ Vdom.Node.div
            ~attrs:
              (Common.Attr.class_ [ "astryx-visually-hidden" ]
              @ Common.Attr.role "alert"
              @ Common.Attr.aria "live" "assertive")
            [ Vdom.Node.text (if date_draft_is_valid then "" else "Invalid date") ]
        ; Vdom.Node.div
            ~attrs:
              (Common.Attr.class_ [ "astryx-visually-hidden" ]
              @ Common.Attr.role "alert"
              @ Common.Attr.aria "live" "assertive")
            [ Vdom.Node.text (if time_draft_is_valid then "" else "Invalid time") ]
        ; Vdom.Node.div
            ~attrs:
              (Common.Attr.class_ [ "astryx-visually-hidden" ]
              @ Common.Attr.role "status"
              @ Common.Attr.aria "live" "polite")
            [ Vdom.Node.text (Option.value model.announce ~default:"") ]
        ]
      in
      let field_children =
        List.concat
          [ [ Vdom.Node.div
                ~attrs:
                  (Common.Attr.class_ [ "astryx-date-time-input__row" ]
                  @ Common.Attr.data "component" "DateTimeInput"
                  @ attrs)
                [ popover
                ; time_segment
                ; (match clear_button with Some button -> button | None -> Vdom.Node.text "")
                ]
            ]
          ; live_regions
          ]
      in
      Field_.view
        ~label
        ~input_id:date_input_id
        ?description:effective_description
        ~is_label_hidden
        ~is_optional
        ~is_required
        ~is_disabled
        ?status
        ~status_variant
        ?width
        ~children:field_children
        ())

;;
