	'
	' Controller test
	'
	' by Oscar Toledo G.
	'
	' Creation date: Aug/21/2024.
	' Revision date: Oct/15/2024. Solved wrong display for number key in 2nd controller.
	'

	CONST left_x = 56
	CONST left_y = 40
	CONST right_x = 160
	CONST right_y = 40

	DEF FN CHAR_XY(x, y) = ((y) / 8 * 32 + (x) / 8)

	MODE 2		' Color for sets of 8 characters.

	DEFINE CHAR 27,7,extra_bitmaps

	VPOKE $2003, $E1	' Color for characters $18-$1f
	VPOKE $2004, $14	' $20-$27
	VPOKE $2005, $1F	' $28-$29
	VPOKE $2006, $1F	' $30-$37
	VPOKE $2007, $1F	' $38-$3f
	VPOKE $2008, $F4	' $40-$47
	VPOKE $2009, $F4	' $48-$4f
	VPOKE $200A, $F4	' $50-$57
	VPOKE $200B, $F4	' $58-$5f
	VPOKE $200C, $F4	' $60-$67
	VPOKE $200D, $F4	' $68-$6f
	VPOKE $200E, $F4	' $70-$77
	VPOKE $200F, $F4	' $78-$7f

	' Center numbers bitmaps
	FOR #c = $0150 TO $01CF
		d = VPEEK(#c)
		VPOKE #c, (d / 2) OR (d / 4)
	NEXT #c
	DEFINE CHAR 42,2,number_bitmap

	VDP(1) = $E0	' 8x8 sprites
	VDP(6) = $00	' Sprites use character bitmaps.

	PRINT AT 36,"CVBasic controller test"

	#c = CHAR_XY(left_x, left_y)
	GOSUB draw_controller
	#c = CHAR_XY(right_x, right_y)
	GOSUB draw_controller

main_loop:
	WHILE 1
		IF cont1.up THEN
			SPRITE 0, left_y - 1, left_x + 16, 27, 9
		ELSE
			SPRITE 0, $d1, 0, 0, 0
		END IF
		IF cont1.left THEN
			SPRITE 1, left_y + 15, left_x, 30, 9
		ELSE
			SPRITE 1, $d1, 0, 0, 0
		END IF
		IF cont1.right THEN
			SPRITE 2, left_y + 15, left_x + 32, 28, 9
		ELSE
			SPRITE 2, $d1, 0, 0, 0
		END IF
		IF cont1.down THEN
			SPRITE 3, left_y + 31, left_x + 16, 29, 9
		ELSE
			SPRITE 3, $d1, 0, 0, 0
		END IF
		IF cont1.button THEN
			SPRITE 4, left_y + 47, left_x - 8, 31, 9
		ELSE
			SPRITE 4, $d1, 0, 0, 0
		END IF
		IF cont1.button2 THEN
			SPRITE 5, left_y + 47, left_x + 40, 31, 9
		ELSE
			SPRITE 5, $d1, 0, 0, 0
		END IF
		c = cont1.key
		IF c = 15 THEN
			SPRITE 6, $d1, 0, 0, 0
		ELSE
			GOSUB prepare_key
			SPRITE 6, left_y + y, left_x + x, c, 9
		END IF
		IF cont2.up THEN
			SPRITE 7, right_y - 1, right_x + 16, 27, 9
		ELSE
			SPRITE 7, $d1, 0, 0, 0
		END IF
		IF cont2.left THEN
			SPRITE 8, right_y + 15, right_x, 30, 9
		ELSE
			SPRITE 8, $d1, 0, 0, 0
		END IF
		IF cont2.right THEN
			SPRITE 9, right_y + 15, right_x + 32, 28, 9
		ELSE
			SPRITE 9, $d1, 0, 0, 0
		END IF
		IF cont2.down THEN
			SPRITE 10, right_y + 31, right_x + 16, 29, 9
		ELSE
			SPRITE 10, $d1, 0, 0, 0
		END IF
		IF cont2.button THEN
			SPRITE 11, right_y + 47, right_x - 8, 31, 9
		ELSE
			SPRITE 11, $d1, 0, 0, 0
		END IF
		IF cont2.button2 THEN
			SPRITE 12, right_y + 47, right_x + 40, 31, 9
		ELSE
			SPRITE 12, $d1, 0, 0, 0
		END IF
		c = cont2.key
		IF c = 15 THEN
			SPRITE 14, $d1, 0, 0, 0
		ELSE
			GOSUB prepare_key
			SPRITE 14, right_y + y, right_x + x, c, 9
		END IF

		WAIT

	WEND

draw_controller:	PROCEDURE
	FOR #d = #c - $0021 TO #c + $01DF STEP $20
		PRINT AT #d, "!!!!!!!"
	NEXT #d

	PRINT AT #c + $0000, "!!\27!!"
	PRINT AT #c + $0040, "\30!\31!\28"
	PRINT AT #c + $0080, "!!\29!!"
	PRINT AT #c + $00bf, "\31!!!!!\31"
	PRINT AT #c + $0100, "1!2!3"
	PRINT AT #c + $0140, "4!5!6"
	PRINT AT #c + $0180, "7!8!9"
	PRINT AT #c + $01C0, "*!0!+"
	END

prepare_key:	PROCEDURE
	IF c = 0 THEN
		x = 16
		y = 111
		c = 48
	ELSEIF c = 10 THEN
		x = 0
		y = 111
		c = 42
	ELSEIF c = 11 THEN
		x = 32
		y = 111
		c = 43
	ELSEIF c > 0 AND c < 10 THEN
		x = ((c - 1) % 3) * 16
		y = 63 + ((c - 1) / 3) * 16
		c = c + 48
	ELSE
		' Some systems have extra characters
		x = 16
		y = 127
	END IF
	END
		
extra_bitmaps:
	BITMAP "...XX..."
	BITMAP "..XXXX.."
	BITMAP ".XXXXXX."
	BITMAP "...XX..."
	BITMAP "...XX..."
	BITMAP "...XX..."
	BITMAP "...XX..."
	BITMAP "...XX..."

	BITMAP "........"
	BITMAP ".....X.."
	BITMAP ".....XX."
	BITMAP "XXXXXXXX"
	BITMAP "XXXXXXXX"
	BITMAP ".....XX."
	BITMAP ".....X.."
	BITMAP "........"

	BITMAP "...XX..."
	BITMAP "...XX..."
	BITMAP "...XX..."
	BITMAP "...XX..."
	BITMAP "...XX..."
	BITMAP ".XXXXXX."
	BITMAP "..XXXX.."
	BITMAP "...XX..."

	BITMAP "........"
	BITMAP "..X....."
	BITMAP ".XX....."
	BITMAP "XXXXXXXX"
	BITMAP "XXXXXXXX"
	BITMAP ".XX....."
	BITMAP "..X....."
	BITMAP "........"

	BITMAP "..XXXX.."
	BITMAP ".XXXXXX."
	BITMAP "XXXXXXXX"
	BITMAP "XXXXXXXX"
	BITMAP "XXXXXXXX"
	BITMAP "XXXXXXXX"
	BITMAP ".XXXXXX."
	BITMAP "..XXXX.."

	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"

	BITMAP "XXXXXXXX"
	BITMAP "XXXXXXXX"
	BITMAP "XXXXXXXX"
	BITMAP "XXXXXXXX"
	BITMAP "XXXXXXXX"
	BITMAP "XXXXXXXX"
	BITMAP "XXXXXXXX"
	BITMAP "XXXXXXXX"

number_bitmap:
	BITMAP "........"
	BITMAP ".XX..XX."
	BITMAP "..XXXX.."
	BITMAP ".XXXXXX."
	BITMAP "..XXXX.."
	BITMAP ".XX..XX."
	BITMAP "........"
	BITMAP "........"

	BITMAP "..XX.XX."
	BITMAP "..XX.XX."
	BITMAP ".XXXXXXX"
	BITMAP "..XX.XX."
	BITMAP ".XXXXXXX"
	BITMAP "..XX.XX."
	BITMAP "..XX.XX."
	BITMAP "........"
