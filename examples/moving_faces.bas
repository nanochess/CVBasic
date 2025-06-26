	'
	' Multiple happy faces (demo for CVBasic)
	'
	' by Oscar Toledo G.
	' https://nanochess.org/
	'
	' Creation date: Jun/25/2025.
	'

	DEFINE SPRITE 0,1,happy_face

	PRINT AT 36,"Happy faces!"

	SIGNED #x

	DIM #x(4)
	DIM #y(4)

	' The horizontal movement range for sprites is from -32 to 255

	#x(0) = -32
	#y(0) = -8

	#x(1) = 32
	#y(1) = 64

	#x(2) = 64
	#y(2) = 128

	#x(3) = 96
	#y(3) = 184

game_loop:
	FOR c = 0 tO 3
		IF #x(c) < 0 THEN
			' The early clock bit moves the sprite 32 pixels to the left.
			SPRITE c, #y(c) - 1, #x(c) + 32, 0, 10 + $80	
		ELSE
			SPRITE c, #y(c) - 1, #x(c), 0, 10
		END IF
		#x(c) = #x(c) + 1
		IF #x(c) >= 256 THEN #x(c) = -32
	NEXT c
	WAIT
	WAIT
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
