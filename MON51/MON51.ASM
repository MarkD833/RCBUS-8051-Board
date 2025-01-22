*
* 8051 Monitor program
*
* Comamnds:
*	A <aa>		- Alter INTERNAL memory
*	  Sub commands:  xx	- Replace & advance
*			<BS>	- Backup to LAST
*			<SP>	- Advance to NEXT
*			<CR>	- Quit
*	B [bp address]	- Display/Set breakpoints
*	C <Reg> <value>	- Change register
*	D <aaaa>,[aaaa]	- Dump EXTERNAL DATA memory
*	E <aaaa>	- Edit EXTERNAL DATA memory
*	  Sub commands: Same as 'A'lter.
*	F <s>,<e> <d>	- Fill a block of memory
*	G <aaaa>	- Go (begin execution)
*	I <aa>,<aa>	- Dump INTERNAL memory
*	L		- Load program into memory
*	O <aa> <value>	- Output to SFR
*	Q <aa>		- Query SFR
*	R		- Display registers
*	S		- Single-Step one instruction
*	U <aaaa>,[aaaa] - Unassemble PROGRAM memory
*	?		- Display HELP summary
*
* Setup:
* The symbol ROM defines the location of the MON51 code in memory. This
* will normally be $0000, unless you are intending to run MON51 itself
* under another debugger or other operating environment.
*
* The symbol MONRAM defines a 80 byte area of memory which must be
* available for EXCLUSIVE use by MON51. This is often set to the highest
* RAM address in the system - 80.
*
* The symbol USERRAM defines the location in memory where user programs
* will be loaded. This controls the default user PC, as well re-vectoring
* the 8051 interrupts to corresponding offsets from this address. This is
* often set to the lowest available RAM address.
*
* When compiling or assembling programs to be tested under MON51, be sure
* to configure your tools such that the application code will be generated
* at the USERRAM address, and any external data areas will occur above the
* code, but below MONRAM.
*
* NOTE: In order to download and to set breakpoints, MON51 must be able to
* write to the USERRAM memory. This is normally accomplished by ANDing the
* -PSEN and -RD signals from the CPU to generate a single CODE/DATA select
* signal. If you wish to maintain separate CODE and DATA memory, you must add
* hardware to re-direct the DATA writes to the CODE memory at specific times
* (perhaps controlled via a I/O port pin). Look for comments beginning with
* '* ???' to identify places where the monitor must write to CODE memory.
*
* The symbol BAUD determines the "reload" value used for timer1 to
* establish the system baud rate. It is calculated with this formula:
*
*		BAUD = (crystal / baud rate) / 384
*
* For example, a system for which this monitor was will be used runs at
* 11.0592 Mhz, and uses a 9600 baud console connection:
*
*		BAUD = (11059200 / 9600) / 384
*
* This calculation shows that on this system, the correct BAUD value is 3.
* 
* If the above formula returns a fractional value, round it to the nearest
* integer, and determine that the actual baud rate that will be generated
* using this formula:
*
*		SPEED = (crystal / integer BAUD) / 384
*
* If the result is not within 5 percent of the desired value, that speed
* is unobtainable with the crystal frequency you are using. In general, the
* lower the SPEED required, the better chance you will have of obtaining it.
*
* ?COPY.TXT 1991-2007 Dave Dunfield
*  -- see COPY.TXT --.
*
* System parameters
ROM	EQU	$0000		Monitor program storage
MONRAM	EQU	$FFB0		MON51 reserved RAM (80 bytes)
USERRAM	EQU	$8000		USER/download RAM
BAUD	EQU	1		Baudrate divisor for TIMER1
* Symbols below this point do not normally have to be changed
MSSIZE	EQU	32		Amount of internal memory to save
NBREAK	EQU	4		Number of breakpoints
* Internal memory locations
	ORG	$0008
OUTFLAG	EQU	$7F
STACK	EQU	$07
* External (reserved) memory locations
	ORG	MONRAM
* Note: PCSAVE, SPSAVE and MRSAVE must occur together in this order
PCSAVE	DS	2		Program Counter save area
SPSAVE	DS	1		Stack Pointer save area
MRSAVE	DS	MSSIZE+5	Memory & Register save area
BRKTAB	DS	NBREAK*5	5 bytes/breakpoint
MBUFFER	DS	20		Temporary space
MRSIZE	EQU	*-MRSAVE	Size of monitor RAM
*
* Beginning of MON51 program code
*
	ORG	ROM		Code goes here
	LJMP	START		Skip interrupt vectors
* Re-vector interrupts
	ORG	ROM+$0003	EXT Interrupt 0
	LJMP	USERRAM+$3
	AJMP	WRCHR
	AJMP	WRSPC
	ORG	ROM+$000B	Timer 0 overflow
	LJMP	USERRAM+$B
	AJMP	WRLFCR
	AJMP	WRHEX
	ORG	ROM+$0013	EXT Interrupt 1
	LJMP	USERRAM+$13
	AJMP	WRDPTR
	AJMP	WRSTR
	ORG	ROM+$001B	Timer1 - Single step
	LJMP	SSINT
	AJMP	RDCHR
	AJMP	RDNIB
	ORG	ROM+$0023	RI+TI interrupt
	LJMP	USERRAM+$23
	AJMP	RDHEX
	AJMP	RDWORD
	ORG	ROM+$002B	TF2+EXF2
	LJMP	USERRAM+$2B
;
	AJMP	RDRANGE
	AJMP	RDADDR
	AJMP	CHKCHR
	AJMP	FLUSH
	AJMP	COMP
	AJMP	DLOAD
* Prompt for and execute commands
FPROMPT	ACALL	FLUSH		Clear out serial port
PROMPT	MOV	SP,#STACK	Set up stack
	MOV	OUTFLAG,#0	Clear output flag
	ACALL	WRLFCR		New line
	MOV	A,#'*'		Prompt character
	ACALL	WRCHR		Write it out
	ACALL	RDCHR		Read the command charecter
	MOV	R7,A		Save command for later
	ACALL	WRCHR		Echo it
	ACALL	WRSPC		Separator
*
* 'D'ump EXTERNAL memory command
*
DUMPO	CJNE	R7,#'D',DUMPI	No, try next
	ACALL	RDADDR		Get starting address
	ACALL	RDRANGE		Get ending address
* Display one line
DUMP1	ACALL	WRLFCR		New line
	ACALL	WRDPTR		Output address
	PUSH	DPH		Save high
	PUSH	DPL		Save low
	MOV	R7,#16		16 bytes/line
* Display the HEX dump
DUMP1A	MOV	A,R7		Get count
	ANL	A,#%00000011	Test lower two
	JNZ	DUMP1B		No extra space
	ACALL	WRSPC		Output a space
DUMP1B	ACALL	WRSPC		Output a space
	MOVX	A,[DPTR]	Get byte
	ACALL	WRHEX		Write in hex
	INC	DPTR		Advance to next
	DJNZ	R7,DUMP1A	Do em all
	ACALL	WRSPC		Output a spave
	ACALL	WRSPC		Another space
* Display the ASCII dump
	POP	DPL		Restore low
	POP	DPH		Restore high
	MOV	R7,#16		Length of line
	MOV	R3,#' '		Low bounds
	MOV	R4,#127		High bounds
DUMP1C	MOVX	A,[DPTR]	Get byte
	ACALL	COMP		Do the compare
	JNC	DUMP1D		OK to output
	MOV	A,#'.'		Convert to '.'
DUMP1D	ACALL	WRCHR		Write it out
	INC	DPTR		Next location
	DJNZ	R7,DUMP1C	Do them all
* Stop looking if we are over
	CLR	C		Insure no borrow
	MOV	A,R5		Get Low
	SUBB	A,DPL		Convert
	MOV	A,R6		Get high
	SUBB	A,DPH		Test it
	JNC	DUMP1		More to Go
* Return to the main command line
DUMP1E	AJMP	PROMPT		Back for more
* Report an error
ERROR1	MOV	A,#'?'		Error
	ACALL	WRCHR		Output
PROMPT1	AJMP	PROMPT		Next command
*
* 'I'internal memory dump
*
DUMPI	CJNE	R7,#'I',EDITE	No, try next
	ACALL	RDHEX		Get address
	JC	ERROR1		Invalid
	MOV	R0,A		Save in index
	MOV	A,#','		Separator
	ACALL	WRCHR		Output it
	ACALL	RDHEX		Get end
	JC	ERROR1		Invalid
	MOV	R4,A		Write it
* Display one line
DUMP2	ACALL	WRLFCR		New line
	MOV	A,R0		Get high byte
	ACALL	WRHEX		Output
	MOV	R5,#8		Size of line
	ACALL	WRSPC		Output a space
* Display the HEX dump
DUMP2A	ACALL	WRSPC		Output a space
	ACALL	RDINTM		Read internal memory
	ACALL	WRHEX		Write in hex
	MOV	A,R0		Get address
	CLR	C		Insure no borrow
	SUBB	A,R4		Calculate remaining
	JNC	DUMP1E		We are all done
	INC	R0		Advance to next
	DJNZ	R5,DUMP2A	Do em all
	SJMP	DUMP2		New line
