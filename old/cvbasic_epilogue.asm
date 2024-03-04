	;
	; CVBasic epilogue (BASIC compiler for Colecovision)
	;
	; by Oscar Toledo G.
	; https://nanochess.org/
	;
	; Creation date: Feb/27/2024.
	; Revision date: Feb/29/2024. Added joystick, keypad, frame, random, and
	;                             read_pointer variables.
	;

	org $7000

sprites:
	rb 128
sprite_data:
	rb 4
frame:
	rb 2
read_pointer:
	rb 2
cursor:
	rb 2
lfsr:
	rb 2
mode:
	rb 1
joy1_data:
	rb 1
joy2_data:
	rb 1
key1_data:
	rb 1
key2_data:
	rb 1

