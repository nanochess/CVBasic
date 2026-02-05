	'
	' Spinner / Roller Controller test (Colecovision)
	' Demo for CVBasic.
	'
	' by Oscar Toledo G.
	' https://nanochess.org/
	'
	' Creation date: Feb/05/2026.
	'

	DEFINE SPRITE 0,1,happy_face

	PRINT AT 36,"Happy face!"

	x = 120
	y = 88

game_loop:
	WAIT
	WAIT
	SPRITE 0, y - 1, x, 0, 10

	x = x + CONT1.SPINNER
	y = y - CONT2.SPINNER

	GOTO game_loop

happy_face:
	BITMAP "......XXXX......"
	BITMAP "....XXXXXXXX...."
	BITMAP "...XXXXXXXXXX..."
	BITMAP "..XXXXXXXXXXXX.."
	BITMAP ".XXXXXXXXXXXXXX."
	BITMAP ".XXXXXXXXXXXXXX."
	BITMAP "XXXX..XXXX..XXXX"
	BITMAP "XXXX..XXXX..XXXX"
	BITMAP "XXXXXXXXXXXXXXXX"
	BITMAP "XXXXXXXXXXXXXXXX"
	BITMAP ".XXXXXXXXXXXXXX."
	BITMAP ".XXX..XXXX..XXX."
	BITMAP "..XXX......XXX.."
	BITMAP "...XXX....XXX..."
	BITMAP "....XXXXXXXX...."
	BITMAP "......XXXX......"