*
* 'E'dit external memory
*
EDITE	CJNE	R7,#'E',EDITI	No, try edit internl
	ACALL	RDADDR		Get a HEX value
EDIT1	ACALL	WRLFCR		New line
	ACALL	WRDPTR		Output address
	ACALL	WRSPC		Output seperator
	MOVX	A,[DPTR]	Get value
	ACALL	WRHEX		Output
	MOV	A,#'-'		Prompt
	ACALL	WRCHR		Output
	ACALL	RDHEX		Get value
	JC	EDIT1B		Error
	MOVX	[DPTR],A	Write it
EDIT1A	INC	DPTR		Advance to next
	SJMP	EDIT1		And proceed
EDIT1B	JZ	EDIT1A		Space, advance
	DEC	A		Test for next
	JNZ	PROMPT1		And continue
	DEC	DPL		Reduce low
	MOV	A,DPL		Get value
	CJNE	A,#$FF,EDIT1	No overflow
	DEC	DPH		Backspace
	SJMP	EDIT1		And proceed
*
* 'A'lter internal memory
*
EDITI	CJNE	R7,#'A',LOAD	No, try next
	ACALL	RDHEX		Get a HEX value
	JC	ERROR1		Invalid
	MOV	R0,A		Save address
EDIT2	ACALL	WRLFCR		New line
	MOV	A,R0		Get address
	ACALL	WRHEX		Output address
	ACALL	WRSPC		Output seperator
	ACALL	RDINTM		Read internal memory
	ACALL	WRHEX		Output
	MOV	A,#'-'		Prompt
	ACALL	WRCHR		Output
	ACALL	RDHEX		Get value
	JC	EDIT2B		Error
	ACALL	WRINTM		Write internal memory
EDIT2A	INC	R0		Advance to next
	SJMP	EDIT2		And proceed
EDIT2B	JZ	EDIT2A		Space, advance
	DEC	A		Test for next
	JNZ	PROMPT1		And continue
	DEC	R0		Backspace
	SJMP	EDIT2		And proceed
*
* Load an image from the serial port
*
LOAD	CJNE	R7,#'L',GOCMD	No, try next
	ACALL	WRLFCR		New line
	CLR	A		Get zero
	MOV	R1,A		Zero LOW
	MOV	R2,A		Zero HIGH
LOAD1	ACALL	DLOAD		Get a record
	JNC	LOAD1		And keep getting em
	MOV	A,R2		Get HIGH
	ACALL	WRHEX		Output
	MOV	A,R1		Get LOW
	ACALL	WRHEX		Output
	MOV	DPTR,#M_BYTES	Point to ' Bytes' message
	ACALL	WRSTR		Output string
	AJMP	FPROMPT		End of the line
*
* Go (begin execution) at the specified address)
*
GOCMD	CJNE	R7,#'G',STEP	No, try next
	ACALL	GETPC		Get address
	MOV	DPTR,#PCSAVE	Point to PC save area
	MOVX	A,[DPTR]	Get HIGH PC
	MOV	R2,A		Save for later
	INC	DPTR		Advance
	MOVX	A,[DPTR]	Get LOW PC
	MOV	R1,A		Save for later
	ACALL	TESTBRK		Check for breakpoint conflict
	ACALL	WRLFCR		New line
* Insert breakpoints in user code
	MOV	DPTR,#BRKTAB	Point to breakpoint table
	MOV	R0,#0		Zero counter
GOC1	MOVX	A,[DPTR]	Get HIGH address
	MOV	R4,A		Save for later
	INC	DPTR		Advance
	MOVX	A,[DPTR]	Get LOW address
	MOV	R3,A		Save for later
	INC	DPTR		Advance
	ORL	A,R4		Breakpoint set?
	JZ	GOC2		No, skip it
	ACALL	SDP43		R4:3 <> DPTR
	MOV	R7,#$12		LCALL Instruction
	ACALL	PATCHBP		Patch breakpoint
	MOV	R7,#=BREAKPT	HIGH address
	ACALL	PATCHBP		Patch breakpoint
	MOV	R7,#BREAKPT	LOW address
	ACALL	PATCHBP		Patch breakpoint
	ACALL	SDP43		Swap back
	SJMP	GOC3		And proceed
GOC2	INC	DPTR		Skip 1
	INC	DPTR		Skip 2
	INC	DPTR		Skip 3
GOC3	INC	R0		Skip 4
	CJNE	R0,#NBREAK,GOC1
* Restore the user registers & execute at user PC
	MOV	DPTR,#MRSAVE+6	Point to memory save area
	MOV	R0,#1		Start at location1
GOC4	MOVX	A,[DPTR]	Get value
	MOV	[R0],A		Save in memory
	INC	DPTR		Advance to next
	INC	R0		Advance pointer
	CJNE	R0,#MSSIZE,GOC4	Do them all
* Restore users STACK pointer
	MOV	DPTR,#SPSAVE	Point to SP save area
	MOVX	A,[DPTR]	Restore
	MOV	SP,A		Set User SP
* Restore users program counter
	MOV	DPTR,#PCSAVE	Point to save area
	MOVX	A,[DPTR]	Get HIGH pc
	MOV	B,A		Save for later
	INC	DPTR		Advance
	MOVX	A,[DPTR]	Get LOW pc
	PUSH	A		Save LOW
	PUSH	B		Save HIGH
* Restore users registers
	MOV	DPTR,#MRSAVE	Point to memory save area
	MOVX	A,[DPTR]	Restore 'A'
	PUSH	A
	INC	DPTR
	MOVX	A,[DPTR]	Restore 'B'
	MOV	B,A
	INC	DPTR
	MOVX	A,[DPTR]	Restore PSW
	MOV	PSW,A
	INC	DPTR
	MOVX	A,[DPTR]	Restore DPH
	PUSH	A
	INC	DPTR
	MOVX	A,[DPTR]	Restore DPL
	PUSH	A
	INC	DPTR
	MOVX	A,[DPTR]	Restore R0
	MOV	0,A		Restore memory
	POP	DPL		Restore DPL
	POP	DPH		Restore DPH
	POP	A		Restore ACC
	RET			Dispatch to user program
* Patch user program with breakpoint
PATCHBP	CLR	A		Zero offset
	MOVC	A,[A+DPTR]	Get byte of code
	ACALL	WR43		Write to table
	MOV	A,R7		LCALL Instruction
* ??? Write to code memory
	MOVX	[DPTR],A	Patch code
	INC	DPTR		Skip to next
	RET
*
* Single step one instruction
*
STEP	CJNE	R7,#'S',RDUMP	No, try next
	MOV	DPTR,#PCSAVE	Point to saved PC
	MOVX	A,[DPTR]	Get HIGH
	INC	DPTR		Advance
	MOV	R2,A		Save
	MOVX	A,[DPTR]	Get LOW
	MOV	R1,A		Save
	ACALL	DODISS		Display on screen
	ACALL	FLUSH		Wait for TX complete
* Setup timer-1 for single step interrupt
	CLR	TCON.6		Stop timer1
	MOV	A,TMOD		Get timer mode
	ANL	A,#%00001111	Zero timer1 mode
	ORL	A,#%00010000	Timer1 16 bit
	MOV	TMOD,A		Resave new timer mode
	MOV	TH1,#$FF	-1
	MOV	TL1,#$FE	-2
	CLR	TCON.7		Clear timer1 int pend
* Restore the user register memory
	MOV	DPTR,#MRSAVE+6	Point to memory save area
	MOV	R0,#1		Start at location1
STEP1	MOVX	A,[DPTR]	Get value
	MOV	[R0],A		Save in memory
	INC	DPTR		Advance to next
	INC	R0		Advance pointer
	CJNE	R0,#MSSIZE,STEP1 Do them all
* Restore users STACK pointer
	MOV	DPTR,#SPSAVE	Point to SP save area
	MOVX	A,[DPTR]	Restore
	MOV	SP,A		Set User SP
* Restore users program counter
	MOV	DPTR,#PCSAVE	Point to save area
	MOVX	A,[DPTR]	Get HIGH pc
	MOV	B,A		Save for later
	INC	DPTR		Advance
	MOVX	A,[DPTR]	Get LOW pc
	PUSH	A		Save LOW
	PUSH	B		Save HIGH
* Restore users registers
	MOV	DPTR,#MRSAVE	Point to memory save area
	MOVX	A,[DPTR]	Restore 'A'
	PUSH	A
	INC	DPTR
	MOVX	A,[DPTR]	Restore 'B'
	MOV	B,A
	INC	DPTR
	MOVX	A,[DPTR]	Restore PSW
	MOV	PSW,A
	INC	DPTR
	MOVX	A,[DPTR]	Restore DPH
	PUSH	A
	INC	DPTR
	MOVX	A,[DPTR]	Restore DPL
	PUSH	A
	INC	DPTR
	MOVX	A,[DPTR]	Restore R0
	MOV	0,A		Restore memory
	POP	DPL		Restore DPL
	POP	DPH		Restore DPH
	POP	A		Restore ACC
