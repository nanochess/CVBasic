# Ultra simple makefile for CVBasic
# by Oscar Toledo G.
# https://github.com/nanochess/CVBasic
#
CFLAGS = -O

cvbasic: cvbasic.o node.o driver.o cpuz80.o cpu6502.o cpu9900.o
	@$(CC) cvbasic.o node.o driver.o cpuz80.o cpu6502.o cpu9900.o -o $@ $(LDFLAGS)

check: cvbasic
	@./$< examples/viboritas.bas /tmp/viboritas.asm
	@./$< --sms examples/viboritas_sms.bas /tmp/viboritas_sms.asm
	@./$< --nes examples/viboritas_nes.bas /tmp/viboritas_nes.asm

clean:
	@rm cvbasic cvbasic.o node.o driver.o cpuz80.o cpu6502.o cpu9900.o

love:
	@echo "...not war"
