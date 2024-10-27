	; CVBasic compiler v0.7.1 Sep/30/2024
	; Command: ./cvbasic --creativision examples/space_attack.bas space_attack.asm 
	; Created: Wed Oct 23 16:09:25 2024

COLECO:	equ 0
SG1000:	equ 0
MSX:	equ 0
SGM:	equ 0
SVI:	equ 0
SORD:	equ 0
MEMOTECH:	equ 0
EINSTEIN:	equ 0
CPM:	equ 0
PENCIL:	equ 0
PV2000:	equ 0
TI99:	equ 0
NABU:	equ 0

CVBASIC_MUSIC_PLAYER:	equ 0
CVBASIC_COMPRESSION:	equ 0
CVBASIC_BANK_SWITCHING:	equ 0

BASE_RAM:	equ $0050	; Base of RAM
STACK:	equ $017f	; Base stack pointer
VDP:	equ $00	; VDP port (write)
VDPR:	equ $00	; VDP port (read)
PSG:	equ $00	; PSG port (write)
SMALL_ROM:	equ 0

	;
	; CVBasic prologue (BASIC compiler, 6502 target)
	;
	; by Oscar Toledo G.
	; https://nanochess.org/
	;
	; Creation date: Aug/05/2024.
	; Revision date: Aug/06/2024. Ported music player from Z80 CVBasic.
	; Revision date: Aug/07/2024. Ported Pletter decompressor from Z80 CVBasic.
	;                             Added VDP delays.
	; Revision date: Aug/16/2024. Corrected bug in define_char_unpack.
	; Revision date: Aug/21/2024. Added support for keypad.
	; Revision date: Aug/30/2024. Changed mode bit to bit 3 (avoids collision
	;                             with flicker flag).
	; Revision date: Oct/15/2024. Added LDIRMV.
	;

	CPU 6502

BIOS_NMI_RESET_ADDR:	EQU $F808
BIOS_READ_CONTROLLERS:	EQU $FA00
BIOS_WRITE_PSG:		EQU $FE77

	;
	; Platforms supported:
	; o Vtech Creativision.
	; o Dick Smith's Wizzard.
	;

	;
	; CVBasic variables in zero page.
	;

	; This is a block of 8 bytes that should stay together.
temp:		equ $02
temp2:		equ $04
result:		equ $06
pointer:	equ $08

read_pointer:	equ $0a
cursor:		equ $0c
pletter_off:	equ $0e	; Used by Pletter

	; Zero page $00-$01 and $10-$1f are used by
	; the Creativision BIOS to read the controllers.
joy1_dir:	equ $11
joy2_dir:	equ $13
joy1_buttons:	equ $16
joy2_buttons:	equ $17

joy1_data:	equ $20
joy2_data:	equ $21
key1_data:	equ $22
key2_data:	equ $23
frame:		equ $24
lfsr:		equ $26
mode:           equ $28
flicker:	equ $29
sprite_data:	equ $2a
ntsc:		equ $2e
pletter_bit:	equ $2f

	IF CVBASIC_MUSIC_PLAYER
music_playing:		EQU $30
music_timing:		EQU $31
music_start:		EQU $32
music_pointer:		EQU $34
music_note_counter:	EQU $36
music_instrument_1:	EQU $37
music_note_1:		EQU $38
music_counter_1:	EQU $39
music_instrument_2:	EQU $3a
music_note_2:		EQU $3b
music_counter_2:	EQU $3c
music_instrument_3:	EQU $3d
music_note_3:		EQU $3e
music_counter_3:	EQU $3f
music_drum:		EQU $40
music_counter_4:	EQU $41
audio_freq1:		EQU $42
audio_freq2:		EQU $44
audio_freq3:		EQU $46
audio_vol1:		EQU $48
audio_vol2:		EQU $49
audio_vol3:		EQU $4a
audio_vol4hw:		EQU $4b
audio_noise:		EQU $4c
audio_control:		EQU $4d
music_mode:		EQU $4e
	ENDIF

sprites:	equ $0180

	ORG $4000+$4000*SMALL_ROM
	
WRTVDP:
	STA $3001
	TXA
	ORA #$80
	STA $3001
	RTS

SETWRT:
	STA $3001	; 4
	TYA		; 2
	ORA #$40	; 2
	STA $3001	; 4
	RTS		; 6

SETRD:
	STA $3001	; 4
	TYA		; 2
	AND #$3F	; 2
	STA $3001	; 4
	RTS		; 6

	; VDP delays calculated for 6502 running at 2 mhz.
WRTVRM:
	JSR SETWRT	; 6
	TXA		; 2
	NOP		; 2
	NOP		; 2
	NOP		; 2 = RTS + 14 = Minimum cycles
	NOP		; 2
	STA $3000	; 4
	RTS		; 6

RDVRM:
	JSR SETRD	; 6
	NOP		; 2
	NOP		; 2
	NOP		; 2
	NOP		; 2
	NOP		; 2
	NOP		; 2
	NOP		; 2
	NOP		; 2
	NOP		; 2
	NOP		; 2
	NOP		; 2
	LDA $2000	; 4
	RTS		; 6

FILVRM:
	LDA pointer
	LDY pointer+1
	JSR SETWRT
	LDA temp2
	BEQ .1
	INC temp2+1
.1:
	LDA temp	; 3
	STA $3000	; 4
	NOP		; 2
	NOP		; 2
	DEC temp2	; 5
	BNE .1		; 2/3/4
	DEC temp2+1	; 5
	BNE .1		; 2/3/4
	RTS	

LDIRMV:
	LDA temp
	LDY temp+1
	JSR SETRD
	LDA temp2
	BEQ .1
	INC temp2+1
.1:
	LDY #0
.2:
	LDA $3000	; 4
	STA (pointer),Y	; 5/6
	INC pointer	; 5
	BNE .3		; 2/3/4
	INC pointer+1	; 5
.3:
	DEC temp2	; 5
	BNE .2		; 2/3/4
	DEC temp2+1	; 5
	BNE .2		; 2/3/4
	RTS

LDIRVM:
	LDA pointer
	LDY pointer+1
	JSR SETWRT
	LDA temp2
	BEQ .1
	INC temp2+1
.1:
	LDY #0
.2:
	LDA (temp),Y	; 5/6
	STA $3000	; 4
	INC temp	; 5
	BNE .3		; 2/3/4
	INC temp+1	; 5
.3:
	DEC temp2	; 5
	BNE .2		; 2/3/4
	DEC temp2+1	; 5
	BNE .2		; 2/3/4
	RTS

LDIRVM3:
	JSR .1
	JSR .1
.1:	LDA temp
	PHA
	LDA temp+1
	PHA
	LDA temp2
	PHA
	LDA temp2+1
	PHA
	JSR LDIRVM
	LDA pointer+1
	CLC
	ADC #8
	STA pointer+1
	PLA
	STA temp2+1
	PLA
	STA temp2
	PLA
	STA temp+1
	PLA
	STA temp
	RTS

DISSCR:
	SEI
	LDA #$A2
	LDX #$01
	JSR WRTVDP
	CLI
	RTS

ENASCR:
	SEI
	LDA #$E2
	LDX #$01
	JSR WRTVDP
	CLI
	RTS

CPYBLK:
	SEI
.1:	
	LDA temp2
	PHA
	LDA temp2+1
	PHA
	TXA
	PHA
	TYA
	PHA
	LDA temp
	PHA
	LDA temp+1
	PHA
	LDA #0
	STA temp2+1
	JSR LDIRVM
	PLA
	STA temp+1
	PLA
	STA temp
	PLA
	STA temp2+1
	PLA
	STA temp2
	LDA temp
	CLC
	ADC temp2
	STA temp
	LDA temp+1
	ADC temp2+1
	STA temp+1
	LDX temp2
	LDY temp2+1
	PLA
	STA temp2+1
	PLA
	STA temp2
	LDA pointer
	CLC
	ADC #$20
	STA pointer
	LDA pointer+1
	ADC #$00
	STA pointer+1
	DEC temp2+1
	BNE .1
	CLI
	RTS

cls:
	lda #$00
	ldy #$18
	sta cursor
	sty cursor+1
	sta pointer
	sty pointer+1
	ldy #$03
	sta temp2
	sty temp2+1
	lda #$20
	sta temp
	sei
	jsr FILVRM
	cli
	rts

print_string_cursor_constant:
	PLA
	STA temp
	PLA
	STA temp+1
	LDY #1
	LDA (temp),Y
	STA cursor
	INY
	LDA (temp),Y
	STA cursor+1
	INY
	LDA (temp),Y
	STA temp2
	TYA
	CLC
	ADC temp
	STA temp
	BCC $+4
	INC temp+1
	LDA temp2
	BNE print_string.2

print_string_cursor:
	STA cursor
	STY cursor+1
print_string:
	PLA
	STA temp
	PLA
	STA temp+1
	LDY #1
	LDA (temp),Y
	STA temp2
	INC temp
	BNE $+4
	INC temp+1
.2:	CLC
	ADC temp
	TAY
	LDA #0
	ADC temp+1
	PHA
	TYA
	PHA
	INC temp
	BNE $+4
	INC temp+1
	LDA temp2
	PHA
	LDA #0
	STA temp2+1
	LDA cursor
	STA pointer
	LDA cursor+1
	AND #$07
	ORA #$18
	STA pointer+1
	SEI
	JSR LDIRVM
	CLI
	PLA
	CLC
	ADC cursor
	STA cursor
	BCC .1
	INC cursor+1
.1:	
	RTS

print_number:
	LDX #0
	STX temp
	SEI
print_number5:
	LDX #10000
	STX temp2
	LDX #10000/256
	STX temp2+1
	JSR print_digit
print_number4:
	LDX #1000
	STX temp2
	LDX #1000/256
	STX temp2+1
	JSR print_digit
print_number3:
	LDX #100
	STX temp2
	LDX #0
	STX temp2+1
	JSR print_digit
print_number2:
	LDX #10
	STX temp2
	LDX #0
	STX temp2+1
	JSR print_digit
print_number1:
	LDX #1
	STX temp2
	STX temp
	LDX #0
	STX temp2+1
	JSR print_digit
	CLI
	RTS

print_digit:
	LDX #$2F
