open! Core
open! Bonsai_web
open Js_of_ocaml

type preset =
  | Slide_down
  | Slide_up
  | Fade_in
  | Scale_in

let class_ = function
  | Slide_down -> "astryx-enter--slide-down"
  | Slide_up -> "astryx-enter--slide-up"
  | Fade_in -> "astryx-enter--fade-in"
  | Scale_in -> "astryx-enter--scale-in"
;;

(* Module-level, like upstream's own flag: it describes the page, not one component. *)
let first_frame_done = ref false

(* Upstream's exact schedule: flip the flag in the next animation frame after module load.
   The first render therefore reads [false] — nothing animates on first paint — and
   anything mounted after the first frame reads [true]. Guarded, because a native or
   jsdom test realm has a window object but may not have requestAnimationFrame. *)
let () =
  if Js.Optdef.test (Js.Unsafe.get Dom_html.window "requestAnimationFrame")
  then
    ignore
      (Js.Unsafe.meth_call
         Dom_html.window
         "requestAnimationFrame"
         [| Js.Unsafe.inject
              (Js.wrap_callback (fun (_ : float) -> first_frame_done := true))
         |])
;;

let animate () = !first_frame_done
