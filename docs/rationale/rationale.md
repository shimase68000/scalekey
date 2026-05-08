# Rationale — scalekey

## Background

OPM Tone Editor 'N' was originally built as a single process.

Tone editing and real-time playback lived together in the same program.\
The keyboard input handler, the MIDI input handler, and the parameter editor
all ran as one unit.

This worked well enough in early versions.\
But as the playback functionality grew — polyphonic support, MIDI input,\
channel assignment policies — a tension became visible.

The editor needed to be responsive to the user.\
The playback engine needed to be responsive to the instrument.

These are different kinds of responsiveness,\
and they do not coexist easily in the same process.

---

## The Problem

An editor is driven by user events.\
It waits, then responds.

A real-time playback engine is driven by timing.\
It cannot wait.

When both responsibilities live in the same process,\
each one imposes constraints on the other.\
The editor's workload can cause latency in note triggering.\
The playback handler can interfere with the editor's responsiveness.

More concretely:\
a parameter change that triggers screen redraw,\
a file load that takes a few milliseconds,\
a menu operation that requires keyboard focus —\
any of these can disrupt the timing of a note that should have fired immediately.

On a resource-constrained system like the X68000,\
where scheduling is not preemptive and there is no OS-level isolation between tasks,\
this tension is not theoretical. It is a practical constraint.

---

## The Decision

In version 1.10, the playback functionality was extracted from Tone Editor\
and moved into an independent module: **scalekey**.

scalekey runs as a TSR (Terminate and Stay Resident) process.\
It resides in memory alongside Tone Editor,\
receives input from keyboard and MIDI,\
and sends note-on / note-off directly to the OPM chip.

Tone Editor controls scalekey — loading it at startup,\
configuring its parameters, unloading it on exit.\
But Tone Editor does not execute playback itself.

This separation means:

- Tone Editor can focus entirely on editing
- scalekey can focus entirely on real-time response
- each can be developed, tested, and extended independently

---

## Why Assembly

scalekey is implemented in 68000 assembly only.

Tone Editor is written in C with partial assembly.\
scalekey is assembly throughout.

This is not a historical accident.\
It is a deliberate choice made for the same reason\
that the two processes were separated in the first place:

real-time input handling on the X68000\
requires predictable, low-overhead execution.

C introduces indirection — function call overhead,\
stack frame setup, compiler-generated sequences\
that are correct but not always minimal.\
For the input polling loop and note dispatch path,\
these costs are not acceptable.

Assembly gives direct control over what happens\
at each instruction boundary.\
The latency between a key press and a note reaching the OPM\
can be minimized precisely because nothing is hidden.

---

## Why TSR

A TSR process stays resident after its initial execution.\
It remains in memory and can be invoked by other processes.

This architecture was chosen for two reasons.

First, it matches the operational model of the X68000.\
TSR is an established pattern on Human68k,\
used by system utilities, input drivers, and resident tools.\
scalekey fits naturally into this pattern.

Second, it makes scalekey transparent to the user.\
Tone Editor manages the scalekey lifecycle:\
loading it when needed, configuring it according to OE.JSN,\
unloading it on exit.

The user does not need to know that scalekey is a separate process.\
From the user's perspective, real-time playback is simply part of Tone Editor.\
The separation is an implementation detail, not a user-facing concept.

---

## The Interface: TRAP #7

The two processes communicate through TRAP #7,\
with a routine number in d0.

TRAP #7 was chosen as an available trap vector\
that does not conflict with sound drivers or other resident tools\
commonly used in X68000 music environments.

The interface provides 15 entry points (routine0–14) through which\
a master tool configures and controls scalekey at runtime:

- Process management (TSR exit, main loop address)
- Display control (on/off, position, MIDI marker)
- Note control (offset, octave shift, keyin enable)
- Channel management (select, assign policy, unison/poly)
- MIDI control (channel filter, board status, keyoff all)
- Device control (slotmask)

Version information is returned by multiple API calls,\
allowing a master tool to confirm scalekey's capabilities\
during its initialization sequence without a dedicated version check call.

The range check in the TRAP #7 handler:

```asm
cmp.w   #NUM_OF_PROC,d0
bhi     trap7_exit      ; out of range → ignore
```

ensures forward compatibility.\
Unknown routine numbers are silently ignored,\
allowing older master tools to work with newer versions of scalekey\
without modification.

---

## Relationship to OPM Tone Editor

scalekey does not run autonomously.\
Tone Editor obtains the main loop address via TRAP #7 routine 7,\
and drives it by polling from its own main loop.

This is intentional.

Sound drivers such as MDX players use timer interrupts for playback.\
If scalekey also used timer interrupts, conflicts would be likely.\
By using polling instead, Tone Editor and scalekey can coexist\
with external sound drivers running simultaneously.

scalekey does not share state with the editor's internal data structures.\
The TRAP #7 interface is the boundary.\
What happens on each side of it is independent.

---

## Keyboard and MIDI: A Unified Path

Keyboard input and MIDI input are handled differently at the hardware level,\
but they converge on the same entry points:\
`note_keyon` and `note_keyoff`.

Neither function knows or cares which input device triggered it.\
The channel assignment policy, polyphonic count, and channel selection\
apply equally to both.

This is why keyboard and MIDI can be used simultaneously —\
playing with a PC keyboard in one hand and a MIDI keyboard in the other,\
as if playing an electronic organ.\
The unified path makes this a natural consequence of the design,\
not a special feature.

### Sequential and RoundRobin

Two channel assignment policies are available:

**Sequential** assigns channels starting from the lowest available each time.\
This produces deterministic, machine-like behavior —\
the same note sequence always results in the same channel assignment.\
Suitable for tone verification and alignment with MDX-style playback.

