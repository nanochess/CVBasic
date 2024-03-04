	;
	; BoingBASIC prologue
	;
	; by Oscar Toledo G.
	; https://nanochess.org/
	;
	; Creation date: Feb/27/2024.
	;

	fname "game.rom"

VDP:	equ $be
JOYSEL:	equ $c0
KEYSEL:	equ $80
JOY1:	equ $fc
JOY2:	equ $ff

STACK:	equ $7400

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

nmi_off:
	push hl
	ld hl,mode
	set 0,(hl)
	pop hl
	ret

nmi_on:
	push af
	push hl
	ld hl,mode
	res 0,(hl)
	nop
	bit 1,(hl)
	jr nz,nmi_handler.0
	pop hl
	pop af
	ret

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

.1:	ld hl,$1b00
	call SETWRT
	ld hl,sprites
	ld bc,$8000+VDP
	outi
	jp nz,$-2
	pop hl
	in a,(VDP+1)
	pop af
	retn

GTSTCK:
        out (JOYSEL),a
	ex (sp),hl
	ex (sp),hl
        in a,(JOY1)
	ld b,a
	in a,(JOY2)
	and b
        and $0f
        ld c,a
        ld b,0
        ld hl,.1
        add hl,bc
        ld a,(hl)
        ret

.1:
        db 0,0,0,6,0,0,8,7,0,4,0,5,2,3,1,0

GTTRIG:
        out (KEYSEL),a
        ex (sp),hl
        ex (sp),hl
        in a,(JOY1)
        ld c,a
        in a,(JOY2)
        and c
        ld c,a
	out (JOYSEL),a
	ex (sp),hl
	ex (sp),hl
	in a,(JOY1)
        and c
        ld c,a
	in a,(JOY2)
	and c
	rlca
	rlca
	ccf
	ld a,0
	sbc a,a
	ret

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
	call LDIRVM3
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

START:
	di
	ld sp,STACK
	in a,(VDP+1)
	ld bc,$8201
	call WRTVDP
	in a,(VDP+1)
	ld bc,$8201
	call WRTVDP
	xor a
	ld (mode),a
	ld bc,$0200
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

	ld hl,($006c)
	ld de,-128
	add hl,de
	push hl
	ld de,$0100
	ld bc,$0300
	call LDIRVM
	pop hl
	push hl
	ld de,$0900
	ld bc,$0300
	call LDIRVM
	pop hl
	ld de,$1100
	ld bc,$0300
	call LDIRVM
	ld hl,$2000
	ld bc,$1800
	ld a,$f1
	call FILVRM
	ld hl,$1800
	ld bc,$0300
	ld a,$20
	call FILVRM
	ld hl,$1b00
	ld bc,$0080
	ld a,$d1
	call FILVRM
	ld hl,sprites
	ld de,sprites+1
	ld bc,127
	ld (hl),$d1
	ldir
	ld hl,$3800
	ld bc,$0800
	xor a
	call FILVRM

	ld de,$0100
	ld bc,$e201	; Enable screen and interrupts.
	call WRTVDP

	; boingBASIC program start.
