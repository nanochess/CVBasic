	' TMSColor 2.1.0 Mar/07/2024
	' Command: tmscolor -t128 -b -n portrait.bmp portrait.bas 
	' Created: Fri Mar 08 15:12:14 2024

	' This portrait is courtesy of my game Zombie Near

	'
	' Recommended code:
	' MODE 0
	' DEFINE CHAR 128,50,image_char
	' DEFINE COLOR 128,50,image_color
	' SCREEN image_pattern,0,0,8,8,8
	'
image_char:
	DATA BYTE $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
	DATA BYTE $ff,$ff,$f8,$f0,$e0,$c0,$c0,$80
	DATA BYTE $ff,$fc,$ff,$ff,$f8,$fb,$f8,$f0
	DATA BYTE $ff,$07,$01,$07,$03,$c0,$3c,$ff
	DATA BYTE $ff,$ff,$ff,$ff,$3f,$1f,$0f,$07
	DATA BYTE $ff,$ff,$fe,$fe,$fc,$fc,$f8,$f8
	DATA BYTE $ff,$ff,$ff,$ff,$f8,$fb,$f0,$e0
	DATA BYTE $f7,$f0,$f0,$e0,$ff,$f0,$ff,$c0
	DATA BYTE $80,$79,$01,$01,$01,$01,$ff,$0f
	DATA BYTE $03,$01,$01,$ff,$ff,$ff,$ff,$7f
	DATA BYTE $ff,$ff,$ff,$ff,$ff,$7f,$7f,$3f
	DATA BYTE $f8,$f8,$f0,$f0,$f0,$f0,$f0,$f0
	DATA BYTE $c0,$80,$fe,$fe,$fc,$fc,$fc,$fc
	DATA BYTE $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
	DATA BYTE $07,$03,$01,$01,$e0,$f0,$f8,$fc
	DATA BYTE $7f,$3f,$3f,$3f,$3f,$1f,$1f,$1f
	DATA BYTE $3f,$1f,$1f,$0f,$0f,$0f,$07,$07
	DATA BYTE $e0,$e0,$e0,$e0,$e0,$e0,$c0,$c0
	DATA BYTE $fc,$fc,$f0,$f0,$e0,$1a,$1c,$19
	DATA BYTE $ff,$ff,$7f,$0f,$87,$e7,$1b,$05
	DATA BYTE $fe,$ff,$f8,$e0,$c3,$ce,$f0,$c8
	DATA BYTE $1f,$0f,$0f,$0f,$7f,$3f,$3f,$3f
	DATA BYTE $07,$07,$07,$03,$03,$03,$01,$01
	DATA BYTE $80,$80,$80,$80,$fe,$fe,$fe,$fe
	DATA BYTE $1d,$1e,$1f,$1f,$1f,$e0,$e0,$e0
	DATA BYTE $4d,$1d,$fd,$fd,$fd,$fb,$fb,$f7
	DATA BYTE $ea,$f0,$ff,$ff,$ff,$ff,$ff,$ff
	DATA BYTE $3f,$37,$33,$33,$03,$03,$03,$03
	DATA BYTE $01,$01,$03,$03,$03,$03,$03,$03
	DATA BYTE $fe,$fe,$fe,$fe,$fe,$fe,$fe,$14
	DATA BYTE $e0,$e0,$e0,$f0,$f0,$f8,$07,$03
	DATA BYTE $f7,$f9,$fe,$ff,$f8,$e3,$e4,$f3
	DATA BYTE $ff,$7f,$ff,$ff,$3f,$8f,$4f,$9f
	DATA BYTE $03,$03,$03,$07,$0f,$1f,$1f,$3f
	DATA BYTE $03,$03,$03,$03,$03,$03,$03,$03
	DATA BYTE $fe,$fe,$fe,$fe,$fe,$fe,$fe,$ff
	DATA BYTE $14,$14,$14,$14,$14,$14,$14,$14
	DATA BYTE $f0,$fc,$ff,$ff,$7f,$7f,$7f,$7f
	DATA BYTE $f8,$0f,$00,$10,$08,$07,$00,$0f
	DATA BYTE $3f,$fe,$f8,$f0,$c0,$01,$01,$03
	DATA BYTE $7f,$7f,$09,$09,$09,$09,$09,$09
	DATA BYTE $03,$03,$03,$03,$03,$03,$03,$03
	DATA BYTE $ff,$f0,$c0,$01,$01,$03,$03,$03
	DATA BYTE $14,$14,$14,$22,$22,$22,$22,$22
	DATA BYTE $7f,$bf,$bf,$bf,$bf,$9f,$9f,$9f
	DATA BYTE $0f,$0f,$00,$ff,$ff,$ff,$ff,$ff
	DATA BYTE $03,$03,$03,$03,$07,$07,$07,$07
	DATA BYTE $13,$13,$13,$13,$13,$13,$23,$27
	DATA BYTE $03,$03,$fc,$fc,$fc,$fc,$fc,$fc
	DATA BYTE $ff,$ff,$ff,$1f,$03,$fc,$ff,$ff

