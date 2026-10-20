(* CodeBlock — a hand-port of Astryx's CodeBlock/CodeBlock.tsx.

   Upstream is a read-only code display: a syntax-highlighted <pre> with an
   optional header row (file title and/or language label), an optional
   copy-to-clipboard button, optional line numbers, optional soft wrapping,
   highlighted lines, a unified-diff mode, and a collapsible header.

   The port keeps upstream's public surface (see code_block.mli) and the three
   pieces of behaviour that need a host language of their own:

   - the tokeniser (below) — upstream drives a set of regular expressions per
     language; the port has no regular-expression dependency, so it ships a
     small matcher engine and one rule table per language;
   - the diff splitter — upstream's splitDiffLines, ported literally;
   - the clipboard — upstream's useClipboard, ported to the house's
     navigator.clipboard shape (src/timestamp.ml) with a document.execCommand
     fallback.

   Divergences are recorded in code_block.mli. *)

open! Core
open! Bonsai_web
open Js_of_ocaml

(* The house's shared attribute helpers (classes, data-*, aria, style). *)
module Attr = Common.Attr

(* The root's default id, house style. *)
let default_id = "astryx-code-block"

(* Upstream's [useId] gives every block its own region id, and the collapse
   control points at it with [aria-controls]. A fixed id would collide as soon
   as a page carried two collapsible blocks, so the port counts them. *)
let next_region_id = ref 0

let fresh_region_id () =
  incr next_region_id;
  sprintf "astryx-code-block-region-%d" !next_region_id
;;

(* ------------------------------------------------------------------ tokens *)

(* The token classes upstream's tokeniser emits. They are the class names in
   upstream's [astryx-token-<type>] spans and the keys of its syntax theme. *)
module Kind = struct
  type t =
    | Comment
    | String
    | Number
    | Function
    | Type
    | Keyword
    | Operator
    | Constant
    | Punctuation
    | Variable
    | Property
    | Tag
    | Attribute

  let name = function
    | Comment -> "comment"
    | String -> "string"
    | Number -> "number"
    | Function -> "function"
    | Type -> "type"
    | Keyword -> "keyword"
    | Operator -> "operator"
    | Constant -> "constant"
    | Punctuation -> "punctuation"
    | Variable -> "variable"
    | Property -> "property"
    | Tag -> "tag"
    | Attribute -> "attribute"
  ;;

  let equal a b =
    match a, b with
    | Comment, Comment
    | String, String
    | Number, Number
    | Function, Function
    | Type, Type
    | Keyword, Keyword
    | Operator, Operator
    | Constant, Constant
    | Punctuation, Punctuation
    | Variable, Variable
    | Property, Property
    | Tag, Tag
    | Attribute, Attribute ->
      true
    | _ -> false
  ;;
end

(* A matcher: given the whole text and a position, the position just past the
   text it matches, or [None] when it does not match there. Lookahead is free:
   a matcher sees the whole text, so "an identifier followed by (" can be
   expressed without consuming the "(". *)
type matcher = string -> int -> int option

let is_sub text i s =
  let n = String.length s in
  if i + n > String.length text then false
  else
    let rec go k =
      k >= n || (Char.equal (String.get text (i + k)) (String.get s k) && go (k + 1))
    in
    go 0
;;

let starts_with s prefix = is_sub s 0 prefix

let is_alpha c =
  let n = Char.to_int c in
  (n >= 97 && n <= 122) || (n >= 65 && n <= 90)
;;
let is_digit c =
  let n = Char.to_int c in
  n >= 48 && n <= 57
;;
let is_hex c =
  let n = Char.to_int c in
  is_digit c || (n >= 97 && n <= 102) || (n >= 65 && n <= 70)
;;
let is_ident_start c = is_alpha c || Char.equal c '_' || Char.equal c '$'
let is_ident_char c = is_ident_start c || is_digit c
let is_space c = Char.equal c ' ' || Char.equal c '\t'

let any pred text i =
  if i < String.length text && pred (String.get text i) then Some (i + 1) else None
;;

let char c = any (fun x -> Char.equal x c)
let str s text i = if is_sub text i s then Some (i + String.length s) else None

let seq ms text i =
  let rec go j = function
    | [] -> Some j
    | m :: rest -> (match m text j with None -> None | Some j' -> go j' rest)
  in
  go i ms
;;

(* Greedy repetition. A matcher that consumes nothing stops the loop, so the
   engine cannot spin. *)
let rep m text i =
  let rec go j = match m text j with Some j' when j' > j -> go j' | _ -> j in
  go i
;;

let rep1 m text i = match m text i with Some j when j > i -> Some (rep m text j) | _ -> None

(* The same greedy repetition, in matcher shape: it always succeeds and
   reports the position past the run. Used inside [seq] lists. *)
let rep_opt m text i = Some (rep m text i)

let index_of c text from =
  let n = String.length text in
  let rec go j = if j >= n then None else if Char.equal (String.get text j) c then Some j else go (j + 1) in
  go from
;;

let mem_str s l = List.exists l ~f:(fun x -> String.equal x s)

let ident_run text i =
  if i < String.length text && is_ident_start (String.get text i)
  then Some (rep (any is_ident_char) text i)
  else None
;;

(* A keyword: an identifier that is in the language's keyword list. *)
let kw words text i =
  match ident_run text i with
  | None -> None
  | Some j -> if mem_str (String.sub text ~pos:i ~len:(j - i)) words then Some j else None
;;

(* An identifier that is followed by [next] (skipping spaces) — upstream's
   function pattern. Only the identifier is consumed. *)
let ident_before next text i =
  match ident_run text i with
  | None -> None
  | Some j ->
    let k = rep (any is_space) text j in
    if k < String.length text && Char.equal (String.get text k) next then Some j else None
;;

(* An identifier that starts with a capital — upstream's type pattern. *)
let ident_capitalized text i =
  match ident_run text i with
  | Some j
    when j > i
         && is_alpha (String.get text i)
         && Char.equal (String.get text i) (Char.uppercase (String.get text i)) ->
    Some j
  | _ -> None
;;

(* A property that follows "->" or "::" — upstream's Hack pattern, which uses
   a lookbehind the port expresses by inspecting the text before the match. *)
let ident_after_property text i =
  match ident_run text i with
  | None -> None
  | Some j ->
    if i >= 2 && (is_sub text (i - 2) "->" || is_sub text (i - 2) "::") then Some j else None
;;

let line_comment prefix text i =
  if is_sub text i prefix then
    match index_of '\n' text i with None -> Some (String.length text) | Some k -> Some k
  else None
;;

let block_comment open_delim close_delim text i =
  if is_sub text i open_delim then
    let rec go j =
      if j >= String.length text then Some j
      else if is_sub text j close_delim then Some (j + String.length close_delim)
      else go (j + 1)
    in
    go (i + String.length open_delim)
  else None
;;

let string_lit quote text i =
  if i < String.length text && Char.equal (String.get text i) quote then
    let rec go j =
      if j >= String.length text then Some j
      else if Char.equal (String.get text j) '\\' then go (j + 2)
      else if Char.equal (String.get text j) quote then Some (j + 1)
      else go (j + 1)
    in
    go (i + 1)
  else None
;;

(* A triple-quoted string: it may span lines, so the search for the closing
   delimiter starts after the first newline. *)
let triple_string quote text i =
  let dbl = String.make 3 quote in
  if is_sub text i dbl then
    let rec go j =
      if j >= String.length text then Some j
      else if is_sub text j dbl then Some (j + 3)
      else go (j + 1)
    in
    go (i + 3)
  else None
;;

(* A string literal that is followed by [next] — upstream's JSON property
   pattern ("..." followed by a colon). *)
let string_before next text i =
  match string_lit '"' text i with
  | None -> None
  | Some j ->
    let k = rep (any is_space) text j in
    if k < String.length text && Char.equal (String.get text k) next then Some j else None
;;

let number text i =
  if i < String.length text && is_digit (String.get text i) then
    let j = rep (any is_digit) text i in
    let j =
      if
        j + 1 < String.length text
        && Char.equal (String.get text j) '.'
        && is_digit (String.get text (j + 1))
      then rep (any is_digit) text (j + 1)
      else j
    in
    Some j
  else None
;;

let prefixed_number prefix pred text i =
  if is_sub text i prefix then
    let j = rep (any pred) text (i + String.length prefix) in
    if j > i + String.length prefix then Some j else None
  else None
;;

let run_of chars text i =
  let pred c = List.exists chars ~f:(Char.equal c) in
  if i < String.length text && pred (String.get text i) then Some (rep (any pred) text i) else None
;;

(* ------------------------------------------------------------- rule tables *)

let js_keywords =
  [ "const"; "let"; "var"; "function"; "class"; "if"; "else"; "for"; "while"; "return"
  ; "import"; "export"; "from"; "default"; "async"; "await"; "try"; "catch"; "throw"
  ; "new"; "typeof"; "instanceof"; "interface"; "type"; "enum"; "extends"; "implements"
  ; "switch"; "case"; "break"; "continue"; "do"; "in"; "of"; "void"; "null"; "undefined"
  ; "true"; "false"; "this"; "super"; "yield"; "delete"; "static"; "public"; "private"
  ; "protected"; "readonly"; "abstract"; "as"; "is"; "keyof"; "declare"; "module"
  ; "namespace"; "require" ]
;;

let python_keywords =
  [ "def"; "class"; "if"; "elif"; "else"; "for"; "while"; "return"; "import"; "from"
  ; "as"; "with"; "try"; "except"; "raise"; "True"; "False"; "None"; "and"; "or"; "not"
  ; "in"; "is"; "lambda"; "yield"; "async"; "await"; "pass"; "break"; "continue"; "del"
  ; "global"; "nonlocal"; "assert"; "finally"; "print"; "self"; "cls" ]
;;

let bash_keywords =
  [ "if"; "then"; "else"; "elif"; "fi"; "for"; "do"; "done"; "while"; "until"; "case"
  ; "esac"; "function"; "in"; "select"; "return"; "exit"; "local"; "export"; "source"
  ; "alias"; "unalias"; "readonly"; "shift"; "eval"; "exec"; "set"; "unset"; "trap"
  ; "wait"; "read"; "echo"; "printf"; "test"; "true"; "false" ]
;;

let css_keywords = [ "important"; "inherit"; "initial"; "unset"; "revert"; "auto"; "none" ]

let php_keywords =
  [ "function"; "class"; "if"; "else"; "elseif"; "for"; "foreach"; "while"; "return"
  ; "echo"; "public"; "private"; "protected"; "static"; "new"; "try"; "catch"; "throw"
  ; "namespace"; "use"; "require"; "require_once"; "include"; "include_once"; "extends"
  ; "implements"; "interface"; "abstract"; "final"; "const"; "var"; "true"; "false"
  ; "null"; "array"; "isset"; "unset"; "empty"; "list"; "match"; "enum"; "switch"; "case"
  ; "break"; "continue"; "do"; "yield"; "fn" ]
;;

let hack_keywords =
  [ "function"; "class"; "if"; "else"; "for"; "foreach"; "while"; "return"; "echo"
  ; "public"; "private"; "protected"; "static"; "new"; "try"; "catch"; "throw"; "namespace"
  ; "use"; "require"; "include"; "extends"; "implements"; "interface"; "abstract"; "final"
  ; "const"; "shape"; "vec"; "dict"; "keyset"; "async"; "await"; "concurrent"; "enum"
  ; "type"; "newtype"; "tuple"; "inout" ]
;;

let operator_chars = [ '+'; '-'; '*'; '/'; '%'; '='; '!'; '<'; '>'; '&'; '|'; '^'; '~'; '?'; ':' ]
let punctuation_chars = [ '{'; '}'; '('; ')'; '['; ']'; ';'; ','; '.' ]

let js_rules =
  [ (Kind.Comment, block_comment "/*" "*/")
  ; (Kind.Comment, line_comment "//")
  ; (Kind.String, string_lit '`')
  ; (Kind.String, string_lit '"')
  ; (Kind.String, string_lit '\'')
  ; (Kind.Constant, seq [ char '@'; rep1 (any is_ident_char) ])
  ; (Kind.Number, prefixed_number "0x" is_hex)
  ; (Kind.Number, prefixed_number "0X" is_hex)
  ; (Kind.Number, prefixed_number "0b" (fun c -> Char.equal c '0' || Char.equal c '1'))
  ; (Kind.Number, prefixed_number "0o" (fun c -> let n = Char.to_int c in n >= 48 && n <= 55))
  ; (Kind.Number, number)
  ; (Kind.Keyword, kw js_keywords)
  ; (Kind.Function, ident_before '(')
  ; (Kind.Type, ident_capitalized)
  ; (Kind.Operator, run_of operator_chars)
  ; (Kind.Punctuation, any (fun c -> List.exists punctuation_chars ~f:(Char.equal c)))
  ]
;;

let json_rules =
  [ (Kind.Property, string_before ':')
  ; (Kind.String, string_lit '"')
  ; (Kind.Number, number)
  ; (Kind.Constant, kw [ "true"; "false"; "null" ])
  ; (Kind.Punctuation, any (fun c -> List.exists [ '{'; '}'; '('; ')'; '['; ']'; ':'; ',' ] ~f:(Char.equal c)))
  ]
;;

let html_rules =
  [ (Kind.Comment, block_comment "<!--" "-->")
  ; (Kind.Keyword, seq [ str "<!DOCTYPE"; rep_opt (any (fun c -> not (Char.equal c '>'))) ])
  ; (Kind.Tag, seq [ char '<'; rep_opt (any (fun c -> Char.equal c '/')); rep1 (any is_alpha) ])
  ; (Kind.Tag, seq [ char '<'; rep_opt (any (fun c -> Char.equal c '/')); char '>' ])
  ; (Kind.String, string_lit '"')
  ; (Kind.String, string_lit '\'')
  ; (Kind.Attribute, ident_before '=')
  ; (Kind.Operator, char '=')
  ]
;;

let css_rules =
  [ (Kind.Comment, block_comment "/*" "*/")
  ; (Kind.Comment, line_comment "//")
  ; (Kind.String, string_lit '"')
  ; (Kind.String, string_lit '\'')
  ; (Kind.Variable, seq [ str "--"; rep1 (any is_ident_char) ])
  ; (Kind.Number, number)
  ; (Kind.Constant, seq [ char '#'; rep1 (any is_hex) ])
  ; (Kind.Keyword, kw css_keywords)
  ; (Kind.Keyword, seq [ char '@'; rep1 (any is_ident_char) ])
  ; (Kind.Tag, seq [ char '.'; rep1 (any is_ident_char) ])
  ; (Kind.Keyword, seq [ char ':'; rep1 (any is_ident_char) ])
  ; (Kind.Function, ident_before '(')
  ; (Kind.Property, ident_before ':')
  ; (Kind.Punctuation, any (fun c -> List.exists [ '{'; '}'; '('; ')'; '['; ']'; ';' ] ~f:(Char.equal c);))
  ; (Kind.Punctuation, any (fun c -> List.exists [ ','; ':' ] ~f:(Char.equal c)))
  ; (Kind.Operator, run_of [ '+'; '~'; '>'; '*'; '='; '|'; '^'; '$' ])
  ]
;;

let python_rules =
  [ (Kind.String, triple_string '"')
  ; (Kind.String, triple_string '\'')
  ; (Kind.String, seq [ char 'f'; string_lit '"' ])
  ; (Kind.String, seq [ char 'f'; string_lit '\'' ])
  ; (Kind.Comment, line_comment "#")
  ; (Kind.String, string_lit '"')
  ; (Kind.String, string_lit '\'')
  ; (Kind.Constant, seq [ char '@'; rep1 (any is_ident_char) ])
  ; (Kind.Number, prefixed_number "0x" is_hex)
  ; (Kind.Number, number)
  ; (Kind.Keyword, kw python_keywords)
  ; (Kind.Function, ident_before '(')
  ; (Kind.Type, ident_capitalized)
  ; (Kind.Operator, run_of operator_chars)
  ; (Kind.Punctuation, any (fun c -> List.exists punctuation_chars ~f:(Char.equal c)))
  ]
;;

let bash_rules =
  [ (Kind.Comment, line_comment "#")
  ; (Kind.String, string_lit '"')
  ; (Kind.String, string_lit '\'')
  ; (Kind.Variable, seq [ char '$'; char '{'; rep_opt (any (fun c -> not (Char.equal c '}'))); char '}' ])
  ; (Kind.Variable, seq [ char '$'; rep1 (any is_ident_char) ])
  ; (Kind.Variable, seq [ char '$'; any (fun c -> List.exists [ '0'; '@'; '#'; '?'; '*'; '!'; '$'; '-' ] ~f:(Char.equal c)) ])
  ; (Kind.Number, number)
  ; (Kind.Keyword, kw bash_keywords)
  ; (Kind.Function, ident_before '(')
  ; (Kind.Operator, run_of [ '|'; '&'; '<'; '>'; ';' ; '!' ])
  ; (Kind.Punctuation, any (fun c -> List.exists [ '{'; '}'; '('; ')'; '['; ']' ] ~f:(Char.equal c)))
  ]
;;

let php_rules =
  [ (Kind.Comment, block_comment "/*" "*/")
  ; (Kind.Comment, line_comment "//")
  ; (Kind.Comment, line_comment "#")
  ; (Kind.String, string_lit '"')
  ; (Kind.String, string_lit '\'')
  ; (Kind.Variable, seq [ char '$'; rep1 (any is_ident_char) ])
  ; (Kind.Number, prefixed_number "0x" is_hex)
  ; (Kind.Number, number)
  ; (Kind.Keyword, kw php_keywords)
  ; (Kind.Function, ident_before '(')
  ; (Kind.Type, ident_capitalized)
  ; (Kind.Operator, run_of operator_chars)
  ; (Kind.Constant, seq [ char '@'; rep1 (any is_ident_char) ])
  ; (Kind.Punctuation, any (fun c -> List.exists punctuation_chars ~f:(Char.equal c)))
  ]
;;

let hack_rules =
  [ (Kind.Comment, block_comment "/*" "*/")
  ; (Kind.Comment, line_comment "//")
  ; (Kind.String, string_lit '"')
  ; (Kind.String, string_lit '\'')
  ; (Kind.Variable, seq [ char '$'; rep1 (any is_ident_char) ])
  ; (Kind.Number, prefixed_number "0x" is_hex)
  ; (Kind.Number, number)
  ; (Kind.Keyword, kw hack_keywords)
  ; (Kind.Type, ident_capitalized)
  ; (Kind.Function, ident_before '(')
  ; (Kind.Property, ident_after_property)
  ; (Kind.Operator, run_of operator_chars)
  ; (Kind.Constant, seq [ str "<<"; rep1 (any is_ident_char) ])
  ; (Kind.Punctuation, any (fun c -> List.exists punctuation_chars ~f:(Char.equal c)))
  ]
;;

let yaml_rules =
  [ (Kind.Comment, line_comment "#")
  ; (Kind.String, string_lit '"')
  ; (Kind.String, string_lit '\'')
  ; (Kind.Constant, kw [ "true"; "false"; "yes"; "no"; "on"; "off"; "null" ])
  ; (Kind.Variable, seq [ any (fun c -> Char.equal c '&' || Char.equal c '*'); rep1 (any is_ident_char) ])
  ; (Kind.Type, seq [ str "!!"; rep1 (any is_ident_char) ])
  ; (Kind.Number, number)
  ; (Kind.Keyword, str "---")
  ; (Kind.Keyword, str "...")
  ; (Kind.Property, ident_before ':')
  ; (Kind.Operator, any (fun c -> List.exists [ ':'; '|'; '>'; '-'; '?' ] ~f:(Char.equal c)))
  ; (Kind.Punctuation, any (fun c -> List.exists [ '{'; '}'; '('; ')'; '['; ']'; ',' ] ~f:(Char.equal c)))
  ]
;;

let md_rules =
  [ (Kind.Keyword, seq [ str "```"; rep_opt (any (fun c -> not (Char.equal c '\n'))) ])
  ; (Kind.Keyword, seq [ str "#"; rep_opt (any (fun c -> Char.equal c '#')); char ' ' ])
  ; (Kind.Keyword, str "---")
  ; (Kind.Keyword, str "***")
  ; (Kind.String, seq [ str "**"; rep_opt (any (fun c -> not (Char.equal c '*'))); str "**" ])
  ; (Kind.String, seq [ char '*'; rep_opt (any (fun c -> not (Char.equal c '*'))); char '*' ])
  ; (Kind.Constant, seq [ char '`'; rep_opt (any (fun c -> not (Char.equal c '`'))); char '`' ])
  ; (Kind.Comment, seq [ char '>'; rep_opt (any (fun c -> not (Char.equal c '\n'))) ])
  ]
;;

(* The rule table and the default (uncoloured) class for a language. An
   unknown language has no rules: the code shows as plain text, which is what
   upstream does with a language it does not know. *)
let language_rules (language : string) : (Kind.t * matcher) list * Kind.t =
  match String.lowercase language with
  | "typescript" | "javascript" | "tsx" | "jsx" | "ts" | "js" -> js_rules, Kind.Variable
  | "json" -> json_rules, Kind.Punctuation
  | "html" | "xml" | "svg" -> html_rules, Kind.Variable
  | "css" | "scss" | "less" -> css_rules, Kind.Variable
  | "python" | "py" -> python_rules, Kind.Variable
  | "bash" | "sh" | "zsh" | "shell" -> bash_rules, Kind.Variable
  | "php" -> php_rules, Kind.Variable
  | "hack" -> hack_rules, Kind.Variable
  | "yaml" | "yml" -> yaml_rules, Kind.Variable
  | "markdown" | "md" -> md_rules, Kind.Variable
  | _ -> [], Kind.Variable
;;

(* The tokeniser: scan left to right, take the first rule that matches at the
   current position, and drop the tokens whose class is the language's default
   (upstream drops them too — they would carry the base colour anyway). *)
let tokenize ~rules ~default text =
  let n = String.length text in
  let rec go i acc =
    if i >= n then List.rev acc
    else
      let rec try_rules = function
        | [] -> None
        | (kind, m) :: rest ->
          (match m text i with
           | Some j when j > i -> Some (kind, j)
           | _ -> try_rules rest)
      in
      match try_rules rules with
      | Some (kind, j) -> if Kind.equal kind default then go j acc else go j ((i, j, kind) :: acc)
      | None -> go (i + 1) acc
  in
  go 0 []
;;

(* ------------------------------------------------------------------- lines *)

(* Split into lines, dropping the empty line a trailing newline leaves
   behind — upstream's [code.split('\n')] handling. *)
let split_lines text =
  let n = String.length text in
  let rec go i start acc =
    if i >= n then List.rev (String.sub text ~pos:start ~len:(n - start) :: acc)
    else if Char.equal (String.get text i) '\n' then
      go (i + 1) (i + 1) (String.sub text ~pos:start ~len:(i - start) :: acc)
    else go (i + 1) start acc
  in
  let lines = go 0 0 [] in
  match List.rev lines with
  | [] -> []
  | last :: rest -> if String.length last = 0 && List.length rest > 0 then List.rev rest else lines
;;

(* The byte range of every line, in order. *)
let line_bounds text =
  let n = String.length text in
  let rec go i start acc =
    if i >= n then List.rev ((start, n) :: acc)
    else if Char.equal (String.get text i) '\n' then go (i + 1) (i + 1) ((start, i) :: acc)
    else go (i + 1) start acc
  in
  go 0 0 []
;;

(* The [i]-th element of a list, as an option. Base's [List.nth] returns an
   [Option0.t], so the port keeps its own tiny helper. *)
let nth_opt l i =
  let rec go i l =
    match l with
    | [] -> None
    | x :: rest -> if Int.equal i 0 then Some x else go (i - 1) rest
  in
  go i l
;;

(* Cut the token list into one list per line. A token that spans lines (a block
   comment, a triple-quoted string) contributes a piece to each line it
   covers. *)
let tokens_per_line bounds tokens =
  List.map
    bounds
    ~f:(fun (ls, le) ->
      List.map
        tokens
        ~f:(fun (s, e, kind) ->
          let cs = if s > ls then s else ls in
          let ce = if e < le then e else le in
          if cs < ce then Some (cs - ls, ce - ls, kind) else None)
      |> List.filter_opt
      |> List.sort ~compare:(fun (a, _, _) (b, _, _) -> Int.compare a b))
;;

(* -------------------------------------------------------------------- diff *)

type diff_kind =
  | Added
  | Removed
  | Diff_header
  | Context

(* The indexes of the [--- ] / [+++ ] pair that forms a file header directly
   before an [@@] hunk. Every other [---]/[+++] line is a change, so a removed
   line that starts with [--] is never misread. *)
let file_header_lines lines =
  let arr = Array.of_list lines in
  let n = Array.length arr in
  let headers = ref [] in
  for i = 0 to n - 3 do
    if
      starts_with arr.(i) "--- "
      && starts_with arr.(i + 1) "+++ "
      && starts_with arr.(i + 2) "@@"
    then headers := i :: (i + 1) :: !headers
  done;
  List.rev !headers
;;

let diff_line_kind ~is_file_header line =
  if starts_with line "@@" || is_file_header then Diff_header
  else if starts_with line "+" then Added
  else if starts_with line "-" then Removed
  else Context
;;

(* Split a diff into the glyph column and the code the base language sees:
   an added, removed or space-led context line loses its first character; a
   context line with no leading space keeps all of it; a header line
   contributes an empty line so the offsets stay per line. *)
let split_diff_lines lines =
  let headers = file_header_lines lines in
  List.mapi lines ~f:(fun i line ->
      let is_file_header = List.exists headers ~f:(fun h -> Int.equal h i) in
      let kind = diff_line_kind ~is_file_header line in
      match kind with
      | Diff_header -> (kind, "", "")
      | Context when not (starts_with line " ") -> (kind, "", line)
      | _ ->
        if String.length line = 0 then (kind, "", "")
        else
          ( kind
          , String.sub line ~pos:0 ~len:1
          , String.sub line ~pos:1 ~len:(String.length line - 1) ))
;;

(* --------------------------------------------------------------- clipboard *)

(* The house clipboard shape (src/timestamp.ml): write through
   navigator.clipboard, report success, and report the end of the "copied"
   window 1500 ms later. A [document.execCommand] fallback covers a host
   without the async clipboard API. *)
let copy_impl_js =
  Js.Unsafe.pure_js_expr
    {|
(function(){
  return function(text,onResult){
    var n=(window.navigator||navigator);
    var fallback=function(){
      try{
        var t=document.createElement('textarea');
        t.value=text;
        t.setAttribute('readonly','');
        t.style.position='fixed';
        t.style.left='-9999px';
        document.body.appendChild(t);
        t.select();
        t.setSelectionRange(0,t.value.length);
        var ok=document.execCommand('copy');
        document.body.removeChild(t);
        return !!ok;
      }catch(e){return false;}
    };
    var succeed=function(){
      setTimeout(function(){onResult(0);},1500);
      onResult(1);
    };
    if(n&&n.clipboard&&n.clipboard.writeText){
      n.clipboard.writeText(text).then(succeed).catch(function(){
        if(fallback()){succeed();}else{onResult(0);}
      });
    }else{
      if(fallback()){succeed();}else{onResult(0);}
    }
  };
})()
|}
;;

let js_str (s : string) = Js.Unsafe.inject (Js.string s)

(* ------------------------------------------------------------------- lines *)

(* The token spans of one line: the text between the tokens as plain text, the
   tokens themselves in a coloured span. *)
let build_spans text pieces =
  let n = String.length text in
  if n = 0 then [ Vdom.Node.text "\u{200b}" ]
  else
  let rec go cursor acc = function
    | [] ->
      if cursor < n then List.rev (Vdom.Node.text (String.sub text ~pos:cursor ~len:(n - cursor)) :: acc)
      else List.rev acc
    | (s, e, kind) :: rest ->
      let acc = if s > cursor then Vdom.Node.text (String.sub text ~pos:cursor ~len:(s - cursor)) :: acc else acc in
      let acc =
        Vdom.Node.span ~attrs:[ Vdom.Attr.class_ ("astryx-token-" ^ Kind.name kind) ]
          [ Vdom.Node.text (String.sub text ~pos:s ~len:(e - s)) ]
        :: acc
      in
      go e acc rest
  in
  go 0 [] pieces
;;

(* The content of one line: the diff marker column and the code. *)
let build_line_content ~diff ~line ~tokens =
  match diff with
  | None ->
    [ Vdom.Node.span ~attrs:(Attr.class_ [ "astryx-code-block__line-content" ]) (build_spans line tokens) ]
  | Some (kind, glyph, text) ->
    let marker_class =
      match kind with
      | Added -> [ "astryx-code-block__diff-marker--added" ]
      | Removed -> [ "astryx-code-block__diff-marker--removed" ]
      | Diff_header | Context -> []
    in
    let marker_text = if String.length glyph = 0 then " " else glyph in
    let code_nodes =
      match kind with
      | Diff_header -> [ Vdom.Node.text (if String.length line = 0 then "\u{200b}" else line) ]
      | Added | Removed | Context -> build_spans text tokens
    in
    [ Vdom.Node.span ~attrs:(Attr.class_ [ "astryx-code-block__diff-marker" ] @ Attr.class_ marker_class)
        [ Vdom.Node.text marker_text ]
    ; Vdom.Node.span ~attrs:(Attr.class_ [ "astryx-code-block__line-content" ]) code_nodes
    ]
;;

(* -------------------------------------------------------------------- view *)

type size =
  | Sm
  | Md

type container =
  | Card
  | Section

let size_name = function Sm -> "sm" | Md -> "md"
let container_name = function Card -> "card" | Section -> "section"

let view
    ?attrs
    ?(id = default_id)
    ?language
    ?title
    ?has_language_label
    ?has_line_numbers
    ?highlight_lines
    ?is_diff
    ?has_copy_button
    ?(on_copy = Bonsai.return (fun () -> Effect.Many []))
    ?is_wrapped
    ?max_height
    ?is_collapsible
    ?collapsible_threshold
    ?size
    ?width
    ?container
    ~code
    graph
  : Vdom.Node.t Bonsai.t =
  let language_s = Option.value language ~default:"plaintext" in
  let has_language_label = Option.value has_language_label ~default:true in
  let has_line_numbers = Option.value has_line_numbers ~default:false in
  let is_diff = Option.value is_diff ~default:false in
  let has_copy_button = Option.value has_copy_button ~default:true in
  let is_wrapped = Option.value is_wrapped ~default:false in
  let is_collapsible = Option.value is_collapsible ~default:false in
  let collapsible_threshold = Option.value collapsible_threshold ~default:10 in
  let size = Option.value size ~default:Md in
  let container = Option.value container ~default:Card in
  let width_s = Option.value width ~default:"fit-content" in
  let highlight_lines = Option.value highlight_lines ~default:[] in
  (* A fresh region id per instance: upstream's useId gives every block its
     own, and the collapse control points at it with aria-controls. A fixed
     id would collide as soon as a page carried two collapsible blocks. *)
  let region_id = fresh_region_id () in
  let copied, set_copied = Bonsai.state false graph in
  let announce, set_announce = Bonsai.state "" graph in
  let copy_impl, _ = Bonsai.state copy_impl_js graph in
  (* The callback is a graph value, so it is pulled into the render next to the
     rest of the state. *)
  let collapse =
    Use_collapsible.component
      ~is_collapsible
      ~config:{ default_is_open = Some true; is_open = None; on_open_change = None }
      graph
  in
  (* [Bonsai.state] hands back two Conts: the value and the setter. The
     setter has to be pulled into the graph before the render can call it, so
     the two travel together. *)
  (* The state the render needs travels as one flat tuple: the copy flag and
     its setter, the live-region text and its setter, the clipboard helper,
     the copy callback and the collapse control. *)
  let s = Bonsai.map2 copied set_copied ~f:(fun copied set_copied -> (copied, set_copied)) in
  let s = Bonsai.map2 s announce ~f:(fun (copied, set_copied) announce ->
      (copied, set_copied, announce)) in
  let s = Bonsai.map2 s set_announce ~f:(fun (copied, set_copied, announce) set_announce ->
      (copied, set_copied, announce, set_announce)) in
  let s = Bonsai.map2 s copy_impl ~f:(fun (copied, set_copied, announce, set_announce) copy_impl ->
      (copied, set_copied, announce, set_announce, copy_impl)) in
  let s = Bonsai.map2 s on_copy ~f:(fun (copied, set_copied, announce, set_announce, copy_impl) on_copy ->
      (copied, set_copied, announce, set_announce, copy_impl, on_copy)) in
  let s =
    Bonsai.map2 s collapse
      ~f:(fun (copied, set_copied, announce, set_announce, copy_impl, on_copy) (is_enabled, is_open, toggle) ->
          (copied, set_copied, announce, set_announce, copy_impl, on_copy, is_enabled, is_open, toggle))
  in
  Bonsai.map s
    ~f:(fun (copied, set_copied, announce, set_announce, copy_impl, on_copy, is_enabled, is_open, toggle) ->
    let lines = split_lines code in
    let line_count = List.length lines in
    let diff = if is_diff then Some (split_diff_lines lines) else None in
    let token_source =
      match diff with
      | Some d -> String.concat ~sep:"\n" (List.map d ~f:(fun (_, _, content) -> content))
      | None -> code
    in
    let rules, default_kind = language_rules language_s in
    let tokens = tokenize ~rules ~default:default_kind token_source in
    let per_line = tokens_per_line (line_bounds token_source) tokens in
    let diff_lines = match diff with Some d -> d | None -> [] in
    let language_label =
      if not has_language_label then None
      else if is_diff then
        Some (if String.equal language_s "plaintext" then "diff" else language_s ^ " diff")
      else if not (String.equal language_s "plaintext") then Some language_s
      else None
    in
    let show_header = Option.is_some title || Option.is_some language_label in
    let can_collapse = show_header && is_enabled && line_count >= collapsible_threshold in
    let is_collapsed = can_collapse && not is_open in
    let digits = string_of_int (max 1 (String.length (string_of_int line_count))) in
    (* The header: the title / language label, and the copy button. *)
    let header_control =
      let chevron =
        Vdom.Node.span
          ~attrs:(Attr.class_ [ "astryx-code-block__chevron" ]
                  @ (if is_collapsed then [] else Attr.class_ [ "astryx-code-block__chevron--expanded" ]))
          [ Icon.view ~size:Icon.Xsm ~color:Icon.Inherit ~name:"chevronRight" () ]
      in
      let title_span =
        Vdom.Node.span ~attrs:(Attr.class_ [ "astryx-code-block__title" ])
          ((if can_collapse then [ chevron ] else [])
           @ (match title with Some t -> [ Vdom.Node.text t ] | None -> [])
           @ (match title, language_label with
              | Some _, Some l -> [ Vdom.Node.text (" \u{2014} " ^ l) ]
              | None, Some l -> [ Vdom.Node.text l ]
              | _ -> []))
      in
      if can_collapse then
        Vdom.Node.create
          "button"
          ~attrs:(Attr.class_ [ "astryx-code-block__header-control" ]
                  @ [ Vdom.Attr.create "type" "button" ]
                  @ [ Vdom.Attr.create "aria-expanded" (if is_collapsed then "false" else "true") ]
                  @ [ Vdom.Attr.create "aria-controls" region_id ]
                  @ [ Vdom.Attr.on_click (fun _ -> toggle ()) ])
          [ title_span ]
      else Vdom.Node.div ~attrs:(Attr.class_ [ "astryx-code-block__header-control" ]) [ title_span ]
    in
    let copy_button =
      if not has_copy_button then None
      else
        let icon_node =
          Icon.view ~size:Icon.Sm ~color:Icon.Inherit ~name:(if copied then "check" else "copy") ()
        in
        let label_s = if copied then "Copied" else "Copy code" in
        let on_click _ =
          let apply_result (flag : float) =
            let did_copy = Float.equal flag 1. in
            Effect.Many
              ([ set_copied did_copy
               ; set_announce (if did_copy then "Copied" else "") ]
              @ (if did_copy then [ on_copy () ] else []))
          in
          let on_result =
            Js.wrap_callback (fun (flag : float) ->
              Effect.Expert.handle_non_dom_event_exn (apply_result flag))
          in
          ignore (Js.Unsafe.fun_call copy_impl [| js_str code; Js.Unsafe.inject on_result |]);
          Effect.Many []
        in
        Some
          (Icon_button.view
             ~label:label_s
             ~icon:icon_node
             ~variant:Button.Ghost
             ~size:Button.Sm
             ~on_click
             ())
    in
    let header_row =
      if not show_header then Vdom.Node.none
      else
        Vdom.Node.div ~attrs:(Attr.class_ [ "astryx-code-block__header" ])
          [ header_control
          ; (match copy_button with Some b -> b | None -> Vdom.Node.none)
          ]
    in
    (* The code: one row per line, with the line number in the gutter and the
       tokens in the content column. *)
    let line_nodes =
      List.mapi lines ~f:(fun i line ->
          let line_tokens =
            match nth_opt per_line i with Some t -> t | None -> []
          in
          let line_diff = match nth_opt diff_lines i with Some l -> Some l | None -> None in
          let classes = ref [ "astryx-code-block__line" ] in
          let data_diff =
            match line_diff with
            | Some (Added, _, _) ->
              classes := !classes @ [ "astryx-code-block__line--added" ];
              [ Vdom.Attr.create "data-diff" "added" ]
            | Some (Removed, _, _) ->
              classes := !classes @ [ "astryx-code-block__line--removed" ];
              [ Vdom.Attr.create "data-diff" "removed" ]
            | Some (Diff_header, _, _) ->
              classes := !classes @ [ "astryx-code-block__line--header" ];
              [ Vdom.Attr.create "data-diff" "header" ]
            | Some (Context, _, _) -> []
            | None -> []
          in
          if has_line_numbers then classes := !classes @ [ "astryx-code-block__line--numbered" ] else ();
          (* Upstream lays every line of a diff out as a two-column grid, so
             the glyph column sits at the same offset on every line and the
             indentation reads exactly as written. *)
          if is_diff then classes := !classes @ [ "astryx-code-block__line--diff" ] else ();
          if List.exists highlight_lines ~f:(fun n -> Int.equal n (i + 1)) then
            classes := !classes @ [ "astryx-code-block__line--highlighted" ]
          else ();
          let content =
            match line_diff with
            | Some (kind, glyph, text) -> build_line_content ~diff:(Some (kind, glyph, text)) ~line ~tokens:line_tokens
            | None -> build_line_content ~diff:None ~line ~tokens:line_tokens
          in
          Vdom.Node.div
            ~attrs:(Attr.class_ !classes
                    @ [ Vdom.Attr.create "data-line" (string_of_int (i + 1)) ]
                    @ data_diff)
            content)
    in
    let code_el =
      Vdom.Node.create
        "code"
        ~attrs:(Attr.class_
                  [ "astryx-code-block__code"; "astryx-code-block__code--" ^ Kind.name default_kind ]
                  @ (if is_wrapped then Attr.class_ [ "astryx-code-block__code--wrapped" ] else [])
                  @ (if has_line_numbers then Attr.class_ [ "astryx-code-block__code--numbered" ] else [])
                  @ Attr.style [ ("--_codeblock-gutter-width", digits ^ "ch") ])
        line_nodes
    in
    let viewport_attrs =
      [ Vdom.Attr.create "role" "group"
      ; Vdom.Attr.create "aria-label" (Option.value language_label ~default:"Code")
      ; Vdom.Attr.create "tabindex" "0"
      ]
      @ (match max_height with
         | Some h -> Attr.style [ ("max-height", Common.Size_value.to_css h) ]
         | None -> [])
    in
    let viewport =
      Vdom.Node.div ~attrs:(Attr.class_ [ "astryx-code-block__viewport" ] @ viewport_attrs)
        [ Vdom.Node.div ~attrs:(Attr.class_ [ "astryx-code-block__content" ]) [ code_el ] ]
    in
    let body =
      if not can_collapse then viewport
      else
        Vdom.Node.div
          ~attrs:(Attr.class_
                    [ "astryx-code-block__collapse-grid" ]
                    @ (if is_collapsed then Attr.class_ [ "astryx-code-block__collapse-grid--collapsed" ] else [])
                    @ [ Vdom.Attr.create "id" region_id ]
                    @ (if is_collapsed then [ Vdom.Attr.create "inert" "" ] else []))
          [ Vdom.Node.div ~attrs:(Attr.class_ [ "astryx-code-block__collapse-inner" ]) [ viewport ] ]
    in
    let root_attrs =
      Attr.class_
        [ "astryx-code-block"; "astryx-code-block--" ^ size_name size; "astryx-code-block--" ^ container_name container ]
        @ (if is_wrapped then Attr.class_ [ "astryx-code-block--wrapped" ] else [])
        @ [ Vdom.Attr.create "id" id ]
        @ (if String.equal width_s "fit-content" then []
           else Attr.style [ ("width", width_s); ("min-width", "0"); ("max-width", "none") ])
        @ Attr.data "component" "CodeBlock"
        @ Attr.data "language" language_s
        @ Attr.data "size" (size_name size)
        @ Attr.data "container" (container_name container)
        @ Attr.data "has-line-numbers" (if has_line_numbers then "true" else "false")
        @ Attr.data "is-diff" (if is_diff then "true" else "false")
        @ Attr.data "is-wrapped" (if is_wrapped then "true" else "false")
        @ Attr.data "is-collapsible" (if can_collapse then "true" else "false")
        @ Attr.data "is-collapsed" (if is_collapsed then "true" else "false")
        @ Option.value attrs ~default:[]
    in
    let announcer =
      Vdom.Node.div ~attrs:(Attr.class_ [ "astryx-visually-hidden" ] @ Attr.role "status")
        [ Vdom.Node.text announce ]
    in
    Vdom.Node.create
      "pre"
      ~attrs:root_attrs
      [ header_row
      ; body
      ; (match copy_button with Some b when not show_header -> b | _ -> Vdom.Node.none)
      ; announcer
      ])
;;
