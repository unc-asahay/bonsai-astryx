(* Text — mirrors Astryx's Text/Text.tsx. *)

open! Core
open! Bonsai_web

type type_ =
  | Body
  | Large
  | Label
  | Supporting
  | Code
  | Display_1
  | Display_2
  | Display_3

type size =
  | Size_4xs
  | Size_3xs
  | Size_2xs
  | Xsm
  | Sm
  | Base
  | Lg
  | Xl
  | Size_2xl
  | Size_3xl
  | Size_4xl
  | Size_5xl

type color =
  | Primary
  | Secondary
  | Disabled
  | Placeholder
  | Accent
  | Inherit

type weight =
  | Normal
  | Medium
  | Semibold
  | Bold

type display =
  | Inline
  | Block

type element =
  | Span
  | P
  | Div
  | Label

val view
  :  ?type_:type_
  -> ?size:size
  -> ?color:color
  -> ?weight:weight
  -> ?display:display
  -> ?element:element
  -> ?max_lines:int
  -> ?justify:Common.Alignment.t
  -> ?has_strikethrough:bool
  -> ?has_tabular_numbers:bool
  -> ?id:string
  -> Vdom.Node.t list
  -> Vdom.Node.t

(* Class helpers, reused by Heading and any other type-scale consumer. *)
val type_class : type_ -> string
val size_class : size -> string
val color_class : color -> string
val weight_class : weight -> string
val display_class : display -> string
val justify_class : Common.Alignment.t -> string
