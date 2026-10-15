(* GENERATED FILE — do not edit by hand.
   Source: astryx:packages/core/src/theme/tokens.stylex.ts  (MIT, Meta Platforms, Inc. and affiliates)
   Regenerate with: python3 tools/gen-ocaml-tokens.py

   These are the upstream design tokens as published. Values may use modern CSS
   syntax (e.g. light-dark(...)); they are emitted verbatim, so anything that
   consumes them must be a browser (or resolve them the same way). *)

open! Core

let source = "astryx:packages/core/src/theme/tokens.stylex.ts"

(* color: 79 tokens *)
let color_accent = "light-dark(#0064E0, #2694FE)"
let color_accent_muted = "light-dark(#0082FB33, #0082FB3F)"
let color_on_accent = "light-dark(#FFFFFF, #FFFFFF)"
let color_neutral = "light-dark(rgba(5, 54, 89, 0.1), rgba(223, 226, 229, 0.2))"
let color_background_surface = "light-dark(#FFFFFF, #1F1F22)"
let color_background_body = "light-dark(#F1F4F7, #111112)"
let color_overlay = "light-dark(#01122866, #11111299)"
let color_overlay_hover = "light-dark(#0536590C, #FFFFFF0C)"
let color_overlay_pressed = "light-dark(#05365919, #FFFFFF19)"
let color_background_muted = "light-dark(#0536590C, #1111127F)"
let color_text_primary = "light-dark(#0A1317, #DFE2E5)"
let color_text_secondary = "light-dark(#4E606F, #AAAFB5)"
let color_text_disabled = "light-dark(#A4B0BC, #6F747C)"
let color_text_accent = "light-dark(#0064E0, #3E9EFB)"
let color_on_dark = "light-dark(#FFFFFF, #FFFFFF)"
let color_on_light = "light-dark(#000000, #000000)"
let color_icon_accent = "light-dark(#0064E0, #2694FE)"
let color_icon_primary = "light-dark(#0A1317, #DFE2E5)"
let color_icon_secondary = "light-dark(#4E606F, #AAAFB5)"
let color_icon_disabled = "light-dark(#A4B0BC, #6F747C)"
let color_background_card = "light-dark(#FFFFFF, #1F1F22)"
let color_background_popover = "light-dark(#FFFFFF, #28292C)"
let color_background_inverted = "light-dark(#0A1317, #FFFFFF)"
let color_background_error_inverted = "light-dark(#AA071E, #E3193B)"
let color_success = "light-dark(#0D8626, #0D8626)"
let color_success_muted = "light-dark(#0B991F33, #0B991F3F)"
let color_on_success = "light-dark(#FFFFFF, #FFFFFF)"
let color_error = "light-dark(#E3193B, #F5394F)"
let color_error_muted = "light-dark(#E3193B33, #F5394F3F)"
let color_on_error = "light-dark(#FFFFFF, #FFFFFF)"
let color_warning = "light-dark(#E9AF08, #F2C00B)"
let color_warning_muted = "light-dark(#E2A40033, #E2A4003F)"
let color_on_warning = "light-dark(#0A1317, #0A1317)"
let color_border = "light-dark(#05365919, #F2F4F619)"
let color_border_emphasized = "light-dark(#CCD3DB, #494D53)"
let color_skeleton = "light-dark(#CCD3DB, #5A5E66)"
let color_track = "light-dark(#CCD3DB, #5A5E66)"
let color_shadow = "light-dark(rgba(5, 54, 89, 0.1), rgba(0, 0, 0, 0.3))"
let color_tint_hover = "light-dark(black, white)"
let color_background_blue = "light-dark(#0171E333, #0171E333)"
let color_border_blue = "light-dark(#0064E0, #2694FE)"
let color_icon_blue = "light-dark(#0064E0, #2694FE)"
let color_text_blue = "light-dark(#042F97, #AFD7FF)"
let color_background_cyan = "light-dark(#03A7D733, #03A7D733)"
let color_border_cyan = "light-dark(#089DD0, #0171A4)"
let color_icon_cyan = "light-dark(#00ACC1, #26C6DA)"
let color_text_cyan = "light-dark(#014975, #A1EEF9)"
let color_background_gray = "light-dark(#0A131733, #666A724C)"
let color_border_gray = "light-dark(#647685, #748695)"
let color_icon_gray = "light-dark(#4E606F, #AAAFB5)"
let color_text_gray = "light-dark(#0A1317, #E7EAED)"
let color_background_green = "light-dark(#24BB5E33, #24BB5E33)"
let color_border_green = "light-dark(#0D8626, #0B991F)"
let color_icon_green = "light-dark(#0D8626, #26A756)"
let color_text_green = "light-dark(#09441F, #A5F690)"
let color_background_orange = "light-dark(#F2790233, #F2790233)"
let color_border_orange = "light-dark(#EB6E00, #B34A01)"
let color_icon_orange = "light-dark(#E9690B, #FB8C00)"
let color_text_orange = "light-dark(#6B2203, #FDB876)"
let color_background_pink = "light-dark(#E638B333, #E638B333)"
let color_border_pink = "light-dark(#F351C0, #C02294)"
let color_icon_pink = "light-dark(#C2185B, #EC407A)"
let color_text_pink = "light-dark(#650053, #FEADE3)"
let color_background_purple = "light-dark(#7952FF33, #7952FF33)"
let color_border_purple = "light-dark(#9081FF, #7340FE)"
let color_icon_purple = "light-dark(#5B08D8, #7952FF)"
let color_text_purple = "light-dark(#3E0697, #B3B0FE)"
let color_background_red = "light-dark(#E3193B33, #E3193B33)"
let color_border_red = "light-dark(#E3193B, #F5394F)"
let color_icon_red = "light-dark(#D31130, #E3193B)"
let color_text_red = "light-dark(#7B0210, #FFB2B8)"
let color_background_teal = "light-dark(#0DB7AF33, #0DB7AF33)"
let color_border_teal = "light-dark(#08A3A3, #08767D)"
let color_icon_teal = "light-dark(#009688, #26A69A)"
let color_text_teal = "light-dark(#083943, #40DCCD)"
let color_background_yellow = "light-dark(#E2A40033, #E2A40033)"
let color_border_yellow = "light-dark(#C58600, #B47700)"
let color_icon_yellow = "light-dark(#FBC02D, #FFEE58)"
let color_text_yellow = "light-dark(#753F07, #FBCE03)"

