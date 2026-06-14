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

	PRINT AT 98,"CONT1.SPINNER max.per frame"

	PRINT AT 162,"CONT2.SPINNER max.per frame"

	x = 120
	y = 88
	
	max_x = 0
	max_y = 0

	counter = 0

game_loop:
	WAIT
	IF counter = 60 THEN
		counter = 0
		PRINT AT 130,<3>max_x
		PRINT AT 194,<3>max_y
	END IF

	counter = counter + 1

	#dx = CONT1.SPINNER
	#dy = CONT2.SPINNER
	mx = ABS(#dx)
	my = ABS(#dy)
	IF mx > max_x THEN max_x = mx
	IF my > max_y THEN max_y = my
	
	SPRITE 0, y - 1, x, 0, 10

	x = x + #dx
	y = y - #dy

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