* Activate the timer
	ORL	IE,#%10001000	Enable Timer1 interrupt
	SETB	TCON.6		Enable timer1
	RET			Execute user program
*
* Dump user registers
*
RDUMP	CJNE	R7,#'R',CHREG	No, try next
	MOV	DPTR,#MRSAVE+2	Point to user PSW
	MOVX	A,[DPTR]	Get user PSW
	MOV	R6,A		Save for later
	MOV	DPTR,#RNTABLE	Point to register names
	MOV	R0,#0		Zero offset
* Display next register from bank
RDUMP1	ACALL	WRSTR		Output value
	PUSH	DPH		Save HIGH
	PUSH	DPL		Save LOW
	MOV	DPH,#=PCSAVE	Point to memory buffer
	MOV	A,#PCSAVE	Point to low
	ADD	A,R0		Include offset
	INC	R0		Advance offset
	MOV	DPL,A		Save low value
	MOVX	A,[DPTR]	Get value
	POP	DPL		Restore LOW
	POP	DPH		Restore HIGH
	ACALL	WRHEX		Output value
* Test for second line... = Registers
	CLR	A		Zero offset
	MOVC	A,[A+DPTR]	More data?
	CJNE	A,#$0A,RDUMP2	Not special case
	MOV	A,R6		Get user PSW
	ANL	A,#%00011000	Save only rbank
	ADD	A,R0		Offset to bank
	MOV	R0,A		Resave
RDUMP2	JNB	A.7,RDUMP1	Yes, output
	AJMP	PROMPT		Next command
*
* Change user register
*
CHREG	CJNE	R7,#'C',FILL	Change resgister?
	ACALL	RDCHR		Get register name
	MOV	R7,A		Save for later
	ACALL	WRCHR		Echo it
	ACALL	WRSPC		Output
	MOV	DPTR,#PCSAVE	Point to table
	CJNE	R7,#'P',*+5	PC?
	SJMP	CHRE2		Save two bytes
	INC	DPTR
	INC	DPTR
	CJNE	R7,#'S',*+5	SP?
	SJMP	CHRE1		Save one byte
	INC	DPTR
	CJNE	R7,#'A',*+5	ACC?
	SJMP	CHRE1		Save one byte
	INC	DPTR
	CJNE	R7,#'B',*+5	B?
	SJMP	CHRE1		Save one byte
	INC	DPTR
	MOVX	A,[DPTR]	Get PSW
	ANL	A,#%00011000	Save Register bits
	MOV	R6,A		Save PSW
	CJNE	R7,#'W',*+5	PSW?
	SJMP	CHRE1		Save one byte
	INC	DPTR
	CJNE	R7,#'D',CHRE4	DPTR?
* Write a 16 bit register value
CHRE2	ACALL	RDWORD		Get WORD
	JC	ERROR2		Error
	XCH	A,B		Get High
	MOVX	[DPTR],A	Write to memory
	INC	DPTR		Advance
	MOV	A,B		Get second byte
CHRE3	MOVX	[DPTR],A	Save
	AJMP	PROMPT
* Set R0-R7 in current register bank
CHRE4	MOV	A,R7		Get char back
	MOV	R3,#'0'		Low bound
	MOV	R4,#'7'+1	High bound
	ACALL	COMP		In range?
	JC	ERROR2		No, report error
	SUBB	A,#'0'		Convert to binary
	ORL	A,R6		Offset to bank
	ADD	A,#MRSAVE+5	Point to registers
	MOV	DPL,A		Set up DPL
* Write an 8 bit register value
CHRE1	ACALL	RDHEX		Get BYTE
	JNC	CHRE3		Ok to write
* Not a recognized command
ERROR2	AJMP	ERROR1		Report error
*
* Fill memory
*
FILL	CJNE	R7,#'F',UNASS	Fill?
	ACALL	RDADDR		Get address
	ACALL	RDRANGE		Get range
	ACALL	WRSPC		Output space
	ACALL	RDHEX		Get byte value
	JC	ERROR2		Report error
	MOV	R7,A		Save data
FILL1	MOV	A,R7		Get byte
	MOVX	[DPTR],A	Write to data
	INC	DPTR		Advance to next
	CLR	C		Insure no borrow
	MOV	A,R5		Get Low
	SUBB	A,DPL		Convert
	MOV	A,R6		Get high
	SUBB	A,DPH		Test it
	JNC	FILL1		More to Go
	AJMP	PROMPT		Next command
*
* Un-assemble memory
*
UNASS	CJNE	R7,#'U',BRKPT	No, try next
	ACALL	RDADDR		Get address
	MOV	R2,DPH		Set high byte
	MOV	R1,DPL		Set low byte
	ACALL	RDRANGE		Get ending address
UNASS1	ACALL	WRLFCR		New line
	ACALL	DODISS		Output text
	CLR	C		Insure no borrow
	MOV	A,R5		Get Low
	SUBB	A,R1		Convert
	MOV	A,R6		Get high
	SUBB	A,R2		Test it
	JNC	UNASS1		More to Go
	AJMP	PROMPT		Back for more
*
* Examine/Change breakpoints
*
BRKPT	CJNE	R7,#'B',QUERY	Breakpoint?
	ACALL	RDCHR		Get character
	CJNE	A,#' ',BRKPT2	Set breakpoint
* Display the breakpoints
	MOV	DPTR,#BRKTAB	Point to table
	MOV	R7,#0		Count
BRKPT1	MOV	A,#'B'		Get 'B'
	ACALL	WRCHR		Output
	MOV	A,R7		Get number
	ADD	A,#'0'		Convert to ASCII
	ACALL	WRCHR		Output
	MOV	A,#'='		Seperator
	ACALL	WRCHR		Output
	MOVX	A,[DPTR]	Get address
	INC	DPTR		Skip to next
	ACALL	WRHEX		Output
	MOVX	A,[DPTR]	Get next address
	INC	DPTR		Skip to next
	ACALL	WRHEX		Output
	INC	DPTR		Skip opcode
	INC	DPTR		""
	INC	DPTR		""
	ACALL	WRSPC		Space over
	INC	R7		Advance count
	CJNE	R7,#NBREAK,BRKPT1 Show them all
	AJMP	PROMPT
* Set a breakpoint
BRKPT2	MOV	R3,#'0'		Lower limit
	MOV	R4,#'0'+NBREAK	Upper limit
	ACALL	COMP		In range?
	JC	ERROR2		Error
	ACALL	WRCHR		Echo it
	CLR	C		Zero carry
	SUBB	A,#'0'		Convert to binary
	MOV	R6,A		Copy
	ACALL	WRSPC		Space over
	ACALL	RDWORD		Get word
	JC	ERROR2		Report error
	PUSH	A		Save for later
	PUSH	B		Save for later
	MOV	R2,B		Set HIGH
	MOV	R1,A		Set LOW
	ACALL	TESTBRK		Check for conflicts
	XCH	A,R1		Get value
	ADD	A,#2		Adjust for new break
	XCH	A,R1
	XCH	A,R2
	ADDC	A,#0
	XCH	A,R2
	ACALL	TESTBRK		Check again
	MOV	A,R6		Get 
	RL	A		X2
	RL	A		X4
	ANL	A,#%11111100	Mask wrap
	ADD	A,R6		X5
	ADD	A,#BRKTAB	Point to breakpoint table
	MOV	DPL,A		Set LOW address
	MOV	DPH,#=BRKTAB	Set HIGH address
	POP	A		Restore HIGH
	MOVX	[DPTR],A	Set HIGH
	INC	DPTR		Advance
	POP	A		Restore LOW
	MOVX	[DPTR],A	Set LOW
	AJMP	PROMPT
*
* Query SFR register
*
QUERY	CJNE	R7,#'Q',OUTPUT	Query?
	ACALL	GETSFR		Get SFR address
	MOV	R0,#$E5		Indicate reading (MOV A,d)
	ACALL	DOXSUB		Read the data
	ACALL	WRHEX		And display the value
	AJMP	PROMPT
* Get SFR address and display
GETSFR	ACALL	RDHEX		Get address
	MOV	R1,A		Save address
	MOV	R4,#=MBUFFER	Point to buffer
	MOV	R3,#MBUFFER	Point
	ACALL	DIRECT		Get value
	CLR	A		Get zero
	ACALL	WR43		Zero terminate
	ACALL	WRSPC		Space over
	MOV	DPTR,#MBUFFER	Point to buffer
	ACALL	WRSTR		Output
	MOV	A,#'='		Indicator
	AJMP	WRCHR		Output
*
* Write and SFR register
*
OUTPUT	CJNE	R7,#'O',XLOOP	Output request
	ACALL	GETSFR		Get address
	ACALL	RDHEX		Get data
	MOV	R2,A		Save data
	MOV	R0,#$F5		Indicate writing (MOV d,A)
	ACALL	DOXSUB		Write the data
	AJMP	PROMPT
