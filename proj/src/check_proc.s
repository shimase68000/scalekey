;
; check process
;
;----------------------------------

	.xref	prog_start
	.xref	proc_mark

;----------------------------------

	.xdef	check_proc

;----------------------------------

	.text

check_proc:
	movem.l	d2,-(sp)

	moveq.l	#0,d2				; +0 : link to the previous memory block
	bsr		check_proc_sub		; check TSR (backward)
	tst.b	d0
	bne		@f

	moveq.l	#12,d2				; +12: link to the next memory block
	bsr		check_proc_sub		; check TSR (forward)
@@:
	movem.l	(sp)+,d2
	rts

;----------------------------------
check_proc_sub:
	movem.l	d1/a0-a2,-(sp)

sub_loop:
	tst.l	(a0,d2.w)
	bne		@f

	moveq.l	#0,d0				; process not found: return 0
	bra		sub_exit

;-----
@@:
	movea.l	(a0,d2.w),a0
	cmpi.b	#$ff,4(a0)			; check attributes of memory block ($ff: KEEP process)
	bne		sub_loop
	; a0 points at the memory management block. Human68k places the
	; program $100 bytes further on, so the marker of the resident copy
	; sits at (proc_mark - prog_start) from there.
	lea		proc_mark-prog_start+$100(a0),a1
	lea		proc_mark(pc),a2

	moveq.l	#8-1,d1
@@:
	cmp.b	(a1)+,(a2)+
	dbne	d1,@b
	bne		sub_loop

	moveq.l	#1,d0				; process exist: return 1

sub_exit:
	movem.l	(sp)+,d1/a0-a2
	rts
