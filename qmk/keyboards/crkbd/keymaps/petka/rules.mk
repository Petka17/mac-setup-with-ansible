# The Pro Micro (ATmega32U4) has ~28 KB for firmware, so keep only what the
# keymap uses.
LTO_ENABLE = yes
VIA_ENABLE = no
MOUSEKEY_ENABLE = no
CONSOLE_ENABLE = no
COMMAND_ENABLE = no

OLED_ENABLE = yes

# Static per-layer underglow colours via rgblight instead of the keyboard's
# default RGB Matrix, whose effects take several KB.
RGB_MATRIX_ENABLE = no
RGBLIGHT_ENABLE = yes
