;
; scalekey.s
;
;----------------------------------

    .include iocscall.mac
	.include doscall.mac

	.include title.mac
	.include scalekey.mac
	.include key_matrix.mac

;----------------------------------

; keeppr_bottom.s -----
	.xref	_keeppr_bottom

; check_proc.s -----
	.xref	check_proc

; comline.s -----
	.xref	parse_comline

; disp.s -----
	.xref	disp_cls_all
	.xref	disp_opm_channel
	.xref	disp_opm_note
	.xref	disp_midi_in_marker

; keyonoff -----
	.xref	note_keyon
	.xref	note_keyoff
	.xref	midi_note_keyoff_all
	.xref	delay_keyonoff

	.xref	scalekey_channel_use
	.xref	scalekey_channel_order
	.xref	scalekey_channel_stat
	.xref	keyin_enable

; opmset.s -----
	.xref	note_oct_updown
	.xref	note_oct_updown_shift_value
	.xref	note_oct_updown_ctrl_value

; trap7.s -----
	.xref	set_trap7

; midi.s -----
	.xref	init_midi
	.xref	midi_recv_loop
	.xref	midi_board_not_arrive

; comline.s -----
	.xref	print_usage_flag
	.xref	print_title_enable
	.xref	kill_proc_flag

;----------------------------------

BITSNS_WORK	.equ	$800		; IOCS BITSNS workarea (16 bytes)

;----------------------------------

	.xdef	prog_start
	.xdef	proc_mark

	.xdef	proc_adrs_backup
	.xdef	proc_cont_address
	.xdef	main_loop

;----------------------------------

	.text

_keeppr_top:
prog_start:
	bra		@f
;----------------------------------
;	Residency marker.
;
;	check_proc looks for this string at a fixed offset from the top of
;	the resident block, so its position is part of the contract between
;	versions: a version that places it elsewhere cannot see - and cannot
;	remove - this one.
;
;	routine0 depends on that. It hands the resident block address back
;	to the caller instead of freeing it, so a caller that ignores the
;	return value leaks the block. Versions that share this marker
;	position must share the routine0 contract as well.
;----------------------------------
proc_mark:
	.dc.b	'SCALEKEY'
;----------------------------------

@@:
	clr.l	-(sp)
	DOS		__SUPER
	addq.w	#4,sp

	lea		(_keeppr_top-240)(pc),a3
	lea		proc_adrs_backup(pc),a4
	move.l	a3,(a4)
	move.l	a0,4(a4)

	bsr		parse_comline
	bsr		print_title

	move.w	print_usage_flag(pc),d0
	beq		@f
	bsr		print_usage
	move.w	#EXITCODE_NORMAL,d0
	bra		prog_exit
@@:
	move.w	kill_proc_flag(pc),d0
	beq		pre_start_main

precheck_kill_proc:
	bsr		check_proc
	tst.b	d0
	bne		proc_exist_kill_proc

proc_not_exist:
	bsr		print_proc_not_exist
	move.w	#EXITCODE_NORMAL,d0
	bra		prog_exit

proc_exist_kill_proc:
	moveq.l	#0,d0			; function 0: TSR exit
	trap	#7

	move.l	d0,-(sp)		; returned block address
	DOS		__MFREE
	addq.l	#4,sp

	bsr		disp_cls_all
	bsr		print_kill_proc
	move.w	#EXITCODE_KILL_PROC,d0

prog_exit:
	andi.w	#$ff,d0
	move.w	d0,-(sp)
	DOS		__EXIT2

;----------------------------------
pre_start_main:
	bsr		check_proc
	tst.b	d0
	beq		start_main

proc_exist_exit:
	bsr		print_proc_exist
	move.w	#EXITCODE_ALREADY_EXIST,d0
	bra		prog_exit

;----------------------------------
start_main:
	bsr		init_scalekey_channel_use
	bsr		init_scalekey_matrix
	bsr		set_trap7
	bsr		init_midi			; check MIDI board

	bsr		print_set_trap7
	bsr		print_keeppr
	move.w	#EXITCODE_KEEPPR,-(sp)
	move.l	#_keeppr_bottom-_keeppr_top,-(sp)
	DOS		__KEEPPR

