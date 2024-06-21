# Ultra simple makefile for CVBasic
# by Oscar Toledo G.
# https://github.com/nanochess/CVBasic
#
build:
	@cc cvbasic.c node.c -o cvbasic

clean:
	@rm cvbasic node

love:
	@echo "...not war"

