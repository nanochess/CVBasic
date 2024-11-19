	'
	' Joystick moving with joystick (demo for CVBasic)
	'
	' by Oscar Toledo G.
	' https://nanochess.org/
	'
	' Creation date: Mar/03/2024.
	'

	DEFINE SPRITE 0,1,happy_face

	PRINT AT 36,"Happy face!"

	x = 50
	y = 100

	SPRITE 1, 96, 128, 0, 14

game_loop:
	WAIT
	PRINT AT 0, "VDP.STATUS = ", <>VDP.STATUS , "  "

	SPRITE 0, y - 1, x, 0, face_color

	IF FRAME AND 1 THEN
		face_color = 10
		IF cont1.up THEN IF y > 0 THEN y = y - 1
		IF cont1.left THEN IF x > 0 THEN x = x - 1
		IF cont1.right THEN IF x < 240 THEN x = x + 1
		IF cont1.down THEN IF y < 176 THEN y = y + 1
		IF cont1.button THEN face_color = 5
		IF cont1.button2 THEN face_color = 6
	END IF

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
