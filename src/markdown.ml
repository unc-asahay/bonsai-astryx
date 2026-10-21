(* Markdown — renders a markdown document.

   A scoped port of upstream's [Markdown] component: the block and inline
   syntax a document needs, upstream's DOM shape, and upstream's URL
   policy. The document is parsed when the tree is built, so [view] is a
   pure builder like [Text.view] and [Code.view].

   The scope, and what is deliberately not ported, are in the interface. *)

open! Core
open! Bonsai_web

module Attr = Common.Attr
module Blockquote = Blockquote
module Code = Code
module Heading = Heading
module Link = Link

(* ------------------------------------------------------------------ the
   blocks. A block is one of: heading, paragraph, code, quote, list, or
   break. *)

(** A fenced code block, as the parser found it: the code without the
    fence, and the fence's info string (the language), when it had one. *)
type code_block =
  { code : string
  ; language : string option
  }

(** What the host does when one of the document's links is activated.

    Upstream's [onLinkClick] returns false to cancel the browser's default
    navigation and undefined to let it happen. The port splits the two:
    the constructor says what happens to the navigation, and the effect
    says what the host does about it. *)
type link_click =
  | Follow of unit Effect.t
      (** The browser follows the destination; the effect runs. *)
  | Prevent of unit Effect.t
      (** The default navigation is cancelled; the effect runs. *)

type block =
  | Heading of int * string  (** the level, 1 to 6, and the text *)
  | Paragraph of string
  | Code of string * string option  (** the body of a fenced block, and the fence's language *)
  | Quote of block list
  | List of bool * (block list list)  (** ordered, and the items, each a list of blocks *)
  | Break

(* A list item's text, with its continuation lines folded in. *)
type item = { first : string; rest : string list }

let is_blank line = String.equal (String.strip line) ""

(* The indentation of a line, in spaces. A tab counts as four. *)
let indent_of line =
  let n = ref 0 in
  let len = String.length line in
  let i = ref 0 in
  while !i < len do
    match line.[!i] with
    | ' ' -> incr n; incr i
    | '\t' -> n := !n + 4 - (!n mod 4); incr i
    | _ -> i := len
  done;
  !n
;;

let drop_indent line amount =
  let n = ref 0 and i = ref 0 in
  let len = String.length line in
  let stop = ref false in
  while !i < len && !n < amount && not !stop do
    match line.[!i] with
    | ' ' -> incr n; incr i
    | '\t' -> n := !n + 4 - (!n mod 4); incr i
    | _ -> stop := true
  done;
  String.sub line ~pos:!i ~len:(len - !i)
;;

(* The ATX heading: a run of '#' and then the text, with the optional closing
   run of '#' removed. *)
let atx_heading line =
  let n = ref 0 in
  let len = String.length line in
  while !n < len && Char.equal line.[!n] '#' do
    incr n
  done;
  if !n = 0 || !n > 6 || (!n < len && (not (Char.equal line.[!n] ' ')) && (not (Char.equal line.[!n] '\t'))) then None
  else
    let text = String.sub line ~pos:!n ~len:(len - !n) |> String.strip in
    let text_len = String.length text in
    let text =
      if text_len > 0 && Char.equal text.[text_len - 1] '#' then
        String.sub text ~pos:0 ~len:(text_len - 1) |> String.strip
      else text
    in
    Some (!n, text)
;;

(* A thematic break: three or more of the same marker. *)
let is_break line =
  let stripped = String.strip line in
  let len = String.length stripped in
  if len < 3 then false
  else
    let marker = stripped.[0] in
    if (not (Char.equal marker '-')) && (not (Char.equal marker '*')) && (not (Char.equal marker '_'))
    then false
    else
      let ok = ref true in
      String.iteri
        ~f:(fun _ c -> if not (Char.equal c marker) then ok := false)
        stripped;
      !ok
;;

(* A list marker at the start of a line: the bullet, or the number of an
   ordered item. The marker is returned with its width. *)
let list_marker line =
  let len = String.length line in
  if len = 0 then None
  else
    let first = line.[0] in
    if Char.equal first '-' || Char.equal first '*' || Char.equal first '+' then
      if len = 1 then Some (false, 1)
      else if Char.equal line.[1] ' ' || Char.equal line.[1] '\t' then Some (false, 2)
      else None
    else if Char.is_digit first then
      let digits = ref 0 in
      while !digits < len && Char.is_digit line.[!digits] do
        incr digits
      done;
      if !digits > 9 || !digits = len then None
      else if Char.equal line.[!digits] '.' || Char.equal line.[!digits] ')' then
        if !digits + 1 < len
           && (Char.equal line.[(!digits + 1)] ' ' || Char.equal line.[(!digits + 1)] '\t')
        then Some (true, !digits + 2)
        else None
      else None
    else None
;;

(* The fence of a code block: the run of markers, and whether it is a tilde. *)
let code_fence line =
  let stripped = String.strip line in
  let len = String.length stripped in
  if len < 3 then None
  else
    let marker = stripped.[0] in
    if (not (Char.equal marker '`')) && (not (Char.equal marker '~')) then None
    else
      let n = ref 0 in
      while !n < len && Char.equal stripped.[!n] marker do
        incr n
      done;
      Some (!n, marker)
;;

(* The parser. The lines are consumed in order, and a block that continues
   over several lines — a quote, a list, a fence — takes the lines that
   belong to it. *)
(* Whether a line's marker is of the same kind as a list's: both bullets,
   or both numbers. *)
let same_kind marker ordered =
  match (marker, ordered) with
  | Some (is_ordered, _), Some list_ordered -> Bool.equal is_ordered list_ordered
  | _ -> false
;;

let rec parse_blocks (lines : string list) : block list =
  let rec go lines acc =
    match lines with
    | [] -> List.rev acc
    | line :: rest ->
      if is_blank line then go rest acc
      else if is_break line then go rest (Break :: acc)
      else
        match atx_heading line with
        | Some (level, text) -> go rest (Heading (level, text) :: acc)
        | None ->
          (match code_fence line with
           | Some (fence_len, marker) ->
             let body = ref [] in
             let rec take = function
               | [] -> []
               | l :: ls ->
                 (match code_fence l with
                  | Some (n, m) when n >= fence_len && Char.equal m marker -> ls
                  | _ ->
                    body := l :: !body;
                    take ls)
             in
             let rest = take rest in
             let language =
               let info_len = String.length line - fence_len - 1 in
               if info_len <= 0 then None
               else
                 let info = String.strip (String.sub line ~pos:(fence_len + 1) ~len:info_len) in
                 if String.equal info "" then None else Some info
             in
             go rest (Code (String.concat ~sep:"\n" (List.rev !body), language) :: acc)
           | None ->
             (match list_marker line with
              | Some _ -> parse_list lines acc
              | None ->
                if String.length (String.strip line) > 0
                   && Char.equal (String.strip line).[0] '>'
                then parse_quote lines acc
                else parse_paragraph lines acc))
  and parse_paragraph lines acc =
    let taken = ref [] in
    let rec take = function
      | [] -> []
      | l :: ls ->
        if is_blank l then ls
        else if
          Option.is_some (atx_heading l)
          || is_break l
          || Option.is_some (list_marker l)
          || (String.length (String.strip l) > 0
              && Char.equal (String.strip l).[0] '>')
        then l :: ls
        else
          (taken := l :: !taken;
           take ls)
    in
    let rest = take lines in
    let text = String.concat ~sep:"\n" (List.rev !taken) in
    go rest (Paragraph text :: acc)
  and parse_quote lines acc =
    let taken = ref [] in
    let rec take = function
      | [] -> []
      | l :: ls ->
        let stripped = String.strip l in
        if String.length stripped = 0 || not (Char.equal stripped.[0] '>') then l :: ls
        else
          (taken :=
             (if String.length stripped > 1 && Char.equal stripped.[1] ' ' then
                String.sub stripped ~pos:2 ~len:(String.length stripped - 2)
              else String.sub stripped ~pos:1 ~len:(String.length stripped - 1))
           :: !taken;
           take ls)
    in
    let rest = take lines in
    go rest (Quote (parse_blocks (List.rev !taken)) :: acc)
  and parse_list lines acc =
    let items = ref [] in
    let ordered = ref None in
    let rec take_items lines =
      match lines with
      | [] -> []
      | line :: rest ->
        if is_blank line then
          (* A blank line ends the list unless the next line continues it.
             A line that is indented continues the item it follows, and a
             line that is an item of the same kind continues the list. A
             bullet and a number are two lists, even with nothing between
             them. *)
          (match rest with
           | next :: _
             when (not (is_blank next))
                  && (Int.compare (indent_of next) 0 > 0
                      || same_kind (list_marker next) !ordered)
           -> take_items rest
           | _ -> rest)
        else
          match list_marker line with
          | None -> line :: rest
          | Some (is_ordered, width) ->
            if Option.is_none !ordered then ordered := Some is_ordered;
            let first = String.sub line ~pos:width ~len:(String.length line - width) in
            let item = ref { first; rest = [] } in
            let rec take_continuation = function
              | [] -> []
              | l :: ls ->
                if is_blank l then l :: ls
                else if Int.compare (indent_of l) 0 > 0 then
                  (item := { !item with rest = !item.rest @ [ drop_indent l width ] };
                   take_continuation ls)
                else if Option.is_some (list_marker l) then l :: ls
                else
                  (item := { !item with rest = !item.rest @ [ l ] };
                   take_continuation ls)
            in
            let rest = take_continuation rest in
            items := !item :: !items;
            take_items rest
    in
    let rest = take_items lines in
    let blocks =
      List.map
        ~f:(fun item ->
          let text = String.concat ~sep:"\n" (item.first :: item.rest) in
          parse_blocks (String.split_on_chars ~on:['\n'] text))
        !items
    in
    go rest (List (Option.value !ordered ~default:false, blocks) :: acc)
  in
  go lines []
;;

(* ------------------------------------------------------------------ the
   inline markup. *)

type inline =
  | Text of string
  | Strong of inline list
  | Emphasis of inline list
  | Strike of inline list
  | Code of string
  | Link of string * string  (** the text, and the destination *)
  | Image of string  (** the alt text *)

(* The destination of a link, and how much of the text it takes. *)
let destination text =
  let len = String.length text in
  if len < 2 || (not (Char.equal text.[0] '(')) then None
  else
    (* The destination runs to the matching ')', and a destination may hold
       parentheses of its own, so they are counted. *)
    let depth = ref 0 in
    let close = ref (-1) in
    String.iteri
      ~f:(fun i c ->
        if !close = -1 then
          match c with
          | '(' -> incr depth
          | ')' ->
            decr depth;
            if !depth = 0 then close := i
          | _ -> ())
      text;
    if !close = -1 then None
    else
      let inner = String.sub text ~pos:1 ~len:(!close - 1) |> String.strip in
      let inner_len = String.length inner in
      let dest =
        if inner_len >= 2 && Char.equal inner.[0] '<' && Char.equal inner.[inner_len - 1] '>' then
          String.sub inner ~pos:1 ~len:(inner_len - 2)
        else inner
      in
      Some (dest, !close + 1)
;;

(* The text of a link, up to the matching bracket. *)
let link_text text =
  let close = ref (-1) in
  let depth = ref 0 in
  String.iteri
    ~f:(fun i c ->
      if !close = -1 then
        match c with
        | '[' -> incr depth
        | ']' ->
          decr depth;
          if !depth = 0 then close := i
        | _ -> ())
    text;
  if !close = -1 then None else Some !close
;;

(* The inline markup of a piece of text. The markers are matched in pairs,
   and what is not markup is text. *)
let rec parse_inline (text : string) : inline list =
  let len = String.length text in
  let rec go i acc =
    if i >= len then List.rev acc
    else
      match text.[i] with
      | '`' ->
        (* Inline code: the run of backticks, then the text, then the run. *)
        let ticks = ref 1 in
        while i + !ticks < len && Char.equal text.[(i + !ticks)] '`' do
          incr ticks
        done;
        let fence = String.make !ticks '`' in
        let close = ref (-1) in
        let j = ref (i + !ticks) in
        while !j < len && !close = -1 do
          if Char.equal text.[!j] '`' then close := !j else incr j
        done;
        if !close = -1 then go (i + !ticks) (Text fence :: acc)
        else
          let body = String.sub text ~pos:(i + !ticks) ~len:(!close - i - !ticks) in
          go (!close + !ticks) (Code body :: acc)
      | '*' | '_' ->
        let marker = text.[i] in
        let strong = i + 1 < len && Char.equal text.[i + 1] marker in
        let run = if strong then 2 else 1 in
        let fence = String.make run marker in
        let close = ref (-1) in
        let j = ref (i + run) in
        while !j < len && !close = -1 do
          if Char.equal text.[!j] marker then close := !j else incr j
        done;
        if !close = -1 then go (i + run) (Text fence :: acc)
        else
          let body = String.sub text ~pos:(i + run) ~len:(!close - i - run) in
          let inner = parse_inline body in
          let node = if strong then Strong inner else Emphasis inner in
          go (!close + run) (node :: acc)
      | '~' ->
        if i + 1 < len && Char.equal text.[i + 1] '~' then
          let close = ref (-1) in
          let j = ref (i + 2) in
          while !j < len && !close = -1 do
            if Char.equal text.[!j] '~' && !j + 1 < len && Char.equal text.[(!j + 1)] '~' then
              close := !j
            else incr j
          done;
          if !close = -1 then go (i + 2) (Text "~" :: acc)
          else
            let body = String.sub text ~pos:(i + 2) ~len:(!close - i - 2) in
            go (!close + 2) (Strike (parse_inline body) :: acc)
        else go (i + 1) (Text "~" :: acc)
      | '[' ->
        let rest = String.sub text ~pos:i ~len:(len - i) in
        (match link_text rest with
         | None -> go (i + 1) (Text "[" :: acc)
         | Some close ->
           let label = String.sub rest ~pos:1 ~len:(close - 1) in
           let after = String.sub rest ~pos:(close + 1) ~len:(String.length rest - close - 1) in
           (match destination after with
            | None -> go (i + 1) (Text "[" :: acc)
            | Some (dest, dest_len) -> go (i + close + 1 + dest_len) (Link (label, dest) :: acc)))
      | '!' ->
        if i + 1 < len && Char.equal text.[i + 1] '[' then
          let rest = String.sub text ~pos:(i + 1) ~len:(len - i - 1) in
          (match link_text rest with
           | None -> go (i + 1) (Text "!" :: acc)
           | Some close ->
             let label = String.sub rest ~pos:1 ~len:(close - 1) in
             go (i + close + 2) (Image label :: acc))
        else go (i + 1) (Text "!" :: acc)
      | _ ->
        (* A run of plain text up to the next marker. *)
        let j = ref (i + 1) in
        while
          !j < len
          &&
          match text.[!j] with
          | '`' | '*' | '_' | '~' | '[' | '!' -> false
          | _ -> true
        do
          incr j
        done;
        let body = String.sub text ~pos:i ~len:(!j - i) in
        go !j (Text body :: acc)
  in
  go 0 []
;;

(* ------------------------------------------------------------------ the
   rendering. *)

(* The house's link policy: a destination that may be followed. An internal
   destination stays in the page; an external one opens in a new tab. *)
let is_safe_destination destination =
  let destination = String.strip destination in
  if String.equal destination "" then false
  else
    let lower = String.lowercase destination in
    if String.is_prefix ~prefix:"javascript:" lower then false
    else if String.is_prefix ~prefix:"data:" lower then false
    else if String.is_prefix ~prefix:"vbscript:" lower then false
    else true
;;

let is_external destination =
  let lower = String.lowercase (String.strip destination) in
  String.is_prefix ~prefix:"http://" lower || String.is_prefix ~prefix:"https://" lower
;;

let rec render_inline ~(on_link_click : (string -> link_click) option) (nodes : inline list) :
    Vdom.Node.t list =
  List.map
    ~f:(fun node ->
      match node with
      | Text text -> Vdom.Node.text text
      | Strong inner -> Vdom.Node.strong ~attrs:[] (render_inline ~on_link_click inner)
      | Emphasis inner -> Vdom.Node.em ~attrs:[] (render_inline ~on_link_click inner)
      | Strike inner ->
        Vdom.Node.span
          ~attrs:[ Vdom.Attr.class_ "astryx-markdown__strike" ]
          (render_inline ~on_link_click inner)
      | Code body -> Code.view [ Vdom.Node.text body ]
      | Link (label, destination) ->
        if is_safe_destination destination then
          Link.view
            ~href:destination
            ~is_external_link:(is_external destination)
            ?on_click:
              (match on_link_click with
               | None -> None
               | Some handler ->
                 Some
                   (fun event ->
                     match handler destination with
                     | Follow effect -> effect
                     | Prevent effect ->
                       Common.prevent_default event;
                       effect))
            (render_inline ~on_link_click (parse_inline label))
        else Vdom.Node.text label
      | Image alt ->
        Vdom.Node.span
          ~attrs:[ Vdom.Attr.class_ "astryx-markdown__image-alt" ]
          [ Vdom.Node.text ("[" ^ alt ^ "]") ])
    nodes
;;

(* The marker of a list, by depth: the same order upstream uses. *)
let list_marker_style ~ordered ~depth =
  if ordered then
    match depth mod 3 with
    | 0 -> "decimal"
    | 1 -> "lower-alpha"
    | _ -> "lower-roman"
  else
    match depth mod 3 with
    | 0 -> "disc"
    | 1 -> "circle"
    | _ -> "square"
;;

(* The house's heading levels. *)
let heading_level = function
  | 1 -> Heading.H1
  | 2 -> Heading.H2
  | 3 -> Heading.H3
  | 4 -> Heading.H4
  | 5 -> Heading.H5
  | _ -> Heading.H6
;;

let rec render_block
    ~depth
    ~code_block
    ~on_link_click
    (block : block)
    : Vdom.Node.t list =
  match block with
  | Heading (level, text) ->
    [ Vdom.Node.div
        ~attrs:
          (Attr.class_ [ "astryx-markdown__heading" ]
          @ Attr.data "level" (Int.to_string level))
        [ Heading.view ~level:(heading_level level) [ Vdom.Node.text text ] ] ]
  | Paragraph text ->
    [ Vdom.Node.div
        ~attrs:(Attr.class_ [ "astryx-markdown__paragraph" ] @ Attr.role "paragraph")
        (render_inline ~on_link_click (parse_inline text)) ]
  | Code (body, language) ->
    (match code_block with
     | Some render -> [ render { code = body; language } ]
     | None ->
       [ Vdom.Node.pre
           ~attrs:
             (Vdom.Attr.class_ "astryx-markdown__pre"
             :: (match language with
                 | None -> []
                 | Some language -> [ Vdom.Attr.create "data-astryx-language" language ]))
           [ Vdom.Node.code ~attrs:[] [ Vdom.Node.text body ] ] ])
  | Quote blocks ->
    [ Blockquote.view
        (List.concat (List.map ~f:(render_block ~depth ~code_block ~on_link_click) blocks)) ]
  | List (ordered, items) ->
    let marker = list_marker_style ~ordered ~depth in
    let children =
      List.map
        ~f:(fun blocks ->
          Vdom.Node.li
            ~attrs:
              (Attr.class_ [ "astryx-markdown__item" ]
              @ Attr.style [ ("list-style-type", marker) ])
            (List.concat
               (List.map ~f:(render_block ~depth:(depth + 1) ~code_block ~on_link_click) blocks)))
        items
    in
    [ if ordered
      then Vdom.Node.ol ~attrs:[ Vdom.Attr.class_ "astryx-markdown__list" ] children
      else Vdom.Node.ul ~attrs:[ Vdom.Attr.class_ "astryx-markdown__list" ] children ]
  | Break -> [ Vdom.Node.hr ~attrs:[ Vdom.Attr.class_ "astryx-markdown__break" ] () ]
;;

let view ?id ?class_ ?code_block ?on_link_click ~source () =
  let blocks = parse_blocks (String.split_on_chars ~on:['\n'] source) in
  let children =
    List.concat (List.map ~f:(render_block ~depth:0 ~code_block ~on_link_click) blocks)
  in
  Vdom.Node.div
    ~attrs:
      (Attr.class_
         [ "astryx-markdown" ]
       @ (match class_ with
          | None -> []
          | Some class_ -> [ Vdom.Attr.class_ class_ ])
       @ Attr.role "document"
       @ Attr.data "component" "Markdown"
       @ (match id with
          | None -> []
          | Some id -> [ Vdom.Attr.id id ]))
    children
;;
