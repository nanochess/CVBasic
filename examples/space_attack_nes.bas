	'
	' Space Attack (demo for CVBasic)
	'
	' by Oscar Toledo G.
	' https://nanochess.org/
	'
	' Creation date: Feb/29/2024.
	' Revision date: Nov/13/2024. Added pixel stars background and double-speed enemies.
	' Revision date: Aug/24/2025. Adapted for NES/Famicom.
	'

	DIM enemy_x(8)
	DIM enemy_y(8)
	DIM enemy_s(8)

restart_game:
	CLS
	PALETTE LOAD game_palette

	#score = 0

	player_x = 120
	player_y = 192
	bullet_y = 0
	FOR c = 0 TO 7
		enemy_s(c) = 0
	NEXT c

	SCREEN DISABLE

	' Draw the stars background
	'
	' We make a vertical strip using 8 characters (numbers 16 to 23)
	' and we repeat it continuously (24 rows / 8 characters = 3 repetitions)
	'
	FOR d = 0 TO 31				' For each column
		FOR #c = 0 TO 928 STEP 32
			e = RANDOM(8) + 16
			VPOKE $2000 + #c + d, e		' Put strip character.
			VPOKE $2800 + #c + d, e		' Put strip character.
		NEXT #c
	NEXT d

	SCREEN ENABLE

	GOSUB update_score

game_loop:
	WAIT

	'
	' Displace stars pixel by pixel
	'
	scroll_y = scroll_y - 1
	IF scroll_y = $ff THEN scroll_y = $ef
	SCROLL 0, scroll_y

	' Background "music" (two tones alternating each 16 video frames)
	#c = 960
	IF FRAME AND 32 THEN #c = 1023
	d = (FRAME AND 31) / 2
	SOUND 10, #c, 15 - d + 16

	' Setup player sprite
	SPRITE 0,player_y-1,player_x,0+1,0
	SPRITE 1,player_y-1,player_x+8,2+1,0

	' Setup bullet sprite
	IF bullet_y = 0 THEN	' Active?
		SPRITE 2,$f0,0,0,0	' No, remove sprites.
		SPRITE 3,$f0,0,0,0	
		SOUND 11,,16		' Disable sound.
	ELSE
		SPRITE 2,bullet_y-1,bullet_x,8+1,2	' Setup sprites.
		SPRITE 3,bullet_y-1,bullet_x+8,10+1,2	'
		bullet_y = bullet_y - 4	' Displace bullet.
		SOUND 11,bullet_y+16,11+16	' Make sound.
	END IF

	'
	' Display and move the enemies.
	'
	FOR c = 0 TO 7
		IF enemy_s(c) = 0 THEN	' No enemy
			SPRITE 4 + c * 2, $f0, 0, 0, 0
			SPRITE 5 + c * 2, $f0, 0, 0, 0
			' Create one
			enemy_x(c) = RANDOM(232) + 4
			enemy_y(c) = $f0 + RANDOM(16)
			enemy_s(c) = RANDOM(2) + 1
		ELSEIF enemy_s(c) < 3 THEN	' Enemy moving.
			SPRITE 4 + c * 2, enemy_y(c) - 1, enemy_x(c), 4+1, 1
			SPRITE 5 + c * 2, enemy_y(c) - 1, enemy_x(c) + 8, 6+1, 1

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
			IF enemy_y(c) >= $e8 AND enemy_y(c) <= $ef THEN	' Reached bottom.
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
						SOUND 14,$E7,13+16	' Start enemy explosion sound
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
				SPRITE 4 + c * 2, $f0, 0, 0, 0
				SPRITE 5 + c * 2, $f0, 0, 0, 0
			ELSE
				SPRITE 4 + c * 2, enemy_y(c) - 1, enemy_x(c), 12+1, 3
				SPRITE 5 + c * 2, enemy_y(c) - 1, enemy_x(c) + 8, 14+1, 3
			END IF

			' Displace explosion slowly.
			IF FRAME AND 1 THEN
				IF enemy_y(c) < $c0 THEN enemy_y(c) = enemy_y(c) + 1
			END IF		

			' Explosion sound.
			SOUND 14,enemy_s(c)		
			enemy_s(c) = enemy_s(c) + 1
			IF enemy_s(c) = 80 THEN	' Time reached.
				SOUND 14,,0+16
				enemy_x(c) = RANDOM(232) + 4
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
	'
	' Explosion effect and sound.
	'
	SOUND 10,,0+16
	SOUND 11,,0+16
	FOR c = 0 TO 120
		WAIT
		SOUND 14,$E4 + (c AND 3),13+16
		e = player_y - 1 + RANDOM(5) - 2
		d = player_x + RANDOM(5) - 2
		SPRITE 0, e, d, 12+1, 3
		SPRITE 1, e, d + 8, 14+1, 3
	NEXT c
	SOUND 14,,0+16

	'
	' Remove enemies.
	'
	FOR c = 2 TO 19
		SPRITE c, $f0, 0, 0, 0
	NEXT c

	CLS
	SCROLL 0,0
	WAIT

	PRINT AT 250,"GAME"
	PRINT AT 282,"OVER"

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
	SPRITE 32, 16, $c0, #score / 10000 % 10 * 2 + 128, 0
	SPRITE 33, 16, $c8, #score / 1000 % 10 * 2 + 128, 0
	SPRITE 34, 16, $d0, #score / 100 % 10 * 2 + 128, 0
	SPRITE 35, 16, $d8, #score / 10 % 10 * 2 + 128, 0
	SPRITE 36, 16, $e0, #score % 10 * 2 + 128, 0
	SPRITE 37, 16, $e8, 128, 0
	END

