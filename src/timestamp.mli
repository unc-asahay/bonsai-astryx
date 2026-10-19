(* Timestamp — a hand-port of Astryx's Timestamp/Timestamp.tsx (438 lines),
   formatInstant.ts (245), formatRelativeTime.ts (96), tooltipEntries.ts (230)
   and TimestampHoverCard.tsx (261).

   Formats a date/time value into human-readable text on a semantic <time>
   element, with an ISO 8601 datetime attribute. Relative formats ("2 hours
   ago"), absolute formats ("Mar 21, 2025"), auto (relative for recent,
   date_time for older), and the machine shapes (system_* / unix_seconds) are
   all upstream's. The hover surface is the copyable hover card built on the
   port's own {!Hover_card}: one line per configured zone/format, each row
   optionally copyable.

   {2 The viewer's zone}

   The visible text always reads in the viewer's own zone (upstream's rule:
   no time zone is passed for the visible text), and only the card names
   others. Upstream resolves the viewer's zone through the provider locale
   and Intl's host default; this port does the same — the Intl calls are
   delegated to the host (see {!format_instant}), so whatever zone the
   browser is running in is the zone the timestamps read in. Only the
   {v system_* v} shapes and {v unix_seconds v} are zone-independent.

   {2 Divergences, named rather than hidden}

   - {b Locale}. Upstream reads the provider locale ([useLocale], default
     [en]) and localizes every word. This port has no locale provider, so the
     language is fixed: all [Intl.DateTimeFormat] / [Intl.RelativeTimeFormat]
     calls use [en] (the upstream fallback), and the card's strings
     ("Timestamp details", "Copy <value>", "Copied") are the English defaults
     of upstream's i18n catalogue. A locale-aware caller can ask [format_instant]
     / [format_relative_time] with a locale directly — the component does not
     expose one (same standing as {!More_menu}'s labels).
   - {b Lazy import}. Upstream lazy-loads TimestampHoverCard behind
     [Suspense] so a card-less timestamp never bundles it. This port has no
     code splitting: the card is compiled in, and the bundle cost is one
     chunk instead of two. Rendering is unchanged — a card-less timestamp
     still attaches no HoverCard at all.
   - {b No tooltip on absolute formats without entries, as upstream}. The
     gate is `has_tooltip && (relative || entries)`, ported exactly: an
     absolute format with no configured entries shows no hover surface and no
     tab stop; configuring entries opens it, and {v has_tooltip=false v}
     suppresses it either way. An empty entry list is not a second way to
     spell "off".
   - {b The card's id}. Upstream's layer id comes from React's [useId]; this
     port's {!Hover_card} requires an id, so [view] takes [id]: when omitted
     a deterministic fresh id ([{v timestamp-card-N v}]) is allocated once
     per mounted instance, so [aria-controls] always points at the card that
     is on screen.
   - {b Touch}. Upstream's card has no touch mode either (the touch handling
     is the hover card's own); a tap opens the card after the show delay,
     exactly as {!Hover_card} documents.
   - {b themeProps}. The [themeProps('timestamp')] / [themeProps('timestamp-copy-button')]
     seams have no counterpart, the standing of every previous milestone
     (the theme targets the class names, never the props).
   - {b Clipboard}. Upstream's [useClipboard] writes through
     [navigator.clipboard.writeText], announces to a polite live region, and
     reverts the copied flag after 1500 ms (its explicit [resetAfterMs]).
     The port does the same through the same browser API; a clipboard
     rejection is a silent no-op. One difference of mechanism: upstream's
     announcement is hosted by the application's own announcer
     ([useAnnounce]); the port hosts its own [role=status] live region in
     the card, because the port cannot ask the application for one.
   - {b No [useDevWarning]} console contract for an unparseable value: the
     port renders nothing (upstream's behaviour) and reports the invalid
     value through [data-astryx-invalid] rather than a dev-only console warn.

   The IC timezone caveat: an invalid `timezoneID` falls back to the viewer's
   zone with a console warning, as upstream decides in [resolveTimezoneID];
   the warning is emitted at most once per bad identifier, as upstream's
   [warnedTimezoneIDs] set ensures. *)

open! Core
open! Bonsai_web

type value =
  | Str of string
  (** An ISO 8601 date string (or any string [new Date] accepts). *)
  | Num of float
  (** A Unix timestamp. Numbers below [1e12] are seconds, the rest are
      milliseconds — upstream's heuristic, ported exactly. *)

type format =
  | Relative
  (** "2 hours ago", "yesterday", "now" — long relative. *)
  | Relative_short
  (** "2h ago", "1d ago" — narrow relative, for compact surfaces. *)
  | Auto
  (** Relative when within [auto_threshold] seconds of now, [Date_time]
      otherwise. *)
  | Date
  (** "Mar 21, 2025" *)
  | Date_long
  (** "March 21, 2025" *)
  | Date_weekday
  (** "Wed, Mar 21, 2025" *)
  | Date_time
  (** "Mar 21, 2025, 2:51 PM" *)
  | Time
  (** "2:51 PM" *)
  | System_date
  (** "2025-03-21" *)
  | System_date_time
  (** "2025-03-21 14:51:53" *)
  | System_time
  (** "14:51:53" *)
  | Unix_seconds
  (** "1742565113" — zone-independent. *)

type instant_format =
  | Instant of format
  (** An absolute [format]; a relative or [Auto] raises [Invalid_argument]. *)
  | Full
  (** The long absolute style that backs a relative timestamp's accessible
      name and the card's default line ("February 19, 2026 at 5:00:00 PM
      UTC"). *)

type relative_style =
  | Long
  | Narrow

type tooltip_entry =
  { timezone_id : string option
        (** IANA zone, or [None]/[local] for the viewer's own zone. *)
  ; format : instant_format option
        (** [None] means [Full] — the long absolute style. *)
  ; label : string option
        (** Text beside the time (already translated by the caller; the port
            never invents labels). *)
  ; is_copyable : bool
        (** Whether the row shows a copy-to-clipboard button. *)
  }

type tooltip_line =
  { label : string option
  ; value : string
  ; is_copyable : bool
  }

val zone_parts : ms:float -> timezone_id:string -> int * int * int * int * int * int
(** [zone_parts ~ms ~timezone_id] returns wall-clock fields
    (year, month, day, hour, minute, second) of [ms] in the named zone,
    through the host's [Intl.formatToParts]. It is the one [Intl] dependency
    of the [system_*] shapes. *)

val format_instant
  :  ms:float
  -> instant_format
  -> ?timezone_id:string
  -> ?is_timezone_shown:bool
  -> ?timezone_name_style:[ `Short | `Long ]
  -> ?locale:string
  -> unit
  -> string
(** Renders one instant in one absolute format. [timezone_id] omitted means
    the viewer's own zone (the host default — [Intl] is handed no [timeZone]).
    [is_timezone_shown] is honoured by [Date_time] and [Time] only; [Full]
    always shows a zone name; the [system_*] shapes never do. *
    locale defaults to [en] — the component's fixed locale. *)

val format_relative_time
  :  date_ms:float
  -> now_ms:float
  -> relative_style
  -> ?locale:string
  -> unit
  -> string
(** The relative phrase for [date_ms] read at [now_ms] ("2 hours ago",
    "yesterday", "now"), tiered exactly as upstream tiers it (second, minute,
    hour, day, month, year) with the 10-second "now" tolerance and the 30 s
    future-skew tolerance. *)

val format_tooltip_lines : ms:float -> tooltip_entry list -> tooltip_line list
(** One line per entry, in the order given, with zone resolution and the
    zone-abbreviation rule ("which zone is named" is decided here, "how the
    instant reads" is {!format_instant}'s). *)

val view
  :  ?format:format
  -> ?auto_threshold:float
  -> ?has_tooltip:bool
  -> ?tooltip_entries:tooltip_entry list
  -> ?is_timezone_shown:bool
  -> ?is_live:bool
  -> ?type_:Text.type_
  -> ?size:Text.size
  -> ?color:Text.color
  -> ?weight:Text.weight
  -> ?id:string
  -> ?attrs:Vdom.Attr.t list
  -> value:value
  -> Bonsai.graph
  -> Vdom.Node.t Bonsai.t
(** [view ~value graph] renders the timestamp.

    Defaults, all upstream's: [format = Auto] (7-day threshold; relative when
    newer, [Date_time] otherwise), [has_tooltip = true] ({v only when v} the
    effective format is relative — absolute formats have no card unless
    [tooltip_entries] are configured), [is_timezone_shown = false],
    [is_live = false], [type_ = Supporting], [color = Secondary], [size] /
    [weight] unset.

    The <time> element carries [datetime] (ISO 8601), [aria-label] with the
    full absolute time — zone name spelled out, [WCAG 3.1.4] — only when the
    visible text is relative, and [tabindex=0] only while a card is attached.
    An unparseable value renders nothing at all (upstream's behaviour) and
    marks the element's intent through [data-astryx-invalid="true"] on a
    hidden probing node — the port reports it visibly rather than a dev-only
    console warn.

    The card, when shown, is [Above], [focus_trigger = Always] (the <time> is
    the tab stop) and always indicated — upstream passes the same three.
    [is_live = true] keeps the relative reading fresh at the interval the
    reading's own precision dictates (1 s under a minute, 30 s under an
    hour, 1 min under a day, 5 min beyond — upstream's [getLiveInterval]). *)
