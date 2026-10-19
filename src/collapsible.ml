(* Collapsible + CollapsibleGroup, ported from upstream Collapsible/.
   See collapsible.mli for the contract and the divergences. *)

open! Core
open! Bonsai_web

module Attr = Common.Attr

open Js_of_ocaml

type chevron_position =
  | Start
  | End

type density =
  | Compact
  | Balanced
  | Spacious

type mode =
  | Single
  | Multiple

type item =
  { value : string
  ; trigger : Vdom.Node.t
  ; children : Vdom.Node.t list
  ; is_disabled : bool
  ; chevron_position : chevron_position option
  }

(* -------------------------------------------------- shared row renderer ---- *)

let density_trigger_class = function
  | Compact -> "astryx-collapsible__trigger--compact"
  | Balanced -> "astryx-collapsible__trigger--balanced"
  | Spacious -> "astryx-collapsible__trigger--spacious"
;;

let density_content_class = function
  | Compact -> "astryx-collapsible__content--compact"
  | Balanced -> "astryx-collapsible__content--balanced"
  | Spacious -> "astryx-collapsible__content--spacious"
;;

(* One disclosure row: root, trigger button (label + chevron), content region.
   The chevron's classes ride on the Icon's own wrapper span — the element a
   theme would target is the one that rotates, the same call Banner made. *)
let render_row
  ~(root_attrs : Vdom.Attr.t list)
  ~(is_open : bool)
  ~(toggle : unit -> unit Effect.t)
  ~(is_disabled : bool)
  ~(chevron_position : chevron_position)
  ~(divided : bool)
  ~(density : density option)
  ~(content_id : string)
  ~(trigger : Vdom.Node.t)
  ~(children : Vdom.Node.t list)
  =
  let chevron_class =
    Attr.class_
      ([ "astryx-collapsible__chevron" ]
       @ (match chevron_position with Start -> [ "astryx-collapsible__chevron--start" ] | End -> [])
       @ [ if is_open
           then "astryx-collapsible__chevron--expanded"
           else "astryx-collapsible__chevron--closed" ])
  in
  let glyph =
    match chevron_position with Start -> "chevronRight" | End -> "chevronDown"
  in
  let chevron =
    Icon.view
      ~size:Icon.Sm
      ~color:Icon.Secondary
      ~attrs:chevron_class
      ~name:glyph
      ()
  in
  let trigger_density =
    match density with Some d -> [ density_trigger_class d ] | None -> []
  in
  let content_density =
    match density with Some d -> [ density_content_class d ] | None -> []
  in
  let trigger_attrs =
    Attr.class_
      ([ "astryx-collapsible__trigger" ]
       @ (if is_disabled then [ "astryx-collapsible__trigger--disabled" ] else [])
       @ trigger_density)
    @ [ Vdom.Attr.create "type" "button"
      ; Vdom.Attr.create "aria-expanded" (if is_open then "true" else "false")
      ; Vdom.Attr.create "aria-controls" content_id
      ; Vdom.Attr.on_click
          (fun (_ : Dom_html.mouseEvent Js.t) ->
            (* Activation is guarded rather than left to the native
               [disabled] attribute, so the trigger keeps [aria-disabled]
               semantics and stays discoverable — the system-wide
               convention. *)
            if is_disabled then Effect.Ignore else toggle ())
      ]
    @ (if is_disabled
       then [ Vdom.Attr.create "aria-disabled" "true"; Vdom.Attr.create "tabindex" "-1" ]
       else [])
  in
  let trigger_label =
    Vdom.Node.span
      ~attrs:(Attr.class_ [ "astryx-collapsible__trigger-label" ])
      [ trigger ]
  in
  let button =
    Vdom.Node.button
      ~attrs:trigger_attrs
      (match chevron_position with
       | Start -> [ chevron; trigger_label ]
       | End -> [ trigger_label; chevron ])
  in
  let content =
    Vdom.Node.div
      ~attrs:
        (Attr.class_
           ([ "astryx-collapsible__content" ]
            @ (if not is_open then [ "astryx-collapsible__content--hidden" ] else [])
            @ content_density)
         @ [ Vdom.Attr.create "id" content_id ])
      children
  in
  Vdom.Node.div
    ~attrs:
      (Attr.class_
         ([ "astryx-collapsible" ]
          @ (if divided then [ "astryx-collapsible--divided" ] else [])
         )
       @ root_attrs)
    [ button; content ]
