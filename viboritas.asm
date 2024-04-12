COLECO:	equ 1
SG1000:	equ 0
MSX:	equ 0
SGM:	equ 1
	;
	; CVBasic prologue (BASIC compiler for Colecovision)
	;
	; by Oscar Toledo G.
	; https://nanochess.org/
	;
	; Creation date: Feb/27/2024.
	; Revision date: Feb/29/2024. Turns off sound. Now it reads the controllers.
	;                             Added 16-bit multiply, division, modulo, and abs.
	;                             Added random generator. Added sound routines.
	; Revision date: Mar/03/2024. Removed fname directive to use gasm80.
	; Revision date: Mar/05/2024. Added support for Sega SG1000.
	; Revision date: Mar/06/2024. Added ENASCR, DISSCR, and CPYBLK.
	; Revision date: Mar/08/2024. Added modes 0, 1 and 2.
	; Revision date: Mar/12/2024. Added support for MSX.
	; Revision date: Mar/14/2024. Added _sgn16.
	; Revision date: Mar/15/2024. Added upper 16k enable for MSX.
	; Revision date: Apr/11/2024. Added support for formatting numbers. Added
	;                             support for Super Game Module.
	;

VDP:    equ $98+$26*COLECO+$26*SG1000
JOYSEL:	equ $c0
KEYSEL:	equ $80

PSG:    equ $ff-$80*SG1000
JOY1:   equ $fc-$20*SG1000
JOY2:   equ $ff-$22*SG1000

BASE_RAM: equ $e000-$7000*COLECO-$2000*SG1000+$0c00*SGM

STACK:	equ $f000-$7c00*COLECO-$2c00*SG1000+$0c00*SGM

    if COLECO
	org $8000
	db $55,$aa
	dw 0
	dw 0
	dw 0
	dw 0
	dw START

	jp 0	; rst $08
	jp 0	; rst $10
	jp 0	; rst $18
	jp 0	; rst $20
	jp 0	; rst $28
	jp 0	; rst $30
	jp 0	; rst $38

	jp nmi_handler
    endif
    if SG1000
	org $0000
	jp START
	db $ff,$ff,$ff,$ff,$ff
	jp 0
	db $ff,$ff,$ff,$ff,$ff
	jp 0
	db $ff,$ff,$ff,$ff,$ff
	jp 0
	db $ff,$ff,$ff,$ff,$ff
	jp 0
	db $ff,$ff,$ff,$ff,$ff
	jp 0
	db $ff,$ff,$ff,$ff,$ff
	jp 0
	db $ff,$ff,$ff,$ff,$ff
	jp nmi_handler	; It should be called int_handler.
	
	db $ff,$ff,$ff,$ff,$ff
	db $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
	db $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
	db $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
	db $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
	db $ff,$ff,$ff,$ff,$ff,$ff

	ei		; NMI handler (pause button)
	retn

    endif
    if MSX
	ORG $4000
	db "AB"
	dw START
	dw $0000
	dw $0000
	dw $0000
	dw $0000
    endif

WRTVDP:
	ld a,b
	out (VDP+1),a
	ld a,c
	or $80
	out (VDP+1),a
	ret

SETWRT:
	ld a,l
	out (VDP+1),a
	ld a,h
	or $40
	out (VDP+1),a
	ret

SETRD:
	ld a,l
	out (VDP+1),a
	ld a,h
        and $3f
	out (VDP+1),a
	ret

WRTVRM:
	push af
	call SETWRT
	pop af
	out (VDP),a
	ret

RDVRM:
        push af
        call SETRD
        pop af
        ex (sp),hl
        ex (sp),hl
        in a,(VDP)
        ret

FILVRM:
	push af
	call SETWRT
.1:	pop af
	out (VDP),a
	push af
	dec bc
	ld a,b
	or c
	jp nz,.1
	pop af
	ret

LDIRVM:
        EX DE,HL
.1:     LD A,(DE)
        CALL WRTVRM
        INC DE
        INC HL
        DEC BC
        LD A,B
        OR C
        JR NZ,.1
        RET

LDIRVM3:
	call .1
	call .1
.1:	push hl
	push de
	push bc
	call LDIRVM
	pop bc
	pop de
	ld a,d
	add a,8
	ld d,a
	pop hl
	ret

DISSCR:
	call nmi_off
	ld bc,$a201
	call WRTVDP
	jp nmi_on

ENASCR:
	call nmi_off
	ld bc,$e201
	call WRTVDP
	jp nmi_on

CPYBLK:
	pop hl
	ex af,af'
	pop af
	ld b,a
	pop af
	ld c,a
	pop de
	ex (sp),hl
	call nmi_off
.1:	push bc
	push hl
	push de
	ld b,0
	call LDIRVM
	pop hl
	ld bc,$0020
	add hl,bc
	ex de,hl
	pop hl
	ex af,af'
	ld c,a
	ld b,0
	add hl,bc
	ex af,af'
	pop bc
	djnz .1
	jp nmi_on
	
nmi_off:
    if COLECO
	push hl
	ld hl,mode
	set 0,(hl)
	pop hl
    endif
    if SG1000+MSX
        di
    endif
	ret

nmi_on:
    if COLECO
	push af
	push hl
	ld hl,mode
	res 0,(hl)
	nop
	bit 1,(hl)
	jp nz,nmi_handler.0
	pop hl
	pop af
    endif
    if SG1000+MSX
        ei
    endif
	ret

    if COLECO
keypad_table:
        db $0f,$08,$04,$05,$0c,$07,$0a,$02
        db $0d,$0b,$00,$09,$03,$01,$06,$0f
    endif

cls:
	ld hl,$1800
	ld (cursor),hl
	ld bc,$0300
	ld a,$20
	call nmi_off
	call FILVRM
	jp nmi_on

print_string:
	ld c,a
	ld b,0
	ld de,(cursor)
	ld a,d
	and $03
	or $18
	ld d,a
	push de
	push bc
	call nmi_off
	call LDIRVM
	call nmi_on
	pop bc
	pop hl
	add hl,bc
	ld (cursor),hl
	ret

print_number:
	ld b,0
	call nmi_off
print_number5:
	ld de,10000
	call print_digit
print_number4:
	ld de,1000
	call print_digit
print_number3:
	ld de,100
	call print_digit
print_number2:
	ld de,10
	call print_digit
print_number1:
	ld de,1
	ld b,e
	call print_digit
	jp nmi_on

print_digit:
	ld a,$2f
	or a
.2:	inc a
	sbc hl,de
	jp nc,.2
	add hl,de
	cp $30
	jr nz,.3
	ld a,b
	or a
	ret z
	dec a
	jr z,.4
	ld a,c
	jr .5	
.4:
	ld a,$30
.3:	ld b,1
.5:	push hl
	ld hl,(cursor)
	ex af,af'
	ld a,h
	and $03
	or $18
	ld h,a
	ex af,af'
	call WRTVRM
	inc hl
	ld (cursor),hl
	pop hl
	ret

define_sprite:
	ex de,hl
	ld l,a
	ld h,0
	add hl,hl	; x2
	add hl,hl	; x4
	add hl,hl	; x8
	add hl,hl	; x16
	add hl,hl	; x32
	ld c,l
	ld b,h
	pop af
	pop hl
	push af
	add hl,hl	; x2
	add hl,hl	; x4
	ld h,$07
	add hl,hl	; x8
	add hl,hl	; x16
	add hl,hl	; x32
	ex de,hl
	call nmi_off
	call LDIRVM
	jp nmi_on
	
define_char:
	ex de,hl
	ld l,a
	ld h,0
	add hl,hl	; x2
	add hl,hl	; x4
	add hl,hl	; x8
	ld c,l
	ld b,h
	pop af
	pop hl
	push af
	add hl,hl	; x2
	add hl,hl	; x4
	add hl,hl	; x8
	ex de,hl
	call nmi_off
	ld a,(mode)
	and 4
	jr nz,.1
	call LDIRVM3
	jp nmi_on
	
.1:	call LDIRVM
	jp nmi_on

define_color:
	ex de,hl
	ld l,a
	ld h,0
	add hl,hl	; x2
	add hl,hl	; x4
	add hl,hl	; x8
	ld c,l
	ld b,h
	pop af
	pop hl
	push af
	add hl,hl	; x2
	add hl,hl	; x4
	add hl,hl	; x8
	ex de,hl
	set 5,d
	call nmi_off
	call LDIRVM3
	jp nmi_on
	
update_sprite:
	pop bc
	ld (sprite_data+3),a
	pop af
	ld (sprite_data+2),a
	pop af
	ld (sprite_data+1),a
	pop af
	ld (sprite_data),a
	pop af
	push bc
	ld de,sprites
	add a,a
	add a,a
	ld e,a
	ld hl,sprite_data
	ld bc,4
	ldir
	ret

	; Fast 16-bit multiplication.
_mul16:
	ld b,h
	ld c,l
	ld a,16
	ld hl,0
.1:
	srl d
	rr e
	jr nc,.2
	add hl,bc
.2:	sla c
	rl b
	dec a
	jp nz,.1
	ret

	; Fast 16-bit division.
_div16:
	ld b,h
	ld c,l
	ld hl,0
	ld a,16
.1:
	rl c
	rl b
	adc hl,hl
	sbc hl,de
	jp nc,.2	
	add hl,de
.2:
	ccf
	dec a
	jp nz,.1
	rl c
	rl b
	ld h,b
	ld l,c
	ret

	; Fast 16-bit modulo.
_mod16:
	ld b,h
	ld c,l
	ld hl,0
	ld a,16
.1:
	rl c
	rl b
	adc hl,hl
	sbc hl,de
	jp nc,.2	
	add hl,de
.2:
	ccf
	dec a
	jp nz,.1
	ret

_abs16:
	bit 7,h
	ret z
	ld a,h
	cpl
	ld h,a
	ld a,l
	cpl
	ld l,a
	inc hl
	ret

_sgn16:
	ld a,h
	or l
	ret z
	bit 7,h
	ld hl,$ffff
	ret nz
	inc hl
	inc hl
	ret

	; Random number generator.
	; From my game Mecha Eight.
random:
        ld hl,(lfsr)
        ld a,h
        or l
        jr nz,.0
        ld hl,$7811
.0:     ld a,h
        and $80
        ld b,a
        ld a,h
        and $02
        rrca
        rrca
        xor b
        ld b,a
        ld a,h
        and $01
        rrca
        xor b
        ld b,a
        ld a,l
        and $20
        rlca
        rlca
        xor b
        rlca
        rr h
        rr l
        ld (lfsr),hl
        ret

sn76489_freq:
    if COLECO+SG1000
	ld b,a
	ld a,l
	and $0f
	or b
	out (PSG),a
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
	ld a,h
	and $3f
	out (PSG),a
    endif
	ret

sn76489_vol:
    if COLECO+SG1000
	cpl
	and $0f
	or b
	out (PSG),a
    endif
	ret

sn76489_control:
    if COLECO+SG1000
	and $0f
	or $e0
	out (PSG),a
    endif
	ret

ay3_reg:
    if COLECO
	push af
	ld a,b
	out ($50),a
	pop af
	out ($51),a
	ret
    endif
    if SG1000
        ret
    endif
    if MSX
	ld e,a
	ld a,b
	jp WRTPSG
    endif
        ret
    endif