* ??? Build subroutine in code memory to Read/Write SFR
* ??? Entry: R0 = $E5/$F5 R1=Address R2=Data(write only)
DOXSUB:
	MOV	DPTR,#MBUFFER	Point to buffer
	MOV	A,R0		Get prefix
	MOVX	[DPTR],A	Write it
	INC	DPTR		Advance to next
	MOV	A,R1		Get address
	MOVX	[DPTR],A	Write it
	INC	DPTR		Advance to next
	MOV	A,#$22		'RET' instruction
	MOVX	[DPTR],A	Write it
	MOV	A,R2		Get value
	LJMP	MBUFFER		Execute subroutine
*
* LOOP commands
*
XLOOP	CJNE	R7,#'X',WRITE	No, try next
	ACALL	RDCHR		Read the command charecter
	MOV	R7,A		Save command for later
	ACALL	WRCHR		Echo it
	ACALL	WRSPC		Seperator
	CJNE	R7,#'R',XLW
	ACALL	RDADDR		Read address
XLR1	MOVX	A,[DPTR]	Read value
	ACALL	CHKCHR		Check for character
	CJNE	A,#$1B,XLR1	Do all
	AJMP	PROMPT
XLW	CJNE	R7,#'W',XLC
	ACALL	RDADDR		Get address
	ACALL	WRSPC		Space over
	ACALL	RDHEX		Get data
XLW1	MOVX	[DPTR],A	Write value
	ACALL	CHKCHR		Check for character
	CJNE	A,#$1B,XLW1	Do all
	AJMP	PROMPT
XLC	CJNE	R7,#'C',ERROR3
	ACALL	RDADDR		Get address
XLC1	CLR	A		Zero offset
	MOVC	A,[A+DPTR]	Read it
	ACALL	CHKCHR		Character?
	CJNE	A,#$1B,XLC1	Do all
	AJMP	PROMPT
*
* Single write to memory
*
WRITE	CJNE	R7,#'W',help
	LCALL	RDADDR		Get a HEX value
	LCALL	WRSPC
	LCALL	RDHEX
	JC	error3
	MOVX	[DPTR],A
	LJMP	PROMPT
ERROR3	AJMP	ERROR1
*
* Help request
*
HELP	CJNE	R7,#'?',ERROR3	Help?
	MOV	DPTR,#HTEXT	Point to help text
HELP1	ACALL	WRLFCR		New line
	MOV	R7,#25		Width of screen
HELP2	CLR	A		Zero offset
	MOVC	A,[A+DPTR]	Get char
	INC	DPTR		Advance
	JZ	HELP4		No suffix
	CJNE	A,#'|',HELP5	Normal char
HELP3	ACALL	WRSPC		Output a space
	DJNZ	R7,HELP3	And proceed
	MOV	A,#'-'		Seperator
	ACALL	WRCHR		Output
	ACALL	WRSPC		Another space
	ACALL	WRSTR		Output rest of
HELP4	MOVC	A,[A+DPTR]	Get char (A already zero)
	JNZ	HELP1		Do all lines
	AJMP	PROMPT		Next command
HELP5	ACALL	WRCHR		Echo character
	DEC	R7		Reduce count
	SJMP	HELP2		Handle next
WGO	LJMP	WRITE
*
* Get PC value... SP = current
*
GETPC	ACALL	RDWORD		Get value
	JC	GETP1		Its OK
	MOV	DPTR,#PCSAVE	Get value
	XCH	A,B		A = high
	MOVX	[DPTR],A	Write HIGH
	INC	DPTR		Advance
	MOV	A,B		Get LOW
	MOVX	[DPTR],A	Set it
	RET
GETP1	JNZ	ERROR3		Not space
	MOV	DPTR,#M_PC	Point to '->' message
	ACALL	WRSTR		Output
	MOV	DPTR,#PCSAVE	Point to it
	ACALL	GETP2		Output first byte
GETP2	MOVX	A,[DPTR]	Get value
	INC	DPTR		Advance
	AJMP	WRHEX		And proceed
*
* Read an address, abort on error
*
RDADDR	ACALL	RDHEX		Read high byte
	JC	ERROR3		Report error
	MOV	DPH,A		Set DPH
	ACALL	RDHEX		Read low byte
	JC	ERROR3		Report error
	MOV	DPL,A		Set DPL
	RET
*
* Read closing portion of range
*
RDRANGE	MOV	A,#','		Seperator
	ACALL	WRCHR		Output
	ACALL	RDWORD		Get byte
	MOV	R5,A		Save LOW
	MOV	R6,B		Save HIGH
	JNC	RET1		Its OK
	JNZ	ERROR3		Report error
	MOV	A,#$FF		Get FF
	MOV	R5,A		Assume END
	MOV	R6,A		Assume END
	ACALL	WRHEX		Output
	MOV	A,R5		Get FF back
	SJMP	WRHEX		Output
*
* Write the value of DPTR in hex
*
WRDPTR	MOV	A,DPH		Get high
	ACALL	WRHEX		Output if
	MOV	A,DPL		Get low
*
* Write byte in A to the serial port in HEX
*
WRHEX	PUSH	A		Save value
	SWAP	A		Get high nibble
	ACALL	WRHEX1		Output it
	POP	A		Get low nibble
WRHEX1	ANL	A,#%00001111	Use low digit only
	ADD	A,#'0'		Convert to ASCII
	CJNE	A,#'0'+10,*+3	Non-Destructive compare
	JC	WRCHR		A = 0-9
	ADD	A,#7		Convert HEX digits
	SJMP	WRCHR		And write the character
*
* Write the string (DPTR) to the serial port
*
WRSTR	CLR	A		Zero offset
	MOVC	A,[A+DPTR]	Get character (From ROM)
	INC	DPTR		Advance to next
	JZ	RET1		End of string
	ACALL	WRCHR		Write it out
	SJMP	WRSTR		And go again
*
* Write a newline (LFCR) to the serial port
*
WRLFCR	ACALL	CHKCHR		Any characters received?
	CJNE	A,#$1B,WRLFCR1	Escape?
	AJMP	PROMPT		Yes, abort command
WRLFCR1	CJNE	A,#' ',WRLFCR2	Halt output
	MOV	A,OUTFLAG	Get output flag
	JB	A.7,WRLFCR4	Already set
	ORL	OUTFLAG,#$80	Set flag
	SJMP	WRLFCR		And proceed
WRLFCR2	CJNE	A,#$0D,WRLFCR3	No, wait for it
	ANL	OUTFLAG,#$7F	Clear flag
WRLFCR3	MOV	A,OUTFLAG	Get output flag
	JB	A.7,WRLFCR	Inhibited
WRLFCR4	MOV	A,#'J'-$40	Get LINE-FEED
	ACALL	WRCHR		Output it
	MOV	A,#'M'-$40	Get CARRIAGE RETURN
	SJMP	WRCHR		And output it
*
* Write a space to the serial port
*
WRSPC	MOV	A,#' '		Get a space
*
* Write a character to the serial port
*
WRCHR	JNB	SCON.1,*	Wait for the bit
	CLR	SCON.1		Indicte we are sending
	MOV	SBUF,A		Write out char
RET1	RET
*
* Read a word into B:A from the serial port
*
RDWORD	ACALL	RDHEX		Get a byte
	JC	RET1		Error, exit
	MOV	B,A		Save high byte
*
* Read a byte from the serial port
*
RDHEX	ACALL	RDNIB		Read a nibble
	JC	RET1		Error, exit
	SWAP	A		Get in high nibble
	MOV	R7,A		Save for later
	ACALL	RDNIB		Read next nibble
	JC	RET1		Error, exit
	ORL	A,R7		Include high nibble
	RET
*
* Read a nibble in HEX from the serial port
*
RDNIB	ACALL	RDCHR		Get character
* Handle numeric digits '0'-'9'
	MOV	R3,#'0'		Lower bound
	MOV	R4,#'9'+1	Higher bound
	ACALL	COMP		Do the compare
	JC	RDNIB1		Failed
	ACALL	WRCHR		Echo it
	SUBB	A,#'0'		Convert
	RET
* Handle HEX digits 'A'-'F'
RDNIB1	MOV	R3,#'A'		Lower bound
	MOV	R4,#'F'+1	Higher bound
	ACALL	COMP		Do the compare
	JC	RDNIB2		Report error
	ACALL	WRCHR		Echo the character
	SUBB	A,#'0'+7	Convert
	RET
* Not valid, return with ERROR only if SPACE or CR
RDNIB2	CJNE	A,#' ',RDNIB3	Not space, continue
	CLR	A		Zero = space
	SETB	C		Indicate special condtion
	RET
RDNIB3	CJNE	A,#$08,RDNIB4	Not BS, continue
	MOV	A,#1		One = Backspace
	SETB	C		Indicate special condition
	RET
RDNIB4	CJNE	A,#$0D,RDNIB	Not CR, continue
	MOV	A,#2		Two = Carriage return
RDNIB5	SETB	C		Indicate special condition
	RET
*
* Read a character from the serial port
*
RDCHR	JNB	SCON.0,*	Wait for the bit
	CLR	SCON.0		Indicate we receved it
	MOV	A,SBUF		Read the data
* Convert the data to upper case
	PUSH	A		Save original
	ADD	A,#-'a'		First test
	JNC	RDCHR1		< 'a', leave alone
	SUBB	A,#25		Second test
	JNC	RDCHR1		> 'z', leave alone
	POP	A		Restore char
	SUBB	A,#$1F		Convert to UPPER
	RET
