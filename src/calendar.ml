(* Calendar — the month grid a person picks a date (or a date range) with.

   Port of upstream's [packages/core/src/Calendar]. The behaviour contract is
   upstream's own: [Calendar.spec.md] (intent, ARIA, FR1-FR5) and
   [Calendar.test.tsx] (case by case). See calendar.mli for the contract and
   the recorded divergences.

   The grid is model-driven: the day that holds the roving Tab stop lives in
   this module's state, so the Tab stop, the arrow keys and the drawn range
   all come from the same date arithmetic. Upstream instead lets
   [useGridFocus] stamp [tabindex] onto DOM cells and reads the focused day
   back out of [document.activeElement]; the two agree on what a person sees,
   and the model-driven form keeps "which day is focused" and "which day is
   drawn" from drifting apart. *)

open! Core
open! Bonsai_web
open Js_of_ocaml

module Attr = Common.Attr

(* ------------------------------------------------------------------ types *)

type mode =
  | Single
  | Range

type date_range =
  { start_date : Plain_date.t
  ; end_date : Plain_date.t
  }

type selection =
  | Single_date of Plain_date.t
  | Date_range of date_range

(* ------------------------------------------------------------- list helpers *)

(* Written out rather than taken from [List] so the file does not depend on
   the labelled-argument spellings of the core version in use. *)

let init_list n ~f =
  let rec go i acc = if i < 0 then acc else go (i - 1) (f i :: acc) in
  go (n - 1) []
;;

let indexed list =
  let rec go i acc = function
    | [] -> List.rev acc
    | x :: rest -> go (i + 1) ((i, x) :: acc) rest
  in
  go 0 [] list
;;

let rec find_map_opt f = function
  | [] -> None
  | x :: rest -> (match f x with Some v -> Some v | None -> find_map_opt f rest)
;;

let rec nth_opt list n =
  match list with
  | [] -> None
  | x :: rest -> if n <= 0 then Some x else nth_opt rest (n - 1)
;;

(* ------------------------------------------------------------------ dates *)

let month_key (d : Plain_date.t) = (d.year * 12) + d.month

let first_of_month (d : Plain_date.t) = { d with day = 1 }

let same_month (a : Plain_date.t) (b : Plain_date.t) = a.year = b.year && a.month = b.month

(* ------------------------------------------------------------------- grid *)

(* One cell of a month's grid. [is_outside] marks a day borrowed from a
   neighbouring month: it is drawn, but it is never picked and it never takes
   keyboard focus (FR5). *)
type grid_day =
  { date : Plain_date.t
  ; is_outside : bool
  ; day_number : int
  }

(* Port of upstream's [useCalendarDays]: the month's days, padded to whole
   weeks with the neighbouring months' days. *)
let grid_days ~(year:int) ~(month:int) ~(week_starts_on:int) ~(has_variable_row_count:bool) : grid_day list list =
  let first = Plain_date.create ~year ~month ~day:1 in
  let days_in_month = Plain_date.days_in_month year month in
  let starting_day_of_week = (Plain_date.day_of_week first - week_starts_on + 7) mod 7 in
  let total_days = days_in_month + starting_day_of_week in
  let rows = if has_variable_row_count then (total_days + 6) / 7 else 6 in
  let cell index =
    let day_offset = index - starting_day_of_week + 1 in
    let is_outside = day_offset < 1 || day_offset > days_in_month in
    let date =
      if is_outside
      then Plain_date.add_days first (day_offset - 1)
      else Plain_date.create ~year ~month ~day:day_offset
    in
    { date ; is_outside ; day_number = date.day }
  in
  init_list rows ~f:(fun row -> init_list 7 ~f:(fun column -> cell ((row * 7) + column)))
;;

(* The weekday names, in the order the columns run. Upstream rotates the
   locale's standalone short names by [week_starts_on]; the host's Intl short
   weekday names stand in for that table. *)
let weekday_names ~(locale:string) ~(week_starts_on:int) : string list =
  let today = Plain_date.today () in
  let sunday = Plain_date.add_days today (-(Plain_date.day_of_week today)) in
  init_list 7 ~f:(fun column ->
    let day_of_week = (week_starts_on + column) mod 7 in
    Plain_date.format_weekday_only ~locale (Plain_date.add_days sunday day_of_week))
;;

(* ------------------------------------------------------------- day states *)

(* Port of upstream's [computeDayCellState]. *)
type day_state =
  { effectively_disabled : bool
  ; is_today : bool
  ; is_selected : bool
  ; is_in_range : bool
  ; is_range_start : bool
  ; is_range_end : bool
  ; is_in_preview : bool
  ; is_preview_start : bool
  ; is_preview_end : bool
  }

let compute_day_state
    ~(date:Plain_date.t)
    ~(mode:mode)
    ~(selected_date:Plain_date.t option)
    ~(range_start:Plain_date.t option)
    ~(range_end:Plain_date.t option)
    ~(preview_start:Plain_date.t option)
    ~(preview_end:Plain_date.t option)
    ~(today:Plain_date.t)
    ~(is_disabled:bool)
    ~(is_outside:bool)
  : day_state =
  let in_month = not is_outside in
  let matches date' = match date' with Some d -> Plain_date.is_equal date d | None -> false in
  let is_selected =
    in_month
    && (match mode with
        | Single -> matches selected_date
        | Range -> false)
  in
  let is_in_range =
    in_month
    && (match mode with
        | Single -> false
        | Range ->
          (match range_start, range_end with
           | Some first, Some last -> Plain_date.is_in_range date ~first ~last
           | _ -> false))
  in
  let is_range_start =
    in_month
    && (match mode with Single -> false | Range -> matches range_start)
  in
  let is_range_end =
    in_month
    && (match mode with Single -> false | Range -> matches range_end)
  in
  let is_in_preview =
    in_month
    && (match preview_start, preview_end with
        | Some first, Some last -> Plain_date.is_in_range date ~first ~last
        | _ -> false)
  in
  { effectively_disabled = is_disabled || is_outside
  ; is_today = in_month && Plain_date.is_equal date today
  ; is_selected
  ; is_in_range
  ; is_range_start
  ; is_range_end
  ; is_in_preview
  ; is_preview_start = in_month && matches preview_start
  ; is_preview_end = in_month && matches preview_end
  }
;;

(* ------------------------------------------------------------ focus hook *)

(* Moving the DOM focus onto the day the model says holds it. The day button
   is re-created whenever the month changes, so the hook has to act on mount
   as well as on update. *)
module Focus_hook = struct
  module T = struct
    module State = struct
      type t = unit

      let create () = ()
    end

    module Input = struct
      type t = { is_target : bool }

      let sexp_of_t { is_target } = Sexp.List [ Sexp.Atom (Bool.to_string is_target) ]

      let combine left _ = left
    end

    let focus_element (node : Dom_html.element Js.t) =
      ignore (Js.Unsafe.meth_call node "focus" [||])

    let init _ _ = State.create ()

    let on_mount (input : Input.t) _ node = if input.is_target then focus_element node

    let on_mount = `Schedule_animation_frame on_mount

    let update ~old_input:(old_input : Input.t) ~new_input:(new_input : Input.t) _ node =
      if (not old_input.is_target) && new_input.is_target then focus_element node

    let destroy _ _ _ = ()
  end

  module Hook = Vdom.Attr.Hooks.Make (T)

  let attr ~is_target () =
    Vdom.Attr.create_hook "astryx-calendar-focus" (Hook.create { T.Input.is_target })
  ;;
end

(* ------------------------------------------------------------------ view *)

(* The component's own state. The selected dates, the month in view, the day
   that has the keyboard focus, the Tab stops (one per month in view), the
   range's anchor, the day under the pointer, and what was announced. *)
type model =
  { focused : Plain_date.t option
  ; stops : (int * Plain_date.t) list
  ; selection : selection option
  ; base_month : Plain_date.t option
  ; range_start : Plain_date.t option
  ; hover : Plain_date.t option
  ; announce : string option
  ; announced_label : string option
  }

let rec view
    ?id
    ?attrs
    ?(mode = Single)
    ?value
    ?(default_value = None)
    ?on_change
    ?(number_of_months = 1)
    ?min
    ?max
    ?(date_constraints = [])
    ?(max_range_span = None)
    ?(min_range_span = 1)
    ?focus_date
    ?on_focus_date_change
    ?(has_outside_days = true)
    ?(has_week_numbers = false)
    ?(has_variable_row_count = false)
    ?(week_starts_on = 0)
    ?(locale = "en")
    graph
  : Vdom.Node.t Bonsai.t =
  let months_count = if number_of_months = 2 then 2 else 1 in
  let min_date = min in
  let max_date = max in
  (* Upstream controls the selection when [value] is given and the visible
     month only when both the date and the callback are given. *)
  let is_controlled_value = Option.is_some value in
  let is_controlled_month = Option.is_some focus_date && Option.is_some on_focus_date_change in
  let today = Plain_date.today () in
  let value_tree = match value with Some v -> v | None -> Bonsai.return None in
  let on_change_tree =
    match on_change with Some f -> Bonsai.map f ~f:(fun f -> Some f) | None -> Bonsai.return None
  in
  let focus_date_tree = match focus_date with Some f -> f | None -> Bonsai.return None in
  let on_focus_date_change_tree =
    match on_focus_date_change with
    | Some f -> Bonsai.map f ~f:(fun f -> Some f)
    | None -> Bonsai.return None
  in
  let externals =
    let a = Bonsai.map2 value_tree on_change_tree ~f:(fun value on_change -> (value, on_change)) in
    let b = Bonsai.map2 a focus_date_tree ~f:(fun (value, on_change) fd -> (value, on_change, fd)) in
    Bonsai.map2 b on_focus_date_change_tree ~f:(fun (value, on_change, fd) ofc -> (value, on_change, fd, ofc))
  in
  let initial_model =
    { focused = None
    ; stops = []
    ; selection = default_value
    ; base_month = None
    ; range_start = None
    ; hover = None
    ; announce = None
    ; announced_label = None
    }
  in
  let model, set_model = Bonsai.state' initial_model graph in
  let set_model_f = Bonsai.map set_model ~f:(fun f -> f) in
  let with_model = Bonsai.map2 model externals ~f:(fun model ext -> (model, ext)) in
  let all = Bonsai.map2 with_model set_model_f ~f:(fun (model, ext) set -> (model, ext, set)) in
  Bonsai.map all ~f:(fun (model, ext, set) -> render ~model ~ext ~set ~mode ~months_count ~min_date ~max_date ~date_constraints ~max_range_span ~min_range_span ~has_outside_days ~has_week_numbers ~has_variable_row_count ~week_starts_on ~locale ~today ~is_controlled_value ~is_controlled_month ~id ~attrs ())

and render
    ~model
    ~ext
    ~set
    ~mode
    ~months_count
    ~min_date
    ~max_date
    ~date_constraints
    ~max_range_span
    ~min_range_span
    ~has_outside_days
    ~has_week_numbers
    ~has_variable_row_count
    ~week_starts_on
    ~locale
    ~today
    ~is_controlled_value
    ~is_controlled_month
    ~id
    ~attrs
    ()
  : Vdom.Node.t =
  let value, on_change, focus_date, on_focus_date_change = ext in
  let selection = if is_controlled_value then value else model.selection in
  (* A day is disabled when it is outside the window, when a range-span bound
     rules it out, or when a constraint rejects it. *)
  let range_anchor = match mode with Range -> model.range_start | Single -> None in
  let is_enabled (date : Plain_date.t) =
    let out_of_window =
      (match min_date with Some m -> Plain_date.is_before date m | None -> false)
      || (match max_date with Some m -> Plain_date.is_after date m | None -> false)
    in
    let out_of_span =
      match range_anchor with
      | None -> false
      | Some anchor ->
        let distance = abs (Plain_date.diff_days anchor date) in
        (match max_range_span with
         | Some span -> distance > span - 1
         | None -> false)
        || (min_range_span > 1 && distance > 0 && distance < min_range_span - 1)
    in
    let rejected = List.exists date_constraints ~f:(fun f -> not (f date)) in
    not (out_of_window || out_of_span || rejected)
  in
  (* The visible month: the controlled date wins, then the selection, then
     today clamped into the window (upstream's [getInitialFocusDate]). *)
  let initial_month =
    match focus_date with
    | Some d -> first_of_month d
    | None ->
      (match selection with
       | Some (Single_date d) -> first_of_month d
       | Some (Date_range r) -> first_of_month r.start_date
       | None ->
         (match min_date with
          | Some m when Plain_date.is_before today m -> first_of_month m
          | _ ->
            (match max_date with
             | Some m when Plain_date.is_after today m ->
               let shifted = Plain_date.add_months (first_of_month m) (-(months_count - 1)) in
               (match min_date with
                | Some mn when Plain_date.is_before shifted (first_of_month mn) -> first_of_month mn
                | _ -> shifted)
             | _ -> first_of_month today)))
  in
  let base_month =
    if is_controlled_month
    then (match focus_date with Some d -> first_of_month d | None -> initial_month)
    else match model.base_month with Some m -> m | None -> initial_month
  in
  let months = init_list months_count ~f:(fun i -> Plain_date.add_months base_month i) in
  let month_label month = Plain_date.format_month_year ~locale month in
  let months_label = String.concat ~sep:" – " (List.map ~f:month_label months) in
  let label_of_base base = String.concat ~sep:" – " (List.map ~f:month_label (init_list months_count ~f:(fun i -> Plain_date.add_months base i))) in
  (* The range on screen: the committed one, or — while a range is being
     picked — the start alone. *)
  let range_start, range_end =
    match model.range_start with
    | Some s -> (Some s, Some s)
    | None ->
      (match selection with
       | Some (Date_range r) -> (Some r.start_date, Some r.end_date)
       | _ -> (None, None))
  in
  (* The preview: the range the pointer (or a shift-click) is proposing. *)
  let preview_start, preview_end =
    match mode, model.range_start, model.hover with
    | Range, Some start, Some hovered when not (Plain_date.is_equal start hovered) ->
      if Plain_date.is_before hovered start then (Some hovered, Some start) else (Some start, Some hovered)
    | _ -> (None, None)
  in
  let selected_date = match selection with Some (Single_date d) -> Some d | _ -> None in
  let announce_date (date : Plain_date.t) = Plain_date.format_with_weekday ~locale date in
  (* The Tab stop of a month: the day the reader last moved to in that month,
     else the month's seed — the selected day, else today, else its first
     enabled day. *)
  let seed_of_month (month : Plain_date.t) =
    let cells = List.concat (grid_days ~year:month.year ~month:month.month ~week_starts_on ~has_variable_row_count) in
    let in_month date = same_month date month && is_enabled date in
    match selection with
    | Some (Single_date d) when in_month d -> Some d
    | _ ->
      if in_month today
      then Some today
      else find_map_opt (fun cell -> if (not cell.is_outside) && is_enabled cell.date then Some cell.date else None) cells
  in
  let stop_of_month month =
    match List.Assoc.find model.stops (month_key month) ~equal:Int.equal with
    | Some d when same_month d month && is_enabled d -> Some d
    | Some _ -> seed_of_month month
    | None -> seed_of_month month
  in
  (* ------------------------------------------------------------- actions *)
  let report_change selection =
    match on_change with Some f -> [ f selection ] | None -> []
  in
  let report_month (month : Plain_date.t) =
    match on_focus_date_change with Some f -> [ f month ] | None -> []
  in
  let pick_day (date : Plain_date.t) ~(shift : bool) =
    match mode with
    | Single ->
      let selection = Single_date date in
      Effect.Many
        ([ set (fun state -> { state with selection = Some selection }) ]
         @ report_change selection)
    | Range ->
      (match model.range_start with
       | None ->
         set (fun state ->
           { state with
             range_start = Some date
           ; announce = Some (sprintf "Start date %s. Select an end date." (announce_date date))
           ; announced_label = Some months_label
           })
       | Some start ->
         if Plain_date.is_equal date start && min_range_span > 1
         then
           (* Picking the start again would commit a one-day range, which the
              minimum span forbids: it clears the start instead. *)
           set (fun state ->
             { state with
               range_start = None
             ; announce = Some (sprintf "Cleared start date %s. Select a start date." (announce_date date))
             ; announced_label = Some months_label
             })
         else if shift
         then
           (* A shift-click proposes the end of the range without committing
              it, so the band can be drawn first. *)
           set (fun state -> { state with hover = Some date })
         else
           let start_date, end_date =
             if Plain_date.is_before date start then (date, start) else (start, date)
           in
           let selection = Date_range { start_date ; end_date } in
           Effect.Many
             ([ set (fun state ->
                  { state with
                    selection = Some selection
                  ; range_start = None
                  ; hover = None
                  ; announce =
                      Some
                        (sprintf
                           "Selected range: %s to %s."
                           (announce_date start_date)
                           (announce_date end_date))
                  ; announced_label = Some months_label
                  })
              ]
              @ report_change selection))
  in
  let hover_day (date : Plain_date.t option) = set (fun state -> { state with hover = date }) in
  (* The month a target day needs, when it is not on screen. The view shifts
     as little as it can in the key's direction: the target month becomes the
     last pane going forwards and the first pane going backwards. *)
  let shifted_base (target : Plain_date.t) =
    let first_shown = base_month in
    let last_shown = Option.value (nth_opt months (months_count - 1)) ~default:base_month in
    let target_month = first_of_month target in
    if month_key target_month < month_key first_shown
    then Some target_month
    else if month_key target_month > month_key last_shown
    then Some (Plain_date.add_months target_month (-(months_count - 1)))
    else None
  in
  (* The day a key moves to. Inside the month the arrows walk the grid's own
     days; a move that runs off the month's edge crosses into the
     neighbouring month, where the walk continues until it finds an enabled
     day. *)
  let resolve_key ~(key : string) ~(ctrl : bool) ~(meta : bool) ~(shift : bool) ~(month : Plain_date.t) ~(focused : Plain_date.t) =
    let cells = List.concat (grid_days ~year:month.year ~month:month.month ~week_starts_on ~has_variable_row_count) in
    let first_cell = match cells with cell :: _ -> cell | [] -> { date = focused ; is_outside = false ; day_number = 1 } in
    let last_cell = match List.rev cells with cell :: _ -> cell | [] -> first_cell in
    let in_window date = not (Plain_date.is_before date first_cell.date || Plain_date.is_after date last_cell.date) in
    let in_month date = same_month date month in
    let scan ~(delta : int) ~(step : int) =
      let rec go date =
        if not (in_window date)
        then None
        else if in_month date && is_enabled date
        then Some date
        else go (Plain_date.add_days date (delta * step))
      in
      go (Plain_date.add_days focused (delta * step))
    in
    let cross ~(delta : int) ~(step : int) =
      let rec go candidate =
        if abs (Plain_date.diff_days focused candidate) > 366
        then None
        else
          let out_of_window =
            (match min_date with Some m -> Plain_date.is_before candidate m | None -> false)
            || (match max_date with Some m -> Plain_date.is_after candidate m | None -> false)
          in
          if out_of_window
          then None
          else if is_enabled candidate
          then Some candidate
          else go (Plain_date.add_days candidate (delta * step))
      in
      go (Plain_date.add_days focused (delta * step))
    in
    let page ~(delta : int) =
      let candidate = Plain_date.add_months focused delta in
      let out_of_window =
        (match min_date with Some m -> Plain_date.is_before candidate m | None -> false)
        || (match max_date with Some m -> Plain_date.is_after candidate m | None -> false)
      in
      if out_of_window
      then None
      else if is_enabled candidate
      then Some candidate
      else
        (* The same day of the month is not available: the month's first
           enabled day takes its place. *)
        let days_in_month = Plain_date.days_in_month candidate.year candidate.month in
        let rec first_enabled day =
          if day > days_in_month
          then None
          else
            let date = Plain_date.create ~year:candidate.year ~month:candidate.month ~day in
            if is_enabled date then Some date else first_enabled (day + 1)
        in
        first_enabled 1
    in
    let cells_indexed = indexed cells in
    let index_of date =
      find_map_opt
        (fun (index, cell) -> if Plain_date.is_equal cell.date date then Some index else None)
        cells_indexed
    in
    let row_bounds index =
      let row_start = (index / 7) * 7 in
      let row_end = min (row_start + 6) (List.length cells - 1) in
      (row_start, row_end)
    in
    let enabled_in_range ~from ~to_ =
      find_map_opt
        (fun (index, cell) ->
          if index < from || index > to_ then None
          else if (not cell.is_outside) && is_enabled cell.date then Some cell.date else None)
        cells_indexed
    in
    match key with
    | "ArrowRight" -> (match scan ~delta:1 ~step:1 with Some d -> Some d | None -> cross ~delta:1 ~step:1)
    | "ArrowLeft" -> (match scan ~delta:(-1) ~step:1 with Some d -> Some d | None -> cross ~delta:(-1) ~step:1)
    | "ArrowDown" -> (match scan ~delta:1 ~step:7 with Some d -> Some d | None -> cross ~delta:1 ~step:7)
    | "ArrowUp" -> (match scan ~delta:(-1) ~step:7 with Some d -> Some d | None -> cross ~delta:(-1) ~step:7)
    | "Home" ->
      if ctrl || meta
      then
        find_map_opt
          (fun cell -> if (not cell.is_outside) && is_enabled cell.date then Some cell.date else None)
          cells
      else
        (match index_of focused with
         | None -> None
         | Some index ->
           let row_start, row_end = row_bounds index in
           enabled_in_range ~from:row_start ~to_:row_end)
    | "End" ->
      if ctrl || meta
      then
        find_map_opt
          (fun cell -> if (not cell.is_outside) && is_enabled cell.date then Some cell.date else None)
          (List.rev cells)
      else
        (match index_of focused with
         | None -> None
         | Some index ->
           let row_start, row_end = row_bounds index in
           enabled_in_range ~from:row_start ~to_:row_end)
    | "PageUp" -> page ~delta:(if shift then -12 else -1)
    | "PageDown" -> page ~delta:(if shift then 12 else 1)
    | _ -> None
  in
  (* ------------------------------------------------------- key handling *)
  let move_focus ~(key : string) ~(ctrl : bool) ~(meta : bool) ~(shift : bool) ~(month : Plain_date.t) =
    match model.focused with
    | None -> Effect.Ignore
    | Some focused ->
      (match resolve_key ~key ~ctrl ~meta ~shift ~month ~focused with
       | None -> Effect.Ignore
       | Some target ->
         let new_base = shifted_base target in
         let effects =
           [ set (fun state ->
               { state with
                 focused = Some target
               ; stops = (month_key (first_of_month target), target) :: model.stops
               ; base_month = (match new_base with Some m -> Some m | None -> model.base_month)
               ; announce = (match new_base with Some _ -> Some (label_of_base (Option.value new_base ~default:base_month)) | None -> model.announce)
               ; announced_label = (match new_base with Some m -> Some (label_of_base m) | None -> model.announced_label)
               })
           ]
           @ (match new_base with Some m -> report_month m | None -> [])
         in
         Effect.Many effects)
  in
  let on_grid_keydown ~(month : Plain_date.t) (ev : Dom_html.keyboardEvent Js.t) =
    let key = Option.value (Common.string_prop ev "key") ~default:"" in
    match key with
    | "ArrowRight" | "ArrowLeft" | "ArrowUp" | "ArrowDown" | "Home" | "End" | "PageUp" | "PageDown" ->
      Common.prevent_default ev;
      move_focus
        ~key
        ~ctrl:(Common.bool_prop ev "ctrlKey")
        ~meta:(Common.bool_prop ev "metaKey")
        ~shift:(Common.bool_prop ev "shiftKey")
        ~month
    | _ -> Effect.Ignore
  in
  (* ------------------------------------------------------- month header *)
  let can_navigate ~(backwards : bool) =
    match (if backwards then min_date else max_date) with
    | None -> true
    | Some bound ->
      if backwards
      then month_key (first_of_month bound) < month_key base_month
      else month_key (first_of_month bound) > month_key ((Option.value (nth_opt months (months_count - 1)) ~default:base_month))
  in
  let navigate_month ~(backwards : bool) =
    if not (can_navigate ~backwards)
    then Effect.Ignore
    else
      let new_base = Plain_date.add_months base_month (if backwards then -1 else 1) in
      Effect.Many
        ([ set (fun state ->
             { state with
               base_month = (if is_controlled_month then state.base_month else Some new_base)
             ; focused = None
             ; announce = Some (label_of_base new_base)
             ; announced_label = Some (label_of_base new_base)
             })
          ]
         @ report_month new_base)
  in
  let nav_button ~(backwards : bool) ~(label : string) ~(icon : string) =
    Button.view
      ~label
      ~variant:Button.Ghost
      ~size:Button.Sm
      ~is_icon_only:true
      ~is_disabled:(not (can_navigate ~backwards))
      ~icon:(Icon.view ~name:icon ~size:Icon.Sm ~color:Icon.Inherit ())
      ~on_click:(fun (_ : Dom_html.mouseEvent Js.t) -> navigate_month ~backwards)
      []
  in
  let header =
    Vdom.Node.div
      ~attrs:(Attr.class_ [ "astryx-calendar__header" ])
      [ nav_button ~backwards:true ~label:"Previous month" ~icon:"chevronLeft"
      ; Vdom.Node.span
          ~attrs:(Attr.class_ [ "astryx-calendar__month-year-label" ])
          [ Vdom.Node.text months_label ]
      ; nav_button ~backwards:false ~label:"Next month" ~icon:"chevronRight"
      ]
  in
  (* ------------------------------------------------------- month grid *)
  let day_names = weekday_names ~locale ~week_starts_on in
  let render_month (month : Plain_date.t) =
    let rows = grid_days ~year:month.year ~month:month.month ~week_starts_on ~has_variable_row_count in
    let stop = stop_of_month month in
    let week_numbers =
      if not has_week_numbers
      then []
      else
        [ Vdom.Node.div
            ~attrs:
              (Attr.role "columnheader"
               @ Attr.class_ [ "astryx-calendar__day-name"; "astryx-calendar__week-number-header" ])
            [ Visually_hidden.view [ Vdom.Node.text (Plain_date.week_field_name ~locale ()) ] ]
        ]
    in
    let day_name_row =
      Vdom.Node.div
        ~attrs:(Attr.role "row" @ Attr.class_ [ "astryx-calendar__week-row" ])
        (week_numbers
         @ List.map day_names ~f:(fun name ->
             Vdom.Node.div
               ~attrs:(Attr.role "columnheader" @ Attr.class_ [ "astryx-calendar__day-name" ])
               [ Vdom.Node.text name ]))
    in
    let render_week (week : grid_day list) =
      let week_date =
        match find_map_opt (fun cell -> if not cell.is_outside then Some cell.date else None) week with
        | Some d -> d
        | None -> (match week with cell :: _ -> cell.date | [] -> month)
      in
      let cells = indexed week in
      let states =
        List.map cells ~f:(fun (index, cell) ->
            ( index
            , cell
            , compute_day_state
                ~date:cell.date
                ~mode
                ~selected_date
                ~range_start
                ~range_end
                ~preview_start
                ~preview_end
                ~today
                ~is_disabled:(not (is_enabled cell.date))
                ~is_outside:cell.is_outside ))
      in
      let render_cell (_index, cell) (state : day_state) =
        let band_class ~kind ~round_start ~round_end =
          [ Printf.sprintf "astryx-calendar__%s-bg" kind ]
          @ (if round_start then [ Printf.sprintf "astryx-calendar__%s-bg--start" kind ] else [])
          @ (if round_end then [ Printf.sprintf "astryx-calendar__%s-bg--end" kind ] else [])
        in
        let date_label = announce_date cell.date in
        let day_label =
          if state.is_selected
          then sprintf "%s, selected" date_label
          else if state.is_range_start && state.is_range_end
          then
            (match model.range_start with
             | Some _ -> sprintf "%s, range start" date_label
             | None -> sprintf "%s, range start and range end" date_label)
          else if state.is_range_start
          then sprintf "%s, range start" date_label
          else if state.is_range_end
          then sprintf "%s, range end" date_label
          else if state.is_in_range
          then sprintf "%s, in range" date_label
          else date_label
        in
        let is_endpoint = state.is_selected || state.is_range_start || state.is_range_end in
        let day_class =
          [ "astryx-calendar__day" ]
          @ (if cell.is_outside then [ "astryx-calendar__day--outside" ] else [])
          @ (if state.is_today && not state.is_in_range then [ "astryx-calendar__day--today" ] else [])
          @ (if state.is_today && state.is_in_range then [ "astryx-calendar__day--today-in-range" ] else [])
          @ (if is_endpoint then [ "astryx-calendar__day--selected" ] else [])
          @ (if state.effectively_disabled then [ "astryx-calendar__day--disabled" ] else [])
        in
        let is_stop = match stop with Some d -> Plain_date.is_equal d cell.date | None -> false in
        let button =
          if cell.is_outside && not has_outside_days
          then []
          else
            [ Vdom.Node.button
                ~attrs:
                  (Attr.class_ day_class
                   @ [ Vdom.Attr.create "type" "button"
                     ; Vdom.Attr.create "data-date" (Plain_date.to_iso cell.date)
                     ; Vdom.Attr.create "aria-label" day_label
                     ; Vdom.Attr.create "tabindex" (if is_stop then "0" else "-1")
                     ]
                   @ (if state.effectively_disabled then Attr.aria "disabled" "true" else [])
                   @ (if state.is_today then Attr.aria "current" "date" else [])
                   @ [
                       Vdom.Attr.on_click
                         (fun (ev : Dom_html.mouseEvent Js.t) ->
                           pick_day cell.date ~shift:(Common.bool_prop ev "shiftKey"))
                     ; Vdom.Attr.on_mouseenter
                         (fun (_ : Dom_html.mouseEvent Js.t) -> hover_day (Some cell.date))
                     ; Vdom.Attr.on_mouseleave (fun (_ : Dom_html.mouseEvent Js.t) -> hover_day None)
                     ; Vdom.Attr.on_focus
                         (fun (_ : Dom_html.focusEvent Js.t) ->
                           set (fun state -> { state with focused = Some cell.date }))
                     ; Focus_hook.attr ~is_target:(Poly.equal model.focused (Some cell.date)) ()
                     ])
                [ Vdom.Node.text (string_of_int cell.day_number) ]
            ]
        in
        let bands =
          (if state.is_in_range
           then
             [ Vdom.Node.div
                 ~attrs:
                   (Attr.class_
                      (band_class ~kind:"range" ~round_start:state.is_range_start ~round_end:state.is_range_end))
                 []
             ]
           else [])
          @ (if state.is_in_preview
             then
               [ Vdom.Node.div
                   ~attrs:
                     (Attr.class_
                        (band_class
                           ~kind:"preview"
                           ~round_start:state.is_preview_start
                           ~round_end:state.is_preview_end))
                 []
             ]
             else [])
        in
        [ Vdom.Node.div
            ~attrs:
              (Attr.role "gridcell"
               @ Attr.class_ [ "astryx-calendar__cell" ]
               @ (if state.is_selected || state.is_in_range then Attr.aria "selected" "true" else []))
            (bands @ button) ]
      in
      let cells_nodes = List.map states ~f:(fun (index, cell, state) -> render_cell (index, cell) state) in
      let week_number_cell =
        if not has_week_numbers
        then []
        else
          [ Vdom.Node.div
              ~attrs:(Attr.role "rowheader" @ Attr.class_ [ "astryx-calendar__week-number" ])
              [ Vdom.Node.text (string_of_int (Plain_date.get_week_number week_date)) ]
          ]
      in
      [ Vdom.Node.div
          ~attrs:(Attr.role "row" @ Attr.class_ [ "astryx-calendar__week-row" ])
          (week_number_cell @ List.concat cells_nodes) ]
    in
    let week_nodes = List.concat (List.map rows ~f:render_week) in
    [ Vdom.Node.div
        ~attrs:(Attr.class_ [ "astryx-calendar__month" ])
        [ Vdom.Node.div
            ~attrs:
              (Attr.role "grid"
               @ Attr.aria "label" (month_label month)
               @ (match mode with Range -> Attr.aria "multiselectable" "true" | Single -> [])
               @ Attr.class_
                   ([ "astryx-calendar__days" ]
                    @ (if has_week_numbers then [ "astryx-calendar__days--with-week-numbers" ] else []))
               @ [ Vdom.Attr.on_keydown (on_grid_keydown ~month) ])
            (day_name_row :: week_nodes) ] ]
  in
  let months_node =
    Vdom.Node.div
      ~attrs:(Attr.class_ [ "astryx-calendar__months" ])
      (List.concat (List.map months ~f:render_month))
  in
  (* Upstream announces through a document-level live region; the port draws
     the region in place, so the text is part of the tree. *)
  let live_text =
    match model.announced_label with
    | Some announced when String.equal announced months_label -> (match model.announce with Some m -> m | None -> "")
    | Some _ -> months_label
    | None -> ""
  in
  let live_region =
    Vdom.Node.div
      ~attrs:
        (Attr.class_ [ "astryx-visually-hidden" ]
         @ Attr.role "status"
         @ Attr.aria "live" "polite")
      [ Vdom.Node.text live_text ]
  in
  Vdom.Node.div
    ~attrs:
      (Attr.class_ [ "astryx-calendar" ]
       @ Attr.data "component" "Calendar"
       @ (match mode with Single -> Attr.data "mode" "single" | Range -> Attr.data "mode" "range")
       @ [ Vdom.Attr.create "id" (Option.value id ~default:"astryx-calendar") ]
       @ (match attrs with Some a -> a | None -> []))
    [ header ; months_node ; live_region ]
;;
