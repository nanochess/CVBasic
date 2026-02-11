	'
	' Viboritas (demo for CVBasic)
	'
	' by Oscar Toledo G.
	' https://nanochess.org/
	'
	' Creation date: Oct/1990.
	' Revision date: Feb/29/2024. Ported to CVBasic.
	' Revision date: Feb/10/2026. Adapted to MSX2.
	'

	' The original game was made in Z80 assembler,
	' you can see it here: https://nanochess.org/viboritas.html

	' It is easier to understand in CVBasic ;)

	MODE 4
	SCREEN DISABLE
	PALETTE LOAD game_palette
	FOR c = 32 TO 127
		DEFINE COLOR c,1,letter_colors
	NEXT c
	SCREEN ENABLE
	DEFINE CHAR 128,21,game_bitmaps
	DEFINE COLOR 128,21,game_colors
	DEFINE SPRITE 0,20,game_sprites
	DEFINE SPRITE COLOR 0,2,VARPTR sprites_color(0)
	DEFINE SPRITE COLOR 2,2,VARPTR sprites_color(32)
	DEFINE SPRITE COLOR 4,2,VARPTR sprites_color(32)
	DEFINE SPRITE COLOR 6,2,VARPTR sprites_color(32)

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

		SPRITE 0, y_player - 1, x_player, player_frame * 2
		SPRITE 1, y_player - 1, x_player, player_frame * 2 + 4
		SPRITE 2, y_enemy1 - 1, x_enemy1, enemy1_frame * 2
		SPRITE 3, y_enemy1 - 1, x_enemy1, enemy1_frame * 2 + 4
		SPRITE 4, y_enemy2 - 1, x_enemy2, enemy2_frame * 2
		SPRITE 5, y_enemy2 - 1, x_enemy2, enemy2_frame * 2 + 4
		SPRITE 6, y_enemy3 - 1, x_enemy3, enemy3_frame * 2
		SPRITE 7, y_enemy3 - 1, x_enemy3, enemy3_frame * 2 + 4

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
					SOUND 5, 200 - c * 10, 13
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

	SOUND 5,640,13
	SOUND 6,320,13
	SOUND 7,160,13

	player_frame = 0
	FOR c = 0 TO 30
		WAIT
		WAIT
		player_frame = player_frame XOR 8
		SPRITE 0, y_player - 1, x_player, player_frame * 2
		SPRITE 1, y_player - 1, x_player, player_frame * 2 + 4
	NEXT c

	GOSUB sound_off

	DO
		WAIT
		SOUND 5,200 - y_player,13
		player_frame = player_frame XOR 8
		SPRITE 0, y_player - 1, x_player, player_frame * 2
		SPRITE 1, y_player - 1, x_player, player_frame * 2 + 4
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
	DATA BYTE $71,$11,$B1,$B1,$B1,$11,$11,$11
	DATA BYTE $51,$51,$51,$51,$51,$51,$51,$51

	DATA BYTE $38,$38,$38,$38,$38,$38,$38,$38
	DATA BYTE $81,$81,$81,$81,$81,$81,$81,$81
	DATA BYTE $51,$51,$51,$51,$51,$51,$51,$51
	DATA BYTE $51,$51,$51,$51,$51,$51,$51,$51

	DATA BYTE $31,$31,$31,$31,$31,$31,$31,$31
	DATA BYTE $A1,$A1,$A1,$A1,$A1,$A1,$A1,$A1
	DATA BYTE $71,$71,$71,$51,$51,$71,$71,$71
	DATA BYTE $B1,$B1,$B1,$B1,$B1,$B1,$B1,$B1

	DATA BYTE $83,$83,$83,$83,$83,$83,$83,$83
	DATA BYTE $2C,$2C,$2C,$2C,$2C,$2C,$2C,$2C
	DATA BYTE $11,$3B,$3B,$3B,$3B,$3B,$3B,$11
	DATA BYTE $C1,$C1,$C1,$C1,$C1,$C1,$C1,$C1

	DATA BYTE $71,$71,$71,$71,$71,$71,$71,$71

letter_colors:
	DATA BYTE $71,$71,$71,$71,$71,$71,$71,$71

