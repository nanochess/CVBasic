	'
	' Viboritas (demo for CVBasic)
	'
	' by Oscar Toledo G.
	' https://nanochess.org/
	'
	' Creation date: Oct/1990.
	' Revision date: Feb/29/2024. Ported to CVBasic.
	'

	' The original game was made in Z80 assembler,
	' you can see it here: https://nanochess.org/viboritas.html

	' It is easier to understand in CVBasic ;)

	DEFINE CHAR 128,21,game_bitmaps
	DEFINE COLOR 128,21,game_colors
	DEFINE SPRITE 0,10,game_sprites

restart_game:
	lives = 2
	level = 1
restart_level:
	WAIT
	
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

		SPRITE 0, y_player - 1, x_player, player_frame, 15
		SPRITE 1, y_enemy1 - 1, x_enemy1, enemy1_frame, 14
		SPRITE 2, y_enemy2 - 1, x_enemy2, enemy2_frame, 14
		SPRITE 3, y_enemy3 - 1, x_enemy3, enemy3_frame, 14

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
		SPRITE 0, y_player - 1, x_player, player_frame, 15
	NEXT c

	GOSUB sound_off

	DO
		WAIT
		SOUND 0,200 - y_player,13
		player_frame = player_frame XOR 8
		SPRITE 0, y_player - 1, x_player, player_frame, 15
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
	FOR #c = $1800 TO $1a7c STEP 4
		VPOKE #c, base_character
		VPOKE #c + 1, base_character
		VPOKE #c + 2, base_character
		VPOKE #c + 3, base_character + 1.
	NEXT #c

	' Draw over the floors.
	FOR #c = $1880 TO $1A60 STEP 160
		FOR #d = #c TO #c + 31
			VPOKE #d, base_character + 2.
		NEXT #d
	NEXT #c

	' Draw the ladders.
	ladders = 6 - level

	FOR #c = $1880 TO $19C0 STEP 160
		FOR d = 1 TO ladders
			e = RANDOM(28) + 2
			VPOKE #c + e, base_character + 3.
			VPOKE #c + e + 32, base_character + 3.
			VPOKE #c + e + 64, base_character + 3.
			VPOKE #c + e + 96, base_character + 3.
			VPOKE #c + e + 128, base_character + 3.
		NEXT d
	NEXT #c

	' Draw the "exit".
	VPOKE $1A5E, 148

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
			#c = $1800 + row * 32 + column
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
			#c = $1800 + row * 32 + column
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
	BITMAP "XXXXXXXX"
	BITMAP "XXXXXXXX"
	BITMAP "XXXXXXXX"
	BITMAP "XXXXXXXX"
	BITMAP "XXXXXXXX"
	BITMAP "XXXXXXXX"
	BITMAP "XXXXXXXX"
	BITMAP "XXXXXXXX"

	BITMAP "XXX..XXX"
	BITMAP "XXX..XXX"
	BITMAP "XXX..XXX"
	BITMAP "XXX..XXX"
	BITMAP "XXX..XXX"
	BITMAP "XXX..XXX"
	BITMAP "XXX..XXX"
	BITMAP "XXX..XXX"

	BITMAP "XXXXXXXX"
	BITMAP "XXXXXXXX"
	BITMAP "........"
	BITMAP "XXXXXXXX"
	BITMAP "XXXXXXXX"
	BITMAP "........"
	BITMAP "XXXXXXXX"
	BITMAP "XXXXXXXX"

	BITMAP ".X....X."
	BITMAP ".X....X."
	BITMAP ".XXXXXX."
	BITMAP ".X....X."
	BITMAP ".X....X."
	BITMAP ".XXXXXX."
	BITMAP ".X....X."
	BITMAP ".X....X."

	BITMAP "XXXXXXX."
	BITMAP "X.....X."
	BITMAP "X.XXX.X."
	BITMAP "X.X.X.X."
	BITMAP "X.XXX.X."
	BITMAP "X.....X."
	BITMAP "XXXXXXX."
	BITMAP "........"

	BITMAP "X.XXX.X."
	BITMAP "X.XXX.X."
	BITMAP "X.XXX.X."
	BITMAP "X.XXX.X."
	BITMAP "X.XXX.X."
	BITMAP "X.XXX.X."
	BITMAP "X.XXX.X."
	BITMAP "X.XXX.X."

	BITMAP "XXX.XXX."
	BITMAP "........"
	BITMAP "XXXXXXXX"
	BITMAP "XXXXXXXX"
	BITMAP "XXXXXXXX"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"

	BITMAP ".X....X."
	BITMAP ".X....X."
	BITMAP ".XXXXXX."
	BITMAP ".X....X."
	BITMAP ".X....X."
	BITMAP ".XXXXXX."
	BITMAP ".X....X."
	BITMAP ".X....X."

	BITMAP "XXX.XXXX"
	BITMAP "XXX.XXXX"
	BITMAP "XXX.XXXX"
	BITMAP "........"
	BITMAP "XXXXXXX."
	BITMAP "XXXXXXX."
	BITMAP "XXXXXXX."
	BITMAP "........"

	BITMAP ".XXXXXX."
	BITMAP ".XXXXXX."
	BITMAP ".XXXXXX."
	BITMAP "........"
	BITMAP ".XX.XXX."
	BITMAP ".XX.XXX."
	BITMAP ".XX.XXX."
	BITMAP "........"

	BITMAP "........"
	BITMAP "XXXXXXXX"
	BITMAP "XXXXXXXX"
	BITMAP "X.X.X.X."
	BITMAP ".X...X.."
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"

	BITMAP ".X....X."
	BITMAP ".X....X."
	BITMAP ".XXXXXX."
	BITMAP ".X....X."
	BITMAP ".X....X."
	BITMAP ".XXXXXX."
	BITMAP ".X....X."
	BITMAP ".X....X."

	BITMAP "XXX.XXX."
	BITMAP "XXX.XXX."
	BITMAP "XXX.XXX."
	BITMAP "........"
	BITMAP "XXX.XXX."
	BITMAP "XXX.XXX."
	BITMAP "XXX.XXX."
	BITMAP "........"

	BITMAP ".X......"
	BITMAP "..XX...."
	BITMAP "....XX.."
	BITMAP "......XX"
	BITMAP "....XX.."
	BITMAP "..XX...."
	BITMAP ".X......"
	BITMAP ".X......"

	BITMAP "........"
	BITMAP "XXXXXXXX"
	BITMAP "........"
	BITMAP "X.X.X.X."
	BITMAP ".X.X.X.X"
	BITMAP "........"
	BITMAP "XXXXXXXX"
	BITMAP "........"

	BITMAP "X......X"
	BITMAP "X......X"
	BITMAP "XX....XX"
	BITMAP "X.XXXX.X"
	BITMAP "X......X"
	BITMAP "X......X"
	BITMAP "XX....XX"
	BITMAP "X.XXXX.X"

	BITMAP "X......X"
	BITMAP ".X.XX..."
	BITMAP "..XX.XXX"
	BITMAP ".X...XXX"
	BITMAP "..XXX..X"
	BITMAP "..X..XXX"
	BITMAP ".X..X..X"
	BITMAP "..X..XXX"

	BITMAP ".X...XXX"
	BITMAP ".X..X..X"
	BITMAP "..X..XXX"
	BITMAP ".X......"
	BITMAP "..X.X..."
	BITMAP "...X.X.X"
	BITMAP "...X..X."
	BITMAP "..X..XXX"

	BITMAP "........"
	BITMAP "XXXXXXX."
	BITMAP "XXXXXXX."
	BITMAP "........"
	BITMAP "XXX.XXXX"
	BITMAP "XXX.XXXX"
	BITMAP "........"
	BITMAP "........"

	BITMAP "....XX.."
	BITMAP "....XX.."
	BITMAP "...XX..."
	BITMAP "...XX..."
	BITMAP "..XX...."
	BITMAP "..XX...."
	BITMAP "...XX..."
	BITMAP "...XX..."

	BITMAP ".X.X.X.."
	BITMAP "XXXXXXX."
	BITMAP ".X.X.X.."
	BITMAP "XXXXXXX."
	BITMAP ".X.X.X.."
	BITMAP "XXXXXXX."
	BITMAP ".X.X.X.."
	BITMAP "........"

