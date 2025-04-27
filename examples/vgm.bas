	'
	' Mini VGM player for CVBasic
	'
	' This handles only SN76489 VGM files.
	'
	' by Oscar Toledo G.
	' https://nanochess.org/
	'
	' Creation date: Mar/13/2024.
	'

	'
	' I/O port where the PSG is located in hardware.
	'
'	CONST VGM_PSG_PORT = $7F	' For SG-1000/SMS
	CONST VGM_PSG_PORT = $FF	' For Colecovision

	ON FRAME GOSUB vgm_play

	PRINT AT 33,"VGM playing..."

	'
	' Start playing a VGM song.
	'
	#vgm_song = VARPTR vgm_music(0)
	GOSUB vgm_start

	'
	' Does nothing except to show the current playing pointer.
	'
	WHILE 1
		WAIT
		PRINT AT 65,#vgm_pointer,"    "
	WEND

	'
	' Start playing a VGM song.
	' Input: #vgm_song = pointer to song.
	'
vgm_start:	PROCEDURE
	#vgm_end = #vgm_song + (PEEK(#vgm_song + 4) + (PEEK(#vgm_song + 5) * 256))
	IF PEEK(#vgm_song + 8) < $50 THEN
		#vgm_pointer = #vgm_song + 64
	ELSE
		#vgm_pointer = #vgm_song + $34 + (PEEK(#vgm_song + 52) + (PEEK(#vgm_song + 53) * 256))
	END IF

	END

	'
	' This routine is called on each video frame to play the next audio data.
	'
vgm_play:	PROCEDURE
	IF #vgm_pointer = 0 THEN RETURN

	IF #vgm_pointer >= #vgm_end THEN #vgm_pointer = 0: RETURN

	WHILE 1
		vgm_byte = PEEK(#vgm_pointer)
		#vgm_pointer = #vgm_pointer + 1
		IF vgm_byte = $50 THEN
			OUT VGM_PSG_PORT,PEEK(#vgm_pointer)
			#vgm_pointer = #vgm_pointer + 1
		ELSEIF vgm_byte = $61 THEN
			#vgm_pointer = #vgm_pointer + 2
			EXIT WHILE
		ELSEIF vgm_byte = $62 THEN
			EXIT WHILE
		ELSEIF vgm_byte = $63 THEN
			EXIT WHILE
		ELSEIF vgm_byte = $66 THEN
			#vgm_pointer = 0
			EXIT WHILE
		END IF
	WEND
	END

	'
	' You can download VGM music from:
	' https://www.zophar.net/music/sega-master-system-vgm/alex-kidd-in-miracle-world
	'
	' You need to decompress the file, and inside each file is compressed with gzip,
	' so you need to decompress again each file.
	'
vgm_music:
	ASM INCBIN "alexkidd.vgm"
