	;
	; BoingBASIC prologue
	;
	; by Oscar Toledo G.
	; https://nanochess.org/
	;
	; Creation date: Feb/27/2024.
	; Revision date: Feb/29/2024. Turns off sound. Now it reads the controllers.
	;                             Added 16-bit multiply, division, modulo, and abs.
	;                             Added random generator. Added sound routines.
	;

	fname "game.rom"

VDP:	equ $be
JOYSEL:	equ $c0
KEYSEL:	equ $80
JOY1:	equ $fc
JOY2:	equ $ff
PSG:	equ $ff

TURN_OFF_SOUND:	equ $1fd6

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

.1:	push bc
	push de
	ld hl,$1b00
	call SETWRT
	ld hl,sprites
	ld bc,$8000+VDP
	outi
	jp nz,$-2

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

	ld hl,(frame)
	inc hl
	ld (frame),hl

	pop de
	pop bc
	pop hl
	in a,(VDP+1)
	pop af
	retn

keypad_table:
        db $0f,$08,$04,$05,$0c,$07,$0a,$02
        db $0d,$0b,$00,$09,$03,$01,$06,$0f

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
	ld de,10000
	call nmi_off
	call .1
	ld de,1000
	call .1
	ld de,100
	call .1
	ld de,10
	call .1
	ld de,1
	inc b
	call .1
	jp nmi_on

.1:	ld a,$2f
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
	ld a,$30
.3:	push hl
	ld hl,(cursor)
	ld c,a
	ld a,h
	and $03
	or $18
	ld h,a
	ld a,c
	call WRTVRM
	inc hl
	ld (cursor),hl
	pop hl
	ld b,1
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
	ret

sn76489_vol:
	cpl
	and $0f
	or b
	out (PSG),a
	ret

sn76489_control:
	and $0f
	or $e0
	out (PSG),a
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

	ld hl,(lfsr)	; Save RAM trash for random generator.
	ld de,$7000
	xor a
	ld (de),a
	inc de
	bit 2,d
	jp z,$-4
	ld (lfsr),hl

	call TURN_OFF_SOUND

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

	ld a,$ff
	ld (joy1_data),a
	ld (joy2_data),a
	ld a,$0f
	ld (key1_data),a
	ld (key2_data),a

	; boingBASIC program start.
	LD HL,128
	PUSH HL
	LD A,21
	LD HL,boing_GAME_BITMAPS
	CALL define_char
	LD HL,128
	PUSH HL
	LD A,21
	LD HL,boing_GAME_COLORS
	CALL define_color
	LD HL,0
	PUSH HL
	LD A,10
	LD HL,boing_GAME_SPRITES
	CALL define_sprite
boing_RESTART_GAME:
	LD A,2
	LD (boing_LIVES),A
	LD A,1
	LD (boing_LEVEL),A
boing_RESTART_LEVEL:
	LD HL,684
	LD (cursor),HL
	LD HL,cv0
	LD A,7
	CALL print_string
	JP cv1
cv0:
	DB $4c,$69,$76,$65,$73,$3a,$20
cv1:
	LD A,(boing_LIVES)
	LD L,A
	LD H,0
	CALL print_number
	LD HL,745
	LD (cursor),HL
	LD HL,cv2
	LD A,14
	CALL print_string
	JP cv3
cv2:
	DB $6e,$61,$6e,$6f,$63,$68,$65,$73
	DB $73,$20,$32,$30,$32,$34
cv3:
boing_NEXT_LEVEL:
	CALL boing_DRAW_LEVEL
	LD A,8
	LD (boing_X_PLAYER),A
	LD A,16
	LD (boing_Y_PLAYER),A
	LD A,0
	LD (boing_PLAYER_FRAME),A
	LD HL,64
	PUSH HL
	LD HL,128
	PUSH HL
	CALL random
	POP DE
	CALL _mod16
	POP DE
	ADD HL,DE
	LD A,L
	LD (boing_X_ENEMY1),A
	LD A,56
	LD (boing_Y_ENEMY1),A
	LD A,24
	LD (boing_ENEMY1_FRAME),A
	LD HL,80
	PUSH HL
	LD HL,128
	PUSH HL
	CALL random
	POP DE
	CALL _mod16
	POP DE
	ADD HL,DE
	LD A,L
	LD (boing_X_ENEMY2),A
	LD A,96
	LD (boing_Y_ENEMY2),A
	LD A,32
	LD (boing_ENEMY2_FRAME),A
	LD HL,48
	PUSH HL
	LD HL,128
	PUSH HL
	CALL random
	POP DE
	CALL _mod16
	POP DE
	ADD HL,DE
	LD A,L
	LD (boing_X_ENEMY3),A
	LD A,136
	LD (boing_Y_ENEMY3),A
	LD A,24
	LD (boing_ENEMY3_FRAME),A
	LD A,0
	LD (boing_ENEMY_SPEED),A
	CALL boing_START_SONG
boing_GAME_LOOP:
cv4:
	LD HL,1
	LD A,H
	OR L
	JP Z,cv5
	HALT
	CALL boing_PLAY_SONG
	LD A,0
	PUSH AF
	LD HL,1
	PUSH HL
	LD A,(boing_Y_PLAYER)
	LD L,A
	LD H,0
	POP DE
	OR A
	SBC HL,DE
	LD A,L
	PUSH AF
	LD A,(boing_X_PLAYER)
	PUSH AF
	LD A,(boing_PLAYER_FRAME)
	PUSH AF
	LD A,15
	CALL update_sprite
	LD A,1
	PUSH AF
	LD HL,1
	PUSH HL
	LD A,(boing_Y_ENEMY1)
	LD L,A
	LD H,0
	POP DE
	OR A
	SBC HL,DE
	LD A,L
	PUSH AF
	LD A,(boing_X_ENEMY1)
	PUSH AF
	LD A,(boing_ENEMY1_FRAME)
	PUSH AF
	LD A,14
	CALL update_sprite
	LD A,2
	PUSH AF
	LD HL,1
	PUSH HL
	LD A,(boing_Y_ENEMY2)
	LD L,A
	LD H,0
	POP DE
	OR A
	SBC HL,DE
	LD A,L
	PUSH AF
	LD A,(boing_X_ENEMY2)
	PUSH AF
	LD A,(boing_ENEMY2_FRAME)
	PUSH AF
	LD A,14
	CALL update_sprite
	LD A,3
	PUSH AF
	LD HL,1
	PUSH HL
	LD A,(boing_Y_ENEMY3)
	LD L,A
	LD H,0
	POP DE
	OR A
	SBC HL,DE
	LD A,L
	PUSH AF
	LD A,(boing_X_ENEMY3)
	PUSH AF
	LD A,(boing_ENEMY3_FRAME)
	PUSH AF
	LD A,14
	CALL update_sprite
	CALL boing_MOVE_PLAYER
	LD HL,80
	PUSH HL
	LD A,(boing_ENEMY_SPEED)
	LD L,A
	LD H,0
	POP DE
	ADD HL,DE
	LD A,L
	LD (boing_ENEMY_SPEED),A
