# QMK userspace

Firmware for the Corne 36 LP (Keebmaker, wired, Pro Micro / ATmega32U4 with
the Caterina bootloader). `tasks/qmk.yml` installs QMK and points it at this
directory as an [external userspace](https://docs.qmk.fm/newbs_external_userspace),
with `crkbd/rev1` + `petka` as the default build target.

```plain
qmk/
├── qmk.json                         # userspace manifest + build target
├── keyboards/crkbd/keymaps/petka/   # keymap.c, config.h, rules.mk
└── backups/                         # stock firmware read off each half
```

## Layout

GACS home row mods (Cmd, Alt, Ctrl, Shift from pinky to index) on the base
layer, and on the Symbols layer's left home row to pair with its numpad.
Tuned with Chordal Hold, Permissive Hold, and Flow Tap. Thumbs:
`— · Space · Nav | Sym · Backspace · —`; the outer thumbs are empty, so mods
come only from the home rows. Holding Nav and Sym together gives the Monitor
layer, where `F` or `J` sends F20: skhd runs `~/.local/bin/monitor-switch`,
which switches the BenQ (and its KVM) to the other Mac. The OLEDs show the
layer name and the underglow colour follows the layer.

## Build and flash

```bash
qmk compile            # check the size line: the 32U4 has 28672 bytes for firmware
qmk flash              # waits for the bootloader: double-press the half's reset button
```

Flash each half on its own: USB in, TRRS cable out. Both halves take the same
firmware. Whichever half has USB acts as the left half, so with both halves
connected, plug USB into the left one. Always connect the TRRS cable before USB:
hot-plugging it can short the controller.

Holding `Q` (left) or `P` (right) while plugging in also enters the bootloader
and clears EEPROM. Use this if a half misbehaves after a flash.

## Backups and reverting

`backups/` holds the Keebmaker firmware, read through the bootloader before the
first flash (both halves were identical):

- `stock-full-chip.hex`: the whole flash as read, Caterina bootloader included
- `stock-firmware.hex`: the same minus the bootloader region (0x7000+), the
  file to restore with. Caterina refuses writes to its own region.
- `left-eeprom.hex`, `right-eeprom.hex`: each half's EEPROM (VIA keymap,
  lighting settings)

The bootloader itself is never overwritten, so a double-press of reset always
gets back to a flashable state. To restore a half, double-press its reset
button, then within 8 seconds:

```bash
AVRDUDE="$HOME/Library/Application Support/qmk/bin/avrdude"
"$AVRDUDE" -p atmega32u4 -c avr109 -P /dev/cu.usbmodem* \
  -U flash:w:backups/stock-firmware.hex:i -U eeprom:w:backups/left-eeprom.hex:i
```
