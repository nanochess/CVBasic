	;
	; CVBasic prologue (BASIC compiler, 6502 target)
	;
	; by Oscar Toledo G.
	; https://nanochess.org/
	;
	; Creation date: May/13/2025.
	; Revision date: Jul/20/2025. Added code to load sprites and read controllers.
	;

	CPU 6502

	;
	; Platforms supported:
	; o NES/Famicom
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
ppu_pointer:	equ $0e

joy1_data:	equ $20
joy2_data:	equ $21
key1_data:	equ $22
key2_data:	equ $23
frame:		equ $24
lfsr:		equ $26
mode:           equ $28
cont_bits:	equ $29
sprite_data:	equ $2a
ntsc:		equ $2e
vdp_status:	equ $30

	IF CVBASIC_MUSIC_PLAYER
music_playing:		EQU $4f
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

SPRITE_PAGE:	EQU $02

	FORG $0000
	; The ORG address doesn't matter here
	; iNES cartridge header
	DB "NES",$1A
	DB NES_PRG_BANKS
	DB NES_CHR_BANKS
	DB $00	; Cartridge type LSB !!!
	DB $00	; Cartridge type MSB !!!
	DB $00	; Number of 8K RAM pages.
	DB $00,$00,$00,$00,$00,$00,$00	; Reserved

	FORG $0010
	ORG $8000
	
PPUCTRL:	EQU $2000
PPUMASK:	EQU $2001
PPUSTATUS:	EQU $2002
OAMADDR:	EQU $2003
PPUSCROLL:	EQU $2005
PPUADDR:	EQU $2006
PPUDATA:	EQU $2007
SPRRAM:		EQU $4014
CONT1:		EQU $4016
CONT2:		EQU $4017

update_sprite:
	ASL A
	ASL A
	STA pointer
	LDA #SPRITE_PAGE
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

irq_handler:
	RTI

nmi_handler:
	PHA
	TXA
	PHA
	TYA
	PHA
	
	LDA PPUSTATUS	; VDP interruption clear.
	STA vdp_status

	LDA #$00	; !!! Can be used for flicker
	STA OAMADDR
	LDA #SPRITE_PAGE	
	STA SPRRAM

	LDX #$00
	CPX ppu_pointer
	BEQ .1
	LDA $0100,X
	STA PPUADDR
	LDA $0101,X
	STA PPUADDR
	LDA $0102

.1:

	LDA #$01
	STA CONT1
	LDA #$00
	STA CONT1
	LDX #$08
	LDA CONT1
	ROR A
	ROL cont_bits
	DEX
	BNE $-7
	LDA cont_bits
	JSR convert_joystick
	STA joy1_data
	STX key1_data

	LDX #$08
	LDA CONT2
	ROR A
	ROL cont_bits
	DEX
	BNE $-7
	LDA cont_bits
	JSR convert_joystick
	STA joy2_data
	STX key2_data

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

	;CVBASIC MARK DON'T CHANGE
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

	LDA #0
	STA PPUADDR
	STA PPUADDR
	STA PPUSCROLL
	STA PPUSCROLL

	PLA
	TAY
	PLA
	TAX
	PLA
	RTI

convert_joystick:
	LDA #0
	LDX #15
	ROR cont_bits
	BCS $+4
	ORA #2
	ROR cont_bits
	BCS $+4
	ORA #8
	ROR cont_bits
	BCS $+4
	ORA #4
	ROR cont_bits
	BCS $+4
	ORA #1
	ROR cont_bits
	BCS $+4
	LDX #11
	ROR cont_bits
	BCS $+4
	LDX #10
	ROR cont_bits
	BCS $+4
	ORA #$40
	ROR cont_bits
	BCS $+4
	ORA #$80
	RTS

wait:
	LDA frame
.1:	CMP frame
	BEQ .1
	RTS

music_init:
	RTS

music_play:
	RTS

music_generate:
	RTS

music_hardware:
	RTS

START:
	SEI
	CLD

	BIT PPUSTATUS

	LDA #$40
	STA $4017
	LDA #$00
	STA $4015
	STA $4010

	STA PPUCTRL
	STA PPUMASK
	
	TAX
.1:	STA $00,X
	STA $0100,X
	STA $0200,X
	STA $0300,X
	STA $0400,X
	STA $0500,X
	STA $0600,X
	STA $0700,X
	INX
	BNE .1

	LDX #STACK
	TXS

	;
	; The NES starts with the PPU registers write-protected.
	; Around 29000 cycles must happen before these can be written.
	;
	
	BIT PPUSTATUS
	BPL $-3	
			; About 27384 cycles passed at this time.
	BIT PPUSTATUS
	BPL $-3
			; About 57165 cycles passed at this time.

	; Clear 2K of pattern memory
	LDA #$20
	STA PPUADDR
	LDA #$00
	STA PPUADDR
	LDX #$78
	LDA #$20
.2:
	STA PPUDATA
	STA PPUDATA
	STA PPUDATA
	STA PPUDATA
	STA PPUDATA
	STA PPUDATA
	STA PPUDATA
	STA PPUDATA
	DEX
	BNE .2

	LDX #$40
	LDA #$00
.3:	STA PPUDATA
	DEX
	BNE .3

	; Setup base palette
	LDA #$3F
	STA PPUADDR
	LDA #$00
	STA PPUADDR
	LDX #8
.4:
	LDA #$0F	; Black
	STA PPUDATA
	LDA #$35	; Red
	STA PPUDATA
	LDA #$3A	; Green
	STA PPUDATA
	LDA #$30	; White
	STA PPUDATA
	DEX
	BNE .4

	BIT PPUSTATUS
	BPL $-3	
	LDA #$1e	; Color normal, Sprites visible, Background visible, No clipping, Color.
	STA PPUMASK
	LDA #$A8	; Enable NMI, 8x16 sprites, BG=$0000, SPR=$1000, NAME=$2000
	STA PPUCTRL

	JSR music_init

;	JSR mode_0

	LDA #$00
	STA joy1_data
	STA joy2_data
	LDA #$0F
	STA key1_data
	STA key2_data

