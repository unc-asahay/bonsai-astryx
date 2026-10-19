(* Plain_date — immutable calendar-date arithmetic (port of upstream
   utils/plainDate.ts). Gregorian-only, pure, no time-of-day. *)

type t = { year : int; month : int; day : int }

val create : year:int -> month:int -> day:int -> t
(** [create ~year ~month ~day] raises [Invalid_argument] on out-of-range
    fields (year >= 1, month 1-12, day valid for the month). *)

val of_iso : string -> t
(** Parse an ISO calendar date ["YYYY-MM-DD"]. *)

val to_iso : t -> string
(** Render an ISO calendar date ["YYYY-MM-DD"]. *)

val today : unit -> t
(** The host's current local date. *)

val days_in_month : int -> int -> int
(** [days_in_month year month] for valid months; 0 otherwise. *)

val day_of_week : t -> int
(** 0 = Sunday ... 6 = Saturday, host-local. *)

val add_months : t -> int -> t
(** Pure month arithmetic with day clamping (Jan 31 + 1mo = Feb 28/29). *)

val add_days : t -> int -> t

val diff_days : t -> t -> int
(** Whole calendar days from [a] to [b]; positive when [b] is after [a]. *)

val compare : t -> t -> int
val is_before : t -> t -> bool
val is_after : t -> t -> bool
val is_equal : t -> t -> bool
val max : t -> t -> t
val min : t -> t -> t
val is_in_range : t -> first:t -> last:t -> bool

val set_first_of_month : t -> t
val set_start_of_week : t -> week_starts_on:int -> t
val set_end_of_week_exclusive : t -> week_starts_on:int -> t

val get_week_number : t -> int
(** ISO 8601 week-of-year number. *)

(* Host-Intl formatting: options are JSON strings (see the constants below),
   delegated to [Intl.DateTimeFormat] on the host with a 'gregory' calendar. *)

val format : ?locale:string -> t -> string -> string
val format_with_weekday : ?locale:string -> t -> string
val format_short_with_weekday : ?locale:string -> t -> string
val format_long : ?locale:string -> t -> string
val format_month_year : ?locale:string -> t -> string
val format_weekday_only : ?locale:string -> t -> string
val format_month_only : ?locale:string -> t -> string
val format_short : ?locale:string -> t -> string
val format_short_with_year : ?locale:string -> t -> string

val week_field_name : ?locale:string -> unit -> string
(** CLDR name of the "week of year" field (falls back to "week"). *)

type shared_format = [ `Date | `Date_long | `Date_weekday | `System_date ]

val format_shared : ?locale:string -> t -> shared_format -> string
(** The date-only members of Timestamp's format vocabulary, shared with
    DateInput: [ `Date ] = "Mar 21, 2026", [ `System_date ] = ISO. *)
