;
; keyon/keyoff
;
;----------------------------------

    .include	iocscall.mac
	.include	doscall.mac

;----------------------------------

	.xdef	note_keyon
	.xdef	note_keyoff
	.xdef	midi_note_keyoff_all
	.xdef	delay_keyonoff

	.xdef	scalekey_channel_use
	.xdef	scalekey_channel_order
	.xdef	scalekey_channel_stat
	.xdef	channel_select
	.xdef	channel_policy
	.xdef	channel_policy_over
	.xdef	channel_use_scan_offset

	.xdef	unison_count
	.xdef	poly_count
	.xdef	delay_count
	.xdef	keyin_enable

	.xref	opmset_keyon
	.xref	opmset_keyoff

;----------------------------------
; keyon
;   d5.l: key note
;   d6.l: use(key) data
;  Break: a6
;----------------------------------
note_keyon:
	andi.w	#$00ff,d6

	movem.l	d0-d7/a2-a3/a5,-(sp)

;----- check unison & poly count
	move.w	unison_count(pc),d0
	beq		exit_keyon				; unison=0 -> exit
	move.w	poly_count(pc),d1
	beq		exit_keyon				; poly=0 -> exit
	move.w	channel_select(pc),d2
	beq		exit_keyon				; channel_select = all zero -> exit

	mulu.w	d0,d1		; poly*unison => d1 (effective poly count)
	cmpi.w	#8,d1		; check poly count
	bhi		exit_keyon

;----- check channsel_use
note_keyon_start:
	lea		scalekey_channel_stat(pc),a2
	lea		unison_flag(pc),a6
	move.w	unison_count(pc),(a6)	; clear unison flag & set unison count
	lea		delay_count(pc),a5
	move.w	2(a5),(a5)				; reset delay count (for keyon)

unison_loop:
	move.w	d1,d2

	lea		scalekey_channel_use+8*4(pc),a5
	moveq.l	#8-1,d0
1:
	tst.l	-(a5)
	beq		@f
	subq.w	#1,d2
	beq		note_keyon_over		; => keyon over
@@:
	dbra	d0,1b

;----- keyon_sub
note_keyon_sub:
	move.l	d1,-(sp)

	lea		scalekey_channel_use(pc),a5
	moveq.l	#0,d1
	move.w	channel_use_scan_offset(pc),d1
	moveq.l	#8-1,d0
1:
	bclr.l	#14,d6		; clear keyoff flag
	move.w	d1,d2
	lsr.w	#2,d2		; d2: channel number

	btst.b	d2,channel_select+1(pc)
	beq		3f

	tst.b	2(a5,d1.w)	; delay channel?
	beq		2f			; normal channel -> check channel_use

;--- check key matrix
	bset.l	#14,d6		; set keyoff flag (keyoff before keyon)
	move.l	d6,d7
	andi.l	#$ffff_0000,d7
	swap	d7
	cmp.w	(a5,d1.w),d7
	bne		3f			; not same key -> next channel

;--- check unison count
	move.w	d6,d7
	lsr.w	#8,d7
	andi.b	#$0f,d7
	move.b	2(a5,d1.w),d3
	andi.b	#$0f,d3
	cmp.b	d3,d7		; cmp.b unison count
	beq		1f			; available channel
2:
	tst.l	(a5,d1.w)	; check channel_use
	beq		1f			; zero -> available channel exist
3:
	addq.w	#4,d1		; next channel_use
	and.w	#%11100,d1
	dbra	d0,1b

;----- ??????
;	DEBUG_PHASE	'?'
	move.l	(sp)+,d1		; poly count
	bra		exit_keyon		; exit_keyon

;----- available channel exist
1:
	lea		(a5,d1.w),a3
	move.l	d6,(a3)			; d6(matrix data) => (a5,d1.w)channel_use

	move.w	d1,d2
	lsr.w	#2,d2			; d2: channel number
	bsr		delete_channel_order

;--- set channel_stat
	move.w	d6,d2
	andi.w	#$1000,d2
	beq		@f

	lea		delay_count(pc),a5
	moveq.l	#0,d2
	move.w	(a5),d2			; delay_count(for keyon) -> d2.hw
	swap	d2
	move.w	(a5),d2			; delay_count(for keyoff) -> d2.lw
	move.l	d2,(a2,d1.w)	; d2 -> channel_stat(keyon)
	add.w	2(a5),d2		; d2 += delay_count(base)
	move.w	d2,(a5)			; d2 -> delay_count(for keyon)