.2:
	INX
	SEC
	SBC temp2
	PHA
	TYA
	SBC temp2+1
	TAY
	PLA
	BCS .2
	CLC
	ADC temp2
	PHA
	TYA
	ADC temp2+1
	TAY
	PLA
	CPX #$30
	BNE .3
	LDX temp
	BNE .4
	RTS

.4:	DEX
	BEQ .6
	LDX temp+1
	BNE .5
.6:
	LDX #$30
.3:	PHA
	LDA #1
	STA temp
	PLA
.5:	PHA
	TYA
	PHA
	LDA cursor+1
	AND #$07
	ORA #$18
	TAY
	LDA cursor
	JSR WRTVRM
	INC cursor
	BNE .1
	INC cursor+1
.1:
	PLA
	TAY
	PLA
	RTS

define_sprite:
	sta temp2
	lda #0
	sta temp2+1
	lda #7
	sta pointer+1
	lda pointer
	asl a
	asl a
	asl a
	rol pointer+1
	asl a
	rol pointer+1
	asl a
	rol pointer+1
	sta pointer
	lda temp2
	asl a
	rol temp2+1
	asl a
	rol temp2+1
	asl a
	rol temp2+1
	asl a
	rol temp2+1
	asl a
	rol temp2+1
	sta temp2
	sei
	jsr LDIRVM
	cli
	rts

define_char:
	sta temp2
	lda #0
	sta pointer+1
	sta temp2+1
	lda pointer
	asl a
	rol pointer+1
	asl a
	rol pointer+1
	asl a
	rol pointer+1
	sta pointer
	lda temp2
	asl a
	rol temp2+1
	asl a
	rol temp2+1
	asl a
	rol temp2+1
	sta temp2
	sei
	lda mode
	and #$08
	bne .1
	jsr LDIRVM3
	cli
	rts

.1:	jsr LDIRVM
	cli
	rts

define_color:
	sta temp2
	lda #0
	sta temp2+1
	lda #$04
	sta pointer+1
	lda pointer
	asl a
	rol pointer+1
	asl a
	rol pointer+1
	asl a
	rol pointer+1
	sta pointer
	lda temp2
	asl a
	rol temp2+1
	asl a
	rol temp2+1
	asl a
	rol temp2+1
	sta temp2
	sei
	jsr LDIRVM3
	cli
	rts

update_sprite:
	ASL A
	ASL A
	ORA #$80
	STA pointer
	LDA #$01
	STA pointer+1
	LDY #0
	LDA sprite_data+0
	STA (pointer),Y
	INY
	LDA sprite_data+1
	STA (pointer),Y
	INY
	LDA sprite_data+2
	STA (pointer),Y
	INY
	LDA sprite_data+3
	STA (pointer),Y
	RTS

_abs16:
	PHA
	TYA
	BPL _neg16.1
	PLA
_neg16:
	EOR #$FF
	CLC
	ADC #1
	PHA
	TYA
	EOR #$FF
	ADC #0
	TAY
.1:
	PLA
	RTS

_sgn16:
	STY temp
	ORA temp
	BEQ .1
	TYA
	BMI .2
	LDA #0
	TAY
	LDA #1
	RTS

.2:	LDA #$FF
.1:	TAY
	RTS

_read16:
	JSR _read8
	PHA
	JSR _read8
	TAY
	PLA
	RTS

_read8:
	LDY #0
	LDA (read_pointer),Y
	INC read_pointer
	BNE .1
	INC read_pointer+1
.1:
	RTS

_peek8:
	STA pointer
	STY pointer+1
	LDY #0
	LDA (pointer),Y
	RTS

_peek16:
	STA pointer
	STY pointer+1
	LDY #0
	LDA (pointer),Y
	PHA
	INY
	LDA (pointer),Y
	TAY
	PLA
	RTS

	; temp2 contains left side (dividend)
	; temp contains right side (divisor)

	; 16-bit multiplication.
_mul16:
	PLA
	STA result
	PLA
	STA result+1
	PLA
	STA temp2+1
	PLA
	STA temp2
	LDA result+1
	PHA
	LDA result
	PHA
	LDA #0
	STA result
	STA result+1
	LDX #15
.1:
	LSR temp2+1
	ROR temp2
	BCC .2
	LDA result
	CLC
	ADC temp
	STA result
	LDA result+1
	ADC temp+1
	STA result+1
.2:	ASL temp
	ROL temp+1
	DEX
	BPL .1
	LDA result
	LDY result+1
	RTS

	; 16-bit signed modulo.
_mod16s:
	PLA
	STA result
	PLA
	STA result+1
	PLA
	STA temp2+1
	PLA
	STA temp2
	LDA result+1
	PHA
	LDA result
	PHA
	LDY temp2+1
	PHP
	BPL .1
	LDA temp2
	JSR _neg16
	STA temp2
	STY temp2+1
.1:
	LDY temp+1
	BPL .2
	LDA temp
	JSR _neg16
	STA temp
	STY temp+1
.2:
	JSR _mod16.1
	PLP
	BPL .3
	JMP _neg16
.3:
	RTS

	; 16-bit signed division.
_div16s:
	PLA
	STA result
	PLA
	STA result+1
	PLA
	STA temp2+1
	PLA
	STA temp2
	LDA result+1
	PHA
	LDA result
	PHA
	LDA temp+1
	EOR temp2+1
	PHP
	LDY temp2+1
	BPL .1
	LDA temp2
	JSR _neg16
	STA temp2
	STY temp2+1
.1:
	LDY temp+1
	BPL .2
	LDA temp
	JSR _neg16
	STA temp
	STY temp+1
.2:
	JSR _div16.1
	PLP
	BPL .3
	JMP _neg16
.3:
	RTS

_div16:
	PLA
	STA result
	PLA
	STA result+1
	PLA
	STA temp2+1
	PLA
	STA temp2
	LDA result+1
	PHA
	LDA result
	PHA
.1:
	LDA #0
	STA result
	STA result+1
	LDX #15
.2:
	ROL temp2
	ROL temp2+1
	ROL result
	ROL result+1
	LDA result
	SEC
	SBC temp
	STA result
	LDA result+1
	SBC temp+1
	STA result+1
	BCS .3
	LDA result
	ADC temp
	STA result
	LDA result+1
	ADC temp+1
	STA result+1
	CLC
.3:
	DEX
	BPL .2
	ROL temp2
	ROL temp2+1
	LDA temp2
	LDY temp2+1
	RTS

_mod16:
	PLA
	STA result
	PLA
	STA result+1
	PLA
	STA temp2+1
	PLA
	STA temp2
	LDA result+1
	PHA
	LDA result
	PHA
.1:
	LDA #0
	STA result
	STA result+1
	LDX #15
.2:
	ROL temp2
	ROL temp2+1
	ROL result
	ROL result+1
	LDA result
	SEC
	SBC temp
	STA result
	LDA result+1
	SBC temp+1
	STA result+1
	BCS .3
	LDA result
	ADC temp
	STA result
	LDA result+1
	ADC temp+1
	STA result+1
	CLC
.3:
	DEX
	BPL .2
	LDA result
	LDY result+1
	RTS

	; Random number generator.
	; From my game Mecha Eight.
random:
	LDA lfsr
	ORA lfsr+1
	BNE .0
	LDA #$11
	STA lfsr
	LDA #$78
	STA lfsr+1
.0:	LDA lfsr+1
	ROR A	
	ROR A		
	ROR A		
	EOR lfsr+1	
	STA temp
	LDA lfsr+1
	ROR A
	ROR A
	EOR temp
	STA temp
	LDA lfsr
	ASL A
	ASL A
	EOR temp
	ROL A
	ROR lfsr+1
	ROR lfsr
	LDA lfsr
	LDY lfsr+1
	RTS

sn76489_freq:
	STA temp
	STY temp+1
	STX temp2
	AND #$0f
	ORA temp2
	JSR BIOS_WRITE_PSG
	LDA temp+1
	ASL temp
	ROL A
	ASL temp
	ROL A
	ASL temp
	ROL A
	ASL temp
	ROL A
	AND #$3f	
	JMP BIOS_WRITE_PSG
	
sn76489_vol:
	STX temp2
	EOR #$ff
	AND #$0f
	ORA temp2
	JMP BIOS_WRITE_PSG

sn76489_control:
	AND #$0f
	ORA #$e0
	JMP BIOS_WRITE_PSG

vdp_generic_mode:
	SEI
	LDX #$00
	JSR WRTVDP
	LDA #$A2
	INX
	JSR WRTVDP
	LDA #$06	; $1800 for pattern table.
	INX
	JSR WRTVDP
	TYA
	INX		; for color table.
	JSR WRTVDP
	LDA temp+1
	INX		; for bitmap table.
	JSR WRTVDP
	LDA #$36	; $1b00 for sprite attribute table.
	INX
	JSR WRTVDP
	LDA #$07	; $3800 for sprites bitmaps.
	INX
	JSR WRTVDP
	LDA #$01
	INX
	JSR WRTVDP
	LDA #font_bitmaps
	LDY #font_bitmaps>>8
	STA temp
	STY temp+1
	LDA #$00
	STA pointer
	STA temp2
	LDA #$01
	STA pointer+1
	LDA #$03
	STA temp2+1
	RTS

mode_0:
	LDA mode
	AND #$F7
	STA mode
	LDY #$ff	; $2000 for color table.
	LDA #$03	; $0000 for bitmaps
	STA temp+1
	LDA #$02
	JSR vdp_generic_mode
	JSR LDIRVM3
	SEI
	LDA #$f0
	STA temp
	LDA #$00
	STA pointer
	STA temp2
	LDY #$2000>>8
	STY pointer+1
	LDY #$1800>>8
	STY temp2+1
	JSR FILVRM
	CLI
	JSR cls
vdp_generic_sprites:
	LDA #$d1
	STA temp
	LDA #$00
	STA pointer
	STA temp2+1
	LDY #$1b00>>8
	STY pointer+1
	LDA #$80
	STA temp2
	SEI
	JSR FILVRM
	LDX #$7F
	LDA #$D1
.1:
	STA sprites,X
	DEX
	BPL .1
	LDA #$E2
	LDX #$01
	JSR WRTVDP
	CLI
	RTS

