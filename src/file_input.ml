(* FileInput — a labelled file picker: the trigger is a real <input type="file">
   reached through a visually-hidden button, and the container is a
   non-interactive surface that opens the picker under the Clickable_container
   rules (the clear button is a plain sibling, so no nested-interactive
   violation).

   The port's file model (mli): the application gets metadata — name, size,
   MIME — read off the DOM File; the native input still holds the real objects
   and the picker, drag-drop and accept-filtering are the browser's. The byte
   stream belongs to the application's own File source, which is the one named
   divergence (there is no OCaml type for a live File, and nothing here stores
   a JS value in application state). *)

module Field_ = Field

open! Core
open! Bonsai_web
open Js_of_ocaml

type mode =
  | Input
  | Dropzone

type status_type = Field_status.type_ =
  | Warning
  | Error
  | Success

type status_variant = Field_status.placement =
  | Attached
  | Detached
  | Tooltip

type t =
  { name : string
  ; size : int
  ; mime : string
  }
[@@deriving sexp_of]

(* ----------------------------------------------------- reading the DOM File *)

(* One evaluator per field, the same shape as the port's other JS bridges: the
   browser knows the File API best and this hands back plain values. *)
let file_name (file : Js.Unsafe.any) : string =
  Js.to_string
    (Js.Unsafe.fun_call
       (Js.Unsafe.pure_js_expr "(function (f) { return f.name; })")
       [| Js.Unsafe.inject file |]
     : Js.js_string Js.t)
;;

let file_size (file : Js.Unsafe.any) : int =
  let size : float =
    Js.Unsafe.fun_call
      (Js.Unsafe.pure_js_expr "(function (f) { return f.size; })")
      [| Js.Unsafe.inject file |]
  in
  int_of_float size
;;

let file_mime (file : Js.Unsafe.any) : string =
  Js.to_string
    (Js.Unsafe.fun_call
       (Js.Unsafe.pure_js_expr "(function (f) { return f.type || ''; })")
       [| Js.Unsafe.inject file |]
     : Js.js_string Js.t)
;;

let files_from_js (files : Js.Unsafe.any) : t list =
  let n : int =
    Js.Unsafe.fun_call
      (Js.Unsafe.pure_js_expr "(function (fs) { return fs.length; })")
      [| Js.Unsafe.inject files |]
  in
  List.init n ~f:(fun i ->
    let file = Js.Unsafe.get files i in
    { name = file_name file; size = file_size file; mime = file_mime file })
;;

