module Field_ = Field

open! Core
open! Bonsai_web
open! Js_of_ocaml

type orientation =
  | Horizontal
  | Vertical

type value_display =
  | Tooltip
  | Text
  | No_value

type mark =
  { value : float
  ; label : string option
  }

type t =
  | Single of float
  | Range of float * float

let thumb_size = 20.
let thumb_inset = thumb_size /. 2.

(* ------------------------------------------------------------------ pure math *)

let clamp val_ min max = Float.min (Float.max val_ min) max

let get_decimal_precision (num : float) : int =
  let s = Float.to_string num in
  let mantissa, exponent =
    match String.split ~on:'e' s with
    | [ m; e ] -> m, int_of_string e
    | [ m ] -> m, 0
    | _ -> s, 0
  in
  let decimals =
    match String.split ~on:'.' mantissa with
    | [ _; frac ] -> String.length frac
    | _ -> 0
  in
  decimals + Int.max 0 (-exponent)
;;

let snap_to_step (val_ : float) (min : float) (step : float) : float =
  if Float.(<=) step 0.
  then val_
  else (
    let steps = Float.round ((val_ -. min) /. step) in
    let snapped = min +. (steps *. step) in
    let precision =
      Int.min (Int.max (get_decimal_precision min) (get_decimal_precision step)) 20
    in
    float_of_string (Printf.sprintf "%.*f" precision snapped))
;;

let get_percent (val_ : float) (min : float) (max : float) : float =
  if Float.equal max min then 0. else ((val_ -. min) /. (max -. min)) *. 100.
;;

let css_length (percent : float) (px : float) : string =
  let f3 n = Printf.sprintf "%.3f" n in
  Printf.sprintf "calc(%s%% %s %spx)" (f3 percent) (if Float.(<) px 0. then "-" else "+") (f3 (Float.abs px))
;;

let inset_position (percent : float) : string =
  css_length percent (thumb_inset -. (percent /. 100.) *. thumb_size)
;;

let inset_span (from_percent : float) (to_percent : float) : string =
  let delta = to_percent -. from_percent in
  css_length delta (-.(delta /. 100.) *. thumb_size)
;;

let travel_fraction (offset : float) (size : float) : float =
  let travel = size -. thumb_size in
  if Float.(>) travel 0.
  then (offset -. thumb_inset) /. travel
  else if Float.(>) size 0. then offset /. size else 0.
;;

let get_value_from_position
      ~orientation
      ~min
      ~max
      ~step
      ~width
      ~height
      ~client_x
      ~client_y
      ~is_rtl
  : float
  =
  let percent =
    match orientation with
    | Horizontal ->
      let offset = if is_rtl then width -. client_x else client_x in
      travel_fraction offset width
    | Vertical -> 1. -. travel_fraction client_y height
  in
  let percent = clamp percent 0. 1. in
  let raw = min +. (percent *. (max -. min)) in
  clamp (snap_to_step raw min step) min max
;;

let values_of =
  function
  | Single v -> [ v ]
  | Range (v0, v1) -> [ v0; v1 ]
;;

let is_range_values = function [ _; _ ] -> true | _ -> false
;;

let update_range ~min ~max ~min_gap ~thumb_index ~new_val v0 v1 : float * float =
  let v0', v1' =
    if thumb_index = 0
    then Float.min new_val (v1 -. min_gap), v1
    else v0, Float.max new_val (v0 +. min_gap)
  in
  (clamp v0' min max), (clamp v1' min max)
;;

(* ------------------------------------------------------------------- js interop *)

let client_x (ev : Dom_html.pointerEvent Js.t) : float = Js.Unsafe.get ev "clientX"
let client_y (ev : Dom_html.pointerEvent Js.t) : float = Js.Unsafe.get ev "clientY"
let pointer_id (ev : Dom_html.pointerEvent Js.t) : int = Js.Unsafe.get ev "pointerId"

