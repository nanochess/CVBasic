	;
	; CVBasic prologue (BASIC compiler, 6502 target)
	;
	; by Oscar Toledo G.
	; https://nanochess.org/
	;
	; Creation date: May/13/2025.
	; Revision date: Jul/20/2025. Added code to load sprites and read controllers.
	; Revision date: Aug/23/2025. Support for writing VRAM and PRINT.
	; Revision date: Aug/24/2025. Support for scrolling, SCREEN, and DISABLE/ENABLE.
	;                             Added music player.
	; Revision date: Aug/25/2025. Added support for 256K and 512K ROM.
	; Revision date: Aug/26/2025. Added support for CHRRAM selection.
	;

	CPU 6502

	;
	; Platforms supported:
	; o NES/Famicom
	;

	;
	; CVBasic variables in zero page.
	;

ppu_source:	equ $00	; Used in NMI for source address for PPU copy
	; This is a block of 8 bytes that should stay together.
temp:		equ $02
temp2:		equ $04
result:		equ $06
pointer:	equ $08

read_pointer:	equ $0a
cursor:		equ $0c
mode:           equ $0e
ntsc:		equ $0f

vdp_status:	equ $10
flicker:	equ $11
frame:		equ $12
ppu_pointer:	equ $14
ppu_temp:	equ $15	; Used in NMI to save X
ppu_ctrl:	equ $16
ppu_mask:	equ $17
scroll_x:	equ $18
scroll_y:	equ $1a
CHRRAM_BANK:	equ $1c
cont_bits:	equ $1d
lfsr:		equ $1e

joy1_data:	equ $20
joy2_data:	equ $21
key1_data:	equ $22
key2_data:	equ $23
sprite_data:	equ $24

	IF CVBASIC_MUSIC_PLAYER
music_playing:		EQU $4f
music_bank:             EQU $30
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
music_tick:		EQU $4d
music_mode:		EQU $4e
	ENDIF

SPRITE_PAGE:	EQU $02
PPUBUF:		EQU $0100
BANKSEL:	EQU $C000

	FORG $0000
	; The ORG address doesn't matter here
	; iNES cartridge header
	DB "NES",$1A
	DB NES_PRG_BANKS
    if CVBASIC_BANK_SWITCHING
	DB 0	; It has CHRRAM
	DB $e2|NES_NAMETABLE	; Cartridge type LSB
	DB $10	; Cartridge type MSB
	DB $00	; Number of 8K RAM pages.
    else
	DB NES_CHR_BANKS
	DB $00|NES_NAMETABLE	; Cartridge type LSB
	DB $00	; Cartridge type MSB
	DB $00	; Number of 8K RAM pages.
    endif
	DB $00,$00,$00,$00,$00,$00,$00	; Reserved

    if CVBASIC_BANK_SWITCHING
        if CVBASIC_BANK_ROM_SIZE-512
		FORG $3c010
		ORG $c000
        else
		FORG $7c010
		ORG $c000
        endif
    else
	FORG $0010
	ORG $8000
    endif
	
PPUCTRL:	EQU $2000
PPUMASK:	EQU $2001
PPUSTATUS:	EQU $2002
OAMADDR:	EQU $2003
OAMDATA:	EQU $2004
PPUSCROLL:	EQU $2005
PPUADDR:	EQU $2006
PPUDATA:	EQU $2007
SPRRAM:		EQU $4014
CONT1:		EQU $4016
CONT2:		EQU $4017

	;
	; NES architecture prevents direct access to VRAM except
	; during the VBLANK.
	;
WRTVRM:
	PHA
	TXA
	LDX ppu_pointer
	STA PPUBUF+2,X
	PLA
	STA PPUBUF,X
	TYA
	ORA #$40
	STA PPUBUF+1,X
	INX
	INX
	INX
	STX ppu_pointer
	CPX #$40
	BCS .1
	RTS
.1:
	JMP wait

LDIRVM4:
	JSR LDIRVM2
	JSR LDIRVM2
	JSR LDIRVM2
	JSR LDIRVM2
	RTS

