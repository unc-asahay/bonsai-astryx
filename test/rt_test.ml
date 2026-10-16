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
