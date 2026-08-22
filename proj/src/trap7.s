;
; trap7.s
;
;----------------------------------

    .include iocscall.mac
	.include doscall.mac

	.include title.mac
	.include scalekey.mac

;----------------------------------

	.xref	disp_onoff
	.xref	xpos_channel
	.xref	xpos_midi_marker
	.xref	channel_use_scan_offset
	.xref	channel_policy
	.xref	channel_policy_over
	.xref	channel_select
	.xref	note_offset
	.xref	note_oct_updown
	.xref	note_oct_updown_shift_value

	.xref	slotmask
	.xref	keyin_enable
	.xref	detune
	.xref	delay_count
	.xref	opmreg_access_permission
	.xref	opmset_detune

	.xref	unison_count
	.xref	poly_count
	.xref	midi_channel_filter
	.xref	midi_board_not_arrive
	.xref	midi_note_keyoff_all

	.xref	restore_mcsvector
	.xref	proc_adrs_backup
	.xref	proc_cont_address
	.xref	main_loop

;----------------------------------

	.xdef	set_trap7

;----------------------------------

TRAPNO		.equ	$20+7		; trap #7 vector number
PSP_EXECPATH	.equ	$80		; Human68k PSP +$80 = execution path area
							;  (drive 2 + path 66 + name 24 bytes)
PROC_NUM	.equ	(end_of_proc_table-proc_table)/2-1

;----------------------------------
set_trap7:
	lea		trap7_entry(pc),a1
	move.w	#TRAPNO,d1
	IOCS	_B_INTVCS

	lea		backup_trap7_adrs(pc),a0
	move.l	d0,(a0)

	rts

;----------------------------------
backup_trap7_adrs:
	.ds.l	1

;----------------------------------
trap7_entry:
	movem.l	d2-d7/a0-a6,-(sp)

	cmp.w	#PROC_NUM,d0
	bhi		trap7_exit		; out of range => ignore

	add.w	d0,d0
	move.w	proc_table(pc,d0.w),d0
	jsr		proc_table(pc,d0.w)

trap7_exit:
	movem.l	(sp)+,d2-d7/a0-a6
	rte

;----------------------------------
proc_table:
	.dc.w	routine0-proc_table		; 00: TSR exit
	.dc.w	routine1-proc_table		; 01: disp on/off & get scalekey version
	.dc.w	routine2-proc_table		; 02: set disp position & get scalekey version
	.dc.w	routine3-proc_table		; 03: set note offset & get scalekey version
	.dc.w	routine4-proc_table		; 04: set shift/ctrl control
	.dc.w	routine5-proc_table		; 05: set channel assign policy (sequential/round-robin)
	.dc.w	routine6-proc_table     ; 06: set channel select
	.dc.w	routine7-proc_table		; 07: get main routine address
	.dc.w	routine8-proc_table		; 08: set unison/polyphonic count
	.dc.w	routine9-proc_table		; 09: set midi channel filter
	.dc.w	routine10-proc_table	; 10: set disp position (MIDI marker)
	.dc.w	routine11-proc_table	; 11: get MIDI board status
	.dc.w	routine12-proc_table	; 12: keyoff ALL for MIDI
	.dc.w	routine13-proc_table	; 13: set slotmask
	.dc.w	routine14-proc_table	; 14: set keyin enable/disable
	.dc.w	routine15-proc_table	; 15: set start scan channel
	.dc.w	routine16-proc_table	; 16: set detune
	.dc.w	routine17-proc_table	; 17: set delay count
	.dc.w	routine18-proc_table	; 18: set opmreg_access_permission
	.dc.w	routine19-proc_table	; 19: get exec path
	.dc.w	routine20-proc_table	; 20: mark of master

end_of_proc_table:

;----------------------------------
; 00: TSR exit
;  => d0.l: address of the resident block. The CALLER must free it.
;
;  Note : The MFREE is not performed here. Freeing the block from
;         inside it would leave the remaining instructions - this rts,
;         plus trap7_exit's movem and rte - executing in memory that no
;         longer belongs to us. The caller is always a separate instance
;         of scalekey.x running in its own block.
;         Do not reinstate the MFREE here.
;----------------------------------
routine0:
	bsr		restore_mcsvector

	movea.l	backup_trap7_adrs(pc),a1
	move.w	#TRAPNO,d1
	IOCS	_B_INTVCS

	move.l	proc_adrs_backup(pc),d0		; hand the block to the caller
	rts