game_palette:
	DATA $0000	' 0
	DATA $0000	' 1
	DATA $0700	' 2 Green
	DATA $0250	' 3 Red
	DATA $0057	' 4 Blue
	DATA $0427	' 5 Light blue
	DATA $0507	' 6 Player suit
	DATA $0777	' 7 White
	DATA $0371	' 8 Light red
	DATA $0464	' 9 Player face
	DATA $0570	' 10 Yellow
	DATA $0555	' 11 Gray
	DATA $0400	' 12 Dark green
	DATA $0777	' 13 Snake tongue
	DATA $0600	' 14 Snake body
	DATA $0000	' 15 Black border for sprites

game_sprites:
	BITMAP ".......X.X.X...."
	BITMAP ".....XXXXX.XX..."
	BITMAP "....XXX.....X..."
	BITMAP ".....XX.....X..."
	BITMAP "....XX....X.X..."
	BITMAP ".....XX.X...X..."
	BITMAP "....XXX.XXX.X..."
	BITMAP "..XXXXXX...X...."
	BITMAP ".XXXXXXXXXXXX..."
	BITMAP "XXXXXXXXXXXXXX.."
	BITMAP "XXXXXXXXXXXXXX.."
	BITMAP "XXXXXXXXXXXXX..."
	BITMAP ".XXXXXXXXXXXX..."
	BITMAP "...XXXXXXXXXXX.."
	BITMAP "...XXXXXXXXXXXX."
	BITMAP "...XXXXXXXXXXX.."

	BITMAP ".......X.X.X...."
	BITMAP ".....XXXXXXXX..."
	BITMAP "....XXXXXXXXX..."
	BITMAP ".....XXXXXXXX..."
	BITMAP "....XXXXXXXXX..."
	BITMAP ".....XXXXXXXX..."
	BITMAP "....X..XXXXXX..."
	BITMAP "..X....XXXXX...."
	BITMAP ".X..X...XXXXX..."
	BITMAP "X..XX....X...X.."
	BITMAP "X...X....X...X.."
	BITMAP "X...X.XXXXXXX..."
	BITMAP ".XXXXX....XXX..."
	BITMAP "...X...X.....X.."
	BITMAP "...X...XX.....X."
	BITMAP "...X....XXXXXX.."

	BITMAP "......XXXXXXXX.."
	BITMAP ".....XXX.....X.."
	BITMAP "......XX.....X.."
	BITMAP ".....XX....X.X.."
	BITMAP "......X..X...X.."
	BITMAP ".....XXX.XXX.X.."
	BITMAP ".....XXXX...X..."
	BITMAP "....XXXXXXXX...."
	BITMAP "....XXXXXXX....."
	BITMAP "....XXXXXXXX...."
	BITMAP "....XXXXXXXX...."
	BITMAP "....XXXXXXX....."
	BITMAP ".....XXXXXX....."
	BITMAP ".....XXXX......."
	BITMAP ".....XXXXXX....."
	BITMAP ".....XXXXXXX...."

	BITMAP "......XXXXXXXX.."
	BITMAP ".....XXXXXXXXX.."
	BITMAP "......XXXXXXXX.."
	BITMAP ".....XXXXXXXXX.."
	BITMAP "......XXXXXXXX.."
	BITMAP ".....X..XXXXXX.."
	BITMAP ".....X..XXXXX..."
	BITMAP "....X....XXX...."
	BITMAP "....X.....X....."
	BITMAP "....X..X...X...."
	BITMAP "....X..X...X...."
	BITMAP "....X...XXX....."
	BITMAP ".....X....X....."
	BITMAP ".....X..X......."
	BITMAP ".....X....X....."
	BITMAP ".....X.....X...."

	BITMAP "....X.X.X......."
	BITMAP "...XXXXXXXX....."
	BITMAP "...X.....XXX...."
	BITMAP "...X.....XX....."
	BITMAP "...X.X....XX...."
	BITMAP "...X...X.XX....."
	BITMAP "...X.XXX..XX...."
	BITMAP "....X...XXXXXX.."
	BITMAP ".....XXXXXXXXXX."
	BITMAP "..XXXXXXXXXXXXXX"
	BITMAP "..XXXXXXXXXXXXXX"
	BITMAP "...XXX.XXXXXXXXX"
	BITMAP "...XXXXXXXXXXXX."
	BITMAP "..XXXXXXXXXXX..."
	BITMAP ".XXXXXXXXXXXX..."
	BITMAP "..XXXXXXXXXXX..."

	BITMAP "....X.X.X......."
	BITMAP "...XXXXXXXX....."
	BITMAP "...XXXXXXXXX...."
	BITMAP "...XXXXXXXX....."
	BITMAP "...XXXXXXXXX...."
	BITMAP "...XXXXXXXX....."
	BITMAP "...XXXXXXX.X...."
	BITMAP "....XXXXX....X.."
	BITMAP ".....XXX...X..X."
	BITMAP "..X...X....XX..X"
	BITMAP "..X...X....X...X"
	BITMAP "...XXX.XXX.X...X"
	BITMAP "...XXX....XXXXX."
	BITMAP "..X.....X...X..."
	BITMAP ".X.....XX...X..."
	BITMAP "..XXXXXX....X..."

	BITMAP "..XXXXXXXX......"
	BITMAP "..X.....XXX....."
	BITMAP "..X.....XX......"
	BITMAP "..X.X....XX....."
	BITMAP "..X...X.XX......"
	BITMAP "..X.XXX..XX....."
	BITMAP "...X...XXXX....."
	BITMAP "....XXXXXXXX...."
	BITMAP ".....XXXXXXX...."
	BITMAP "....XXXXXXXX...."
	BITMAP "....XXXXXXXX...."
	BITMAP ".....XXXXXXX...."
	BITMAP ".....XXXXXX....."
	BITMAP "......XXXXX....."
	BITMAP ".....XXXXXX....."
	BITMAP "....XXXXXXX....."

	BITMAP "..XXXXXXXX......"
	BITMAP "..XXXXXXXXX....."
	BITMAP "..XXXXXXXX......"
	BITMAP "..XXXXXXXXX....."
	BITMAP "..XXXXXXXX......"
	BITMAP "..XXXXXXXXX....."
	BITMAP "...XXXXX..X....."
	BITMAP "....XXX....X...."
	BITMAP ".....X.....X...."
	BITMAP "....X...X..X...."
	BITMAP "....X...X..X...."
	BITMAP ".....XXX...X...."
	BITMAP ".....X....X....."
	BITMAP "......XX..X....."
	BITMAP ".....X....X....."
	BITMAP "....X.....X....."

	BITMAP "...XXXXXXXXX...."
	BITMAP "....XXXXXXX....."
	BITMAP "...XXXXXXXXX...."
	BITMAP "...XXXXXXXXXXXX."
	BITMAP "....XXXXXXXXXXXX"
	BITMAP "....XXXXXXXXXXXX"
	BITMAP ".....X...XXXXXX."
	BITMAP "...XXXXXXXXXX..."
	BITMAP ".XXXXXXXXXXX...."
	BITMAP "XXXXX.XXXX......"
	BITMAP "XXXXXXXXXXX....."
	BITMAP ".XXX.XXXXXXXX..."
	BITMAP "....XXXX.XXXXX.."
	BITMAP "...XXXXX.XXXXXX."
	BITMAP "..XXXXXX..XXXX.."
	BITMAP ".XXXXXXX........"

	BITMAP "...XXXXXXXXX...."
	BITMAP "....XXXXXXX....."
	BITMAP "...XXXXXXXXX...."
	BITMAP "...XXXXXXXXXXXX."
	BITMAP "....XXXXXXXX...X"
	BITMAP "....XXXXXXXX...X"
	BITMAP ".....XXXXXX..XX."
	BITMAP "...X..XXX...X..."
	BITMAP ".XX..X....XX...."
	BITMAP "X...X.XXXX......"
	BITMAP "X...XX....X....."
	BITMAP ".XXX.X.XX..XX..."
	BITMAP "....X..X.X...X.."
	BITMAP "...XX..X.X....X."
	BITMAP "..X....X..XXXX.."
	BITMAP ".X.....X........"

	BITMAP "....XXXXXXXXX..."
	BITMAP ".....XXXXXXX...."
	BITMAP "....XXXXXXXXX..."
	BITMAP ".XXXXXXXXXXXX..."
	BITMAP "XXXXXXXXXXXX...."
	BITMAP "XXXXXXXXXXXX...."
	BITMAP ".XXXXXX...XX...."
	BITMAP "...XXXXXXXXXX..."
	BITMAP "....XXXXXXXXXXX."
	BITMAP "......XXXX.XXXXX"
	BITMAP ".....XXXXXXXXXXX"
	BITMAP "...XXXXXXXX.XXX."
	BITMAP "..XXXXX.XXXX...."
	BITMAP ".XXXXX..XXXXX..."
	BITMAP "..XXX...XXXXXX.."
	BITMAP "........XXXXXXX."

	BITMAP "....XXXXXXXXX..."
	BITMAP ".....XXXXXXX...."
	BITMAP "....XXXXXXXXX..."
	BITMAP ".XXXXXXXXXXXX..."
	BITMAP "X...XXXXXXXX...."
	BITMAP "X...XXXXXXXX...."
	BITMAP ".XX..XXXXXXX...."
	BITMAP "...X...XXX..X..."
	BITMAP "....XX....X..XX."
	BITMAP "......XXXX.X...X"
	BITMAP ".....X....XX...X"
	BITMAP "...XX..XX.X.XXX."
	BITMAP "..X...X.X..X...."
	BITMAP ".X...X..X..XX..."
	BITMAP "..XXX...X....X.."
	BITMAP "........X.....X."

	BITMAP "..X..X.XX......."
	BITMAP ".X.X..XXX......."
	BITMAP ".X.X..XXX......."
	BITMAP ".X..X.XX........"
	BITMAP ".XX....XX......."
	BITMAP "XX....X.XX......"
	BITMAP "XXX..X..XX....X."
	BITMAP "...XXX..XX...X.X"
	BITMAP "...X...XX....X.X"
	BITMAP "..X....XX...X.XX"
	BITMAP ".X....XX....X.XX"
	BITMAP ".X...XX.XX.X..XX"
	BITMAP ".X...XXX..XX.XX."
	BITMAP ".X.........X.XX."
	BITMAP "..X..........XX."
	BITMAP "...XXXXXXXXXXX.."

	BITMAP "..XXXXXXX......."
	BITMAP ".XX.XX.XX......."
	BITMAP ".XX.XX.XX......."
	BITMAP ".XXXXXXX........"
	BITMAP ".XXXXXXXX......."
	BITMAP "X.XXXXXXXX......"
	BITMAP ".XXXXXXXXX....X."
	BITMAP "...XXXXXXX...XXX"
	BITMAP "...XXXXXX....XXX"
	BITMAP "..XXXXXXX...XXXX"
	BITMAP ".XXXXXXX....XXXX"
	BITMAP ".XXXXXX.XX.XXXXX"
	BITMAP ".XXXXXXXXXXXXXX."
	BITMAP ".XXXXXXXXXXXXXX."
	BITMAP "..XXXXXXXXXXXXX."
	BITMAP "...XXXXXXXXXXX.."

	BITMAP "....XX.XX......."
	BITMAP "...X..X.XX......"
	BITMAP "..X.X..XXX......"
	BITMAP "..X.X..XXX......"
	BITMAP "..X..X.XX......."
	BITMAP "...X....XX......"
	BITMAP ".XX....X.XX....."
	BITMAP "XXX...X..XX....."
	BITMAP "XXXXXXX..XX..X.."
	BITMAP ".XXX....XX..X.X."
	BITMAP "..X....XXX.X.XX."
	BITMAP "..X...XX.X.X.XX."
	BITMAP "..X...XX.XX.XX.."
	BITMAP "..X.........XX.."
	BITMAP "...X.....X..XX.."
	BITMAP "....XXXXXXXXX..."

	BITMAP "....XX.XX......."
	BITMAP "...XXXXXXX......"
	BITMAP "..XX.XX.XX......"
	BITMAP "..XX.XX.XX......"
	BITMAP "..XXXXXXX......."
	BITMAP "...XXXXXXX......"
	BITMAP ".XXXXXXXXXX....."
	BITMAP "X.XXXXXXXXX....."
	BITMAP "X..XXXXXXXX..X.."
	BITMAP ".XXXXXXXXX..XXX."
	BITMAP "..XXXXXXXX.XXXX."
	BITMAP "..XXXXXXXX.XXXX."
	BITMAP "..XXXXXXXXXXXX.."
	BITMAP "..XXXXXXXXXXXX.."
	BITMAP "...XXXXXXXXXXX.."
	BITMAP "....XXXXXXXXX..."

	BITMAP ".......XX.X..X.."
	BITMAP ".......XXX..X.X."
	BITMAP ".......XXX..X.X."
	BITMAP "........XX.X..X."
	BITMAP ".......XX....XX."
	BITMAP "......XX.X....XX"
	BITMAP ".X....XX..X..XXX"
	BITMAP "X.X...XX..XXX..."
	BITMAP "X.X....XX...X..."
	BITMAP "XX.X...XX....X.."
	BITMAP "XX.X....XX....X."
	BITMAP "XX..X.XX.XX...X."
	BITMAP ".XX.XX..XXX...X."
	BITMAP ".XX.X.........X."
	BITMAP ".XX..........X.."
	BITMAP "..XXXXXXXXXXX..."

	BITMAP ".......XXXXXXX.."
	BITMAP ".......XX.XX.XX."
	BITMAP ".......XX.XX.XX."
	BITMAP "........XXXXXXX."
	BITMAP ".......XXXXXXXX."
	BITMAP "......XXXXXXXX.X"
	BITMAP ".X....XXXXXXXXX."
	BITMAP "XXX...XXXXXXX..."
	BITMAP "XXX....XXXXXX..."
	BITMAP "XXXX...XXXXXXX.."
	BITMAP "XXXX....XXXXXXX."
	BITMAP "XXXXX.XX.XXXXXX."
	BITMAP ".XXXXXXXXXXXXXX."
	BITMAP ".XXXXXXXXXXXXXX."
	BITMAP ".XXXXXXXXXXXXX.."
	BITMAP "..XXXXXXXXXXX..."

	BITMAP ".......XX.XX...."
	BITMAP "......XX.X..X..."
	BITMAP "......XXX..X.X.."
	BITMAP "......XXX..X.X.."
	BITMAP ".......XX.X..X.."
	BITMAP "......XX....X..."
	BITMAP ".....XX.X....X.."
	BITMAP ".....XX..X...XXX"
	BITMAP "..X..XX..XXXXXXX"
	BITMAP ".X.X..XX....X..."
	BITMAP ".XX.X.XXX....X.."
	BITMAP ".XX.XX..XX...X.."
	BITMAP "..XX.X..XX...X.."
	BITMAP "..XX.........X.."
	BITMAP "..XX..X.....X..."
	BITMAP "...XXXXXXXXX...."

	BITMAP ".......XX.XX...."
	BITMAP "......XXXXXXX..."
	BITMAP "......XX.XX.XX.."
	BITMAP "......XX.XX.XX.."
	BITMAP ".......XXXXXXX.."
	BITMAP "......XXXXXXX..."
	BITMAP ".....XXXXXXXXX.."
	BITMAP ".....XXXXXXXXX.X"
	BITMAP "..X..XXXXXXXX..X"
	BITMAP ".XXX..XXXXXXX..."
	BITMAP ".XXXX.XXXXXXXX.."
	BITMAP ".XXXXXXXXXXXXX.."
	BITMAP "..XXXXXXXXXXXX.."
	BITMAP "..XXXXXXXXXXXX.."
	BITMAP "..XXXXXXXXXXX..."
	BITMAP "...XXXXXXXXX...."

sprites_color:
	DATA BYTE $06,$06,$06,$06,$06,$06,$06,$06
	DATA BYTE $06,$06,$06,$06,$06,$06,$06,$06
	DATA BYTE $49,$49,$49,$49,$49,$49,$49,$49
	DATA BYTE $49,$49,$49,$49,$49,$49,$49,$49
	DATA BYTE $0d,$0d,$0d,$0d,$0d,$0d,$0d,$0d
	DATA BYTE $0d,$0d,$0d,$0d,$0d,$0d,$0d,$0d
	DATA BYTE $4e,$4e,$4e,$4e,$4e,$4e,$4e,$4e
	DATA BYTE $4e,$4e,$4e,$4e,$4e,$4e,$4e,$4e

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
		SOUND 5, #note_freq(note - 1)
	END IF
	SOUND 5, , volume_effect(tick_note)
	END

sound_off:	PROCEDURE
	SOUND 5,,0
	SOUND 6,,0
	SOUND 7,,0
	SOUND 9,,$38
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
