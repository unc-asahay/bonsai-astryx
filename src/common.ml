(* Shared vocabulary for the port: spacing steps, size values, class names and
   the small CSS helpers the components share.

   Divergence from upstream, recorded deliberately: Astryx compiles StyleX to
   atomic CSS at build time. This port emits BEM-ish class names for structure
   and variants (so parity tests can compare them) and inline [style] attributes
   for the numeric props (gap, padding, width, height), which are per-instance
   values rather than reusable rules. The token *values* are the upstream ones —
   see src/tokens.ml and assets/tokens.css, both generated. *)

open! Core
open! Bonsai_web

module Spacing = struct
  (* Astryx's numeric spacing scale: 0, 0.5, 1, 1.5, 2, 3, 4, 5, 6, 8, 10.
     Token names use a dash for the half step: --spacing-0-5. *)
  type t =
    | S0
    | S0_5
    | S1
    | S1_5
    | S2
    | S3
    | S4
    | S5
    | S6
    | S8
    | S10
  [@@deriving sexp_of]

  let step = function
    | S0 -> "0"
    | S0_5 -> "0-5"
    | S1 -> "1"
    | S1_5 -> "1-5"
    | S2 -> "2"
    | S3 -> "3"
    | S4 -> "4"
    | S5 -> "5"
    | S6 -> "6"
    | S8 -> "8"
    | S10 -> "10"
  ;;

  let var t = sprintf "var(--spacing-%s)" (step t)

  let all = [ S0; S0_5; S1; S1_5; S2; S3; S4; S5; S6; S8; S10 ]
end

(* Which state a form treats as its default. Upstream declares this in FormLayout.tsx and passes it
   down through React context; the port puts the value here, next to the other shared value types,
   because the controls and the layout both need it and neither should own the other. *)
module Optionality = struct
  type t =
    | Optional
    | Required
end

module Size_value = struct
  (* Astryx: numbers are pixels, strings are used as-is. *)
  type t =
    | Px of int
    | Css of string

  let to_css = function
    | Px n -> sprintf "%dpx" n
    | Css s -> s
  ;;
end

(* Shared by Stack, Text and Heading. Astryx types these as one union whose legal
   values differ per axis: the main axis takes start|center|end|between|around|
   evenly, the cross axis takes start|center|end|stretch. Values that are illegal
   for the axis they land on fall back to that axis's neutral value. *)
module Alignment = struct
  type t =
    | Start
    | Center
    | End
    | Stretch
    | Between
    | Around
    | Evenly

  let to_string = function
    | Start -> "start"
    | Center -> "center"
    | End -> "end"
    | Stretch -> "stretch"
    | Between -> "between"
    | Around -> "around"
    | Evenly -> "evenly"
  ;;

  (* Cross axis: start | center | end | stretch. *)
  let cross_class = function
    | Start | Between -> "astryx-align--start"
    | Center | Around -> "astryx-align--center"
    | End | Evenly -> "astryx-align--end"
    | Stretch -> "astryx-align--stretch"
  ;;

  (* Main axis: start | center | end | between | around | evenly. *)
  let main_class = function
    | Start -> "astryx-justify--start"
    | Center -> "astryx-justify--center"
    | End -> "astryx-justify--end"
    | Between -> "astryx-justify--between"
    | Around -> "astryx-justify--around"
    | Evenly -> "astryx-justify--evenly"
    | Stretch -> "astryx-justify--start"
  ;;

  (* Text justification accepts only the cross-axis subset. *)
  let text_justify_class = function
    | Start -> "astryx-text--justify-start"
    | Center -> "astryx-text--justify-center"
    | End -> "astryx-text--justify-end"
    | Stretch | Between | Around | Evenly -> ""
  ;;
end

module Css = struct
  let of_pairs pairs = String.concat ~sep:"; " (List.map pairs ~f:(fun (k, v) -> sprintf "%s: %s" k v))
end

module Attr = struct
  let class_list classes = String.concat ~sep:" " (List.filter classes ~f:(Fn.non String.is_empty))

  (* [style] with empty pairs omitted, so an unstyled element carries no attribute. *)
  let style pairs =
    let pairs = List.filter pairs ~f:(fun (_, v) -> not (String.is_empty v)) in
    match pairs with
    | [] -> []
    | _ -> [ Vdom.Attr.create "style" (Css.of_pairs pairs) ]
  ;;

  let class_ classes =
    let s = class_list classes in
    if String.is_empty s then [] else [ Vdom.Attr.class_ s ]
  ;;

  let aria name value = [ Vdom.Attr.create (sprintf "aria-%s" name) value ]
  let aria_opt name = function Some v -> aria name v | None -> []
  let role r = [ Vdom.Attr.create "role" r ]

  (* data-* attributes are how the parity harness reads an element's intent, so
     every ported component states its own name and the props it received. *)
  let data name value = [ Vdom.Attr.create (sprintf "data-astryx-%s" name) value ]
end
