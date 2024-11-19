	'
	' Space Attack (demo for CVBasic)
	'
	' by Oscar Toledo G.
	' https://nanochess.org/
	'
	' Creation date: Feb/29/2024.
	' Revision date: Nov/13/2024. Added pixel stars background and double-speed enemies.
	'

	DEFINE SPRITE 0,4,sprites_bitmaps

	DIM enemy_x(8)
	DIM enemy_y(8)
	DIM enemy_s(8)

restart_game:
	CLS
	MODE 2		' In this mode, char definitions are faster

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
	FOR d = 0 TO 31				' For each column
		e = e + RANDOM(4) + 2		' Displace the strip offset for this column.
		FOR #c = 0 TO 736 STEP 32
			e = ((e + 1) AND 7) OR 16	' Limit to range 16 to 23.
			VPOKE $1800 + #c + d, e		' Put strip character.
		NEXT #c
	NEXT d

	GOSUB update_score

game_loop:
	WAIT

	' Displace stars pixel by pixel
	'
	' This is almost magic because these characters are used in the whole screen,
	' so this redefinition of characters updates the whole screen.
	'
	DEFINE CHAR 16,8,VARPTR pixel_bitmaps(((FRAME / 2) AND 63) XOR 63)

	' Background "music" (two tones alternating each 16 video frames)
	#c = 960
	IF FRAME AND 32 THEN #c = 1023
	d = (FRAME AND 31) / 2
	SOUND 0, #c, 15 - d

	' Setup player sprite
	SPRITE 0,player_y-1,player_x,0,10

	' Setup bullet sprite
	IF bullet_y = 0 THEN	' Active?
		SPRITE 1,$d1,0,0,0	' No, remove sprite.
		SOUND 1,,0		' Disable sound.
	ELSE
		SPRITE 1,bullet_y-1,bullet_x,8,7	' Setup sprite.
		bullet_y = bullet_y - 4	' Displace bullet.
		SOUND 1,bullet_y+16,11	' Make sound.
	END IF

	'
	' Display and move the enemies.
	'
	FOR c = 0 TO 7
		IF enemy_s(c) = 0 THEN	' No enemy
			SPRITE c + 2, $d1, 0, 0, 0
			' Create one
			enemy_x(c) = RANDOM(240)
			enemy_y(c) = $c0 + c * 4
			enemy_s(c) = RANDOM(2) + 1
		ELSEIF enemy_s(c) < 3 THEN	' Enemy moving.
			SPRITE c + 2, enemy_y(c) - 1, enemy_x(c), 4, 2

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
				enemy_x(c) = RANDOM(240)
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
			IF FRAME AND 4 THEN d = 10 ELSE d = 6
			SPRITE c + 2, enemy_y(c) - 1, enemy_x(c), 12, d

			' Displace explosion slowly.
			IF FRAME AND 1 THEN
				IF enemy_y(c) < $c0 THEN enemy_y(c) = enemy_y(c) + 1
			END IF		

			' Explosion sound.
			SOUND 2,enemy_s(c)		
			enemy_s(c) = enemy_s(c) + 1
			IF enemy_s(c) = 80 THEN	' Time reached.
				SOUND 3,,0
				enemy_x(c) = RANDOM(240)
				enemy_y(c) = $f2
				enemy_s(c) = 1	' Bring back enemy.
			END IF
		END IF
	NEXT c

	'
	' Movement of the player.
	'
	IF cont1.left THEN IF player_x > 0 THEN player_x = player_x - 2
	IF cont1.right THEN IF player_x < 240 THEN player_x = player_x + 2
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
	PRINT AT 11,"GAME OVER"

	'
	' Explosion effect and sound.
	'
	SOUND 0,,0
	SOUND 1,,0
	SOUND 2,32,0
	FOR c = 0 TO 120
		WAIT
		SOUND 3,$E4 + (c AND 3),13
		SPRITE 0, player_y - 1 + RANDOM(5) - 2, player_x + RANDOM(5) - 2, 12, RANDOM(14) + 2
	NEXT c
	SOUND 3,,0

	'
	' Remove enemies.
	'
	FOR c = 1 TO 9
		SPRITE c, $d1, 0, 0, 0
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
	PRINT AT 2,#score,"0"
	END

	'
	' Pixel scrolling stars
	'
pixel_bitmaps:
	BITMAP "....X..."
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
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"

	BITMAP "....X..."
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
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"

	'
	' Bitmaps for the game.
	'
sprites_bitmaps:
	BITMAP ".......XX......."
	BITMAP ".......XX......."
	BITMAP "......XXXX......"
	BITMAP "......XXXX......"
	BITMAP "......XXXX......"
	BITMAP ".....XXXXXX....."
	BITMAP ".....XXXXXX....."
	BITMAP ".....XX..XX....."
	BITMAP ".....X....X....."
	BITMAP "..XX.XXXXXX.XX.."
	BITMAP ".XXX.XXXXXX.XXX."
	BITMAP ".XXXXX....XXXXX."
	BITMAP "XX..XXXXX.XX..XX"
	BITMAP "XXX.XXXXXXXXX.XX"
	BITMAP "XXXX.XXXXXX.XXXX"
	BITMAP ".XX..XX..XX..XX."

	BITMAP "....XXXXXXXX...."
	BITMAP "...X........X..."
	BITMAP "..X.XX....XX.X.."
	BITMAP ".X...XXXXXX...X."
	BITMAP ".X...X.XX.X...X."
	BITMAP ".X...XXXXXX...X."
	BITMAP ".X....XXXX....X."
	BITMAP ".X..XX....XX..X."
	BITMAP ".XXXX.XXXX.XXXX."
	BITMAP "XXX..X....X..XXX"
	BITMAP "..XXXXXXXXXXXX.."
	BITMAP "XXX....XX....XXX"
	BITMAP "X.XXXX.XX.XXXX.X"
	BITMAP "X..XX.XXXX.XX..X"
	BITMAP "XXX..XX..XX..XXX"
	BITMAP "..XXXX....XXXX.."

	BITMAP "................"
	BITMAP "................"
	BITMAP "................"
	BITMAP "................"
	BITMAP ".......XX......."
	BITMAP "......XXXX......"
	BITMAP "......XXXX......"
	BITMAP "......XXXX......"
	BITMAP "......XXXX......"
	BITMAP "....XXXXXXXX...."
	BITMAP "...XXXXXXXXXX..."
	BITMAP "......XXXX......"
	BITMAP ".....XX...XX...."
	BITMAP "................"
	BITMAP "................"
	BITMAP "................"

	BITMAP "................"
	BITMAP "................"
	BITMAP ".......X........"
	BITMAP ".......XX......."
	BITMAP "X......XXX......"
	BITMAP "XXX.....XXX...XX"
	BITMAP "XXXXX..XXXX..XXX"
	BITMAP "...XXXXXXXXXXX.."
	BITMAP ".....XXXXXX.X..."
	BITMAP "......X..X.X...."
	BITMAP ".....XXXXXXXX..."
	BITMAP "....XXX.XXXXXX.."
	BITMAP "...XXX.....XXXX."
	BITMAP "...XX........XXX"
	BITMAP "..XX............"
	BITMAP "................"
