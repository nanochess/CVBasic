	'
	' Viboritas (demo for CVBasic)
	'
	' by Oscar Toledo G.
	' https://nanochess.org/
	'
	' Creation date: Oct/1990.
	' Revision date: Feb/29/2024. Ported to CVBasic.
	' Revision date: Aug/23/2025. Adapted to NES.
	'

	' The original game was made in Z80 assembler,
	' you can see it here: https://nanochess.org/viboritas.html

	' It is easier to understand in CVBasic ;)

	DIM #ladders(15)

restart_game:
	lives = 2
	level = 1
restart_level:
	
	PRINT AT 780,"Lives: ",lives
	PRINT AT 841,"nanochess 1990"
	
	' Palette for the player
	PALETTE 17,$12
	PALETTE 18,$2c
	PALETTE 19,$36

	' Palette for snakes
	PALETTE 21,$0F
	PALETTE 22,$30
	PALETTE 23,$2a

next_level:
	GOSUB draw_level

	x_player = 8
	y_player = 16
	player_frame = 0

	x_enemy1 = random(128) + 64
	y_enemy1 = 56
	enemy1_frame = 24
	x_enemy2 = random(128) + 80
	y_enemy2 = 96
	enemy2_frame = 32
	x_enemy3 = random(128) + 48
	y_enemy3 = 136
	enemy3_frame = 24

	enemy_speed = 0

	GOSUB start_song

game_loop:
	WHILE 1
		WAIT
		GOSUB play_song

		SPRITE 0, y_player + 23, x_player, player_frame + 1, 0
		SPRITE 1, y_player + 23, x_player + 8, player_frame + 3, 0
		SPRITE 2, y_enemy1 + 23, x_enemy1, enemy1_frame + 1, 1
		SPRITE 3, y_enemy1 + 23, x_enemy1 + 8, enemy1_frame + 3, 1
		SPRITE 4, y_enemy2 + 23, x_enemy2, enemy2_frame + 1, 1
		SPRITE 5, y_enemy2 + 23, x_enemy2 + 8, enemy2_frame + 3, 1
		SPRITE 6, y_enemy3 + 23, x_enemy3, enemy3_frame + 1, 1
		SPRITE 7, y_enemy3 + 23, x_enemy3 + 8, enemy3_frame + 3, 1

		GOSUB move_player

		c = $50 + level * 4
		enemy_speed = enemy_speed + c
		WHILE enemy_speed >= $40
			enemy_speed = enemy_speed - $40
			GOSUB move_enemies
		WEND
		IF cont1.button THEN
			IF x_player > 232 AND x_player < 248 AND y_player = 136 THEN
				GOSUB sound_off

				FOR c = 1 to 10
					WAIT
					SOUND 10, 200 - c * 10, 13 + 16
				NEXT c

				level = level + 1
				IF level = 6 THEN
					GOSUB sound_off
					PRINT AT 267," YOU WIN! "
					#c = FRAME
					DO
						WAIT
					LOOP WHILE FRAME - #c < 300
					level = 1
					GOTO restart_level
				END IF
				GOTO next_level	
			END IF
		END IF
		IF ABS(y_player + 1 - y_enemy1) < 8 THEN
			IF ABS(x_player + 1 - x_enemy1) < 8 THEN GOTO player_dies
		END IF
		IF ABS(y_player + 1 - y_enemy2) < 8 THEN
			IF ABS(x_player + 1 - x_enemy2) < 8 THEN GOTO player_dies
		END IF
		IF ABS(y_player + 1 - y_enemy3) < 8 THEN
			IF ABS(x_player + 1 - x_enemy3) < 8 THEN GOTO player_dies
		END IF
	WEND

player_dies:
	GOSUB sound_off

	SOUND 10,640,13 + 48
	SOUND 11,320,13 + 48

	player_frame = 0
	FOR c = 0 TO 30
		WAIT
		WAIT
		player_frame = player_frame XOR 8
		SPRITE 0, y_player + 23, x_player, player_frame + 1, 0
		SPRITE 1, y_player + 23, x_player + 8, player_frame + 3, 0
	NEXT c

	GOSUB sound_off

	DO
		WAIT
		SOUND 10,200 - y_player,13 + 48
		player_frame = player_frame XOR 8
		SPRITE 0, y_player + 23, x_player, player_frame + 1, 0
		SPRITE 1, y_player + 23, x_player + 8, player_frame + 3, 0
		y_player = y_player + 2
	LOOP WHILE y_player < 160

	GOSUB sound_off

	IF lives = 0 THEN
		PRINT AT 267," GAME OVER "
		#c = FRAME
		DO
			WAIT
		LOOP WHILE FRAME - #c < 300
		GOTO restart_game
	END IF
	lives = lives - 1
	GOTO restart_level

	'
	' Draw the current level.
	'
