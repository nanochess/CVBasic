	' Feb/27/2024 18:24
	VPOKE $3800,$3C
	VPOKE $3801,$42
	VPOKE $3802,$A5
	VPOKE $3803,$81
	VPOKE $3804,$A5
	VPOKE $3805,$99
	VPOKE $3806,$42
	VPOKE $3807,$3C

	x = 50
	y = 100
	dx = 1
	dy = 1

game_loop:
	WAIT
	WAIT
	VPOKE $1B00,y-1.
	VPOKE $1B01,x
	VPOKE $1B02,0
	VPOKE $1B03,10

	x = x + dx
	IF x = 0 THEN dx = -dx
	IF x = 248 THEN dx = -dx
	y = y + dy
	IF y = 0 THEN dy = -dy
	IF y = 184 THEN dy = -dy
	GOTO game_loop