RDCHR1	POP	A		Restore
	RET
*
* Check for a character received
*
CHKCHR	CLR	A		Assume zero
	JNB	SCON.0,CHKC1	No data, return
	CLR	SCON.0		Indicate we received it
	MOV	A,SBUF		Read the data
CHKC1	RET
*
* Flush the serial port (Wait till all chars received/sent)
*
FLUSH	MOV	R7,#0		Delay count
FLUSH1	ACALL	CHKCHR		Any data?
	JNZ	FLUSH		Reset the timer
	JNB	SCON.1,FLUSH	Wait for TX complete
	DJNZ	R7,FLUSH1	Wait for expiry
	RET
*
* Read a byte without echo
*
DLBYTE	ACALL	DLNIB		Get first digit
	SWAP	A		Get in high digit
	MOV	R5,A		Save for later
	ACALL	DLNIB		Get low digit
	ORL	A,R5		Include high
	RET
*
* Read a nibble without echo
*
DLNIB	ACALL	RDCHR		Read a character
	MOV	R3,#'0'		Lower bound
	MOV	R4,#'9'+1	Upper bound
	ACALL	COMP		Perform the compare
	JNC	DLNIB1		Invalid
	MOV	R3,#'A'		Lower bound
	MOV	R4,#'F'+1	Upper bound
	ACALL	COMP		Perform the compare
	JC	DLERR		Report error
	SUBB	A,#7		Convert HEX
DLNIB1	SUBB	A,#'0'		Convert NUMBERS
	RET
*
* Read a MHX record from the serial port
*
DLOAD	ACALL	RDCHR		Read a character
	CJNE	A,#'S',DLINT	Try intel record
* Download a MOTOROLA HEX format record
DLMOT	ACALL	RDCHR		Read another char
	CLR	C		No borrow in
	SUBB	A,#'0'		Header record
	JZ	DLOAD		Yes, ignore it
	DEC	A		Type 1 (data record)
	JZ	DLMOT1		Yes, grab it
	SUBB	A,#8		Type 9 (EOF)
DLEOF	JZ	RDNIB5		Yes end of file (Set C)
* Error in download
DLERR	MOV	DPTR,#M_LOAD	Point to '?Load error' message
	ACALL	WRSTR		Output
	AJMP	FPROMPT		And continue
DLMOT1	ACALL	DLBYTE		Get length
	MOV	R6,A		Start checksum
	ADD	A,#-3		Convert to actual length
	MOV	R7,A		Save length
	ADD	A,R1		Add to LOW length
	MOV	R1,A		Save
	MOV	A,R2		Get HIGH length
	ADDC	A,#0		Adjust for carry
	MOV	R2,A		Resave
	ACALL	DLBYTE		Get byte of address
	MOV	DPH,A		Save high
	ADD	A,R6		Include in checksum
	MOV	R6,A		Resave checksum
	ACALL	DLBYTE		Get low byte of address
	MOV	DPL,A		Save low
	ADD	A,R6		Include in checksum
	MOV	R6,A		And re-save
DLMOT2	ACALL	DLBYTE		Get a byte
* ??? Write to code memory
	MOVX	[DPTR],A	Write to memory
	INC	DPTR		Advance to next
	ADD	A,R6		Include in checksum
	MOV	R6,A		And re-save
	DJNZ	R7,DLMOT2	Do whole record
	ACALL	DLBYTE		Get checksum
	ADD	A,R6		Include calculated value
	INC	A		Convert
	JNZ	DLERR		Failed!
	CLR	C		Indicte RX OK
	RET
* Download an INTEL format record
DLINT	CJNE	A,#':',DLOAD	Not INTEL, ignore
	ACALL	DLBYTE		Get count
	MOV	R6,A		Start checksum
	MOV	R7,A		Record length
	JZ	DLEOF		End of file
	ADD	A,R1		Add LOW length
	MOV	R1,A		Resave
	MOV	A,R2		Get HIGH length
	ADDC	A,#0		Adjust for high
	MOV	R2,A		Resave
	ACALL	DLBYTE		Get HIGH address
	MOV	DPH,A		Set up DPTR
	ADD	A,R6		Include in checksum
	MOV	R6,A		Resave
	ACALL	DLBYTE		Get LOW address
	MOV	DPL,A		Set up DPTR
	ADD	A,R6		Include checksum
	MOV	R6,A		Resave
	ACALL	DLBYTE		Read RECORD type
	ADD	A,R6		Incldue in checksum
	MOV	R6,A		Resave
DLINT1	ACALL	DLBYTE		Read a data byte
* ??? Write to code memory
	MOVX	[DPTR],A	Write to memory
	INC	DPTR		Advance to next
	ADD	A,R6		Include in checksum
	MOV	R6,A		Resave
	DJNZ	R7,DLINT1	Do them all
	ACALL	DLBYTE		Get record checksum
	ADD	A,R6		Include in checksum
	JNZ	DLERR		Report error
	CLR	C		Indicate success
	RET
*
* Compare the ACCUMULATOR with R3&R4
* Sets the C flag if ACC <R3 or >=R4
*
COMP	PUSH	A		Save ACC
	CLR	C		Clear carry
	SUBB	A,R3		Test
	JC	COMP1		< R3, report no
	POP	A		Restore A
	PUSH	A		And re-stack
	SUBB	A,R4		Test
	CPL	C		C = A >= R4
COMP1	POP	A		Restore A
RET2	RET
*
* Disassemble to screen
*
DODISS	MOV	R4,#=MBUFFER	Get HIGH output address
	MOV	R3,#MBUFFER	Get LOW output address
	PUSH	2		Save HIGH output
	PUSH	1		Save LOW output
	ACALL	DISASS		Do dis-assembly
	POP	DPL		Get LOW
	POP	DPH		Get HIGH
	ACALL	WRDPTR		Output address
	MOV	R7,#5		Max # spaces
DODISS1	ACALL	WRSPC		Space over
	CLR	A		Zero OFFSET
	MOVC	A,[A+DPTR]	Get value
	INC	DPTR		Advance
	ACALL	WRHEX		Output
	DEC	R7		Reduce count
	MOV	A,R1		Get LOW
	CJNE	A,DPL,DODISS1	More...
	MOV	A,R2		Get HIGH
	CJNE	A,DPH,DODISS1	More...
DODISS2	ACALL	WRSPC		Space
	ACALL	WRSPC		Space
	ACALL	WRSPC		Space
	DJNZ	R7,DODISS2	Do them ALL
	MOV	DPTR,#MBUFFER	Point to buffer
DODISS3	MOVX	A,[DPTR]	Get character
	INC	DPTR		Advance
	JZ	RET2		Exit
	ACALL	WRCHR		Output char
	SJMP	DODISS3		Continue
*
* Disassemble opcode
* R2:1 = Input pointer, R4:3 = Output pointer R5:7 = Temp locs
DISASS	PUSH	DPH		Save DPH
	PUSH	DPL		Save DPL
	PUSH	5		Save R5
	PUSH	7		Save R7
	ACALL	LAR21Z		Read opcode
	MOV	DPTR,#OTABLE	Point to lookup table
	MOV	R5,A		Save for later
* Look for instruction in table
dis1	CLR	A		Zero offset
	MOVC	A,[A+DPTR]	Get value from table
	ANL	A,R5		Mask for variables
	MOV	B,A		Save for compare
	INC	DPTR		Advance to test
	CLR	A		Zero offset
	MOVC	A,[A+DPTR]	Get byte from table
	INC	DPTR		Advance
	CJNE	A,B,dis2	Not correct instruction
* This is the instruction
dis3	MOV	R7,#6		Counter
dis4	CLR	A		Zero offset
	MOVC	A,[A+DPTR]	Get byte to output
	INC	DPTR		Advance to next
	CJNE	A,#' ',dis5	Not space, its OK
dis41	ACALL	WR43		Output to string
	DJNZ	R7,dis41	Do them all
	SJMP	dis4		next byte
* Not it, try next
dis2	CLR	A		Zero offset
	MOVC	A,[A+DPTR]	Get byte
	INC	DPTR		Advance
	JNZ	dis2		No, keep looking
	SJMP	dis1		Go again
* Test for 'r'egister ID
dis5	CJNE	A,#'r',dis6	Register?
	MOV	A,#'R'		Stuff in 'R'
	ACALL	WR43		Output it
	MOV	A,R5		Get opcode back
dis51	ANL	A,#$07		Save 'R' bits
	ADD	A,#'0'		Convert to ASCII
	ACALL	WR43		Write it
	SJMP	dis4		And proceed
* Test for 'i'ndirect id
dis6	CJNE	A,#'i',dis7	Indirect?
	MOV	A,#'['		Opening brace
	ACALL	WR43		Output
	MOV	A,#'R'		Register indicator
	ACALL	WR43		Output
	MOV	A,R5		Get opcode
	ANL	A,#$01		Save ID
	ADD	A,#'0'		Convert to ASCII
	ACALL	WR43		Output
	MOV	A,#']'		Closing brace
	ACALL	WR43		Output
	SJMP	dis4		Save
