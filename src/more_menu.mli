(** A menu whose trigger is one button, labelled from its icon and its name.

    MoreMenu is upstream's thinnest component: 183 lines that hold nothing of their own. It is a
    {!Dropdown_menu} whose trigger is a specific Button - ghost, icon-only, the accessible name being the
    label - and whose open state the caller may own. That is why it arrives last of the menu family: it can
    only be a delegation once the menu underneath can be configured and controlled, which is what M23a added.
    The port's version is that delegation, with nothing invented in between.

    {2 Divergences}

    - Upstream defaults the label through its i18n catalogue ([@astryx.moreMenu.label]). The port has no
      catalogue, so [label] defaults to the English string [More] - the same default the catalogue holds, but
      a caller who needs another language must pass one.
    - Upstream's default icon is its [moreHorizontal] glyph. That icon is not in this port's set, so the
      default is the character [⋯] in a span that is hidden from assistive technology (the label is the
      accessible name, not the glyph). Pass [icon] to use anything else.
    - Upstream passes [hasChevron] false. The port's trigger renders no chevron in any case, so there is
      nothing to turn off and no argument for it.
    - [placement], [alignment] and [presentation] are not ported, the same gap {!Dropdown_menu} names: the
      port positions the menu from CSS.
    - The marker is [MoreMenu], passed down as the trigger's [component_name]. A component that delegates
      still has to name itself, or every tool that looks for markers finds the Button instead.
*)
open! Core
open! Bonsai_web

val view
  :  ?attrs:Vdom.Attr.t list
  -> ?id:string
  -> ?label:string
  -> ?variant:Button.variant
  -> ?size:Button.size
  -> ?icon:Vdom.Node.t
  -> ?is_disabled:bool
  -> ?is_open:bool Bonsai.t
  -> ?on_open_change:(bool -> unit Bonsai.Effect.t) Bonsai.t
  -> on_select:(Dropdown_menu.item -> unit Bonsai.Effect.t) Bonsai.t
  -> items:Dropdown_menu.entry list
  -> Bonsai.graph
  -> Vdom.Node.t Bonsai.t
