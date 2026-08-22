;
; ym3802.s
;
;	YM3802 (MCS) MIDI interface control
;
;   This module is always entered in supervisor mode - it accesses the
;   I/O area and masks interrupts with ori.w #$700,sr.
;
;   Subroutines save SR on entry and return with "move.w (sp)+,sr" + rts.
;   That relies on the saved SR having S = 1: move.w (sp)+,sr switches the
;   active stack between SSP and USP the instant the S bit is restored, so
;   a path that reached S = 0 would make the following rts pop from the
;   wrong stack.
;   irq0_realtime_msg - irq7_global_timer are real interrupt handlers and
;   return with rte. Do not convert between the two forms.
;
;----------------------------------

	.include	iocscall.mac

;----------------------------------

	.xdef	mcs_init
	.xdef	mcs_receive
	.xdef	mcs_check
	.xdef	restore_mcsvector

;----------------------------------
REGBASE		.equ	$EAFA01
MCS_VECNO	.equ	$80		; first MCS interrupt vector NUMBER.
							;  mcs_init also writes this to the IVR
							;  (bank 0 R4), so the two must agree.
MCS_VECSTEP	.equ	2		; step between vector numbers.
							;  *** NEEDS CONFIRMATION ***
							;  A 68000 exception vector normally occupies
							;  one vector number per 4 bytes, yet the numbers
							;  advance by 2 here ($80,$82,...,$8E). MIDI input
							;  demonstrably works on real hardware, so the
							;  assumption is that the YM3802 drives the low
							;  bits of its IVR in steps of 2. Update this once
							;  the datasheet confirms or refutes it.

	.offset	0

; The YM3802 is an 8-bit device mapped on odd addresses, so the
; register window has a 2-byte stride and every access is move.b.
; R1 is the bank select register: the meaning of R0 and R2-R7
; depends on the bank currently selected.

R0:	.ds.w	1
R1:	.ds.w	1
R2:	.ds.w	1
R3:	.ds.w	1
R4:	.ds.w	1
R5:	.ds.w	1
R6:	.ds.w	1
R7:	.ds.w	1

	.text

;------------------------------------------------=
;	Check MCS
;-------------------------------------------------
;  Out   : d0.l =  0: installed
;		          -1: not installed
;
;  Note  : Temporarily replaces the bus error vector with a local
;          handler, reads REGBASE, and decides whether the MIDI board
;          is present from whether an exception occurred.
;          On an exception, buserr_handler restores SP from the saved value,
;          so the routine does not depend on the exception frame size,
;          which differs per CPU (68000: 14 bytes, 68030: up to 92
;          bytes, and so on).
;          Saving and restoring SP is not a speed optimisation but
;          the key to portability - do not remove it.
;
;  Note  : The direct reference to $0008 assumes VBR = 0. This is the
;          only VBR = 0 dependency in this file.
;------------------------------------------------=
mcs_check:
	movem.l	a0-a1,-(sp)

	move.w	sr,-(sp)
	ori.w	#$700,sr
	movea.l	#$0008,a1

	lea.l	buserr_saved_sp(pc),a0
	move.l	sp,(a0)+
	move.l	(a1),(a0)
	lea.l	buserr_handler(pc),a0
	move.l	a0,(a1)

	movea.l	#REGBASE,a0
	tst.b	(a0)
	moveq.l	#0,d0		; installed
	bra		1f

buserr_handler:
	movea.l	buserr_saved_sp(pc),sp
	moveq.l	#-1,d0		; not installed
1:
	move.l	buserr_saved_vector(pc),(a1)
	move.w	(sp)+,sr

	movem.l	(sp)+,a0-a1

	rts