cv6:
	LD HL,64
	PUSH HL
	LD A,(boing_ENEMY_SPEED)
	LD L,A
	LD H,0
	POP DE
	OR A
	SBC HL,DE
	LD A,0
	JR C,$+3
	DEC A
	OR A
	JP Z,cv7
	LD HL,64
	PUSH HL
	LD A,(boing_ENEMY_SPEED)
	LD L,A
	LD H,0
	POP DE
	OR A
	SBC HL,DE
	LD A,L
	LD (boing_ENEMY_SPEED),A
	CALL boing_MOVE_ENEMIES
	JP cv6
cv7:
	LD A,64
	PUSH AF
	LD A,(joy1_data)
	POP BC
	AND B
	OR A
	JP Z,cv8
	LD HL,136
	PUSH HL
	LD A,(boing_Y_PLAYER)
	LD L,A
	LD H,0
	POP DE
	OR A
	SBC HL,DE
	LD A,0
	JR NZ,$+3
	DEC A
	PUSH AF
	LD HL,248
	PUSH HL
	LD A,(boing_X_PLAYER)
	LD L,A
	LD H,0
	POP DE
	OR A
	SBC HL,DE
	LD A,0
	JR NC,$+3
	DEC A
	PUSH AF
	LD A,(boing_X_PLAYER)
	LD L,A
	LD H,0
	PUSH HL
	LD HL,232
	POP DE
	OR A
	SBC HL,DE
	LD A,0
	JR NC,$+3
	DEC A
	POP BC
	AND B
	POP BC
	AND B
	OR A
	JP Z,cv9
	CALL boing_SOUND_OFF
	LD A,1
	LD (boing_C),A
cv10:
	HALT
	LD HL,10
	PUSH HL
	LD A,(boing_C)
	LD L,A
	LD H,0
	POP DE
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
	LD A,1
	PUSH AF
	LD A,(boing_C)
	POP BC
	ADD A,B
	LD (boing_C),A
	LD A,(boing_C)
	PUSH AF
	LD A,10
	POP BC
	CP B
	LD A,0
	JR NC,$+3
	DEC A
	OR A
	JP Z,cv10
	LD HL,1
	PUSH HL
	LD A,(boing_LEVEL)
	LD L,A
	LD H,0
	POP DE
	ADD HL,DE
	LD A,L
	LD (boing_LEVEL),A
	LD HL,6
	PUSH HL
	LD A,(boing_LEVEL)
	LD L,A
	LD H,0
	POP DE
	OR A
	SBC HL,DE
	LD A,0
	JR NZ,$+3
	DEC A
	OR A
	JP Z,cv11
	CALL boing_SOUND_OFF
	LD HL,267
	LD (cursor),HL
	LD HL,cv12
	LD A,10
	CALL print_string
	JP cv13
cv12:
	DB $20,$59,$4f,$55,$20,$57,$49,$4e
	DB $21,$20
