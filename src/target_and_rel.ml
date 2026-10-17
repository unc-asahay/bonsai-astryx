open! Core

(* The tokens appended to a _blank target's rel, in upstream's order. *)
let blank_target_rel_tokens = [ "noopener"; "noreferrer" ]

let compute ~target ~rel =
  match target with
  | Some "_blank" ->
    (* Split on runs of whitespace, dropping empties, exactly as `rel?.split(/\s+/).filter(Boolean)`
       does. `String.split` with `on_chars` keeps empties, which would produce a double space in the
       join below. *)
    let tokens =
      Option.value_map rel ~default:[] ~f:(fun rel ->
        (* The ASCII whitespace JS's \\s matches, written out because String.split takes the characters
           rather than a predicate. A Unicode space (U+00A0, U+2009) therefore splits here where upstream
           would not - a divergence in the direction of splitting more, on inputs a rel attribute does not
           carry in practice. *)
        (* Whitespace runs, not a single delimiter: every whitespace character is folded to a space
           first, because Core's String.split takes one character rather than a set. The comment above
           about ASCII vs Unicode still applies. *)
        String.map rel ~f:(fun c -> if Char.is_whitespace c then ' ' else c)
        |> String.split ~on:' '
        |> List.filter ~f:(Fn.non String.is_empty))
    in
    (* case-sensitive, as upstream is: see the interface. *)
    let tokens =
      List.fold blank_target_rel_tokens ~init:tokens ~f:(fun tokens token ->
        if List.mem tokens token ~equal:String.equal then tokens else tokens @ [ token ])
    in
    (* `target` is still the outer string option: the pattern matched on its CONTENTS, so this is
       already Some "_blank". Wrapping it again is a string option option, which the type checker
       caught. *)
    target, Some (String.concat ~sep:" " tokens)
  | _ -> target, rel
;;
