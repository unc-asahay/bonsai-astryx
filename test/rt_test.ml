(* Component-level rendering tests: every ported component, in isolation.

   Each case below builds one component (or one family of variants) and materialises
   it into the page under a [data-case] container. test/run.mjs then asserts on the
   DOM that comes out, and on the click case it asserts that a real event dispatched
   into the Bonsai graph changed the rendered output.

   Why split it that way: this side has to be OCaml because driving an event into a
   Bonsai component means using Bonsai_web_test's Handle — there is no way to do that
   from outside the program. Asserting on the DOM, on the other hand, is plain work
   best done where the DOM API is familiar. So OCaml renders and dispatches; node
   asserts.

   Unlike the demo-page gates, nothing here depends on the demo's composition: if a
   component's contract breaks in isolation, this is where it shows up. *)

open! Core
open! Bonsai_web
open Js_of_ocaml

module Button = Astryx.Button
module Text = Astryx.Text
module S = Astryx.Common.Spacing
module A = Astryx.Common.Alignment
module Size = Astryx.Common.Size_value

let document : Dom_html.document Js.t = Dom_html.document

(* Mount a rendered node in its own container named [case].

   Js.Unsafe.coerce rather than a coercion: Vdom.Node.to_dom hands back a
   [Dom.node Js.t] while appendChild wants the element type. The value really is an
   element at runtime — the types differ because the DOM class hierarchy is modelled
   as object types. *)
(* [ONLY_CASE=name] mounts a single case. Each case mounts independently, so this is
   how a warning or an exception that arrives without a stack — everything raised
   inside js_of_ocaml does — gets attributed to the case that caused it. *)
let case_filter =
  (* Read from the JS global [ONLY_CASE]; js_of_ocaml's stdlib here has no
     [getenv_opt] and matching [Not_found] trips Core's deprecation alert. *)
  Js.Optdef.to_option
    (Js.Unsafe.get Js.Unsafe.global "ONLY_CASE" : Js.js_string Js.t Js.Optdef.t)
  |> Option.map ~f:Js.to_string
;;

let mount (case : string) (node : Vdom.Node.t) =
  match case_filter with
  | Some only when not (String.equal only case) -> ()
  | _ ->
    let host = document##createElement (Js.string "div") in
    host##setAttribute (Js.string "data-case") (Js.string case);
    ignore (document##.body##appendChild (Js.Unsafe.coerce host));
    ignore (host##appendChild (Js.Unsafe.coerce (Vdom.Node.to_dom node)))
;;

let icon () = Vdom.Node.span ~attrs:[] [ Vdom.Node.text "+" ]

(* ---------------------------------------------------------------- rendering *)


let slider_component (graph : Bonsai.graph) =
  let value, set_value = Bonsai.state (Astryx.Slider.Single 25.) graph in
  let on_change = Bonsai.map set_value ~f:(fun set_value -> fun v -> set_value v) in
  let on_change_end = Bonsai.map set_value ~f:(fun set_value -> fun v -> set_value v) in
  let sr label msg = Some { Astryx.Input_types.type_ = label; message = Some msg } in
  let mk ?(id = "sl") ?(label = "sl label") ?(markers = None) ?(orientation = Astryx.Slider.Horizontal)
      ?(disabled = false) ?(required = false) ?(description = None) ?(status = None)
      ?(value_spec = None) ?(value_display = Astryx.Slider.Tooltip)
      graph =
    let value_t =
      match value_spec with Some v -> Bonsai.return v | None -> value
    in
    Astryx.Slider.view
      ~id ~label ~orientation
      ~is_disabled:disabled
      ?description
      ?status
      ~is_required:required
      ~value_display
      ?marks:markers
      ~value:value_t
      ~on_change
      ~on_change_end
      graph
  in
  let trees =
    [ mk ~id:"sl-basic" graph
    ; mk ~id:"sl-range" ~label:"range" ~value_spec:(Some (Astryx.Slider.Range (25., 75.))) graph
    ; mk ~id:"sl-disabled" ~disabled:true graph
    ; mk ~id:"sl-required" ~required:true ~label:"Required" graph
    ; mk ~id:"sl-desc" ~description:(Some "Adjust the amount") graph
    ; mk ~id:"sl-error" ~label:"Error" ~status:(sr Astryx.Input_types.Error "Out of range") graph
    ; mk ~id:"sl-marks" ~markers:(Some [ { Astryx.Slider.value = 0.; label = Some "0" }
                                       ; { Astryx.Slider.value = 50.; label = Some "50" }
                                       ; { Astryx.Slider.value = 100.; label = Some "100" } ]) graph
    ; mk ~id:"sl-vertical" ~orientation:Astryx.Slider.Vertical ~label:"Vertical" graph
    ]
  in
  let tree =
    List.fold trees ~init:(Bonsai.return []) ~f:(fun acc t ->
      Bonsai.map2 acc t ~f:(fun acc node -> acc @ [ node ]))
  in
  Bonsai.map tree ~f:(fun nodes -> Vdom.Node.div ~attrs:[ Vdom.Attr.id "sl-all" ] nodes)
;;

let () =
  (* Button: variants, sizes, elevations, states, types, link *)
  mount "button-default" (Button.view ~label:"Save" []);
  mount
    "button-variants"
    (Vdom.Node.div
       ~attrs:[]
       (List.map
          [ Button.Primary; Button.Secondary; Button.Ghost; Button.Destructive ]
          ~f:(fun variant -> Button.view ~variant ~label:"x" [])));
  mount
    "button-sizes"
    (Vdom.Node.div
       ~attrs:[]
       (List.map [ Button.Sm; Button.Md; Button.Lg ] ~f:(fun size ->
          Button.view ~size ~label:"x" [])));
  mount
    "button-elevation"
    (Vdom.Node.div
       ~attrs:[]
       (List.map [ Button.E_none; Button.Low; Button.Med; Button.High ] ~f:(fun elevation ->
          Button.view ~elevation ~label:"x" [])));
  mount "button-loading" (Button.view ~label:"Save" ~is_loading:true []);
  mount "button-disabled" (Button.view ~label:"Save" ~is_disabled:true []);
  mount "button-defaulting" (Button.view ~label:"Save" ~is_loading:true ~is_disabled:true []);
  mount "button-icon-only" (Button.view ~label:"Add item" ~is_icon_only:true ~icon:(icon ()) []);
  mount "button-with-icon" (Button.view ~label:"Add" ~icon:(icon ()) []);
  mount
    "button-link"
    (Button.view
       ~label:"Upstream"
       ~href:"https://github.com/facebook/astryx"
       ~target:"_blank"
       ~rel:"noreferrer"
       []);
  mount
    "button-types"
    (Vdom.Node.div
       ~attrs:[]
       (List.map [ Button.Button; Button.Submit; Button.Reset ] ~f:(fun type_ ->
          Button.view ~type_ ~label:"x" [])));
  (* StatusDot: every variant, plus pulsing *)
  mount
    "statusdot-all"
    (Vdom.Node.div
       ~attrs:[]
       (([ Astryx.StatusDot.Success; Warning; Error; Accent; Neutral ]
         |> List.map ~f:(fun variant ->
           Astryx.StatusDot.view
             ~variant
             ~label:
               (sprintf
                  "%s-dot"
                  (match variant with
                   | Astryx.StatusDot.Success -> "success"
                   | Warning -> "warning"
                   | Error -> "error"
                   | Accent -> "accent"
                   | Neutral -> "neutral"))
             ()))
        @ [ Astryx.StatusDot.view
              ~variant:Astryx.StatusDot.Accent
              ~label:"pulsing-dot"
              ~is_pulsing:true
              ()
          ]));
  (* Badge: every variant *)
  mount
    "badge-all"
    (Vdom.Node.div
       ~attrs:[]
       (List.map
          [ Astryx.Badge.Neutral; Info; Success; Warning; Error; Blue; Cyan; Green; Orange
          ; Pink; Purple; Red; Teal; Yellow
          ]
          ~f:(fun variant -> Astryx.Badge.view ~variant "badge")));
  (* Divider: orientations, weights, label *)
  mount
    "divider-all"
    (Vdom.Node.div
       ~attrs:[]
       [ Astryx.Divider.view ()
       ; Astryx.Divider.view ~variant:Astryx.Divider.Subtle ()
       ; Astryx.Divider.view ~variant:Astryx.Divider.Strong ()
       ; Astryx.Divider.view ~label:(Vdom.Node.text "or") ()
       ; Astryx.Divider.view ~orientation:Astryx.Divider.Vertical ()
       ]);
  (* Skeleton: radii *)
  mount
    "skeleton-all"
    (Vdom.Node.div
       ~attrs:[]
       (List.map
          [ Astryx.Skeleton.R_none; R0; R1; R2; R3; R4; Rounded ]
          ~f:(fun radius ->
            Astryx.Skeleton.view
              ~width:(Size.Px 100)
              ~height:(Size.Px 12)
              ~radius
              ())));
  (* Text: the scale, colours, weights *)
  mount
    "text-all"
    (Vdom.Node.div
       ~attrs:[]
       [ Text.view [ Vdom.Node.text "body" ]
       ; Text.view ~type_:Text.Large [ Vdom.Node.text "large" ]
       ; Text.view ~type_:Text.Label [ Vdom.Node.text "label" ]
       ; Text.view ~type_:Text.Code [ Vdom.Node.text "code" ]
       ; Text.view ~color:Text.Secondary [ Vdom.Node.text "secondary" ]
       ; Text.view ~weight:Text.Semibold [ Vdom.Node.text "semibold" ]
       ; Text.view ~has_tabular_numbers:true [ Vdom.Node.text "1234" ]
       ]);
  (* Heading: every level *)
  mount
    "heading-levels"
    (Vdom.Node.div
       ~attrs:[]
       (List.map [ Astryx.Heading.H1; H2; H3; H4; H5; H6 ] ~f:(fun level ->
          Astryx.Heading.view ~level [ Vdom.Node.text "h" ])));
  (* Stack: direction, alignment, wrap, gap *)
  mount
    "stack-all"
    (Vdom.Node.div
       ~attrs:[]
       [ Astryx.Stack.view
           ~direction:Astryx.Stack.Horizontal
           ~gap:S.S3
           ~align:A.Center
           [ Vdom.Node.text "a"; Vdom.Node.text "b" ]
       ; Astryx.Stack.view ~gap:S.S2 [ Vdom.Node.text "c" ]
       ; Astryx.Stack.view ~wrap:true ~justify:A.Between [ Vdom.Node.text "d" ]
       ]);
  (* Center: axes and inline *)
  mount
    "center-all"
    (Vdom.Node.div
       ~attrs:[]
       [ Astryx.Center.view ~axis:Astryx.Center.Both [ Vdom.Node.text "both" ]
       ; Astryx.Center.view ~axis:Astryx.Center.Horizontal [ Vdom.Node.text "h" ]
       ; Astryx.Center.view ~axis:Astryx.Center.Vertical [ Vdom.Node.text "v" ]
       ; Astryx.Center.view ~axis:Astryx.Center.Both ~is_inline:true [ Vdom.Node.text "i" ]
       ]);
  (* Section: variants and dividers *)
  mount
    "section-all"
    (Vdom.Node.div
       ~attrs:[]
       [ Astryx.Section.view [ Vdom.Node.text "plain" ]
       ; Astryx.Section.view ~variant:Astryx.Section.Muted [ Vdom.Node.text "muted" ]
       ; Astryx.Section.view
           ~dividers:[ Astryx.Section.Top; Astryx.Section.Bottom ]
           [ Vdom.Node.text "bordered" ]
       ]);
  (* Grid: track forms *)
  mount
    "grid-tracks"
    (Vdom.Node.div
       ~attrs:[]
       [ Astryx.Grid.view ~columns:(Astryx.Grid.Fixed 3) [ Vdom.Node.text "1" ]
       ; Astryx.Grid.view
           ~columns:(Astryx.Grid.Responsive (180, Astryx.Grid.Fill))
           [ Vdom.Node.text "2" ]
       ; Astryx.Grid.view
           ~columns:(Astryx.Grid.Responsive (180, Astryx.Grid.Fit))
           [ Vdom.Node.text "3" ]
       ]);
  (* Card: variants *)
  mount
    "card-all"
    (Vdom.Node.div
       ~attrs:[]
       [ Astryx.Card.view ~padding:S.S4 [ Vdom.Node.text "default" ]
       ; Astryx.Card.view ~variant:Astryx.Card.Muted ~padding:S.S4 [ Vdom.Node.text "muted" ]
       ]);
  (* VisuallyHidden: every element *)
  mount
    "visuallyhidden-all"
    (Vdom.Node.div
       ~attrs:[]
       [ Astryx.VisuallyHidden.view [ Vdom.Node.text "sr-span" ]
       ; Astryx.VisuallyHidden.view ~element:Astryx.VisuallyHidden.Div [ Vdom.Node.text "sr-div" ]
       ; Astryx.VisuallyHidden.view ~element:Astryx.VisuallyHidden.P [ Vdom.Node.text "sr-p" ]
       ])
;;

(* HStack / VStack: prop presets over Stack — upstream renders them through Stack,
   so they carry Stack's marker rather than one of their own. Axis defaults differ
   with direction, which is what these two cases pin down. *)
let () =
  mount
    "hstack-all"
    (Vdom.Node.div
       ~attrs:[]
       [ Astryx.HStack.view ~gap:S.S2 [ Vdom.Node.text "a"; Vdom.Node.text "b" ]
       ; Astryx.HStack.view ~h_align:A.Center ~gap:S.S1 [ Vdom.Node.text "c" ]
       ]);
  mount
    "vstack-all"
    (Vdom.Node.div
       ~attrs:[]
       [ Astryx.VStack.view ~gap:S.S2 [ Vdom.Node.text "a"; Vdom.Node.text "b" ]
       ; Astryx.VStack.view ~v_align:A.End ~gap:S.S1 [ Vdom.Node.text "c" ]
       ])
;;

(* AspectRatio: the two shapes, and all three fit values (plus the no-fit case,
   where the child is left to style itself). *)
let () =
  mount
    "aspect-ratio-all"
    (Vdom.Node.div
       ~attrs:[]
       [ Astryx.AspectRatio.view ~ratio:(16. /. 9.) [ Vdom.Node.text "16:9" ]
       ; Astryx.AspectRatio.view
           ~ratio:1.0
           ~shape:Astryx.AspectRatio.Ellipse
           ~fit:Astryx.AspectRatio.Cover
           [ Vdom.Node.text "1:1" ]
       ; Astryx.AspectRatio.view
           ~ratio:(4. /. 3.)
           ~fit:Astryx.AspectRatio.Center
           [ Vdom.Node.text "4:3" ]
       ])
;;

(* IconButton: a Button preset, so it inherits Button's marker AND its
   accessible-name contract — the label is now the only thing naming the control. *)
let () =
  mount
    "icon-button-all"
    (Vdom.Node.div
       ~attrs:[]
       [ Astryx.IconButton.view ~label:"Add item" ~icon:(icon ()) ()
       ; Astryx.IconButton.view ~label:"Delete" ~is_disabled:true ~icon:(icon ()) ()
       ; Astryx.IconButton.view ~label:"Saving" ~is_loading:true ~icon:(icon ()) ()
       ])
;;

(* Code and Blockquote: both are the element they claim to be, which is the part
   worth asserting (a <code> that renders a span is a different contract). *)
let () =
  mount
    "code-all"
    (Vdom.Node.div
       ~attrs:[]
       [ Astryx.Code.view [ Vdom.Node.text "primary" ]
       ; Astryx.Code.view ~color:Astryx.Code.Secondary [ Vdom.Node.text "secondary" ]
       ; Astryx.Code.view ~color:Astryx.Code.Inherit [ Vdom.Node.text "inherit" ]
       ; Astryx.Code.view ~size:Astryx.Code.Inherit [ Vdom.Node.text "sized" ]
       ]);
  mount
    "blockquote-all"
    (Vdom.Node.div
       ~attrs:[]
       [ Astryx.Blockquote.view [ Vdom.Node.text "plain quote" ]
       ; Astryx.Blockquote.view ~cite:(Vdom.Node.text "someone") [ Vdom.Node.text "cited" ]
       ])
;;

(* NavIcon, EmptyState and Citation — the M7 trio. *)
let () =
  mount
    "nav-icon-all"
    (Vdom.Node.div
       ~attrs:[]
       [ Astryx.NavIcon.view ~icon:(icon ()) ()
       ; Astryx.NavIcon.view ~icon:(Vdom.Node.span [ Vdom.Node.text "S" ]) ()
       ])
;;

let () =
  mount
    "empty-state-all"
    (Vdom.Node.div
       ~attrs:[]
       [ Astryx.EmptyState.view
           ~title:"No results"
           ~description:(Vdom.Node.text "Try a different search.")
           ~icon:(icon ())
           ~actions:
             [ Astryx.Button.view ~label:"Retry" []; Astryx.Button.view ~label:"Clear" [] ]
           ()
       ; Astryx.EmptyState.view
           ~heading_level:Astryx.EmptyState.H2
           ~title:"Nothing here yet"
           ~is_compact:true
           ()
       ])
;;

let () =
  mount
    "citation-all"
    (Vdom.Node.div
       ~attrs:[]
       [ (* a safe URL becomes a real link *)
         Astryx.Citation.view
           ~source:
             (Astryx.Citation.source
                ~title:"Designing with tokens"
                ~url:"https://example.com/spec"
                ())
           ~number:1
           ()
       ; (* a javascript: URL must not become a link, but must not vanish either *)
         Astryx.Citation.view
           ~source:(Astryx.Citation.source ~title:"Untrusted" ~url:"javascript:alert(1)" ())
           ~number:2
           ()
       ; (* no URL at all, and no title either: both fall back to the number *)
         Astryx.Citation.view ~source:(Astryx.Citation.source ()) ~number:3 ()
       ; Astryx.Citation.view
           ~variant:Astryx.Citation.Number
           ~source:(Astryx.Citation.source ~url:"https://example.com/a" ())
           ~number:4
           ()
       ; Astryx.Citation.view
           ~variant:Astryx.Citation.Number
           ~source:(Astryx.Citation.source ())
           ~number:5
           ()
       ; (* favicon path: a src supplied instead of an icon node *)
         Astryx.Citation.view
           ~source:
             (Astryx.Citation.source
                ~title:"With favicon"
                ~url:"https://example.com"
                ~src:"https://example.com/favicon.ico"
                ())
           ~number:6
           ()
       ])
;;

(* The safe-URL control, exercised through the compiled bundle rather than
   re-implemented in JavaScript: each row carries what the caller expects in
   [data-safe] and what the port actually decided as its text. The cases are the ones
   a naive prefix test gets wrong — a scheme spliced with a control character or a
   newline, a space before the colon, and mixed case. *)
let () =
  let cases =
    [ "https://example.com/spec", true
    ; "/relative/path", true
    ; "mailto:someone@example.com", true
    ; "data:image/png;base64,AAAA", true
    ; "javascript:alert(1)", false
    ; "JavaScript:alert(1)", false
    ; "javascript:   alert(1)", false
    ; (* A space BEFORE the colon is not a scheme at all, so this is not a javascript:
         URL — browsers resolve it as a relative path, and upstream allows it. Expecting
         a refusal here would be inventing policy. *)
      "JAVASCRIPT :alert(1)", true
    ; "java\x00script:alert(1)", false
    ; "java\nscript:alert(1)", false
    ; "  javascript:alert(1)  ", false
    ; "vbscript:msgbox(1)", false
    ; "data:text/html,<script>alert(1)</script>", false
    ]
  in
  mount
    "citation-safety"
    (Vdom.Node.div
       ~attrs:[]
       (List.map cases ~f:(fun (url, expected_safe) ->
          Vdom.Node.span
            ~attrs:
              ([ Vdom.Attr.create "data-url" url ]
               @ [ Vdom.Attr.create "data-safe" (Bool.to_string expected_safe) ])
            [ Vdom.Node.text (if Astryx.Citation.is_safe_url url then "safe" else "unsafe") ])))
;;

(* Icon — the generated glyph table, driven through the renderer. The point of these
   cases is the generator: a wrong path, a lost attribute or a namespace mistake shows
   up here rather than as a blank space in a screenshot. *)
let () =
  mount
    "icon-all"
    (Vdom.Node.div
       ~attrs:[]
       [ (* index 0: defaults — decorative, md, stroke wrapper *)
         Astryx.Icon.view ~name:"close" ()
       ; (* 1: the solid wrapper (fill, no stroke) *)
         Astryx.Icon.view ~name:"success" ()
       ; (* 2: an icon that overrides the wrapper's stroke-width *)
         Astryx.Icon.view ~name:"menu" ()
       ; (* 3: circle-only glyph *)
         Astryx.Icon.view ~name:"moreHorizontal" ()
       ; (* 4: rect + path glyph *)
         Astryx.Icon.view ~name:"calendar" ()
       ; (* 5: explicit size and colour *)
         Astryx.Icon.view ~size:Astryx.Icon.Lg ~color:Astryx.Icon.Red ~name:"warning" ()
       ; (* 6: a real label makes it a meaningful image *)
         Astryx.Icon.view ~label:"Delete row" ~name:"close" ()
       ; (* 7: an empty label is the same as no label *)
         Astryx.Icon.view ~label:"" ~name:"close" ()
       ; (* 8: an unknown name is visible, not silent *)
         Astryx.Icon.view ~name:"noSuchIcon" ()
       ; (* 9: the caller's own accessibility attributes win. The override is a
            duplicate name on one element — virtual_dom sets the later one (the
            same result React's attribute spread gives) but warns about it, and
            only the incoming attribute can silence it, so the caller's does. *)
         Astryx.Icon.view
           ~name:"close"
           ~attrs:
             [ Vdom.Attr.suppress_merge_warnings (Vdom.Attr.create "aria-hidden" "false")
             ; Vdom.Attr.create "role" "presentation"
             ]
           ()
       ; (* 10, 11: the remaining sizes, so every size class is exercised *)
         Astryx.Icon.view ~size:Astryx.Icon.Xsm ~name:"check" ()
       ; Astryx.Icon.view ~size:Astryx.Icon.Sm ~name:"check" ()
       ])
;;



(* FieldStatus — three types, both variants, and the first-paint animation rule. *)
let () =
  mount
    "field-status-all"
    (Vdom.Node.div
       ~attrs:[]
       [ (* 0,1,2: attached (the default) — bare text, no icon, no wrapper *)
         Astryx.Field_status.view
           ~type_:Astryx.Field_status.Warning
           ~message:"Careful: this cannot be undone."
           ()
       ; Astryx.Field_status.view
           ~type_:Astryx.Field_status.Error
           ~message:"That email is already in use."
           ()
       ; Astryx.Field_status.view ~type_:Astryx.Field_status.Success ~message:"Saved." ()
       ; (* 3,4: detached — icon + message *)
         Astryx.Field_status.view
           ~variant:Astryx.Field_status.Detached
           ~type_:Astryx.Field_status.Error
           ~message:"Detached error"
           ()
       ; Astryx.Field_status.view
           ~variant:Astryx.Field_status.Detached
           ~type_:Astryx.Field_status.Success
           ~message:"Detached success"
           ()
       ; (* 5: caller attrs are applied *)
         Astryx.Field_status.view
           ~type_:Astryx.Field_status.Warning
           ~message:"With a custom id"
           ~attrs:[ Vdom.Attr.id "status-custom" ]
           ()
       ])
;;


(* The part that has to be OCaml: a real event dispatched into the Bonsai graph.
   The rendered count goes into the DOM so run.mjs can assert on the component's
   own output rather than on internal state.

   Bonsai.map2 rather than let%sub/let%arr: in this release Bonsai.state takes the
   graph and returns a pair of trees, which is not the shape the ppx sugar expects. *)
let () =
  let component graph =
    let count, set_count = Bonsai.state 0 graph in
    Bonsai.map2 count set_count ~f:(fun count set_count ->
      Vdom.Node.div
        ~attrs:
          [ Vdom.Attr.create "data-click-count" (Int.to_string count)
          ; Vdom.Attr.create "data-case" "click-dispatch"
          ]
        [ Button.view
            ~label:"Increment"
            ~on_click:(fun _ -> set_count (count + 1))
            []
        ])
  in
  let handle = Bonsai_web_test.Handle.create (Bonsai_web_test.Result_spec.vdom Fn.id) component in
  (* before *)
  let before = Bonsai_web_test.Handle.last_result handle in
  mount "click-before" before;
  (* dispatch a real click on the button, then read the component's own output.
     recompute_view_until_stable is not optional: click_on only feeds the event into
     the graph, and last_result returns whatever the view last computed. Without this
     call the count reads 0 after a click that did happen. *)
  Bonsai_web_test.Handle.click_on
    handle
    ~get_vdom:Fn.id
    ~selector:"[data-astryx-component=Button]";
  Bonsai_web_test.Handle.recompute_view_until_stable handle;
  let after = Bonsai_web_test.Handle.last_result handle in
  mount "click-after" after;
  (* and a second click, to prove it is not a one-shot *)
  Bonsai_web_test.Handle.click_on
    handle
    ~get_vdom:Fn.id
    ~selector:"[data-astryx-component=Button]";
  Bonsai_web_test.Handle.recompute_view_until_stable handle;
  let after2 = Bonsai_web_test.Handle.last_result handle in
  mount "click-after-2" after2
;;

(* ------------------------------------------------------------- DropdownMenu --
   The first ported component that is a system rather than a leaf: a trigger, a
   surface, and rows reachable by pointer, keyboard and typeahead.

   What is asserted here, and what deliberately is not. The port drives its menu
   through the DOM exactly as upstream does — the highlight is DOM focus, and rows
   are found by querying the container — so its two most interesting behaviours are
   focus moves, and Bonsai's focus effects are no-ops under jsdom. Nor can the
   keyboard cases be written here: the test harness builds a keyboard event with an
   *empty* [key] (filling in only [keyCode]), and it appends its own fields after
   any [extra_event_fields], so a synthetic key cannot reach a handler that reads
   [event.key] the way upstream's does. Rather than assert a fiction, the keyboard
   and focus behaviour is asserted in the browser gate, against real key events.

   What is left is still the majority of the contract, and it is checked below:
   the trigger's ARIA, the always-present menu element (so [aria-controls] never
   dangles), rows that only exist while open, roles, the disabled row, the link
   row that is the anchor itself, group naming, a divider, a heading, and every
   state transition — open on click, a selection reaching the consumer, close. *)

module Dm = Astryx.Dropdown_menu

let dm_item
      ?description
      ?end_content
      ?icon
      ?(variant = Dm.Default)
      ?(is_disabled = false)
      ?href
      (id : string)
      (label : string)
  : Dm.item
  =
  { Dm.id
  ; label
  ; description
  ; end_content
  ; icon
  ; variant
  ; is_disabled
  ; href
  ; has_close_on_select = None
  }
;;

let dm_entries () : Dm.entry list =
  [ Dm.Item (dm_item ~description:"Create a file in this project" ~end_content:(Vdom.Node.text "⌘N") ~icon:"info" "new" "New file")
  ; Dm.Item (dm_item "open" "Open")
  ; Dm.Item (dm_item ~is_disabled:true "duplicate" "Duplicate")
  ; Dm.Divider
  ; Dm.Heading "Danger zone"
  ; Dm.Item (dm_item ~description:"This cannot be undone" ~icon:"error" ~variant:Dm.Destructive "delete" "Delete")
  ; Dm.Group
      { heading = Some "Sort by"
      ; items = [ dm_item "sort-name" "Name"; dm_item "sort-date" "Date" ]
      }
  ; Dm.Group { heading = None; items = [ dm_item "loose" "Loose row" ] }
  ; Dm.Item (dm_item ~href:"#menu-docs" "docs" "Documentation")
  ]
;;

(* The menu plus a record of what was selected: the selection has to be visible in
   the DOM, otherwise a passing test says nothing about the consumer receiving it. *)
let menu_component graph =
  let selected, set_selected = Bonsai.state (None : string option) graph in
  let on_select =
    Bonsai.map set_selected ~f:(fun set_selected (item : Dm.item) -> set_selected (Some item.id))
  in
  let menu = Dm.view ~id:"dm" ~trigger_label:"Actions" ~on_select ~entries:(dm_entries ()) graph in
  Bonsai.map2 selected menu ~f:(fun selected menu ->
    Vdom.Node.div
      ~attrs:[ Vdom.Attr.create "data-selected" (Option.value selected ~default:"-") ]
      [ menu ])
;;

let () =
  let handle = Bonsai_web_test.Handle.create (Bonsai_web_test.Result_spec.vdom Fn.id) menu_component in
  let snapshot case = mount case (Bonsai_web_test.Handle.last_result handle) in
  (* The harness's synthetic click provides [currentTarget] and the modifier keys but
     not [button], and its event proxy raises on any field a handler reads that it was
     not given — so the left button is supplied explicitly. *)
  let left_click = [ "button", Js.Unsafe.inject (Js.number_of_float 0.) ] in
  snapshot "dropdown-menu-closed";
  Bonsai_web_test.Handle.click_on handle ~get_vdom:Fn.id ~selector:"#dm-trigger" ~extra_event_fields:left_click;
  Bonsai_web_test.Handle.recompute_view_until_stable handle;
  snapshot "dropdown-menu-open";
  Bonsai_web_test.Handle.click_on
    handle
    ~get_vdom:Fn.id
    ~selector:"[data-astryx-menu-item=open]"
    ~extra_event_fields:left_click;
  Bonsai_web_test.Handle.recompute_view_until_stable handle;
  snapshot "dropdown-menu-selected"
;;

(* ---------------------------------------------------- Field + TextInput (M11) *)

(* One component, seven fields: one per thing the wiring has to get right. Static on purpose —
   what is under test here is the markup the field emits for a given set of props. *)
let field_static_component (_ : Bonsai.graph) =
  let value = Bonsai.return "acme" in
  let noop = Bonsai.return (fun (_ : string) -> Effect.Many []) in
  let field
        ?status
        ?status_variant
        ?is_disabled
        ?is_read_only
        ?is_label_hidden
        ?is_optional
        ?is_required
        ?description
        ~label
        ~id
        ()
    =
    Astryx.Text_input.view
      ~label
      ~id
      ?status
      ?status_variant
      ?is_disabled
      ?is_read_only
      ?is_label_hidden
      ?is_optional
      ?is_required
      ?description
      ~value
      ~on_change:noop
      ()
  in
  (* Every field is a value in the graph; a page can only take unwrapped nodes, and this Bonsai
     offers both/map2 rather than a list combinator. *)
  let unwrap_all nodes =
    List.fold nodes ~init:(Bonsai.return []) ~f:(fun acc node ->
      Bonsai.both acc node |> Bonsai.map ~f:(fun (acc, node) -> node :: acc))
    |> Bonsai.map ~f:List.rev
  in
  Bonsai.map
    (unwrap_all
       [ field ~label:"Full name" ~id:"rt-field-required" ~description:"On the invoice."
           ~is_required:true ()
       ; field ~label:"Email" ~id:"rt-field-optional" ~is_optional:true ()
       ; field
           ~label:"Workspace"
           ~id:"rt-field-error"
           ~status:{ Astryx.Input_types.type_ = Astryx.Input_types.Error; message = Some "That name is taken." } ()
       ; field
           ~label:"API key"
           ~id:"rt-field-detached"
           ~status:{ Astryx.Input_types.type_ = Astryx.Input_types.Success; message = Some "Verified." }
           ~status_variant:Astryx.Field_status.Detached ()
       ; field
           ~label:"Database"
           ~id:"rt-field-tooltip"
           ~status:{ Astryx.Input_types.type_ = Astryx.Input_types.Warning; message = Some "Read only." }
           ~status_variant:Astryx.Field_status.Tooltip ()
       ; field ~label:"Account id" ~id:"rt-field-hidden" ~is_label_hidden:true ~is_disabled:true ()
       ; field ~label:"Password" ~id:"rt-field-readonly" ~is_read_only:true ()
       ])
    ~f:(fun nodes -> Vdom.Node.div nodes)
;;

(* The interactive case: the harness types into the real input and the graph answers. jsdom has
   no keyboard of its own — the harness gives synthetic key events an empty key — so what can be
   checked here is that the control is genuinely controlled. Enter's behaviour belongs to the
   browser gate, where a real key event exists. *)
let field_interactive_component (graph : Bonsai.graph) =
  let name, set_name = Bonsai.state "" graph in
  let on_change = Bonsai.map set_name ~f:(fun set value -> set value) in
  let input =
    Astryx.Text_input.view
      ~label:"Name"
      ~id:"rt-field-live"
      ~is_required:true
      ~value:name
      ~on_change
      ()
  in
  let echo =
    Bonsai.map name ~f:(fun name ->
      Vdom.Node.div
        ~attrs:[ Vdom.Attr.create "data-rt-value" name ]
        [ Vdom.Node.text name ])
  in
  Bonsai.map2 input echo ~f:(fun input echo -> Vdom.Node.div [ input; echo ])
;;

let () =
  let handle =
    Bonsai_web_test.Handle.create (Bonsai_web_test.Result_spec.vdom Fn.id) field_static_component
  in
  mount "field-static" (Bonsai_web_test.Handle.last_result handle)
;;

let () =
  let handle =
    Bonsai_web_test.Handle.create
      (Bonsai_web_test.Result_spec.vdom Fn.id)
      field_interactive_component
  in
  mount "field-before" (Bonsai_web_test.Handle.last_result handle);
  Bonsai_web_test.Handle.input_text
    handle
    ~get_vdom:Fn.id
    ~selector:"#rt-field-live"
    ~text:"Ada Lovelace";
  Bonsai_web_test.Handle.recompute_view_until_stable handle;
  mount "field-after" (Bonsai_web_test.Handle.last_result handle)
;;

(* ---------------------------------------------------------------- TextArea (M12) *)

(* The same Field wrapper as M11 with a different control inside it, so these cases assert what is
   different about a textarea rather than re-testing the wiring: the element itself, the row
   count, the value that is not an attribute, and a status that carries no message at all. *)
let text_area_static_component (_ : Bonsai.graph) =
  let value = Bonsai.return "line one" in
  let noop = Bonsai.return (fun (_ : string) -> Effect.Many []) in
  let area ?status ?status_variant ?is_disabled ?is_read_only ?rows ?has_spell_check ~label ~id ()
    =
    Astryx.Text_area.view
      ~label
      ~id
      ?status
      ?status_variant
      ?is_disabled
      ?is_read_only
      ?rows
      ?has_spell_check
      ~value
      ~on_change:noop
      ()
  in
  let unwrap_all nodes =
    List.fold nodes ~init:(Bonsai.return []) ~f:(fun acc node ->
      Bonsai.both acc node |> Bonsai.map ~f:(fun (acc, node) -> node :: acc))
    |> Bonsai.map ~f:List.rev
  in
  Bonsai.map
    (unwrap_all
       [ area ~label:"Notes" ~id:"rt-textarea-default" ()
       ; area ~label:"Changelog" ~id:"rt-textarea-rows" ~rows:6 ()
       ; area
           ~label:"Commit summary"
           ~id:"rt-textarea-error"
           ~status:
             { Astryx.Input_types.type_ = Astryx.Input_types.Error; message = Some "Too long." }
           ()
       ; area
           ~label:"Deploy target"
           ~id:"rt-textarea-no-message"
           ~status:{ Astryx.Input_types.type_ = Astryx.Input_types.Warning; message = None }
           ()
       ; area ~label:"Frozen" ~id:"rt-textarea-disabled" ~is_disabled:true ()
       ; area
           ~label:"Reference"
           ~id:"rt-textarea-readonly"
           ~is_read_only:true
           ~has_spell_check:false
           ()
       ])
    ~f:(fun nodes -> Vdom.Node.div nodes)
;;

(* The interactive case, and the one behaviour a textarea has that an input does not: the value it
   reports contains newlines, because Enter is a character here rather than a submit. *)
let text_area_interactive_component (graph : Bonsai.graph) =
  let draft, set_draft = Bonsai.state "" graph in
  let on_change = Bonsai.map set_draft ~f:(fun set value -> set value) in
  let area =
    Astryx.Text_area.view
      ~label:"Release notes"
      ~id:"rt-textarea-live"
      ~rows:4
      ~value:draft
      ~on_change
      ()
  in
  let echo =
    Bonsai.map draft ~f:(fun draft ->
      Vdom.Node.div ~attrs:[ Vdom.Attr.create "data-rt-value" draft ] [ Vdom.Node.text draft ])
  in
  Bonsai.map2 area echo ~f:(fun area echo -> Vdom.Node.div [ area; echo ])
;;

let () =
  let handle =
    Bonsai_web_test.Handle.create
      (Bonsai_web_test.Result_spec.vdom Fn.id)
      text_area_static_component
  in
  mount "textarea-static" (Bonsai_web_test.Handle.last_result handle)
;;

let () =
  let handle =
    Bonsai_web_test.Handle.create
      (Bonsai_web_test.Result_spec.vdom Fn.id)
      text_area_interactive_component
  in
  mount "textarea-before" (Bonsai_web_test.Handle.last_result handle);
  Bonsai_web_test.Handle.input_text
    handle
    ~get_vdom:Fn.id
    ~selector:"#rt-textarea-live"
    ~text:"first line\nsecond line";
  Bonsai_web_test.Handle.recompute_view_until_stable handle;
  mount "textarea-after" (Bonsai_web_test.Handle.last_result handle)
;;

(* ---------------------------------------------------------------- FieldLabel (M12) *)

(* The label group on its own: the label names a control by id, the description is a sibling of it,
   and a group label is a <span> naming a set of controls rather than one. *)
let field_label_static_component (_ : Bonsai.graph) =
  let group
        ?label_icon
        ?label_id
        ?(is_group_label = false)
        ?(is_label_hidden = false)
        ?(is_disabled = false)
        ?(is_optional = false)
        ?(is_required = false)
        ?description
        ?description_id
        ~label
        ~input_id
        ()
    =
    Astryx.Field_label.view
      ?label_icon
      ?label_id
      ~is_group_label
      ~is_label_hidden
      ~is_disabled
      ~is_optional
      ~is_required
      ?description
      ?description_id
      ~label
      ~input_id
      ()
  in
  let control id =
    Vdom.Node.input ~attrs:[ Vdom.Attr.create "id" id; Vdom.Attr.create "type" "text" ] ()
  in
  let group_choices =
    Vdom.Node.div
      ~attrs:
        [ Vdom.Attr.create "role" "group"
        ; Vdom.Attr.create "aria-labelledby" "rt-fl-group-label"
        ]
      [ Vdom.Node.input
          ~attrs:
            [ Vdom.Attr.create "id" "rt-fl-group-a"
            ; Vdom.Attr.create "type" "checkbox"
            ; Vdom.Attr.create "aria-label" "Include the README"
            ]
          ()
      ]
  in
  (* A pure node, wrapped: a component's view is a value in the graph, and a static one is the
     simplest such value. *)
  Bonsai.return
    (Vdom.Node.div
       [ group
           ~label:"Workspace name"
        ~input_id:"rt-fl-named"
        ~description:"Shown in the sidebar."
        ~description_id:"rt-fl-named-desc"
        ()
    ; control "rt-fl-named"
    ; group ~label:"Billing email" ~input_id:"rt-fl-required" ~is_required:true ()
    ; group ~label:"Purchase order" ~input_id:"rt-fl-optional" ~is_optional:true ()
    ; group ~label:"Search scope" ~input_id:"rt-fl-icon" ~label_icon:"search" ()
    ; group ~label:"Account reference" ~input_id:"rt-fl-hidden" ~is_label_hidden:true ()
    ; group ~label:"Frozen field" ~input_id:"rt-fl-disabled" ~is_disabled:true ()
    ; group
        ~label:"Include in the release"
        ~input_id:"rt-fl-group-label"
        ~label_id:"rt-fl-group-label"
        ~is_group_label:true
        ()
       ; group_choices
       ])
;;

let () =
  let handle =
    Bonsai_web_test.Handle.create
      (Bonsai_web_test.Result_spec.vdom Fn.id)
      field_label_static_component
  in
  mount "fieldlabel-static" (Bonsai_web_test.Handle.last_result handle)
;;

(* ---------------------------------------------------------------- Indicator (M13) *)

(* The three kinds, with no control attached. The interesting assertions are the two absences: an
   unchecked bare check mark renders nothing at all, and a checkbox in the indeterminate state
   renders a bar instead of a tick. *)
let indicator_static_component (_ : Bonsai.graph) =
  let mark ?(is_disabled = false) id ~kind ~state ~size =
    Vdom.Node.div
      ~attrs:[ Vdom.Attr.create "id" id ]
      [ Astryx.Indicator.view ~kind ~state ~size ~is_disabled () ]
  in
  let open Astryx.Indicator in
  Bonsai.return
    (Vdom.Node.div
       [ mark "rt-ind-cb-un" ~kind:Checkbox ~state:Unchecked ~size:Md
       ; mark "rt-ind-cb-on" ~kind:Checkbox ~state:Checked ~size:Md
       ; mark "rt-ind-cb-mixed" ~kind:Checkbox ~state:Indeterminate ~size:Md
       ; mark "rt-ind-cb-sm" ~kind:Checkbox ~state:Checked ~size:Sm
       ; mark "rt-ind-cb-dis" ~kind:Checkbox ~state:Checked ~size:Md ~is_disabled:true
       ; mark "rt-ind-radio-off" ~kind:Radio ~state:Unchecked ~size:Md
       ; mark "rt-ind-radio-on" ~kind:Radio ~state:Checked ~size:Md
       ; mark "rt-ind-check-off" ~kind:Check ~state:Unchecked ~size:Md
       ; mark "rt-ind-check-on" ~kind:Check ~state:Checked ~size:Md
       ])
;;

let () =
  let handle =
    Bonsai_web_test.Handle.create
      (Bonsai_web_test.Result_spec.vdom Fn.id)
      indicator_static_component
  in
  mount "indicator-static" (Bonsai_web_test.Handle.last_result handle)
;;

(* ---------------------------------------------------------------- CheckboxInput (M12) *)

let checkbox_input_static_component (_ : Bonsai.graph) =
  let open Astryx in
  let no_change = Bonsai.return (fun (_ : Checkbox_input.value) -> Effect.Many []) in
  (* The control is a tree, so the examples have to be joined rather than nested — a plain node
     cannot hold a Bonsai.t. *)
  let join_all trees =
    List.fold trees ~init:(Bonsai.return []) ~f:(fun acc tree ->
      Bonsai.map2 acc tree ~f:(fun acc node -> acc @ [ node ]))
  in
  let box ?is_disabled ?is_read_only ?is_label_hidden ?is_optional ?is_required ?description
        ?description_id ?status ?size ~label ~id value
    =
    Checkbox_input.view
      ?is_disabled
      ?is_read_only
      ?is_label_hidden
      ?is_optional
      ?is_required
      ?description
      ?description_id
      ?status
      ?size
      ~label
      ~id
      ~value:(Bonsai.return value)
      ~on_change:no_change
      ()
  in
  let boxes =
    [ box ~label:"Selected" ~id:"rt-cb-on" Checkbox_input.Checked
       ; box ~label:"Not selected" ~id:"rt-cb-off" Checkbox_input.Unchecked
       ; box ~label:"Partly selected" ~id:"rt-cb-mixed" Checkbox_input.Indeterminate
       ; box
           ~label:"With a description"
           ~id:"rt-cb-described"
           ~description:"The notes are short."
           ~description_id:"rt-cb-described-desc"
           Checkbox_input.Unchecked
       ; box
           ~label:"In error"
           ~id:"rt-cb-error"
           ~status:
             { Input_types.type_ = Input_types.Error; message = Some "Read them first." }
           Checkbox_input.Unchecked
       ; box
           ~label:"Warnings only"
           ~id:"rt-cb-warning"
           ~status:{ Input_types.type_ = Input_types.Warning; message = None }
           Checkbox_input.Unchecked
       ; box ~label:"Disabled" ~id:"rt-cb-disabled" ~is_disabled:true Checkbox_input.Checked
       ; box ~label:"Read only" ~id:"rt-cb-readonly" ~is_read_only:true Checkbox_input.Unchecked
       ; box ~label:"Hidden label" ~id:"rt-cb-hidden" ~is_label_hidden:true Checkbox_input.Checked
       ; box ~label:"Required" ~id:"rt-cb-required" ~is_required:true Checkbox_input.Unchecked
    ; box ~label:"Optional" ~id:"rt-cb-optional" ~is_optional:true Checkbox_input.Unchecked
    ]
  in
  Bonsai.map (join_all boxes) ~f:(fun boxes -> Vdom.Node.div boxes)
;;

let () =
  let handle =
    Bonsai_web_test.Handle.create
      (Bonsai_web_test.Result_spec.vdom Fn.id)
      checkbox_input_static_component
  in
  mount "checkbox-static" (Bonsai_web_test.Handle.last_result handle)
;;

(* ---------------------------------------------------------------- Switch (M12) *)

let switch_static_component (_ : Bonsai.graph) =
  let open Astryx in
  let no_change = Bonsai.return (fun (_ : bool) -> Effect.Many []) in
  let join_all trees =
    List.fold trees ~init:(Bonsai.return []) ~f:(fun acc tree ->
      Bonsai.map2 acc tree ~f:(fun acc node -> acc @ [ node ]))
  in
  let sw ?is_disabled ?is_label_hidden ?is_optional ?is_required ?description ?description_id
        ?status ?size ~label ~id value
    =
    Switch.view
      ?is_disabled
      ?is_label_hidden
      ?is_optional
      ?is_required
      ?description
      ?description_id
      ?status
      ?size
      ~label
      ~id
      ~value:(Bonsai.return value)
      ~on_change:no_change
      ()
  in
  let switches =
    [ sw ~label:"On" ~id:"rt-sw-on" true
    ; sw ~label:"Off" ~id:"rt-sw-off" false
    ; sw
        ~label:"With a description"
        ~id:"rt-sw-described"
        ~description:"Follows the system setting."
        ~description_id:"rt-sw-described-desc"
        false
    ; sw
        ~label:"In error"
        ~id:"rt-sw-error"
        ~status:{ Input_types.type_ = Input_types.Error; message = Some "Cannot be turned off." }
        true
    ; sw ~label:"Disabled" ~id:"rt-sw-disabled" ~is_disabled:true true
    ; sw ~label:"Hidden label" ~id:"rt-sw-hidden" ~is_label_hidden:true true
    ; sw ~label:"Required" ~id:"rt-sw-required" ~is_required:true false
    ; sw ~label:"Small" ~id:"rt-sw-sm" ~size:Indicator.Sm true
    ]
  in
  Bonsai.map (join_all switches) ~f:(fun switches -> Vdom.Node.div switches)
;;

let () =
  let handle =
    Bonsai_web_test.Handle.create
      (Bonsai_web_test.Result_spec.vdom Fn.id)
      switch_static_component
  in
  mount "switch-static" (Bonsai_web_test.Handle.last_result handle)
;;

(* ---------------------------------------------------------------- RadioList (M13) *)

let radio_list_static_component (_ : Bonsai.graph) =
  let open Astryx in
  let no_change = Bonsai.return (fun (_ : string) -> Effect.Many []) in
  let item ?(description = None) ?(is_disabled = false) value label =
    { Radio_list.value; label; description; is_disabled }
  in
  let group ?(is_disabled = false) ?(is_label_hidden = false) ?(is_optional = false)
        ?(is_required = false) ?(orientation = Radio_list.Vertical) ?description ?status ~label ~id
        ~value items
    =
    Radio_list.view
      ~label
      ~id
      ~items
      ~is_disabled
      ~is_label_hidden
      ~is_optional
      ~is_required
      ~orientation
      ?description
      ?status
      ~value:(Bonsai.return value)
      ~on_change:no_change
      ()
  in
  let join_all trees =
    List.fold trees ~init:(Bonsai.return []) ~f:(fun acc tree ->
      Bonsai.map2 acc tree ~f:(fun acc node -> acc @ [ node ]))
  in
  let groups =
    [ group
        ~label:"Shipping"
        ~id:"rt-rl-live"
        ~value:"express"
        ~description:"Express is the default."
        [ item "standard" "Standard"
        ; item ~description:(Some "Arrives tomorrow.") "express" "Express"
        ; item "pickup" "Pick up"
        ]
    ; group
        ~label:"Warranty"
        ~id:"rt-rl-status"
        ~value:"one"
        ~status:{ Input_types.type_ = Input_types.Error; message = Some "Pick one." }
        [ item "one" "One year"; item "three" "Three years" ]
    ; group
        ~label:"Plan"
        ~id:"rt-rl-disabled"
        ~value:"free"
        ~is_disabled:true
        [ item "free" "Free"; item "pro" "Pro" ]
    ; group
        ~label:"Period"
        ~id:"rt-rl-disabled-item"
        ~value:"monthly"
        [ item "monthly" "Monthly"; item ~is_disabled:true "annual" "Annual" ]
    ; group ~label:"Alignment" ~id:"rt-rl-horizontal" ~value:"start"
        ~orientation:Radio_list.Horizontal
        [ item "start" "Start"; item "center" "Centre" ]
    ; group ~label:"Contact" ~id:"rt-rl-required" ~value:"email" ~is_required:true
        [ item "email" "Email"; item "phone" "Phone" ]
    ; group ~label:"Theme" ~id:"rt-rl-hidden" ~value:"light" ~is_label_hidden:true
        [ item "light" "Light"; item "dark" "Dark" ]
    ]
  in
  Bonsai.map (join_all groups) ~f:(fun groups -> Vdom.Node.div groups)
;;

let () =
  let handle =
    Bonsai_web_test.Handle.create
      (Bonsai_web_test.Result_spec.vdom Fn.id)
      radio_list_static_component
  in
  mount "radio-list-static" (Bonsai_web_test.Handle.last_result handle)
;;

(* ---------------------------------------------------------------- FormLayout (M13) *)

let form_layout_static_component (_ : Bonsai.graph) =
  let open Astryx in
  let no_change = Bonsai.return (fun (_ : string) -> Effect.Many []) in
  let field ?(is_optional = false) ?(is_required = false) ?optionality label id =
    Text_input.view
      ~label
      ~id
      ~is_optional
      ~is_required
      ?optionality
      ~value:(Bonsai.return "")
      ~on_change:no_change
      ()
  in
  let join_all trees =
    List.fold trees ~init:(Bonsai.return []) ~f:(fun acc tree ->
      Bonsai.map2 acc tree ~f:(fun acc node -> acc @ [ node ]))
  in
  let layout ?(direction = Form_layout.Vertical) fields =
    Bonsai.map (join_all fields) ~f:(fun children -> Form_layout.view ~direction ~children ())
  in
  let opt = Form_layout.Optional in
  let req = Form_layout.Required in
  let trees =
    [ layout [ field "Name" "rt-fl-v-name"; field "Email" "rt-fl-v-email" ]
    ; layout ~direction:Form_layout.Horizontal
        [ field "City" "rt-fl-h-city"; field "Postcode" "rt-fl-h-post" ]
    ; layout ~direction:Form_layout.Horizontal_labels
        [ field "Account" "rt-fl-l-account"; field "Region" "rt-fl-l-region" ]
    ; layout
        [ field ~optionality:opt ~is_required:true "Email" "rt-fl-opt-email"
        ; field ~optionality:opt "Nickname" "rt-fl-opt-nick"
        ]
    ; layout
        [ field ~optionality:req "Email" "rt-fl-req-email"
        ; field ~optionality:req ~is_optional:true "Nickname" "rt-fl-req-nick"
        ]
    ; layout
        [ field ~is_required:true "Email" "rt-fl-both-email"
        ; field ~is_optional:true "Nickname" "rt-fl-both-nick"
        ]
    ; layout [ field "Company" "rt-fl-nest-company"; layout ~direction:Form_layout.Horizontal [ field "Town" "rt-fl-nest-town" ] ]
    ]
  in
  Bonsai.map (join_all trees) ~f:(fun children -> Vdom.Node.div children)
;;

let () =
  let handle =
    Bonsai_web_test.Handle.create
      (Bonsai_web_test.Result_spec.vdom Fn.id)
      form_layout_static_component
  in
  mount "form-layout-static" (Bonsai_web_test.Handle.last_result handle)
;;

(* ---------------------------------------------------------------- Tooltip (M13) *)

let tooltip_static_component (graph : Bonsai.graph) =
  let open Astryx in
  let join_all trees =
    List.fold trees ~init:(Bonsai.return []) ~f:(fun acc tree ->
      Bonsai.map2 acc tree ~f:(fun acc node -> acc @ [ node ]))
  in
  let trigger id label =
    Vdom.Node.span ~attrs:[ Vdom.Attr.create "id" id ] [ Vdom.Node.text label ]
  in
  let tip ?(placement = Tooltip.Above) ?(alignment = Tooltip.Center) ?is_open ~id ~content trigger
    =
    Tooltip.view ~placement ~alignment ?is_open ~id:(id ^ "-message") ~content ~trigger graph
  in
  let trees =
    [ tip ~id:"rt-tip-closed" ~content:"Hidden until asked for." (trigger "rt-tip-closed-trigger" "Trigger")
    ; tip ~is_open:true ~id:"rt-tip-open" ~content:"Open because the caller says so."
        (trigger "rt-tip-open-trigger" "Trigger")
    ; tip ~is_open:true ~placement:Tooltip.Below ~alignment:Tooltip.End ~id:"rt-tip-placed"
        ~content:"Placed." (trigger "rt-tip-placed-trigger" "Trigger")
    ]
  in
  Bonsai.map (join_all trees) ~f:(fun children -> Vdom.Node.div children)
;;

let () =
  let handle =
    Bonsai_web_test.Handle.create
      (Bonsai_web_test.Result_spec.vdom Fn.id)
      tooltip_static_component
  in
  mount "tooltip-static" (Bonsai_web_test.Handle.last_result handle)
;;

(* ------------------------------------------------- disabledMessage (M13) *)

(* The contract in one place: a disabled control *with* a reason drops the native disabled attribute
   for aria-disabled plus form="" — so it stays focusable and submits nothing — renders the reason
   and describes it; a disabled control *without* a reason keeps the native attribute it always had;
   and a reason on an enabled control changes nothing at all. *)
let disabled_message_static (_ : Bonsai.graph) =
  let open Astryx in
  let no_checkbox_change = Bonsai.return (fun (_ : Checkbox_input.value) -> Effect.Many []) in
  let no_switch_change = Bonsai.return (fun (_ : bool) -> Effect.Many []) in
  let join_all trees =
    List.fold trees ~init:(Bonsai.return []) ~f:(fun acc tree ->
      Bonsai.map2 acc tree ~f:(fun acc node -> acc @ [ node ]))
  in
  let checkbox ?is_disabled ?disabled_message ~id value =
    Checkbox_input.view
      ?is_disabled
      ?disabled_message
      ~label:"Managed setting"
      ~description:"A description that must survive the merge."
      ~description_id:(id ^ "-description")
      ~id
      ~value:(Bonsai.return value)
      ~on_change:no_checkbox_change
      ()
  in
  let switch ?is_disabled ?disabled_message ~id value =
    Switch.view
      ?is_disabled
      ?disabled_message
      ~label:"Managed switch"
      ~id
      ~value:(Bonsai.return value)
      ~on_change:no_switch_change
      ()
  in
  join_all
    [ checkbox
        ~is_disabled:true
        ~disabled_message:"Your administrator manages this."
        ~id:"dm-checkbox-reason"
        Checkbox_input.Checked
    ; checkbox ~is_disabled:true ~id:"dm-checkbox-noreason" Checkbox_input.Unchecked
    ; checkbox ~disabled_message:"Ignored while the control is enabled." ~id:"dm-checkbox-enabled"
        Checkbox_input.Checked
    ; switch
        ~is_disabled:true
        ~disabled_message:"Enforced by your organisation."
        ~id:"dm-switch-reason"
        true
    ]
  |> Bonsai.map ~f:(fun children -> Vdom.Node.div children)
;;

let () =
  Bonsai_web_test.Handle.create
    (Bonsai_web_test.Result_spec.vdom Fn.id)
    disabled_message_static
  |> fun handle -> mount "disabled-message" (Bonsai_web_test.Handle.last_result handle)
;;

(* ---------------------------------------------------------------- Dialog (M14) *)

(* jsdom has no dialog behaviour at all — showModal and close do not exist on its elements — so this
   gate presses the half it can: the inline path, which is the structure without any modality, and
   the fact that the *modal* path renders and reports without throwing where the platform has no
   dialog. The modal behaviour itself (top layer, focus trap, Escape, backdrop) belongs to a real
   browser and is pressed there. *)
let dialog_static (_ : Bonsai.graph) =
  let open Astryx in
  let no_change = Bonsai.return (fun (_ : bool) -> Effect.Many []) in
  let join_all trees =
    List.fold trees ~init:(Bonsai.return []) ~f:(fun acc tree ->
      Bonsai.map2 acc tree ~f:(fun acc node -> acc @ [ node ]))
  in
  let title id = Vdom.Node.div ~attrs:[ Vdom.Attr.create "id" id ] [ Vdom.Node.text "Title" ] in
  let body = Vdom.Node.div [ Vdom.Node.text "Body" ] in
  let dialog ?is_inline ?purpose ?variant ?width ?position ~is_open ~id () =
    Dialog.view
      ?is_inline
      ?purpose
      ?variant
      ?width
      ?position
      ~labelled_by:(id ^ "-title")
      ~is_open:(Bonsai.return is_open)
      ~on_open_change:no_change
      ~id
      ~children:(Bonsai.return [ title (id ^ "-title"); body ])
      ()
  in
  join_all
    [ dialog ~is_inline:true ~is_open:true ~id:"dlg-inline" ()
    ; (* closed inline renders nothing at all: upstream returns null, and so does this *)
      dialog ~is_inline:true ~is_open:false ~id:"dlg-inline-closed" ()
    ; dialog
        ~is_inline:true
        ~purpose:Dialog.Required
        ~is_open:true
        ~id:"dlg-inline-required" ()
    ; dialog ~is_inline:true ~variant:Dialog.Fullscreen ~is_open:true
        ~id:"dlg-inline-fullscreen" ()
    ; dialog
        ~is_inline:true
        ~width:"28rem"
        ~position:{ Dialog.top = Some "4rem"; bottom = None; start = None; end_ = None }
        ~is_open:true
        ~id:"dlg-inline-sized" ()
      (* the modal path, in a realm where showModal does not exist *)
    ; dialog ~is_open:false ~id:"dlg-modal-closed" ()
    ; dialog ~purpose:Dialog.Required ~is_open:false ~id:"dlg-modal-required" ()
    ]
  |> Bonsai.map ~f:(fun children -> Vdom.Node.div children)
;;

let () =
  Bonsai_web_test.Handle.create
    (Bonsai_web_test.Result_spec.vdom Fn.id)
    dialog_static
  |> fun handle -> mount "dialog" (Bonsai_web_test.Handle.last_result handle)
;;

(* ------------------------------------------------------- AlertDialog (M14) *)

(* The inline path is the one jsdom can read, and it is the interesting one: the role must be "group"
   there, because an alertdialog role would promise an interruption and a focus trap a non-modal preview
   does not have. The rest is association — the ids the dialog names and describes itself from have to
   point at elements that exist. *)
let alert_dialog_static (_ : Bonsai.graph) =
  let open Astryx in
  let join_all trees =
    List.fold trees ~init:(Bonsai.return []) ~f:(fun acc tree ->
      Bonsai.map2 acc tree ~f:(fun acc node -> acc @ [ node ]))
  in
  let one ?(loading = false) id =
    Alert_dialog.view
      ~title:"Delete this page?"
      ~description:"The page and its history are removed for everyone."
      ~action_label:"Delete"
      ~cancel_label:"Keep it"
      ~action_variant:Button.Destructive
      ~is_action_loading:loading
      ~is_inline:true
      ~is_open:(Bonsai.return true)
      ~on_action:(Bonsai.return (Effect.Many []))
      ~on_open_change:(Bonsai.return (fun (_ : bool) -> Effect.Many []))
      ~id
      ()
  in
  join_all [ one "adlg-plain"; one ~loading:true "adlg-loading" ]
  |> Bonsai.map ~f:(fun children -> Vdom.Node.div children)
;;

let () =
  Bonsai_web_test.Handle.create
    (Bonsai_web_test.Result_spec.vdom Fn.id)
    alert_dialog_static
  |> fun handle -> mount "alert-dialog" (Bonsai_web_test.Handle.last_result handle)
;;

(* ------------------------------------------------------- DialogHeader (M14) *)

(* The two things worth pressing: that the heading really carries the id a dialog would name itself
   from (and is focusable without joining the tab order), and that the close button is *absent* when
   there is no callback to report to — upstream renders no button there, and an assertion on the
   presence of a button cannot notice a button that should not exist. *)
let dialog_header_static (_ : Bonsai.graph) =
  let open Astryx in
  let join_all trees =
    List.fold trees ~init:(Bonsai.return []) ~f:(fun acc tree ->
      Bonsai.map2 acc tree ~f:(fun acc node -> acc @ [ node ]))
  in
  let one ?on_open_change ?subtitle ?(has_divider = false) id =
    Dialog_header.view
      ~title_id:(id ^ "-title")
      ~title:(Vdom.Node.text "Delete this project?")
      ?on_open_change
      ?subtitle
      ~has_divider
      ~attrs:[ Vdom.Attr.create "id" id ]
      ()
  in
  join_all
    [ one "dhdr-no-close"
    ; one
        ~on_open_change:(Bonsai.return (fun (_ : bool) -> Effect.Many []))
        ~subtitle:(Vdom.Node.text "This cannot be undone.")
        ~has_divider:true
        "dhdr-with-close"
    ]
  |> Bonsai.map ~f:(fun children -> Vdom.Node.div children)
;;

let () =
  Bonsai_web_test.Handle.create
    (Bonsai_web_test.Result_spec.vdom Fn.id)
    dialog_header_static
  |> fun handle -> mount "dialog-header" (Bonsai_web_test.Handle.last_result handle)
;;

(* ------------------------------------------------------------------------ Kbd (M15)

   The rules are rendered as text next to the live component on purpose. The runner is Linux, so the
   live component can only ever exercise the non-Apple branch; rendering the pure functions for both
   answers is what makes the Mac branch pressable here instead of requiring a Mac to test. *)
let kbd_static (_ : Bonsai.graph) =
  let open Astryx in
  let rule id text = Vdom.Node.div ~attrs:[ Vdom.Attr.create "id" id ] [ Vdom.Node.text text ] in
  (* The component's own pipeline, spelled out: split (which resolves aliases), then display or label. *)
  let renders keys ~is_mac label_of =
    List.map (Kbd.split_keys keys) ~f:(label_of ~is_mac) |> String.concat ~sep:"+"
  in
  Bonsai.return
    (Vdom.Node.div
    [ Kbd.view ~keys:"mod+k" ~attrs:[ Vdom.Attr.create "id" "kbd-live" ] ()
    ; Kbd.view ~keys:"mod+shift+p" ~attrs:[ Vdom.Attr.create "id" "kbd-live-multi" ] ()
    ; rule "kbd-rule-mod-mac-display" (Kbd.key_display ~is_mac:true "mod")
    ; rule "kbd-rule-mod-mac-label" (Kbd.key_label ~is_mac:true "mod")
    ; rule "kbd-rule-mod-other-display" (Kbd.key_display ~is_mac:false "mod")
    ; rule "kbd-rule-mod-other-label" (Kbd.key_label ~is_mac:false "mod")
    ; rule "kbd-rule-esc-display" (renders "esc" ~is_mac:false Kbd.key_display)
    ; rule "kbd-rule-esc-label" (renders "esc" ~is_mac:false Kbd.key_label)
    ; rule "kbd-rule-return-display" (renders "return" ~is_mac:false Kbd.key_display)
    ; rule "kbd-rule-plus-display" (renders "shift+plus" ~is_mac:false Kbd.key_display)
    ; rule "kbd-rule-unknown-display" (renders "pageup" ~is_mac:false Kbd.key_display)
    ; rule "kbd-rule-unknown-label" (renders "pageup" ~is_mac:false Kbd.key_label)
    ; rule "kbd-rule-split" (String.concat ~sep:"," (Kbd.split_keys "mod+shift+P"))
    ])
;;

let () =
  Bonsai_web_test.Handle.create (Bonsai_web_test.Result_spec.vdom Fn.id) kbd_static
  |> fun handle -> mount "kbd" (Bonsai_web_test.Handle.last_result handle)
;;

(* --------------------------------------------------------------------- layer (M16)

   jsdom has no Popover API at all, so this fixture is about the *fallback*: the hook must be a no-op
   rather than a crash, and the caller's value must survive untouched. The native path is the browser
   gate's business — the same split <dialog> forced, for the same reason. *)
let layer_static (_ : Bonsai.graph) =
  let one id is_open =
    Vdom.Node.div
      ~attrs:[ Vdom.Attr.create "id" id ]
      [ Vdom.Node.span
          ~attrs:
            [ Vdom.Attr.create "id" (id ^ "-trigger-wrapper")
            ; Astryx.Common.Layer_trigger_hook.attr
                ~controls:(id ^ "-surface")
                ~is_open
                ~on_toggle:Effect.Ignore
                ()
            ]
          [ Vdom.Node.create "button" ~attrs:[ Vdom.Attr.create "id" (id ^ "-trigger") ] [] ]
      ; Vdom.Node.div
          ~attrs:
            ([ Vdom.Attr.create "id" (id ^ "-surface"); Vdom.Attr.create "popover" "auto" ]
             @ Astryx.Common.Attr.data "component" "Layer"
             @ [ Astryx.Common.Layer_hook.attr ~is_open ~on_platform_close:Effect.Ignore ])
          [ Vdom.Node.text "layer content" ]
      ; Vdom.Node.div
          ~attrs:[ Vdom.Attr.create "id" (id ^ "-value") ]
          [ Vdom.Node.text (if is_open then "the value says open" else "the value says closed") ]
      ]
  in
  (* One closed and one open: the open one is the case that would throw if the guard were missing. *)
  Bonsai.return (Vdom.Node.div [ one "layer-closed" false; one "layer-open" true ])
;;

let () =
  Bonsai_web_test.Handle.create (Bonsai_web_test.Result_spec.vdom Fn.id) layer_static
  |> fun handle -> mount "layer" (Bonsai_web_test.Handle.last_result handle)
;;

(* ------------------------------------------------------------------ Layer geometry (M43)
   The heart of Layer is pure: upstream's getPositionArea / getPositionTryFallbacks /
   getSelfAlignment are functions, not DOM, and this harness can press both branches of the
   anchor positioning without a browser — jsdom has none. The provider is a structure fact:
   display: contents, one custom property per declared edge, inherited by children. The
   surface attrs are structure too: the class list and the inline style, asserted verbatim.
   The live geometry (computed gutter, caps) is the browser gate's, as always. *)

let layer_geometry_static (_ : Bonsai.graph) =
  let rule id text = Vdom.Node.div ~attrs:[ Vdom.Attr.create "id" id ] [ Vdom.Node.text text ] in
  let self_alignment_text placement alignment in_view =
    match
      Astryx.Layer.self_alignment ~placement ~alignment ~is_anchor_in_view:in_view
    with
    | None -> "none"
    | Some { property; value } ->
        Printf.sprintf
          "%s:%s"
          (match property with
           | `Align_self -> "align-self"
           | `Justify_self -> "justify-self")
          value
  in
  let surface =
    Astryx.Layer.surface_attrs
      ~placement:Astryx.Layer.Below
      ~alignment:Astryx.Layer.Align_center
      ~anchor:"--demo-anchor"
      ()
  in
  let surface_offset =
    Astryx.Layer.surface_attrs
      ~placement:Astryx.Layer.Below
      ~alignment:Astryx.Layer.Align_start
      ~anchor:"--demo-anchor"
      ~offset:(Astryx.Common.Size_value.Px 8)
      ()
  in
  Bonsai.return
    (Vdom.Node.div
       [ rule "layer-geo-area-below-center"
           (Astryx.Layer.position_area
              ~placement:Astryx.Layer.Below
              ~alignment:Astryx.Layer.Align_center
              ())
       ; rule "layer-geo-area-above-start"
           (Astryx.Layer.position_area
              ~placement:Astryx.Layer.Above
              ~alignment:Astryx.Layer.Align_start
              ())
       ; rule "layer-geo-area-end-end"
           (Astryx.Layer.position_area
              ~placement:Astryx.Layer.End
              ~alignment:Astryx.Layer.Align_end
              ())
       ; rule "layer-geo-area-start-end"
           (Astryx.Layer.position_area
              ~placement:Astryx.Layer.Start
              ~alignment:Astryx.Layer.Align_end
              ())
       ; rule "layer-geo-fallbacks-below-center"
           (Astryx.Layer.position_try_fallbacks
              ~placement:Astryx.Layer.Below
              ~alignment:Astryx.Layer.Align_center
              ())
       ; rule "layer-geo-fallbacks-start-start"
           (Astryx.Layer.position_try_fallbacks
              ~placement:Astryx.Layer.Start
              ~alignment:Astryx.Layer.Align_start
              ())
       ; rule "layer-geo-self-aligned-inview"
           (self_alignment_text
              Astryx.Layer.Below
              Astryx.Layer.Align_start
              true)
       ; rule "layer-geo-self-aligned-out"
           (self_alignment_text
              Astryx.Layer.Below
              Astryx.Layer.Align_start
              false)
       ; rule "layer-geo-self-centered-out"
           (self_alignment_text
              Astryx.Layer.Below
              Astryx.Layer.Align_center
              false)
       ; rule "layer-geo-self-inline-out"
           (self_alignment_text
              Astryx.Layer.End
              Astryx.Layer.Align_end
              false)
       ; rule "layer-geo-slide-name"
           (Astryx.Layer.slide_rule_name
              ~placement:Astryx.Layer.Below
              ~alignment:Astryx.Layer.Align_center
              ~side:Astryx.Layer.Same)
       ; rule "layer-geo-inset-properties"
           (Astryx.Layer.inset_properties
              (Astryx.Layer.inset
                 ~block_end:(Astryx.Common.Size_value.Px 56)
                 ~inline_start:(Astryx.Common.Size_value.Css "12px")
                 ())
           |> List.map ~f:(fun (k, v) -> k ^ "=" ^ v) |> String.concat ~sep:",")
       (* The provider: the declaration on the element the gate can read, and the surface
          it carries. *)
       ; Vdom.Node.div
           ~attrs:
             [ Vdom.Attr.create "id" "layer-geo-provider" ]
           [ Astryx.Layer.Provider.view
               ~inset:
                 (Astryx.Layer.inset
                    ~block_end:(Astryx.Common.Size_value.Px 56)
                    ())
               [ Vdom.Node.div
                   ~attrs:
                     ([ Vdom.Attr.create "id" "layer-geo-surface"
                      ; Vdom.Attr.create "popover" "manual"
                      ]
                      @ surface)
                   [ Vdom.Node.text "layer geo content" ]
               ; Vdom.Node.div
                   ~attrs:
                     ([ Vdom.Attr.create "id" "layer-geo-surface-offset" ]
                      @ surface_offset)
                   [ Vdom.Node.text "layer geo offset content" ]
               ] ]
       ])
;;

let () =
  Bonsai_web_test.Handle.create
    (Bonsai_web_test.Result_spec.vdom Fn.id)
    layer_geometry_static
  |> fun handle -> mount "layer-geometry" (Bonsai_web_test.Handle.last_result handle)
;;

(* --------------------------------------------------------------------------------- ButtonGroup (M17) *)
(* What belongs in this gate is the structure, not the behaviour: the roving tab stop is written by a
   mount effect, and this harness does not pump those (see Gate 30). The browser gate asserts that the
   group really is one tab stop and that the arrows move within it. *)
let button_group_static (_ : Bonsai.graph) =
  let member label ?(is_disabled = false) () = Astryx.Button.view ~label ~is_disabled [] in
  Bonsai.return
   @@ Astryx.Button_group.view
    ~label:"Actions"
    ~children:
      [ member "Copy" ()
      ; member "Cut" ()
      ; member "Paste" ~is_disabled:true ()
      ]
      ()
;;

let () =
  Bonsai_web_test.Handle.create
    (Bonsai_web_test.Result_spec.vdom Fn.id)
    button_group_static
  |> fun handle -> mount "button-group" (Bonsai_web_test.Handle.last_result handle)
;;

(* ------------------------------------------------------------------------------------- Popover (M18) *)
(* State, because the component is controlled: a static value could never open, so a fixture without
   state would pass here and mean nothing. The behaviour - the platform's dismissal, focus, and the
   value being told - is the browser gate's; what belongs here is the structure, including the one
   structural fact the focus rule rests on. *)
let popover_static (graph : Bonsai.graph) =
  let is_open, set_is_open = Bonsai.state false graph in
  Bonsai.map2 is_open set_is_open ~f:(fun is_open set ->
    Astryx.Popover.view
      ~id:"popover"
      ~label:"Share"
      ~trigger:(Astryx.Button.view ~label:"Share" [])
      ~content:(Vdom.Node.text "popover content")
      ~is_open
      ~on_open_change:(fun open_ -> set open_)
      ())
;;

let () =
  Bonsai_web_test.Handle.create
    (Bonsai_web_test.Result_spec.vdom Fn.id)
    popover_static
  |> fun handle -> mount "popover" (Bonsai_web_test.Handle.last_result handle)
;;

(* --------------------------------------------------------------------------------------- Timer (M19) *)
(* The reading is initial here and then corrected by the hook, which this harness does not pump — so the
   initial value is what this gate can honestly assert, plus the two facts that are structure rather than
   behaviour: a real <time> with a machine-readable duration on it, and digits that do not jitter as they
   change. The boundaries and the counting are the browser gate's. *)
let timer_static (_ : Bonsai.graph) =
  Bonsai.return
    (Vdom.Node.div
       [ Astryx.Timer.view ~attrs:[ Vdom.Attr.create "id" "timer-elapsed" ] ()
       ; Astryx.Timer.view
           ~format:Astryx.Timer.Clock
           ~attrs:[ Vdom.Attr.create "id" "timer-clock" ]
           ()
       ])
;;

let () =
  Bonsai_web_test.Handle.create (Bonsai_web_test.Result_spec.vdom Fn.id) timer_static
  |> fun handle -> mount "timer" (Bonsai_web_test.Handle.last_result handle)
;;

(* The group's own surface, which is all this harness can see: which element the label names, that the
   label carries no `for` (a group label names the group, not a control), the size class, and that the
   adornment really is a child of the group rather than a sibling of it. The shared border and the
   first/last-child corners are CSS, so they are the browser gate's to prove. *)
let input_group_static (_ : Bonsai.graph) =
  let input id =
    Vdom.Node.input
      ~attrs:
        (Astryx.Common.Attr.class_ [ "astryx-text-input__input" ]
         @ [ Vdom.Attr.create "id" id; Vdom.Attr.create "type" "text" ])
      ()
  in
  Bonsai.return
    (Vdom.Node.div
       [ Astryx.Input_group.view
           ~id:"ig-amount"
           ~label:"Amount"
           ~description:"In the account's currency."
           ~size:Astryx.Input_group.Sm
           ~children:
             [ Astryx.Input_group_text.view ~children:[ Vdom.Node.text "USD" ] ()
             ; input "ig-amount-input"
             ]
           ()
       ; Astryx.Input_group.view
           ~id:"ig-locked"
           ~label:"Locked"
           ~is_disabled:true
           ~size:Astryx.Input_group.Lg
           ~children:[ input "ig-locked-input" ] ()
       ])
;;

let () =
  Bonsai_web_test.Handle.create (Bonsai_web_test.Result_spec.vdom Fn.id) input_group_static
  |> fun handle -> mount "input_group" (Bonsai_web_test.Handle.last_result handle)
;;

(* The toolbar's own surface: that it says what it is and which way it runs, that a centre slot switches the
   layout, and that an input inside it is a member. The roving behaviour and the caret guard are behaviour, so
   they are the browser gate's - and the caret guard in particular needs a real caret. *)
let toolbar_static (_ : Bonsai.graph) =
  let button label = Astryx.Button.view ~label [] in
  Bonsai.return
    (Vdom.Node.div
       [ Astryx.Toolbar.view
           ~label:"Document actions"
           ~attrs:[ Vdom.Attr.create "id" "tb-actions" ]
           ~start_content:[ button "Bold" ]
           ~end_content:[ button "Share" ]
           ()
       ; Astryx.Toolbar.view
           ~label:"Zoom"
           ~attrs:[ Vdom.Attr.create "id" "tb-center" ]
           ~start_content:[ button "Out" ]
           ~center_content:[ button "100%" ]
           ~end_content:[ button "In" ]
           ()
       ; Astryx.Toolbar.view
           ~label:"Search"
           ~orientation:Astryx.Toolbar.Vertical
           ~attrs:[ Vdom.Attr.create "id" "tb-vertical" ]
           ~start_content:
             [ Vdom.Node.input
                 ~attrs:
                   [ Vdom.Attr.create "id" "tb-input"; Vdom.Attr.create "type" "text" ]
                 ()
             ]
           ()
       ])
;;

let () =
  Bonsai_web_test.Handle.create (Bonsai_web_test.Result_spec.vdom Fn.id) toolbar_static
  |> fun handle -> mount "toolbar" (Bonsai_web_test.Handle.last_result handle)
;;

(* ------------------------------------------------------------------ overflow arithmetic

   The fit math behind an overflowing list, driven as rows. It is a pure function of plain measurements, so
   it is the one part of that mechanism a gate can check without a browser at all - which is the reason
   upstream keeps it in a file of its own, and the reason this port ported it before the component.

   The expectation lives in a data attribute rather than in the assertion, so the gate compares two numbers
   it can both see. Cases are chosen to pin the RULES, not the happy path: the floor winning over a lower
   ceiling, the reserved indicator changing the answer, a cap larger than the list being a no-op, the
   multi-row packing, and collapse-from-start reversing which end is kept. *)
let overflow_math_cases : (string * int list * int * int * int * int * int option * int option * Astryx.Overflow_math.collapse_from * int * int) list =
  let open Astryx.Overflow_math in
  [ (* label, widths, gap, available, indicator, min, max, maxRows, from, expected count, expected rows *)
    "everything fits", [ 50; 50; 50 ], 8, 500, 40, 0, None, None, End, 3, 1
  ; "one item too many, with a marker to reserve for", [ 100; 100; 100 ], 8, 250, 40, 0, None, None, End, 1, 1
  ; "same widths with no marker: one more item fits", [ 100; 100; 100 ], 8, 250, 0, 0, None, None, End, 2, 1
  ; "the floor wins when the ceiling is below it", [ 100; 100 ], 8, 0, 0, 2, Some 1, None, End, 2, 1
  ; "a ceiling below the item count caps it", [ 10; 10; 10; 10 ], 0, 1000, 0, 0, Some 2, None, End, 2, 1
  ; "a ceiling above the item count is a no-op", [ 10; 10; 10; 10 ], 0, 1000, 0, 0, Some 99, None, End, 4, 1
  ; "multi-row: everything fits in two rows, so nothing collapses", [ 100; 100; 100; 100 ], 10, 250, 40, 0, None, Some 2, End, 4, 2
  ; "multi-row: the last row reserves room for the marker", [ 100; 100; 100; 100 ], 10, 150, 40, 0, None, Some 2, End, 2, 2
  ; "collapsing from the end keeps the first item that fits", [ 500; 10; 10 ], 0, 100, 0, 0, None, None, End, 0, 0
  ; "collapsing from the start keeps the other end instead", [ 500; 10; 10 ], 0, 100, 0, 0, None, None, Start, 2, 1
  ; "no items at all", [], 8, 500, 40, 0, None, None, End, 0, 0
  ]
;;

let () =
  let rows =
    List.map overflow_math_cases ~f:(fun (label, widths, gap, available, indicator, min_v, max_v, max_rows, from, expect_count, expect_rows) ->
      let got =
        Astryx.Overflow_math.compute
          ~widths
          ~gap
          ~available_width:available
          ~indicator_width:indicator
          ~min_visible_items:min_v
          ?max_visible_items:max_v
          ?max_rows
          ~collapse_from:from
          ()
      in
      Vdom.Node.div
        ~attrs:
          (Astryx.Common.Attr.data "label" label
           @ Astryx.Common.Attr.data "expect-visible" (Int.to_string expect_count)
           @ Astryx.Common.Attr.data "expect-rows" (Int.to_string expect_rows)
           @ Astryx.Common.Attr.data "got-visible" (Int.to_string got.Astryx.Overflow_math.visible_count)
           @ Astryx.Common.Attr.data "got-rows" (Int.to_string got.Astryx.Overflow_math.rows))
        [])
  in
  mount "overflow-math" (Vdom.Node.div rows)
;;

(* Rendered here rather than by a deriver, because this project's ppx set has none: a segment prints as
   T(text) or L(href|label|is_external), which is readable in a failure and comparable as a string. *)
let render_segments segs =
  List.map segs ~f:(function
    | Astryx.Linkify.Text text -> "T(" ^ text ^ ")"
    | Astryx.Linkify.Link { href; label; is_external } ->
      "L(" ^ href ^ "|" ^ label ^ "|" ^ Bool.to_string is_external ^ ")")
  |> String.concat ~sep:" "
;;

(* The linkify walk, driven as rows carrying both the expectation and the answer - the safe-url matrix's
   shape. It is a pure function of the text and the matches, so it needs no browser at all, and the cases
   pin the RULES rather than the happy path: the sort's stability, which decides ties by collection order,
   and the overlap rule that lets the first match win. *)
let () =
  let open Astryx.Linkify in
  let m start stop href label is_external = { start; stop; href; label; is_external } in
  let l href label is_external = Link { href; label; is_external } in
  let cases : (string * string * match_ list * segment list) list =
    [ ( "a url in the middle of a sentence"
      , "see https://x.dev/a now"
      , [ m 4 19 "https://x.dev/a" "https://x.dev/a" true ]
      , [ Text "see "; l "https://x.dev/a" "https://x.dev/a" true; Text " now" ] )
    ; ( "a match at position 0 emits NO empty leading text"
      , "hi@x.dev wrote"
      , [ m 0 8 "mailto:hi@x.dev" "hi@x.dev" false ]
      , [ l "mailto:hi@x.dev" "hi@x.dev" false; Text " wrote" ] )
    ; ( "adjacent matches are both kept, with nothing between them"
      , "a.t b.c"
      , [ m 0 3 "A" "A" false; m 4 7 "B" "B" false ]
      , [ l "A" "A" false; Text " "; l "B" "B" false ] )
    ; ( "overlapping ranges: the FIRST match wins, not the longer one"
      , "0123456789abcde"
      , [ m 0 10 "A" "A" false; m 5 15 "B" "B" false ]
      , [ l "A" "A" false; Text "abcde" ] )
    ; ( "equal starts: the earlier one in the INPUT wins - the sort must be stable"
      , "0123456789"
      , [ m 2 5 "A" "A" false; m 2 9 "B" "B" false ]
      , [ Text "01"; l "A" "A" false; Text "56789" ] )
    ; ( "a match ending at the last character emits NO trailing empty text"
      , "x https://a.dev"
      , [ m 2 15 "https://a.dev" "https://a.dev" true ]
      , [ Text "x "; l "https://a.dev" "https://a.dev" true ] )
    ; ( "no matches at all gives the whole text back", "nothing here", [], [ Text "nothing here" ] )
    ; ( "unsorted input is ordered by position"
      , "aa bb"
      , [ m 3 5 "B" "B" false; m 0 2 "A" "A" false ]
      , [ l "A" "A" false; Text " "; l "B" "B" false ] )
    ; ( "a match that swallows everything leaves one segment", "https://a.dev", [ m 0 13 "u" "u" true ], [ l "u" "u" true ] )
    ]
  in
  let rows =
    List.map cases ~f:(fun (label, text, matches, expect) ->
      let got = segments_of_matches ~text matches in
      Vdom.Node.div
        ~attrs:
          (Astryx.Common.Attr.data "label" label
           @ Astryx.Common.Attr.data "expect" (render_segments expect)
           @ Astryx.Common.Attr.data "got" (render_segments got))
        [])
  in
  mount "linkify" (Vdom.Node.div rows)
;;


(* The scanner and the walk TOGETHER, driven by the built-in patterns on real text. The cases above feed
   hand-made matches to prove the cutting; these prove the finding, which needs the regex engine and so
   runs under node rather than a browser. *)
let () =
  let open Astryx.Linkify in
  let run text = segments_of_matches ~text (find_matches ~text ~patterns:builtins) |> render_segments in
  let cases : (string * string * string) list =
    [ ( "a url in a sentence"
      , "see https://x.dev/a now"
      , "T(see ) L(https://x.dev/a|https://x.dev/a|true) T( now)" )
    ; ( "an email becomes a mailto link", "mail hi@x.dev please"
      , "T(mail ) L(mailto:hi@x.dev|hi@x.dev|false) T( please)" )
    ; ( "both builtins, in the order they appear"
      , "a https://x.dev then b@y.dev"
      , "T(a ) L(https://x.dev|https://x.dev|true) T( then ) L(mailto:b@y.dev|b@y.dev|false)" )
    ; ( "a url at the very end leaves no trailing text", "x https://a.dev"
      , "T(x ) L(https://a.dev|https://a.dev|true)" )
    ; ( "a url in brackets stops before the closing one", "(https://x.dev/a)"
      , "T(() L(https://x.dev/a|https://x.dev/a|true) T())" )
    ; ( "no matches gives the text back whole", "nothing to see", "T(nothing to see)" )
    ; ( "two urls with text between them"
      , "https://a.dev and https://b.dev"
      , "L(https://a.dev|https://a.dev|true) T( and ) L(https://b.dev|https://b.dev|true)" )
    ]
  in
  let rows =
    List.map cases ~f:(fun (label, text, expect) ->
      Vdom.Node.div
        ~attrs:
          (Astryx.Common.Attr.data "label" label
           @ Astryx.Common.Attr.data "expect" expect
           @ Astryx.Common.Attr.data "got" (run text))
        [])
  in
  mount "linkify-builtins" (Vdom.Node.div rows)
;;


(* The destination handoff: which of upstream's three branches a pair of props resolves to, and the rules
   that decide it. Every case here describes a link that would compile and look right while doing the
   wrong thing, which is why they are pinned rather than reasoned about. *)
let () =
  let open Astryx.Link_destination in
  let show = function
    | Rejected -> "Rejected"
    | Native None -> "Native(no href)"
    | Native (Some h) -> "Native(" ^ h ^ ")"
    | Routed { href; to_ } ->
      "Routed(href="
      ^ Option.value href ~default:"-"
      ^ ",to="
      ^ Option.value to_ ~default:"-"
      ^ ")"
  in
  let cases : (string * component * string option * string option * string) list =
    [ ( "a plain native link is NOT rejected by its absent `to`"
      , Anchor
      , Some "/x"
      , None
      , "Native(/x)" )
    ; ( "an unsafe href is rejected", Anchor, Some "javascript:alert(1)", None, "Rejected" )
    ; ( "one unsafe `to` rejects the WHOLE handoff, good href included"
      , Custom
      , Some "/x"
      , Some "javascript:alert(1)"
      , "Rejected" )
    ; ( "both absent is still a native anchor, with no destination"
      , Anchor
      , None
      , None
      , "Native(no href)" )
    ; ( "a custom component is handed both props"
      , Custom
      , Some "https://x.dev"
      , Some "/docs"
      , "Routed(href=https://x.dev,to=/docs)" )
    ; ( "a custom component's `to` defaults to its href"
      , Custom
      , Some "/docs"
      , None
      , "Routed(href=/docs,to=/docs)" )
    ; ( "a data:text/html destination is rejected"
      , Anchor
      , Some "data:text/html,<script>alert(1)</script>"
      , None
      , "Rejected" )
    ; ( "a custom component with neither prop is routed with neither"
      , Custom
      , None
      , None
      , "Routed(href=-,to=-)" )
    ]
  in
  let rows =
    List.map cases ~f:(fun (label, component, href, to_, expect) ->
      Vdom.Node.div
        ~attrs:
          (Astryx.Common.Attr.data "label" label
           @ Astryx.Common.Attr.data "expect" expect
           @ Astryx.Common.Attr.data "got" (show (resolve ~component ~href ~to_)))
        [])
  in
  mount "link-destination" (Vdom.Node.div rows)
;;


(* Which element a polymorphic component renders as: the four-step priority order, and the rule that a
   disabled href is excluded at step 1 rather than downgraded afterwards. *)
let () =
  let open Astryx.Interactive_role in
  (* `name` lived here and the role is rendered by `show` instead, which also reports whether an inert
     thing still renders as a button - removing it is one fewer way to render a role two ways. *)
  let cases : (string * string option * bool * bool * string) list =
    [ ( "an href with no click is a link", Some "/x", false, false, "link" )
    ; ( "no href but a click is a button", None, true, false, "button" )
    ; ( "neither is inert", None, false, false, "inert" )
    ; ( "a DISABLED href is not a link - it resolves through the remaining steps"
      , Some "/x"
      , false
      , true
      , "inert" )
    ; ( "a disabled href WITH a click is still a button", Some "/x", true, true, "button" )
    ; ( "href outranks a click", Some "/x", true, false, "link" )
    ; ( "an inert thing with no href still renders as a button"
      , None
      , true
      , false
      , "button (renders_as_button)" )
    ; ( "but an inert thing WITH an href renders as a plain anchor"
      , Some "/x"
      , false
      , true
      , "inert (plain anchor)" )
    ]
  in
  let show href has_click is_disabled =
    let role = of_inputs ~href ~has_on_click:has_click ~is_disabled in
    match role with
    | Link -> "link"
    | Button -> "button"
    | Inert ->
      if renders_as_button role ~href
      then "inert (plain anchor)"
      else if Option.is_some href
      then "inert (anchor, no href)"
      else "inert"
  in
  let rows =
    List.map cases ~f:(fun (label, href, has_click, is_disabled, _) ->
      Vdom.Node.div
        ~attrs:
          (Astryx.Common.Attr.data "label" label
           @ Astryx.Common.Attr.data "got" (show href has_click is_disabled))
        [])
  in
  mount "interactive-role" (Vdom.Node.div rows)
;;


(* Normalizing target/rel: the _blank case appends noopener and noreferrer, preserving the caller's rel
   and its order, and nothing else is touched. *)
let () =
  let open Astryx.Target_and_rel in
  let show target rel =
    let target, rel = compute ~target ~rel in
    "target="
    ^ Option.value target ~default:"-"
    ^ " rel="
    ^ Option.value rel ~default:"-"
  in
  let cases : (string * string option * string option * string) list =
    [ ( "neither prop given is left alone", None, None, "target=- rel=-" )
    ; ( "a target that is not _blank is untouched", Some "_self", Some "nofollow", "target=_self rel=nofollow" )
    ; ( "_blank with no rel gains both tokens", Some "_blank", None, "target=_blank rel=noopener noreferrer" )
    ; ( "the caller's rel is preserved, and the tokens go on the END"
      , Some "_blank"
      , Some "nofollow"
      , "target=_blank rel=nofollow noopener noreferrer" )
    ; ( "a token already present is not duplicated", Some "_blank", Some "noopener", "target=_blank rel=noopener noreferrer" )
    ; ( "both already present is unchanged", Some "_blank", Some "noopener noreferrer", "target=_blank rel=noopener noreferrer" )
    ; ( "whitespace is normalized, not preserved", Some "_blank", Some "  spaced   out  ", "target=_blank rel=spaced out noopener noreferrer" )
    ; ( "the membership test is CASE-SENSITIVE, so NOOPENER is appended too"
      , Some "_blank"
      , Some "NOOPENER"
      , "target=_blank rel=NOOPENER noopener noreferrer" )
    ]
  in
  let rows =
    List.map cases ~f:(fun (label, target, rel, expect) ->
      Vdom.Node.div
        ~attrs:
          (Astryx.Common.Attr.data "label" label
           @ Astryx.Common.Attr.data "expect" expect
           @ Astryx.Common.Attr.data "got" (show target rel))
        [])
  in
  mount "target-and-rel" (Vdom.Node.div rows)
;;

(* Token: the four upstream branches in one case, side by side, because the BRANCH MEMBERSHIP is the
   contract: role first (a live href makes the anchor the root - or the sibling container when the
   remove button would nest invalidly inside it), then on_click -> container with an invisible
   button, otherwise the plain span. Markers are upstream's: pressable only on interactive
   non-disabled surfaces, colour and size reflected as data, the refused javascript: href losing its
   destination while keeping its shape, and the remove button's accessible name in English. *)
let () =
  let open Astryx.Token in
  let noop _ = Effect.Ignore in
  let view = view in
  mount
    "token-all"
    (Vdom.Node.div
       [ Vdom.Node.div [ view "plain" ]
       ; Vdom.Node.div [ view ~on_remove:noop "detachable" ]
       ; Vdom.Node.div [ view ~on_click:noop "clickable" ]
       ; Vdom.Node.div [ view ~on_click:noop ~on_remove:noop "click-detach" ]
       ; Vdom.Node.div [ view ~is_disabled:true ~on_click:noop "parked" ]
       ; Vdom.Node.div [ view ~href:"/docs" "linked" ]
       ; Vdom.Node.div [ view ~href:"/docs" ~on_remove:noop "linked-detach" ]
       ; Vdom.Node.div [ view ~href:"javascript:alert(1)" "refused" ]
       ; Vdom.Node.div [ view ~size:Sm ~color:Red ~icon:(icon ()) "sized" ]
       ; Vdom.Node.div [ view ~is_label_hidden:true ~description:"a real person" ~icon:(icon ()) "sam" ]
       ; Vdom.Node.div [ view ~end_content:(Vdom.Node.text "x9") "tailed" ]
       ; Vdom.Node.div [ view ~is_disabled:true "dimmed" ]
       ])
;;

(* Spinner: every size and shade as the unlabelled status element, plus both labelled
   arrangements - string label (aria-labelledby naming) and node label (accessible name
   falls back to aria-label/default). Geometry checked in run.mjs: the box is the ring
   plus the stroke on each side, the arc keeps ARC_FRACTION of the circumference. *)
let () =
  mount
    "spinner-all"
    (Vdom.Node.div
       [ (List.map [ Astryx.Spinner.Sm; Md; Lg; Xl ] ~f:(fun size ->
            Astryx.Spinner.view ~size ())
         |> Vdom.Node.div)
       ; (List.map [ Astryx.Spinner.Default; Subtle; On_media; Inherit ]
           ~f:(fun shade -> Astryx.Spinner.view ~shade ())
         |> Vdom.Node.div)
       ; Vdom.Node.div [ Astryx.Spinner.view ~label:"Loading..." () ]
       ; Vdom.Node.div
           [ Astryx.Spinner.view ~label_node:(Vdom.Node.text "Fetching") () ]
       ; Vdom.Node.div [ Astryx.Spinner.view ~aria_label:"Busy" () ]
       ])
;;

(* ----------------------------------------------------------------- Thumbnail (M34)

   A preview card whose states are the contract: placeholder (no source), the image
   (with the decorative/aliased split), the skeleton (loading, no source), the upload
   overlay (loading, has source), the remove button (shown always or on hover), the
   interactive open button, and the disabled case. The per-source error cell is
   asserted in run.mjs by rendering a fresh mount after an error; the rendered states
   here cover the rest. All instances live in one graph because Thumbnail owns the
   failed-source state, the same shape Avatar's fixture uses. *)
let join_all (trees : Vdom.Node.t Bonsai.t list) =
  List.fold trees ~init:(Bonsai.return []) ~f:(fun acc tree ->
    Bonsai.map2 acc tree ~f:(fun acc node -> acc @ [ node ]))
;;

let thumbnail_component (graph : Bonsai.graph) =
  let noop (_ : Dom_html.mouseEvent Js.t) = Effect.Ignore in
  let one ?label ?src ?alt ?on_remove ?on_click ?is_loading ?is_disabled ?show_remove_on
      ?(id = "astryx-thumbnail") name
    =
    Astryx.Thumbnail.view
      ?src
      ?alt
      ?label
      ?on_remove
      ?on_click
      ?is_loading
      ?is_disabled
      ?show_remove_on
      ~id
      graph
    |> Bonsai.map ~f:(fun node ->
           Vdom.Node.div
             ~attrs:
               [ Vdom.Attr.create "data-case" name
               ; Vdom.Attr.create "data-astryx-thumbnail-case" name
               ]
             [ node ])
  in
  let trees =
    [ one ~id:"t-plain" "placeholder"
    ; one ~id:"t-image" ~src:"https://example.invalid/a.jpg" ~alt:"A photo" "image"
    ; one ~id:"t-decorative" ~src:"https://example.invalid/b.jpg" "decorative"
    ; one ~id:"t-loading-src" ~src:"https://example.invalid/c.jpg" ~is_loading:true "upload"
    ; one ~id:"t-loading-none" ~is_loading:true "skeleton"
    ; one ~id:"t-remove" ~src:"https://example.invalid/d.jpg" ~alt:"R" ~label:"report.pdf"
        ~on_remove:noop "remove"
    ; one ~id:"t-remove-always" ~src:"https://example.invalid/e.jpg" ~alt:"A"
        ~on_remove:noop ~show_remove_on:`Always "remove-always"
    ; one ~id:"t-interactive" ~src:"https://example.invalid/f.jpg" ~alt:"I"
        ~on_click:noop "interactive"
    ; one ~id:"t-disabled" ~src:"https://example.invalid/g.jpg" ~alt:"D"
        ~on_remove:noop ~on_click:noop ~is_disabled:true "disabled"
    ]
  in
  Bonsai.map (join_all trees) ~f:(fun children -> Vdom.Node.div children)
;;

let () =
  let handle =
    Bonsai_web_test.Handle.create
      (Bonsai_web_test.Result_spec.vdom Fn.id)
      thumbnail_component
  in
  mount "thumbnail-all" (Bonsai_web_test.Handle.last_result handle)
;;

(* ScrollableArea: the viewport's props and contract are props about the geometry
   intent; the measured state itself cannot be exercised in jsdom (no layout: every
   client extent is 0, so the viewport stays unmeasurable and inactive). What the
   harness CAN render is the pre-measurement contract: the viewport carries role,
   aria-label, data-scroll-axis (raw, not data-astryx- prefixed - upstream's
   contract), the content box carries data-scroll-content, and with no effective
   axis there is no tabindex. The live cases (tabindex appears, edges flip when
   real layout measures) are the browser gate's job. All instances share one graph
   because the viewport is stateful. *)
let scrollable_area_component (graph : Bonsai.graph) =
  let trees =
    [ Astryx.Scrollable_area.view
        ~id:"sa-block"
        ~label:"Activity history"
        graph
        [ Vdom.Node.text "block axis" ]
    ; Astryx.Scrollable_area.view
        ~id:"sa-inline"
        ~axis:`Inline
        ~label:"Tags"
        graph
        [ Vdom.Node.text "inline axis" ]
    ; Astryx.Scrollable_area.view
        ~id:"sa-both"
        ~axis:`Both
        ~label:"Gallery"
        graph
        [ Vdom.Node.text "both axes" ]
    ; Astryx.Scrollable_area.view
        ~id:"sa-region"
        ~role:`Region
        ~label:"Activity history"
        ~overscroll:`Contain
        graph
        [ Vdom.Node.text "region role" ]
    ; Astryx.Scrollable_area.view
        ~id:"sa-padded"
        ~label:"Activity history"
        ~padding:Astryx.Common.Spacing.S3
        graph
        [ Vdom.Node.text "padded" ]
    ; Astryx.Scrollable_area.view
        ~id:"sa-full-bleed"
        ~label:"Activity history"
        ~is_full_bleed:true
        graph
        [ Vdom.Node.text "full bleed" ]
    ]
  in
  Bonsai.map (join_all trees) ~f:(fun nodes -> Vdom.Node.div nodes)
;;

let () =
  let handle =
    Bonsai_web_test.Handle.create
      (Bonsai_web_test.Result_spec.vdom Fn.id)
      scrollable_area_component
  in
  mount "scrollable-area-all" (Bonsai_web_test.Handle.last_result handle)
;;

(* NavHeadingMenu: markup contract. The menu is trigger-less, so what renders is
   the surface itself: role=menu, rows as role=menuitem, a disabled row with
   aria-disabled, a row with an href being the anchor itself, icon + description
   cells. The wrapper readouts make the two effects observable: choosing a row
   hands its id to on_select, and Escape (a native keydown dispatched from
   jsdom, which the test harness itself cannot synthesise) runs on_close.
   Keyboard moves (arrows/Home/End/typeahead) move DOM focus and are asserted in
   the real-browser gate where focus is real. *)
let nav_heading_menu_component (graph : Bonsai.graph) =
  let selected, set_selected = Bonsai.state (None : string option) graph in
  let closed_count, set_closed_count = Bonsai.state 0 graph in
  let on_select =
    Bonsai.map set_selected ~f:(fun set_selected (item : Astryx.Nav_heading_menu.item) ->
      set_selected (Some item.id))
  in
  let on_close =
    Bonsai.map2 closed_count set_closed_count ~f:(fun count set_count ->
      set_count (count + 1))
  in
  let items =
    [ { Astryx.Nav_heading_menu.id = "dashboard"; label = "Dashboard"; description = None; icon = None; href = Some "#dashboard"; is_disabled = false }
    ; { Astryx.Nav_heading_menu.id = "analytics"; label = "Analytics"; description = Some "Usage by day and by team"; icon = Some "chart"; href = Some "#analytics"; is_disabled = false }
    ; { Astryx.Nav_heading_menu.id = "reports"; label = "Reports"; description = None; icon = None; href = Some "#reports"; is_disabled = true }
    ; { Astryx.Nav_heading_menu.id = "settings"; label = "Settings"; description = None; icon = Some "gear"; href = None; is_disabled = false }
    ]
  in
  let menu =
    Bonsai.map3
      selected
      closed_count
      (Astryx.Nav_heading_menu.view ~id:"nhm-all" ~on_select ~on_close ~items graph)
      ~f:(fun selected closed_count menu ->
        Vdom.Node.div
          ~attrs:
            [ Vdom.Attr.id "nhm-wrap"
            ; Vdom.Attr.create "data-selected" (Option.value selected ~default:"-")
            ; Vdom.Attr.create "data-closed" (string_of_int closed_count)
            ]
          [ menu ])
  in
  let sizes graph =
    [ Astryx.Nav_heading_menu.view ~id:"nhm-sm" ~size:Astryx.Nav_heading_menu.Sm ~on_select ~items graph
    ; Astryx.Nav_heading_menu.view ~id:"nhm-lg" ~size:Astryx.Nav_heading_menu.Lg ~on_select ~items graph
    ]
  in
  let join_all trees =
    List.fold trees ~init:(Bonsai.return []) ~f:(fun acc tree ->
      Bonsai.map2 acc tree ~f:(fun acc node -> acc @ [ node ]))
  in
  Bonsai.map2 menu (join_all (sizes graph)) ~f:(fun menu sizes ->
    Vdom.Node.div [ menu; Vdom.Node.div sizes ])
;;

let () =
  let handle =
    Bonsai_web_test.Handle.create
      (Bonsai_web_test.Result_spec.vdom Fn.id)
      nav_heading_menu_component
  in
  mount "nav-heading-menu-all" (Bonsai_web_test.Handle.last_result handle)
;;

let segmented_control_component (graph : Bonsai.graph) =
  let selected, set_selected = Bonsai.state "grid" graph in
  let on_change = Bonsai.map set_selected ~f:(fun set_selected value -> set_selected value) in
  let item ?(is_label_hidden = false) ?(icon = None) ?(is_disabled = false) value label =
    { Astryx.Segmented_control.value; label; is_label_hidden; icon; is_disabled }
  in
  let grid_list =
    [ item "grid" "Grid"; item "list" "List"; item "table" "Table" ]
  in
  let icons =
    [ item ~icon:(Some (Vdom.Node.text "☰")) "grid" "Grid"
    ; item ~icon:(Some (Vdom.Node.text "≡")) "list" "List"
    ; item ~icon:(Some (Vdom.Node.text "▦")) "table" "Table"
    ]
  in
  let icon_only =
    [ item ~is_label_hidden:true ~icon:(Some (Vdom.Node.text "☰")) "grid" "Grid"
    ; item ~is_label_hidden:true ~icon:(Some (Vdom.Node.text "≡")) "list" "List"
    ; item ~is_label_hidden:true ~icon:(Some (Vdom.Node.text "▦")) "table" "Table"
    ]
  in
  let with_disabled =
    [ item "grid" "Grid"; item ~is_disabled:true "list" "List"; item "table" "Table" ]
  in
  let control =
    Astryx.Segmented_control.view
      ~id:"segc-all"
      ~label:"View mode"
      ~value:selected
      ~on_change
      ~items:grid_list
      graph
  in
  let main =
    Bonsai.map2 selected control ~f:(fun selected control ->
        Vdom.Node.div
          ~attrs:
            [ Vdom.Attr.id "segc-wrap"; Vdom.Attr.create "data-selected" selected ]
          [ control ])
  in
  let variants graph =
    [ Astryx.Segmented_control.view
        ~id:"segc-sm"
        ~label:"View mode"
        ~size:Astryx.Segmented_control.Sm
        ~value:(Bonsai.return "grid")
        ~on_change
        ~items:grid_list
        graph
    ; Astryx.Segmented_control.view
        ~id:"segc-fill"
        ~label:"View mode"
        ~layout:`Fill
        ~value:(Bonsai.return "list")
        ~on_change
        ~items:grid_list
        graph
    ; Astryx.Segmented_control.view
        ~id:"segc-icons"
        ~label:"View mode"
        ~value:(Bonsai.return "grid")
        ~on_change
        ~items:icons
        graph
    ; Astryx.Segmented_control.view
        ~id:"segc-icon-only"
        ~label:"View mode"
        ~value:(Bonsai.return "grid")
        ~on_change
        ~items:icon_only
        graph
    ; Astryx.Segmented_control.view
        ~id:"segc-disabled-item"
        ~label:"View mode"
        ~value:(Bonsai.return "grid")
        ~on_change
        ~items:with_disabled
        graph
    ; Astryx.Segmented_control.view
        ~id:"segc-disabled"
        ~label:"View mode"
        ~is_disabled:true
        ~value:(Bonsai.return "grid")
        ~on_change
        ~items:grid_list
        graph
    ; Astryx.Segmented_control.view
        ~id:"segc-disabled-message"
        ~label:"View mode"
        ~is_disabled:true
        ~disabled_message:"Locked by the plan."
        ~value:(Bonsai.return "grid")
        ~on_change
        ~items:grid_list
        graph
    ]
  in
  let join_all trees =
    List.fold trees ~init:(Bonsai.return []) ~f:(fun acc tree ->
      Bonsai.map2 acc tree ~f:(fun acc node -> acc @ [ node ]))
  in
  Bonsai.map2 main (join_all (variants graph)) ~f:(fun main variants ->
    Vdom.Node.div [ main; Vdom.Node.div variants ])
;;

let () =
  let handle =
    Bonsai_web_test.Handle.create
      (Bonsai_web_test.Result_spec.vdom Fn.id)
      segmented_control_component
  in
  mount "segmented-control-all" (Bonsai_web_test.Handle.last_result handle)
;;

(* Overlay: markup + state contract. The wrapper is the overlay container
   (class + marker + touch hook), the scrim renders inside it with the
   position/align/scrim classes, and its visibility classes follow show_on or
   is_open. The controlled variant is wired to state so the checks can flip
   is_open and confirm the inert/visibility classes; hover/focus reveal and the
   touch toggle are CSS/real-browser behaviour and are asserted in the
   browser gate. MediaTheme wrapper carries data-astryx-media. *)
let overlay_component (graph : Bonsai.graph) =
  let open_now, _set_open_now = Bonsai.state false graph in
  let content label =
    [ Vdom.Node.div
        ~attrs:[ Vdom.Attr.class_ "ov-fixture-content" ]
        [ Vdom.Node.text label ]
    ]
  in
  let surface =
    [ Vdom.Node.div ~attrs:[ Vdom.Attr.class_ "ov-fixture-surface" ] [ Vdom.Node.text "media" ] ]
  in
  let main =
    Astryx.Overlay.view
      ~id:"ov-controlled"
      ~is_open:open_now
      ~content:(content "Quick view")
      ~children:surface
      graph
  in
  let readout =
    Bonsai.map open_now ~f:(fun open_now ->
      Vdom.Node.div
        ~attrs:[ Vdom.Attr.create "id" "ov-fixture-state" ]
        [ Vdom.Node.text (if open_now then "open" else "closed") ])
  in
  let plain_graph ?show_on ?(scrim = Astryx.Overlay.Dark) ?(position = Astryx.Overlay.Fill)
      ?(align = Astryx.Overlay.End) id graph =
    Astryx.Overlay.view
      ~id
      ?show_on
      ~scrim
      ~position
      ~align
      ~content:(content "Quick view")
      ~children:surface
      graph
  in
  let variants graph =
    [ plain_graph ~show_on:Astryx.Overlay.Hover "ov-hover" graph
    ; plain_graph ~show_on:Astryx.Overlay.Focus "ov-focus" graph
    ; plain_graph ~position:Astryx.Overlay.Bottom "ov-bottom" graph
    ; plain_graph ~position:Astryx.Overlay.Top ~scrim:Astryx.Overlay.Light "ov-top" graph
    ; plain_graph ~scrim:Astryx.Overlay.Light "ov-light" graph
    ; plain_graph ~scrim:Astryx.Overlay.None "ov-none" graph
    ; plain_graph ~align:Astryx.Overlay.Center "ov-center" graph
    ; plain_graph ~show_on:Astryx.Overlay.Hover_or_focus ~position:Astryx.Overlay.Bottom
        "ov-hover-bottom" graph
    ]
  in
  let join_all trees =
    List.fold trees ~init:(Bonsai.return []) ~f:(fun acc tree ->
      Bonsai.map2 acc tree ~f:(fun acc node -> acc @ [ node ]))
  in
  Bonsai.map2 (Bonsai.map2 main readout ~f:(fun main readout -> Vdom.Node.div [ main; readout ]))
    (join_all (variants graph))
    ~f:(fun main variants -> Vdom.Node.div [ main; Vdom.Node.div variants ])
;;

let () =
  let handle =
    Bonsai_web_test.Handle.create
      (Bonsai_web_test.Result_spec.vdom Fn.id)
      overlay_component
  in
  mount "overlay-all" (Bonsai_web_test.Handle.last_result handle)
;;

let file_input_component (graph : Bonsai.graph) =
  let value, set_value = Bonsai.state None graph in
  let on_change = Bonsai.map set_value ~f:(fun set_value -> fun files -> set_value files) in
  let status s = Some { Astryx.Input_types.type_ = s; message = Some "File is too large (5 MB max)" } in
  let mk ?mode ?(is_disabled = false) ?(is_loading = false) ?(is_required = false)
      ?(is_multiple = false) ?(status = None) ?(status_variant = Astryx.Field_status.Tooltip)
      ?(placeholder = "") ?label id graph =
    Astryx.File_input.view
      ~id
      ?mode
      ~label:(Option.value label ~default:(id ^ " label"))
      ~is_disabled
      ~is_loading
      ~is_required
      ~is_multiple
      ?status
      ~status_variant
      ~placeholder
      ~value
      ~on_change
      graph
  in
  let trees =
    [ mk "fi-compact" graph
    ; mk ~mode:Astryx.File_input.Dropzone "fi-dropzone" graph
    ; mk ~is_disabled:true "fi-disabled" graph
    ; mk ~is_loading:true "fi-loading" graph
    ; mk ~is_required:true "fi-required" graph
    ; mk ~is_multiple:true ~label:"Upload images" "fi-multiple" graph
    ; mk ~status:(status Astryx.Input_types.Error) ~status_variant:Astryx.Field_status.Attached "fi-error" graph
    ; mk ~placeholder:"Choose a file…" "fi-placeholder" graph
    ]
  in
  let tree =
    List.fold trees ~init:(Bonsai.return []) ~f:(fun acc t ->
      Bonsai.map2 acc t ~f:(fun acc node -> acc @ [ node ]))
  in
  Bonsai.map tree ~f:(fun nodes -> Vdom.Node.div ~attrs:[ Vdom.Attr.id "fi-all" ] nodes)
;;

let () =
  let handle =
    Bonsai_web_test.Handle.create
      (Bonsai_web_test.Result_spec.vdom Fn.id)
      file_input_component
  in
  mount "file-input-all" (Bonsai_web_test.Handle.last_result handle)
;;

(* ---------------------------------------------------------------- layout *)

let layout_all () =
  let text s = Vdom.Node.text s in
  let px n = Astryx.Common.Size_value.Px n in
  Vdom.Node.div
    ~attrs:[ Vdom.Attr.id "layout-all"; Vdom.Attr.class_ "layout-shell" ]
    [ Astryx.Layout.view
        ~id:"layout-shell-example"
        ~header:(Astryx.Layout.header ~has_divider:true ~role:"banner" [ text "Header" ] ())
        ~start:(Astryx.Layout.panel ~has_divider:true ~width:(px 200) [ text "Start" ] ())
        ~content:(Astryx.Layout.content ~role:"main" [ text "Main" ] ())
        ~end_:(Astryx.Layout.panel ~has_divider:true ~width:(px 240) [ text "End" ] ())
        ~footer:(Astryx.Layout.footer ~has_divider:true [ text "Footer" ] ())
        ()
    ; Astryx.Layout.view
        ~id:"layout-default-dividers"
        ~default_has_dividers:true
        ~header:(Astryx.Layout.header [ text "Inherited divider" ] ())
        ~content:(Astryx.Layout.content [ text "Body" ] ())
        ()
    ; Astryx.Layout.view
        ~id:"layout-auto"
        ~height:Astryx.Layout.Auto
        ~content_width:(px 640)
        ~content:(Astryx.Layout.content ~is_scrollable:false [ text "Auto" ] ())
        ()
    ; Astryx.Layout.panel ~has_divider:false ~width:(px 300) [ text "Bare panel" ] ()
    ]
;;

let () = mount "layout-all" (layout_all ())
let () =
  let handle =
    Bonsai_web_test.Handle.create
      (Bonsai_web_test.Result_spec.vdom Fn.id)
      slider_component
  in
  mount "slider-all" (Bonsai_web_test.Handle.last_result handle)
;;

(* ------------------------------------------------------------------ Item (M44) *)
let item_component (graph : Bonsai.graph) =
  let join trees =
    List.fold trees ~init:(Bonsai.return []) ~f:(fun acc t ->
      Bonsai.map2 acc t ~f:(fun acc node -> acc @ [ node ]))
  in
  let text s = Vdom.Node.text s in
  let no_activate () = Effect.Many [] in
  let action ?(is_disabled = false) ?(has_removal = false)
      ?(variant = Astryx.Item.Accent) label =
    { Astryx.Item.label; icon = None; on_activate = no_activate;
      is_disabled; variant; has_removal }
  in
  let swipe_actions =
    { Astryx.Item.leading = [ action ~variant:Astryx.Item.Neutral "Unread" ]
    ; trailing = [ action "Archive"
                 ; action ~variant:Astryx.Item.Destructive ~has_removal:true "Delete" ]
    }
  in
  let row ?(id = "it") ?(as_ = Astryx.Item.Div) ?description
      ?(align = Astryx.Item.Center) ?(density = Astryx.Item.Balanced)
      ?label_lines ?description_lines ?(layout = Astryx.Item.Stacked)
      ?on_click ?href ?is_selected ?is_highlighted ?is_disabled
      ?swipe_actions ?swipe_behavior label graph =
    Astryx.Item.view ~as_ ?description ~align ~density ?label_lines ?description_lines
      ~layout ?on_click ?href ?is_selected ?is_highlighted ?is_disabled
      ?swipe_actions ?swipe_behavior
      ~attrs:[ Vdom.Attr.id id ] ~label graph
  in
  let trees =
    [ row ~id:"it-basic" ~description:(text "a description") (text "Basic") graph
    ; row ~id:"it-align" ~align:Astryx.Item.Start ~density:Astryx.Item.Compact
        ~description:(text "top aligned") (text "Align start") graph
    ; row ~id:"it-compact" ~density:Astryx.Item.Compact (text "compact") graph
    ; row ~id:"it-balanced" ~density:Astryx.Item.Balanced (text "balanced") graph
    ; row ~id:"it-spacious" ~density:Astryx.Item.Spacious (text "spacious") graph
    ; row ~id:"it-truncate1" ~label_lines:1
        ~description:(text "a long description that a single line must ellipsize")
        (text "single line") graph
    ; row ~id:"it-truncate2" ~label_lines:1 ~description_lines:2
        ~description:(text "two clamped lines: this one runs on long enough to exceed the second line")
        (text "two lines") graph
    ; row ~id:"it-selected" ~is_selected:true (text "Selected") graph
    ; row ~id:"it-highlighted" ~is_highlighted:true (text "Highlighted") graph
    ; row ~id:"it-disabled" ~is_disabled:true ~description:(text "inert") (text "Disabled") graph
    ; row ~id:"it-click" ~on_click:(fun _ -> Effect.Many []) (text "Click") graph
    ; row ~id:"it-link" ~href:"#it" (text "Link") graph
    ; row ~id:"it-link-root"
        ~as_:(Astryx.Item.Custom (fun attrs kids -> Vdom.Node.a ~attrs kids))
        ~href:"#it-root" (text "Root link") graph
    ; row ~id:"it-inline" ~layout:Astryx.Item.Inline
        ~description:(text "one line") (text "Inline") graph
    ; row ~id:"it-swipe" ~swipe_actions (text "Swipe") graph
    ; row ~id:"it-swipe-commit" ~swipe_actions ~swipe_behavior:Astryx.Item.Commit
        (text "Swipe commit") graph
    ]
  in
  Bonsai.map (join trees) ~f:(fun nodes ->
    Vdom.Node.div ~attrs:[ Vdom.Attr.id "it-all" ] nodes)
;;

let () =
  let handle =
    Bonsai_web_test.Handle.create
      (Bonsai_web_test.Result_spec.vdom Fn.id)
      item_component
  in
  mount "item-all" (Bonsai_web_test.Handle.last_result handle)
;;
