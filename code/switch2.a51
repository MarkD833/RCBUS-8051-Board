; SWITCH2.A51
;
; Simple program to output a count to the LEDs on an SC129 digital I/O board.
; The SC129 should have jumpers set for I/O space address $00 (default).
; The first time the count reaches 15, then the RAM_SHARE bit is set to cause
; the program and data spaces to be separate (program in lower 64K and data in
; upper 64K).
;
; Visually, there should be nothing to see and the code should continue counting.
; 
$NOMOD51
$INCLUDE(89C51RC.MCU)

SC129	EQU	0FC00h				; address of SC129 card in 8051 memory space
SPLIT	EQU	0F801h				; address of the location for RAM_SHARE

WRHEX	EQU	0438h				; address of WRHEX routine in MON51
WRCRLF	EQU	0474h				; address of WRLFCR4 routine in MON51

	ORG		4000h				; start user code at address $4000

	MOV		DPTR,#SC129			; DPTR holds address of SC129 card
	CLR		A
	MOVX	@DPTR,A				; all LEDs off
	CALL	WRHEX
	CALL	WRCRLF
	
	MOV		R3,#15				; count 15 LED changes
	MOV		R1,#00h
	MOV		R2,#00h
LOOP1:
	NOP
	DJNZ	R1,LOOP1
	DJNZ	R2,LOOP1
	MOVX	@DPTR,A				; update LEDs
	INC		A					; increment LED port counter
	MOV		R4,A				; save ACC
	DEC		R3					; decrement LED change counter
	CJNE	R3,#0,LOOP1			; repeat till it's zero

	; now done a count of 15 on the LEDs so 
	; separate program space from data space
	MOV		DPTR,#SPLIT			; DPTR holds address of RAM_SHARE latch
	MOV		A,#1
	MOVX	@DPTR,A				; write a 1 to RAM_SHARE

	; program space and data space should now be separate
	NOP
	NOP
	NOP
	MOV		A,R4				; restore ACC
	MOV		DPTR,#SC129			; DPTR holds address of SC129 card
	
	; carry on counting on the LEDs
	MOV		R1,#00h
	MOV		R2,#00h
LOOP2:
	NOP
	DJNZ	R1,LOOP2
	DJNZ	R2,LOOP2
	MOVX	@DPTR,A				; update LEDs
	INC		A
	MOV		R4,A				; save ACC

	; if program space and data space are really separate, then writing
	; to the NOP instruction address will have no effect on the program
	; as the write will occur in data space. 
	MOV		DPTR,#LOOP2			; DPTR holds address of data space variable
	MOVX	A,@DPTR				; read RAM variable
	INC		A					; increment it
	MOVX	@DPTR,A				; write RAM variable
	CALL	WRHEX				; display the value
	CALL	WRCRLF
	MOV		A,R4				; restore ACC
	
	MOV		DPTR,#SC129			; DPTR holds address of SC129 card
	SJMP	LOOP2

	END
	