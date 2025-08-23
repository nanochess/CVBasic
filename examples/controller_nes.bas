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

	SPRITE 16, 24, 8, (c AND $80) / 128 * 2, 0
	SPRITE 17, 24, 16, (c AND $40) / 64 * 2, 0
	SPRITE 18, 24, 24, (c AND $20) / 32 * 2, 0
	SPRITE 19, 24, 32, (c AND $10) / 16 * 2, 0
	SPRITE 20, 24, 40, (c AND $08) / 8 * 2, 0
	SPRITE 21, 24, 48, (c AND $04) / 4 * 2, 0
	SPRITE 22, 24, 56, (c AND $02) / 2 * 2, 0
	SPRITE 23, 24, 64, (c AND $01) / 1 * 2, 0

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