image_color:
	DATA BYTE $e1,$e1,$e1,$e1,$e1,$e1,$e1,$e1
	DATA BYTE $e1,$e1,$eb,$eb,$eb,$eb,$eb,$eb
	DATA BYTE $e1,$eb,$b1,$b1,$ba,$ba,$ba,$ba
	DATA BYTE $e1,$eb,$eb,$ba,$ba,$ba,$ba,$a1
	DATA BYTE $e1,$e1,$e1,$e1,$eb,$eb,$eb,$eb
	DATA BYTE $e1,$e1,$eb,$eb,$eb,$eb,$eb,$eb
	DATA BYTE $b1,$b1,$b1,$b1,$ba,$ba,$ba,$ba
	DATA BYTE $ba,$ba,$ba,$ba,$a1,$ba,$a1,$a8
	DATA BYTE $ba,$ba,$ba,$ba,$ba,$ba,$a1,$a8
	DATA BYTE $eb,$eb,$eb,$b1,$b1,$b1,$b1,$ba
	DATA BYTE $e1,$e1,$e1,$e1,$e1,$eb,$eb,$eb
	DATA BYTE $eb,$eb,$eb,$eb,$eb,$eb,$eb,$eb
	DATA BYTE $ba,$ba,$a8,$a9,$a9,$a9,$a9,$a9
	DATA BYTE $81,$81,$81,$91,$91,$91,$91,$91
	DATA BYTE $a8,$a8,$a8,$a8,$98,$98,$98,$98
	DATA BYTE $ba,$ba,$ba,$ba,$ba,$ba,$ba,$ba
	DATA BYTE $eb,$eb,$eb,$eb,$eb,$eb,$eb,$eb
	DATA BYTE $eb,$eb,$eb,$eb,$eb,$eb,$eb,$eb
	DATA BYTE $a9,$a9,$a1,$b1,$b9,$91,$91,$91
	DATA BYTE $91,$91,$91,$91,$91,$91,$91,$91
	DATA BYTE $98,$91,$91,$91,$91,$91,$91,$91
	DATA BYTE $ba,$ba,$ba,$ba,$a9,$a1,$a1,$a1
	DATA BYTE $eb,$eb,$eb,$eb,$eb,$eb,$eb,$eb
	DATA BYTE $eb,$eb,$eb,$eb,$a1,$a1,$a1,$a1
	DATA BYTE $91,$91,$91,$91,$91,$b9,$b9,$b9
	DATA BYTE $91,$91,$91,$91,$91,$91,$91,$91
	DATA BYTE $91,$91,$91,$91,$91,$91,$91,$91
	DATA BYTE $a8,$a8,$a8,$a8,$a8,$a8,$a8,$a8
	DATA BYTE $eb,$ea,$ea,$ea,$ea,$eb,$ea,$eb
	DATA BYTE $a1,$a1,$a1,$a1,$a1,$a1,$a1,$ba
	DATA BYTE $b9,$b9,$b9,$b9,$b9,$b9,$91,$91
	DATA BYTE $91,$91,$91,$91,$96,$98,$98,$96
	DATA BYTE $91,$91,$91,$91,$96,$98,$98,$96
	DATA BYTE $a8,$a8,$a8,$a8,$a8,$a8,$a8,$a8
	DATA BYTE $eb,$ea,$eb,$eb,$eb,$eb,$eb,$eb
	DATA BYTE $ea,$ea,$ea,$ea,$ea,$ea,$ea,$e1
	DATA BYTE $ba,$ba,$ba,$ba,$ba,$ba,$ba,$ba
	DATA BYTE $b1,$b1,$b1,$b1,$ba,$ba,$ba,$ba
	DATA BYTE $96,$91,$f1,$91,$91,$91,$f1,$91
	DATA BYTE $96,$98,$98,$98,$98,$a8,$a1,$a8
	DATA BYTE $a8,$a8,$ba,$ba,$ba,$ba,$ba,$ba
	DATA BYTE $eb,$eb,$eb,$eb,$eb,$eb,$eb,$eb
	DATA BYTE $e1,$e1,$e1,$a1,$a5,$a5,$a5,$a5
	DATA BYTE $ba,$ba,$ba,$ba,$ba,$ba,$ba,$ba
	DATA BYTE $ba,$ba,$ba,$ba,$ba,$ba,$ba,$ba
	DATA BYTE $91,$91,$f1,$71,$71,$71,$71,$71
	DATA BYTE $a8,$a8,$a1,$a7,$a7,$a7,$a7,$a7
	DATA BYTE $ba,$ba,$ba,$ba,$ba,$ba,$ba,$ba
	DATA BYTE $eb,$eb,$b1,$b5,$b5,$b5,$b5,$b5
	DATA BYTE $e1,$e1,$e1,$e1,$e1,$51,$51,$51

image_pattern:
	DATA BYTE $80,$80,$81,$82,$83,$84,$80,$80
	DATA BYTE $80,$85,$86,$87,$88,$89,$8a,$80
	DATA BYTE $80,$8b,$8c,$8d,$8e,$8f,$90,$80
	DATA BYTE $80,$91,$92,$93,$94,$95,$96,$80
	DATA BYTE $80,$97,$98,$99,$9a,$9b,$9c,$80
	DATA BYTE $80,$9d,$9e,$9f,$a0,$a1,$a2,$80
	DATA BYTE $a3,$a4,$a5,$a6,$a7,$a8,$a9,$80
	DATA BYTE $aa,$ab,$ac,$ad,$ae,$af,$b0,$b1
