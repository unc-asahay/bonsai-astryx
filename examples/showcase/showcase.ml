(* The showcase: every ported component, in every variant and state this port
   supports, rendered by the same modules a consumer would import.

   Two jobs:
     1. it is the site people look at — site/index.html mounts this bundle;
     2. it is the subject of the real-browser gate (tools/visual/verify-browser.mjs),
        which asserts that each section below actually rendered its component, that
        the variant classes are present, and that the interactive section responds
        to a real click.

   Only the public [Astryx] API is used, so this file is also the proof that the
   API is usable from outside the library. Sections carry [data-showcase-component]
   and examples carry [data-example] so the harness can address them without
   depending on CSS classes. *)

open! Core
open! Bonsai_web

module S = Astryx.Common.Spacing
module A = Astryx.Common.Alignment
module Size = Astryx.Common.Size_value
module Text = Astryx.Text

(* ---------------------------------------------------------------- chrome *)

(* A placeholder box, so layout demos have something to lay out. Not a component;
   it deliberately has no data-astryx-component attribute, so component counts in
   the harness stay meaningful. *)
let chip s = Vdom.Node.span ~attrs:[ Vdom.Attr.class_ "chip" ] [ Vdom.Node.text s ]

let ex name node =
  Vdom.Node.div
    ~attrs:[ Vdom.Attr.class_ "ex"; Vdom.Attr.create "data-example" name ]
    [ Vdom.Node.div ~attrs:[ Vdom.Attr.class_ "ex-render" ] [ node ]
    ; Vdom.Node.div ~attrs:[ Vdom.Attr.class_ "ex-name" ] [ Vdom.Node.text name ]
    ]
;;

let section ~id ~title ~note examples =
  Vdom.Node.section
    ~attrs:
      [ Vdom.Attr.class_ "sec"
      ; Vdom.Attr.create "id" id
      ; Vdom.Attr.create "data-showcase-component" title
      ]
    [ Vdom.Node.h2 ~attrs:[ Vdom.Attr.class_ "sec-title" ] [ Vdom.Node.text title ]
    ; Vdom.Node.p ~attrs:[ Vdom.Attr.class_ "sec-note" ] [ Vdom.Node.text note ]
    ; Vdom.Node.div ~attrs:[ Vdom.Attr.class_ "sec-body" ] examples
    ]
;;

let label s = Astryx.Text.view ~type_:Text.Label [ Vdom.Node.text s ]

(* Every section renders values in the graph, and a section can only render unwrapped nodes. This
   Bonsai offers map2/both rather than a list combinator, so the trees are combined pairwise and
   read back by position: the names next to [nth] below make the order checkable at a glance, and a
   missing example fails loudly instead of quietly rendering the wrong node. *)
let unwrap_all nodes =
  List.fold nodes ~init:(Bonsai.return []) ~f:(fun acc node ->
    Bonsai.both acc node |> Bonsai.map ~f:(fun (acc, node) -> node :: acc))
  |> Bonsai.map ~f:List.rev
;;

(* ---------------------------------------------------------------- sections *)

let s_stack () =
  section
    ~id:"stack"
    ~title:"Stack"
    ~note:
      "Flex primitive. On Horizontal, h_align drives the main axis (justify-content) and \
       v_align the cross axis; on Vertical it is the reverse."
    [ ex
        "horizontal / h_align start"
        (Astryx.Stack.view
           ~direction:Astryx.Stack.Horizontal
           ~gap:S.S3
           ~align:A.Start
           [ chip "one"; chip "two"; chip "three" ])
    ; ex
        "horizontal / h_align center"
        (Astryx.Stack.view
           ~direction:Astryx.Stack.Horizontal
           ~gap:S.S3
           ~align:A.Center
           [ chip "one"; chip "two"; chip "three" ])
    ; ex
        "horizontal / h_align end"
        (Astryx.Stack.view
           ~direction:Astryx.Stack.Horizontal
           ~gap:S.S3
           ~justify:A.End
           [ chip "one"; chip "two"; chip "three" ])
    ; ex
        "horizontal / justify between"
        (Astryx.Stack.view
           ~direction:Astryx.Stack.Horizontal
           ~gap:S.S3
           ~justify:A.Between
           [ chip "one"; chip "two"; chip "three" ])
    ; ex
        "vertical / gap 2"
        (Astryx.Stack.view ~gap:S.S2 [ chip "one"; chip "two" ])
    ; ex
        "wrap"
        (Astryx.Stack.view
           ~direction:Astryx.Stack.Horizontal
           ~gap:S.S2
           ~wrap:true
           (List.map [ "alpha"; "beta"; "gamma"; "delta"; "epsilon"; "zeta"; "eta" ] ~f:chip))
    ; ex "padding 4" (Astryx.Stack.view ~gap:S.S2 ~padding:S.S4 [ chip "padded" ])
    ; ex
        "scrollable"
        (Astryx.Stack.view
           ~gap:S.S2
           ~is_scrollable:true
           ~height:(Size.Px 90)
           (List.map [ "1"; "2"; "3"; "4"; "5"; "6"; "7"; "8" ] ~f:chip))
    ]
;;

let s_text () =
  section
    ~id:"text"
    ~title:"Text"
    ~note:"The type scale, the colour set and the weight set. Code uses the mono face."
    [ ex "type: Body" (Astryx.Text.view [ Vdom.Node.text "Body — the default paragraph." ])
    ; ex "type: Large" (Astryx.Text.view ~type_:Text.Large [ Vdom.Node.text "Large" ])
    ; ex "type: Label" (label "Label")
    ; ex "type: Supporting" (Astryx.Text.view ~type_:Text.Supporting [ Vdom.Node.text "Supporting" ])
    ; ex "type: Code" (Astryx.Text.view ~type_:Text.Code [ Vdom.Node.text "let x = 1" ])
    ; ex "type: Display_1" (Astryx.Text.view ~type_:Text.Display_1 [ Vdom.Node.text "Display" ])
    ; ex "color: Secondary" (Astryx.Text.view ~color:Text.Secondary [ Vdom.Node.text "secondary" ])
    ; ex "color: Accent" (Astryx.Text.view ~color:Text.Accent [ Vdom.Node.text "accent" ])
    ; ex "color: Disabled" (Astryx.Text.view ~color:Text.Disabled [ Vdom.Node.text "disabled" ])
    ; ex "weight: Semibold" (Astryx.Text.view ~weight:Text.Semibold [ Vdom.Node.text "Semibold" ])
    ; ex "tabular numbers" (Astryx.Text.view ~has_tabular_numbers:true [ Vdom.Node.text "1,234,567" ])
    ; ex "strikethrough" (Astryx.Text.view ~has_strikethrough:true [ Vdom.Node.text "cancelled" ])
    ]
;;

let s_heading () =
  section
    ~id:"heading"
    ~title:"Heading"
    ~note:"level selects the semantic element (h1-h6) and the visual scale; accessibility_level can override only the announced level."
    [ ex "H1" (Astryx.Heading.view ~level:Astryx.Heading.H1 [ Vdom.Node.text "Heading one" ])
    ; ex "H2" (Astryx.Heading.view ~level:Astryx.Heading.H2 [ Vdom.Node.text "Heading two" ])
    ; ex "H3" (Astryx.Heading.view ~level:Astryx.Heading.H3 [ Vdom.Node.text "Heading three" ])
    ; ex "H4" (Astryx.Heading.view ~level:Astryx.Heading.H4 [ Vdom.Node.text "Heading four" ])
    ; ex "H5" (Astryx.Heading.view ~level:Astryx.Heading.H5 [ Vdom.Node.text "Heading five" ])
    ; ex "H6" (Astryx.Heading.view ~level:Astryx.Heading.H6 [ Vdom.Node.text "Heading six" ])
    ]
;;

let button_icon = Vdom.Node.span ~attrs:[ Vdom.Attr.class_ "glyph" ] [ Vdom.Node.text "+" ]

let s_button () =
  section
    ~id:"button"
    ~title:"Button"
    ~note:
      "is_loading sets aria-busy and aria-disabled rather than native disabled, so focus \
       is never dropped mid-action and a hidden live region announces Loading. is_disabled \
       uses the native attribute."
    [ ex "variant: Primary" (Astryx.Button.view ~variant:Astryx.Button.Primary ~label:"Primary" [])
    ; ex "variant: Secondary" (Astryx.Button.view ~variant:Astryx.Button.Secondary ~label:"Secondary" [])
    ; ex "variant: Ghost" (Astryx.Button.view ~variant:Astryx.Button.Ghost ~label:"Ghost" [])
    ; ex
        "variant: Destructive"
        (Astryx.Button.view ~variant:Astryx.Button.Destructive ~label:"Delete" [])
    ; ex "size: Sm" (Astryx.Button.view ~size:Astryx.Button.Sm ~label:"Small" [])
    ; ex "size: Md" (Astryx.Button.view ~size:Astryx.Button.Md ~label:"Medium" [])
    ; ex "size: Lg" (Astryx.Button.view ~size:Astryx.Button.Lg ~label:"Large" [])
    ; ex "elevation: Low" (Astryx.Button.view ~elevation:Astryx.Button.Low ~label:"Elevated" [])
    ; ex "state: is_loading" (Astryx.Button.view ~label:"Save" ~is_loading:true [])
    ; ex "state: is_disabled" (Astryx.Button.view ~label:"Disabled" ~is_disabled:true [])
    ; ex "icon + label" (Astryx.Button.view ~label:"Add" ~icon:button_icon [])
    ; ex
        "is_icon_only"
        (Astryx.Button.view ~label:"Add item" ~is_icon_only:true ~icon:button_icon [])
    ; ex
        "href renders an <a>"
        (Astryx.Button.view
           ~label:"Upstream repo"
           ~href:"https://github.com/facebook/astryx"
           ~target:"_blank"
           ~rel:"noreferrer"
           [])
    ; ex "type_: Submit" (Astryx.Button.view ~type_:Astryx.Button.Submit ~label:"Submit" [])
    ]
;;

let s_badge () =
  let v = Astryx.Badge.view in
  section
    ~id:"badge"
    ~title:"Badge"
    ~note:"One-line status or category chip. The five semantic variants come first, then the extended colour set."
    [ ex "Neutral" (v ~variant:Astryx.Badge.Neutral "Draft")
    ; ex "Info" (v ~variant:Astryx.Badge.Info "In review")
    ; ex "Success" (v ~variant:Astryx.Badge.Success "Shipped")
    ; ex "Warning" (v ~variant:Astryx.Badge.Warning "Stale")
    ; ex "Error" (v ~variant:Astryx.Badge.Error "Failed")
    ; ex "Blue" (v ~variant:Astryx.Badge.Blue "Blue")
    ; ex "Cyan" (v ~variant:Astryx.Badge.Cyan "Cyan")
    ; ex "Green" (v ~variant:Astryx.Badge.Green "Green")
    ; ex "Orange" (v ~variant:Astryx.Badge.Orange "Orange")
    ; ex "Pink" (v ~variant:Astryx.Badge.Pink "Pink")
    ; ex "Purple" (v ~variant:Astryx.Badge.Purple "Purple")
    ; ex "Red" (v ~variant:Astryx.Badge.Red "Red")
    ; ex "Teal" (v ~variant:Astryx.Badge.Teal "Teal")
    ; ex "Yellow" (v ~variant:Astryx.Badge.Yellow "Yellow")
    ; ex
        "with icon"
        (v ~variant:Astryx.Badge.Success ~icon:button_icon "Deployed")
    ]
;;

let s_card () =
  let body s =
    Astryx.Stack.view
      ~gap:S.S2
      [ label s
      ; Astryx.Text.view ~type_:Text.Supporting [ Vdom.Node.text "Supporting copy inside the card." ]
      ]
  in
  section
    ~id:"card"
    ~title:"Card"
    ~note:"Container with a background variant, an elevation and spacing-scale padding. Content is whatever you pass."
    [ ex "variant: Default" (Astryx.Card.view ~padding:S.S4 [ body "Default" ])
    ; ex "variant: Transparent" (Astryx.Card.view ~variant:Astryx.Card.Transparent ~padding:S.S4 [ body "Transparent" ])
    ; ex "variant: Muted" (Astryx.Card.view ~variant:Astryx.Card.Muted ~padding:S.S4 [ body "Muted" ])
    ; ex "variant: Blue" (Astryx.Card.view ~variant:Astryx.Card.Blue ~padding:S.S4 [ body "Blue" ])
    ; ex "variant: Green" (Astryx.Card.view ~variant:Astryx.Card.Green ~padding:S.S4 [ body "Green" ])
    ; ex "variant: Red" (Astryx.Card.view ~variant:Astryx.Card.Red ~padding:S.S4 [ body "Red" ])
    ; ex "elevation: E_none" (Astryx.Card.view ~elevation:Astryx.Button.E_none ~padding:S.S4 [ body "No elevation" ])
    ; ex "elevation: Med" (Astryx.Card.view ~elevation:Astryx.Button.Med ~padding:S.S4 [ body "Medium" ])
    ; ex "elevation: High" (Astryx.Card.view ~elevation:Astryx.Button.High ~padding:S.S4 [ body "High" ])
    ; ex "padding 2" (Astryx.Card.view ~padding:S.S2 [ label "Tight padding" ])
    ; ex "padding 6" (Astryx.Card.view ~padding:S.S6 [ label "Loose padding" ])
    ; ex "max_width 240" (Astryx.Card.view ~padding:S.S4 ~max_width:(Size.Px 240) [ body "Constrained" ])
    ]
;;

let s_divider () =
  section
    ~id:"divider"
    ~title:"Divider"
    ~note:"Separator with a subtle/strong weight, an optional centred label, and a vertical orientation."
    [ ex "horizontal" (Astryx.Divider.view ())
    ; ex "variant: Subtle" (Astryx.Divider.view ~variant:Astryx.Divider.Subtle ())
    ; ex "variant: Strong" (Astryx.Divider.view ~variant:Astryx.Divider.Strong ())
    ; ex "with label" (Astryx.Divider.view ~label:(Vdom.Node.text "or") ())
    ; ex "is_full_bleed" (Astryx.Divider.view ~is_full_bleed:true ())
    ; ex
        "vertical"
        (Astryx.Stack.view
           ~direction:Astryx.Stack.Horizontal
           ~gap:S.S3
           ~align:A.Center
           ~height:(Size.Px 40)
           [ chip "left"
           ; Astryx.Divider.view ~orientation:Astryx.Divider.Vertical ()
           ; chip "right"
           ])
    ]
;;

let s_status_dot () =
  let v = Astryx.StatusDot.view in
  section
    ~id:"statusdot"
    ~title:"StatusDot"
    ~note:"Decorative to the eye, meaningful to assistive tech: role=img with the required label as its accessible name."
    [ ex "Success" (v ~variant:Astryx.StatusDot.Success ~label:"Healthy" ())
    ; ex "Warning" (v ~variant:Astryx.StatusDot.Warning ~label:"Degraded" ())
    ; ex "Error" (v ~variant:Astryx.StatusDot.Error ~label:"Down" ())
    ; ex "Accent" (v ~variant:Astryx.StatusDot.Accent ~label:"Deploying" ())
    ; ex "Neutral" (v ~variant:Astryx.StatusDot.Neutral ~label:"Unknown" ())
    ; ex "is_pulsing" (v ~variant:Astryx.StatusDot.Accent ~label:"In progress" ~is_pulsing:true ())
    ; ex
        "in a sentence"
        (Astryx.Stack.view
           ~direction:Astryx.Stack.Horizontal
           ~gap:S.S2
           ~align:A.Center
           [ v ~variant:Astryx.StatusDot.Success ~label:"Healthy" ()
           ; Astryx.Text.view [ Vdom.Node.text "All three regions healthy" ]
           ])
    ]
;;

let s_skeleton () =
  let v = Astryx.Skeleton.view in
  section
    ~id:"skeleton"
    ~title:"Skeleton"
    ~note:"Placeholder shape for content still loading. Decorative, so aria-hidden."
    [ ex "R_none" (v ~width:(Size.Px 160) ~height:(Size.Px 16) ~radius:Astryx.Skeleton.R_none ())
    ; ex "R0" (v ~width:(Size.Px 160) ~height:(Size.Px 16) ~radius:Astryx.Skeleton.R0 ())
    ; ex "R1" (v ~width:(Size.Px 160) ~height:(Size.Px 16) ~radius:Astryx.Skeleton.R1 ())
    ; ex "R2" (v ~width:(Size.Px 160) ~height:(Size.Px 16) ~radius:Astryx.Skeleton.R2 ())
    ; ex "R3" (v ~width:(Size.Px 160) ~height:(Size.Px 16) ~radius:Astryx.Skeleton.R3 ())
    ; ex "R4" (v ~width:(Size.Px 160) ~height:(Size.Px 16) ~radius:Astryx.Skeleton.R4 ())
    ; ex "Rounded (pill)" (v ~width:(Size.Px 160) ~height:(Size.Px 16) ~radius:Astryx.Skeleton.Rounded ())
    ; ex
        "a paragraph of placeholders"
        (Astryx.Stack.view
           ~gap:S.S2
           [ v ~width:(Size.Css "60%") ~height:(Size.Px 12) ()
           ; v ~width:(Size.Css "90%") ~height:(Size.Px 12) ()
           ; v ~width:(Size.Css "75%") ~height:(Size.Px 12) ()
           ])
    ]
;;

let s_center () =
  let v = Astryx.Center.view in
  section
    ~id:"center"
    ~title:"Center"
    ~note:"Centres on logical axes: Horizontal centres the inline axis, Vertical the block axis, Both does both. Padding follows upstream's precedence (inline-start beats inline beats padding)."
    [ ex "axis: Both" (v ~axis:Astryx.Center.Both ~height:(Size.Px 80) [ chip "both" ])
    ; ex "axis: Horizontal" (v ~axis:Astryx.Center.Horizontal [ chip "horizontal" ])
    ; ex "axis: Vertical" (v ~axis:Astryx.Center.Vertical ~height:(Size.Px 80) [ chip "vertical" ])
    ; ex "is_inline" (v ~axis:Astryx.Center.Both ~is_inline:true [ chip "inline" ])
    ; ex "padding 4" (v ~axis:Astryx.Center.Both ~height:(Size.Px 80) ~padding:S.S4 [ chip "padded" ])
    ; ex
        "padding_inline_start wins"
        (v
           ~axis:Astryx.Center.Both
           ~height:(Size.Px 80)
           ~padding:S.S2
           ~padding_inline:S.S4
           ~padding_inline_start:S.S6
           [ chip "precedence" ])
    ]
;;

let s_section () =
  let v = Astryx.Section.view in
  let inner s = Astryx.Text.view [ Vdom.Node.text s ] in
  section
    ~id:"section"
    ~title:"Section"
    ~note:"Page region with a background variant, spacing-scale padding (default step 4) and dividers on chosen logical sides."
    [ ex "variant: Section" (v ~padding:S.S4 [ inner "Section" ])
    ; ex "variant: Transparent" (v ~variant:Astryx.Section.Transparent ~padding:S.S4 [ inner "Transparent" ])
    ; ex "variant: Muted" (v ~variant:Astryx.Section.Muted ~padding:S.S4 [ inner "Muted" ])
    ; ex "dividers: Top" (v ~dividers:[ Astryx.Section.Top ] ~padding:S.S4 [ inner "Top border" ])
    ; ex
        "dividers: Top + Bottom"
        (v ~dividers:[ Astryx.Section.Top; Astryx.Section.Bottom ] ~padding:S.S4 [ inner "Both borders" ])
    ; ex
        "dividers: Start + End"
        (v ~dividers:[ Astryx.Section.Start; Astryx.Section.End ] ~padding:S.S4 [ inner "Logical sides" ])
    ; ex "padding 6" (v ~padding:S.S6 [ inner "Loose" ])
    ]
;;

let s_grid () =
  let cell s = Vdom.Node.div ~attrs:[ Vdom.Attr.class_ "cell" ] [ Vdom.Node.text s ] in
  let v = Astryx.Grid.view in
  section
    ~id:"grid"
    ~title:"Grid"
    ~note:"Two track forms, emitting upstream's exact CSS: Fixed n → repeat(n, 1fr); Responsive (px, Fill|Fit) → repeat(auto-fill|auto-fit, minmax(px, 1fr)). Upstream's {max} form is deliberately unported (see the .mli)."
    [ ex "Fixed 2" (v ~columns:(Astryx.Grid.Fixed 2) ~gap:S.S3 [ cell "1"; cell "2"; cell "3"; cell "4" ])
    ; ex "Fixed 3" (v ~columns:(Astryx.Grid.Fixed 3) ~gap:S.S3 [ cell "1"; cell "2"; cell "3" ])
    ; ex "Fixed 4" (v ~columns:(Astryx.Grid.Fixed 4) ~gap:S.S2 [ cell "1"; cell "2"; cell "3"; cell "4"; cell "5"; cell "6"; cell "7"; cell "8" ])
    ; ex
        "Responsive (180, Fill)"
        (v
           ~columns:(Astryx.Grid.Responsive (180, Astryx.Grid.Fill))
           ~gap:S.S3
           [ cell "1"; cell "2"; cell "3"; cell "4"; cell "5" ])
    ; ex
        "Responsive (180, Fit)"
        (v
           ~columns:(Astryx.Grid.Responsive (180, Astryx.Grid.Fit))
           ~gap:S.S3
           [ cell "1"; cell "2"; cell "3" ])
    ; ex
        "row_gap / column_gap differ"
        (v ~columns:(Astryx.Grid.Fixed 3) ~row_gap:S.S6 ~column_gap:S.S1 [ cell "1"; cell "2"; cell "3"; cell "4"; cell "5"; cell "6" ])
    ]
;;

let s_visually_hidden () =
  section
    ~id:"visuallyhidden"
    ~title:"VisuallyHidden"
    ~note:"Exposed to assistive technology, invisible on screen — so these examples look empty on purpose. The clip block is fixed; upstream deliberately omits className/style here so a consumer cannot accidentally un-hide it."
    [ ex "Span (default)" (Astryx.VisuallyHidden.view [ Vdom.Node.text "screen-reader only, span" ])
    ; ex "Div" (Astryx.VisuallyHidden.view ~element:Astryx.VisuallyHidden.Div [ Vdom.Node.text "screen-reader only, div" ])
    ; ex "P" (Astryx.VisuallyHidden.view ~element:Astryx.VisuallyHidden.P [ Vdom.Node.text "screen-reader only, p" ])
    ]
;;

(* ------------------------------------------------- interactive (state) *)

(* A real counter: the harness clicks this button in Chromium and asserts the
   number changed. That is interaction testing, which the jsdom gate cannot do.

   Written with explicit combinators rather than let%sub/let%arr: in this preview
   release `Bonsai.state` takes the graph and returns a *pair of trees*
   (['model t * ('model -> unit Effect.t) t]), which is not the shape the ppx
   sugar expects. Bonsai.map2 is the direct, type-checked way to combine them. *)