let rect_of (el : Dom_html.element Js.t) =
  (Js.Unsafe.meth_call el "getBoundingClientRect" [||] : Dom_html.clientRect Js.t)
;;
let rect_num (rect : Dom_html.clientRect Js.t) (name : string) : float = Js.Unsafe.get rect name


let is_rtl (el : Dom_html.element Js.t) : bool =
  let style = Js.Unsafe.meth_call Js.Unsafe.global "getComputedStyle" [| Js.Unsafe.inject el |] in
  String.equal (Js.to_string (Js.Unsafe.get style "direction")) "rtl"
;;

let el_of (ev : _ Js.t) : Dom_html.element Js.t option =
  match Js.Opt.to_option (Common.prop ev "currentTarget" : Dom_html.element Js.t Js.opt) with
  | Some el -> Some el
  | None -> None

let attr_of (el : _ Js.t) (name : string) : string option =
  match Js.Opt.to_option (Js.Unsafe.meth_call (Obj.magic el : _ Js.t) "getAttribute" [| Js.Unsafe.inject (Js.string name) |]) with
  | Some s -> Some (Js.to_string s)
  | None -> None
;;

let closest_el (el : Dom_html.element Js.t) (selector : string) : Dom_html.element Js.t option =
  match Js.Opt.to_option (Js.Unsafe.meth_call el "closest" [| Js.Unsafe.inject (Js.string selector) |]) with
  | Some e -> Some e
  | None -> None
;;

let modifiers (ev : _ Js.t) =
  Common.bool_prop ev "metaKey", Common.bool_prop ev "ctrlKey", Common.bool_prop ev "shiftKey", Common.bool_prop ev "altKey"
;;

let capture_pointer (el : Dom_html.element Js.t) (ev : Dom_html.pointerEvent Js.t) =
  match Js.Opt.to_option (Js.Unsafe.get el "setPointerCapture") with
  | None -> ()
  | Some _ -> Js.Unsafe.meth_call el "setPointerCapture" [| Js.Unsafe.inject (pointer_id ev) |]
;;

let fmt_num (v : float) : string = Printf.sprintf "%g" v

let display_value format_value v =
  match format_value with Some f -> f v | None -> fmt_num v
;;

(* -------------------------------------------------------------------- component *)

