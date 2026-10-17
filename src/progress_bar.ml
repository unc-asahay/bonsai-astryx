open! Core
open! Bonsai_web

type variant =
  | Accent
  | Success
  | Warning
  | Neutral
  | Error
;;

type mark =
  { value : float
  ; label : string
  }
;;

let variant_class = function
  | Accent -> "astryx-progress-bar__fill--accent"
  | Success -> "astryx-progress-bar__fill--success"
  | Warning -> "astryx-progress-bar__fill--warning"
  | Neutral -> "astryx-progress-bar__fill--neutral"
  | Error -> "astryx-progress-bar__fill--error"
;;

let default_format_value_label value max =
  (* [max] is also Core's polymorphic max, so the comparison is spelled out for floats rather than written
     with an operator that would resolve to the wrong one. *)
  let max_is_positive = Float.( > ) max 0. in
  let percentage = if max_is_positive then value /. max *. 100. else 0. in
  sprintf "%d%%" (Float.to_int (Float.round percentage))
;;

let view
  ?(attrs = [])
  ?(id = "astryx-progress-bar")
  ?(value = 0.)
  ?(max = 100.)
  ?(is_label_hidden = false)
  ?(has_value_label = false)
  ?(format_value_label = default_format_value_label)
  ?(variant = Accent)
  ?(is_indeterminate = false)
  ?(is_disabled = false)
  ?marks
  ~label
  graph
  =
  (* A value that is not a number, or a max that is not positive, would otherwise leak into the ARIA and into
     the width - the same two places upstream guards. *)
  let safe_value = if Float.is_finite value then value else 0. in
  let safe_max = if Float.is_finite max then max else 0. in
  let clamped = Float.min (Float.max 0. safe_value) safe_max in
  let percentage = if Float.(safe_max > 0.) then clamped /. safe_max *. 100. else 0. in
  let value_text = format_value_label clamped safe_max in
  let show_value_label = has_value_label && not is_indeterminate in
  let label_id = id ^ "-label" in
  let fill_class =
    String.concat
      ~sep:" "
      ([ "astryx-progress-bar__fill" ]
       @ [ (if is_disabled then "astryx-progress-bar__fill--disabled" else variant_class variant) ])
  in
  let fill =
    if is_indeterminate
    then Vdom.Node.div ~attrs:[ Vdom.Attr.class_ (fill_class ^ " astryx-progress-bar__fill--indeterminate") ] []
    else
      Vdom.Node.div
        ~attrs:
          [ Vdom.Attr.class_ fill_class
          ; Vdom.Attr.create "style" (sprintf "width:%.4f%%" percentage)
          ]
        []
  in
  let track =
    Vdom.Node.div
      ~attrs:
        ([ Vdom.Attr.class_
             ("astryx-progress-bar__track"
              ^ if is_indeterminate then " astryx-progress-bar__track--clipped" else "")
         ; Vdom.Attr.create "role" "progressbar"
         ; Vdom.Attr.create "aria-labelledby" label_id
         ]
         @ (if is_indeterminate
            then []
            else
              [ Vdom.Attr.create "aria-valuenow" (sprintf "%.0f" clamped)
              ; Vdom.Attr.create "aria-valuemin" "0"
              ; Vdom.Attr.create "aria-valuemax" (sprintf "%.0f" safe_max)
              ; Vdom.Attr.create "aria-valuetext" value_text
              ]))
      [ fill ]
  in
  (* Marks are ignored when the bar is indeterminate, and they sit outside the progressbar role so each tick
     stays focusable on its own. Each is a Tooltip, which is why this component needs the graph. *)
  let resolved_marks =
    match is_indeterminate, marks with
    | true, _ | false, None -> []
    | false, Some marks ->
      List.filter marks ~f:(fun mark -> Float.is_finite mark.value)
      |> List.mapi ~f:(fun index mark ->
        let clamped_mark = Float.min (Float.max 0. mark.value) safe_max in
        let mark_pct = if Float.(safe_max > 0.) then clamped_mark /. safe_max *. 100. else 0. in
        index, mark, mark_pct)
  in
  let marks_trees =
    List.map resolved_marks ~f:(fun (index, mark, mark_pct) ->
      let on_fill = Float.(percentage > 0. && mark_pct <= percentage) in
      let tick =
        Vdom.Node.div
          ~attrs:
            [ Vdom.Attr.class_
                (String.concat
                   ~sep:" "
                   ([ "astryx-progress-bar__mark" ]
                    @ [ (if on_fill then "astryx-progress-bar__mark--on-fill" else "astryx-progress-bar__mark--off-fill") ]
                    @ [ (if is_disabled then "astryx-progress-bar__mark--disabled" else "") ]))
            ; Vdom.Attr.create "style" (sprintf "inset-inline-start:%.4f%%" mark_pct)
            ; Vdom.Attr.create "tabindex" "0"
            ; Vdom.Attr.create "aria-label" mark.label
            ]
          []
      in
      Tooltip.view
        ~placement:Tooltip.Above
        ~id:(sprintf "%s-mark-%d" id index)
        ~content:mark.label
        ~trigger:tick
        graph)
  in
  let marks_node =
    List.fold marks_trees ~init:(Bonsai.return []) ~f:(fun acc tree ->
      Bonsai.map2 acc tree ~f:(fun acc node -> acc @ [ node ]))
  in
  Bonsai.map marks_node ~f:(fun marks_node ->
    let header =
      if (not is_label_hidden) || show_value_label
      then
        [ Vdom.Node.div
            ~attrs:[ Vdom.Attr.class_ "astryx-progress-bar__header" ]
            ([ Vdom.Node.span
                 ~attrs:
                   [ Vdom.Attr.class_
                       ("astryx-progress-bar__label"
                        ^ if is_label_hidden then " astryx-progress-bar__label--hidden" else ""
                        ^ if is_disabled then " astryx-progress-bar__label--disabled" else "")
                   ; Vdom.Attr.id label_id
                   ]
                 [ Vdom.Node.text label ]
             ]
             @ (if show_value_label
                then
                  [ Vdom.Node.span
                      ~attrs:
                        [ Vdom.Attr.class_
                            ("astryx-progress-bar__value"
                             ^ if is_disabled then " astryx-progress-bar__value--disabled" else "")
                        ]
                      [ Vdom.Node.text value_text ]
                  ]
                else []))
        ]
      else []
    in
    Vdom.Node.div
      ~attrs:
        ([ Vdom.Attr.class_ "astryx-progress-bar"
         ; (* The id names the root as well as prefixing the label and the marks, so the bar is findable by
              the name the caller gave it - the same rule MetadataList arrived at one milestone ago. *)
           Vdom.Attr.id id
         ]
         @ Common.Attr.data "component" "ProgressBar"
         @ attrs)
      (header @ [ Vdom.Node.div ~attrs:[ Vdom.Attr.class_ "astryx-progress-bar__track-container" ] (track :: marks_node) ]))
;;
