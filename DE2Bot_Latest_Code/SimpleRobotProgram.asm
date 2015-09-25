; SimpleRobotProgram.asm
; Created by Kevin Johnson
; (no copyright applied; edit freely, no attribution necessary)
; This program:
; 1) performs some basic robot initialization
; 2) waits for the user to enable the motors and
; 3) press KEY3
; 4) moves forward ~2ft and stops
; 5) repeats 3-5

	ORG     &H000		;Begin program at x000
Init:
	; Always a good idea to make sure the robot
	; stops in the event of a reset.
	LOAD    Zero
	OUT     LVELCMD     ; Stop motors
	OUT     RVELCMD
	OUT     SONAREN     ; Disable sonar (optional)
	OUT		BEEP

	CALL    SetupI2C    ; Configure the I2C
	CALL    BattCheck   ; Get battery voltage (and end if too low).
	OUT     SSEG2       ; Display batt voltage on SS

	LOAD    Zero
	ADDI    &H17        ; arbitrary reminder to toggle SW17
	OUT     SSEG1
WaitForUser:
	IN		XPOS
	OUT		SSEG2
	IN      XIO         ; contains KEYs and SAFETY
	AND     StartMask   ; mask with 0x10100 : KEY3 and SAFETY
	XOR     Mask4       ; KEY3 is active low; invert SAFETY to match
	JPOS    WaitForUser ; one of those is not ready, so try again 

Main: ; "Real" program starts here.
	OUT     RESETODO    ; reset odometry in case wheels moved after programming
	
	LOAD	One
	STORE	CurX
	STORE	CurY
	
Game:
	CALL	FORGETME	; Reset data associated with bot and base station
	CALL	ImAlive		; Let base station know I exist
	CALL	REPDUTY		; Let it know that I'm ready for duty
	LOAD	Zero
DoJob:
	OUT		RESETODO
	CALL	REQJOB		; Get Job #N and do it
	LOAD	N
	SUB		One			; Decrement N
	STORE	N			; Store new N
	JPOS	DoJob		; Do all jobs until 0
	CALL	GOHOME		; After all jobs, go home
	CALL	CLKOUT		; Clock out of base station
	
	JUMP	WaitForUser

	
;***** SUBROUTINES

; Subroutine to wait (block) for 1 second
Wait1:
	OUT     TIMER
Wloop:
	IN      TIMER
	OUT     LEDS
	ADDI    -10
	JNEG    Wloop
	RETURN
	
WaitHalf:
	OUT     TIMER
Wloop3:
	IN      TIMER
	OUT     LEDS
	ADDI    -5
	JNEG    Wloop3
	RETURN
	
; Subroutine to wait (block) & beep for 3 seconds
BeepWait3:
	OUT     TIMER
Wloop2:
	LOAD	Two			; 360*2 Hz
	OUT		BEEP
	IN      TIMER
	OUT     LEDS
	ADDI    -25
	JNEG    Wloop2
	LOAD	Zero
	OUT		BEEP
	RETURN


; This subroutine will get the battery voltage,
; and stop program execution if it is too low.
; SetupI2C must be executed prior to this.
BattCheck:
	CALL    GetBattLvl 
	SUB     MinBatt
	JNEG    DeadBatt
	ADD     MinBatt     ; get original value back
	RETURN
; If the battery is too low, we want to make
; sure that the user realizes it...
DeadBatt:
	LOAD    Four
	OUT     BEEP        ; start beep sound
	CALL    GetBattLvl  ; get the battery level
	OUT     SSEG1       ; display it everywhere
	OUT     SSEG2
	OUT     LCD
	LOAD    Zero
	ADDI    -1          ; 0xFFFF
	OUT     LEDS        ; all LEDs on
	OUT     GLEDS
	CALL    Wait1       ; 1 second
	Load    Zero
	OUT     BEEP        ; stop beeping
	LOAD    Zero
	OUT     LEDS        ; LEDs off
	OUT     GLEDS
	CALL    Wait1       ; 1 second
	JUMP    DeadBatt    ; repeat forever
	
