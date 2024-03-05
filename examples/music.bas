	rem
	rem Test of IntyBASIC music player
	rem by Oscar Toledo G. http://nanochess.org
	rem Aug/26/2014
	rem

	REM Include useful predefined constants

main:
	V=0

wait_key:
	CLS
        PRINT AT 66,"Press button"
        FOR c = 0 TO 60
                WAIT
        NEXT c
wait_loop:
	IF CONT1.BUTTON THEN GOTO play_1
	IF CONT1.BUTTON2 THEN GOTO play_2

	GOTO wait_loop

play_1:
        PRINT AT 66,"Bach Invention 8"
        PRINT AT 130,"(fragment)"
	WAIT
	PLAY SIMPLE
	PLAY tune_1

	' Sound effect if button touch
repeat:
	WAIT
	IF CONT1.BUTTON2 THEN V=15
        SOUND 2,300,V
        IF V>0 THEN V=V-1
        IF MUSIC.PLAYING THEN GOTO repeat
        GOTO wait_key

play_2:
        PRINT AT 66,"Mecha-8 Level 4 "
        PRINT AT 130,"(fragment)"
	WAIT
	PLAY FULL
	PLAY tune_2
repeat2:
	WAIT
        IF CONT1.BUTTON THEN PLAY OFF: GOTO wait_key
	GOTO repeat2

	' Bach Invention 8 (BWV779)
	' Fragment
tune_1:	DATA BYTE 7
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

	' Mecha-8 level 5: alone
	' Fragment
tune_2: DATA BYTE 5
	MUSIC G5#Y,C3#,-,M1
	MUSIC S,S,-,M2
	MUSIC F5#,G3#,-,M2
	MUSIC S,S,-,M2
	MUSIC E5,C3#,-,M1
	MUSIC S,S,-,M2
	MUSIC D5#,G3#,-,M2
	MUSIC S,S,-,M2
	MUSIC E5,C3#,-,M1
	MUSIC S,S,-,M2
	MUSIC F5#,G3#,-,M2
	MUSIC S,S,-,M2
	MUSIC G5#,C3#,-,M1
	MUSIC S,S,-,M2
	MUSIC S,G3#,-,M2
	MUSIC S,S,-,M2
	MUSIC S,C3#,-,M1
	MUSIC S,S,-,M2
	MUSIC C5#,G3#,-,M2
	MUSIC -,S,-,M2
	MUSIC G5#,C3#,-,M1
	MUSIC S,S,-,M2
	MUSIC E5,G3#,-,M2
	MUSIC -,S,-,M2
	MUSIC F5#,B2,-,M1
	MUSIC S,S,-,M2
	MUSIC S,F3#,-,M2
	MUSIC S,S,-,M2
	MUSIC S,B2,-,M1
	MUSIC S,S,-,M2
	MUSIC -,F3#,-,M2
	MUSIC -,S,-,M2
	MUSIC -,B2,-,M1
	MUSIC -,S,-,M2
	MUSIC -,F3#,-,M2
	MUSIC -,S,-,M2
	MUSIC -,B2,-,M1
	MUSIC -,S,-,M2
	MUSIC -,F3#,-,M1
	MUSIC -,S,-,M2
	MUSIC C5#,B2,-,M1
	MUSIC S,S,-,M2
	MUSIC F5#,F3#,-,M1
	MUSIC S,S,-,M2
	MUSIC C5#,B2,-,M1
	MUSIC S,S,-,M2
	MUSIC E5,A2,-,M1
	MUSIC S,S,-,M2
	MUSIC S,E3,-,M1
	MUSIC S,S,-,M2
	MUSIC S,A2,-,M1
	MUSIC S,S,-,M2
	MUSIC S,E3,-,M1
	MUSIC S,S,-,M2
	MUSIC S,A2,-,M1
	MUSIC S,S,-,M2
	MUSIC S,E3,-,M1
	MUSIC S,S,-,M2
	MUSIC S,A2,-,M1
	MUSIC S,S,-,M2
	MUSIC F5#,E3,-,M1
	MUSIC S,S,-,M2
	MUSIC E5,A2,-,M2
	MUSIC S,S,-,M2
	MUSIC D5#,E3,-,M1
	MUSIC S,S,-,M2
	MUSIC S,A2,-,M2
	MUSIC S,S,-,M2
	MUSIC C5,G2#,-,M1
	MUSIC S,S,-,M2
	MUSIC S,D3#,-,M2
	MUSIC S,S,-,M2
	MUSIC S,G2#,-,M1
	MUSIC S,S,-,M2
	MUSIC S,D3#,-,M2
	MUSIC S,S,-,M2
	MUSIC S,G2#,-,M1
	MUSIC S,S,-,M2
	MUSIC -,D3#,-,M2
	MUSIC -,S,-,M2
	MUSIC -,G2#,-,M1
	MUSIC -,S,-,M2
	MUSIC -,D3#,-,M2
	MUSIC -,S,-,M2
	MUSIC -,G2#,-,M1
	MUSIC -,S,-,M2
	MUSIC -,D3#,-,M1
	MUSIC -,S,-,M3
	MUSIC -,G2#,-,M1
	MUSIC -,S,-,M2
	MUSIC -,D3#,-,M1
	MUSIC -,S,-,M3
	MUSIC -,G2#,-,M1
	MUSIC -,S,-,M1
	MUSIC -,D3#,-,M1
	MUSIC -,S,-,M1
	MUSIC REPEAT
