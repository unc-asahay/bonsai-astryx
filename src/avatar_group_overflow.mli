(** The "+N" indicator at the end of an avatar group.

    It is a button, because upstream's is: the base carries disabled styling and the whole point of the
    indicator is usually to open the rest of the list. A count that is zero or negative is clamped rather than
    rendered as "+-3". The chip is a circle when the count is short and grows into a pill when it is not, so
    its size is a *minimum* - which is why the height and the min-width are set together.

    {2 Divergences}

    - Upstream looks its label up in the i18n catalogue; the port writes the English.
    - [themeProps] has no counterpart (the port styles by class).
*)

open! Core
open! Bonsai_web

(** [view ?content ?on_click ~count ~size ()] is the indicator. [content] replaces the "+N" text; [size] is the
    avatar size it stands in for, since the chip has to match the row it ends. *)
val view
  :  ?attrs:Vdom.Attr.t list
  -> ?id:string
  -> ?content:Vdom.Node.t
  -> ?on_click:unit Effect.t
  -> count:int
  -> size:Avatar.size
  -> unit
  -> Vdom.Node.t