; Subroutine to configure the I2C for reading batt voltage
; Only needs to be done once after each reset.
SetupI2C:
	LOAD    I2CWCmd     ; 0x1190 (write 1B, read 1B, addr 0x90)
	OUT     I2C_CMD     ; to I2C_CMD register
	LOAD    Zero        ; 0x0000 (A/D port 0, no increment)
	OUT     I2C_DATA    ; to I2C_DATA register
	OUT     I2C_RDY     ; start the communication
	CALL    BlockI2C    ; wait for it to finish
	RETURN
	
; Subroutine to read the A/D (battery voltage)
; Assumes that SetupI2C has been run
GetBattLvl:
	LOAD    I2CRCmd     ; 0x0190 (write 0B, read 1B, addr 0x90)
	OUT     I2C_CMD     ; to I2C_CMD
	OUT     I2C_RDY     ; start the communication
	CALL    BlockI2C    ; wait for it to finish
	IN      I2C_DATA    ; get the returned data
	RETURN

; Subroutine to block until I2C device is idle
BlockI2C:
	IN      I2C_RDY;   ; Read busy signal
	JPOS    BlockI2C    ; If not 0, try again
	RETURN              ; Else return
	
; Subrotuine to inform the base station of existance
IMALIVE:

	LOAD 	TSENDALV    ; Load value to send
	OUT 	UART		; Send to UART
	CALL	INUART0
	CALL	INUART1		; Receive response from UART
	CALL	INUART0		; Wait until data is cleared

	CALL	INUART1		; Receive checksum from UART
	;CALL	INUART0		; Wait until data is cleared
	
	RETURN


; Subroutine to inform base station that I'm ready
REPDUTY:

	LOAD 	SNDDUTY		; Load value to send
	
	OUT 	UART		; Send to UART
	CALL	INUART0
	CALL	INUART1		; Receive from UART
	STORE	RDUTY		; Store response
	CALL	INUART0		; Wait until data is cleared
	
	CALL	INUART1		; Receive checksum from UART
	;CALL	INUART0		; Wait until data is cleared
	RETURN


		
; Subroutine to clock out
CLKOUT:
	LOAD	CLKVAL		; Load value to send
	OUT		UART		; Send to UART
	CALL	INUART0
	CALL	INUART1		; Receive data from UART
	CALL	INUART0		; Wait until data is cleared
	
	CALL	INUART1		; Receive checksum from UART
	;CALL	INUART0		; Wait until data is cleared
	RETURN


; Subroutine to request job
REQJOB:

	LOAD	REQVAL		; Load value to send
	ADD		N			; Add specific job number
	;CALL	INUART0
	OUT		UART		; Send to UART
	CALL	INUART0

	CALL	INUART1		; Receive X1 from UART
	STORE	X1			; Store X1
	CALL	INUART0		; Wait until data is cleared
	
	CALL	INUART1		; Receive Y1 from UART
	STORE	Y1			; Store Y1
	CALL	INUART0		; Wait until data is cleared
	
	CALL	INUART1		; Receive X2 from UART
	STORE	X2			; Store X2
	CALL	INUART0		; Wait until data is cleared
	
	CALL	INUART1		; Receive Y2 from UART
	STORE 	Y2			; Store Y2
	CALL	INUART0		; Wait until data is cleared

	CALL	INUART1		; Receive checksum from UART
	
	;CALL	INUART0		; Wait until data is cleared
	

	
; Move to pickup location

; Start Pickup Location - X =================

	OUT		RESETODO
	LOAD	Zero
	STORE	Temp
	
	LOAD	X1
	OUT		SSEG1
	SUB		CurX
	MULT	TwoFeet
	STORE	Temp
	JPOS	MOVEXF
	JNEG	MOVEXR
	JZERO	PICKX
	
MOVEXF:
	LOAD	FMedium
	OUT		LVELCMD
	ADD		TurnConst
	OUT		RVELCMD
	IN		XPOS
	SUB		Temp
	OUT		SSEG2
	JNEG	MOVEXF
	JUMP	PICKX
	
MOVEXR:
	LOAD	RMedium
	OUT		LVELCMD
	SUB		TurnConst2
	OUT		RVELCMD
	IN		XPOS
	SUB		Temp
	OUT		SSEG2
	JPOS	MOVEXR
	JUMP	PICKX

PICKX:

	LOAD	X1			; Update X value
	STORE	CurX		; Store new X value
	OUT		RESETODO
	CALL	Rotate90	; Rotate 90 anticlockwise


; End Pickup Location X =======================