;----------------------------------
init_scalekey_channel_use:
	lea		scalekey_channel_use(pc),a0
	lea		scalekey_channel_order(pc),a1
	moveq.l	#8-1,d0
@@:
	clr.l	(a0)+
	clr.b	(a1)+

	dbra	d0,@b
	rts

;----------------------------------
init_scalekey_matrix:
	lea 	scalekey_matrix(pc),a0
	lea 	scalekey_bitsns_mask(pc),a1
1:
	move.l	(a0)+,d0
	bne		@f
	rts
@@:
	move.l	d0,d1
	swap	d0
	lsr.w	#8,d0
	andi.w	#$ff,d0			; d0: num
	swap	d1				; d1: mask data
	or.b	d1,(a1,d0.w)
	bra		1b

;----------------------------------
; main_loop
;----------------------------------
main_loop:
	movem.l	d2-d7/a2-a6,-(sp)

	bsr		disp_opm_channel
	bsr		disp_opm_note
	bsr		disp_midi_in_marker
	bsr		check_shift_ctrl

	bsr		delay_keyonoff		; proc delay count down

	move.w	midi_board_not_arrive(pc),d0
	bne		check_keyboard_input
	bsr		midi_recv_loop

;----------------------------------
; check keyboard input
;----------------------------------
check_keyboard_input:
	lea		scalekey_bitsns_mask(pc),a0
	lea		bitsns_data(pc),a1
	lea		bitsns_data_pre(pc),a2
	lea		bitsns_data_xor(pc),a3
	lea		BITSNS_WORK,a4
	moveq.l	#16-1,d0
1:
	move.b	(a0)+,d1	; d1: bitsns_mask
	beq		@f

	move.b	(a1),d2		; d2: bs_pre
	move.b	d2,(a2)
	move.b	(a4),d3		; d3: bs
	move.b	d3,(a1)
	eor.b	d2,d3
	and.b	d1,d3
	move.b	d3,(a3)
@@:
	addq.w	#1,a1
	addq.w	#1,a2
	addq.w	#1,a3
	addq.w	#1,a4

	dbra	d0,1b

;----------------------------------
; check bitsns xor data
;----------------------------------
	lea		scalekey_matrix(pc),a0
	lea		bitsns_data_xor(pc),a1
	lea		bitsns_data(pc),a2
1:
	move.l	(a0)+,d3
	bne		@f

	movem.l	(sp)+,d2-d7/a2-a6
	rts

;---
@@:
	move.l	d3,d6		; matrix data => d6
	move.l	d3,d4
	move.l	d3,d5
	swap	d3
	lsr.w	#8,d3
	andi.w	#$ff,d3		; d3: num
	swap	d4			; d4: mask
	move.b	(a1,d3.w),d5
	and.b	d4,d5
	beq		1b

	lsr.w	#8,d5
	andi.l	#$ff,d5		; d5: key note (0-95)

	move.b	d5,d6		; key note -> d6.b
	move.b	(a2,d3.w),d3
	and.b	d4,d3
	beq		@f			; key on/off?

	btst.b	#INPUT_ENABLE_KEYBOARD,keyin_enable+1(pc)	; check keyin_enable
	beq		1b
	bsr		note_keyon
	bra		1b
@@:
	bsr		note_keyoff
	bra		1b

;----------------------------------
check_shift_ctrl:
	lea		note_oct_updown(pc),a5
	clr.w	(a5)

	move.b	BITSNS_WORK+$E,d0
	btst.l	#0,d0		; check SHIFT key
	beq		@f
	move.w	note_oct_updown_shift_value(pc),(a5)
	rts
@@:
	btst.l	#1,d0		; check CTRL key
	beq		@f
	move.w	note_oct_updown_ctrl_value(pc),(a5)
@@:
	rts

;----------------------------------
print_title:
	move.w	print_title_enable(pc),d0
	beq		@f

print_title_force:
	lea		str_title(pc),a1
	IOCS	_B_PRINT
@@:
	rts

;----------------------------------
print_keeppr:
	move.w	print_title_enable(pc),d0
	beq		@f

	lea		str_keeppr(pc),a1
	IOCS	_B_PRINT
