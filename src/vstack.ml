module Port_stack = Stack

open! Core
open! Bonsai_web

let view
  ?h_align
  ?v_align
  ?justify
  ?align
  ?gap
  ?padding
  ?padding_inline
  ?padding_block
  ?width
  ?height
  ?max_width
  ?min_height
  ?is_scrollable
  ?wrap
  children
  =
  Port_stack.view
    ~direction:Port_stack.Vertical
    ?h_align
    ?v_align
    ?justify
    ?align
    ?gap
    ?padding
    ?padding_inline
    ?padding_block
    ?width
    ?height
    ?max_width
    ?min_height
    ?is_scrollable
    ?wrap
    children
;;