; Start Pickup Location Y ======================

	; Now the bot is at the correct X value for Pickup.
	; Move it along Y
	CALL	STOP
	OUT		RESETODO
	LOAD	Zero
	STORE	Temp


	LOAD	Y1
	OUT		SSEG1
	SUB		CurY
	MULT	TwoFeet
	STORE	Temp
	JPOS	MOVEYF
	JNEG	MOVEYR
	JZERO	PICKY
	
	
	
MOVEYF:
	LOAD	FMedium
	OUT		LVELCMD
	ADD		TurnConst
	OUT		RVELCMD
	IN		XPOS
	SUB		Temp
	OUT		SSEG2
	JNEG	MOVEYF
	JUMP	PICKY
	
MOVEYR:
	LOAD	RMedium
	OUT		LVELCMD
	SUB		TurnConst2
	OUT		RVELCMD
	IN		XPOS
	SUB		Temp
	OUT		SSEG2
	JPOS	MOVEYR
	JUMP	PICKY

PICKY:
	CALL	STOP		; Stop the bot
	LOAD	Zero
	OUT		RESETODO
	LOAD	Y1			; Update Y value
	STORE	CurY		; Store new Y value
	CALL	STOP		; Stop the bot
	

; End Pickup Location Y ======================
	
	CALL	PICKUP		; Tell base station, job has been picked up

; Start Dropoff Location Y ====================


	OUT		RESETODO
	LOAD	Zero
	STORE	Temp

	LOAD	Y2
	OUT		SSEG1
	SUB		CurY
	MULT	TwoFeet
	STORE	Temp
	JPOS	MOVEYF2
	JNEG	MOVEYR2
	JZERO	DROPY
	
	
MOVEYF2:
	LOAD	FMedium
	OUT		LVELCMD
	ADD		TurnConst
	OUT		RVELCMD
	IN		XPOS
	SUB		Temp
	OUT		SSEG2
	JNEG	MOVEYF2
	JUMP	DROPY
	
	
	
MOVEYR2:
	LOAD	RMedium
	OUT		LVELCMD
	SUB		TurnConst2
	OUT		RVELCMD
	IN		XPOS
	SUB		Temp
	OUT		SSEG2
	JPOS	MOVEYR2
	JUMP	DROPY

DROPY:

	LOAD	Y2			; Update Y value
	STORE	CurY		; Store new Y value
	OUT		RESETODO
	CALL	Rotate270	; Rotate 270 anticlockwise


; End Dropoff Location Y =======================

; Start Dropoff Location - X =================

	CALL	STOP
	OUT		RESETODO
	LOAD	Zero
	STORE	Temp
	
	LOAD	One
	OUT		SSEG1
	SUB		CurX
	MULT	TwoFeet
	STORE	Temp
	JNEG	MOVEXR2
	JUMP	DROPX
	
MOVEXR2:
	LOAD	RMedium
	OUT		LVELCMD
	SUB		TurnConst2
	OUT		RVELCMD
	;LOAD	Mask6
	;OUT		SONAREN
	;IN		DIST6
	;JNEG	MOVEXR2
	;SUB		Pedro
	IN		XPOS
	SUB		Temp
	OUT		SSEG2
	JPOS	MOVEXR2
	JUMP	DROPX

DROPX:
	CALL	STOP		; Stop the bot
	LOAD	Zero
	OUT		RESETODO
	LOAD	One			; Update X value
	STORE	CurX		; Store new X value
	CALL	STOP		; Stop the bot

	
; End Dropoff Location X =======================

	CALL	DROPOFF		; Tell base station, job has been dropped off
	RETURN

	
STOP:
	LOAD	Zero
	OUT		LVELCMD
	OUT		RVELCMD
	CALL	WaitHalf
	RETURN
	
Rotate90:
	LOAD	RSlow
	OUT		LVELCMD
	LOAD	FSlow
	OUT		RVELCMD
	IN		THETA
	OUT		SSEG1
	SUB		Deg90
	OUT		SSEG2
	JNEG 	Rotate90
	RETURN
	
Rotate270:
	LOAD	RSlow
	OUT		LVELCMD
	LOAD	FSlow
	OUT		RVELCMD
	IN		THETA
	OUT		SSEG1
	SUB		Deg270
	OUT		SSEG2
	JNEG 	Rotate270
	RETURN

	
