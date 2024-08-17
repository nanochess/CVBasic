	; CVBasic compiler v0.6.1 Aug/15/2024
	; Command: ./cvbasic --creativision examples/viboritas.bas viboritas.asm 
	; Created: Sat Aug 17 10:24:48 2024

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

CVBASIC_MUSIC_PLAYER:	equ 0
CVBASIC_COMPRESSION:	equ 0
CVBASIC_BANK_SWITCHING:	equ 0

BASE_RAM:	equ $0050	; Base of RAM
STACK:	equ $017f	; Base stack pointer
VDP:	equ $00	; VDP port (write)
VDPR:	equ $00	; VDP port (read)
PSG:	equ $00	; PSG port (write)

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

	ORG $4000
	
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
	lda #$00
	ldy #$03
	sta temp2
	sty temp2+1
	lda #$20
	sta temp
	sei
	jsr FILVRM
	cli
	rts

print_string:
	STA temp
	STY temp+1
	STX temp2
	TXA
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
	and #$04
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

	; temp2 constains left side (dividend)
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
	JSR _neg16
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
	JSR _neg16
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
	JSR WRTVDP
	LDA #$A2
	LDX #$01
	JSR WRTVDP
	LDA #$06	; $1800 for pattern table.
	LDX #$02
	JSR WRTVDP
	LDA temp
	LDX #$03	; for color table.
	JSR WRTVDP
	LDA temp+1
	LDX #$04	; for bitmap table.
	JSR WRTVDP
	LDA #$36	; $1b00 for sprite attribute table.
	LDX #$05
	JSR WRTVDP
	LDA #$07	; $3800 for sprites bitmaps.
	LDX #$06
	JSR WRTVDP
	LDA #$01
	LDX #$07
	JMP WRTVDP

mode_0:
	LDA mode
	AND #$FB
	STA mode
	LDA #$ff	; $2000 for color table.
	STA temp
	LDA #$03	; $0000 for bitmaps
	STA temp+1
	LDA #$02
	LDX #$00
	JSR vdp_generic_mode
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
	JSR LDIRVM3
	CLI
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
	AND #$FB
	STA mode
	LDA #$ff	; $2000 for color table.
	STA temp
	LDA #$03	; $0000 for bitmaps
	STA temp+1
	LDA #$02
	LDX #$00
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
	ORA #$04
	STA mode
	LDA #$80	; $2000 for color table.
	STA temp
	LDA #$00	; $0000 for bitmaps
	STA temp+1
	LDA #$00
	LDX #$00
	JSR vdp_generic_mode
	LDA #font_bitmaps
	LDY #font_bitmaps>>8
	STA temp
	STY temp+1
	LDA #$00
	STA pointer
	STA temp2
	LDY #$0100>>8
	STY pointer+1
	LDY #$0300>>8
	STY temp2+1
	JSR LDIRVM
	CLI
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
	LDA FRAME
	AND #1
	BEQ .2
	TYA
	ORA joystick_table,X
	RTS
.2:
	TYA
	ORA joystick_table+16,X
	RTS

.1:	TYA
	RTS

joystick_table:
	DB $04,$04,$06,$06,$02,$02,$03,$03
	DB $01,$01,$09,$09,$08,$08,$0C,$0C

	DB $0C,$04,$04,$06,$06,$02,$02,$03
	DB $03,$01,$01,$09,$09,$08,$08,$0C

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
	and #$04
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

cvb_Y_ENEMY1:	equ $0050
cvb_Y_ENEMY2:	equ $0051
cvb_Y_ENEMY3:	equ $0052
cvb_C:	equ $0053
cvb_D:	equ $0054
cvb_E:	equ $0055
cvb_PLAYER_FRAME:	equ $0056
cvb_TICK_NOTE:	equ $0057
cvb_LIVES:	equ $0058
cvb_LEVEL:	equ $0059
cvb_ENEMY1_FRAME:	equ $005a
cvb_COLUMN:	equ $005b
cvb_ENEMY_SPEED:	equ $005c
cvb_SONG_NOTE:	equ $005d
cvb_ENEMY2_FRAME:	equ $005e
cvb_#C:	equ $005f
cvb_#D:	equ $0061
cvb_BASE_CHARACTER:	equ $0063
cvb_X_PLAYER:	equ $0064
cvb_ENEMY3_FRAME:	equ $0065
cvb_X_ENEMY1:	equ $0066
cvb_X_ENEMY2:	equ $0067
cvb_X_ENEMY3:	equ $0068
cvb_NOTE:	equ $0069
cvb_LADDERS:	equ $006a
cvb_ROW:	equ $006b
cvb_Y_PLAYER:	equ $006c
ram_end:
	; 	'
	; 	' Viboritas (demo for CVBasic)
	; 	'
	; 	' by Oscar Toledo G.
	; 	' https://nanochess.org/
	; 	'
	; 	' Creation date: Oct/1990.
	; 	' Revision date: Feb/29/2024. Ported to CVBasic.
	; 	'
	; 
	; 	' The original game was made in Z80 assembler,
	; 	' you can see it here: https://nanochess.org/viboritas.html
	; 
	; 	' It is easier to understand in CVBasic ;)
	; 
	; 	DEFINE CHAR 128,21,game_bitmaps
	LDA #128
	LDY #0
	STA pointer
	LDA #21
	PHA
	LDA #cvb_GAME_BITMAPS
	STA temp
	LDA #cvb_GAME_BITMAPS>>8
	STA temp+1
	PLA
	JSR define_char
	; 	DEFINE COLOR 128,21,game_colors
	LDA #128
	LDY #0
	STA pointer
	LDA #21
	PHA
	LDA #cvb_GAME_COLORS
	STA temp
	LDA #cvb_GAME_COLORS>>8
	STA temp+1
	PLA
	JSR define_color
	; 	DEFINE SPRITE 0,10,game_sprites
	LDA #0
	LDY #0
	STA pointer
	LDA #10
	PHA
	LDA #cvb_GAME_SPRITES
	STA temp
	LDA #cvb_GAME_SPRITES>>8
	STA temp+1
	PLA
	JSR define_sprite
	; 
	; restart_game:
cvb_RESTART_GAME:
	; 	lives = 2
	LDA #2
	STA cvb_LIVES
	; 	level = 1
	LDA #1
	STA cvb_LEVEL
	; restart_level:
cvb_RESTART_LEVEL:
	; 	
	; 	PRINT AT 684,"Lives: ",lives
	LDA #172
	LDY #2
	STA cursor
	STY cursor+1
	LDA #cv1
	LDY #cv1>>8
	LDX #7
	JSR print_string
	JMP cv2
cv1:
	DB $4c,$69,$76,$65,$73,$3a,$20
cv2:
	LDA cvb_LIVES
	LDY #0
	JSR print_number
	; 	PRINT AT 745,"nanochess 1990"
	LDA #233
	LDY #2
	STA cursor
	STY cursor+1
	LDA #cv3
	LDY #cv3>>8
	LDX #14
	JSR print_string
	JMP cv4
cv3:
	DB $6e,$61,$6e,$6f,$63,$68,$65,$73
	DB $73,$20,$31,$39,$39,$30
cv4:
	; 	
	; next_level:
cvb_NEXT_LEVEL:
	; 	GOSUB draw_level
	JSR cvb_DRAW_LEVEL
	; 
	; 	x_player = 8
	LDA #8
	STA cvb_X_PLAYER
	; 	y_player = 16
	LDA #16
	STA cvb_Y_PLAYER
	; 	player_frame = 0
	LDA #0
	STA cvb_PLAYER_FRAME
	; 
	; 	x_enemy1 = random(128) + 64
	JSR random
	AND #127
	CLC
	ADC #64
	STA cvb_X_ENEMY1
	; 	y_enemy1 = 56
	LDA #56
	STA cvb_Y_ENEMY1
	; 	enemy1_frame = 24
	LDA #24
	STA cvb_ENEMY1_FRAME
	; 	x_enemy2 = random(128) + 80
	JSR random
	AND #127
	CLC
	ADC #80
	STA cvb_X_ENEMY2
	; 	y_enemy2 = 96
	LDA #96
	STA cvb_Y_ENEMY2
	; 	enemy2_frame = 32
	LDA #32
	STA cvb_ENEMY2_FRAME
	; 	x_enemy3 = random(128) + 48
	JSR random
	AND #127
	CLC
	ADC #48
	STA cvb_X_ENEMY3
	; 	y_enemy3 = 136
	LDA #136
	STA cvb_Y_ENEMY3
	; 	enemy3_frame = 24
	LDA #24
	STA cvb_ENEMY3_FRAME
	; 
	; 	enemy_speed = 0
	LDA #0
	STA cvb_ENEMY_SPEED
	; 
	; 	GOSUB start_song
	JSR cvb_START_SONG
	; 
	; game_loop:
cvb_GAME_LOOP:
	; 	WHILE 1