(* spacing: 15 tokens *)
let spacing_0 = "0rem"
let spacing_0_5 = "0.125rem"
let spacing_1 = "0.25rem"
let spacing_1_5 = "0.375rem"
let spacing_2 = "0.5rem"
let spacing_3 = "0.75rem"
let spacing_4 = "1rem"
let spacing_5 = "1.25rem"
let spacing_6 = "1.5rem"
let spacing_7 = "1.75rem"
let spacing_8 = "2rem"
let spacing_9 = "2.25rem"
let spacing_10 = "2.5rem"
let spacing_11 = "2.75rem"
let spacing_12 = "3rem"

(* size: 3 tokens *)
let size_element_sm = "28px"
let size_element_md = "32px"
let size_element_lg = "36px"

(* border: 1 tokens *)
let border_width = "1px"

(* focus: 4 tokens *)
let focus_outline_width = "2px"
let focus_outline_style = "solid"
let focus_outline_color = "var(--color-accent)"
let focus_outline_offset = "3px"

(* radius: 7 tokens *)
let radius_none = "0px"
let radius_inner = "4px"
let radius_element = "8px"
let radius_container = "12px"
let radius_page = "28px"
let radius_chat = "28px"
let radius_full = "9999px"

(* shadow: 8 tokens *)
let shadow_low = "0px 1px 1px light-dark(rgba(0, 0, 0, 0.1), rgba(0, 0, 0, 0.2)), 0px 2px 8px light-dark(rgba(0, 0, 0, 0.1), rgba(0, 0, 0, 0.2))"
let shadow_med = "0px 1px 2px light-dark(rgba(0, 0, 0, 0.1), rgba(0, 0, 0, 0.2)), 0px 2px 12px light-dark(rgba(0, 0, 0, 0.1), rgba(0, 0, 0, 0.2))"
let shadow_high = "0px 2px 2px light-dark(rgba(0, 0, 0, 0.1), rgba(0, 0, 0, 0.2)), 0px 8px 24px light-dark(rgba(0, 0, 0, 0.1), rgba(0, 0, 0, 0.3))"
let shadow_inset_hover = "inset 0px 0px 0px 2px light-dark(rgba(5, 54, 89, 0.15), rgba(223, 226, 229, 0.2))"
let shadow_inset_selected = "inset 0px 0px 0px 2px rgba(1, 113, 227, 0.5)"
let shadow_inset_success = "inset 0px 0px 0px 2px rgba(38, 167, 86, 0.3)"
let shadow_inset_warning = "inset 0px 0px 0px 2px rgba(226, 164, 0, 0.3)"
let shadow_inset_error = "inset 0px 0px 0px 2px rgba(227, 25, 59, 0.3)"

