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
  Bonsai.map2 count set_count ~f:(fun count set_count ->
    section
      ~id:"interactive"
      ~title:"Interactive"
      ~note:
        "Stateful: the button's on_click increments a Bonsai state value. The browser gate \
         clicks it and reads the counter back."
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

let specs =
  [ s_stack (); s_text (); s_heading (); s_button (); s_badge (); s_card (); s_divider ()
  ; s_status_dot (); s_skeleton (); s_center (); s_section (); s_grid (); s_visually_hidden ()
  ; s_hstack (); s_vstack (); s_aspect_ratio ()
  ; s_icon_button (); s_code (); s_blockquote ()
  ; s_nav_icon (); s_empty_state (); s_citation ()
  ; s_icon ()
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
  ; "interactive", "Interactive"
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

let page (graph : Bonsai.graph) =
  let interactive_section = interactive graph in
  Bonsai.map interactive_section ~f:(fun interactive_section ->
    Vdom.Node.div
      ~attrs:[ Vdom.Attr.class_ "showcase" ]
      [ nav ()
      ; Vdom.Node.main
          ~attrs:[ Vdom.Attr.class_ "main" ]
          (specs @ [ interactive_section ])
      ])
;;

let () =
  Bonsai_web.Start.start ~bind_to_element_with_id:"astryx-showcase" page
;;
