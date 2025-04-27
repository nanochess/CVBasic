	'
	' Using VARPTR to redefine graphics for levels
	'
	' by Oscar Toledo G.
	' https://nanochess.org/
	'
	' Creation date: Aug/26/2024.
	' Revision date: Sep/27/2025. Adapted to Sega Master System.
	'

	level = 1

	WHILE 1

		CLS

		DEFINE CHAR 128,2,VARPTR level_bitmaps((level - 1) * 64)	' Each character is 32 bytes. 2*32 = 64

		FOR c = 1 TO 10
			PRINT AT RANDOM(768),"\128"
		NEXT c
		FOR c = 1 TO 10
			PRINT AT RANDOM(768),"\129"
		NEXT c

		FOR c = 1 TO 120: WAIT: NEXT

		level = level + 1

		IF level = 3 THEN level = 1

	WEND

level_bitmaps:
	BITMAP "..aaaa.."
	BITMAP ".a....a."
	BITMAP "a.a..a.a"
	BITMAP "a......a"
	BITMAP "a.a..a.a"
	BITMAP "a..aa..a"
	BITMAP ".a....a."
	BITMAP "..aaaa.."

        BITMAP ".....3.."
	BITMAP "....3333"
	BITMAP "33..3.33"
	BITMAP ".3333333"
	BITMAP "..3333.."
	BITMAP ".33333.."
	BITMAP ".33..33."
	BITMAP ".33..33."

	BITMAP "..9999.."
	BITMAP ".9....9."
	BITMAP "9......9"
	BITMAP "9.9..9.9"
	BITMAP "9......9"
	BITMAP "9......9"
	BITMAP ".9....9."
	BITMAP "..9999.."

        BITMAP "..5..5.."
	BITMAP ".55..55."
	BITMAP ".555555."
	BITMAP ".5.55.5."
	BITMAP ".55555.5"
	BITMAP "..5555.5"
	BITMAP ".55.5555"
	BITMAP ".55.5555"

