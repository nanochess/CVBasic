	'
	' Bouncing happy face (demo for CVBasic)
	'
	' by Oscar Toledo G.
	' https://nanochess.org/
	'
	' Creation date: Feb/28/2024.
	'

	DEFINE SPRITE 0,2,happy_face

	PRINT AT 36,"Happy face!"

	x = 50
	y = 100
	dx = 1
	dy = 1

game_loop:
	WAIT
	WAIT
	SPRITE 0,y-1,x,0
	SPRITE 1,y-1,x+8,1

	x = x + dx
	IF x = 0 THEN dx = -dx
	IF x = 240 THEN dx = -dx
	y = y + dy
	IF y = 0 THEN dy = -dy
	IF y = 176 THEN dy = -dy
	GOTO game_loop

	' The face includes the color for the sprite
	' A = Yellow in the default palette.
	' F = White
	' 4 = Yellow
	' 6 = Red
happy_face:
	BITMAP "......AA"
	BITMAP "....AAAA"
	BITMAP "...AAAAA"
	BITMAP "..AAAAAA"
	BITMAP ".AAAAAAA"
	BITMAP ".AAFFFAA"
	BITMAP "AAAFFFAA"
	BITMAP "AAAFF4AA"
	BITMAP "AAAAAAAA"
	BITMAP "AAAAAAAA"
	BITMAP ".AAAAAAA"
	BITMAP ".AAA66AA"
	BITMAP "..AAA666"
	BITMAP "...AAA66"
	BITMAP "....AAAA"
	BITMAP "......AA"

	BITMAP "AA......"
	BITMAP "AAAA...."
	BITMAP "AAAAA..."
	BITMAP "AAAAAA.."
	BITMAP "AAAAAAA."
	BITMAP "AAFFFAA."
	BITMAP "AAFFFAAA"
	BITMAP "AA4FFAAA"
	BITMAP "AAAAAAAA"
	BITMAP "AAAAAAAA"
	BITMAP "AAAAAAA."
	BITMAP "AA66AAA."
	BITMAP "666AAA.."
	BITMAP "66AAA..."
	BITMAP "AAAA...."
	BITMAP "AA......"
