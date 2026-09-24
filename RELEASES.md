# scalekey version 1.11

English | [日本語](RELEASES.ja.md)

**Updated:** August 26, 2026\
**Author:** UG.

---

## Overview

Added support for running alongside an external sound driver that supports\
MIDI output.

---

## 1. New Features and Enhancements

- Added a **mode in which the MIDI interface (YM3802) is left untouched**.

  When made resident with the `-n` switch, scalekey does not initialise the\
  MIDI interface. Use it when a sound driver that supports MIDI output is kept\
  resident.\
  In this mode, playing via MIDI input is not available (keyboard performance\
  still works).

  ```
  scalekey -n
  ```

  The mode is fixed when scalekey is made resident and cannot be changed\
  afterwards.

---

## 2. Requirements and Limitations

- A **MIDI board** is required for MIDI input.\
  Without one, only keyboard performance is available.
- **A single scalekey cannot be used from more than one host at the same time.**\
  The host that claims it first keeps it until it exits.
- **Remove a resident v1.11 with v1.10 or later.**\
  v1.11 and v1.00 / v1.01 do not recognise each other, so those older builds\
  cannot remove v1.11.
- Verified on an X68000 emulator environment.

---

## 3. Notes

- scalekey runs as a TSR (Terminate and Stay Resident) process.
- It is designed to be used together with
  **[OPM Tone Editor 'Ｎ'](https://github.com/shimase68000/opm-tone-editor-n) v1.21**.\
  From the editor, `scalekey.midi_enable` in `oe.jsn` provides the equivalent of `-n`.\
  See the editor's
  [RELEASES](https://github.com/shimase68000/opm-tone-editor-n/blob/main/RELEASES.md)
  for details.

---

<footer>
<p align="center">Copyright (c) 2026 UG. All rights reserved.</p>
</footer>