cv5:
	; 		WAIT
	JSR wait
	; 		GOSUB play_song
	JSR cvb_PLAY_SONG
	; 
	; 		SPRITE 0, y_player - 1, x_player, player_frame, 15
	LDA #0
	PHA
	LDA cvb_Y_PLAYER
	SEC
	SBC #1
	STA sprite_data
	LDA cvb_X_PLAYER
	STA sprite_data+1
	LDA cvb_PLAYER_FRAME
	STA sprite_data+2
	LDA #15
	STA sprite_data+3
	PLA
	JSR update_sprite
	; 		SPRITE 1, y_enemy1 - 1, x_enemy1, enemy1_frame, 14
	LDA #1
	PHA
	LDA cvb_Y_ENEMY1
	SEC
	SBC #1
	STA sprite_data
	LDA cvb_X_ENEMY1
	STA sprite_data+1
	LDA cvb_ENEMY1_FRAME
	STA sprite_data+2
	LDA #14
	STA sprite_data+3
	PLA
	JSR update_sprite
	; 		SPRITE 2, y_enemy2 - 1, x_enemy2, enemy2_frame, 14
	LDA #2
	PHA
	LDA cvb_Y_ENEMY2
	SEC
	SBC #1
	STA sprite_data
	LDA cvb_X_ENEMY2
	STA sprite_data+1
	LDA cvb_ENEMY2_FRAME
	STA sprite_data+2
	LDA #14
	STA sprite_data+3
	PLA
	JSR update_sprite
	; 		SPRITE 3, y_enemy3 - 1, x_enemy3, enemy3_frame, 14
	LDA #3
	PHA
	LDA cvb_Y_ENEMY3
	SEC
	SBC #1
	STA sprite_data
	LDA cvb_X_ENEMY3
	STA sprite_data+1
	LDA cvb_ENEMY3_FRAME
	STA sprite_data+2
	LDA #14
	STA sprite_data+3
	PLA
	JSR update_sprite
	; 
	; 		GOSUB move_player
	JSR cvb_MOVE_PLAYER
	; 
	; 		c = $50 + level * 4
	LDA cvb_LEVEL
	ASL A
	ASL A
	CLC
	ADC #80
	STA cvb_C
	; 		enemy_speed = enemy_speed + c
	LDA cvb_ENEMY_SPEED
	CLC
	ADC cvb_C
	STA cvb_ENEMY_SPEED
	; 		WHILE enemy_speed >= $40
cv7:
	LDA cvb_ENEMY_SPEED
	CMP #64
	BCS cv9
	JMP cv8
cv9:
	; 			enemy_speed = enemy_speed - $40
	LDA cvb_ENEMY_SPEED
	SEC
	SBC #64
	STA cvb_ENEMY_SPEED
	; 			GOSUB move_enemies
	JSR cvb_MOVE_ENEMIES
	; 		WEND
	JMP cv7
cv8:
	; 		IF cont1.button THEN
	LDA joy1_data
	AND #64
	BNE cv11
	JMP cv10
cv11:
	; 			IF x_player > 232 AND x_player < 248 AND y_player = 136 THEN
	LDA cvb_X_PLAYER
	CMP #233
	BCS cv13
	LDA #0
	DB $2c
cv13:
	LDA #255
	PHA
	LDA cvb_X_PLAYER
	CMP #248
	BCC cv14
	LDA #0
	DB $2c
cv14:
	LDA #255
	STA temp
	PLA
	AND temp
	PHA
	LDA cvb_Y_PLAYER
	CMP #136
	BEQ cv15
	LDA #0
	DB $2c
cv15:
	LDA #255
	STA temp
	PLA
	AND temp
	BNE cv16
	JMP cv12
cv16:
	; 				GOSUB sound_off
	JSR cvb_SOUND_OFF
	; 
	; 				FOR c = 1 to 10
	LDA #1
	STA cvb_C
cv17:
	; 					WAIT
	JSR wait
	; 					SOUND 0, 200 - c * 10, 13
	LDA #200
	LDY #0
	PHA
	TYA
	PHA
	LDA cvb_C
	LDY #0
	PHA
	TYA
	PHA
	LDA #10
	LDY #0
	STA temp
	STY temp+1
	JSR _mul16
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
	LDX #$80
	JSR sn76489_freq
	LDA #13
	LDX #$90
	JSR sn76489_vol
	; 				NEXT c
	LDA cvb_C
	CLC
	ADC #1
	STA cvb_C
	LDA cvb_C
	CMP #11
	BCS cv18
	JMP cv17
cv18:
	; 
	; 				level = level + 1
	LDA cvb_LEVEL
	CLC
	ADC #1
	STA cvb_LEVEL
	; 				IF level = 6 THEN
	LDA cvb_LEVEL
	CMP #6
	BEQ cv20
	JMP cv19
cv20:
	; 					GOSUB sound_off
	JSR cvb_SOUND_OFF
	; 					PRINT AT 267," YOU WIN! "
	LDA #11
	LDY #1
	STA cursor
	STY cursor+1
	LDA #cv21
	LDY #cv21>>8
	LDX #10
	JSR print_string
	JMP cv22
cv21:
	DB $20,$59,$4f,$55,$20,$57,$49,$4e
	DB $21,$20
cv22:
	; 					#c = FRAME
	LDA frame
	LDY frame+1
	STA cvb_#C
	STY cvb_#C+1
	; 					DO
cv23:
	; 						WAIT
	JSR wait
	; 					LOOP WHILE FRAME - #c < 300
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
	BCC cv26
	JMP cv25
cv26:
	JMP cv23
cv25:
	; 					level = 1
	LDA #1
	STA cvb_LEVEL
	; 					GOTO restart_level
	JMP cvb_RESTART_LEVEL
	; 				END IF
cv19:
	; 				GOTO next_level	
	JMP cvb_NEXT_LEVEL
	; 			END IF
cv12:
	; 		END IF
cv10:
	; 		IF ABS(y_player + 1 - y_enemy1) < 8 THEN
	LDA cvb_Y_PLAYER
	LDY #0
	CLC
	ADC #1
	TAX
	TYA
	ADC #0
	TAY
	TXA
	SEC
	SBC cvb_Y_ENEMY1
	TAX
	TYA
	SBC #0
	TAY
	TXA
	JSR _abs16
	SEC
	SBC #8
	TYA
	SBC #0
	BCC cv28
	JMP cv27
cv28:
	; 			IF ABS(x_player + 1 - x_enemy1) < 8 THEN GOTO player_dies
	LDA cvb_X_PLAYER
	LDY #0
	CLC
	ADC #1
	TAX
	TYA
	ADC #0
	TAY
	TXA
	SEC
	SBC cvb_X_ENEMY1
	TAX
	TYA
	SBC #0
	TAY
	TXA
	JSR _abs16
	SEC
	SBC #8
	TYA
	SBC #0
	BCC cv30
	JMP cv29
cv30:
	JMP cvb_PLAYER_DIES
cv29:
	; 		END IF
cv27:
	; 		IF ABS(y_player + 1 - y_enemy2) < 8 THEN
	LDA cvb_Y_PLAYER
	LDY #0
	CLC
	ADC #1
	TAX
	TYA
	ADC #0
	TAY
	TXA
	SEC
	SBC cvb_Y_ENEMY2
	TAX
	TYA
	SBC #0
	TAY
	TXA
	JSR _abs16
	SEC
	SBC #8
	TYA
	SBC #0
	BCC cv32
	JMP cv31
cv32:
	; 			IF ABS(x_player + 1 - x_enemy2) < 8 THEN GOTO player_dies
	LDA cvb_X_PLAYER
	LDY #0
	CLC
	ADC #1
	TAX
	TYA
	ADC #0
	TAY
	TXA
	SEC
	SBC cvb_X_ENEMY2
	TAX
	TYA
	SBC #0
	TAY
	TXA
	JSR _abs16
	SEC
	SBC #8
	TYA
	SBC #0
	BCC cv34
	JMP cv33
cv34:
	JMP cvb_PLAYER_DIES
cv33:
	; 		END IF
cv31:
	; 		IF ABS(y_player + 1 - y_enemy3) < 8 THEN
	LDA cvb_Y_PLAYER
	LDY #0
	CLC
	ADC #1
	TAX
	TYA
	ADC #0
	TAY
	TXA
	SEC
	SBC cvb_Y_ENEMY3
	TAX
	TYA
	SBC #0
	TAY
	TXA
	JSR _abs16
	SEC
	SBC #8
	TYA
	SBC #0
	BCC cv36
	JMP cv35
cv36:
	; 			IF ABS(x_player + 1 - x_enemy3) < 8 THEN GOTO player_dies
	LDA cvb_X_PLAYER
	LDY #0
	CLC
	ADC #1
	TAX
	TYA
	ADC #0
	TAY
	TXA
	SEC
	SBC cvb_X_ENEMY3
	TAX
	TYA
	SBC #0
	TAY
	TXA
	JSR _abs16
	SEC
	SBC #8
	TYA
	SBC #0
	BCC cv38
	JMP cv37
cv38:
	JMP cvb_PLAYER_DIES
cv37:
	; 		END IF
cv35:
	; 	WEND
	JMP cv5
cv6:
	; 
	; player_dies:
