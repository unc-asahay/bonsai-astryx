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

(* No [sexp_of] here, deliberately: this project's ppx set has no sexp deriver, so an
   [@@deriving sexp_of] attribute is silently ignored rather than refused. Anything needing to print a
   segment writes it out where it is needed. *)
