/*
** Switch two 8K banks (for Creativision MAME)
** Use with --creativision -rom16 switch of CVBasic.
**
** by Oscar Toledo G.
**
** Creation date: Sep/12/2024.
*/

#include <stdio.h>
#include <stdlib.h>

char rom[16384];

/*
** Main program
*/
int main(int argc, char *argv[])
{
	FILE *input;
	FILE *output;

	if (argc != 2) {
		fprintf(stderr, "Usage: switch game.rom\n");
		exit(1);
	}
	input = fopen(argv[1], "rb");
	if (input == NULL) {
		fprintf(stderr, "Cannot open '%s'\n", argv[1]);
		exit(1);
	}	
	if (fread(rom, 1, sizeof(rom), input) != sizeof(rom)) {
		fprintf(stderr, "Cannot read at least 16K\n");
		exit(1);
	}
	fclose(input);
	output = fopen(argv[1], "wb");
	if (output == NULL) {
		fprintf(stderr, "Cannot open '%s'\n", argv[1]);
		exit(1);
	}
	if (fwrite(rom + 8192, 1, 8192, output) != 8192) {
		fprintf(stderr, "Couldn't write switched ROM data\n");
		exit(1);
	}
	if (fwrite(rom, 1, 8192, output) != 8192) {
		fprintf(stderr, "Couldn't write switched ROM data\n");
		exit(1);
	}
	fclose(output);
	exit(0);
}

