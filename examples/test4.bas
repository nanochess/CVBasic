	'
	' Benchmark and multiplication/division routines test.
	'
	' by Oscar Toledo G.
	' https://nanochess.org/
	'
	' Creation date: Mar/25/2026.
	'

	#time = FRAME
	FOR #c = 1 TO 65534
	#d = $0001 * #c
	IF FRAME - #time >= 60 THEN EXIT FOR
	NEXT #c
	PRINT AT $0002,<.5>#c," muls $0001 in 1 second"
	#time = FRAME
	FOR #c = 1 TO 65534
	#d = $00ff * #c
	IF FRAME - #time >= 60 THEN EXIT FOR
	NEXT #c
	PRINT AT $0022,<.5>#c," muls $00ff in 1 second"
	#time = FRAME
	FOR #c = 1 TO 65534
	#d = $8000 * #c
	IF FRAME - #time >= 60 THEN EXIT FOR
	NEXT #c
	PRINT AT $0042,<.5>#c," muls $8000 in 1 second"
	#time = FRAME
	FOR #c = 1 TO 65534
	#d = $aa55 * #c
	IF FRAME - #time >= 60 THEN EXIT FOR
	NEXT #c
	PRINT AT $0062,<.5>#c," muls $aa55 in 1 second"

	#time = FRAME
	FOR #c = 1 TO 65534
	#d = $00ff / #c
	IF FRAME - #time >= 60 THEN EXIT FOR
	NEXT #c
	PRINT AT $00C2,#c," divs $00ff in 1 second."

	#time = FRAME
	FOR #c = 1 TO 65534
	#d = $FFFF / #c
	IF FRAME - #time >= 60 THEN EXIT FOR
	NEXT #c
	PRINT AT $00e2,#c," divs $ffff in 1 second."

	#e = $0101
	FOR #c = 1 TO 65000 STEP 101
	#d = $0101 * #c
	PRINT AT $0122,"$0101 * ",#c, " = ",<.5>#d
	IF #d <> #e THEN PRINT AT $0142,"bad ",#c
	#e = #e + $0101 * 101
	NEXT #c

	#e = $0100
	FOR #c = 1 TO 65000 STEP 101
	#d = $0100 * #c
	PRINT AT $0162,"$0100 * ",#c, " = ",<.5>#d
	IF #d <> #e THEN PRINT AT $0182,"bad ",#c
	#e = #e + $0100 * 101
	NEXT #c

	#e = $0001
	FOR #c = 1 TO 65000 STEP 101
	#d = $0001 * #c
	PRINT AT $01A2,"$0001 * ",#c, " = ",<.5>#d
	IF #d <> #e THEN PRINT AT $01C2,"bad ",#c
	#e = #e + $0001 * 101
	NEXT #c

	#e = $0007
	FOR #c = 1 TO 1000
	#d = #e / 7
	PRINT AT $01e2,#e, " / $0007 = ",<.5>#d
	IF #d <> #c THEN PRINT AT $0202,"bad ",#c
	#e = #e + 7
	NEXT #c

	WHILE 1: WEND

	' For testing NES code generation.
'	CHRROM 0

