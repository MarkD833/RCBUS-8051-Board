; SC406.A51
;
; Simple program to read the temperature from a TC74 temperature sensor mounted on
; an SC406 module using an SC704 I2C bus master card.
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
TC74ADDR	EQU		04Dh	; I2C bus address of the TC74
TC74READCMD	EQU		00h		; TC74 read temperature command

	ORG		4000h

	MOV		DPTR,#TITLE
	ACALL	WRSTR

	MOV		PSW,#00h		; make sure we're on register bank 0

	ACALL	I2CSTART		; START condition
	MOV		A,#TC74ADDR		; TC74 device address
	RL		A				; shift 1 bit left
	ACALL	I2CWRITE		; output device address + write
	JC		NAK				; no response - give up

	MOV		A,#TC74READCMD	; read temperature command
	ACALL	I2CWRITE		; output device address
	JC		NAK				; no response - give up

	ACALL	I2CEND			; STOP condition
	NOP
	ACALL	I2CSTART		; START condition
	MOV		A,#TC74ADDR		; TC74 device address
	RL		A				; shift 1 bit left
	ORL		A,#01h			; set read bit
	ACALL	I2CWRITE		; output device address
	JC		NAK				; no response - give up

	ACALL	I2CREAD			; read a byte
	MOV		B,A				; save the byte
	ACALL	I2CEND			; STOP condition
	
	MOV		A,B				; get received byte back
	MOV		B,#10
	DIV		AB				; divide by 10 - B holds 1's digit
	MOV		R7,B			; save 1's digit
	MOV		B,#10
	DIV		AB				; divide by 10 - B holds 10's digit
	MOV		R6,B			; save 10's digit
	ADD		A,#'0'			; A holds 100's digit - convert to ASCII
	ACALL	WRCHR			; Write it out	
	MOV		A,R6			; Get 10's digit
	ADD		A,#'0'			; convert to ASCII
	ACALL	WRCHR			; Write it out	
	MOV		A,R7			; Get 1's digit
	ADD		A,#'0'			; convert to ASCII
	ACALL	WRCHR			; Write it out	

	MOV		DPTR,#DEGC
	ACALL	WRSTR
	RET
	
NAK:
	ACALL	I2CEND			; STOP condition
	MOV		DPTR,#NAKRX
	ACALL	WRSTR
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
I2CW1:	
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
	DJNZ	R1,I2CW1
	
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
; read a byte - ACC holds the received byte
; C is set for a NACK and clear for an ACK
; State of SCL & SDA held in R0 in register bank 3
;
I2CREAD:
	ORL		EECON,#04h	; switch to DPTR 1
	MOV		DPTR,#IOADDR
	MOV		PSW,#18h	; switch to register bank 3

	MOV		R1,#8		; number of bits to read
I2CR1:
	MOV		A,#(SCLHI+SDAHI)
	MOVX	@DPTR,A		; update the port
	NOP
	NOP
	NOP
	NOP
	MOVX	A,@DPTR		; read the port
	RLC		A			; carry flag holds bit just read in
	XCH		A,R0		; swap A & R0
	RLC		A			; carry flag now in bit 0
	XCH		A,R0		; swap A & R0 again
	MOV		A,#SDAHI	; SCL LOW
	MOVX	@DPTR,A		; update the port
	NOP
	NOP
	NOP
	NOP
	DJNZ	R1,I2CR1

	; R0 now holds the complete received byte
	MOV		B,R0
	MOV		A,B

	MOV		PSW,#00h	; switch back to register bank 0
						; do this here or we lose the carry flag
	
	; done 8 bits so check for ACK or NAK
	MOV		A,#SDAHI	; release SDA and set SCL LOW
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
	
	MOV		A,B			; get received byte back
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
	DB		'TC74 Temperature Sensor (SC406) read via SC704 I2C Bus Master',10,13,0
NAKRX:
	DB		'NAK received.',10,13,0
DEGC:
	DB		' Deg C',10,13,0

	END