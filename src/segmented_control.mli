(** A segmented button group for single selection: radio group semantics without
    the visible circles. Visually a tab bar, semantically a control of a value.

    The control is [value]-controlled: the caller [value] picks the selected
    segment and [on_change] is how the control reports that the person moved the
    selection. Segment-by-segment [is_disabled] keeps a choice visible but
    unselectable; group [is_disabled] dims and blocks the whole control.

    * Semantics (fair, not faked): [role=radiogroup] + [aria-label] on the
      container (there is no visible group label), [role=radio],
      [aria-checked] and [aria-disabled] on the segments, roving tab stop
      managed by [Common.List_focus] exactly as upstream's
      [useListFocus(hasRovingTabIndex)] does it - the stop follows the
      selected segment, and the arrow keys move focus (and select, because
      selection follows focus) without ever changing the tab stop per item.

    * Focus follows selection: arrow onto another segment selects it, exactly
      like a native radio group, and clicking a segment is shortcut for focus +
      select (the click path also works, but the [on_focusin] handler is what
      keeps arrow-key selection working when the browser's focus event lands).

    * [prefer_existing_stop]: [Common.List_focus] defaults to "the focused
      member wins" (what a ButtonGroup needs: a re-render cannot drag the stop
      back while someone stands on the third button). A controlled radiogroup
      is the reverse: the selected segment owns the tab stop and upstream's
      sync never consults focus at all. [Segmented_control.view] turns on the
      opt-in flag so its stop = the segment with tabindex=0, falling back to
      the first enabled segment - upstream's exact rule.

    * Group [is_disabled] with [disabled_message]: the visible half is one
      class, and instead of upstream's hover-only tooltip the reason is a
      persistent bubble ([role=tooltip], house rule from M13: a description
      that exists only on hover is one a screen reader never reads). The
      selected segment stays focusable (upstream's [keepsSelectedFocusable])
      so the reason can be explored, but nothing selects.

    * Sizes Sm/Md/Lg (28/32/36px tall, padding 2/3/3, concentric radius
      element-radius minus the padding); layout [`Hug] (default, segments hug
      their content) or [`Fill] (segments stretch equally). Icon-only
      segments ([is_label_hidden] with no label visible) never truncate; a
      hug control with a visible label yields its width at most to the
      container.

    * Named divergences from upstream, rather than hidden ones: upstream
      per-item consumer [onClick] before selection is not part of the port
      (the item model has no callback slot); upstream's press-feedback state
      is deferred (visual feedback uses [font-weight] + `:active` only, as
      with the card controls); upstream's keyboard hint "Press Enter or Space"
      is out of scope (a radio has no pressed state to describe).

    * This component stays in the status-quo house rule for the library's
      visual token set: heights come from `--size-element-*`, not a
      segmented-control-specific token. *)

open! Core
open! Bonsai_web

type size =
  | Sm
  | Md
  | Lg
[@@deriving sexp_of]

type item =
  { value : string
  ; label : string
  ; is_label_hidden : bool
  ; icon : Vdom.Node.t option
  ; is_disabled : bool
  }
[@@deriving sexp_of]

val view
  :  ?attrs:Vdom.Attr.t list
  -> ?id:string
  -> ?size:size
  -> ?layout:[ `Hug | `Fill ]
  -> ?is_disabled:bool
  -> ?disabled_message:string
  -> label:string
  -> value:string Bonsai.t
  -> on_change:(string -> unit Bonsai.Effect.t) Bonsai.t
  -> items:item list
  -> Bonsai.graph
  -> Vdom.Node.t Bonsai.t
