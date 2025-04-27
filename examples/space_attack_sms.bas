	'
	' Space Attack (demo for CVBasic)
	'
	' by Oscar Toledo G.
	' https://nanochess.org/
	'
	' Creation date: Feb/29/2024.
	' Revision date: Nov/13/2024. Added pixel stars background and double-speed enemies.
	' Revision date: Apr/26/2025. Adapted for Sega Master System.
	'

	DEFINE SPRITE 0,8,sprites_bitmaps

	DEFINE CHAR 16,8,pixel_bitmaps

	DIM enemy_x(8)
	DIM enemy_y(8)
	DIM enemy_s(8)

restart_game:
	CLS
	MODE 4		' In this mode, char definitions are faster
	BORDER ,4	' Avoid scrolling in the columns 24-31

	#score = 0

	player_x = 120
	player_y = 176
	bullet_y = 0
	FOR c = 0 TO 7
		enemy_s(c) = 0
	NEXT c

	' Draw the stars background
	'
	' We make a vertical strip using 8 characters (numbers 16 to 23)
	' and we repeat it continuously (24 rows / 8 characters = 3 repetitions)
	'
	FOR d = 0 TO 46 STEP 2				' For each column
		FOR #c = 0 TO 1728 STEP 64
			e = RANDOM(8) + 16
			VPOKE $3800 + #c + d, e		' Put strip character.
		NEXT #c
	NEXT d

	GOSUB update_score

game_loop:
	WAIT

	'
	' Displace stars pixel by pixel
	'
	scroll_y = scroll_y - 1
	IF scroll_y = $ff THEN scroll_y = $df
	SCROLL 0, scroll_y

	' Background "music" (two tones alternating each 16 video frames)
	#c = 960
	IF FRAME AND 32 THEN #c = 1023
	d = (FRAME AND 31) / 2
	SOUND 0, #c, 15 - d

	' Setup player sprite
	SPRITE 0,player_y-1,player_x,0
	SPRITE 1,player_y-1,player_x+8,2

	' Setup bullet sprite
	IF bullet_y = 0 THEN	' Active?
		SPRITE 2,$e0,0,0	' No, remove sprites.
		SPRITE 3,$e0,0,0	
		SOUND 1,,0		' Disable sound.
	ELSE
		SPRITE 2,bullet_y-1,bullet_x,8	' Setup sprites.
		SPRITE 3,bullet_y-1,bullet_x+8,10	'
		bullet_y = bullet_y - 4	' Displace bullet.
		SOUND 1,bullet_y+16,11	' Make sound.
	END IF

	'
	' Display and move the enemies.
	'
	FOR c = 0 TO 7
		IF enemy_s(c) = 0 THEN	' No enemy
			SPRITE 4 + c * 2, $e0, 0, 0
			SPRITE 5 + c * 2, $e0, 0, 0
			' Create one
			enemy_x(c) = RANDOM(168) + 4
			enemy_y(c) = $c0 + c * 4
			enemy_s(c) = RANDOM(2) + 1
		ELSEIF enemy_s(c) < 3 THEN	' Enemy moving.
			SPRITE 4 + c * 2, enemy_y(c) - 1, enemy_x(c), 4
			SPRITE 5 + c * 2, enemy_y(c) - 1, enemy_x(c) + 8, 6

			' Slowly drift towards the player.
			IF (FRAME AND 3) = 0 THEN
				IF player_x < enemy_x(c) THEN
					enemy_x(c) = enemy_x(c) - 1
				ELSE
					enemy_x(c) = enemy_x(c) + 1
				END IF
			END IF
			' Move down.
			IF enemy_s(c) = 1 THEN
				enemy_y(c) = enemy_y(c) + 2
			ELSE
				enemy_y(c) = enemy_y(c) + 3
			END IF
			IF enemy_y(c) >= $c0 AND enemy_y(c) <= $c7 THEN	' Reached bottom.
				enemy_x(c) = RANDOM(168) + 4
				enemy_y(c) = $f2	' Reset enemy.
				enemy_s(c) = RANDOM(2) + 1
			END IF

			'
			' Check if bullet has been launched.
			'
			IF bullet_y <> 0 THEN	' Is bullet launched?
				IF ABS(bullet_x + 1 - enemy_x(c)) < 8 THEN
					IF ABS(bullet_y + 1 - enemy_y(c)) < 8 THEN
						enemy_s(c) = 3	' Enemy explodes
						#score = #score + 1
						GOSUB update_score
						bullet_y = 0
						sound 2,2	' Start enemy explosion sound
						SOUND 3,$E7,13
					END IF
				END IF
			END IF

			'
			' Check if player is hit by enemy.
			'
			IF ABS(player_y + 1 - enemy_y(c)) < 8 THEN
				IF ABS(player_x + 1 - enemy_x(c)) < 8 THEN
					GOTO player_dies
				END IF
			END IF
		ELSE
			' Enemy explosion.
			IF FRAME AND 4 THEN
				SPRITE 4 + c * 2, $e0, 0, 0
				SPRITE 5 + c * 2, $e0, 0, 0
			ELSE
				SPRITE 4 + c * 2, enemy_y(c) - 1, enemy_x(c), 12
				SPRITE 5 + c * 2, enemy_y(c) - 1, enemy_x(c) + 8, 14
			END IF

			' Displace explosion slowly.
			IF FRAME AND 1 THEN
				IF enemy_y(c) < $c0 THEN enemy_y(c) = enemy_y(c) + 1
			END IF		

			' Explosion sound.
			SOUND 2,enemy_s(c)		
			enemy_s(c) = enemy_s(c) + 1
			IF enemy_s(c) = 80 THEN	' Time reached.
				SOUND 3,,0
				enemy_x(c) = RANDOM(168) + 4
				enemy_y(c) = $f2
				enemy_s(c) = 1	' Bring back enemy.
			END IF
		END IF
	NEXT c

	'
	' Movement of the player.
	'
	IF cont1.left THEN IF player_x > 0 THEN player_x = player_x - 2
	IF cont1.right THEN IF player_x < 176 THEN player_x = player_x + 2
	IF cont1.button THEN	' Fire!
		IF bullet_y = 0 THEN	' Only if no bullet active.
			bullet_y = player_y - 8
			bullet_x = player_x
		END IF
	END IF
	GOTO game_loop

	'
	' Player dies.
	'