;;

(* ------------------------------------------------------------ view --------- *)

let view
  ?(attrs = [])
  ?(id = "astryx-collapsible")
  ?is_open
  ?(is_disabled = false)
  ?default_is_open
  ?on_open_change
  ?(chevron_position = End)
  ~trigger
  ?(children = [])
  graph
  =
  let config =
    { Use_collapsible.default_is_open =
        (match is_open with
         | Some _ -> None
         | None -> Some (Option.value default_is_open ~default:true))
    ; is_open
    ; on_open_change
    }
  in
  let state = Use_collapsible.component ~is_collapsible:true ~config graph in
  Bonsai.map state ~f:(fun (_is_enabled, is_open, toggle) ->
    let content_id = sprintf "%s-content" id in
    render_row
      ~root_attrs:
        (Common.Attr.data "component" "Collapsible"
         @ Common.Attr.data "open" (string_of_bool is_open)
         @ [ Vdom.Attr.create "id" id ]
         @ attrs)
      ~is_open
      ~toggle
      ~is_disabled
      ~chevron_position
      ~divided:false
      ~density:None
      ~content_id
      ~trigger
      ~children)
;;

(* ------------------------------------------------------- view_group ------- *)

let view_group
  ?(attrs = [])
  ?(id = "astryx-collapsible-group")
  ?(mode = Single)
  ?value
  ?(default_value = [])
  ?on_change
  ?(has_dividers = false)
  ?density
  ?chevron_position
  ~items
  graph
  =
  let is_controlled = Option.is_some value in
  let internal, set_internal = Bonsai.state default_value graph in
  let open_values = match value with Some v -> v | None -> internal in
  let on_change =
    match on_change with Some f -> Bonsai.map f ~f:(fun f -> Some f) | None -> Bonsai.return None
  in
  let resolved_density =
    match density with Some d -> Some d | None -> if has_dividers then Some Balanced else None
  in
  Bonsai.map3 open_values on_change set_internal
    ~f:(fun open_values on_change set_internal ->
      let is_open (v : string) = List.mem open_values v ~equal:String.equal in
      let toggle (v : string) =
        let next =
          match mode with
          | Single -> if is_open v then [] else [ v ]
          | Multiple ->
            if is_open v
            then List.filter open_values ~f:(fun x -> not (String.equal x v))
            else open_values @ [ v ]
        in
        let effects =
          (if is_controlled then [] else [ set_internal next ])
          @ (match on_change with Some f -> [ f next ] | None -> [])
        in
        Effect.Many effects
      in
      let rows =
        List.map items ~f:(fun (item : item) ->
          let row_toggle () = toggle item.value in
          render_row
            ~root_attrs:
              (Common.Attr.data "value" item.value
               @ Common.Attr.data "open" (string_of_bool (is_open item.value))
               @ [])
            ~is_open:(is_open item.value)
            ~toggle:row_toggle
            ~is_disabled:item.is_disabled
            ~chevron_position:
              (Option.value item.chevron_position ~default:(Option.value chevron_position ~default:End))
            ~divided:has_dividers
            ~density:resolved_density
            ~content_id:(sprintf "%s-%s-content" id item.value)
            ~trigger:item.trigger
            ~children:item.children)
      in
      let wrapper_attrs =
        Attr.class_ [ "astryx-collapsible-group" ]
        @ (Common.Attr.data "component" "CollapsibleGroup"
           @ Common.Attr.data "mode" (match mode with Single -> "single" | Multiple -> "multiple")
           @ [ Vdom.Attr.create "id" id ]
           @ attrs)
      in
      Vdom.Node.div ~attrs:wrapper_attrs rows)
;;