LDIRVM2:
	JSR LDIRVM
	LDA pointer
	CLC
	ADC temp2
	STA pointer
	BCC .1
	INC pointer+1
.1:
	RTS

LDIRVM:
	LDX ppu_pointer
	LDA pointer
	STA PPUBUF,X
	LDA pointer+1
	STA PPUBUF+1,X
	LDA #0
	SEC
	SBC temp2
	STA PPUBUF+2,X
	LDA temp
	SEC
	SBC PPUBUF+2,X
	STA PPUBUF+3,X
	LDA temp+1
	SBC #0
	STA PPUBUF+4,X
	TXA
	CLC
	ADC #5
	STA ppu_pointer
	CMP #$40
	BCS .1
	RTS
.1:
	JMP wait

ENASCR:
	LDA ppu_mask
	ORA #$18
	STA ppu_mask
	RTS

DISSCR:
	LDA ppu_mask
	AND #$E7
	STA ppu_mask
	RTS

CPYBLK:
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
	ADC #$20	; !!! Variation for scrolling
	STA pointer
	LDA pointer+1
	ADC #$00
	STA pointer+1
	DEC temp2+1
	BNE .1
	RTS

cls:
	LDA #$80
.1:
	PHA
	LDX ppu_pointer
	CMP #$8F
	BNE .2
	LDA #$00
	BEQ .3

.2:	LDA #$20
.3:	STA PPUBUF+3,X
	LDA #$40
	STA PPUBUF+2,X
	LDA #$00
	STA PPUBUF,X
	PLA
	STA PPUBUF+1,X
	PHA
	CLC
	ROR PPUBUF+1,X
	ROR PPUBUF,X
	SEC
	ROR PPUBUF+1,X
	ROR PPUBUF,X
	INX
	INX
	INX
	INX
	STX ppu_pointer
	JSR wait
	PLA
	CLC
	ADC #1
	CMP #$90
	BNE .1
	RTS

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
	
  if CVBASIC_BANK_SWITCHING
	LDA $BFFF
	PHA
  endif
	; Load sprites
	LDA mode
	AND #4		; Flicker enabled?
	BNE .5		; No, jump.
	LDA flicker
	CLC
	ADC #32
	STA flicker
	JMP .6
.5:
	LDA #$00
.6:
	STA OAMADDR
	LDX #SPRITE_PAGE	
	STX SPRRAM	; Use DMA for sprite loading

	; Screen changes
	LDA ppu_pointer	; Any change?
	BEQ .1		; No, jump.
	LDX #$00
.0:	LDY PPUBUF,X
	INX
	LDA PPUBUF,X
	INX
	STA PPUADDR	; High-byte of VRAM address.
	ROL A
	STY PPUADDR	; Low-byte of VRAM address.
	BCS .2		; Fill routine.
	BMI .7		; Single byte routine.
			; Copy routine.
	LDA PPUBUF+1,X
	STA ppu_source
	LDA PPUBUF+2,X
	STA ppu_source+1
	LDY PPUBUF,X	; Negative counter.
	INX
	INX
	INX
.4:
	LDA (ppu_source),Y
	STA PPUDATA
	INY
	BNE .4
	CPX ppu_pointer
	BNE .0
	JMP .11

	; Single byte
.7:
	LDA PPUBUF,X
	INX
	STA PPUDATA
	CPX ppu_pointer
	BNE .0
	JMP .11

	; Filling data	
.2:
	LDY PPUBUF,X
	INX
	LDA PPUBUF,X
	INX
.3:
	STA PPUDATA
	DEY
	BNE .3	
	CPX ppu_pointer
	BNE .0

.11:
	LDA #0
	STA ppu_pointer
