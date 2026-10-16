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
let mount (case : string) (node : Vdom.Node.t) =
  let host = document##createElement (Js.string "div") in
  host##setAttribute (Js.string "data-case") (Js.string case);
  ignore (document##.body##appendChild (Js.Unsafe.coerce host));
  ignore (host##appendChild (Js.Unsafe.coerce (Vdom.Node.to_dom node)))
;;

let icon () = Vdom.Node.span ~attrs:[] [ Vdom.Node.text "+" ]

(* ---------------------------------------------------------------- rendering *)

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

(* -------------------------------------------------------------- interaction *)

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
