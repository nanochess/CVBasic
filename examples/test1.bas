	'
	' Test 1 - Moving stars 
	'
	' by Oscar Toledo G.
	' https://nanochess.org/
	'
	' Creation date: Feb/29/2024.
	' Revision date: Apr/27/2025. Uses new CHR$ syntax.
	'

	DIM #stars(24)

	FOR c = 0 TO 23
		#stars(c) = 32 * c + #initial_positions(c)
	NEXT c

	WHILE 1
		PRINT AT 2,FRAME
		PRINT AT 12,".",<5>FRAME,"."
		PRINT AT 22,":",<.5>FRAME,":"

		WAIT
		FOR c = 0 TO 23
			PRINT AT #stars(c), CHR$(32)
			#stars(c) = #stars(c) + 32
			IF #stars(c) >= 768 THEN #stars(c) = #stars(c) - 736
			PRINT AT #stars(c), CHR$(42)
		NEXT c
	WEND


#initial_positions:
	DATA 21,30,6,5
	DATA 18,11,11,5
	DATA 29,25,22,8
	DATA 10,2,9,22
	DATA 6,14,9,20
	DATA 14,28,31,24