PICKUP:
	LOAD	PICKVAL		; Load value to send
	ADD		N			; Add specific job number
	OUT		UART		; Send to UART
	CALL	INUART0
	CALL	INUART1		; Receive response from UART
	;OUT		SSEG2
	CALL	INUART0		; Wait until data is cleared
	
	CALL	INUART1		; Receive checksum from UART
	;CALL	INUART0		; Wait until data is cleared
	
	CALL	BeepWait3	; Wait and beep for 3 seconds
	RETURN

	
DROPOFF:
	LOAD	DROPVAL		; Load value to send
	OUT		UART		; Send to UART
	CALL	INUART0
	CALL	INUART1		; Receive response from UART
	;OUT		SSEG2
	CALL	INUART0		; Wait until data is cleared
	
	CALL	INUART1		; Receive checksum from UART
	;CALL	INUART0		; Wait until data is cleared
	
	CALL	BeepWait3	; Wait and beep for 3 seconds
	RETURN
	

GOHOME:
; Get Ready to go back to (1,1)

	OUT		RESETODO
	
	LOAD	One
	OUT		SSEG1
	SUB		CurX
	MULT	TwoFeet
	STORE	Temp
	JNEG	HOMEXR
	JUMP	HOMEX	
	
HOMEXR:
	LOAD	RMedium
	OUT		LVELCMD
	SUB		TurnConst2
	OUT		RVELCMD
	;LOAD	Mask6
	;OUT		SONAREN
	;IN		DIST6
	;JNEG	MOVEXR2
	;SUB		Pedro
	IN		XPOS
	SUB		Temp
	OUT		SSEG2
	JPOS	HOMEXR
	JUMP	HOMEX

HOMEX:	
	CALL	STOP		; Stop the bot
	LOAD	One			; Update X value
	STORE	CurX		; Store new X value
	CALL	Rotate90	; Rotate 90 anticlockwise
	CALL	STOP		; Stop the bot

; Now the bot is at (1,N)
	OUT		RESETODO

	LOAD	One
	OUT		SSEG1
	SUB		CurY
	MULT	TwoFeet
	STORE	Temp
	JNEG	HOMEYR
	JUMP	HOMEY
	
HOMEYR:
	LOAD	RMedium
	OUT		LVELCMD
	SUB		TurnConst2
	OUT		RVELCMD
	;LOAD	Mask6
	;OUT		SONAREN
	;IN		DIST6
	;JNEG	MOVEXR2
	;SUB		Pedro
	IN		XPOS
	SUB		Temp
	OUT		SSEG2
	JPOS	HOMEYR
	JUMP	HOMEY

HOMEY:	
	CALL	STOP		; Stop the bot
	LOAD	Y1			; Update Y value
	STORE	CurY		; Store new Y value
	CALL	STOP		; Stop the bot
	
	RETURN


INUART1:
	IN		USTB
	SUB		One
	JNEG	INUART1
	JPOS	INUART1
	IN		UART
	AND		FIXIN
	RETURN

INUART0:
	IN		USTB
	JNEG	INUART0
	JPOS	INUART0
	RETURN
	


; Used for testing purposes only
FORGETME:
	LOAD	FRGTVAL		; Load value to send
	OUT		UART		; Send to UART
	CALL	INUART1		; Receive data from UART
	CALL	INUART0		; Wait until data is cleared
	
	CALL	INUART1		; Receive checksum from UART
	;CALL	INUART0		; Wait until data is cleared
	RETURN	

	
ErrorVal:	DW	&HFF

; Constants for Im Alive
TSENDALV:   DW &H0B
TESTN:	  	DW &H0F
TESTALV:  	DW 0

; Constants for Reporting for Duty
SNDDUTY:	DW &H10		; CHANGE TO &H10 FOR ACTUAL JOBS --- TEST JOBS RANGE FROM 80 to 84
RDUTY:		DW 0

CLKVAL:		DW &H60

REQVAL:		DW &H20

CXPOS:		DW 0
CYPOS:		DW 0
DYPOS:		DW 0

PICKVAL:	DW &H30
DROPVAL:	DW &H40

FIXIN:		DW &HFF

FRGTVAL:	DW &H90

; N - Job number (8 to 1)
N:		  DW 8