mode_1:
	LDA mode
	AND #$F7
	STA mode
	LDY #$ff	; $2000 for color table.
	LDA #$03	; $0000 for bitmaps
	STA temp+1
	LDA #$02
	JSR vdp_generic_mode
	LDA #$00
	STA temp
	STA pointer
	STA pointer+1
	STA temp2
	LDA #$18
	STA temp2+1
	JSR FILVRM
	CLI
	LDA #$f0
	STA temp
	LDA #$00
	STA pointer
	STA temp2
	LDY #$2000>>8
	STY pointer+1
	LDY #$1800>>8
	STY temp2+1
	SEI
	JSR FILVRM
	CLI
	LDA #$1800
	LDY #$1800>>8
	STA pointer
	STY pointer+1
.1:	SEI
	LDA pointer
	LDY pointer+1
	JSR SETWRT
	LDX #32
	LDY pointer
.2:
	TYA		; 2
	STA $3000	; 4
	NOP		; 2
	NOP		; 2
	NOP		; 2
	INY		; 2
	DEX		; 2
	BNE .2		; 2/3/4
	CLI
	LDA pointer
	CLC
	ADC #32
	STA pointer
	BCC .1
	INC pointer+1
	LDA pointer+1
	CMP #$1B
	BNE .1
	JMP vdp_generic_sprites

mode_2:
	LDA mode
	ORA #$08
	STA mode
	LDY #$80	; $2000 for color table.
	LDA #$00	; $0000 for bitmaps
	STA temp+1
	JSR vdp_generic_mode
	JSR LDIRVM
	SEI
	LDA #$f0
	STA temp
	LDA #$00
	STA pointer
	STA temp2+1
	LDY #$2000>>8
	STY pointer+1
	LDA #$20
	STA temp2
	JSR FILVRM
	CLI
	JSR cls
	JMP vdp_generic_sprites

int_handler:
	PHA
	TXA
	PHA
	TYA
	PHA
	LDA $2001	; VDP interruption clear.
	LDA #$1B00
	LDY #$1B00>>8
	JSR SETWRT
	LDA mode
	AND #$04
	BEQ .4
	LDX #0
.7:	LDA sprites,X	; 4
	STA $3000	; 4
	NOP		; 2
	NOP		; 2
	INX		; 2
	CPX #$80	; 2
	BNE .7		; 2/3/4
	JMP .5

.4:	LDA flicker
	CLC
	ADC #4
	AND #$7f
	STA flicker
	TAX
	LDY #31
.6:
	LDA sprites,X
	STA $3000	
	NOP
	NOP
	NOP
	NOP
	NOP
	INX
	LDA sprites,X
	STA $3000
	NOP
	NOP
	NOP
	NOP
	NOP
	INX
	LDA sprites,X
	STA $3000
	NOP
	NOP
	NOP
	NOP
	NOP
	INX
	LDA sprites,X
	STA $3000
	TXA
	CLC
	ADC #25
	AND #$7f
	TAX
	DEY
	BPL .6
.5:
	JSR BIOS_READ_CONTROLLERS

	LDX joy1_dir
	LDA joy1_buttons
	JSR convert_joystick
	STA joy1_data

	LDX joy2_dir
	LDA joy2_buttons
	LSR A
	LSR A
	JSR convert_joystick
	STA joy2_data

	LDX #1
	LDA $18
	CMP #$0C
	BEQ .11
	INX
	LDA $19
	CMP #$30
	BEQ .11
	INX
	CMP #$60
	BEQ .11
	INX
	CMP #$28
	BEQ .11
	INX
	CMP #$48
	BEQ .11
	INX
	CMP #$50
	BEQ .11
	INX
	LDA $1B
	CMP #$06
	BEQ .11
	INX
	CMP #$42
	BEQ .11
	INX
	CMP #$22
	BEQ .11
	LDX #0
	CMP #$12
	BEQ .11
	LDX #11
	CMP #$09
	BEQ .11
	LDA $19
	LDX #10
	CMP #$09
	BEQ .11
	LDX #$0f
.11:	STX key1_data

    if CVBASIC_MUSIC_PLAYER
	LDA music_mode
	BEQ .10
	JSR music_hardware
.10:
    endif
	INC frame
	BNE .8
	INC frame+1
.8:
	INC lfsr	; Make LFSR more random
	INC lfsr
	INC lfsr
    if CVBASIC_MUSIC_PLAYER
	LDA music_mode
	BEQ .9
	JSR music_generate
.9:
    endif
	; This is like saving extra registers, because these
	; are used by the compiled code, and we don't want
	; any reentrancy.
	LDA temp+0
	PHA
	LDA temp+1
	PHA
	LDA temp+2
	PHA
	LDA temp+3
	PHA
	LDA temp+4
	PHA
	LDA temp+5
	PHA
	LDA temp+6
	PHA
	LDA temp+7
	PHA
	PLA
	STA temp+7
	PLA
	STA temp+6
	PLA
	STA temp+5
	PLA
	STA temp+4
	PLA
	STA temp+3
	PLA
	STA temp+2
	PLA
	STA temp+1
	PLA
	STA temp+0

	PLA
	TAY
	PLA
	TAX
	PLA
	RTI

convert_joystick:
	ROR A
	ROR A
	ROR A
	AND #$C0
	TAY
	TXA
	BEQ .1
	AND #$0F
	TAX
;	LDA FRAME
;	AND #1
;	BEQ .2
	TYA
	ORA joystick_table,X
	RTS
;.2:
;	TYA
;	ORA joystick_table+16,X
;	RTS

.1:	TYA
	RTS

joystick_table:
	DB $04,$04,$06,$06,$02,$02,$03,$03
	DB $01,$01,$09,$09,$08,$08,$0C,$0C

;	DB $0C,$04,$04,$06,$06,$02,$02,$03
;	DB $03,$01,$01,$09,$09,$08,$08,$0C

wait:
	LDA frame
.1:	CMP frame
	BEQ .1
	RTS

music_init:
	LDA #$9f
	JSR BIOS_WRITE_PSG	
	LDA #$bf
	JSR BIOS_WRITE_PSG	
	LDA #$df
	JSR BIOS_WRITE_PSG	
	LDA #$ff
	JSR BIOS_WRITE_PSG
    if CVBASIC_MUSIC_PLAYER
    else	
	RTS
    endif

    if CVBASIC_MUSIC_PLAYER
	LDA #$ff
	STA audio_vol4hw
	LDA #$00
	STA audio_control
	LDA #music_silence
	LDY #music_silence>>8
	;
	; Play music.
	; YA = Pointer to music.
	;
music_play:
	SEI
	STA music_pointer
	STY music_pointer+1
	LDY #0
	STY music_note_counter
	LDA (music_pointer),Y
	STA music_timing
	INY
	STY music_playing
	INC music_pointer
	BNE $+4
	INC music_pointer+1
	LDA music_pointer
	LDY music_pointer+1
	STA music_start
	STY music_start+1
	CLI
	RTS

	;
	; Generates music
	;
music_generate:
	LDA #0
	STA audio_vol1
	STA audio_vol2
	STA audio_vol3
	LDA #$FF
	STA audio_vol4hw
	LDA music_note_counter
	BEQ .1
	JMP .2
.1:
	LDY #0
	LDA (music_pointer),Y
	CMP #$fe	; End of music?
	BNE .3		; No, jump.
	LDA #0		; Keep at same place.
	STA music_playing
	RTS

.3:	CMP #$fd	; Repeat music?
	BNE .4
	LDA music_start
	LDY music_start+1
	STA music_pointer
	STY music_pointer+1
	JMP .1

.4:	LDA music_timing
	AND #$3f	; Restart note time.
	STA music_note_counter

	LDA (music_pointer),Y
	CMP #$3F	; Sustain?
	BEQ .5
	AND #$C0
	STA music_instrument_1
	LDA (music_pointer),Y
	AND #$3F
	ASL A
	STA music_note_1
	LDA #0
	STA music_counter_1
.5:
	INY
	LDA (music_pointer),Y
	CMP #$3F	; Sustain?
	BEQ .6
	AND #$C0
	STA music_instrument_2
	LDA (music_pointer),Y
	AND #$3F
	ASL A
	STA music_note_2
	LDA #0
	STA music_counter_2
.6:
	INY
	LDA (music_pointer),Y
	CMP #$3F	; Sustain?
	BEQ .7
	AND #$C0
	STA music_instrument_3
	LDA (music_pointer),Y
	AND #$3F
	ASL A
	STA music_note_3
	LDA #0
	STA music_counter_3
.7:
	INY
	LDA (music_pointer),Y
	STA music_drum
	LDA #0	
	STA music_counter_4
	LDA music_pointer
	CLC
	ADC #4
	STA music_pointer
	LDA music_pointer+1
	ADC #0
	STA music_pointer+1
.2:
	LDY music_note_1
	BEQ .8
	LDA music_instrument_1
	LDX music_counter_1
	JSR music_note2freq
	STA audio_freq1
	STY audio_freq1+1
	STX audio_vol1
.8:
	LDY music_note_2
	BEQ .9
	LDA music_instrument_2
	LDX music_counter_2
	JSR music_note2freq
	STA audio_freq2
	STY audio_freq2+1
	STX audio_vol2
.9:
	LDY music_note_3
	BEQ .10
	LDA music_instrument_3
	LDX music_counter_3
	JSR music_note2freq
	STA audio_freq3
	STY audio_freq3+1
	STX audio_vol3
.10:
	LDA music_drum
	BEQ .11
	CMP #1		; 1 - Long drum.
	BNE .12
	LDA music_counter_4
	CMP #3
	BCS .11
.15:
	LDA #$ec
	STA audio_noise
	LDA #$f5
	STA audio_vol4hw
	JMP .11

.12:	CMP #2		; 2 - Short drum.
	BNE .14
	LDA music_counter_4
	CMP #0
	BNE .11
	LDA #$ed
	STA audio_noise
	LDA #$F5
	STA audio_vol4hw
	JMP .11

.14:	;CMP #3		; 3 - Roll.
	;BNE
	LDA music_counter_4
	CMP #2
	BCC .15
	ASL A
	SEC
	SBC music_timing
	BCC .11
	CMP #4
	BCC .15
