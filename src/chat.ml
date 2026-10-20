(* Chat — the conversation surface: a transcript of messages and a composer.

   Upstream's Chat is a family of components (ChatLayout, ChatMessageList,
   ChatMessage, ChatMessageBubble, ChatMessageMetadata, ChatComposer,
   ChatComposerInput, ChatSendButton) composed through React context. This
   port folds them into one module: a message is a record and a transcript is
   a list of records, so the two things the context carried — the sender and
   the density — are ordinary fields.

   What upstream shows is kept. The transcript is a polite log, so a screen
   reader announces a message as it arrives. A message is an article aligned
   by its sender, with an optional avatar, an optional author name, a bubble
   and a metadata row; a run of messages from one author tightens the
   bubble's corners on the joined side, so the run reads as one block. The
   composer is a controlled input with a send action, which a stop action
   replaces while a response streams, and the send action is live only when
   there is something to send.

   Two divergences are worth repeating here; both are recorded in chat.mli.
   Upstream has no per-message editing at all, so the editor in this port is
   a house extension: a chat surface that cannot take a message back is not
   the surface the CLI ships. And the composer's status line is a plain
   string here, where upstream's composer status carries a severity of its
   own.

   A component here is a Bonsai model of a node, as everywhere in this
   library, and the models a caller hands in — the composer's text, the
   editor's draft — are combined with the ones this module builds rather
   than stored in it. *)

open! Core
open! Bonsai_web

module Attr = Common.Attr

(* ------------------------------------------------------------------ types *)

type sender =
  | User
  | Assistant
  | System

type density =
  | Compact
  | Balanced
  | Spacious

type group =
  | First
  | Middle
  | Last

type status =
  | Sending
  | Sent
  | Delivered
  | Read
  | Failed

type variant =
  | Filled
  | Ghost

type align =
  | Top
  | Bottom

type elevation =
  | Low
  | Flat

type status_position =
  | Top
  | Bottom

type thread =
  | Ready
  | Loading
  | Empty
  | Error of string

type edit =
  { edit_value : string Bonsai.t
  ; on_change : (string -> unit Effect.t) Bonsai.t
  ; on_save : (string -> unit Effect.t) Bonsai.t
  ; on_cancel : (unit -> unit Effect.t) Bonsai.t
  }

type message =
  { sender : sender
  ; content : Vdom.Node.t list
  ; author : string option
  ; avatar : Vdom.Node.t option
  ; timestamp : Timestamp.value option
  ; status : status option
  ; group : group option
  ; variant : variant
  ; footer : Vdom.Node.t option
  ; edit : edit option
  ; density : density option
  }

type composer =
  { value : string Bonsai.t
  ; on_change : (string -> unit Effect.t) Bonsai.t
  ; on_submit : (string -> unit Effect.t) Bonsai.t
  ; on_stop : (unit -> unit Effect.t) Bonsai.t
  ; is_stop_shown : bool
  ; is_disabled : bool
  ; is_sending : bool
  ; placeholder : string
  ; density : density
  ; elevation : elevation
  ; status : string option
  ; status_position : status_position
  ; input : Vdom.Node.t option
  }

(* ------------------------------------------------------------------ names *)

let sender_name : sender -> string = function
  | User -> "user"
  | Assistant -> "assistant"
  | System -> "system"
;;

let density_name : density -> string = function
  | Compact -> "compact"
  | Balanced -> "balanced"
  | Spacious -> "spacious"
;;

let group_name : group -> string = function
  | First -> "first"
  | Middle -> "middle"
  | Last -> "last"
;;

let status_name : status -> string = function
  | Sending -> "sending"
  | Sent -> "sent"
  | Delivered -> "delivered"
  | Read -> "read"
  | Failed -> "failed"
;;

let status_label : status -> string = function
  | Sending -> "Sending"
  | Sent -> "Sent"
  | Delivered -> "Delivered"
  | Read -> "Read"
  | Failed -> "Failed"
;;