game_colors:
	DATA BYTE $CC,$CC,$CC,$CC,$CC,$CC,$CC,$CC
	DATA BYTE $21,$21,$21,$21,$21,$21,$21,$21
	DATA BYTE $A1,$A1,$A1,$A1,$A1,$A1,$A1,$A1
	DATA BYTE $51,$51,$51,$51,$51,$51,$51,$51

	DATA BYTE $54,$54,$54,$54,$54,$54,$54,$54
	DATA BYTE $51,$51,$51,$51,$51,$51,$51,$51
	DATA BYTE $F1,$11,$E1,$E1,$E1,$11,$11,$11
	DATA BYTE $51,$51,$51,$51,$51,$51,$51,$51

	DATA BYTE $68,$68,$68,$68,$68,$68,$68,$68
	DATA BYTE $81,$81,$81,$81,$81,$81,$81,$81
	DATA BYTE $51,$51,$51,$51,$51,$51,$51,$51
	DATA BYTE $51,$51,$51,$51,$51,$51,$51,$51

	DATA BYTE $61,$61,$61,$61,$61,$61,$61,$61
	DATA BYTE $A1,$A1,$A1,$A1,$A1,$A1,$A1,$A1
	DATA BYTE $F1,$F1,$F1,$51,$51,$F1,$F1,$F1
	DATA BYTE $E1,$E1,$E1,$E1,$E1,$E1,$E1,$E1

	DATA BYTE $86,$86,$86,$86,$86,$86,$86,$86
	DATA BYTE $2C,$2C,$2C,$2C,$2C,$2C,$2C,$2C
	DATA BYTE $11,$6E,$6E,$6E,$6E,$6E,$6E,$11
	DATA BYTE $C1,$C1,$C1,$C1,$C1,$C1,$C1,$C1

	DATA BYTE $F1,$F1,$F1,$F1,$F1,$F1,$F1,$F1

