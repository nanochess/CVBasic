	'
	' Brinquitos: Demo game
	'
	' by Oscar Toledo Gutiérrez
	' https://nanochess.org/
	'
	' Creation date: Oct/06/2024.
	' Revision date: Aug/24/2025. Adapted to NES/Famicom.
	'

	CONST MAX_CLOUDS = 4

	'
	' Cloud information
	'
	DIM cloud_x(MAX_CLOUDS)	' X-coordinate
	DIM cloud_y(MAX_CLOUDS)	' Y-coordinate
	DIM cloud_e(MAX_CLOUDS)	' State
	
	PALETTE LOAD game_palette

	'
	' Restart game
	'
restart_game:
	' Clear the screen
	CLS

	' Green letters in the center
	VPOKE $23C8,$55
	VPOKE $23C9,$55
	VPOKE $23CA,$55
	VPOKE $23CB,$55
	VPOKE $23CC,$55
	VPOKE $23CD,$55
	VPOKE $23CE,$55
	VPOKE $23CF,$55

	#puntos = 0

	' Setup initial clouds
	cloud_y(3) = 176
	cloud_y(2) = 126
	cloud_y(1) = 76
	cloud_y(0) = 26

	cloud_x(3) = 128
	cloud_e(3) = 0

	c = 2
	GOSUB setup_cloud
	c = 1
	GOSUB setup_cloud
	c = 0
	GOSUB setup_cloud

	' Setup player
	x = 128			' X-coordinate
	y = 160			' Y-coordinate
	jump_state = 0		' Jump state
	standing_on = 3		' Standing on cloud 3

	PLAY SIMPLE
	PLAY music_gladiators

	'
	' Main loop
	'
main_loop:

	'
	' Jump sound effect.
	'
	IF jump_state >= 33 THEN	' Jumping
		f = 4
		SOUND 12, $0800 + y, 64
		SOUND 15, 15
	ELSEIF jump_state THEN		' Falling
		f = 8
		SOUND 12, $0800 + y, 64
		SOUND 15, 15
	ELSE				' Standing
		f = 0
		SOUND 15, 11
	END IF

	' Show the player sprite
	SPRITE 0, y - 1, x - 8, f + 1, 0
	SPRITE 1, y - 1, x, f + 3, 0
	
	' Show sprites for clouds
	FOR c = 0 TO 3
		SPRITE c * 2 + 2, cloud_y(c) - 1, cloud_x(c) - 8, 12 + 1, 1
		SPRITE c * 2 + 3, cloud_y(c) - 1, cloud_x(c), 14 + 1, 1
	NEXT c

	' Video synchronization
	WAIT

	' Update score
	PRINT AT 65,<>#puntos

	' Detect if it should do vertical displacement...
	' ...of the screen.
	IF y < 110 AND jump_state = 0 THEN
		y = y + 1
		FOR c = 0 TO MAX_CLOUDS - 1
			cloud_y(c) = cloud_y(c) + 1
			IF cloud_y(c) = 192 THEN
				cloud_y(c) = -8
				GOSUB setup_cloud
			END IF
		NEXT c
	END IF

	' Detect if the player stands on a cloud
	IF jump_state <> 0 AND jump_state < 33 AND standing_on = 255 THEN
		FOR c = 0 TO MAX_CLOUDS - 1
			IF ABS(cloud_x(c) + 1 - x) < 8 AND ABS(cloud_y(c) - 16 - y) < 3 THEN
				jump_state = 0
				y = cloud_y(c) - 16
				standing_on = c
				IF was_on <> standing_on THEN 
					#puntos = #puntos + 1
				END IF
			END IF
		NEXT c
	END IF

	' Move the clouds
	FOR c = 0 TO MAX_CLOUDS - 1
		IF cloud_e(c) = 1 THEN	' 1- Left
			IF standing_on = c THEN x = x - 2
			cloud_x(c) = cloud_x(c) - 2
			IF cloud_x(c) < 18 THEN cloud_e(c) = 2
		ELSEIF cloud_e(c) = 2 THEN	' 2- Right
			IF standing_on = c THEN x = x + 2
			cloud_x(c) = cloud_x(c) + 2
			IF cloud_x(c) > 238 THEN cloud_e(c) = 1
		END IF
	NEXT c

	' Handle jumping.
	IF jump_state THEN
		IF jump_state >= 33 THEN
			jump_state = jump_state - 1
			y = y - 2
		ELSE
			y = y + 2
			IF y = 242 OR y = 243 THEN GOTO end_of_game
		END IF
	END IF

	' Jump if button pressed
	IF cont.button THEN
		IF jump_state = 0 THEN
			jump_state = 64
			was_on = standing_on
			standing_on = 255
		END IF
	END IF

	GOTO main_loop

	'
	' End of game
	'
end_of_game:
	' Turn off jumping sound effect
	SOUND 15, 11
	
	' Final music
	PLAY music_end

	PRINT AT 168,"G A M E   O V E R"

	FOR c = 1 TO 240
		WAIT
	NEXT c

	GOTO restart_game

	'
	' Setup a cloud
	'
setup_cloud:	PROCEDURE

	'
	' Choose a position with margin of 32 pixels at each side.
	' Make sure the minimum distance of 64 pixels...
	' ...against the next cloud so the jump is possible.
	'
	DO
		cloud_x(c) = RANDOM(96) * 2 + 32
	LOOP WHILE ABS(cloud_x(c) + 1 - cloud_x((c + 1) % MAX_CLOUDS)) < 64

	' Assign a movement direction.
	cloud_e(c) = RANDOM(2) + 1
	END

