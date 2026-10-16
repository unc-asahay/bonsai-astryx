(* Public entry point of the library.

   Everything here is a hand-port of an Astryx component: the prop names, the
   variant sets, the defaults and the accessibility behaviour come from upstream
   (see docs/components/<Name>.md, which is generated from Astryx's own
   machine-readable docs). `Divergence` sections in each component file record
   where the port deliberately differs. *)

module Common = Common
module Tokens = Tokens
module Stack = Stack
module Text = Text
module Heading = Heading
module Button = Button
module Card = Card
module Badge = Badge
module Divider = Divider
module Skeleton = Skeleton
module Center = Center
module Section = Section
module Grid = Grid
module Visually_hidden = Visually_hidden
module Aspect_ratio = Aspect_ratio
module Hstack = Hstack
module Vstack = Vstack
module Icon_button = Icon_button
module Code = Code
module Blockquote = Blockquote
module Nav_icon = Nav_icon
module NavIcon = Nav_icon
module Empty_state = Empty_state
module EmptyState = Empty_state
module Citation = Citation

(* The file is status_dot.ml (OCaml module names cannot carry the upstream
   capitalisation), but the public name matches upstream: Astryx.StatusDot. *)
module Status_dot = Status_dot
module StatusDot = Status_dot
module VisuallyHidden = Visually_hidden
module AspectRatio = Aspect_ratio
module HStack = Hstack
module VStack = Vstack
module IconButton = Icon_button
module Icon = Icon
module Entry_animation = Entry_animation
module Field_status = Field_status
module Input_types = Input_types
module Dropdown_menu = Dropdown_menu
module Field = Field
module Text_input = Text_input
module TextInput = Text_input
module Text_area = Text_area
module TextArea = Text_area

