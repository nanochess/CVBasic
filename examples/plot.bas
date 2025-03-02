	'
	' Drawing pixels and lines with CVBasic
	'
	' by Oscar Toledo G.
	' https://nanochess.org/
	'
	' Creation date: Jan/23/2025.
	'

	DEF FN PSET(x,y)=#c=((x) AND $f8.)+((y) / 8. * 256)+((y) AND 7.):VPOKE #c,VPEEK(#c) OR bit_table((x) AND 7)

	DEF FN PSETCOLOR(x,y,color)=PSET(x,y):VPOKE #c+$2000,color*16

	DEF FN PRESET(x,y)=#c=((x) AND $f8.)+((y) / 8. * 256)+((y) AND 7.):VPOKE #c,VPEEK(#c) AND NOT bit_table((x) AND 7)

	DEF FN LINE(w,x,y,z)=x1=w:y1=x:x2=y:y2=z:GOSUB draw_line

	DEF FN LINECOLOR(w,x,y,z,a)=x1=w:y1=x:x2=y:y2=z:c=a:GOSUB draw_line_color

	DEF FN CIRCLE(w,x,y)=x1=w:y1=x:c=y:GOSUB draw_circle

	MODE 1
	
	y = 20
	FOR x = 20 TO 220
		PSET(x, y)
	NEXT x

	FOR y = 20 TO 170
		PSET(x, y)
	NEXT y

	FOR x = 220 TO 20 STEP -1
		PSET(x, y)
	NEXT x

	FOR y = 170 TO 20 STEP -1
		PSET(x, y)
	NEXT y

	FOR y = 40 TO 150
		FOR x = 32 TO 55
			PSETCOLOR(x, y, y AND $0F)
		NEXT x
	NEXT y

	FOR x = 102 TO 202 STEP 10
		LINE(x, 40, 202, 150)
	NEXT x

	FOR y = 40 TO 150 STEP 10
		LINE(102, y, 202, 150)
	NEXT y

	FOR x = 8 TO 240 STEP 8
		LINECOLOR(128, 0, x, 16, (x / 8) AND $0F)
	NEXT x

	CIRCLE(80, 60, 15)
	CIRCLE(80, 100, 20)
	CIRCLE(80, 140, 25)

	WHILE 1: WEND

	'
	' Draw a line using the Bresenham algorithm
	'
	SIGNED #err

draw_line:	PROCEDURE
	sx = SGN(x2 + 0 - x1)
	sy = SGN(y2 + 0 - y1)
	#dx = ABS(x2 + 0 - x1)
	#dy = ABS(y2 + 0 - y1)
	IF #dx > #dy THEN
		#err = 2 * #dy - #dx
		WHILE 1
			PSET(x1, y1)
			IF x1 = x2 THEN RETURN
			IF #err < 0 THEN
				#err = #err + 2 * #dy
			ELSE
				#err = #err + 2 * (#dy - #dx)
				y1 = y1 + sy
			END IF
			x1 = x1 + sx
		WEND
	ELSE
		#err = 2 * #dx - #dy
		WHILE 1
			PSET(x1, y1)
			IF y1 = y2 THEN RETURN
			IF #err < 0 THEN
				#err = #err + 2 * #dx
			ELSE
				#err = #err + 2 * (#dx - #dy)
				x1 = x1 + sx
			END IF
			y1 = y1 + sy
		WEND
	END IF
	END

draw_line_color:	PROCEDURE
	sx = SGN(x2 + 0 - x1)
	sy = SGN(y2 + 0 - y1)
	#dx = ABS(x2 + 0 - x1)
	#dy = ABS(y2 + 0 - y1)
	IF #dx > #dy THEN
		#err = 2 * #dy - #dx
		WHILE 1
			PSETCOLOR(x1, y1, c)
			IF x1 = x2 THEN RETURN
			IF #err < 0 THEN
				#err = #err + 2 * #dy
			ELSE
				#err = #err + 2 * (#dy - #dx)
				y1 = y1 + sy
			END IF
			x1 = x1 + sx
		WEND
	ELSE
		#err = 2 * #dx - #dy
		WHILE 1
			PSETCOLOR(x1, y1, c)
			IF y1 = y2 THEN RETURN
			IF #err < 0 THEN
				#err = #err + 2 * #dx
			ELSE
				#err = #err + 2 * (#dx - #dy)
				x1 = x1 + sx
			END IF
			y1 = y1 + sy
		WEND
	END IF
	END

draw_points:	PROCEDURE
	PSET(x1 + x, y1 + y)
	PSET(x1 + x, y1 - y)
	PSET(x1 - x, y1 + y)
	PSET(x1 - x, y1 - y)
	PSET(x1 + y, y1 + x)
	PSET(x1 + y, y1 - x)
	PSET(x1 - y, y1 + x)
	PSET(x1 - y, y1 - x)
	END

draw_circle:	PROCEDURE
	x = 0
	y = c
	#err = 3 - 2 * c
	GOSUB draw_points
	WHILE x <= y
		IF #err > 0 THEN
			y = y - 1
			#err = #err + 4 * x - 4 * y + 10
		ELSE
			#err = #err + 4 * x + 6
		END IF
		x = x + 1
		GOSUB draw_points
	WEND

	END

bit_table:
	DATA BYTE $80,$40,$20,$10,$08,$04,$02,$01