let interactive (graph : Bonsai.graph) =
  let count, set_count = Bonsai.state 0 graph in
  let show_status, set_show_status = Bonsai.state false graph in
  let counter = Bonsai.map2 count set_count ~f:(fun count set_count -> count, set_count) in
  (* Both state values *and* both setters have to be unwrapped here: in this release
     Bonsai.state returns each as a tree, so a setter used inside a map callback must be
     mapped over like any other value. *)
  let status = Bonsai.map2 show_status set_show_status ~f:(fun v set_v -> v, set_v) in
  Bonsai.map2 counter status ~f:(fun (count, set_count) (show_status, set_show_status) ->
    section
      ~id:"interactive"
      ~title:"Interactive"
      ~note:
        "Stateful: the button's on_click increments a Bonsai state value. The browser gate \
         clicks it and reads the counter back. The second example mounts a FieldStatus on \
         demand — that is the only way to observe the entry animation, since upstream \
         deliberately does not animate anything present on the first paint."
      [ ex
          "increment"
          (Astryx.Stack.view
             ~direction:Astryx.Stack.Horizontal
             ~gap:S.S3
             ~align:A.Center
             [ Astryx.Button.view
                 ~label:"Increment"
                 ~variant:Astryx.Button.Primary
                 ~on_click:(fun _ -> set_count (count + 1))
                 []
             ; Astryx.Text.view
                 ~id:"click-count"
                 ~type_:Text.Large
                 ~has_tabular_numbers:true
                 [ Vdom.Node.text (sprintf "count: %d" count) ]
             ])
      ; ex
          "a status mounted after the first paint animates in"
          (Astryx.Stack.view
             ~direction:Astryx.Stack.Vertical
             ~gap:S.S3
             [ Astryx.Button.view
                 ~label:"Show status"
                 ~on_click:(fun _ -> set_show_status true)
                 []
             ; (if show_status
                then
                  Astryx.Field_status.view
                    ~variant:Astryx.Field_status.Detached
                    ~type_:Astryx.Field_status.Error
                    ~message:"This appeared after the first paint, so it animates."
                    ~attrs:[ Vdom.Attr.id "late-status" ]
                    ()
                else Vdom.Node.none)
             ; Astryx.Button.view
                 ~label:"Hide status"
                 ~on_click:(fun _ -> set_show_status false)
                 []
             ])
      ])
;;

(* ------------------------------------------- HStack / VStack / AspectRatio *)

(* HStack and VStack render through Stack upstream, so their examples are labelled
   with the preset, not a separate component name. *)
let s_hstack () =
  section
    ~id:"hstack"
    ~title:"HStack"
    ~note:
      "A prop preset over Stack with direction pinned horizontal — upstream renders \
       it through Stack, so it carries Stack's marker. hAlign drives the main axis, \
       vAlign the cross axis; justify/align are the Tailwind-style aliases."
    [ ex "gap: 2" (Astryx.HStack.view ~gap:S.S2 [ chip "a"; chip "b"; chip "c" ])
    ; ex "hAlign: Center" (Astryx.HStack.view ~h_align:A.Center ~gap:S.S2 [ chip "a"; chip "b" ])
    ; ex
        "justify: Between"
        (Astryx.HStack.view ~justify:A.Between ~gap:S.S2 [ chip "a"; chip "b"; chip "c" ])
    ; ex "vAlign: End" (Astryx.HStack.view ~v_align:A.End ~gap:S.S2 [ chip "a"; chip "b" ])
    ]
;;

let s_vstack () =
  section
    ~id:"vstack"
    ~title:"VStack"
    ~note:
      "The mirror of HStack: direction pinned vertical, so vAlign drives the main \
       axis and hAlign the cross axis. Everything else is Stack."
    [ ex "gap: 2" (Astryx.VStack.view ~gap:S.S2 [ chip "a"; chip "b"; chip "c" ])
    ; ex "vAlign: End" (Astryx.VStack.view ~v_align:A.End ~gap:S.S2 [ chip "a"; chip "b" ])
    ; ex
        "justify: Between"
        (Astryx.VStack.view ~justify:A.Between ~gap:S.S1 [ chip "a"; chip "b"; chip "c" ])
    ; ex "hAlign: Center" (Astryx.VStack.view ~h_align:A.Center ~gap:S.S2 [ chip "a"; chip "b" ])
    ]
;;

let s_aspect_ratio () =
  section
    ~id:"aspectratio"
    ~title:"AspectRatio"
    ~note:
      "Two elements, as upstream: the outer box holds the ratio and the clip, the \
       inner box fills it. The ratio is emitted as a CSS custom property rather than \
       an inline aspect-ratio, so a consumer rule can still override it — which is \
       how a responsive ratio is set."
    [ ex
        "ratio: 16/9"
        (Astryx.AspectRatio.view
           ~ratio:(16. /. 9.)
           [ Vdom.Node.div ~attrs:[ Vdom.Attr.class_ "ratio-fill" ] [ Vdom.Node.text "16 / 9" ] ])
    ; ex
        "ratio: 4/3"
        (Astryx.AspectRatio.view
           ~ratio:(4. /. 3.)
           [ Vdom.Node.div ~attrs:[ Vdom.Attr.class_ "ratio-fill" ] [ Vdom.Node.text "4 / 3" ] ])
    ; ex
        "ratio: 1 (square)"
        (Astryx.AspectRatio.view
           ~ratio:1.0
           [ Vdom.Node.div ~attrs:[ Vdom.Attr.class_ "ratio-fill" ] [ Vdom.Node.text "1 / 1" ] ])
    ; ex
        "shape: Ellipse, fit: Cover"
        (Astryx.AspectRatio.view
           ~ratio:1.0
           ~shape:Astryx.AspectRatio.Ellipse
           ~fit:Astryx.AspectRatio.Cover
           [ Vdom.Node.div ~attrs:[ Vdom.Attr.class_ "ratio-fill" ] [] ])
    ; ex
        "fit: Contain"
        (Astryx.AspectRatio.view
           ~ratio:(16. /. 9.)
           ~fit:Astryx.AspectRatio.Contain
           [ Vdom.Node.div ~attrs:[ Vdom.Attr.class_ "ratio-fill" ] [] ])
    ; ex
        "fit: Center"
        (Astryx.AspectRatio.view
           ~ratio:(16. /. 9.)
           ~fit:Astryx.AspectRatio.Center
           [ Vdom.Node.div ~attrs:[ Vdom.Attr.class_ "ratio-chip" ] [ Vdom.Node.text "natural size" ] ])
    ]
;;

(* ------------------------------------------- IconButton / Code / Blockquote *)

let s_icon_button () =
  section
    ~id:"iconbutton"
    ~title:"IconButton"
    ~note:
      "A Button preset with isIconOnly set — upstream is literally \
       <Button {...props} icon={icon} isIconOnly />, so it keeps Button's marker. The \
       required label becomes the accessible name, which is why an icon-only control \
       in this library can never be nameless."
    [ ex "variant: Secondary" (Astryx.IconButton.view ~label:"Add item" ~icon:button_icon ())
    ; ex
        "variant: Primary"
        (Astryx.IconButton.view ~variant:Astryx.Button.Primary ~label:"Add item" ~icon:button_icon ())
    ; ex "size: Lg" (Astryx.IconButton.view ~size:Astryx.Button.Lg ~label:"Add item" ~icon:button_icon ())
    ; ex "is_loading" (Astryx.IconButton.view ~label:"Add item" ~is_loading:true ~icon:button_icon ())
    ; ex "is_disabled" (Astryx.IconButton.view ~label:"Add item" ~is_disabled:true ~icon:button_icon ())
    ]
;;

let s_code () =
  section
    ~id:"code"
    ~title:"Code"
    ~note:
      "A real <code> element. Text's 'code' type is a span carrying code styling — \
       upstream keeps those two separate and so does this port."
    [ ex "color: Primary" (Astryx.Code.view [ Vdom.Node.text "const answer = 42;" ])
    ; ex
        "color: Secondary"
        (Astryx.Code.view ~color:Astryx.Code.Secondary [ Vdom.Node.text "npm run gates" ])
    ; ex "color: Inherit" (Astryx.Code.view ~color:Astryx.Code.Inherit [ Vdom.Node.text "inherit" ])
    ; ex "size: Inherit" (Astryx.Code.view ~size:Astryx.Code.Inherit [ Vdom.Node.text "inherit" ])
    ; ex
        "inside larger text"
        (Astryx.Text.view
           ~type_:Text.Large
           [ Vdom.Node.text "run "
           ; Astryx.Code.view ~size:Astryx.Code.Inherit [ Vdom.Node.text "dune build" ]
           ; Vdom.Node.text " before pushing"
           ])
    ]
;;

let s_blockquote () =
  section
    ~id:"blockquote"
    ~title:"Blockquote"
    ~note:
      "The optional cite renders as a bare <cite>. Never a <footer>: blockquote is a \
       sectioning root, so a footer inside it would map to a contentinfo landmark and \
       hand a quote an accessibility landmark it should not have."
    [ ex
        "plain"
        (Astryx.Blockquote.view
           [ Vdom.Node.text "Programs must be written for people to read, and only \
                              incidentally for machines to execute." ])
    ; ex
        "with cite"
        (Astryx.Blockquote.view
           ~cite:(Vdom.Node.text "Abelson & Sussman, SICP")
           [ Vdom.Node.text "A port is a rewrite with the same contract, not a \
                              translation of the syntax." ])
    ]
;;

(* ---------------------------------------------------------------- assembly *)

(* ------------------------------------------- NavIcon / EmptyState / Citation *)

let s_nav_icon () =
  section
    ~id:"navicon"
    ~title:"NavIcon"
    ~note:
      "One round accent bubble, sized by a token. Deliberately not responsive: the size \
       comes from --size-element-md, so a theme change resizes it and the component needs \
       no media query. Upstream leaves the icon's accessibility to the caller and so does \
       this port."
    [ ex "icon node" (Astryx.NavIcon.view ~icon:button_icon ())
    ; ex "text glyph" (Astryx.NavIcon.view ~icon:(Vdom.Node.span [ Vdom.Node.text "S" ]) ())
    ]
;;

let s_empty_state () =
  section
    ~id:"emptystate"
    ~title:"EmptyState"
    ~note:
      "role=status, so assistive tech is told the state changed. The title is a real \
       heading (h3 by default). The description renders as a div, never a <p>: it accepts \
       arbitrary nodes and a <p> cannot legally contain block children."
    [ ex "with icon, description and actions"
        (Astryx.EmptyState.view
           ~title:"No results"
           ~description:(Vdom.Node.text "Try a different search term or clear the filters.")
           ~icon:button_icon
           ~actions:
             [ Astryx.Button.view ~variant:Astryx.Button.Primary ~label:"Clear filters" []
             ; Astryx.Button.view ~label:"Learn more" []
             ]
           ())
    ; ex "title only" (Astryx.EmptyState.view ~title:"Nothing here yet" ())
    ; ex "is_compact"
        (Astryx.EmptyState.view ~is_compact:true ~title:"Nothing here yet" ())
    ; ex "heading_level: H2"
        (Astryx.EmptyState.view ~heading_level:Astryx.EmptyState.H2 ~title:"No results" ())
    ]
;;

let s_citation () =
  section
    ~id:"citation"
    ~title:"Citation"
    ~note:
      "The URL is checked before it becomes an href: control characters are stripped first \
       (so 'java\\0script:' cannot slip through), and javascript:, vbscript: and \
       data:text/html are refused. A refused URL does not remove the citation — it renders \
       as inert text instead of a link, which is what the last example shows."
    [ ex "label, with URL"
        (Astryx.Citation.view
           ~source:
             (Astryx.Citation.source
                ~title:"Designing with design tokens"
                ~url:"https://example.com/tokens"
                ())
           ~number:1
           ())
    ; ex "number"
        (Astryx.Citation.view
           ~variant:Astryx.Citation.Number
           ~source:(Astryx.Citation.source ~url:"https://example.com/a" ())
           ~number:2
           ())
    ; ex "with favicon"
        (Astryx.Citation.view
           ~source:
             (Astryx.Citation.source
                ~title:"example.com"
                ~url:"https://example.com"
                (* A local asset on purpose: the showcase must not reach out to the
                   network to render its own examples, and a remote favicon produced a
                   console error (ERR_NAME_NOT_RESOLVED) in the browser gate. *)
                ~src:"/site/favicon.svg"
                ())
           ~number:3
           ())
    ; ex "no URL: inert, still named"
        (Astryx.Citation.view
           ~source:(Astryx.Citation.source ~title:"Offline source" ())
           ~number:4
           ())
    ; ex "refused URL (javascript:) renders inert"
        (Astryx.Citation.view
           ~source:
             (Astryx.Citation.source ~title:"Untrusted" ~url:"javascript:alert(1)" ())
           ~number:5
           ())
    ; ex "number only, no URL"
        (Astryx.Citation.view
           ~variant:Astryx.Citation.Number
           ~source:(Astryx.Citation.source ())
           ~number:6
           ())
    ]
;;

(* --------------------------------------------------------------------- Icon *)

let icon_gallery () =
  Vdom.Node.div
    ~attrs:(Astryx.Common.Attr.class_ [ "icon-gallery" ])
    (List.map Astryx.Icon.names ~f:(fun name ->
       Vdom.Node.div
         ~attrs:(Astryx.Common.Attr.class_ [ "icon-gallery__cell" ])
         [ Astryx.Icon.view ~name ()
         ; Vdom.Node.span
             ~attrs:(Astryx.Common.Attr.class_ [ "icon-gallery__name" ])
             [ Vdom.Node.text name ]
         ]))
;;

let s_icon () =
  section
    ~id:"icon"
    ~title:"Icon"
    ~note:
      "Every glyph here is generated from upstream's defaultIcons.tsx by \
       tools/extract-icons.mjs: the path data is copied byte for byte rather than retyped, \
       and the generator refuses to write a partial table. Sizes are 12/16/20/24px \
       (xsm/sm/md/lg) and the default is md. Colour flows through currentColor, so an \
       icon takes its parent's colour unless given one of the token colours."
    [ ex "all 30 icons in the registry" (icon_gallery ())
    ; ex "sizes: xsm, sm, md (default), lg"
        (Vdom.Node.div
           ~attrs:(Astryx.Common.Attr.class_ [ "row" ])
           [ Astryx.Icon.view ~size:Astryx.Icon.Xsm ~name:"search" ()
           ; Astryx.Icon.view ~size:Astryx.Icon.Sm ~name:"search" ()
           ; Astryx.Icon.view ~name:"search" ()
           ; Astryx.Icon.view ~size:Astryx.Icon.Lg ~name:"search" ()
           ])
    ; ex "token colours"
        (Vdom.Node.div
           ~attrs:(Astryx.Common.Attr.class_ [ "row" ])
           [ Astryx.Icon.view ~size:Astryx.Icon.Lg ~color:Astryx.Icon.Primary ~name:"info" ()
           ; Astryx.Icon.view ~size:Astryx.Icon.Lg ~color:Astryx.Icon.Success ~name:"success" ()
           ; Astryx.Icon.view ~size:Astryx.Icon.Lg ~color:Astryx.Icon.Error ~name:"error" ()
           ; Astryx.Icon.view ~size:Astryx.Icon.Lg ~color:Astryx.Icon.Warning ~name:"warning" ()
           ; Astryx.Icon.view ~size:Astryx.Icon.Lg ~color:Astryx.Icon.Accent ~name:"calendar" ()
           ; Astryx.Icon.view ~size:Astryx.Icon.Lg ~color:Astryx.Icon.Gray ~name:"clock" ()
           ])
    ; ex "solid status glyphs (fill, no stroke)" (Astryx.Icon.view ~name:"stop" ())
    ; ex "labelled: role=img plus aria-label"
        (Astryx.Icon.view ~label:"Delete row" ~name:"close" ())
    ; ex "an unknown name is visible, not silent"
        (Astryx.Icon.view ~name:"noSuchIcon" ())
    ]
;;

(* --------------------------------------------------------------- FieldStatus *)

let s_field_status () =
  section
    ~id:"fieldstatus"
    ~title:"FieldStatus"
    ~note:
      "attached (the default) overlaps the control above it: a negative top margin, the \
       bottom corners rounded, and pointer-events:none so the overlap cannot swallow a \
       click meant for the control. It renders the message as bare text. detached sits \
       below the control with the type's icon. The role carries the urgency: alert for an \
       error, status otherwise — which is how upstream's announcer behaves. Nothing here \
       animates, because everything on this page is present at the first paint."
    [ ex "attached: warning / error / success"
        (Astryx.Stack.view
           ~direction:Astryx.Stack.Vertical
           ~gap:S.S2
           [ Astryx.Field_status.view
               ~type_:Astryx.Field_status.Warning
               ~message:"This will replace the existing file."
               ()
           ; Astryx.Field_status.view
               ~type_:Astryx.Field_status.Error
               ~message:"That email address is already in use."
               ()
           ; Astryx.Field_status.view
               ~type_:Astryx.Field_status.Success
               ~message:"Saved just now."
               ()
           ])
    ; ex "detached: warning"
        (Astryx.Field_status.view
           ~variant:Astryx.Field_status.Detached
           ~type_:Astryx.Field_status.Warning
           ~message:"Changes apply to every project."
           ())
    ; ex "detached: error"
        (Astryx.Field_status.view
           ~variant:Astryx.Field_status.Detached
           ~type_:Astryx.Field_status.Error
           ~message:"Could not reach the server. Try again."
           ())
    ; ex "detached: success"
        (Astryx.Field_status.view
           ~variant:Astryx.Field_status.Detached
           ~type_:Astryx.Field_status.Success
           ~message:"Invitation sent."
           ())
    ]
;;

module Dm = Astryx.Dropdown_menu

let demo_menu_item
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

let demo_menu_entries : Dm.entry list =
  [ Dm.Item
      (demo_menu_item
         ~description:"Create a file in this project"
         ~end_content:(Vdom.Node.text "⌘N")
         ~icon:"info"
         "new"
         "New file")
  ; Dm.Item (demo_menu_item ~end_content:(Vdom.Node.text "⌘O") "open" "Open")
  ; Dm.Item (demo_menu_item ~icon:"success" "save" "Save")
  ; Dm.Divider
  ; Dm.Item (demo_menu_item ~is_disabled:true "duplicate" "Duplicate")
  ; Dm.Heading "Danger zone"
  ; Dm.Item
      (demo_menu_item
         ~description:"This cannot be undone"
         ~icon:"error"
         ~variant:Dm.Destructive
         "delete"
         "Delete project")
  ; Dm.Group
      { heading = Some "Sort by"
      ; items = [ demo_menu_item "sort-name" "Name"; demo_menu_item "sort-date" "Date modified" ]
      }
  ; Dm.Item (demo_menu_item ~href:"#dropdownmenu" "docs" "Documentation")
  ]
;;

(* DropdownMenu is the first ported component whose behaviour is mostly not a function
   of its props: the highlight is DOM focus, rows are found by querying the container,
   and the keyboard is what moves between them. jsdom cannot express that — a synthetic
   key event there carries no [key] — so this section is where the keyboard, the
   typeahead and the focus return are asserted for real, by
   tools/visual/verify-browser.mjs against Chromium.

   The selection is the *consumer's* state (the menu hands the item to [on_select] and
   the page renders it), which is why it is shown as a separate example. *)
let dropdown_menu_demo (graph : Bonsai.graph) =
  let selected, set_selected = Bonsai.state (None : string option) graph in
  let on_select =
    Bonsai.map set_selected ~f:(fun set_selected (item : Dm.item) -> set_selected (Some item.id))
  in
  let menu =
    Dm.view ~id:"menu-file" ~trigger_label:"File" ~on_select ~entries:demo_menu_entries graph
  in
  (* Controlled: the open state lives out here, so the button below opens the menu without touching its
     trigger. That is the whole difference between a menu that owns its state and one whose owner does, and
     the only way to prove it is to open it from somewhere else. *)
  let controlled_open, set_controlled_open = Bonsai.state false graph in
  let controlled_state =
    Bonsai.map2 controlled_open set_controlled_open ~f:(fun value setter -> value, setter)
  in
  let controlled =
    Dm.view
      ~id:"menu-controlled"
      ~trigger_label:"Controlled"
      ~is_open:controlled_open
      ~on_open_change:set_controlled_open
      ~on_select
      ~entries:demo_menu_entries
      graph
  in
  let controlled_example =
    Bonsai.map2 controlled_state controlled ~f:(fun (is_open, set_is_open) controlled ->
      ex
        "a controlled menu, opened from outside its trigger"
        (Vdom.Node.div
           [ Astryx.Button.view
               ~label:(sprintf "Turn it %s from here" (if is_open then "off" else "on"))
               ~attrs:[ Vdom.Attr.id "menu-controlled-toggle" ]
               ~on_click:(fun _ -> set_is_open (not is_open))
               []
           ; controlled
           ]))
  in
  (* And the trigger is a Button all the way down, so an icon-only ghost button is configuration. *)
  let icon_only =
    Dm.view
      ~id:"menu-icon-only"
      ~trigger_label:"More"
      ~variant:Astryx.Button.Ghost
      ~is_icon_only:true
      ~icon:(Vdom.Node.span ~attrs:[ Vdom.Attr.class_ "demo-glyph" ] [ Vdom.Node.text "\xe2\x8b\xaf" ])
      ~on_select
      ~entries:demo_menu_entries
      graph
  in
  let pair a b = Bonsai.map2 a b ~f:(fun a b -> a, b) in
  Bonsai.map2
    (pair selected menu)
    (pair controlled_example icon_only)
    ~f:(fun (selected, menu) (controlled_example, icon_only) ->
      section
        ~id:"dropdownmenu"
        ~title:"DropdownMenu"
        ~note:
          "A menu button: click or press Down to open, Up/Down/Home/End to move, typing to \
           jump to a row, Enter or Space to choose, Escape to close and hand focus back to \
           the trigger. A row can carry an icon, a description and right-aligned end \
           content, and a row with an href is the anchor itself, so ⌘-click still opens a \
           tab. A disabled row cannot take focus, so the arrow keys skip it: the port \
           excludes it by selector rather than testing it later, which is what upstream \
           does. The menu can also be controlled - the caller owns the open state and hears \
           about every change through one callback - and its trigger is a Button, so an \
           icon-only ghost trigger is configuration rather than a second component."
        [ ex "a menu button" menu
        ; controlled_example
        ; ex "an icon-only ghost trigger" icon_only
        ; ex
            "the selection reaches the consumer"
            (Astryx.Text.view
               ~id:"menu-selection"
               [ Vdom.Node.text
                   (match selected with
                    | Some id -> sprintf "selected: %s" id
                    | None -> "selected: —")
               ])
        ])
