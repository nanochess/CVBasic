	;
	; Z80 integer 32-bit square root
	;
	; by Oscar Toledo G.
	;
	; Creation date: Apr/07/2026.
	;
	; Based on code from https://stackoverflow.com/questions/15557667/square-root-by-bit-shift
	;
	; Input:
	;   dehl = number
	;
	; Output:
	;   hl = root.
	;
isqrt:
	ld a,d
	or e
	or h
	or l
	ret z

	exx
	ld hl,0
	ld de,0
	exx
	ld ix,.bit
.0:
	ld a,d
	sub (ix+3)
	jr nz,.1
	ld a,e
	sub (ix+2)
	jr nz,.1
	ld a,h
	sub (ix+1)
	jr nz,.1
	ld a,l
	sub (ix+0)
.1:	jr z,.2
	jr c,.2
	inc ix
	inc ix
	inc ix
	inc ix
	jp .0

.2:	ld a,ixl
	cp .bit+16*4
	jr z,.3
	exx
	push de
	push hl
	ld a,l
	add a,(ix+0)
	ld l,a
	ld a,h
	adc a,(ix+1)
	ld h,a
	ld a,e
	adc a,(ix+2)
	ld e,a
	ld a,d
	adc a,(ix+3)
	ld d,a	
	exx
	ld a,l
	exx
	sub l
	exx
	ld a,h
	exx
	sbc a,h
	exx
	ld a,e
	exx
	sbc a,e
	exx
	ld a,d
	exx
	sbc a,d
	exx
	jp c,.5
	ld a,l
	exx
	sub l
	exx
	ld l,a
	ld a,h
	exx
	sbc a,h
	exx
	ld h,a
	ld a,e
	exx
	sbc a,e
	exx
	ld e,a
	ld a,d
	exx
	sbc a,d
	pop hl
	pop de
	exx
	ld d,a

	exx
	srl d
	rr e
	rr h
	rr l
	ld a,l
	add a,(ix+0)
	ld l,a
	ld a,h
	adc a,(ix+1)
	ld h,a
	ld a,e
	adc a,(ix+2)
	ld e,a
	ld a,d
	adc a,(ix+3)
	ld d,a
	exx
	jp .4

.5:
	exx
	pop hl
	pop de
	srl d
	rr e
	rr h
	rr l
	exx	
.4:
	inc ix
	inc ix
	inc ix
	inc ix
	jp .2
.3:
	exx
	ret

.bit:
	dw $0000,$4000
	dw $0000,$1000
	dw $0000,$0400
	dw $0000,$0100
	dw $0000,$0040
	dw $0000,$0010
	dw $0000,$0004
	dw $0000,$0001
	dw $4000,$0000
	dw $1000,$0000
	dw $0400,$0000
	dw $0100,$0000
	dw $0040,$0000
	dw $0010,$0000
	dw $0004,$0000
	dw $0001,$0000

