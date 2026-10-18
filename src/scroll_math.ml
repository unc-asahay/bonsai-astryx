open! Core

let tolerance = 1

type logical_axis =
  | Inline
  | Block

type physical_axis =
  | X
  | Y

type mapping =
  { inline : physical_axis
  ; block : physical_axis
  ; inline_reversed : bool
  ; block_reversed : bool
  }
[@@deriving sexp_of, equal]

type axis_state =
  { is_scrollable : bool
  ; at_start : bool
  ; at_end : bool
  }
[@@deriving sexp_of, equal]

let inactive_axis_state = { is_scrollable = false; at_start = true; at_end = true }

let mapping_of ~writing_mode ~direction =
  let mode = String.lowercase writing_mode in
  let is_vertical = String.is_prefix mode ~prefix:"vertical" || String.is_prefix mode ~prefix:"sideways" in
  let is_rtl = String.equal direction "rtl" in
  if not is_vertical
  then
    { inline = X
    ; block = Y
    ; inline_reversed = is_rtl
    ; block_reversed = false
    }
  else
    let inline_reversed = (if String.equal mode "sideways-lr" then not is_rtl else is_rtl) in
    { inline = Y
    ; block = X
    ; inline_reversed
    ; block_reversed = String.is_suffix mode ~suffix:"-rl"
    }
;;

let is_scroll_capable value =
  String.equal value "auto" || String.equal value "scroll" || String.equal value "overlay"
;;

let overflow_geometry ~client_extent ~content_extent =
  content_extent - client_extent > tolerance
;;

let scroll_axis ~client_extent ~content_extent ~offset ~overflow ~reversed =
  let max_offset = content_extent - client_extent in
  if not (is_scroll_capable overflow) || max_offset <= tolerance
  then inactive_axis_state
  else
    let logical_offset =
      Int.min max_offset (Int.max 0 (if reversed then Int.abs offset else offset))
    in
    { is_scrollable = true
    ; at_start = logical_offset <= tolerance
    ; at_end = logical_offset >= max_offset - tolerance
    }
;;
