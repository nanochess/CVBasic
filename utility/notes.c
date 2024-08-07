/*
 ** Calculate frequencies for music notes
 **
 ** by Oscar Toledo G.
 ** https://nanochess.org/
 **
 ** Creation date: Aug/06/2024.
 */

#include <stdio.h>
#include <stdlib.h>
#include <ctype.h>
#include <math.h>

/*
 ** Mathematics based on this post:
 **   https://codepen.io/enxaneta/post/frequencies-of-musical-notes
 */

double frequencies[12];

/*
 ** Calculate octave
 */
void calculate_octave(int octave)
{
    double a;
    
    a = 440.0 * pow(2, octave - 4.0);
    frequencies[0] = a * pow(2, -9.0/12);
    frequencies[1] = a * pow(2, -8.0/12);
    frequencies[2] = a * pow(2, -7.0/12);
    frequencies[3] = a * pow(2, -6.0/12);
    frequencies[4] = a * pow(2, -5.0/12);
    frequencies[5] = a * pow(2, -4.0/12);
    frequencies[6] = a * pow(2, -3.0/12);
    frequencies[7] = a * pow(2, -2.0/12);
    frequencies[8] = a * pow(2, -1.0/12);
    frequencies[9] = a;
    frequencies[10] = a * pow(2, 1.0/12);
    frequencies[11] = a * pow(2, 2.0/12);
}

/*
 ** Main program
 */
int main(int argc, char *argv[])
{
    int c;
    int d;
    int e;
    int base_freq;
    int max;
    int value;
    
    if (argc == 1) {
        fprintf(stderr, "\n");
        fprintf(stderr, "Usage:\n");
        fprintf(stderr, "    notes [-sn] 3579545 >source.asm\n");
        fprintf(stderr, "\n");
        fprintf(stderr, "It will generate an assembler note table for the given\n");
        fprintf(stderr, "frequency. This is useful in my CVBasic compiler\n");
        fprintf(stderr, "because I need 3 tables: 3.58 mhz, 4.00 mhz, and 2.00 mhz.\n");
        fprintf(stderr, "Of course, doing these tables manually is a chore.\n");
        fprintf(stderr, "\n");
        fprintf(stderr, "The values are valid for AY-3-8910 or SN76489 chips.\n");
        fprintf(stderr, "\n");
        fprintf(stderr, "It will warn you if the final value exceeds 4095 or\n");
        fprintf(stderr, "1023 (if the -sn option is used).\n");
        fprintf(stderr, "\n");
        fprintf(stderr, "Base musical frequencies are output in stderr, and\n");
        fprintf(stderr, "assembler code in stdout.\n");
        fprintf(stderr, "\n");
        exit(1);
    }
    fprintf(stderr, "Notes v0.1.0 Aug/07/2024 by Oscar Toledo G. https://nanochess.org\n");
    
    if (argv[1][0] == '-' && tolower(argv[1][1] == 's') && tolower(argv[1][2]) == 'n') {
        base_freq = atoi(argv[2]);
        max = 1023;
    } else {
        base_freq = atoi(argv[1]);
        max = 4095;
    }
    fprintf(stdout, "\t;\n");
    fprintf(stdout, "\t; Musical notes table.\n");
    fprintf(stdout, "\t;\n");
    fprintf(stdout, "music_notes_table:\n");
    fprintf(stdout, "\t; Silence - 0\n");
    fprintf(stdout, "\tdw 0\n");
    for (c = 2; c < 8; c++) {
        switch (c) {
            case 2:
                fprintf(stdout, "\t; Values for %4.2f mhz.\n", base_freq / 1e6);
                fprintf(stdout, "\t; 2nd octave - Index 1\n");
                break;
            case 3:
                fprintf(stdout, "\t; 3rd octave - Index 13\n");
                break;
            case 4:
                fprintf(stdout, "\t; 4th octave - Index 25\n");
                break;
            case 5:
                fprintf(stdout, "\t; 5th octave - Index 37\n");
                break;
            case 6:
                fprintf(stdout, "\t; 6th octave - Index 49\n");
                break;
            case 7:
                fprintf(stdout, "\t; 7th octave - Index 61\n");
                break;
        }
        calculate_octave(c);
        if (c == 7)
            e = 3;
        else
            e = 12;
        fprintf(stdout, "\tdw ");
        for (d = 0; d < e; d++) {
            fprintf(stderr, "%4.1f%s", frequencies[d], (d == e - 1) ? "\n" : ",");
            value = (int) (base_freq / 32.0 / frequencies[d] + 0.5);
            if (value > max)
                fprintf(stderr, "Warning: Exceeded range for octave %d, note %d\n", c, d);
            fprintf(stdout, "%d%c", value, (d == e - 1) ? '\n' : ',');
        }
        fprintf(stderr, "---\n");
    }
    exit(0);
}

