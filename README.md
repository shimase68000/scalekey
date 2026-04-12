# scalekey

Real-time keyboard and MIDI input with tone control for X68000

---

## Overview

scalekey is a real-time input and tone control tool for the Sharp X68000.

It is designed to receive input from both keyboard and MIDI,
and trigger tone generation in real time.

This tool is primarily used together with **OPM Tone Editor 'N'**,
where it serves as a real-time input and playback component.

---

## Features

* Real-time keyboard input
* Real-time MIDI input
* Tone trigger and control
* Designed for low-latency operation
* Intended for integration with other tools

---

## Design Concept

scalekey separates input handling and tone control from the editor.

* Editor (Tone Editor) handles parameter editing
* scalekey handles real-time input and playback

This separation allows:

- simpler editor design
- reusable input/control logic
- flexible system configuration
- more efficient debugging
- easier extension of functionality

---

## Current Status

This project is under active development.

The source code is not included at this time due to ongoing refactoring and cleanup,
particularly around MIDI I/O implementation.

The repository currently provides documentation, including a rationale describing the design.

---

## Future Direction

Future extensions may include real-time recording and playback capabilities.

---

## Relationship with OPM Tone Editor

scalekey is designed to work with:

OPM Tone Editor 'N'

* Tone Editor: editing and data management
* scalekey: real-time input and tone triggering

Together, they form a modular FM sound system.

---

## Notes on MIDI

MIDI functionality is part of the design, but the current implementation is being reviewed.

The MIDI I/O layer will be reimplemented in a clean and well-defined form.

---

## License

MIT License
