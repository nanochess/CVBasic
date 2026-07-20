    '
    ' Test of FM instruments
    '
    ' by Oscar Toledo G.
    ' https://nanochess.org/
    '
    ' Creation date: Jul/14/2026.
    '

    ' Enable ASCII16 or Sega Mapper in emulation.

    BANK ROM 128	' Required to enable FM.

    OPTION FM ON	' Required to integrate FM support.

    '
    ' This requires a MSX2+ or Sega Master System with FM extension (Japanese)
    '
    PLAY INSTRUMENT $00,$00,$00,$00	' All voices using user-defined instrument.

    debounce = 15

    instrument = 0

    PLAY FULL

    IF MUSIC.FM_ENABLED THEN
        PRINT AT 2,"Ready to play FM..."
    END IF

game_loop:
    PRINT AT 66,"Instrument: ",<2>instrument
    DEFINE VRAM $1866, 24, VARPTR names(instrument * 24)
    PRINT AT 162,"Press button to play"

    WAIT
    c = CONT
    IF debounce THEN debounce = debounce - 1: c = 0
    IF c AND 1 THEN
        debounce = 15
        IF instrument = 0 THEN instrument = 63 ELSE instrument = instrument - 1
    END IF
    IF c AND 4 THEN
        debounce = 15
        IF instrument = 63 THEN instrument = 0 ELSE instrument = instrument + 1
    END IF
    IF c AND 64 THEN
        debounce = 15
        PLAY INSTRUMENT VARPTR fm_instruments(instrument * 8)	' Define instrument.
        PLAY music_simple
    END IF
    IF c AND 128 THEN
        debounce = 15
        PLAY INSTRUMENT VARPTR fm_instruments(instrument * 8)	' Define instrument.
        PLAY music_bach
    END IF
    GOTO game_loop
    
music_simple:
    DATA BYTE 16
    MUSIC C4,-,-,-
    MUSIC D4,-,-,-
    MUSIC E4,-,-,-
    MUSIC F4,-,-,-
    MUSIC G4,-,-,-
    MUSIC A4,-,-,-
    MUSIC B4,-,-,-
    MUSIC C5,-,-,-
    MUSIC -,-,-,-
    MUSIC STOP

	' Bach Invention 8 (BWV779)
	' Fragment