player_dies:
	PRINT AT 250,"GAME"
	PRINT AT 282,"OVER"

	'
	' Explosion effect and sound.
	'
	SOUND 0,,0
	SOUND 1,,0
	SOUND 2,32,0
	FOR c = 0 TO 120
		WAIT
		SOUND 3,$E4 + (c AND 3),13
		e = player_y - 1 + RANDOM(5) - 2
		d = player_x + RANDOM(5) - 2
		SPRITE 0, e, d, 12
		SPRITE 1, e, d + 8, 14
	NEXT c
	SOUND 3,,0

	'
	' Remove enemies.
	'
	FOR c = 2 TO 19
		SPRITE c, $e0, 0, 0
	NEXT c

	'
	' Big delay.
	'
	#c = FRAME
	DO
		WAIT
	LOOP WHILE FRAME - #c < 300

	GOTO restart_game

	'
	' Update the score on the screen.
	'
update_score:	PROCEDURE
	PRINT AT 57,"SCORE:"
	PRINT AT 89,#score,"0"
	END

	'
	' Pixel scrolling stars
	'
pixel_bitmaps:
	BITMAP ".5......"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"

	BITMAP "........"
	BITMAP "........"
	BITMAP ".....5.."
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"

	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "...5...."
	BITMAP "........"
	BITMAP "........"

	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP ".5......"
	BITMAP "........"
	BITMAP "........"

	BITMAP "........"
	BITMAP "......5."
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"

	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "......5."
	BITMAP "........"

	BITMAP "........"
	BITMAP "........"
	BITMAP "....5..."
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"

	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP ".5......"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"

	'
	' Bitmaps for the game.
	'
sprites_bitmaps:
	BITMAP ".......FF......."
	BITMAP ".......FF......."
	BITMAP "......FFFF......"
	BITMAP "......FFFF......"
	BITMAP "......FFFF......"
	BITMAP ".....FFFFFF....."
	BITMAP ".....FFFFFF....."
	BITMAP ".....FF55FF....."
	BITMAP ".....F5555F....."
	BITMAP "..FF4FFFFFF4FF.."
	BITMAP ".FFF4FFFFFF4FFF."
	BITMAP ".FFFFF4444FFFFF."
	BITMAP "FF44FFFFF4FF44FF"
	BITMAP "FFF4FFFFFFFFF4FF"
	BITMAP "FFFF.FFFFFF.FFFF"
	BITMAP ".66..66..66..66."

	BITMAP "....33333333...."
	BITMAP "...3........3..."
	BITMAP "..3.FF....FF.3.."
	BITMAP ".3...FFFFFF...3."
	BITMAP ".3...FDFFDF...3."
	BITMAP ".3...FFFFFF...3."
	BITMAP ".3....FFFF ...3."
	BITMAP ".3..DD.FF.DD..3."
	BITMAP ".3DDD.DDDD.DDD3."
	BITMAP "366..D5555D..663"
	BITMAP "..333333333333.."
	BITMAP "333CCCC33CCCC333"
	BITMAP "3C3333C33C3333C3"
	BITMAP "3CC33C3333C33CC3"
	BITMAP "333CC33..33CC333"
	BITMAP "..3333....3333.."

	BITMAP "................"
	BITMAP "................"
	BITMAP "................"
	BITMAP "................"
	BITMAP ".......F5......."
	BITMAP "......F775......"
	BITMAP "......F775......"
	BITMAP "......F775......"
	BITMAP "......F775......"
	BITMAP "....FFF77775...."
	BITMAP "...7777777775..."
	BITMAP "......7555......"
	BITMAP ".....75...75...."
	BITMAP "................"
	BITMAP "................"
	BITMAP "................"

	BITMAP "................"
	BITMAP "................"
	BITMAP ".......6........"
	BITMAP ".......6A......."
	BITMAP "6......66A......"
	BITMAP "666.....666...66"
	BITMAP "6666A..66A6..6A6"
	BITMAP "...66A66AA666A.."
	BITMAP ".....66AAAAA6..."
	BITMAP "......6AAAA6...."
	BITMAP ".....666AAA66..."
	BITMAP "....666.66AA66.."
	BITMAP "...6A6.....6666."
	BITMAP "...6A........666"
	BITMAP "..66............"
	BITMAP "................"
