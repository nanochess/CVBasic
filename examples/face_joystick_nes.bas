	'
	' Joystick moving with joystick (demo for CVBasic)
	'
	' by Oscar Toledo G.
	' https://nanochess.org/
	'
	' Creation date: Mar/03/2024.
	' Revision date: Aug/23/2025. Adapted for NES.
	'

'	DEFINE SPRITE 0,1,happy_face

'	PRINT AT 36,"Happy face!"

	PALETTE LOAD full_palette

	x = 50
	y = 100

	SPRITE 2, 96, 128, 1, 3
	SPRITE 3, 96, 136, 3, 3

game_loop:
	WAIT
	PALETTE 31, (FRAME / 16) + $30

'	PRINT AT 0, "VDP.STATUS = ", <>VDP.STATUS , "  "

	SPRITE 0, y - 1, x, 1, face_palette
	SPRITE 1, y - 1, x + 8, 3, face_palette

	IF FRAME AND 1 THEN
		face_palette = 0
		IF cont1.up THEN IF y > 0 THEN y = y - 1
		IF cont1.left THEN IF x > 0 THEN x = x - 1
		IF cont1.right THEN IF x < 240 THEN x = x + 1
		IF cont1.down THEN IF y < 176 THEN y = y + 1
		IF cont1.button THEN face_palette = 1
		IF cont1.button2 THEN face_palette = 2
	END IF

	GOTO game_loop

full_palette:
	DATA BYTE $0F,$30,$30,$30
	DATA BYTE $0F,$30,$30,$30
	DATA BYTE $0F,$30,$30,$30
	DATA BYTE $0F,$30,$30,$30
	DATA BYTE $0F,$30,$30,$32
	DATA BYTE $0F,$30,$30,$34
	DATA BYTE $0F,$30,$30,$36
	DATA BYTE $0F,$30,$30,$38

	CHRROM 0

	CHRROM PATTERN 256

	BITMAP "......3333......"
	BITMAP "....33333333...."
	BITMAP "...3333333333..."
	BITMAP "..333333333333.."
	BITMAP ".33333333333333."
	BITMAP ".33333333333333."
	BITMAP "3333..3333..3333"
	BITMAP "3333..3333..3333"
	BITMAP "3333333333333333"
	BITMAP "3333333333333333"
	BITMAP ".33333333333333."
	BITMAP ".333..3333..333."
	BITMAP "..333......333.."
	BITMAP "...333....333..."
	BITMAP "....33333333...."
	BITMAP "......3333......"