music_bach:	DATA BYTE 7
	MUSIC F4,-
	MUSIC S,-
	MUSIC A4,-
	MUSIC S,-
	MUSIC F4,-
	MUSIC S,-
	MUSIC C5,-
	MUSIC S,-
	MUSIC F4,-
	MUSIC S,-

	MUSIC F5,-
	MUSIC S,-
	MUSIC E5,F3
	MUSIC D5,S
	MUSIC C5,A3
	MUSIC D5,S
	MUSIC C5,F3
	MUSIC A4#,S
	MUSIC A4,C4
	MUSIC A4#,S
	MUSIC A4,F3
	MUSIC G4,S

	MUSIC F4,F4
	MUSIC S,S
	MUSIC A4,E4
	MUSIC S,D4
	MUSIC C5,C4
	MUSIC S,D4
	MUSIC A4,C4
	MUSIC S,A3#
	MUSIC F5,A3
	MUSIC S,A3#
	MUSIC C5,A3
	MUSIC S,G3

	MUSIC A5,F3
	MUSIC C6,S
	MUSIC A5#,A3
	MUSIC C6,S
	MUSIC A5,C4
	MUSIC C6,S
	MUSIC A5#,A3
	MUSIC C6,S
	MUSIC A5,F4
	MUSIC C6,S
	MUSIC A5#,C4
	MUSIC C6,S

	MUSIC F5,A3
	MUSIC A5,C4
	MUSIC G5,A3#
	MUSIC A5,C4
	MUSIC F5,A3
	MUSIC A5,C4
	MUSIC G5,A3#
	MUSIC A5,C4
	MUSIC F5,A3
	MUSIC A5,C4
	MUSIC G5,A3#
	MUSIC A5,C4

	MUSIC D5,F3
	MUSIC F5,A3
	MUSIC E5,G3
	MUSIC F5,A3
	MUSIC D5,F3
	MUSIC F5,A3
	MUSIC E5,G3
	MUSIC F5,A3
	MUSIC D5,F3
	MUSIC F5,A3
	MUSIC E5,G3
	MUSIC F5,A3

	MUSIC B4,D3
	MUSIC S,F3
	MUSIC G4,E3
	MUSIC S,F3
	MUSIC D5,D3
	MUSIC S,F3
	MUSIC B4,E3
	MUSIC S,F3
	MUSIC F5,D3
	MUSIC S,F3
	MUSIC D5,E3
	MUSIC S,F3

	MUSIC G5,B3
	MUSIC A5,S
	MUSIC G5,G3
	MUSIC F5,S
	MUSIC E5,C4
	MUSIC F5,S
	MUSIC E5,G3
	MUSIC D5,S
	MUSIC C5,E4
	MUSIC D5,S
	MUSIC C5,C4
	MUSIC A4#,S

	MUSIC A4,F4
	MUSIC S,G4
	MUSIC D5,F4
	MUSIC C5,E4
	MUSIC B4,D4
	MUSIC C5,E4
	MUSIC B4,D4
	MUSIC A4,C4
	MUSIC G4,B3
	MUSIC A4,C4
	MUSIC G4,B3
	MUSIC F4,A3

	MUSIC E4,G3
	MUSIC F4,S
	MUSIC E4,C4
	MUSIC D4,B3
	MUSIC C4,A3
	MUSIC S,B3
	MUSIC C5,A3
	MUSIC B4,G3
	MUSIC C5,F3
	MUSIC S,G3
	MUSIC E4,F3
	MUSIC S,E3

	MUSIC F4,D3
	MUSIC S,E3
	MUSIC C5,D3
	MUSIC S,C3
	MUSIC E4,G3
	MUSIC S,F3
	MUSIC C5,E3
	MUSIC S,F3
	MUSIC D4,G3
	MUSIC S,S
	MUSIC B4,G2
	MUSIC S,S

	MUSIC C5,C4
	MUSIC S,S
	MUSIC S,S
	MUSIC S,S
	MUSIC STOP

	'
	' Editing waveforms (an editor could be made):
	'
	' Register:
	'          7     6       5       4     3    2  1  0
	'   0    AM(M)  VIB(M)  EGT(M)  KSR(M)  Multiple(M)
	'   1    AM(C)  VIB(C)  EGT(C)  KSR(C)  Multiple(C)
        '   2        KSL(M)      Total LEVEL MODULATOR
	'   3        KSL(C)     Unused    DC   DM    Feedback
	'   4            Attack (M)              Decay (M)
	'   5            Attack (C)              Decay (C)
	'   6           Sustain (M)             Release (M)
	'   7           Sustain (C)             Release (C)
	'

	'
	' Extracted from the FM-PAC ROM for Sony HB-F1XDJ by nanochess. Jul/14/2026.
	'
	' The original ROM entries are 32-byte wide, I ran an automatic processor
	' to get the following data in register order.
	'
	' Register:
	'  0 = rom[16]
	'  1 = rom[24]
	'  2 = rom[17]
	'  3 = (rom[25] & ~0x07) | ((rom[10] >> 1) & 7)  Feedback (preserves KSL(C))
	'  4 = rom[18]
	'  5 = rom[26]
	'  6 = rom[19]
	'  7 = rom[27]
	'
	' The ROM also contains entries 8-byte wide, but these have a
	' fixed 0x20 value in byte 3, and this renders it unusable.
	'
	' This data is important as there aren't references of instruments
	' settings for YM2413 in Internet (not even in the datasheet).
	'
	' Probably all original Japanese composing software for MSX2+
	' referred to the instruments ROM or allowed some alteration on
	' values, but it was early 1990s and without Internet probably
	' this data was forgotten.
	'
