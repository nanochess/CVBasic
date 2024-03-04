	'
	' Test 2 - Multiply/Divide/Modulo + READ DATA 
	'
	' by Oscar Toledo G.
	' https://nanochess.org/
	'
	' Creation date: Feb/29/2024.
	'

	FOR c = 0 TO 23

		PRINT AT c * 32, c * 3
		PRINT AT c * 32 + 8, c / 3
		PRINT AT c * 32 + 16, c % 3

	NEXT c

	#pointer = $1800

	RESTORE saved_string

	DO
		READ BYTE c
		IF c = 0 THEN EXIT DO

		VPOKE #pointer, c
		#pointer = #pointer + 1		
	LOOP WHILE 1

	WHILE 1: WEND

saved_string:
	DATA BYTE "Test string",0
