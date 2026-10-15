(* Demo page for the ported components.

   Two jobs:
     1. it is the manual smoke test — build it, open it, look at it;
     2. it is the subject of the visual/parity harness, which screenshots this
        page and compares structural selectors against the upstream Storybook
        story of the same component.

   Everything here goes through the public [Astryx] API only, so the demo also
   proves the API is usable from outside the library. *)

open! Core
open! Bonsai_web

module S = Astryx.Common.Spacing
module A = Astryx.Common.Alignment

let section title children =
  Astryx.Stack.view
    ~gap:S.S5
    ~padding:S.S5
    ~align:A.Start
    (Astryx.Heading.view ~level:Astryx.Heading.H3 [ Vdom.Node.text title ] :: children)
;;

let buttons () =
  Astryx.Stack.view
    ~direction:Astryx.Stack.Horizontal
    ~gap:S.S3
    ~align:A.Center
    ~wrap:true
    [ Astryx.Button.view ~variant:Astryx.Button.Primary ~label:"Primary" []
    ; Astryx.Button.view ~variant:Astryx.Button.Secondary ~label:"Secondary" []
    ; Astryx.Button.view ~variant:Astryx.Button.Ghost ~label:"Ghost" []
    ; Astryx.Button.view ~variant:Astryx.Button.Destructive ~label:"Delete" []
    ]
;;

let badges () =
  Astryx.Stack.view
    ~direction:Astryx.Stack.Horizontal
    ~gap:S.S2
    ~wrap:true
    [ Astryx.Badge.view ~variant:Astryx.Badge.Neutral "Draft"
    ; Astryx.Badge.view ~variant:Astryx.Badge.Info "In review"
    ; Astryx.Badge.view ~variant:Astryx.Badge.Success "Shipped"
    ; Astryx.Badge.view ~variant:Astryx.Badge.Warning "Stale"
    ; Astryx.Badge.view ~variant:Astryx.Badge.Error "Failed"
    ]
;;

let card () =
  Astryx.Card.view
    ~padding:S.S4
    ~elevation:Astryx.Button.Low
    [ Astryx.Stack.view
        ~gap:S.S3
        [ Astryx.Text.view ~type_:Astryx.Text.Label [ Vdom.Node.text "Deploy status" ]
        ; Astryx.Stack.view
            ~direction:Astryx.Stack.Horizontal
            ~gap:S.S2
            ~align:A.Center
            [ Astryx.StatusDot.view ~variant:Astryx.StatusDot.Success ~label:"Healthy" ()
            ; Astryx.Text.view [ Vdom.Node.text "All three regions healthy" ]
            ]
        ; Astryx.Divider.view ()
        ; badges ()
        ]
    ]
;;

let loading () =
  Astryx.Stack.view
    ~direction:Astryx.Stack.Horizontal
    ~gap:S.S3
    ~align:A.Center
    [ Astryx.Skeleton.view ~width:(Astryx.Common.Size_value.Px 120) ~height:(Astryx.Common.Size_value.Px 12) ()
    ; Astryx.Skeleton.view ~width:(Astryx.Common.Size_value.Px 80) ~height:(Astryx.Common.Size_value.Px 12) ()
    ]
;;

let layout () =
  Astryx.Grid.view
    ~columns:(Astryx.Grid.Fixed 3)
    ~gap:S.S3
    ~align:A.Stretch
    [ Astryx.Center.view
        ~axis:Astryx.Center.Both
        ~padding:S.S3
        [ Astryx.Text.view ~type_:Astryx.Text.Supporting [ Vdom.Node.text "centered" ] ]
    ; Astryx.Section.view
        ~variant:Astryx.Section.Muted
        ~dividers:[ Astryx.Section.Top; Astryx.Section.Bottom ]
        ~padding:S.S3
        [ Astryx.Text.view [ Vdom.Node.text "section" ] ]
    ; Astryx.Center.view
        ~axis:Astryx.Center.Horizontal
        ~height:(Astryx.Common.Size_value.Px 40)
        [ Astryx.VisuallyHidden.view [ Vdom.Node.text "screen reader only" ] ]
    ]
;;

let page () =
  Astryx.Stack.view
    ~gap:S.S6
    ~padding:S.S6
    ~max_width:(Astryx.Common.Size_value.Px 880)
    [ Astryx.Heading.view
        ~level:Astryx.Heading.H1
        [ Vdom.Node.text "bonsai-astryx component demo" ]
    ; Astryx.Text.view
        ~type_:Astryx.Text.Supporting
        [ Vdom.Node.text "Every element below is rendered by the ported OCaml/Bonsai component." ]
    ; Astryx.Divider.view ()
    ; section "Buttons" [ buttons () ]
    ; section "Card + StatusDot + Badges" [ card () ]
    ; section
        "Button states"
        [ Astryx.Stack.view
            ~direction:Astryx.Stack.Horizontal
            ~gap:S.S3
            ~align:A.Center
            [ Astryx.Button.view ~label:"Save" ~is_loading:true []
            ; Astryx.Button.view ~label:"Disabled" ~is_disabled:true []
            ; Astryx.Button.view ~label:"Large" ~size:Astryx.Button.Lg []
            ]
        ]
    ; section "Layout primitives" [ layout () ]
    ; section "Skeleton" [ loading () ]
    ; Astryx.Text.view
        ~type_:Astryx.Text.Supporting
        [ Vdom.Node.text "milestone 2: 13 components ported" ]
    ]
;;

let () =
  Bonsai_web.Start.start ~bind_to_element_with_id:"astryx-demo" (fun _ -> Bonsai.return (page ()))
;;
