open! Core
open! Bonsai_web

type variant =
  | Label
  | Number

type source =
  { title : string option
  ; url : string option
  ; src : string option
  ; icon : Vdom.Node.t option
  }

let source ?title ?url ?src ?icon () = { title; url; src; icon }

(* ---------------------------------------------------------------- URL safety

   Ported from upstream utils/safeUrl.ts, deliberately literally:

   - Control characters (\x00-\x1f and \x7f) are stripped *before* inspection. This is
     the part that matters: "java\0script:alert(1)" or "java\nscript:...." would sail
     past a naive prefix test, while a browser may still treat the result as a script
     URL. Strip first, then compare.
   - The comparison is case-insensitive, and spaces immediately *after* the scheme's
     colon are removed, so "javascript:  alert(1)" folds to "javascript:alert(1)" and is
     refused.
   - A space *before* the colon is a different thing and is deliberately left alone:
     "javascript :alert(1)" has no valid scheme, because a space is not a scheme
     character, so it is not a javascript: URL — browsers resolve it as a relative path.
     Upstream allows it and so does this port. It looks like a hole and is not one;
     refusing it would be inventing policy the original does not have.
   - javascript:, vbscript: and data:text/html are refused; anything else is allowed.

   The failure mode is "no href", never "citation disappears": a refused URL renders the
   pill as inert text, which is what upstream does. *)
let normalize_url url =
  String.filter url ~f:(fun c ->
    let code = Char.to_int c in
    not (code <= 0x1f || code = 0x7f))
  |> String.strip
;;

(* Folds the case and removes spaces that directly follow a leading scheme, so
   "JAVASCRIPT : x" and "javascript:x" compare equal. *)
let comparable_url normalized =
  let lower = String.lowercase normalized in
  let is_scheme_char c =
    Char.is_alphanum c || Char.equal c '+' || Char.equal c '.' || Char.equal c '-'
  in
  match String.index lower ':' with
  | None -> lower
  | Some colon ->
    let scheme = String.prefix lower colon in
    let scheme_well_formed =
      (not (String.is_empty scheme))
      && Char.is_alpha (String.get scheme 0)
      && String.for_all scheme ~f:is_scheme_char
    in
    if not scheme_well_formed
    then lower
    else (
      let rest = String.drop_prefix lower (colon + 1) |> String.lstrip in
      String.concat [ scheme; ":"; rest ])
;;

let is_safe_url url =
  let comparable = comparable_url (normalize_url url) in
  not
    (String.is_prefix comparable ~prefix:"javascript:"
     || String.is_prefix comparable ~prefix:"vbscript:"
     || String.is_prefix comparable ~prefix:"data:text/html")
;;

(* ------------------------------------------------------------------ render *)

let variant_string = function
  | Label -> "label"
  | Number -> "number"
;;

let safe_href = function
  | None -> None
  | Some url -> if is_safe_url url then Some url else None
;;

let view ?(variant = Label) ?(attrs = []) ~source ~number () =
  let { title; url; src; icon } = source in
  (* The visible label is the title when there is one, and the number when there is not:
     a citation with no title is still a citation. *)
  let title_text = Option.value title ~default:(Int.to_string number) in
  let href = safe_href url in
  let label = sprintf "Citation %d: %s" number title_text in
  let heading_role =
    match href with
    | Some _ -> "doc-noteref"
    | None ->
      (* doc-noteref is a link role, and it is not permitted on an inert span; without a
         permitted role the span would have no accessible name at all. group is
         supported everywhere and lets the aria-label below do the naming. *)
      "group"
  in
  let base_attrs =
    Common.Attr.class_
      [ "astryx-citation"
      ; sprintf "astryx-citation--%s" (variant_string variant)
      ; (if Option.is_some href then "astryx-citation--link" else "")
      ]
    @ Common.Attr.data "component" "Citation"
    @ Common.Attr.data "variant" (variant_string variant)
    @ Common.Attr.aria "label" label
    @ [ Vdom.Attr.role heading_role ]
    @ [ Vdom.Attr.create "title" title_text ]
    @ attrs
  in
  let link_attrs =
    match href with
    | None -> []
    | Some href ->
      [ Vdom.Attr.href href
      ; Vdom.Attr.create "target" "_blank"
      ; Vdom.Attr.create "rel" "noopener noreferrer"
      ]
  in
  let body =
    match variant with
    | Number -> [ Vdom.Node.text (Int.to_string number) ]
    | Label ->
      let icon_block =
        match icon, src with
        | None, None -> []
        | Some icon, _ ->
          (* A caller-supplied node wins over the image URL, as upstream does. *)
          [ Vdom.Node.span
              ~attrs:
                (Common.Attr.class_ [ "astryx-citation__icon" ]
                 @ Common.Attr.aria "hidden" "true")
              [ icon ]
          ]
        | None, Some src ->
          [ Vdom.Node.span
              ~attrs:
                (Common.Attr.class_ [ "astryx-citation__icon" ]
                 @ Common.Attr.aria "hidden" "true")
              [ Vdom.Node.img
                  ~attrs:
                    (Common.Attr.class_ [ "astryx-citation__icon-img" ]
                     @ [ Vdom.Attr.src src; Vdom.Attr.alt "" ])
                  ()
              ]
          ]
      in
      icon_block
      @ [ Vdom.Node.span
            ~attrs:(Common.Attr.class_ [ "astryx-citation__text" ])
            [ Vdom.Node.text title_text ]
        ]
  in
  match href with
  | Some _ -> Vdom.Node.a ~attrs:(base_attrs @ link_attrs) body
  | None -> Vdom.Node.span ~attrs:base_attrs body
;;
