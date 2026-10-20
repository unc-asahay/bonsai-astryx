(* The Stepper showcase section: the multi-step flow control, in the variants
   upstream ships.

   Upstream's Stepper is a [Stepper] plus [Step] children that register
   themselves through React context. Bonsai has no context, so the port is
   data-driven: the steps are a list, and the current step is a value the
   caller owns. That is what the examples show - each clickable stepper owns
   its own current step and moves it when a step is clicked.

   The examples cover upstream's own stories: a horizontal flow, a vertical
   one, the indicator sitting on the track, the three densities, the
   statuses, the optional and disabled steps, a custom indicator, and the
   narrow container where the stepper collapses to a summary row.

   Every example carries a distinct DOM id, so the browser gate can address
   it: "showcase-stepper-<variant>". *)

open! Core
open! Bonsai_web
open Prelude

module S = Astryx.Stepper

let demo (graph : Bonsai.graph) : Vdom.Node.t Bonsai.t =
  let ex_tree label tree = Bonsai.map tree ~f:(fun node -> ex label node) in
  (* The four steps of the flow every example shows. *)
  let flow_steps =
    [ { S.label = "Account"
      ; description = Some "Your name and email"
      ; status = None
      ; is_disabled = false
      ; is_optional = false
      ; end_content = None
      ; indicator = None
      ; density = None
      ; content = []
      }
    ; { S.label = "Profile"
      ; description = Some "How you show up"
      ; status = Some S.Success
      ; is_disabled = false
      ; is_optional = false
      ; end_content = None
      ; indicator = None
      ; density = None
      ; content = []
      }
    ; { S.label = "Review"
      ; description = Some "Check it over"
      ; status = None
      ; is_disabled = false
      ; is_optional = false
      ; end_content = None
      ; indicator = None
      ; density = None
      ; content = []
      }
    ; { S.label = "Done"
      ; description = None
      ; status = None
      ; is_disabled = false
      ; is_optional = false
      ; end_content = None
      ; indicator = None
      ; density = None
      ; content = []
      }
    ]
  in
  (* A stepper that owns its current step, so a click moves it. *)
  let stepper ?id ?orientation ?density ?indicator_position ?horizontal_options
      ?(steps = flow_steps) () =
    let active, set_active = Bonsai.state 0 graph in
    let on_step_click =
      Bonsai.map set_active ~f:(fun set_active -> fun (i : int) -> set_active i)
    in
    S.view
      ?id
      ?orientation
      ?density
      ?indicator_position
      ?horizontal_options
      ~on_step_click
      ~active_step:active
      ~steps
      graph
  in
  (* The same four steps, with the statuses and the states upstream shows. *)
  let mixed_steps =
    [ { S.label = "Account"; description = None; status = Some S.Success
      ; is_disabled = false; is_optional = false; end_content = None
      ; indicator = None; density = None; content = [] }
    ; { S.label = "Profile"; description = None; status = Some S.Warning
      ; is_disabled = false; is_optional = false; end_content = None
      ; indicator = None; density = None; content = [] }
    ; { S.label = "Review"; description = None; status = Some S.Error
      ; is_disabled = false; is_optional = false; end_content = None
      ; indicator = None; density = None; content = [] }
    ; { S.label = "Optional step"; description = None; status = None
      ; is_disabled = false; is_optional = true; end_content = None
      ; indicator = None; density = None; content = [] }
    ; { S.label = "Unavailable"; description = None; status = None
      ; is_disabled = true; is_optional = false; end_content = None
      ; indicator = None; density = None; content = [] }
    ]
  in
  let custom_indicator_steps =
    [ { S.label = "First"; description = None; status = None
      ; is_disabled = false; is_optional = false; end_content = None
      ; indicator = Some (S.Custom (Astryx.Icon.view ~name:"info" ~size:Astryx.Icon.Md ()))
      ; density = None; content = [] }
    ; { S.label = "Second"; description = None; status = None
      ; is_disabled = false; is_optional = false; end_content = None
      ; indicator = Some (S.Custom (Astryx.Icon.view ~name:"check" ~size:Astryx.Icon.Md ()))
      ; density = None; content = [] }
    ; { S.label = "Third"; description = None; status = None
      ; is_disabled = false; is_optional = false; end_content = None
      ; indicator = None; density = None; content = [] }
    ]
  in
  let trees =
    [ ex_tree "horizontal" (stepper ~id:"showcase-stepper-horizontal" ())
    ; ex_tree "vertical" (stepper ~id:"showcase-stepper-vertical" ~orientation:S.Vertical ())
    ; ex_tree "the indicator on the track"
        (stepper ~id:"showcase-stepper-on-track" ~indicator_position:S.On_track ())
    ; ex_tree "the densities"
        (Bonsai.map
           (Bonsai.both
              (stepper ~id:"showcase-stepper-density-compact" ~density:S.Compact ())
              (stepper ~id:"showcase-stepper-density-spacious" ~density:S.Spacious ()))
           ~f:(fun (a, b) ->
             Vdom.Node.div
               ~attrs:[ Vdom.Attr.class_ "astryx-stack" ]
               [ a; b ]))
    ; ex_tree "the statuses, an optional step and a disabled one"
        (stepper ~id:"showcase-stepper-statuses" ~steps:mixed_steps ())
    ; ex_tree "a custom indicator"
        (stepper ~id:"showcase-stepper-custom-indicator" ~steps:custom_indicator_steps ())
    ; ex_tree "collapsed into a summary"
        (Bonsai.map
           (stepper
              ~id:"showcase-stepper-collapsed"
              ~horizontal_options:
                { S.minimum_step_width = 112
                ; collapsed_variant = S.With_label_and_controls
                }
              ())
           ~f:(fun node ->
             Vdom.Node.div
               ~attrs:[ Vdom.Attr.create "style" "width: 260px;" ]
               [ node ]))
    ]
  in
  let nodes = unwrap_all trees in
  Bonsai.map nodes ~f:(fun nodes ->
    section
      ~id:"stepper"
      ~title:"Stepper"
      ~note:
        "A multi-step flow: the current step is marked, the connectors show \
         how far along the flow is, and a narrow stepper collapses into a \
         summary row. Click a step to move the current one."
      [ Vdom.Node.div ~attrs:[ Vdom.Attr.class_ "showcase-row" ] nodes ])
;;
