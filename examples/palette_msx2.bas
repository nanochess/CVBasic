	'
	' MSX2 Palette demo
	'
	' by Oscar Toledo G. (example for CVBasic)
	' https://nanochess.org/
	'
	' Creation date: Feb/09/2026.
	'

	'
	' The RGB (red-green-blue) color order inside the 16-bit word is:
	' 0 0 0 0  0 g g g  0 r r r  0 b b b
	'

	PRINT AT 33,"Hello world!"

	PALETTE LOAD main_palette

	FOR #c = $0400 TO $043F
		VPOKE #c, $ff
	NEXT #c

	d = $41
	FOR #c = $2400 TO $2438 STEP 8
		VPOKE #c, d
		VPOKE #c + 1, d
		VPOKE #c + 2, d
		VPOKE #c + 3, d
		VPOKE #c + 4, d
		VPOKE #c + 5, d
		VPOKE #c + 6, d
		VPOKE #c + 7, d
		d = d + $10
	NEXT #c

	e = $80
	FOR #c = $1810 TO $181E STEP 2
		FOR d = 0 TO 7
			VPOKE #c + d * 32, e
			VPOKE #c + d * 32 + 1, e
		NEXT d
		e = e + 1
	NEXT #c

main_loop:
	FOR #c = $0010 TO $0070 STEP $0010
		WAIT
		WAIT
		PALETTE 15, #c
	NEXT #c

	FOR #c = $0100 TO $0700 STEP $0100
		WAIT
		WAIT
		PALETTE 15, #c
	NEXT #c

	FOR #c = $0001 TO $0007 STEP $0001
		WAIT
		WAIT
		PALETTE 15, #c
	NEXT #c

	GOTO main_loop

main_palette:
	DATA $0000
	DATA $0462
	DATA $0777
	DATA $0777
	DATA $0000
	DATA $0001
	DATA $0012
	DATA $0123
	DATA $0234
	DATA $0345
	DATA $0456
	DATA $0567
	DATA $0777
	DATA $0777
	DATA $0777
	DATA $0777
