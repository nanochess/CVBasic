rom_end:
	times $fffa-$ db $ff

	dw nmi_handler
	dw START
	dw irq_handler	