; Job Coordinates
X1:		  DW 1
Y1:		  DW 1
X2:		  DW 1
Y2:		  DW 1

; Current location
CurX:	  DW 1
CurY:	  DW 1

; Move by X/Y
MovX:	  DW 0
MovY:	  DW 0

; Current Direction and Speed
DirSpeed: DW 0

TurnConst: DW 10

TurnConst2: DW 8

; This is a good place to put variables
Temp:     DW 0 ; "Temp" is not a great name, but can be helpful

; Having some constants can be very useful
Zero:     DW 0
One:      DW 1
Two:      DW 2
Three:    DW 3
Four:     DW 4
Five:     DW 5
Six:      DW 6
Seven:    DW 7
Eight:    DW 8
Nine:     DW 9
Ten:      DW 10
FSlow:    DW 480       ; 100 is about the lowest value that will move at all
RSlow:    DW -480
FMedium:  DW 480
RMedium:  DW -480
FFast:    DW 500       ; 500 is a fair clip (511 is max)
RFast:    DW -500
Pedro:	  DW 150
Deg90:    DW 118
;Deg180:   DW 320
Deg270:   DW 449
;Deg360:	  DW 700
; Masks of multiple bits can be constructed by, for example,
; LOAD Mask0; OR Mask2; OR Mask4, etc.
Mask0:    DW &B00000001
Mask1:    DW &B00000010
Mask2:    DW &B00000100
Mask3:    DW &B00001000
Mask4:    DW &B00010000
Mask5:    DW &B00100000
Mask6:    DW &B01000000
Mask7:    DW &B10000000
StartMask: DW &B10100
AllSonar: DW &B11111111
OneMeter: DW 476        ; one meter in 2.1mm units
HalfMeter: DW 238       ; half meter in 2.1mm units
TwoFeet:  DW 257        ; ~2ft in 2.1mm units
MinBatt:  DW 110        ; 11V - minimum safe battery voltage
I2CWCmd:  DW &H1190     ; write one byte, read one byte, addr 0x90
I2CRCmd:  DW &H0190     ; write nothing, read one byte, addr 0x90

; IO address space map
SWITCHES: EQU &H00  ; slide switches
LEDS:     EQU &H01  ; red LEDs
TIMER:    EQU &H02  ; timer, usually running at 10 Hz
XIO:      EQU &H03  ; pushbuttons and some misc. inputs
SSEG1:    EQU &H04  ; seven-segment display (4-digits only)
SSEG2:    EQU &H05  ; seven-segment display (4-digits only)
LCD:      EQU &H06  ; primitive 4-digit LCD display
GLEDS:    EQU &H07  ; Green LEDs (and Red LED16+17)
BEEP:     EQU &H0A  ; Control the beep
LPOS:     EQU &H80  ; left wheel encoder position (read only)
LVEL:     EQU &H82  ; current left wheel velocity (read only)
LVELCMD:  EQU &H83  ; left wheel velocity command (write only)
RPOS:     EQU &H88  ; same values for right wheel...
RVEL:     EQU &H8A  ; ...
RVELCMD:  EQU &H8B  ; ...
I2C_CMD:  EQU &H90  ; I2C module's CMD register,
I2C_DATA: EQU &H91  ; ... DATA register,
I2C_RDY:  EQU &H92  ; ... and BUSY register
UART:     EQU &H98  ; The basic UART interface provided
USTB:	  EQU &H99  ; UART_OUT_STB
; 0x98-0x9F are reserved for any additional UART functions you create
SONAR:    EQU &HA0  ; base address for more than 16 registers....
DIST0:    EQU &HA8  ; the eight sonar distance readings
DIST1:    EQU &HA9  ; ...
DIST2:    EQU &HAA  ; ...
DIST3:    EQU &HAB  ; ...
DIST4:    EQU &HAC  ; ...
DIST5:    EQU &HAD  ; ...
DIST6:    EQU &HAE  ; ...
DIST7:    EQU &HAF  ; ...
SONAREN:  EQU &HB2  ; register to control which sonars are enabled
XPOS:     EQU &HC0  ; Current X-position (read only)
YPOS:     EQU &HC1  ; Y-position
THETA:    EQU &HC2  ; Current rotational position of robot (0-701)
RESETODO: EQU &HC3  ; reset odometry to 0