(* duration: 9 tokens *)
let duration_fast_min = "130ms"
let duration_fast = "175ms"
let duration_fast_max = "230ms"
let duration_medium_min = "310ms"
let duration_medium = "410ms"
let duration_medium_max = "550ms"
let duration_slow_min = "730ms"
let duration_slow = "975ms"
let duration_slow_max = "1300ms"

(* ease: 1 tokens *)
let ease_standard = "cubic-bezier(0.24, 1, 0.4, 1)"

(* typography: 3 tokens *)
let font_family_body = "-apple-system, BlinkMacSystemFont, \"Segoe UI\", Roboto, Helvetica, Arial, sans-serif"
let font_family_code = "\"SF Mono\", Monaco, Consolas, monospace"
let font_family_heading = "-apple-system, BlinkMacSystemFont, \"Segoe UI\", Roboto, Helvetica, Arial, sans-serif"

(* text_size: 12 tokens *)
let font_size_4xs = "0.375rem"
let font_size_3xs = "0.4375rem"
let font_size_2xs = "0.5rem"
let font_size_xs = "0.625rem"
let font_size_sm = "0.75rem"
let font_size_base = "0.875rem"
let font_size_lg = "1.0625rem"
let font_size_xl = "1.25rem"
let font_size_2xl = "1.5rem"
let font_size_3xl = "1.8125rem"
let font_size_4xl = "2.1875rem"
let font_size_5xl = "2.625rem"

(* font_weight: 4 tokens *)
let font_weight_normal = "400"
let font_weight_medium = "500"
let font_weight_semibold = "600"
let font_weight_bold = "700"

(* type_scale: 42 tokens *)
let text_heading_1_size = "var(--font-size-2xl)"
let text_heading_1_weight = "var(--font-weight-semibold)"
let text_heading_1_leading = "1.3333"
let text_heading_2_size = "var(--font-size-xl)"
let text_heading_2_weight = "var(--font-weight-semibold)"
let text_heading_2_leading = "1.4"
let text_heading_3_size = "var(--font-size-lg)"
let text_heading_3_weight = "var(--font-weight-semibold)"
let text_heading_3_leading = "1.4118"
let text_heading_4_size = "var(--font-size-base)"
let text_heading_4_weight = "var(--font-weight-semibold)"
let text_heading_4_leading = "1.4286"
let text_heading_5_size = "var(--font-size-sm)"
let text_heading_5_weight = "var(--font-weight-semibold)"
let text_heading_5_leading = "1.6667"
let text_heading_6_size = "var(--font-size-xs)"
let text_heading_6_weight = "var(--font-weight-semibold)"
let text_heading_6_leading = "1.6"
let text_body_size = "var(--font-size-base)"
let text_body_weight = "var(--font-weight-normal)"
let text_body_leading = "1.4286"
let text_large_size = "var(--font-size-lg)"
let text_large_weight = "var(--font-weight-semibold)"
let text_large_leading = "1.4118"
let text_label_size = "var(--font-size-base)"
let text_label_weight = "var(--font-weight-medium)"
let text_label_leading = "1.4286"
let text_code_size = "var(--font-size-base)"
let text_code_weight = "var(--font-weight-normal)"
let text_code_leading = "1.4286"
let text_supporting_size = "var(--font-size-sm)"
let text_supporting_weight = "var(--font-weight-normal)"
let text_supporting_leading = "1.6667"
let text_display_1_size = "var(--font-size-5xl)"
let text_display_1_weight = "var(--font-weight-normal)"
let text_display_1_leading = "1.2381"
let text_display_2_size = "var(--font-size-4xl)"
let text_display_2_weight = "var(--font-weight-normal)"
let text_display_2_leading = "1.2571"
let text_display_3_size = "var(--font-size-3xl)"
let text_display_3_weight = "var(--font-weight-normal)"
let text_display_3_leading = "1.2414"

