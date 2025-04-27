	'
	' Joystick moving with joystick (demo for CVBasic)
	'
	' by Oscar Toledo G.
	' https://nanochess.org/
	'
	' Creation date: Mar/03/2024.
	' Revision date: Apr/26/2025. Adapted for Sega Master System.
	'

	DEFINE SPRITE 0,2,happy_face

	PRINT AT 36,"Happy face!"

	x = 50
	y = 100

	SPRITE 2, 96, 128, 0
	SPRITE 3, 96, 136, 1

game_loop:
	WAIT
	PRINT AT 0, "VDP.STATUS = ", <>VDP.STATUS , "  "

	SPRITE 0,y-1,x,0
	SPRITE 1,y-1,x+8,1

	IF FRAME AND 1 THEN
		IF cont1.up THEN IF y > 0 THEN y = y - 1
		IF cont1.left THEN IF x > 0 THEN x = x - 1
		IF cont1.right THEN IF x < 240 THEN x = x + 1
		IF cont1.down THEN IF y < 176 THEN y = y + 1
		IF cont1.button THEN
			PALETTE 10+16,$30
		ELSEIF cont1.button2 THEN
			PALETTE 10+16,$03
		ELSE
			PALETTE 10+16,$0F
		END IF
	END IF

	GOTO game_loop

	' The face includes the color for the sprite
	' A = Yellow in the default palette.
	' F = White
	' 4 = Yellow
	' 6 = Red
happy_face:
	BITMAP "......AA"
	BITMAP "....AAAA"
	BITMAP "...AAAAA"
	BITMAP "..AAAAAA"
	BITMAP ".AAAAAAA"
	BITMAP ".AAFFFAA"
	BITMAP "AAAFFFAA"
	BITMAP "AAAFF4AA"
	BITMAP "AAAAAAAA"
	BITMAP "AAAAAAAA"
	BITMAP ".AAAAAAA"
	BITMAP ".AAA66AA"
	BITMAP "..AAA666"
	BITMAP "...AAA66"
	BITMAP "....AAAA"
	BITMAP "......AA"

	BITMAP "AA......"
	BITMAP "AAAA...."
	BITMAP "AAAAA..."
	BITMAP "AAAAAA.."
	BITMAP "AAAAAAA."
	BITMAP "AAFFFAA."
	BITMAP "AAFFFAAA"
	BITMAP "AA4FFAAA"
	BITMAP "AAAAAAAA"
	BITMAP "AAAAAAAA"
	BITMAP "AAAAAAA."
	BITMAP "AA66AAA."
	BITMAP "666AAA.."
	BITMAP "66AAA..."
	BITMAP "AAAA...."
	BITMAP "AA......"