;----------------------------------
;	init mcs
;----------------------------------
;  In    : none
;  Out   : none
;  Break : none
;
;  Note  : a6 holds REGBASE across the IOCS call made inside set_mcsvector.
;          This relies on the IOCS convention that nothing except d0
;          and documented return values is destroyed.
;----------------------------------
mcs_init:
	move.w	sr,-(sp)
	movem.l	d0/a6,-(sp)
	ori.w	#$700,sr

	movea.l	#REGBASE,a6
	move.b	#%1000_0000,R1(a6)
	bsr		mcs_wait
	clr.b	R1(a6)			; release reset (bank 0 selected)
	move.b	#MCS_VECNO,R4(a6)	; IVR = base vector number

	bsr		set_mcsvector

	clr.b	R1(a6)
	clr.b	R6(a6)			; disable mcs interrupt

	move.b	#6,R1(a6)
	move.b	#%0000_0010,R6(a6)

	; The three timer/counter values below are part of the init sequence,
	; but the interrupts they would raise (IRQ7 global timer, IRQ1 MIDI
	; clock) are disabled, so nothing consumes them.
	move.w	#1000,d0
	bsr		set_global_timer

	move.w	#500,d0
	bsr		set_midiclock_timer

	move.w	#24,d0
	bsr		set_click_counter

	move.b	#6,R1(a6)	
	move.b	#%1001_0100,R5(a6)

	move.b	#5,R1(a6)	
	move.b	#%1000_0000,R5(a6)

@@:
	btst.b	#0,R4(a6)
	bne		@b

	move.b	#4,R1(a6)
	move.b	#%0000_1000,R4(a6)
	move.b	#%0000_0000,R5(a6)

	move.b	#3,R1(a6)
	move.b	#%1001_0000,R5(a6)

@@:
	btst.b	#0,R4(a6)
	bne		@b

	move.b	#2,R1(a6)
	move.b	#%0000_1000,R4(a6)
	move.b	#%0000_0000,R5(a6)

	clr.b	R1(a6)
	move.b	#%0000_1010,R5(a6)
	move.b	#%0001_0010,R3(a6)

	move.b	#1,R1(a6)
	move.b	#%0000_1111,R4(a6)

	move.b	#$9,R1(a6)
	clr.b	R4(a6)

	move.b	#3,R1(a6)
	move.b	#%1111_1100,R5(a6)
	move.b	#%0001_0001,R5(a6)

	move.b	#5,R1(a6)
	move.b	#%0000_0001,R5(a6)

	bsr		clear_rx_buffer

	clr.b	R1(a6)
	move.b	#%0010_0000,R6(a6)	; enable mcs interrupt
								;   bit5: IRQ5 receive - the only one used.
								;  All eight handlers are registered even so;
								;  each clears its own request, which is what
								;  makes an unexpected interrupt survivable.

	movem.l	(sp)+,d0/a6
	move.w	(sp)+,sr	
	rts

;
;	Set interrupt vector table
;
;  In    : none
;  Out   : none
;  Break : none
;
;  Note  : Registers the 8 MCS handlers through IOCS _B_INTVCS and
;          saves the previous vector contents into intvector_backup.
;          The IOCS macro destroys d0, but d0 has already been
;          consumed by the preceding lea, and _B_INTVCS returns the
;          previous handler address there - which is exactly what
;          gets stored.
;
set_mcsvector:
	movem.l	d0-d2/a0-a2,-(sp)

	lea		irq_offset_table(pc),a0
	lea		intvector_backup(pc),a2
	move.l	#MCS_VECNO,d1		; move.l, not moveq: moveq would
								;  sign-extend $80 to $FFFFFF80
	moveq.l	#8-1,d2
@@:
	move.w	(a0)+,d0
	lea		irq_offset_table(pc,d0.w),a1
	IOCS	_B_INTVCS
	move.l	d0,(a2)+			; backup previous vector address
	addq.l	#MCS_VECSTEP,d1
	dbra	d2,@b

	movem.l	(sp)+,d0-d2/a0-a2
	rts