* Test for 'm'emory reference
dis7	CJNE	A,#'m',dis8	Memory reference?
	MOV	A,#'#'		Indicate immediiate
	ACALL	WR43		Output
	ACALL	LAR21Z		Get value
	ACALL	WRHEXS		Output in hex
	SJMP	dis4		And proceed
* Test for 'x'tended address
dis8	CJNE	A,#'x',dis9	Xtended?
	ACALL	LAR21Z		Get value
	ACALL	WRHEXS		Output in hex
	ACALL	LAR21Z		Get value
	ACALL	WRHEXS		Output
	SJMP	dis4		And proceed
* Test for 'j' relative jump address
dis9	CJNE	A,#'j',dis10	Jump address?
	ACALL	LAR21Z		Get value
	ACALL	CBW		Sign extend
	ADD	A,R1		Add LOW
	XCH	A,B		B = low
	ADDC	A,R2		Add HIGH
dis91	ACALL	WRHEXS		Output HIGH
	MOV	A,B		Get LOW
	ACALL	WRHEXS		output
	SJMP	dis4		And proceed
* Test for 'a' absolute address
dis10	CJNE	A,#'a',dis11	ABS address?
	ACALL	LAR21Z		Get value
	PUSH	A		Save LOW
	MOV	A,R2		Get high address
	ANL	A,#$F8		Save high bits
	MOV	B,A		Save for later
	MOV	A,R5		Get opcode
	RR	A		Shift
	RR	A		To
	RR	A		Get
	RR	A		Insert
	RR	A		Bits
	ANL	A,#%00000111	Save only lower three
	ORL	A,B		Include extra bits
	POP	B		Restore LOW
	SJMP	dis91		Display
* Test for 'd' direct memory address
dis11	CJNE	A,#'d',dis12	Direct memory address?
	ACALL	LAR21Z		Get address
dis111	ACALL	DIRECT		display direct address
dis112	AJMP	dis4		And proceed
* Test for 'b' bit address
dis12	CJNE	A,#'b',dis13	No, try next
	ACALL	LAR21Z		Get value
	PUSH	A		Save for later
	ANL	A,#$F8		Remove bit position
	JB	A.7,dis121	Negative, its ok
	RR	A		Over
	RR	A		To low bit
	RR	A		address range
	ANL	A,#%00011111	Mask bits
	ADD	A,#$20		Convert
dis121	ACALL	DIRECT		Write address
	MOV	A,#'.'		Separator
	ACALL	WR43		write it
	POP	A		Restore
	AJMP	dis51		Write & return
* Test for 'e' - special direct
dis13	CJNE	A,#'e',dis14	Special direct?
	MOV	B,#0		High = 0
	MOV	A,#1		Offset = 1
	ACALL	LAR21		Get value
	SJMP	dis111		And proceed
* Test for 'f' - special direct
dis14	CJNE	A,#'f',dis15	Special direct?
	MOV	A,#-1		Offset -1
	MOV	B,#-1		Offset -1
	ACALL	LAR21		Get data
	SJMP	dis111		and prcoeed
* Normal data, output to buffer
dis15	ACALL	WR43		Output
	DEC	R7		Reduce count
	JNZ	dis112		Go till end
	POP	7		Restore R7
	POP	5		Restore R5
	POP	DPL		Restore DPL
	POP	DPH		Restore DPH
	RET
*
* Look up opcode in the direct memory access table
* Write to R4:3+
*
DIRECT	MOV	B,A		Save a copy
	PUSH	DPH		Save LOW
	PUSH	DPL		Save HIGH
	MOV	DPTR,#DTABLE	Point to table
dir1	CLR	A		Zero offset
	MOVC	A,[A+DPTR]	Get value
	INC	DPTR		Advance
	JZ	dir4		End of list
	JNB	A.7,dir1	Still in entry
	CJNE	A,B,dir1	This is not it
dir2	CLR	A		Zero offset
	MOVC	A,[A+DPTR]	Get data
	INC	DPTR		Advance to next
	JZ	dir3		End of list
	JB	A.7,dir3	End of list
	ACALL	WR43		Write to buffer
	SJMP	dir2		Do them all
dir3	POP	DPL		Restore LOW
	POP	DPH		Restore HIGH
	RET
dir4	POP	DPL		Restore LOW
	POP	DPH		Restore HIGH
	MOV	A,B		Get value back
*
* Write byte in AL to [R4:3+] in hex
*
WRHEXS	PUSH	A		Save for later
	RR	A		Shift high nibble
	RR	A		Into low nibble
	RR	A		For output
	RR	A		first
	ACALL	WRHEXS1		Output it
	POP	A		Restore LOW
WRHEXS1	ANL	A,#%00001111	Save only high digit
	ADD	A,#'0'		Convert to ASCII
	CJNE	A,#'0'+10,*+3	In range?
	JC	WR43		Yes, its OK
	ADD	A,#7		Convert alphas
* Write byte to [R4:3+]
WR43	ACALL	SDP43		Swap into DPTR
	MOVX	[DPTR],A	Write data
	INC	DPTR		Advance
SDP43	XCH	A,R4		Get R4
	XCH	A,DPH		Swap with DPH
	XCH	A,R4		Replace R4
	XCH	A,R3		Get R3
	XCH	A,DPL		Swap with DPH
	XCH	A,R3		Replace R3
	RET
* Load 0[R2:3+]
LAR21Z	CLR	A		Zero LOW
	MOV	B,A		Zero HIGH
* Load BA[R2:3+]
LAR21	PUSH	DPH		Save DPH
	PUSH	DPL		Save DPL
	ADD	A,R1		Get low value
	MOV	DPL,A		Resave
	MOV	A,R2		Get high
	ADDC	A,B		Adjust for overflow
	MOV	DPH,A		Resave
	CLR	A		Zero offset
	MOVC	A,[A+DPTR]	Load value
	POP	DPL		Restore DPL
	POP	DPH		Restore DPH
INC23	XCH	A,R1		Get LOW
	ADD	A,#1		Advance
	XCH	A,R1		Replace
	XCH	A,R2		Get HIGH
	ADDC	A,#0		Cary high
	XCH	A,R2		Replace
	RET
* Convert a byte to word
CBW	MOV	B,#0		Assume zero
	JNB	A.7,*+5		Its OK
	DEC	B		Convert to -1
	RET
*
* Read user internal memory [R0]
*
RDINTM	CJNE	R0,#MSSIZE,*+3	Non-destruction compare
	JC	RDINTM1		Special case
	MOV	A,[R0]		Read it
	RET
RDINTM1	PUSH	DPH		Save Data pointer
	PUSH	DPL
	MOV	DPH,#=MRSAVE	Point to high address
	MOV	A,#MRSAVE+5	Set up low address
	ADD	A,R0		Offset to desired location
	MOV	DPL,A		Set up low
	MOVX	A,[DPTR]	Read value
	POP	DPL
	POP	DPH
	RET
*
* Write user internal memory [R0]
*
WRINTM	CJNE	R0,#MSSIZE,*+3	Non-destruction compare
	JC	WRINTM1		Special case
	MOV	[R0],A		Write it
	RET
WRINTM1	PUSH	DPH		Save data pointer
	PUSH	DPL
	PUSH	A		Save value to write
	MOV	DPH,#=MRSAVE	Point to high address
	MOV	A,#MRSAVE+5	Set up low address
	ADD	A,R0		Offset to desired location
	MOV	DPL,A		Set up low
	POP	A		Get value to write
	MOVX	[DPTR],A	Write value
	POP	DPL
	POP	DPH
	RET
*
* Breakpoint has been encountered
*
BREAKPT	ACALL	SAVEREG		Save user registers
* Replace any breakpointed code
	MOV	DPTR,#BRKTAB	Point to breakpoint
	MOV	R0,#0		Set to zero
BREAK1	MOVX	A,[DPTR]	Get HIGH address
	INC	DPTR		Advance
	MOV	R4,A		Save
	MOVX	A,[DPTR]	Get LOW address
	INC	DPTR		Advance
	MOV	R3,A		Save
	ORL	A,R4		Is this one used?
	JZ	BREAK3		No, skip it
* Breakpoint... Replace user code
	MOV	R7,#3		Move three bytes
BREAK2	MOVX	A,[DPTR]	Get code byte
	INC	DPTR		Advance
* ??? Write to code memory
	ACALL	WR43		Write to code
	DJNZ	R7,BREAK2	Write it all
	SJMP	BREAK4		And proceed
* No breakpoint set... skip to next
BREAK3	INC	DPTR		Skip code
	INC	DPTR
	INC	DPTR
BREAK4	INC	R0		Advance code
	CJNE	R0,#NBREAK,BREAK1 Do them all
* Continue with breakpoint processing
	MOV	DPTR,#M_BREAK	Point to 'Break at ' message
	ACALL	WRSTR		Output