ay3_freq:
    if COLECO
	out ($50),a
	push af
	ld a,l
	out ($51),a
	pop af
	inc a
	out ($50),a
	push af
	ld a,h
	and $0f
	out ($51),a
	pop af
	ret
    endif
    if SG1000
	ret
    endif
    if MSX
	ld e,l
	call WRTPSG
	ld e,h
	inc a
	jp WRTPSG
    endif

    if SG1000
	; Required for SG1000 as it doesn't have a BIOS
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
    endif

mode_0:
	ld hl,mode
	res 2,(hl)
	call nmi_off
	ld bc,$0200
	call WRTVDP
	ld bc,$a201
	call WRTVDP
	ld bc,$0602	; $1800 for pattern table.
	call WRTVDP
	ld bc,$ff03	; $2000 for color table.
	call WRTVDP
	ld bc,$0304	; $0000 for bitmap table.
	call WRTVDP
	ld bc,$3605	; $1b00 for sprite attribute table.
	call WRTVDP
	ld bc,$0706	; $3800 for sprites bitmaps.
	call WRTVDP
	ld bc,$0107
	call WRTVDP
    if COLECO
	ld hl,($006c)
	ld de,-128
	add hl,de
    endif
    if SG1000
	ld hl,font_bitmaps
    endif
    if MSX
	ld hl,($0004)   
	inc h
    endif
	ld de,$0100
	ld bc,$0300
	call LDIRVM3
	call nmi_on
	call nmi_off
	ld hl,$2000
	ld bc,$1800
	ld a,$f0
	call FILVRM
	call nmi_on
	call cls
	call nmi_off
	ld hl,$1b00
	ld bc,$0080
	ld a,$d1
	call FILVRM
	ld hl,sprites
	ld de,sprites+1
	ld bc,127
	ld (hl),$d1
	ldir
	call nmi_on
	call nmi_off
	ld bc,$e201	; Enable screen and interrupts.
	call WRTVDP
	jp nmi_on

mode_1:
	ld hl,mode
	res 2,(hl)
	call nmi_off
	ld bc,$0200
	call WRTVDP
	ld bc,$a201
	call WRTVDP
	ld bc,$0602	; $1800 for pattern table.
	call WRTVDP
	ld bc,$ff03	; $2000 for color table.
	call WRTVDP
	ld bc,$0304	; $0000 for bitmap table.
	call WRTVDP
	ld bc,$3605	; $1b00 for sprite attribute table.
	call WRTVDP
	ld bc,$0706	; $3800 for sprites bitmaps.
	call WRTVDP
	ld bc,$0107
	call WRTVDP
	ld hl,$0000
	ld bc,$1800
	xor a
	call FILVRM
	call nmi_on
	call nmi_off
	ld hl,$2000
	ld bc,$1800
	ld a,$f0
	call FILVRM
	call nmi_on
	ld hl,$1800
.1:	call nmi_off
	ld b,32
.2:	ld a,l
	call WRTVRM
	inc hl
	djnz .2
	call nmi_on
	ld a,h
	cp $1b
	jp nz,.1
	call nmi_off
	ld hl,$1b00
	ld bc,$0080
	ld a,$d1
	call FILVRM
	ld hl,sprites
	ld de,sprites+1
	ld bc,127
	ld (hl),$d1
	ldir
	call nmi_on
	call nmi_off
	ld bc,$e201	; Enable screen and interrupts.
	call WRTVDP
	jp nmi_on

mode_2:
	ld hl,mode
	set 2,(hl)
	call nmi_off
	ld bc,$0000
	call WRTVDP
	ld bc,$a201
	call WRTVDP
	ld bc,$0602	; $1800 for pattern table.
	call WRTVDP
	ld bc,$8003	; $2000 for color table.
	call WRTVDP
	ld bc,$0004	; $0000 for bitmap table.
	call WRTVDP
	ld bc,$3605	; $1b00 for sprite attribute table.
	call WRTVDP
	ld bc,$0706	; $3800 for sprites bitmaps.
	call WRTVDP
	ld bc,$0107
	call WRTVDP
    if COLECO
	ld hl,($006c)
	ld de,-128
	add hl,de
    endif
    if SG1000
	ld hl,font_bitmaps
    endif
    if MSX
	ld hl,($0004)   
	inc h
    endif
	ld de,$0100
	ld bc,$0300
	call LDIRVM
	call nmi_on
	call nmi_off
	ld hl,$2000
	ld bc,$0020
	ld a,$f0
	call FILVRM
	call nmi_on
	call cls
	call nmi_off
	ld hl,$1b00
	ld bc,$0080
	ld a,$d1
	call FILVRM
	ld hl,sprites
	ld de,sprites+1
	ld bc,127
	ld (hl),$d1
	ldir
	call nmi_on
	call nmi_off
	ld bc,$e201	; Enable screen and interrupts.
	call WRTVDP
	jp nmi_on

    if MSX
ENASLT: EQU $0024       ; Select slot (H=Addr, A=Slot)
RSLREG: EQU $0138       ; Read slot status in A

        ;
        ; Get slot mapping
        ; B = 16K bank (0 for $0000, 1 for $4000, 2 for $8000, 3 for $c000)
        ; A = Current slot selection status (CALL RSLREG)
        ;
get_slot_mapping:
        call rotate_slot
        ld c,a
        add a,$C1       ; EXPTBL
        ld l,a
        ld h,$FC
        ld a,(hl)
        and $80         ; Get expanded flag
        or c
        ld c,a
        inc hl
        inc hl
        inc hl
        inc hl
        ld a,(hl)       ; SLTTBL
        call rotate_slot
        rlca
        rlca
        or c            ; A contains bit 7 = Marks expanded
                        ;            bit 6 - 4 = Doesn't care
                        ;            bit 3 - 2 = Secondary mapper
                        ;            bit 1 - 0 = Primary mapper
        ret

rotate_slot:
        push bc
        dec b
        inc b
        jr z,.1
.0:     rrca
        rrca
        djnz .0
.1:     and 3
        pop bc
        ret

    endif

START:
	di
	ld sp,STACK
	in a,(VDP+1)
	ld bc,$8201
	call WRTVDP
	in a,(VDP+1)
	ld bc,$8201
	call WRTVDP

	ld hl,(lfsr)	; Save RAM trash for random generator.
	ld de,BASE_RAM
	xor a
	ld (de),a
	inc de
	bit 2,d
	jp z,$-4
	ld (lfsr),hl

    if COLECO
	ld a,($0069)
	cp 50
	ld a,0
	jr z,$+4
	ld a,1
	ld (ntsc),a
    endif
    if SG1000
	ld a,1
	ld (ntsc),a
    endif
    if MSX
	ld a,($002b)
	cpl
	rlca
	and $01
	ld (ntsc),a

        call RSLREG
        ld b,1          ; $4000-$7fff
        call get_slot_mapping
        ld h,$80
        call ENASLT     ; Map into $8000-$BFFF
    endif

    if SGM
WRITE_REGISTER:	equ $1fd9
FILL_VRAM:	equ $1f82
WRITE_VRAM:	equ $1fdf

        ld b,$00	; First step.
.0:     ld hl,$2000	; RAM at $2000.
.1:     ld (hl),h	; Try to write a byte.
        inc h
        jp p,.1		; Repeat until reaching $8000.
        ld h,$20	; Go back at $2000.
.2:     ld a,(hl)	; Read back byte.
        cp h		; Is it correct?
        jr nz,.3	; No, jump.
        inc h
        jp p,.2		; Repeat until reaching $8000.
        jp .4		; Memory valid!

.3:     ld a,$01        ; Enable SGM
        out ($53),a
        inc b
        bit 1,b         ; Already enabled?
        jr z,.0		; No, test RAM again.

        ld bc,$0000
        call WRITE_REGISTER
        ld bc,$0180
        call WRITE_REGISTER
        ld bc,$0206
        call WRITE_REGISTER
        ld bc,$0380
        call WRITE_REGISTER
        ld bc,$0400
        call WRITE_REGISTER
        ld bc,$0536
        call WRITE_REGISTER
        ld bc,$0607
        call WRITE_REGISTER
        ld bc,$070D
        call WRITE_REGISTER
        ld bc,$03F0
        ld de,$00E8 
        ld hl,$158B     ; Note! direct access to Colecovision ROM
        call WRITE_VRAM
        ld hl,$2000
        ld de,32 
        ld a,$FD
        call FILL_VRAM
        ld hl,$1B00
        ld de,128
        ld a,$D1
        call FILL_VRAM
        ld hl,$1800
        ld de,769
        ld a,$20
        call FILL_VRAM
        ld bc,$0020
        ld de,$1980 
        ld hl,.5
        call WRITE_VRAM
        ld bc,$01C0
        call WRITE_REGISTER
        jr $

.5:     db " SUPER GAME MODULE NOT DETECTED "

.4:
	ld ix,(lfsr)
        ld hl,$2000
        ld de,$2001
        ld bc,$5FFF
        ld (hl),0
        ldir
	ld (lfsr),ix
    endif
	call music_init

	xor a
	ld (mode),a

	call mode_0

	ld a,$ff
	ld (joy1_data),a
	ld (joy2_data),a
	ld a,$0f
	ld (key1_data),a
	ld (key2_data),a

    if MSX
	ld hl,nmi_handler
	ld ($fd9b),hl
	ld a,$c3
	ld ($fd9a),a
    endif

	; CVBasic program start.
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
	LD HL,128
	PUSH HL
	LD A,21
	LD HL,cvb_GAME_BITMAPS
	CALL define_char
	; 	DEFINE COLOR 128,21,game_colors
	LD HL,128
	PUSH HL
	LD A,21
	LD HL,cvb_GAME_COLORS
	CALL define_color
	; 	DEFINE SPRITE 0,10,game_sprites
	LD HL,0
	PUSH HL
	LD A,10
	LD HL,cvb_GAME_SPRITES
	CALL define_sprite
	; 
	; restart_game:
cvb_RESTART_GAME:
	; 	lives = 2
	LD A,2
	LD (cvb_LIVES),A
	; 	level = 1
	LD A,1
	LD (cvb_LEVEL),A
	; restart_level:
cvb_RESTART_LEVEL:
	; 	
	; 	PRINT AT 684,"Lives: ",lives
	LD HL,684
	LD (cursor),HL
	LD HL,cv1
	LD A,7
	CALL print_string
	JP cv2
cv1:
	DB $4c,$69,$76,$65,$73,$3a,$20
cv2:
	LD A,(cvb_LIVES)
	LD L,A
	LD H,0
	CALL print_number
	; 	PRINT AT 745,"nanochess 1990"
	LD HL,745
	LD (cursor),HL
	LD HL,cv3
	LD A,14
	CALL print_string
	JP cv4
cv3:
	DB $6e,$61,$6e,$6f,$63,$68,$65,$73
	DB $73,$20,$31,$39,$39,$30
cv4:
	; 	
	; next_level:
cvb_NEXT_LEVEL:
	; 	GOSUB draw_level
	CALL cvb_DRAW_LEVEL
	; 
	; 	x_player = 8
	LD A,8
	LD (cvb_X_PLAYER),A
	; 	y_player = 16
	LD A,16
	LD (cvb_Y_PLAYER),A
	; 	player_frame = 0
	SUB A
	LD (cvb_PLAYER_FRAME),A
	; 
	; 	x_enemy1 = random(128) + 64
	CALL random
	LD A,L
	AND 127
	ADD A,64
	LD (cvb_X_ENEMY1),A
	; 	y_enemy1 = 56
	LD A,56
	LD (cvb_Y_ENEMY1),A
	; 	enemy1_frame = 24
	LD A,24
	LD (cvb_ENEMY1_FRAME),A
	; 	x_enemy2 = random(128) + 80
	CALL random
	LD A,L
	AND 127
	ADD A,80
	LD (cvb_X_ENEMY2),A
	; 	y_enemy2 = 96
	LD A,96
	LD (cvb_Y_ENEMY2),A
	; 	enemy2_frame = 32
	LD A,32
	LD (cvb_ENEMY2_FRAME),A
	; 	x_enemy3 = random(128) + 48
	CALL random
	LD A,L
	AND 127
	ADD A,48
	LD (cvb_X_ENEMY3),A
	; 	y_enemy3 = 136
	LD A,136
	LD (cvb_Y_ENEMY3),A
	; 	enemy3_frame = 24
	LD A,24
	LD (cvb_ENEMY3_FRAME),A
	; 
	; 	enemy_speed = 0
	SUB A
	LD (cvb_ENEMY_SPEED),A
	; 
	; 	GOSUB start_song
	CALL cvb_START_SONG
	; 
	; game_loop:
cvb_GAME_LOOP:
	; 	WHILE 1
cv5:
	; 		WAIT
	HALT
	; 		GOSUB play_song
	CALL cvb_PLAY_SONG
	; 
	; 		SPRITE 0, y_player - 1, x_player, player_frame, 15
	SUB A
	PUSH AF
	LD A,(cvb_Y_PLAYER)
	DEC A
	PUSH AF
	LD A,(cvb_X_PLAYER)
	PUSH AF
	LD A,(cvb_PLAYER_FRAME)
	PUSH AF
	LD A,15
	CALL update_sprite
	; 		SPRITE 1, y_enemy1 - 1, x_enemy1, enemy1_frame, 14
	LD A,1
	PUSH AF
	LD A,(cvb_Y_ENEMY1)
	DEC A
	PUSH AF
	LD A,(cvb_X_ENEMY1)
	PUSH AF
	LD A,(cvb_ENEMY1_FRAME)
	PUSH AF
	LD A,14
	CALL update_sprite
	; 		SPRITE 2, y_enemy2 - 1, x_enemy2, enemy2_frame, 14
	LD A,2
	PUSH AF
	LD A,(cvb_Y_ENEMY2)
	DEC A
	PUSH AF
	LD A,(cvb_X_ENEMY2)
	PUSH AF
	LD A,(cvb_ENEMY2_FRAME)
	PUSH AF
	LD A,14
	CALL update_sprite
	; 		SPRITE 3, y_enemy3 - 1, x_enemy3, enemy3_frame, 14
	LD A,3
	PUSH AF
	LD A,(cvb_Y_ENEMY3)
	DEC A
	PUSH AF
	LD A,(cvb_X_ENEMY3)
	PUSH AF
	LD A,(cvb_ENEMY3_FRAME)
	PUSH AF
	LD A,14
	CALL update_sprite
	; 
	; 		GOSUB move_player
	CALL cvb_MOVE_PLAYER
	; 
	; 		c = $50 + level * 4
	LD A,(cvb_LEVEL)
	LD L,A
	LD H,0
	ADD HL,HL
	ADD HL,HL
	LD A,L
	ADD A,80
	LD (cvb_C),A
	; 		enemy_speed = enemy_speed + c
	PUSH AF
	LD A,(cvb_ENEMY_SPEED)
	POP BC
	ADD A,B
	LD (cvb_ENEMY_SPEED),A
	; 		WHILE enemy_speed >= $40
cv7:
	LD A,(cvb_ENEMY_SPEED)
	CP 64
	JP C,cv8
	; 			enemy_speed = enemy_speed - $40
	SUB 64
	LD (cvb_ENEMY_SPEED),A
	; 			GOSUB move_enemies
	CALL cvb_MOVE_ENEMIES
	; 		WEND
	JP cv7
cv8:
	; 		IF cont1.button THEN
	LD A,(joy1_data)
	AND 64
	JP Z,cv9
	; 			IF x_player > 232 AND x_player < 248 AND y_player = 136 THEN
	LD A,(cvb_Y_PLAYER)
	CP 136
	LD A,0
	JR NZ,$+3
	DEC A
	PUSH AF
	LD A,(cvb_X_PLAYER)
	CP 248
	LD A,0
	JR NC,$+3
	DEC A
	PUSH AF
	LD A,(cvb_X_PLAYER)
	PUSH AF
	LD A,232
	POP BC
	CP B
	LD A,0
	JR NC,$+3
	DEC A
	POP BC
	AND B
	POP BC
	AND B
	JP Z,cv10
	; 				GOSUB sound_off
	CALL cvb_SOUND_OFF
	; 
	; 				FOR c = 1 to 10
	LD A,1
	LD (cvb_C),A
cv11:
	; 					WAIT
	HALT
	; 					SOUND 0, 200 - c * 10, 13
	LD A,(cvb_C)
	LD L,A
	LD H,0
	LD DE,10
	CALL _mul16
	PUSH HL
	LD HL,200
	POP DE
	OR A
	SBC HL,DE
	LD A,$80
	CALL sn76489_freq
	LD A,13
	LD B,$90
	CALL sn76489_vol
	; 				NEXT c
	LD A,(cvb_C)
	INC A
	LD (cvb_C),A
	PUSH AF
	LD A,10
	POP BC
	CP B
	LD A,0
	JR NC,$+3
	DEC A
	OR A
	JP Z,cv11
	; 
	; 				level = level + 1
	LD A,(cvb_LEVEL)
	INC A
	LD (cvb_LEVEL),A
	; 				IF level = 6 THEN
	CP 6
	JP NZ,cv12
	; 					GOSUB sound_off
	CALL cvb_SOUND_OFF
	; 					PRINT AT 267," YOU WIN! "
	LD HL,267
	LD (cursor),HL
	LD HL,cv13
	LD A,10
	CALL print_string
	JP cv14
cv13:
	DB $20,$59,$4f,$55,$20,$57,$49,$4e
	DB $21,$20
