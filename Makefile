# Ultra simple makefile for CVBasic
# by Oscar Toledo G.
# https://github.com/nanochess/CVBasic
#
CFLAGS = -O

build: cvbasic.o node.o z80.o
	@$(CC) cvbasic.o node.o z80.o -o cvbasic

check: build
	@./cvbasic examples/viboritas.bas /tmp/viboritas.asm

clean:
	@rm cvbasic cvbasic.o node.o z80.o

love:
	@echo "...not war"
