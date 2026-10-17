open Js_of_ocaml
open! Core

type segment =
  | Text of string
  | Link of link

and link =
  { href : string
  ; label : string
  ; is_external : bool
  }

type match_ =
  { start : int
  ; stop : int
  ; href : string
  ; label : string
  ; is_external : bool
  }

(* Declared in the interface too, as every type here is: an .mli that names a type requires the
   implementation to define it, and the first build after adding the scanner to the interface failed
   exactly because this one was missing. *)
type pattern =
  { source : string
  ; flags : string
  ; href : string list -> string
  ; label : (string list -> string) option
  ; is_external : bool
  }

let segments_of_matches ~text matches =
  (* Stable, and by start only. Upstream's comment says "sort by start position, then by earlier pattern
     priority (stable sort)" while the comparator compares nothing but start: the priority tie-break is
     the collection order holding because the sort is stable. Relying on that deliberately means the
     stability has to be deliberate here too. *)
  let ordered = List.stable_sort matches ~compare:(fun a b -> Int.compare a.start b.start) in
  let kept =
    List.fold ordered ~init:(0, []) ~f:(fun (last_stop, acc) m ->
      (* [>=] not [>]: a match that begins exactly where the previous ended is adjacent, not overlapping,
         and upstream keeps it. *)
      if m.start >= last_stop then m.stop, m :: acc else last_stop, acc)
    |> snd
    |> List.rev
  in
  let pieces, last_index =
    List.fold kept ~init:([], 0) ~f:(fun (acc, last_index) m ->
      let acc =
        if m.start > last_index
        then
          Text (String.sub text ~pos:last_index ~len:(m.start - last_index))
          :: acc
        else acc
      in
      ( Link { href = m.href; label = m.label; is_external = m.is_external } :: acc
      , m.stop ))
  in
  let pieces =
    if last_index < String.length text
    then Text (String.sub text ~pos:last_index ~len:(String.length text - last_index)) :: pieces
    else pieces
  in
  List.rev pieces
;;

(* ----------------------------------------------------------------- the scanner *)

(* One JS call per pattern collects every hit, rather than looping across the boundary. The first attempt
   at a helper like this in this project returned a JS array typed as an OCaml list, which does not
   convert: the list read the array's first slot as its head and its SECOND as its tail, so the next
   element was undefined and measuring it threw. Every crossing here is therefore an explicit conversion -
   Js.to_array, then Js.to_string - and never a silent one. *)
let scan_js =
  Js.Unsafe.eval_string
    {|(function (source, flags, text) {
        var re = new RegExp(source, flags);
        var out = [];
        var m;
        while ((m = re.exec(text)) !== null) {
          if (m[0].length === 0) { re.lastIndex = re.lastIndex + 1; continue; }
          out.push({ index: m.index, groups: Array.prototype.slice.call(m) });
        }
        return out;
      })|}
;;

let scan (pattern : pattern) ~text : (int * string list) list =
  let raw =
    Js.Unsafe.fun_call
      scan_js
      [| Js.Unsafe.inject (Js.string pattern.source)
       ; Js.Unsafe.inject (Js.string pattern.flags)
       ; Js.Unsafe.inject (Js.string text)
      |]
  in
  let arr : Js.Unsafe.any Js.js_array Js.t = Js.Unsafe.coerce raw in
  Array.to_list (Js.to_array arr)
  |> List.map ~f:(fun hit ->
    let index : int = Js.Unsafe.get hit "index" in
    let groups : string list =
      Js.Unsafe.get hit "groups"
      |> Js.Unsafe.coerce
      |> Js.to_array
      |> Array.to_list
      |> List.map ~f:Js.to_string
    in
    index, groups)
;;

let label_of (pattern : pattern) groups = Option.value_map pattern.label ~default:(List.hd_exn groups) ~f:(fun f -> f groups)

let find_matches ~text ~patterns =
  List.concat
    (List.map patterns ~f:(fun pattern ->
       List.map (scan pattern ~text) ~f:(fun (start, groups) ->
         let matched = List.hd_exn groups in
         { start
         ; stop = start + String.length matched
         ; href = pattern.href groups
         ; label = label_of pattern groups
         ; is_external = pattern.is_external
         })))
;;

let url_pattern =
  { source = "https?:\\/\\/[^\\s<>'\")\\]},]+"
  ; flags = "g"
  ; href = (fun groups -> List.hd_exn groups)
  ; label = None
  ; is_external = true
  }
;;

let email_pattern =
  { source = "[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}"
  ; flags = "g"
  ; href = (fun groups -> "mailto:" ^ List.hd_exn groups)
  ; label = None
  ; is_external = false
  }
;;

let builtins = [ url_pattern; email_pattern ]