;
;	Restore interrupt vector table
;
;  In    : none
;  Out   : none
;  Break : none
;
;  Note  : Two orderings in this routine are load-bearing.
;
;          (a) The intvector_backup test comes BEFORE any access to
;              REGBASE. A zero first entry means set_mcsvector never ran,
;              which in turn means mcs_check failed and the MCS may
;              not be present at all. Touching REGBASE in that case
;              raises a bus error, and by this point mcs_check's
;              handler is long gone - nothing would catch it.
;
;          (b) The YM3802 interrupt enables are cleared BEFORE the
;              vectors are put back. The reverse order would let an
;              incoming MIDI byte reach a handler that no longer
;              belongs to this module. SR is held at level 7 for the
;              whole routine, so there is no window in between.
;
;          Do not reorder for readability.
;
restore_mcsvector:
	move.w	sr,-(sp)
	movem.l	d0-d2/a1-a2/a6,-(sp)
	ori.w	#$700,sr		; disable interrupt

	lea		intvector_backup(pc),a2
	tst.l	(a2)			; did set_mcsvector ever run?
	beq		2f

	movea.l	#REGBASE,a6
	clr.b	R1(a6)
	clr.b	R6(a6)			; disable mcs interrupt
	move.b	#$FF,R3(a6)		; clear any pending IRQ requests

	move.l	#MCS_VECNO,d1
	moveq.l	#8-1,d2
1:
	movea.l	(a2)+,a1
	IOCS	_B_INTVCS
	addq.l	#MCS_VECSTEP,d1
	dbra	d2,1b

2:
	movem.l	(sp)+,d0-d2/a1-a2/a6
	move.w	(sp)+,sr
	rts

;
; Interrupt handler offset table
;
;   Order-critical: entry N is the handler for IRQ N. set_mcsvector
;   walks this table and restore_mcsvector relies on the same order.
;   The irqN_ prefix on each label exists so that a wrong order is
;   visible here rather than only at run time.
;
;   All eight are registered, but only IRQ5 is enabled (see the
;   enable mask in mcs_init), so the other seven handlers are not
;   reached. They are kept as a defensive landing point and as the
;   starting point for any future use.
;
irq_offset_table:
	.dc.w	irq0_realtime_msg-irq_offset_table
	.dc.w	irq1_midi_clock-irq_offset_table
	.dc.w	irq2_playback_counter-irq_offset_table
	.dc.w	irq3_recording_counter-irq_offset_table
	.dc.w	irq4_offline-irq_offset_table
	.dc.w	irq5_receive-irq_offset_table
	.dc.w	irq6_transmit_empty-irq_offset_table
	.dc.w	irq7_global_timer-irq_offset_table

;------------------------------------------------
;	Set global timer value
;------------------------------------------------
;  In    : a6.l = REGBASE
;		   d0.w = interval value (units of 8 usec)
;  Out   : none
;  Break : d0
;------------------------------------------------
set_global_timer:
	move.w	sr,-(sp)
	ori.w	#$700,sr

	move.b	#8,R1(a6)
	move.b	d0,R4(a6)
	lsr.w	#8,d0
	move.b	d0,R5(a6)	

	move.w	(sp)+,sr
	rts

;------------------------------------------------
;	Set MIDI clock timer value
;------------------------------------------------
;  In    : a6.l = REGBASE
;		   d0.w = interval value (units of 8 usec)
;  Out   : none
;  Break : d0
;------------------------------------------------
set_midiclock_timer:
	move.w	sr,-(sp)
	ori.w	#$700,sr

	move.b	#8,R1(a6)
	move.b	d0,R6(a6)
	lsr.w	#8,d0
	move.b	d0,R7(a6)

	move.w	(sp)+,sr
	rts

;------------------------------------------------
;	Set click counter value
;------------------------------------------------
;  In    : a6.l = REGBASE
;		   d0.b = interval value (units of MIDI clock)
;  Out   : none
;  Break : d0
;------------------------------------------------
set_click_counter:
	move.w	sr,-(sp)
	ori.w	#$700,sr

	move.b	#6,R1(a6)
	bset.l	#7,d0
	move.b	d0,R7(a6)

	move.w	(sp)+,sr
	rts