.1:

	; Final settings for PPU
	LDA #0
	STA PPUADDR
	STA PPUADDR
	LDA scroll_x
	STA PPUSCROLL	
	LDA scroll_y
	STA PPUSCROLL
	LDA ppu_ctrl
	LSR A
	LSR A
	STA ppu_temp
	LDA scroll_y+1
	ROR A
	ROL ppu_temp	
	LDA scroll_x+1
	ROR A
	ROL ppu_temp
	LDA ppu_temp
	STA PPUCTRL
	LDA ppu_mask
	STA PPUMASK

	LDA PPUSTATUS	; VDP interruption clear.
	STA vdp_status

	; Read controllers
	LDA #$01
	STA CONT1
	STA cont_bits
	LSR A
	STA CONT1

.15:	LDA CONT1
;	LSR A
	AND #3		; So it works with Famicom
	CMP #1
	ROL cont_bits
	BCC .15

	JSR convert_joystick
	STA joy1_data
	STX key1_data

	LDA #$01
	STA CONT1
	STA cont_bits
	LSR A
	STA CONT1

.16:	LDA CONT2
;	LSR A
	AND #3		; So it works with Famicom
	CMP #1
	ROL cont_bits
	BCC .16

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
	LDA ntsc
	BEQ .12
	LDX music_tick
	INX
	CPX #6
	BNE .14
	LDX #0
.14:	STX music_tick
	BEQ .9
.12:
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

  if CVBASIC_BANK_SWITCHING
	PLA
	ORA CHRRAM_BANK
	STA BANKSEL
  endif
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
	BCC $+4
	ORA #2
	ROR cont_bits
	BCC $+4
	ORA #8
	ROR cont_bits
	BCC $+4
	ORA #4
	ROR cont_bits
	BCC $+4
	ORA #1
	ROR cont_bits
	BCC $+4
	LDX #11
	ROR cont_bits
	BCC $+4
	LDX #10
	ROR cont_bits
	BCC $+4
	ORA #$40
	ROR cont_bits
	BCC $+4
	ORA #$80
	RTS

wait:
	LDA frame
.1:	CMP frame
	BEQ .1
	RTS

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
	LDX ppu_pointer
	LDA cursor
	STA PPUBUF,X
	LDA cursor+1
	AND #$07
	ORA #$20
	STA PPUBUF+1,X
	LDA #0
	SEC
	SBC temp2
	STA PPUBUF+2,X
	LDA temp
	SEC
	SBC PPUBUF+2,X
	STA PPUBUF+3,X
	LDA temp+1
	SBC #0
	STA PPUBUF+4,X
	TXA
	CLC
	ADC #5
	STA ppu_pointer
	LDA temp2
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
	BNE print_char
.6:
	LDX #$30
.3:	PHA
	LDA #1
	STA temp
	PLA

print_char:
	PHA
	TYA
	PHA
	LDA cursor+1
	AND #$07
	ORA #$20
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

mode_0:
	JSR cls
clear_sprites:
	LDA #$F0
	LDX #0
.1:
	STA $0200,X
	INX
	INX
	INX
	INX
	BNE .1
	RTS

music_init:
	LDA #$40
	STA $4017
	LDA #$10
	STA $4000	; Channel 1 silent
	STA $4004	; Channel 2 silent
	STA $400C	; Channel 4 silent
	LDA #$0b
	STA $4015	; Enable channel 1, 2 and 4.
	LDA #$00
	STA $4010
    if CVBASIC_MUSIC_PLAYER
    else	
	RTS
    endif

    if CVBASIC_MUSIC_PLAYER
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
    if CVBASIC_BANK_SWITCHING
	LDA $BFFF
	STA music_bank
    endif
	CLI
	RTS

	;
	; Generates music
	;
music_generate:
	LDA #$10
	STA audio_vol1
	STA audio_vol2
	STA audio_vol3
	STA audio_vol4hw
	LDA music_note_counter
	BEQ .1
	JMP .2
.1:
    if CVBASIC_BANK_SWITCHING
	LDA music_bank
	ORA CHRRAM_BANK
	STA BANKSEL
    endif
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
	LDA #$06
	STA audio_noise
	LDA #$9c
	STA audio_vol4hw
	JMP .11

