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
	; Revision date: Apr/13/2024. Updates LFSR in interruption handler.
	; Revision date: Apr/26/2024. All code moved to cvbasic_prologue.asm so it
	;                             can remain accessible in bank 0 (bank switching).
	; Revision date: Aug/02/2024. Added rom_end label for Memotech.
	; Revision date: Aug/15/2024. Added support for Tatung Einstein.
	; Revision date: Nov/12/2024. Added vdp_status.
	; Revision date: Feb/03/2025. Round final ROM size to 8K multiples.
	; Revision date: Feb/05/2026. Added support for spinners and roller controller
	;                             (Colecovision).
	;

rom_end:

	; ROM final size rounding
    if MSX+COLECO+SG1000+SMS+SVI+SORD
        TIMES (($+$1FFF)&$1e000)-$ DB $ff
    endif
    if MEMOTECH+EINSTEIN+NABU
	; Align following data to a 256-byte page.
        TIMES $100-($&$ff) DB $4f
    endif
    if PV2000
	TIMES $10000-$ DB $ff
    endif
    if SG1000+SMS
      if CVBASIC_BANK_SWITCHING
        forg CVBASIC_BANK_ROM_SIZE*1024-1	; Force final ROM size
	db $ff
      endif
	forg $7FF0
	org $7FF0
	db "TMR SEGA"
	db 0,0
	db 0,0		; Checksum
	db $11,$78	; Product code
	db $00		; Version
	db $4c		; SMS Export + 32KB for checksum
    endif

    if MSX
      if FM_SUPPORT
	;
	; FM driver 
	;
	; by Oscar Toledo G.
	;
	; Creation date: Sep/28/2012. For Mecha-9.
	; Revision date: Mar/07/2026. Adapted for Metro Wars (CVBasic)
	; Revision date: Mar/12/2026. Adapted for release in CVBasic.
	;

	FORG $01FD00
	ORG $BD00

	;
	; This code cannot be in the area $4000-$7fff
	;

        ; Subroutines from BIOS MSX
CALSLT:         equ $001c       ; Inter-slot call (disables interruptions)
;ENASLT:         equ $0024       ; Enable slot (H=High-byte address, C=Slot)

        ; Subroutines from OPLL ROM
WRTOPL:         equ $4110
INIOPL:         equ $4113

        ;
        ; Play music for FM
        ;
music_generate_fm:
	; Fragments of code in caller.

.0:     ld a,(music_timing)
        and $3f         ; Restarts note time.
        ld (music_note_counter),a
        push hl
	push bc
	push de
        call fm_rom_switch
	pop de
	pop bc
        ld a,b
        cp $3f          ; Sustain?
        jr z,.1
        ld a,$10
        call play_fm
.1:     ld a,c          ; Read second voice.
        cp $3f          ; Sustain?
        jr z,.2
        ld b,a
        ld a,$11
        call play_fm
.2:     ld a,d          ; Read third voice.
        cp $3f          ; Sustain?
        jr z,.3
        ld b,a
        ld a,$12
        call play_fm
.3:     push de
	call cartridge_rom_switch
	pop de
        pop hl
        ld a,e          ; Read effect.
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
        ;
        ; Build extras
        ;
.6:     ld a,(music_drum)    ; Read effect.
        or a            ; Effect happening?
        jr z,.7         ; No, jump.
        call fm_rom_switch
        ld a,(music_drum)    ; Read effect.
        dec a           ; 1 - Long drum.
        jr nz,.5
        ld a,(music_counter_4)
        or a
        ld de,$0e28
        jr z,.9
        cp 3
        ld de,$0e20
        jr z,.9
        jr .4

.5:     dec a           ; 2 - Short drum.
        jr nz,.11
        ld a,(music_counter_4)
        or a
        ld e,$21
        jr z,.9
        cp 3
        ld e,$20
        jr nz,.4
.9:     ld a,$0e
        call write_fm
        jr .4

.12:    cp 2
        jr nz,.9
        ld e,$20
        ld a,$0e
        call write_fm
        ld e,$28
        jr .9