;----------------------------------
; 01: disp on/off & get scalekey version
;     d1.w: -1: only get version
;            0: disp off
;            1: disp on for Tone Editor N
;  => d0.l: version of scalekey
;----------------------------------
routine1:
	tst.l	d1
	bmi		@f

	lea		disp_onoff(pc),a1
	move.w	d1,(a1)
@@:
	move.l	marker_version(pc),d0
	rts

;----------------------------------
; 02: set disp position & get scalekey version
;     d1.w: Xpos
;     d2.w: Ypos
;  => d0.l: version of scalekey
;
;  Note : writes four words starting at xpos_channel (disp.s):
;           +0 xpos_channel  +2 ypos_channel
;           +4 xpos_note     +6 ypos_note
;         the note line sits one row below the channel line.
;----------------------------------
routine2:
	lea		xpos_channel(pc),a1
	move.w	d1,(a1)
	move.w	d1,4(a1)
	move.w	d2,2(a1)
	addq.w	#1,d2
	move.w	d2,6(a1)

	move.l	marker_version(pc),d0
	rts

;----------------------------------
; 03: note offset & get scalekey version
;      d1.w: offset
;   => d0.w: version of scalekey
;----------------------------------
routine3:
	lea		note_offset(pc),a1
	move.w	d1,(a1)

	move.l	marker_version(pc),d0
	rts

;----------------------------------
; 04: shift/ctrl +12/-12
;     d1.w: 0=SHIFT+/CTRL-
;           1=SHIFT-/CTRL+
;----------------------------------
routine4:
	lea		note_oct_updown_shift_value(pc),a1
	tst.w	d1
	beq		@f

	move.w	#SCALEKEY_OCT_UP,(a1)		; SHIFT
	move.w	#SCALEKEY_OCT_DOWN,2(a1)	; CTRL
	rts

@@:
	move.w	#SCALEKEY_OCT_DOWN,(a1)		; SHIFT
	move.w	#SCALEKEY_OCT_UP,2(a1)		; CTRL
	rts

;----------------------------------
; 05: channel assign policy
;     d1.w: 0=sequencial / 1=round-robin
;     d2.w: 0=hold / 1=over
;----------------------------------
routine5:
	lea		channel_policy(pc),a1
	move.w	d1,(a1)
	lea		channel_policy_over(pc),a1
	move.w	d2,(a1)

	lea		channel_use_scan_offset(pc),a1	; reset use_scan_offset
	move.w	2(a1),(a1)
	rts

;----------------------------------
; 06: channel select
;     d1.w: channel select data
;----------------------------------
routine6:
	lea		channel_select(pc),a1
	move.w	d1,(a1)
	rts

;----------------------------------
; 07: get main_loop address
;  => d0.l: main_loop address
;----------------------------------
routine7:
	lea		main_loop(pc),a1
	move.l	a1,d0
	rts

;----------------------------------
; 08: set unison/polyphonic count
;     d1.w: unison count
;     d2.w: polyphonic count
;----------------------------------
routine8:
	lea		unison_count(pc),a1
	move.w	d1,(a1)
	lea		poly_count(pc),a1
	move.w	d2,(a1)
	rts

;----------------------------------
; 09: set midi_channel_filter
;     d1.w: midi_channel_filter (-2=GET)
;  => d0.l:
;----------------------------------
routine9:
	lea		midi_channel_filter(pc),a1
	cmpi.w	#-2,d1
	beq		@f

	move.w	d1,(a1)
@@:
	moveq.l	#0,d0
	move.w	(a1),d0
	rts

;----------------------------------
; 10: set disp position (MIDI marker)
;     d1.w: Xpos
;     d2.w: Ypos
;
;  Note : writes xpos_midi_marker / ypos_midi_marker (disp.s) as a pair.
;----------------------------------
routine10:
	lea		xpos_midi_marker(pc),a1
	move.w	d1,(a1)
	move.w	d2,2(a1)
	rts

;----------------------------------
; 11: get MIDI board status
;  => d0.l: 0=MIDI board exist
;----------------------------------
routine11:
	moveq.l	#0,d0
	move.w	midi_board_not_arrive(pc),d0
	rts

