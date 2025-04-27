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
	SPRITE 3, 96, 136, 2

game_loop:
	WAIT
	PRINT AT 0, "VDP.STATUS = ", <>VDP.STATUS , "  "

	SPRITE 0,y-1,x,0
	SPRITE 1,y-1,x+8,2

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
	BITMAP "......AAAA......"
	BITMAP "....AAAAAAAA...."
	BITMAP "...AAAAAAAAAA..."
	BITMAP "..AAAAAAAAAAAA.."
	BITMAP ".AAAAAAAAAAAAAA."
	BITMAP ".AAFFFAAAAFFFAA."
	BITMAP "AAAFFFAAAAFFFAAA"
	BITMAP "AAAFF4AAAA4FFAAA"
	BITMAP "AAAAAAAAAAAAAAAA"
	BITMAP "AAAAAAAAAAAAAAAA"
	BITMAP ".AAAAAAAAAAAAAA."
	BITMAP ".AAA66AAAA66AAA."
	BITMAP "..AAA666666AAA.."
	BITMAP "...AAA6666AAA..."
	BITMAP "....AAAAAAAA...."
	BITMAP "......AAAA......"
