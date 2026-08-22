;
; comline.s (parse command line)
;
;----------------------------------

    .include iocscall.mac
	.include doscall.mac

;----------------------------------

	.xdef	parse_comline

	.xdef	print_usage_flag
	.xdef	print_title_enable
	.xdef	kill_proc_flag

;----------------------------------
parse_comline:
	move.l	a2,-(sp)

	tst.b	(a2)+		; skip the length byte, and check for empty
	beq		parse_exit

	bsr		parse_sub

parse_exit:
	move.l	(sp)+,a2
	rts

;----------------------------------
parse_sub:
	movem.l	d0-d2/a1,-(sp)
	moveq.l	#0,d1

parse_sub_loop:
	move.b	(a2)+,d0
	bne		@f

	movem.l	(sp)+,d0-d2/a1
	rts

@@:
	tst.b	d1
	bne		1f

	cmp.b	#'/',d0
	beq		@f
	cmp.b	#'-',d0
	beq		@f
	bra		parse_sub_loop
@@:
	moveq.l	#1,d1
	bra		parse_sub_loop

;---
1:
	move.b	(a2),d2
	cmpi.b	#' ',d2			; check ' '
	bne		@f
	moveq.l	#0,d1			; clear flag
@@:
	ori.b	#$20,d0
	cmpi.b	#'s',d0			; 's': non disp mode
	beq		switch_s
	cmpi.b	#'r',d0			; 'r': unload TSR process
	beq		switch_r
; anything other than 's' / 'r' after '/' or '-' lands here
switch_usage:
	lea		print_usage_flag(pc),a1
	move.w	#1,(a1)
	bra		parse_sub_loop

switch_r:
	lea		kill_proc_flag(pc),a1
	move.w	#1,(a1)
	bra		parse_sub_loop

switch_s:
	lea		print_title_enable(pc),a1
	move.w	#0,(a1)
	bra		parse_sub_loop

;----------------------------------
print_usage_flag:			; switch other
	.dc.w	0

print_title_enable:			; switch 's'
	.dc.w	1

kill_proc_flag:				; switch 'r'
	.dc.w	0