cvb_PLAYER_DIES:
	; 	GOSUB sound_off
	JSR cvb_SOUND_OFF
	; 
	; 	SOUND 0,640,13
	LDA #128
	LDY #2
	LDX #$80
	JSR sn76489_freq
	LDA #13
	LDX #$90
	JSR sn76489_vol
	; 	SOUND 1,320,13
	LDA #64
	LDY #1
	LDX #$a0
	JSR sn76489_freq
	LDA #13
	LDX #$b0
	JSR sn76489_vol
	; 	SOUND 2,160,13
	LDA #160
	LDY #0
	LDX #$c0
	JSR sn76489_freq
	LDA #13
	LDX #$d0
	JSR sn76489_vol
	; 
	; 	player_frame = 0
	LDA #0
	STA cvb_PLAYER_FRAME
	; 	FOR c = 0 TO 30
	LDA #0
	STA cvb_C
cv39:
	; 		WAIT
	JSR wait
	; 		WAIT
	JSR wait
	; 		player_frame = player_frame XOR 8
	LDA cvb_PLAYER_FRAME
	EOR #8
	STA cvb_PLAYER_FRAME
	; 		SPRITE 0, y_player - 1, x_player, player_frame, 15
	LDA #0
	PHA
	LDA cvb_Y_PLAYER
	SEC
	SBC #1
	STA sprite_data
	LDA cvb_X_PLAYER
	STA sprite_data+1
	LDA cvb_PLAYER_FRAME
	STA sprite_data+2
	LDA #15
	STA sprite_data+3
	PLA
	JSR update_sprite
	; 	NEXT c
	LDA cvb_C
	CLC
	ADC #1
	STA cvb_C
	LDA cvb_C
	CMP #31
	BCS cv40
	JMP cv39
cv40:
	; 
	; 	GOSUB sound_off
	JSR cvb_SOUND_OFF
	; 
	; 	DO
cv41:
	; 		WAIT
	JSR wait
	; 		SOUND 0,200 - y_player,13
	LDA #200
	LDY #0
	SEC
	SBC cvb_Y_PLAYER
	TAX
	TYA
	SBC #0
	TAY
	TXA
	LDX #$80
	JSR sn76489_freq
	LDA #13
	LDX #$90
	JSR sn76489_vol
	; 		player_frame = player_frame XOR 8
	LDA cvb_PLAYER_FRAME
	EOR #8
	STA cvb_PLAYER_FRAME
	; 		SPRITE 0, y_player - 1, x_player, player_frame, 15
	LDA #0
	PHA
	LDA cvb_Y_PLAYER
	SEC
	SBC #1
	STA sprite_data
	LDA cvb_X_PLAYER
	STA sprite_data+1
	LDA cvb_PLAYER_FRAME
	STA sprite_data+2
	LDA #15
	STA sprite_data+3
	PLA
	JSR update_sprite
	; 		y_player = y_player + 2
	LDA cvb_Y_PLAYER
	CLC
	ADC #2
	STA cvb_Y_PLAYER
	; 	LOOP WHILE y_player < 160
	LDA cvb_Y_PLAYER
	CMP #160
	BCC cv44
	JMP cv43
cv44:
	JMP cv41
cv43:
	; 
	; 	GOSUB sound_off
	JSR cvb_SOUND_OFF
	; 
	; 	IF lives = 0 THEN
	LDA cvb_LIVES
	CMP #0
	BEQ cv46
	JMP cv45
cv46:
	; 		PRINT AT 267," GAME OVER "
	LDA #11
	LDY #1
	STA cursor
	STY cursor+1
	LDA #cv47
	LDY #cv47>>8
	LDX #11
	JSR print_string
	JMP cv48
cv47:
	DB $20,$47,$41,$4d,$45,$20,$4f,$56
	DB $45,$52,$20
cv48:
	; 		#c = FRAME
	LDA frame
	LDY frame+1
	STA cvb_#C
	STY cvb_#C+1
	; 		DO
cv49:
	; 			WAIT
	JSR wait
	; 		LOOP WHILE FRAME - #c < 300
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
	BCC cv52
	JMP cv51
cv52:
	JMP cv49
cv51:
	; 		GOTO restart_game
	JMP cvb_RESTART_GAME
	; 	END IF
cv45:
	; 	lives = lives - 1
	LDA cvb_LIVES
	SEC
	SBC #1
	STA cvb_LIVES
	; 	GOTO restart_level
	JMP cvb_RESTART_LEVEL
	; 
	; 	'
	; 	' Draw the current level.
	; 	'
	; draw_level:	PROCEDURE
cvb_DRAW_LEVEL:
	; 
	; 	' Get the base character to draw the level.
	; 	base_character = 128 + (level - 1) * 4
	LDA cvb_LEVEL
	SEC
	SBC #1
	ASL A
	ASL A
	CLC
	ADC #128
	STA cvb_BASE_CHARACTER
	; 
	; 	' Draw the background.
	; 	FOR #c = $1800 TO $1a7c STEP 4
	LDA #0
	LDY #24
	STA cvb_#C
	STY cvb_#C+1
cv53:
	; 		VPOKE #c, base_character
	LDA cvb_BASE_CHARACTER
	PHA
	LDA cvb_#C
	LDY cvb_#C+1
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	SEI
	JSR WRTVRM
	CLI
	; 		VPOKE #c + 1, base_character
	LDA cvb_BASE_CHARACTER
	PHA
	LDA cvb_#C
	LDY cvb_#C+1
	CLC
	ADC #1
	TAX
	TYA
	ADC #0
	TAY
	TXA
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	SEI
	JSR WRTVRM
	CLI
	; 		VPOKE #c + 2, base_character
	LDA cvb_BASE_CHARACTER
	PHA
	LDA cvb_#C
	LDY cvb_#C+1
	CLC
	ADC #2
	TAX
	TYA
	ADC #0
	TAY
	TXA
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	SEI
	JSR WRTVRM
	CLI
	; 		VPOKE #c + 3, base_character + 1.
	LDA cvb_BASE_CHARACTER
	CLC
	ADC #1
	PHA
	LDA cvb_#C
	LDY cvb_#C+1
	CLC
	ADC #3
	TAX
	TYA
	ADC #0
	TAY
	TXA
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	SEI
	JSR WRTVRM
	CLI
	; 	NEXT #c
	LDA cvb_#C
	LDY cvb_#C+1
	CLC
	ADC #4
	TAX
	TYA
	ADC #0
	TAY
	TXA
	STA cvb_#C
	STY cvb_#C+1
	LDA cvb_#C
	LDY cvb_#C+1
	SEC
	SBC #125
	TYA
	SBC #26
	BCS cv54
	JMP cv53
cv54:
	; 
	; 	' Draw over the floors.
	; 	FOR #c = $1880 TO $1A60 STEP 160
	LDA #128
	LDY #24
	STA cvb_#C
	STY cvb_#C+1
cv55:
	; 		FOR #d = #c TO #c + 31
	LDA cvb_#C
	LDY cvb_#C+1
	STA cvb_#D
	STY cvb_#D+1
cv56:
	; 			VPOKE #d, base_character + 2.
	LDA cvb_BASE_CHARACTER
	CLC
	ADC #2
	PHA
	LDA cvb_#D
	LDY cvb_#D+1
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	SEI
	JSR WRTVRM
	CLI
	; 		NEXT #d
	LDA cvb_#D
	LDY cvb_#D+1
	CLC
	ADC #1
	TAX
	TYA
	ADC #0
	TAY
	TXA
	STA cvb_#D
	STY cvb_#D+1
	LDA cvb_#C
	LDY cvb_#C+1
	CLC
	ADC #31
	TAX
	TYA
	ADC #0
	TAY
	TXA
	SEC
	SBC cvb_#D
	TYA
	SBC cvb_#D+1
	BCC cv57
	JMP cv56
cv57:
	; 	NEXT #c
	LDA cvb_#C
	LDY cvb_#C+1
	CLC
	ADC #160
	TAX
	TYA
	ADC #0
	TAY
	TXA
	STA cvb_#C
	STY cvb_#C+1
	LDA cvb_#C
	LDY cvb_#C+1
	SEC
	SBC #97
	TYA
	SBC #26
	BCS cv58
	JMP cv55
cv58:
	; 
	; 	' Draw the ladders.
	; 	ladders = 6 - level
	LDA #6
	LDY #0
	SEC
	SBC cvb_LEVEL
	TAX
	TYA
	SBC #0
	TAY
	TXA
	STA cvb_LADDERS
	; 
	; 	FOR #c = $1880 TO $19C0 STEP 160
	LDA #128
	LDY #24
	STA cvb_#C
	STY cvb_#C+1
cv59:
	; 		FOR d = 1 TO ladders
	LDA #1
	STA cvb_D
