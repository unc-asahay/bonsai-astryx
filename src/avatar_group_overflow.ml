open! Core
open! Bonsai_web

(* Upstream's 2px border, doubled because the size is a content-box minimum: the chip has to end up the same
   overall size as the avatars beside it. *)
let border_width = 2

let view ?(attrs = []) ?(id = "astryx-avatar-group-overflow") ?content ?on_click ~count ~size () =
  let safe_count = Int.max count 0 in
  (* Upstream's translated label; the port writes the English. *)
  let label = sprintf "%d more" safe_count in
  let text = match content with Some content -> [ content ] | None -> [ Vdom.Node.text (sprintf "+%d" safe_count) ] in
  let pixels = Avatar.size_pixels size + (border_width * 2) in
  Vdom.Node.create
    "button"
    ~attrs:
      ([ Vdom.Attr.class_ "astryx-avatar-group-overflow"
       ; Vdom.Attr.create "type" "button"
       ; Vdom.Attr.id id
       ; Vdom.Attr.create "aria-label" label
       ; Vdom.Attr.create
           "style"
           (sprintf "min-width:%dpx;height:%dpx;border-width:%dpx" pixels pixels border_width)
       ]
       @ (match on_click with
          | Some effect -> [ Vdom.Attr.on_click (fun _ -> effect) ]
          | None -> [])
       @ Common.Attr.data "component" "AvatarGroupOverflow"
       @ attrs)
    text
;;
