(* The collapsible state machine, ported from upstream Collapsible/useCollapsible.ts.
   See use_collapsible.mli for the contract and the group-context divergence. *)

open! Core
open! Bonsai_web

type config =
  { default_is_open : bool option
  ; is_open : bool Bonsai.t option
  ; on_open_change : (bool -> unit Effect.t) Bonsai.t option
  }

let component
  ?(config = { default_is_open = None; is_open = None; on_open_change = None })
  ~is_collapsible
  graph
  =
  let is_enabled = is_collapsible in
  match config.is_open with
  (* Controlled: the caller owns the state; toggle only reports. *)
  | Some is_open ->
    let on_open_change =
      match config.on_open_change with
      | Some f -> f
      | None -> Bonsai.return (fun (_ : bool) -> Effect.Many [])
    in
    Bonsai.map2 is_open on_open_change ~f:(fun is_open on_open_change ->
        let toggle () = on_open_change (not is_open) in
        (is_enabled, is_open, toggle))
  (* Uncontrolled: internal state is the source of truth. *)
  | None ->
    let initial =
      match config.default_is_open with None -> true | Some b -> b
    in
    let internal, set_internal = Bonsai.state initial graph in
    let on_open_change =
      match config.on_open_change with
      | Some f -> Bonsai.map f ~f:(fun f -> Some f)
      | None -> Bonsai.return None
    in
    Bonsai.map3 internal set_internal on_open_change
      ~f:(fun is_open set_internal on_open_change ->
        let toggle () =
          let next = not is_open in
          let effects =
            [ set_internal next ]
            @ (match on_open_change with
               | None -> []
               | Some f -> [ f next ])
          in
          Effect.Many effects
        in
        (is_enabled, is_open, toggle))
;;
