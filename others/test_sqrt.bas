	'
	' Test Z80 integer square root
	'
	' by Oscar Toledo G.
	'
	' Creation date: Apr/07/2026.
	'

	PRINT AT 33, USR sqrt(16384)
	PRINT AT 65, USR sqrt(10000)
	PRINT AT 97, USR sqrt(100)

	WHILE 1: WEND

ASM SQRT:
ASM LD DE,0
ASM CALL isqrt
ASM RET

	ASM INCLUDE "sqrt.asm"
