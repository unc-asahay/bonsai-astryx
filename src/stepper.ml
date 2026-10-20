open! Core
open! Bonsai_web
open Js_of_ocaml

(* The Stepper - a multi-step flow control.

   Upstream splits this into a [Stepper] (the ordered list, the context, the
   responsive collapse) and a [Step] (one entry: indicator, label, status,
   body). Bonsai has no parent/child component context, so the two are
   flattened here: the steps are a plain list and the current step is a value
   the caller owns. Everything else - the progress vocabulary, the connector
   fill, the indicator presets, the accessible names, the compact collapse -
   follows upstream.

   Note on [None]: the [indicator] variant below has a [None] constructor, and
   it shadows [option]'s [None] for the rest of this file. Option's [None] is
   therefore spelled [none] in expression position here, and [None] in a
   pattern is resolved by the type of the value being matched. *)

(* Option's [None], bound before the [indicator] variant below declares a
   constructor of the same name. *)
let none : 'a option = None

type orientation =
  | Horizontal
  | Vertical

type density =
  | Compact
  | Balanced
  | Spacious

type indicator_position =
  | Separated
  | On_track

type status =
  | Accent
  | Success
  | Warning
  | Error

type indicator =
  | Auto
  | Number
  | None
  | Custom of Vdom.Node.t

type collapsed_variant =
  | With_label_and_controls
  | With_label
  | Hidden_label

type horizontal_options =
  {
    minimum_step_width : int
  ; collapsed_variant : collapsed_variant
  }

type step =
  {
    label : string
  ; description : string option
  ; status : status option
  ; is_disabled : bool
  ; is_optional : bool
  ; end_content : Vdom.Node.t option
  ; indicator : indicator option
  ; density : density option
  ; content : Vdom.Node.t list
  }

(* Where a step stands relative to the active one. Upstream calls this
   "progress" and uses it for the connector fill, the label colour and the
   indicator glyph. *)
type progress =
  | Completed
  | In_progress
  | Not_started

(* The glyph a step's status draws in its indicator. Upstream draws a tick
   for a success, a warning sign for a warning and a cross for an error; the
   neutral accent state draws nothing of its own. *)
type glyph =
  | Tick
  | Warning_glyph
  | Error_glyph

