	'
	' Using VARPTR to redefine graphics for levels
	'
	' by Oscar Toledo G.
	' https://nanochess.org/
	'
	' Creation date: Aug/26/2024.
	'

	level = 1

	WHILE 1

		CLS

		DEFINE CHAR 128,2,VARPTR level_bitmaps((level - 1) * 16)	' Each character is 8 bytes. 2*8 = 16

		DEFINE COLOR 128,2,VARPTR level_colors((level - 1) * 16)	' Each character is 8 bytes. 2*8 = 16

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
	BITMAP "..XXXX.."
	BITMAP ".X....X."
	BITMAP "X.X..X.X"
	BITMAP "X......X"
	BITMAP "X.X..X.X"
	BITMAP "X..XX..X"
	BITMAP ".X....X."
	BITMAP "..XXXX.."

        BITMAP ".....X.."
	BITMAP "....XXXX"
	BITMAP "XX..X.XX"
	BITMAP ".XXXXXXX"
	BITMAP "..XXXX.."
	BITMAP ".XXXXX.."
	BITMAP ".XX..XX."
	BITMAP ".XX..XX."

	BITMAP "..XXXX.."
	BITMAP ".X....X."
	BITMAP "X......X"
	BITMAP "X.X..X.X"
	BITMAP "X......X"
	BITMAP "X......X"
	BITMAP ".X....X."
	BITMAP "..XXXX.."

        BITMAP "..X..X.."
	BITMAP ".XX..XX."
	BITMAP ".XXXXXX."
	BITMAP ".X.XX.X."
	BITMAP ".XXXXX.X"
	BITMAP "..XXXX.X"
	BITMAP ".XX.XXXX"
	BITMAP ".XX.XXXX"

level_colors:
	DATA BYTE $A1,$A1,$A1,$A1,$A1,$A1,$A1,$A1
	DATA BYTE $31,$31,$31,$31,$31,$31,$31,$31
	DATA BYTE $91,$91,$91,$91,$91,$91,$91,$91
	DATA BYTE $51,$51,$51,$51,$51,$51,$51,$51