draw_level:	PROCEDURE

	FOR c = 0 TO 63
		SPRITE c, $f0, 0, 0, 0
	NEXT c

	' Clean the screen in a curtain to hide palette change
	FOR #c = $2060 TO $207F
		FOR #d = #c TO #c + $280 STEP 32
			VPOKE #d, 32
		NEXT #d
		WAIT
	NEXT #c

	c = (level - 1) * 4
	PALETTE 4, palette_screens(c)
	PALETTE 5, palette_screens(c + 1)
	PALETTE 6, palette_screens(c + 2)
	PALETTE 7, palette_screens(c + 3)

	' Select palette 1 for game tiles
	' Indicators in the bottom are still in palette 0
	FOR #c = $23c0 TO $23ef
		VPOKE #c, $55
	NEXT #c

	' Get the base character to draw the level.
	base_character = 128 + (level - 1) * 4

	' Draw the background.
	FOR #c = $2060 TO $22DC STEP 4
		VPOKE #c, base_character
		VPOKE #c + 1, base_character
		VPOKE #c + 2, base_character
		VPOKE #c + 3, base_character + 1
	NEXT #c

	' Draw over the floors.
	FOR #c = $20e0 TO $22c0 STEP 160
		FOR #d = #c TO #c + 31 
			VPOKE #d, base_character + 2.
		NEXT #d
	NEXT #c

	' Draw the ladders.
	ladders = 6 - level

	next_ladder = 0

	FOR #c = $20e0 TO $2220 STEP 160
		FOR d = 1 TO ladders
			e = (RANDOM(28) + 2)
			#ladders(next_ladder) = #c + e
			next_ladder = next_ladder + 1
			VPOKE #c + e, base_character + 3.
			VPOKE #c + e + 32, base_character + 3.
			VPOKE #c + e + 64, base_character + 3.
			VPOKE #c + e + 96, base_character + 3.
			VPOKE #c + e + 128, base_character + 3.
		NEXT d
	NEXT #c

	' Draw the "exit".
	VPOKE $22be, 148

	END

	'
	' Move the player
	'
