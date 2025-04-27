	'
	' Test 2 - Multiply/Divide/Modulo + READ DATA 
	'
	' by Oscar Toledo G.
	' https://nanochess.org/
	'
	' Creation date: Feb/29/2024.
	' Revision date: Aug/06/2024. Updated with new tests.
	' Revision date: Sep/01/2024. Added arithmetic tests.
	'

	DIM array(5), #array(5)

	SIGNED #count, #value

	WHILE 1

	CLS

	PRINT AT 0,"Arithmetic operations"

	a = $5a
	b = $a0

	PRINT AT $0040, a + b
	PRINT AT $0060, a - b
	PRINT AT $0080, a OR b
	PRINT AT $00a0, a AND b
	PRINT AT $00c0, a XOR b
	PRINT AT $00e0, a = b
	PRINT AT $0100, a <> b
	PRINT AT $0120, a < b
	PRINT AT $0140, a > b
	PRINT AT $0160, a <= b
	PRINT AT $0180, a >= b

	#a = $5a
	#b = $a0

	PRINT AT $0050, #a + #b
	PRINT AT $0070, #a - #b
	PRINT AT $0090, #a OR #b
	PRINT AT $00b0, #a AND #b
	PRINT AT $00d0, #a XOR #b
	PRINT AT $00f0, #a = #b
	PRINT AT $0110, #a <> #b
	PRINT AT $0130, #a < #b
	PRINT AT $0150, #a > #b
	PRINT AT $0170, #a <= #b
	PRINT AT $0190, #a >= #b

	FOR c = 1 TO 180
		WAIT
	NEXT c

	CLS

	PRINT AT 0, "Multiply/Divide/Modulo test"

	FOR c = 0 TO 22

		PRINT AT c * 32 + 32, c * 3
		PRINT AT c * 32 + 40, c / 3
		PRINT AT c * 32 + 48, c % 3

	NEXT c

	FOR c = 1 TO 180
		WAIT
	NEXT c

	CLS

	PRINT AT 0, "Same but signed"

	FOR #count = -10 TO 10

		PRINT AT #count * 32 + 352
		#value = #count * 3
		IF #value < 0 THEN PRINT "-",<>-#value ELSE PRINT <>#value

		PRINT AT #count * 32 + 360
		#value = #count / 3
		IF #value < 0 THEN PRINT "-",<>-#value ELSE PRINT <>#value

		PRINT AT #count * 32 + 368
		#value = #count % 3
		IF #value < 0 THEN PRINT "-",<>-#value ELSE PRINT <>#value

	NEXT #count

	FOR c = 1 TO 180
		WAIT
	NEXT c

	CLS

	PRINT AT 0,"RESTORE/READ BYTE/READ"

	#pointer = $1840

	RESTORE saved_string

	DO
		READ BYTE c
		IF c = 0 THEN EXIT DO

		PRINT AT #pointer, CHR$(c)
		#pointer = #pointer + 1		
	LOOP WHILE 1

	PRINT AT 128

	DO
		READ #c
		IF #c = 0 THEN EXIT DO
		PRINT <>#c," "
	LOOP WHILE 1

	FOR c = 1 TO 180
		WAIT
	NEXT c

	CLS

	PRINT AT 0,"Arrays"

	array(0) = 8
	array(1) = 24
	array(2) = 16
	array(3) = 32
	array(4) = 48

	#array(0) = 101
	#array(1) = 202
	#array(2) = 303
	#array(3) = 404
	#array(4) = 505

	FOR c = 0 TO 4

		PRINT AT c * 32 + 64, <>array(c)
		PRINT AT c * 32 + 72, <>#array(c)

	NEXT c

	FOR c = 1 TO 180
		WAIT
	NEXT c

	CLS

	PRINT AT 0,"ON GOTO/ON GOSUB"

	FOR c = 0 TO 5
		ON c GOTO label1, label2, label3, label4, label5
		PRINT AT 195,"success: out of range"
		GOTO label6

label1:		PRINT AT 35,"label1"
		GOTO label6

label2:		PRINT AT 67,"label2"
		GOTO label6

label3:		PRINT AT 99,"label3"
		GOTO label6

label4:		PRINT AT 131,"label4"
		GOTO label6

label5:		PRINT AT 163,"label5"
		GOTO label6

label6:
	NEXT c

	FOR c = 1 TO 3
		ON c - 1 GOSUB subroutine_1, subroutine_2, subroutine_3
	NEXT c

	FOR c = 1 TO 180
		WAIT
	NEXT c

	WEND

subroutine_1:	PROCEDURE
	PRINT AT 472,"/-----\\"
	END

subroutine_2:	PROCEDURE
	PRINT AT 504,"|^   ^|"
	END

subroutine_3:	PROCEDURE
	PRINT AT 536,"|  A  |"
	END

saved_string:
	DATA BYTE "Test string",0

	DATA 444,333,222,111,0