.11:    ;dec a           ; 3 - Roll.
        ;jp nz,.4
        ld a,(music_timing)
        and $3e
        rrca
        ld b,a
        ld a,(music_counter_4)
        ld e,$28
        or a
        jr z,.9
        cp b
        jr z,.12
        ld e,$20
        cp 2
        jr z,.9 
        dec a
        dec a
        cp b
        jr z,.9 
.4:     call cartridge_rom_switch
.7:
        ; Increment time for drum.
        ld hl,music_counter_4
        inc (hl)
        ld hl,music_note_counter
        dec (hl)
        ret

        ;
        ; Play note in FM
        ; A = Voice ($10 - $11 - $12)
        ; B = Instrument + Note.
        ;
play_fm:
        push bc
        push de
        ld c,a          ; Saves base register.
        add a,$10
        ld e,$00	; Turn off voice if it was turned on.
        push bc
        call write_fm
        pop bc
        ld a,b          ; Read instrument (bits 7-6)
	and $c0
        rlca
        rlca
	ld hl,fm_inst
	add a,l
	ld l,a
	adc a,h
	sub l
	ld h,a
	ld e,(hl)	; Select instrument.

        ld a,c
        add a,$20
        push bc
        call write_fm
        pop bc
        ld a,b          ; Read note.
        and $3f
        ld hl,fm_notes
        add a,a         ; Index into note table.
        add a,l
        ld l,a
        adc a,h
        sub l
        ld h,a
        ld a,c
        ld e,(hl)       ; Get low byte.
        push bc
        push hl
        call write_fm
        pop hl
        pop bc
        inc hl
        ld e,(hl)       ; Get high byte (octave).
        ld a,b
        cpl
        and $c0         ; Is it bass?
        jr nz,.1        ; No, jump.
        ld a,e
        sub 2           ; Lower octave.
        ld e,a
.1:     ld a,b
        and $c0
        cp $40          ; Is it clarinet?
        jr nz,$+4       ; No, jump.
        inc e           ; Higher octave.
        inc e
        ld a,c
        add a,$10
        call write_fm
        pop de
        pop bc
        ret

        ;
        ; Detects FM (OPLL)
        ; Carry = Set = FM detected.
        ;         Clear = No FM detected.
        ;
detect_fm:
        ld bc,$0000
.1:     push bc
        ld hl,$fcc1     ; EXPTBL
        ld a,l
        add a,c
        ld l,a
        ld a,(hl)
        and $80
        or c
        call find_fm    ; Search in subslots.
        pop bc
        ret nc          ; Jump if something has been found.
        inc c
        bit 2,c         ; Four slots analyzed?
        jr z,.1         ; No, jump.
        ret

fm_signature_1:     db "APRLOPLL"   ; Internal MSX-Music.
fm_signature_2:     db "PAC2OPLL"   ; FM-Pac cartridge.

find_fm:
        bit 7,a         ; Expanded slot?
        ld b,1          ; No subslots.
        jr z,.1         ; No, jump.
        and $f3
        ld b,4          ; Ok, four subslots.
.1:     ld c,a
.2:     push bc
        ld h,$40
        ld a,c
        call ENASLT
        ld hl,$4018
        push hl
        ld de,fm_signature_1
        ld b,8
.4:     ld a,(de)
        cp (hl)
        jr nz,.5
        inc de
        inc hl
        djnz .4
.5:     pop hl
        jr z,.8         ; Detected? Jump to take note.
        ld de,fm_signature_2
        ld b,8
.6:     ld a,(de)
        cp (hl)
        jr nz,.7
        inc de
        inc hl
        djnz .6
.7:     jr nz,.3        ; Not detected? Jump to next subslot.
.8:     pop bc
        ld a,c          ; Take note of slot.
        ld (fm_slot),a
        push bc
        ld a,1          ; Enable FM.
        ld (fm_enabled),a
.3:
        ; Important! The H register should be $40 here.
        ld a,(cartridge_slot)
        call ENASLT
        pop bc
        ld a,(fm_enabled)
        or a
        ret nz
        ld a,c
        add a,4
        ld c,a
        djnz .2
        scf
        ret

        ;
        ; Init FM
        ;
init_fm:
        push ix
        push iy
        call fm_rom_switch
        ld hl,$ef00
        call INIOPL
        ld hl,.0
        ld b,24