(* The input's change event: ev.target is the <input type=file>. *)
let files_of_input_event (ev : Dom_html.event Js.t) : t list =
  files_from_js
    (Js.Unsafe.fun_call
       (Js.Unsafe.pure_js_expr
          "(function (ev) { return ev.target && ev.target.files ? ev.target.files : []; })")
       [| Js.Unsafe.inject ev |])
;;

(* A drop event's dataTransfer.files — same answer, different accessor. *)
let files_of_drop_event (ev : Dom_html.dragEvent Js.t) : t list =
  files_from_js
    (Js.Unsafe.fun_call
       (Js.Unsafe.pure_js_expr
          "(function (ev) { var dt = ev.dataTransfer; return dt && dt.files ? dt.files : []; })")
       [| Js.Unsafe.inject ev |])
;;

let reset_input_value (ev : Dom_html.event Js.t) =
  (* Re-selecting the same file must fire change again, so the value is cleared
     after every pick — upstream clears its input ref for the same reason. The
     event's target IS the input. *)
  let (_ : unit) =
    Js.Unsafe.fun_call
      (Js.Unsafe.pure_js_expr "(function (ev) { if (ev.target) ev.target.value = ''; })")
      [| Js.Unsafe.inject ev |]
  in
  ()
;;

let open_picker (input_id : string) =
  (* The trigger is a real button; the native input is visually hidden and never
     focused (tabindex=-1), so activation reaches it through [click]. *)
  let (_ : unit) =
    Js.Unsafe.fun_call
      (Js.Unsafe.pure_js_expr
         "(function (id) { var el = document.getElementById(id); if (el) el.click(); })")
      [| Js.Unsafe.inject (Js.string input_id) |]
  in
  ()
;;

let prevent_default_event ev =
  (* Without preventDefault the browser refuses the drop — and drag events
     without it also leave the ghost. *)
  let (_ : unit) =
    Js.Unsafe.fun_call
      (Js.Unsafe.pure_js_expr "(function (ev) { ev.preventDefault(); })")
      [| Js.Unsafe.inject ev |]
  in
  ()
;;

(* ---------------------------------------------------------- pure validation *)

let format_file_size bytes =
  if bytes < 1024 then sprintf "%d B" bytes
  else if bytes < 1024 * 1024 then sprintf "%.1f KB" (Float.of_int bytes /. 1024.)
  else sprintf "%.1f MB" (Float.of_int bytes /. (1024. *. 1024.))
;;

let validate_files ?accept ?max_size ?max_files ?(is_multiple = false) files =
  let errors = ref [] in
  let valid = ref files in
  (match accept with
  | None -> ()
  | Some accept ->
    let accepted =
      String.split accept ~on:','
      |> List.map ~f:(fun s -> String.strip s |> String.lowercase)
      |> List.filter ~f:(Fn.non String.is_empty)
    in
    let matches file =
      List.exists accepted ~f:(fun type_ ->
        let lower = String.lowercase file.name in
        if String.is_prefix type_ ~prefix:"."
        then String.is_suffix lower ~suffix:type_
        else if String.is_suffix type_ ~suffix:"/*"
        then String.is_prefix (String.lowercase file.mime) ~prefix:(String.drop_suffix type_ 2)
        else String.equal (String.lowercase file.mime) type_)
    in
    valid := List.filter !valid ~f:(fun file ->
        if matches file
        then true
        else (
          errors := !errors @ [ sprintf "%s is not an accepted file type." file.name ];
          false)));
  (match max_size with
  | None -> ()
  | Some max_size ->
    valid := List.filter !valid ~f:(fun file ->
        if file.size <= max_size
        then true
        else (
          errors :=
            !errors @ [ sprintf "%s exceeds the %s limit." file.name (format_file_size max_size) ];
          false)));
  (match max_files with
  | Some max_files when is_multiple && List.length !valid > max_files ->
    errors := !errors @ [ sprintf "Too many files: the maximum is %d." max_files ];
    valid := List.take !valid max_files
  | _ -> ());
  (!valid, !errors)
;;

(* ------------------------------------------------------------ the container *)

module K = Common.Clickable_container

let surface_click ~is_disabled ~event_f (ev : Dom_html.mouseEvent Js.t) =
  if is_disabled
  then Effect.Ignore
  else (
    let root = Js.Unsafe.get ev "currentTarget" in
    let target_el = Js.Unsafe.get ev "target" in
    if K.has_text_selection root || K.is_interactive_target ~root ~target:target_el
    then Effect.Ignore
    else event_f ())
;;

let container_classes ~dropz ~drag_over ~is_disabled ~status =
  List.filter
    [ "astryx-file-input"
    ; (if dropz then "astryx-file-input--dropzone" else "astryx-file-input--compact")
    ; (if drag_over then "astryx-file-input--drag-over" else "")
    ; (if is_disabled then "astryx-file-input--disabled" else "")
    ; (match status with
      | Some { Input_types.type_ = Error; _ } -> "astryx-file-input--error"
      | Some { Input_types.type_ = Warning; _ } -> "astryx-file-input--warning"
      | Some { Input_types.type_ = Success; _ } -> "astryx-file-input--success"
      | None -> "")
    ]
    ~f:(Fn.non String.is_empty)
;;

let view
    ?(mode = Input)
    ?accept
    ?(is_multiple = false)
    ?max_size
    ?max_files
    ?(is_disabled = false)
    ?disabled_message
    ?(is_required = false)
    ?(is_optional = false)
    ?(is_loading = false)
    ?status
    ?(status_variant = Field_status.Attached)
    ?description
    ?placeholder
    ?width
    ?(attrs = [])
    ?(id = "astryx-file-input")
    ~label
    ~value
    ~on_change
    graph
  =
  let input_id = id ^ "-input" in
  let trigger_id = id ^ "-trigger" in
  let announce_id = id ^ "-announce" in
  let drag_over, set_drag_over = Bonsai.state false graph in
  let validation_error, set_validation_error = Bonsai.state None graph in
  let announcement, set_announcement = Bonsai.state None graph in
  let dropz = Poly.equal mode Dropzone in
  let shows_disabled_message = is_disabled && Option.is_some disabled_message in
  let busy = is_loading in
  let default_placeholder =
    if is_multiple then "Choose files" else "Choose file"
  in
  let display_placeholder = Option.value placeholder ~default:default_placeholder in
  (* The derived status: the caller's status wins, else the validation error. *)
  let status_t =
    match status with
    | Some s -> Bonsai.return (Some s)
    | None ->
      Bonsai.map validation_error ~f:(fun e ->
        Option.map e ~f:(fun msg -> { Input_types.type_ = Error; message = Some msg }))
  in
  (* The commit: validate → write the status → hand the selection to the
     application → announce a successful attach politely. Errors are announced
     assertively by the Field status that mounts them, so the announce here
     covers only the attach (upstream's forms-17 rule). *)
  let handle_files =
    Bonsai.map3 on_change set_validation_error set_announcement
      ~f:(fun on_change set_validation_error set_announcement ->
        fun files ->
          let valid, errors =
            validate_files ?accept ?max_size ?max_files ~is_multiple files
          in
          let error_effect =
            match errors with
            | first :: _ -> set_validation_error (Some first)
            | [] -> set_validation_error None
          in
          let change_effect =
            if List.is_empty valid
            then on_change None
            else
              let result = if is_multiple then valid else List.take valid 1 in
              on_change (Some result)
          in
          let announce_effect =
            match (List.is_empty errors, List.is_empty valid) with
            | true, false ->
              set_announcement
                (Some
                   (match valid with
                   | [ one ] -> sprintf "Attached: %s" one.name
                   | _ -> sprintf "Attached %d files" (List.length valid)))
            | _ -> Effect.Ignore
          in
          Effect.Many [ error_effect; change_effect; announce_effect ])
  in
  let container_t =
    let p1 = Bonsai.map2 handle_files value ~f:Tuple2.create in
    let p2 =
      Bonsai.map2 set_drag_over
        (Bonsai.map2 drag_over announcement ~f:Tuple2.create)
        ~f:Tuple2.create
    in
    Bonsai.map3 p1 status_t p2
      ~f:(fun (handle_files, value_now) status (set_drag_over, (drag_over, announcement)) ->
      let has_files =
        match value_now with
        | Some files -> not (List.is_empty files)
        | None -> false
      in
      let file_names =
        match value_now with
        | Some files when not (List.is_empty files) ->
          String.concat ~sep:", " (List.map files ~f:(fun f -> f.name))
        | _ -> ""
      in
      let status_classes = container_classes ~dropz ~drag_over ~is_disabled ~status in
      let drag_attrs =
        if is_disabled || not dropz
        then []
        else
          [ Vdom.Attr.on_dragenter (fun _ -> set_drag_over true)
          ; Vdom.Attr.on_dragover (fun ev ->
              prevent_default_event ev;
              set_drag_over true)
          ; Vdom.Attr.on_dragleave (fun _ -> set_drag_over false)
          ; Vdom.Attr.on_drop (fun ev ->
              let files = files_of_drop_event ev in
              prevent_default_event ev;
              Effect.Many
                [ set_drag_over false
                ; (if List.is_empty files then Effect.Ignore else handle_files files)
                ])
          ]
      in
      let trigger_accessible_name =
        if has_files && not (String.is_empty file_names)
        then sprintf "%s, %s" label file_names
        else label
      in
      let trigger_described_by =
        List.filter
          [ (if Option.is_some description then Some (trigger_id ^ "-desc") else None)
          ; (match (status, status_variant) with
            | (Some { Input_types.type_ = _; message = Some _ }, Tooltip) -> None
            | (Some { Input_types.type_ = _; message = Some _ }, _) ->
              Some (trigger_id ^ "-status")
            | _ -> None)
          ]
          ~f:Option.is_some
        |> List.map ~f:(fun o -> Option.value_exn o)
      in
      let trigger_described_by_attr =
        match trigger_described_by with
        | [] -> []
        | ids -> [ Vdom.Attr.create "aria-describedby" (String.concat ~sep:" " ids) ]
      in
      let trigger_button =
        Vdom.Node.create
          "button"
          ~attrs:
            ([ Vdom.Attr.id trigger_id
             ; Vdom.Attr.create "type" "button"
             ; Vdom.Attr.class_ "astryx-file-input__trigger astryx-visually-hidden"
             ; Vdom.Attr.create "aria-label" trigger_accessible_name
             ; Vdom.Attr.create "aria-busy" (string_of_bool busy)
             ; Vdom.Attr.create "style" "pointer-events:none"
             ; Vdom.Attr.create "tabindex"
                 (if shows_disabled_message then "0" else if is_disabled then "-1" else "0")
             ; (if is_disabled && not shows_disabled_message
                then Vdom.Attr.create "disabled" ""
                else Vdom.Attr.create "aria-disabled" "false")
             ; (match trigger_described_by_attr with
                | a :: _ -> a
                | [] -> Vdom.Attr.create "aria-describedby" "")
             ; (if is_required && not is_optional
                then Vdom.Attr.create "aria-required" "true"
                else Vdom.Attr.create "aria-required" "false")
             ; (match status with
               | Some { Input_types.type_ = Error; _ } -> Vdom.Attr.create "aria-invalid" "true"
               | _ -> Vdom.Attr.create "aria-invalid" "false")
             ]
            @ (if is_disabled
               then []
               else
                 [ Vdom.Attr.on_click (fun (_ : Dom_html.mouseEvent Js.t) ->
                      open_picker input_id;
                      Effect.Ignore)
                 ]))
          []
      in
      let native_extra =
        (match accept with Some a -> [ Vdom.Attr.create "accept" a ] | None -> [])
        @ (if is_multiple then [ Vdom.Attr.create "multiple" "" ] else [])
        @ (if is_disabled then [ Vdom.Attr.create "disabled" "" ] else [])
      in
      let native_input =
        Vdom.Node.create
          "input"
          ~attrs:
            ([ Vdom.Attr.id input_id
             ; Vdom.Attr.create "type" "file"
             ; Vdom.Attr.class_ "astryx-file-input__native"
             ; Vdom.Attr.create "aria-hidden" "true"
             ; Vdom.Attr.create "tabindex" "-1"
             ; Vdom.Attr.on_change (fun ev _ ->
                 let files = files_of_input_event ev in
                 reset_input_value ev;
                 let effect = handle_files files in
                 effect)
             ]
            @ native_extra
            @ Common.Attr.style [ "display", "none" ])
          []
      in
      let content =
        if busy
        then [ Spinner.view () ]
        else if has_files
        then [ Vdom.Node.span ~attrs:[ Vdom.Attr.class_ "astryx-file-input__filename" ] [ Vdom.Node.text file_names ] ]
        else
          [ Icon.view ~name:"upload" ()
          ; Vdom.Node.span
              ~attrs:(Common.Attr.class_ [ "astryx-file-input__placeholder" ])
              [ Vdom.Node.text
                  (if dropz && drag_over then "Drop files here" else display_placeholder)
              ]
          ]
      in
      let clear_button =
        if has_files && (not is_disabled) && not busy
        then
          [ Vdom.Node.create
              "button"
              ~attrs:
                [ Vdom.Attr.create "type" "button"
                ; Vdom.Attr.class_ "astryx-file-input__clear"
                ; Vdom.Attr.create "aria-label" "Clear file"
                ; Vdom.Attr.on_click (fun (_ : Dom_html.mouseEvent Js.t) -> handle_files [])
                ]
              [ Vdom.Node.text "Remove" ]
          ]
        else []
      in
      let announce_node =
        Vdom.Node.div
          ~attrs:
            [ Vdom.Attr.id announce_id
            ; Vdom.Attr.class_ "astryx-visually-hidden"
            ; Vdom.Attr.create "role" "status"
            ]
          [ Vdom.Node.text (Option.value announcement ~default:"") ]
      in
      Vdom.Node.div
        ~attrs:
          (Common.Attr.class_ status_classes
          @ Common.Attr.data "component" "FileInput"
          @ [ Vdom.Attr.id id ]
          @ (if shows_disabled_message
             then [ Vdom.Attr.create "data-disabled-message" "true" ]
             else [])
          @ (if is_disabled
             then []
             else [ Vdom.Attr.on_click (surface_click ~is_disabled:false ~event_f:(fun () -> open_picker input_id; Effect.Ignore)) ])
          @ drag_attrs
          @ attrs)
        (trigger_button :: native_input :: (content @ clear_button @ [ announce_node ])))
  in
  Bonsai.map container_t ~f:(fun container ->
    let reason_node =
      match (is_disabled, disabled_message) with
      | true, Some msg ->
        [ Vdom.Node.div
            ~attrs:[ Vdom.Attr.class_ "astryx-file-input__reason" ]
            [ Vdom.Node.text msg ]
        ]
      | _ -> []
    in
    Field_.view
      ~label
      ~input_id:trigger_id
      ?description
      ?status
      ~status_variant
      ~is_required
      ~is_optional
      ~is_disabled
      ?width
      ~children:(container :: reason_node)
      ())
;;
