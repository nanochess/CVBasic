
	DEFINE SPRITE 0,1,happy_face

	PRINT AT 36,"Happy face!"

	x = 50
	y = 100
	dx = 1
	dy = 1


game_loop:
	WAIT
	WAIT
	SPRITE 0,y-1,x,0,face_color

	face_color = 10
	IF cont1.up THEN IF y > 0 THEN y = y - 1
	IF cont1.left THEN IF x > 0 THEN x = x - 1
	IF cont1.right THEN IF x < 240 THEN x = x + 1
	IF cont1.down THEN IF y < 176 THEN y = y + 1
	IF cont1.button THEN face_color = 5
	IF cont1.button2 THEN face_color = 6

	GOTO game_loop

happy_face:
	BITMAP "......XXXX......"
	BITMAP "....XXXXXXXX...."
	BITMAP "...XXXXXXXXXX..."
	BITMAP "..XXXXXXXXXXXX.."
	BITMAP ".XXXXXXXXXXXXXX."
	BITMAP ".XXXXXXXXXXXXXX."
	BITMAP "XXXX..XXXX..XXXX"
	BITMAP "XXXX..XXXX..XXXX"
	BITMAP "XXXXXXXXXXXXXXXX"
	BITMAP "XXXXXXXXXXXXXXXX"
	BITMAP ".XXXXXXXXXXXXXX."
	BITMAP ".XXX..XXXX..XXX."
	BITMAP "..XXX......XXX.."
	BITMAP "...XXX....XXX..."
	BITMAP "....XXXXXXXX...."
	BITMAP "......XXXX......"
