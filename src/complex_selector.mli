(** ComplexSelector — a rich custom selector shell (upstream [ComplexSelector/ComplexSelector.tsx]).

    The selector owns the field, the trigger, the popup and the focus contract, and hands the
    application a render function for the selection surface:

    [children value commit close state]

    where [commit] writes a new value into the application (and drives the busied state when
    [changeAction] had been provided — see the divergence below), [close] dismisses the popup the
    same way every other route does, and [state] names the surface and its ids, so the child can
    wire [aria-controls]/[aria-labelledby] and pick its own dismissed-by-close behaviour.

    {2 What the popup is}

    A native [popover] attribute surface (the same mechanism {!Popover} stands on): the platform
    owns the top layer, outside-pointer dismissal, Escape and CSS anchor positioning against the
    trigger box. The port carries no fallback positioning engine — the same statement [popover.mli]
    makes. The surface is [role="dialog"], [aria-modal="true"], labelled by the field [label],
    and focus enters its first focusable control on open (or the surface itself if it has none);
    no close button — the application's content speaks for itself, exactly as upstream configures
    [usePopover] here.

    {2 Divergences, each recorded where it is decided}

    - {b [changeAction] and the optimistic value are not ported.} Upstream commits with
      [useTransition] + [useOptimistic] so a slow action cannot fight the browser's echo. The
      standing house call (M48, made for every component that takes [changeAction]) is that a
      Bonsai effect cannot await the async action, so [?is_loading] replaces the pair: the
      application owns the async work and reports it with [is_loading], which drives the trigger
      spinner, [aria-busy] and [state.is_busy]. [commit] calls [on_change] and nothing else.
    - {b [renderTrigger] (the caller-rendered opener with the popup anchored to it) is not ported.}
      The port builds its own field and button; an opener it does not own cannot be wired to the
      layer mechanism, which needs to sit on the trigger element.
    - {b No imperative [handleRef].} Bonsai has no imperative handle to hand out, so the port
      instead offers the same control as {!Dropdown_menu}: pass both [?is_open] and
      [?on_open_change] to drive it, or neither to let it own its state. [?on_open_change] alone is
      an observation callback. [handleRef]'s open/close/toggle/isOpen thus all have a
      non-imperative equivalent.
    - {b [startIcon] is an icon {i name}, not a node} — the port's icons come from a generated
      registry, the same call [Field]'s label icon already makes. [triggerLabel] is a string
      likewise.
    - {b [children] is a plain function and cannot own Bonsai state.} It is called where the
      component's own state is in scope, so it closes over the current [value]/[commit]/[close]/
      [state] — a child that needs state of its own must be driven by the application (the value
      it commits is the value it receives back).
    - {b no [labelTooltip]} (the port's [Field] has none), and the container/control styling props
      ([containerXstyle] etc.) and the caller's [aria-describedby] override are not exposed.
    - The English strings are fixed: placeholder ["Choose..."] (upstream's own en catalogue),
      no i18n provider. The press-feedback transform is the campaign-wide named omission: the
      [active] scale is reproduced, the data-astryx-press overlay is not.

    {2 A note on ids}

    [id] is the trigger button's id (upstream semantics — the field label points at it), and
    [content_id = id ^ "-content"], [label_id = id ^ "-label"], description and status ids
    [id ^ "-desc"] / [id ^ "-status"] are derived. Pass a distinct [id] per instance on a page. *)

open! Core
open! Bonsai_web
open Js_of_ocaml

type variant =
  | Input  (** the field-input look — the default *)
  | Secondary  (** the secondary-button look: neutral fill, borderless *)
  | Ghost  (** the ghost-button look: borderless, transparent *)

type size = Input_types.size =
  | Sm
  | Md
  | Lg

type status = Input_types.status =
  { type_ : Field_status.type_
  ; message : string option
  }

type placement = Popover.placement =
  | Below
  | Above
  | Start
  | End

type alignment = Popover.alignment =
  | Align_start
  | Align_center
  | Align_end

type render_state =
  { is_open : bool
  ; is_busy : bool
  ; trigger_id : string
  ; content_id : string
  }

val view
  :  ?attrs:Vdom.Attr.t list
  -> ?id:string
  -> ?is_open:bool Bonsai.t
  -> ?on_open_change:(bool -> unit Effect.t) Bonsai.t
  -> ?on_click:(Dom_html.mouseEvent Js.t -> unit Effect.t)
  -> ?on_key_down:(Dom_html.keyboardEvent Js.t -> unit Effect.t)
  -> ?is_label_hidden:bool
  -> ?description:string
  -> ?is_optional:bool
  -> ?is_required:bool
  -> ?is_disabled:bool
  -> ?is_loading:bool
  -> ?status:status
  -> ?status_variant:Field_status.placement
  -> ?size:size
  -> ?variant:variant
  -> ?start_icon:string
  -> ?width:Common.Size_value.t
  -> ?placement:placement
  -> ?alignment:alignment
  -> ?trigger_label:string Bonsai.t
  -> ?placeholder:string
  -> label:string
  -> value:'v Bonsai.t
  -> ?on_change:('v -> unit Effect.t) Bonsai.t
  -> children:('v -> ('v -> unit Effect.t) -> (unit -> unit Effect.t) -> render_state -> Vdom.Node.t list)
  -> Bonsai.graph
  -> Vdom.Node.t Bonsai.t
(** [view ~label ~value ~children ()?>... (graph)].

    Defaults, all upstream's: [size = Md], [variant = Input], [placement = Below],
    [alignment = Align_start], [status_variant = Attached] — which upstream demotes to [Detached]
    for [Secondary]/[Ghost] selectors, and this port does the same. [is_loading = false].

    [children] is called on every render with the current [value] (never optimistic — see the
    divergence), [commit], [close] and the render state; the nodes it returns live inside the
    popup's content container, which is always in the DOM and hidden by the platform's
    [popover] mechanism.

    [trigger_label] is a computation, not a string: upstream builds its trigger text from the
    caller's state on every render, and so does the Bonsai caller — derive it from the same
    state [value] comes from. Omit it to show [placeholder]. *)
