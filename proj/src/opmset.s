;
; opmset.s
;
;----------------------------------

    .include iocscall.mac
	.include doscall.mac
	.include scalekey.mac

;----------------------------------

	.xref	scalekey_channel_use

	.xdef	opmreg_access_permission
	.xdef	opmset_detune
	.xdef	opmset_keyon
	.xdef	opmset_keyoff

	.xdef	note_offset
	.xdef	note_oct_updown
	.xdef	note_oct_updown_shift_value
	.xdef	note_oct_updown_ctrl_value

	.xdef	slotmask
	.xdef	detune

;----------------------------------
;	opmset_detune
;----------------------------------
opmset_detune:
	lea		detune(pc),a1
	lea		scalekey_channel_use+8*4(pc),a2
	lea		octval(pc),a3

	moveq.l	#8-1,d7
1:
	move.l	-(a2),d3	; check channel_use
	beq		2f			; -> next channel
	btst.l	#12,d3		; delay?
	bne		2f			; -> next channel

	move.w	d7,d2
	add.w	d2,d2
	move.w	(a1,d2.w),d2	; d2: detune

	moveq.l	#0,d5
	move.b	d3,d5			; d5: note
	ext.w	d5

	moveq.l	#0,d3
	move.w	d2,d3

	asr.w	#8,d3
	add.w	d3,d5
	bpl		@f

	moveq.l	#0,d5
	moveq.l	#0,d2
@@:
	cmpi.w	#8*12,d5
	bcs		@f
	moveq.l	#(8*12-1),d5
@@:
	move.w	d7,d1
	addi.w	#$30,d1			; KF reg.
	IOCS	_OPMSET

	move.w	d7,d1
	addi.w	#$28,d1			; KC reg.
	move.b	(a3,d5.w),d2	; d2: KeyCode
	IOCS	_OPMSET
2:
	dbra	d7,1b
	rts

;----------------------------------
;	opmset_keyon
;	   d2.l: channel no.
;      d5.l: note
;   => d0.l: effective note (offset/octave applied, detune not applied)
;
;   d0 is produced by pushing d5 a second time and popping one register
;   more than was pushed - the extra long lands in d0. See the movem pair.
;----------------------------------
opmset_keyon:
	movem.l	d1-d5/a0,-(sp)

	ext.w	d5
	lea		octval(pc),a0

	move.l	d2,d1	; d2 => d1/d3/d4: channel no.
	move.l	d2,d3
	move.l	d2,d4

	add.l	d3,d3
	move.w	detune(pc,d3.w),d3		; d3: detune value
	add.w	note_offset(pc),d5		; d5: note + offset
	add.w	note_oct_updown(pc),d5	;          + octupdown
	move.l	d5,-(sp)				; d5.l(note without detune) => -(sp)

	moveq.l	#0,d2
	move.b	d3,d2	; d2: detune

	asr.w	#8,d3
	add.w	d3,d5   ; + detune
	bpl		@f

	moveq.l	#0,d5	; note   <= 0
	moveq.l	#0,d2	; detune <= 0 (KF)
@@:
	cmpi.w	#8*12,d5
	bcs		@f
	moveq.l	#(8*12-1),d5
@@:
	move.l	d4,d1
	addi.w	#$30,d1			  ; KF reg.
	IOCS	_OPMSET

	move.l	d4,d1
	addi.w	#$28,d1			  ; KC reg.
	moveq.l	#0,d2
	move.b	(a0,d5.w),d2	  ; d2: KeyCode
	IOCS	_OPMSET

	moveq.l	#$8,d1			  ; Slotmask & KeyON reg.
	move.l	d4,d2			  ; d4: channel no.
	or.b	slotmask(pc,d4.w),d2  ; d2: slotmask
	IOCS	_OPMSET

	movem.l	(sp)+,d0-d5/a0 	  ; restore original note(d5.l) into d0.l, and restore d1-d5/a0
	rts

;----------------------------------
detune:
	.dc.w	0,0,0,0,0,0,0,0

;----------------------------------
;	opmset_keyoff
;	   d2.l: channel no.
;----------------------------------
opmset_keyoff:
	movem.l	d0-d2,-(sp)

	andi.w	#%111,d2
	moveq.l	#$8,d1
	IOCS	_OPMSET

	movem.l	(sp)+,d0-d2
	rts

;----------------------------------
opmreg_access_permission:
	.dc.l	0

slotmask:
	.dc.b	%0111_1000
	.dc.b	%0111_1000
	.dc.b	%0111_1000
	.dc.b	%0111_1000
	.dc.b	%0111_1000
	.dc.b	%0111_1000
	.dc.b	%0111_1000
	.dc.b	%0111_1000

note_offset:
	.dc.w	45

note_oct_updown_shift_value:
	.dc.w	SCALEKEY_OCT_UP

note_oct_updown_ctrl_value:
	.dc.w	SCALEKEY_OCT_DOWN

note_oct_updown:
	.dc.w	0

octval:
	.dc.b	$00,$01,$02,$04,$05,$06,$08,$09,$0A,$0C,$0D,$0E
	.dc.b	$10,$11,$12,$14,$15,$16,$18,$19,$1A,$1C,$1D,$1E
	.dc.b	$20,$21,$22,$24,$25,$26,$28,$29,$2A,$2C,$2D,$2E
	.dc.b	$30,$31,$32,$34,$35,$36,$38,$39,$3A,$3C,$3D,$3E
	.dc.b	$40,$41,$42,$44,$45,$46,$48,$49,$4A,$4C,$4D,$4E
	.dc.b	$50,$51,$52,$54,$55,$56,$58,$59,$5A,$5C,$5D,$5E
	.dc.b	$60,$61,$62,$64,$65,$66,$68,$69,$6A,$6C,$6D,$6E
	.dc.b	$70,$71,$72,$74,$75,$76,$78,$79,$7A,$7C,$7D,$7E
