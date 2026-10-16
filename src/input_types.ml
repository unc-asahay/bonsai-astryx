open! Core

type size =
  | Sm
  | Md
  | Lg

type status_type = Field_status.type_ =
  | Warning
  | Error
  | Success

type status =
  { type_ : status_type
  ; message : string option
  }