@@:
	moveq.l	#0,d2
	move.w	d1,d2

;--- count channel_use
	lea		scalekey_channel_use+8*4(pc),a5
	moveq.l	#0,d4
	moveq.l	#8-1,d0
1:
	tst.l	-(a5)
	beq		@f
	addq.b	#1,d4		; d4: count channel_use
@@:
	dbra	d0,1b

;--- set channel_order
	lea		scalekey_channel_order(pc),a5
	move.w	d1,d3
	lsr.w	#2,d3
	move.b	d4,(a5,d3.w)	; use count => channel_order

;--- set next start scan channel
	addq.w	#4,d1
	and.w	#%11100,d1

	lea		channel_use_scan_offset(pc),a5
	move.w	channel_policy(pc),d3	; check channel policy
	bne		@f

	move.w	2(a5),d1	; 2(a5): start of channel scan x4
@@:
	move.w	d1,(a5)

	btst.l	#12,d6		; keyon delay?
	bne		1f			; skip opm keyon

;--- opm keyon
	lsr.l	#2,d2
	bsr		opmset_keyon	; d2.l:channel no.  d5.l:note
	move.b	d0,3(a3)		; d0:note => a3+3: matrix

;--- unison check
1:
	lea		delay_count(pc),a5
	tst.b	(a6)		; first keyon? (check unison flag)
	bne		@f

	move.w	2(a5),(a5)	; first delay_count (for keyon)
@@:
	tst.w	2(a5)		; delay=0?
	beq		@f

	move.b	1(a6),d7	; d7 <- unison count
	ori.b	#$10,d7		; set keyon delay flag
	lsl.w	#8,d7		; d7 <<8
	andi.w	#$00ff,d6
	or.w	d7,d6		; d6:bit12: keyon delay flag, bit11-8:unison count
@@:
	move.l	(sp)+,d1	; poly count -> d1

	move.b	#1,(a6)		; 1 =>  unison sub_flag
	subq.b	#1,1(a6)	; dec. unison count
	bne		unison_loop

exit_keyon:
	movem.l	(sp)+,d0-d7/a2-a3/a5
	rts

;----- keyon policy=over
note_keyon_over:
	move.w	channel_policy_over(pc),d0	; check policy=over?
	beq		exit_keyon					; policy=hold -> exit

	lea		scalekey_channel_order+8(pc),a5
	moveq.l	#8-1,d0
@@:
	cmpi.b	#1,-(a5)
	dbeq	d0,@b
	bne		exit_keyon		; ??? illigal -> exit

;--- clear channel_order
	move.w	d0,d2			; d2: channel no.
	bsr		delete_channel_order

;--- clear channel_use & opm keyoff
	lea		scalekey_channel_use(pc),a5
	add.w	d0,d0
	add.w	d0,d0
	clr.l	(a5,d0.w)		; clear (a5):channel_use

	bsr		opmset_keyoff
	bra		note_keyon_sub

;----------------------------------
; deley keyon/off
;----------------------------------
delay_keyonoff:
	movem.l	d0-d3/d5/a5-a6,-(sp)

	lea		scalekey_channel_stat(pc),a6
	lea		scalekey_channel_use+8*4(pc),a5

	moveq.l	#8-1,d0

delay_keyonoff_loop:
	move.l	d0,-(sp)

	move.l	-(a5),d1
	move.w	d1,d3
	btst.l	#12,d1			; keyon delay?
	beq		1f				; -> keyoff count down

;--- keyon count down
	move.w	d0,d1
	add.w	d1,d1
	add.w	d1,d1
	subq.w	#1,(a6,d1.w)	; dec. keyon wait count
	bne		1f				; -> keyoff count down

	move.w	d0,d2			; channel no. -> d2
	btst.b	#6,2(a5)		; check keyoff flag (keyoff before keyon)
	beq		@f
	bsr		opmset_keyoff
@@:
	move.w	d0,d2			; channel no. -> d2
	moveq.l	#0,d5
	move.b	3(a5),d5		; keyon note -> d5
	bsr		opmset_keyon
	move.b	d0,3(a5)		; d0: effective note

	andi.b	#$af,2(a5)		; clear keyon wait flag & keyoff flag
	ori.b	#$80,2(a5)		; set delay noteon flag

;--- check flag
1:
	move.l	(sp)+,d0

	btst.l	#13,d3		; keyoff delay?
	beq		9f			; next channel

