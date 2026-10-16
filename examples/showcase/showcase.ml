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
  Bonsai.map2 selected menu ~f:(fun selected menu ->
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
         does."
      [ ex "a menu button" menu
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
  let row nodes = Vdom.Node.div ~attrs:(Common.Attr.class_ [ "showcase-checkbox-row" ]) nodes in
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
          ~attrs:(Common.Attr.class_ [ "showcase-checkbox-children" ])
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
  let plain ?is_disabled ?is_read_only ?is_label_hidden ?is_optional ?is_required ~label ~id value =
    Checkbox_input.view
      ?is_disabled
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
  let row nodes = Vdom.Node.div ~attrs:(Common.Attr.class_ [ "showcase-switch-row" ]) nodes in
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
  let plain ?is_disabled ?is_label_hidden ?is_optional ?is_required ?size ~label ~id value =
    Switch.view
      ?is_disabled
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

let specs =
  [ s_stack (); s_text (); s_heading (); s_button (); s_badge (); s_card (); s_divider ()
  ; s_status_dot (); s_skeleton (); s_center (); s_section (); s_grid (); s_visually_hidden ()
  ; s_hstack (); s_vstack (); s_aspect_ratio ()
  ; s_icon_button (); s_code (); s_blockquote ()
  ; s_nav_icon (); s_empty_state (); s_citation ()
  ; s_icon (); s_field_status (); s_field_label (); s_indicator ()
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
  ; "field", "Field + TextInput"
  ; "textarea", "TextArea"
  ; "dropdownmenu", "DropdownMenu"
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
  let checkbox_section = checkbox_demo graph in
  let switch_section = switch_demo graph in
  let dropdown_section = dropdown_menu_demo graph in
  let field_section = field_demo graph in
  let text_area_section = text_area_demo graph in
  let pair a b = Bonsai.map2 a b ~f:(fun a b -> a, b) in
  let stateful =
    pair
      (pair interactive_section checkbox_section)
      (pair dropdown_section field_section)
  in
  let stateful = pair stateful switch_section in
  Bonsai.map2
    stateful
    text_area_section
    ~f:(fun (((interactive, checkbox), (dropdown, field)), switch) text_area ->
    Vdom.Node.div
      ~attrs:[ Vdom.Attr.class_ "showcase" ]
      [ nav ()
      ; Vdom.Node.main
          ~attrs:[ Vdom.Attr.class_ "main" ]
          (specs
           @ [ field; text_area; checkbox; switch; dropdown; interactive ])
      ])
;;

let () =
  Bonsai_web.Start.start ~bind_to_element_with_id:"astryx-showcase" page
;;
