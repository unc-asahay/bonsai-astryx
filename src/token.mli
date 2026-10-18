(* Token — mirrors Astryx's Token/Token.tsx: a chip for an entity inline.

   [label] is the one required argument and takes last positionally, like Badge,
   because it is the token's content rather than a configuration of it.

   Four rendering branches, upstream's order, and the order is the contract:

   1. resolved role = Link — a live [href] (not disabled) always wins.
      - no [on_remove]: the anchor IS the root, content inside it.
      - with [on_remove]: a <button> nested inside an <a> is invalid HTML
        (upstream's own reason, WCAG 4.1.2), so the root becomes a <span> and the
        link and the remove button render as SIBLINGS. Upstream's [TokenLink]
        wrapper additionally delegates container clicks to the inner link
        (middle-click, cmd/ctrl-click, text-selection guard) via
        [useClickableContainer]; that hook is ref machinery this port does not
        have, so the sibling structure is reproduced - which is the part that
        makes the markup valid - and the delegation is not. Clicking the icon or
        end area of a removable link token therefore does not activate the link.
        Named, not silently dropped.
   2. otherwise, with [on_click]: a <span> root whose label hides inside an
      invisible <button> (real button semantics), the root taking focus-within
      outline; the root's own click handler skips targets inside any button/anchor
      (upstream's [closest('button, a')] guard) and is absent when disabled.
   3. otherwise: a plain <span>.

   An [on_click] given together with a live [href] never fires - upstream's role
   priority resolves Link first and branch 1 never attaches the handler. A
   DISABLED [href] with an [on_click] resolves through [Interactive_role]'s later
   steps to Button and takes branch 2.

   Divergences, all recorded rather than dropped:

   - [xstyle]/[className]/[style] collapse into one [?attrs], port-wide.
   - No [useTranslator]: the remove button's accessible name is the English
     default 'Remove <label>' (upstream's en source for [@astryx.token.remove]);
     upstream's locale table is not ported.
   - No [usePressFeedback] controller: the constant [data-astryx-pressable]
     marker is reproduced (as [Selectable_card] and [Clickable_card] do), but the
     document-level controller that writes [data-astryx-press] under a touch is
     the press-feedback pillar, not yet ported - a mouse [::active] paints, a
     finger does not.
   - Role step 3 (interactive trigger context) has no port - see
     [Interactive_role]; upstream's [effectiveOnClick = onClick ?? context-noop]
     reduces here to [on_click] itself.
   - The href passes [Link_destination], this port's shared safe-destination
     contract (also applied by [Link] and [Citation]): a refused destination
     renders the same markup without it.
   - [aria-description] is reproduced verbatim, non-standard spelling and all -
     upstream writes it, and silently "correcting" it to [aria-describedby] would
     change the accessibility tree from under the upstream contract.

   Sizes and colours are upstream's: sm/md/lg against the element-size tokens
   (all three minus 8px), eleven colours including the neutral default. *)

open! Core
open Bonsai_web
open Js_of_ocaml

type size =
  | Sm
  | Md  (** the default *)
  | Lg

type color =
  | Default  (** the default *)
  | Red
  | Orange
  | Yellow
  | Green
  | Teal
  | Cyan
  | Blue
  | Purple
  | Pink
  | Gray

val view
  :  ?size:size
  -> ?color:color
  -> ?icon:Vdom.Node.t
  -> ?end_content:Vdom.Node.t
  -> ?is_disabled:bool
  -> ?is_label_hidden:bool
  -> ?description:string
  -> ?href:string
  -> ?on_click:(Dom_html.mouseEvent Js.t -> unit Effect.t)
  -> ?on_remove:(Dom_html.mouseEvent Js.t -> unit Effect.t)
  -> ?attrs:Vdom.Attr.t list
  -> string
  -> Vdom.Node.t