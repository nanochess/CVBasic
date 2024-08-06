	;
	; CVBasic prologue (BASIC compiler, 6502 target)
	;
	; by Oscar Toledo G.
	; https://nanochess.org/
	;
	; Creation date: Aug/05/2024.
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
lfsr:		equ $0e

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
mode:           equ $26
flicker:	equ $27
sprite_data:	equ $28
ntsc:		equ $2c
music_mode:	equ $2d
music_playing:	equ $2e

sprites:	equ $0180

	ORG $4000
	
WRTVDP:
	STA $3001
	TXA
	ORA #$80
	STA $3001
	RTS

SETWRT:
	STA $3001
	TYA
	ORA #$40
	STA $3001
	RTS

SETRD:
	STA $3001
	TYA
	AND #$3F
	STA $3001
	RTS

WRTVRM:
	JSR SETWRT
	TXA		; !!! Delay
	STA $3000
	RTS

RDVRM:
	JSR SETRD
	PHA		; !!! Delay
	PLA
	LDA $2000
	RTS

FILVRM:
	LDA pointer
	LDY pointer+1
	JSR SETWRT
	LDA temp2
	BEQ .1
	INC temp2+1
.1:
	LDA temp
	STA $3000
	DEC temp2
	BNE .1
	DEC temp2+1
	BNE .1
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
	LDA (temp),Y
	STA $3000
	INC temp
	BNE .3
	INC temp+1
.3:
	DEC temp2
	BNE .2
	DEC temp2+1
	BNE .2
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
	AND #$80
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
	LDA #$0100
	LDY #$0100>>8
	STA pointer
	STY pointer+1
	LDA #$0300
	LDY #$0300>>8
	STA temp2
	STY temp2+1
	JSR LDIRVM3
	CLI
	SEI
	LDA #$f0
	STA temp
	LDA #$2000
	LDY #$2000>>8
	STA pointer
	STY pointer+1
	LDA #$1800
	LDY #$1800>>8
	STA temp2
	STY temp2+1
	JSR FILVRM
	CLI
	JSR cls
vdp_generic_sprites:
	SEI
	LDA #$d1
	STA temp
	LDA #$1b00
	LDY #$1b00>>8
	STA pointer
	STY pointer+1
	LDA #$0080
	LDY #$0080>>8
	STA temp2
	STY temp2+1
	JSR FILVRM
	LDX #$7F
	LDA #$D1
.1:
	STA sprites,X
	DEX
	BPL .1
	CLI
	SEI
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
	LDA #00
	STA temp
	LDA #$0000
	LDY #$0000>>8
	STA pointer
	STY pointer+1
	LDA #$1800
	LDY #$1800>>8
	STA temp2
	STY temp2+1
	JSR FILVRM
	CLI
	SEI
	LDA #$f0
	STA temp
	LDA #$2000
	LDY #$2000>>8
	STA pointer
	STY pointer+1
	LDA #$1800
	LDY #$1800>>8
	STA temp2
	STY temp2+1
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
.2:
	LDA pointer
	STA $3000	; !!! Delay
	DEX
	BNE .2
	CLI
	LDA pointer
	CLC
	ADC #32
	STA pointer
	BCS .3
	INC pointer+1
.3:
	LDA pointer+1
	CMP #$1B
	BNE .1
	JMP vdp_generic_sprites

mode_2:
	LDA mode
	AND #$FB
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
	LDA #$0100
	LDY #$0100>>8
	STA pointer
	STY pointer+1
	LDA #$0300
	LDY #$0300>>8
	STA temp2
	STY temp2+1
	JSR LDIRVM
	CLI
	SEI
	LDA #$f0
	STA temp
	LDA #$2000
	LDY #$2000>>8
	STA pointer
	STY pointer+1
	LDA #$0020
	LDY #$0020>>8
	STA temp2
	STY temp2+1
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
.7:	LDA sprites,X
	STA $3000	; !!! Delay
	INX
	CPX #$80
	BNE .7
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
	STA $3000	; !!! Delay
	INX
	LDA sprites,X
	STA $3000
	INX
	LDA sprites,X
	STA $3000
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
	BEQ .7
	JSR music_hardware
.7:
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
	; !!!
	RTS

    if CVBASIC_MUSIC_PLAYER
music_play:
	; !!!
	RTS

music_generate:
	; !!!
	RTS

music_hardware:
	; !!!
	RTS

music_silence:
	db 8
	db 0,0,0,0
	db -2
    endif

    if CVBASIC_COMPRESSION
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