.11:
	LDX music_counter_1
	INX
	CPX #$18
	BNE $+4
	LDX #$10
	STX music_counter_1

	LDX music_counter_2
	INX
	CPX #$18
	BNE $+4
	LDX #$10
	STX music_counter_2

	LDX music_counter_3
	INX
	CPX #$18
	BNE $+4
	LDX #$10
	STX music_counter_3

	INC music_counter_4
	DEC music_note_counter
	RTS

music_flute:
	LDA music_notes_table,Y
	CLC
	ADC .2,X
	PHA
	LDA music_notes_table+1,Y
	ADC #0
	TAY
	LDA .1,X
	TAX
	PLA
	RTS

.1:
        db 10,12,13,13,12,12,12,12
        db 11,11,11,11,10,10,10,10
        db 11,11,11,11,10,10,10,10

.2:
	db 0,0,0,0,0,1,1,1
	db 0,1,1,1,0,1,1,1
	db 0,1,1,1,0,1,1,1

	;
	; Converts note to frequency.
	; Input:
	;   A = Instrument.
	;   Y = Note (1-62)
	;   X = Instrument counter.
	; Output:
	;   YA = Frequency.
	;   X = Volume.
	;
music_note2freq:
	CMP #$40
	BCC music_piano
	BEQ music_clarinet
	CMP #$80
	BEQ music_flute
	;
	; Bass instrument
	; 
music_bass:
	LDA music_notes_table,Y
	ASL A
	PHA
	LDA music_notes_table+1,Y
	ROL A
	TAY
	LDA .1,X
	TAX
	PLA
	RTS

.1:
	db 13,13,12,12,11,11,10,10
	db 9,9,8,8,7,7,6,6
	db 5,5,4,4,3,3,2,2

music_piano:
	LDA music_notes_table,Y
	PHA
	LDA music_notes_table+1,Y
	TAY
	LDA .1,X
	TAX
	PLA
	RTS

.1:	db 12,11,11,10,10,9,9,8
	db 8,7,7,6,6,5,5,4
	db 4,4,5,5,4,4,3,3

music_clarinet:
	LDA music_notes_table,Y
	CLC
	ADC .2,X
	PHA
	LDA .2,X
	BMI .3
	LDA #$00
	DB $2C
.3:	LDA #$ff
	ADC music_notes_table+1,Y
	LSR A
	TAY
	LDA .1,X
	TAX
	PLA
	ROR A
	RTS

.1:
        db 13,14,14,13,13,12,12,12
        db 11,11,11,11,12,12,12,12
        db 11,11,11,11,12,12,12,12

.2:
	db 0,0,0,0,-1,-2,-1,0
	db 1,2,1,0,-1,-2,-1,0
	db 1,2,1,0,-1,-2,-1,0

	;
	; Musical notes table.
	;
music_notes_table:
	; Silence - 0
	dw 0
	; Values for 2.00 mhz.
	; 2nd octave - Index 1
	dw 956,902,851,804,758,716,676,638,602,568,536,506
	; 3rd octave - Index 13
	dw 478,451,426,402,379,358,338,319,301,284,268,253
	; 4th octave - Index 25
	dw 239,225,213,201,190,179,169,159,150,142,134,127
	; 5th octave - Index 37
	dw 119,113,106,100,95,89,84,80,75,71,67,63
	; 6th octave - Index 49
	dw 60,56,53,50,47,45,42,40,38,36,34,32
	; 7th octave - Index 61
	dw 30,28,27

music_hardware:
	LDA music_mode
	CMP #4		; PLAY SIMPLE?
	BCC .7		; Yes, jump.
	LDA audio_vol2
	BNE .7
	LDA audio_vol3
	BEQ .7
	STA audio_vol2
	LDA #0
	STA audio_vol3
	LDA audio_freq3
	LDY audio_freq3+1
	STA audio_freq2
	STY audio_freq2+1
.7:
	LDA audio_freq1+1
	CMP #$04
	LDA #$9F
	BCS .1
	LDA audio_freq1
	AND #$0F
	ORA #$80
	JSR BIOS_WRITE_PSG
	LDA audio_freq1+1
	ASL audio_freq1
	ROL A
	ASL audio_freq1
	ROL A
	ASL audio_freq1
	ROL A
	ASL audio_freq1
	ROL A
	JSR BIOS_WRITE_PSG
	LDX audio_vol1
	LDA ay2sn,X
	ORA #$90
.1:	JSR BIOS_WRITE_PSG

	LDA audio_freq2+1
	CMP #$04
	LDA #$BF
	BCS .2
	LDA audio_freq2
	AND #$0F
	ORA #$A0
	JSR BIOS_WRITE_PSG
	LDA audio_freq2+1
	ASL audio_freq2
	ROL A
	ASL audio_freq2
	ROL A
	ASL audio_freq2
	ROL A
	ASL audio_freq2
	ROL A
	JSR BIOS_WRITE_PSG
	LDX audio_vol2
	LDA ay2sn,X
	ORA #$b0
.2:	JSR BIOS_WRITE_PSG

	LDA music_mode
	CMP #4		; PLAY SIMPLE?
	BCC .6		; Yes, jump.

	LDA audio_freq3+1
	CMP #$04
	LDA #$DF
	BCS .3
	LDA audio_freq3
	AND #$0F
	ORA #$C0
	JSR BIOS_WRITE_PSG
	LDA audio_freq3+1
	ASL audio_freq3
	ROL A
	ASL audio_freq3
	ROL A
	ASL audio_freq3
	ROL A
	ASL audio_freq3
	ROL A
	JSR BIOS_WRITE_PSG
	LDX audio_vol3
	LDA ay2sn,X
	ORA #$D0
.3:	JSR BIOS_WRITE_PSG

.6:	LDA music_mode
	LSR A		; NO DRUMS?
	BCC .8
	LDA audio_vol4hw
	CMP #$ff
	BEQ .4
	LDA audio_noise
	CMP audio_control
	BEQ .4
	STA audio_control
	JSR BIOS_WRITE_PSG
.4:	LDA audio_vol4hw
	JSR BIOS_WRITE_PSG
.8:
	RTS

        ;
        ; Converts AY-3-8910 volume to SN76489
        ;
ay2sn:
        db $0f,$0f,$0f,$0e,$0e,$0e,$0d,$0b,$0a,$08,$07,$05,$04,$03,$01,$00

music_silence:
	db 8
	db 0,0,0,0
	db -2
    endif

    if CVBASIC_COMPRESSION
define_char_unpack:
	lda #0
	sta pointer+1
	lda pointer
	asl a
	rol pointer+1
	asl a
	rol pointer+1
	asl a
	rol pointer+1
	sta pointer
	lda mode
	and #$08
	beq unpack3
	bne unpack

define_color_unpack:
	lda #4
	sta pointer+1
	lda pointer
	asl a
	rol pointer+1
	asl a
	rol pointer+1
	asl a
	rol pointer+1
	sta pointer
unpack3:
	jsr .1
	jsr .1
.1:	lda pointer
	pha
	lda pointer+1
	pha
	lda temp
	pha
	lda temp+1
	pha
	jsr unpack
	pla
	sta temp+1
	pla
	sta temp
	pla
	clc
	adc #8
	sta pointer+1
	pla
	sta pointer
	rts

        ;
        ; Pletter-0.5c decompressor (XL2S Entertainment & Team Bomba)
        ; Ported from Z80 original
	; temp = Pointer to source data
	; pointer = Pointer to target VRAM
	; temp2
	; temp2+1
	; result
	; result+1
	; pletter_off
	; pletter_off+1
	;
unpack:
	; Initialization
	ldy #0
	sty temp2
	lda (temp),y
	inc temp
	bne $+4
	inc temp+1
	asl a
	rol temp2
	adc #1
	asl a
	rol temp2
	asl a
	sta pletter_bit
	rol temp2
	rol temp2
	lda #.modes
	adc temp2
	sta temp2
	lda #.modes>>8
	adc #0
	sta temp2+1
	lda (temp2),y
	tax
	iny
	lda (temp2),y
	stx temp2	; IX (temp2)
	sta temp2+1
	lda pletter_bit
.literal:
	sta pletter_bit
	ldy #0
	lda (temp),y
	inc temp
	bne $+4
	inc temp+1
	tax
	lda pointer
	ldy pointer+1
	sei
	jsr WRTVRM
	cli
	inc pointer
	bne $+4
	inc pointer+1
	lda pletter_bit
.loop:
	asl a
	bne $+5
	jsr .getbit
	bcc .literal

	; Compressed data
	ldx #1
	stx result
	dex
	stx result+1
.getlen:
	asl a
	bne $+5
	jsr .getbit
	bcc .lenok
.lus:	asl a
	bne $+5
	jsr .getbit
	rol result
	rol result+1
	bcc $+3
	rts
	asl a
	bne $+5
	jsr .getbit
	bcc .lenok
	asl a
	bne $+5
	jsr .getbit
	rol result
	rol result+1
	bcc $+3
	rts
	asl a
	bne $+5
	jsr .getbit
	bcs .lus
.lenok:
	inc result
	bne $+4
	inc result+1
	sta pletter_bit
	ldy #0
	sty pletter_off+1
	lda (temp),y
	inc temp
	bne $+4
	inc temp+1
	sta pletter_off
	lda pletter_off
	bpl .offsok
	lda pletter_bit
	jmp (temp2)
	
.mode6:
	asl a
	bne $+5
	jsr .getbit
	rol pletter_off+1
.mode5:
	asl a
	bne $+5
	jsr .getbit
	rol pletter_off+1
.mode4:
	asl a
	bne $+5
	jsr .getbit
	rol pletter_off+1
.mode3:
	asl a
	bne $+5
	jsr .getbit
	rol pletter_off+1
.mode2:
	asl a
	bne $+5
	jsr .getbit
	rol pletter_off+1
	asl a
	bne $+5
	jsr .getbit
	sta pletter_bit
	bcc .offsok
	inc pletter_off+1
	lda pletter_off
	and #$7f
	sta pletter_off
.offsok:
	inc pletter_off
	bne $+4
	inc pletter_off+1

	lda result
	beq $+4
	inc result+1

	lda pointer
	sec
	sbc pletter_off
	sta pletter_off
	lda pointer+1
	sbc pletter_off+1
	sta pletter_off+1
