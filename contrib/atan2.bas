	'
	' atan2 and getsincos functions for 256 degrees circles
	'
	' Contributed by Arturo Ragozini (ARTRAG)
	'
	' Added Jan/10/2026.
	'

''''''''''''''''''''''''''''''''''''''''''''''''
'        ;;;;;;;; atan(2^(x/32))*128/pi ;;;;;;;;
atan_tab:   
        data $20,$20,$20,$21,$21,$22,$22,$23,$23,$23,$24,$24,$25,$25,$26,$26
        data $26,$27,$27,$28,$28,$28,$29,$29,$2A,$2A,$2A,$2B,$2B,$2C,$2C,$2C
        data $2D,$2D,$2D,$2E,$2E,$2E,$2F,$2F,$2F,$30,$30,$30,$31,$31,$31,$31
        data $32,$32,$32,$32,$33,$33,$33,$33,$34,$34,$34,$34,$35,$35,$35,$35
        data $36,$36,$36,$36,$36,$37,$37,$37,$37,$37,$37,$38,$38,$38,$38,$38
        data $38,$39,$39,$39,$39,$39,$39,$39,$39,$3A,$3A,$3A,$3A,$3A,$3A,$3A
        data $3A,$3B,$3B,$3B,$3B,$3B,$3B,$3B,$3B,$3B,$3B,$3B,$3C,$3C,$3C,$3C
        data $3C,$3C,$3C,$3C,$3C,$3C,$3C,$3C,$3C,$3D,$3D,$3D,$3D,$3D,$3D,$3D
        data $3D,$3D,$3D,$3D,$3D,$3D,$3D,$3D,$3D,$3D,$3D,$3D,$3E,$3E,$3E,$3E
        data $3E,$3E,$3E,$3E,$3E,$3E,$3E,$3E,$3E,$3E,$3E,$3E,$3E,$3E,$3E,$3E
        data $3E,$3E,$3E,$3E,$3E,$3E,$3E,$3E,$3E,$3E,$3E,$3E,$3F,$3F,$3F,$3F
        data $3F,$3F,$3F,$3F,$3F,$3F,$3F,$3F,$3F,$3F,$3F,$3F,$3F,$3F,$3F,$3F
        data $3F,$3F,$3F,$3F,$3F,$3F,$3F,$3F,$3F,$3F,$3F,$3F,$3F,$3F,$3F,$3F
        data $3F,$3F,$3F,$3F,$3F,$3F,$3F,$3F,$3F,$3F,$3F,$3F,$3F,$3F,$3F,$3F
        data $3F,$3F,$3F,$3F,$3F,$3F,$3F,$3F,$3F,$3F,$3F,$3F,$3F,$3F,$3F,$3F
        data $3F,$3F,$3F,$3F,$3F,$3F,$3F,$3F,$3F,$3F,$3F,$3F,$3F,$3F,$3F,$3F
 
'        ;;;;;;;; log2(x)*32 ;;;;;;;; 
log2_tab:  
        data $00,$00,$20,$32,$40,$4A,$52,$59,$60,$65,$6A,$6E,$72,$76,$79,$7D
        data $80,$82,$85,$87,$8A,$8C,$8E,$90,$92,$94,$96,$98,$99,$9B,$9D,$9E
        data $A0,$A1,$A2,$A4,$A5,$A6,$A7,$A9,$AA,$AB,$AC,$AD,$AE,$AF,$B0,$B1
        data $B2,$B3,$B4,$B5,$B6,$B7,$B8,$B9,$B9,$BA,$BB,$BC,$BD,$BD,$BE,$BF
        data $C0,$C0,$C1,$C2,$C2,$C3,$C4,$C4,$C5,$C6,$C6,$C7,$C7,$C8,$C9,$C9
        data $CA,$CA,$CB,$CC,$CC,$CD,$CD,$CE,$CE,$CF,$CF,$D0,$D0,$D1,$D1,$D2
        data $D2,$D3,$D3,$D4,$D4,$D5,$D5,$D5,$D6,$D6,$D7,$D7,$D8,$D8,$D9,$D9
        data $D9,$DA,$DA,$DB,$DB,$DB,$DC,$DC,$DD,$DD,$DD,$DE,$DE,$DE,$DF,$DF
        data $DF,$E0,$E0,$E1,$E1,$E1,$E2,$E2,$E2,$E3,$E3,$E3,$E4,$E4,$E4,$E5
        data $E5,$E5,$E6,$E6,$E6,$E7,$E7,$E7,$E7,$E8,$E8,$E8,$E9,$E9,$E9,$EA
        data $EA,$EA,$EA,$EB,$EB,$EB,$EC,$EC,$EC,$EC,$ED,$ED,$ED,$ED,$EE,$EE
        data $EE,$EE,$EF,$EF,$EF,$EF,$F0,$F0,$F0,$F1,$F1,$F1,$F1,$F1,$F2,$F2
        data $F2,$F2,$F3,$F3,$F3,$F3,$F4,$F4,$F4,$F4,$F5,$F5,$F5,$F5,$F5,$F6
        data $F6,$F6,$F6,$F7,$F7,$F7,$F7,$F7,$F8,$F8,$F8,$F8,$F9,$F9,$F9,$F9
        data $F9,$FA,$FA,$FA,$FA,$FA,$FB,$FB,$FB,$FB,$FB,$FC,$FC,$FC,$FC,$FC
        data $FD,$FD,$FD,$FD,$FD,$FD,$FE,$FE,$FE,$FE,$FE,$FF,$FF,$FF,$FF,$FF
        data $FF							' trick to cope with 256
		