.12:	CMP #2		; 2 - Short drum.
	BNE .14
	LDA music_counter_4
	CMP #0
	BNE .11
	LDA #$02
	STA audio_noise
	LDA #$9c
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
	db $9a,$9c,$9d,$9d,$9c,$9c,$9c,$9c
	db $9b,$9b,$9b,$9b,$9a,$9a,$9a,$9a
	db $9b,$9b,$9b,$9b,$9a,$9a,$9a,$9a

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
	db $9d,$9d,$9c,$9c,$9b,$9b,$9a,$9a
	db $99,$99,$98,$98,$97,$97,$96,$96
	db $95,$95,$94,$94,$93,$93,$92,$92

music_piano:
	LDA music_notes_table,Y
	PHA
	LDA music_notes_table+1,Y
	TAY
	LDA .1,X
	TAX
	PLA
	RTS

.1:	
	db $dc,$db,$db,$da,$da,$d9,$d9,$d8
	db $d8,$d7,$d7,$d6,$d6,$d5,$d5,$d4
	db $d4,$d4,$d5,$d5,$d4,$d4,$d3,$d3

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
	db $1d,$1e,$1e,$1d,$1d,$1c,$1c,$1c
	db $1b,$1b,$1b,$1b,$1c,$1c,$1c,$1c
	db $1b,$1b,$1b,$1b,$1c,$1c,$1c,$1c

.2:
	db 0,0,0,0,-1,-1,-1,0
	db 1,1,1,0,-1,-1,-1,0
	db 1,1,1,0,-1,-1,-1,0

	;
	; Musical notes table.
	;
music_notes_table:
	; Silence - 0
	dw 0
	; Values for 1.79 mhz. / 16, offset 0
	; 2nd octave - Index 1
	dw 1710,1614,1524,1438,1357,1281,1209,1141,1077,1017,960,906
	; 3rd octave - Index 13
	dw 855,807,762,719,679,641,605,571,539,508,480,453
	; 4th octave - Index 25
	dw 428,404,381,360,339,320,302,285,269,254,240,226
	; 5th octave - Index 37
	dw 214,202,190,180,170,160,151,143,135,127,120,113
	; 6th octave - Index 49
	dw 107,101,95,90,85,80,76,71,67,64,60,57
	; 7th octave - Index 61
	dw 53,50,48

	;
	; When the frequency upper byte is rewritten, the
	; output phase is reset, and it creates glitches.
	; So it doesn't rewrite frequency unless the note
	; changes.
	;
music_hardware:
	LDA music_mode
	CMP #4		; PLAY SIMPLE?
	BCC .9		; Yes, jump.
	LDA audio_vol2
	AND #$0F
	BNE .9
	LDA audio_vol3
	AND #$0F
	BEQ .9
	LDA audio_vol3
	STA audio_vol2
	LDA #$10
	STA audio_vol3
	LDA audio_freq3
	LDY audio_freq3+1
	STA audio_freq2
	STY audio_freq2+1
.9:
	LDA audio_freq1
	STA $4002
	LDA music_counter_1
	CMP #1
	BNE .3
	LDA audio_freq1+1
	ORA #$08	; Keeps tone enabled
	STA $4003
.3:	LDA audio_vol1
	STA $4000
	LDA #0
	STA $4001

	LDA audio_freq2
	STA $4006
	LDA music_counter_2
	CMP #1
	BNE .4
	LDA audio_freq2+1
	ORA #$08	; Keeps tone enabled
	STA $4007
.4:	LDA audio_vol2
	STA $4004
	LDA #0
	STA $4005

	LDA music_mode
	CMP #4		; PLAY SIMPLE?
	BCC .6		; Yes, jump.

	LSR audio_freq3+1
	ROR audio_freq3
	LDA audio_freq3
	STA $400A
	LDA music_counter_3
	CMP #1
	BNE .5
	LDA audio_freq3+1
	ORA #$08	; Keeps tone enabled
	STA $400B