* Adjust PC by -3 to compensate for breakpoint return address
	MOV	DPTR,#PCSAVE	Point to PC save area
	MOVX	A,[DPTR]	Get HIGH value
	INC	DPTR		Advance
	MOV	B,A		B = HIGH
	MOVX	A,[DPTR]	Get LOW value
	CLR	C		Zero carry
	SUBB	A,#3		Backup by 3
	XCH	A,B		Get HIGH
	SUBB	A,#0		Include carry
	MOV	DPTR,#PCSAVE	Point to PC save area
	MOVX	[DPTR],A	Write new HIGH
	ACALL	WRHEX		Output
	INC	DPTR		Advance
	MOV	A,B		Get LOW
	XCH	A,B		Get LOW
	MOVX	[DPTR],A	Write new LOW
	ACALL	WRHEX		Output
	AJMP	PROMPT
*
* Test for see if breakpoint conflict at address R2:1
*
TESTBRK	MOV	DPTR,#BRKTAB	Point to breakpoint table
	MOV	R0,#0		Init count
TSTBR1	MOVX	A,[DPTR]	Get HIGH value
	INC	DPTR		Advance
	MOV	R4,A		Save HIGH
	MOVX	A,[DPTR]	Get LOW value
	INC	DPTR		Advance
	MOV	R3,A		Continue
	INC	DPTR		Skip
	INC	DPTR		Code
	INC	DPTR		Bytes
	ORL	A,R4		Breakpoint set?
	JZ	TSTBR3		No, skip it
	MOV	R7,#3		Test three times
TSTBR2	CLR	C		Zero carry
	MOV	A,R1		Get LOW
	SUBB	A,R3		Do LOW
	MOV	B,A		Save for later
	MOV	A,R2		Get HIGH
	SUBB	A,R4		Do HIGH
	ORL	A,B		Same?
	JZ	TSTBR4		We found a collision
	MOV	A,R3		Get LOW BP address
	ADD	A,#1		Advance
	MOV	R3,A		Resave
	MOV	A,R4		Get HIGH BP address
	ADDC	A,#0		Include carry
	MOV	R4,A		Resave
	DJNZ	R7,TSTBR2	Keep going
TSTBR3	INC	R0		Advance count
	CJNE	R0,#NBREAK,TSTBR1 Do them all
	RET
TSTBR4	MOV	DPTR,#M_CONFL	Point to 'Breakpoint Conflict!' message
	ACALL	WRSTR		Output
	AJMP	PROMPT		Abort command
*
* Single step interrupt has been encounted
*
SSINT	CLR	IE.3		Disable timer-1 interrupt
	ACALL	SAVEREG		Save user registers
* Reset timer1 for baud rate generation
	MOV	A,TMOD		Get timer mode
	ANL	A,#%00001111	Zero timer1 mode
	ORL	A,#%00100000	T1 = 8 bit auto-reload
	MOV	TMOD,A		Resave new timer mode
	MOV	TH1,#-BAUD	Timer1 reload value
	MOV	TL1,#-BAUD	Timer1 initial value
	CLR	TCON.7		Clear timer1 int pend
	ACALL	IRET		Reset interrupt system
	AJMP	PROMPT		Re-enter monitor
IRET	RETI
*
* Save the user registers & switch to montor stack
*
SAVEREG	PUSH	DPL		Save DPTR
	PUSH	DPH		""
* Save A,B PSW & DPTR
	MOV	DPTR,#MRSAVE	Point to save area
	MOVX	[DPTR],A	Save ACC
	INC	DPTR
	MOV	A,B		Save 'B'
	MOVX	[DPTR],A
	INC	DPTR
	MOV	A,PSW		Save PSW
	MOVX	[DPTR],A
	INC	DPTR
	ANL	PSW,#%11100111	Insure RB=0
	POP	A		Save DPH
	MOVX	[DPTR],A
	INC	DPTR
	POP	A		Save DPL
	MOVX	[DPTR],A
* Save the return address so we can get back to monitor
	MOV	DPTR,#MBUFFER	Point to temp space
	POP	A		Get HIGH ret addr
	MOVX	[DPTR],A	Save it
	INC	DPTR		Advance
	POP	A		Get LOW ret addr
	MOVX	[DPTR],A	Save it
* Save R0-R7 + n bytes of stack space
	MOV	DPTR,#MRSAVE+5	Point to registers
	MOV	A,R0		Save R0
	MOVX	[DPTR],A
	INC	DPTR
	MOV	R0,#1		Point to R1
SAVER1	MOV	A,[R0]		Get data
	MOVX	[DPTR],A	Write to memory
	INC	DPTR		Advance pointer
	INC	R0		Next internal
	CJNE	R0,#MSSIZE,SAVER1 Do them all
* Save the users PC
	MOV	DPTR,#PCSAVE	Point to PC save area
	POP	A		Get HIGH pc
	MOVX	[DPTR],A	Save PC
	INC	DPTR		Advance
	POP	A		Get LOW PC
	MOVX	[DPTR],A	Advance
	INC	DPTR		Advance
* Save the users stack pointer
	MOV	A,SP		Get SP
	MOVX	[DPTR],A	Save for later
* Return to caller by jumping to original routine
	MOV	SP,#STACK	Reset to our stack pointer
	MOV	DPTR,#MBUFFER	Point to temporary location
	MOVX	A,[DPTR]	Get value
	MOV	B,A		Save for later
	INC	DPTR		Advance
	MOVX	A,[DPTR]	Get rest of value
	PUSH	A		Save for return
	PUSH	B		""
	RET			Back to caller
*
* Text Messages
*
M_BYTES	STRZ	' Bytes'
M_PC	STRZ	'->'
M_LOAD	STRZ	'?Load error'
M_BREAK	STRZ	'Break at '
M_CONFL	DB	$0A,$0D
	STRZ	'Breakpoint conflict!'
M_HELLO	DB	$0A,$0D
	STR	'MON51 Version 1.1'
	DB	$0A,$0D,$0A
	STR	'?COPY.TXT 1991-2007 Dave Dunfield'
	DB	$0A,$0D
	STR	' -- see COPY.TXT --.'
	DB	$0A,0
*
* Table of register names to output
*
RNTABLE	STRZ	'PC='
	STRZ	''
	STRZ	' SP='
	STRZ	' A='
	STRZ	' B='
	STRZ	' PSW='
	STRZ	' DPTR='
	STRZ	''
* Note 'RDUMP' keys on a leading $0A to detect register bank
	DB	$0A,$0D
	STRZ	'R0='
	STRZ	' R1='
	STRZ	' R2='
	STRZ	' R3='
	STRZ	' R4='
	STRZ	' R5='
	STRZ	' R6='
	STRZ	' R7='
	DB	$FF		End of list
