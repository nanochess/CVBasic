	'
	' String handling in CVBASIC
	'
	' by Oscar Toledo G.
	' https://nanochess.org/
	'
	' Creation date: Apr/14/2025.
	'

	'
	' CVBasic doesn't support directly strings, but enough
	' support to provide the data and do processing.
	'

	' This is a macro, CVBasic doesn't process strings
	DEF FN center_string(pos, str) = PRINT AT pos - LEN(str)/2, str

	DEF FN wait_for_button(a) = FOR c = 0 TO 15:WAIT:NEXT:DO:WAIT:LOOP WHILE cont.button = 0

	DEF FN get_string(where, num) = RESTORE where: c = num: WHILE c > 0: DO: READ BYTE char: LOOP WHILE char <> 0: c = c - 1: WEND

	DEF FN print_string(a) = WHILE 1: READ BYTE char: IF char <> 0 THEN PRINT CHR$(char): WEND

	WHILE 1

	CLS

	center_string(80, "Hello, World!")

	wait_for_button(0)

	CLS

	get_string(messages_1, RANDOM(10))

	print_string(0)

	get_string(messages_2, RANDOM(5))

	print_string(0)

	get_string(messages_3, RANDOM(5))

	print_string(0)

	wait_for_button(0)

	WEND

messages_1:
	DATA BYTE "William",0
	DATA BYTE "Olivia",0
	DATA BYTE "Jack",0
	DATA BYTE "Amelia",0
	DATA BYTE "Michael",0
	DATA BYTE "Eleanor",0
	DATA BYTE "Noah",0
	DATA BYTE "Lily",0
	DATA BYTE "James",0
	DATA BYTE "Emma",0

messages_2:
	DATA BYTE " likes ",0
	DATA BYTE " dislikes ",0
	DATA BYTE " loves ",0
	DATA BYTE " hates ",0
	DATA BYTE " enjoys ",0

messages_3:
	DATA BYTE "frogs",0
	DATA BYTE "horses",0
	DATA BYTE "dogs",0
	DATA BYTE "cats",0
	DATA BYTE "turtles",0