;;


(* Field + TextInput are demonstrated together because that is how they are used: TextInput
   renders the control, and Field owns the label, the description and the status around it. *)
let field_demo (graph : Bonsai.graph) =
  let name, set_name = Bonsai.state "" graph in
  let email, set_email = Bonsai.state "" graph in
  let on_change setter = Bonsai.map setter ~f:(fun set value -> set value) in
  (* The setter is a value in the graph and TextInput takes it as one, so each input stays a
     single expression — no wrapping map, and therefore no tree of a tree. *)
  let name_input =
    Astryx.TextInput.view
      ~label:"Full name"
      ~id:"showcase-field-name"
      ~description:"Exactly as it should appear on an invoice."
      ~is_required:true
      ~placeholder:"Ada Lovelace"
      ~value:name
      ~on_change:(on_change set_name)
      ()
  in
  let email_input =
    Astryx.TextInput.view
      ~label:"Email"
      ~id:"showcase-field-email"
      ~type_:Astryx.TextInput.Email
      ~start_icon:"search"
      ~is_optional:true
      ~placeholder:"ada@example.com"
      ~value:email
      ~on_change:(on_change set_email)
      ()
  in
  (* What the application holds, on screen: the browser gate types into the input above and
     asserts this line changed, which is the only way to tell a controlled input from one that
     merely looks right at first paint. *)
  let typed =
    Bonsai.map2 name email ~f:(fun name email ->
      Vdom.Node.p
        ~attrs:[ Vdom.Attr.create "data-showcase-typed" "true" ]
        [ Vdom.Node.text (sprintf "name=%S email=%S" name email) ])
  in
  let static ?status ?status_variant ?is_disabled ?is_label_hidden ?type_ ?start_icon ~label ~id
        value
    =
    Astryx.TextInput.view
      ~label
      ~id
      ?status
      ?status_variant
      ?is_disabled
      ?is_label_hidden
      ?type_
      ?start_icon
      ~value:(Bonsai.return value)
      ~on_change:(Bonsai.return (fun _ -> Effect.Many []))
      ()
  in
  (* Enter is the one thing jsdom cannot test — its synthetic key events carry an empty key — so
     the showcase exposes a field whose only job is to be submitted with a real key press. *)
  let submitted, set_submitted = Bonsai.state false graph in
  let enter_input =
    Astryx.Text_input.view
      ~label:"Submit with Enter"
      ~id:"showcase-field-enter"
      ~description:"The application only hears about Enter, not about the keystrokes."
      ~placeholder:"then press Enter"
      ~value:(Bonsai.return "")
      ~on_change:(Bonsai.return (fun _ -> Effect.Many []))
      ~on_enter:(Bonsai.map set_submitted ~f:(fun set -> set true))
      ()
  in
  let submitted_echo =
    Bonsai.map submitted ~f:(fun submitted ->
      Vdom.Node.p
        ~attrs:
          [ Vdom.Attr.create
              "data-showcase-submitted"
              (if submitted then "true" else "false")
          ]
        [ Vdom.Node.text
            (if submitted then "enter: received" else "enter: nothing yet")
        ])
  in
  let nodes =
    unwrap_all
      [ typed
      ; static
          ~label:"Workspace"
          ~id:"showcase-field-attached"
          ~status:{ Astryx.Input_types.type_ = Astryx.Input_types.Error; message = Some "That name is taken." }
          "acme"
      ; static
          ~label:"API key"
          ~id:"showcase-field-detached"
          ~status:{ Astryx.Input_types.type_ = Astryx.Input_types.Success; message = Some "Verified." }
          ~status_variant:Astryx.Field_status.Detached
          "sk-live-1234"
      ; static
          ~label:"Database"
          ~id:"showcase-field-tooltip"
          ~status:{ Astryx.Input_types.type_ = Astryx.Input_types.Warning; message = Some "This one is read-only." }
          ~status_variant:Astryx.Field_status.Tooltip
          "primary"
      ; static
          ~label:"Account id"
          ~id:"showcase-field-disabled"
          ~is_label_hidden:true
          ~is_disabled:true
          "acct_9f21"
      ; static
          ~label:"Password"
          ~id:"showcase-field-readonly"
          ~type_:Astryx.TextInput.Password
          "correct-horse-battery-staple"
      ; enter_input
      ; submitted_echo
      ]
  in
  let inputs = Bonsai.both name_input email_input in
  Bonsai.map2 inputs nodes ~f:(fun (name_node, email_node) nodes ->
    (* Read back by position: the names are the labels of the list above, so the order is visible
       next to them, and a missing example fails loudly instead of rendering the wrong node. *)
    let nth i =
      match List.nth nodes i with
      | Some node -> node
      | None -> failwith (sprintf "field_demo: no example at index %d" i)
    in
    let typed = nth 0 in
    let attached = nth 1 in
    let detached = nth 2 in
    let tooltip = nth 3 in
    let disabled = nth 4 in
    let readonly = nth 5 in
    let enter_node = nth 6 in
    let submitted_node = nth 7 in
    section
      ~id:"field"
      ~title:"Field + TextInput"
      ~note:
        "A text input is two components, not one. Field owns the label, the description and the \
         status; TextInput renders the control that points at them. The wiring is the point: \
         the label is a real <label for>, the control is named once and never also with \
         aria-labelledby, aria-describedby lists only the text that is really rendered, and \
         Required/Optional is shown and announced as the same thing. A status can be attached \
         (behind the control's bottom edge — the default), detached (below the field, for a \
         control with no border of its own) or a tooltip, which renders no message box at all \
         and announces the message instead. Typing in the first two fields reaches the \
         application: the line under them is what the port's state actually holds. The last field \
         is submitted with Enter, which the browser gate presses for real — jsdom's synthetic \
         key events carry an empty key, so a keyboard assertion there would be worthless."
      [ ex "a required field, with a description" name_node
      ; ex "an optional field, with a start icon" email_node
      ; ex "the value the application holds" typed
      ; ex "an attached error (the default placement)" attached
      ; ex "a detached success" detached
      ; ex "the tooltip placement renders no message box" tooltip
      ; ex "a disabled field, with its label hidden" disabled
      ; ex "a read-only password field" readonly
      ; ex "Enter reaches the application, and nothing else does" enter_node
      ; ex "what the application heard" submitted_node
      ])
;;

(* ---------------------------------------------------------------- TextArea *)

let text_area_demo (graph : Bonsai.graph) =
  let draft, set_draft = Bonsai.state "Ready when you are." graph in
  let on_change set = Bonsai.map set ~f:(fun set value -> set value) in
  let live =
    Astryx.TextArea.view
      ~label:"Release notes"
      ~id:"showcase-textarea-live"
      ~description:"Markdown is fine; the review step renders it."
      ~is_required:true
      ~rows:4
      ~placeholder:"What changed?"
      ~value:draft
      ~on_change:(on_change set_draft)
      ()
  in
  (* The value the application holds, on screen. A textarea's value is its child text, so the
     question the browser gate asks here is the one a naive port fails: type, then let a re-render
     happen, and see whether the text the user typed is still there. *)
  let echo =
    Bonsai.map draft ~f:(fun draft ->
      Vdom.Node.p
        ~attrs:[ Vdom.Attr.create "data-showcase-textarea" "true" ]
        [ Vdom.Node.text (sprintf "textarea=%S" draft) ])
  in
  let static
        ?status
        ?status_variant
        ?is_disabled
        ?is_read_only
        ?placeholder
        ?rows
        ?size
        ~label
        ~id
        value
    =
    Astryx.TextArea.view
      ~label
      ~id
      ?status
      ?status_variant
      ?is_disabled
      ?is_read_only
      ?placeholder
      ?rows
      ?size
      ~value:(Bonsai.return value)
      ~on_change:(Bonsai.return (fun _ -> Effect.Many []))
      ()
  in
  let nodes =
    unwrap_all
      [ static ~label:"Notes" ~id:"showcase-textarea-default" "Three rows, which is upstream's default."
      ; static
          ~label:"Changelog"
          ~id:"showcase-textarea-rows"
          ~rows:6
          ~placeholder:"One line per change"
          "Six rows, and a placeholder until there is something to say."
      ; static
          ~label:"Commit summary"
          ~id:"showcase-textarea-error"
          ~status:
            { Astryx.Input_types.type_ = Astryx.Input_types.Error
            ; message = Some "Keep the summary under 72 characters."
            }
          "A summary line long enough to be rejected by an imaginary repository"
      ; static
          ~label:"Deploy target"
          ~id:"showcase-textarea-no-message"
          ~status:{ Astryx.Input_types.type_ = Astryx.Input_types.Warning; message = None }
          "coloured, with nothing to say yet"
      ; static ~label:"Frozen" ~id:"showcase-textarea-disabled" ~is_disabled:true "Cannot be edited."
      ; static
          ~label:"Reference"
          ~id:"showcase-textarea-readonly"
          ~is_read_only:true
          "Selectable, submittable, not editable."
      ; static
          ~label:"Small"
          ~id:"showcase-textarea-sm"
          ~size:Astryx.TextArea.Sm
          "Small padding, same row count."
      ]
  in
  let live = Bonsai.both live echo in
  Bonsai.map2 live nodes ~f:(fun (live_node, echo_node) nodes ->
    let nth i =
      match List.nth nodes i with
      | Some node -> node
      | None -> failwith (sprintf "text_area_demo: no example at index %d" i)
    in
    let default_rows = nth 0 in
    let six_rows = nth 1 in
    let error = nth 2 in
    let no_message = nth 3 in
    let disabled = nth 4 in
    let readonly = nth 5 in
    let small = nth 6 in
    section
      ~id:"textarea"
      ~title:"TextArea"
      ~note:
        "The same Field wrapper as TextInput, with a textarea inside it — so the label, the \
         description and the status wiring are the ones already verified, and the difference is \
         the element. Two of those differences are real. A textarea ignores a value attribute; \
         its value is its child text, and React hides that by treating value as a property, so a \
         port that copies the JSX has a field that looks right and discards what the user types. \
         And its size is padding, not height: upstream's own note is that rows controls the \
         height, so the sizes here deliberately have no height rule. The first control's value \
         reaches the application — the line under it is what the state holds after the browser \
         gate types. The fourth example is a status with no message: coloured, with no box and \
         nothing announced, because there is nothing to say yet."
      [ ex "a required textarea, with a description" live_node
      ; ex "the value the application holds" echo_node
      ; ex "three rows, upstream's default" default_rows
      ; ex "rows:6, the height comes from the row count" six_rows
      ; ex "an error, attached" error
      ; ex "a status with no message renders no box" no_message
      ; ex "a disabled textarea" disabled
      ; ex "a read-only textarea" readonly
      ; ex "size sm: padding, not height" small
      ])
;;

let s_field_label () =
  (* The label group on its own — which is how a control that is not a Field uses it: the label
     names the control by id, and nothing here is inside a Field. The last example is the
     group-label path, where the label is a <span> and a set of controls names itself from it. *)
  let labelled ?label_icon ?label_id ?(is_group_label = false) ?(is_label_hidden = false)
        ?(is_disabled = false) ?(is_optional = false) ?(is_required = false) ?description
        ?description_id ~label ~input_id ()
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
    Vdom.Node.div
      ~attrs:(Astryx.Common.Attr.class_ [ "astryx-text-input" ])
      [ Vdom.Node.input
          ~attrs:
            (Astryx.Common.Attr.class_ [ "astryx-text-input__input" ]
             @ [ Vdom.Attr.create "id" id; Vdom.Attr.create "type" "text" ])
          ()
      ]
  in
  let field ?label_icon ?label_id ?is_group_label ?is_label_hidden ?is_disabled ?is_optional
        ?is_required ?description ?description_id ~label ~input_id ()
    =
    Astryx.Stack.view
      ~direction:Astryx.Stack.Vertical
      ~gap:S.S2
      [ labelled
          ?label_icon
          ?label_id
          ?is_group_label
          ?is_label_hidden
          ?is_disabled
          ?is_optional
          ?is_required
          ?description
          ?description_id
          ~label
          ~input_id
          ()
      ; control input_id
      ]
  in
  let group_choices =
    Vdom.Node.div
      ~attrs:
        (Astryx.Common.Attr.class_ [ "astryx-text-input" ]
         @ [ Vdom.Attr.create "role" "group"
           ; Vdom.Attr.create "aria-labelledby" "showcase-fl-group-label"
           ])
      [ Vdom.Node.input
          ~attrs:
            [ Vdom.Attr.create "id" "showcase-fl-group-a"
            ; Vdom.Attr.create "type" "checkbox"
            ; Vdom.Attr.create "aria-label" "Include the README"
            ]
          ()
      ; Vdom.Node.input
          ~attrs:
            [ Vdom.Attr.create "id" "showcase-fl-group-b"
            ; Vdom.Attr.create "type" "checkbox"
            ; Vdom.Attr.create "aria-label" "Include the changelog"
            ]
          ()
      ]
  in
  section
    ~id:"fieldlabel"
    ~title:"FieldLabel"
    ~note:
      "The label and description group, on its own. Field renders it above every control, but \
       CheckboxInput and Switch want it beside their control instead — so upstream keeps it as a \
       component of its own, and so does this port, where Field now renders through it. The label \
       is a real <label for> naming the control by id, and the description is a sibling rather \
       than a child: nested, it would fold into the control's accessible name and then be \
       announced twice, once as the name and again through aria-describedby. The last example is \
       the other path — a group label is a <span>, because a <label> names exactly one control and \
       cannot name a set of them, so the group names itself with aria-labelledby. A hidden label \
       is still the control's name; it is put out of sight, not out of the accessibility tree."
    [ ex "a label and description naming a control"
        (field
           ~label:"Workspace name"
           ~input_id:"showcase-fl-named"
           ~description:"Shown in the sidebar."
           ~description_id:"showcase-fl-named-desc"
           ())
    ; ex "required: the marker is part of the name"
        (field ~label:"Billing email" ~input_id:"showcase-fl-required" ~is_required:true ())
    ; ex "optional" (field ~label:"Purchase order" ~input_id:"showcase-fl-optional" ~is_optional:true ())
    ; ex "a label icon"
        (field ~label:"Search scope" ~input_id:"showcase-fl-icon" ~label_icon:"search" ())
    ; ex "a hidden label still names the control"
        (field ~label:"Account reference" ~input_id:"showcase-fl-hidden" ~is_label_hidden:true ())
    ; ex "a disabled label"
        (field ~label:"Frozen field" ~input_id:"showcase-fl-disabled" ~is_disabled:true ())
    ; ex "a group label names a set of controls, not one"
        (Astryx.Stack.view
           ~direction:Astryx.Stack.Vertical
           ~gap:S.S2
           [ labelled
               ~label:"Include in the release"
               ~input_id:"showcase-fl-group-label"
               ~label_id:"showcase-fl-group-label"
               ~is_group_label:true
               ()
           ; group_choices
           ])
    ]
;;

let s_indicator () =
  (* The decorative visuals on their own, with no control attached — these are what CheckboxInput,
     a radio list and a bare check mark draw. Every one of them is aria-hidden, because the
     semantics belong to whatever composes them, so this section is about the marks and the states
     rather than about interaction.

     The two states that are easy to get wrong are here on purpose: a radio draws a circle in
     *both* states, because an empty circle is information (this option exists and is not chosen),
     and a bare check mark draws nothing at all when it is not on, because there is no box for it
     to be empty. *)
  let mark ?(is_disabled = false) ~kind ~state ~size () =
    Astryx.Indicator.view ~kind ~state ~size ~is_disabled ()
  in
  let row nodes =
    Astryx.Stack.view ~direction:Astryx.Stack.Horizontal ~gap:S.S3 nodes
  in
  let cb = Astryx.Indicator.Checkbox in
  let radio = Astryx.Indicator.Radio in
  let check = Astryx.Indicator.Check in
  let unchecked = Astryx.Indicator.Unchecked in
  let checked = Astryx.Indicator.Checked in
  let indeterminate = Astryx.Indicator.Indeterminate in
  let sm = Astryx.Indicator.Sm in
  let md = Astryx.Indicator.Md in
  let note text = Astryx.Text.view ~size:Astryx.Text.Sm [ Vdom.Node.text text ] in
  section
    ~id:"indicator"
    ~title:"Indicator"
    ~note:
      "The selection visuals, ported as one module with three kinds because they are one primitive \
       with a kind — the same reason Stack covers HStack and VStack. Upstream resolves them through \
       a registry keyed by name so a theme can swap one out; the port has no theme system yet, so \
       this is the registry's default entry and a theme seam would sit in front of it. The hover \
       rules are scoped to the owning control (the [astryx-indicator-scope] element here), not to \
       the indicator, which is why hovering the label of a checkbox lights the box."
    [ ex "checkbox, unchecked" (mark ~kind:cb ~state:unchecked ~size:md ())
    ; ex "checkbox, checked" (mark ~kind:cb ~state:checked ~size:md ())
    ; ex "checkbox, indeterminate: a bar, not a tick"
        (mark ~kind:cb ~state:indeterminate ~size:md ())
    ; ex "sm and md — 20px and 24px, and the mark grows with the box"
        (row
           [ mark ~kind:cb ~state:unchecked ~size:sm ()
           ; mark ~kind:cb ~state:checked ~size:sm ()
           ; mark ~kind:cb ~state:unchecked ~size:md ()
           ; mark ~kind:cb ~state:checked ~size:md ()
           ])
    ; ex "disabled — dimmed, and an empty box goes muted as well"
        (row
           [ mark ~kind:cb ~state:unchecked ~size:md ~is_disabled:true ()
           ; mark ~kind:cb ~state:checked ~size:md ~is_disabled:true ()
           ])
    ; ex "hover — the owning control lights the box, not the box itself"
        (Vdom.Node.div
           ~attrs:(Astryx.Common.Attr.class_ [ "astryx-indicator-scope" ])
           [ row [ mark ~kind:cb ~state:unchecked ~size:md (); mark ~kind:cb ~state:checked ~size:md () ] ])
    ; ex "radio, unchecked: an empty circle is the information"
        (mark ~kind:radio ~state:unchecked ~size:md ())
    ; ex "radio, checked" (mark ~kind:radio ~state:checked ~size:md ())
    ; ex "radio, disabled" (mark ~kind:radio ~state:checked ~size:md ~is_disabled:true ())
    ; ex "check, unchecked: nothing renders — a bare mark has no box to be empty"
        (row [ mark ~kind:check ~state:unchecked ~size:md (); note "an absence, not an empty box" ])
    ; ex "check, checked" (mark ~kind:check ~state:checked ~size:md ())
    ; ex "check, disabled" (mark ~kind:check ~state:checked ~size:md ~is_disabled:true ())
    ]
;;

(* ------------------------------------------------- checkbox (state) *)

