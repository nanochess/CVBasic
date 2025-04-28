	'
	' Brinquitos: Demo game
	'
	' by Oscar Toledo Gutiérrez
	' https://nanochess.org/
	'
	' Creation date: Oct/06/2024.
	' Revision date: Apr/26/2025. Adapted to Sega Master System.
	'

	CONST MAX_CLOUDS = 4

	'
	' Cloud information
	'
	DIM cloud_x(MAX_CLOUDS)	' X-coordinate
	DIM cloud_y(MAX_CLOUDS)	' Y-coordinate
	DIM cloud_e(MAX_CLOUDS)	' State
	
	'
	' Restart game
	'
restart_game:
	' Clear the screen
	CLS
	' Turquoise numbers
	FOR #c = $0603 TO $07FF STEP 4
		VPOKE #c, 0
	NEXT #c
	' Blue background
	FOR #c = $0402 TO $0FFE STEP 4
		VPOKE #c, VPEEK(#c) OR $FF
	NEXT #c

	' Define sprites
	DEFINE SPRITE 0,8,sprites_bitmaps

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
		SOUND 2, y, 12
	ELSEIF jump_state THEN		' Falling
		f = 8
		SOUND 2, y, 12
	ELSE				' Standing
		f = 0
		SOUND 2, , 0
	END IF

	' Show the player sprite
	SPRITE 0, y - 1, x - 8, f
	SPRITE 1, y - 1, x, f + 2
	
	' Show sprites for clouds
	FOR c = 0 TO 3
		SPRITE c * 2 + 2, cloud_y(c) - 1, cloud_x(c) - 8, 12
		SPRITE c * 2 + 3, cloud_y(c) - 1, cloud_x(c), 14
	NEXT c

	' Video synchronization
	WAIT

	' Update score
	PRINT AT 1,<>#puntos

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
			IF y = 200 OR y = 201 THEN GOTO end_of_game
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
	SOUND 2, , 0
	
	' Final music
	PLAY music_end

	PRINT AT 135,"G A M E   O V E R"

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

	'
	' Game sprites
	'
sprites_bitmaps:
	BITMAP "................"	' Standing
	BITMAP "................"
	BITMAP "................"
	BITMAP "......AAAA......"
	BITMAP ".....AAAAAA....."
	BITMAP "....AAAAAAAAA..."
	BITMAP "...AA44AA44AA..."
	BITMAP "...AA44AA44AA..."
	BITMAP "..AAAAAAAAAAAA.."
	BITMAP ".AAAAAFAAFAAAAA."
	BITMAP "AA.A66AAAA66A.AA"
	BITMAP "AA.AA666666AA.AA"
	BITMAP "AA.AAAAAAAAAA.AA"
	BITMAP "999..AA..AA..999"
	BITMAP "....555..555...."
	BITMAP "...5555..5555..."

	BITMAP ".99..........99."	' Jumping
	BITMAP "999..........999"
	BITMAP "AAA...AAAA...AAA"
	BITMAP ".AA..AAAAAA..AA."
	BITMAP ".AA.A44AA44A.AA."
	BITMAP ".A.AA44AA44AA.A."
	BITMAP ".A.AAAAAAAAAA.A."
	BITMAP "..AAAAFAAFAAAA.."
	BITMAP "...A66AAAA66A..."
	BITMAP "...AA66AA66AA..."
	BITMAP "...AAA6666AAA..."
	BITMAP "...AAAAAAAAAA..."
	BITMAP ".....AA..AA....."
	BITMAP ".....AA..AA....."
	BITMAP ".....55..55....."
	BITMAP "....555..555...."

	BITMAP ".99..........99."	' Falling
	BITMAP "999...AAAA...999"
	BITMAP ".AA..AAAAAA..AA."
	BITMAP ".AA.A44AA44A.AA."
	BITMAP ".A.AA44AA44AA.A."
	BITMAP ".A.AAAAAAAAAA.A."
	BITMAP "..AAAAFAAFAAAA.."
	BITMAP "...AAAAFFAAAA..."
	BITMAP "...AA666666AA..."
	BITMAP "...AAA6666AAA..."
	BITMAP "...AAAAAAAAAA..."
	BITMAP ".....AA..AA....."
	BITMAP ".....AA..AA....."
	BITMAP ".....55..55....."
	BITMAP ".....55..55....."
	BITMAP "....555..555...."

	BITMAP "..FFF1FFF1F....."	' Cloud
	BITMAP ".FFFFE1FFE1FE..."
	BITMAP ".FFEEFF1FFE1FE.."
	BITMAP "FFE11FF1FFE1FE.."
	BITMAP "EE1FFF11EEF11E.."
	BITMAP ".1FFF1FF111FE..."
	BITMAP ".FFFF1FFE1FFFE.."
	BITMAP ".FFFF1FFE1FFFFE."
	BITMAP "..EEEE..EE..EE.."
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