move_player:	PROCEDURE
	IF cont1.left THEN
		IF y_player % 40 = 16 THEN	' Player aligned on floor
			IF x_player > 0 THEN x_player = x_player - 1
			IF FRAME AND 4 THEN player_frame = 8 ELSE player_frame = 12
		END IF
	END IF
	IF cont1.right THEN
		IF y_player % 40 = 16 THEN	' Player aligned on floor
			IF x_player < 240 THEN x_player = x_player + 1
			IF FRAME AND 4 THEN player_frame = 0 ELSE player_frame = 4
		END IF
	END IF
	IF cont1.up THEN
		IF y_player % 40 = 16 THEN	' Player aligned on floor.
			column = (x_player + 7) /8
			row = (y_player + 8) / 8
			#c = $2060 + row * 32 + column
			FOR c = 0 TO next_ladder - 1
				IF #c >= #ladders(c) THEN
					#d = #c - #ladders(c)
					IF (#d AND $1F) = 0 THEN	' Centered horizontally?
						IF #d < $a0 THEN	' Over ladder?
							y_player = y_player - 1
						END IF
					END IF
				END IF
			NEXT c
		ELSE
			IF FRAME AND 4 THEN player_frame = 16 ELSE player_frame = 20
			y_player = y_player - 1
		END IF
	END IF
	IF cont1.down THEN
		IF y_player % 40 = 16 THEN	' Player aligned on floor.
			column = (x_player + 7) /8
			row = (y_player + 16) / 8
			#c = $2060 + row * 32 + column
			FOR c = 0 TO next_ladder - 1
				IF #c >= #ladders(c) THEN
					#d = #c - #ladders(c)
					IF (#d AND $1F) = 0 THEN	' Centered horizontally?
						IF #d < $a0 THEN	' Over ladder?
							y_player = y_player + 1
						END IF
					END IF
				END IF
			NEXT c
		ELSE
			IF FRAME AND 4 THEN player_frame = 16 ELSE player_frame = 20
			y_player = y_player + 1
		END IF
	END IF
	END

	'
	' Move the enemies.
	'
move_enemies:	PROCEDURE
	IF enemy1_frame < 32 THEN
		x_enemy1 = x_enemy1 - 1.
		IF x_enemy1 = 0 THEN enemy1_frame = 32
	ELSE
		x_enemy1 = x_enemy1 + 1.
		IF x_enemy1 = 240 THEN enemy1_frame = 24
	END IF
	enemy1_frame = (enemy1_frame AND $f8) + (FRAME AND 4)

	IF enemy2_frame < 32 THEN
		x_enemy2 = x_enemy2 - 1.
		IF x_enemy2 = 0 THEN enemy2_frame = 32
	ELSE
		x_enemy2 = x_enemy2 + 1.
		IF x_enemy2 = 240 THEN enemy2_frame = 24
	END IF
	enemy2_frame = (enemy2_frame AND $f8) + (FRAME AND 4)

	IF enemy3_frame < 32 THEN
		x_enemy3 = x_enemy3 - 1.
		IF x_enemy3 = 0 THEN enemy3_frame = 32
	ELSE
		x_enemy3 = x_enemy3 + 1.
		IF x_enemy3 = 240 THEN enemy3_frame = 24
	END IF
	enemy3_frame = (enemy3_frame AND $f8) + (FRAME AND 4)
	END

palette_screens:
	DATA BYTE $0F,$2A,$2C,$28
	DATA BYTE $0F,$02,$12,$10
	DATA BYTE $0F,$07,$17,$12
	DATA BYTE $0F,$17,$27,$10
	DATA BYTE $0F,$16,$2A,$10

	CHRROM 0

	CHRROM PATTERN 128

	BITMAP "11111111"
	BITMAP "11111111"
	BITMAP "11111111"
	BITMAP "11111111"
	BITMAP "11111111"
	BITMAP "11111111"
	BITMAP "11111111"
	BITMAP "11111111"

	BITMAP "111..111"
	BITMAP "111..111"
	BITMAP "111..111"
	BITMAP "111..111"
	BITMAP "111..111"
	BITMAP "111..111"
	BITMAP "111..111"
	BITMAP "111..111"

	BITMAP "33333333"
	BITMAP "33333333"
	BITMAP "........"
	BITMAP "33333333"
	BITMAP "33333333"
	BITMAP "........"
	BITMAP "33333333"
	BITMAP "33333333"

	BITMAP ".2....2."
	BITMAP ".2....2."
	BITMAP ".222222."
	BITMAP ".2....2."
	BITMAP ".2....2."
	BITMAP ".222222."
	BITMAP ".2....2."
	BITMAP ".2....2."

	BITMAP "22222221"
	BITMAP "21111121"
	BITMAP "21222121"
	BITMAP "21212121"
	BITMAP "21222121"
	BITMAP "21111121"
	BITMAP "22222221"
	BITMAP "11111111"

	BITMAP "2.222.2."
	BITMAP "2.222.2."
	BITMAP "2.222.2."
	BITMAP "2.222.2."
	BITMAP "2.222.2."
	BITMAP "2.222.2."
	BITMAP "2.222.2."
	BITMAP "2.222.2."

	BITMAP "333.333."
	BITMAP "........"
	BITMAP "33333333"
	BITMAP "33333333"
	BITMAP "33333333"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"

	BITMAP ".1....1."
	BITMAP ".1....1."
	BITMAP ".111111."
	BITMAP ".1....1."
	BITMAP ".1....1."
	BITMAP ".111111."
	BITMAP ".1....1."
	BITMAP ".1....1."

	BITMAP "11121111"
	BITMAP "11121111"
	BITMAP "11121111"
	BITMAP "22222222"
	BITMAP "11111112"
	BITMAP "11111112"
	BITMAP "11111112"
	BITMAP "22222222"

	BITMAP ".222222."
	BITMAP ".222222."
	BITMAP ".222222."
	BITMAP "........"
	BITMAP ".22.222."
	BITMAP ".22.222."
	BITMAP ".22.222."
	BITMAP "........"

	BITMAP "........"
	BITMAP "33333333"
	BITMAP "33333333"
	BITMAP "3.3.3.3."
	BITMAP ".3...3.."
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"

	BITMAP ".3....3."
	BITMAP ".3....3."
	BITMAP ".333333."
	BITMAP ".3....3."
	BITMAP ".3....3."
	BITMAP ".333333."
	BITMAP ".3....3."
	BITMAP ".3....3."

	BITMAP "111.111."
	BITMAP "111.111."
	BITMAP "111.111."
	BITMAP "........"
	BITMAP "111.111."
	BITMAP "111.111."
	BITMAP "111.111."
	BITMAP "........"

	BITMAP ".2......"
	BITMAP "..22...."
	BITMAP "....22.."
	BITMAP "......22"
	BITMAP "....22.."
	BITMAP "..22...."
	BITMAP ".2......"
	BITMAP ".2......"

	BITMAP "........"
	BITMAP "33333333"
	BITMAP "........"
	BITMAP "1.1.1.1."
	BITMAP ".1.1.1.1"
	BITMAP "........"
	BITMAP "33333333"
	BITMAP "........"

	BITMAP "3......3"
	BITMAP "3......3"
	BITMAP "33....33"
	BITMAP "3.3333.3"
	BITMAP "3......3"
	BITMAP "3......3"
	BITMAP "33....33"
	BITMAP "3.3333.3"

	BITMAP "1......1"
	BITMAP ".1.11..."
	BITMAP "..11.111"
	BITMAP ".1...111"
	BITMAP "..111..1"
	BITMAP "..1..111"
	BITMAP ".1..1..1"
	BITMAP "..1..111"

	BITMAP ".2...222"
	BITMAP ".2..2..2"
	BITMAP "..2..222"
	BITMAP ".2......"
	BITMAP "..2.2..."
	BITMAP "...2.2.2"
	BITMAP "...2..2."
	BITMAP "..2..222"

	BITMAP "........"
	BITMAP "11111113"
	BITMAP "11111113"
	BITMAP "33333333"
	BITMAP "11131111"
	BITMAP "11131111"
	BITMAP "33333333"
	BITMAP "........"

	BITMAP "....22.."
	BITMAP "....22.."
	BITMAP "...22..."
	BITMAP "...22..."
	BITMAP "..22...."
	BITMAP "..22...."
	BITMAP "...22..."
	BITMAP "...22..."

	BITMAP ".3.3.3.."
	BITMAP "3333333."
	BITMAP ".3.3.3.."
	BITMAP "3333333."
	BITMAP ".3.3.3.."
	BITMAP "3333333."
	BITMAP ".3.3.3.."
	BITMAP "........"

	CHRROM PATTERN 256

	BITMAP ".......1.1.1...."
	BITMAP ".....11111311..."
	BITMAP "....111333331..."
	BITMAP ".....11333331..."
	BITMAP "....113333131..."
	BITMAP ".....11313331..."
	BITMAP "....122311131..."
	BITMAP "..1222213331...."
	BITMAP ".122122211111..."
	BITMAP "12211222212221.."
	BITMAP "12221222212221.."
	BITMAP "1222121111111..."
	BITMAP ".111112222111..."
	BITMAP "...12221222221.."
	BITMAP "...122211222221."
	BITMAP "...12222111111.."

	BITMAP "......11111111.."
	BITMAP ".....111333331.."
	BITMAP "......11333331.."
	BITMAP ".....113333131.."
	BITMAP "......13313331.."
	BITMAP ".....122311131.."
	BITMAP ".....12213331..."
	BITMAP "....12222111...."
	BITMAP "....1222221....."
	BITMAP "....12212221...."
	BITMAP "....12212221...."
	BITMAP "....1222111....."
	BITMAP ".....122221....."
	BITMAP ".....1221......."
	BITMAP ".....122221....."
	BITMAP ".....1222221...."

	BITMAP "....1.1.1......."
	BITMAP "...11111111....."
	BITMAP "...133333111...."
	BITMAP "...13333311....."
	BITMAP "...131333311...."
	BITMAP "...13331311....."
	BITMAP "...131113321...."
	BITMAP "....1333122221.."
	BITMAP ".....1112221221."
	BITMAP "..12221222211221"
	BITMAP "..12221222212221"
	BITMAP "...111.111212221"
	BITMAP "...111222211111."
	BITMAP "..12222212221..."
	BITMAP ".122222112221..."
	BITMAP "..11111122221..."

	BITMAP "..11111111......"
	BITMAP "..133333111....."
	BITMAP "..13333311......"
	BITMAP "..131333311....."
	BITMAP "..13331311......"
	BITMAP "..131113311....."
	BITMAP "...13331221....."
	BITMAP "....11122221...."
	BITMAP ".....1222221...."
	BITMAP "....12221221...."
	BITMAP "....12221221...."
	BITMAP ".....1112221...."
	BITMAP ".....122221....."
	BITMAP "......11221....."
	BITMAP ".....122221....."
	BITMAP "....1222221....."

	BITMAP "...111111111...."
	BITMAP "....1111111....."
	BITMAP "...111111111...."
	BITMAP "...111111111111."
	BITMAP "....111111112221"
	BITMAP "....111111112221"
	BITMAP ".....1333112211."
	BITMAP "...1221112221..."
	BITMAP ".11221222211...."
	BITMAP "12221.1111......"
	BITMAP "12221122221....."
	BITMAP ".111.12112211..."
	BITMAP "....1221.12221.."
	BITMAP "...11221.122221."
	BITMAP "..122221..1111.."
	BITMAP ".1222221........"

	BITMAP "....111111111..."
	BITMAP ".....1111111...."
	BITMAP "....111111111..."
	BITMAP ".111111111111..."
	BITMAP "122211111111...."
	BITMAP "122211111111...."
	BITMAP ".11221133311...."
	BITMAP "...1222111221..."
	BITMAP "....11222212211."
	BITMAP "......1111.12221"
	BITMAP ".....12222112221"
	BITMAP "...11221121.111."
	BITMAP "..12221.1221...."
	BITMAP ".12221..12211..."
	BITMAP "..111...122221.."
	BITMAP "........1222221."

	BITMAP "..1331311......."
	BITMAP ".13233211......."
	BITMAP ".13233211......."
	BITMAP ".1331311........"
	BITMAP ".11333311......."
	BITMAP "1233331311......"
	BITMAP "2113313311....1."
	BITMAP "...1113311...131"
	BITMAP "...133311....131"
	BITMAP "..1333311...1311"
	BITMAP ".1333311....1311"
	BITMAP ".133311.11.13311"
	BITMAP ".13331113311311."
	BITMAP ".13333333331311."
	BITMAP "..1333333333311."
	BITMAP "...11111111111.."

	BITMAP "....11.11......."
	BITMAP "...1331311......"
	BITMAP "..13233211......"
	BITMAP "..13233211......"
	BITMAP "..1331311......."
	BITMAP "...1333311......"
	BITMAP ".1133331311....."
	BITMAP "12133313311....."
	BITMAP "12211113311..1.."
	BITMAP ".111333311..131."
	BITMAP "..13333111.1311."
	BITMAP "..13331131.1311."
	BITMAP "..133311311311.."
	BITMAP "..133333333311.."
	BITMAP "...13333313311.."
	BITMAP "....111111111..."

	BITMAP ".......1131331.."
	BITMAP ".......11233231."
	BITMAP ".......11233231."
	BITMAP "........1131331."
	BITMAP ".......11333311."
	BITMAP "......1131333321"
	BITMAP ".1....1133133112"
	BITMAP "131...1133111..."
	BITMAP "131....113331..."
	BITMAP "1131...1133331.."
	BITMAP "1131....1133331."
	BITMAP "11331.11.113331."
	BITMAP ".11311331113331."
	BITMAP ".11313333333331."
	BITMAP ".1133333333331.."
	BITMAP "..11111111111..."

	BITMAP ".......11.11...."
	BITMAP "......1131331..."
	BITMAP "......11233231.."
	BITMAP "......11233231.."
	BITMAP ".......1131331.."
	BITMAP "......1133331..."
	BITMAP ".....113133331.."
	BITMAP ".....11331333121"
	BITMAP "..1..11331111221"
	BITMAP ".131..1133331..."
	BITMAP ".1131.11133331.."
	BITMAP ".1131133113331.."
	BITMAP "..113133113331.."
	BITMAP "..113333333331.."
	BITMAP "..11331333331..."
	BITMAP "...111111111...."

start_song:	PROCEDURE
	tick_note = 8
	song_note = 47
	END

play_song:	PROCEDURE
	tick_note = tick_note + 1.
	IF tick_note = 16. THEN
		tick_note = 0.
		song_note = song_note + 1.
		IF song_note = 48. THEN song_note = 0.
		note = song_notes(song_note)
		SOUND 10, #note_freq(note - 1)
	END IF
	SOUND 10, , volume_effect(tick_note) + 48
	END

sound_off:	PROCEDURE
	SOUND 10,,16
	SOUND 11,,16
	END

volume_effect:
	DATA BYTE 11,12,13,12,12,11,11,10
	DATA BYTE 10,9,9,10,10,9,9,8

song_notes:
	DATA BYTE 1,2,3,4,5,4,3,2
	DATA BYTE 1,2,3,4,5,4,3,2
	DATA BYTE 6,4,7,8,9,8,7,4
	DATA BYTE 6,4,7,8,9,8,7,4
	DATA BYTE 3,12,8,10,11,10,8,12
	DATA BYTE 6,4,7,8,9,8,7,4

#note_freq:
	DATA $01AC
	DATA $0153
	DATA $011D
	DATA $00FE
	DATA $00F0
	DATA $0140
	DATA $00D6
	DATA $00BE
	DATA $00B4
	DATA $00AA
	DATA $00A0
	DATA $00E2