(* A checkbox is the first control in the port whose whole point is a round trip: the click changes
   the application's value, and the DOM's *property* has to follow it back. So two of these are live,
   and the browser gate drives them.

   The group is the reason the third value exists. A parent whose children disagree is
   indeterminate — that is the only way that state is ever produced, and it is not something styling
   can fake. Clicking the parent sets all three, which is what the browser does natively with a
   half-selected parent, and the parent's value is *derived* from the children rather than stored,
   so its readout cannot drift from the boxes.

   Every example here is a tree, because the control itself is one: [ex] wraps a node, so each
   example's tree is mapped through [ex] and the resulting trees are joined back into the section. *)
let checkbox_demo (graph : Bonsai.graph) =
  let open Astryx in
  let checked_of = function true -> Checkbox_input.Checked | false -> Checkbox_input.Unchecked in
  let bool_of = function
    | Checkbox_input.Checked -> true
    | Checkbox_input.Unchecked | Checkbox_input.Indeterminate -> false
  in
  let as_value t = Bonsai.map t ~f:checked_of in
  let as_change t = Bonsai.map t ~f:(fun set value -> set (bool_of value)) in
  (* Bonsai has no variadic join, so a fixed list of trees is threaded through map2. *)
  let join_all (trees : Vdom.Node.t Bonsai.t list) =
    List.fold trees ~init:(Bonsai.return []) ~f:(fun acc tree ->
      Bonsai.map2 acc tree ~f:(fun acc node -> acc @ [ node ]))
  in
  let note id text = Vdom.Node.div ~attrs:[ Vdom.Attr.create "id" id ] [ Vdom.Node.text text ] in
  let row nodes = Vdom.Node.div ~attrs:(Astryx.Common.Attr.class_ [ "showcase-checkbox-row" ]) nodes in
  let ex_tree label tree = Bonsai.map tree ~f:(fun node -> ex label node) in
  let no_change =
    Bonsai.return (fun (_ : Checkbox_input.value) -> Effect.Many [])
  in
  let state_text prefix value =
    match value with
    | Checkbox_input.Checked -> prefix ^ ": checked"
    | Checkbox_input.Unchecked -> prefix ^ ": unchecked"
    | Checkbox_input.Indeterminate -> prefix ^ ": indeterminate"
  in
  (* --- one live box, whose state is printed beside it --------------------- *)
  let one, set_one = Bonsai.state false graph in
  let live_one =
    let control =
      Checkbox_input.view
        ~label:"Email me about changes"
        ~id:"showcase-checkbox-live"
        ~description:"One message per release, no more."
        ~description_id:"showcase-checkbox-live-desc"
        ~value:(as_value one)
        ~on_change:(as_change set_one)
        ()
    in
    let readout =
      Bonsai.map one ~f:(fun one ->
        note "showcase-checkbox-live-state" (state_text "this box" (checked_of one)))
    in
    Bonsai.map (join_all [ control; readout ]) ~f:(fun nodes -> Vdom.Node.div nodes)
  in
  (* --- a parent and three children --------------------------------------- *)
  let a, set_a = Bonsai.state true graph in
  let b, set_b = Bonsai.state false graph in
  let c, set_c = Bonsai.state true graph in
  let parent_value =
    Bonsai.map2
      (Bonsai.map2 a b ~f:(fun a b -> a, b))
      c
      ~f:(fun (a, b) c ->
      let on = List.count [ a; b; c ] ~f:Fn.id in
      if on = 0 then Checkbox_input.Unchecked
      else if on = 3 then Checkbox_input.Checked
      else Checkbox_input.Indeterminate)
  in
  let parent_change =
    Bonsai.map2
      (Bonsai.map2 set_a set_b ~f:(fun sa sb -> sa, sb))
      set_c
      ~f:(fun (set_a, set_b) set_c value ->
      let on = bool_of value in
      Effect.Many [ set_a on; set_b on; set_c on ])
  in
  let child id label value set =
    Checkbox_input.view
      ~label
      ~id
      ~value:(as_value value)
      ~on_change:(as_change set)
      ()
  in
  let group =
    let parent =
      Checkbox_input.view
        ~label:"Include in the release"
        ~id:"showcase-checkbox-parent"
        ~description:"Some of these are optional."
        ~description_id:"showcase-checkbox-parent-desc"
        ~value:parent_value
        ~on_change:parent_change
        ()
    in
    let children =
      Bonsai.map
        (join_all
           [ child "showcase-checkbox-child-1" "The changelog" a set_a
           ; child "showcase-checkbox-child-2" "The README" b set_b
           ; child "showcase-checkbox-child-3" "The migration notes" c set_c
           ])
        ~f:(fun nodes ->
        Vdom.Node.div
          ~attrs:(Astryx.Common.Attr.class_ [ "showcase-checkbox-children" ])
          nodes)
    in
    let readout =
      Bonsai.map parent_value ~f:(fun value ->
        note "showcase-checkbox-parent-state" (state_text "the parent" value))
    in
    Bonsai.map (join_all [ parent; children; readout ]) ~f:(fun nodes -> Vdom.Node.div nodes)
  in
  let static value =
    Bonsai.return value
  in
  let plain ?is_disabled ?disabled_message ?is_read_only ?is_label_hidden ?is_optional
        ?is_required ~label ~id value
    =
    Checkbox_input.view
      ?is_disabled
      ?disabled_message
      ?is_read_only
      ?is_label_hidden
      ?is_optional
      ?is_required
      ~label
      ~id
      ~value:(static value)
      ~on_change:no_change
      ()
  in
  let examples =
    [ ex_tree "a live checkbox: click it, and the property follows the value" live_one
    ; ex_tree "a parent and its children: indeterminate is what a disagreement looks like" group
    ; ex_tree "indeterminate on its own"
        (plain ~label:"Partially selected" ~id:"showcase-checkbox-mixed"
           Checkbox_input.Indeterminate)
    ; ex_tree "checked and unchecked, the two ordinary states"
        (Bonsai.map
           (join_all
              [ plain ~label:"Selected" ~id:"showcase-checkbox-on" Checkbox_input.Checked
              ; plain ~label:"Not selected" ~id:"showcase-checkbox-off" Checkbox_input.Unchecked
              ])
           ~f:row)
    ; ex_tree "disabled: dimmed, and it does not toggle"
        (plain ~label:"Frozen" ~id:"showcase-checkbox-disabled" ~is_disabled:true
           Checkbox_input.Checked)
    ; ex_tree "read-only: it still takes focus and refuses the click"
        (plain ~label:"Locked but reachable" ~id:"showcase-checkbox-readonly" ~is_read_only:true
           Checkbox_input.Unchecked)
    ; ex_tree "disabled with a reason, and still reachable"
        (plain
           ~label:"Managed by your administrator"
           ~id:"showcase-checkbox-reason"
           ~is_disabled:true
           ~disabled_message:"Your administrator manages this setting."
           Checkbox_input.Checked)
    ; ex_tree "required, and optional"
        (Bonsai.map
           (join_all
              [ plain ~label:"Accept the terms" ~id:"showcase-checkbox-required" ~is_required:true
                  Checkbox_input.Unchecked
              ; plain
                  ~label:"Subscribe to the newsletter"
                  ~id:"showcase-checkbox-optional"
                  ~is_optional:true
                  Checkbox_input.Unchecked
              ])
           ~f:row)
    ; ex_tree "a description, and an error status below the row"
        (Checkbox_input.view
           ~label:"I have read the migration notes"
           ~id:"showcase-checkbox-status"
           ~description:"The notes are short."
           ~description_id:"showcase-checkbox-status-desc"
           ~status:
             { Input_types.type_ = Input_types.Error
             ; message = Some "You have to read them before continuing."
             }
           ~value:(static Checkbox_input.Unchecked)
           ~on_change:no_change
           ())
    ; ex_tree "a hidden label still names the control"
        (plain ~label:"Include diagnostics" ~id:"showcase-checkbox-hidden" ~is_label_hidden:true
           Checkbox_input.Checked)
    ; ex_tree "sm and md"
        (Bonsai.map
           (join_all
              [ Checkbox_input.view
                  ~label:"Small"
                  ~id:"showcase-checkbox-sm"
                  ~size:Indicator.Sm
                  ~value:(static Checkbox_input.Checked)
                  ~on_change:no_change
                  ()
              ; Checkbox_input.view
                  ~label:"Medium"
                  ~id:"showcase-checkbox-md"
                  ~size:Indicator.Md
                  ~value:(static Checkbox_input.Checked)
                  ~on_change:no_change
                  ()
              ])
           ~f:row)
    ]
  in
  Bonsai.map (join_all examples) ~f:(fun examples ->
    section
      ~id:"checkbox"
      ~title:"CheckboxInput"
      ~note:
        "The label sits *beside* the control, which is why upstream composes this out of FieldLabel \
         and FieldStatus rather than out of Field. The first two examples are live: click one, or \
         tab to it and press Space. The group is the only thing that ever produces the indeterminate \
         state — a parent whose children disagree — and clicking it sets all three, the way a \
         browser does with a half-selected parent. Note what the third example does *not* have: an \
         aria-checked=\"mixed\". The native indeterminate property is the authoritative mixed \
         state, and a second source of truth can disagree with it."
      examples)
;;

(* ------------------------------------------------- switch (state) *)

(* The same shape as the checkbox section, and for the same reason: a switch is only correct if the
   click reaches the application and the property follows the value back. The readout is derived
   from the state, so it cannot agree with the box by accident. *)
let switch_demo (graph : Bonsai.graph) =
  let open Astryx in
  let join_all (trees : Vdom.Node.t Bonsai.t list) =
    List.fold trees ~init:(Bonsai.return []) ~f:(fun acc tree ->
      Bonsai.map2 acc tree ~f:(fun acc node -> acc @ [ node ]))
  in
  let row nodes = Vdom.Node.div ~attrs:(Astryx.Common.Attr.class_ [ "showcase-switch-row" ]) nodes in
  let ex_tree label tree = Bonsai.map tree ~f:(fun node -> ex label node) in
  let no_change = Bonsai.return (fun (_ : bool) -> Effect.Many []) in
  let is_on, set_is_on = Bonsai.state false graph in
  let live =
    let control =
      Switch.view
        ~label:"Dark mode"
        ~id:"showcase-switch-live"
        ~description:"Follows the system setting until you touch it."
        ~description_id:"showcase-switch-live-desc"
        ~value:is_on
        ~on_change:(Bonsai.map set_is_on ~f:(fun set value -> set value))
        ()
    in
    let readout =
      Bonsai.map is_on ~f:(fun on ->
        Vdom.Node.div
          ~attrs:[ Vdom.Attr.create "id" "showcase-switch-live-state" ]
          [ Vdom.Node.text ("this switch: " ^ if on then "on" else "off") ])
    in
    Bonsai.map (join_all [ control; readout ]) ~f:(fun nodes -> Vdom.Node.div nodes)
  in
  let plain ?is_disabled ?disabled_message ?is_label_hidden ?is_optional ?is_required ?size ~label
        ~id value
    =
    Switch.view
      ?is_disabled
      ?disabled_message
      ?is_label_hidden
      ?is_optional
      ?is_required
      ?size
      ~label
      ~id
      ~value:(Bonsai.return value)
      ~on_change:no_change
      ()
  in
  let examples =
    [ ex_tree "a live switch: click it, and the property follows the value" live
    ; ex_tree "on and off"
        (Bonsai.map
           (join_all
              [ plain ~label:"On" ~id:"showcase-switch-on" true
              ; plain ~label:"Off" ~id:"showcase-switch-off" false
              ])
           ~f:row)
    ; ex_tree "clicking the label works too" (plain ~label:"Notifications" ~id:"showcase-switch-label" false)
    ; ex_tree "disabled"
        (Bonsai.map
           (join_all
              [ plain ~label:"Frozen on" ~id:"showcase-switch-disabled-on" ~is_disabled:true true
              ; plain ~label:"Frozen off" ~id:"showcase-switch-disabled-off" ~is_disabled:true false
              ])
           ~f:row)
    ; ex_tree "disabled with a reason, and still reachable"
        (Bonsai.map
           (join_all
              [ plain
                  ~label:"Two-factor"
                  ~id:"showcase-switch-reason"
                  ~is_disabled:true
                  ~disabled_message:"Two-factor is enforced by your organisation."
                  true
              ; plain
                  ~label:"Beta channel"
                  ~id:"showcase-switch-reason-2"
                  ~is_disabled:true
                  ~disabled_message:"Ask an admin to turn this on."
                  false
              ])
           ~f:row)
    ; ex_tree "sm and md"
        (Bonsai.map
           (join_all
              [ plain ~label:"Small" ~id:"showcase-switch-sm" ~size:Indicator.Sm true
              ; plain ~label:"Medium" ~id:"showcase-switch-md" ~size:Indicator.Md true
              ])
           ~f:row)
    ; ex_tree "required, and optional"
        (Bonsai.map
           (join_all
              [ plain ~label:"Use the beta channel" ~id:"showcase-switch-required" ~is_required:true false
              ; plain ~label:"Share anonymous usage" ~id:"showcase-switch-optional" ~is_optional:true false
              ])
           ~f:row)
    ; ex_tree "a description, and an error status below the row"
        (Switch.view
           ~label:"Two-factor authentication"
           ~id:"showcase-switch-status"
           ~description:"Required for administrators."
           ~description_id:"showcase-switch-status-desc"
           ~status:
             { Input_types.type_ = Input_types.Error
             ; message = Some "Administrators cannot turn this off."
             }
           ~value:(Bonsai.return true)
           ~on_change:no_change
           ())
    ; ex_tree "a hidden label still names the control"
        (plain ~label:"Telemetry" ~id:"showcase-switch-hidden" ~is_label_hidden:true true)
    ]
  in
  Bonsai.map (join_all examples) ~f:(fun examples ->
    section
      ~id:"switch"
      ~title:"Switch"
      ~note:
        "The control is a native checkbox with role=\"switch\", which is what makes a screen \
         reader announce \"switch, on\" rather than \"checkbox, checked\"; the track is \
         aria-hidden paint over it, and the thumb grows when it is on. Note what it does *not* have: \
         an aria-checked. The input's own checkedness is the state, and a second declaration can \
         disagree with it — the same judgment as the checkbox's missing aria-checked=\"mixed\". \
         The first example is live, and the readout is derived from the same state the control gets, \
         so it cannot agree by accident."
      examples)
;;

(* ------------------------------------------------- radio list (state) *)

(* The group is the first consumer of Indicator's radio kind — which has been ported and unrendered
   since M12, the same position Indicator itself was in before CheckboxInput. The keyboard is the
   interesting part and it is not this code's doing: radios sharing a name are one tab stop, the
   arrows move between them *and* select, and the browser restores the last selection. The browser
   gate presses those keys rather than believing the comment. *)
let radio_list_demo (graph : Bonsai.graph) =
  let open Astryx in
  let join_all (trees : Vdom.Node.t Bonsai.t list) =
    List.fold trees ~init:(Bonsai.return []) ~f:(fun acc tree ->
      Bonsai.map2 acc tree ~f:(fun acc node -> acc @ [ node ]))
  in
  let row nodes = Vdom.Node.div ~attrs:(Astryx.Common.Attr.class_ [ "showcase-radio-row" ]) nodes in
  let ex_tree label tree = Bonsai.map tree ~f:(fun node -> ex label node) in
  let no_change = Bonsai.return (fun (_ : string) -> Effect.Many []) in
  let item ?(description = None) ?(is_disabled = false) value label =
    { Radio_list.value; label; description; is_disabled }
  in
  let shipping =
    [ item "standard" "Standard"; item "express" "Express"; item "pickup" "Pick up in store" ]
  in
  let selected, set_selected = Bonsai.state "express" graph in
  let live =
    let group =
      Radio_list.view
        ~label:"Shipping"
        ~id:"showcase-radio-list-live"
        ~description:"Express is the default for this account."
        ~items:shipping
        ~value:selected
        ~on_change:(Bonsai.map set_selected ~f:(fun set value -> set value))
        ()
    in
    let readout =
      Bonsai.map selected ~f:(fun value ->
        Vdom.Node.div
          ~attrs:[ Vdom.Attr.create "id" "showcase-radio-list-state" ]
          [ Vdom.Node.text ("chosen: " ^ value) ])
    in
    Bonsai.map (join_all [ group; readout ]) ~f:(fun nodes -> Vdom.Node.div nodes)
  in
  let plain ?(is_disabled = false) ?(is_label_hidden = false) ?(is_optional = false)
        ?(is_required = false) ?(orientation = Radio_list.Vertical) ?(size = Indicator.Md)
        ?(value = "") ?status ~label ~id items =
    Radio_list.view
      ~label
      ~id
      ~items
      ~is_disabled
      ~is_label_hidden
      ~is_optional
      ~is_required
      ~orientation
      ~size
      ?status
      ~value:(Bonsai.return value)
      ~on_change:no_change
      ()
  in
  let described =
    [ item ~description:(Some "Arrives in 3–5 days.") "standard" "Standard"
    ; item ~description:(Some "Arrives tomorrow, costs more.") "express" "Express"
    ]
  in
  let with_disabled =
    [ item "monthly" "Monthly"
    ; item ~description:(Some "Not on your plan.") ~is_disabled:true "annual" "Annual"
    ]
  in
  let sizes =
    [ Radio_list.
        { value = "a"; label = "Small"; description = None; is_disabled = false }
    ; { value = "b"; label = "Medium"; description = None; is_disabled = false }
    ]
  in
  let examples =
    [ ex_tree "a live group: the choice prints beside it" live
    ; ex_tree "horizontal" (plain ~orientation:Radio_list.Horizontal ~label:"Alignment" ~id:"showcase-radio-horizontal" [ item "start" "Start"; item "center" "Centre"; item "pin" "End" ])
    ; ex_tree "an item with its own description"
        (plain ~label:"Delivery" ~id:"showcase-radio-described" described)
    ; ex_tree "one item disabled, the others not"
        (plain ~value:"monthly" ~label:"Billing period" ~id:"showcase-radio-disabled-item" with_disabled)
    ; ex_tree "the whole group disabled"
        (plain ~is_disabled:true ~label:"Plan" ~id:"showcase-radio-disabled-group" [ item "free" "Free"; item "pro" "Pro" ])
    ; ex_tree "required, and optional"
        (Bonsai.map
           (join_all
              [ plain ~is_required:true ~label:"Contact method" ~id:"showcase-radio-required"
                  [ item "email" "Email"; item "phone" "Phone" ]
              ; plain ~is_optional:true ~label:"Preferred language"
                  ~id:"showcase-radio-optional" [ item "en" "English"; item "fr" "French" ]
              ])
           ~f:row)
    ; ex_tree "an error status below the group"
        (plain ~label:"Warranty"
           ~id:"showcase-radio-status"
           ~status:{ Input_types.type_ = Input_types.Error; message = Some "Pick one to continue." }
           [ item "one" "One year"; item "three" "Three years" ])
    ; ex_tree "a hidden label still names the group"
        (plain ~is_label_hidden:true ~label:"Theme" ~id:"showcase-radio-hidden" [ item "light" "Light"; item "dark" "Dark" ])
    ; ex_tree "sm and md"
        (Bonsai.map
           (join_all
              [ plain ~size:Indicator.Sm ~label:"Small" ~id:"showcase-radio-sm" sizes
              ; plain ~size:Indicator.Md ~label:"Medium" ~id:"showcase-radio-md" sizes
              ])
           ~f:row)
    ]
  in
  Bonsai.map (join_all examples) ~f:(fun examples ->
    section
      ~id:"radiogroup"
      ~title:"RadioList"
      ~note:
        "One choice out of several. Upstream composes Field here rather than FieldLabel — a radio \
         group *is* a form field, so the label is a group label (a span the group names itself from \
         with aria-labelledby) and the status sits below the whole set. The keyboard needs no code: \
         radios sharing a name are one tab stop, the arrows move between them and select, and the \
         browser restores the last selection, which is exactly what the browser gate presses keys to \
         check. The one deliberate difference from upstream is written in the interface: upstream's \
         item label is a plain span (its event delegation would make a real <label for> fire twice), \
         and the port's is a real <label for> — which names the radio the same way and is also \
         clickable."
      examples)
;;

(* ------------------------------------------------- form layout (state) *)

(* Upstream's FormLayout does two jobs: it arranges fields, and it supplies the form's
   [defaultOptionality] through React context. The port keeps the first and makes the second an
   argument on each field, because a context would have to be active while the child tree is built
   and these children are built before the container sees them. What the examples below are for is
   the *rule*, which is upstream's exactly: only the exception is marked. *)
let form_layout_demo (_ : Bonsai.graph) =
  let open Astryx in
  let join_all (trees : Vdom.Node.t Bonsai.t list) =
    List.fold trees ~init:(Bonsai.return []) ~f:(fun acc tree ->
      Bonsai.map2 acc tree ~f:(fun acc node -> acc @ [ node ]))
  in
  let ex_tree label tree = Bonsai.map tree ~f:(fun node -> ex label node) in
  let no_change = Bonsai.return (fun (_ : string) -> Effect.Many []) in
  let field ?(is_optional = false) ?(is_required = false) ?optionality label id =
    Astryx.TextInput.view
      ~label
      ~id
      ~is_optional
      ~is_required
      ?optionality
      ~value:(Bonsai.return "")
      ~on_change:no_change
      ()
  in
  (* The fields are trees — a control returns a [Bonsai.t] — so the layout is a tree over them. *)
  let layout ?(direction = Form_layout.Vertical) fields =
    Bonsai.map (join_all fields) ~f:(fun children -> Form_layout.view ~direction ~children ())
  in
  let opt = Form_layout.Optional in
  let req = Form_layout.Required in
  let examples =
    [ ex_tree "vertical, the default"
        (layout [ field "Full name" "showcase-fl-v-name"; field "Email" "showcase-fl-v-email" ])
    ; ex_tree "horizontal: equal columns"
        (layout
           ~direction:Form_layout.Horizontal
           [ field "Street" "showcase-fl-h-street"
           ; field "City" "showcase-fl-h-city"
           ; field "Postcode" "showcase-fl-h-post"
           ])
    ; ex_tree "labels to the left, collapsing on a narrow container"
        (layout
           ~direction:Form_layout.Horizontal_labels
           [ field "Account" "showcase-fl-l-account"; field "Region" "showcase-fl-l-region" ])
    ; ex_tree "optionality = Optional: only the required field is marked"
        (layout
           [ field ~optionality:opt ~is_required:true "Email (you will be emailed)"
               "showcase-fl-opt-email"
           ; field ~optionality:opt "Nickname" "showcase-fl-opt-nick"
           ])
    ; ex_tree "optionality = Required: only the optional field is marked"
        (layout
           [ field ~optionality:req "Email" "showcase-fl-req-email"
           ; field ~optionality:req ~is_optional:true "Nickname (if you have one)"
               "showcase-fl-req-nick"
           ])
    ; ex_tree "unset: each field marks itself, as it did before FormLayout existed"
        (layout
           [ field ~is_required:true "Email" "showcase-fl-both-email"
           ; field ~is_optional:true "Nickname" "showcase-fl-both-nick"
           ])
    ; ex_tree "a horizontal row nested inside a vertical form"
        (layout
           [ field "Company" "showcase-fl-nest-company"
           ; layout
               ~direction:Form_layout.Horizontal
               [ field "City" "showcase-fl-nest-city"; field "Postcode" "showcase-fl-nest-post" ]
           ])
    ]
  in
  Bonsai.map (join_all examples) ~f:(fun examples ->
    section
      ~id:"form-layout"
      ~title:"FormLayout"
      ~note:
        "Arranges fields — vertical, equal columns, or labels to the left — and owns the rule that \
         decides whether a field is marked at all. Upstream supplies that rule through React \
         context; here it is an argument on each field, the same decision RadioList made about its \
         items and for the same reason: a context has to be live while the child tree is built, and \
         children arrive already built. The rule is upstream's exactly — only the exception is \
         marked, so under Optional just the required field reads Required and under Required just \
         the optional one reads Optional. The other half of that rule is the part that is easy to \
         lose: a layout default moves aria-required but never the native required attribute, so \
         choosing a default cannot switch on the browser's own validation. The port asserts both \
         halves."
      examples)
;;

(* ------------------------------------------------- tooltip (state) *)

(* The tooltip owns its open/close state, so it takes the graph — the same shape DropdownMenu uses.
   Two claims in here are the ones worth pressing rather than reading: that the message element is
   absent from the DOM while closed (so it cannot be found by a selector or a screen reader), and
   that aria-describedby appears on the anchor only while it is open, which is what upstream does
   when its layer opens and restores on close. *)
let tooltip_demo (graph : Bonsai.graph) =
  let open Astryx in
  let join_all (trees : Vdom.Node.t Bonsai.t list) =
    List.fold trees ~init:(Bonsai.return []) ~f:(fun acc tree ->
      Bonsai.map2 acc tree ~f:(fun acc node -> acc @ [ node ]))
  in
  let ex_tree label tree = Bonsai.map tree ~f:(fun node -> ex label node) in
  let row nodes = Vdom.Node.div ~attrs:(Astryx.Common.Attr.class_ [ "showcase-radio-row" ]) nodes in
  let tip ?(placement = Tooltip.Above) ?(alignment = Tooltip.Center) ?is_open ~id ~content
        trigger
    =
    Tooltip.view
      ~placement
      ~alignment
      ?is_open
      ~id:(id ^ "-message")
      ~content
      ~trigger
      graph
  in
  (* Button takes children rather than attrs, so the trigger's id rides on a wrapper — which is also
     the element the tooltip anchors to, so the gate can hover it either way. *)
  let button id label =
    Vdom.Node.span
      ~attrs:[ Vdom.Attr.create "id" id ]
      [ Button.view ~variant:Button.Secondary ~label [] ]
  in
  (* A control that is disabled but still focusable: this is the pattern upstream's disabledMessage
     exists for. A natively disabled button receives no pointer events at all, so it can neither show
     a tooltip nor tell anyone why it is unavailable; arming it with aria-disabled keeps it reachable
     while telling assistive technology the same thing. *)
  let focusable_disabled id label =
    Vdom.Node.button
      ~attrs:
        ([ Vdom.Attr.create "id" id
         ; Vdom.Attr.create "type" "button"
         ; Vdom.Attr.create "aria-disabled" "true"
         ]
         @ Astryx.Common.Attr.class_ [ "astryx-button"; "astryx-button--secondary"; "astryx-button--md" ])
      [ Vdom.Node.text label ]
  in
  let examples =
    [ ex_tree "above the trigger — the default"
        (tip
           ~id:"showcase-tip-above"
           ~content:"Above, and centred on the trigger."
           (button "showcase-tip-above-trigger" "Hover or focus me"))
    ; ex_tree "below"
        (tip
           ~placement:Tooltip.Below
           ~id:"showcase-tip-below"
           ~content:"Below the trigger."
           (button "showcase-tip-below-trigger" "Hover or focus me"))
    ; ex_tree "start and end"
        (Bonsai.map2
           (tip
              ~placement:Tooltip.Start
              ~id:"showcase-tip-start"
              ~content:"Beside the trigger, on the start side."
              (button "showcase-tip-start-trigger" "Start"))
           (tip
              ~placement:Tooltip.End
              ~id:"showcase-tip-end"
              ~content:"Beside the trigger, on the end side."
              (button "showcase-tip-end-trigger" "End"))
           ~f:(fun start end_ -> row [ start; end_ ]))
    ; ex_tree "aligned to the start and end of the anchor"
        (Bonsai.map2
           (tip
              ~alignment:Tooltip.Start
              ~id:"showcase-tip-align-start"
              ~content:"Aligned to the anchor's start edge."
              (button "showcase-tip-align-start-trigger" "Align start"))
           (tip
              ~alignment:Tooltip.End
              ~id:"showcase-tip-align-end"
              ~content:"Aligned to the anchor's end edge."
              (button "showcase-tip-align-end-trigger" "Align end"))
           ~f:(fun start end_ -> row [ start; end_ ]))
    ; ex_tree "open because the caller says so"
        (tip
           ~is_open:true
           ~id:"showcase-tip-controlled"
           ~content:"is_open replaces the hover and focus state entirely, so this one is open for a reason of the caller's own."
           (button "showcase-tip-controlled-trigger" "No interaction needed"))
    ; ex_tree "a disabled control that stays focusable"
        (tip
           ~is_open:true
           ~id:"showcase-tip-disabled"
           ~content:"Export is not on your plan."
           (focusable_disabled "showcase-tip-disabled-trigger" "Export"))
    ]
  in
  Bonsai.map (join_all examples) ~f:(fun examples ->
    section
      ~id:"tooltip"
      ~title:"Tooltip"
      ~note:
        "A short message attached to a trigger, open while the trigger is hovered or focused and \\
         gone the moment it is not — the message element is not in the DOM at all while closed, \\
         which is what makes the last two examples worth having: the second-last is open because its \\
         caller said so, and the last is the pattern a disabled control needs, a control that looks \\
         disabled and still takes focus, because a natively disabled button receives no pointer \\
         events and so can never explain itself. Two divergences are named in the interface rather \\
         than hidden here: the message is positioned in place instead of through a portal, so an \\
         ancestor with overflow hidden clips it, and the hover delay is not ported — opening after a \\
         pause needs a timer that can write back into the component's state, which this release has \\
         no primitive for."
      examples)
;;

(* ------------------------------------------------- dialog (state, and the platform) *)

(* The only component so far whose behaviour is the browser's: a <dialog> opened with showModal() is
   in the top layer, the page behind it is inert, focus is trapped and ::backdrop is drawn, none of
   which is written anywhere in the port. What IS ours is the dismissal matrix, and that is what the
   live examples below exist to press: Escape and a backdrop click are two separate permissions, and
   "required" refuses both. *)
let dialog_demo (graph : Bonsai.graph) =
  let open Astryx in
  let join_all (trees : Vdom.Node.t Bonsai.t list) =
    List.fold trees ~init:(Bonsai.return []) ~f:(fun acc tree ->
      Bonsai.map2 acc tree ~f:(fun acc node -> acc @ [ node ]))
  in
  let ex_tree label tree = Bonsai.map tree ~f:(fun node -> ex label node) in
  let body text =
    Vdom.Node.div
      ~attrs:(Astryx.Common.Attr.class_ [ "showcase-dialog-body" ])
      [ Vdom.Node.text text ]
  in
  let title id text =
    Vdom.Node.div
      ~attrs:[ Vdom.Attr.create "id" id; Vdom.Attr.create "class" "showcase-dialog-title" ]
      [ Vdom.Node.text text ]
  in
  let inline ?purpose ?variant ?width ?max_height ?position ?padding label text =
    ex_tree
      label
      (Dialog.view
         ~is_inline:true
         ?purpose
         ?variant
         ?width
         ?max_height
         ?position
         ?padding
         ~labelled_by:"showcase-dialog-inline-title"
         ~is_open:(Bonsai.return true)
         ~on_open_change:(Bonsai.return (fun (_ : bool) -> Effect.Many []))
         ~id:("showcase-dialog-inline-" ^ label)
         ~children:(Bonsai.return [ title "showcase-dialog-inline-title" "Dialog"; body text ])
         ())
  in
  (* One live dialog per purpose, each with a readout the application owns. The gate reads the readout
     to learn whether the component *reported* a dismissal — a different question from whether the
     element closed, and the one a controlled component has to get right.

     Both arguments are trees taken straight from the state: the component returns a tree itself, so
     wrapping it in a map2 would nest one tree inside another. The close button inside needs no
     callback at all — a <form method="dialog"> submit button closes the dialog itself, and the
     component reports it through on_open_change. That is the platform doing the work, and it is why
     the children stay plain nodes. *)
  let live purpose name =
    let is_open, set_is_open = Bonsai.state false graph in
    let open_button =
      Bonsai.map set_is_open ~f:(fun set_is_open ->
        Button.view
          ~variant:Button.Secondary
          ~label:("Open (" ^ name ^ ")")
          ~attrs:[ Vdom.Attr.create "id" ("showcase-dialog-open-" ^ name) ]
          ~on_click:(fun _ -> set_is_open true)
          [])
    in
    let readout =
      Bonsai.map is_open ~f:(fun is_open ->
        Vdom.Node.div
          ~attrs:[ Vdom.Attr.create "id" ("showcase-dialog-state-" ^ name) ]
          [ Vdom.Node.text
              (if is_open then "the application says: open" else "the application says: closed")
          ])
    in
    let close_form =
      Vdom.Node.create
        "form"
        ~attrs:[ Vdom.Attr.create "method" "dialog" ]
        [ Button.view
            ~variant:Button.Primary
            ~label:"Close"
            (* type=submit is what makes the platform's own <form method="dialog"> close the dialog.
               The port's Button defaults to type=button — which is the right default, and was also
               why the first version of this example did nothing at all when clicked. *)
            ~type_:Button.Submit
            ~attrs:[ Vdom.Attr.create "id" ("showcase-dialog-close-" ^ name) ]
            []
        ]
    in
    let dialog =
      Dialog.view
        ~purpose
        ~labelled_by:("showcase-dialog-title-" ^ name)
        ~is_open
        ~on_open_change:(Bonsai.map set_is_open ~f:(fun set_is_open value -> set_is_open value))
        ~id:("showcase-dialog-" ^ name)
        ~children:
          (Bonsai.return
             [ title ("showcase-dialog-title-" ^ name) ("A " ^ name ^ " dialog")
             ; body "Escape and a backdrop click are separate permissions."
             ; close_form
             ])
        ()
    in
    ex_tree
      ("a live dialog, purpose = " ^ name)
      (Bonsai.map2
         (Bonsai.map2 open_button readout ~f:(fun a b -> a, b))
         dialog
         ~f:(fun (open_button, readout) dialog -> Vdom.Node.div [ open_button; dialog; readout ]))
  in
  let examples =
    [ inline "structure, rendered inline" "The showcase path: ordinary markup, no top layer."
    ; inline
        "purpose = required, which is what makes it an alert dialog"
        "role=alertdialog, and neither exit works."
        ~purpose:Dialog.Required
    ; inline
        "sized and placed"
        "width, max-height and a position are inline styles."
        ~width:"28rem"
        ~max_height:"50vh"
        ~position:{ Dialog.top = Some "4rem"; bottom = None; start = Some "2rem"; end_ = None }
        ~padding:Common.Spacing.S5
    ; inline
        "variant = fullscreen"
        "Ignores width, max-height and position; it is the viewport."
        ~variant:Dialog.Fullscreen
    ; live Dialog.Info "info"
    ; live Dialog.Form "form"
    ; live Dialog.Required "required"
    ]
  in
  Bonsai.map (join_all examples) ~f:(fun examples ->
    section
      ~id:"dialog"
      ~title:"Dialog"
      ~note:
        "A modal surface built on the platform's own <dialog>, opened with showModal() — so the top \\
         layer, the inert page behind it, the focus trap and the ::backdrop come from the browser and \\
         are not written here at all. What is ours is the dismissal matrix, and the three live \\
         dialogs below are how it is pressed rather than read: purpose = info closes on Escape and on \\
         a backdrop click, purpose = form closes on Escape but NOT on a backdrop click (a half-filled \\
         form should not be lost to a stray click), and purpose = required refuses both and carries \\
         role = alertdialog, because a dialog that refuses every exit is one the user has to answer. \\
         Two divergences are named in the interface rather than hidden: upstream's Layer gives it a \\
         depth stack, a page scroll lock and a directional open animation, none of which is ported \\
         (what is ported is the focus restoration, because that is behaviour rather than flourish), \\
         and the title association is an argument here where upstream wires it from context, because \\
         a child in this port is already built by the time the container sees it."
      examples)
;;

(* ------------------------------------------------- alert dialog (a dialog with an answer) *)

(* Upstream builds this on Dialog with purpose="form" and then overrides the role, which is why
   Dialog.view takes ~role. Two things are worth pressing here rather than reading: that the inline path
   really does say "group" (an alertdialog role would promise an interruption and a focus trap a
   non-modal preview does not have), and that the title and the description are *associated* rather than
   merely rendered — a description only a sighted user gets is one assistive technology never reads. *)
let alert_dialog_demo (graph : Bonsai.graph) =
  let open Astryx in
  let join_all (trees : Vdom.Node.t Bonsai.t list) =
    List.fold trees ~init:(Bonsai.return []) ~f:(fun acc tree ->
      Bonsai.map2 acc tree ~f:(fun acc node -> acc @ [ node ]))
  in
  let ex_tree label tree = Bonsai.map tree ~f:(fun node -> ex label node) in
  let inline ?(loading = false) () =
    ex_tree
      ("an inline alert dialog" ^ if loading then ", action in flight" else "")
      (Alert_dialog.view
         ~title:"Delete this page?"
         ~description:"The page and its history are removed for everyone. This cannot be undone."
         ~action_label:"Delete"
         ~cancel_label:"Keep it"
         ~action_variant:Button.Destructive
         ~is_action_loading:loading
         ~is_inline:true
         ~is_open:(Bonsai.return true)
         ~on_action:(Bonsai.return (Effect.Many []))
         ~on_open_change:(Bonsai.return (fun (_ : bool) -> Effect.Many []))
         ~id:"showcase-alert-dialog-inline"
         ())
  in
  (* One live alert dialog, and the action is the application's to take — which is why on_action is a
     tree rather than a callback the component calls for you. The answer both counts and closes, because
     closing after an action is the *caller's* decision here, exactly as upstream leaves it. *)
  let live =
    let is_open, set_is_open = Bonsai.state false graph in
    let actions_taken, set_actions_taken = Bonsai.state 0 graph in
    let open_button =
      Bonsai.map set_is_open ~f:(fun set_is_open ->
        Button.view
          ~variant:Button.Secondary
          ~label:"Open alert dialog"
          ~attrs:[ Vdom.Attr.create "id" "showcase-alert-dialog-open" ]
          ~on_click:(fun _ -> set_is_open true)
          [])
    in
    let readout =
      Bonsai.map2 is_open actions_taken ~f:(fun is_open actions ->
        Vdom.Node.div
          ~attrs:[ Vdom.Attr.create "id" "showcase-alert-dialog-state" ]
          [ Vdom.Node.text
              (Printf.sprintf "%s; answers taken: %d"
                 (if is_open then "the application says: open" else "the application says: closed")
                 actions)
          ])
    in
    let dialog =
      Alert_dialog.view
        ~title:"Discard your changes?"
        ~description:"Your edits since the last save are lost."
        ~action_label:"Discard"
        ~cancel_label:"Keep editing"
        ~action_variant:Button.Destructive
        ~is_open
        (* The action is a tree, and it has to be: a caller holding two state setters has no way to
           hand a plain function in. It counts the answer and then closes, because closing after an
           action is the caller's decision here — upstream leaves it to the consumer too. *)
        ~on_action:
          (Bonsai.map2
             (Bonsai.map2 actions_taken set_actions_taken ~f:(fun taken set_taken -> set_taken (taken + 1)))
             set_is_open
             ~f:(fun count_up set_is_open -> Effect.Many [ count_up; set_is_open false ]))
        ~on_open_change:(Bonsai.map set_is_open ~f:(fun set_is_open value -> set_is_open value))
        ~id:"showcase-alert-dialog-live"
        ()
    in
    ex_tree
      "a live alert dialog: the answer is the application's"
      (Bonsai.map2 (Bonsai.map2 open_button readout ~f:(fun a b -> a, b)) dialog
         ~f:(fun (open_button, readout) dialog ->
         Vdom.Node.div [ open_button; dialog; readout ]))
  in
  let examples = [ inline (); inline ~loading:true (); live ] in
  Bonsai.map (join_all examples) ~f:(fun examples ->
    section
      ~id:"alert-dialog"
      ~title:"AlertDialog"
      ~note:
        "A confirmation dialog: a Dialog with a purpose, a subject and two answers. Upstream builds it \
         on Dialog with purpose = form and then overrides the role, and the override is the interesting \
         part — the modal form carries role = alertdialog, but the same component is also used as a \
         non-modal inline preview, and an alertdialog role there would promise an interruption, a focus \
         trap and an inert page behind it that the preview does not have, so the preview says group. \
         The port follows the code rather than the prose in one place worth naming: upstream's docs say \
         an alert dialog requires an explicit action to dismiss, and it passes purpose = form, which \
         allows Escape. The port keeps Escape, because that is what the shipped component does — the \
         prose and the code disagree, and a port that split the difference would match neither. The \
         title and the description are strings here, so the component owns both elements and both ids \
         and wires aria-labelledby and aria-describedby itself: a description that is drawn but not \
         described is one assistive technology never reads. The two buttons are one CSS rule rather \
         than a media query in JavaScript — column-reverse below 640px puts the destructive answer \
         first under the thumb, which is the order upstream chooses on a small screen, with no \
         re-render on resize. Not ported, with the reason in alert_dialog.mli: \
         useImperativeAlertDialog, which needs a handle concept the port does not have."
      examples)
;;

(* ------------------------------------------------- dialog header (naming the dialog) *)

(* The header is the piece that gives a dialog its name, and the association is the whole point: the
   heading carries an id, and the dialog is told to name itself from that same id. The caller makes that
   link because the caller can see both — which is the recurring shape of this port's context-free
   design.

   The close button is the other half, and it is conditional on purpose: a header with no callback to
   report to renders no button at all, rather than a control that does nothing. Both states are on the
   page, and the gate asserts the absence as carefully as the presence. *)
let dialog_header_demo (graph : Bonsai.graph) =
  let open Astryx in
  let join_all (trees : Vdom.Node.t Bonsai.t list) =
    List.fold trees ~init:(Bonsai.return []) ~f:(fun acc tree ->
      Bonsai.map2 acc tree ~f:(fun acc node -> acc @ [ node ]))
  in
  let ex_tree label tree = Bonsai.map tree ~f:(fun node -> ex label node) in
  let body text =
    Vdom.Node.div
      ~attrs:(Astryx.Common.Attr.class_ [ "showcase-dialog-body" ])
      [ Vdom.Node.text text ]
  in
  let header ?on_open_change ?subtitle ?start_content ?end_content ?edge ?(divider = false) id =
    Dialog_header.view
      ~title_id:(id ^ "-title")
      ~title:(Vdom.Node.text "Delete this project?")
      ?subtitle
      ?on_open_change
      ?start_content
      ?end_content
      ?end_content_edge_compensation:edge
      ~has_divider:divider
      ~attrs:[ Vdom.Attr.create "id" id ]
      ()
  in
  let inline ~id ?on_open_change ?subtitle ?start_content ?end_content ?edge ?divider label =
    ex_tree
      label
      (header ?on_open_change ?subtitle ?start_content ?end_content ?edge ?divider id)
  in
  let live =
    let is_open, set_is_open = Bonsai.state false graph in
    let title_id = "showcase-dialog-header-live-title" in
    let open_button =
      Bonsai.map set_is_open ~f:(fun set_is_open ->
        Button.view
          ~variant:Button.Secondary
          ~label:"Open (with a header)"
          ~attrs:[ Vdom.Attr.create "id" "showcase-dialog-header-open" ]
          ~on_click:(fun _ -> set_is_open true)
          [])
    in
    let readout =
      Bonsai.map is_open ~f:(fun is_open ->
        Vdom.Node.div
          ~attrs:[ Vdom.Attr.create "id" "showcase-dialog-header-state" ]
          [ Vdom.Node.text
              (if is_open then "the application says: open" else "the application says: closed")
          ])
    in
    (* The header reports through the same callback the dialog does, and the dialog is told to name
       itself from the heading's id — the two halves of the association, made by the caller. *)
    let header =
      header
        ~on_open_change:(Bonsai.map set_is_open ~f:(fun set_is_open value -> set_is_open value))
        ~subtitle:(Vdom.Node.text "This cannot be undone.")
        ~divider:true
        "showcase-dialog-header-live"
    in
    let dialog =
      Dialog.view
        ~labelled_by:title_id
        ~is_open
        ~on_open_change:(Bonsai.map set_is_open ~f:(fun set_is_open value -> set_is_open value))
        ~id:"showcase-dialog-header-live"
        ~children:(Bonsai.map header ~f:(fun header -> [ header; body "Body content." ]))
        ()
    in
    ex_tree
      "a live dialog named by its header, and closed by it"
      (Bonsai.map2
         (Bonsai.map2 open_button readout ~f:(fun a b -> a, b))
         dialog
         ~f:(fun (open_button, readout) dialog -> Vdom.Node.div [ open_button; dialog; readout ]))
  in
  let examples =
    [ inline
        ~id:"showcase-dialog-header-no-close"
        "no callback, so no close button"
        ~subtitle:(Vdom.Node.text "No button is drawn at all.")
    ; inline
        ~id:"showcase-dialog-header-with-slots"
        "with a callback, so the button exists"
        ~subtitle:(Vdom.Node.text "And the subtitle sits under the title.")
        ~start_content:(Icon.view ~name:"chevron-left" ())
        ~end_content:(Badge.view "Draft")
        ~edge:Dialog_header.All
        ~divider:true
    ; live
    ]
  in
  Bonsai.map (join_all examples) ~f:(fun examples ->
    section
      ~id:"dialog-header"
      ~title:"DialogHeader"
      ~note:
        "What names a dialog, and what closes it. Upstream wires the title to its parent Dialog through \
         context; here the heading carries an id and the caller passes that same string to the dialog's \
         ~labelled_by, because the caller is the only thing that can see both — the same reason \
         AlertDialog owns its own body outright. The close button is present exactly when there is an \
         ~on_open_change to report to, which is upstream's rule: a control that cannot tell anyone it \
         was pressed is a control that does nothing, so the first example renders no button and the \
         gate asserts that absence as carefully as it asserts the button in the second. The heading is \
         a real h2 with tabindex=-1: focusable programmatically without joining the tab order. It also \
         marks itself as what the dialog should focus on open, and Dialog's hook does the focusing — \
         because the platform's own focus delegate skips a tabindex=-1 element and would land on the \
         close button, where a screen reader would announce Close rather than the dialog's name. The \
         hook is the right owner for the same reason the id is an argument: the header cannot know the \
         dialog opened, since upstream learns that from context, and Dialog is the only thing that \
         does."
      examples)
;;

(* ---------------------------------------------------------------- Kbd *)

(* ------------------------------------------------------------------------------- ButtonGroup *)
(* ---------------------------------------------------------------------------------------- Timer *)
let s_timer () =
  (* Fixed past start times, so the readings below are deterministic instead of "about two minutes" -
     the same choice the Tooltip's delay check makes. Offsets are deliberately away from a boundary. *)
  (* Read through JS, not Core: under js_of_ocaml this is a 32-bit target and
     Time_ns.to_int_ns_since_epoch refuses there outright - which took the whole showcase page down and
     was caught by the browser gate's "the app mounted" check. The component reads its own clock the same
     way, for the same reason. *)
  let now_ms : float = Js_of_ocaml.Js.Unsafe.eval_string "Date.now()" in
  let timer ?start_time ?(format = Astryx.Timer.Elapsed) ~id () =
    Astryx.Timer.view ?start_time ~format ~attrs:[ Vdom.Attr.create "id" id ] ()
  in
  section
    ~id:"timer"
    ~title:"Timer"
    ~note:
      "An elapsed duration that stays readable - and machine-readable - without re-rendering. What is \
       rendered is a real <time> element: the human reading is its text and an ISO 8601 duration is its \
       datetime. Those two are not always the same number, and the difference is the interesting part. \
       Past an hour the elapsed reading stops showing seconds, and then the duration follows the *text* \
       rather than the raw elapsed time, because a duration that disagrees with its own visible reading \
       is worse than none; the two timers below share a start time and show that, the clock format \
       reporting the true duration while the elapsed format reports the one it displays. Nothing here \
       re-renders to keep the reading current: the component writes the changed text straight to the \
       element it owns, because a per-second re-render of a timer is a per-second re-render of \
       everything above it. The wait until the next change is computed rather than rounded to a second - \
       past an hour the reading only moves once a minute, so asking every second would be work done to \
       discover that nothing had changed. A start time in the future is the one case where the reading \
       sits at zero and then moves."
    [ ex "counting: the reading moves on its own" (timer ~id:"showcase-timer-live" ())
    ; ex
        "an hour and two minutes in, elapsed format: the duration reports what the text represents"
        (timer ~id:"showcase-timer-elapsed-hour" ~start_time:(now_ms -. 3_725_000.) ())
    ; ex
        "the same instant, clock format: same start time, and the duration is now the real one"
        (timer ~id:"showcase-timer-clock" ~start_time:(now_ms -. 3_725_000.) ~format:Astryx.Timer.Clock ())
    ]
;;

let s_button_group () =
  let member ?(is_disabled = false) id label =
    Astryx.Button.view ~label ~is_disabled ~attrs:[ Vdom.Attr.create "id" id ] []
  in
  let group
    ?(orientation = Astryx.Button_group.Horizontal)
    ?(elevation = Astryx.Button_group.None_)
    ~id
    label
    members
    =
    Astryx.Button_group.view
      ~label
      ~orientation
      ~elevation
      ~attrs:[ Vdom.Attr.create "id" id ]
      ~children:members
      ()
  in
  section
    ~id:"button-group"
    ~title:"ButtonGroup"
    ~note:
      "Buttons joined into one surface: shared edges, and a single tab stop with the arrows moving \
       within it. Two things here are worth knowing. The connected look is drawn by CSS from the group \
       rather than by a context the children read, because a child in this port is built before its \
       container sees it - and the rule has to target the button *inside* each child, since a member \
       that renders its own layer wraps its button. Upstream hit the same wall and moved the end-cap \
       rules into Button.tsx. The single tab stop is behaviour, and unlike a radio group the platform \
       does not provide it for buttons, so the group implements the APG roving tabindex itself: one \
       member is reachable by Tab, arrows move along the orientation, Home and End jump to the ends, \
       the ends wrap, and disabled members are skipped. Arrow keys pressed inside a member's own layer \
       - a tooltip, a menu - stay with that layer, because the nearest boundary above the key event has \
       to be the group's own root. One thing is not ported and is named rather than approximated: size \
       does not propagate from the group to its members, so each member states its own."
    [ ex
        "a horizontal group: one tab stop, the arrows move within it, and the disabled member is skipped"
        (group
           "Actions"
           ~id:"showcase-button-group"
           [ member "showcase-bg-copy" "Copy"
           ; member "showcase-bg-cut" "Cut"
           ; member "showcase-bg-delete" ~is_disabled:true "Delete"
           ])
    ; ex
        "floating: the shadow sits on the group, so the connected members lift as one surface"
        (group
           "Floating actions"
           ~id:"showcase-button-group-elevated"
           ~elevation:Astryx.Button_group.Low
           [ member "showcase-bg-approve" "Approve"; member "showcase-bg-reject" "Reject" ])
    ; ex
        "vertical: the same component on the other axis"
        (group
           "Zoom"
           ~id:"showcase-button-group-vertical"
           ~orientation:Astryx.Button_group.Vertical
           [ member "showcase-bg-in" "Zoom in"; member "showcase-bg-out" "Zoom out" ])
    ]
;;

let s_kbd () =
  let kbd keys = Astryx.Kbd.view ~keys () in
  let row name keys =
    Astryx.Stack.view
      ~direction:Astryx.Stack.Horizontal
      ~gap:S.S3
      ~align:A.Center
      [ label name; kbd keys ]
  in
  section
    ~id:"kbd"
    ~title:"Kbd"
    ~note:
      "A shortcut, drawn as keycaps. The part worth noticing is not the glyphs but the split between \
       them: the wrapper is role=img with an aria-label built from spoken words — Control + K, Command \
       + Shift + P — and every cap inside is aria-hidden. Glyphs are announced meaninglessly, so a \
       shortcut can look perfect and still be unusable, and this component takes that seriously. mod is \
       the one key whose name depends on the platform: a command symbol on an Apple platform, Ctrl \
       elsewhere — so this page renders whatever the machine reading it actually uses. Upstream defers \
       that answer through useSyncExternalStore so a server render and the first client render cannot \
       disagree; this port has no server render, so it asks directly, a divergence recorded rather than \
       a workaround copied. The detection is upstream's, including the detail that an empty or Unknown \
       client-hints platform is no answer rather than a negative one, so it falls through to \
       navigator.platform instead of concluding not-Apple. Keys split on +, are trimmed, lowercased, \
       and resolved through the aliases esc and return; a key it has never heard of falls back to its \
       own uppercase self rather than vanishing."
    [ ex
        "in the middle of a sentence, where a shortcut usually lives"
        (Vdom.Node.p
           [ Vdom.Node.text "Press "
           ; kbd "mod+k"
           ; Vdom.Node.text " to open the palette, or "
           ; kbd "mod+shift+p"
           ; Vdom.Node.text " to run a command by name."
           ])
    ; ex
        "every key it knows a glyph for"
        (Vdom.Node.div
           [ row "mod" "mod"
           ; row "ctrl" "ctrl"
           ; row "alt" "alt"
           ; row "shift" "shift"
           ; row "enter" "enter"
           ; row "backspace" "backspace"
           ; row "escape" "escape"
           ; row "tab" "tab"
           ; row "arrows" "up+down+left+right"
           ; row "a literal plus key" "shift+plus"
           ])
    ; ex
        "a key nobody taught it about renders as itself"
        (Vdom.Node.div [ row "unknown" "pageup"; row "in a combination" "mod+shift+f5"; row "aliases resolve" "esc+return" ])
    ]
;;

(* ------------------------------------------------------------------ layer (the native popover API) *)

(* The mechanism the overlay family stands on, demonstrated rather than described. Two layers, the same
   markup, one attribute apart: `auto` is dismissed by the platform and `manual` is not. That difference
   is not a flag the port implements — it is what the attribute means to the browser — which is the whole
   point of asking the platform first. *)

(* ------------------------------------------------------------------------------------ Popover *)
let popover_demo (graph : Bonsai.graph) =
  let is_open, set_is_open = Bonsai.state false graph in
  let popover =
    Bonsai.map2 is_open set_is_open ~f:(fun is_open set ->
      Astryx.Popover.view
        ~id:"showcase-popover"
        ~label:"Share"
        ~trigger:
          (Astryx.Button.view
             ~label:"Share"
             ~attrs:[ Vdom.Attr.create "id" "showcase-popover-trigger" ]
             [])
        ~content:
          (Astryx.Stack.view
             ~direction:Astryx.Stack.Vertical
             ~gap:S.S2
             [ Astryx.Button.view ~label:"Copy link" []
             ; Astryx.Button.view ~label:"Copy as markdown" []
             ])
        ~is_open
        ~on_open_change:(fun open_ -> set open_)
        ())
  in
  Bonsai.map popover ~f:(fun popover ->
    section
      ~id:"popover"
      ~title:"Popover"
      ~note:
        "A layer anchored to its trigger, opened and dismissed by the platform. Upstream does the same \
         thing with the native Popover API — popover=auto and showPopover({source: trigger}) — so the \
         browser owns the top layer, the outside click, Escape *and* the positioning; that is why this \
         component contains no placement maths at all, and why the trigger is rendered inside a stable \
         anchor wrapper (upstream's comment: a pressed-state transform on the trigger would make the \
         surface jitter as it is placed). The trigger is wired by the mechanism rather than by the \
         caller, because aria-expanded is state and an attribute passed in from outside could only be a \
         snapshot. Focus enters the first genuine control in the content, falling back to the labelled \
         surface when there is none, and the generated close button is not a candidate — it sits outside \
         the content wrapper, which is exactly what keeps it out of initial focus while leaving it \
         reachable by keyboard. Closing returns focus to the trigger, but only if focus was inside. Two \
         things upstream has are named as missing rather than approximated: width is handed to CSS \
         instead of being measured and clamped against the viewport, and there is no modal focus trap — \
         isModal is announced with aria-modal and nothing is trapped."
      [ ex
          "click the trigger, press Escape, click outside: the value is told each time, which is the whole point"
          popover
      ])
;;

let layer_demo (graph : Bonsai.graph) =
  let join_all trees =
    List.fold trees ~init:(Bonsai.return []) ~f:(fun acc tree ->
      Bonsai.map2 acc tree ~f:(fun acc node -> acc @ [ node ]))
  in
  let one ~id ~popover_kind ~label =
    let is_open, set_is_open = Bonsai.state false graph in
    (* The trigger is an ordinary ported Button, and the ARIA wiring is here on purpose: this
       demonstrates the *mechanism* under Popover, so the trigger is wired by hand rather than by the
       component. Popover itself does this for its caller — see the Popover section. *)
    let trigger =
      Bonsai.map2 is_open set_is_open ~f:(fun is_open set ->
        Vdom.Node.span
          ~attrs:
            [ Vdom.Attr.create "id" (id ^ "-trigger-wrapper")
              (* The trigger is wired by the mechanism, not by the caller: aria-expanded is state, so
                 an attribute handed in from outside could only be a snapshot. The click comes from
                 here for the same reason — which is why this Button has no on_click of its own. *)
            ; Astryx.Common.Layer_trigger_hook.attr
                ~controls:(id ^ "-surface")
                ~is_open
                ~on_toggle:(set (not is_open))
                ()
            ]
          [ Astryx.Button.view
              ~label
              ~attrs:[ Vdom.Attr.create "id" (id ^ "-trigger") ]
              []
          ])
    in
    let surface =
      Bonsai.map2 is_open set_is_open ~f:(fun is_open set ->
        Vdom.Node.div
          ~attrs:
            ([ Vdom.Attr.create "id" (id ^ "-surface")
             ; Vdom.Attr.create "popover" popover_kind
             ; Vdom.Attr.class_ "astryx-layer-demo"
             ]
             (* Attr.data returns a list, and these are lists too, so the whole set is spliced. *)
             @ Astryx.Common.Attr.data "component" "Layer"
             @ [ (* The one line that is the mechanism: the value goes in, and a close the platform
                    performs comes back out through on_platform_close. *)
                 Astryx.Common.Layer_hook.attr ~is_open ~on_platform_close:(set false)
               ])
          [ Vdom.Node.div
              ~attrs:[ Vdom.Attr.class_ "astryx-layer-demo__title" ]
              [ Vdom.Node.text "An anchored layer" ]
          ; Vdom.Node.p
              ~attrs:[ Vdom.Attr.class_ "astryx-layer-demo__body" ]
              [ Vdom.Node.text
                  (if String.equal popover_kind "auto"
                   then
                     "Dismissed by the platform: click anywhere outside this box, or press Escape. \
                      Neither is a handler in this port — a popover=\"auto\" layer behaves that way \
                      because the browser decides it does."
                   else
                     "Not dismissed by the platform: click outside it, or press Escape. The layer \
                      stays where it is, because popover=\"manual\" means the platform leaves it \
                      alone.")
              ]
          ; Astryx.Button.view
              ~label:"Close it from the application"
              ~attrs:[ Vdom.Attr.create "id" (id ^ "-close") ]
              ~on_click:(fun _ -> set false)
              []
          ])
    in
    let readout =
      Bonsai.map is_open ~f:(fun is_open ->
        Vdom.Node.div
          ~attrs:
            [ Vdom.Attr.create "id" (id ^ "-state")
            ; Vdom.Attr.class_ "astryx-layer-demo__state"
            ]
          [ Vdom.Node.text
              (Printf.sprintf
                 "the value the application holds: %s"
                 (if is_open then "open" else "closed"))
          ])
    in
    Bonsai.map3 trigger surface readout ~f:(fun trigger surface readout ->
      Vdom.Node.div
        ~attrs:[ Vdom.Attr.class_ "astryx-layer-demo__wrap" ]
        [ trigger; surface; readout ])
  in
  (* Two trees, in the order the match below destructures them — the same pairwise discipline the rest
     of this file uses, since Bonsai offers no list combinator over trees. *)
  let examples =
    [ one
        ~id:"showcase-layer-auto"
        ~popover_kind:"auto"
        ~label:"Open a layer the platform dismisses"
    ; one
        ~id:"showcase-layer-manual"
        ~popover_kind:"manual"
        ~label:"Open a layer the platform leaves alone"
    ]
  in
  Bonsai.map (join_all examples) ~f:(fun examples ->
    match examples with
    | [ auto; manual ] ->
      section
        ~id:"layer"
        ~title:"Layer"
        ~note:
          "The mechanism the whole overlay family stands on, demonstrated rather than described. \
           Upstream does not position its layers with JavaScript — it opens them with the native \
           Popover API, which hands the platform the top layer, outside-click dismissal, Escape, and \
           CSS anchor positioning against the trigger. The two layers below differ by one attribute: \
           popover=auto is the platform's to dismiss, popover=manual is not, and the second is how a \
           surface asks for explicit dismissal only. Note what is missing from the markup: no \
           document-level click listener, no keydown handler, no stacking maths. What the port adds is \
           the part the platform cannot know — that a layer the *browser* closed has to be reported \
           back, or the value saying open quietly becomes a lie. The gate presses both halves: in \
           jsdom, which has no Popover API at all, nothing is thrown and the value is still the truth; \
           in Chromium, a real click outside and a real Escape decide it. This is a mechanism, not yet \
           a component: Popover adds the trigger's ARIA wiring, the labelled surface and the close \
           button on top of it."
        (* Inside the map the trees are resolved, so these are plain nodes. *)
        [ ex "dismissed by the platform (popover=auto)" auto
        ; ex "explicit dismissal only (popover=manual)" manual
        ]
    | _ -> Vdom.Node.none)
;;

let s_input_group () =
  (* A raw input stands in for a real control here: the point of the section is the group's own surface —
     the box, the label that names it, the adornment's shared edge — and a stateful TextInput would add a
     state machine to demonstrate a layout. *)
  let input id value =
    Vdom.Node.input
      ~attrs:
        (Astryx.Common.Attr.class_ [ "astryx-text-input__input" ]
         @ [ Vdom.Attr.create "id" id
           ; Vdom.Attr.create "type" "text"
           ; Vdom.Attr.create "value" value
           ])
      ()
  in
  section
    ~id:"input-group"
    ~title:"InputGroup"
    ~note:("A group is one field with more than one control in it. The label names the group rather than a " ^ "control — so it carries no `for` — and the status message is detached, sitting below the " ^ "group because there is no single control's edge for it to sit against. The box is inline-flex " ^ "stretched to a step of the shared size scale, so its children fill the height without being " ^ "told the size.")
    [ ex "an adornment belongs to the group's surface, not inside it — note the single shared border"
        (Astryx.Input_group.view
           ~id:"showcase-group-amount"
           ~label:"Amount"
           ~size:Astryx.Input_group.Md
           ~children:
             [ Astryx.Input_group_text.view ~children:[ Vdom.Node.text "USD" ] ()
             ; input "showcase-group-amount-input" "1,250.00"
             ]
           ())
    ; ex "a prefix, a description, and a detached status message"
        (Astryx.Input_group.view
           ~id:"showcase-group-site"
           ~label:"Site"
           ~description:"Where the export is published."
           ~status:{ Astryx.Input_types.type_ = Astryx.Input_types.Success; message = Some "Reachable." }
           ~size:Astryx.Input_group.Sm
           ~children:
             [ Astryx.Input_group_text.view ~children:[ Vdom.Node.text "https://" ] ()
             ; input "showcase-group-site-input" "example.com"
             ]
           ())
    ; ex "disabled — the whole group dims from one attribute on one box"
        (Astryx.Input_group.view
           ~id:"showcase-group-locked"
           ~label:"Locked"
           ~is_disabled:true
           ~size:Astryx.Input_group.Lg
           ~children:[ input "showcase-group-locked-input" "read only" ] ())
    ]
;;

let s_toolbar () =
  let button label = Astryx.Button.view ~label [] in
  section
    ~id:"toolbar"
    ~title:"Toolbar"
    ~note:
      ("A toolbar is one tab stop named as one region: Tab reaches it, the arrows move between its members, "
       ^ "and it says what it is. A centre slot switches the row to three columns so the middle is centred "
       ^ "against the bar rather than against whatever happens to sit beside it.")
    [ ex "start and end slots — a flex row where the ends are pushed apart"
        (Astryx.Toolbar.view
           ~label:"Document actions"
           ~attrs:[ Vdom.Attr.create "id" "showcase-toolbar-actions" ]
           ~start_content:[ button "Bold"; button "Italic" ]
           ~end_content:[ button "Share" ]
           ())
    ; ex "a centre slot, so the middle is centred against the bar"
        (Astryx.Toolbar.view
           ~label:"Zoom controls"
           ~attrs:[ Vdom.Attr.create "id" "showcase-toolbar-zoom" ]
           ~start_content:[ button "Out" ]
           ~center_content:[ button "100%" ]
           ~end_content:[ button "In" ]
           ())
    ; ex
        "vertical, with a text field: an arrow at the end of its text leaves the field, one mid-text moves the caret — which is what lets a toolbar hold an input at all"
        (Astryx.Toolbar.view
           ~label:"Search and filters"
           ~attrs:[ Vdom.Attr.create "id" "showcase-toolbar-search" ]
           ~orientation:Astryx.Toolbar.Vertical
           ~start_content:
             [ Vdom.Node.input
                 ~attrs:
                   (Astryx.Common.Attr.class_ [ "astryx-text-input__input" ]
                    @ [ Vdom.Attr.create "id" "showcase-toolbar-input"
                      ; Vdom.Attr.create "type" "text"
                      ; Vdom.Attr.create "value" "query"
                      ])
                 ()
             ]
           ~end_content:[ button "Search" ]
           ())
    ]
;;

(* A 48x48 inline SVG, so the "image that loads" example genuinely loads without reaching the network - which
   matters in a gate that must not depend on one. The other examples point at sources that cannot load, which
   is the point of them. *)
let avatar_data_uri =
  "data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='48' height='48'%3E%3Crect width='48' \
   height='48' fill='%237c5cff'/%3E%3C/svg%3E"
;;

(* Avatar takes a graph because its image fallback chain is state: a source that failed is remembered so the
   next one can be tried, and the initials are what is left when even that fails. The jsdom harness renders
   static nodes, so this component's checks live in the browser gate - where an image error can actually be
   fired. *)
let avatar_demo (graph : Bonsai.graph) =
  let showcase_row = Vdom.Attr.class_ "showcase-row" in
  let sizes =
    unwrap_all
      [ Astryx.Avatar.view ~size:Astryx.Avatar.Xsm ~name:"Ada Lovelace" graph ()
      ; Astryx.Avatar.view ~size:Astryx.Avatar.Sm ~name:"Ada Lovelace" graph ()
      ; Astryx.Avatar.view ~size:Astryx.Avatar.Md ~name:"Ada Lovelace" graph ()
      ; Astryx.Avatar.view ~size:Astryx.Avatar.Lg ~name:"Ada Lovelace" graph ()
      ; Astryx.Avatar.view ~size:Astryx.Avatar.Xl ~name:"Ada Lovelace" graph ()
      ]
  in
  let shapes =
    unwrap_all
      [ Astryx.Avatar.view ~id:"avatar-circle" ~shape:Astryx.Avatar.Circle ~size:Astryx.Avatar.Lg ~name:"A B" graph ()
      ; Astryx.Avatar.view ~id:"avatar-rounded" ~shape:Astryx.Avatar.Rounded ~size:Astryx.Avatar.Lg ~name:"A B" graph ()
      ; Astryx.Avatar.view ~id:"avatar-square" ~shape:Astryx.Avatar.Square ~size:Astryx.Avatar.Lg ~name:"A B" graph ()
      ]
  in
  let examples : Vdom.Node.t list Bonsai.t =
    unwrap_all
      [ Bonsai.map (Astryx.Avatar.view ~id:"avatar-initials" ~name:"Ada Lovelace" graph ()) ~f:(ex "initials from a name")
      ; Bonsai.map
          (Astryx.Avatar.view ~id:"avatar-image" ~src:avatar_data_uri ~name:"Grace Hopper" graph ())
          ~f:(ex "an image that loads, with the initials waiting behind it")
      ; Bonsai.map
          (Astryx.Avatar.view
             ~id:"avatar-fallback"
             (* Paths that genuinely 404. A data URI is the wrong tool here: it always loads, and a
                malformed payload merely fails to parse - which fires no error event at all, as the first
                version of this example discovered by never falling back. *)
             ~src:"/site/this-source-does-not-exist.png"
             ~fallback_src:"/site/neither-does-this-one.png"
             ~name:"Grace Hopper"
             graph
             ())
          ~f:(ex "both sources fail, so the initials follow")
      ; Bonsai.map
          (Astryx.Avatar.view
             ~id:"avatar-status"
             ~name:"Ada Lovelace"
             (* The dot carries no label of its own here, and that is the point: the avatar's own name
                already composes the status in, and a labelled dot inside would announce it twice. *)
             ~status:(Astryx.Avatar_status_dot.view ~variant:Astryx.Avatar_status_dot.Success ())
             ~status_label:"Online"
             graph
             ())
          ~f:(ex "a status dot, composed into the name as \"Ada Lovelace, Online\"")
      ; Bonsai.map
          (Astryx.Avatar.view ~id:"avatar-decorative" ~src:avatar_data_uri graph ())
          ~f:(ex "decorative: no name and no label, so nothing is announced")
      ; Bonsai.map
          (Astryx.Avatar.view ~id:"avatar-link" ~name:"Grace Hopper" ~href:"#avatars" graph ())
          ~f:(ex "a link, when given an href")
      ; Bonsai.map
          (Astryx.Avatar.view ~id:"avatar-button" ~name:"Grace Hopper" ~on_click:Effect.Ignore graph ())
          ~f:(ex "a button, when given a click handler and no href")
      ; Bonsai.map2 sizes shapes ~f:(fun sizes shapes ->
          ex
            "five sizes, three shapes"
            (Vdom.Node.div
               ~attrs:[ showcase_row ]
               [ Vdom.Node.div ~attrs:[ showcase_row ] sizes
               ; Vdom.Node.div ~attrs:[ showcase_row ] shapes
               ]))
      ]
  in
  Bonsai.map examples ~f:(fun examples ->
    section
      ~id:"avatar"
      ~title:"Avatar"
      ~note:
        "A picture with a fallback, and a status that has to stay reachable even though a role=\"img\" root \
         prunes its descendants. Four states, in order: the image, then the fallback source once the first has \
         failed, then the initials from the name, and finally the default icon - not an empty plate, which is \
         what a name with no letters would otherwise render."
      examples)
;;

(* AvatarGroup takes its members already rendered, which is what lets it stay a function of nodes rather than
   of the graph - and what lets the jsdom harness render it at all. The caller slices: upstream's group does
   not count what fits, it renders what it is given and the chip says how many were left out. *)
let avatar_group_demo (graph : Bonsai.graph) =
  let facepile ?(size = Astryx.Avatar.Md) ?(id = "avatar-group") names chip =
    unwrap_all
      (List.map names ~f:(fun (key, name) ->
         Astryx.Avatar.view ~id:(sprintf "%s-member-%s" id key) ~size ~name graph ()))
    |> Bonsai.map ~f:(fun avatars ->
      Astryx.Avatar_group.view ~id ~label:"Team" ~size ~overflow:chip ~avatars ())
  in
  let examples : Vdom.Node.t list Bonsai.t =
    unwrap_all
      [ Bonsai.map
          (facepile [ "a", "Ada Lovelace"; "b", "Grace Hopper"; "c", "Alan Turing" ]
             (Astryx.Avatar_group_overflow.view ~id:"avatar-group-overflow" ~count:7 ~size:Astryx.Avatar.Md ()))
          ~f:(ex "three of ten, with the rest as a chip")
      ; Bonsai.map
          (facepile ~size:Astryx.Avatar.Lg ~id:"avatar-group-large"
             [ "a", "Ada Lovelace"; "b", "Grace Hopper" ]
             (Astryx.Avatar_group_overflow.view ~id:"avatar-group-large-overflow" ~count:12 ~size:Astryx.Avatar.Lg ()))
          ~f:(ex "the overlap is a ratio, so it scales with the avatars")
      ; Bonsai.return
          (ex
             "a chip whose content the caller supplies"
             (Astryx.Avatar_group.view
                ~id:"avatar-group-custom"
                ~label:"Team"
                ~overflow:
                  (Astryx.Avatar_group_overflow.view
                     ~id:"avatar-group-custom-overflow"
                     ~content:(Vdom.Node.text "see all")
                     ~count:99
                     ~size:Astryx.Avatar.Md
                     ())
                ~avatars:
                  [ Astryx.Avatar_status_dot.view ~variant:Astryx.Avatar_status_dot.Neutral () ]
                ()))
      ]
  in
  Bonsai.map examples ~f:(fun examples ->
    section
      ~id:"avatar-group"
      ~title:"AvatarGroup"
      ~note:
        "A facepile: avatars stacked with a negative inline-start margin on every member, and a chip for the \
         ones left out. The overlap is round(size * 0.25) and it is a margin on each member rather than on the \
         container, because a container margin is defeated the moment a member is wrapped in something of its \
         own. The row is one tab stop with the arrow keys between members, and a screen reader is told so. The \
         group does not count what fits: the consumer slices and says how many are left, which is upstream's \
         rule and the reason there is no measuring here."
      examples)
;;

(* ToggleButton is a pure view - a function of its value, not of the graph - which is what lets its pressed
   state be the caller's: the state lives in the graph and the node is built from it. The reason it is pure is
   worth keeping in mind when adding to it: a view that reached for the graph could not be re-run when the
   state changed. *)
let toggle_icon filled =
  Vdom.Node.create_svg
    "svg"
    ~attrs:
      [ Vdom.Attr.create "xmlns" "http://www.w3.org/2000/svg"
      ; Vdom.Attr.create "viewBox" "0 0 24 24"
      ; Vdom.Attr.create "width" "1em"
      ; Vdom.Attr.create "height" "1em"
      ; Vdom.Attr.create "aria-hidden" "true"
      ]
    (if filled
     then [ Vdom.Node.create_svg "circle" ~attrs:[ Vdom.Attr.create "cx" "12"; Vdom.Attr.create "cy" "12"; Vdom.Attr.create "r" "9"; Vdom.Attr.create "fill" "currentColor" ] [] ]
     else
       [ Vdom.Node.create_svg "circle" ~attrs:[ Vdom.Attr.create "cx" "12"; Vdom.Attr.create "cy" "12"; Vdom.Attr.create "r" "9"; Vdom.Attr.create "fill" "none"; Vdom.Attr.create "stroke" "currentColor"; Vdom.Attr.create "stroke-width" "2" ] [] ])
;;

let toggle_button_demo (graph : Bonsai.graph) =
  let toggle ?(id = "") label =
    let pressed, set_pressed = Bonsai.state false graph in
    Bonsai.map2 pressed set_pressed ~f:(fun is_pressed set_pressed ->
      Astryx.Toggle_button.view ~id ~label ~is_pressed ~on_pressed_change:set_pressed ())
  in
  let trio =
    unwrap_all
      [ toggle ~id:"toggle-bold" "Bold"
      ; toggle ~id:"toggle-italic" "Italic"
      ; toggle ~id:"toggle-underline" "Underline"
      ]
    |> Bonsai.map ~f:(fun buttons ->
      Astryx.Toggle_button_group.view ~id:"toggle-group" ~label:"Text style" ~buttons ())
  in
  let examples : Vdom.Node.t list Bonsai.t =
    unwrap_all
      [ Bonsai.map trio ~f:(ex "three toggles, each holding its own pressed state")
      ; Bonsai.return
          (ex
             "icon-only, so the label becomes the name and the hover text"
             (Astryx.Toggle_button.view
                ~id:"toggle-icon-only"
                ~label:"Favorite"
                ~is_icon_only:true
                ~icon:(toggle_icon false)
                ~is_pressed:true
                ()))
      ; Bonsai.return
          (ex
             "a vertical group, and an icon that swaps when pressed"
             (Astryx.Toggle_button_group.view
                ~id:"toggle-group-vertical"
                ~orientation:Astryx.Toggle_button_group.Vertical
                ~label:"View"
                ~buttons:
                  [ Astryx.Toggle_button.view ~id:"toggle-swap" ~label:"Outline" ~icon:(toggle_icon false) ~pressed_icon:(toggle_icon true) ~is_pressed:true ()
                  ; Astryx.Toggle_button.view ~id:"toggle-swap-off" ~label:"Empty" ~icon:(toggle_icon false) ~pressed_icon:(toggle_icon true) ()
                  ]
                ()))
      ]
  in
  Bonsai.map examples ~f:(fun examples ->
    section
      ~id:"toggle-button"
      ~title:"ToggleButton"
      ~note:
        "A button that stays down. It is the port's Button with aria-pressed, an icon that swaps when pressed, \
         and - for the icon-only case - the label doubling as the accessible name and the hover text. The \
         width reservation upstream does (a second copy of the label in the pressed weight, sharing a grid \
         cell with the real one, so a row does not shuffle when a toggle goes down) is named as a divergence \
         rather than faked: the two copies have to share a cell, and this Button owns its own label. The group \
         is a named group with aria-orientation; the selection belongs to the caller, since the port has no \
         contexts."
      examples)
;;

let selectable_card_demo (graph : Bonsai.graph) =
  (* Selection is the caller's, exactly as upstream's composition hint says: a set for multi-select, and the
     card keeps nothing of its own. The set is keyed by the card's id, so the label stays free for the
     accessible name. *)
  let state, set_state = Bonsai.state (Set.empty (module String)) graph in
  let card ?(variant = Astryx.Card.Default) ~id ~label children =
    Bonsai.map2 state set_state ~f:(fun state set_state ->
      let is_selected = Set.mem state id in
      Astryx.Selectable_card.view
        ~variant
        ~is_selected
        ~label
        ~attrs:[ Vdom.Attr.id id ]
        ~on_change:(fun next ->
          set_state (if next then Set.add state id else Set.remove state id))
        children)
  in
  let multi_select =
    unwrap_all
      [ card ~id:"sc-blue" ~variant:Astryx.Card.Blue ~label:"Blue" [ Vdom.Node.text "Blue" ]
      ; card ~id:"sc-green" ~variant:Astryx.Card.Green ~label:"Green" [ Vdom.Node.text "Green" ]
      ; card ~id:"sc-purple" ~variant:Astryx.Card.Purple ~label:"Purple" [ Vdom.Node.text "Purple" ]
      ]
    |> Bonsai.map ~f:(fun cards -> Astryx.HStack.view ~gap:S.S2 cards)
  in
  let examples : Vdom.Node.t list Bonsai.t =
    unwrap_all
      [ Bonsai.map multi_select ~f:(ex "three cards, one set: click to select more than one")
      ; Bonsai.return
          (ex
             "selected, and a disabled card that still explains itself"
             (Astryx.HStack.view
                ~gap:S.S2
                [ Astryx.Selectable_card.view
                    ~is_selected:true
                    ~label:"Selected"
                    ~attrs:[ Vdom.Attr.id "sc-selected" ]
                    ~on_change:(fun _ -> Effect.Ignore)
                    [ Vdom.Node.text "Selected" ]
                ; Astryx.Selectable_card.view
                    ~is_disabled:true
                    ~is_selected:false
                    ~label:"Unavailable"
                    ~attrs:[ Vdom.Attr.id "sc-disabled" ]
                    ~on_change:(fun _ -> Effect.Ignore)
                    [ Vdom.Node.text "Unavailable" ]
                ]))
      ; Bonsai.return
          (ex
             "a nested button: clicking it does NOT select the card"
             (Astryx.Selectable_card.view
                ~is_selected:false
                ~label:"With a nested control"
                ~attrs:[ Vdom.Attr.id "sc-nested" ]
                ~on_change:(fun _ -> Effect.Ignore)
                [ Vdom.Node.text "Card body"
                ; Astryx.Button.view
                    ~label:"Inner"
                    ~variant:Astryx.Button.Secondary
                    ~on_click:(fun _ -> Effect.Ignore)
                    []
                ]))
      ]
  in
  Bonsai.map examples ~f:(fun examples ->
    section
      ~id:"selectable-card"
      ~title:"SelectableCard"
      ~note:
        "A Card that toggles between selected and unselected. The surface is a plain div with no role and \
         no tabindex; a visually-hidden checkbox inside carries the role, the accessible name and the \
         checked state, so native checkbox behaviour comes for free and the container has no semantics of \
         its own to get wrong. Selection is controlled - the set above lives in the caller, exactly as the \
         composition hint says. The click rules are the mechanism: a surface click selects, a click on a \
         nested button is left to the button, and a click that ends a text selection is ignored. Named as a \
         divergence: the touch press model (a 461-line document-level controller) is not ported, so a finger \
         press does not paint while a mouse press does."
      examples)
;;

let s_clickable_card () =
  let card ?(variant = Astryx.Card.Default) ~label ?href ?target ?is_disabled children =
    Astryx.Clickable_card.view ~label ?href ?target ?is_disabled ~variant children
  in
  section
    ~id:"clickable-card"
    ~title:"ClickableCard"
    ~note:
      "A Card whose whole surface is the action. The surface is a plain div; a visually-hidden link - or a \
       button, when there is no href - carries the accessible name, so the card is operable as a link or a \
       button by assistive technology while looking like a card. The click rules are the same mechanism \
       SelectableCard uses, extracted into Common when this component became its second consumer: a surface \
       click acts, a click on a nested control is left to that control, and a click that ends a text \
       selection does nothing. The last card asks for a javascript: href and renders inert - no href, \
       role=link, aria-disabled - because unlike upstream there is no framework here to vet the attribute."
    [ ex
        "a link card: the whole surface navigates"
        (card ~label:"Open the report" ~href:"https://example.com/report" [ Vdom.Node.text "A link card" ])
    ; ex
        "no href: the surface is a button and runs the handler"
        (card ~label:"Run the action" [ Vdom.Node.text "An action card" ])
    ; ex
        "disabled: the link drops out of the tab order and its clicks are cancelled"
        (card
           ~label:"Unavailable"
           ~href:"https://example.com/unavailable"
           ~is_disabled:true
           [ Vdom.Node.text "A disabled card" ])
    ; ex
        "a refused href renders inert rather than navigating"
        (card ~label:"Refused" ~href:"javascript:alert(1)" [ Vdom.Node.text "A refused href" ])
    ]
;;

let s_link () =
  let link ?(label = None) ?attrs children =
    Astryx.Link.view ?label ?attrs children
  in
  section
    ~id:"link"
    ~title:"Link"
    ~note:
      "A styled link that is sometimes not a link at all. Three rendering branches, in this order: a \
       button when the resolved role is button, then a disabled anchor with NO href, then the anchor. \
       The order is why the second branch exists — a disabled link with an on_click is still a button, \
       and only a disabled link with nothing to click becomes inert. The disabled anchor has no href on \
       purpose: an anchor without one is not focusable and exposes no link affordance, so neither \
       programmatic focus plus Enter, nor assistive-technology activation, nor middle-click can navigate. \
       A refused destination takes the same route — one unsafe destination rejects the whole handoff, \
       including a perfectly good href — so the link still renders and simply goes nowhere. External \
       links gain target=_blank with noopener and noreferrer appended to whatever rel the caller passed, \
       preserving its order, and a visually-hidden note that the new tab opened, because the icon is \
       decorative and an unannounced new tab is a surprise."
    [ ex "Default" (link [ Vdom.Node.text "A link to nowhere in particular" ])
    ; ex "Always underlined" (Astryx.Link.view ~has_underline:true [ Vdom.Node.text "Underlined" ])
    ; ex "External" (Astryx.Link.view ~is_external_link:true ~href:"https://example.com" [ Vdom.Node.text "example.com" ])
    ; ex "Disabled" (Astryx.Link.view ~is_disabled:true ~href:"https://example.com" [ Vdom.Node.text "Disabled" ])
    ; ex
        "No destination, so a button"
        (Astryx.Link.view ~on_click:(fun _ -> Effect.Ignore) [ Vdom.Node.text "Does something" ])
    ]
;;

let s_token () =
  section
    ~id:"token"
    ~title:"Token"
    ~note:
      "A chip for an entity inline - a tag, a filter, a recipient. Which ELEMENT it renders as is \
       decided by same resolved role that drives Link, in upstream's order: a live href makes the \
       anchor the root, and fires a remove button alongside it the root becomes a span so the link \
       and the button sit as SIBLINGS - a button nested inside an anchor is invalid HTML, and the \
       sibling shape is the fix; without a link, an on_click hides a real button under a visible \
       label and the focus ring moves to the whole token; otherwise it is a plain span. A remove \
       button's name always says which token it removes ('Remove ' plus the label, upstream's \
       English message), a refused destination loses its href but keeps its outline, and colour \
       plus size are reflected as data attributes so callers can theme them without selectors. \
       One thing upstream does that this port does not: when a link token is also removable, \
       upstream lets a click anywhere on the chip drive the inner link (new-tab clicks included) \
       through a ref-bridged hook - here the markers and structure are faithful but only the link \
       itself navigates. A press paints with the mouse; the touch press controller is the \
       press-feedback milestone, still to come."
    [ ex "Default" (Astryx.Token.view "engineering")
    ; ex "Coloured category" (Astryx.Token.view ~color:Astryx.Token.Green "status: active")
    ; ex
        "Removable"
        (Astryx.Token.view ~on_remove:(fun _ -> Effect.Ignore) "label: ui")
    ; ex
        "Clickable"
        (Astryx.Token.view ~on_click:(fun _ -> Effect.Ignore) "open details")
    ; ex "Link" (Astryx.Token.view ~href:"https://example.com" "example.com")
    ; ex
        "Link + removable (sibling container)"
        (Astryx.Token.view ~href:"/docs" ~on_remove:(fun _ -> Effect.Ignore) "docs (v2)")
    ; ex
        "Disabled"
        (Astryx.Token.view ~is_disabled:true ~on_click:(fun _ -> Effect.Ignore) "archived")
    ; ex
        "Icon only, label for screen readers"
        (Astryx.Token.view
           ~is_label_hidden:true
           ~description:"Done"
           ~icon:(Astryx.Icon.view ~size:Astryx.Icon.Md ~name:"check" ())
           "done")
    ]
;;

let s_spinner () =
  section
    ~id:"spinner"
    ~title:"Spinner"
    ~note:
      "An animated loading ring, in four sizes (the box is the ring plus its stroke on each side: \
       xl draws a 28px ring inside a 36px box) and four shades - accent on light, on-dark for media \
       surfaces, secondary text for inline lists, and inherit, which reads the parent's currentColor \
       so a spinner inside a coloured button matches it (its track at 0.3). Geometry is drawn as \
       SVG attributes, so a render without the stylesheet still shows the right ring; the moving \
       arc covers 0.375 of the circumference and the dash loops once per cycle. With a string label \
       the visible text names the status element through aria-labelledby (never both, so screen \
       readers don't announce it twice); a non-string label can't be referenced, so it falls back to \
       the English 'Loading' accessible name, as does a bare spinner. Divergences: upstream pins \
       every ring's animation to the timeline origin so spinners mounted at different times stay in \
       phase (Web Animations machinery not ported), and it registers the geometry vars with \
       CSS.registerProperty - here the same value is emitted inline as a real <length>, which is \
       what the keyframes' calc() needs."
    [ ex "Default" (Astryx.Spinner.view ())
    ; ex
        "All sizes"
        (Vdom.Node.div
           [ Astryx.Spinner.view ~size:Astryx.Spinner.Sm ()
           ; Astryx.Spinner.view ~size:Astryx.Spinner.Md ()
           ; Astryx.Spinner.view ~size:Astryx.Spinner.Lg ()
           ; Astryx.Spinner.view ~size:Astryx.Spinner.Xl ()
           ])
    ; ex
        "Shades"
        (Vdom.Node.div
           [ Astryx.Spinner.view ~shade:Astryx.Spinner.Default ()
           ; Astryx.Spinner.view ~shade:Astryx.Spinner.Subtle ()
           ; Astryx.Spinner.view ()
           ; Astryx.Spinner.view ~shade:Astryx.Spinner.Inherit ()
           ])
    ; ex "With label" (Astryx.Spinner.view ~label:"Loading..." ())
    ; ex
        "Label as rich content"
        (Astryx.Spinner.view
           ~label_node:
             (Astryx.Text.view
                ~type_:Astryx.Text.Body
                ~weight:Astryx.Text.Bold
                [ Vdom.Node.text "Fetching data" ])
           ())
    ; ex
        "On media"
        (Vdom.Node.div
           ~attrs:[ Vdom.Attr.class_ "astryx-demo-on-media" ]
           [ Astryx.Spinner.view ~shade:Astryx.Spinner.On_media ~label:"Uploading..." () ])
    ]
;;


(* Thumbnail takes a graph only for the failed-source memory: one cell remembers the exact source that
   failed so a changed source gets a fresh load. The states are otherwise props - placeholder, skeleton,
   upload overlay, remove (hover or always), interactive, disabled. The jsdom harness can render each by
   prop; the state change after a real image error is exercised in the browser gate. *)
let thumbnail_demo (graph : Bonsai.graph) =
  let examples : Vdom.Node.t list Bonsai.t =
    unwrap_all
      [ Bonsai.map
          (Astryx.Thumbnail.view
             ~id:"thumbnail-placeholder"
             ~label:"photo.png"
             graph
             )
          ~f:(ex "no source: the placeholder silhouette")
      ; Bonsai.map
          (Astryx.Thumbnail.view
             ~id:"thumbnail-image"
             ~src:avatar_data_uri
             ~alt:"A lilac square"
             ~label:"picture.svg"
             graph
             )
          ~f:(ex "a source that loads, with the inset edge")
      ; Bonsai.map
          (Astryx.Thumbnail.view
             ~id:"thumbnail-image-label"
             ~src:avatar_data_uri
             ~label:"report.pdf"
             graph
             )
          ~f:(ex "decorative (no alt): the name is the label alone")
      ; Bonsai.map
          (Astryx.Thumbnail.view
             ~id:"thumbnail-skeleton"
             ~src:"/site/this-source-does-not-exist.png"
             ~is_loading:true
             ~label:"uploading.pdf"
             graph
             )
          ~f:(ex "loading with a source: the scrimmed upload overlay")
      ; Bonsai.map
          (Astryx.Thumbnail.view
             ~id:"thumbnail-remove-hover"
             ~src:avatar_data_uri
             ~alt:"A lilac square"
             ~label:"report.pdf"
             ~on_remove:(fun _ -> Effect.Ignore)
             graph
             )
          ~f:(ex "a remove button, revealed on hover and focus")
      ; Bonsai.map
          (Astryx.Thumbnail.view
             ~id:"thumbnail-remove-always"
             ~src:avatar_data_uri
             ~alt:"A lilac square"
             ~label:"always.pdf"
             ~on_remove:(fun _ -> Effect.Ignore)
             ~show_remove_on:`Always
             graph
             )
          ~f:(ex "the remove button kept visible")
      ; Bonsai.map
          (Astryx.Thumbnail.view
             ~id:"thumbnail-interactive"
             ~src:avatar_data_uri
             ~alt:"A lilac square"
             ~on_click:(fun _ -> Effect.Ignore)
             graph
             )
          ~f:(ex "interactive: the whole surface is a button")
      ; Bonsai.map
          (Astryx.Thumbnail.view
             ~id:"thumbnail-disabled"
             ~src:avatar_data_uri
             ~alt:"A lilac square"
             ~label:"taken.pdf"
             ~on_click:(fun _ -> Effect.Ignore)
             ~on_remove:(fun _ -> Effect.Ignore)
             ~is_disabled:true
             graph
             )
          ~f:(ex "disabled: no hover, no actions")
      ; Bonsai.map
          (Astryx.Thumbnail.view
             ~id:"thumbnail-error"
             ~src:"/site/this-source-does-not-exist.png"
             ~alt:"Anything"
             ~label:"broken.png"
             graph
             )
          ~f:(ex "the source fails: the placeholder returns")
      ]
  in
  Bonsai.map examples ~f:(fun examples ->
    section
      ~id:"thumbnail"
      ~title:"Thumbnail"
      ~note:
        "A square preview card for an attachment, in four surface states: the image once it has loaded, \

         a skeleton while it is fetched, the placeholder silhouette when there is no source or the load has \

         failed, and the scrimmed upload overlay while an existing source is still being processed. The \

         remove button (when [on_remove] is set) overlays the corner - revealed on hover and keyboard \

         focus by default, or always visible - and its icon is a real Button, so the scrim colours are \

         fixed rather than luminance-adapting. A label both names the group - the remove button reads \

         'Remove <name>' and an interactive surface 'Open <name>' - and supplies the hover title; an image \

         without alt is decorative, so the name comes from the label alone. Divergences: upstream's \

         label tooltip is the native title attribute (the port's Tooltip takes a static trigger, and the \

         root is state-driven - the same divergence Avatar records), and there is no press-feedback \

         machinery: the interactive surface is a real button, so the press is the browser's own [:active]."
      examples)
;;


(* ScrollableArea is stateful in one thing: the measured state of the viewport, which drives the
   data-scroll-* attributes, the tabindex, and the overflow/overscroll style. The examples are
   static geometry - fixed viewport sizes over content that overflows them - and the jsdom harness
   can only render the pre-measurement state (jsdom has no layout: every client extent is 0 and the
   viewport is not measurable, so it stays inactive). The live cases - a measured viewport gains
   tabindex 0, edges flip as it scrolls - are exercised in the browser gate, where layout is real. *)
let scrollable_area_demo (graph : Bonsai.graph) =
  let row items =
    Vdom.Node.div
      ~attrs:[ Vdom.Attr.class_ "astryx-scrollable-area-demo__row" ]
      items
  in
  let rows count =
    List.init count ~f:(fun i ->
      row
        [ Vdom.Node.span ~attrs:[ Vdom.Attr.class_ "astryx-scrollable-area-demo__index" ]
            [ Vdom.Node.text (Int.to_string (i + 1)) ]
        ; Vdom.Node.span
            [ Vdom.Node.text
                (sprintf
                   "Row %d - the viewport is as wide as its content box, and it keeps its own scrollbar." i)
            ]
        ])
  in
  let chip i =
    Vdom.Node.span
      ~attrs:[ Vdom.Attr.class_ "astryx-scrollable-area-demo__chip" ]
      [ Vdom.Node.text (sprintf "item %d" i) ]
  in
  let examples : Vdom.Node.t list Bonsai.t =
    unwrap_all
      [ Bonsai.map
          (Astryx.Scrollable_area.view
             ~id:"scrollable-block"
             ~label:"Activity history"
             ~height:(Size.Px 180)
             graph
             (rows 12))
          ~f:(ex "block axis: vertical scrolling in a fixed height")
      ; Bonsai.map
          (Astryx.Scrollable_area.view
             ~id:"scrollable-inline"
             ~axis:`Inline
             ~label:"Tags"
             ~width:(Size.Px 420)
             graph
             (List.init 16 ~f:(fun i -> chip (i + 1))))
          ~f:(ex "inline axis: horizontal scrolling")
      ; Bonsai.map
          (Astryx.Scrollable_area.view
             ~id:"scrollable-both"
             ~axis:`Both
             ~label:"Gallery"
             ~width:(Size.Px 420)
             ~height:(Size.Px 180)
             graph
             (List.init 40 ~f:(fun i -> chip (i + 1))))
          ~f:(ex "both axes: a small window over a large grid")
      ; Bonsai.map
          (Astryx.Scrollable_area.view
             ~id:"scrollable-region"
             ~role:`Region
             ~label:"Activity history"
             ~height:(Size.Px 180)
             ~overscroll:`Contain
             graph
             (rows 12))
          ~f:(ex "role region + contained overscroll")
      ; Bonsai.map
          (Astryx.Scrollable_area.view
             ~id:"scrollable-padded"
             ~label:"Activity history"
             ~height:(Size.Px 180)
             ~padding:S.S3
             graph
             (rows 8))
          ~f:(ex "content padding on the spacing scale")
      ; Bonsai.map
          (Astryx.Scrollable_area.view
             ~id:"scrollable-sticky"
             ~label:"Activity history"
             ~height:(Size.Px 180)
             ~sticky_containment:`Always
             graph
             (rows 8))
          ~f:(ex "sticky containment always: a fitting viewport keeps its boundary")
      ; Bonsai.map
          (Astryx.Scrollable_area.view
             ~id:"scrollable-fitting"
             ~label:"Activity history"
             ~height:(Size.Px 180)
             graph
             (rows 3))
          ~f:(ex "fitting content: no effective axis, no tab stop")
      ]
  in
  Bonsai.map examples ~f:(fun examples ->
    section
      ~id:"scrollable-area"
      ~title:"ScrollableArea"
      ~note:
        "A native scroll viewport whose accessibility follows the measured geometry, not the \\\

         intent alone. The viewport is the root and its single child is a normal block content \\\

         box; only a requested axis that actually overflows makes the box scrollable, and only \\\

         then does the viewport enter the tab order (tabindex is removed - or held at -1 while \\\

         it still holds focus - when the axis stops being effective). The measured state is \\\

         published as data-scroll-* attributes on the viewport and data-scroll-content on the \\\

         content box, exactly upstream's contract: edges are logical (stable under RTL and \\\

         vertical writing modes), and an inactive axis reports both edges at rest. The \\\

         overflow style is clip until a Sticky boundary is needed, then auto on the overflowed \\\

         axis and hidden on the crossed one, with overscroll-behavior on the requested axes. \\\

         Full-bleed escapes the container's --container-padding-* variables. Divergences: the \\\

         hook's contentOrViewport keyboard delegation is not ported (the component always passes \\\

         owner 'viewport', which upstream never delegates), and the overflow/overscroll values \\\

         are real inline CSS properties rather than stylex custom-property shims."
      examples)
;;

let specs =
  [ s_stack (); s_text (); s_heading (); s_button (); s_badge (); s_card (); s_divider ()
  ; s_status_dot (); s_skeleton (); s_center (); s_section (); s_grid (); s_visually_hidden ()
  ; s_hstack (); s_vstack (); s_aspect_ratio ()
  ; s_icon_button (); s_code (); s_blockquote ()
  ; s_nav_icon (); s_empty_state (); s_citation ()
  ; s_icon (); s_field_status (); s_field_label (); s_indicator ()
  ; s_kbd ()
  ; s_button_group ()
  ; s_timer ()
  ; s_input_group ()
  ; s_toolbar ()
  ; s_clickable_card ()
  ; s_link ()
  ; s_token ()
  ; s_spinner ()
  ]
;;

(* The nav is an explicit list rather than derived from the section nodes,
   because Vdom does not expose a way to read an attribute back off a built node.
   tools/visual/verify-browser.mjs asserts that every nav href resolves to a real
   section id and vice versa, so the two cannot drift unnoticed. *)
let nav_items =
  [ "stack", "Stack"
  ; "text", "Text"
  ; "heading", "Heading"
  ; "button", "Button"
  ; "badge", "Badge"
  ; "card", "Card"
  ; "divider", "Divider"
  ; "statusdot", "StatusDot"
  ; "skeleton", "Skeleton"
  ; "center", "Center"
  ; "section", "Section"
  ; "grid", "Grid"
  ; "visuallyhidden", "VisuallyHidden"
  ; "hstack", "HStack"
  ; "vstack", "VStack"
  ; "aspectratio", "AspectRatio"
  ; "iconbutton", "IconButton"
  ; "code", "Code"
  ; "blockquote", "Blockquote"
  ; "navicon", "NavIcon"
  ; "emptystate", "EmptyState"
  ; "citation", "Citation"
  ; "icon", "Icon"
  ; "fieldstatus", "FieldStatus"
  ; "fieldlabel", "FieldLabel"
  ; "indicator", "Indicator"
  ; "checkbox", "CheckboxInput"
  ; "switch", "Switch"
  ; "radiogroup", "RadioList"
  ; "form-layout", "FormLayout"
  ; "tooltip", "Tooltip"
  ; "dialog", "Dialog"
  ; "alert-dialog", "AlertDialog"
  ; "dialog-header", "DialogHeader"
  ; "kbd", "Kbd"
  ; "button-group", "ButtonGroup"
  ; "timer", "Timer"; "input-group", "InputGroup"; "toolbar", "Toolbar"
  ; "metadata-list", "MetadataList"; "moremenu", "MoreMenu"; "progressbar", "ProgressBar"; "avatar", "Avatar"; "avatar-group", "AvatarGroup"; "toggle-button", "ToggleButton"; "selectable-card", "SelectableCard"; "clickable-card", "ClickableCard"; "link", "Link"; "token", "Token"; "spinner", "Spinner"; "thumbnail", "Thumbnail"
  ; "layer", "Layer"
  ; "popover", "Popover"
  ; "field", "Field + TextInput"
  ; "textarea", "TextArea"
  ; "dropdownmenu", "DropdownMenu"
  ; "interactive", "Interactive"
  ; "overflow-list", "OverflowList"
  ; "scrollable-area", "ScrollableArea"
  ]
;;

(* [Vdom.Node.*] creators take their attributes as the labelled [?attrs] and their
   children as the single positional argument — so it is [li ~attrs:[] [kids]], not
   [li [] [kids]]: the latter passes two positional arguments and the first is
   silently taken as the children. *)
let nav_lis items =
  List.map items ~f:(fun (id, title) ->
    Vdom.Node.li
      ~attrs:[]
      [ Vdom.Node.a
          ~attrs:[ Vdom.Attr.create "href" (sprintf "#%s" id) ]
          [ Vdom.Node.text title ]
      ])
;;

let nav () =
  Vdom.Node.nav
    ~attrs:[ Vdom.Attr.class_ "nav"; Vdom.Attr.create "aria-label" "Ported components" ]
    [ Vdom.Node.div ~attrs:[ Vdom.Attr.class_ "nav-head" ] [ Vdom.Node.text "Ported components" ]
    ; Vdom.Node.ul ~attrs:[ Vdom.Attr.class_ "nav-list" ] (nav_lis nav_items)
    ]
;;

(* MetadataList takes a graph even when nothing is truncated: upstream creates its show-all state
   unconditionally, and the port keeps that shape. The consequence is the same one the overlay family has -
   a stateful component cannot be rendered by the jsdom harness at all, because that harness renders static
   nodes and this needs the Bonsai runtime. Its structural and behavioural checks therefore live in the
   browser gate, which is where the toggle can actually be clicked. *)
let metadata_list_demo (graph : Bonsai.graph) =
  let item label value =
    Astryx.Metadata_list_item.view ~label ~children:[ Vdom.Node.text value ] ()
  in
  (* Each item is the *list* of nodes it contributes - the term and the value, separate children of the
     list grid. Keeping them as items rather than flattening is what lets truncation cut between them. *)
  let rows =
    [ item "Account" "northwind-logistics"
    ; item "Region" "us-west-2"
    ; item "Plan" "Enterprise"
    ; item "Seats" "240"
    ; item "Renewal" "2027-03-01"
    ; item "Owner" "ops@northwind.example"
    ]
  in
  let example ?title ?columns ?label_position ?label_width ?orientation ?max_num_of_items ~id label =
    Bonsai.map
      (Astryx.Metadata_list.view
         ?title
         ?columns
         ?label_position
         ?label_width
         ?orientation
         ?max_num_of_items
         ~id
         ~items:(Bonsai.return rows)
         graph)
      ~f:(fun node -> ex label node)
  in
  let single = example ~id:"showcase-metadata-single" "single column, labels inline" in
  let multi =
    example
      ~id:"showcase-metadata-multi"
      ~columns:Astryx.Metadata_list.Multi
      "multi-column: the labels stack, since there is no term column to align to"
  in
  let fixed =
    example
      ~id:"showcase-metadata-fixed"
      ~columns:(Astryx.Metadata_list.Fixed 3)
      "an explicit three columns, whether or not the box is wide enough for them"
  in
  let truncated =
    example
      ~id:"showcase-metadata-truncated"
      ~max_num_of_items:3
      "truncated at three, with the show-all toggle the state exists for"
  in
  let horizontal =
    example
      ~id:"showcase-metadata-horizontal"
      ~orientation:Astryx.Metadata_list.Horizontal
      "horizontal: pairs in a wrapping row, where the label is stacked whatever is asked for"
  in
  let examples : Vdom.Node.t list Bonsai.t =
    Bonsai.map2
      (Bonsai.map2 single multi ~f:(fun a b -> [ a; b ]))
      (Bonsai.map2 fixed (Bonsai.map2 truncated horizontal ~f:(fun c d -> [ c; d ])) ~f:(fun c d ->
         c :: d))
      ~f:(fun ab cd -> ab @ cd)
  in
  Bonsai.map examples ~f:(fun examples ->
    section
        ~id:"metadata-list"
        ~title:"MetadataList"
        ~note:
          "Terms and values as a real <dl>. Two things are worth knowing. The layout belongs to the list, \
           not to the items: a single-column grid puts each term and value on a row of their own (stacked), \
           a two-column grid puts them side by side, and the item renders the pair as a fragment so either \
           works. And a stacked pair sits slightly further apart here than upstream, because upstream wraps \
           the pair in a flex column with a half-step gap while a grid row gap is a full step."
      examples)
;;

(* MoreMenu is a delegation and nothing else, which is worth showing precisely because there is so little to
   see: the same entries as the menu above, a trigger that is a ghost icon-only button, and - for the third
   example - an open state the demo owns. Its marker says MoreMenu rather than Button, which is the whole
   point of passing a component name down. *)
let more_menu_demo (graph : Bonsai.graph) =
  let selected, set_selected = Bonsai.state (None : string option) graph in
  let on_select =
    Bonsai.map set_selected ~f:(fun set_selected (item : Dm.item) -> set_selected (Some item.id))
  in
  let default = Astryx.More_menu.view ~id:"more-menu" ~on_select ~items:demo_menu_entries graph in
  let named =
    Astryx.More_menu.view
      ~id:"more-menu-named"
      ~label:"Actions"
      ~on_select
      ~items:demo_menu_entries
      graph
  in
  let controlled_open, set_controlled_open = Bonsai.state false graph in
  let controlled =
    Astryx.More_menu.view
      ~id:"more-menu-controlled"
      ~is_open:controlled_open
      ~on_open_change:set_controlled_open
      ~on_select
      ~items:demo_menu_entries
      graph
  in
  let controlled_state =
    Bonsai.map2 controlled_open set_controlled_open ~f:(fun value setter -> value, setter)
  in
  let controlled_example =
    Bonsai.map2 controlled_state controlled ~f:(fun (is_open, set_is_open) controlled ->
      ex
        "controlled from the outside, like the menu above"
        (Vdom.Node.div
           [ Astryx.Button.view
               ~label:(sprintf "Turn it %s from here" (if is_open then "off" else "on"))
               ~attrs:[ Vdom.Attr.id "more-menu-controlled-toggle" ]
               ~on_click:(fun _ -> set_is_open (not is_open))
               []
           ; controlled
           ]))
  in
  let pair a b = Bonsai.map2 a b ~f:(fun a b -> a, b) in
  Bonsai.map2
    (pair selected (pair default named))
    controlled_example
    (* The selection is written and never read here - the menu above prints it. *)
    ~f:(fun (_selected, (default, named)) controlled_example ->
      section
        ~id:"moremenu"
        ~title:"MoreMenu"
        ~note:
          "A menu whose trigger is one icon-only ghost button. There is nothing here that the menu above \
           does not do - which is the point: MoreMenu holds no behaviour of its own, it configures the menu \
           underneath (variant, size, icon-only, a label that becomes the accessible name) and passes its \
           own name down so the marker on the trigger says MoreMenu rather than Button. It can be controlled \
           the same way, because the menu can be."
        [ ex "the default trigger: an icon-only ghost button named More" default
        ; ex "a label of its own, which becomes the accessible name" named
        ; controlled_example
        ])
;;
(* ProgressBar takes a graph because its marks are Tooltips, and a Tooltip owns its open state - the bar
   without marks has nothing stateful in it, but the shape is the same either way. The consequence is the one
   MetadataList has: the jsdom gate cannot render it, so its checks measure the fill in Chromium. *)
let progress_bar_demo (graph : Bonsai.graph) =
  let p = Astryx.Progress_bar.view in
  let example ?value ?max ?has_value_label ?variant ?is_indeterminate ?is_disabled ?marks ~id label =
    Bonsai.map
      (p ?value ?max ?has_value_label ?variant ?is_indeterminate ?is_disabled ?marks ~id ~label graph)
      ~f:(fun node -> ex label node)
  in
  let plain = example ~id:"progress-plain" ~value:60. "value 60 of 100, no value label" in
  let labelled =
    example
      ~id:"progress-labelled"
      ~value:60.
      ~has_value_label:true
      "the same bar reporting its value, formatted as a whole percent"
  in
  let marks : Astryx.Progress_bar.mark list =
    [ { value = 25.; label = "25%: the first checkpoint" }
    ; { value = 50.; label = "50%: half" }
    ; { value = 90.; label = "90%: nearly there" }
    ]
  in
  let marked =
    example
      ~id:"progress-marked"
      ~value:60.
      ~has_value_label:true
      ~marks
      "three marks, each a focusable tick with a Tooltip - Tab to one to read it"
  in
  let indeterminate =
    example
      ~id:"progress-indeterminate"
      ~is_indeterminate:true
      "indeterminate: no value to report, and the animation stops under prefers-reduced-motion"
  in
  let four =
    Bonsai.map4
      (Astryx.Progress_bar.view ~id:"progress-accent" ~value:45. ~label:"Accent" graph)
      (Astryx.Progress_bar.view ~id:"progress-success" ~value:45. ~variant:Astryx.Progress_bar.Success ~label:"Success" graph)
      (Astryx.Progress_bar.view ~id:"progress-warning" ~value:45. ~variant:Astryx.Progress_bar.Warning ~label:"Warning" graph)
      (Astryx.Progress_bar.view
         ~id:"progress-disabled"
         ~value:40.
         ~is_disabled:true
         ~label:"Disabled"
         graph)
      ~f:(fun a b c d -> Vdom.Node.div [ a; b; c; d ])
  in
  let variants = Bonsai.map four ~f:(fun four -> ex "variants, and a disabled bar" four) in
  let first = Bonsai.map2 plain labelled ~f:(fun plain labelled -> [ plain; labelled ]) in
  let rest =
    Bonsai.map3 marked indeterminate variants ~f:(fun marked indeterminate variants ->
      [ marked; indeterminate; variants ])
  in
  Bonsai.map2 first rest ~f:(fun first rest ->
      section
      ~id:"progressbar"
      ~title:"ProgressBar"
      ~note:
        "A bar with a value, a track and a fill. The role is on the track and the label sits outside it, \
         pointing in with aria-labelledby, so a label hidden from view still names the bar. Marks are labelled \
         points: each is a focusable tick outside the progressbar role, wrapped in the port's Tooltip, which \
         is why the component takes a graph at all."
      (first @ rest))
;;
let overflow_list_demo (graph : Bonsai.graph) =
  (* The items carry fixed widths so the arithmetic is observable from outside: a row of known widths
     collapses at a predictable count, which is what the browser gate measures. A caller's items need no
     width at all - they just have to be measurable. *)
  let item ~label ~px =
    Vdom.Node.div
      ~attrs:[ Vdom.Attr.create "style" ("width: " ^ Int.to_string px ^ "px") ]
      [ Vdom.Node.text label ]
  in
  let items =
    [ item ~label:"one" ~px:90
    ; item ~label:"two" ~px:90
    ; item ~label:"three" ~px:110
    ; item ~label:"four" ~px:70
    ; item ~label:"five" ~px:120
    ; item ~label:"six" ~px:80
    ]
  in
  (* A width the items cannot all fit into, so something always has to collapse. *)
  let _fixed_width = "width: 320px" in
  (* And one whose width follows the window. This is not decoration: with a fixed width, resizing the
     browser changes nothing, so the observer would never fire and the live-resize path would never be
     exercised. A percentage width makes the count a function of the viewport, which is what the
     responsive gate can then assert across its four viewports. *)
  (* [vw], not a percentage. A percentage follows the PARENT, and the showcase's content column is
     width-constrained, so a percentage example does not change when the window does - the gate caught
     exactly that: a 700px wider viewport left the row at 438px and the count unmoved. [vw] follows the
     viewport, which is the thing the resize check actually changes. *)
  (* A third of the viewport, chosen so the example is genuinely BETWEEN the two answers: at the gate's
     width it overflows and at a wider one everything fits. At 50vw all six fitted at both widths, so
     nothing collapsed and the resize had nothing to change - the count was right and the check was
     vacuous, which is worse than a failure. *)
  let responsive_width = "width: 33vw; min-width: 160px" in
  let narrow =
    Astryx.Overflow_list.view
      ~gap:S.S2
      ~items
      ~attrs:[ Vdom.Attr.id "overflow-list-narrow"; Vdom.Attr.create "style" responsive_width ]
      graph
      ()
  in
  let from_start =
    Astryx.Overflow_list.view
      ~gap:S.S2
      ~collapse_from:Astryx.Overflow_list.Start
      ~items
      ~attrs:[ Vdom.Attr.id "overflow-list-start"; Vdom.Attr.create "style" responsive_width ]
      graph
      ()
  in
  let roomy =
    Astryx.Overflow_list.view
      ~gap:S.S2
      ~items
      ~attrs:[ Vdom.Attr.id "overflow-list-roomy"; Vdom.Attr.create "style" "width: 1400px" ]
      graph
      ()
  in
  let examples : Vdom.Node.t list Bonsai.t =
    unwrap_all
      [ Bonsai.map narrow
          ~f:
            (ex
               "half the window's width, so the count follows the window: what fits, and the rest behind \
               an indicator")
      ; Bonsai.map from_start
          ~f:
            (ex
               "collapse_from: Start keeps the other end instead - same width, same count, opposite end")
      ; Bonsai.map roomy ~f:(ex "room for all of them: no indicator at all")
      ]
  in
  Bonsai.map examples ~f:(fun examples ->
    section
      ~id:"overflow-list"
      ~title:"OverflowList"
      ~note:
        "Two containers: one hidden and measured with every item in it, one visible with only the slice. The count follows the real layout, so resizing the window changes it."
      examples)
;;

let page (graph : Bonsai.graph) =
  let interactive_section = interactive graph in
  let checkbox_section = checkbox_demo graph in
  let switch_section = switch_demo graph in
  let radio_list_section = radio_list_demo graph in
  let form_layout_section = form_layout_demo graph in
  let tooltip_section = tooltip_demo graph in
  let dialog_section = dialog_demo graph in
  let alert_dialog_section = alert_dialog_demo graph in
  let dialog_header_section = dialog_header_demo graph in
  let layer_section = layer_demo graph in
  let popover_section = popover_demo graph in
  let dropdown_section = dropdown_menu_demo graph in
  let field_section = field_demo graph in
  let text_area_section = text_area_demo graph in
  let metadata_list_section = metadata_list_demo graph in
  let more_menu_section = more_menu_demo graph in
  let progress_bar_section = progress_bar_demo graph in
  let avatar_section = avatar_demo graph in
  let avatar_group_section = avatar_group_demo graph in
  let toggle_button_section = toggle_button_demo graph in
  let selectable_card_section = selectable_card_demo graph in
  let overflow_list_section = overflow_list_demo graph in
  let thumbnail_section = thumbnail_demo graph in
  let scrollable_area_section = scrollable_area_demo graph in
  let pair a b = Bonsai.map2 a b ~f:(fun a b -> a, b) in
  let stateful =
    pair
      (pair interactive_section checkbox_section)
      (pair dropdown_section field_section)
  in
  let stateful = pair stateful switch_section in
  let stateful = pair stateful radio_list_section in
  let stateful = pair stateful form_layout_section in
  let stateful = pair stateful tooltip_section in
  let stateful = pair stateful dialog_section in
  let stateful = pair stateful alert_dialog_section in
  let stateful = pair stateful dialog_header_section in
  let stateful = pair stateful layer_section in
  let stateful = pair stateful popover_section in
  let stateful = pair stateful metadata_list_section in
  let stateful = pair stateful more_menu_section in
  let stateful = pair stateful progress_bar_section in
  let stateful = pair stateful avatar_section in
  let stateful = pair stateful avatar_group_section in
  let stateful = pair stateful toggle_button_section in
  let stateful = pair stateful selectable_card_section in
  let stateful = pair stateful overflow_list_section in
  let stateful = pair stateful thumbnail_section in
  let stateful = pair stateful scrollable_area_section in
  Bonsai.map2
    stateful
    text_area_section
    ~f:(fun (((((((((((((((((((((interactive, checkbox), (dropdown, field)), switch), radio_list), form_layout), tooltip), dialog), alert_dialog), dialog_header), layer), popover), metadata_list), more_menu), progress_bar), avatar), avatar_group), toggle_button), selectable_card), overflow_list), thumbnail), scrollable_area)
    text_area ->
Vdom.Node.div
      ~attrs:[ Vdom.Attr.class_ "showcase" ]
      [ nav ()
      ; Vdom.Node.main
          ~attrs:[ Vdom.Attr.class_ "main" ]
          (specs
           @ [ field; text_area; checkbox; switch; radio_list; form_layout; tooltip; dialog; alert_dialog; dialog_header; layer; popover; dropdown; interactive; metadata_list; more_menu; progress_bar; avatar; avatar_group; toggle_button; selectable_card; overflow_list; thumbnail; scrollable_area ])
      ])
;;

let () =
  Bonsai_web.Start.start ~bind_to_element_with_id:"astryx-showcase" page
;;