game_palette:
	DATA BYTE $0F,$30,$30,$30
	DATA BYTE $0F,$30,$30,$30
	DATA BYTE $0F,$30,$30,$30
	DATA BYTE $0F,$30,$30,$30
	DATA BYTE $0F,$16,$10,$30
	DATA BYTE $0F,$12,$16,$24
	DATA BYTE $0F,$12,$10,$30
	DATA BYTE $0F,$16,$27,$30

	CHRROM 0

	CHRROM PATTERN 16
	'
	' Pixel scrolling stars
	'
	BITMAP ".1......"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"

	BITMAP "........"
	BITMAP "........"
	BITMAP ".....1.."
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
	BITMAP "...1...."
	BITMAP "........"
	BITMAP "........"

	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP ".1......"
	BITMAP "........"
	BITMAP "........"

	BITMAP "........"
	BITMAP "......1."
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
	BITMAP "......1."
	BITMAP "........"

	BITMAP "........"
	BITMAP "........"
	BITMAP "....1..."
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"

	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP ".1......"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"

	CHRROM PATTERN 128

	BITMAP "3333333."
	BITMAP "3.....3."
	BITMAP "3.....3."
	BITMAP "3....33."
	BITMAP "3....33."
	BITMAP "3....33."
	BITMAP "3333333."
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"

	BITMAP "....3..."
	BITMAP "....3..."
	BITMAP "....3..."
	BITMAP "...33..."
	BITMAP "...33..."
	BITMAP "...33..."
	BITMAP "...33..."
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"

	BITMAP "3333333."
	BITMAP "3.....3."
	BITMAP "......3."
	BITMAP "3333333."
	BITMAP "33......"
	BITMAP "33......"
	BITMAP "3333333."
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"

	BITMAP "3333333."
	BITMAP "3.....3."
	BITMAP "......3."
	BITMAP ".333333."
	BITMAP ".....33."
	BITMAP "3....33."
	BITMAP "3333333."
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"

	BITMAP "3......."
	BITMAP "3......."
	BITMAP "3.....3."
	BITMAP "3.....3."
	BITMAP "3333333."
	BITMAP ".....33."
	BITMAP ".....33."
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"

	BITMAP "3333333."
	BITMAP "3.....3."
	BITMAP "3......."
	BITMAP "3333333."
	BITMAP ".....33."
	BITMAP "3....33."
	BITMAP "3333333."
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"

	BITMAP "33333..."
	BITMAP "3...3..."
	BITMAP "3......."
	BITMAP "3333333."
	BITMAP "3....33."
	BITMAP "3....33."
	BITMAP "3333333."
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"

	BITMAP "3333333."
	BITMAP "......3."
	BITMAP "......3."
	BITMAP ".....33."
	BITMAP ".....33."
	BITMAP ".....33."
	BITMAP ".....33."
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"

	BITMAP ".33333.."
	BITMAP ".3...3.."
	BITMAP ".3...3.."
	BITMAP "3333333."
	BITMAP "3.....3."
	BITMAP "3.....3."
	BITMAP "3333333."
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"

	BITMAP "3333333."
	BITMAP "3.....3."
	BITMAP "3.....3."
	BITMAP "3333333."
	BITMAP ".....33."
	BITMAP ".....33."
	BITMAP ".....33."
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"

	CHRROM PATTERN 256

	BITMAP ".......33......."
	BITMAP ".......33......."
	BITMAP "......3333......"
	BITMAP "......3333......"
	BITMAP "......3333......"
	BITMAP ".....333333....."
	BITMAP ".....333333....."
	BITMAP ".....332233....."
	BITMAP ".....322223....."
	BITMAP "..332333333233.."
	BITMAP ".33323333332333."
	BITMAP ".33333222233333."
	BITMAP "3322333332332233"
	BITMAP "3332333333333233"
	BITMAP "3333.333333.3333"
	BITMAP ".11..11..11..11."

	BITMAP "....33333333...."
	BITMAP "...3........3..."
	BITMAP "..3.33....33.3.."
	BITMAP ".3...333333...3."
	BITMAP ".3...323323...3."
	BITMAP ".3...333333...3."
	BITMAP ".3....3333 ...3."
	BITMAP ".3..22.33.22..3."
	BITMAP ".3222.2222.2223."
	BITMAP "311..211112..113"
	BITMAP "..333333333333.."
	BITMAP "3331111331111333"
	BITMAP "3133331331333313"
	BITMAP "3113313333133113"
	BITMAP "3331133..3311333"
	BITMAP "..3333....3333.."

	BITMAP "................"
	BITMAP "................"
	BITMAP "................"
	BITMAP "................"
	BITMAP ".......31......."
	BITMAP "......3221......"
	BITMAP "......3221......"
	BITMAP "......3221......"
	BITMAP "......3221......"
	BITMAP "....33322221...."
	BITMAP "...2222222221..."
	BITMAP "......2111......"
	BITMAP ".....21...21...."
	BITMAP "................"
	BITMAP "................"
	BITMAP "................"

	BITMAP "................"
	BITMAP "................"
	BITMAP ".......1........"
	BITMAP ".......12......."
	BITMAP "1......112......"
	BITMAP "111.....111...11"
	BITMAP "11112..1121..121"
	BITMAP "...11211221112.."
	BITMAP ".....11222221..."
	BITMAP "......122221...."
	BITMAP ".....11122211..."
	BITMAP "....111.112211.."
	BITMAP "...121.....1111."
	BITMAP "...12........111"
	BITMAP "..11............"
	BITMAP "................"
