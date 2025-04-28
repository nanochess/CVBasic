	'
	' Bouncing happy face (demo for CVBasic)
	'
	' by Oscar Toledo G.
	' https://nanochess.org/
	'
	' Creation date: Feb/28/2024.
	' Revision date: Apr/26/2025. Adapted for Sega Master System.
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
	SPRITE 1,y-1,x+8,2

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
	BITMAP "......AAAA......"
	BITMAP "....AAAAAAAA...."
	BITMAP "...AAAAAAAAAA..."
	BITMAP "..AAAAAAAAAAAA.."
	BITMAP ".AAAAAAAAAAAAAA."
	BITMAP ".AAFFFAAAAFFFAA."
	BITMAP "AAAFFFAAAAFFFAAA"
	BITMAP "AAAFF4AAAA4FFAAA"
	BITMAP "AAAAAAAAAAAAAAAA"
	BITMAP "AAAAAAAAAAAAAAAA"
	BITMAP ".AAAAAAAAAAAAAA."
	BITMAP ".AAA66AAAA66AAA."
	BITMAP "..AAA666666AAA.."
	BITMAP "...AAA6666AAA..."
	BITMAP "....AAAAAAAA...."
	BITMAP "......AAAA......"
