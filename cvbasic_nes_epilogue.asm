rom_end:
    if CVBASIC_BANK_SWITCHING
	forg CVBASIC_BANK_ROM_SIZE*1024+16-6	; Go to final of ROM minus vectors
   else
	times $fffa-$ db $ff
    endif

	dw nmi_handler
	dw START
	dw irq_handler	
