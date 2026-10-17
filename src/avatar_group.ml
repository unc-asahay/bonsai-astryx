open! Core
open! Bonsai_web

(* Upstream's ratio, and the reason it is a ratio rather than a distance: the overlap has to scale with the
   avatars it stacks. *)
let overlap_ratio = 0.25
let hint_id = "astryx-avatar-group-hint"

let view ?(attrs = []) ?(id = "astryx-avatar-group") ?label ?overflow ?(size = Avatar.Md) ?shape ~avatars () =
  let pixels = Avatar.size_pixels size in
  let overlap = Float.iround_nearest_exn (Float.of_int pixels *. overlap_ratio) in
  let _ = shape in
  let described_by =
    match label with
    | Some _ -> [ Vdom.Attr.create "aria-describedby" hint_id ]
    | None -> []
  in
  (* The hint is what tells a screen reader that the row is navigable, since the roving tab index is not
     something a screen reader can infer. Upstream translates it; the port writes the English. *)
  let hint =
    Vdom.Node.span
      ~attrs:[ Vdom.Attr.class_ "astryx-visually-hidden"; Vdom.Attr.id hint_id ]
      [ Vdom.Node.text "Use the arrow keys to move between avatars" ]
  in
  Vdom.Node.div
    ~attrs:
      ([ Vdom.Attr.class_ "astryx-avatar-group"
       ; Vdom.Attr.id id
       ; Vdom.Attr.create "role" "group"
       ]
       @ (match label with Some label -> [ Vdom.Attr.create "aria-label" label ] | None -> [])
       @ described_by
       (* The overlap travels to the members as a custom property, exactly as upstream does it: each member
          takes the same negative inline-start margin, so a wrapped member still overlaps correctly. *)
       @ [ Vdom.Attr.create "style" (sprintf "--astryx-avatar-group-overlap:%dpx" overlap) ]
       (* The mechanism's default selector is for buttons, and a facepile is made of divs plus a chip - so it
          is told here what a member is. The default boundary selector already matches, because this root is a
          role="group". *)
       @ [ Common.List_focus.attr
             ~orientation:Common.List_focus.Horizontal
             ~item_selector:".astryx-avatar, .astryx-avatar-group-overflow"
             ()
         ]
       @ Common.Attr.data "component" "AvatarGroup"
       @ attrs)
    (avatars @ [ overflow |> Option.value ~default:Vdom.Node.none ] @ [ hint ])
;;