cv13:
	LD HL,(frame)
	LD (boing_#C),HL
cv14:
	HALT
	LD HL,300
	PUSH HL
	LD HL,(boing_#C)
	PUSH HL
	LD HL,(frame)
	POP DE
	OR A
	SBC HL,DE
	POP DE
	OR A
	SBC HL,DE
	LD A,0
	JR NC,$+3
	DEC A
	OR A
	JP Z,cv16
	JP cv14
cv16:
	LD A,1
	LD (boing_LEVEL),A
	JP boing_RESTART_LEVEL
cv11:
	JP boing_NEXT_LEVEL
cv9:
cv8:
	LD HL,8
	PUSH HL
	LD A,(boing_Y_ENEMY1)
	LD L,A
	LD H,0
	PUSH HL
	LD HL,1
	PUSH HL
	LD A,(boing_Y_PLAYER)
	LD L,A
	LD H,0
	POP DE
	ADD HL,DE
	POP DE
	OR A
	SBC HL,DE
	CALL _abs16
	POP DE
	OR A
	SBC HL,DE
	LD A,0
	JR NC,$+3
	DEC A
	OR A
	JP Z,cv17
	LD HL,8
	PUSH HL
	LD A,(boing_X_ENEMY1)
	LD L,A
	LD H,0
	PUSH HL
	LD HL,1
	PUSH HL
	LD A,(boing_X_PLAYER)
	LD L,A
	LD H,0
	POP DE
	ADD HL,DE
	POP DE
	OR A
	SBC HL,DE
	CALL _abs16
	POP DE
	OR A
	SBC HL,DE
	LD A,0
	JR NC,$+3
	DEC A
	OR A
	JP Z,cv18
	JP boing_PLAYER_DIES
cv18:
cv17:
	LD HL,8
	PUSH HL
	LD A,(boing_Y_ENEMY2)
	LD L,A
	LD H,0
	PUSH HL
	LD HL,1
	PUSH HL
	LD A,(boing_Y_PLAYER)
	LD L,A
	LD H,0
	POP DE
	ADD HL,DE
	POP DE
	OR A
	SBC HL,DE
	CALL _abs16
	POP DE
	OR A
	SBC HL,DE
	LD A,0
	JR NC,$+3
	DEC A
	OR A
	JP Z,cv19
	LD HL,8
	PUSH HL
	LD A,(boing_X_ENEMY2)
	LD L,A
	LD H,0
	PUSH HL
	LD HL,1
	PUSH HL
	LD A,(boing_X_PLAYER)
	LD L,A
	LD H,0
	POP DE
	ADD HL,DE
	POP DE
	OR A
	SBC HL,DE
	CALL _abs16
	POP DE
	OR A
	SBC HL,DE
	LD A,0
	JR NC,$+3
	DEC A
	OR A
	JP Z,cv20
	JP boing_PLAYER_DIES
cv20:
cv19:
	LD HL,8
	PUSH HL
	LD A,(boing_Y_ENEMY3)
	LD L,A
	LD H,0
	PUSH HL
	LD HL,1
	PUSH HL
	LD A,(boing_Y_PLAYER)
	LD L,A
	LD H,0
	POP DE
	ADD HL,DE
	POP DE
	OR A
	SBC HL,DE
	CALL _abs16
	POP DE
	OR A
	SBC HL,DE
	LD A,0
	JR NC,$+3
	DEC A
	OR A
	JP Z,cv21
	LD HL,8
	PUSH HL
	LD A,(boing_X_ENEMY3)
	LD L,A
	LD H,0
	PUSH HL
	LD HL,1
	PUSH HL
	LD A,(boing_X_PLAYER)
	LD L,A
	LD H,0
	POP DE
	ADD HL,DE
	POP DE
	OR A
	SBC HL,DE
	CALL _abs16
	POP DE
	OR A
	SBC HL,DE
	LD A,0
	JR NC,$+3
	DEC A
	OR A
	JP Z,cv22
	JP boing_PLAYER_DIES
cv22:
cv21:
	JP cv4
cv5:
boing_PLAYER_DIES:
	CALL boing_SOUND_OFF
	LD HL,640
	LD A,$80
	CALL sn76489_freq
	LD A,13
	LD B,$90
	CALL sn76489_vol
	LD HL,320
	LD A,$a0
	CALL sn76489_freq
	LD A,13
	LD B,$b0
	CALL sn76489_vol
	LD HL,160
	LD A,$c0
	CALL sn76489_freq
	LD A,13
	LD B,$d0
	CALL sn76489_vol
	LD A,0
	LD (boing_PLAYER_FRAME),A
	LD A,0
	LD (boing_C),A
cv23:
	HALT
	HALT
	LD HL,8
	PUSH HL
	LD A,(boing_PLAYER_FRAME)
	LD L,A
	LD H,0
	POP DE
	LD A,L
	XOR E
	LD L,A
	LD A,H
	XOR D
	LD H,A
	LD A,L
	LD (boing_PLAYER_FRAME),A
	LD A,0
	PUSH AF
	LD HL,1
	PUSH HL
	LD A,(boing_Y_PLAYER)
	LD L,A
	LD H,0
	POP DE
	OR A
	SBC HL,DE
	LD A,L
	PUSH AF
	LD A,(boing_X_PLAYER)
	PUSH AF
	LD A,(boing_PLAYER_FRAME)
	PUSH AF
	LD A,15
	CALL update_sprite
	LD A,1
	PUSH AF
	LD A,(boing_C)
	POP BC
	ADD A,B
	LD (boing_C),A
	LD A,(boing_C)
	PUSH AF
	LD A,30
	POP BC
	CP B
	LD A,0
	JR NC,$+3
	DEC A
	OR A
	JP Z,cv23
	CALL boing_SOUND_OFF
cv24:
	HALT
	LD A,(boing_Y_PLAYER)
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
	LD HL,8
	PUSH HL
	LD A,(boing_PLAYER_FRAME)
	LD L,A
	LD H,0
	POP DE
	LD A,L
	XOR E
	LD L,A
	LD A,H
	XOR D
	LD H,A
	LD A,L
	LD (boing_PLAYER_FRAME),A
	LD A,0
	PUSH AF
	LD HL,1
	PUSH HL
	LD A,(boing_Y_PLAYER)
	LD L,A
	LD H,0
	POP DE
	OR A
	SBC HL,DE
	LD A,L
	PUSH AF
	LD A,(boing_X_PLAYER)
	PUSH AF
	LD A,(boing_PLAYER_FRAME)
	PUSH AF
	LD A,15
	CALL update_sprite
	LD HL,2
	PUSH HL
	LD A,(boing_Y_PLAYER)
	LD L,A
	LD H,0
	POP DE
	ADD HL,DE
	LD A,L
	LD (boing_Y_PLAYER),A
	LD HL,160
	PUSH HL
	LD A,(boing_Y_PLAYER)
	LD L,A
	LD H,0
	POP DE
	OR A
	SBC HL,DE
	LD A,0
	JR NC,$+3
	DEC A
	OR A
	JP Z,cv26
	JP cv24
cv26:
	CALL boing_SOUND_OFF
	LD HL,0
	PUSH HL
	LD A,(boing_LIVES)
	LD L,A
	LD H,0
	POP DE
	OR A
	SBC HL,DE
	LD A,0
	JR NZ,$+3
	DEC A
	OR A
	JP Z,cv27
	LD HL,267
	LD (cursor),HL
	LD HL,cv28
	LD A,11
	CALL print_string
	JP cv29
cv28:
	DB $20,$47,$41,$4d,$45,$20,$4f,$56
	DB $45,$52,$20
cv29:
	LD HL,(frame)
	LD (boing_#C),HL
cv30:
	HALT
	LD HL,300
	PUSH HL
	LD HL,(boing_#C)
	PUSH HL
	LD HL,(frame)
	POP DE
	OR A
	SBC HL,DE
	POP DE
	OR A
	SBC HL,DE
	LD A,0
	JR NC,$+3
	DEC A
	OR A
	JP Z,cv32
	JP cv30
cv32:
	JP boing_RESTART_GAME
cv27:
	LD HL,1
	PUSH HL
	LD A,(boing_LIVES)
	LD L,A
	LD H,0
	POP DE
	OR A
	SBC HL,DE
	LD A,L
	LD (boing_LIVES),A
	JP boing_RESTART_LEVEL
boing_DRAW_LEVEL:
	LD HL,4
	PUSH HL
	LD HL,1
	PUSH HL
	LD A,(boing_LEVEL)
	LD L,A
	LD H,0
	POP DE
	OR A
	SBC HL,DE
	POP DE
	CALL _mul16
	PUSH HL
	LD HL,128
	POP DE
	ADD HL,DE
	LD A,L
	LD (boing_BASE_CHARACTER),A
	LD HL,6144
	LD (boing_#C),HL
cv33:
	LD HL,(boing_#C)
	PUSH HL
	LD A,(boing_BASE_CHARACTER)
	POP HL
	CALL NMI_OFF
	CALL WRTVRM
	CALL NMI_ON
	LD HL,1
	PUSH HL
	LD HL,(boing_#C)
	POP DE
	ADD HL,DE
	PUSH HL
	LD A,(boing_BASE_CHARACTER)
	POP HL
	CALL NMI_OFF
	CALL WRTVRM
	CALL NMI_ON
	LD HL,2
	PUSH HL
	LD HL,(boing_#C)
	POP DE
	ADD HL,DE
	PUSH HL
	LD A,(boing_BASE_CHARACTER)
	POP HL
	CALL NMI_OFF
	CALL WRTVRM
	CALL NMI_ON
	LD HL,3
	PUSH HL
	LD HL,(boing_#C)
	POP DE
	ADD HL,DE
	PUSH HL
	LD HL,1
	PUSH HL
	LD A,(boing_BASE_CHARACTER)
	LD L,A
	LD H,0
	POP DE
	ADD HL,DE
	LD A,L
	POP HL
	CALL NMI_OFF
	CALL WRTVRM
	CALL NMI_ON
	LD HL,4
	PUSH HL
	LD HL,(boing_#C)
	POP DE
	ADD HL,DE
	LD (boing_#C),HL
	LD HL,(boing_#C)
	PUSH HL
	LD HL,6780
	POP DE
	OR A
	SBC HL,DE
	LD A,0
	JR NC,$+3
	DEC A
	OR A
	JP Z,cv33
	LD HL,6272
	LD (boing_#C),HL
cv34:
	LD HL,(boing_#C)
	LD (boing_#D),HL
cv35:
	LD HL,(boing_#D)
	PUSH HL
	LD HL,2
	PUSH HL
	LD A,(boing_BASE_CHARACTER)
	LD L,A
	LD H,0
	POP DE
	ADD HL,DE
	LD A,L
	POP HL
	CALL NMI_OFF
	CALL WRTVRM
	CALL NMI_ON
	LD HL,1
	PUSH HL
	LD HL,(boing_#D)
	POP DE
	ADD HL,DE
	LD (boing_#D),HL
	LD HL,(boing_#D)
	PUSH HL
	LD HL,31
	PUSH HL
	LD HL,(boing_#C)
	POP DE
	ADD HL,DE
	POP DE
	OR A
	SBC HL,DE
	LD A,0
	JR NC,$+3
	DEC A
	OR A
	JP Z,cv35
	LD HL,160
	PUSH HL
	LD HL,(boing_#C)
	POP DE
	ADD HL,DE
	LD (boing_#C),HL
	LD HL,(boing_#C)
	PUSH HL
	LD HL,6752
	POP DE
	OR A
	SBC HL,DE
	LD A,0
	JR NC,$+3
	DEC A
	OR A
	JP Z,cv34
	LD A,(boing_LEVEL)
	LD L,A
	LD H,0
	PUSH HL
	LD HL,6
	POP DE
	OR A
	SBC HL,DE
	LD A,L
	LD (boing_LADDERS),A
	LD HL,6272
	LD (boing_#C),HL
cv36:
	LD A,1
	LD (boing_D),A
cv37:
	LD HL,2
	PUSH HL
	LD HL,28
	PUSH HL
	CALL random
	POP DE
	CALL _mod16
	POP DE
	ADD HL,DE
	LD A,L
	LD (boing_E),A
	LD A,(boing_E)
	LD L,A
	LD H,0
	PUSH HL
	LD HL,(boing_#C)
	POP DE
	ADD HL,DE
	PUSH HL
	LD HL,3
	PUSH HL
	LD A,(boing_BASE_CHARACTER)
	LD L,A
	LD H,0
	POP DE
	ADD HL,DE
	LD A,L
	POP HL
	CALL NMI_OFF
	CALL WRTVRM
	CALL NMI_ON
	LD HL,32
	PUSH HL
	LD A,(boing_E)
	LD L,A
	LD H,0
	PUSH HL
	LD HL,(boing_#C)
	POP DE
	ADD HL,DE
	POP DE
	ADD HL,DE
	PUSH HL
	LD HL,3
	PUSH HL
	LD A,(boing_BASE_CHARACTER)
	LD L,A
	LD H,0
	POP DE
	ADD HL,DE
	LD A,L
	POP HL
	CALL NMI_OFF
	CALL WRTVRM
	CALL NMI_ON
	LD HL,64
	PUSH HL
	LD A,(boing_E)
	LD L,A
	LD H,0
	PUSH HL
	LD HL,(boing_#C)
	POP DE
	ADD HL,DE
	POP DE
	ADD HL,DE
	PUSH HL
	LD HL,3
	PUSH HL
	LD A,(boing_BASE_CHARACTER)
	LD L,A
	LD H,0
	POP DE
	ADD HL,DE
	LD A,L
	POP HL
	CALL NMI_OFF
	CALL WRTVRM
	CALL NMI_ON
	LD HL,96
	PUSH HL
	LD A,(boing_E)
	LD L,A
	LD H,0
	PUSH HL
	LD HL,(boing_#C)
	POP DE
	ADD HL,DE
	POP DE
	ADD HL,DE
	PUSH HL
	LD HL,3
	PUSH HL
	LD A,(boing_BASE_CHARACTER)
	LD L,A
	LD H,0
	POP DE
	ADD HL,DE
	LD A,L
	POP HL
	CALL NMI_OFF
	CALL WRTVRM
	CALL NMI_ON
	LD HL,128
	PUSH HL
	LD A,(boing_E)
	LD L,A
	LD H,0
	PUSH HL
	LD HL,(boing_#C)
	POP DE
	ADD HL,DE
	POP DE
	ADD HL,DE
	PUSH HL
	LD HL,3
	PUSH HL
	LD A,(boing_BASE_CHARACTER)
	LD L,A
	LD H,0
	POP DE
	ADD HL,DE
	LD A,L
	POP HL
	CALL NMI_OFF
	CALL WRTVRM
	CALL NMI_ON
	LD A,1
	PUSH AF
	LD A,(boing_D)
	POP BC
	ADD A,B
	LD (boing_D),A
	LD A,(boing_D)
	PUSH AF
	LD A,(boing_LADDERS)
	POP BC
	CP B
	LD A,0
	JR NC,$+3
	DEC A
	OR A
	JP Z,cv37
	LD HL,160
	PUSH HL
	LD HL,(boing_#C)
	POP DE
	ADD HL,DE
	LD (boing_#C),HL
	LD HL,(boing_#C)
	PUSH HL
	LD HL,6592
	POP DE
	OR A
	SBC HL,DE
	LD A,0
	JR NC,$+3
	DEC A
	OR A
	JP Z,cv36
	LD HL,6750
	PUSH HL
	LD A,148
	POP HL
	CALL NMI_OFF
	CALL WRTVRM
	CALL NMI_ON
	RET
boing_MOVE_PLAYER:
	LD A,8
	PUSH AF
	LD A,(joy1_data)
	POP BC
	AND B
	OR A
	JP Z,cv38
	LD HL,16
	PUSH HL
	LD HL,40
	PUSH HL
	LD A,(boing_Y_PLAYER)
	LD L,A
	LD H,0
	POP DE
	CALL _mod16
	POP DE
	OR A
	SBC HL,DE
	LD A,0
	JR NZ,$+3
	DEC A
	OR A
	JP Z,cv39
	LD A,(boing_X_PLAYER)
	LD L,A
	LD H,0
	PUSH HL
	LD HL,0
	POP DE
	OR A
	SBC HL,DE
	LD A,0
	JR NC,$+3
	DEC A
	OR A
	JP Z,cv40
	LD HL,1
	PUSH HL
	LD A,(boing_X_PLAYER)
	LD L,A
	LD H,0
	POP DE
	OR A
	SBC HL,DE
	LD A,L
	LD (boing_X_PLAYER),A
cv40:
	LD HL,4
	PUSH HL
	LD HL,(frame)
	POP DE
	LD A,L
	AND E
	LD L,A
	LD A,H
	AND D
	LD H,A
	LD A,H
	OR L
	JP Z,cv41
	LD A,8
	LD (boing_PLAYER_FRAME),A
	JP cv42
cv41:
	LD A,12
	LD (boing_PLAYER_FRAME),A
cv42:
cv39:
cv38:
	LD A,2
	PUSH AF
	LD A,(joy1_data)
	POP BC
	AND B
	OR A
	JP Z,cv43
	LD HL,16
	PUSH HL
	LD HL,40
	PUSH HL
	LD A,(boing_Y_PLAYER)
	LD L,A
	LD H,0
	POP DE
	CALL _mod16
	POP DE
	OR A
	SBC HL,DE
	LD A,0
	JR NZ,$+3
	DEC A
	OR A
	JP Z,cv44
	LD HL,240
	PUSH HL
	LD A,(boing_X_PLAYER)
	LD L,A
	LD H,0
	POP DE
	OR A
	SBC HL,DE
	LD A,0
	JR NC,$+3
	DEC A
	OR A
	JP Z,cv45
	LD HL,1
	PUSH HL
	LD A,(boing_X_PLAYER)
	LD L,A
	LD H,0
	POP DE
	ADD HL,DE
	LD A,L
	LD (boing_X_PLAYER),A
cv45:
	LD HL,4
	PUSH HL
	LD HL,(frame)
	POP DE
	LD A,L
	AND E
	LD L,A
	LD A,H
	AND D
	LD H,A
	LD A,H
	OR L
	JP Z,cv46
	LD A,0
	LD (boing_PLAYER_FRAME),A
	JP cv47
cv46:
	LD A,4
	LD (boing_PLAYER_FRAME),A
cv47:
cv44:
cv43:
	LD A,1
	PUSH AF
	LD A,(joy1_data)
	POP BC
	AND B
	OR A
	JP Z,cv48
	LD HL,16
	PUSH HL
	LD HL,40
	PUSH HL
	LD A,(boing_Y_PLAYER)
	LD L,A
	LD H,0
	POP DE
	CALL _mod16
	POP DE
	OR A
	SBC HL,DE
	LD A,0
	JR NZ,$+3
	DEC A
	OR A
	JP Z,cv49
	LD HL,8
	PUSH HL
	LD HL,7
	PUSH HL
	LD A,(boing_X_PLAYER)
	LD L,A
	LD H,0
	POP DE
	ADD HL,DE
	POP DE
	CALL _div16
	LD A,L
	LD (boing_COLUMN),A
	LD HL,8
	PUSH HL
	LD HL,8
	PUSH HL
	LD A,(boing_Y_PLAYER)
	LD L,A
	LD H,0
	POP DE
	ADD HL,DE
	POP DE
	CALL _div16
	LD A,L
	LD (boing_ROW),A
	LD A,(boing_COLUMN)
	LD L,A
	LD H,0
	PUSH HL
	LD HL,32
	PUSH HL
	LD A,(boing_ROW)
	LD L,A
	LD H,0
	POP DE
	CALL _mul16
	PUSH HL
	LD HL,6144
	POP DE
	ADD HL,DE
	POP DE
	ADD HL,DE
	LD (boing_#C),HL
	LD HL,3
	PUSH HL
	LD A,(boing_BASE_CHARACTER)
	LD L,A
	LD H,0
	POP DE
	ADD HL,DE
	PUSH HL
	LD HL,(boing_#C)
	CALL nmi_off
	CALL RDVRM
	CALL nmi_on
	LD L,A
	LD H,0
	POP DE
	OR A
	SBC HL,DE
	LD A,0
	JR NZ,$+3
	DEC A
	OR A
	JP Z,cv50
	LD HL,1
	PUSH HL
	LD A,(boing_Y_PLAYER)
	LD L,A
	LD H,0
	POP DE
	OR A
	SBC HL,DE
	LD A,L
	LD (boing_Y_PLAYER),A
cv50:
	JP cv51
cv49:
	LD HL,4
	PUSH HL
	LD HL,(frame)
	POP DE
	LD A,L
	AND E
	LD L,A
	LD A,H
	AND D
	LD H,A
	LD A,H
	OR L
	JP Z,cv52
	LD A,16
	LD (boing_PLAYER_FRAME),A
	JP cv53
cv52:
	LD A,20
	LD (boing_PLAYER_FRAME),A
cv53:
	LD HL,1
	PUSH HL
	LD A,(boing_Y_PLAYER)
	LD L,A
	LD H,0
	POP DE
	OR A
	SBC HL,DE
	LD A,L
	LD (boing_Y_PLAYER),A
cv51:
cv48:
	LD A,4
	PUSH AF
	LD A,(joy1_data)
	POP BC
	AND B
	OR A
	JP Z,cv54
	LD HL,16
	PUSH HL
	LD HL,40
	PUSH HL
	LD A,(boing_Y_PLAYER)
	LD L,A
	LD H,0
	POP DE
	CALL _mod16
	POP DE
	OR A
	SBC HL,DE
	LD A,0
	JR NZ,$+3
	DEC A
	OR A
	JP Z,cv55
	LD HL,8
	PUSH HL
	LD HL,7
	PUSH HL
	LD A,(boing_X_PLAYER)
	LD L,A
	LD H,0
	POP DE
	ADD HL,DE
	POP DE
	CALL _div16
	LD A,L
	LD (boing_COLUMN),A
	LD HL,8
	PUSH HL
	LD HL,16
	PUSH HL
	LD A,(boing_Y_PLAYER)
	LD L,A
	LD H,0
	POP DE
	ADD HL,DE
	POP DE
	CALL _div16
	LD A,L
	LD (boing_ROW),A
	LD A,(boing_COLUMN)
	LD L,A
	LD H,0
	PUSH HL
	LD HL,32
	PUSH HL
	LD A,(boing_ROW)
	LD L,A
	LD H,0
	POP DE
	CALL _mul16
	PUSH HL
	LD HL,6144
	POP DE
	ADD HL,DE
	POP DE
	ADD HL,DE
	LD (boing_#C),HL
	LD HL,3
	PUSH HL
	LD A,(boing_BASE_CHARACTER)
	LD L,A
	LD H,0
	POP DE
	ADD HL,DE
	PUSH HL
	LD HL,(boing_#C)
	CALL nmi_off
	CALL RDVRM
	CALL nmi_on
	LD L,A
	LD H,0
	POP DE
	OR A
	SBC HL,DE
	LD A,0
	JR NZ,$+3
	DEC A
	OR A
	JP Z,cv56
	LD HL,1
	PUSH HL
	LD A,(boing_Y_PLAYER)
	LD L,A
	LD H,0
	POP DE
	ADD HL,DE
	LD A,L
	LD (boing_Y_PLAYER),A
cv56:
	JP cv57
cv55:
	LD HL,4
	PUSH HL
	LD HL,(frame)
	POP DE
	LD A,L
	AND E
	LD L,A
	LD A,H
	AND D
	LD H,A
	LD A,H
	OR L
	JP Z,cv58
	LD A,16
	LD (boing_PLAYER_FRAME),A
	JP cv59
cv58:
	LD A,20
	LD (boing_PLAYER_FRAME),A
cv59:
	LD HL,1
	PUSH HL
	LD A,(boing_Y_PLAYER)
	LD L,A
	LD H,0
	POP DE
	ADD HL,DE
	LD A,L
	LD (boing_Y_PLAYER),A
cv57:
cv54:
	RET
boing_MOVE_ENEMIES:
	LD HL,32
	PUSH HL
	LD A,(boing_ENEMY1_FRAME)
	LD L,A
	LD H,0
	POP DE
	OR A
	SBC HL,DE
	LD A,0
	JR NC,$+3
	DEC A
	OR A
	JP Z,cv60
	LD HL,1
	PUSH HL
	LD A,(boing_X_ENEMY1)
	LD L,A
	LD H,0
	POP DE
	OR A
	SBC HL,DE
	LD A,L
	LD (boing_X_ENEMY1),A
	LD HL,0
	PUSH HL
	LD A,(boing_X_ENEMY1)
	LD L,A
	LD H,0
	POP DE
	OR A
	SBC HL,DE
	LD A,0
	JR NZ,$+3
	DEC A
	OR A
	JP Z,cv61
	LD A,32
	LD (boing_ENEMY1_FRAME),A
cv61:
	JP cv62
cv60:
	LD HL,1
	PUSH HL
	LD A,(boing_X_ENEMY1)
	LD L,A
	LD H,0
	POP DE
	ADD HL,DE
	LD A,L
	LD (boing_X_ENEMY1),A
	LD HL,240
	PUSH HL
	LD A,(boing_X_ENEMY1)
	LD L,A
	LD H,0
	POP DE
	OR A
	SBC HL,DE
	LD A,0
	JR NZ,$+3
	DEC A
	OR A
	JP Z,cv63
	LD A,24
	LD (boing_ENEMY1_FRAME),A
cv63:
cv62:
	LD HL,4
	PUSH HL
	LD HL,(frame)
	POP DE
	LD A,L
	AND E
	LD L,A
	LD A,H
	AND D
	LD H,A
	PUSH HL
	LD HL,248
	PUSH HL
	LD A,(boing_ENEMY1_FRAME)
	LD L,A
	LD H,0
	POP DE
	LD A,L
	AND E
	LD L,A
	LD A,H
	AND D
	LD H,A
	POP DE
	ADD HL,DE
	LD A,L
	LD (boing_ENEMY1_FRAME),A
	LD HL,32
	PUSH HL
	LD A,(boing_ENEMY2_FRAME)
	LD L,A
	LD H,0
	POP DE
	OR A
	SBC HL,DE
	LD A,0
	JR NC,$+3
	DEC A
	OR A
	JP Z,cv64
	LD HL,1
	PUSH HL
	LD A,(boing_X_ENEMY2)
	LD L,A
	LD H,0
	POP DE
	OR A
	SBC HL,DE
	LD A,L
	LD (boing_X_ENEMY2),A
	LD HL,0
	PUSH HL
	LD A,(boing_X_ENEMY2)
	LD L,A
	LD H,0
	POP DE
	OR A
	SBC HL,DE
	LD A,0
	JR NZ,$+3
	DEC A
	OR A
	JP Z,cv65
	LD A,32
	LD (boing_ENEMY2_FRAME),A
cv65:
	JP cv66
cv64:
	LD HL,1
	PUSH HL
	LD A,(boing_X_ENEMY2)
	LD L,A
	LD H,0
	POP DE
	ADD HL,DE
	LD A,L
	LD (boing_X_ENEMY2),A
	LD HL,240
	PUSH HL
	LD A,(boing_X_ENEMY2)
	LD L,A
	LD H,0
	POP DE
	OR A
	SBC HL,DE
	LD A,0
	JR NZ,$+3
	DEC A
	OR A
	JP Z,cv67
	LD A,24
	LD (boing_ENEMY2_FRAME),A
cv67:
cv66:
	LD HL,4
	PUSH HL
	LD HL,(frame)
	POP DE
	LD A,L
	AND E
	LD L,A
	LD A,H
	AND D
	LD H,A
	PUSH HL
	LD HL,248
	PUSH HL
	LD A,(boing_ENEMY2_FRAME)
	LD L,A
	LD H,0
	POP DE
	LD A,L
	AND E
	LD L,A
	LD A,H
	AND D
	LD H,A
	POP DE
	ADD HL,DE
	LD A,L
	LD (boing_ENEMY2_FRAME),A
	LD HL,32
	PUSH HL
	LD A,(boing_ENEMY3_FRAME)
	LD L,A
	LD H,0
	POP DE
	OR A
	SBC HL,DE
	LD A,0
	JR NC,$+3
	DEC A
	OR A
	JP Z,cv68
	LD HL,1
	PUSH HL
	LD A,(boing_X_ENEMY3)
	LD L,A
	LD H,0
	POP DE
	OR A
	SBC HL,DE
	LD A,L
	LD (boing_X_ENEMY3),A
	LD HL,0
	PUSH HL
	LD A,(boing_X_ENEMY3)
	LD L,A
	LD H,0
	POP DE
	OR A
	SBC HL,DE
	LD A,0
	JR NZ,$+3
	DEC A
	OR A
	JP Z,cv69
	LD A,32
	LD (boing_ENEMY3_FRAME),A
cv69:
	JP cv70
cv68:
	LD HL,1
	PUSH HL
	LD A,(boing_X_ENEMY3)
	LD L,A
	LD H,0
	POP DE
	ADD HL,DE
	LD A,L
	LD (boing_X_ENEMY3),A
	LD HL,240
	PUSH HL
	LD A,(boing_X_ENEMY3)
	LD L,A
	LD H,0
	POP DE
	OR A
	SBC HL,DE
	LD A,0
	JR NZ,$+3
	DEC A
	OR A
	JP Z,cv71
	LD A,24
	LD (boing_ENEMY3_FRAME),A
cv71:
cv70:
	LD HL,4
	PUSH HL
	LD HL,(frame)
	POP DE
	LD A,L
	AND E
	LD L,A
	LD A,H
	AND D
	LD H,A
	PUSH HL
	LD HL,248
	PUSH HL
	LD A,(boing_ENEMY3_FRAME)
	LD L,A
	LD H,0
	POP DE
	LD A,L
	AND E
	LD L,A
	LD A,H
	AND D
	LD H,A
	POP DE
	ADD HL,DE
	LD A,L
	LD (boing_ENEMY3_FRAME),A
	RET
boing_GAME_BITMAPS:
	DB $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
	DB $e7,$e7,$e7,$e7,$e7,$e7,$e7,$e7
	DB $ff,$ff,$00,$ff,$ff,$00,$ff,$ff
	DB $42,$42,$7e,$42,$42,$7e,$42,$42
	DB $fe,$82,$ba,$aa,$ba,$82,$fe,$00
	DB $ba,$ba,$ba,$ba,$ba,$ba,$ba,$ba
	DB $ee,$00,$ff,$ff,$ff,$00,$00,$00
	DB $42,$42,$7e,$42,$42,$7e,$42,$42
	DB $ef,$ef,$ef,$00,$fe,$fe,$fe,$00
	DB $7e,$7e,$7e,$00,$6e,$6e,$6e,$00
	DB $00,$ff,$ff,$aa,$44,$00,$00,$00
	DB $42,$42,$7e,$42,$42,$7e,$42,$42
	DB $ee,$ee,$ee,$00,$ee,$ee,$ee,$00
	DB $40,$30,$0c,$03,$0c,$30,$40,$40
	DB $00,$ff,$00,$aa,$55,$00,$ff,$00
	DB $81,$81,$c3,$bd,$81,$81,$c3,$bd
	DB $81,$58,$37,$47,$39,$27,$49,$27
	DB $47,$49,$27,$40,$28,$15,$12,$27
	DB $00,$fe,$fe,$00,$ef,$ef,$00,$00
	DB $0c,$0c,$18,$18,$30,$30,$18,$18
	DB $54,$fe,$54,$fe,$54,$fe,$54,$00
boing_GAME_COLORS:
	DB $cc
	DB $cc
	DB $cc
	DB $cc
	DB $cc
	DB $cc
	DB $cc
	DB $cc
	DB $21
	DB $21
	DB $21
	DB $21
	DB $21
	DB $21
	DB $21
	DB $21
	DB $a1
	DB $a1
	DB $a1
	DB $a1
	DB $a1
	DB $a1
	DB $a1
	DB $a1
	DB $51
	DB $51
	DB $51
	DB $51
	DB $51
	DB $51
	DB $51
	DB $51
	DB $54
	DB $54
	DB $54
	DB $54
	DB $54
	DB $54
	DB $54
	DB $54
	DB $51
	DB $51
	DB $51
	DB $51
	DB $51
	DB $51
	DB $51
	DB $51
	DB $f1
	DB $11
	DB $e1
	DB $e1
	DB $e1
	DB $11
	DB $11
	DB $11
	DB $51
	DB $51
	DB $51
	DB $51
	DB $51
	DB $51
	DB $51
	DB $51
	DB $68
	DB $68
	DB $68
	DB $68
	DB $68
	DB $68
	DB $68
	DB $68
	DB $81
	DB $81
	DB $81
	DB $81
	DB $81
	DB $81
	DB $81
	DB $81
	DB $51
	DB $51
	DB $51
	DB $51
	DB $51
	DB $51
	DB $51
	DB $51
	DB $51
	DB $51
	DB $51
	DB $51
	DB $51
	DB $51
	DB $51
	DB $51
	DB $61
	DB $61
	DB $61
	DB $61
	DB $61
	DB $61
	DB $61
	DB $61
	DB $a1
	DB $a1
	DB $a1
	DB $a1
	DB $a1
	DB $a1
	DB $a1
	DB $a1
	DB $f1
	DB $f1
	DB $f1
	DB $51
	DB $51
	DB $f1
	DB $f1
	DB $f1
	DB $e1
	DB $e1
	DB $e1
	DB $e1
	DB $e1
	DB $e1
	DB $e1
	DB $e1
	DB $86
	DB $86
	DB $86
	DB $86
	DB $86
	DB $86
	DB $86
	DB $86
	DB $2c
	DB $2c
	DB $2c
	DB $2c
	DB $2c
	DB $2c
	DB $2c
	DB $2c
	DB $11
	DB $6e
	DB $6e
	DB $6e
	DB $6e
	DB $6e
	DB $6e
	DB $11
	DB $c1
	DB $c1
	DB $c1
	DB $c1
	DB $c1
	DB $c1
	DB $c1
	DB $c1
	DB $f1
	DB $f1
	DB $f1
	DB $f1
	DB $f1
	DB $f1
	DB $f1
	DB $f1
boing_GAME_SPRITES:
	DB $00,$01,$05,$03,$07,$03,$07,$1e
	DB $37,$67,$77,$74,$03,$0e,$0e,$0f
	DB $00,$50,$f0,$f0,$d0,$70,$10,$e0
	DB $00,$b8,$b8,$00,$c0,$f8,$7c,$00
	DB $00,$02,$01,$03,$01,$03,$03,$07
	DB $07,$06,$06,$07,$03,$03,$03,$03
	DB $a8,$f8,$f8,$e8,$b8,$88,$70,$80
	DB $c0,$e0,$e0,$00,$c0,$00,$c0,$e0
	DB $00,$0a,$0f,$0f,$0b,$0e,$08,$07
	DB $00,$1d,$1d,$00,$03,$1f,$3e,$00
	DB $00,$80,$a0,$c0,$e0,$c0,$e0,$78
	DB $ec,$e6,$ee,$2e,$c0,$70,$70,$f0
	DB $15,$1f,$1f,$17,$1d,$11,$0e,$01
	DB $03,$07,$07,$00,$03,$00,$03,$07
	DB $00,$40,$80,$c0,$80,$c0,$c0,$e0
	DB $e0,$60,$60,$e0,$c0,$c0,$c0,$c0
	DB $0a,$07,$0f,$0f,$07,$07,$03,$0c
	DB $1b,$70,$73,$02,$06,$06,$1e,$3e
	DB $a0,$c0,$e0,$e0,$ce,$ce,$98,$70
	DB $c0,$00,$c0,$60,$38,$3c,$00,$00
	DB $05,$03,$07,$07,$73,$73,$19,$0e
	DB $03,$00,$03,$06,$1c,$38,$00,$00
	DB $50,$e0,$f0,$f0,$e0,$e0,$c0,$30
	DB $d8,$0e,$ce,$40,$60,$60,$78,$7c
	DB $1b,$2d,$2d,$36,$1f,$7d,$9b,$03
	DB $0f,$1f,$3e,$3c,$3c,$3f,$1f,$0f
	DB $00,$00,$00,$00,$00,$80,$80,$82
	DB $02,$06,$06,$0e,$cc,$ec,$fc,$38
	DB $00,$0d,$16,$16,$1b,$0f,$1e,$5d
	DB $61,$0f,$1f,$1e,$1e,$1f,$0f,$07
	DB $00,$80,$80,$80,$00,$80,$c0,$c0
	DB $c0,$84,$0c,$cc,$d8,$f8,$b8,$30
	DB $00,$00,$00,$00,$00,$01,$01,$41
	DB $40,$60,$60,$70,$33,$37,$3f,$1c
	DB $d8,$b4,$b4,$6c,$f8,$be,$d9,$c0
	DB $f0,$f8,$7c,$3c,$3c,$fc,$f8,$f0
	DB $00,$01,$01,$01,$00,$01,$03,$03
	DB $03,$21,$30,$33,$1b,$1f,$1d,$0c
	DB $00,$b0,$68,$68,$d8,$f0,$78,$ba
	DB $86,$f0,$f8,$78,$78,$f8,$f0,$e0
boing_START_SONG:
	LD A,8
	LD (boing_TICK_NOTE),A
	LD A,47
	LD (boing_SONG_NOTE),A
	RET
boing_PLAY_SONG:
	LD A,1
	PUSH AF
	LD A,(boing_TICK_NOTE)
	POP BC
	ADD A,B
	LD (boing_TICK_NOTE),A
	LD A,16
	PUSH AF
	LD A,(boing_TICK_NOTE)
	POP BC
	CP B
	LD A,0
	JR NZ,$+3
	DEC A
	OR A
	JP Z,cv72
	LD A,0
	LD (boing_TICK_NOTE),A
	LD A,1
	PUSH AF
	LD A,(boing_SONG_NOTE)
	POP BC
	ADD A,B
	LD (boing_SONG_NOTE),A
	LD A,48
	PUSH AF
	LD A,(boing_SONG_NOTE)
	POP BC
	CP B
	LD A,0
	JR NZ,$+3
	DEC A
	OR A
	JP Z,cv73
	LD A,0
	LD (boing_SONG_NOTE),A
cv73:
	LD A,(boing_SONG_NOTE)
	LD L,A
	LD H,0
	PUSH HL
	LD HL,boing_SONG_NOTES
	POP DE
	ADD HL,DE
	LD A,(HL)
	LD (boing_NOTE),A
	LD HL,2
	PUSH HL
	LD HL,1
	PUSH HL
	LD A,(boing_NOTE)
	LD L,A
	LD H,0
	POP DE
	OR A
	SBC HL,DE
	POP DE
	CALL _mul16
	PUSH HL
	LD HL,boing_#NOTE_FREQ
	POP DE
	ADD HL,DE
	LD A,(HL)
	INC HL
	LD H,(HL)
	LD L,A
	LD A,$80
	CALL sn76489_freq
	LD A,13
	LD B,$90
	CALL sn76489_vol
	JP cv74
cv72:
	LD HL,2
	PUSH HL
	LD A,(boing_TICK_NOTE)
	LD L,A
	LD H,0
	POP DE
	CALL _div16
	PUSH HL
	LD HL,13
	POP DE
	OR A
	SBC HL,DE
	LD A,L
	LD B,$90
	CALL sn76489_vol
cv74:
	RET
boing_SOUND_OFF:
	LD A,0
	LD B,$90
	CALL sn76489_vol
	LD A,0
	LD B,$b0
	CALL sn76489_vol
	LD A,0
	LD B,$d0
	CALL sn76489_vol
	LD A,0
	LD B,$f0
	CALL sn76489_vol
	RET
boing_SONG_NOTES:
	DB $01
	DB $02
	DB $03
	DB $04
	DB $05
	DB $04
	DB $03
	DB $02
	DB $01
	DB $02
	DB $03
	DB $04
	DB $05
	DB $04
	DB $03
	DB $02
	DB $06
	DB $04
	DB $07
	DB $08
	DB $09
	DB $08
	DB $07
	DB $04
	DB $06
	DB $04
	DB $07
	DB $08
	DB $09
	DB $08
	DB $07
	DB $04
	DB $03
	DB $0c
	DB $08
	DB $0a
	DB $0b
	DB $0a
	DB $08
	DB $0c
	DB $06
	DB $04
	DB $07
	DB $08
	DB $09
	DB $08
	DB $07
	DB $04
boing_#NOTE_FREQ:
	DW $01ac
	DW $0153
	DW $011d
	DW $00fe
	DW $00f0
	DW $0140
	DW $00d6
	DW $00be
	DW $00b4
	DW $00aa
	DW $00a0
	DW $00e2
	;
	; BoingBASIC epilogue.
	;
	; by Oscar Toledo G.
	; https://nanochess.org/
	;
	; Creation date: Feb/27/2024.
	; Revision date: Feb/29/2024. Added joystick, keypad and random variables.
	;

	org $7000

sprites:
	rb 128
sprite_data:
	rb 4
frame:
	rb 2
cursor:
	rb 2
lfsr:
	rb 2
mode:
	rb 1
joy1_data:
	rb 1
joy2_data:
	rb 1
key1_data:
	rb 1
key2_data:
	rb 1

boing_Y_ENEMY1:	rb 1
boing_Y_ENEMY2:	rb 1
boing_Y_ENEMY3:	rb 1
boing_C:	rb 1
boing_D:	rb 1
boing_E:	rb 1
boing_PLAYER_FRAME:	rb 1
boing_TICK_NOTE:	rb 1
boing_LIVES:	rb 1
boing_LEVEL:	rb 1
boing_ENEMY1_FRAME:	rb 1
boing_COLUMN:	rb 1
boing_ENEMY_SPEED:	rb 1
boing_SONG_NOTE:	rb 1
boing_ENEMY2_FRAME:	rb 1
boing_#C:	rb 2
boing_#D:	rb 2
boing_BASE_CHARACTER:	rb 1
boing_X_PLAYER:	rb 1
boing_ENEMY3_FRAME:	rb 1
boing_X_ENEMY1:	rb 1
boing_X_ENEMY2:	rb 1
boing_X_ENEMY3:	rb 1
boing_NOTE:	rb 1
boing_LADDERS:	rb 1
boing_ROW:	rb 1
boing_Y_PLAYER:	rb 1