;-----------------------------------
;	Serial data receive routine
;------------------------------------------------
;  Out   : d0.b = status (0: no data / bit7 = 1: valid)
;		   d1.b = received data (meaningful only when d0 says valid)
;
;-----------------------------------
mcs_receive:
	move.w	sr,-(sp)
	movem.l	d2/a0,-(sp)

	ori.w	#$700,sr

	moveq.l	#0,d2
	move.b	pt_output(pc),d2
	cmp.b	pt_input(pc),d2
	beq		1f

	lea.l	rx_buffer(pc),a0
	move.b	(a0,d2.w),d1
	lea.l	st_buffer(pc),a0
	move.b	(a0,d2.w),d0
	lea.l	pt_output(pc),a0
	addq.b	#1,(a0)
	bra		2f
;-----
1:
	moveq.l	#0,d0		; status = 0 (no data)
	moveq.l	#0,d1		; no data
2:
	movem.l	(sp)+,d2/a0
	move.w	(sp)+,sr
	rts

;------------------------------------------------
;	Clear receive buffer
;------------------------------------------------
;  Note  : pt_input and pt_output are cleared together with a single
;          clr.w. This requires the two to stay adjacent, in that
;          order, on an even boundary. Reordering the data section
;          breaks this silently.
;------------------------------------------------
clear_rx_buffer:
	move.w	sr,-(sp)
	ori.w	#$700,sr
	move.l	a0,-(sp)

	lea.l	pt_input(pc),a0
	clr.w	(a0)

	movea.l	(sp)+,a0
	move.w	(sp)+,sr
	rts

;------------------------------------------------
;	Initialisation delay (>= 8 usec guaranteed on any CPU)
;------------------------------------------------
;  Note  : Called exactly once, from mcs_init, so waiting far longer
;          than needed costs nothing. The iteration count is fixed
;          rather than cycle-counted so that the delay holds on any
;          CPU and clock:
;            68000 / 10MHz  : about 4 msec
;            68060 / 100MHz : 40 usec or more
;          Do not turn this back into a cycle-counted loop.
;
;  In    : none
;  Out   : none
;  Break : none
;------------------------------------------------
MCSWAIT_COUNT	.equ	4000

mcs_wait:
	move.w	d0,-(sp)
	move.w	#MCSWAIT_COUNT-1,d0
@@:
	dbra	d0,@b
	move.w	(sp)+,d0
	rts

;------------------------------------------------
;	Interrupt handler - IRQ0
;------------------------------------------------
;	MIDI real time message detected
;------------------------------------------------
irq0_realtime_msg:
	move.l	a6,-(sp)
	movea.l	#REGBASE,a6		; a6.l = MCS register base address
	move.b	#%0000_0001,R3(a6)	; clear IRQ0 request (R03)
	movea.l	(sp)+,a6
	rte

;------------------------------------------------
;	Interrupt handler - IRQ1
;------------------------------------------------
;	MIDI clock
;	IRQ1 is not enabled (see mcs_init).
;------------------------------------------------
irq1_midi_clock:
	move.l	a6,-(sp)
	movea.l	#REGBASE,a6			; a6.l = MCS register base address
	move.b	#%0000_0010,R3(a6)	; clear IRQ1 request (R03)
	movea.l	(sp)+,a6
	rte

;------------------------------------------------
;	Interrupt handler - IRQ2
;------------------------------------------------
;	Playback counter interrupt
;------------------------------------------------
irq2_playback_counter:
	move.l	a6,-(sp)
	movea.l	#REGBASE,a6			; a6.l = MCS register base address
	move.b	#%0000_0100,R3(a6)	; clear IRQ2
	movea.l	(sp)+,a6
	rte

;------------------------------------------------
;	Interrupt handler - IRQ3
;------------------------------------------------
;	Recording counter interrupt
;------------------------------------------------
irq3_recording_counter:
	move.l	a6,-(sp)
	movea.l	#REGBASE,a6			; a6.l = MCS register base address
	move.b	#%0000_1000,R3(a6)	; clear IRQ3
	movea.l	(sp)+,a6
	rte

;------------------------------------------------
;	Interrupt handler - IRQ4
;------------------------------------------------
;	Offline interrupt
;------------------------------------------------
irq4_offline:
	move.l	a6,-(sp)
	movea.l	#REGBASE,a6			; a6.l = MCS register base address
	move.b	#%0001_0000,R3(a6)	; clear IRQ4
	movea.l	(sp)+,a6
	rte

