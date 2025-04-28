	'
	' Test 3
	'
	' by Oscar Toledo G.
	' https://nanochess.org/
	'
	' Creation date: Nov/12/2024.
	' Revision date: Apr/27/2025. Adapted for Sega Master System.
	'

	DEFINE SPRITE 0, 2, sprite_bitmap

	sprite_x = 148
	sprite_y = 116

	#state = 0
	d = 1

	WHILE 1

		SPRITE 0, sprite_y - 1, sprite_x, 0
		SPRITE 1, sprite_y - 1, sprite_x + 8, 2

		WAIT
		WAIT

		d = d - 1
		IF d = 0 THEN
			d = 40
			#state = #state + 1
			IF #state = 10 THEN #state = 1
		END IF

		SELECT CASE #state
			CASE 1
				PALETTE 10 + 16, $0F
				sprite_x = sprite_x - 2
			CASE 2
				sprite_y = sprite_y - 2
			CASE 3
				sprite_x = sprite_x + 2
			CASE 4
				sprite_y = sprite_y + 2
			CASE 5 TO 6
				sprite_x = sprite_x - 1
				sprite_y = sprite_y - 1
			CASE 7 TO 8
				sprite_x = sprite_x + 1
				sprite_y = sprite_y + 1
			CASE ELSE
				PALETTE 10 + 16, RANDOM(63) + 1
		END SELECT

	WEND


sprite_bitmap:
	BITMAP "......AAAA......"
	BITMAP "......AAAA......"
	BITMAP "......AAAA......"
	BITMAP "......AAAA......"
	BITMAP ".......AA......."
	BITMAP "..A....AA......."
	BITMAP ".AAAAAAAAAAA...."
	BITMAP ".AAAAAAAAAAAA..."
	BITMAP ".......AA...AA.."
	BITMAP ".......AA....AA."
	BITMAP "......AAAA....AA"
	BITMAP ".....AA..AA....."
	BITMAP ".....AA..AA....."
	BITMAP ".....AA..AA....."
	BITMAP ".....AA..AA....."
	BITMAP "....AAA..AAA...."
