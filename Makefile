# Ultra simple makefile for CVBasic
# by Oscar Toledo G.
# https://github.com/nanochess/CVBasic
#
CFLAGS = -O

build: cvbasic.c node.c
	@$(CC) $(CFLAGS) cvbasic.c node.c -o cvbasic

check: build
	@./cvbasic examples/test1.bas /tmp/test1.asm

clean:
	@rm cvbasic

love:
	@echo "...not war"
