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
       ; (* 9: the caller's own accessibility attributes win *)
         Astryx.Icon.view
           ~name:"close"
           ~attrs:
             [ Vdom.Attr.create "aria-hidden" "false"
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