.1:     ld e,(hl)
        inc hl
        ld a,(hl)
        inc hl
        call write_fm
        djnz .1
        call cartridge_rom_switch
	ld a,$30	; Piano
	ld (fm_inst),a
	ld a,$50	; Clarinet
	ld (fm_inst+1),a
	ld a,$40	; Flute
	ld (fm_inst+2),a
	ld a,$e0	; Acoustic bass
	ld (fm_inst+3),a
        pop iy
        pop ix
        ret

.0:     dw $0011        ; Unique programmable instrument (not used)
        dw $0111
        dw $0220
        dw $0320
        dw $04ff
        dw $05b2
        dw $06f4
        dw $07f4
        dw $0e20        ; Enables percussion mode.
        dw $2000        ; Turn off main voices.
        dw $2100
        dw $2200
        dw $2300
        dw $2400
        dw $2500
        dw $1620        ; Set up percussion.
        dw $1750
        dw $18c0
        dw $2605
        dw $2705
        dw $2801
        dw $3600        ;       / Bass Drum (volume for percussion)
        dw $3720        ; Hihat / Snare Drum
        dw $3800        ; Tom   / Top Cymbal

	;
	; Turn off FM
	;
turn_off_fm:
	ld a,(fm_slot)
	inc a
	ret z
	ld a,(fm_enabled)
	or a
	ret z
        call fm_rom_switch
	LD A,$10+$10
	LD E,$00
	CALL write_fm
	LD A,$11+$10
	LD E,$00
	CALL write_fm
	LD A,$12+$10
	LD E,$00
	CALL write_fm
	CALL cartridge_rom_switch
	RET

        ; Write a FM register
        ; A = register
        ; E = data
write_fm:
        jp WRTOPL

        ;
        ; Map FM BIOS 16K in $4000-$7FFF 
        ;
fm_rom_switch:
        di
        ld a,(fm_slot)
        ld h,$40
        jp ENASLT

        ;
        ; Map cartridge in $4000-$7FFF 
        ;
cartridge_rom_switch:
        ld a,(cartridge_slot)
        ld h,$40
        call ENASLT
        ei
        ret

fm_notes:
        ; Silence - 0
        dw 0
        ; Octave 2 - 1
        dw $14ad,$14b7,$14c2,$14cd,$14d9,$14e6
        dw $14f4,$1503,$1512,$1522,$1534,$1546
        ; Octave 3 - 13
        dw $16ad,$16b7,$16c2,$16cd,$16d9,$16e6
        dw $16f4,$1703,$1712,$1722,$1734,$1746
        ; Octave 4 - 25
        dw $18ad,$18b7,$18c2,$18cd,$18d9,$18e6
        dw $18f4,$1903,$1912,$1922,$1934,$1946
        ; Octave 5 - 37
        dw $1aad,$1ab7,$1ac2,$1acd,$1ad9,$1ae6
        dw $1af4,$1b03,$1b12,$1b22,$1b34,$1b46
        ; Octave 6 - 49
        dw $1cad,$1cb7,$1cc2,$1ccd,$1cd9,$1ce6
        dw $1cf4,$1d03,$1d12,$1d22,$1d34,$1d46
        ; Octave 7 - 61
        ; Space for two notes more.
      endif
    endif

    if COLECO+SG1000+SMS+MSX+SVI+SORD+PV2000
	org BASE_RAM
    endif
ram_start:

sprites:
    if SMS
	rb 256
    else
	rb 128
    endif
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
    if MSX
cartridge_slot:
	rb 1
fm_slot:
	rb 1
fm_enabled:
	rb 1
fm_inst:
	rb 4
    endif
mode:
	rb 1	; bit 0: NMI disabled.
		; bit 1: NMI received.
		; bit 2: No sprite flicker.
		; bit 3: Single charset mode.
		; bit 4: MSX2 sprites.
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
vdp_status:
	rb 1
    if COLECO
      if COLECO_SPINNER
spinner_data:
        rb 3
      endif
    endif
    if NABU
nabu_data0: rb 1
nabu_data1: rb 1
nabu_data2: rb 1
    endif

    if CVBASIC_MUSIC_PLAYER
music_tick:             rb 1
music_mode:             rb 1

    if CVBASIC_BANK_SWITCHING
music_bank:             rb 1
    endif
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
