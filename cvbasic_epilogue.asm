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
	;CVBASIC MARK DON'T CHANGE

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
