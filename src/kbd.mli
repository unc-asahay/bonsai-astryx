(** A keyboard shortcut, rendered as keycaps.

    {2 The glyphs are for eyes, which is why the component carries an accessible name}

    Upstream renders ⌘ ⇧ ↵ ⌫ as glyphs and then does something easy to miss: the wrapper is [role="img"]
    with an [aria-label] built from *spoken* words — "Command + Shift + P" — and every keycap is
    [aria-hidden]. Glyphs are announced meaninglessly by assistive technology, so a shortcut can render
    perfectly and still be unusable. The port keeps both halves as separate functions, which is also why
    [key_display] and [key_label] are exposed: the gate runs on a Linux runner, so the Mac branch has to
    be pressable directly rather than requiring the machine to be a Mac.

    {2 [mod] is platform-aware, and this port answers that question differently on purpose}

    [mod] is ⌘ on Apple platforms and "Ctrl" elsewhere. Upstream defers the answer through
    [useSyncExternalStore] so that the server render and the first client render cannot disagree — a
    hydration mismatch would flip every shortcut on the page. This port has no server render, so it asks
    directly and records the divergence rather than copying a workaround for a problem it does not have.

    The detection rules themselves are ported as written, including the part that is easy to get wrong:
    a client-hints platform of [""] or ["Unknown"] is treated as *no answer* rather than as a negative
    one, and falls through to the legacy [navigator.platform] check. The client-hints branch tests for
    "mac" case-insensitively; the legacy branch tests ["Mac"]/["iPhone"]/["iPad"]/["iPod"] as written.

    {2 Keys}

    [keys] splits on ["+"], trims and lowercases each part, and resolves [esc → escape] and
    [return → enter]. Display falls back to the uppercased key, so a key upstream has never heard of
    renders as itself instead of vanishing. A literal "+" key is spelled ["plus"] (["shift+plus"]).

    {2 One known divergence}

    Upstream merges a caller's class into its own; here a caller-supplied class in [attrs] replaces the
    component's, because virtual_dom keeps the last attribute of a given name. [attrs] is therefore for
    identity attributes (["id"], data, ARIA) — the same caveat every other component in this port
    carries, recorded rather than hidden. *)

open! Core
open! Bonsai_web

val split_keys : string -> string list
(** [split_keys "mod+shift+P"] = [["mod"; "shift"; "p"]]. Over-long or empty parts survive as they are;
    an unknown key is not an error, it is a key with no glyph of its own. *)

val key_display : is_mac:bool -> string -> string
(** The glyph on the cap: ["⌘"], ["⇧"], ["Esc"], or the uppercased key when there is no glyph. *)

val key_label : is_mac:bool -> string -> string
(** The spoken name: ["Command"], ["Shift"], ["Escape"], or the uppercased key. *)

val is_apple_platform : unit -> bool
(** Upstream's detection, in upstream's order: client hints when they name a platform, the legacy
    [navigator.platform] otherwise. *)

val view : keys:string -> ?attrs:Vdom.Attr.t list -> unit -> Vdom.Node.t
(** [view ~keys:"mod+k" ()] — one [role="img"] wrapper naming the whole shortcut for assistive
    technology, with one [aria-hidden] cap per key inside it. *)
