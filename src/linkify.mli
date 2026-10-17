(** Turning plain text into a mix of text and links.

    The split here is upstream's own, and it is what makes the interesting half provable: finding the
    matches needs a regex engine, but cutting the text up around them does not. [segments_of_matches]
    is therefore a pure function of the text and the matches, and the scanner that produces those
    matches is separate.

    {2 The behaviour that is easy to get subtly wrong}

    - **The first match wins for overlapping ranges**, and matches are sorted by start position first.
      Equal starts are decided by the ORDER THEY WERE COLLECTED IN, which is why the sort must be
      stable: upstream relies on JavaScript's sort being stable and on custom patterns being collected
      before built-in ones. A non-stable sort would make the result depend on the engine.
    - The sort is by start position **only**, so a match that begins inside a longer earlier one loses
      to it, which is the intent and not an accident of ordering.
    - Text before the first match, text between matches, and text after the last one come out as [Text]
      segments; nothing is emitted for a gap of length zero, so a match at position 0 produces no empty
      leading segment. *)
open! Core

type segment =
  | Text of string
  | Link of link

and link =
  { href : string
  ; label : string
  ; is_external : bool
  }

(** One match, resolved but not yet cut into the text. [stop] is exclusive. *)
type match_ =
  { start : int
  ; stop : int
  ; href : string
  ; label : string
  ; is_external : bool
  }

val segments_of_matches : text:string -> match_ list -> segment list

(** A pattern to look for in text, and what to turn a hit into.

    [source] and [flags] are a JavaScript regular expression, deliberately: upstream's patterns are JS
    regexes and this port renders in a browser, so borrowing the engine keeps the matching identical
    rather than nearly identical. The component gate runs under node, so this is testable without a
    browser. *)
type pattern =
  { source : string
  ; flags : string
  ; (* The whole match first, then the capture groups, in order - so a pattern with groups can build its
       href from them, exactly as upstream's [href: (match) => ...] does. *)
    href : string list -> string
  ; label : (string list -> string) option
  ; is_external : bool
  }

(** Detects http(s) URLs. External by default. *)
val url_pattern : pattern

(** Detects email addresses, and links them as [mailto:]. *)
val email_pattern : pattern

(** The two above, in the order upstream collects them. *)
val builtins : pattern list

(** Every match in [text] for every pattern, in the order the patterns were given and then by position
    within the text. NOT sorted or de-overlapped: that is [segments_of_matches]'s job, and keeping the
    collection order intact is what makes the tie-break there meaningful.

    A zero-length match is skipped and the scan resumed past it. Upstream's two built-ins cannot match
    empty, but a caller's pattern can, and a global regex that matches empty makes [exec] loop forever at
    the same index - so this is a guard against a caller's pattern, not against ours. *)
val find_matches : text:string -> patterns:pattern list -> match_ list


(* No [sexp_of] here, deliberately: this project's ppx set has no sexp deriver, so an
   [@@deriving sexp_of] attribute is silently ignored rather than refused. Anything needing to print a
   segment writes it out where it is needed. *)
