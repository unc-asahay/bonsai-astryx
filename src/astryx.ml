(* Public entry point of the library.

   Everything here is a hand-port of an Astryx component: the prop names, the
   variant sets, the defaults and the accessibility behaviour come from upstream
   (see docs/components/<Name>.md, which is generated from Astryx's own
   machine-readable docs). `Divergence` sections in each component file record
   where the port deliberately differs. *)

module Avatar = Avatar
module Avatar_group = Avatar_group
module Avatar_group_overflow = Avatar_group_overflow
module Avatar_status_dot = Avatar_status_dot
module Metadata_list = Metadata_list
module Metadata_list_item = Metadata_list_item

module More_menu = More_menu

module Popover = Popover
module Common = Common
module Progress_bar = Progress_bar

module Tokens = Tokens
module Timer = Timer
module Stack = Stack
module Toggle_button = Toggle_button
module Toggle_button_group = Toggle_button_group
module Toolbar = Toolbar
module Text = Text
module Heading = Heading
module Button = Button
module Button_group = Button_group
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
module Input_group = Input_group
module Input_group_text = Input_group_text
module Icon = Icon
module Entry_animation = Entry_animation
module Field_status = Field_status
module Input_types = Input_types
module Indicator = Indicator
module Checkbox_input = Checkbox_input
module CheckboxInput = Checkbox_input
module Switch = Switch
module Radio_list = Radio_list
module Form_layout = Form_layout
module FormLayout = Form_layout
module Tooltip = Tooltip
module Dialog = Dialog
module Alert_dialog = Alert_dialog
module Kbd = Kbd
module Dialog_header = Dialog_header
module AlertDialog = Alert_dialog
module RadioList = Radio_list
module Field_label = Field_label
module Dropdown_menu = Dropdown_menu
module Field = Field
module Text_input = Text_input
module TextInput = Text_input
module Text_area = Text_area
module TextArea = Text_area
module Selectable_card = Selectable_card
module SelectableCard = Selectable_card
module Clickable_card = Clickable_card
module ClickableCard = Clickable_card
module Overflow_math = Overflow_math
module Overflow_list = Overflow_list