game_palette:
	DATA BYTE $02,$27,$27,$27
	DATA BYTE $02,$27,$27,$2A
	DATA BYTE $02,$27,$27,$27
	DATA BYTE $02,$27,$27,$27
	DATA BYTE $02,$27,$16,$12
	DATA BYTE $02,$0F,$10,$30
	DATA BYTE $02,$27,$27,$27
	DATA BYTE $02,$27,$27,$27

	'
	' Game sprites
	'
	CHRROM 0

	CHRROM PATTERN 256

	BITMAP "................"	' Standing
	BITMAP "................"
	BITMAP "................"
	BITMAP "......1111......"
	BITMAP ".....111111....."
	BITMAP "....11111111...."
	BITMAP "...1133113311..."
	BITMAP "...1133113311..."
	BITMAP "..111111111111.."
	BITMAP ".11111311311111."
	BITMAP "11.1..1111..1.11"
	BITMAP "11.11......11.11"
	BITMAP "11.1111111111.11"
	BITMAP "222..11..11..222"
	BITMAP "....222..222...."
	BITMAP "...2222..2222..."

	BITMAP ".22..........22."	' Jumping
	BITMAP "222..........222"
	BITMAP "111...1111...111"
	BITMAP ".11..111111..11."
	BITMAP ".11.13311331.11."
	BITMAP ".1.1133113311.1."
	BITMAP ".1.1111111111.1."
	BITMAP "..111131131111.."
	BITMAP "...1..1111..1..."
	BITMAP "...11..11..11..."
	BITMAP "...111....111..."
	BITMAP "...1111111111..."
	BITMAP ".....11..11....."
	BITMAP ".....11..11....."
	BITMAP ".....22..22....."
	BITMAP "....222..222...."

	BITMAP ".22..........22."	' Falling
	BITMAP "222...1111...222"
	BITMAP ".11..111111..11."
	BITMAP ".11.13311331.11."
	BITMAP ".1.1133113311.1."
	BITMAP ".1.1111111111.1."
	BITMAP "..111131131111.."
	BITMAP "...1111331111..."
	BITMAP "...11......11..."
	BITMAP "...111....111..."
	BITMAP "...1111111111..."
	BITMAP ".....11..11....."
	BITMAP ".....11..11....."
	BITMAP ".....22..22....."
	BITMAP ".....22..22....."
	BITMAP "....222..222...."

	BITMAP "..333133313....."	' Cloud
	BITMAP ".333321332132..."
	BITMAP ".3322331332132.."
	BITMAP "33211331332132.."
	BITMAP "22133311223112.."
	BITMAP ".133313311132..."
	BITMAP ".3333133213332.."
	BITMAP ".33331332133332."
	BITMAP "..2222..22..22.."
	BITMAP "................"
	BITMAP "................"
	BITMAP "................"
	BITMAP "................"
	BITMAP "................"
	BITMAP "................"
	BITMAP "................"

	'
	' Gladiators music (circus entry)
	'
music_gladiators:
	DATA BYTE 7
	MUSIC C5,C3,-,-
	MUSIC S,S,-,-
	MUSIC B4,G3,-,-
	MUSIC S,S,-,-
	MUSIC A4#,G2,-,-
	MUSIC B4,S,-,-
	MUSIC A4#,G3,-,-
	MUSIC A4,S,-,-

	MUSIC G4#,C3,-,-
	MUSIC S,S,-,-
	MUSIC G4,G3,-,-
	MUSIC S,S,-,-
	MUSIC F4#,G2,-,-
	MUSIC S,S,-,-
	MUSIC G4,G3,-,-
	MUSIC S,S,-,-

	MUSIC A4,C3,-,-
	MUSIC S,S,-,-
	MUSIC G4#,G3,-,-
	MUSIC S,S,-,-
	MUSIC G4,G2,-,-
	MUSIC G4#,S,-,-
	MUSIC G4,G3,-,-
	MUSIC F4#,S,-,-

	MUSIC F4,C3,-,-
	MUSIC S,S,-,-
	MUSIC E4,G3,-,-
	MUSIC S,S,-,-
	MUSIC D4#,G2,-,-
	MUSIC S,S,-,-
	MUSIC E4,G3,-,-
	MUSIC S,S,-,-

	MUSIC G4,B2,-,-
	MUSIC S,S,-,-
	MUSIC F4,G3,-,-
	MUSIC F4,S,-,-
	MUSIC C4#,G2,-,-
	MUSIC S,S,-,-
	MUSIC D4,G3,-,-
	MUSIC S,S,-,-

	MUSIC G4,B2,-,-
	MUSIC S,S,-,-
	MUSIC F4,G3,-,-
	MUSIC F4,S,-,-
	MUSIC C4#,G2,-,-
	MUSIC S,S,-,-
	MUSIC D4,G3,-,-
	MUSIC S,S,-,-

	MUSIC B3,B2,-,-
	MUSIC C4,S,-,-
	MUSIC C4S,G3,-,-
	MUSIC D4,S,-,-
	MUSIC D4S,G2,-,-
	MUSIC E4,S,-,-
	MUSIC F4,G3,-,-
	MUSIC F4S,S,-,-

	MUSIC G4,B2,-,-
	MUSIC G4S,S,-,-
	MUSIC A4,G3,-,-
	MUSIC B4,S,-,-
	MUSIC A4,G2,-,-
	MUSIC S,S,-,-
	MUSIC G4,G3,-,-
	MUSIC S,S,-,-

	MUSIC REPEAT

	'
	' Music for end of game.
	'
music_end:
	DATA BYTE 20
	MUSIC C4,-,-,-
	MUSIC G3,-,-,-
	MUSIC C3,-,-,-
	MUSIC S,-,-,-
	MUSIC S,-,-,-
	MUSIC S,-,-,-
	MUSIC STOP

