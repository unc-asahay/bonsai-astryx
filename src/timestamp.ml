(* Copyright (c) Meta Platforms, Inc. and affiliates.
   Ported to OCaml/Bonsai from the astryx Timestamp component: Timestamp.tsx,
   formatInstant.ts, formatRelativeTime.ts, tooltipEntries.ts and
   TimestampHoverCard.tsx.

   A formatted timestamp on a semantic <time> element. The visible text always
   reads in the viewer's own zone (upstream's rule — no time zone is handed to
   Intl for it), the card names others. All Intl work is delegated to the host
   through a single evaluated object, so whatever the browser's Intl knows is
   what the port knows; locale is fixed at "en" (see the mli's divergences). *)

open! Core
open! Bonsai_web
open Js_of_ocaml

module Attr = Common.Attr

type value =
  | Str of string
  | Num of float
;;

type format =
  | Relative
  | Relative_short
  | Auto
  | Date
  | Date_long
  | Date_weekday
  | Date_time
  | Time
  | System_date
  | System_date_time
  | System_time
  | Unix_seconds
;;

type instant_format =
  | Instant of format
  | Full
;;

type relative_style =
  | Long
  | Narrow
;;

type tooltip_entry =
  { timezone_id : string option
  ; format : instant_format option
  ; label : string option
  ; is_copyable : bool
  }
;;

type tooltip_line =
  { label : string option
  ; value : string
  ; is_copyable : bool
  }
;;

(* ----------------------------------------------------------------------- JS *)

(* The port's one Intl dependency: [Intl.DateTimeFormat] /
   [Intl.RelativeTimeFormat] / [Intl.formatToParts], evaluated on the host.
   Formatters are cached by key so a live timestamp doesn't rebuild one per
   tick; an unrecognized time zone (which makes the constructor throw) yields
   an empty string here and is handled by the caller's resolution, and a host
   without the required Intl data answers "" — rendering nothing at all, the
   upstream failure mode for an unparseable value. *)
let intl_js =
  Js.Unsafe.pure_js_expr
    "(function(){\
var F={},R={};\
function fmt(ms,f,tz,shown,style,loc){\
var o;\
if(f==='full'){o={year:'numeric',month:'long',day:'numeric',hour:'numeric',minute:'2-digit',second:'2-digit'};o.timeZoneName=style||'short';}\
else if(f==='date'){o={year:'numeric',month:'short',day:'numeric'};}\
else if(f==='date_long'){o={year:'numeric',month:'long',day:'numeric'};}\
else if(f==='date_weekday'){o={weekday:'short',month:'short',day:'numeric',year:'numeric'};}\
else if(f==='date_time'){o={year:'numeric',month:'short',day:'numeric',hour:'numeric',minute:'2-digit'};if(shown){o.timeZoneName='short';}}\
else if(f==='time'){o={hour:'numeric',minute:'2-digit'};if(shown){o.timeZoneName='short';}}\
else{return '';}\
if(f!=='time'){o.calendar='gregory';}\
if(tz){o.timeZone=tz;}\
var k=(loc||'en')+'|'+f+'|'+(tz||'')+'|'+(style||'')+'|'+(shown?1:0);\
var x=F[k];if(!x){try{x=F[k]=new Intl.DateTimeFormat(loc||'en',o);}catch(e){x=null;}}\
if(!x){return '';}\
return x.format(new Date(ms));\
}\
function rel(value,unit,style,numeric,loc){\
var k=(loc||'en')+'|'+style+'|'+numeric;\
var x=R[k];if(!x){try{x=R[k]=new Intl.RelativeTimeFormat(loc||'en',{numeric:numeric,style:style});}catch(e){x=null;}}\
if(!x){return '';}\
return x.format(value,unit);\
}\
function parts(instant,tz){\
try{\
var o={year:'numeric',month:'2-digit',day:'2-digit',hour:'2-digit',minute:'2-digit',second:'2-digit',hourCycle:'h23',calendar:'gregory'};\
if(tz){o.timeZone=tz;}\
var p=new Intl.DateTimeFormat('en-US',o).formatToParts(new Date(instant));\
var x={};\
for(var i=0;i<p.length;i++){if(p[i].type!=='literal'){x[p[i].type]=p[i].value;}}\
return {ok:1,y:+x.year,m:+x.month,d:+x.day,h:+x.hour,mi:+x.minute,s:+x.second};\
}catch(e){return {ok:0,y:0,m:0,d:0,h:0,mi:0,s:0};}\
}\
function vtz(tz){try{new Intl.DateTimeFormat('en-US',{timeZone:tz});return 1;}catch(e){return 0;}}\
function parse(s){var d=new Date(s);var t=d.getTime();return {ok:(isNaN(t)?0:1),ms:t};}\
function iso(ms){return new Date(ms).toISOString();}\
return {fmt:fmt,rel:rel,parts:parts,vtz:vtz,parse:parse,iso:iso};\
})()"
;;

let js_str s = Js.Unsafe.inject (Js.string s)
let js_num f = Js.Unsafe.inject (Js.number_of_float f)
let js_bool b = Js.Unsafe.inject (Js.bool b)
let call name args = Js.Unsafe.fun_call (Js.Unsafe.get intl_js name) args
let call_str name args = Js.to_string (Js.Unsafe.coerce (call name args))

let now_ms () : float = Js.to_float (Js.Unsafe.coerce (Js.Unsafe.eval_string "Date.now()"))

(* A fresh card id per mounted instance — the HoverCard requires one, upstream
   gets one from React's useId. *)
let next_card_id = ref 0
let fresh_card_id () = incr next_card_id; sprintf "timestamp-card-%d" !next_card_id

(* The copy affordance's JS: writes through navigator.clipboard, calls
   [on_result 1] on success and [on_result 0] after 1500 ms, or [on_result 0]
   on rejection — the "silent no-op" upstream's useClipboard documents. Built
   once per instance (a cell), because it is stateful only in the JS timer. *)
let copy_impl_js =
  Js.Unsafe.pure_js_expr
    "(function(){\
return function(text,onResult){\
var n=(window.navigator||navigator);\
if(n&&n.clipboard&&n.clipboard.writeText){\
n.clipboard.writeText(text).then(function(){\
setTimeout(function(){onResult(0);},1500);\
onResult(1);\
}).catch(function(){onResult(0);});\
}else{onResult(0);}\
};\
})()"
;;

(* ----------------------------------------------------------------- helpers *)

let pad n = Printf.sprintf "%02d" n

let wall_clock ~ms ~(zone : string) : int * int * int * int * int * int =
  let r = call "parts" [| js_num ms; js_str zone |] in
  let get name = Js.to_float (Js.Unsafe.get r name) |> int_of_float in
  if Js.to_bool (Js.Unsafe.get r "ok")
  then get "y", get "m", get "d", get "h", get "mi", get "s"
  else
    (* The named zone is not one Intl accepts (an invalid identifier, or a
       host with no Intl). Fall back to the viewer's own zone — same shape,
       and it cannot crash: resolveTimezoneID validated before we get here. *)
    let r = call "parts" [| js_num ms; js_str "" |] in
    if Js.to_bool (Js.Unsafe.get r "ok")
    then get "y", get "m", get "d", get "h", get "mi", get "s"
    else 0, 0, 0, 0, 0, 0
;;

let zone_parts ~ms ~timezone_id = wall_clock ~ms ~zone:timezone_id

let name_of_instant_format = function
  | Full -> "full"
  | Instant Date -> "date"
  | Instant Date_long -> "date_long"
  | Instant Date_weekday -> "date_weekday"
  | Instant Date_time -> "date_time"
  | Instant Time -> "time"
  | Instant _ -> assert false
;;

let style_name = function `Short -> "short" | `Long -> "long"

let relative_style_name = function Long -> "long" | Narrow -> "narrow"

(* ------------------------------------------------------------------ format *)

let format_instant
    ~ms
    fmt
    ?timezone_id
    ?(is_timezone_shown = false)
    ?(timezone_name_style = `Short)
    ?(locale = "en")
    ()
  =
  match fmt with
  | Instant (Relative | Relative_short | Auto) ->
    invalid_arg "Timestamp.format_instant: a relative format names no instant"
  | Instant (System_date | System_date_time | System_time as f) ->
    let y, mo, d, h, mi, s = wall_clock ~ms ~zone:(Option.value timezone_id ~default:"") in
    (match f with
     | System_date -> sprintf "%d-%s-%s" y (pad mo) (pad d)
     | System_date_time -> sprintf "%d-%s-%s %s:%s:%s" y (pad mo) (pad d) (pad h) (pad mi) (pad s)
     | System_time -> sprintf "%s:%s:%s" (pad h) (pad mi) (pad s)
     | _ -> assert false)
  | Instant Unix_seconds ->
    (* Zone-independent by construction: how many seconds have elapsed is the
       same in every zone — and timeZone is ignored here, as upstream says. *)
    Int64.to_string (Int64.of_float (Stdlib.Float.floor (ms /. 1000.)))
  | (Instant (Date | Date_long | Date_weekday | Date_time | Time) | Full) ->
    call_str
      "fmt"
      [| js_num ms
       ; js_str (name_of_instant_format fmt)
       ; js_str (Option.value timezone_id ~default:"")
       ; js_bool is_timezone_shown
       ; js_str (style_name timezone_name_style)
       ; js_str locale
      |]
;;

let format_relative_time ~date_ms ~now_ms style ?(locale = "en") () =
  let diff_seconds = Float.round ((now_ms -. date_ms) /. 1000.) in
  let abs_diff = Float.abs diff_seconds in
  (* At (or a hair before/after) the present — the wider future tolerance
     absorbs realistic clock skew, as upstream's FUTURE_SKEW_TOLERANCE does. *)
  if Float.(<) abs_diff 10. || (Float.(<) diff_seconds 0. && Float.(<=) abs_diff 30.)
  then
    call_str
      "rel"
      [| js_num 0.
       ; js_str "second"
       ; js_str (relative_style_name style)
       ; js_str "auto"
       ; js_str locale
      |]
  else
    let count, unit =
      if Float.(<) abs_diff 60.
      then abs_diff, "second"
      else if Float.(<) abs_diff 3600.
      then Float.round_down (abs_diff /. 60.), "minute"
      else if Float.(<) abs_diff 86400.
      then Float.round_down (abs_diff /. 3600.), "hour"
      else if Float.(<) abs_diff (30. *. 86400.)
      then Float.round_down (abs_diff /. 86400.), "day"
      else if Float.(<) abs_diff (365. *. 86400.)
      then Float.round_down (abs_diff /. (30. *. 86400.)), "month"
      else Float.round_down (abs_diff /. (365. *. 86400.)), "year"
    in
    let value = if Float.(<) diff_seconds 0. then count else -.count in
    (* The long form keeps the "yesterday" idiom; the compact form is always
       numeric ("1d ago"), as upstream decides. *)
    let numeric =
      match style, unit, value with
      | Long, "day", -1. -> "auto"
      | _ -> "always"
    in
    call_str
      "rel"
      [| js_num value
       ; js_str unit
       ; js_str (relative_style_name style)
       ; js_str numeric
       ; js_str locale
      |]
;;

(* ------------------------------------------------------------------ entries *)

(* Zone identifiers already reported as unknown: one report per bad identifier,
   however many renders show it — upstream's warnedTimezoneIDs. *)
let warned_timezone_ids : (string, unit) Hashtbl.t = Hashtbl.Poly.create ()

let resolve_timezone_id = function
  | None -> None
  | Some id when String.equal (String.lowercase id) "local" -> None
  | Some id ->
    if Js.to_bool (call "vtz" [| js_str id |])
    then Some id
    else (
      if not (Hashtbl.mem warned_timezone_ids id)
      then Hashtbl.set warned_timezone_ids ~key:id ~data:();
      (* An unknown identifier degrades to the viewer's zone, not a throw. *)
      None)
;;

let zone_key = function None -> "local" | Some z -> String.lowercase z

let should_show_zone_name ~format ~has_multiple_zones ~is_named_zone =
  match format with
  | Full -> true
  | Instant (Date_time | Time) -> has_multiple_zones || is_named_zone
  | _ -> false
;;

let format_tooltip_lines ~ms entries =
  let resolved = List.map entries ~f:(fun e -> resolve_timezone_id e.timezone_id) in
  let has_multiple_zones =
    let keys = List.map resolved ~f:zone_key in
    match keys with
    | [] | [ _ ] -> false
    | first_key :: rest -> List.exists rest ~f:(fun k -> not (String.equal k first_key))
  in
  List.mapi entries ~f:(fun index entry ->
    let format = Option.value entry.format ~default:Full in
    let timezone = List.nth_exn resolved index in
    { label = entry.label
    ; is_copyable = entry.is_copyable
    ; value =
        format_instant
          ~ms
          format
          ?timezone_id:timezone
          ~is_timezone_shown:
            (should_show_zone_name ~format ~has_multiple_zones ~is_named_zone:(Option.is_some timezone))
          ()
    })
;;

(* -------------------------------------------------------------------- view *)

type render_info =
  { time_node : Vdom.Node.t
  ; card_node : Vdom.Node.t
  ; show_tooltip : bool
  }

let is_parseable = function
  | Str s ->
    let r = call "parse" [| js_str s |] in
    Js.to_bool (Js.Unsafe.get r "ok")
  | Num n -> Float.is_finite n
;;

let date_ms_of_value = function
  | Str s ->
    let r = call "parse" [| js_str s |] in
    Js.to_float (Js.Unsafe.get r "ms")
  | Num n -> if Float.(<) n 1e12 then n *. 1000. else n
;;

let view
    ?(format = Auto)
    ?(auto_threshold = 604_800.)
    ?(has_tooltip = true)
    ?tooltip_entries
    ?(is_timezone_shown = false)
    ?(is_live = false)
    ?(type_ = Text.Supporting)
    ?size
    ?(color = Text.Secondary)
    ?weight
    ?id
    ?(attrs = [])
    ~value
    (graph : Bonsai.graph)
  =
  (* An unparseable value renders nothing (upstream's behaviour); the port
     reports the intent through a hidden probing node instead of a dev-only
     console warn — see the mli. *)
  match value with
  | Str _ | Num _ when not (is_parseable value) ->
    Bonsai.return
      (Vdom.Node.div
         ~attrs:
           (Attr.class_ [ "astryx-visually-hidden" ]
            @ Attr.data "component" "Timestamp"
            @ Attr.data "invalid" "true"
            @ attrs)
         [])
  | _ ->
    let date_ms = date_ms_of_value value in
    let iso_string = call_str "iso" [| js_num date_ms |] in
    let card_id = Option.value id ~default:(fresh_card_id ()) in
    let now, set_now = Bonsai.state (now_ms ()) graph in
    let copied, set_copied = Bonsai.state ([] : (int * bool) list) graph in
    let announce, set_announce = Bonsai.state "" graph in
    let copy_impl, _ = Bonsai.state copy_impl_js graph in
    (* Everything the render reads, in one value: the text and the card both
       change with [now] (a live reading's precision dictates its own interval)
       and the copy state. *)
    let render =
      let a1 = Bonsai.map2 now set_now ~f:(fun n s -> n, s) in
      let a2 = Bonsai.map2 a1 copied ~f:(fun (n, s) c -> (n, s), c) in
      let a3 = Bonsai.map2 a2 set_copied ~f:(fun t s -> t, s) in
      let a4 = Bonsai.map2 a3 announce ~f:(fun t a -> t, a) in
      let a5 = Bonsai.map2 a4 set_announce ~f:(fun t s -> t, s) in
      let a6 = Bonsai.map2 a5 copy_impl ~f:(fun t c -> t, c) in
      Bonsai.map a6 ~f:(fun
        ((((((now, set_now), copied), set_copied), announce), set_announce), copy_impl) ->
        let diff_seconds = Float.round ((now -. date_ms) /. 1000.) in
        let effective =
          match format with
          | Auto ->
            if Float.(<=) (Float.abs diff_seconds) auto_threshold then Relative else Date_time
          | f -> f
        in
        let is_relative =
          match effective with Relative | Relative_short -> true | _ -> false
        in
        let display_text =
          match effective with
          | Relative -> format_relative_time ~date_ms ~now_ms:now Long ()
          | Relative_short -> format_relative_time ~date_ms ~now_ms:now Narrow ()
          | (Date | Date_long | Date_weekday | Date_time | Time as f) ->
            format_instant ~ms:date_ms (Instant f) ~is_timezone_shown ()
          | (System_date | System_date_time | System_time | Unix_seconds as f) ->
            format_instant ~ms:date_ms (Instant f) ()
          | Auto -> ""
        in
        (* The full absolute reading: visible on the card, spelled out in the
           aria-label (WCAG 3.1.4 — an abbreviation like "PST" reads as an
           unexpanded initialism to a screen reader). *)
        let full_absolute = format_instant ~ms:date_ms Full () in
        let aria_label = format_instant ~ms:date_ms Full ~timezone_name_style:`Long () in
        (* An empty array is not a second way to spell "off"; and entry
           presence opens the surface for absolute formats too. *)
        let entries =
          match tooltip_entries with
          | Some es when not (List.is_empty es) -> Some es
          | _ -> None
        in
        let show_tooltip = has_tooltip && (is_relative || Option.is_some entries) in
        let lines =
          match entries with
          | Some es -> format_tooltip_lines ~ms:date_ms es
          | None -> [ { label = None; value = full_absolute; is_copyable = true } ]
        in
        (* Live readings re-arm at the precision the reading itself dictates:
           under a minute every second, under an hour every 30 s, under a day
           every minute, beyond every 5 minutes — upstream's getLiveInterval. *)
        let interval_ms =
          if is_live && is_relative
          then
            let abs_diff = Float.abs diff_seconds in
            if Float.(<) abs_diff 60.
            then Some 1000.
            else if Float.(<) abs_diff 3600.
            then Some 30_000.
            else if Float.(<) abs_diff 86_400.
            then Some 60_000.
            else Some 300_000.
          else None
        in
        let time_attrs =
          [ Vdom.Attr.create "datetime" iso_string ]
          @ (if is_relative then Attr.aria "label" aria_label else [])
          @ (if show_tooltip then [ Vdom.Attr.create "tabindex" "0" ] else [])
          @ (match interval_ms with
             | Some _ ->
               [ Common.Interval_hook.attr ~interval_ms ~on_tick:(set_now (now_ms ())) ]
             | None -> [])
          @ Attr.data "component" "Timestamp"
          @ attrs
        in
        let time_ctrl =
          Vdom.Node.create "time" ~attrs:time_attrs [ Vdom.Node.text display_text ]
        in
        let time_node = Text.view ~type_ ?size ~color ?weight [ time_ctrl ] in
        (* The card: one row per entry, in a <dl> grid — label column when any
           row is labelled, action column when any row is copyable; the cells
           align down the shared columns, as upstream's grid templates do. *)
        let has_label_column =
          List.exists lines ~f:(fun line ->
            match line.label with Some l -> not (String.is_empty l) | None -> false)
        in
        let has_action_column = List.exists lines ~f:(fun line -> line.is_copyable) in
        let grid_class =
          match has_label_column, has_action_column with
          | true, true -> "astryx-timestamp-card--label-action"
          | true, false -> "astryx-timestamp-card--label"
          | false, true -> "astryx-timestamp-card--action"
          | false, false -> "astryx-timestamp-card--value"
        in
        let copy_button index row_value =
          let is_copied =
            List.exists copied ~f:(fun (i, c) -> Int.equal i index && c)
          in
          let label =
            if is_copied then "Copied" else sprintf "Copy %s" row_value
          in
          Icon_button.view
            ~label
            ~icon:
              (Icon.view
                 ~size:Icon.Sm
                 ~color:Icon.Inherit
                 ~name:(if is_copied then "check" else "copy")
                 ())
            ~variant:Button.Ghost
            ~size:Button.Sm
            ~on_click:(fun _ ->
              let apply_result (flag : float) =
                let copied' =
                  if Float.(flag = 1.)
                  then
                    (index, true)
                    :: List.filter copied ~f:(fun (i, _) -> not (Int.equal i index))
                  else List.filter copied ~f:(fun (i, _) -> not (Int.equal i index))
                in
                Effect.Many
                  [ set_copied copied'
                  ; set_announce (if Float.(flag = 1.) then "Copied" else "")
                  ]
              in
              let on_result =
                Js.wrap_callback (fun (flag : float) ->
                  Effect.Expert.handle_non_dom_event_exn (apply_result flag))
              in
              ignore (Js.Unsafe.fun_call copy_impl [| js_str row_value; Js.Unsafe.inject on_result |]);
              Effect.Many [])
            ()
        in
        let row index line =
          Vdom.Node.div
            ~attrs:(Attr.class_ [ "astryx-timestamp-card__row" ])
            ((if has_label_column
              then
                [ Vdom.Node.dt
                    ~attrs:(Attr.class_ [ "astryx-timestamp-card__label" ])
                    [ Vdom.Node.text (Option.value line.label ~default:"") ]
                ]
              else [])
             @ [ Vdom.Node.dd
                   ~attrs:(Attr.class_ [ "astryx-timestamp-card__value" ])
                   [ Vdom.Node.text line.value ]
               ]
             @ (if has_action_column
                then
                  [ Vdom.Node.div
                      ~attrs:(Attr.class_ [ "astryx-timestamp-card__action" ])
                      (if line.is_copyable then [ copy_button index line.value ] else [])
                  ]
                else []))
        in
        let card_dl =
          Vdom.Node.dl
            ~attrs:
              (Attr.class_ [ "astryx-timestamp-card"; grid_class ]
               @ Attr.data "component" "TimestampCard")
            (List.mapi lines ~f:row)
        in
        (* The polite live region the copy announcement goes to: the port hosts
           its own, because it cannot ask the application for one. *)
        let announcer =
          if has_action_column
          then
            Vdom.Node.div
              ~attrs:(Attr.class_ [ "astryx-visually-hidden" ] @ Attr.role "status")
              [ Vdom.Node.text announce ]
          else Vdom.Node.none
        in
        let card_node =
          Vdom.Node.div
            ~attrs:(Attr.class_ [ "astryx-timestamp-card-wrap" ])
            [ card_dl; announcer ]
        in
        { time_node; card_node; show_tooltip })
    in
    let show_tooltip = Bonsai.map render ~f:(fun r -> r.show_tooltip) in
    let time_t = Bonsai.map render ~f:(fun r -> r.time_node) in
    let card_t = Bonsai.map render ~f:(fun r -> r.card_node) in
    (* The surface is the port's own HoverCard — the same three upstream
       passes: above, focus on the <time> tab stop, always indicated. The card
       only mounts while show_tooltip is true; the plain <time> is the
       card-less path, no tab stop, no wrapper (the hover card's aria lives on
       a wrapper this port owns). *)
    let with_card =
      Hover_card.view_t
        ~id:card_id
        ~label:"Timestamp details"
        ~placement:Hover_card.Above
        ~focus_trigger:Hover_card.Focus_always
        ~has_hover_indication:Hover_card.Indicate_show
        ~trigger_t:time_t
        ~content_t:card_t
        graph
    in
    Bonsai.map2 show_tooltip (Bonsai.both with_card time_t)
      ~f:(fun show (with_card, plain) -> if show then with_card else plain)
;;