**RoundRobin** advances the scan offset with each assignment.\
This distributes notes across channels in rotation,\
allowing a note to sustain on its channel while the next note\
begins on a fresh one.\
The result is natural overlap — closer to real performance,\
where notes from a live keyboard do not wait for previous notes to end.

### keyin_enable

A separate flag controls keyboard input independently of MIDI input.

When Tone Editor requires keyboard focus for text input —\
tone names, file memos, FEP-based Japanese input —\
keyboard note triggering can be suspended without affecting MIDI input.

A corresponding `midi_enable` flag is planned,\
providing independent control of each input path.\
When OPM access must be suspended entirely,\
both flags can be disabled independently.

---

## OPM Channel Partitioning

`channel_select` defines which OPM channels scalekey may use.\
`poly_count` defines the maximum simultaneous notes within those channels.

This allows the OPM's eight channels to be partitioned by purpose:

```
ch.A–D : external sound driver (MDX playback)
ch.E–F : scalekey (tone editing and confirmation)
ch.G–H : unused
```

Combined with the absence of timer interrupts,\
this partitioning ensures complete coexistence with external sound drivers —\
no interrupt conflicts, no register write conflicts.

Tone editing can happen against a musical backdrop,\
with the sound driver providing the context\
in which the edited tone will eventually be used.

---

## slotmask

Each OPM channel has an independent slotmask value\
controlling which operators (OP1–OP4) are active on key-on.

slotmask and operator topology (OTG) are independent.\
OTG describes the connection structure.\
slotmask selects which operators within that structure are active.

Tone Editor can modify slotmask values directly,\
and they are stored as part of the tone data (OPMDATA).\
On key-on, the stored slotmask is written to the OPM register,\
ensuring that the saved tone reproduces exactly as edited.

---

## scalekey as a Common Slave Engine

The separation from Tone Editor was not only about solving\
the tension between editing and playback.

It was also about making scalekey usable by any master tool\
that needs to drive OPM in real time.

The design intent, stated simply:\
*if the master changes, scalekey should still work as a common slave.*

This was not a concrete plan at the time of separation.\
It was a decision not to close off options\
that a future master might need.

The result is an architecture where different master tools\
can use the same slave engine:

```
Tone Editor   → master: tone editing    / slave: scalekey
Motif Editor  → master: phrase editing  / slave: scalekey
Other Editor  → master: other purposes  / slave: scalekey
```

Tone data is passed to scalekey as a pointer from the master,\
not loaded by scalekey itself.\
This keeps file I/O in the master's domain,\
and keeps scalekey focused on what it does:\
receive notes, assign channels, write to OPM.

---

## Timer Interrupts — A Reservation

The absence of timer interrupts in the current implementation\
is not a limitation. It is a reservation.

In Tone Editor v0.07, the upper center pane was left empty —\
not because it was unfinished,\
but because it was held open for future use.\
That space was filled in v1.00.

The current decision to avoid timer interrupts follows the same logic.

The present design assumes coexistence with external sound drivers.\
In that environment, timer interrupts belong to those drivers,\
and scalekey stays out of their way.

A future design is planned in which scalekey —\
or a module integrated with it —\
manages its own sound driver and takes ownership of timer interrupts.

At that point, two modes will exist:

**External sound driver mode**\
Timer interrupts unused by scalekey.\
Tone Editor drives scalekey via polling.\
External drivers run alongside without conflict.

**Internal sound driver mode**\
scalekey (or an integrated module) owns timer interrupts.\
Tone Editor and scalekey form a self-contained performance environment.

The current implementation is the first mode.\
The second mode is what the reservation is for.

---

## Future Direction

Planned extensions to scalekey's capabilities,\
each of which will correspond to new TRAP #7 API entries:

- Unison with more than one simultaneous channel
- Portamento
- MIDI velocity, pitch bend, and aftertouch
- MIDI program change with tone pointer from master
- Real-time phrase recording and playback (MED format)
- Internal sound driver (possibly integrated with scalekey)
- Direct VRAM writing for display (replacing IOCS calls)

### On Phrase Recording

The same philosophy that treats tone data as a primary resource\
is intended to extend to phrase data.

A phrase captured in the moment — a fragment of improvisation,\
a motif that emerged without planning —\
is material for future composition.

Recorded phrase data is intended to remain as raw as possible:\
note-on/off events, timing, and velocity\
preserved without quantization or abstraction.

Quantization discards information.\
The nuance of a phrase played in the moment\
is precisely what makes it worth keeping.\
Whether to quantize is a decision for later, not for the recorder.

Over time, recorded phrases can be organized into a motif library —\
a collection of starting points,\
in the same way that an OED file is a collection of tonal starting points.

The format for this data is not yet finalized,\
but is expected to follow the naming convention of the ecosystem\
(tentatively: **MED — Motif Editor Data**).

### On the Evolving Ecosystem

When phrase recording, internal sound driver,\
and MIDI program change are all in place,\
the ecosystem reaches a new level of coherence:

```
Motif Editor
    ↓ MED  → phrase data
    ↓ OED  → tone data (pointer passed to scalekey)
    ↓ TRAP #7 → scalekey
scalekey
    ↓ OPM
YM2151
```

The editor shapes the tones.\
The format stores and organizes them.\
The playback engine applies them in real time.\
The recorder captures what emerged.

---

## Summary

scalekey exists because editing and playing\
are fundamentally different responsibilities.

Separating them is not an optimization.\
It is a recognition of what each task actually requires.

The editor requires user-responsiveness.\
The playback engine requires timing-responsiveness.

The design does not predict the future.\
It avoids closing off options that the future might need.

The current absence of timer interrupts is not a gap.\
It is a held position —\
the same kind of held position that left a blank space\
in the center pane of v0.07,\
waiting for what would eventually fill it.
