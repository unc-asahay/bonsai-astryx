(* Button — mirrors Astryx's Button/Button.tsx.

   Accessibility behaviour reproduced from upstream (not approximated):
     - isLoading: aria-busy + aria-disabled, *not* native disabled, so keyboard
       focus is never dropped mid-action; a visually hidden live region announces
       "Loading"; a spinner is rendered aria-hidden.
     - isDisabled: native disabled attribute (upstream switches to aria-disabled
       only when a tooltip is present, which this port does not support yet).
     - isIconOnly: the required [label] becomes aria-label instead of text.
   Divergence: React-only props (children, endContent, clickAction, as) are not
   modelled; supplying an href renders an <a>, otherwise a <button>. *)

open! Core
open! Bonsai_web

type variant =
  | Primary
  | Secondary
  | Ghost
  | Destructive

type size =
  | Sm
  | Md
  | Lg

type elevation =
  | E_none
  | Low
  | Med
  | High

type type_ =
  | Button
  | Submit
  | Reset

val view
  :  label:string
  -> ?variant:variant
  -> ?size:size
  -> ?elevation:elevation
  -> ?type_:type_
  -> ?is_loading:bool
  -> ?is_disabled:bool
  -> ?is_icon_only:bool
  -> ?icon:Vdom.Node.t
  -> ?width:Common.Size_value.t
  -> ?href:string
  -> ?target:string
  -> ?rel:string
  -> ?on_click:(Js_of_ocaml.Dom_html.mouseEvent Js_of_ocaml.Js.t -> unit Ui_effect.t)
  -> ?component_name:string
  (** What this element calls itself in [data-astryx-component] — "Button" unless a component that
      *delegates* to this one is naming itself (IconButton). The marker is how every tool here
      identifies a component, so a wrapper that could not name itself would be invisible to all of them;
      and the attribute cannot simply be passed in through [attrs], because virtual_dom warns and drops
      rather than letting two attributes of the same name meet. *)
  -> ?attrs:Vdom.Attr.t list
  -> Vdom.Node.t list
  -> Vdom.Node.t