.5:
	LDA #$20
	STA $4008
	LDA audio_vol3
	AND #$0F
	BNE .1
	LDA #$0B
	JMP .2

.1:	LDA #$0F
.2:	STA $4015

.6:	LDA music_mode
	LSR A		; NO DRUMS?
	BCC .8
	LDA music_counter_4
	CMP #1
	BNE .7
	LDA audio_noise
	STA $400E
	ORA #$08	; Keeps tone enabled
	STA $400F
.7:	LDA audio_vol4hw
	STA $400C
.8:
	RTS

music_silence:
	db 8
	db 0,0,0,0
	db -2
    endif


    IF CVBASIC_BANK_SWITCHING
copy_chrram:
	LDA #$00
	STA PPUADDR
	STA PPUADDR
	STA temp
	STX temp+1
	LDX #32
.1:
	JSR copy_page
	DEX
	BNE .1
	RTS

copy_page:
	LDY #0
.1:
	LDA (temp),Y
	STA PPUDATA
	INY
	BNE .1
	INC temp+1
	RTS
    ENDIF

START:
	SEI
	CLD

	BIT PPUSTATUS

	LDA #$40
	STA $4017
	LDA #$10
	STA $4000	; Channel 1 silent
	STA $4004	; Channel 2 silent
	STA $400C	; Channel 4 silent
	LDA #$0b
	STA $4015	; Enable channel 1, 2 and 4.
	LDA #$00
	STA $4010

	LDA #0
	STA PPUCTRL
	STA PPUMASK
	
	TAX
.1:	STA $00,X
	STA $0100,X
	STA $0300,X
	STA $0400,X
	STA $0500,X
	STA $0600,X
	STA $0700,X
	INX
	BNE .1

	LDX #STACK
	TXS

	JSR clear_sprites

	;
	; The NES starts with the PPU registers write-protected.
	; Around 29000 cycles must happen before these can be written.
	;
	
	; lidnariq code for detecting NTSC/PAL/Dendy system
	; From: https://forums.nesdev.org/viewtopic.php?p=163258#p163258
	LDX #0
	LDY #0
	BIT PPUSTATUS
	BPL $-3	
.5:
	INX
	BNE .6
	INY
.6:
			; About 27384 cycles passed at this time.
	BIT PPUSTATUS
	BPL .5
	LDA #0
	STA PPUCTRL
	STA PPUMASK

	TYA
	CMP #16
	BCC .7
	LSR A
.7:	CLC
	ADC #$F7
	CMP #3
	BCC .8
	LDA #3		; Bad
	; 0=NTSC, 1=Pal, 2=Dendy, 3=Bad
.8:
	CMP #0		; Pass NTSC unchanged
	BEQ .9
	LDA #1		; All other PAL
.9:	EOR #1
	STA ntsc
			; About 57165 cycles passed at this time.

    IF CVBASIC_BANK_SWITCHING
	; Copy CHRROM to CHRRAM
	LDA #$00+CVBASIC_BANK_ROM_SIZE/16-3
	STA BANKSEL
	LDX #$80
	JSR copy_chrram

	LDA #$20+CVBASIC_BANK_ROM_SIZE/16-3
	STA BANKSEL
	LDX #$A0
	JSR copy_chrram

	LDA #$40+CVBASIC_BANK_ROM_SIZE/16-2
	STA BANKSEL
	LDX #$80
	JSR copy_chrram

	LDA #$60+CVBASIC_BANK_ROM_SIZE/16-2
	STA BANKSEL
	LDX #$A0
	JSR copy_chrram

	LDA #$00	; BANK SELECT 1
	STA BANKSEL
    ENDIF

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
	STA ppu_mask
	LDA #$A8	; Enable NMI, 8x16 sprites, BG=$0000, SPR=$1000, NAME=$2000
	STA ppu_ctrl
	STA PPUCTRL

	JSR music_init

	JSR mode_0

	LDA #$00
	STA joy1_data
	STA joy2_data
	LDA #$0F
	STA key1_data
	STA key2_data