cv14:
	; 					#c = FRAME
	LD HL,(frame)
	LD (cvb_#C),HL
	; 					DO
cv15:
	; 						WAIT
	HALT
	; 					LOOP WHILE FRAME - #c < 300
	LD HL,(frame)
	LD DE,(cvb_#C)
	OR A
	SBC HL,DE
	LD DE,300
	OR A
	SBC HL,DE
	JP NC,cv17
	JP cv15
cv17:
	; 					level = 1
	LD A,1
	LD (cvb_LEVEL),A
	; 					GOTO restart_level
	JP cvb_RESTART_LEVEL
	; 				END IF
cv12:
	; 				GOTO next_level	
	JP cvb_NEXT_LEVEL
	; 			END IF
cv10:
	; 		END IF
cv9:
	; 		IF ABS(y_player + 1 - y_enemy1) < 8 THEN
	LD A,(cvb_Y_ENEMY1)
	LD L,A
	LD H,0
	PUSH HL
	LD A,(cvb_Y_PLAYER)
	LD L,A
	LD H,0
	INC HL
	POP DE
	OR A
	SBC HL,DE
	CALL _abs16
	LD DE,8
	OR A
	SBC HL,DE
	JP NC,cv18
	; 			IF ABS(x_player + 1 - x_enemy1) < 8 THEN GOTO player_dies
	LD A,(cvb_X_ENEMY1)
	LD L,A
	LD H,0
	PUSH HL
	LD A,(cvb_X_PLAYER)
	LD L,A
	LD H,0
	INC HL
	POP DE
	OR A
	SBC HL,DE
	CALL _abs16
	LD DE,8
	OR A
	SBC HL,DE
	JP NC,cv19
	JP cvb_PLAYER_DIES
cv19:
	; 		END IF
cv18:
	; 		IF ABS(y_player + 1 - y_enemy2) < 8 THEN
	LD A,(cvb_Y_ENEMY2)
	LD L,A
	LD H,0
	PUSH HL
	LD A,(cvb_Y_PLAYER)
	LD L,A
	LD H,0
	INC HL
	POP DE
	OR A
	SBC HL,DE
	CALL _abs16
	LD DE,8
	OR A
	SBC HL,DE
	JP NC,cv20
	; 			IF ABS(x_player + 1 - x_enemy2) < 8 THEN GOTO player_dies
	LD A,(cvb_X_ENEMY2)
	LD L,A
	LD H,0
	PUSH HL
	LD A,(cvb_X_PLAYER)
	LD L,A
	LD H,0
	INC HL
	POP DE
	OR A
	SBC HL,DE
	CALL _abs16
	LD DE,8
	OR A
	SBC HL,DE
	JP NC,cv21
	JP cvb_PLAYER_DIES
cv21:
	; 		END IF
cv20:
	; 		IF ABS(y_player + 1 - y_enemy3) < 8 THEN
	LD A,(cvb_Y_ENEMY3)
	LD L,A
	LD H,0
	PUSH HL
	LD A,(cvb_Y_PLAYER)
	LD L,A
	LD H,0
	INC HL
	POP DE
	OR A
	SBC HL,DE
	CALL _abs16
	LD DE,8
	OR A
	SBC HL,DE
	JP NC,cv22
	; 			IF ABS(x_player + 1 - x_enemy3) < 8 THEN GOTO player_dies
	LD A,(cvb_X_ENEMY3)
	LD L,A
	LD H,0
	PUSH HL
	LD A,(cvb_X_PLAYER)
	LD L,A
	LD H,0
	INC HL
	POP DE
	OR A
	SBC HL,DE
	CALL _abs16
	LD DE,8
	OR A
	SBC HL,DE
	JP NC,cv23
	JP cvb_PLAYER_DIES
cv23:
	; 		END IF
cv22:
	; 	WEND
	JP cv5
cv6:
	; 
	; player_dies:
cvb_PLAYER_DIES:
	; 	GOSUB sound_off
	CALL cvb_SOUND_OFF
	; 
	; 	SOUND 0,640,13
	LD HL,640
	LD A,$80
	CALL sn76489_freq
	LD A,13
	LD B,$90
	CALL sn76489_vol
	; 	SOUND 1,320,13
	LD HL,320
	LD A,$a0
	CALL sn76489_freq
	LD A,13
	LD B,$b0
	CALL sn76489_vol
	; 	SOUND 2,160,13
	LD HL,160
	LD A,$c0
	CALL sn76489_freq
	LD A,13
	LD B,$d0
	CALL sn76489_vol
	; 
	; 	player_frame = 0
	SUB A
	LD (cvb_PLAYER_FRAME),A
	; 	FOR c = 0 TO 30
	SUB A
	LD (cvb_C),A
cv24:
	; 		WAIT
	HALT
	; 		WAIT
	HALT
	; 		player_frame = player_frame XOR 8
	LD A,(cvb_PLAYER_FRAME)
	XOR 8
	LD (cvb_PLAYER_FRAME),A
	; 		SPRITE 0, y_player - 1, x_player, player_frame, 15
	SUB A
	PUSH AF
	LD A,(cvb_Y_PLAYER)
	DEC A
	PUSH AF
	LD A,(cvb_X_PLAYER)
	PUSH AF
	LD A,(cvb_PLAYER_FRAME)
	PUSH AF
	LD A,15
	CALL update_sprite
	; 	NEXT c
	LD A,(cvb_C)
	INC A
	LD (cvb_C),A
	PUSH AF
	LD A,30
	POP BC
	CP B
	LD A,0
	JR NC,$+3
	DEC A
	OR A
	JP Z,cv24
	; 
	; 	GOSUB sound_off
	CALL cvb_SOUND_OFF
	; 
	; 	DO
cv25:
	; 		WAIT
	HALT
	; 		SOUND 0,200 - y_player,13
	LD A,(cvb_Y_PLAYER)
	LD L,A
	LD H,0
	PUSH HL
	LD HL,200
	POP DE
	OR A
	SBC HL,DE
	LD A,$80
	CALL sn76489_freq
	LD A,13
	LD B,$90
	CALL sn76489_vol
	; 		player_frame = player_frame XOR 8
	LD A,(cvb_PLAYER_FRAME)
	XOR 8
	LD (cvb_PLAYER_FRAME),A
	; 		SPRITE 0, y_player - 1, x_player, player_frame, 15
	SUB A
	PUSH AF
	LD A,(cvb_Y_PLAYER)
	DEC A
	PUSH AF
	LD A,(cvb_X_PLAYER)
	PUSH AF
	LD A,(cvb_PLAYER_FRAME)
	PUSH AF
	LD A,15
	CALL update_sprite
	; 		y_player = y_player + 2
	LD A,(cvb_Y_PLAYER)
	ADD A,2
	LD (cvb_Y_PLAYER),A
	; 	LOOP WHILE y_player < 160
	CP 160
	JP NC,cv27
	JP cv25
cv27:
	; 
	; 	GOSUB sound_off
	CALL cvb_SOUND_OFF
	; 
	; 	IF lives = 0 THEN
	LD A,(cvb_LIVES)
	AND A
	JP NZ,cv28
	; 		PRINT AT 267," GAME OVER "
	LD HL,267
	LD (cursor),HL
	LD HL,cv29
	LD A,11
	CALL print_string
	JP cv30
cv29:
	DB $20,$47,$41,$4d,$45,$20,$4f,$56
	DB $45,$52,$20
cv30:
	; 		#c = FRAME
	LD HL,(frame)
	LD (cvb_#C),HL
	; 		DO
cv31:
	; 			WAIT
	HALT
	; 		LOOP WHILE FRAME - #c < 300
	LD HL,(frame)
	LD DE,(cvb_#C)
	OR A
	SBC HL,DE
	LD DE,300
	OR A
	SBC HL,DE
	JP NC,cv33
	JP cv31
cv33:
	; 		GOTO restart_game
	JP cvb_RESTART_GAME
	; 	END IF
cv28:
	; 	lives = lives - 1
	LD A,(cvb_LIVES)
	DEC A
	LD (cvb_LIVES),A
	; 	GOTO restart_level
	JP cvb_RESTART_LEVEL
	; 
	; 	'
	; 	' Draw the current level.
	; 	'
	; draw_level:	PROCEDURE
cvb_DRAW_LEVEL:
	; 
	; 	' Get the base character to draw the level.
	; 	base_character = 128 + (level - 1) * 4
	LD A,(cvb_LEVEL)
	LD L,A
	LD H,0
	DEC HL
	ADD HL,HL
	ADD HL,HL
	LD A,L
	ADD A,128
	LD (cvb_BASE_CHARACTER),A
	; 
	; 	' Draw the background.
	; 	FOR #c = $1800 TO $1a7c STEP 4
	LD HL,6144
	LD (cvb_#C),HL
cv34:
	; 		VPOKE #c, base_character
	LD HL,(cvb_#C)
	PUSH HL
	LD A,(cvb_BASE_CHARACTER)
	POP HL
	CALL NMI_OFF
	CALL WRTVRM
	CALL NMI_ON
	; 		VPOKE #c + 1, base_character
	LD HL,(cvb_#C)
	INC HL
	PUSH HL
	LD A,(cvb_BASE_CHARACTER)
	POP HL
	CALL NMI_OFF
	CALL WRTVRM
	CALL NMI_ON
	; 		VPOKE #c + 2, base_character
	LD HL,(cvb_#C)
	INC HL
	INC HL
	PUSH HL
	LD A,(cvb_BASE_CHARACTER)
	POP HL
	CALL NMI_OFF
	CALL WRTVRM
	CALL NMI_ON
	; 		VPOKE #c + 3, base_character + 1.
	LD HL,(cvb_#C)
	INC HL
	INC HL
	INC HL
	PUSH HL
	LD A,(cvb_BASE_CHARACTER)
	INC A
	POP HL
	CALL NMI_OFF
	CALL WRTVRM
	CALL NMI_ON
	; 	NEXT #c
	LD HL,(cvb_#C)
	LD DE,4
	ADD HL,DE
	LD (cvb_#C),HL
	LD HL,6780
	LD DE,(cvb_#C)
	OR A
	SBC HL,DE
	LD A,0
	JR NC,$+3
	DEC A
	OR A
	JP Z,cv34
	; 
	; 	' Draw over the floors.
	; 	FOR #c = $1880 TO $1A60 STEP 160
	LD HL,6272
	LD (cvb_#C),HL
cv35:
	; 		FOR #d = #c TO #c + 31
	LD HL,(cvb_#C)
	LD (cvb_#D),HL
cv36:
	; 			VPOKE #d, base_character + 2.
	LD HL,(cvb_#D)
	PUSH HL
	LD A,(cvb_BASE_CHARACTER)
	ADD A,2
	POP HL
	CALL NMI_OFF
	CALL WRTVRM
	CALL NMI_ON
	; 		NEXT #d
	LD HL,(cvb_#D)
	INC HL
	LD (cvb_#D),HL
	LD HL,(cvb_#C)
	LD DE,31
	ADD HL,DE
	LD DE,(cvb_#D)
	OR A
	SBC HL,DE
	LD A,0
	JR NC,$+3
	DEC A
	OR A
	JP Z,cv36
	; 	NEXT #c
	LD HL,(cvb_#C)
	LD DE,160
	ADD HL,DE
	LD (cvb_#C),HL
	LD HL,6752
	LD DE,(cvb_#C)
	OR A
	SBC HL,DE
	LD A,0
	JR NC,$+3
	DEC A
	OR A
	JP Z,cv35
	; 
	; 	' Draw the ladders.
	; 	ladders = 6 - level
	LD A,(cvb_LEVEL)
	LD L,A
	LD H,0
	PUSH HL
	LD HL,6
	POP DE
	OR A
	SBC HL,DE
	LD A,L
	LD (cvb_LADDERS),A
	; 
	; 	FOR #c = $1880 TO $19C0 STEP 160
	LD HL,6272
	LD (cvb_#C),HL
cv37:
	; 		FOR d = 1 TO ladders
	LD A,1
	LD (cvb_D),A
cv38:
	; 			e = RANDOM(28) + 2
	CALL random
	LD DE,28
	CALL _mod16
	LD A,L
	ADD A,2
	LD (cvb_E),A
	; 			VPOKE #c + e, base_character + 3.
	LD L,A
	LD H,0
	PUSH HL
	LD HL,(cvb_#C)
	POP DE
	ADD HL,DE
	PUSH HL
	LD A,(cvb_BASE_CHARACTER)
	ADD A,3
	POP HL
	CALL NMI_OFF
	CALL WRTVRM
	CALL NMI_ON
	; 			VPOKE #c + e + 32, base_character + 3.
	LD A,(cvb_E)
	LD L,A
	LD H,0
	PUSH HL
	LD HL,(cvb_#C)
	POP DE
	ADD HL,DE
	LD DE,32
	ADD HL,DE
	PUSH HL
	LD A,(cvb_BASE_CHARACTER)
	ADD A,3
	POP HL
	CALL NMI_OFF
	CALL WRTVRM
	CALL NMI_ON
	; 			VPOKE #c + e + 64, base_character + 3.
	LD A,(cvb_E)
	LD L,A
	LD H,0
	PUSH HL
	LD HL,(cvb_#C)
	POP DE
	ADD HL,DE
	LD DE,64
	ADD HL,DE
	PUSH HL
	LD A,(cvb_BASE_CHARACTER)
	ADD A,3
	POP HL
	CALL NMI_OFF
	CALL WRTVRM
	CALL NMI_ON
	; 			VPOKE #c + e + 96, base_character + 3.
	LD A,(cvb_E)
	LD L,A
	LD H,0
	PUSH HL
	LD HL,(cvb_#C)
	POP DE
	ADD HL,DE
	LD DE,96
	ADD HL,DE
	PUSH HL
	LD A,(cvb_BASE_CHARACTER)
	ADD A,3
	POP HL
	CALL NMI_OFF
	CALL WRTVRM
	CALL NMI_ON
	; 			VPOKE #c + e + 128, base_character + 3.
	LD A,(cvb_E)
	LD L,A
	LD H,0
	PUSH HL
	LD HL,(cvb_#C)
	POP DE
	ADD HL,DE
	LD DE,128
	ADD HL,DE
	PUSH HL
	LD A,(cvb_BASE_CHARACTER)
	ADD A,3
	POP HL
	CALL NMI_OFF
	CALL WRTVRM
	CALL NMI_ON
	; 		NEXT d
	LD A,(cvb_D)
	INC A
	LD (cvb_D),A
	PUSH AF
	LD A,(cvb_LADDERS)
	POP BC
	CP B
	LD A,0
	JR NC,$+3
	DEC A
	OR A
	JP Z,cv38
	; 	NEXT #c
	LD HL,(cvb_#C)
	LD DE,160
	ADD HL,DE
	LD (cvb_#C),HL
	LD HL,6592
	LD DE,(cvb_#C)
	OR A
	SBC HL,DE
	LD A,0
	JR NC,$+3
	DEC A
	OR A
	JP Z,cv37
	; 
	; 	' Draw the "exit".
	; 	VPOKE $1A5E, 148
	LD HL,6750
	PUSH HL
	LD A,148
	POP HL
	CALL NMI_OFF
	CALL WRTVRM
	CALL NMI_ON
	; 
	; 	END
	RET
	; 
	; 	'
	; 	' Move the player
	; 	'
	; move_player:	PROCEDURE
cvb_MOVE_PLAYER:
	; 	IF cont1.left THEN
	LD A,(joy1_data)
	AND 8
	JP Z,cv39
	; 		IF y_player % 40 = 16 THEN	' Player aligned on floor
	LD A,(cvb_Y_PLAYER)
	LD L,A
	LD H,0
	LD DE,40
	CALL _mod16
	LD DE,16
	OR A
	SBC HL,DE
	JP NZ,cv40
	; 			IF x_player > 0 THEN x_player = x_player - 1
	LD A,(cvb_X_PLAYER)
	PUSH AF
	SUB A
	POP BC
	CP B
	JP NC,cv41
	LD A,(cvb_X_PLAYER)
	DEC A
	LD (cvb_X_PLAYER),A
cv41:
	; 			IF FRAME AND 4 THEN player_frame = 8 ELSE player_frame = 12
	LD HL,(frame)
	LD A,L
	AND 4
	LD L,A
	LD H,0
	LD A,H
	OR L
	JP Z,cv42
	LD A,8
	LD (cvb_PLAYER_FRAME),A
	JP cv43
cv42:
	LD A,12
	LD (cvb_PLAYER_FRAME),A
cv43:
	; 		END IF
cv40:
	; 	END IF
cv39:
	; 	IF cont1.right THEN
	LD A,(joy1_data)
	AND 2
	JP Z,cv44
	; 		IF y_player % 40 = 16 THEN	' Player aligned on floor
	LD A,(cvb_Y_PLAYER)
	LD L,A
	LD H,0
	LD DE,40
	CALL _mod16
	LD DE,16
	OR A
	SBC HL,DE
	JP NZ,cv45
	; 			IF x_player < 240 THEN x_player = x_player + 1
	LD A,(cvb_X_PLAYER)
	CP 240
	JP NC,cv46
	INC A
	LD (cvb_X_PLAYER),A
cv46:
	; 			IF FRAME AND 4 THEN player_frame = 0 ELSE player_frame = 4
	LD HL,(frame)
	LD A,L
	AND 4
	LD L,A
	LD H,0
	LD A,H
	OR L
	JP Z,cv47
	SUB A
	LD (cvb_PLAYER_FRAME),A
	JP cv48
cv47:
	LD A,4
	LD (cvb_PLAYER_FRAME),A
cv48:
	; 		END IF
cv45:
	; 	END IF
cv44:
	; 	IF cont1.up THEN
	LD A,(joy1_data)
	AND 1
	JP Z,cv49
	; 		IF y_player % 40 = 16 THEN	' Player aligned on floor.
	LD A,(cvb_Y_PLAYER)
	LD L,A
	LD H,0
	LD DE,40
	CALL _mod16
	LD DE,16
	OR A
	SBC HL,DE
	JP NZ,cv50
	; 			column = (x_player + 7) /8
	LD A,(cvb_X_PLAYER)
	LD L,A
	LD H,0
	LD DE,7
	ADD HL,DE
	SRL H
	RR L
	SRL H
	RR L
	SRL H
	RR L
	LD A,L
	LD (cvb_COLUMN),A
	; 			row = (y_player + 8) / 8
	LD A,(cvb_Y_PLAYER)
	LD L,A
	LD H,0
	LD DE,8
	ADD HL,DE
	SRL H
	RR L
	SRL H
	RR L
	SRL H
	RR L
	LD A,L
	LD (cvb_ROW),A
	; 			#c = $1800 + row * 32 + column
	LD A,(cvb_COLUMN)
	LD L,A
	LD H,0
	PUSH HL
	LD A,(cvb_ROW)
	LD L,A
	LD H,0
	ADD HL,HL
	ADD HL,HL
	ADD HL,HL
	ADD HL,HL
	ADD HL,HL
	LD DE,6144
	ADD HL,DE
	POP DE
	ADD HL,DE
	LD (cvb_#C),HL
	; 			IF VPEEK(#c) = base_character + 3 THEN	' Ladder?
	LD A,(cvb_BASE_CHARACTER)
	LD L,A
	LD H,0
	INC HL
	INC HL
	INC HL
	PUSH HL
	LD HL,(cvb_#C)
	CALL nmi_off
	CALL RDVRM
	CALL nmi_on
	LD L,A
	LD H,0
	POP DE
	OR A
	SBC HL,DE
	JP NZ,cv51
	; 				y_player = y_player - 1
	LD A,(cvb_Y_PLAYER)
	DEC A
	LD (cvb_Y_PLAYER),A
	; 			END IF
cv51:
	; 		ELSE
	JP cv52
cv50:
	; 			IF FRAME AND 4 THEN player_frame = 16 ELSE player_frame = 20
	LD HL,(frame)
	LD A,L
	AND 4
	LD L,A
	LD H,0
	LD A,H
	OR L
	JP Z,cv53
	LD A,16
	LD (cvb_PLAYER_FRAME),A
	JP cv54
cv53:
	LD A,20
	LD (cvb_PLAYER_FRAME),A
cv54:
	; 			y_player = y_player - 1
	LD A,(cvb_Y_PLAYER)
	DEC A
	LD (cvb_Y_PLAYER),A
	; 		END IF
cv52:
	; 	END IF
cv49:
	; 	IF cont1.down THEN
	LD A,(joy1_data)
	AND 4
	JP Z,cv55
	; 		IF y_player % 40 = 16 THEN	' Player aligned on floor.
	LD A,(cvb_Y_PLAYER)
	LD L,A
	LD H,0
	LD DE,40
	CALL _mod16
	LD DE,16
	OR A
	SBC HL,DE
	JP NZ,cv56
	; 			column = (x_player + 7) /8
	LD A,(cvb_X_PLAYER)
	LD L,A
	LD H,0
	LD DE,7
	ADD HL,DE
	SRL H
	RR L
	SRL H
	RR L
	SRL H
	RR L
	LD A,L
	LD (cvb_COLUMN),A
	; 			row = (y_player + 16) / 8
	LD A,(cvb_Y_PLAYER)
	LD L,A
	LD H,0
	LD DE,16
	ADD HL,DE
	SRL H
	RR L
	SRL H
	RR L
	SRL H
	RR L
	LD A,L
	LD (cvb_ROW),A
	; 			#c = $1800 + row * 32 + column
	LD A,(cvb_COLUMN)
	LD L,A
	LD H,0
	PUSH HL
	LD A,(cvb_ROW)
	LD L,A
	LD H,0
	ADD HL,HL
	ADD HL,HL
	ADD HL,HL
	ADD HL,HL
	ADD HL,HL
	LD DE,6144
	ADD HL,DE
	POP DE
	ADD HL,DE
	LD (cvb_#C),HL
	; 			IF VPEEK(#c) = base_character + 3 THEN	' Ladder?
	LD A,(cvb_BASE_CHARACTER)
	LD L,A
	LD H,0
	INC HL
	INC HL
	INC HL
	PUSH HL
	LD HL,(cvb_#C)
	CALL nmi_off
	CALL RDVRM
	CALL nmi_on
	LD L,A
	LD H,0
	POP DE
	OR A
	SBC HL,DE
	JP NZ,cv57
	; 				y_player = y_player + 1
	LD A,(cvb_Y_PLAYER)
	INC A
	LD (cvb_Y_PLAYER),A
	; 			END IF
cv57:
	; 		ELSE
	JP cv58
cv56:
	; 			IF FRAME AND 4 THEN player_frame = 16 ELSE player_frame = 20
	LD HL,(frame)
	LD A,L
	AND 4
	LD L,A
	LD H,0
	LD A,H
	OR L
	JP Z,cv59
	LD A,16
	LD (cvb_PLAYER_FRAME),A
	JP cv60
cv59:
	LD A,20
	LD (cvb_PLAYER_FRAME),A
cv60:
	; 			y_player = y_player + 1
	LD A,(cvb_Y_PLAYER)
	INC A
	LD (cvb_Y_PLAYER),A
	; 		END IF
cv58:
	; 	END IF
cv55:
	; 	END
	RET
	; 
	; 	'
	; 	' Move the enemies.
	; 	'
	; move_enemies:	PROCEDURE
cvb_MOVE_ENEMIES:
	; 	IF enemy1_frame < 32 THEN
	LD A,(cvb_ENEMY1_FRAME)
	CP 32
	JP NC,cv61
	; 		x_enemy1 = x_enemy1 - 1.
	LD A,(cvb_X_ENEMY1)
	DEC A
	LD (cvb_X_ENEMY1),A
	; 		IF x_enemy1 = 0 THEN enemy1_frame = 32
	AND A
	JP NZ,cv62
	LD A,32
	LD (cvb_ENEMY1_FRAME),A
cv62:
	; 	ELSE
	JP cv63
cv61:
	; 		x_enemy1 = x_enemy1 + 1.
	LD A,(cvb_X_ENEMY1)
	INC A
	LD (cvb_X_ENEMY1),A
	; 		IF x_enemy1 = 240 THEN enemy1_frame = 24
	CP 240
	JP NZ,cv64
	LD A,24
	LD (cvb_ENEMY1_FRAME),A
cv64:
	; 	END IF
cv63:
	; 	enemy1_frame = (enemy1_frame AND $f8) + (FRAME AND 4)
	LD HL,(frame)
	LD A,L
	AND 4
	LD L,A
	LD H,0
	PUSH HL
	LD A,(cvb_ENEMY1_FRAME)
	LD L,A
	LD H,0
	LD A,L
	AND 248
	LD L,A
	LD H,0
	POP DE
	ADD HL,DE
	LD A,L
	LD (cvb_ENEMY1_FRAME),A
	; 
	; 	IF enemy2_frame < 32 THEN
	LD A,(cvb_ENEMY2_FRAME)
	CP 32
	JP NC,cv65
	; 		x_enemy2 = x_enemy2 - 1.
	LD A,(cvb_X_ENEMY2)
	DEC A
	LD (cvb_X_ENEMY2),A
	; 		IF x_enemy2 = 0 THEN enemy2_frame = 32
	AND A
	JP NZ,cv66
	LD A,32
	LD (cvb_ENEMY2_FRAME),A
cv66:
	; 	ELSE
	JP cv67
cv65:
	; 		x_enemy2 = x_enemy2 + 1.
	LD A,(cvb_X_ENEMY2)
	INC A
	LD (cvb_X_ENEMY2),A
	; 		IF x_enemy2 = 240 THEN enemy2_frame = 24
	CP 240
	JP NZ,cv68
	LD A,24
	LD (cvb_ENEMY2_FRAME),A
cv68:
	; 	END IF
cv67:
	; 	enemy2_frame = (enemy2_frame AND $f8) + (FRAME AND 4)
	LD HL,(frame)
	LD A,L
	AND 4
	LD L,A
	LD H,0
	PUSH HL
	LD A,(cvb_ENEMY2_FRAME)
	LD L,A
	LD H,0
	LD A,L
	AND 248
	LD L,A
	LD H,0
	POP DE
	ADD HL,DE
	LD A,L
	LD (cvb_ENEMY2_FRAME),A
	; 
	; 	IF enemy3_frame < 32 THEN
	LD A,(cvb_ENEMY3_FRAME)
	CP 32
	JP NC,cv69
	; 		x_enemy3 = x_enemy3 - 1.
	LD A,(cvb_X_ENEMY3)
	DEC A
	LD (cvb_X_ENEMY3),A
	; 		IF x_enemy3 = 0 THEN enemy3_frame = 32
	AND A
	JP NZ,cv70
	LD A,32
	LD (cvb_ENEMY3_FRAME),A
cv70:
	; 	ELSE
	JP cv71
cv69:
	; 		x_enemy3 = x_enemy3 + 1.
	LD A,(cvb_X_ENEMY3)
	INC A
	LD (cvb_X_ENEMY3),A
	; 		IF x_enemy3 = 240 THEN enemy3_frame = 24
	CP 240
	JP NZ,cv72
	LD A,24
	LD (cvb_ENEMY3_FRAME),A
cv72:
	; 	END IF
cv71:
	; 	enemy3_frame = (enemy3_frame AND $f8) + (FRAME AND 4)
	LD HL,(frame)
	LD A,L
	AND 4
	LD L,A
	LD H,0
	PUSH HL
	LD A,(cvb_ENEMY3_FRAME)
	LD L,A
	LD H,0
	LD A,L
	AND 248
	LD L,A
	LD H,0
	POP DE
	ADD HL,DE
	LD A,L
	LD (cvb_ENEMY3_FRAME),A
	; 	END
	RET
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
	DB $cc
	DB $cc
	DB $cc
	DB $cc
	DB $cc
	DB $cc
	DB $cc
	DB $cc
	; 	DATA BYTE $21,$21,$21,$21,$21,$21,$21,$21
	DB $21
	DB $21
	DB $21
	DB $21
	DB $21
	DB $21
	DB $21
	DB $21
	; 	DATA BYTE $A1,$A1,$A1,$A1,$A1,$A1,$A1,$A1
	DB $a1
	DB $a1
	DB $a1
	DB $a1
	DB $a1
	DB $a1
	DB $a1
	DB $a1
	; 	DATA BYTE $51,$51,$51,$51,$51,$51,$51,$51
	DB $51
	DB $51
	DB $51
	DB $51
	DB $51
	DB $51
	DB $51
	DB $51
	; 
	; 	DATA BYTE $54,$54,$54,$54,$54,$54,$54,$54
	DB $54
	DB $54
	DB $54
	DB $54
	DB $54
	DB $54
	DB $54
	DB $54
	; 	DATA BYTE $51,$51,$51,$51,$51,$51,$51,$51
	DB $51
	DB $51
	DB $51
	DB $51
	DB $51
	DB $51
	DB $51
	DB $51
	; 	DATA BYTE $F1,$11,$E1,$E1,$E1,$11,$11,$11
	DB $f1
	DB $11
	DB $e1
	DB $e1
	DB $e1
	DB $11
	DB $11
	DB $11
	; 	DATA BYTE $51,$51,$51,$51,$51,$51,$51,$51
	DB $51
	DB $51
	DB $51
	DB $51
	DB $51
	DB $51
	DB $51
	DB $51
	; 
	; 	DATA BYTE $68,$68,$68,$68,$68,$68,$68,$68
	DB $68
	DB $68
	DB $68
	DB $68
	DB $68
	DB $68
	DB $68
	DB $68
	; 	DATA BYTE $81,$81,$81,$81,$81,$81,$81,$81
	DB $81
	DB $81
	DB $81
	DB $81
	DB $81
	DB $81
	DB $81
	DB $81
	; 	DATA BYTE $51,$51,$51,$51,$51,$51,$51,$51
	DB $51
	DB $51
	DB $51
	DB $51
	DB $51
	DB $51
	DB $51
	DB $51
	; 	DATA BYTE $51,$51,$51,$51,$51,$51,$51,$51
	DB $51
	DB $51
	DB $51
	DB $51
	DB $51
	DB $51
	DB $51
	DB $51
	; 
	; 	DATA BYTE $61,$61,$61,$61,$61,$61,$61,$61
	DB $61
	DB $61
	DB $61
	DB $61
	DB $61
	DB $61
	DB $61
	DB $61
	; 	DATA BYTE $A1,$A1,$A1,$A1,$A1,$A1,$A1,$A1
	DB $a1
	DB $a1
	DB $a1
	DB $a1
	DB $a1
	DB $a1
	DB $a1
	DB $a1
	; 	DATA BYTE $F1,$F1,$F1,$51,$51,$F1,$F1,$F1
	DB $f1
	DB $f1
	DB $f1
	DB $51
	DB $51
	DB $f1
	DB $f1
	DB $f1
	; 	DATA BYTE $E1,$E1,$E1,$E1,$E1,$E1,$E1,$E1
	DB $e1
	DB $e1
	DB $e1
	DB $e1
	DB $e1
	DB $e1
	DB $e1
	DB $e1
	; 
	; 	DATA BYTE $86,$86,$86,$86,$86,$86,$86,$86
	DB $86
	DB $86
	DB $86
	DB $86
	DB $86
	DB $86
	DB $86
	DB $86
	; 	DATA BYTE $2C,$2C,$2C,$2C,$2C,$2C,$2C,$2C
	DB $2c
	DB $2c
	DB $2c
	DB $2c
	DB $2c
	DB $2c
	DB $2c
	DB $2c
	; 	DATA BYTE $11,$6E,$6E,$6E,$6E,$6E,$6E,$11
	DB $11
	DB $6e
	DB $6e
	DB $6e
	DB $6e
	DB $6e
	DB $6e
	DB $11
	; 	DATA BYTE $C1,$C1,$C1,$C1,$C1,$C1,$C1,$C1
	DB $c1
	DB $c1
	DB $c1
	DB $c1
	DB $c1
	DB $c1
	DB $c1
	DB $c1
	; 
	; 	DATA BYTE $F1,$F1,$F1,$F1,$F1,$F1,$F1,$F1
	DB $f1
	DB $f1
	DB $f1
	DB $f1
	DB $f1
	DB $f1
	DB $f1
	DB $f1
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
	LD A,8
	LD (cvb_TICK_NOTE),A
	; 	song_note = 47
	LD A,47
	LD (cvb_SONG_NOTE),A
	; 	END
	RET
	; 
	; play_song:	PROCEDURE
cvb_PLAY_SONG:
	; 	tick_note = tick_note + 1.
	LD A,(cvb_TICK_NOTE)
	INC A
	LD (cvb_TICK_NOTE),A
	; 	IF tick_note = 16. THEN
	CP 16
	JP NZ,cv73
	; 		tick_note = 0.
	SUB A
	LD (cvb_TICK_NOTE),A
	; 		song_note = song_note + 1.
	LD A,(cvb_SONG_NOTE)
	INC A
	LD (cvb_SONG_NOTE),A
	; 		IF song_note = 48. THEN song_note = 0.
	CP 48
	JP NZ,cv74
	SUB A
	LD (cvb_SONG_NOTE),A
cv74:
	; 		note = song_notes(song_note)
	LD A,(cvb_SONG_NOTE)
	LD L,A
	LD H,0
	LD DE,cvb_SONG_NOTES
	ADD HL,DE
	LD A,(HL)
	LD (cvb_NOTE),A
	; 		SOUND 0, #note_freq(note - 1)
	LD L,A
	LD H,0
	DEC HL
	ADD HL,HL
	LD DE,cvb_#NOTE_FREQ
	ADD HL,DE
	LD A,(HL)
	INC HL
	LD H,(HL)
	LD L,A
	LD A,$80
	CALL sn76489_freq
	; 	END IF
cv73:
	; 	SOUND 0, , volume_effect(tick_note)
	LD A,(cvb_TICK_NOTE)
	LD L,A
	LD H,0
	LD DE,cvb_VOLUME_EFFECT
	ADD HL,DE
	LD A,(HL)
	LD B,$90
	CALL sn76489_vol
	; 	END
	RET
	; 
	; sound_off:	PROCEDURE
cvb_SOUND_OFF:
	; 	SOUND 0,,0
	SUB A
	LD B,$90
	CALL sn76489_vol
	; 	SOUND 1,,0
	SUB A
	LD B,$b0
	CALL sn76489_vol
	; 	SOUND 2,,0
	SUB A
	LD B,$d0
	CALL sn76489_vol
	; 	SOUND 3,,0
	SUB A
	LD B,$f0
	CALL sn76489_vol
	; 	END
	RET
	; 
	; volume_effect:
cvb_VOLUME_EFFECT:
	; 	DATA BYTE 11,12,13,12,12,11,11,10
	DB $0b
	DB $0c
	DB $0d
	DB $0c
	DB $0c
	DB $0b
	DB $0b
	DB $0a
	; 	DATA BYTE 10,9,9,10,10,9,9,8
	DB $0a
	DB $09
	DB $09
	DB $0a
	DB $0a
	DB $09
	DB $09
	DB $08
	; 
	; song_notes:
cvb_SONG_NOTES:
	; 	DATA BYTE 1,2,3,4,5,4,3,2
	DB $01
	DB $02
	DB $03
	DB $04
	DB $05
	DB $04
	DB $03
	DB $02
	; 	DATA BYTE 1,2,3,4,5,4,3,2
	DB $01
	DB $02
	DB $03
	DB $04
	DB $05
	DB $04
	DB $03
	DB $02
	; 	DATA BYTE 6,4,7,8,9,8,7,4
	DB $06
	DB $04
	DB $07
	DB $08
	DB $09
	DB $08
	DB $07
	DB $04
	; 	DATA BYTE 6,4,7,8,9,8,7,4
	DB $06
	DB $04
	DB $07
	DB $08
	DB $09
	DB $08
	DB $07
	DB $04
	; 	DATA BYTE 3,12,8,10,11,10,8,12
	DB $03
	DB $0c
	DB $08
	DB $0a
	DB $0b
	DB $0a
	DB $08
	DB $0c
	; 	DATA BYTE 6,4,7,8,9,8,7,4
	DB $06
	DB $04
	DB $07
	DB $08
	DB $09
	DB $08
	DB $07
	DB $04
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
CVBASIC_MUSIC_PLAYER:	equ 0
CVBASIC_COMPRESSION:	equ 0
	;
	; CVBasic epilogue (BASIC compiler for Colecovision)
	;
	; by Oscar Toledo G.
	; https://nanochess.org/
	;
	; Creation date: Feb/27/2024.
	; Revision date: Feb/29/2024. Added joystick, keypad, frame, random, and
	;                             read_pointer variables.
	; Revision date: Mar/04/2024. Added music player.
	; Revision date: Mar/05/2024. Added support for Sega SG1000.
	; Revision date: Mar/12/2024. Added support for MSX.
	; Revision date: Mar/13/2024. Added Pletter decompressor.
	; Revision date: Mar/19/2024. Added support for sprite flicker.
	; Revision date: Apr/11/2024. Added support for Super Game Module.
	;

nmi_handler:
	push af
	push hl
	ld hl,mode
	bit 0,(hl)
	jr z,.1
	set 1,(hl)
	pop hl
	pop af
	retn

.0:	res 1,(hl)

.1:	push bc
	push de
    if SG1000+MSX
	in a,(VDP+1)
    endif
	ld bc,$8000+VDP
	bit 2,(hl)
	jr z,.4

	ld hl,$1b00
	call SETWRT
	ld hl,sprites
	outi
	jp nz,$-2
	jr .5

.4:
	ld hl,$1b00
	call SETWRT
	ld a,(flicker)
	add a,$04
	ld (flicker),a
	ld l,a
	ld h,sprites>>8
	ld de,24
	ld b,128
.6:
	res 7,l
	outi
	jp $+3
	outi
	jp $+3
	outi
	jp $+3
	outi
	jp $+3
	add hl,de
	jp nz,.6
.5:

    if COLECO
	out (JOYSEL),a
	ex (sp),hl
	ex (sp),hl
	in a,(JOY1)
	or $b0
	ld b,a
	in a,(JOY2)
	or $b0
	ld c,a

	out (KEYSEL),a
	ex (sp),hl
	ex (sp),hl
	in a,(JOY1)
	ld d,a
	in a,(JOY2)
	ld e,a

	ld a,d
	rlca
	or $7f
	and b
	cpl
	ld (joy1_data),a

	ld a,e
	rlca
	or $7f
	and c
	cpl
	ld (joy2_data),a

	ld a,d
	and $0f
	ld c,a
	ld b,0
	ld hl,keypad_table
	add hl,bc
	ld a,(hl)
	ld (key1_data),a

	ld a,e
	and $0f
	ld c,a
	ld hl,keypad_table
	add hl,bc
	ld a,(hl)
	ld (key2_data),a
    endif
    if SG1000
        ld b,$ff
        in a,(JOY1)
        bit 0,a
        jr nz,$+4
        res 0,b
        bit 1,a
        jr nz,$+4
        res 2,b
        bit 2,a
        jr nz,$+4
        res 3,b
        bit 3,a
        jr nz,$+4
        res 1,b
        bit 4,a
        jr nz,$+4
        res 6,b
        bit 5,a
        jr nz,$+4
        res 7,b
	push af
	ld a,b
	cpl
	ld (joy1_data),a
	pop af

	ld b,$ff
        bit 6,a
        jr nz,$+4
        res 0,b
        bit 7,a
        jr nz,$+4
        res 2,b

        in a,(JOY2)
        bit 0,a
        jr nz,$+4
        res 3,b
        bit 1,a
        jr nz,$+4
        res 1,b
        bit 2,a
        jr nz,$+4
        res 4,b
        bit 3,a
        jr nz,$+4
        res 5,b
	push af
	ld a,b
	cpl
	ld (joy2_data),a
	pop af

    endif
    if MSX

	ld a,15
	call RDPSG
	and $b0
	or $4f
	ld e,a
	ld a,15
	call WRTPSG
	ld a,14
	call RDPSG
	ld b,$ff
	bit 0,a
	jr nz,$+4
	res 0,b
	bit 3,a
	jr nz,$+4
	res 1,b
	bit 1,a
	jr nz,$+4
	res 2,b
	bit 2,a
	jr nz,$+4
	res 3,b
	bit 4,a
	jr nz,$+4
	res 6,b
	bit 5,a
	jr nz,$+4
	res 7,b
	ld a,b
	cpl
	ld (joy2_data),a

        ld b,$ff
	in a,($aa)
	and $f0
	or $08
	out ($aa),a
	in a,($a9)
	bit 5,a
	jr nz,$+4
        res 0,b
	bit 7,a
	jr nz,$+4
        res 1,b
        bit 6,a
        jr nz,$+4
        res 2,b
        bit 4,a
        jr nz,$+4
        res 3,b
	bit 0,a
	jr nz,$+4
	res 6,b
	in a,($aa)
	and $f0
	or $04
	out ($aa),a
	in a,($a9)
	bit 2,a
	jr nz,$+4
	res 7,b

	ld a,15
	call RDPSG
	and $b0
	or $0f
	ld e,a
	ld a,15
	call WRTPSG
	ld a,14
	call RDPSG
	bit 0,a
	jr nz,$+4
	res 0,b
	bit 3,a
	jr nz,$+4
	res 1,b
	bit 1,a
	jr nz,$+4
	res 2,b
	bit 2,a
	jr nz,$+4
	res 3,b
	bit 4,a
	jr nz,$+4
	res 6,b
	bit 5,a
	jr nz,$+4
	res 7,b

	ld a,b
	cpl
	ld (joy1_data),a
    endif

    if CVBASIC_MUSIC_PLAYER
	ld a,(music_mode)
	or a
	call nz,music_hardware
    endif

	ld hl,(frame)
	inc hl
	ld (frame),hl

    if CVBASIC_MUSIC_PLAYER
	;
	; Music is played with a 50hz clock.
	;
	ld a,(ntsc)
	or a
	jr z,.2
	ld a,(music_tick)
	inc a
	cp 6
	jr nz,$+3
	xor a
	ld (music_tick),a
	jr z,.3
.2:
	ld a,(music_mode)
	or a
	call nz,music_generate
.3:
    endif

	pop de
	pop bc
	pop hl
    if COLECO
	in a,(VDP+1)
	pop af
	retn
    endif
    if SG1000
	pop af
        ei
        reti
    endif
    if MSX
	pop af
        ret
    endif

	;
	; The music player code comes from my
	; game Princess Quest for Colecovision (2012)
	;

        ;
        ; Init music player.
        ;
music_init:
    if COLECO+SG1000
        ld a,$9f
        out (PSG),a
        ld a,$bf
        out (PSG),a
        ld a,$df
        out (PSG),a
        ld a,$ff
        out (PSG),a
        ld a,$ec
        out (PSG),a
    endif
    if MSX
WRTPSG:	equ $0093
RDPSG:	equ $0096

	ld a,$08
	ld e,$00
	call WRTPSG
	ld a,$09
	ld e,$00
	call WRTPSG
	ld a,$0a
	ld e,$00
	call WRTPSG
	ld a,$07
	ld e,$b8
	call WRTPSG
    endif
    if SGM
	ld b,$08
	xor a
	call ay3_reg
	ld b,$09
	call ay3_reg
	ld b,$0a
	call ay3_reg
	ld b,$07
	ld a,$b8
	call ay3_reg
    endif
    if CVBASIC_MUSIC_PLAYER
    else
	ret
    endif

    if CVBASIC_MUSIC_PLAYER
        ld a,$ff
        ld (audio_vol4hw),a
        ld a,$ec
        ld (audio_control),a
        ld a,$b8
        ld (audio_mix),a
	ld hl,music_silence
        ;
	; Play a music.
	; HL = Pointer to music.
        ;
music_play:
        call nmi_off
        ld a,(hl)          
        ld (music_timing),a
        inc hl
        ld (music_start),hl
        ld (music_pointer),hl
        xor a
        ld (music_note_counter),a
	inc a
	ld (music_playing),a
        jp nmi_on

        ;
        ; Reads 4 bytes.
        ;
music_four:
        ld b,(hl)
        inc hl
        ld c,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld e,(hl)
        ret

        ;
        ; Generates music.
        ;
music_generate:
        ld a,(audio_mix)
        and $c0                 
        or $38
        ld (audio_mix),a
        xor a                ; Turn off all the sound channels.
        ld l,a
        ld h,a
        ld (audio_vol1),hl   ; audio_vol1/audio_vol2
        ld (audio_vol3),a
	ld a,$ff
	ld (audio_vol4hw),a

        ld a,(music_note_counter)
        or a
        jp nz,.6
        ld hl,(music_pointer)
.15:    push hl
        call music_four
        pop hl
        ld a,(music_timing)
        rlca
        jr nc,.16
        ld e,d
        ld d,0
        jr .17

.16:    rlca
        jr nc,.17
        ld e,0
.17:    ld a,b		; Read first byte.
        cp -2           ; End of music?
        jr nz,.19       ; No, jump.
        xor a		; Keep at same place.
        ld (music_playing),a
        ret

.19:    cp -3           ; Repeat music?
        jp nz,.0
        ld hl,(music_start)
        jr .15

.0:     ld a,(music_timing)
        and $3f         ; Restart note time.
        ld (music_note_counter),a
        ld a,b
        cp $3f          ; Sustain?
        jr z,.1
        rlca
        rlca
        and 3
        ld (music_instrument_1),a    
        ld a,b
        and $3f
        ld (music_note_1),a    
        xor a         
        ld (music_counter_1),a    
.1:     ld a,c          
        cp $3f          
        jr z,.2
        rlca
        rlca
        and 3
        ld (music_instrument_2),a    
        ld a,c
        and $3f
        ld (music_note_2),a    
        xor a         
        ld (music_counter_2),a    
.2:     ld a,d          
        cp $3f          
        jr z,.3
        rlca
        rlca
        and 3
        ld (music_instrument_3),a    
        ld a,d
        and $3f
        ld (music_note_3),a    
        xor a         
        ld (music_counter_3),a    
.3:     ld a,e          
        ld (music_drum),a
        xor a
        ld (music_counter_4),a
        inc hl
        inc hl
        inc hl
        ld a,(music_timing)
        and $c0
        jr nz,.14
        inc hl
.14:    ld (music_pointer),hl

.6:     ld a,(music_note_1)    
        or a            
        jr z,.7         
        ld bc,(music_instrument_1)
        call music_note2freq
        ld (audio_freq1),hl 
        ld (audio_vol1),a

.7:     ld a,(music_note_2)    
        or a            
        jr z,.8         
        ld bc,(music_instrument_2)
        call music_note2freq
        ld (audio_freq2),hl 
        ld (audio_vol2),a

.8:     ld a,(music_note_3)    
        or a            
        jr z,.9         
        ld bc,(music_instrument_3)
        call music_note2freq
        ld (audio_freq3),hl 
        ld (audio_vol3),a

.9:     ld a,(music_drum)    
        or a            
        jr z,.4         
        dec a           ; 1 - Long drum.
        jr nz,.5
        ld a,(music_counter_4)
        cp 3
        jp nc,.4
.10:    ld a,5
        ld (audio_noise),a
        call enable_drum
        jr .4

.5:     dec a           ; 2 - Short durm.
        jr nz,.11
        ld a,(music_counter_4)
        or a
        jp nz,.4
        ld a,8
        ld (audio_noise),a
        call enable_drum
        jr .4

.11:    ;dec a           ; 3 - Roll.
        ;jp nz,.4
        ld a,(music_timing)
        and $3e
        rrca
        ld b,a
        ld a,(music_counter_4)
        cp 2
        jp c,.10
        cp b
        jp c,.4
        dec a
        dec a
        cp b
        jp c,.10
.4:
        ld a,(music_counter_1)
        inc a
        cp $18
        jp nz,$+5
        sub $08
        ld (music_counter_1),a

        ld a,(music_counter_2)
        inc a
        cp $18
        jp nz,$+5
        sub $08
        ld (music_counter_2),a

        ld a,(music_counter_3)
        inc a
        cp $18
        jp nz,$+5
        sub $08
        ld (music_counter_3),a

        ld hl,music_counter_4
        inc (hl)
        ld hl,music_note_counter
        dec (hl)
        ret

        ;
        ; Converts note to frequency.
 	; Input:
	;   A = Note (1-62).
	;   B = Instrument counter.
	;   C = Instrument.
        ; Output:
	;   HL = Frequency.
	;   A = Volume.
	;
music_note2freq:
        add a,a
        ld e,a
        ld d,0
        ld hl,music_notes_table
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld a,c
        or a
        jp z,music_piano
        dec a
        jp z,music_clarinet
        dec a
        jp z,music_flute
        ;
        ; Bass instrument.
        ;
music_bass:
        add hl,hl

        ;
        ; Piano instrument.
        ;
music_piano:
        ld a,b
        add a,.1&255
        ld c,a
        adc a,.1>>8
        sub c
        ld b,a
        ld a,(bc)
        ret

.1:
        db 12,11,11,10,10,9,9,8
        db 8,7,7,6,6,5,5,4
        db 4,4,5,5,4,4,3,3

        ;
        ; Clarinet instrument.
        ;
music_clarinet:
        ld a,b
        add a,.1&255
        ld c,a
        adc a,.1>>8
        sub c
        ld b,a
        ld a,(bc)
        ld e,a
        rlca
        sbc a,a
        ld d,a
        add hl,de
        srl h           
        rr l
        jp nc,.2
        inc hl
.2:     ld a,c
        add a,24
        ld c,a
	jr nc,$+3
	inc b
        ld a,(bc)
        ret

.1:
        db 0,0,0,0
        db -2,-4,-2,0
        db 2,4,2,0
        db -2,-4,-2,0
        db 2,4,2,0
        db -2,-4,-2,0

        db 13,14,14,13,13,12,12,12
        db 11,11,11,11,12,12,12,12
        db 11,11,11,11,12,12,12,12

        ;
        ; Flute instrument.
        ;
music_flute:
        ld a,b
        add a,.1&255
        ld c,a
        adc a,.1>>8
        sub c
        ld b,a
        ld a,(bc)
        ld e,a
        rlca
        sbc a,a
        ld d,a
        add hl,de
        ld a,c
        add a,24
        ld c,a
	jr nc,$+3
	inc b
        ld a,(bc)
        ret

.1:
        db 0,0,0,0
        db 0,1,2,1
        db 0,1,2,1
        db 0,1,2,1
        db 0,1,2,1
        db 0,1,2,1
                 
        db 10,12,13,13,12,12,12,12
        db 11,11,11,11,10,10,10,10
        db 11,11,11,11,10,10,10,10

        ;
        ; Emit sound.
        ;
music_hardware:
    if COLECO+SG1000
	ld a,(music_mode)
	cp 4		; PLAY SIMPLE?
	jr c,.7		; Yes, jump.
        ld a,(audio_vol2)
        or a
        jp nz,.7
        ld a,(audio_vol3)
        or a
        jp z,.7
        ld (audio_vol2),a
        xor a
        ld (audio_vol3),a
        ld hl,(audio_freq3)
        ld (audio_freq2),hl
.7:
        ld hl,(audio_freq1)
        ld a,h
        cp 4
        ld a,$9f
        jp nc,.1
        ld a,l
        and $0f
        or $80
        out (PSG),a
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld a,h
        out (PSG),a
        ld a,(audio_vol1)
        add a,ay2sn&255
        ld l,a
        adc a,ay2sn>>8
        sub l
        ld h,a
        ld a,(hl)
        or $90
.1:     out (PSG),a

        ld hl,(audio_freq2)
        ld a,h
        cp 4
        ld a,$bf
        jp nc,.2
        ld a,l
        and $0f
        or $a0
        out (PSG),a
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld a,h
        out (PSG),a
        ld a,(audio_vol2)
        add a,ay2sn&255
        ld l,a
        adc a,ay2sn>>8
        sub l
        ld h,a
        ld a,(hl)
        or $b0
.2:     out (PSG),a

	ld a,(music_mode)
	cp 4		; PLAY SIMPLE?
	jr c,.6		; Yes, jump.

        ld hl,(audio_freq3)
        ld a,h
        cp 4
        ld a,$df
        jp nc,.3
        ld a,l
        and $0f
        or $c0
        out (PSG),a
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld a,h
        out (PSG),a
        ld a,(audio_vol3)
        add a,ay2sn&255
        ld l,a
        adc a,ay2sn>>8
        sub l
        ld h,a
        ld a,(hl)
        or $d0
.3:     out (PSG),a

.6:
	ld a,(music_mode)
	and 1		; NO DRUMS?
	ret z		; Yes, return.

        ld a,(audio_vol4hw)
        inc a           
        jr z,.4        
        ld a,(audio_noise)
        cp 16
        ld b,$ec        
        jp c,.5
        ld b,$ed        
;       ld b,$ee        
.5:     ld a,(audio_control)
        cp b
        jr z,.4
        ld a,b
        ld (audio_control),a
        out (PSG),a
.4:     ld a,(audio_vol4hw)
        out (PSG),a
        ret
    endif
    if MSX
	ld a,(music_mode)
	cp 4		; PLAY SIMPLE?
	jr c,.8		; Yes, jump.	
	ld hl,audio_freq1
	ld bc,$0b00
	ld a,c
	ld e,(hl)
	call WRTPSG
	inc hl
	inc c
	djnz $-7
	ret
.8:
	ld hl,audio_freq1
	ld bc,$0400
	ld a,c
	ld e,(hl)
	call WRTPSG
	inc hl
	inc c
	djnz $-7
	inc hl
	inc hl
	inc c
	inc c
	ld a,(music_mode)
	and 1
	jr z,.9
	ld a,c
	ld e,(hl)
	call WRTPSG
	inc hl
	inc c
	ld a,c
	ld e,(hl)
	call WRTPSG
	inc hl
	inc c
	jr .10
.9:	inc hl
	inc c
	inc hl
	inc c
.10:	ld b,$02
	ld a,c
	ld e,(hl)
	call WRTPSG
	inc hl
	inc c
	djnz $-7
	ret
    endif

        ;
        ; Enable drum.
        ;
enable_drum:
    if COLECO+SG1000
        ld a,$f5
        ld (audio_vol4hw),a
    else
        ld hl,audio_mix
        ld a,(audio_vol2)
        or a
        jr nz,.1
        ld a,10
        ld (audio_vol2),a
        set 1,(hl)
.1:     res 4,(hl)
    endif
        ret

        ;
	; Musical notes table.
	;
music_notes_table:
        ; Silence - 0
        dw 0
        ; 2nd octave - 1
        dw 1721,1621,1532,1434,1364,1286,1216,1141,1076,1017,956,909
        ; 3rd octave - 13
        dw 854,805,761,717,678,639,605,571,538,508,480,453
        ; 4th octave - 25
        dw 427,404,380,360,339,321,302,285,270,254,240,226
        ; 5th octave - 37
        dw 214,202,191,180,170,160,151,143,135,127,120,113
        ; 6th octave - 49
        dw 107,101,95,90,85,80,76,71,67,64,60,57
        ; 7th octave - 61
	dw 54,51,48

    if COLECO+SG1000
        ;
        ; Converts AY-3-8910 volume to SN76489
        ;
ay2sn:
        db $0f,$0f,$0f,$0e,$0e,$0e,$0d,$0b,$0a,$08,$07,$05,$04,$03,$01,$00
    endif

music_silence:
	db 8
	db 0,0,0,0
	db -2
    endif

    if CVBASIC_COMPRESSION
define_char_unpack:
	ex de,hl
	pop af
	pop hl
	push af
	add hl,hl	; x2
	add hl,hl	; x4
	add hl,hl	; x8
	ex de,hl
	ld a,(mode)
	and 4
	jp z,unpack3
	jp unpack

define_color_unpack:
	ex de,hl
	pop af
	pop hl
	push af
	add hl,hl	; x2
	add hl,hl	; x4
	add hl,hl	; x8
	ex de,hl
	set 5,d
unpack3:
	call .1
	call .1
.1:
	push de
	push hl
	call unpack
	pop hl
	pop de
	ld a,d
	add a,8	
	ld d,a
	ret
	
        ;
        ; Pletter-0.5c decompressor (XL2S Entertainment & Team Bomba)
        ;
unpack:
; Initialization
        ld a,(hl)
        inc hl
	exx
        ld de,0
        add a,a
        inc a
        rl e
        add a,a
        rl e
        add a,a
        rl e
        rl e
        ld hl,.modes
        add hl,de
        ld c,(hl)
        inc hl
        ld b,(hl)
        push bc
        pop ix
        ld e,1
	exx
        ld iy,.loop

; Main depack loop
.literal:
        ex af,af'
        call nmi_off
        ld a,(hl)
        ex de,hl
        call WRTVRM
        ex de,hl
        inc hl
        inc de
        call nmi_on
        ex af,af'
.loop:   add a,a
        call z,.getbit
        jr nc,.literal

; Compressed data
	exx
        ld h,d
        ld l,e
.getlen: add a,a
        call z,.getbitexx
        jr nc,.lenok
.lus:    add a,a
        call z,.getbitexx
        adc hl,hl
        ret c   
        add a,a
        call z,.getbitexx
        jr nc,.lenok
        add a,a
        call z,.getbitexx
        adc hl,hl
        ret c  
        add a,a
        call z,.getbitexx
        jr c,.lus
.lenok:  inc hl
	exx
        ld c,(hl)
        inc hl
        ld b,0
        bit 7,c
        jr z,.offsok
        jp (ix)

.mode6:  add a,a
        call z,.getbit
        rl b
.mode5:  add a,a
        call z,.getbit
        rl b
.mode4:  add a,a
        call z,.getbit
        rl b
.mode3:  add a,a
        call z,.getbit
        rl b
.mode2:  add a,a
        call z,.getbit
        rl b
        add a,a
        call z,.getbit
        jr nc,.offsok
        or a
        inc b
        res 7,c
.offsok: inc bc
        push hl
	exx
        push hl
	exx
        ld l,e
        ld h,d
        sbc hl,bc
        pop bc
        ex af,af'
.loop2: 
        call nmi_off
        call RDVRM              ; unpack
        ex de,hl
        call WRTVRM
        ex de,hl        ; 4
        call nmi_on
        inc hl          ; 6
        inc de          ; 6
        dec bc          ; 6
        ld a,b          ; 4
        or c            ; 4
        jr nz,.loop2     ; 10
        ex af,af'
        pop hl
        jp (iy)

.getbit: ld a,(hl)
        inc hl
	rla
	ret

.getbitexx:
	exx
        ld a,(hl)
        inc hl
	exx
	rla
	ret

.modes:
        dw      .offsok
        dw      .mode2
        dw      .mode3
        dw      .mode4
        dw      .mode5
        dw      .mode6

    endif

	org BASE_RAM

sprites:
	rb 128
sprite_data:
	rb 4
frame:
	rb 2
read_pointer:
	rb 2
cursor:
	rb 2
lfsr:
	rb 2
mode:
	rb 1
flicker:
	rb 1
joy1_data:
	rb 1
joy2_data:
	rb 1
key1_data:
	rb 1
key2_data:
	rb 1
ntsc:
	rb 1

    if CVBASIC_MUSIC_PLAYER
music_tick:             rb 1
music_mode:             rb 1

music_start:		rb 2
music_pointer:		rb 2
music_playing:		rb 1
music_timing:		rb 1
music_note_counter:	rb 1
music_instrument_1:	rb 1
music_counter_1:	rb 1
music_note_1:		rb 1
music_instrument_2:	rb 1
music_counter_2:	rb 1
music_note_2:		rb 1
music_instrument_3:	rb 1
music_counter_3:	rb 1
music_note_3:		rb 1
music_counter_4:	rb 1
music_drum:		rb 1

audio_freq1:		rb 2
audio_freq2:		rb 2
audio_freq3:		rb 2
audio_noise:		rb 1
audio_mix:		rb 1
audio_vol1:		rb 1
audio_vol2:		rb 1
audio_vol3:		rb 1

audio_control:		rb 1
audio_vol4hw:		rb 1
    endif

    if SGM
	org $2000	; Start for variables.
    endif
cvb_Y_ENEMY1:	rb 1
cvb_Y_ENEMY2:	rb 1
cvb_Y_ENEMY3:	rb 1
cvb_C:	rb 1
cvb_D:	rb 1
cvb_E:	rb 1
cvb_PLAYER_FRAME:	rb 1
cvb_TICK_NOTE:	rb 1
cvb_LIVES:	rb 1
cvb_LEVEL:	rb 1
cvb_ENEMY1_FRAME:	rb 1
cvb_COLUMN:	rb 1
cvb_ENEMY_SPEED:	rb 1
cvb_SONG_NOTE:	rb 1
cvb_ENEMY2_FRAME:	rb 1
cvb_#C:	rb 2
cvb_#D:	rb 2
cvb_BASE_CHARACTER:	rb 1
cvb_X_PLAYER:	rb 1
cvb_ENEMY3_FRAME:	rb 1
cvb_X_ENEMY1:	rb 1
cvb_X_ENEMY2:	rb 1
cvb_X_ENEMY3:	rb 1
cvb_NOTE:	rb 1
cvb_LADDERS:	rb 1
cvb_ROW:	rb 1
cvb_Y_PLAYER:	rb 1
