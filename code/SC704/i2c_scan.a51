; I2C_SCAN.A51
;
; Simple program to scan the I2C bus via an SC704 I2C bus master card
; and report back any active I2C devices.
;
; SCL is controlled by bit 0 and SDA is controlled by bit 7.
;
; Uses register bank 3 for private variables
; R0 holds a copy of whats writtien to the I2C port.
;
; Load register definitions for an ATMEL AT89S8253.
$NOMOD51
$INCLUDE(89S8253.MCU)

SDALO		EQU		07Fh	; AND with this value
SDAHI		EQU		080h	; OR with this value
SCLLO		EQU		0FEh	; AND with this value
SCLHI		EQU		001h	; OR with this value

IOBASE		EQU		0FC00h	; IO space base address
SC704ADDR	EQU		00Ch	; SC704 default address is 12 (0x0C)

IOADDR		EQU		IOBASE+SC704ADDR

DELAY		EQU		08h

	ORG		4000h

	MOV		DPTR,#TITLE
	ACALL	WRSTR

	MOV		PSW,#00h		; switch to register bank 0
	MOV		R0,#08h			; start with address 8
LOOP:
	ACALL	I2CSTART		; START condition
	MOV		A,R0			; get the address to check
	RL		A				; shift 1 bit left
	ACALL	I2CWRITE
	JC		NAK				; no device at that address

	MOV		A,R0			; get address just scanned
	ACALL	WRHEX			; display it
	ACALL	WRCRLF
NAK:
	ACALL	I2CEND			; STOP condition
	INC		R0				; move to next address
	CJNE	R0,#080h,LOOP
	RET


;
; Send START condition
; Assumes SDA and SCL are both HIGH already
;
I2CSTART:
	MOV		PSW,#18h	; switch to register bank 3
	MOV		R0,#081h	; set SCL & SDA bits HIGH
	MOV		PSW,#00h	; switch to register bank 0
	
	ORL		EECON,#04h	; switch to DPTR 1
	MOV		DPTR,#IOADDR

	MOV		A,#01h		; set SCL HIGH & SDA LOW
	MOVX	@DPTR,A		; update the port
	NOP
	NOP
	MOV		A,#00h		; set SCL LOW & SDA LOW
	MOVX	@DPTR,A		; update the port

	ANL		EECON,#0FBh	; switch back to DPTR 0
	RET
;
; write a byte - ACC holds the byte to sends
; C is set for a NACK and clear for an ACK
; State of SCL & SDA held in R0 in register bank 3
;
I2CWRITE:
	ORL		EECON,#04h	; switch to DPTR 1
	MOV		DPTR,#IOADDR
	MOV		PSW,#18h	; switch to register bank 3

	MOV		R1,#8		; number of bits to send
I2CX1:	
	RLC		A			; carry holds bit to send
	XCH		A,R0		; swap A & R0
	RRC		A			; carry now in MSB (i.e. SDA bit)
	MOVX	@DPTR,A		; update the port
	NOP
	ORL		A,#SCLHI	
	MOVX	@DPTR,A		; update the port
	NOP
	NOP
	NOP
	NOP
	ANL		A,#SCLLO	
	MOVX	@DPTR,A		; update the port
	XCH		A,R0		; swap A & R0
	DJNZ	R1,I2CX1
	
	MOV		PSW,#00h	; switch back to register bank 0
						; do this here or we lose the carry flag
						
	; done 8 bits so check for ACK or NAK
	MOV		A,#080h		; release SDA and set SCL LOW
	MOVX	@DPTR,A		; update the port
	NOP
	
	MOV		A,#081h		; release SDA and set SCL HIGH
	MOVX	@DPTR,A		; update the port
	NOP
	NOP
	MOVX	A,@DPTR		; read the port
	RLC		A			; carry flag holds ACK/NAK state
	MOV		A,#080h		; SDA HIGH and SCL LOW
	MOVX	@DPTR,A		; update the port
	
	ANL		EECON,#0FBh	; switch back to DPTR 0
	RET

;
; Send STOP condition
; SCL will already be low
;
I2CEND:
	ORL		EECON,#04h	; switch to DPTR 1
	MOV		DPTR,#IOADDR

	MOV		A,#00h		; set SCL LOW & SDA LOW
	MOVX	@DPTR,A		; update the port
	NOP
	NOP
	MOV		A,#01h		; set SCL HIGH & SDA LOW
	MOVX	@DPTR,A		; update the port
	NOP
	NOP
	MOV		A,#081h		; set SCL HIGH & SDA HIGH
	MOVX	@DPTR,A		; update the port

	ANL		EECON,#0FBh	; switch back to DPTR 0
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
	DB		'RCBus 8051 I2C Scanner - SC704 @ Address 0x0C',10,13
	DB		'Scanning for devices ...',10,13,0
ACKMSG:
	DB		'ACK received',10,13,0
NAKMSG:
	DB		'NAK received',10,13,0
	END