;
; disp.s
;
;----------------------------------

    .include iocscall.mac
	.include doscall.mac
	.include scalekey.mac
	.include disp.mac

;----------------------------------

	.xdef	disp_cls_all
	.xdef	disp_midi_in_marker
	.xdef	disp_opm_channel
	.xdef	disp_opm_note
	.xdef	disp_onoff
	.xdef	xpos_channel
	.xdef	xpos_midi_marker

;----------------------------------

	.xref	scalekey_channel_use
	.xref	channel_select
	.xref	midiin_disp_count

;----------------------------------
; disp all clear 
;----------------------------------
disp_cls_all:
	move.w	disp_onoff(pc),d1
	bne		@f
	rts

;--- clear midi marker
@@:
	lea		escseq_save(pc),a1			; save position status
	IOCS	_B_PRINT

	lea		xpos_midi_marker(pc),a3
	move.w	(a3)+,d1
	move.w	(a3),d2
	IOCS	_B_LOCATE

	lea		escseq_off(pc),a1
	IOCS	_B_PRINT
	moveq.l	#' ',d1
	IOCS	_B_PUTC

;--- clear opm channel
	lea		xpos_channel(pc),a3
	lea		chara_opm_channel+8*8(pc),a4
	move.w	(a3)+,d1
	move.w	(a3)+,d2
	IOCS	_B_LOCATE
	movea.l	a4,a1
	IOCS	_B_PRINT

;--- clear opm note
	move.w	(a3)+,d1
	move.w	(a3),d2
	IOCS	_B_LOCATE
	movea.l	a4,a1
	IOCS	_B_PRINT

	lea		escseq_load(pc),a1			; load position status
	IOCS	_B_PRINT

	rts

;----------------------------------
; disp midi-in marker
;----------------------------------
disp_midi_in_marker:
	move.w	disp_onoff(pc),d1
	bne		@f
1:
	rts

@@:
	lea		midiin_disp_count(pc),a3
	move.w	(a3),d3
	beq		1b

	btst.l	#15,d3		; check disp flag
	beq		2f

;--- disp marker
	bclr.l	#15,d3		; clear disp flag

	lea		xpos_midi_marker(pc),a4
	move.w	(a4)+,d1
	move.w	(a4),d2
	IOCS	_B_LOCATE

	moveq.l	#'*',d1
	IOCS	_B_PUTC		; disp '*'

	move.b	2(a3),d1
	bmi		2f			; not channel number -> skip disp

	addi.b	#'1',d1		; 1-9/A-G 'G'=16
	cmpi.b	#'9',d1
	bls		@f
	addi.b	#'A'-'9'-1,d1
@@:
	IOCS	_B_PUTC		; disp channel number

;--- count down
2:
	subq.w	#1,d3
	bne		3f

;--- clear marker
	lea		xpos_midi_marker(pc),a4
	move.w	(a4)+,d1
	move.w	(a4),d2
	IOCS	_B_LOCATE

	moveq.l	#' ',d1
	IOCS	_B_PUTC
	IOCS	_B_PUTC
3:
	move.w	d3,(a3)
	rts

;----------------------------------
disp_opm_channel:
	move.w	disp_onoff(pc),d1
	bne		@f
	rts

@@:
	lea		escseq_off(pc),a3
	lea		scalekey_channel_use(pc),a4
	lea		chara_opm_channel(pc),a5
	move.w	channel_select(pc),d6
	moveq.l	#0,d4
	move.w	xpos_channel(pc),d4
	moveq.l	#0,d5
	move.w	ypos_channel(pc),d5

	moveq.l	#8-1,d3
1:
	move.l	d4,d1
	move.l	d5,d2
	IOCS	_B_LOCATE

	movea.l	a3,a1		; set normal color (white)
	lsr.w	#1,d6
	bcc		@f			; channel un use

	addq.w	#6,a1		; set delay color (rev yellow)
	btst.b	#4,2(a4)	; keyon delay?
	bne		@f

	addq.w	#6,a1		; set keyon color (rev cyan)
	tst.l	(a4)		; channel use?
	bne		@f

	addq.w	#6,a1		; set keyoff color (rev white)
@@:
	IOCS	_B_PRINT
	addq.w	#4,a4

	movea.l	a5,a1
	IOCS	_B_PRINT
	addq.w	#4,d4
	addq.w	#8,a5
	dbra	d3,1b
	rts

;----------------------------------
disp_opm_note:
	move.w	disp_onoff(pc),d1
	bne		@f
	rts

