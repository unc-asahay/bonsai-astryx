(* Chat — the conversation surface: a transcript of messages and a composer.

   Upstream's Chat is a family of components (ChatLayout, ChatMessageList,
   ChatMessage, ChatMessageBubble, ChatMessageMetadata, ChatComposer,
   ChatComposerInput, ChatSendButton) composed through React context. The
   port folds them into one module: a message is a record and a transcript is
   a list of records, so the two things the context carried — the sender and
   the density — are ordinary fields.

   The first example is live. The composer is controlled, so the text in it
   is the application's state and the line under it says what the application
   holds: that round trip is the only way to tell a controlled composer from
   one that merely looks right at first paint. *)

open! Core
open! Bonsai_web

module Chat = Astryx.Chat
module Timestamp = Astryx.Timestamp

open Prelude

let demo (graph : Bonsai.graph) : Vdom.Node.t Bonsai.t =
  (* An example whose tree is a model, rather than a node. *)
  let ex_model name tree = Bonsai.map tree ~f:(fun node -> ex name node) in
  let body text = [ Vdom.Node.text text ] in
  let initials text = Vdom.Node.span [ Vdom.Node.text text ] in
  let no_change = Bonsai.return (fun (_ : string) -> Effect.Many []) in
  let no_stop = Bonsai.return (fun () -> Effect.Many []) in
  (* The composer every example starts from. A record update is how a state
     varies here, so that each example states only what it changes. *)
  let base_composer : Chat.composer =
    { Chat.value = Bonsai.return ""
    ; Chat.on_change = no_change
    ; Chat.on_submit = no_change
    ; Chat.on_stop = no_stop
    ; Chat.is_stop_shown = false
    ; Chat.is_disabled = false
    ; Chat.is_sending = false
    ; Chat.placeholder = "Send a message"
    ; Chat.density = Chat.Balanced
    ; Chat.elevation = Chat.Low
    ; Chat.status = None
    ; Chat.status_position = Chat.Bottom
    ; Chat.input = None
    }
  in
  let composer_of composer = Chat.composer_view ~composer graph () in
  (* --- the transcript -------------------------------------------------------- *)
  let greeting =
    Chat.message
      ~sender:Chat.Assistant
      ~author:"Navi"
      ~avatar:(initials "N")
      ~timestamp:(Timestamp.Str "2026-03-21T14:51:00Z")
      ~status:Chat.Read
      ~content:(body "Hello — the release is cut. What would you like to check?")
      ()
  in
  let reply =
    Chat.message
      ~sender:Chat.User
      ~author:"Ada"
      ~timestamp:(Timestamp.Str "2026-03-21T14:52:30Z")
      ~status:Chat.Delivered
      ~content:(body "Did the migration notes go out?")
      ()
  in
  let answer =
    Chat.message
      ~sender:Chat.Assistant
      ~author:"Navi"
      ~avatar:(initials "N")
      ~timestamp:(Timestamp.Str "2026-03-21T14:53:00Z")
      ~status:Chat.Sent
      ~content:(body "They did — the changelog and the migration notes, both in the release.")
      ()
  in
  let notice =
    Chat.message ~sender:Chat.System ~content:(body "The assistant was reconnected.") ()
  in
  let transcript = Chat.view ~messages:[ greeting; reply; answer; notice ] graph () in
  (* --- grouped messages ------------------------------------------------------ *)
  let grouped =
    [ Chat.message
        ~sender:Chat.Assistant
        ~author:"Navi"
        ~group:Chat.First
        ~content:(body "Three in a row read as one block, because the sender-side corners tighten.")
        ()
    ; Chat.message
        ~sender:Chat.Assistant
        ~author:"Navi"
        ~group:Chat.Middle
        ~content:(body "This is the middle of the run.")
        ()
    ; Chat.message
        ~sender:Chat.Assistant
        ~author:"Navi"
        ~group:Chat.Last
        ~content:(body "And this is the last of it.")
        ()
    ]
  in
  let grouped_transcript = Chat.view ~messages:grouped graph () in
  (* --- a ghost bubble -------------------------------------------------------- *)
  let ghost =
    Chat.view
      ~messages:
        [ Chat.message
            ~sender:Chat.Assistant
            ~author:"Navi"
            ~variant:Chat.Ghost
            ~content:(body "A ghost bubble has no fill of its own, so the content lines up with the text column.")
            ()
        ]
      graph ()
  in
  (* --- the thread states ----------------------------------------------------- *)
  let loading = Chat.view ~thread:Chat.Loading ~messages:[] graph () in
  let empty = Chat.view ~thread:Chat.Empty ~messages:[] graph () in
  let failed =
    Chat.view ~thread:(Chat.Error "The conversation could not be loaded.") ~messages:[] graph ()
  in
  let align_top =
    Chat.message_list ~id:"showcase-chat-align-top" ~align:Chat.Top ~messages:[ reply ] graph ()
  in
  (* --- the density scale ----------------------------------------------------- *)
  let compact = Chat.view ~density:Chat.Compact ~messages:[ greeting; reply ] graph () in
  let spacious = Chat.view ~density:Chat.Spacious ~messages:[ greeting; reply ] graph () in
  (* --- the whole thread, composer and all ------------------------------------ *)
  let whole =
    Chat.view ~composer:(Some base_composer) ~messages:[ greeting; reply; answer ] graph ()
  in
  (* --- the live composer ----------------------------------------------------- *)
  let draft, set_draft = Bonsai.state "" graph in
  let sent, set_sent = Bonsai.state (None : string option) graph in
  let live_composer =
    Chat.composer_view
      ~id:"showcase-chat-composer"
      ~composer:
        { base_composer with
          Chat.value = draft
        ; Chat.on_change = Bonsai.map set_draft ~f:(fun set value -> set value)
        ; Chat.on_submit = Bonsai.map set_sent ~f:(fun set text -> set (Some text))
        ; Chat.placeholder = "Ask about the release"
        }
      graph ()
  in
  let sent_readout =
    Bonsai.map sent ~f:(fun sent ->
      Vdom.Node.div
        ~attrs:[ Vdom.Attr.create "id" "showcase-chat-sent" ]
        [ Vdom.Node.text
            (match sent with
             | Some text -> "sent: " ^ text
             | None -> "sent: -")
        ])
  in
  let live =
    Bonsai.map2 live_composer sent_readout ~f:(fun composer readout ->
      Vdom.Node.div
        ~attrs:[ Vdom.Attr.create "id" "showcase-chat-live" ]
        [ composer; readout ])
  in
  (* --- a message being edited (a house extension) ---------------------------- *)
  let edit_draft, set_edit_draft = Bonsai.state "Did the migration notes go out?" graph in
  let saved, set_saved = Bonsai.state (None : string option) graph in
  let edit_message =
    Chat.message
      ~sender:Chat.User
      ~author:"Ada"
      ~edit:
        { Chat.edit_value = edit_draft
        ; Chat.on_change = Bonsai.map set_edit_draft ~f:(fun set value -> set value)
        ; Chat.on_save = Bonsai.map set_saved ~f:(fun set text -> set (Some text))
        ; Chat.on_cancel = Bonsai.map set_saved ~f:(fun set () -> set None)
        }
      ~content:(body "Did the migration notes go out?")
      ()
  in
  let editing =
    Bonsai.map2 (Chat.view ~messages:[ edit_message ] graph ()) saved ~f:(fun transcript saved ->
      Vdom.Node.div
        ~attrs:[ Vdom.Attr.create "id" "showcase-chat-editing" ]
        [ transcript
        ; Vdom.Node.div
            ~attrs:[ Vdom.Attr.create "id" "showcase-chat-edited" ]
            [ Vdom.Node.text
                (match saved with
                 | Some text -> "edited: " ^ text
                 | None -> "edited: -")
            ]
        ])
  in
  (* --- the composer's states ------------------------------------------------- *)
  let disabled = composer_of { base_composer with Chat.is_disabled = true } in
  let sending =
    composer_of
      { base_composer with
        Chat.is_sending = true
      ; Chat.value = Bonsai.return "On its way."
      }
  in
  let stopping =
    composer_of
      { base_composer with
        Chat.is_stop_shown = true
      ; Chat.value = Bonsai.return "Streaming…"
      }
  in
  let status_below = composer_of { base_composer with Chat.status = Some "Reconnecting…" } in
  let status_above =
    composer_of
      { base_composer with
        Chat.status = Some "Reconnecting…"
      ; Chat.status_position = Chat.Top
      }
  in
  let flat = composer_of { base_composer with Chat.elevation = Chat.Flat } in
  let compact_composer = composer_of { base_composer with Chat.density = Chat.Compact } in
  let examples =
    [ ex_model "a live composer: the text is the application's, and sending is too" live
    ; ex_model "a transcript: assistant, user and system" transcript
    ; ex_model "the whole thread: the messages above, the composer below" whole
    ; ex_model "grouped messages: a run reads as one block" grouped_transcript
    ; ex_model "a ghost bubble: no fill, same alignment" ghost
    ; ex_model "thread: loading" loading
    ; ex_model "thread: empty" empty
    ; ex_model "thread: error" failed
    ; ex_model "align: top" align_top
    ; ex_model "density: compact" compact
    ; ex_model "density: spacious" spacious
    ; ex_model "composer: disabled" disabled
    ; ex_model "composer: sending" sending
    ; ex_model "composer: stop" stopping
    ; ex_model "composer: a status line, below" status_below
    ; ex_model "composer: a status line, above" status_above
    ; ex_model "composer: flat" flat
    ; ex_model "composer: compact" compact_composer
    ; ex_model "a message being edited" editing
    ]
  in
  Bonsai.map (unwrap_all examples) ~f:(fun examples ->
    section
      ~id:"chat"
      ~title:"Chat"
      ~note:
        "A conversation: the transcript above, the composer below. The transcript is a polite \
         log, so a screen reader announces a message as it arrives, and a grouped run of \
         messages from one author tightens the corners on the joined side. The composer is \
         controlled — the text is the application's, and the send button is live only when \
         there is something to send. The thread has four states: ready shows the messages, \
         and loading, empty and error show their own state in their place. The editing \
         example is a house extension: upstream's Chat has no per-message editing at all, \
         and the port adds it because a chat surface that cannot take a message back is not \
         the surface the CLI ships."
      examples)
;;