;------------------------------------------------
;	Interrupt handler - IRQ5
;------------------------------------------------
;	Receive interrupt
;------------------------------------------------
irq5_receive:
	movem.l	d0-d2/a0-a1/a6,-(sp)
	ori.w	#$700,sr		; disable all interrupts
							;  (TODO: is masking to level 7 the
							;   right thing to do here?)

	movea.l	#REGBASE,a6		; a6.l = MCS register base address

	moveq.l	#0,d2
	move.b	pt_input(pc),d2		; load input pointer
	lea.l	rx_buffer(pc),a0	; load Rx buffer address
	lea.l	st_buffer(pc),a1	; load status buffer address

	move.b	#$03,R1(a6)		; R34(RSR) and R36(RDR)
1:
	move.b	R4(a6),d1		; read FIFO-Rx status
	bpl		3f

	move.b	R6(a6),d0		; read FIFO-Rx data

	addq.b	#1,d2			; advance by one byte for FIFO

	cmp.b	pt_output(pc),d2	; check end of buffer
	beq		2f

	subq.b	#1,d2
	move.b	d0,(a0,d2.w)	; Rx data
	move.b	d1,(a1,d2.w)	; status data
	addq.b	#1,d2
	bra		1b

2:
	subq.b	#1,d2		; a proper buffer-full handler belongs
	bra		1b			;  here, but the data is simply
						;  discarded instead

3:
	lea.l	pt_input(pc),a0		; save input pointer
	move.b	d2,(a0)

	move.b	#%0010_0000,R3(a6)	; clear IRQ5

	movem.l	(sp)+,d0-d2/a0-a1/a6

	rte

;------------------------------------------------
;	Interrupt handler - IRQ6
;------------------------------------------------
;	Transmit buffer empty
;
;	IRQ6 is not enabled (see mcs_init): this module has no transmit
;	path, and "transmit buffer empty" holds permanently when nothing
;	is ever sent.
;------------------------------------------------
irq6_transmit_empty:
	move.l	a6,-(sp)
	movea.l	#REGBASE,a6			; a6.l = MCS register base address
	move.b	#%0100_0000,R3(a6)	; TODO: should transmit buffering be
								;  handled here?
	movea.l	(sp)+,a6
	rte

;------------------------------------------------
;	Interrupt handler - IRQ7
;------------------------------------------------
;	Global timer zero count interrupt
;------------------------------------------------
irq7_global_timer:
	move.l	a6,-(sp)
	movea.l	#REGBASE,a6		; a6.l = MCS register base address
	move.b	#%1000_0000,R3(a6)
	movea.l	(sp)+,a6
	rte

;----------------------------------
	.even

;	Previous contents of the 8 MCS interrupt vectors, filled in by
;	set_mcsvector. Explicitly initialised to 0 so that 0 means "no valid
;	backup": when mcs_check fails, mcs_init - and therefore set_mcsvector -
;	never runs, and the array stays zero.
;	(A genuine previous vector of 0 cannot be told apart from "never
;	backed up", but skipping it and restoring it are equally harmless.)
;
;	restore_mcsvector puts these back. It masks the YM3802 interrupt
;	enables first and restores the vectors afterwards; the reverse
;	order would let an incoming MIDI byte reach a stale handler.
;	A zero first entry is what restore_mcsvector uses as its
;	"nothing to undo" condition.
intvector_backup:
	.dc.l	0,0,0,0,0,0,0,0

buserr_saved_sp:
	.dc.l	0		; SSP

buserr_saved_vector:
	.dc.l	0		; bus error vector

;--- The following two are cleared together by clear_rx_buffer with a single
;--- clr.w. They must stay adjacent and on an even boundary.
;--- Do not reorder.
pt_input:
	.ds.b	1		; FIFO-Rx buffer input pointer

pt_output:
	.ds.b	1		; FIFO-Rx buffer output pointer

rx_buffer:
	.ds.b	256		; Rx data buffer

st_buffer:
	.ds.b	256		; Rx status buffer

