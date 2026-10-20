#pragma once

// Home row mods. QMK's recommended starting point:
// https://docs.qmk.fm/tap_hold#configuring-home-row-mods
#define TAPPING_TERM 250
#define PERMISSIVE_HOLD // another key tapped while a mod-tap is held -> hold
#define CHORDAL_HOLD    // a mod-tap only holds with a key on the other hand
#define FLOW_TAP_TERM 150 // while typing fast, mod-taps always tap

// The OLED on the right (non-USB) half shows the layer too.
#define SPLIT_LAYER_STATE_ENABLE

// Static colours only: no animation modes are compiled in. The cap keeps the
// 54 LEDs well inside what a USB port supplies; replaces the keyboard's 120.
#undef RGBLIGHT_LIMIT_VAL
#define RGBLIGHT_LIMIT_VAL 80
#define RGBLIGHT_DEFAULT_MODE RGBLIGHT_MODE_STATIC_LIGHT