game_sprites:
	BITMAP "................"
	BITMAP ".......X.X.X...."
	BITMAP ".....X.XXXXX...."
	BITMAP "......XXXXXX...."
	BITMAP ".....XXXXX.X...."
	BITMAP "......XX.XXX...."
	BITMAP ".....XXX...X...."
	BITMAP "...XXXX.XXX....."
	BITMAP "..XX.XXX........"
	BITMAP ".XX..XXXX.XXX..."
	BITMAP ".XXX.XXXX.XXX..."
	BITMAP ".XXX.X.........."
	BITMAP "......XXXX......"
	BITMAP "....XXX.XXXXX..."
	BITMAP "....XXX..XXXXX.."
	BITMAP "....XXXX........"

	BITMAP "........X.X.X..."
	BITMAP "......X.XXXXX..."
	BITMAP ".......XXXXXX..."
	BITMAP "......XXXXX.X..."
	BITMAP ".......XX.XXX..."
	BITMAP "......XXX...X..."
	BITMAP "......XX.XXX...."
	BITMAP ".....XXXX......."
	BITMAP ".....XXXXX......"
	BITMAP ".....XX.XXX....."
	BITMAP ".....XX.XXX....."
	BITMAP ".....XXX........"
	BITMAP "......XXXX......"
	BITMAP "......XX........"
	BITMAP "......XXXX......"
	BITMAP "......XXXXX....."

	BITMAP "................"
	BITMAP "....X.X.X......."
	BITMAP "....XXXXX.X....."
	BITMAP "....XXXXXX......"
	BITMAP "....X.XXXXX....."
	BITMAP "....XXX.XX......"
	BITMAP "....X...XXX....."
	BITMAP ".....XXX.XXXX..."
	BITMAP "........XXX.XX.."
	BITMAP "...XXX.XXXX..XX."
	BITMAP "...XXX.XXXX.XXX."
	BITMAP "..........X.XXX."
	BITMAP "......XXXX......"
	BITMAP "...XXXXX.XXX...."
	BITMAP "..XXXXX..XXX...."
	BITMAP "........XXXX...."

	BITMAP "...X.X.X........"
	BITMAP "...XXXXX.X......"
	BITMAP "...XXXXXX......."
	BITMAP "...X.XXXXX......"
	BITMAP "...XXX.XX......."
	BITMAP "...X...XXX......"
	BITMAP "....XXX.XX......"
	BITMAP ".......XXXX....."
	BITMAP "......XXXXX....."
	BITMAP ".....XXX.XX....."
	BITMAP ".....XXX.XX....."
	BITMAP "........XXX....."
	BITMAP "......XXXX......"
	BITMAP "........XX......"
	BITMAP "......XXXX......"
	BITMAP ".....XXXXX......"

	BITMAP "....X.X.X.X....."
	BITMAP ".....XXXXX......"
	BITMAP "....XXXXXXX....."
	BITMAP "....XXXXXXX....."
	BITMAP ".....XXXXX..XXX."
	BITMAP ".....XXXXX..XXX."
	BITMAP "......XXX..XX..."
	BITMAP "....XX...XXX...."
	BITMAP "...XX.XXXX......"
	BITMAP ".XXX............"
	BITMAP ".XXX..XXXX......"
	BITMAP "......X..XX....."
	BITMAP ".....XX...XXX..."
	BITMAP ".....XX...XXXX.."
	BITMAP "...XXXX........."
	BITMAP "..XXXXX........."


	BITMAP ".....X.X.X.X...."
	BITMAP "......XXXXX....."
	BITMAP ".....XXXXXXX...."
	BITMAP ".....XXXXXXX...."
	BITMAP ".XXX..XXXXX....."
	BITMAP ".XXX..XXXXX....."
	BITMAP "...XX..XXX......"
	BITMAP "....XXX...XX...."
	BITMAP "......XXXX.XX..."
	BITMAP "............XXX."
	BITMAP "......XXXX..XXX."
	BITMAP ".....XX..X......"
	BITMAP "...XXX...XX....."
	BITMAP "..XXX....XX....."
	BITMAP ".........XXXX..."
	BITMAP ".........XXXXX.."

	BITMAP "...XX.XX........"
	BITMAP "..X.XX.X........"
	BITMAP "..X.XX.X........"
	BITMAP "..XX.XX........."
	BITMAP "...XXXXX........"
	BITMAP ".XXXXX.XX......."
	BITMAP "X..XX.XXX......."
	BITMAP "......XXX.....X."
	BITMAP "....XXXX......X."
	BITMAP "...XXXXX.....XX."
	BITMAP "..XXXXX......XX."
	BITMAP "..XXXX......XXX."
	BITMAP "..XXXX..XX..XX.."
	BITMAP "..XXXXXXXXX.XX.."
	BITMAP "...XXXXXXXXXXX.."
	BITMAP "....XXXX..XXX..."

	BITMAP "................"
	BITMAP "....XX.XX......."
	BITMAP "...X.XX.X......."
	BITMAP "...X.XX.X......."
	BITMAP "...XX.XX........"
	BITMAP "....XXXXX......."
	BITMAP "...XXXX.XX......"
	BITMAP ".X.XXX.XXX......"
	BITMAP ".XX....XXX......"
	BITMAP "....XXXXX....X.."
	BITMAP "...XXXXX....XX.."
	BITMAP "...XXXX.XX..XX.."
	BITMAP "...XXXX.XX.XX..."
	BITMAP "...XXXXXXXXXX..."
	BITMAP "....XXXXX.XXX..."
	BITMAP ".....XXX..XX...."

	BITMAP "........XX.XX..."
	BITMAP "........X.XX.X.."
	BITMAP "........X.XX.X.."
	BITMAP ".........XX.XX.."
	BITMAP "........XXXXX..."
	BITMAP ".......XX.XXXXX."
	BITMAP ".......XXX.XX..X"
	BITMAP ".X.....XXX......"
	BITMAP ".X......XXXX...."
	BITMAP ".XX.....XXXXX..."
	BITMAP ".XX......XXXXX.."
	BITMAP ".XXX......XXXX.."
	BITMAP "..XX..XX..XXXX.."
	BITMAP "..XX.XXXXXXXXX.."
	BITMAP "..XXXXXXXXXXX..."
	BITMAP "...XXX..XXXX...."

	BITMAP "................"
	BITMAP ".......XX.XX...."
	BITMAP ".......X.XX.X..."
	BITMAP ".......X.XX.X..."
	BITMAP "........XX.XX..."
	BITMAP ".......XXXXX...."
	BITMAP "......XX.XXXX..."
	BITMAP "......XXX.XXX.X."
	BITMAP "......XXX....XX."
	BITMAP "..X....XXXXX...."
	BITMAP "..XX....XXXXX..."
	BITMAP "..XX..XX.XXXX..."
	BITMAP "...XX.XX.XXXX..."
	BITMAP "...XXXXXXXXXX..."
	BITMAP "...XXX.XXXXX...."
	BITMAP "....XX..XXX....."

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
