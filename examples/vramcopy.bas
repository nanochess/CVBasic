	'
	' Example of DEFINE VRAM READ
	'
	' by Oscar Toledo G.
	' https://nanochess.org/
	'
	' Creation date: Oct/15/2024.
	'

	DIM array(64)

	CLS
	MODE 0
	DEFINE CHAR 16,2,wall_bitmaps
	DEFINE COLOR 16,2,wall_colors
	
	FOR #c = 0 TO 63
		VPOKE $1800 + #c, RANDOM(2) + 16
	NEXT #c

	DEFINE VRAM READ $1800,$0040,VARPTR array(0)

	FOR #c = 64 TO 704 STEP 64
		DEFINE VRAM $1800 + #c, $0040, VARPTR array(0)
	NEXT #c
	
	WHILE 1: WEND

wall_bitmaps:
	BITMAP "XXX.XXXX"
	BITMAP "XXX.XXXX"
	BITMAP "XXX.XXXX"
	BITMAP "........"
	BITMAP "XXXXXXX."
	BITMAP "XXXXXXX."
	BITMAP "XXXXXXX."
	BITMAP "........"

	BITMAP "XXXXXXX."
	BITMAP "X..X..XX"
	BITMAP "X..X..XX"
	BITMAP "X..X..XX"
	BITMAP "X..X..XX"
	BITMAP "X..X..XX"
	BITMAP "XXXXXXXX"
	BITMAP ".XXXXXXX"

wall_colors:
	DATA BYTE $6E,$6E,$6E,$6E,$6E,$6E,$6E,$6E
	DATA BYTE $F1,$F5,$F5,$F4,$F4,$F4,$F1,$F1