.loop2:
	sei
	lda pletter_off
	ldy pletter_off+1
	jsr RDVRM
	tax
	lda pointer
	ldy pointer+1
	jsr WRTVRM
	cli
	inc pletter_off
	bne $+4
	inc pletter_off+1
	inc pointer
	bne $+4
	inc pointer+1
	dec result
	bne .loop2
	dec result+1
	bne .loop2

	lda pletter_bit
	jmp .loop

.getbit:
	ldy #0
	lda (temp),y
	inc temp
	bne $+4
	inc temp+1
	rol a
	rts

.modes:
	dw .offsok
	dw .mode2
	dw .mode3
	dw .mode4
	dw .mode5
	dw .mode6
    endif

	; Required for Creativision because it doesn't provide an ASCII charset.
	;
        ; My personal font for TMS9928.
        ;
        ; Patterned after the TMS9928 programming manual 6x8 letters
        ; with better lowercase letters, also I made a proper
        ; AT sign.
        ;
font_bitmaps:
        db $00,$00,$00,$00,$00,$00,$00,$00      ; $20 space
        db $20,$20,$20,$20,$20,$00,$20,$00      ; $21 !
        db $50,$50,$50,$00,$00,$00,$00,$00      ; $22 "
        db $50,$50,$f8,$50,$f8,$50,$50,$00      ; $23 #
        db $20,$78,$a0,$70,$28,$f0,$20,$00      ; $24 $
        db $c0,$c8,$10,$20,$40,$98,$18,$00      ; $25 %
        db $40,$a0,$40,$a0,$a8,$90,$68,$00      ; $26 &
        db $60,$20,$40,$00,$00,$00,$00,$00      ; $27 '
        db $10,$20,$40,$40,$40,$20,$10,$00      ; $28 (
        db $40,$20,$10,$10,$10,$20,$40,$00      ; $29 )
        db $00,$a8,$70,$20,$70,$a8,$00,$00      ; $2a *
        db $00,$20,$20,$f8,$20,$20,$00,$00      ; $2b +
        db $00,$00,$00,$00,$00,$60,$20,$40      ; $2c ,
        db $00,$00,$00,$fc,$00,$00,$00,$00      ; $2d -
        db $00,$00,$00,$00,$00,$00,$60,$00      ; $2e .
        db $00,$08,$10,$20,$40,$80,$00,$00      ; $2f /
        db $70,$88,$98,$a8,$c8,$88,$70,$00      ; $30 0
        db $20,$60,$20,$20,$20,$20,$f8,$00      ; $31 1
        db $70,$88,$08,$10,$60,$80,$f8,$00      ; $32 2
        db $70,$88,$08,$30,$08,$88,$70,$00      ; $33 3
        db $30,$50,$90,$90,$f8,$10,$10,$00      ; $34 4
        db $f8,$80,$f0,$08,$08,$08,$f0,$00      ; $35 5
        db $30,$40,$80,$f0,$88,$88,$70,$00      ; $36 6
        db $f8,$08,$10,$20,$20,$20,$20,$00      ; $37 7
        db $70,$88,$88,$70,$88,$88,$70,$00      ; $38 8
        db $70,$88,$88,$78,$08,$10,$60,$00      ; $39 9
        db $00,$00,$00,$60,$00,$60,$00,$00      ; $3a :
        db $00,$00,$00,$60,$00,$60,$20,$40      ; $3b ;
        db $10,$20,$40,$80,$40,$20,$10,$00      ; $3c <
        db $00,$00,$f8,$00,$f8,$00,$00,$00      ; $3d =
        db $08,$04,$02,$01,$02,$04,$08,$00      ; $3e >
        db $70,$88,$08,$10,$20,$00,$20,$00      ; $3f ?
        db $70,$88,$98,$a8,$98,$80,$70,$00      ; $40 @
        db $20,$50,$88,$88,$f8,$88,$88,$00      ; $41 A
        db $f0,$88,$88,$f0,$88,$88,$f0,$00      ; $42 B
        db $70,$88,$80,$80,$80,$88,$70,$00      ; $43 C
        db $f0,$88,$88,$88,$88,$88,$f0,$00      ; $44 D
        db $f8,$80,$80,$f0,$80,$80,$f8,$00      ; $45 E
        db $f8,$80,$80,$f0,$80,$80,$80,$00      ; $46 F
        db $70,$88,$80,$b8,$88,$88,$70,$00      ; $47 G
        db $88,$88,$88,$f8,$88,$88,$88,$00      ; $48 H
        db $70,$20,$20,$20,$20,$20,$70,$00      ; $49 I
        db $08,$08,$08,$08,$88,$88,$70,$00      ; $4A J
        db $88,$90,$a0,$c0,$a0,$90,$88,$00      ; $4B K
        db $80,$80,$80,$80,$80,$80,$f8,$00      ; $4C L
        db $88,$d8,$a8,$a8,$88,$88,$88,$00      ; $4D M
        db $88,$c8,$c8,$a8,$98,$98,$88,$00      ; $4E N
        db $70,$88,$88,$88,$88,$88,$70,$00      ; $4F O
        db $f0,$88,$88,$f0,$80,$80,$80,$00      ; $50 P
        db $70,$88,$88,$88,$88,$a8,$90,$68      ; $51 Q
        db $f0,$88,$88,$f0,$a0,$90,$88,$00      ; $52 R
        db $70,$88,$80,$70,$08,$88,$70,$00      ; $53 S
        db $f8,$20,$20,$20,$20,$20,$20,$00      ; $54 T
        db $88,$88,$88,$88,$88,$88,$70,$00      ; $55 U
        db $88,$88,$88,$88,$50,$50,$20,$00      ; $56 V
        db $88,$88,$88,$a8,$a8,$d8,$88,$00      ; $57 W
        db $88,$88,$50,$20,$50,$88,$88,$00      ; $58 X
        db $88,$88,$88,$70,$20,$20,$20,$00      ; $59 Y
        db $f8,$08,$10,$20,$40,$80,$f8,$00      ; $5A Z
        db $78,$60,$60,$60,$60,$60,$78,$00      ; $5B [
        db $00,$80,$40,$20,$10,$08,$00,$00      ; $5C \
        db $F0,$30,$30,$30,$30,$30,$F0,$00      ; $5D ]
        db $20,$50,$88,$00,$00,$00,$00,$00      ; $5E 
        db $00,$00,$00,$00,$00,$00,$f8,$00      ; $5F _
        db $40,$20,$10,$00,$00,$00,$00,$00      ; $60 
        db $00,$00,$68,$98,$88,$98,$68,$00      ; $61 a
        db $80,$80,$f0,$88,$88,$88,$f0,$00      ; $62 b
        db $00,$00,$78,$80,$80,$80,$78,$00      ; $63 c
        db $08,$08,$68,$98,$88,$98,$68,$00      ; $64 d
        db $00,$00,$70,$88,$f8,$80,$70,$00      ; $65 e
        db $30,$48,$40,$e0,$40,$40,$40,$00      ; $66 f
        db $00,$00,$78,$88,$88,$78,$08,$70      ; $67 g
        db $80,$80,$f0,$88,$88,$88,$88,$00      ; $68 h
        db $20,$00,$60,$20,$20,$20,$70,$00      ; $69 i
        db $08,$00,$18,$08,$88,$88,$70,$00      ; $6a j
        db $80,$80,$88,$90,$e0,$90,$88,$00      ; $6b k
        db $60,$20,$20,$20,$20,$20,$70,$00      ; $6c l
        db $00,$00,$d0,$a8,$a8,$a8,$a8,$00      ; $6d m
        db $00,$00,$b0,$c8,$88,$88,$88,$00      ; $6e n
        db $00,$00,$70,$88,$88,$88,$70,$00      ; $6f o
        db $00,$00,$f0,$88,$88,$88,$f0,$80      ; $70 p
        db $00,$00,$78,$88,$88,$88,$78,$08      ; $71 q
        db $00,$00,$b8,$c0,$80,$80,$80,$00      ; $72 r
        db $00,$00,$78,$80,$70,$08,$f0,$00      ; $73 s
        db $20,$20,$f8,$20,$20,$20,$20,$00      ; $74 t
        db $00,$00,$88,$88,$88,$98,$68,$00      ; $75 u
        db $00,$00,$88,$88,$88,$50,$20,$00      ; $76 v
        db $00,$00,$88,$a8,$a8,$a8,$50,$00      ; $77 w
        db $00,$00,$88,$50,$20,$50,$88,$00      ; $78 x
        db $00,$00,$88,$88,$98,$68,$08,$70      ; $79 y
        db $00,$00,$f8,$10,$20,$40,$f8,$00      ; $7a z
        db $18,$20,$20,$40,$20,$20,$18,$00      ; $7b {
        db $20,$20,$20,$20,$20,$20,$20,$00      ; $7c |
        db $c0,$20,$20,$10,$20,$20,$c0,$00      ; $7d } 
        db $00,$00,$40,$a8,$10,$00,$00,$00      ; $7e
        db $70,$70,$20,$f8,$20,$70,$50,$00      ; $7f

START:
	SEI
	CLD

	LDA #$00
	TAX
.1:	STA $0100,X
	STA $0200,X
	STA $0300,X
	INX
	BNE .1

	LDX #STACK
	TXS
	LDA $2001
	LDA #$82
	LDX #$01
	JSR WRTVDP
	LDA $2001
	LDA #$82
	LDX #$01
	JSR WRTVDP

	JSR music_init

	JSR mode_0

	LDA #$00
	STA joy1_data
	STA joy2_data
	LDA #$0F
	STA key1_data
	STA key2_data

cvb_C:	equ $0050
cvb_D:	equ $0051
cvb_BULLET_X:	equ $0052
cvb_BULLET_Y:	equ $0053
cvb_PLAYER_X:	equ $0054
cvb_PLAYER_Y:	equ $0055
cvb_#C:	equ $0056
cvb_#SCORE:	equ $0058
array_ENEMY_S:	equ $005a
array_ENEMY_X:	equ $0062
array_ENEMY_Y:	equ $006a
ram_end:
	; 	'
	; 	' Space Attack (demo for CVBasic)
	; 	'
	; 	' by Oscar Toledo G.
	; 	' https://nanochess.org/
	; 	'
	; 	' Creation date: Feb/29/2024.
	; 	'
	; 
	; 	DEFINE SPRITE 0,4,sprites_bitmaps
	LDA #0
	TAY
	STA pointer
	LDA #4
	PHA
	LDA #cvb_SPRITES_BITMAPS
	STA temp
	LDA #cvb_SPRITES_BITMAPS>>8
	STA temp+1
	PLA
	JSR define_sprite
	; 
	; 	DIM enemy_x(8)
	; 	DIM enemy_y(8)
	; 	DIM enemy_s(8)
	; 
	; restart_game:
cvb_RESTART_GAME:
	; 	CLS
	JSR cls
	; 
	; 	#score = 0
	LDA #0
	TAY
	STA cvb_#SCORE
	STY cvb_#SCORE+1
	; 
	; 	GOSUB update_score
	JSR cvb_UPDATE_SCORE
	; 
	; 	player_x = 120
	LDA #120
	STA cvb_PLAYER_X
	; 	player_y = 176
	LDA #176
	STA cvb_PLAYER_Y
	; 	bullet_y = 0
	LDA #0
	STA cvb_BULLET_Y
	; 	FOR c = 0 TO 7
	LDA #0
	STA cvb_C
cv1:
	; 		enemy_s(c) = 0
	LDA #array_ENEMY_S
	CLC
	ADC cvb_C
	TAX
	LDA #array_ENEMY_S>>8
	ADC #0
	TAY
	TXA
	STA temp
	STY temp+1
	LDA #0
	TAY
	STA (temp),Y
	; 	NEXT c
	INC cvb_C
	LDA cvb_C
	CMP #8
	BCC.L cv1
	; 
	; game_loop:
cvb_GAME_LOOP:
	; 	WAIT
	JSR wait
	; 
	; 	' Background "music" (two tones alternating each 16 video frames)
	; 	#c = 960
	LDA #192
	LDY #3
	STA cvb_#C
	STY cvb_#C+1
	; 	IF FRAME AND 16 THEN #c = 1023
	LDA frame
	LDY frame+1
	AND #16
	LDY #0
	STY temp
	ORA temp
	BEQ.L cv2
	LDA #255
	LDY #3
	STA cvb_#C
	STY cvb_#C+1
cv2:
	; 	SOUND 0,#c,15-(FRAME AND 15)
	LDA cvb_#C
	LDY cvb_#C+1
	LDX #128
	JSR sn76489_freq
	LDA #15
	LDY #0
	PHA
	TYA
	PHA
	LDA frame
	LDY frame+1
	AND #15
	LDY #0
	STA temp
	STY temp+1
	PLA
	TAY
	PLA
	SEC
	SBC temp
	TAX
	TYA
	SBC temp+1
	TAY
	TXA
	LDX #144
	JSR sn76489_vol
	; 
	; 	' Setup player sprite
	; 	SPRITE 0,player_y-1,player_x,0,10
	LDA #0
	PHA
	LDA cvb_PLAYER_Y
	SEC
	SBC #1
	STA sprite_data
	LDA cvb_PLAYER_X
	STA sprite_data+1
	LDA #0
	STA sprite_data+2
	LDA #10
	STA sprite_data+3
	PLA
	JSR update_sprite
	; 
	; 	' Setup bullet sprite
	; 	IF bullet_y = 0 THEN	' Active?
	LDA cvb_BULLET_Y
	BNE.L cv3
	; 		SPRITE 1,$d1,0,0,0	' No, remove sprite.
	LDA #1
	PHA
	LDA #209
	STA sprite_data
	LDA #0
	STA sprite_data+1
	LDA #0
	STA sprite_data+2
	LDA #0
	STA sprite_data+3
	PLA
	JSR update_sprite
	; 		SOUND 1,,0		' Disable sound.
	LDA #0
	LDX #176
	JSR sn76489_vol
	; 	ELSE
	JMP cv4
cv3:
	; 		SPRITE 1,bullet_y-1,bullet_x,8,7	' Setup sprite.
	LDA #1
	PHA
	LDA cvb_BULLET_Y
	SEC
	SBC #1
	STA sprite_data
	LDA cvb_BULLET_X
	STA sprite_data+1
	LDA #8
	STA sprite_data+2
	LDA #7
	STA sprite_data+3
	PLA
	JSR update_sprite
	; 		bullet_y = bullet_y - 4	' Displace bullet.
	LDA cvb_BULLET_Y
	SEC
	SBC #4
	STA cvb_BULLET_Y
	; 		SOUND 1,bullet_y+16,11	' Make sound.
	LDA cvb_BULLET_Y
	LDY #0
	CLC
	ADC #16
	TAX
	TYA
	ADC #0
	TAY
	TXA
	LDX #160
	JSR sn76489_freq
	LDA #11
	LDX #176
	JSR sn76489_vol
	; 	END IF
cv4:
	; 
	; 	'
	; 	' Display and move the enemies.
	; 	'
	; 	FOR c = 0 TO 7
	LDA #0
	STA cvb_C
cv5:
	; 		IF enemy_s(c) = 0 THEN	' No enemy
	LDA #array_ENEMY_S
	CLC
	ADC cvb_C
	TAX
	LDA #array_ENEMY_S>>8
	ADC #0
	TAY
	TXA
	JSR _peek8
	CMP #0
	BNE.L cv6
	; 			SPRITE c + 2, $d1, 0, 0, 0
	LDA cvb_C
	CLC
	ADC #2
	PHA
	LDA #209
	STA sprite_data
	LDA #0
	STA sprite_data+1
	LDA #0
	STA sprite_data+2
	LDA #0
	STA sprite_data+3
	PLA
	JSR update_sprite
	; 			' Create one
	; 			enemy_x(c) = RANDOM(240)
	JSR random
	PHA
	TYA
	PHA
	LDA #240
	LDY #0
	STA temp
	STY temp+1
	JSR _mod16
	PHA
	LDA #array_ENEMY_X
	CLC
	ADC cvb_C
	TAX
	LDA #array_ENEMY_X>>8
	ADC #0
	TAY
	TXA
	STA temp
	STY temp+1
	PLA
	LDY #0
	STA (temp),Y
	; 			enemy_y(c) = $c0 + c * 4
	LDA #array_ENEMY_Y
	CLC
	ADC cvb_C
	TAX
	LDA #array_ENEMY_Y>>8
	ADC #0
	TAY
	TXA
	STA temp
	STY temp+1
	LDA cvb_C
	ASL A
	ASL A
	CLC
	ADC #192
	LDY #0
	STA (temp),Y
	; 			enemy_s(c) = 1
	LDA #array_ENEMY_S
	CLC
	ADC cvb_C
	TAX
	LDA #array_ENEMY_S>>8
	ADC #0
	TAY
	TXA
	STA temp
	STY temp+1
	LDA #1
	LDY #0
	STA (temp),Y
	; 		ELSEIF enemy_s(c) = 1 THEN	' Enemy moving.
	JMP cv7
cv6:
	LDA #array_ENEMY_S
	CLC
	ADC cvb_C
	TAX
	LDA #array_ENEMY_S>>8
	ADC #0
	TAY
	TXA
	JSR _peek8
	CMP #1
	BNE.L cv8
	; 			SPRITE c + 2, enemy_y(c) - 1, enemy_x(c), 4, 2
	LDA cvb_C
	CLC
	ADC #2
	PHA
	LDA #array_ENEMY_Y
	CLC
	ADC cvb_C
	TAX
	LDA #array_ENEMY_Y>>8
	ADC #0
	TAY
	TXA
	JSR _peek8
	SEC
	SBC #1
	STA sprite_data
	LDA #array_ENEMY_X
	CLC
	ADC cvb_C
	TAX
	LDA #array_ENEMY_X>>8
	ADC #0
	TAY
	TXA
	JSR _peek8
	STA sprite_data+1
	LDA #4
	STA sprite_data+2
	LDA #2
	STA sprite_data+3
	PLA
	JSR update_sprite
	; 
	; 			' Slowly drift towards the player.
	; 			IF (FRAME AND 3) = 0 THEN
	LDA frame
	LDY frame+1
	AND #3
	LDY #0
	STY temp
	ORA temp
	BNE.L cv9
	; 				IF player_x < enemy_x(c) THEN
	LDA cvb_PLAYER_X
	PHA
	LDA #array_ENEMY_X
	CLC
	ADC cvb_C
	TAX
	LDA #array_ENEMY_X>>8
	ADC #0
	TAY
	TXA
	JSR _peek8
	STA temp
	PLA
	CMP temp
	BCS.L cv10
	; 					enemy_x(c) = enemy_x(c) - 1
	LDA #array_ENEMY_X
	CLC
	ADC cvb_C
	STA temp
	LDA #array_ENEMY_X>>8
	ADC #0
	STA temp+1
	LDY #0
	LDA (temp),Y
	SEC
	SBC #1
	STA (temp),Y
	; 				ELSE
	JMP cv11
cv10:
	; 					enemy_x(c) = enemy_x(c) + 1
	LDA #array_ENEMY_X
	CLC
	ADC cvb_C
	STA temp
	LDA #array_ENEMY_X>>8
	ADC #0
	STA temp+1
	LDY #0
	LDA (temp),Y
	CLC
	ADC #1
	STA (temp),Y
	; 				END IF
cv11:
	; 			END IF
cv9:
	; 			' Move down.
	; 			enemy_y(c) = enemy_y(c) + 2
	LDA #array_ENEMY_Y
	CLC
	ADC cvb_C
	STA temp
	LDA #array_ENEMY_Y>>8
	ADC #0
	STA temp+1
	LDY #0
	LDA (temp),Y
	CLC
	ADC #2
	STA (temp),Y
	; 			IF enemy_y(c) = $c0 THEN	' Reached frontier.
	LDA #array_ENEMY_Y
	CLC
	ADC cvb_C
	TAX
	LDA #array_ENEMY_Y>>8
	ADC #0
	TAY
	TXA
	JSR _peek8
	CMP #192
	BNE.L cv12
	; 				enemy_x(c) = RANDOM(240)
	JSR random
	PHA
	TYA
	PHA
	LDA #240
	LDY #0
	STA temp
	STY temp+1
	JSR _mod16
	PHA
	LDA #array_ENEMY_X
	CLC
	ADC cvb_C
	TAX
	LDA #array_ENEMY_X>>8
	ADC #0
	TAY
	TXA
	STA temp
	STY temp+1
	PLA
	LDY #0
	STA (temp),Y
	; 				enemy_y(c) = $f2	' Reset enemy.
	LDA #array_ENEMY_Y
	CLC
	ADC cvb_C
	TAX
	LDA #array_ENEMY_Y>>8
	ADC #0
	TAY
	TXA
	STA temp
	STY temp+1
	LDA #242
	LDY #0
	STA (temp),Y
	; 			END IF
