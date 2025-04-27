	'
	' Viboritas (demo for CVBasic)
	'
	' by Oscar Toledo G.
	' https://nanochess.org/
	'
	' Creation date: Oct/1990.
	' Revision date: Feb/29/2024. Ported to CVBasic.
	' Revision date: Apr/26/2025. Adapted to Sega Master System.
	'

	' The original game was made in Z80 assembler,
	' you can see it here: https://nanochess.org/viboritas.html

	' It is easier to understand in CVBasic ;)

	DEFINE CHAR 128,21,game_bitmaps
	DEFINE SPRITE 0,20,game_sprites

restart_game:
	lives = 2
	level = 1
restart_level:
	
	PRINT AT 684,"Lives: ",lives
	PRINT AT 745,"nanochess 1990"
	
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

		SPRITE 0, y_player - 1, x_player, player_frame
		SPRITE 1, y_player - 1, x_player + 8, player_frame + 2
		SPRITE 2, y_enemy1 - 1, x_enemy1, enemy1_frame
		SPRITE 3, y_enemy1 - 1, x_enemy1 + 8, enemy1_frame + 2
		SPRITE 4, y_enemy2 - 1, x_enemy2, enemy2_frame
		SPRITE 5, y_enemy2 - 1, x_enemy2 + 8, enemy2_frame + 2
		SPRITE 6, y_enemy3 - 1, x_enemy3, enemy3_frame
		SPRITE 7, y_enemy3 - 1, x_enemy3 + 8, enemy3_frame + 2

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
					SOUND 0, 200 - c * 10, 13
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

	SOUND 0,640,13
	SOUND 1,320,13
	SOUND 2,160,13

	player_frame = 0
	FOR c = 0 TO 30
		WAIT
		WAIT
		player_frame = player_frame XOR 8
		SPRITE 0, y_player - 1, x_player, player_frame
		SPRITE 1, y_player - 1, x_player + 8, player_frame + 2
	NEXT c

	GOSUB sound_off

	DO
		WAIT
		SOUND 0,200 - y_player,13
		player_frame = player_frame XOR 8
		SPRITE 0, y_player - 1, x_player, player_frame
		SPRITE 1, y_player - 1, x_player + 8, player_frame + 2
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

	' Get the base character to draw the level.
	base_character = 128 + (level - 1) * 4

	' Draw the background.
	FOR #c = $3800 TO $3cf8 STEP 8
		VPOKE #c, base_character
		VPOKE #c + 2, base_character
		VPOKE #c + 4, base_character
		VPOKE #c + 6, base_character + 1.
	NEXT #c

	' Draw over the floors.
	FOR #c = $3900 TO $3cc0 STEP 320
		FOR #d = #c TO #c + 62 STEP 2
			VPOKE #d, base_character + 2.
		NEXT #d
	NEXT #c

	' Draw the ladders.
	ladders = 6 - level

	FOR #c = $3900 TO $3B80 STEP 320
		FOR d = 1 TO ladders
			e = (RANDOM(28) + 2) * 2
			VPOKE #c + e, base_character + 3.
			VPOKE #c + e + 64, base_character + 3.
			VPOKE #c + e + 128, base_character + 3.
			VPOKE #c + e + 192, base_character + 3.
			VPOKE #c + e + 256, base_character + 3.
		NEXT d
	NEXT #c

	' Draw the "exit".
	VPOKE $3CBC, 148

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
			#c = $3800 + row * 64 + column * 2
			IF VPEEK(#c) = base_character + 3 THEN	' Ladder?
				y_player = y_player - 1
			END IF
		ELSE
			IF FRAME AND 4 THEN player_frame = 16 ELSE player_frame = 20
			y_player = y_player - 1
		END IF
	END IF
	IF cont1.down THEN
		IF y_player % 40 = 16 THEN	' Player aligned on floor.
			column = (x_player + 7) /8
			row = (y_player + 16) / 8
			#c = $3800 + row * 64 + column * 2
			IF VPEEK(#c) = base_character + 3 THEN	' Ladder?
				y_player = y_player + 1
			END IF
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

game_bitmaps:
	BITMAP "CCCCCCCC"
	BITMAP "CCCCCCCC"
	BITMAP "CCCCCCCC"
	BITMAP "CCCCCCCC"
	BITMAP "CCCCCCCC"
	BITMAP "CCCCCCCC"
	BITMAP "CCCCCCCC"
	BITMAP "CCCCCCCC"

	BITMAP "222..222"
	BITMAP "222..222"
	BITMAP "222..222"
	BITMAP "222..222"
	BITMAP "222..222"
	BITMAP "222..222"
	BITMAP "222..222"
	BITMAP "222..222"

	BITMAP "AAAAAAAA"
	BITMAP "AAAAAAAA"
	BITMAP "........"
	BITMAP "AAAAAAAA"
	BITMAP "AAAAAAAA"
	BITMAP "........"
	BITMAP "AAAAAAAA"
	BITMAP "AAAAAAAA"

	BITMAP ".5....5."
	BITMAP ".5....5."
	BITMAP ".555555."
	BITMAP ".5....5."
	BITMAP ".5....5."
	BITMAP ".555555."
	BITMAP ".5....5."
	BITMAP ".5....5."

	BITMAP "55555554"
	BITMAP "54444454"
	BITMAP "54555454"
	BITMAP "54545454"
	BITMAP "54555454"
	BITMAP "54444454"
	BITMAP "55555554"
	BITMAP "44444444"

	BITMAP "5.555.5."
	BITMAP "5.555.5."
	BITMAP "5.555.5."
	BITMAP "5.555.5."
	BITMAP "5.555.5."
	BITMAP "5.555.5."
	BITMAP "5.555.5."
	BITMAP "5.555.5."

	BITMAP "FFF.FFF."
	BITMAP "........"
	BITMAP "EEEEEEEE"
	BITMAP "EEEEEEEE"
	BITMAP "EEEEEEEE"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"

	BITMAP ".5....5."
	BITMAP ".5....5."
	BITMAP ".555555."
	BITMAP ".5....5."
	BITMAP ".5....5."
	BITMAP ".555555."
	BITMAP ".5....5."
	BITMAP ".5....5."

	BITMAP "66686666"
	BITMAP "66686666"
	BITMAP "66686666"
	BITMAP "88888888"
	BITMAP "66666668"
	BITMAP "66666668"
	BITMAP "66666668"
	BITMAP "88888888"

	BITMAP ".888888."
	BITMAP ".888888."
	BITMAP ".888888."
	BITMAP "........"
	BITMAP ".88.888."
	BITMAP ".88.888."
	BITMAP ".88.888."
	BITMAP "........"

	BITMAP "........"
	BITMAP "55555555"
	BITMAP "55555555"
	BITMAP "5.5.5.5."
	BITMAP ".5...5.."
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"

	BITMAP ".5....5."
	BITMAP ".5....5."
	BITMAP ".555555."
	BITMAP ".5....5."
	BITMAP ".5....5."
	BITMAP ".555555."
	BITMAP ".5....5."
	BITMAP ".5....5."

	BITMAP "666.666."
	BITMAP "666.666."
	BITMAP "666.666."
	BITMAP "........"
	BITMAP "666.666."
	BITMAP "666.666."
	BITMAP "666.666."
	BITMAP "........"

	BITMAP ".A......"
	BITMAP "..AA...."
	BITMAP "....AA.."
	BITMAP "......AA"
	BITMAP "....AA.."
	BITMAP "..AA...."
	BITMAP ".A......"
	BITMAP ".A......"

	BITMAP "........"
	BITMAP "FFFFFFFF"
	BITMAP "........"
	BITMAP "5.5.5.5."
	BITMAP ".5.5.5.5"
	BITMAP "........"
	BITMAP "FFFFFFFF"
	BITMAP "........"

	BITMAP "E......E"
	BITMAP "E......E"
	BITMAP "EE....EE"
	BITMAP "E.EEEE.E"
	BITMAP "E......E"
	BITMAP "E......E"
	BITMAP "EE....EE"
	BITMAP "E.EEEE.E"

	BITMAP "86666668"
	BITMAP "68688666"
	BITMAP "66886888"
	BITMAP "68666888"
	BITMAP "66888668"
	BITMAP "66866888"
	BITMAP "68668668"
	BITMAP "66866888"

	BITMAP "C2CCC222"
	BITMAP "C2CC2CC2"
	BITMAP "CC2CC222"
	BITMAP "C2CCCCCC"
	BITMAP "CC2C2CCC"
	BITMAP "CCC2C2C2"
	BITMAP "CCC2CC2C"
	BITMAP "CC2CC222"

	BITMAP "........"
	BITMAP "6666666E"
	BITMAP "6666666E"
	BITMAP "EEEEEEEE"
	BITMAP "666E6666"
	BITMAP "666E6666"
	BITMAP "EEEEEEEE"
	BITMAP "........"

	BITMAP "....CC.."
	BITMAP "....CC.."
	BITMAP "...CC..."
	BITMAP "...CC..."
	BITMAP "..CC...."
	BITMAP "..CC...."
	BITMAP "...CC..."
	BITMAP "...CC..."

	BITMAP ".F.F.F.."
	BITMAP "FFFFFFF."
	BITMAP ".F.F.F.."
	BITMAP "FFFFFFF."
	BITMAP ".F.F.F.."
	BITMAP "FFFFFFF."
	BITMAP ".F.F.F.."
	BITMAP "........"

game_sprites:
	BITMAP ".......1.1.1...."
	BITMAP ".....11A1A1A1..."
	BITMAP "....1A1999991..."
	BITMAP ".....1A999991..."
	BITMAP "....1A9999191..."
	BITMAP ".....1A969991..."
	BITMAP "....1FF966691..."
	BITMAP "..1FFFF19991...."
	BITMAP ".1FF1FFF11111..."
	BITMAP "1FF11FFFF1FFF1.."
	BITMAP "1FFF1FFFF1FFF1.."
	BITMAP "1FFF1F1111111..."
	BITMAP ".11111FFFF111..."
	BITMAP "...1FFF1FF7771.."
	BITMAP "...177711F77771."
	BITMAP "...17777111111.."

	BITMAP "......11A1A1A1.."
	BITMAP ".....1A1999991.."
	BITMAP "......1A999991.."
	BITMAP ".....1A9999191.."
	BITMAP "......19969991.."
	BITMAP ".....1FF966691.."
	BITMAP ".....1FF19991..."
	BITMAP "....1FFFF111...."
	BITMAP "....1FFFFF1....."
	BITMAP "....1FF1FFF1...."
	BITMAP "....1FF1FFF1...."
	BITMAP "....1FFF111....."
	BITMAP ".....1FFFF1....."
	BITMAP ".....1FF1......."
	BITMAP ".....177771....."
	BITMAP ".....1777771...."

	BITMAP "....1.1.1......."
	BITMAP "...1A1A1A11....."
	BITMAP "...1999991A1...."
	BITMAP "...199999A1....."
	BITMAP "...1919999A1...."
	BITMAP "...199969A1....."
	BITMAP "...1966699F1...."
	BITMAP "....19991FFFF1.."
	BITMAP ".....111FFF1FF1."
	BITMAP "..1FFF1FFFF11FF1"
	BITMAP "..1FFF1FFFF1FFF1"
	BITMAP "...111.111F1FFF1"
	BITMAP "...111FFFF11111."
	BITMAP "..1777FF1FFF1..."
	BITMAP ".17777F117771..."
	BITMAP "..11111177771..."

	BITMAP "..1A1A1A11......"
	BITMAP "..1999991A1....."
	BITMAP "..199999A1......"
	BITMAP "..1919999A1....."
	BITMAP "..199969A1......"
	BITMAP "..1966699A1....."
	BITMAP "...19991FF1....."
	BITMAP "....111FFFF1...."
	BITMAP ".....1FFFFF1...."
	BITMAP "....1FFF1FF1...."
	BITMAP "....1FFF1FF1...."
	BITMAP ".....111FFF1...."
	BITMAP ".....1FFFF1....."
	BITMAP "......11FF1....."
	BITMAP ".....177771....."
	BITMAP "....1777771....."

	BITMAP "...1A1A1A1A1...."
	BITMAP "....1AAAAA1....."
	BITMAP "...1AAAAAAA1...."
	BITMAP "...1AAAAAAA1111."
	BITMAP "....1AAAAA11FFF1"
	BITMAP "....1AAAAA11FFF1"
	BITMAP ".....199911FF11."
	BITMAP "...1FF111FFF1..."
	BITMAP ".11FF1FFFF11...."
	BITMAP "1FFF1.1111......"
	BITMAP "1FFF11FFFF1....."
	BITMAP ".111.1F11FF11..."
	BITMAP "....1FF1.17771.."
	BITMAP "...11FF1.177771."
	BITMAP "..177771..1111.."
	BITMAP ".1777771........"

	BITMAP "....1A1A1A1A1..."
	BITMAP ".....1AAAAA1...."
	BITMAP "....1AAAAAAA1..."
	BITMAP ".1111AAAAAAA1..."
	BITMAP "1FFF11AAAAA1...."
	BITMAP "1FFF11AAAAA1...."
	BITMAP ".11FF1199911...."
	BITMAP "...1FFF111FF1..."
	BITMAP "....11FFFF1FF11."
	BITMAP "......1111.1FFF1"
	BITMAP ".....1FFFF11FFF1"
	BITMAP "...11FF11F1.111."
	BITMAP "..17771.1FF1...."
	BITMAP ".17771..1FF11..."
	BITMAP "..111...177771.."
	BITMAP "........1777771."

	BITMAP "..1331321......."
	BITMAP ".13F33F21......."
	BITMAP ".13F33F21......."
	BITMAP ".1331321........"
	BITMAP ".11333321......."
	BITMAP "1633331321......"
	BITMAP "6113313321....1."
	BITMAP "...1113321...131"
	BITMAP "...133321....131"
	BITMAP "..1333321...1321"
	BITMAP ".1333321....1321"
	BITMAP ".133321.11.13321"
	BITMAP ".13332113311321."
	BITMAP ".13333333331321."
	BITMAP "..1333333333321."
	BITMAP "...12222112221.."

	BITMAP "....11.11......."
	BITMAP "...1331321......"
	BITMAP "..13F33F21......"
	BITMAP "..13F33F21......"
	BITMAP "..1331321......."
	BITMAP "...1333321......"
	BITMAP ".1133331321....."
	BITMAP "16133313321....."
	BITMAP "16611113321..1.."
	BITMAP ".111333321..131."
	BITMAP "..13333211.1321."
	BITMAP "..13332132.1321."
	BITMAP "..133321321321.."
	BITMAP "..133333333321.."
	BITMAP "...13333313321.."
	BITMAP "....122211221..."

	BITMAP ".......1231331.."
	BITMAP ".......12F33F31."
	BITMAP ".......12F33F31."
	BITMAP "........1231331."
	BITMAP ".......12333311."
	BITMAP "......1231333361"
	BITMAP ".1....1233133116"
	BITMAP "131...1233111..."
	BITMAP "131....123331..."
	BITMAP "1231...1233331.."
	BITMAP "1231....1233331."
	BITMAP "12331.11.123331."
	BITMAP ".12311331123331."
	BITMAP ".12313333333331."
	BITMAP ".1233333333331.."
	BITMAP "..12221122221..."

	BITMAP ".......11.11...."
	BITMAP "......1231331..."
	BITMAP "......12F33F31.."
	BITMAP "......12F33F31.."
	BITMAP ".......1231331.."
	BITMAP "......1233331..."
	BITMAP ".....123133331.."
	BITMAP ".....12331333161"
	BITMAP "..1..12331111661"
	BITMAP ".131..1233331..."
	BITMAP ".1231.11233331.."
	BITMAP ".1231133123331.."
	BITMAP "..123133123331.."
	BITMAP "..123333333331.."
	BITMAP "..12331333331..."
	BITMAP "...122112221...."

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
		SOUND 0, #note_freq(note - 1)
	END IF
	SOUND 0, , volume_effect(tick_note)
	END

sound_off:	PROCEDURE
	SOUND 0,,0
	SOUND 1,,0
	SOUND 2,,0
	SOUND 3,,0
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
