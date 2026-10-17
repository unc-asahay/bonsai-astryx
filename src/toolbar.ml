(* This library's own Section, bound before the opens: Core defines a module named Section as well
   (Sexp's, among others), so after [open! Core] the unqualified name would refer to Core's. Same trap,
   same fix, as text_area.ml's Field_. *)
module Section_ = Section

open! Core
open! Bonsai_web

type size = Input_types.size =
  | Sm
  | Md
  | Lg

type orientation = Common.List_focus.orientation =
  | Horizontal
  | Vertical

let size_class = function
  | Sm -> "astryx-toolbar--sm"
  | Md -> "astryx-toolbar--md"
  | Lg -> "astryx-toolbar--lg"
;;

(* What counts as a member, and what counts as "inside this toolbar" for a key event. Both differ from
   ButtonGroup's, which is why the mechanism takes them rather than assuming them. An input is a member here
   because a toolbar may hold a search field; the toolbar is its own boundary, and a popover inside it is a
   boundary too, so a member's open layer keeps its own arrow keys. *)
let item_selector = "button, input, [tabindex], a[href]"
let boundary_selector = "[role=\"toolbar\"], [popover]"

let slot ?(extra_classes = []) ~name children =
  let classes = String.concat ~sep:" " ("astryx-toolbar__slot" :: name :: extra_classes) in
  Vdom.Node.div ~attrs:[ Vdom.Attr.class_ classes ] children
;;

let view
  ?(attrs = [])
  ?(size = Md)
  ?(gap = Common.Spacing.S1)
  ?(orientation = Horizontal)
  ?(variant = Section_.Transparent)
  ?dividers
  ?start_content
  ?center_content
  ?end_content
  ~label
  ()
  =
  let has_start = Option.is_some start_content in
  let has_end = Option.is_some end_content in
  (* The gap reaches the slots through a variable on the box rather than as a per-slot style: one value in
     one place, and the slots read it from their parent like every other inherited property. *)
  let gap_attr =
    Vdom.Attr.create "style" (sprintf "--astryx-toolbar-gap: var(--spacing-%s)" (Common.Spacing.step gap))
  in
  let toolbar_class =
    String.concat
      ~sep:" "
      (("astryx-toolbar" :: size_class size :: [])
       @ (if Option.is_some center_content then [ "astryx-toolbar--grid" ] else [])
       @ (match orientation with
          | Horizontal -> []
          | Vertical -> [ "astryx-toolbar--vertical" ]))
  in
  let toolbar_attrs =
    ([ Vdom.Attr.class_ toolbar_class
     ; Vdom.Attr.create "role" "toolbar"
     ; Vdom.Attr.create "aria-label" label
     ; Vdom.Attr.create "aria-orientation"
         (match orientation with
          | Horizontal -> "horizontal"
          | Vertical -> "vertical")
     ; gap_attr
     ; Common.List_focus.attr
         ~orientation
         ~item_selector
         ~boundary_selector
         ~caret_guard:true
         ()
     ]
     (* Common.Attr.data returns a list, and this list literal is supposed to hold attrs - the splice is the
        difference between an attribute and a list of them. *)
     @ Common.Attr.data "component" "Toolbar"
     @ attrs)
  in
  let slots =
    match center_content with
    | Some center ->
      (* Three columns, so the centre is centred against the toolbar rather than against its neighbours. *)
      [ slot ~name:"astryx-toolbar__slot--start" (Option.value start_content ~default:[])
      ; slot ~name:"astryx-toolbar__slot--center" center
      ; slot ~name:"astryx-toolbar__slot--end" (Option.value end_content ~default:[])
      ]
    | None ->
      let start_slot =
        Option.map start_content ~f:(fun content ->
          slot
            ~name:"astryx-toolbar__slot--start"
            ~extra_classes:(if has_end then [] else [ "astryx-toolbar__slot--start-only" ])
            content)
      in
      let end_slot =
        Option.map end_content ~f:(fun content ->
          slot
            ~name:"astryx-toolbar__slot--end"
            ~extra_classes:(if has_start then [] else [ "astryx-toolbar__slot--end-only" ])
            content)
      in
      List.filter_opt [ start_slot; end_slot ]
  in
  Section_.view
    ~variant
    ?dividers
    ~padding_block:Common.Spacing.S2
    [ Vdom.Node.div ~attrs:toolbar_attrs slots ]
;;
