	'
	' Example of string building
	'
	' by Oscar Toledo G.
	'
	' Creation date: May/23/2024.
	'

	FOR #c = 4 TO 740 STEP 32

		d = RANDOM(10)
		e = RANDOM(10)

		#d = #c
		c = d
		GOSUB point_to_word
		GOSUB show_word

		c = e
		GOSUB point_to_word
		GOSUB show_word
	NEXT #c

	WHILE 1: WEND

point_to_word:	PROCEDURE
	RESTORE planet_names
	WHILE c
		DO
			READ BYTE f
		LOOP WHILE f <> 0
		c = c - 1
	WEND
	END

show_word:	PROCEDURE
	DO
		READ BYTE f
		IF f THEN VPOKE $1800 + #d, f: #d = #d + 1
	LOOP WHILE f <> 0
	END

planet_names:
	DATA BYTE "TRAN",0
	DATA BYTE "TOR",0
	DATA BYTE "JU",0
	DATA BYTE "PI",0
	DATA BYTE "TER",0
	DATA BYTE "NO",0
	DATA BYTE "VA",0
	DATA BYTE "SI",0
	DATA BYTE "RIUS",0
	DATA BYTE "SA",0
	DATA BYTE "NEW",0
	DATA BYTE "GA",0
	DATA BYTE "MARS",0
	DATA BYTE "TI",0
	DATA BYTE "TAN",0
	DATA BYTE "NEP",0
	DATA BYTE "TUNE",0
	DATA BYTE "PLU",0
	DATA BYTE "TON",0
	DATA BYTE "LA",0