cv60:
	; 			e = RANDOM(28) + 2
	JSR random
	PHA
	TYA
	PHA
	LDA #28
	LDY #0
	STA temp
	STY temp+1
	JSR _mod16
	CLC
	ADC #2
	STA cvb_E
	; 			VPOKE #c + e, base_character + 3.
	LDA cvb_BASE_CHARACTER
	CLC
	ADC #3
	PHA
	LDA cvb_#C
	LDY cvb_#C+1
	CLC
	ADC cvb_E
	TAX
	TYA
	ADC #0
	TAY
	TXA
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	SEI
	JSR WRTVRM
	CLI
	; 			VPOKE #c + e + 32, base_character + 3.
	LDA cvb_BASE_CHARACTER
	CLC
	ADC #3
	PHA
	LDA cvb_#C
	LDY cvb_#C+1
	CLC
	ADC cvb_E
	TAX
	TYA
	ADC #0
	TAY
	TXA
	CLC
	ADC #32
	TAX
	TYA
	ADC #0
	TAY
	TXA
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	SEI
	JSR WRTVRM
	CLI
	; 			VPOKE #c + e + 64, base_character + 3.
	LDA cvb_BASE_CHARACTER
	CLC
	ADC #3
	PHA
	LDA cvb_#C
	LDY cvb_#C+1
	CLC
	ADC cvb_E
	TAX
	TYA
	ADC #0
	TAY
	TXA
	CLC
	ADC #64
	TAX
	TYA
	ADC #0
	TAY
	TXA
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	SEI
	JSR WRTVRM
	CLI
	; 			VPOKE #c + e + 96, base_character + 3.
	LDA cvb_BASE_CHARACTER
	CLC
	ADC #3
	PHA
	LDA cvb_#C
	LDY cvb_#C+1
	CLC
	ADC cvb_E
	TAX
	TYA
	ADC #0
	TAY
	TXA
	CLC
	ADC #96
	TAX
	TYA
	ADC #0
	TAY
	TXA
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	SEI
	JSR WRTVRM
	CLI
	; 			VPOKE #c + e + 128, base_character + 3.
	LDA cvb_BASE_CHARACTER
	CLC
	ADC #3
	PHA
	LDA cvb_#C
	LDY cvb_#C+1
	CLC
	ADC cvb_E
	TAX
	TYA
	ADC #0
	TAY
	TXA
	CLC
	ADC #128
	TAX
	TYA
	ADC #0
	TAY
	TXA
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	SEI
	JSR WRTVRM
	CLI
	; 		NEXT d
	LDA cvb_D
	CLC
	ADC #1
	STA cvb_D
	LDA cvb_LADDERS
	CMP cvb_D
	BCC cv61
	JMP cv60
cv61:
	; 	NEXT #c
	LDA cvb_#C
	LDY cvb_#C+1
	CLC
	ADC #160
	TAX
	TYA
	ADC #0
	TAY
	TXA
	STA cvb_#C
	STY cvb_#C+1
	LDA cvb_#C
	LDY cvb_#C+1
	SEC
	SBC #193
	TYA
	SBC #25
	BCS cv62
	JMP cv59
cv62:
	; 
	; 	' Draw the "exit".
	; 	VPOKE $1A5E, 148
	LDA #148
	PHA
	LDA #94
	LDY #26
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	SEI
	JSR WRTVRM
	CLI
	; 
	; 	END
	RTS
	; 
	; 	'
	; 	' Move the player
	; 	'
	; move_player:	PROCEDURE
cvb_MOVE_PLAYER:
	; 	IF cont1.left THEN
	LDA joy1_data
	AND #8
	BNE cv64
	JMP cv63
cv64:
	; 		IF y_player % 40 = 16 THEN	' Player aligned on floor
	LDA cvb_Y_PLAYER
	LDY #0
	PHA
	TYA
	PHA
	LDA #40
	LDY #0
	STA temp
	STY temp+1
	JSR _mod16
	SEC
	SBC #16
	STA temp
	TYA
	SBC #0
	ORA temp
	BEQ cv66
	JMP cv65
cv66:
	; 			IF x_player > 0 THEN x_player = x_player - 1
	LDA cvb_X_PLAYER
	CMP #1
	BCS cv68
	JMP cv67
cv68:
	LDA cvb_X_PLAYER
	SEC
	SBC #1
	STA cvb_X_PLAYER
cv67:
	; 			IF FRAME AND 4 THEN player_frame = 8 ELSE player_frame = 12
	LDA frame
	LDY frame+1
	AND #4
	LDY #0
	STY temp
	ORA temp
	BNE cv70
	JMP cv69
cv70:
	LDA #8
	STA cvb_PLAYER_FRAME
	JMP cv71
cv69:
	LDA #12
	STA cvb_PLAYER_FRAME
cv71:
	; 		END IF
cv65:
	; 	END IF
cv63:
	; 	IF cont1.right THEN
	LDA joy1_data
	AND #2
	BNE cv73
	JMP cv72
cv73:
	; 		IF y_player % 40 = 16 THEN	' Player aligned on floor
	LDA cvb_Y_PLAYER
	LDY #0
	PHA
	TYA
	PHA
	LDA #40
	LDY #0
	STA temp
	STY temp+1
	JSR _mod16
	SEC
	SBC #16
	STA temp
	TYA
	SBC #0
	ORA temp
	BEQ cv75
	JMP cv74
cv75:
	; 			IF x_player < 240 THEN x_player = x_player + 1
	LDA cvb_X_PLAYER
	CMP #240
	BCC cv77
	JMP cv76
cv77:
	LDA cvb_X_PLAYER
	CLC
	ADC #1
	STA cvb_X_PLAYER
cv76:
	; 			IF FRAME AND 4 THEN player_frame = 0 ELSE player_frame = 4
	LDA frame
	LDY frame+1
	AND #4
	LDY #0
	STY temp
	ORA temp
	BNE cv79
	JMP cv78
cv79:
	LDA #0
	STA cvb_PLAYER_FRAME
	JMP cv80
cv78:
	LDA #4
	STA cvb_PLAYER_FRAME
cv80:
	; 		END IF
cv74:
	; 	END IF
cv72:
	; 	IF cont1.up THEN
	LDA joy1_data
	AND #1
	BNE cv82
	JMP cv81
cv82:
	; 		IF y_player % 40 = 16 THEN	' Player aligned on floor.
	LDA cvb_Y_PLAYER
	LDY #0
	PHA
	TYA
	PHA
	LDA #40
	LDY #0
	STA temp
	STY temp+1
	JSR _mod16
	SEC
	SBC #16
	STA temp
	TYA
	SBC #0
	ORA temp
	BEQ cv84
	JMP cv83