fm_instruments:
	DATA BYTE $31, $11, $0e, $05, $d9, $b2, $11, $f4	' 0: Piano 1
	DATA BYTE $30, $10, $0f, $04, $d9, $b2, $10, $f3	' 1: Piano 2
	DATA BYTE $61, $61, $12, $07, $b4, $56, $14, $17	' 2: Violin
	DATA BYTE $61, $31, $20, $07, $6c, $43, $18, $26	' 3: Flute 1
	DATA BYTE $a2, $30, $a0, $07, $88, $54, $14, $06	' 4: Clarinet
	DATA BYTE $31, $34, $20, $05, $72, $56, $0a, $1c	' 5: Oboe
	DATA BYTE $31, $71, $16, $07, $51, $52, $26, $24	' 6: Trumpet
	DATA BYTE $34, $30, $37, $06, $50, $30, $76, $06	' 7: Pipe organ
	DATA BYTE $17, $52, $18, $05, $88, $d9, $66, $24	' 8: Xylophone
	DATA BYTE $e1, $63, $0a, $06, $fc, $f8, $28, $29	' 9: Organ
	DATA BYTE $02, $41, $15, $05, $a3, $a3, $75, $05	' 10: Guitar
	DATA BYTE $19, $53, $0c, $06, $c7, $f5, $11, $03	' 11: Santool 1
	DATA BYTE $23, $43, $0f, $07, $dd, $bf, $4a, $05	' 12: Electric piano 1
	DATA BYTE $03, $09, $11, $0e, $d2, $b4, $f4, $f5	' 13: Clavicode 1
	DATA BYTE $01, $00, $06, $1e, $a3, $e2, $f4, $f4	' 14: Harpsicode 1
	DATA BYTE $01, $01, $11, $0e, $c0, $b4, $01, $f6	' 15: Harpsicode 2
	DATA BYTE $f9, $f1, $24, $06, $95, $d1, $e5, $f2	' 16: Vibraphone
	DATA BYTE $13, $11, $0c, $06, $fc, $d2, $33, $83	' 17: Koto 1
	DATA BYTE $01, $10, $0e, $07, $ca, $e6, $44, $24	' 18: Taiko
	DATA BYTE $e0, $f4, $1b, $87, $11, $f0, $04, $08	' 19: Engine 1
	DATA BYTE $ff, $70, $19, $07, $50, $1f, $05, $01	' 20: UFO
	DATA BYTE $13, $11, $11, $07, $fa, $f2, $21, $f4	' 21: Synthesizer bell
	DATA BYTE $a6, $42, $10, $0d, $fb, $b9, $11, $02	' 22: Chime
	DATA BYTE $40, $31, $89, $06, $c7, $f9, $14, $04	' 23: Synthesizer bass
	DATA BYTE $42, $44, $0b, $06, $94, $b0, $33, $f6	' 24: Synthesizer
	DATA BYTE $01, $03, $0b, $07, $ba, $d9, $25, $06	' 25: Synthesizer percussion
	DATA BYTE $40, $00, $00, $07, $fa, $d9, $37, $04	' 26: Synthesizer rhythm
	DATA BYTE $02, $03, $09, $07, $cb, $ff, $39, $06	' 27: Harm drum
	DATA BYTE $18, $11, $09, $05, $f8, $f5, $26, $26	' 28: Cowbell
	DATA BYTE $0b, $04, $09, $07, $f0, $f5, $01, $27	' 29: Close hi-hat
	DATA BYTE $40, $40, $07, $07, $d0, $d6, $01, $27	' 30: Snare drum
	DATA BYTE $00, $01, $07, $06, $cb, $e3, $36, $25	' 31: Bass drum
	DATA BYTE $11, $11, $08, $04, $fa, $b2, $20, $f4	' 32: Piano 3
	DATA BYTE $11, $11, $11, $00, $c0, $b2, $01, $f4	' 33: Electric piano 2
	DATA BYTE $19, $53, $15, $07, $e7, $95, $21, $03	' 34: Santool 2
	DATA BYTE $30, $70, $19, $07, $42, $62, $26, $24	' 35: Brass
	DATA BYTE $62, $71, $25, $07, $64, $43, $12, $26	' 36: Flute 2
	DATA BYTE $21, $03, $0b, $05, $90, $d4, $02, $f5	' 37: Clavicode 2
	DATA BYTE $01, $03, $0a, $05, $90, $a4, $03, $f5	' 38: Clavicode 3
	DATA BYTE $43, $53, $0e, $85, $b5, $e9, $84, $04	' 39: Koto 2
	DATA BYTE $34, $30, $26, $06, $50, $30, $76, $06	' 40: Pipe organ 2
	DATA BYTE $73, $33, $5a, $06, $99, $f5, $14, $15	' 41: PohdsPLA
	DATA BYTE $73, $13, $16, $05, $f9, $f5, $33, $03	' 42: RohdsPRA
	DATA BYTE $61, $21, $15, $07, $76, $54, $23, $06	' 43: Orch L
	DATA BYTE $63, $70, $1b, $07, $75, $4b, $45, $15	' 44: Orch R
	DATA BYTE $61, $a1, $0a, $05, $76, $54, $12, $07	' 45: Synthesizer violin
	DATA BYTE $61, $78, $0d, $0d, $85, $f2, $14, $03	' 46: Synthesizer organ
	DATA BYTE $31, $71, $15, $07, $b6, $f9, $03, $26	' 47: Synthesizer bass
	DATA BYTE $61, $71, $0d, $05, $75, $f2, $18, $03	' 48: Tube
	DATA BYTE $03, $0c, $14, $06, $a7, $fc, $13, $15	' 49: Shamisen
	DATA BYTE $13, $32, $80, $03, $20, $85, $03, $af	' 50: Magical
	DATA BYTE $f1, $31, $17, $05, $23, $40, $14, $09	' 51: Huwawa
	DATA BYTE $f0, $74, $17, $47, $5a, $43, $06, $fc	' 52: Wander flat
	DATA BYTE $20, $71, $0d, $06, $c1, $d5, $56, $06	' 53: Hardrock
	DATA BYTE $30, $32, $06, $06, $40, $40, $04, $74	' 54: Machine
	DATA BYTE $30, $32, $03, $03, $40, $40, $04, $74	' 55: Machine V
	DATA BYTE $01, $08, $0d, $07, $78, $f8, $7f, $f9	' 56: Comic
	DATA BYTE $c8, $c0, $0b, $05, $76, $f7, $11, $f9	' 57: SE-Comic
	DATA BYTE $49, $40, $0b, $07, $b4, $f9, $ff, $05	' 58: SE-Laser
	DATA BYTE $cd, $42, $0c, $06, $a2, $f0, $00, $01	' 59: SE-Noise
	DATA BYTE $51, $42, $13, $07, $13, $10, $42, $01	' 60: SE-Star 1
	DATA BYTE $51, $42, $13, $07, $13, $10, $42, $01	' 61: SE-Star 2
	DATA BYTE $30, $34, $12, $06, $23, $70, $26, $02	' 62: Engine 2
	DATA BYTE $00, $00, $ff, $f8, $00, $00, $ff, $ff	' 63: Silence

