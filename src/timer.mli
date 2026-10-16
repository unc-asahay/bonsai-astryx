(** An elapsed duration that stays readable — and machine-readable — without re-rendering.

    {2 The reading and the duration are two different numbers}

    What is rendered is a real [<time>] carrying an ISO 8601 duration in its [datetime] and the human
    reading as its text. Past an hour the [elapsed] reading stops showing seconds ("2h 05m"), and then the
    [datetime] follows *the text* rather than the raw elapsed time — a duration that disagrees with its own
    visible reading is worse than no duration at all. That choice is upstream's and is copied here.

    {2 Nothing re-renders}

    Upstream writes the changing text straight to the owned [<time>] node rather than scheduling tick
    renders, and this port does the same: the hook owns the element and writes only what actually changed.
    A per-second re-render of a component is a per-second re-render of everything above it.

    The wait until the next change is computed rather than rounded off to a second — past an hour the
    [elapsed] reading only moves once a minute, so polling every second would be work done to discover that
    nothing had changed. A [start_time] in the future schedules its first change for that moment, and is
    the only case where the reading sits at zero and then moves.

    {2 What is testable without controlling a clock}

    [presentation] and [milliseconds_until_next_change] are exposed, because the gate runs on a machine
    where the clock cannot be moved: the 60-second and one-hour boundaries, the switch to minute
    granularity and a start time in the future are asserted directly as arithmetic rather than inferred
    from something rendered. That the text actually *moves* is the browser gate's job, and it is asserted
    by waiting and reading again. *)

open! Core
open! Bonsai_web

type format =
  | Elapsed
  | Clock
(** [Elapsed] reads "45s", "2m 05s", "1h 30m". [Clock] reads "0:45", "2:05", "1:02:05". *)

type presentation =
  { datetime : string (** ISO 8601 duration, e.g. ["PT125S"]. *)
  ; text : string (** The reading a person sees. *)
  }

val presentation : format:format -> elapsed_ms:int -> presentation
(** The reading and the machine-readable duration for an elapsed time. Pure — this is where the boundaries
    live, so it takes milliseconds and gives back strings with nothing else involved. *)

val milliseconds_until_next_change
  :  format:format
  -> now_ms:float
  -> start_time_ms:float
  -> elapsed_ms:int
  -> int
(** How long to wait before the reading can possibly differ. Never zero: a zero delay would spin. *)

val view
  :  ?attrs:Vdom.Attr.t list
  -> ?start_time:float
  -> ?format:format
  -> ?type_:Text.type_
  -> ?size:Text.size
  -> ?color:Text.color
  -> ?weight:Text.weight
  -> unit
  -> Vdom.Node.t
(** [view ~start_time ()]. With no [start_time] the count begins at this component's mount — resolved once,
    in the hook, the way upstream's [useState] resolves it once. A start time in the future counts down to
    zero and then up. *)
