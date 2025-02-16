; Hello.A51
;
; Simple program to use an SC705 (MC68B50) as a second UART.
; Assumes that the SC705 is at I/O address 0xC0.
;
; Simply prints out "Hello World!" at 115200,8,N,1 assuming that
; a 7.3728MHz crystal was fitted to X1.
;
; Load register definitions for an ATMEL AT89S8253.
$NOMOD51
$INCLUDE(89S8253.MCU)

IOBASE		EQU		0FC00h	; IO space base address
SC705ADDR	EQU		0C0h	; SC718 address is 0xC0

; MC6850 UART register definitions
CTRL		EQU		IOBASE+SC705ADDR
TXRX		EQU		IOBASE+SC705ADDR+1

	ORG		4000h

	MOV		DPTR,#TITLE
	ACALL	WRSTR

	MOV		DPTR,#CTRL
	MOV		A,#016h			; div 64, 8N1, INT disabled
	MOVX	@DPTR,A

	; simple delay
	MOV		R1,#00h
LOOP1:
	NOP
	DJNZ	R1,LOOP1

	ANL		EECON,#0FBh		; select DPTR #0
	MOV		DPTR,#MSG		; DPTR #0 points to text to send

LOOP2:
	MOVX	A,@DPTR			; read the byte
	INC		DPTR
	JZ		THEEND			; quit if end of string to transmit
	MOV		R0,A			; save char to send
	
	ORL		EECON,#04h		; select DPR #1	
	MOV		DPTR,#CTRL
WAIT1:
	MOVX	A,@DPTR			; read status register
	JNB		ACC.1,WAIT1		; wait for tx reg to be empty

	MOV		DPTR,#TXRX
	MOV		A,R0			; restore byte to send
	MOVX	@DPTR,A			; write byte to send
	ANL		EECON,#0FBh		; select DPTR #0
	
	SJMP	LOOP2
	
THEEND:
	RET	

;------------------------------------------------------------------------------
; HELPER ROUTINES - MOSTLY SERIAL I/O
;------------------------------------------------------------------------------
;
; Write a null terminated string to the serial port
; DPTR holds the address of the first character
;
WRSTR:
	CLR		A			; Zero offset
	MOVC	A,@A+DPTR	; Get character (assumes ROM & RAM combined)
	INC		DPTR		; Advance to next
	JZ		WRSTRx		; End of string
	ACALL	WRCHR		; Write it out
	SJMP	WRSTR		; And go back for the next character
WRSTRx:
	RET
;
; Write a new line (CR & LF) to the serial port
;
WRCRLF:
	MOV		A,#10
	ACALL	WRCHR		; Write it out	
	MOV		A,#13
	ACALL	WRCHR		; Write it out	
	RET
;
; Write a character in A to the serial port
;
WRCHR:
	JNB		SCON.1,$	; Wait for the TI bit to be set
	CLR		SCON.1		; Clear TI bit
	MOV		SBUF,A		; Write out char
	RET
;
; Write byte in A to the serial port in HEX
;
WRHEX:
	PUSH	ACC			; Save value
	SWAP	A			; Get high nibble
	ACALL	WRHEX1		; Output it
	POP	ACC				; Get low nibble
WRHEX1:
	ANL	A,#00001111b	; Use low digit only
	ADD	A,#'0'			; Convert to ASCII
	CJNE	A,#'0'+10,$+3	; Non-Destructive compare
	JC	WRCHR			; A = 0-9
	ADD	A,#7			; Convert HEX digits
	SJMP	WRCHR		; And write the character

TITLE:
	DB		'SC705 (MC68B50) Hello Demo',10,13,0
MSG:
	DB		'Hello World!',10,13,0
	
	END