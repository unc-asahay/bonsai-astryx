(* This library's own Field, bound before the opens below. Core defines a module named Field as well
   (first-class fields), so after [open! Core] the unqualified name refers to Core's and this module would
   silently fail to compile against it. Same trap, same fix, as text_area.ml and radio_list.ml. *)
module Field_ = Field

open! Core
open! Bonsai_web

type size = Input_types.size =
  | Sm
  | Md
  | Lg

let size_class = function
  | Sm -> "astryx-input-group--sm"
  | Md -> "astryx-input-group--md"
  | Lg -> "astryx-input-group--lg"
;;

let view
  ?(attrs = [])
  ?(is_label_hidden = false)
  ?description
  ?(is_optional = false)
  ?(is_required = false)
  ?(is_disabled = false)
  ?(size = Md)
  ?status
  ~id
  ~label
  ~children
  ()
  =
  (* Ids are derived from the caller's, not generated here: upstream reaches for useId, which React keeps
     opaque, while every input in this port already takes its identity from its caller. Deriving keeps the
     rendered markup deterministic and a test able to name what it looks for. *)
  let label_id = id ^ "-label" in
  let group_id = id ^ "-group" in
  let group_attrs =
    ([ Vdom.Attr.class_
         (String.concat
            ~sep:" "
            (("astryx-input-group" :: size_class size :: [])
             @ (if is_disabled then [ "astryx-input-group--disabled" ] else [])))
     ; Vdom.Attr.create "id" group_id
     ; Vdom.Attr.create "role" "group"
     ; Vdom.Attr.create "aria-labelledby" label_id
     ]
     @ Common.Attr.data "component" "InputGroup"
     (* Upstream puts aria-describedby on this element, naming the description and the status message so that
        reaching the group announces them. This port's Field does not hand its description element's id back,
        so the link cannot be made from here - see the note in the mli. Not worked around by inventing an id
        that no element carries. *)
     @ attrs)
  in
  Field_.view
    ~is_label_hidden
    ?description
    ~is_optional
    ~is_required
    ~is_disabled
    ?status
    ~status_variant:Field_.Detached
    ~label
    ~label_id
    ~input_id:id
    ~is_group_label:true
    ~children:[ Vdom.Node.div ~attrs:group_attrs children ]
    ()
;;