cv12:
	; 
	; 			'
	; 			' Check if bullet has been launched.
	; 			'
	; 			IF bullet_y <> 0 THEN	' Is bullet launched?
	LDA cvb_BULLET_Y
	BEQ.L cv13
	; 				IF ABS(bullet_x + 1 - enemy_x(c)) < 8 THEN
	LDA cvb_BULLET_X
	LDY #0
	CLC
	ADC #1
	TAX
	TYA
	ADC #0
	TAY
	TXA
	PHA
	TYA
	PHA
	LDA #array_ENEMY_X
	CLC
	ADC cvb_C
	TAX
	LDA #array_ENEMY_X>>8
	ADC #0
	TAY
	TXA
	JSR _peek8
	LDY #0
	STA temp
	STY temp+1
	PLA
	TAY
	PLA
	SEC
	SBC temp
	TAX
	TYA
	SBC temp+1
	TAY
	TXA
	JSR _abs16
	SEC
	SBC #8
	TYA
	SBC #0
	BCS.L cv14
	; 					IF ABS(bullet_y + 1 - enemy_y(c)) < 8 THEN
	LDA cvb_BULLET_Y
	LDY #0
	CLC
	ADC #1
	TAX
	TYA
	ADC #0
	TAY
	TXA
	PHA
	TYA
	PHA
	LDA #array_ENEMY_Y
	CLC
	ADC cvb_C
	TAX
	LDA #array_ENEMY_Y>>8
	ADC #0
	TAY
	TXA
	JSR _peek8
	LDY #0
	STA temp
	STY temp+1
	PLA
	TAY
	PLA
	SEC
	SBC temp
	TAX
	TYA
	SBC temp+1
	TAY
	TXA
	JSR _abs16
	SEC
	SBC #8
	TYA
	SBC #0
	BCS.L cv15
	; 						enemy_s(c) = 2	' Enemy explodes
	LDA #array_ENEMY_S
	CLC
	ADC cvb_C
	TAX
	LDA #array_ENEMY_S>>8
	ADC #0
	TAY
	TXA
	STA temp
	STY temp+1
	LDA #2
	LDY #0
	STA (temp),Y
	; 						#score = #score + 1
	INC cvb_#SCORE
	BNE cv16
	INC cvb_#SCORE+1
cv16:
	; 						GOSUB update_score
	JSR cvb_UPDATE_SCORE
	; 						bullet_y = 0
	LDA #0
	STA cvb_BULLET_Y
	; 						sound 2,2	' Start enemy explosion sound
	LDA #2
	LDY #0
	LDX #192
	JSR sn76489_freq
	; 						SOUND 3,$E7,13
	LDA #231
	JSR sn76489_control
	LDA #13
	LDX #240
	JSR sn76489_vol
	; 					END IF
cv15:
	; 				END IF
cv14:
	; 			END IF
cv13:
	; 
	; 			'
	; 			' Check if player is hit by enemy.
	; 			'
	; 			IF ABS(player_y + 1 - enemy_y(c)) < 8 THEN
	LDA cvb_PLAYER_Y
	LDY #0
	CLC
	ADC #1
	TAX
	TYA
	ADC #0
	TAY
	TXA
	PHA
	TYA
	PHA
	LDA #array_ENEMY_Y
	CLC
	ADC cvb_C
	TAX
	LDA #array_ENEMY_Y>>8
	ADC #0
	TAY
	TXA
	JSR _peek8
	LDY #0
	STA temp
	STY temp+1
	PLA
	TAY
	PLA
	SEC
	SBC temp
	TAX
	TYA
	SBC temp+1
	TAY
	TXA
	JSR _abs16
	SEC
	SBC #8
	TYA
	SBC #0
	BCS.L cv17
	; 				IF ABS(player_x + 1 - enemy_x(c)) < 8 THEN
	LDA cvb_PLAYER_X
	LDY #0
	CLC
	ADC #1
	TAX
	TYA
	ADC #0
	TAY
	TXA
	PHA
	TYA
	PHA
	LDA #array_ENEMY_X
	CLC
	ADC cvb_C
	TAX
	LDA #array_ENEMY_X>>8
	ADC #0
	TAY
	TXA
	JSR _peek8
	LDY #0
	STA temp
	STY temp+1
	PLA
	TAY
	PLA
	SEC
	SBC temp
	TAX
	TYA
	SBC temp+1
	TAY
	TXA
	JSR _abs16
	SEC
	SBC #8
	TYA
	SBC #0
	BCS.L cv18
	; 					GOTO player_dies
	JMP cvb_PLAYER_DIES
	; 				END IF
cv18:
	; 			END IF
cv17:
	; 		ELSE
	JMP cv7
cv8:
	; 			' Enemy explosion.
	; 			IF FRAME AND 4 THEN d = 10 ELSE d = 6
	LDA frame
	LDY frame+1
	AND #4
	LDY #0
	STY temp
	ORA temp
	BEQ.L cv19
	LDA #10
	STA cvb_D
	JMP cv20
cv19:
	LDA #6
	STA cvb_D
cv20:
	; 			SPRITE c + 2, enemy_y(c) - 1, enemy_x(c), 12, d
	LDA cvb_C
	CLC
	ADC #2
	PHA
	LDA #array_ENEMY_Y
	CLC
	ADC cvb_C
	TAX
	LDA #array_ENEMY_Y>>8
	ADC #0
	TAY
	TXA
	JSR _peek8
	SEC
	SBC #1
	STA sprite_data
	LDA #array_ENEMY_X
	CLC
	ADC cvb_C
	TAX
	LDA #array_ENEMY_X>>8
	ADC #0
	TAY
	TXA
	JSR _peek8
	STA sprite_data+1
	LDA #12
	STA sprite_data+2
	LDA cvb_D
	STA sprite_data+3
	PLA
	JSR update_sprite
	; 
	; 			' Displace explosion slowly.
	; 			IF FRAME AND 1 THEN
	LDA frame
	LDY frame+1
	AND #1
	LDY #0
	STY temp
	ORA temp
	BEQ.L cv21
	; 				IF enemy_y(c) < $c0 THEN enemy_y(c) = enemy_y(c) + 1
	LDA #array_ENEMY_Y
	CLC
	ADC cvb_C
	TAX
	LDA #array_ENEMY_Y>>8
	ADC #0
	TAY
	TXA
	JSR _peek8
	CMP #192
	BCS.L cv22
	LDA #array_ENEMY_Y
	CLC
	ADC cvb_C
	STA temp
	LDA #array_ENEMY_Y>>8
	ADC #0
	STA temp+1
	LDY #0
	LDA (temp),Y
	CLC
	ADC #1
	STA (temp),Y
cv22:
	; 			END IF		
cv21:
	; 
	; 			' Explosion sound.
	; 			SOUND 2,enemy_s(c)		
	LDA #array_ENEMY_S
	CLC
	ADC cvb_C
	TAX
	LDA #array_ENEMY_S>>8
	ADC #0
	TAY
	TXA
	JSR _peek8
	LDY #0
	LDX #192
	JSR sn76489_freq
	; 			enemy_s(c) = enemy_s(c) + 1
	LDA #array_ENEMY_S
	CLC
	ADC cvb_C
	STA temp
	LDA #array_ENEMY_S>>8
	ADC #0
	STA temp+1
	LDY #0
	LDA (temp),Y
	CLC
	ADC #1
	STA (temp),Y
	; 			IF enemy_s(c) = 80 THEN	' Time reached.
	LDA #array_ENEMY_S
	CLC
	ADC cvb_C
	TAX
	LDA #array_ENEMY_S>>8
	ADC #0
	TAY
	TXA
	JSR _peek8
	CMP #80
	BNE.L cv23
	; 				SOUND 3,,0
	LDA #0
	LDX #240
	JSR sn76489_vol
	; 				enemy_x(c) = RANDOM(240)
	JSR random
	PHA
	TYA
	PHA
	LDA #240
	LDY #0
	STA temp
	STY temp+1
	JSR _mod16
	PHA
	LDA #array_ENEMY_X
	CLC
	ADC cvb_C
	TAX
	LDA #array_ENEMY_X>>8
	ADC #0
	TAY
	TXA
	STA temp
	STY temp+1
	PLA
	LDY #0
	STA (temp),Y
	; 				enemy_y(c) = $f2
	LDA #array_ENEMY_Y
	CLC
	ADC cvb_C
	TAX
	LDA #array_ENEMY_Y>>8
	ADC #0
	TAY
	TXA
	STA temp
	STY temp+1
	LDA #242
	LDY #0
	STA (temp),Y
	; 				enemy_s(c) = 1	' Bring back enemy.
	LDA #array_ENEMY_S
	CLC
	ADC cvb_C
	TAX
	LDA #array_ENEMY_S>>8
	ADC #0
	TAY
	TXA
	STA temp
	STY temp+1
	LDA #1
	LDY #0
	STA (temp),Y
	; 			END IF
cv23:
	; 		END IF
cv7:
	; 	NEXT c
	INC cvb_C
	LDA cvb_C
	CMP #8
	BCC.L cv5
	; 
	; 	'
	; 	' Movement of the player.
	; 	'
	; 	IF cont1.left THEN IF player_x > 0 THEN player_x = player_x - 2
	LDA joy1_data
	AND #8
	BEQ.L cv24
	LDA cvb_PLAYER_X
	CMP #1
	BCC.L cv25
	DEC cvb_PLAYER_X
	DEC cvb_PLAYER_X
cv25:
cv24:
	; 	IF cont1.right THEN IF player_x < 240 THEN player_x = player_x + 2
	LDA joy1_data
	AND #2
	BEQ.L cv26
	LDA cvb_PLAYER_X
	CMP #240
	BCS.L cv27
	INC cvb_PLAYER_X
	INC cvb_PLAYER_X
