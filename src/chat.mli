(** Chat — a message thread: the messages, the composer under them, and the states a
    thread can be in.

    Upstream's Chat is a family of components (ChatLayout, ChatMessageList,
    ChatMessage, ChatMessageBubble, ChatMessageMetadata, ChatComposer,
    ChatComposerInput, ChatSendButton). This port keeps the surface a chat
    surface actually shows, and says plainly in the sections below what it
    leaves out.

    {2 The message list}

    Each message carries its author, its content, a timestamp, and a delivery
    status. Messages that follow one another from the same author can be
    {e grouped} ({!group}), which is what upstream's bubble grouping does: the
    run reads as one block, with the corners tightened on the joined side.

    {2 The composer}

    The composer is the input plus the send action, in the states upstream
    shows for it: disabled, sending, and the stop button that replaces send
    while a response is streaming. Like the house's other controlled inputs
    ({!Text_area}), the composer is {e controlled}: the caller owns the text
    and applies [on_change] to it. The send button is enabled only when the
    text is not blank.

    {2 The thread states}

    A thread is {e ready}, {e loading}, {e empty} (nothing said yet) or in
    {e error}. Only the ready state renders messages; the others render the
    corresponding state in place of the list.

    {2 What this port does not do}

    - {b Editing is a house extension, not upstream behaviour}. Upstream's Chat
      has no per-message editing state at all — the "edit a message you
      already sent" flow lives in the CLI template
      (packages/cli/assets/templates/pages/ai-chat), not in the component. This
      port implements the editing state anyway (see {!edit}), because a chat
      surface that cannot take a message back is not the surface the CLI
      ships. It is not upstream behaviour and is not claimed to be.
    - {b The composer's drawer}. Upstream's ChatComposer has a [drawer] slot
      (attachments, context chips) rendered above the input. Not ported.
    - {b Header/footer action slots}. Upstream's ChatComposer has
      [headerActions] and [footerActions] slots for extra controls. Not
      ported.
    - {b Custom send button}. Upstream's ChatComposer lets the caller replace
      the send button wholesale. Not ported: this port renders the send
      button itself.
    - {b System messages}. Upstream has a separate ChatSystemMessage
      component for centred notices that are not part of the conversation.
      Not ported; use {!sender} = {!System} for a message that belongs to the
      thread but reads as a notice.
    - {b The mention picker and the reaction bar}. They are separate upstream
      packages, not part of Chat. Not ported. *)

open! Core
open! Bonsai_web