cv84:
	; 			column = (x_player + 7) /8
	LDA cvb_X_PLAYER
	LDY #0
	CLC
	ADC #7
	TAX
	TYA
	ADC #0
	TAY
	TXA
	STY temp
	LSR temp
	ROR A
	LSR temp
	ROR A
	LSR temp
	ROR A
	LDY temp
	STA cvb_COLUMN
	; 			row = (y_player + 8) / 8
	LDA cvb_Y_PLAYER
	LDY #0
	CLC
	ADC #8
	TAX
	TYA
	ADC #0
	TAY
	TXA
	STY temp
	LSR temp
	ROR A
	LSR temp
	ROR A
	LSR temp
	ROR A
	LDY temp
	STA cvb_ROW
	; 			#c = $1800 + row * 32 + column
	LDA cvb_ROW
	LDY #0
	STY temp
	ASL A
	ROL temp
	ASL A
	ROL temp
	ASL A
	ROL temp
	ASL A
	ROL temp
	ASL A
	ROL temp
	LDY temp
	CLC
	ADC #0
	TAX
	TYA
	ADC #24
	TAY
	TXA
	CLC
	ADC cvb_COLUMN
	TAX
	TYA
	ADC #0
	TAY
	TXA
	STA cvb_#C
	STY cvb_#C+1
	; 			IF VPEEK(#c) = base_character + 3 THEN	' Ladder?
	LDA cvb_#C
	LDY cvb_#C+1
	SEI
	JSR RDVRM
	CLI
	LDY #0
	PHA
	TYA
	PHA
	LDA cvb_BASE_CHARACTER
	LDY #0
	CLC
	ADC #3
	TAX
	TYA
	ADC #0
	TAY
	TXA
	STA temp
	STY temp+1
	PLA
	TAY
	PLA
	SEC
	SBC temp
	STA temp
	TYA
	SBC temp+1
	ORA temp
	BEQ cv86
	JMP cv85
cv86:
	; 				y_player = y_player - 1
	LDA cvb_Y_PLAYER
	SEC
	SBC #1
	STA cvb_Y_PLAYER
	; 			END IF
cv85:
	; 		ELSE
	JMP cv87
cv83:
	; 			IF FRAME AND 4 THEN player_frame = 16 ELSE player_frame = 20
	LDA frame
	LDY frame+1
	AND #4
	LDY #0
	STY temp
	ORA temp
	BNE cv89
	JMP cv88
cv89:
	LDA #16
	STA cvb_PLAYER_FRAME
	JMP cv90
cv88:
	LDA #20
	STA cvb_PLAYER_FRAME
cv90:
	; 			y_player = y_player - 1
	LDA cvb_Y_PLAYER
	SEC
	SBC #1
	STA cvb_Y_PLAYER
	; 		END IF
cv87:
	; 	END IF
cv81:
	; 	IF cont1.down THEN
	LDA joy1_data
	AND #4
	BNE cv92
	JMP cv91
cv92:
	; 		IF y_player % 40 = 16 THEN	' Player aligned on floor.
	LDA cvb_Y_PLAYER
	LDY #0
	PHA
	TYA
	PHA
	LDA #40
	LDY #0
	STA temp
	STY temp+1
	JSR _mod16
	SEC
	SBC #16
	STA temp
	TYA
	SBC #0
	ORA temp
	BEQ cv94
	JMP cv93
cv94:
	; 			column = (x_player + 7) /8
	LDA cvb_X_PLAYER
	LDY #0
	CLC
	ADC #7
	TAX
	TYA
	ADC #0
	TAY
	TXA
	STY temp
	LSR temp
	ROR A
	LSR temp
	ROR A
	LSR temp
	ROR A
	LDY temp
	STA cvb_COLUMN
	; 			row = (y_player + 16) / 8
	LDA cvb_Y_PLAYER
	LDY #0
	CLC
	ADC #16
	TAX
	TYA
	ADC #0
	TAY
	TXA
	STY temp
	LSR temp
	ROR A
	LSR temp
	ROR A
	LSR temp
	ROR A
	LDY temp
	STA cvb_ROW
	; 			#c = $1800 + row * 32 + column
	LDA cvb_ROW
	LDY #0
	STY temp
	ASL A
	ROL temp
	ASL A
	ROL temp
	ASL A
	ROL temp
	ASL A
	ROL temp
	ASL A
	ROL temp
	LDY temp
	CLC
	ADC #0
	TAX
	TYA
	ADC #24
	TAY
	TXA
	CLC
	ADC cvb_COLUMN
	TAX
	TYA
	ADC #0
	TAY
	TXA
	STA cvb_#C
	STY cvb_#C+1
	; 			IF VPEEK(#c) = base_character + 3 THEN	' Ladder?
	LDA cvb_#C
	LDY cvb_#C+1
	SEI
	JSR RDVRM
	CLI
	LDY #0
	PHA
	TYA
	PHA
	LDA cvb_BASE_CHARACTER
	LDY #0
	CLC
	ADC #3
	TAX
	TYA
	ADC #0
	TAY
	TXA
	STA temp
	STY temp+1
	PLA
	TAY
	PLA
	SEC
	SBC temp
	STA temp
	TYA
	SBC temp+1
	ORA temp
	BEQ cv96
	JMP cv95
cv96:
	; 				y_player = y_player + 1
	LDA cvb_Y_PLAYER
	CLC
	ADC #1
	STA cvb_Y_PLAYER
	; 			END IF
cv95:
	; 		ELSE
	JMP cv97
cv93:
	; 			IF FRAME AND 4 THEN player_frame = 16 ELSE player_frame = 20
	LDA frame
	LDY frame+1
	AND #4
	LDY #0
	STY temp
	ORA temp
	BNE cv99
	JMP cv98
cv99:
	LDA #16
	STA cvb_PLAYER_FRAME
	JMP cv100
cv98:
	LDA #20
	STA cvb_PLAYER_FRAME
cv100:
	; 			y_player = y_player + 1
	LDA cvb_Y_PLAYER
	CLC
	ADC #1
	STA cvb_Y_PLAYER
	; 		END IF
cv97:
	; 	END IF
cv91:
	; 	END
	RTS
	; 
	; 	'
	; 	' Move the enemies.
	; 	'
	; move_enemies:	PROCEDURE
cvb_MOVE_ENEMIES:
	; 	IF enemy1_frame < 32 THEN
	LDA cvb_ENEMY1_FRAME
	CMP #32
	BCC cv102
	JMP cv101
cv102:
	; 		x_enemy1 = x_enemy1 - 1.
	LDA cvb_X_ENEMY1
	SEC
	SBC #1
	STA cvb_X_ENEMY1
	; 		IF x_enemy1 = 0 THEN enemy1_frame = 32
	LDA cvb_X_ENEMY1
	CMP #0
	BEQ cv104
	JMP cv103
cv104:
	LDA #32
	STA cvb_ENEMY1_FRAME
cv103:
	; 	ELSE
	JMP cv105
cv101:
	; 		x_enemy1 = x_enemy1 + 1.
	LDA cvb_X_ENEMY1
	CLC
	ADC #1
	STA cvb_X_ENEMY1
	; 		IF x_enemy1 = 240 THEN enemy1_frame = 24
	LDA cvb_X_ENEMY1
	CMP #240
	BEQ cv107
	JMP cv106
cv107:
	LDA #24
	STA cvb_ENEMY1_FRAME
cv106:
	; 	END IF
cv105:
	; 	enemy1_frame = (enemy1_frame AND $f8) + (FRAME AND 4)
	LDA cvb_ENEMY1_FRAME
	AND #248
	LDY #0
	PHA
	TYA
	PHA
	LDA frame
	LDY frame+1
	AND #4
	LDY #0
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
	STA cvb_ENEMY1_FRAME
	; 
	; 	IF enemy2_frame < 32 THEN
	LDA cvb_ENEMY2_FRAME
	CMP #32
	BCC cv109
	JMP cv108
cv109:
	; 		x_enemy2 = x_enemy2 - 1.
	LDA cvb_X_ENEMY2
	SEC
	SBC #1
	STA cvb_X_ENEMY2
	; 		IF x_enemy2 = 0 THEN enemy2_frame = 32
	LDA cvb_X_ENEMY2
	CMP #0
	BEQ cv111
	JMP cv110
cv111:
	LDA #32
	STA cvb_ENEMY2_FRAME
cv110:
	; 	ELSE
	JMP cv112
cv108:
	; 		x_enemy2 = x_enemy2 + 1.
	LDA cvb_X_ENEMY2
	CLC
	ADC #1
	STA cvb_X_ENEMY2
	; 		IF x_enemy2 = 240 THEN enemy2_frame = 24
	LDA cvb_X_ENEMY2
	CMP #240
	BEQ cv114
	JMP cv113
cv114:
	LDA #24
	STA cvb_ENEMY2_FRAME
cv113:
	; 	END IF
cv112:
	; 	enemy2_frame = (enemy2_frame AND $f8) + (FRAME AND 4)
	LDA cvb_ENEMY2_FRAME
	AND #248
	LDY #0
	PHA
	TYA
	PHA
	LDA frame
	LDY frame+1
	AND #4
	LDY #0
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
	STA cvb_ENEMY2_FRAME
	; 
	; 	IF enemy3_frame < 32 THEN
	LDA cvb_ENEMY3_FRAME
	CMP #32
	BCC cv116
	JMP cv115
cv116:
	; 		x_enemy3 = x_enemy3 - 1.
	LDA cvb_X_ENEMY3
	SEC
	SBC #1
	STA cvb_X_ENEMY3
	; 		IF x_enemy3 = 0 THEN enemy3_frame = 32
	LDA cvb_X_ENEMY3
	CMP #0
	BEQ cv118
	JMP cv117
cv118:
	LDA #32
	STA cvb_ENEMY3_FRAME
cv117:
	; 	ELSE
	JMP cv119
cv115:
	; 		x_enemy3 = x_enemy3 + 1.
	LDA cvb_X_ENEMY3
	CLC
	ADC #1
	STA cvb_X_ENEMY3
	; 		IF x_enemy3 = 240 THEN enemy3_frame = 24
	LDA cvb_X_ENEMY3
	CMP #240
	BEQ cv121
	JMP cv120
cv121:
	LDA #24
	STA cvb_ENEMY3_FRAME
cv120:
	; 	END IF
cv119:
	; 	enemy3_frame = (enemy3_frame AND $f8) + (FRAME AND 4)
	LDA cvb_ENEMY3_FRAME
	AND #248
	LDY #0
	PHA
	TYA
	PHA
	LDA frame
	LDY frame+1
	AND #4
	LDY #0
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
	STA cvb_ENEMY3_FRAME
	; 	END
	RTS
	; 
	; game_bitmaps:
cvb_GAME_BITMAPS:
	; 	BITMAP "XXXXXXXX"
	; 	BITMAP "XXXXXXXX"
	; 	BITMAP "XXXXXXXX"
	; 	BITMAP "XXXXXXXX"
	; 	BITMAP "XXXXXXXX"
	; 	BITMAP "XXXXXXXX"
	; 	BITMAP "XXXXXXXX"
	; 	BITMAP "XXXXXXXX"
	DB $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
	; 
	; 	BITMAP "XXX..XXX"
	; 	BITMAP "XXX..XXX"
	; 	BITMAP "XXX..XXX"
	; 	BITMAP "XXX..XXX"
	; 	BITMAP "XXX..XXX"
	; 	BITMAP "XXX..XXX"
	; 	BITMAP "XXX..XXX"
	; 	BITMAP "XXX..XXX"
	DB $e7,$e7,$e7,$e7,$e7,$e7,$e7,$e7
	; 
	; 	BITMAP "XXXXXXXX"
	; 	BITMAP "XXXXXXXX"
	; 	BITMAP "........"
	; 	BITMAP "XXXXXXXX"
	; 	BITMAP "XXXXXXXX"
	; 	BITMAP "........"
	; 	BITMAP "XXXXXXXX"
	; 	BITMAP "XXXXXXXX"
	DB $ff,$ff,$00,$ff,$ff,$00,$ff,$ff
	; 
	; 	BITMAP ".X....X."
	; 	BITMAP ".X....X."
	; 	BITMAP ".XXXXXX."
	; 	BITMAP ".X....X."
	; 	BITMAP ".X....X."
	; 	BITMAP ".XXXXXX."
	; 	BITMAP ".X....X."
	; 	BITMAP ".X....X."
	DB $42,$42,$7e,$42,$42,$7e,$42,$42
	; 
	; 	BITMAP "XXXXXXX."
	; 	BITMAP "X.....X."
	; 	BITMAP "X.XXX.X."
	; 	BITMAP "X.X.X.X."
	; 	BITMAP "X.XXX.X."
	; 	BITMAP "X.....X."
	; 	BITMAP "XXXXXXX."
	; 	BITMAP "........"
	DB $fe,$82,$ba,$aa,$ba,$82,$fe,$00
	; 
	; 	BITMAP "X.XXX.X."
	; 	BITMAP "X.XXX.X."
	; 	BITMAP "X.XXX.X."
	; 	BITMAP "X.XXX.X."
	; 	BITMAP "X.XXX.X."
	; 	BITMAP "X.XXX.X."
	; 	BITMAP "X.XXX.X."
	; 	BITMAP "X.XXX.X."
	DB $ba,$ba,$ba,$ba,$ba,$ba,$ba,$ba
	; 
	; 	BITMAP "XXX.XXX."
	; 	BITMAP "........"
	; 	BITMAP "XXXXXXXX"
	; 	BITMAP "XXXXXXXX"
	; 	BITMAP "XXXXXXXX"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	DB $ee,$00,$ff,$ff,$ff,$00,$00,$00
	; 
	; 	BITMAP ".X....X."
	; 	BITMAP ".X....X."
	; 	BITMAP ".XXXXXX."
	; 	BITMAP ".X....X."
	; 	BITMAP ".X....X."
	; 	BITMAP ".XXXXXX."
	; 	BITMAP ".X....X."
	; 	BITMAP ".X....X."
	DB $42,$42,$7e,$42,$42,$7e,$42,$42
	; 
	; 	BITMAP "XXX.XXXX"
	; 	BITMAP "XXX.XXXX"
	; 	BITMAP "XXX.XXXX"
	; 	BITMAP "........"
	; 	BITMAP "XXXXXXX."
	; 	BITMAP "XXXXXXX."
	; 	BITMAP "XXXXXXX."
	; 	BITMAP "........"
	DB $ef,$ef,$ef,$00,$fe,$fe,$fe,$00
	; 
	; 	BITMAP ".XXXXXX."
	; 	BITMAP ".XXXXXX."
	; 	BITMAP ".XXXXXX."
	; 	BITMAP "........"
	; 	BITMAP ".XX.XXX."
	; 	BITMAP ".XX.XXX."
	; 	BITMAP ".XX.XXX."
	; 	BITMAP "........"
	DB $7e,$7e,$7e,$00,$6e,$6e,$6e,$00
	; 
	; 	BITMAP "........"
	; 	BITMAP "XXXXXXXX"
	; 	BITMAP "XXXXXXXX"
	; 	BITMAP "X.X.X.X."
	; 	BITMAP ".X...X.."
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	DB $00,$ff,$ff,$aa,$44,$00,$00,$00
	; 
	; 	BITMAP ".X....X."
	; 	BITMAP ".X....X."
	; 	BITMAP ".XXXXXX."
	; 	BITMAP ".X....X."
	; 	BITMAP ".X....X."
	; 	BITMAP ".XXXXXX."
	; 	BITMAP ".X....X."
	; 	BITMAP ".X....X."
	DB $42,$42,$7e,$42,$42,$7e,$42,$42
	; 
	; 	BITMAP "XXX.XXX."
	; 	BITMAP "XXX.XXX."
	; 	BITMAP "XXX.XXX."
	; 	BITMAP "........"
	; 	BITMAP "XXX.XXX."
	; 	BITMAP "XXX.XXX."
	; 	BITMAP "XXX.XXX."
	; 	BITMAP "........"
	DB $ee,$ee,$ee,$00,$ee,$ee,$ee,$00
	; 
	; 	BITMAP ".X......"
	; 	BITMAP "..XX...."
	; 	BITMAP "....XX.."
	; 	BITMAP "......XX"
	; 	BITMAP "....XX.."
	; 	BITMAP "..XX...."
	; 	BITMAP ".X......"
	; 	BITMAP ".X......"
	DB $40,$30,$0c,$03,$0c,$30,$40,$40
	; 
	; 	BITMAP "........"
	; 	BITMAP "XXXXXXXX"
	; 	BITMAP "........"
	; 	BITMAP "X.X.X.X."
	; 	BITMAP ".X.X.X.X"
	; 	BITMAP "........"
	; 	BITMAP "XXXXXXXX"
	; 	BITMAP "........"
	DB $00,$ff,$00,$aa,$55,$00,$ff,$00
	; 
	; 	BITMAP "X......X"
	; 	BITMAP "X......X"
	; 	BITMAP "XX....XX"
	; 	BITMAP "X.XXXX.X"
	; 	BITMAP "X......X"
	; 	BITMAP "X......X"
	; 	BITMAP "XX....XX"
	; 	BITMAP "X.XXXX.X"
	DB $81,$81,$c3,$bd,$81,$81,$c3,$bd
	; 
	; 	BITMAP "X......X"
	; 	BITMAP ".X.XX..."
	; 	BITMAP "..XX.XXX"
	; 	BITMAP ".X...XXX"
	; 	BITMAP "..XXX..X"
	; 	BITMAP "..X..XXX"
	; 	BITMAP ".X..X..X"
	; 	BITMAP "..X..XXX"
	DB $81,$58,$37,$47,$39,$27,$49,$27
	; 
	; 	BITMAP ".X...XXX"
	; 	BITMAP ".X..X..X"
	; 	BITMAP "..X..XXX"
	; 	BITMAP ".X......"
	; 	BITMAP "..X.X..."
	; 	BITMAP "...X.X.X"
	; 	BITMAP "...X..X."
	; 	BITMAP "..X..XXX"
	DB $47,$49,$27,$40,$28,$15,$12,$27
	; 
	; 	BITMAP "........"
	; 	BITMAP "XXXXXXX."
	; 	BITMAP "XXXXXXX."
	; 	BITMAP "........"
	; 	BITMAP "XXX.XXXX"
	; 	BITMAP "XXX.XXXX"
	; 	BITMAP "........"
	; 	BITMAP "........"
	DB $00,$fe,$fe,$00,$ef,$ef,$00,$00
	; 
	; 	BITMAP "....XX.."
	; 	BITMAP "....XX.."
	; 	BITMAP "...XX..."
	; 	BITMAP "...XX..."
	; 	BITMAP "..XX...."
	; 	BITMAP "..XX...."
	; 	BITMAP "...XX..."
	; 	BITMAP "...XX..."
	DB $0c,$0c,$18,$18,$30,$30,$18,$18
	; 
	; 	BITMAP ".X.X.X.."
	; 	BITMAP "XXXXXXX."
	; 	BITMAP ".X.X.X.."
	; 	BITMAP "XXXXXXX."
	; 	BITMAP ".X.X.X.."
	; 	BITMAP "XXXXXXX."
	; 	BITMAP ".X.X.X.."
	; 	BITMAP "........"
	DB $54,$fe,$54,$fe,$54,$fe,$54,$00
	; 
	; game_colors:
cvb_GAME_COLORS:
	; 	DATA BYTE $CC,$CC,$CC,$CC,$CC,$CC,$CC,$CC
	DB $cc,$cc,$cc,$cc,$cc,$cc,$cc,$cc
	; 	DATA BYTE $21,$21,$21,$21,$21,$21,$21,$21
	DB $21,$21,$21,$21,$21,$21,$21,$21
	; 	DATA BYTE $A1,$A1,$A1,$A1,$A1,$A1,$A1,$A1
	DB $a1,$a1,$a1,$a1,$a1,$a1,$a1,$a1
	; 	DATA BYTE $51,$51,$51,$51,$51,$51,$51,$51
	DB $51,$51,$51,$51,$51,$51,$51,$51
	; 
	; 	DATA BYTE $54,$54,$54,$54,$54,$54,$54,$54
	DB $54,$54,$54,$54,$54,$54,$54,$54
	; 	DATA BYTE $51,$51,$51,$51,$51,$51,$51,$51
	DB $51,$51,$51,$51,$51,$51,$51,$51
	; 	DATA BYTE $F1,$11,$E1,$E1,$E1,$11,$11,$11
	DB $f1,$11,$e1,$e1,$e1,$11,$11,$11
	; 	DATA BYTE $51,$51,$51,$51,$51,$51,$51,$51
	DB $51,$51,$51,$51,$51,$51,$51,$51
	; 
	; 	DATA BYTE $68,$68,$68,$68,$68,$68,$68,$68
	DB $68,$68,$68,$68,$68,$68,$68,$68
	; 	DATA BYTE $81,$81,$81,$81,$81,$81,$81,$81
	DB $81,$81,$81,$81,$81,$81,$81,$81
	; 	DATA BYTE $51,$51,$51,$51,$51,$51,$51,$51
	DB $51,$51,$51,$51,$51,$51,$51,$51
	; 	DATA BYTE $51,$51,$51,$51,$51,$51,$51,$51
	DB $51,$51,$51,$51,$51,$51,$51,$51
	; 
	; 	DATA BYTE $61,$61,$61,$61,$61,$61,$61,$61
	DB $61,$61,$61,$61,$61,$61,$61,$61
	; 	DATA BYTE $A1,$A1,$A1,$A1,$A1,$A1,$A1,$A1
	DB $a1,$a1,$a1,$a1,$a1,$a1,$a1,$a1
	; 	DATA BYTE $F1,$F1,$F1,$51,$51,$F1,$F1,$F1
	DB $f1,$f1,$f1,$51,$51,$f1,$f1,$f1
	; 	DATA BYTE $E1,$E1,$E1,$E1,$E1,$E1,$E1,$E1
	DB $e1,$e1,$e1,$e1,$e1,$e1,$e1,$e1
	; 
	; 	DATA BYTE $86,$86,$86,$86,$86,$86,$86,$86
	DB $86,$86,$86,$86,$86,$86,$86,$86
	; 	DATA BYTE $2C,$2C,$2C,$2C,$2C,$2C,$2C,$2C
	DB $2c,$2c,$2c,$2c,$2c,$2c,$2c,$2c
	; 	DATA BYTE $11,$6E,$6E,$6E,$6E,$6E,$6E,$11
	DB $11,$6e,$6e,$6e,$6e,$6e,$6e,$11
	; 	DATA BYTE $C1,$C1,$C1,$C1,$C1,$C1,$C1,$C1
	DB $c1,$c1,$c1,$c1,$c1,$c1,$c1,$c1
	; 
	; 	DATA BYTE $F1,$F1,$F1,$F1,$F1,$F1,$F1,$F1
	DB $f1,$f1,$f1,$f1,$f1,$f1,$f1,$f1
	; 
	; game_sprites:
cvb_GAME_SPRITES:
	; 	BITMAP "................"
	; 	BITMAP ".......X.X.X...."
	; 	BITMAP ".....X.XXXXX...."
	; 	BITMAP "......XXXXXX...."
	; 	BITMAP ".....XXXXX.X...."
	; 	BITMAP "......XX.XXX...."
	; 	BITMAP ".....XXX...X...."
	; 	BITMAP "...XXXX.XXX....."
	; 	BITMAP "..XX.XXX........"
	; 	BITMAP ".XX..XXXX.XXX..."
	; 	BITMAP ".XXX.XXXX.XXX..."
	; 	BITMAP ".XXX.X.........."
	; 	BITMAP "......XXXX......"
	; 	BITMAP "....XXX.XXXXX..."
	; 	BITMAP "....XXX..XXXXX.."
	; 	BITMAP "....XXXX........"
	DB $00,$01,$05,$03,$07,$03,$07,$1e
	DB $37,$67,$77,$74,$03,$0e,$0e,$0f
	DB $00,$50,$f0,$f0,$d0,$70,$10,$e0
	DB $00,$b8,$b8,$00,$c0,$f8,$7c,$00
	; 
	; 	BITMAP "........X.X.X..."
	; 	BITMAP "......X.XXXXX..."
	; 	BITMAP ".......XXXXXX..."
	; 	BITMAP "......XXXXX.X..."
	; 	BITMAP ".......XX.XXX..."
	; 	BITMAP "......XXX...X..."
	; 	BITMAP "......XX.XXX...."
	; 	BITMAP ".....XXXX......."
	; 	BITMAP ".....XXXXX......"
	; 	BITMAP ".....XX.XXX....."
	; 	BITMAP ".....XX.XXX....."
	; 	BITMAP ".....XXX........"
	; 	BITMAP "......XXXX......"
	; 	BITMAP "......XX........"
	; 	BITMAP "......XXXX......"
	; 	BITMAP "......XXXXX....."
	DB $00,$02,$01,$03,$01,$03,$03,$07
	DB $07,$06,$06,$07,$03,$03,$03,$03
	DB $a8,$f8,$f8,$e8,$b8,$88,$70,$80
	DB $c0,$e0,$e0,$00,$c0,$00,$c0,$e0
	; 
	; 	BITMAP "................"
	; 	BITMAP "....X.X.X......."
	; 	BITMAP "....XXXXX.X....."
	; 	BITMAP "....XXXXXX......"
	; 	BITMAP "....X.XXXXX....."
	; 	BITMAP "....XXX.XX......"
	; 	BITMAP "....X...XXX....."
	; 	BITMAP ".....XXX.XXXX..."
	; 	BITMAP "........XXX.XX.."
	; 	BITMAP "...XXX.XXXX..XX."
	; 	BITMAP "...XXX.XXXX.XXX."
	; 	BITMAP "..........X.XXX."
	; 	BITMAP "......XXXX......"
	; 	BITMAP "...XXXXX.XXX...."
	; 	BITMAP "..XXXXX..XXX...."
	; 	BITMAP "........XXXX...."
	DB $00,$0a,$0f,$0f,$0b,$0e,$08,$07
	DB $00,$1d,$1d,$00,$03,$1f,$3e,$00
	DB $00,$80,$a0,$c0,$e0,$c0,$e0,$78
	DB $ec,$e6,$ee,$2e,$c0,$70,$70,$f0
	; 
	; 	BITMAP "...X.X.X........"
	; 	BITMAP "...XXXXX.X......"
	; 	BITMAP "...XXXXXX......."
	; 	BITMAP "...X.XXXXX......"
	; 	BITMAP "...XXX.XX......."
	; 	BITMAP "...X...XXX......"
	; 	BITMAP "....XXX.XX......"
	; 	BITMAP ".......XXXX....."
	; 	BITMAP "......XXXXX....."
	; 	BITMAP ".....XXX.XX....."
	; 	BITMAP ".....XXX.XX....."
	; 	BITMAP "........XXX....."
	; 	BITMAP "......XXXX......"
	; 	BITMAP "........XX......"
	; 	BITMAP "......XXXX......"
	; 	BITMAP ".....XXXXX......"
	DB $15,$1f,$1f,$17,$1d,$11,$0e,$01
	DB $03,$07,$07,$00,$03,$00,$03,$07
	DB $00,$40,$80,$c0,$80,$c0,$c0,$e0
	DB $e0,$60,$60,$e0,$c0,$c0,$c0,$c0
	; 
	; 	BITMAP "....X.X.X.X....."
	; 	BITMAP ".....XXXXX......"
	; 	BITMAP "....XXXXXXX....."
	; 	BITMAP "....XXXXXXX....."
	; 	BITMAP ".....XXXXX..XXX."
	; 	BITMAP ".....XXXXX..XXX."
	; 	BITMAP "......XXX..XX..."
	; 	BITMAP "....XX...XXX...."
	; 	BITMAP "...XX.XXXX......"
	; 	BITMAP ".XXX............"
	; 	BITMAP ".XXX..XXXX......"
	; 	BITMAP "......X..XX....."
	; 	BITMAP ".....XX...XXX..."
	; 	BITMAP ".....XX...XXXX.."
	; 	BITMAP "...XXXX........."
	; 	BITMAP "..XXXXX........."
	DB $0a,$07,$0f,$0f,$07,$07,$03,$0c
	DB $1b,$70,$73,$02,$06,$06,$1e,$3e
	DB $a0,$c0,$e0,$e0,$ce,$ce,$98,$70
	DB $c0,$00,$c0,$60,$38,$3c,$00,$00
	; 
	; 
	; 	BITMAP ".....X.X.X.X...."
	; 	BITMAP "......XXXXX....."
	; 	BITMAP ".....XXXXXXX...."
	; 	BITMAP ".....XXXXXXX...."
	; 	BITMAP ".XXX..XXXXX....."
	; 	BITMAP ".XXX..XXXXX....."
	; 	BITMAP "...XX..XXX......"
	; 	BITMAP "....XXX...XX...."
	; 	BITMAP "......XXXX.XX..."
	; 	BITMAP "............XXX."
	; 	BITMAP "......XXXX..XXX."
	; 	BITMAP ".....XX..X......"
	; 	BITMAP "...XXX...XX....."
	; 	BITMAP "..XXX....XX....."
	; 	BITMAP ".........XXXX..."
	; 	BITMAP ".........XXXXX.."
	DB $05,$03,$07,$07,$73,$73,$19,$0e
	DB $03,$00,$03,$06,$1c,$38,$00,$00
	DB $50,$e0,$f0,$f0,$e0,$e0,$c0,$30
	DB $d8,$0e,$ce,$40,$60,$60,$78,$7c
	; 
	; 	BITMAP "...XX.XX........"
	; 	BITMAP "..X.XX.X........"
	; 	BITMAP "..X.XX.X........"
	; 	BITMAP "..XX.XX........."
	; 	BITMAP "...XXXXX........"
	; 	BITMAP ".XXXXX.XX......."
	; 	BITMAP "X..XX.XXX......."
	; 	BITMAP "......XXX.....X."
	; 	BITMAP "....XXXX......X."
	; 	BITMAP "...XXXXX.....XX."
	; 	BITMAP "..XXXXX......XX."
	; 	BITMAP "..XXXX......XXX."
	; 	BITMAP "..XXXX..XX..XX.."
	; 	BITMAP "..XXXXXXXXX.XX.."
	; 	BITMAP "...XXXXXXXXXXX.."
	; 	BITMAP "....XXXX..XXX..."
	DB $1b,$2d,$2d,$36,$1f,$7d,$9b,$03
	DB $0f,$1f,$3e,$3c,$3c,$3f,$1f,$0f
	DB $00,$00,$00,$00,$00,$80,$80,$82
	DB $02,$06,$06,$0e,$cc,$ec,$fc,$38
	; 
	; 	BITMAP "................"
	; 	BITMAP "....XX.XX......."
	; 	BITMAP "...X.XX.X......."
	; 	BITMAP "...X.XX.X......."
	; 	BITMAP "...XX.XX........"
	; 	BITMAP "....XXXXX......."
	; 	BITMAP "...XXXX.XX......"
	; 	BITMAP ".X.XXX.XXX......"
	; 	BITMAP ".XX....XXX......"
	; 	BITMAP "....XXXXX....X.."
	; 	BITMAP "...XXXXX....XX.."
	; 	BITMAP "...XXXX.XX..XX.."
	; 	BITMAP "...XXXX.XX.XX..."
	; 	BITMAP "...XXXXXXXXXX..."
	; 	BITMAP "....XXXXX.XXX..."
	; 	BITMAP ".....XXX..XX...."
	DB $00,$0d,$16,$16,$1b,$0f,$1e,$5d
	DB $61,$0f,$1f,$1e,$1e,$1f,$0f,$07
	DB $00,$80,$80,$80,$00,$80,$c0,$c0
	DB $c0,$84,$0c,$cc,$d8,$f8,$b8,$30
	; 
	; 	BITMAP "........XX.XX..."
	; 	BITMAP "........X.XX.X.."
	; 	BITMAP "........X.XX.X.."
	; 	BITMAP ".........XX.XX.."
	; 	BITMAP "........XXXXX..."
	; 	BITMAP ".......XX.XXXXX."
	; 	BITMAP ".......XXX.XX..X"
	; 	BITMAP ".X.....XXX......"
	; 	BITMAP ".X......XXXX...."
	; 	BITMAP ".XX.....XXXXX..."
	; 	BITMAP ".XX......XXXXX.."
	; 	BITMAP ".XXX......XXXX.."
	; 	BITMAP "..XX..XX..XXXX.."
	; 	BITMAP "..XX.XXXXXXXXX.."
	; 	BITMAP "..XXXXXXXXXXX..."
	; 	BITMAP "...XXX..XXXX...."
	DB $00,$00,$00,$00,$00,$01,$01,$41
	DB $40,$60,$60,$70,$33,$37,$3f,$1c
	DB $d8,$b4,$b4,$6c,$f8,$be,$d9,$c0
	DB $f0,$f8,$7c,$3c,$3c,$fc,$f8,$f0
	; 
	; 	BITMAP "................"
	; 	BITMAP ".......XX.XX...."
	; 	BITMAP ".......X.XX.X..."
	; 	BITMAP ".......X.XX.X..."
	; 	BITMAP "........XX.XX..."
	; 	BITMAP ".......XXXXX...."
	; 	BITMAP "......XX.XXXX..."
	; 	BITMAP "......XXX.XXX.X."
	; 	BITMAP "......XXX....XX."
	; 	BITMAP "..X....XXXXX...."
	; 	BITMAP "..XX....XXXXX..."
	; 	BITMAP "..XX..XX.XXXX..."
	; 	BITMAP "...XX.XX.XXXX..."
	; 	BITMAP "...XXXXXXXXXX..."
	; 	BITMAP "...XXX.XXXXX...."
	; 	BITMAP "....XX..XXX....."
	DB $00,$01,$01,$01,$00,$01,$03,$03
	DB $03,$21,$30,$33,$1b,$1f,$1d,$0c
	DB $00,$b0,$68,$68,$d8,$f0,$78,$ba
	DB $86,$f0,$f8,$78,$78,$f8,$f0,$e0
	; 
	; start_song:	PROCEDURE
cvb_START_SONG:
	; 	tick_note = 8
	LDA #8
	STA cvb_TICK_NOTE
	; 	song_note = 47
	LDA #47
	STA cvb_SONG_NOTE
	; 	END
	RTS
	; 
	; play_song:	PROCEDURE
cvb_PLAY_SONG:
	; 	tick_note = tick_note + 1.
	LDA cvb_TICK_NOTE
	CLC
	ADC #1
	STA cvb_TICK_NOTE
	; 	IF tick_note = 16. THEN
	LDA cvb_TICK_NOTE
	CMP #16
	BEQ cv123
	JMP cv122
cv123:
	; 		tick_note = 0.
	LDA #0
	STA cvb_TICK_NOTE
	; 		song_note = song_note + 1.
	LDA cvb_SONG_NOTE
	CLC
	ADC #1
	STA cvb_SONG_NOTE
	; 		IF song_note = 48. THEN song_note = 0.
	LDA cvb_SONG_NOTE
	CMP #48
	BEQ cv125
	JMP cv124
cv125:
	LDA #0
	STA cvb_SONG_NOTE
cv124:
	; 		note = song_notes(song_note)
	LDA cvb_SONG_NOTE
	LDY #0
	CLC
	ADC #cvb_SONG_NOTES
	TAX
	TYA
	ADC #cvb_SONG_NOTES>>8
	TAY
	TXA
	JSR _peek8
	STA cvb_NOTE
	; 		SOUND 0, #note_freq(note - 1)
	LDA cvb_NOTE
	LDY #0
	SEC
	SBC #1
	TAX
	TYA
	SBC #0
	TAY
	TXA
	STY temp
	ASL A
	ROL temp
	LDY temp
	CLC
	ADC #cvb_#NOTE_FREQ
	TAX
	TYA
	ADC #cvb_#NOTE_FREQ>>8
	TAY
	TXA
	JSR _peek16
	LDX #$80
	JSR sn76489_freq
	; 	END IF
cv122:
	; 	SOUND 0, , volume_effect(tick_note)
	LDA cvb_TICK_NOTE
	LDY #0
	CLC
	ADC #cvb_VOLUME_EFFECT
	TAX
	TYA
	ADC #cvb_VOLUME_EFFECT>>8
	TAY
	TXA
	JSR _peek8
	LDX #$90
	JSR sn76489_vol
	; 	END
	RTS
	; 
	; sound_off:	PROCEDURE
cvb_SOUND_OFF:
	; 	SOUND 0,,0
	LDA #0
	LDX #$90
	JSR sn76489_vol
	; 	SOUND 1,,0
	LDA #0
	LDX #$b0
	JSR sn76489_vol
	; 	SOUND 2,,0
	LDA #0
	LDX #$d0
	JSR sn76489_vol
	; 	SOUND 3,,0
	LDA #0
	LDX #$f0
	JSR sn76489_vol
	; 	END
	RTS
	; 
	; volume_effect:
cvb_VOLUME_EFFECT:
	; 	DATA BYTE 11,12,13,12,12,11,11,10
	DB $0b,$0c,$0d,$0c,$0c,$0b,$0b,$0a
	; 	DATA BYTE 10,9,9,10,10,9,9,8
	DB $0a,$09,$09,$0a,$0a,$09,$09,$08
	; 
	; song_notes:
cvb_SONG_NOTES:
	; 	DATA BYTE 1,2,3,4,5,4,3,2
	DB $01,$02,$03,$04,$05,$04,$03,$02
	; 	DATA BYTE 1,2,3,4,5,4,3,2
	DB $01,$02,$03,$04,$05,$04,$03,$02
	; 	DATA BYTE 6,4,7,8,9,8,7,4
	DB $06,$04,$07,$08,$09,$08,$07,$04
	; 	DATA BYTE 6,4,7,8,9,8,7,4
	DB $06,$04,$07,$08,$09,$08,$07,$04
	; 	DATA BYTE 3,12,8,10,11,10,8,12
	DB $03,$0c,$08,$0a,$0b,$0a,$08,$0c
	; 	DATA BYTE 6,4,7,8,9,8,7,4
	DB $06,$04,$07,$08,$09,$08,$07,$04
	; 
	; #note_freq:
cvb_#NOTE_FREQ:
	; 	DATA $01AC
	DW $01ac
	; 	DATA $0153
	DW $0153
	; 	DATA $011D
	DW $011d
	; 	DATA $00FE
	DW $00fe
	; 	DATA $00F0
	DW $00f0
	; 	DATA $0140
	DW $0140
	; 	DATA $00D6
	DW $00d6
	; 	DATA $00BE
	DW $00be
	; 	DATA $00B4
	DW $00b4
	; 	DATA $00AA
	DW $00aa
	; 	DATA $00A0
	DW $00a0
	; 	DATA $00E2
	DW $00e2
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
