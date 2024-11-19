	'
	' Test 3
	'
	' by Oscar Toledo G.
	' https://nanochess.org/
	'
	' Creation date: Nov/12/2024.
	'

	DEFINE SPRITE 0, 1, sprite_bitmap

	sprite_x = 148
	sprite_y = 116

	sprite_color = 10

	#state = 0
	d = 1

	WHILE 1

		SPRITE 0, sprite_y - 1, sprite_x, 0, sprite_color

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
				sprite_color = 10
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
				sprite_color = RANDOM(14) + 2
		END SELECT

	WEND


sprite_bitmap:
	BITMAP "......XXXX......"
	BITMAP "......XXXX......"
	BITMAP "......XXXX......"
	BITMAP "......XXXX......"
	BITMAP ".......XX......."
	BITMAP "..X....XX......."
	BITMAP ".XXXXXXXXXXX...."
	BITMAP ".XXXXXXXXXXXX..."
	BITMAP ".......XX...XX.."
	BITMAP ".......XX....XX."
	BITMAP "......XXXX....XX"
	BITMAP ".....XX..XX....."
	BITMAP ".....XX..XX....."
	BITMAP ".....XX..XX....."
	BITMAP ".....XX..XX....."
	BITMAP "....XXX..XXX...."