(** Who sent a message. Upstream calls this the sender, and it decides the
    message's alignment and its bubble style. *)
type sender =
  | User
  | Assistant
  | System

(** The spacing scale the thread is rendered at. *)
type density =
  | Compact
  | Balanced
  | Spacious

(** Where a message sits in a run of messages from one author. Upstream's
    bubble takes the same three values, and they tighten the bubble's corners
    on the joined side. *)
type group =
  | First
  | Middle
  | Last

(** A message's delivery state, shown next to its timestamp. *)
type status =
  | Sending
  | Sent
  | Delivered
  | Read
  | Failed

(** The bubble's own rendering. A ghost bubble has no background of its own
    and is used for content that should align with the text column without
    looking like a quoted message. *)
type variant =
  | Filled
  | Ghost

(** Which end of the list the messages are packed towards when the list is
    shorter than its container. *)
type align =
  | Top
  | Bottom

(** The composer's resting elevation. Upstream's [low] is the default. *)
type elevation =
  | Low
  | Flat

(** Where the composer's status line sits. *)
type status_position =
  | Top
  | Bottom

(** The state a thread is in. *)
type thread =
  | Ready
      (** Messages are shown. *)
  | Loading
      (** The thread is being fetched. *)
  | Empty
      (** The thread has no messages yet. *)
  | Error of string
      (** The thread could not be loaded; the string is the reason. *)

(** The draft of a message that is being edited.

    This is a house extension, not upstream behaviour — see the note at the
    top of this file. The caller owns the draft and the three actions, so the
    port only renders the editor. *)
type edit =
  { edit_value : string Bonsai.t
        (** The text as it stands in the editor. *)
  ; on_change : (string -> unit Effect.t) Bonsai.t
        (** Called with the new text whenever the editor's content changes. *)
  ; on_save : (string -> unit Effect.t) Bonsai.t
        (** Called with the edited text when the edit is saved. *)
  ; on_cancel : (unit -> unit Effect.t) Bonsai.t
        (** Called when the edit is abandoned. *)
  }

(** One message in the thread. *)
type message =
  { sender : sender
        (** Who sent it. Decides the alignment and the bubble style. *)
  ; content : Vdom.Node.t list
        (** The body of the message. *)
  ; author : string option
        (** The name shown above the body. *)
  ; avatar : Vdom.Node.t option
        (** The picture shown beside the body. *)
  ; timestamp : Timestamp.value option
        (** When the message was sent. *)
  ; status : status option
        (** Its delivery state. *)
  ; group : group option
        (** Where it sits in a run of messages from one author. *)
  ; variant : variant
        (** The bubble's own rendering. *)
  ; footer : Vdom.Node.t option
        (** Extra content under the body. *)
  ; edit : edit option
        (** Set while the message is being edited. A house extension; see
            {!edit}. *)
  ; density : density option
        (** Overrides the thread's density for this message. *)
  }

(** The composer: the input, the send action, and the states around them.

    The input is {e controlled}: [value] is the text in it, and [on_change]
    is how the caller is told the text changed. *)
type composer =
  { value : string Bonsai.t
        (** The text in the input. *)
  ; on_change : (string -> unit Effect.t) Bonsai.t
        (** Called with the new text whenever the input changes. *)
  ; on_submit : (string -> unit Effect.t) Bonsai.t
        (** Called with the text when the message is sent. *)
  ; on_stop : (unit -> unit Effect.t) Bonsai.t
        (** Called when the stop button is pressed. *)
  ; is_stop_shown : bool
        (** Show the stop button in place of send. *)
  ; is_disabled : bool
        (** The input cannot be edited or sent. *)
  ; is_sending : bool
        (** A send is in flight: the send button shows a spinner and cannot
            be pressed again. *)
  ; placeholder : string
        (** The input's placeholder text. *)
  ; density : density
        (** The spacing scale the composer is rendered at. *)
  ; elevation : elevation
        (** The composer's resting elevation. *)
  ; status : string option
        (** A line of text shown with the composer, e.g. "Reconnecting…". *)
  ; status_position : status_position
        (** Where that line sits. *)
  ; input : Vdom.Node.t option
        (** Replaces the built-in input. *)
  }

(** Builds a message, so that the common case does not have to name every
    field. *)
val message
  :  ?author:string
  -> ?avatar:Vdom.Node.t
  -> ?timestamp:Timestamp.value
  -> ?status:status
  -> ?group:group
  -> ?variant:variant
  -> ?footer:Vdom.Node.t
  -> ?edit:edit
  -> ?density:density
  -> sender:sender
  -> content:Vdom.Node.t list
  -> unit
  -> message

(** The list of messages.

    The list is a log region ([role="log"], [aria-live="polite"]), so a screen
    reader announces messages as they arrive. It scrolls to the bottom, the
    way a conversation reads. *)
val message_list
  :  ?id:string
  -> ?attrs:Vdom.Attr.t list
  -> ?density:density
  -> ?align:align
  -> ?thread:thread
  -> messages:message list
  -> Bonsai.graph
  -> unit
  -> Vdom.Node.t Bonsai.t
(** [message_list ~messages graph ()] renders the messages.

    [thread] says what the list should show instead of the messages: {!Ready}
    (the default) shows them, {!Loading} shows a spinner, {!Empty} shows
    "No messages yet", and {!Error} shows the reason. *)

(** The composer. *)
val composer_view
  :  ?id:string
  -> ?attrs:Vdom.Attr.t list
  -> composer:composer
  -> Bonsai.graph
  -> unit
  -> Vdom.Node.t Bonsai.t
(** [composer_view ~composer graph ()] renders the composer.

    The input is a textarea: Enter sends the message, Shift+Enter starts a new
    line. The send button is disabled while the input is empty, while the
    composer is disabled, and while a send is in flight. *)

(** The whole thread: the messages above, the composer below. *)
val view
  :  ?id:string
  -> ?attrs:Vdom.Attr.t list
  -> ?density:density
  -> ?align:align
  -> ?thread:thread
  -> ?composer:composer option
  -> messages:message list
  -> Bonsai.graph
  -> unit
  -> Vdom.Node.t Bonsai.t
(** [view ~messages graph ()] renders the thread.

    The composer is optional: pass [~composer:None] for a read-only thread
    (a transcript, say). *)
