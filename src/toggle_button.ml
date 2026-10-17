open! Core
open! Bonsai_web

let view
  ?(attrs = [])
  ?id
  ?(is_pressed = false)
  ?on_pressed_change
  ?size
  ?variant
  ?elevation
  ?(is_disabled = false)
  ?(is_loading = false)
  ?icon
  ?(is_icon_only = false)
  ?pressed_icon
  ?tooltip
  ?(children = [])
  ~label
  ()
  =
  let resolved_icon =
    match is_pressed, pressed_icon with
    | true, Some pressed_icon -> Some pressed_icon
    | _ -> icon
  in
  (* The visible hover text is a title attribute, and the reason is the same one Avatar gives: upstream shows
     this through the Tooltip component, the port's Tooltip is the ported component and needs a graph, and a
     graph cannot be used here. This view has to be a *pure* function of the value, because [is_pressed] is
     state the caller re-renders on - a view that reached for the graph could not be re-run when the state
     changed. A title shows the same string on hover, and the accessible name is unaffected by it. *)
  let resolved_tooltip =
    match tooltip, is_icon_only with
    | Some tooltip, _ -> Some tooltip
    | None, true -> Some label
    | None, false -> None
  in
  Button.view
    ?variant
    ?size
    ?elevation
    ?icon:resolved_icon
    ~is_disabled
    ~is_loading
    ~is_icon_only
    ~label
    (* Load-bearing: a wrapper that did not name itself would carry Button's marker and be invisible to every
       tool that identifies components by it. *)
    ~component_name:"ToggleButton"
    ?on_click:
      (Option.map on_pressed_change ~f:(fun handler _ -> handler (not is_pressed)))
    ~attrs:
      ([ Vdom.Attr.class_ "astryx-toggle-button"
       ; Vdom.Attr.create "aria-pressed" (if is_pressed then "true" else "false")
       ]
       (* Button has no id argument of its own, so the caller's id travels with the attrs. *)
       @ (match id with Some id -> [ Vdom.Attr.id id ] | None -> [])
       @ (match resolved_tooltip with
          | Some tip -> [ Vdom.Attr.create "title" tip ]
          | None -> [])
       @ attrs)
    children
;;