let status_icon : status -> string = function
  | Sending -> "clock"
  | Sent -> "check"
  | Delivered -> "checkDouble"
  | Read -> "checkDouble"
  | Failed -> "error"
;;

(* Upstream's own names for a sender, in the words a screen reader gets:
   the article is labelled by the author when there is one, and by the
   sender otherwise. *)
let sender_fallback_label : sender -> string = function
  | User -> "Message from you"
  | Assistant -> "Message from the assistant"
  | System -> "System notice"
;;

(* A fresh id per rendered message, the way upstream's useId gives every
   article its own name reference. Allocated once per message, when the
   transcript is built, so it survives re-renders. *)
let next_name_id = ref 0

let fresh_name_id () =
  incr next_name_id;
  sprintf "chat-message-name-%d" !next_name_id
;;

(* ---------------------------------------------------------------- message *)

let message
      ?author
      ?avatar
      ?timestamp
      ?status
      ?group
      ?(variant = Filled)
      ?footer
      ?edit
      ?density
      ~sender
      ~content
      ()
  : message
  =
  { sender
  ; content
  ; author
  ; avatar
  ; timestamp
  ; status
  ; group
  ; variant
  ; footer
  ; edit
  ; density
  }
;;

(* The editor of a message being edited. A house extension: upstream has no
   message-level editing surface at all, so there is no upstream shape to
   copy — only the house's controlled-input shape. *)
let edit_node (edit : edit) =
  let with_change = Bonsai.map2 edit.edit_value edit.on_change ~f:(fun value on_change -> value, on_change) in
  let with_save = Bonsai.map2 with_change edit.on_save ~f:(fun (value, on_change) on_save -> value, on_change, on_save) in
  let all = Bonsai.map2 with_save edit.on_cancel ~f:(fun (value, on_change, on_save) on_cancel -> value, on_change, on_save, on_cancel) in
  Bonsai.map all ~f:(fun (value, on_change, on_save, on_cancel) ->
    let input =
      Vdom.Node.textarea
        ~attrs:
          (Attr.class_ [ "astryx-chat__editor-input" ]
           @ Attr.aria "label" "Edit message"
           @ [ Vdom.Attr.on_input (fun _ value -> on_change value) ])
        [ Vdom.Node.text value ]
    in
    let save =
      Button.view
        ~label:"Save"
        ~variant:Button.Primary
        ~size:Button.Sm
        ~on_click:(fun _ -> on_save value)
        []
    in
    let cancel =
      Button.view
        ~label:"Cancel"
        ~variant:Button.Secondary
        ~size:Button.Sm
        ~on_click:(fun _ -> on_cancel ())
        []
    in
    Vdom.Node.div
      ~attrs:(Attr.class_ [ "astryx-chat__editor" ])
      [ input
      ; Vdom.Node.div
          ~attrs:(Attr.class_ [ "astryx-chat__editor-actions" ])
          [ save; cancel ]
      ])
;;

(* The article, its column, the bubble and the metadata row. Everything here
   is a pure function of the message, so the same message always renders the
   same way. *)
let message_node ~(message : message) ~density ~name_id ~timestamp_node ~edit_node =
  let sender = message.sender in
  let is_system = Poly.equal sender System in
  let has_avatar = (not is_system) && Option.is_some message.avatar in
  let has_author = (not is_system) && Option.is_some message.author in
  let has_metadata =
    (not is_system)
    && ( Option.is_some message.timestamp
       || Option.is_some message.footer
       || Option.is_some message.status )
  in
  let bubble_classes =
    [ "astryx-chat__bubble" ]
    @ (match message.variant with
       | Filled -> []
       | Ghost -> [ "astryx-chat__bubble--ghost" ])
    @ (match message.group with
       | None -> []
       | Some group -> [ "astryx-chat__bubble--group-" ^ group_name group ])
  in
  (* While a message is being edited the editor takes the bubble's place:
   the draft is what the reader is looking at. *)
  let body =
    match message.edit with
    | Some _ -> [ edit_node ]
    | None ->
      message.content
      @ (match message.footer with
         | Some footer -> [ footer ]
         | None -> [])
  in
  let bubble = Vdom.Node.div ~attrs:(Attr.class_ bubble_classes) body in
  (* Upstream's ChatMessageMetadata: the timestamp, then the status, with a
     dot between the slots that are present. *)
  let status_node =
    match message.status with
    | None -> []
    | Some status ->
      let label = status_label status in
      [ Vdom.Node.span
          ~attrs:
            (Attr.class_
               ([ "astryx-chat__status" ]
                @ (match status with
                   | Failed -> [ "astryx-chat__status--failed" ]
                   | _ -> [])
                @ (match status with
                   | Sending -> [ "astryx-chat__status--sending" ]
                   | _ -> []))
            @ Attr.aria "label" ("Message status: " ^ label)
            @ Attr.data "status" (status_name status)
            @ [ Vdom.Attr.create "title" label ])
          [ Icon.view ~name:(status_icon status) ~size:Icon.Xsm ~color:Icon.Inherit ()
          ; Vdom.Node.text label
          ]
      ]
  in
  let metadata_node =
    if not has_metadata
    then []
    else
      let timestamp_part =
        match message.timestamp with
        | Some _ -> [ Vdom.Node.span ~attrs:[] [ timestamp_node ] ]
        | None -> []
      in
      let has_status = not (List.is_empty status_node) in
      let dot () =
        [ Vdom.Node.span
            ~attrs:(Attr.class_ [ "astryx-chat__metadata-separator" ])
            [ Vdom.Node.text "·" ]
        ]
      in
      [ Vdom.Node.div
          ~attrs:(Attr.class_ [ "astryx-chat__metadata" ])
          (timestamp_part
          @ (if (not (List.is_empty timestamp_part)) && has_status then dot () else [])
          @ status_node)
      ]
  in
  let avatar_node =
    match message.avatar with
    | Some avatar when has_avatar ->
      [ Vdom.Node.div
          ~attrs:(Attr.class_ [ "astryx-chat__avatar" ])
          [ avatar ]
      ]
    | _ -> []
  in
  let author_node =
    match message.author with
    | Some author when has_author ->
      [ Vdom.Node.div
          ~attrs:
            (Attr.class_ [ "astryx-chat__author" ]
             @ [ Vdom.Attr.create "id" name_id ])
          [ Vdom.Node.text author ]
      ]
    | _ -> []
  in
  let density_classes =
    match density with
    | Compact -> [ "astryx-chat__message--compact" ]
    | Balanced -> []
    | Spacious -> [ "astryx-chat__message--spacious" ]
  in
  Vdom.Node.article
    ~attrs:
      (Attr.class_
         ([ "astryx-chat__message" ]
          @ (match sender with
             | User -> [ "astryx-chat__message--user" ]
             | System -> [ "astryx-chat__message--system" ]
             | Assistant -> [])
          @ density_classes)
       @ Attr.data "sender" (sender_name sender)
       @ Attr.data "density" (density_name density)
       @ Attr.data "variant"
           (match message.variant with
            | Filled -> "filled"
            | Ghost -> "ghost")
       @ (if has_author
          then Attr.aria "labelledby" name_id
          else Attr.aria "label" (sender_fallback_label sender)))
    (avatar_node
    @ [ Vdom.Node.div
        ~attrs:(Attr.class_ [ "astryx-chat__column" ])
        (author_node @ [ bubble ] @ metadata_node) ])
;;

(* The model of one message: the timestamp (the house Timestamp component,
   as upstream's chat does) and, when the message is being edited, the
   editor. *)
let message_tree ~(message : message) ~density ~graph =
  let density = Option.value message.density ~default:density in
  let name_id = fresh_name_id () in
  let timestamp_tree =
    match message.timestamp with
    | None -> Bonsai.return Vdom.Node.none
    | Some value -> Timestamp.view ~value ~format:Timestamp.Time ~has_tooltip:false graph
  in
  let edit_tree =
    match message.edit with
    | None -> Bonsai.return Vdom.Node.none
    | Some edit -> edit_node edit
  in
  Bonsai.map2 timestamp_tree edit_tree ~f:(fun timestamp_node edit_node ->
    message_node ~message ~density ~name_id ~timestamp_node ~edit_node)
;;

(* ------------------------------------------------------------- transcript *)

(* The log region. A screen reader announces what arrives in it, and it
   scrolls: a conversation reads from the bottom. *)
let message_log ?id ?(attrs = []) ?(density = Balanced) ?(align = (Bottom : align)) ?(thread = Ready) ~messages graph () =
  let message_trees =
    List.map messages ~f:(fun message -> message_tree ~message ~density ~graph)
  in
  let nodes =
    List.fold message_trees ~init:(Bonsai.return []) ~f:(fun acc tree ->
      Bonsai.map2 acc tree ~f:(fun acc node -> acc @ [ node ]))
  in
  Bonsai.map nodes ~f:(fun nodes ->
    let body =
      match thread with
      | Ready -> nodes
      | Loading ->
        [ Vdom.Node.div
            ~attrs:(Attr.class_ [ "astryx-chat__loading" ])
            [ Spinner.view ~size:Spinner.Md () ]
        ]
      | Empty ->
        [ Vdom.Node.div
            ~attrs:(Attr.class_ [ "astryx-chat__empty" ])
            [ Vdom.Node.text "No messages yet" ]
        ]
      | Error reason ->
        [ Vdom.Node.div
            ~attrs:(Attr.class_ [ "astryx-chat__error" ])
            [ Vdom.Node.text reason ]
        ]
    in
    Vdom.Node.div
      ~attrs:
        (Attr.class_
           ([ "astryx-chat__log" ]
            @ (match align with
               | Bottom -> [ "astryx-chat__log--align-bottom" ]
               | Top -> []))
         @ Attr.data "density" (density_name density)
         @ Attr.data "align"
             (match align with
              | Top -> "top"
              | Bottom -> "bottom")
         @ Attr.data "thread"
             (match thread with
              | Ready -> "ready"
              | Loading -> "loading"
              | Empty -> "empty"
              | Error _ -> "error")
         @ [ Vdom.Attr.role "log"
           ; Vdom.Attr.create "aria-live" "polite"
           ; Vdom.Attr.create "tabindex" "0"
           ]
         @ (match id with
            | Some id -> [ Vdom.Attr.create "id" id ]
            | None -> [])
         @ attrs)
      body)
;;

let message_list ?id ?(attrs = []) ?density ?(align = (Bottom : align)) ?thread ~messages graph () =
  message_log ?id ~attrs ?density ~align ?thread ~messages graph ()
;;

(* --------------------------------------------------------------- composer *)

let composer_node ?id ?(attrs = []) (composer : composer) () =
  let c = composer in
  let with_change = Bonsai.map2 c.value c.on_change ~f:(fun value on_change -> value, on_change) in
  let with_submit = Bonsai.map2 with_change c.on_submit ~f:(fun (value, on_change) on_submit -> value, on_change, on_submit) in
  let all = Bonsai.map2 with_submit c.on_stop ~f:(fun (value, on_change, on_submit) on_stop -> value, on_change, on_submit, on_stop) in
  Bonsai.map all ~f:(fun (value, on_change, on_submit, on_stop) ->
    let trimmed = String.strip value in
    (* The send action is live only when there is something to send, the
       composer is usable, and no send is already on its way. *)
    let can_send =
      (not (String.is_empty trimmed))
      && (not c.is_disabled)
      && (not c.is_sending)
    in
    let submit () = if can_send then on_submit trimmed else Effect.Ignore in
    (* Upstream's ChatSendButton: an icon-only button that is the send
       action until the stop action takes its place. *)
    let send_button =
      if c.is_stop_shown
      then
        Button.view
          ~label:"Stop"
          ~variant:Button.Secondary
          ~size:Button.Md
          ~icon:(Icon.view ~name:"stop" ~size:Icon.Md ~color:Icon.Inherit ())
          ~is_icon_only:true
          ~on_click:(fun _ -> on_stop ())
          []
      else
        Button.view
          ~label:"Send"
          ~variant:Button.Primary
          ~size:Button.Md
          ~icon:(Icon.view ~name:"arrowUp" ~size:Icon.Md ~color:Icon.Inherit ())
          ~is_icon_only:true
          ~is_loading:c.is_sending
          ~is_disabled:(not can_send)
          ~on_click:(fun _ -> submit ())
          []
    in
    let input_node =
      match c.input with
      | Some input -> input
      | None ->
        Vdom.Node.textarea
          ~attrs:
            (Attr.class_ [ "astryx-chat__input" ]
             @ Attr.aria "label" "Message input"
             @ [ Vdom.Attr.create "placeholder" c.placeholder
               ; Vdom.Attr.on_input (fun _ value ->
                   if c.is_disabled then Effect.Ignore else on_change value)
               ; Vdom.Attr.on_keydown (fun ev ->
                   let key = Option.value (Common.string_prop ev "key") ~default:"" in
                   let shift = Common.bool_prop ev "shiftKey" in
                   if String.equal key "Enter" && not shift
                   then (
                     Common.prevent_default ev;
                     submit ())
                   else Effect.Ignore)
               ]
             @ (if c.is_disabled then [ Vdom.Attr.disabled' true ] else []))
          [ Vdom.Node.text value ]
    in
    let status_node =
      match c.status with
      | None -> []
      | Some text ->
        [ Vdom.Node.div
            ~attrs:(Attr.class_ [ "astryx-chat__status-line" ])
            [ Vdom.Node.text text ]
        ]
    in
    let row =
      [ Vdom.Node.div
          ~attrs:(Attr.class_ [ "astryx-chat__composer-row" ])
          [ input_node; send_button ]
      ]
    in
    let children =
      match c.status_position with
      | Top -> status_node @ row
      | Bottom -> row @ status_node
    in
    Vdom.Node.div
      ~attrs:
        (Attr.class_
           ([ "astryx-chat__composer" ]
            @ (match c.elevation with
               | Low -> [ "astryx-chat__composer--low" ]
               | Flat -> [ "astryx-chat__composer--flat" ]))
         @ Attr.data "density" (density_name c.density)
         @ Attr.data "elevation"
             (match c.elevation with
              | Low -> "low"
              | Flat -> "flat")
         @ Attr.data "state"
             (if c.is_disabled
              then "disabled"
              else if c.is_sending
              then "sending"
              else "ready")
         @ (match id with
            | Some id -> [ Vdom.Attr.create "id" id ]
            | None -> [])
         @ attrs)
      children)
;;

let composer_view ?id ?(attrs = []) ~composer _graph () =
  composer_node ?id ~attrs composer ()
;;

(* ------------------------------------------------------------------ whole *)

let view ?id ?(attrs = []) ?(density = Balanced) ?(align = (Bottom : align)) ?(thread = Ready) ?composer ~messages graph () =
  let log = message_log ~density ~align ~thread ~messages graph () in
  let composer_tree =
    match composer with
    | None -> Bonsai.return Vdom.Node.none
    | Some None -> Bonsai.return Vdom.Node.none
    | Some (Some composer) -> composer_node composer ()
  in
  Bonsai.map2 log composer_tree ~f:(fun log composer ->
    Vdom.Node.div
      ~attrs:
        (Attr.class_
           ([ "astryx-chat" ]
            @ (match density with
               | Compact -> [ "astryx-chat--compact" ]
               | Balanced -> []
               | Spacious -> [ "astryx-chat--spacious" ]))
         @ Attr.data "component" "Chat"
         @ Attr.data "density" (density_name density)
         @ (match id with
            | Some id -> [ Vdom.Attr.create "id" id ]
            | None -> [])
         @ attrs)
      [ log; composer ])
;;
