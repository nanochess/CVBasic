	'
	' Controller bits (demo for CVBasic)
	'
	' by Oscar Toledo G.
	' https://nanochess.org/
	'
	' Creation date: Aug/23/2025.
	' Revision date: Aug/23/2025. Adapted for NES.
	'

game_loop:
	WAIT
	c = CONT1

	SPRITE 16, 64, 96, (c AND $80) / 128 * 2, 0
	SPRITE 17, 64, 104, (c AND $40) / 64 * 2, 0
	SPRITE 18, 64, 112, (c AND $20) / 32 * 2, 0
	SPRITE 19, 64, 120, (c AND $10) / 16 * 2, 0
	SPRITE 20, 64, 128, (c AND $08) / 8 * 2, 0
	SPRITE 21, 64, 136, (c AND $04) / 4 * 2, 0
	SPRITE 22, 64, 144, (c AND $02) / 2 * 2, 0
	SPRITE 23, 64, 152, (c AND $01) / 1 * 2, 0

	c = CONT1.KEY

	PRINT AT 335,<>c,"  "

	c = CONT2

	SPRITE 24, 192, 96, (c AND $80) / 128 * 2, 0
	SPRITE 25, 192, 104, (c AND $40) / 64 * 2, 0
	SPRITE 26, 192, 112, (c AND $20) / 32 * 2, 0
	SPRITE 27, 192, 120, (c AND $10) / 16 * 2, 0
	SPRITE 28, 192, 128, (c AND $08) / 8 * 2, 0
	SPRITE 29, 192, 136, (c AND $04) / 4 * 2, 0
	SPRITE 30, 192, 144, (c AND $02) / 2 * 2, 0
	SPRITE 31, 192, 152, (c AND $01) / 1 * 2, 0

	c = CONT2.KEY

	PRINT AT 847,<>c,"  "

	GOTO game_loop

	CHRROM 0

	CHRROM PATTERN 0

	BITMAP "..3333.."
	BITMAP ".33..33."
	BITMAP ".33..33."
	BITMAP ".33..33."
	BITMAP ".33..33."
	BITMAP ".33..33."
	BITMAP ".33..33."
	BITMAP "..3333.."
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"

	BITMAP "...33..."
	BITMAP "..333..."
	BITMAP "...33..."
	BITMAP "...33..."
	BITMAP "...33..."
	BITMAP "...33..."
	BITMAP "...33..."
	BITMAP "..3333.."
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"

