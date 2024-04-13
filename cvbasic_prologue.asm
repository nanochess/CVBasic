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
	; Revision date: Apr/13/2024. Saved bytes in SG-1000 ROMs. Faster LDIRVM.
	;                             Shorter mode setting subroutines.
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
	di
	im 1
	jp START
	db $ff,$ff
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

    if SG1000
	db $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff

	; Located at $0066
	ei		; NMI handler (pause button)
	retn
    endif

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
        CALL SETWRT
        EX DE,HL
        DEC BC
        INC C
        LD A,B
        LD B,C
        INC A
        LD C,VDP
.1:     OUTI
        JP NZ,.1
        DEC A
        JP NZ,.1
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

vdp_generic_mode:
	call nmi_off
	call WRTVDP
	ld bc,$a201
	call WRTVDP
	ld bc,$0602	; $1800 for pattern table.
	call WRTVDP
	ld b,d
	ld c,$03	; for color table.
	call WRTVDP
	ld b,e
	ld c,$04	; for bitmap table.
	call WRTVDP
	ld bc,$3605	; $1b00 for sprite attribute table.
	call WRTVDP
	ld bc,$0706	; $3800 for sprites bitmaps.
	call WRTVDP
	ld bc,$0107
	jp WRTVDP

mode_0:
	ld hl,mode
	res 2,(hl)
	ld bc,$0200
	ld de,$ff03	; $2000 for color table, $0000 for bitmaps.
	call vdp_generic_mode
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
vdp_generic_sprites:
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
	ld bc,$0200
	ld de,$ff03	; $2000 for color table, $0000 for bitmaps.
	call vdp_generic_mode
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
	jp vdp_generic_sprites

mode_2:
	ld hl,mode
	set 2,(hl)
	ld bc,$0000
	ld de,$8000	; $2000 for color table, $0000 for bitmaps.
	call vdp_generic_mode
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
	jp vdp_generic_sprites

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
    if SG1000
    else
	di
    endif
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
