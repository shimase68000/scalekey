;
; midi.s
;
;----------------------------------

	.include	iocscall.mac
	.include	doscall.mac
	.include	scalekey.mac
	.include	disp.mac

;----------------------------------

	.xref	mcs_init
	.xref	mcs_receive
	.xref	mcs_check

;----------------------------------

	.xref	note_keyon
	.xref	note_keyoff
	.xref	keyin_enable

;----------------------------------

	.xdef	init_midi
	.xdef	midi_recv_loop

	.xdef	midi_channel_filter
	.xdef   midi_board_not_arrive
	.xdef	midiin_disp_count

;----------------------------------

; MIDI note -> OPM note. MIDI note 72 (C5) maps to 0, so lower notes
; go negative here. opmset sign-extends (ext.w d5) and adds note_offset
; (default 45), which brings them back into range.
CORRECT_MIDI_NOTE	.equ	-(12*6)

;----------------------------------
init_midi:
	lea		midi_buffer(pc),a0	; clear midi_buffer
	clr.l	(a0)

	bsr		mcs_check			; check MIDI board
	tst.l	d0
	bmi		@f

	bsr		mcs_init			; MIDI initialize
	moveq.l	#0,d0
@@:
	lea		midi_board_not_arrive(pc),a0
	move.w	d0,(a0)
	rts

;----------------------------------
midi_board_not_arrive:
	.ds.w	1

;----------------------------------
; midi receive
;----------------------------------
midi_recv_loop:
	bsr		mcs_receive
	tst.b	d0
	bne		1f
	rts							; recv buffer empty

1:
	lea		midiin_disp_count(pc),a1
	lea		midi_buffer(pc),a0
	tst.b	(a0)
	bne		midi_already_started

	move.b	d1,d2
	bpl		@f			; not status byte -> skip setting disp count

	move.w	#MIDIIN_DISP_COUNT.or.$8000,(a1)
	move.b	#$ff,2(a1)
	andi.b	#$f0,d2
	cmpi.b	#$f0,d2			; FxH = MIDI function code
	beq		@f				; -> skip setting midi channel for disp

	move.b	d1,d2
	andi.b	#$0f,d2
	move.b	d2,2(a1)		; 2(a1): disp midi channel
@@:
	move.b	d1,d2
	move.w	midi_channel_filter(pc),d0
	bmi		midi_recv_loop	; channel_filter => Off
	beq		@f				;                => Any

	andi.b	#$0f,d1
	subq.b	#1,d0			;                => Ch.1-16
	cmp.b	d0,d1
	bne		midi_recv_loop
@@:
	andi.b	#$f0,d2
	cmpi.b	#$80,d2			; $80: MIDI note off
	beq		start_midi_noteonoff
	cmpi.b	#$90,d2			; $90: MIDI note on
	bne		midi_recv_loop

start_midi_noteonoff:
	move.b	d2,2(a0)		; 2(a0): $90/$80 ($9n/$8n)
							; 3(a0): note
	move.b	#2,(a0)			; 0(a0): data count=2
	bra		midi_recv_loop
	
midi_already_started:
	sub.b	#1,(a0)
	beq		midi_data_count_0

midi_data_count_1:
	move.b	d1,3(a0)		; 3(a0): note
	bra		midi_recv_loop

midi_data_count_0:
	; d6.l is the "use(key) data" that note_keyon / note_keyoff take:
	;   bit31-16 : key identity ($90 | corrected note)
	;   bit7-0   : corrected note
	; note_keyoff matches on the upper word (keyonoff.s: andi.l
	; #$ffff_0000,d6 / cmp.l d1,d6), so note-on and note-off must build
	; the same identity - hence the status byte is forced to $90 below,
	; and hence the swap. d6 is not merely a note number.
	cmpi.b	#$90,2(a0)		; $90: note on, d0(velocity)=0: note off
	beq		@f

	moveq.l	#0,d1			; d1 <= 0 (note off flag)
	move.b	#$90,2(a0)		; $90: note on (overwrite $90 -> 2(a0))
@@:
	moveq.l	#0,d5
	moveq.l	#0,d6
	move.w	2(a0),d6
	addi.b	#CORRECT_MIDI_NOTE,d6	; correct MIDI note -> OPM note
	move.b	d6,d5
	swap	d6
	move.b	d5,d6		; key note -> d6.b		
	clr.l	(a0)		; clear midi_buffer

	tst.b	d1			; noteon or noteoff ?
	bne		midi_noteon

midi_noteoff:
	btst.b	#INPUT_ENABLE_MIDI,keyin_enable+1(pc)	; check keyin_enable(midi input)
	beq		midi_recv_loop

	bsr		note_keyoff
	bra		midi_recv_loop

midi_noteon:
	btst.b	#INPUT_ENABLE_MIDI,keyin_enable+1(pc)	; check keyin_enable(midi input)
	beq		midi_recv_loop

	bsr		note_keyon
	bra		midi_recv_loop

;----------------------------------
midi_channel_filter:
	.dc.w	0			;   -1: Off
						;    0: Any
						; 1-16: Ch.1-16
midi_buffer:
	.ds.l	1

; disp.s reads the channel as midiin_disp_count+2 (midiin_disp_channel
; is not exported), so the two must stay adjacent in this order.
;   count bit15 : disp request flag
;   count bit14-0: remaining display frames
;   channel      : 0-15, or $ff when there is no channel to show
midiin_disp_count:
	.dc.w	0

midiin_disp_channel:
	.dc.b	0
	.dc.b	0		; padding (.even)
