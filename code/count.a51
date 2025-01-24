; COUNT.A51
;
; Simple program to output a count to the LEDs on an SC129 digital I/O board.
; The SC129 should have jumpers set for I/O space address $00 (default).
; 
$NOMOD51
$INCLUDE(89C51RC.MCU)

SC129	EQU	0FC00h				; address of SC129 card in 8051 memory space

	ORG		4000h				; start user code at address $4000

	MOV		DPTR,#SC129			; DPTR holds address of SC129 card
	CLR		A
	MOVX	@DPTR,A				; all LEDs off

	MOV		R1,#00h
	MOV		R2,#00h
LOOP1:
	NOP
	DJNZ	R1,LOOP1
	DJNZ	R2,LOOP1
	MOVX	@DPTR,A				; update LEDs
	INC		A
	SJMP	LOOP1
		
	END
	