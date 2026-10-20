#include QMK_KEYBOARD_H

enum layers {
    _BASE,
    _SYM, // symbols + numbers
    _NAV, // navigation, numbers, media
    _MON, // Nav + Sym held together: monitor input switch
};

// Home row mods, GACS: Cmd, Alt, Ctrl, Shift from pinky to index.
#define HM_A LGUI_T(KC_A)
#define HM_S LALT_T(KC_S)
#define HM_D LCTL_T(KC_D)
#define HM_F LSFT_T(KC_F)
#define HM_J LSFT_T(KC_J)
#define HM_K LCTL_T(KC_K)
#define HM_L LALT_T(KC_L)
#define HM_SCLN LGUI_T(KC_SCLN)

// The same mods on the Symbols layer's left home row, so they combine with the
// numpad on the right. Mod-taps can only tap basic keycodes, so ( and ) are
// stored as 9 and 0 and their taps are sent shifted in process_record_user.
#define SM_QUOT LGUI_T(KC_QUOT)
#define SM_MINS LALT_T(KC_MINS)
#define SM_LPRN LCTL_T(KC_9)
#define SM_RPRN LSFT_T(KC_0)

// Tap: 4. Hold: Cmd+Shift+4 (macOS area screenshot). LT(0, ...) only borrows
// the tap-hold machinery; the hold is handled in process_record_user.
#define SCRNSHT LT(0, KC_4)

// Tap: F20, which skhd binds to ~/.local/bin/monitor-switch (switch the BenQ
// and its KVM to the other Mac). No Mac keyboard has an F20, so it can't
// collide with an app shortcut.
#define MON_SW KC_F20

// clang-format off
const uint16_t PROGMEM keymaps[][MATRIX_ROWS][MATRIX_COLS] = {
    [_BASE] = LAYOUT_split_3x5_3(
        KC_Q,    KC_W,    KC_E,    KC_R,    KC_T,         KC_Y,    KC_U,    KC_I,    KC_O,    KC_P,
        HM_A,    HM_S,    HM_D,    HM_F,    KC_G,         KC_H,    HM_J,    HM_K,    HM_L,    HM_SCLN,
        KC_Z,    KC_X,    KC_C,    KC_V,    KC_B,         KC_N,    KC_M,    KC_COMM, KC_DOT,  KC_SLSH,
                          XXXXXXX, KC_SPC,  MO(_NAV),     MO(_SYM), KC_BSPC, XXXXXXX
    ),
    [_SYM] = LAYOUT_split_3x5_3(
        KC_DQUO, KC_EQL,  KC_LCBR, KC_RCBR, KC_BSLS,      KC_0,    KC_1,    KC_2,    KC_3,    _______,
        SM_QUOT, SM_MINS, SM_LPRN, SM_RPRN, KC_PIPE,      KC_ENT,  SCRNSHT, KC_5,    KC_6,    XXXXXXX,
        KC_GRV,  KC_PLUS, KC_LBRC, KC_RBRC, KC_TILD,      G(KC_ENT), KC_7,  KC_8,    KC_9,    XXXXXXX,
                          XXXXXXX, KC_LSFT, _______,      _______, _______, XXXXXXX
    ),
    [_NAV] = LAYOUT_split_3x5_3(
        KC_0,    KC_1,    KC_2,    KC_3,    KC_DEL,       KC_HOME, KC_PGDN, KC_PGUP, KC_END,  KC_MUTE,
        KC_ESC,  KC_4,    KC_5,    KC_6,    KC_BSPC,      KC_LEFT, KC_DOWN, KC_UP,   KC_RGHT, KC_VOLU,
        _______, KC_7,    KC_8,    KC_9,    KC_ENT,       G(KC_N), KC_TAB,  S(KC_TAB), KC_LGUI, KC_VOLD,
                          XXXXXXX, XXXXXXX, _______,      _______, _______, XXXXXXX
    ),
    // Everything else is a no-op, so only F or J can fire it.
    [_MON] = LAYOUT_split_3x5_3(
        XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX,      XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX,
        XXXXXXX, XXXXXXX, XXXXXXX, MON_SW,  XXXXXXX,      XXXXXXX, MON_SW,  XXXXXXX, XXXXXXX, XXXXXXX,
        XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX,      XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX,
                          XXXXXXX, XXXXXXX, _______,      _______, XXXXXXX, XXXXXXX
    ),
};

// Thumbs are exempt from Chordal Hold's opposite-hands rule, so a home row
// mod still holds when combined with a thumb on the same hand.
const char chordal_hold_layout[MATRIX_ROWS][MATRIX_COLS] PROGMEM = LAYOUT_split_3x5_3(
    'L', 'L', 'L', 'L', 'L',      'R', 'R', 'R', 'R', 'R',
    'L', 'L', 'L', 'L', 'L',      'R', 'R', 'R', 'R', 'R',
    'L', 'L', 'L', 'L', 'L',      'R', 'R', 'R', 'R', 'R',
                   '*', '*', '*', '*', '*', '*'
);
// clang-format on

bool process_record_user(uint16_t keycode, keyrecord_t *record) {
    switch (keycode) {
        case SCRNSHT:
            if (!record->tap.count && record->event.pressed) {
                tap_code16(G(S(KC_4)));
                return false;
            }
            break;
        case SM_LPRN:
            if (record->tap.count && record->event.pressed) {
                tap_code16(KC_LPRN);
                return false;
            }
            break;
        case SM_RPRN:
            if (record->tap.count && record->event.pressed) {
                tap_code16(KC_RPRN);
                return false;
            }
            break;
    }
    return true;
}

static void set_layer_color(uint8_t layer) {
    switch (layer) {
        case _SYM:
            rgblight_sethsv_noeeprom(HSV_ORANGE);
            break;
        case _NAV:
            rgblight_sethsv_noeeprom(HSV_GREEN);
            break;
        case _MON:
            rgblight_sethsv_noeeprom(HSV_MAGENTA);
            break;
        default:
            rgblight_sethsv_noeeprom(HSV_AZURE);
            break;
    }
}

void keyboard_post_init_user(void) {
    // _noeeprom: ignore whatever lighting state the previous firmware left in
    // EEPROM.
    rgblight_enable_noeeprom();
    rgblight_mode_noeeprom(RGBLIGHT_MODE_STATIC_LIGHT);
    set_layer_color(_BASE);
}

layer_state_t layer_state_set_user(layer_state_t state) {
    state = update_tri_layer_state(state, _SYM, _NAV, _MON);
    set_layer_color(get_highest_layer(state));
    return state;
}

#ifdef OLED_ENABLE
// Replaces the keyboard's default screens (layer + key log on the left, logo
// on the right) with the layer name on both halves.
bool oled_task_user(void) {
    oled_write_P(PSTR("Layer: "), false);
    switch (get_highest_layer(layer_state)) {
        case _SYM:
            oled_write_ln_P(PSTR("Symbols"), false);
            break;
        case _NAV:
            oled_write_ln_P(PSTR("Nav"), false);
            break;
        case _MON:
            oled_write_ln_P(PSTR("Monitor"), false);
            break;
        default:
            oled_write_ln_P(PSTR("Base"), false);
            break;
    }
    return false;
}
#endif