names:
	DATA BYTE "                 Piano 1"
	DATA BYTE "                 Piano 2"
	DATA BYTE "                  Violin"
	DATA BYTE "                 Flute 1"
	DATA BYTE "                Clarinet"
	DATA BYTE "                    Oboe"
	DATA BYTE "                 Trumpet"
	DATA BYTE "              Pipe organ"
	DATA BYTE "               Xylophone"
	DATA BYTE "                   Organ"
	DATA BYTE "                  Guitar"
	DATA BYTE "               Santool 1"
	DATA BYTE "        Electric piano 1"
	DATA BYTE "             Clavicode 1"
	DATA BYTE "            Harpsicode 1"
	DATA BYTE "            Harpsicode 2"
	DATA BYTE "              Vibraphone"
	DATA BYTE "                  Koto 1"
	DATA BYTE "                   Taiko"
	DATA BYTE "                Engine 1"
	DATA BYTE "                     UFO"
	DATA BYTE "        Synthesizer bell"
	DATA BYTE "                   Chime"
	DATA BYTE "        Synthesizer bass"
	DATA BYTE "             Synthesizer"
	DATA BYTE "  Synthesizer percussion"
	DATA BYTE "      Synthesizer rhythm"
	DATA BYTE "               Harm drum"
	DATA BYTE "                 Cowbell"
	DATA BYTE "            Close hi-hat"
	DATA BYTE "              Snare drum"
	DATA BYTE "               Bass drum"
	DATA BYTE "                 Piano 3"
	DATA BYTE "        Electric piano 2"
	DATA BYTE "               Santool 2"
	DATA BYTE "                   Brass"
	DATA BYTE "                 Flute 2"
	DATA BYTE "             Clavicode 2"
	DATA BYTE "             Clavicode 3"
	DATA BYTE "                  Koto 2"
	DATA BYTE "            Pipe organ 2"
	DATA BYTE "                PohdsPLA"
	DATA BYTE "                RohdsPRA"
	DATA BYTE "                  Orch L"
	DATA BYTE "                  Orch R"
	DATA BYTE "      Synthesizer violin"
	DATA BYTE "       Synthesizer organ"
	DATA BYTE "        Synthesizer bass"
	DATA BYTE "                    Tube"
	DATA BYTE "                Shamisen"
	DATA BYTE "                 Magical"
	DATA BYTE "                  Huwawa"
	DATA BYTE "             Wander flat"
	DATA BYTE "                Hardrock"
	DATA BYTE "                 Machine"
	DATA BYTE "               Machine V"
	DATA BYTE "                   Comic"
	DATA BYTE "                SE-Comic"
	DATA BYTE "                SE-Laser"
	DATA BYTE "                SE-Noise"
	DATA BYTE "               SE-Star 1"
	DATA BYTE "               SE-Star 2"
	DATA BYTE "                Engine 2"
	DATA BYTE "                 Silence"