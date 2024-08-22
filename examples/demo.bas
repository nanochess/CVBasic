	'
	' Demo of graphics for CVBasic
	'
	' by Oscar Toledo G.
	'
	' Creation date: Mar/08/2024.
	' Revision date: Aug/06/2024. Added endless loop.
	'

	DIM x(32),y(32),col(32)

	MODE 0

	DEFINE SPRITE 0,1,sprite_bitmap

	' Make a bold font
	FOR #c = $0900 TO $0BFF
		d = VPEEK(#c)
		VPOKE #c, d OR (d + d)
	NEXT #c
	FOR #c = $2900 TO $2BFF
		VPOKE #c, $71
	NEXT #c

	DEFINE CHAR 128,50,image_char
	DEFINE COLOR 128,50,image_color

	WHILE 1

	CLS

	SCREEN image_pattern,0,260,8,8,8

	GOSUB small_wait

	RESTORE message_1

	GOSUB show_message

	GOSUB small_wait
	
	FOR c = 0 TO 7
		WAIT
		WAIT
		#c = 260 + c * 32
		SCREEN spaces,0,#c,8,1
		SCREEN image_pattern,0,#c+32,8,8,8
	NEXT c

	FOR c = 0 TO 7
		WAIT
		WAIT
		#c = 516 + c
		SCREEN spaces,0,#c,1,8,1
		SCREEN image_pattern,0,#c+1,8,8,8
	NEXT c

	RESTORE message_2

	GOSUB show_message

	GOSUB small_wait
	
	FOR c = 0 TO 144
		WAIT
		SPRITE 0,$A0,c,$00,$0f
	NEXT c

	RESTORE message_3

	GOSUB show_message

	GOSUB small_wait

	FOR c = 0 TO 31
		x(c) = RANDOM(176)
		y(c) = RANDOM(240)
		col(c) = (c % 14) + 2
		SPRITE c AND 31,y(c),x(c),$00,col(c)
	NEXT c

	FOR c = 0 TO 240
		WAIT
		FOR d = 0 TO 15
			SPRITE d,y(d),x(d),$00,col(d)
			y(d) = y(d) + 1
			IF y(d) = $c0 THEN y(d) = $f1
		NEXT d
		FOR d = 16 TO 31
			SPRITE d,y(d),x(d),$00,col(d)
			x(d) = x(d) + 1
			IF x(d) = $ff THEN x(d) = $00
		NEXT d
	NEXT c

	FOR c = 0 TO 31
		SPRITE c,$d1,0,0,0
	NEXT c
		
	RESTORE message_4

	GOSUB show_message

	GOSUB small_wait

	WEND

spaces:
	DATA BYTE $20,$20,$20,$20,$20,$20,$20,$20

	INCLUDE "portrait.bas"

small_wait:	PROCEDURE
	FOR c = 0 TO 60
		WAIT
	NEXT c
	END

show_message:	PROCEDURE

	'
	' Erase area.
	'
	FOR #position = $190e TO $19ee STEP 32
		FOR #c = 0 TO $11
			VPOKE #position + #c, 32
		NEXT #c
	NEXT #position

	'
	' Draw message.
	'
	#position = $1800 + 270
	DO
		READ BYTE d
		IF d = $0D THEN
			#position = ((#position + 32) AND $FFE0) + $000e
		ELSEIF d <> 0 THEN
			VPOKE #position, d
			#position = #position + 1
		END IF
		WAIT
	LOOP WHILE d

	END

message_1:
	DATA BYTE "Hi! This is a",$0d
	DATA BYTE "CVBasic demo",$0d
	DATA BYTE "program.",$00

message_2:
	DATA BYTE "You can displace",$0d
	DATA BYTE "graphics moving",$0d
	DATA BYTE "tiles on the",$0d
	DATA BYTE "screen instead of",$0d
	DATA BYTE "graphic data.",$00

message_3:
	DATA BYTE "Sprites can",$0d
	DATA BYTE "overlay",$0d
	DATA BYTE "background",$0d
	DATA BYTE "graphics.",$00

message_4:
	DATA BYTE "I hope you",$0d
	DATA BYTE "enjoyed the",$0d
	DATA BYTE "demo.",$00

sprite_bitmap:
	BITMAP "XXXXXXXXXXXXXXXX"
	BITMAP "XXXXXXXXXXXXXXXX"
	BITMAP "XXXXXXXXXXXXXXXX"
	BITMAP "XXXXXXXXXXXXXXXX"
	BITMAP "XXXXXXXXXXXXXXXX"
	BITMAP "XXXXXXXXXXXXXXXX"
	BITMAP "XXXXXXXXXXXXXXXX"
	BITMAP "XXXXXXXXXXXXXXXX"
	BITMAP "XXXXXXXXXXXXXXXX"
	BITMAP "XXXXXXXXXXXXXXXX"
	BITMAP "XXXXXXXXXXXXXXXX"
	BITMAP "XXXXXXXXXXXXXXXX"
	BITMAP "XXXXXXXXXXXXXXXX"
	BITMAP "XXXXXXXXXXXXXXXX"
	BITMAP "XXXXXXXXXXXXXXXX"
	BITMAP "XXXXXXXXXXXXXXXX"