@@:
	rts

;----------------------------------
print_set_trap7:
	move.w	print_title_enable(pc),d0
	beq		@f

	lea		str_set_trap7(pc),a1
	IOCS	_B_PRINT
@@:
	rts

;----------------------------------
print_kill_proc:
	move.w	print_title_enable(pc),d0
	beq		@f

	lea		str_kill_proc(pc),a1
	IOCS	_B_PRINT
@@:
	rts

;----------------------------------
print_proc_exist:
	move.w	print_title_enable(pc),d0
	beq		@f

	lea		str_proc_exist(pc),a1
	IOCS	_B_PRINT
@@:
	rts

;----------------------------------
print_proc_not_exist:
	move.w	print_title_enable(pc),d0
	beq		@f

	lea		str_proc_not_exist(pc),a1
	IOCS	_B_PRINT
@@:
	rts

;----------------------------------
print_usage:
	move.w	print_title_enable(pc),d0
	bne		@f
	bsr		print_title_force
@@:
	lea		str_usage(pc),a1
	IOCS	_B_PRINT
	rts

;==================================
str_title:
	.dc.b	TITLE_PROGNAME,' version ',TITLE_VERSION,TITLE_SUBVERSION,' ',TITLE_COPYRIGHT,13,10,0
str_keeppr:
	.dc.b	'常駐プロセスを開始しました。',13,10,0
str_kill_proc:
	.dc.b	'常駐プロセスを解除しました。',13,10,0
str_set_trap7:
	.dc.b	'TRAP #7 ベクタを設定しました。',13,10,0
str_proc_exist:
	.dc.b	'常駐プロセスはすでに存在しています。',13,10,0
str_proc_not_exist:
	.dc.b	'常駐プロセスは見つかりません。',13,10,0
str_usage:
	.dc.b	'usage: scalekey [switch]',13,10
	.dc.b	'switch:  -r  常駐解除',13,10
	.dc.b   '         -s  非表示モード',13,10
	.dc.b	0

;----------------------------------
	.even

proc_adrs_backup:
	.ds.l	1
proc_cont_address:
	.ds.l	1

bitsns_data:
	.ds.b	16
bitsns_data_pre:
	.ds.b	16
bitsns_data_xor:
	.ds.b	16

scalekey_bitsns_mask:
	.dc.b	0,0,0,0,0,0,0,0		; 16byte
	.dc.b	0,0,0,0,0,0,0,0

scalekey_matrix:
	.dc.l SCALEKEY_O4C     ; o4 c
	.dc.l SCALEKEY_O4C_    ; o4 c#
	.dc.l SCALEKEY_O4D     ; o4 d
	.dc.l SCALEKEY_O4D_    ; o4 d#
	.dc.l SCALEKEY_O4E     ; o4 e
	.dc.l SCALEKEY_O4F     ; o4 f
	.dc.l SCALEKEY_O4F_    ; o4 f#
	.dc.l SCALEKEY_O4G     ; o4 g
	.dc.l SCALEKEY_O4G_    ; o4 g#
	.dc.l SCALEKEY_O4A     ; o4 a
	.dc.l SCALEKEY_O4A_    ; o4 a#
	.dc.l SCALEKEY_O4B     ; o4 b

	.dc.l SCALEKEY_O5C     ; o5 c
	.dc.l SCALEKEY_O5C_    ; o5 c#
	.dc.l SCALEKEY_O5D     ; o5 d
	.dc.l SCALEKEY_O5D_    ; o5 d#
	.dc.l SCALEKEY_O5E     ; o5 e
	.dc.l SCALEKEY_O5F     ; o5 f
	.dc.l SCALEKEY_O5F_    ; o5 f#
	.dc.l SCALEKEY_O5G     ; o5 g
	.dc.l SCALEKEY_O5G_    ; o5 g#
	.dc.l SCALEKEY_O5A     ; o5 a
	.dc.l SCALEKEY_O5A_    ; o5 a#
	.dc.l SCALEKEY_O5B     ; o5 b

	.dc.l SCALEKEY_O5CX    ; o5 c (additional)
	.dc.l SCALEKEY_O6CX    ; o6 c (additional)
	.dc.l 0

