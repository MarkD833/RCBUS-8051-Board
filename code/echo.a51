; ECHO.A51
;
; Simple program to read the SC129 input port and echo back on the
; SC129 output port.
; The SC129 should have jumpers set for I/O space address $00 (default).
; 
$NOMOD51
$INCLUDE(89C51RC.MCU)

SC129	EQU	0FC00h				; address of SC129 card in 8051 memory space

	ORG		4000h				; start user code at address $4000

	MOV		DPTR,#SC129			; DPTR holds address of SC129 card
LOOP1:
	MOVX	A,@DPTR				; read the input port
	MOVX	@DPTR,A				; write back to output port
	SJMP	LOOP1
		
	END
	