@@:
	lea		escseq_off(pc),a1
	IOCS	_B_PRINT

	lea		str_note(pc),a5
	lea		chara_scalekey_note(pc),a2
	lea		chara_scalekey_oct(pc),a3
	lea		scalekey_channel_use(pc),a4
	moveq.l	#0,d4
	move.w	xpos_note(pc),d4
	moveq.l	#0,d5
	move.w	ypos_note(pc),d5

	moveq.l	#8-1,d3
1:
	move.l	d4,d1
	move.l	d5,d2
	IOCS	_B_LOCATE

	move.l	(a4),d0
	beq		2f			; channel use?
	btst.l	#12,d0		; check keyon wait flag (bit12)
	bne		2f			; delay?

	andi.l	#$ff,d0
	ext.w	d0
	addi.w	#CORRECT_OPM_NOTE,d0	; OPM:4MHz
	bpl		@f
	moveq.l	#0,d0
@@:
	cmpi.w	#8*12,d0
	bcs		@f
	moveq.l	#(8*12-1),d0
@@:
	divu	#12,d0		; div12 => d0
	move.l	d0,d1
	swap	d1			; mod12 => d1

	add.w	d0,d0
	move.w	(a3,d0.w),(a5)
	add.w	d1,d1
	move.w	(a2,d1.w),2(a5)

	movea.l	a5,a1
	IOCS	_B_PRINT
	addq.w	#4,d4
	addq.w	#4,a4
	dbra	d3,1b
	rts
;---
2:
	lea		str_note0(pc),a1
	IOCS	_B_PRINT
	addq.w	#4,d4
	addq.w	#4,a4
	dbra	d3,1b
	rts

;----------------------------------
disp_onoff:
	.dc.w	1

; trap7.s の routine2 (set disp position) が xpos_channel を起点に
; +0/+2/+4/+6 の4ワードへまとめて書き込む。並べ替え禁止。
xpos_channel:
	.dc.w	0
ypos_channel:
	.dc.w	0
xpos_note:
	.dc.w	0
ypos_note:
	.dc.w	1
; routine10 が xpos_midi_marker を起点に +0/+2 へ書き込む。並べ替え禁止。
xpos_midi_marker:
	.dc.w	34
ypos_midi_marker:
	.dc.w	0

	.even
str_note:
	.dc.b	'    ',0,0
str_note0:
	.dc.b	'    ',0,0

; 8 bytes per channel (disp_opm_channel advances a5 by +8).
; The blank block that follows at +8*8 is the clear string used by
; disp_cls_all. Keep both the entry size and that offset.
chara_opm_channel:
	.dc.b	' Ａ ',0,0,0,0
	.dc.b	' Ｂ ',0,0,0,0
	.dc.b	' Ｃ ',0,0,0,0
	.dc.b	' Ｄ ',0,0,0,0
	.dc.b	' Ｅ ',0,0,0,0
	.dc.b	' Ｆ ',0,0,0,0
	.dc.b	' Ｇ ',0,0,0,0
	.dc.b	' Ｈ ',0,0,0,0
	.dc.b	'    ','    ','    ','    '
	.dc.b	'    ','    ','    ','    ',0,0

; disp_opm_channel selects a colour by advancing +6 from escseq_off,
; so every entry below is padded to exactly 6 bytes. Neither the order
; nor the length may change.
;   +0  off    (normal / white)
;   +6  delay  (rev yellow)
;   +12 keyon  (rev cyan)
;   +18 keyoff (rev white)
escseq_off:
	.dc.b	'[m',0,0,0
escseq_delay:
	.dc.b	'[42m',0
escseq_keyon:
	.dc.b	'[41m',0
escseq_keyoff:
	.dc.b	'[43m',0
; escseq_save / escseq_load are 4 bytes and sit outside that chain.
escseq_save:
	.dc.b	'[s',0
escseq_load:
	.dc.b	'[u',0

	.even
chara_scalekey_oct:
	.dc.b	'o0'
	.dc.b	'o1'
	.dc.b	'o2'
	.dc.b	'o3'
	.dc.b	'o4'
	.dc.b	'o5'
	.dc.b	'o6'
	.dc.b	'o7'
	.dc.b	'o8'
	.dc.b	'o9'
	.dc.b	'oA'

	.even
chara_scalekey_note:
	.dc.b	'c '
	.dc.b	'c+'
	.dc.b	'd '
	.dc.b	'd+'
	.dc.b	'e '
	.dc.b	'f '
	.dc.b	'f+'
	.dc.b	'g '
	.dc.b	'g+'
	.dc.b	'a '
	.dc.b	'a+'
	.dc.b	'b '
