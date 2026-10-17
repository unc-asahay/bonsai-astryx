open! Core
open! Bonsai_web

type shape =
  | Circle
  | Rounded
  | Square

type size =
  | Xsm
  | Sm
  | Md
  | Lg
  | Xl
  | Numeric of int

type tooltip =
  | No_tooltip
  | Tooltip_text of string
  | Tooltip_from_name

let shape_class = function
  | Circle -> "astryx-avatar--circle"
  | Rounded -> "astryx-avatar--rounded"
  | Square -> "astryx-avatar--square"
;;

(* Upstream's ladder: 20, 24, 36, 48, 128. The dot's tier follows from the same numbers, and the initials'
   font size is 40% of them - see the stylesheet, where that ratio is spelled out per size. *)
let size_pixels = function
  | Xsm -> 20
  | Sm -> 24
  | Md -> 36
  | Lg -> 48
  | Xl -> 128
  | Numeric px -> px
;;

let size_class = function
  | Xsm -> Some "astryx-avatar--xsm"
  | Sm -> Some "astryx-avatar--sm"
  | Md -> Some "astryx-avatar--md"
  | Lg -> Some "astryx-avatar--lg"
  | Xl -> Some "astryx-avatar--xl"
  | Numeric _ -> None
;;

(* Which element the avatar is. Upstream picks by what the caller gave it: a link with [href], a button with
   [onClick], and a plain box otherwise - and the ARIA it may carry depends on which, since an <a> or a <button>
   already has a role of its own and must not be hidden. *)
type root_element =
  | Div
  | Link
  | Button

let tag_name = function
  | Div -> "div"
  | Link -> "a"
  | Button -> "button"
;;

let meaningful s =
  match s with
  | Some s when not (String.is_empty (String.strip s)) -> Some (String.strip s)
  | _ -> None
;;

let initial_character word =
  match String.to_list (String.strip word) with
  | [] -> ""
  | c :: _ -> String.of_char c
;;

