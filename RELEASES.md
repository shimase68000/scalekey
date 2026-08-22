# scalekey version 1.10

English | [日本語](RELEASES.ja.md)

**Updated:** August 22, 2026  
**Author:** UG.

---

## Overview

v1.10 extends the performance features.

**Unison, delay, and detune** were added, so a single note can now be sounded
across several OPM channels.
The channel assignment methods were also extended, and **Slotmask** is now
supported.

---

## 1. New Features and Enhancements

### Performance

- Added **unison playback (UNISON 0–8 voices [0: Mute])**.
  A single note is layered across several OPM channels.
- Added **delay**.
  Each unison voice is sounded slightly after the previous one.
- Added **detune**.
  The pitch is offset per OPM channel.

### Channel Assignment

- The **channel assignment method** can be specified.
  - **Sequential (SEQ)** … take the lowest free channel in order
  - **RoundRobin (RDR)** … continue from the channel after the last one used

- The **behavior when no channel is free** can now be specified.
  - **Hold (first-come priority)** … keep the sounding channels and do not play the new note
  - **Over (last-come priority)** … stop the oldest channel and play the new note

- The **assign start channel** can now be specified.
  The base channel used when assigning can be chosen from Ch.A–H.

### Tone

- Added **Slotmask** support.
  You can specify which operators are keyed on, per tone.

---

## 2. Requirements and Limitations

- A **MIDI board** is required for MIDI input.
  Without one, only keyboard performance is available.
- **A single scalekey cannot be used from more than one host at the same time.**
  The host that claims it first keeps it until it exits.
- **Remove a resident v1.10 with v1.10 or later.**
  v1.10 and v1.00 / v1.01 do not recognise each other, so an older build cannot
  remove v1.10.
- Verified on an X68000 emulator environment.

---

## 3. Notes

- scalekey runs as a TSR (Terminate and Stay Resident) process.
- It is designed to be used together with
  **[OPM Tone Editor 'Ｎ'](https://github.com/shimase68000/opm-tone-editor-n) v1.20**.
  See the editor's
  [RELEASES](https://github.com/shimase68000/opm-tone-editor-n/blob/main/RELEASES.md)
  for details.

---

<footer>
<p align="center">Copyright (c) 2026 UG. All rights reserved.</p>
</footer>