;----------------------------------
; 12: keyoff ALL for MIDI
;----------------------------------
routine12:
	bra		midi_note_keyoff_all

;----------------------------------
; 13: set slotmask
;     d1.l: channel_slotmask (pointer)
;----------------------------------
routine13:
	lea		slotmask(pc),a1
	movea.l	d1,a2			; a2: channel_slotmask
	moveq.l	#8-1,d2
@@:
	move.b	(a2)+,d1
	lsl.b	#3,d1
	andi.b	#%0111_1000,d1	; slotmask (4bit) shifted into bit6-3
	move.b	d1,(a1)+
	dbra	d2,@b
	rts

;----------------------------------
; 14: keyin enable/disable
;     d1.w: (-1=GET)
;         bit0: keyboard input enable
;         bit1: midi input enable
;     => d0.l
;----------------------------------
routine14:
	lea		keyin_enable(pc),a1
	tst.w	d1
	bmi		@f
	move.w	d1,(a1)
	rts

@@:
	moveq.l	#0,d0
	move.w	(a1),d0
	rts

;----------------------------------
; 15: set start scan channel
;     d1.w: -1=GET
;     => d0.l
;----------------------------------
routine15:
	lea		channel_use_scan_offset(pc),a1
	tst.w	d1
	bmi		@f

	andi.w	#%111,d1
	add.w	d1,d1
	add.w	d1,d1
	move.w	d1,(a1)		; current
	move.w	d1,2(a1)	; base
	rts

@@:
	moveq.l	#0,d0
	move.w	2(a1),d0	; base
	lsr.w	#2,d0		; /4
	rts

;----------------------------------
; 16: set detune
;     d1.l: detune value (pointer)
;----------------------------------
routine16:
	lea		detune(pc),a1
	movea.l	d1,a2			; a2: detune
	moveq.l	#8-1,d2
@@:
	move.w	(a2)+,d1
	add.w	d1,d1
	add.w	d1,d1
	move.w	d1,(a1)+
	dbra	d2,@b

	bra		opmset_detune

;----------------------------------
; 17: set delay count
;     d1.w: -1=GET
;     => d0.l
;----------------------------------
routine17:
	lea		delay_count(pc),a1
	tst.w	d1
	bmi		@f

	move.w	d1,2(a1)
	rts

@@:
	moveq.l	#0,d0
	move.w	2(a1),d0
	rts

;----------------------------------
; 18: set opmreg_access_permission
;     d1.l: -1=GET
;     => d0.l
;----------------------------------
routine18:
	lea		opmreg_access_permission(pc),a1
	tst.l	d1
	bmi		@f

	move.l	d1,(a1)
	rts

@@:
	move.l	(a1),d0
	rts

;----------------------------------
; 19: get exec path
;     => d0.l exec path pointer
;----------------------------------
routine19:
	move.l	proc_cont_address(pc),d0
	addi.l	#PSP_EXECPATH,d0
	rts

;----------------------------------
; 20: mark of master
;     d1.l: -1=GET
;            0=CLEAR
;           >0=ACQUIRE
;     d2.l:  mark (at CLEAR)
;
;     GET:
;       d0.l <= current mark
;
;     CLEAR:
;       if mark==d2.l:
;            mark <= 0
;            d0.l <= 0
;       else:
;            d0.l <= current mark
;
;     ACQUIRE:
;       if mark==0:
;            mark <= d1.l
;            d0.l <= 0
;       else:
;            d0.l <= current mark
;----------------------------------
routine20:
	lea		mark_of_master(pc),a1

	tst.l	d1
	bmi		1f		; -> get
	beq		2f		; -> clear

;--- acquire
	move.l	(a1),d0
	bne     3f		; -> exit

	move.l	d1,(a1)
	moveq.l	#0,d0
	rts

;--- get
1:
	move.l	(a1),d0
	rts

;--- clear
2:
	move.l	(a1),d0
	cmp.l	d0,d2
	bne		3f		; -> exit

	moveq.l	#0,d0
	move.l	d0,(a1)

;--- exit
3:
	rts

;----------------------------------
marker_version:
	.dc.l	SCALEKEY_VERSION

mark_of_master:
	.dc.l	0