'-----------------------------------------------
' Source: https://www.msx.org/forum/msx-talk/development/8-bit-atan2?page=0
' 8-bit atan2
' Calculate the angle, in a 256-degree circle.
' The trick is to use logarithms to get the y/x ratio and
' integrate the power function into the atan table. 
'   input
'   #dx_in, #dy_in    in -256,255
'
'   output
'   angle       	 in 0-255
'      ^
'  q1  |  q0
'------+------>
'  q3  |  q2
'      |
		
	signed #dx_in
	signed #dy_in
		
atan2:  procedure
	if 	(#dy_in>0) then 
		if 	(#dx_in>0) then 
			gosub atan2_q0			'	q0 
		else
			#dx_in=-#dx_in			'	q1 				
			gosub atan2_q0 
			angle = (-angle) and $7F
			return		
		end if
	else 
		if 	(#dx_in>0) then 
			#dy_in=-#dy_in			'	q2 
			gosub atan2_q0 
			angle = -angle
			return		
		else
			#dx_in=-#dx_in			'	q3 				
			#dy_in=-#dy_in
			gosub atan2_q0 
			angle = angle + 128
			return		
		end if
	end if
	return
	end
		
atan2_q0: procedure         
	if (#dx_in>=#dy_in) then
		angle = (-atan_tab(log2_tab(#dx_in)-log2_tab(#dy_in))) and $3F		
	else
		angle = atan_tab(log2_tab(#dy_in)-log2_tab(#dx_in))
	end if
	return		
	end
		
    	
		
';;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
'    input
'    angle       in 0-255
' 
'    output
'    #dy_out = sin(angle)		in -256,256
' 	 #dx_out = cos(angle)    	in -256,256
		
getsincos: procedure
	#dy_out = #sin_table(angle)
	#dx_out = #cos_table(angle)
	end
	
#sin_table:
	data   0,    6,   12,   18,   25,   31,   37,   43,   49,   56,   62,   68,   74,   80,   86,   92
	data  97,  103,  109,  115,  120,  126,  131,  136,  142,  147,  152,  157,  162,  167,  171,  176
	data 181,  185,  189,  193,  197,  201,  205,  209,  212,  216,  219,  222,  225,  228,  231,  234
	data 236,  238,  241,  243,  244,  246,  248,  249,  251,  252,  253,  254,  254,  255,  255,  255
#cos_table:
	data  256,  255,  255,  255,  254,  254,  253,  252,  251,  249,  248,  246,  244,  243,  241,  238
	data  236,  234,  231,  228,  225,  222,  219,  216,  212,  209,  205,  201,  197,  193,  189,  185
	data  181,  176,  171,  167,  162,  157,  152,  147,  142,  136,  131,  126,  120,  115,  109,  103
	data   97,   92,   86,   80,   74,   68,   62,  56,    49,   43,   37,   31,   25,   18,   12,    6
	data    0,   -6,  -12,  -18,  -25,  -31,  -37,  -43,  -49,  -56,  -62,  -68,  -74,  -80,  -86,  -92
	data  -97, -103, -109, -115, -120, -126, -131, -136, -142, -147, -152, -157, -162, -167, -171, -176
	data -181, -185, -189, -193, -197, -201, -205, -209, -212, -216, -219, -222, -225, -228, -231, -234
	data -236, -238, -241, -243, -244, -246, -248, -249, -251, -252, -253, -254, -254, -255, -255, -255
	data -256, -255, -255, -255, -254, -254, -253, -252, -251, -249, -248, -246, -244, -243, -241, -238
	data -236, -234, -231, -228, -225, -222, -219, -216, -212, -209, -205, -201, -197, -193, -189, -185
	data -181, -176, -171, -167, -162, -157, -152, -147, -142, -136, -131, -126, -120, -115, -109, -103
	data  -97,  -92,  -86,  -80,  -74,  -68,  -62,  -56,  -49,  -43,  -37,  -31,  -25,  -18,  -12,   -6
	data    0,    6,   12,   18,   25,   31,   37,   43,   49,   56,   62,   68,   74,   80,   86,   92
	data   97,  103,  109,  115,  120,  126,  131,  136,  142,  147,  152,  157,  162,  167,  171,  176
	data  181,  185,  189,  193,  197,  201,  205,  209,  212,  216,  219,  222,  225,  228,  231,  234
	data  236,  238,  241,  243,  244,  246,  248,  249,  251,  252,  253,  254,  254,  255,  255,  255