let all : (string * string) list =
  [
    "--color-accent", color_accent;
    "--color-accent-muted", color_accent_muted;
    "--color-on-accent", color_on_accent;
    "--color-neutral", color_neutral;
    "--color-background-surface", color_background_surface;
    "--color-background-body", color_background_body;
    "--color-overlay", color_overlay;
    "--color-overlay-hover", color_overlay_hover;
    "--color-overlay-pressed", color_overlay_pressed;
    "--color-background-muted", color_background_muted;
    "--color-text-primary", color_text_primary;
    "--color-text-secondary", color_text_secondary;
    "--color-text-disabled", color_text_disabled;
    "--color-text-accent", color_text_accent;
    "--color-on-dark", color_on_dark;
    "--color-on-light", color_on_light;
    "--color-icon-accent", color_icon_accent;
    "--color-icon-primary", color_icon_primary;
    "--color-icon-secondary", color_icon_secondary;
    "--color-icon-disabled", color_icon_disabled;
    "--color-background-card", color_background_card;
    "--color-background-popover", color_background_popover;
    "--color-background-inverted", color_background_inverted;
    "--color-background-error-inverted", color_background_error_inverted;
    "--color-success", color_success;
    "--color-success-muted", color_success_muted;
    "--color-on-success", color_on_success;
    "--color-error", color_error;
    "--color-error-muted", color_error_muted;
    "--color-on-error", color_on_error;
    "--color-warning", color_warning;
    "--color-warning-muted", color_warning_muted;
    "--color-on-warning", color_on_warning;
    "--color-border", color_border;
    "--color-border-emphasized", color_border_emphasized;
    "--color-skeleton", color_skeleton;
    "--color-track", color_track;
    "--color-shadow", color_shadow;
    "--color-tint-hover", color_tint_hover;
    "--color-background-blue", color_background_blue;
    "--color-border-blue", color_border_blue;
    "--color-icon-blue", color_icon_blue;
    "--color-text-blue", color_text_blue;
    "--color-background-cyan", color_background_cyan;
    "--color-border-cyan", color_border_cyan;
    "--color-icon-cyan", color_icon_cyan;
    "--color-text-cyan", color_text_cyan;
    "--color-background-gray", color_background_gray;
    "--color-border-gray", color_border_gray;
    "--color-icon-gray", color_icon_gray;
    "--color-text-gray", color_text_gray;
    "--color-background-green", color_background_green;
    "--color-border-green", color_border_green;
    "--color-icon-green", color_icon_green;
    "--color-text-green", color_text_green;
    "--color-background-orange", color_background_orange;
    "--color-border-orange", color_border_orange;
    "--color-icon-orange", color_icon_orange;
    "--color-text-orange", color_text_orange;
    "--color-background-pink", color_background_pink;
    "--color-border-pink", color_border_pink;
    "--color-icon-pink", color_icon_pink;
    "--color-text-pink", color_text_pink;
    "--color-background-purple", color_background_purple;
    "--color-border-purple", color_border_purple;
    "--color-icon-purple", color_icon_purple;
    "--color-text-purple", color_text_purple;
    "--color-background-red", color_background_red;
    "--color-border-red", color_border_red;
    "--color-icon-red", color_icon_red;
    "--color-text-red", color_text_red;
    "--color-background-teal", color_background_teal;
    "--color-border-teal", color_border_teal;
    "--color-icon-teal", color_icon_teal;
    "--color-text-teal", color_text_teal;
    "--color-background-yellow", color_background_yellow;
    "--color-border-yellow", color_border_yellow;
    "--color-icon-yellow", color_icon_yellow;
    "--color-text-yellow", color_text_yellow;
    "--spacing-0", spacing_0;
    "--spacing-0-5", spacing_0_5;
    "--spacing-1", spacing_1;
    "--spacing-1-5", spacing_1_5;
    "--spacing-2", spacing_2;
    "--spacing-3", spacing_3;
    "--spacing-4", spacing_4;
    "--spacing-5", spacing_5;
    "--spacing-6", spacing_6;
    "--spacing-7", spacing_7;
    "--spacing-8", spacing_8;
    "--spacing-9", spacing_9;
    "--spacing-10", spacing_10;
    "--spacing-11", spacing_11;
    "--spacing-12", spacing_12;
    "--size-element-sm", size_element_sm;
    "--size-element-md", size_element_md;
    "--size-element-lg", size_element_lg;
    "--border-width", border_width;
    "--focus-outline-width", focus_outline_width;
    "--focus-outline-style", focus_outline_style;
    "--focus-outline-color", focus_outline_color;
    "--focus-outline-offset", focus_outline_offset;
    "--radius-none", radius_none;
    "--radius-inner", radius_inner;
    "--radius-element", radius_element;
    "--radius-container", radius_container;
    "--radius-page", radius_page;
    "--radius-chat", radius_chat;
    "--radius-full", radius_full;
    "--shadow-low", shadow_low;
    "--shadow-med", shadow_med;
    "--shadow-high", shadow_high;
    "--shadow-inset-hover", shadow_inset_hover;
    "--shadow-inset-selected", shadow_inset_selected;
    "--shadow-inset-success", shadow_inset_success;
    "--shadow-inset-warning", shadow_inset_warning;
    "--shadow-inset-error", shadow_inset_error;
    "--duration-fast-min", duration_fast_min;
    "--duration-fast", duration_fast;
    "--duration-fast-max", duration_fast_max;
    "--duration-medium-min", duration_medium_min;
    "--duration-medium", duration_medium;
    "--duration-medium-max", duration_medium_max;
    "--duration-slow-min", duration_slow_min;
    "--duration-slow", duration_slow;
    "--duration-slow-max", duration_slow_max;
    "--ease-standard", ease_standard;
    "--font-family-body", font_family_body;
    "--font-family-code", font_family_code;
    "--font-family-heading", font_family_heading;
    "--font-size-4xs", font_size_4xs;
    "--font-size-3xs", font_size_3xs;
    "--font-size-2xs", font_size_2xs;
    "--font-size-xs", font_size_xs;
    "--font-size-sm", font_size_sm;
    "--font-size-base", font_size_base;
    "--font-size-lg", font_size_lg;
    "--font-size-xl", font_size_xl;
    "--font-size-2xl", font_size_2xl;
    "--font-size-3xl", font_size_3xl;
    "--font-size-4xl", font_size_4xl;
    "--font-size-5xl", font_size_5xl;
    "--font-weight-normal", font_weight_normal;
    "--font-weight-medium", font_weight_medium;
    "--font-weight-semibold", font_weight_semibold;
    "--font-weight-bold", font_weight_bold;
    "--text-heading-1-size", text_heading_1_size;
    "--text-heading-1-weight", text_heading_1_weight;
    "--text-heading-1-leading", text_heading_1_leading;
    "--text-heading-2-size", text_heading_2_size;
    "--text-heading-2-weight", text_heading_2_weight;
    "--text-heading-2-leading", text_heading_2_leading;
    "--text-heading-3-size", text_heading_3_size;
    "--text-heading-3-weight", text_heading_3_weight;
    "--text-heading-3-leading", text_heading_3_leading;
    "--text-heading-4-size", text_heading_4_size;
    "--text-heading-4-weight", text_heading_4_weight;
    "--text-heading-4-leading", text_heading_4_leading;
    "--text-heading-5-size", text_heading_5_size;
    "--text-heading-5-weight", text_heading_5_weight;
    "--text-heading-5-leading", text_heading_5_leading;
    "--text-heading-6-size", text_heading_6_size;
    "--text-heading-6-weight", text_heading_6_weight;
    "--text-heading-6-leading", text_heading_6_leading;
    "--text-body-size", text_body_size;
    "--text-body-weight", text_body_weight;
    "--text-body-leading", text_body_leading;
    "--text-large-size", text_large_size;
    "--text-large-weight", text_large_weight;
    "--text-large-leading", text_large_leading;
    "--text-label-size", text_label_size;
    "--text-label-weight", text_label_weight;
    "--text-label-leading", text_label_leading;
    "--text-code-size", text_code_size;
    "--text-code-weight", text_code_weight;
    "--text-code-leading", text_code_leading;
    "--text-supporting-size", text_supporting_size;
    "--text-supporting-weight", text_supporting_weight;
    "--text-supporting-leading", text_supporting_leading;
    "--text-display-1-size", text_display_1_size;
    "--text-display-1-weight", text_display_1_weight;
    "--text-display-1-leading", text_display_1_leading;
    "--text-display-2-size", text_display_2_size;
    "--text-display-2-weight", text_display_2_weight;
    "--text-display-2-leading", text_display_2_leading;
    "--text-display-3-size", text_display_3_size;
    "--text-display-3-weight", text_display_3_weight;
    "--text-display-3-leading", text_display_3_leading;
  ]

let find name = List.Assoc.find all ~equal:String.equal name