cv27:
cv26:
	; 	IF cont1.button THEN	' Fire!
	LDA joy1_data
	AND #64
	BEQ.L cv28
	; 		IF bullet_y = 0 THEN	' Only if no bullet active.
	LDA cvb_BULLET_Y
	BNE.L cv29
	; 			bullet_y = player_y - 8
	LDA cvb_PLAYER_Y
	SEC
	SBC #8
	STA cvb_BULLET_Y
	; 			bullet_x = player_x
	LDA cvb_PLAYER_X
	STA cvb_BULLET_X
	; 		END IF
cv29:
	; 	END IF
cv28:
	; 	GOTO game_loop
	JMP cvb_GAME_LOOP
	; 
	; 	'
	; 	' Player dies.
	; 	'
	; player_dies:
cvb_PLAYER_DIES:
	; 	PRINT AT 11,"GAME OVER"
	JSR print_string_cursor_constant
	DB $0b,$00,$09
	DB $47,$41,$4d,$45,$20,$4f,$56,$45
	DB $52
	; 
	; 	'
	; 	' Explosion effect and sound.
	; 	'
	; 	SOUND 0,,0
	LDA #0
	LDX #144
	JSR sn76489_vol
	; 	SOUND 1,,0
	LDA #0
	LDX #176
	JSR sn76489_vol
	; 	SOUND 2,32,0
	LDA #32
	LDY #0
	LDX #192
	JSR sn76489_freq
	LDA #0
	LDX #208
	JSR sn76489_vol
	; 	FOR c = 0 TO 120
	LDA #0
	STA cvb_C
cv30:
	; 		WAIT
	JSR wait
	; 		SOUND 3,$E4 + (c AND 3),13
	LDA cvb_C
	AND #3
	CLC
	ADC #228
	JSR sn76489_control
	LDA #13
	LDX #240
	JSR sn76489_vol
	; 		SPRITE 0, player_y - 1 + RANDOM(5) - 2, player_x + RANDOM(5) - 2, 12, RANDOM(14) + 2
	LDA #0
	PHA
	LDA cvb_PLAYER_Y
	LDY #0
	SEC
	SBC #1
	TAX
	TYA
	SBC #0
	TAY
	TXA
	PHA
	TYA
	PHA
	JSR random
	PHA
	TYA
	PHA
	LDA #5
	LDY #0
	STA temp
	STY temp+1
	JSR _mod16
	STA temp
	STY temp+1
	PLA
	TAY
	PLA
	CLC
	ADC temp
	TAX
	TYA
	ADC temp+1
	TAY
	TXA
	SEC
	SBC #2
	STA sprite_data
	LDA cvb_PLAYER_X
	LDY #0
	PHA
	TYA
	PHA
	JSR random
	PHA
	TYA
	PHA
	LDA #5
	LDY #0
	STA temp
	STY temp+1
	JSR _mod16
	STA temp
	STY temp+1
	PLA
	TAY
	PLA
	CLC
	ADC temp
	TAX
	TYA
	ADC temp+1
	TAY
	TXA
	SEC
	SBC #2
	STA sprite_data+1
	LDA #12
	STA sprite_data+2
	JSR random
	PHA
	TYA
	PHA
	LDA #14
	LDY #0
	STA temp
	STY temp+1
	JSR _mod16
	CLC
	ADC #2
	STA sprite_data+3
	PLA
	JSR update_sprite
	; 	NEXT c
	INC cvb_C
	LDA cvb_C
	CMP #121
	BCC.L cv30
	; 	SOUND 3,,0
	LDA #0
	LDX #240
	JSR sn76489_vol
	; 
	; 	'
	; 	' Remove enemies.
	; 	'
	; 	FOR c = 1 TO 9
	LDA #1
	STA cvb_C
cv31:
	; 		SPRITE c, $d1, 0, 0, 0
	LDA cvb_C
	PHA
	LDA #209
	STA sprite_data
	LDA #0
	STA sprite_data+1
	LDA #0
	STA sprite_data+2
	LDA #0
	STA sprite_data+3
	PLA
	JSR update_sprite
	; 	NEXT c
	INC cvb_C
	LDA cvb_C
	CMP #10
	BCC.L cv31
	; 
	; 	'
	; 	' Big delay.
	; 	'
	; 	#c = FRAME
	LDA frame
	LDY frame+1
	STA cvb_#C
	STY cvb_#C+1
	; 	DO
cv32:
	; 		WAIT
	JSR wait
	; 	LOOP WHILE FRAME - #c < 300
	LDA frame
	LDY frame+1
	SEC
	SBC cvb_#C
	TAX
	TYA
	SBC cvb_#C+1
	TAY
	TXA
	SEC
	SBC #44
	TYA
	SBC #1
	BCS.L cv34
	JMP cv32
cv34:
	; 
	; 	GOTO restart_game
	JMP cvb_RESTART_GAME
	; 
	; 	'
	; 	' Update the score on the screen.
	; 	'
	; update_score:	PROCEDURE
cvb_UPDATE_SCORE:
	; 	PRINT AT 2,#score,"0"
	LDA #2
	LDY #0
	STA cursor
	STY cursor+1
	LDA cvb_#SCORE
	LDY cvb_#SCORE+1
	JSR print_number
	JSR print_string
	DB $01
	DB $30
	; 	END
	RTS
	; 
	; 	'
	; 	' Bitmaps for the game.
	; 	'
	; sprites_bitmaps:
cvb_SPRITES_BITMAPS:
	; 	BITMAP ".......XX......."
	; 	BITMAP ".......XX......."
	; 	BITMAP "......XXXX......"
	; 	BITMAP "......XXXX......"
	; 	BITMAP "......XXXX......"
	; 	BITMAP ".....XXXXXX....."
	; 	BITMAP ".....XXXXXX....."
	; 	BITMAP ".....XX..XX....."
	; 	BITMAP ".....X....X....."
	; 	BITMAP "..XX.XXXXXX.XX.."
	; 	BITMAP ".XXX.XXXXXX.XXX."
	; 	BITMAP ".XXXXX....XXXXX."
	; 	BITMAP "XX..XXXXX.XX..XX"
	; 	BITMAP "XXX.XXXXXXXXX.XX"
	; 	BITMAP "XXXX.XXXXXX.XXXX"
	; 	BITMAP ".XX..XX..XX..XX."
	DB $01,$01,$03,$03,$03,$07,$07,$06
	DB $04,$37,$77,$7c,$cf,$ef,$f7,$66
	DB $80,$80,$c0,$c0,$c0,$e0,$e0,$60
	DB $20,$ec,$ee,$3e,$b3,$fb,$ef,$66
	; 
	; 	BITMAP "....XXXXXXXX...."
	; 	BITMAP "...X........X..."
	; 	BITMAP "..X.XX....XX.X.."
	; 	BITMAP ".X...XXXXXX...X."
	; 	BITMAP ".X...X.XX.X...X."
	; 	BITMAP ".X...XXXXXX...X."
	; 	BITMAP ".X....XXXX....X."
	; 	BITMAP ".X..XX....XX..X."
	; 	BITMAP ".XXXX.XXXX.XXXX."
	; 	BITMAP "XXX..X....X..XXX"
	; 	BITMAP "..XXXXXXXXXXXX.."
	; 	BITMAP "XXX....XX....XXX"
	; 	BITMAP "X.XXXX.XX.XXXX.X"
	; 	BITMAP "X..XX.XXXX.XX..X"
	; 	BITMAP "XXX..XX..XX..XXX"
	; 	BITMAP "..XXXX....XXXX.."
	DB $0f,$10,$2c,$47,$45,$47,$43,$4c
	DB $7b,$e4,$3f,$e1,$bd,$9b,$e6,$3c
	DB $f0,$08,$34,$e2,$a2,$e2,$c2,$32
	DB $de,$27,$fc,$87,$bd,$d9,$67,$3c
	; 
	; 	BITMAP "................"
	; 	BITMAP "................"
	; 	BITMAP "................"
	; 	BITMAP "................"
	; 	BITMAP ".......XX......."
	; 	BITMAP "......XXXX......"
	; 	BITMAP "......XXXX......"
	; 	BITMAP "......XXXX......"
	; 	BITMAP "......XXXX......"
	; 	BITMAP "....XXXXXXXX...."
	; 	BITMAP "...XXXXXXXXXX..."
	; 	BITMAP "......XXXX......"
	; 	BITMAP ".....XX...XX...."
	; 	BITMAP "................"
	; 	BITMAP "................"
	; 	BITMAP "................"
	DB $00,$00,$00,$00,$01,$03,$03,$03
	DB $03,$0f,$1f,$03,$06,$00,$00,$00
	DB $00,$00,$00,$00,$80,$c0,$c0,$c0
	DB $c0,$f0,$f8,$c0,$30,$00,$00,$00
	; 
	; 	BITMAP "................"
	; 	BITMAP "................"
	; 	BITMAP ".......X........"
	; 	BITMAP ".......XX......."
	; 	BITMAP "X......XXX......"
	; 	BITMAP "XXX.....XXX...XX"
	; 	BITMAP "XXXXX..XXXX..XXX"
	; 	BITMAP "...XXXXXXXXXXX.."
	; 	BITMAP ".....XXXXXX.X..."
	; 	BITMAP "......X..X.X...."
	; 	BITMAP ".....XXXXXXXX..."
	; 	BITMAP "....XXX.XXXXXX.."
	; 	BITMAP "...XXX.....XXXX."
	; 	BITMAP "...XX........XXX"
	; 	BITMAP "..XX............"
	; 	BITMAP "................"
	DB $00,$00,$01,$01,$81,$e0,$f9,$1f
	DB $07,$02,$07,$0e,$1c,$18,$30,$00
	DB $00,$00,$00,$80,$c0,$e3,$e7,$fc
	DB $e8,$50,$f8,$fc,$1e,$07,$00,$00
rom_end:
	times $bfe8-$ db $ff

	dw START
	dw 0		; IRQ2 handler.

	dw 0
	dw 0

	; Initial VDP registers
	db $02
	db $82
	db $06
	db $ff
	db $00
	db $36
	db $07
	db $01

	dw 0
	dw 0
	dw BIOS_NMI_RESET_ADDR	; Handler for reset.
	dw int_handler	; IRQ1 handler.