let view
      ?(id = "astryx-slider")
      ?(attrs = [])
      ~label
      ?(is_label_hidden = false)
      ?description
      ?(is_disabled = false)
      ?disabled_message
      ?(is_required = false)
      ?(is_optional = false)
      ?status
      ?width
      ?(label_tooltip = "")
      ?(min = 0.)
      ?(max = 100.)
      ?(step = 1.)
      ?(orientation = Horizontal)
      ?format_value
      ?(value_display = Tooltip)
      ?marks
      ?html_name
      ?(min_steps_between_thumbs = 0)
      ~value
      ~on_change
      ?on_change_end
      graph =
    let _ = label_tooltip in
  let horizontal = match orientation with Horizontal -> true | Vertical -> false in
  let min_gap = Float.of_int min_steps_between_thumbs *. step in
  let shows_disabled_message = is_disabled && Option.is_some disabled_message in
  let required_and_not_optional = is_required && not is_optional in
  let reason_id = id ^ "-reason" in
  let label_id = id ^ "-label" in
  let status_is_error =
    match status with
    | Some { Input_types.type_ = Input_types.Error; _ } -> true
    | _ -> false
  in

  let dragging, set_dragging = Bonsai.state None graph in
  let keyboard_focus, set_keyboard_focus = Bonsai.state None graph in
  let dragging_ref : int option ref = ref None in
  let pressed_ref : int option ref = ref None in

  let p1 = Bonsai.map2 set_dragging set_keyboard_focus ~f:Tuple2.create in
  let p2 = Bonsai.map2 p1 on_change ~f:(fun (sd, sk) oc -> (sd, sk, oc)) in
  let p3 =
    match on_change_end with
    | Some oc_end -> Bonsai.map2 p2 oc_end ~f:(fun (sd, sk, oc) oc_end -> (sd, sk, oc, Some oc_end))
    | None -> Bonsai.map p2 ~f:(fun (sd, sk, oc) -> (sd, sk, oc, None))
  in
  let p4 = Bonsai.map2 p3 dragging ~f:Tuple2.create in
  let ctx =
    Bonsai.map3 value p4 keyboard_focus
      ~f:(fun value_ ((sd, sk, oc, oc_end), dragging_now) keyboard_now ->
        let values = List.map (values_of value_) ~f:(fun v -> clamp v min max) in
        sd, sk, oc, oc_end, dragging_now, keyboard_now, values)
  in

  Bonsai.map ctx
    ~f:(fun (set_dragging, set_keyboard_focus, on_change_fn, on_change_end_fn, dragging_now, keyboard_now, values) ->
      let nth i = List.nth_exn values i in
      let is_range = is_range_values values in
      let emit value = on_change_fn value in
      let emit_end value =
        match on_change_end_fn with Some f -> f value | None -> Bonsai.Effect.Ignore
      in

      let track_value (ev : Dom_html.pointerEvent Js.t) : float =
        match el_of ev with
        | None -> min
        | Some track ->
          let rect = rect_of track in
          get_value_from_position
            ~orientation
            ~min
            ~max
            ~step
            ~width:(rect_num rect "width")
            ~height:(rect_num rect "height")
            ~client_x:(client_x ev -. rect_num rect "left")
            ~client_y:(client_y ev -. rect_num rect "top")
            ~is_rtl:(is_rtl track)
      in

      let mark_value (ev : Dom_html.pointerEvent Js.t) : float option =
        match Js.Opt.to_option (Common.prop (Obj.magic ev : _ Js.t) "target" : Dom_html.element Js.t Js.opt) with
        | Some target ->
          (match closest_el (Obj.magic target : Dom_html.element Js.t) "[data-astryx-mark-value]" with
           | Some mark_el -> Option.map (attr_of mark_el "data-astryx-mark-value") ~f:Float.of_string
           | None -> None)
        | None -> None
      in

      let closest_thumb new_value : int =
        match values with
        | [ v0; v1 ] -> if Float.(<=) (Float.abs (new_value -. v0)) (Float.abs (new_value -. v1)) then 0 else 1
        | _ -> 0
      in

      let range_result thumb_index (clamped : float) : t =
        match values with
        | [ v0; v1 ] ->
          let v0', v1' = update_range ~min ~max ~min_gap ~thumb_index ~new_val:clamped v0 v1 in
          Range (v0', v1')
        | [ _ ] -> Single clamped
        | _ -> Single clamped
      in

      let update_value thumb_index (new_val : float) : unit Bonsai.Effect.t =
        if is_disabled
        then Bonsai.Effect.Ignore
        else
          let clamped = clamp (snap_to_step new_val min step) min max in
          emit (range_result thumb_index clamped)
      in

      let fire_end thumb_index (clamped : float) : unit Bonsai.Effect.t =
        emit_end (range_result thumb_index (clamp clamped min max))
      in

      let on_track_down (ev : Dom_html.pointerEvent Js.t) : unit Bonsai.Effect.t =
        if is_disabled
        then Bonsai.Effect.Ignore
        else (
          Common.prevent_default ev;
          let new_value =
            match mark_value ev with Some v -> v | None -> track_value ev
          in
          let thumb_index = match !pressed_ref with Some i -> i | None -> closest_thumb new_value in
          pressed_ref := None;
          dragging_ref := Some thumb_index;
          (match el_of ev with Some track -> capture_pointer track ev | None -> ());
          Bonsai.Effect.Many
            [ set_dragging (Some thumb_index); set_keyboard_focus None; update_value thumb_index new_value ])
      in
      let on_track_move (ev : Dom_html.pointerEvent Js.t) : unit Bonsai.Effect.t =
        match !dragging_ref with
        | None -> Bonsai.Effect.Ignore
        | Some thumb_index -> if is_disabled then Bonsai.Effect.Ignore else update_value thumb_index (track_value ev)
      in
      let on_track_up (_ev : Dom_html.pointerEvent Js.t) : unit Bonsai.Effect.t =
        match !dragging_ref with
        | None -> Bonsai.Effect.Ignore
        | Some thumb_index ->
          dragging_ref := None;
          Bonsai.Effect.Many [ set_dragging None; fire_end thumb_index (nth thumb_index) ]
      in

      let thumb_attrs (i : int) : Vdom.Attr.t list =
        [ Vdom.Attr.create "role" "slider"
        ; Vdom.Attr.create "tabindex" (if is_disabled && not shows_disabled_message then "-1" else "0")
        ; Vdom.Attr.create "aria-valuemin"
            (fmt_num (if is_range && i = 1 then clamp (nth 0 +. min_gap) min max else min))
        ; Vdom.Attr.create "aria-valuemax"
            (fmt_num (if is_range && i = 0 then clamp (nth 1 -. min_gap) min max else max))
        ; Vdom.Attr.create "aria-valuenow" (fmt_num (nth i))
        ; Vdom.Attr.create "aria-orientation" (if horizontal then "horizontal" else "vertical")
        ; (if is_range
           then Vdom.Attr.create "aria-label" (if i = 0 then "Minimum value" else "Maximum value")
           else Vdom.Attr.create "aria-labelledby" label_id)
        ; (if is_disabled then Vdom.Attr.create "aria-disabled" "true" else Vdom.Attr.create "aria-hidden" "false")
        ; (if status_is_error then Vdom.Attr.create "aria-invalid" "true" else Vdom.Attr.create "aria-invalid" "false")
        ; Vdom.Attr.on_pointerdown (fun (ev : Dom_html.pointerEvent Js.t) ->
            pressed_ref := Some i;
            Bonsai.Effect.of_thunk (fun () -> Common.prevent_default ev))
        ; Vdom.Attr.on_keydown (fun (ev : Dom_html.keyboardEvent Js.t) ->
            let key = Option.value (Common.string_prop (Obj.magic ev : _ Js.t) "key") ~default:"" in
            let meta, ctrl, _shift, alt = modifiers (Obj.magic ev : _ Js.t) in
            let ring =
              if (not (String.equal key "Shift")) && not meta && not alt && not ctrl
              then set_keyboard_focus (Some i)
              else Bonsai.Effect.Ignore
            in
            let rtl_now =
              match el_of (Obj.magic ev : _ Js.t) with
              | Some el -> is_rtl el
              | None -> false
            in
            let toward_max = if horizontal && rtl_now then "ArrowLeft" else "ArrowRight" in
            let toward_min = if String.equal toward_max "ArrowLeft" then "ArrowRight" else "ArrowLeft" in
            let new_val =
              match key with
              | k when String.equal k toward_max || String.equal k "ArrowUp" -> nth i +. step
              | k when String.equal k toward_min || String.equal k "ArrowDown" -> nth i -. step
              | k when String.equal k "PageUp" -> nth i +. (step *. 10.)
              | k when String.equal k "PageDown" -> nth i -. (step *. 10.)
              | k when String.equal k "Home" -> min
              | k when String.equal k "End" -> max
              | _ -> Float.nan
            in
            if Float.is_nan new_val
            then Bonsai.Effect.Ignore
            else (
              (if is_disabled
               then ()
               else Common.prevent_default ev);
              let to_bound = String.equal key "Home" || String.equal key "End" in
              let clamped = clamp (if to_bound then new_val else snap_to_step new_val min step) min max in
              Bonsai.Effect.Many
                [ ring; update_value i clamped; fire_end i clamped ]))
        ; Vdom.Attr.on_focus (fun _ -> set_keyboard_focus None)
        ; Vdom.Attr.on_blur (fun _ -> set_keyboard_focus None)
        ]
      in

      let thumb_node i =
        let p = get_percent (nth i) min max in
        let pos =
          if horizontal
          then Common.Attr.style [ "inset-inline-start", inset_position p ]
          else Common.Attr.style [ "bottom", inset_position p; "left", "50%" ]
        in
        let class_tokens =
          [ "astryx-slider__thumb" ]
          @ (if is_disabled then [ "astryx-slider__thumb--disabled" ] else [])
          @ (if Poly.equal dragging_now (Some i) then [ "astryx-slider__thumb--pressed" ] else [])
          @ (if Poly.equal keyboard_now (Some i) then [ "astryx-slider__thumb--keyboard-focus" ] else [])
        in
        Vdom.Node.div
          ~attrs:
            ([ Vdom.Attr.id (if is_range then id ^ "-thumb-" ^ Int.to_string i else id)
             ; Vdom.Attr.create "data-astryx-slider-thumb" (Int.to_string i)
             ]
            @ thumb_attrs i
            @ Common.Attr.class_ class_tokens
            @ pos)
          []
      in

      let bubbles =
        if Poly.equal value_display Tooltip
        then
          List.mapi values ~f:(fun i _ ->
            let p = get_percent (nth i) min max in
            let pos =
              if horizontal
              then Common.Attr.style [ "inset-inline-start", inset_position p ]
              else Common.Attr.style [ "bottom", inset_position p; "left", "50%" ]
            in
            Vdom.Node.div
              ~attrs:(Common.Attr.class_ [ "astryx-slider__bubble" ] @ Vdom.Attr.create "aria-hidden" "true" :: pos)
              [ Vdom.Node.text (display_value format_value (nth i)) ])
        else []
      in

      let mark_nodes =
        match marks with
        | None -> []
        | Some marks ->
          [ Vdom.Node.div
              ~attrs:(Common.Attr.class_ [ "astryx-slider__marks" ] @ [ Vdom.Attr.create "aria-hidden" "true" ])
              (List.map marks ~f:(fun mark ->
                   let p = get_percent mark.value min max in
                   let pos =
                     if horizontal
                     then Common.Attr.style [ "inset-inline-start", inset_position p ]
                     else Common.Attr.style [ "bottom", inset_position p ]
                   in
                   let filled =
                     match values with
                     | [ v0; v1 ] -> Float.(>=) mark.value v0 && Float.(<=) mark.value v1
                     | [ v0 ] -> Float.(<=) mark.value v0
                     | _ -> false
                   in
                   let mark_el =
                     Vdom.Node.div
                       ~attrs:
                         (Common.Attr.class_
                            ([ "astryx-slider__mark" ] @ if filled then [ "astryx-slider__mark--filled" ] else [])
                         @ [ Vdom.Attr.create "data-astryx-mark-value" (fmt_num mark.value)
                           ; Vdom.Attr.create "aria-hidden" "true"
                           ]
                         @ pos)
                       []
                   in
                   match mark.label with
                   | Some l ->
                     Vdom.Node.div
                       ~attrs:[ Vdom.Attr.class_ "astryx-slider__mark-wrap" ]
                       [ mark_el
                       ; Vdom.Node.span
                           ~attrs:
                             (Common.Attr.class_ [ "astryx-slider__mark-label" ]
                             @ [ Vdom.Attr.create "aria-hidden" "true" ]
                             @ pos)
                           [ Vdom.Node.text l ]
                       ]
                   | None -> mark_el))
        ]
      in

      let rail =
        Vdom.Node.div
          ~attrs:(Common.Attr.class_ [ "astryx-slider__rail" ] @ [ Vdom.Attr.create "aria-hidden" "true" ])
          []
      in
      let fill_style =
        match values with
        | [ v0; v1 ] ->
          let p0 = get_percent v0 min max in
          let p1 = get_percent v1 min max in
          if horizontal
          then [ "inset-inline-start", inset_position p0; "width", inset_span p0 p1 ]
          else [ "bottom", inset_position p0; "height", inset_span p0 p1 ]
        | [ v0 ] ->
          let p = get_percent v0 min max in
          if horizontal then [ "inset-inline-start", "0%"; "width", inset_position p ] else [ "bottom", "0%"; "height", inset_position p ]
        | _ -> []
      in
      let fill =
        Vdom.Node.div
          ~attrs:(Common.Attr.class_ [ "astryx-slider__fill" ] @ Common.Attr.style fill_style @ [ Vdom.Attr.create "aria-hidden" "true" ])
          []
      in

      let children =
        mark_nodes
        @ [ rail; fill ]
        @ (List.mapi values ~f:(fun i _ -> thumb_node i))
        @ bubbles
      in

      let track =
        Vdom.Node.div
          ~attrs:
            (Common.Attr.class_ ([ "astryx-slider__track" ] @ if horizontal then [] else [ "astryx-slider__track--vertical" ])
            @ [ Vdom.Attr.create "tabindex" "-1" ]
            @ (if is_range then [ Vdom.Attr.create "role" "group"; Vdom.Attr.create "aria-labelledby" label_id ] else [])
            @ [ Vdom.Attr.on_pointerdown on_track_down
              ; Vdom.Attr.on_pointermove on_track_move
              ; Vdom.Attr.on_pointerup on_track_up
              ])
          children
      in

      let reason_nodes =
        if shows_disabled_message
        then
          [ Vdom.Node.div
              ~attrs:(Common.Attr.class_ [ "astryx-slider__disabled-reason" ] @ [ Vdom.Attr.id reason_id ])
              [ Vdom.Node.text (Option.value_exn disabled_message) ]
          ]
        else []
      in
      let hidden_inputs =
        match html_name with
        | None -> []
        | Some name ->
          List.mapi values ~f:(fun i v ->
            Vdom.Node.create
              "input"
              ~attrs:
                [ Vdom.Attr.create "type" "hidden"
                ; Vdom.Attr.create "name" name
                ; Vdom.Attr.create "value" (fmt_num v)
                ; (if is_disabled then Vdom.Attr.create "disabled" "" else Vdom.Attr.create "data-slider-hidden" (Int.to_string i))
                ]
              [])
      in
      let text_nodes =
        if Poly.equal value_display Text
        then
          [ Vdom.Node.span
              ~attrs:[ Vdom.Attr.class_ "astryx-slider__text-value" ]
              (match values with
               | [ v0; v1 ] ->
                 [ Vdom.Node.text (sprintf "%s \xe2\x80\x93 %s" (display_value format_value v0) (display_value format_value v1)) ]
               | [ v0 ] -> [ Vdom.Node.text (display_value format_value v0) ]
               | _ -> [])
          ]
        else []
      in
      let row =
        Vdom.Node.div
          ~attrs:
            (Common.Attr.class_ ([ "astryx-slider" ] @ if horizontal then [] else [ "astryx-slider--vertical" ])
            @ Common.Attr.data "component" "Slider"
            @ (if is_disabled then Common.Attr.class_ [ "astryx-slider--disabled" ] else [])
            @ [ Vdom.Attr.id id ]
            @ attrs)
          (hidden_inputs @ [ track ] @ text_nodes @ reason_nodes)
      in
      let required_nodes =
        if required_and_not_optional
        then
          [ Vdom.Node.span ~attrs:[ Vdom.Attr.class_ "astryx-visually-hidden"; Vdom.Attr.id (id ^ "-required") ] [ Vdom.Node.text "Required" ] ]
        else []
      in
      Field_.view
        ~label
        ~input_id:id
        ~label_id
        ~is_group_label:true
        ~is_label_hidden
        ?description
        ~is_disabled
        ~is_required
        ~is_optional
        ?status
        ~status_variant:Field_.Detached
        ?width
        ~children:([ row ] @ required_nodes)
        ())
;;
