	'
	' C-style preprocessor test
	'
	' by Oscar Toledo G.
	' https://nanochess.org/
	'
	' Creation date: Jul/23/2026.
	'

	' You can use the platform constant (equivalent to the compilation option),
	' or a constant provided via command-line, or a constant defined inside
	' the program.

#if COLECOVISION
	PRINT AT 33,"Compiled for Colecovision"
#endif

#if SGM
	PRINT AT 65,"Compiled for SGM"
#endif

#if COLECOVISION
	PRINT AT 97,"This is a Colecovision"
#else
	PRINT AT 97,"This isn't a Colecovision"
#endif

	WHILE 1: WEND