(* The parts of a step that are the same wherever the step is shown: the
   indicator, the label, the optional tag, the trailing content, the
   description and the status word. The compact summary shows the active
   step's parts too, so they are built once and shared. *)
type visual =
  { progress : progress
  ; is_active : bool
  ; indicator_node : Vdom.Node.t
  ; label_node : Vdom.Node.t
  ; optional_node : Vdom.Node.t option
  ; end_node : Vdom.Node.t option
  ; description_node : Vdom.Node.t option
  ; status_text : string option
  }

let orientation_name = function
  | Horizontal -> "horizontal"
  | Vertical -> "vertical"
;;

let density_name = function
  | Compact -> "compact"
  | Balanced -> "balanced"
  | Spacious -> "spacious"
;;

let indicator_position_name = function
  | Separated -> "separated"
  | On_track -> "on-track"
;;

let status_name = function
  | Accent -> "accent"
  | Success -> "success"
  | Warning -> "warning"
  | Error -> "error"
;;

(* The words upstream reads out of its translation namespaces. There is no
   translation layer here, so they are spelled out in English. *)
let default_label = "Progress"
let previous_step_label = "Previous step"
let next_step_label = "Next step"
let optional_label = "Optional"
let completed_word = "completed"
let warning_word = "warning"
let error_word = "error"

(* Upstream's default: a step narrower than this cannot hold its own label
   without breaking a word, so the stepper collapses instead. *)
let default_minimum_step_width = 112

(* The status word a step announces. Upstream: an error and a warning say
   themselves, a success says "completed", and a step that is behind the
   active one says "completed" even without a status of its own. A step that
   has not been reached stays silent. *)
let status_text ~progress ~status =
  match status with
  | Some Error -> Some error_word
  | Some Warning -> Some warning_word
  | Some Success -> Some completed_word
  | Some Accent | None ->
    (match progress with
     | Completed -> Some completed_word
     | In_progress | Not_started -> none)
;;

(* The width of the stepper's own list, measured with a ResizeObserver, is
   what decides whether a horizontal stepper collapses. Upstream measures the
   same thing on the same element; the measurement is a hook because the width
   is only knowable in the browser. *)
module Width_hook = struct
  module T = struct
    module State = struct
      type t =
        { mutable observer : Js.Unsafe.any option
        ; (* The last width reported, so the report is conditional: a resize
             that changes nothing must not send the graph round again. *)
          mutable last : int option
        }

      let create () = { observer = none; last = none }
    end

    module Input = struct
      type t = { on_measured : (int -> unit Effect.t) }

      (* Hand-written, like the house's other hooks: this project's ppx set
         has no sexp deriver, and the interface wants one. Only the parts
         worth reading in a log are shown. *)
      let sexp_of_t _ = Sexp.List []
      let combine left right =
        { on_measured =
            (fun value -> Effect.Many [ left.on_measured value; right.on_measured value ])
        }
      ;;
    end

    let width_of (el : Dom_html.element Js.t) : int =
      (* One JS call: this Js_of_ocaml does not coerce a boxed number for us,
         and offsetWidth is the border-box width. *)
      let js = Js.Unsafe.eval_string "(function (el) { return el.offsetWidth; })" in
      (Js.Unsafe.fun_call js [| Js.Unsafe.inject el |] : int)
    ;;

    let report (input : Input.t) state value =
      match state.State.last with
      | Some last when Poly.equal last value -> ()
      | _ ->
        state.last <- Some value;
        Effect.Expert.handle_non_dom_event_exn (input.on_measured value)
    ;;

    let measure (input : Input.t) state node =
      let el : Dom_html.element Js.t = Js.Unsafe.coerce node in
      report input state (width_of el)
    ;;

    let init _ _ = State.create ()

    let on_mount input state node =
      measure input state node;
      (* Its own observer. Built once, kept in the state, and torn down in
         [destroy]. *)
      let js =
        Js.Unsafe.eval_string
          "(function (el, fire) { if (typeof ResizeObserver === 'undefined') return null; \
           var observer = new ResizeObserver(function () { fire(); }); \
           observer.observe(el); return observer; })"
      in
      let fire = Js.wrap_callback (fun () -> measure input state node) in
      state.State.observer
        <- Some (Js.Unsafe.fun_call js [| Js.Unsafe.inject (Js.Unsafe.coerce node); Js.Unsafe.inject fire |])
    ;;

    let on_mount = `Schedule_immediately_after_this_dom_patch_completes on_mount
    let update ~old_input:_ ~new_input state node = measure new_input state node

    let destroy _ state _ =
      (match state.State.observer with
       | None -> ()
       | Some observer ->
         let js = Js.Unsafe.eval_string "(function (o) { o.disconnect(); })" in
         let (_ : unit) = Js.Unsafe.fun_call js [| Js.Unsafe.inject observer |] in
         ());
      state.State.observer <- none
    ;;
  end

  module Hook = Vdom.Attr.Hooks.Make (T)

  let attr ~on_measured =
    Vdom.Attr.create_hook "astryx-stepper-width" (Hook.create { T.Input.on_measured })
end

let view
    ?attrs
    ?id
    ?orientation
    ?label
    ?density
    ?indicator_position
    ?horizontal_options
    ?on_step_click
    ~active_step
    ~steps
    graph
  =
  let orientation = Option.value orientation ~default:Horizontal in
  let label = Option.value label ~default:default_label in
  let density = Option.value density ~default:Balanced in
  let indicator_position = Option.value indicator_position ~default:Separated in
  let horizontal_options =
    Option.value horizontal_options
      ~default:{ minimum_step_width = default_minimum_step_width
               ; collapsed_variant = With_label_and_controls
               }
  in
  let id = Option.value id ~default:"astryx-stepper" in
  let step_count = List.length steps in
  let is_horizontal =
    match orientation with
    | Horizontal -> true
    | Vertical -> false
  in
  (* The measured width of the stepper's own list. It is the input to the
     collapse decision, and it is a graph value because the browser is the
     only thing that knows it. *)
  let measured_width, set_measured_width = Bonsai.state 0 graph in
  let set_measured_width_f = Bonsai.map set_measured_width ~f:(fun set -> set) in
  (* The click callback is optional in the same way upstream's is: whether it
     is there decides whether the steps are navigable at all. The presence is
     read when the graph is built. *)
  let is_navigable = Option.is_some on_step_click in
  let click =
    match on_step_click with
    | None -> Bonsai.return (fun (_ : int) -> Effect.Ignore)
    | Some on_step_click -> Bonsai.map on_step_click ~f:(fun f -> f)
  in
  Bonsai.map3 active_step click (Bonsai.both measured_width set_measured_width_f)
    ~f:(fun active_step click (measured_width, set_measured_width) ->
      (* Upstream's rule: the width is shared out over the steps, and a step
         that gets less than the minimum width cannot hold its own label, so
         the whole stepper collapses. *)
      let is_compact =
        is_horizontal
        && measured_width > 0
        && step_count > 0
        && (measured_width / step_count) < horizontal_options.minimum_step_width
      in
      (* The parts of a step that are the same wherever the step is shown: the
         indicator, the label, the optional tag, the trailing content, the
         description and the status word. The summary row shows the active
         step's parts too, so they are built once and shared. *)
      let visual index step =
        let progress =
          if index < active_step then Completed
          else if index = active_step then In_progress
          else Not_started
        in
        let preset = Option.value step.indicator ~default:Auto in
        let custom_indicator =
          match preset with
          | Custom node -> Some node
          | Auto | Number | None -> none
        in
        (* Upstream only lets a status draw its own glyph in [auto] mode, and
           never on the active step: the active step keeps the ring that says
           "you are here". *)
        let status_glyph =
          match preset, custom_indicator, progress, step.status with
          | Auto, None, (Not_started | Completed), Some Success -> Some Tick
          | Auto, None, (Not_started | Completed), Some Warning -> Some Warning_glyph
          | Auto, None, (Not_started | Completed), Some Error -> Some Error_glyph
          | _ -> none
        in
        let show_number =
          match custom_indicator, status_glyph, preset with
          | None, None, Number -> true
          | None, None, Auto ->
            (match progress with
             | Not_started -> true
             | In_progress | Completed -> false)
          | _ -> false
        in
        let indicator_node =
          match preset with
          | None -> Vdom.Node.none
          | _ ->
            (* The shape decides how the indicator is painted: a number sits
               in a filled circle, a status glyph stands alone, and the two
               progress marks are drawn here rather than taken from the
               registry, as upstream draws them. *)
            let content, shape =
              match custom_indicator with
              | Some node -> node, "custom"
              | None ->
                (match status_glyph with
                 | Some Tick -> Icon.view ~size:Icon.Sm ~color:Icon.Success ~name:"success" (), "icon"
                 | Some Warning_glyph -> Icon.view ~size:Icon.Sm ~color:Icon.Warning ~name:"warning" (), "icon"
                 | Some Error_glyph -> Icon.view ~size:Icon.Sm ~color:Icon.Error ~name:"error" (), "icon"
                 | None ->
                   if show_number
                   then Vdom.Node.text (string_of_int (index + 1)), "number"
                   else
                     match progress with
                     | Completed ->
                       (* The completed mark is a filled circle with a check
                          in it. The check is the registry glyph, painted in
                          the circle's own surface colour. *)
                       ( Icon.view ~size:Icon.Sm ~color:Icon.Inherit ~name:"check" ()
                       , "check" )
                     | In_progress ->
                       (* Upstream's current-step glyph is a ring with a dot
                          in it. There is no ring in the icon registry, so it
                          is drawn here. *)
                       ( Vdom.Node.span
                           ~attrs:[ Vdom.Attr.class_ "astryx-stepper__ring" ]
                           []
                       , "ring" )
                     | Not_started -> Vdom.Node.text (string_of_int (index + 1)), "number")
            in
            Vdom.Node.span
              ~attrs:
                [ Vdom.Attr.class_
                    ("astryx-stepper__indicator astryx-stepper__indicator--" ^ shape) ]
              [ content ]
        in
        let label_node =
          Vdom.Node.span
            ~attrs:[ Vdom.Attr.class_ "astryx-stepper__label" ]
            [ Text.view ~type_:Text.Label [ Vdom.Node.text step.label ] ]
        in
        let optional_node =
          if step.is_optional
          then
            Some
              (Vdom.Node.span
                 ~attrs:[ Vdom.Attr.class_ "astryx-stepper__optional" ]
                 [ Vdom.Node.text optional_label ])
          else none
        in
        let end_node = step.end_content in
        let description_node =
          match step.description with
          | Some description ->
            Some
              (Vdom.Node.span
                 ~attrs:[ Vdom.Attr.class_ "astryx-stepper__description" ]
                 [ Text.view ~type_:Text.Supporting [ Vdom.Node.text description ] ])
          | None -> none
        in
        let status_text = status_text ~progress ~status:step.status in
        { progress
        ; is_active = (match progress with In_progress -> true | _ -> false)
        ; indicator_node
        ; label_node
        ; optional_node
        ; end_node
        ; description_node
        ; status_text
        }
      in
      (* One step. *)
      let step_node index step =
        let visual = visual index step in
        let is_on_track =
          match indicator_position with
          | On_track -> true
          | Separated -> false
        in
        (* Upstream: a step is clickable when it is not disabled, when the
           stepper is navigable at all, and when the stepper has not
           collapsed - a collapsed stepper navigates through its own
           controls, not through its steps. *)
        let is_clickable = (not step.is_disabled) && is_navigable && not is_compact in
        let aria_label =
          match visual.status_text with
          | None -> sprintf "Go to step %d: %s" (index + 1) step.label
          | Some status_text ->
            sprintf "Go to step %d: %s, %s" (index + 1) step.label status_text
        in
        let label_row =
          [ visual.label_node ]
          @ (match visual.optional_node with
             | Some node -> [ node ]
             | None -> [])
          @ (match visual.end_node with
             | Some node -> [ node ]
             | None -> [])
        in
        let row =
          if is_compact
          then
            (* A collapsed stepper keeps the list as a complete ordered
               sequence: every step restores its label, and its status, as
               hidden text. *)
            [ Visually_hidden.view [ Vdom.Node.text step.label ] ]
            @ (match visual.status_text with
               | Some status_text -> [ Visually_hidden.view [ Vdom.Node.text status_text ] ]
               | None -> [])
          else
            let row =
              (if is_on_track then [] else [ visual.indicator_node ])
              @ label_row
              @ (match visual.description_node with
                 | Some node -> [ node ]
                 | None -> [])
              @ (match visual.status_text with
                 | Some status_text when not is_clickable ->
                   [ Visually_hidden.view [ Vdom.Node.text status_text ] ]
                 | Some _ | None -> [])
            in
            if is_clickable
            then
              [ Vdom.Node.button
                  ~attrs:
                    [ Vdom.Attr.type_ "button"
                    ; Vdom.Attr.class_ "astryx-stepper__button"
                    ; Vdom.Attr.create "aria-label" aria_label
                    ; Vdom.Attr.on_click (fun (_ : Dom_html.mouseEvent Js.t) -> click index)
                    ]
                  row
              ]
            else [ Vdom.Node.div ~attrs:[ Vdom.Attr.class_ "astryx-stepper__row" ] row ]
        in
        (* The connector. Upstream draws a bar beside the step when the
           indicator is separated from the track, and the indicator sits on
           the track itself when it is on it. The bar is filled once the step
           is reached; the segment before the indicator is filled once the
           step is reached, the segment after it once the step is behind. *)
        let connector =
          if is_on_track
          then
            let before_filled = index <= active_step in
            let after_filled = index < active_step in
            let segment class_ =
              Vdom.Node.div
                ~attrs:
                  [ Vdom.Attr.class_ class_
                  ; Vdom.Attr.create "aria-hidden" "true"
                  ]
                []
            in
            Vdom.Node.div
              ~attrs:[ Vdom.Attr.class_ "astryx-stepper__track" ]
              [ segment
                  (if before_filled
                   then "astryx-stepper__segment astryx-stepper__segment--filled"
                   else "astryx-stepper__segment")
                ; visual.indicator_node
                ; segment
                  (if after_filled
                   then "astryx-stepper__segment astryx-stepper__segment--filled"
                   else "astryx-stepper__segment")
              ]
          else
            let filled =
              match visual.progress with
              | Completed | In_progress -> true
              | Not_started -> false
            in
            Vdom.Node.div
              ~attrs:
                [ Vdom.Attr.class_
                    (if filled
                     then "astryx-stepper__bar astryx-stepper__bar--filled"
                     else "astryx-stepper__bar")
                ; Vdom.Attr.create "aria-hidden" "true"
                ]
              []
        in
        let classes =
          Common.Attr.class_list
            ([ "astryx-stepper__step" ]
            @ (match visual.progress with
               | Completed -> [ "astryx-stepper__step--completed" ]
               | In_progress -> [ "astryx-stepper__step--active" ]
               | Not_started -> [ "astryx-stepper__step--not-started" ])
            @ (match step.status with
               | Some status -> [ "astryx-stepper__step--" ^ status_name status ]
               | None -> [])
            @ (match step.density with
               | Some density -> [ "astryx-stepper__step--" ^ density_name density ]
               | None -> [])
            @ (if step.is_disabled then [ "astryx-stepper__step--disabled" ] else [])
            @ (if step.is_optional then [ "astryx-stepper__step--optional" ] else []))
        in
        let attrs =
          [ Vdom.Attr.class_ classes ]
          @ (if visual.is_active
             then [ Vdom.Attr.create "aria-current" "step" ]
             else [])
          @ Common.Attr.data "step" (string_of_int index)
        in
        (* The body holds the step's label row and its content, so that the
           vertical layout can set the bar beside them both and the content
           under the label. *)
        let body =
          Vdom.Node.div
            ~attrs:[ Vdom.Attr.class_ "astryx-stepper__body" ]
            (row
            @ (match step.content with
               | [] -> []
               | content ->
                 [ Vdom.Node.div ~attrs:[ Vdom.Attr.class_ "astryx-stepper__content" ] content ]))
        in
        Vdom.Node.li ~attrs [ connector; body ]
      in
      (* The steps of the list. *)
      let step_nodes = steps |> List.mapi ~f:(fun index step -> step_node index step) in
      let list =
        Vdom.Node.ol
          ~attrs:
            [ Vdom.Attr.class_ "astryx-stepper__list"
            ; Vdom.Attr.create "aria-label" label
            ]
          step_nodes
      in
      (* The compact summary row. Upstream portals the active step's label
         into it; there is no portal here, so the stepper renders the same
         thing from the same step data. *)
      let shows_summary =
        is_compact
        && (match horizontal_options.collapsed_variant with
            | Hidden_label -> false
            | With_label | With_label_and_controls -> true)
      in
      let shows_controls =
        match horizontal_options.collapsed_variant with
        | With_label_and_controls -> is_navigable
        | With_label | Hidden_label -> false
      in
      let adjacent_enabled_step delta =
        let enabled =
          steps
          |> List.mapi ~f:(fun index step -> (index, step))
          |> List.filter_map ~f:(fun (index, step) ->
               if step.is_disabled then none else Some index)
        in
        match delta with
        | -1 ->
          enabled
          |> List.filter ~f:(fun index -> index < active_step)
          |> List.rev
          |> List.hd
        | _ ->
          enabled
          |> List.filter ~f:(fun index -> index > active_step)
          |> List.hd
      in
      let control delta label icon_name =
        match adjacent_enabled_step delta with
        | None -> none
        | Some target ->
          Some
            (Icon_button.view
               ~label
               ~icon:(Icon.view ~size:Icon.Sm ~name:icon_name ())
               ~variant:Button.Ghost
               ~on_click:(fun (_ : Dom_html.mouseEvent Js.t) -> click target)
               ())
      in
      let summary =
        if not shows_summary
        then []
        else
          let previous =
            if shows_controls then control (-1) previous_step_label "chevronLeft" else none
          in
          let next = if shows_controls then control 1 next_step_label "chevronRight" else none in
          (* The active step's own name, as upstream's summary shows it. *)
          let active_body =
            match List.nth steps active_step with
            | None -> []
            | Some step ->
              let visual = visual active_step step in
              let body =
                [ visual.indicator_node; visual.label_node ]
                @ (match visual.optional_node with
                   | Some node -> [ node ]
                   | None -> [])
                @ (match visual.description_node with
                   | Some node -> [ node ]
                   | None -> [])
              in
              [ Vdom.Node.div
                  ~attrs:[ Vdom.Attr.class_ "astryx-stepper__summary-body" ]
                  body
              ]
          in
          [ Vdom.Node.div
              ~attrs:[ Vdom.Attr.class_ "astryx-stepper__summary" ]
              ((match previous with
                | Some node -> [ node ]
                | None -> [])
              @ active_body
              @ (match next with
                 | Some node -> [ node ]
                 | None -> []))
          ]
      in
      let classes =
        Common.Attr.class_list
          ([ "astryx-stepper"
           ; "astryx-stepper--" ^ orientation_name orientation
           ; "astryx-stepper--" ^ density_name density
           ; "astryx-stepper--" ^ indicator_position_name indicator_position
           ]
          @ (if is_compact then [ "astryx-stepper--collapsed" ] else []))
      in
      let root_attrs =
        [ Vdom.Attr.class_ classes
        ; Vdom.Attr.id id
        ; Width_hook.attr ~on_measured:(fun width -> set_measured_width width)
        ]
        @ Common.Attr.data "component" "Stepper"
        @ Common.Attr.data "orientation" (orientation_name orientation)
        @ Common.Attr.data "density" (density_name density)
        @ Common.Attr.data "indicator-position" (indicator_position_name indicator_position)
        @ (match attrs with
           | Some attrs -> attrs
           | None -> [])
      in
      Vdom.Node.div ~attrs:root_attrs (list :: summary))
