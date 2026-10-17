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