(* First and last word's first letter, upper-cased - "Ada Lovelace" is "AL", "Ada" is "A". *)
let initials_of name =
  let words =
    String.split (String.strip name) ~on:' '
    |> List.filter_map ~f:(fun word -> Option.some_if (not (String.is_empty word)) word)
  in
  match List.map words ~f:initial_character with
  | [] -> ""
  | [ only ] -> String.uppercase only
  | first :: rest -> String.uppercase (first ^ List.last_exn rest)
;;

(* The status's label is composed into the avatar's name because a role="img" root prunes its descendants, so a
   status dot inside is otherwise unreachable. Upstream translates the separator; the port uses ", ". *)
let compose_accessible_name name status_label =
  match name, status_label with
  | Some name, Some label -> Some (name ^ ", " ^ label)
  | Some name, None -> Some name
  | None, Some label -> Some label
  | None, None -> None
;;

let default_icon =
  Vdom.Node.create_svg
    "svg"
    ~attrs:
      [ Vdom.Attr.create "xmlns" "http://www.w3.org/2000/svg"
      ; Vdom.Attr.create "viewBox" "0 0 24 24"
      ; Vdom.Attr.create "fill" "currentColor"
      ; Vdom.Attr.create "aria-hidden" "true"
      ]
    [ Vdom.Node.create_svg
        "path"
        ~attrs:
          [ Vdom.Attr.create
              "d"
              "M12 12a5 5 0 100-10 5 5 0 000 10zm0 2c-4.42 0-8 2.24-8 5v1h16v-1c0-2.76-3.58-5-8-5z"
          ]
        []
    ]
;;

let view
  ?(attrs = [])
  ?(id = "astryx-avatar")
  ?alt
  ?fallback_src
  ?name
  ?(size = Md)
  ?(shape = Circle)
  ?src
  ?status
  ?status_label
  ?(tooltip = Tooltip_from_name)
  ?href
  ?target
  ?rel
  ?on_click
  graph
  ()
  =
  let meaningful_alt = meaningful alt in
  let meaningful_name = meaningful name in
  let accessible_name =
    compose_accessible_name (Option.first_some meaningful_alt meaningful_name) status_label
  in
  let initials = Option.value_map meaningful_name ~default:"" ~f:initials_of in
  (* The error chain, as upstream has it: the primary source is tried; when it fails, the fallback source;
     when that fails, or there is none, the initials; and when the name yields no initials, the default icon.
     Each cell remembers *which* source failed rather than only that something did, so a source that changes
     gets a fresh attempt instead of inheriting the stale error - upstream's "erroredSrc !== src". *)
  (* Two cells, one per attempt, and they are not interchangeable: with a single "the most recent source that
     failed", the chain loops - the first source fails, the fallback fails, the cell now names the fallback, and
     the first source therefore looks healthy again and is rendered a second time. The gate caught exactly that,
     after I had argued the two cells were equivalent. Each cell remembers its own attempt, and a source that
     changes still gets a fresh try because the cell holds that source's own value rather than a flag.
     The setters are computations of functions, so each is paired with its value - the idiom MetadataList
     needed one milestone ago. *)
  let errored_src, on_src_failed = Bonsai.state (None : string option) graph in
  let errored_fallback, on_fallback_failed = Bonsai.state (None : string option) graph in
  let src_pair = Bonsai.both errored_src on_src_failed in
  let fallback_pair = Bonsai.both errored_fallback on_fallback_failed in
  let element : root_element =
    match href, on_click with
    | Some _, _ -> Link
    | None, Some _ -> Button
    | None, None -> Div
  in
  let anchor_attrs =
    let a11y =
      match element, accessible_name with
      | (Link | Button), Some name -> [ Vdom.Attr.create "aria-label" name ]
      | (Link | Button), None -> []
      | Div, Some name -> [ Vdom.Attr.create "role" "img"; Vdom.Attr.create "aria-label" name ]
      | Div, None -> [ Vdom.Attr.create "role" "presentation"; Vdom.Attr.create "aria-hidden" "true" ]
    in
    (* The visible tooltip is the platform's, and it has to be: upstream shows the name on hover through the
       Tooltip component, and the port's Tooltip takes a static trigger, which a root computed from the image
       state cannot be. A title attribute shows the same thing on hover, and the accessible name above is
       unaffected by it - which is upstream's split too: the tooltip prefers the name, the name prefers alt. *)
    let title =
      match tooltip with
      | No_tooltip -> []
      | Tooltip_text text -> Option.value_map (meaningful (Some text)) ~default:[] ~f:(fun t -> [ Vdom.Attr.create "title" t ])
      | Tooltip_from_name -> Option.value_map meaningful_name ~default:[] ~f:(fun n -> [ Vdom.Attr.create "title" n ])
    in
    ([ Vdom.Attr.class_ "astryx-avatar"
     ; Vdom.Attr.class_ (shape_class shape)
     ; Vdom.Attr.id id
     ]
     @ (match size_class size with Some c -> [ Vdom.Attr.class_ c ] | None -> [])
     @ (match size with
        | Numeric px -> [ Vdom.Attr.create "style" (sprintf "width:%dpx;height:%dpx" px px) ]
        | Xsm | Sm | Md | Lg | Xl -> [])
     (* The dot's tier, and the initials' font size, both follow from the avatar's own size. The tier is a data
        attribute so the stylesheet can place the status; upstream computes the same numbers in JS. *)
     @ [ Vdom.Attr.create
           "data-tier"
           (match size_pixels size with
            | px when px <= 24 -> "small"
            | px when px <= 48 -> "medium"
            | _ -> "large")
       ]
     @ (match href with Some href -> [ Vdom.Attr.create "href" href ] | None -> [])
     @ (match target with Some t -> [ Vdom.Attr.create "target" t ] | None -> [])
     @ (match rel with Some r -> [ Vdom.Attr.create "rel" r ] | None -> [])
     @ (match element, on_click with
        | Button, Some effect ->
          [ Vdom.Attr.create "type" "button"; Vdom.Attr.on_click (fun _ -> effect) ]
        | _ -> [])
     @ Common.Attr.data "component" "Avatar"
     @ a11y
     @ title
     @ attrs)
  in
  (* Everything below depends on the two error cells, so it is one computation over them: the same shape as
     every other stateful component here - the body never has to learn that something changed. *)
  Bonsai.map2 src_pair fallback_pair ~f:(fun (errored_src, on_src_failed) (errored_fallback, on_fallback_failed) ->
    let is_usable candidate errored =
      match candidate, errored with
      | Some candidate, errored -> not (Option.equal String.equal errored (Some candidate))
      | None, _ -> false
    in
    let show_image = is_usable src errored_src in
    let show_fallback = (not show_image) && is_usable fallback_src errored_fallback in
    let image ?(extra = []) src on_error =
      [ Vdom.Node.create
          "img"
          ~attrs:
            ([ Vdom.Attr.class_ "astryx-avatar__image"
             ; Vdom.Attr.create "src" src
             ; Vdom.Attr.create "alt" ""
             ; Vdom.Attr.create "aria-hidden" "true"
             ; Vdom.Attr.on_error (fun _ -> on_error)
             ]
             @ extra)
          []
      ]
    in
    let content =
      if show_image
      then image (Option.value_exn src) (on_src_failed (Some (Option.value_exn src)))
      else if show_fallback
      then
        image
          ~extra:[ Vdom.Attr.create "data-fallback" "true" ]
          (Option.value_exn fallback_src)
          (on_fallback_failed (Some (Option.value_exn fallback_src)))
      else if String.is_empty initials
      then [ Vdom.Node.div ~attrs:[ Vdom.Attr.class_ "astryx-avatar__icon" ] [ default_icon ] ]
      else [ Vdom.Node.div ~attrs:[ Vdom.Attr.class_ "astryx-avatar__initials" ] [ Vdom.Node.text initials ] ]
    in
    let children =
      [ Vdom.Node.div ~attrs:[ Vdom.Attr.class_ "astryx-avatar__content" ] content ]
      @ (match status with
         | None -> []
         | Some status ->
           [ Vdom.Node.div ~attrs:[ Vdom.Attr.class_ "astryx-avatar__status" ] [ status ] ])
    in
    Vdom.Node.create (tag_name element) ~attrs:anchor_attrs children)
;;