;--- keyoff count down
	move.w	d0,d1
	add.w	d1,d1
	add.w	d1,d1
	subq.w	#1,2(a6,d1.w)
	bne		9f			; -> next channel

	clr.l	(a5)		; clear channel_use
	move.w	d0,d2		; channel no. -> d2
	bsr		opmset_keyoff
	bsr		delete_channel_order
9:
	dbra	d0,delay_keyonoff_loop

	movem.l	(sp)+,d0-d3/d5/a5-a6
	rts

;----------------------------------
; keyoff
;   d6.l: use(key) data
;----------------------------------
note_keyoff:
	movem.l	d0-d2/a5-a6,-(sp)

	lea		scalekey_channel_stat(pc),a6
	lea		scalekey_channel_use+8*4(pc),a5
	moveq.l	#8-1,d0
	andi.l	#$ffff_0000,d6

note_keyoff_loop:
;--- search channel
@@:
	move.l	-(a5),d1
	andi.l	#$ffff_0000,d1
	cmp.l	d1,d6
	dbeq	d0,@b
	bne		note_keyoff_exit	; no match -> exit

	movem.l	d0/a5,-(sp)

;--- check delay flag
	tst.b	2(a5)
	beq		@f

	ori.b	#$a0,2(a5)		; set keyoff count flag
	bra		9f
	
;--- key match -> clear channel_use & opm keyoff
@@:
	clr.l	(a5)		; clear (a5):channel_use

	move.w	d0,d2		; d2: channel number
	bsr		opmset_keyoff
	bsr		delete_channel_order
9:
	movem.l	(sp)+,d0/a5
	dbra	d0,note_keyoff_loop		; unison loop

note_keyoff_exit:
	movem.l	(sp)+,d0-d2/a5-a6
	rts

;----------------------------------
; delete channel_order
;   d2.w: channel number
;----------------------------------
delete_channel_order:
	movem.l	d1-d2/a5,-(sp)

;--- clear channel_order
	lea		scalekey_channel_order(pc),a5
	move.b	(a5,d2.w),d1
	beq		3f
	clr.b	(a5,d2.w)

;--- dec channel_order
	addq.w	#8,a5
	moveq.l	#8-1,d2
1:
	cmp.b	-(a5),d1
	bpl		2f
	subq.b	#1,(a5)
2:
	dbra	d2,1b
3:
	movem.l	(sp)+,d1-d2/a5
	rts

;----------------------------------
; keyoff ALL for MIDI
;----------------------------------
midi_note_keyoff_all:
	movem.l	d0-d2/a5,-(sp)

	lea		scalekey_channel_use+8*4(pc),a5
	moveq.l	#8-1,d0
1:
	move.l	-(a5),d1
	rol.l	#8,d1
	cmp.b	#$90,d1		; MIDI originated? (midi.s always stores $90)
	bne		3f
	clr.l	(a5)		; clear channel_use

	move.b	d0,d2
	bsr		opmset_keyoff
	bsr		delete_channel_order
3:
	dbra	d0,1b

	movem.l	(sp)+,d0-d2/a5
	rts

;========================================
; channel_use:
;  [31:16] keyin matrix/midi note on data
;  [15]    delay noteon flag
;  [14]    keyoff flag
;  [13]    keyoff wait flag
;  [12]    keyon wait flag
;  [11:8]  unison number
;  [7:0]   note
;
; channel_stat:
;  [31:16] keyon wait count
;  [15:0]  keyoff wait count

channel_policy:
	.dc.w	0		; 0:sequencial 1:round_robin

channel_policy_over:
	.dc.w	1		; 0:hold 1:over

channel_select:
	.dc.w	%1111_1111		; 1:selected 0:off  bit7(ch.H)-bit0(ch.A)

channel_use_scan_offset:
	.dc.w	0		; scan channel (0-7)x4
	.dc.w	0		; start scan channel (base)

scalekey_channel_use:
	.ds.l	8

scalekey_channel_stat:
	.ds.l	8

scalekey_channel_order:
	.ds.b	8

poly_count:
	.dc.w	8

unison_count:
	.dc.w	1

unison_flag:
	.dc.b	0		; flag
	.dc.b	0		; count

delay_count:
	.dc.w	0		; delay_count (for keyon)
	.dc.w	0		; delay_count (base)

keyin_enable:
	.dc.w	%11		; bit0: keyboard input enable
					; bit1: midi input enable
