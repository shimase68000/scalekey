# scalekey

[English](README.md) | [日本語](README.ja.md)

scalekey is a resident performance module for the YM2151 (OPM) that runs on
Human68k on the X68000.
It provides host applications with the ability to play the OPM from the X68000
keyboard or a MIDI keyboard.

---

## Overview

scalekey stays resident and takes care of **driving the OPM**.

A host application asks scalekey to play, and scalekey handles key input,
channel assignment, and the OPM registers.
Because scalekey takes care of playback, the host can concentrate on its own work.

v1.10 extends the performance features.
**Unison, delay, and detune** were added, so a single note can now be sounded
across several OPM channels.
The channel assignment methods were also extended, and **Slotmask** is now
supported.

---

## Key Features

- **Play the OPM from the X68000 keyboard** (two octaves plus octave shift)
- **Play the OPM from MIDI IN** (MIDI board required)
- **Unison (0–8 voices)**, **delay**, and **per-channel detune**
- **Select the OPM channels used for playing**, and specify the **assign start channel**
- **Channel assignment method** — Sequential / RoundRobin, each with Hold / Over
- **Slotmask** — specify which operators are keyed on
- **MIDI channel filter** — OFF / Any / Ch.1–16
- **On-screen display** of channel state and the note being played
- **Resident and removable** from the command line

---

## System Structure

scalekey is the performance half of a two-part system.

- The **host** decides what to play and owns the tone data.
- **scalekey** owns key input, channel assignment, and the OPM registers.

The two communicate through a TRAP #7 interface. scalekey is written so that any
host can drive it, but at present the only host is
**[OPM Tone Editor 'Ｎ'](https://github.com/shimase68000/opm-tone-editor-n)**.

The TRAP #7 interface is not documented here, since it may still change.
If you want to drive scalekey yourself, see `proj/src/trap7.s`.

> A single scalekey cannot be used from more than one host at the same time.
> The host that claims it first keeps it until it exits.

---

## Usage

```
usage: scalekey [switch]
switch:  -r  remove the resident copy
         -s  quiet mode
```

Running `scalekey` with no switch makes it resident.
Running `scalekey -r` removes it.

When used with OPM Tone Editor 'Ｎ', you normally do not need to run scalekey by
hand — the editor loads and unloads it
(`scalekey.load_on_startup` / `unload_on_exit` in `oe.jsn`).

---

## Requirements

- X68000 running Human68k
- A MIDI board is required for MIDI input.
  Keyboard performance works without one.

Verified on an X68000 emulator environment.

---

## Installation

Download the distribution archive from Releases and extract it to any location.

- [Releases](../../releases)

To use it with OPM Tone Editor 'Ｎ', place `scalekey.r` somewhere on your `PATH`.

- [OPM Tone Editor 'Ｎ'](https://github.com/shimase68000/opm-tone-editor-n) / [OPM Tone Editor 'Ｎ' Releases](https://github.com/shimase68000/opm-tone-editor-n/releases)

OPM Tone Editor 'Ｎ' v1.20 works with scalekey v1.10 or later.

---

## Source Code

The `proj/` directory contains the source code (`inc/`, `src/`, `Makefile`).
It is published as a reference; a detailed build environment guide is not
currently provided.
For normal use, please use the distribution archive from Releases.

---

## License

This project is released under the MIT License.

Copyright (c) 2025-2026 UG.