*
* Dissassembly opcode table
*
OTABLE	DB	$1F,$11,'A','C','A','L','L',' ','a',0
	DB	$F8,$28,'A','D','D',' ','A',',','r',0
	DB	$FF,$25,'A','D','D',' ','A',',','d',0
	DB	$FE,$26,'A','D','D',' ','A',',','i',0
	DB	$FF,$24,'A','D','D',' ','A',',','m',0
	DB	$F8,$38,'A','D','D','C',' ','A',',','r',0
	DB	$FF,$35,'A','D','D','C',' ','A',',','d',0
	DB	$FE,$36,'A','D','D','C',' ','A',',','i',0
	DB	$FF,$34,'A','D','D','C',' ','A',',','m',0
	DB	$1F,$01,'A','J','M','P',' ','a',0
	DB	$F8,$58,'A','N','L',' ','A',',','r',0
	DB	$FF,$55,'A','N','L',' ','A',',','d',0
	DB	$FE,$56,'A','N','L',' ','A',',','i',0
	DB	$FF,$54,'A','N','L',' ','A',',','m',0
	DB	$FF,$52,'A','N','L',' ','d',',','A',0
	DB	$FF,$53,'A','N','L',' ','d',',','m',0
	DB	$FF,$82,'A','N','L',' ','C',',','b',0
	DB	$FF,$B0,'A','N','L',' ','C',',','/','b',0
	DB	$FF,$B5,'C','J','N','E',' ','A',',','d',',','j',0
	DB	$FF,$B4,'C','J','N','E',' ','A',',','m',',','j',0
	DB	$F8,$B8,'C','J','N','E',' ','r',',','m',',','j',0
	DB	$FE,$B6,'C','J','N','E',' ','i',',','m',',','j',0
	DB	$FF,$E4,'C','L','R',' ','A',0
	DB	$FF,$C3,'C','L','R',' ','C',0
	DB	$FF,$C2,'C','L','R',' ','b',0
	DB	$FF,$F4,'C','P','L',' ','A',0
	DB	$FF,$B3,'C','P','L',' ','C',0
	DB	$FF,$B2,'C','P','L',' ','b',0
	DB	$FF,$D4,'D','A',' ','A',0
	DB	$FF,$14,'D','E','C',' ','A',0
	DB	$F8,$18,'D','E','C',' ','r',0
	DB	$FF,$15,'D','E','C',' ','d',0
	DB	$FE,$16,'D','E','C',' ','i',0
	DB	$FF,$84,'D','I','V',' ','A','B',0
	DB	$F8,$D8,'D','J','N','Z',' ','r',',','j',0
	DB	$FF,$D5,'D','J','N','Z',' ','d',',','j',0
	DB	$FF,$04,'I','N','C',' ','A',0
	DB	$F8,$08,'I','N','C',' ','r',0
	DB	$FF,$05,'I','N','C',' ','d',0
	DB	$FE,$06,'I','N','C',' ','i',0
	DB	$FF,$A3,'I','N','C',' ','D','P','T','R',0
	DB	$FF,$20,'J','B',' ','b',',','j',0
	DB	$FF,$10,'J','B','C',' ','b',',','j',0
	DB	$FF,$40,'J','C',' ','j',0
	DB	$FF,$73,'J','M','P',' ','[','A','+','D','P','T','R',']',0
	DB	$FF,$30,'J','N','B',' ','b',',','j',0
	DB	$FF,$50,'J','N','C',' ','j',0
	DB	$FF,$70,'J','N','Z',' ','j',0
	DB	$FF,$60,'J','Z',' ','j',0
	DB	$FF,$12,'L','C','A','L','L',' ','x',0
	DB	$FF,$02,'L','J','M','P',' ','x',0
	DB	$F8,$E8,'M','O','V',' ','A',',','r',0
	DB	$FF,$E5,'M','O','V',' ','A',',','d',0
	DB	$FE,$E6,'M','O','V',' ','A',',','i',0
	DB	$FF,$74,'M','O','V',' ','A',',','m',0
	DB	$F8,$F8,'M','O','V',' ','r',',','A',0
	DB	$F8,$A8,'M','O','V',' ','r',',','d',0
	DB	$F8,$78,'M','O','V',' ','r',',','m',0
	DB	$FF,$F5,'M','O','V',' ','d',',','A',0
	DB	$F8,$88,'M','O','V',' ','d',',','r',0
	DB	$FF,$85,'M','O','V',' ','e',',','f',0
	DB	$FE,$86,'M','O','V',' ','d',',','i',0
	DB	$FF,$75,'M','O','V',' ','d',',','m',0
	DB	$FE,$F6,'M','O','V',' ','i',',','A',0
	DB	$FE,$A6,'M','O','V',' ','i',',','d',0
	DB	$FE,$76,'M','O','V',' ','i',',','m',0
	DB	$FF,$A2,'M','O','V',' ','C',',','b',0
	DB	$FF,$92,'M','O','V',' ','b',',','C',0
	DB	$FF,$90,'M','O','V',' ','D','P','T','R',',','#','x',0
	DB	$FF,$93,'M','O','V','C',' ','A',',','[','A','+','D','P','T','R',']',0
	DB	$FF,$83,'M','O','V','C',' ','A',',','[','A','+','P','C',']',0
	DB	$FE,$E2,'M','O','V','X',' ','A',',','i',0
	DB	$FF,$E0,'M','O','V','X',' ','A',',','[','D','P','T','R',']',0
	DB	$FE,$F2,'M','O','V','X',' ','i',',','A',0
	DB	$FF,$F0,'M','O','V','X',' ','[','D','P','T','R',']',',','A',0
	DB	$FF,$A4,'M','U','L',' ','A','B',0
	DB	$FF,$00,'N','O','P',0
	DB	$F8,$48,'O','R','L',' ','A',',','r',0
	DB	$FF,$45,'O','R','L',' ','A',',','d',0
	DB	$FE,$46,'O','R','L',' ','A',',','i',0
	DB	$FF,$44,'O','R','L',' ','A',',','m',0
	DB	$FF,$42,'O','R','L',' ','d',',','A',0
	DB	$FF,$43,'O','R','L',' ','d',',','m',0
	DB	$FF,$72,'O','R','L',' ','C',',','b',0
	DB	$FF,$A0,'O','R','L',' ','C',',','/','b',0
	DB	$FF,$D0,'P','O','P',' ','d',0
	DB	$FF,$C0,'P','U','S','H',' ','d',0
	DB	$FF,$22,'R','E','T',0
	DB	$FF,$32,'R','E','T','I',0
	DB	$FF,$23,'R','L',' ','A',0
	DB	$FF,$33,'R','L','C',' ','A',0
	DB	$FF,$03,'R','R',' ','A',0
	DB	$FF,$13,'R','R','C',' ','A',0
	DB	$FF,$D3,'S','E','T','B',' ','C',0
	DB	$FF,$D2,'S','E','T','B',' ','b',0
	DB	$FF,$80,'S','J','M','P',' ','j',0
	DB	$F8,$98,'S','U','B','B',' ','A',',','r',0
	DB	$FF,$95,'S','U','B','B',' ','A',',','d',0
	DB	$FE,$96,'S','U','B','B',' ','A',',','i',0
	DB	$FF,$94,'S','U','B','B',' ','A',',','m',0
	DB	$FF,$C4,'S','W','A','P',' ','A',0
	DB	$F8,$C8,'X','C','H',' ','A',',','r',0
	DB	$FF,$C5,'X','C','H',' ','A',',','d',0
	DB	$FE,$C6,'X','C','H',' ','A',',','i',0
	DB	$FE,$D6,'X','C','H','D',' ','A',',','i',0
	DB	$F8,$68,'X','R','L',' ','A',',','r',0
	DB	$FF,$65,'X','R','L',' ','A',',','d',0
	DB	$FE,$66,'X','R','L',' ','A',',','i',0
	DB	$FF,$64,'X','R','L',' ','A',',','m',0
	DB	$FF,$62,'X','R','L',' ','d',',','A',0
	DB	$FF,$63,'X','R','L',' ','d',',','m',0
	DB	0,0,'?','I','L','L','E','G','A','L',0
*
* Direct memory address table
*
DTABLE	DB	$E0,'A'
	DB	$F0,'B'
	DB	$D0,'P','S','W'
	DB	$81,'S','P'
	DB	$82,'D','P','L'
	DB	$83,'D','P','H'
	DB	$80,'P','0'
	DB	$90,'P','1'
	DB	$A0,'P','2'
	DB	$B0,'P','3'
	DB	$B8,'I','P'
	DB	$A8,'I','E'
	DB	$89,'T','M','O','D'
	DB	$C8,'T','2','C','O','N'
	DB	$88,'T','C','O','N'
	DB	$8C,'T','H','0'
	DB	$8A,'T','L','0'
	DB	$8D,'T','H','1'
	DB	$8B,'T','L','1'
	DB	$CD,'T','H','2'
	DB	$CC,'T','L','2'
	DB	$CB,'R','C','A','P','2','H'
	DB	$CA,'R','C','A','P','2','L'
	DB	$98,'S','C','O','N'
	DB	$99,'S','B','U','F'
	DB	$87,'P','C','O','N'
	DB	0
*
* Help text
*
HTEXT	STR	'MON51 Commands:'
	DB	$0A,0
	STRZ	'A <aa>|Alter internal'
	STRZ	'B [n aaaa]|Breakpoints'
	STRZ	'C <r> <data>|Change register'
	STRZ	'D <aaaa>,[aaaa]|Dump external'
	STRZ	'E <aaaa>|Edit external'
	STRZ	'F <aaaa>,[aaaa] <dd>|Fill external'
	STRZ	'G [aaaa]|Go (execute)'
	STRZ	'I <aa>,<aa>|dump Internal'
	STRZ	'L|downLoad'
	STRZ	'O <aa> <data>|Output to SFR'
	STRZ	'Q <aa>|Query SFR'
	STRZ	'R|dump Registers'
	STRZ	'S|Single-Step'
	STRZ	'U <aaaa>,[aaaa]|Un-assemble'
	STRZ	'W <aaaa> <data>|Single write'
	STRZ	'X C <aaaa>|LoopRead Code'
	STRZ	'X R <aaaa>|LoopRead XDATA'
	STRZ	'X W <aaaa> <data>|LoopWrite XDATA'
	DB	0
*
* Initialize the timer 1 for auto-reload at 32xN
*
START	MOV	TMOD,#%00100000	T1=8 bit auto-reload
	MOV	TH1,#-BAUD	Timer 1 reload value
	MOV	TL1,#-BAUD	Timer 1 initial value
	MOV	TCON,#%01001001	Run 1, Hold 0
* Initialize the serial port
	MOV	SCON,#%01010010	Mode 1, REN, TXRDY, RXEMPTY
* Main program - First, initialize memory
MAIN	MOV	DPTR,#PCSAVE	Point to monitor RAM
	MOV	A,#=USERRAM	High default PC
	MOVX	[DPTR],A	Set it
	INC	DPTR		Advance
	MOV	A,#USERRAM	Low default PC
	MOVX	[DPTR],A	Set it
	INC	DPTR		Advance
	MOV	A,#7		Default stack
	MOVX	[DPTR],A	Set it
	INC	DPTR		Advance
	MOV	R7,#MRSIZE	Indicate size
	CLR	A		Zero
CLEAR1	MOVX	[DPTR],A	Zero location
	INC	DPTR		Advance
	DJNZ	R7,CLEAR1	Keep going
	MOV	DPTR,#M_HELLO	Point to startup message
	LCALL	WRSTR		Write it
	LJMP	FPROMPT		And execute
