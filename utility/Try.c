/*
 ** Pletter decompressor for TI-99/4A
 **
 ** C version contributed by JasonACT
 **
 ** Aug/31/2024.
 */

#define _CRT_SECURE_NO_WARNINGS
#include <stdio.h>

//unsigned char * VDPDATA   = 0x8800;
//unsigned char * VDPSTATUS = 0x8802;
//unsigned char * VDPWDATA  = 0x8c00;
//unsigned char * VDPWADR   = 0x8c02;

unsigned char data [1024 * 1024] = {
    0x00
};

unsigned char dest [1024 * 1024] = {
    0x00
};

unsigned char * getbit (unsigned char * a, unsigned char * hl, unsigned char * carry) {
    unsigned char carry2;

    if (*a & 0x80) *carry = 1; else *carry = 0;
    *a <<= 1;
    if (*a == 0) {
        *a = *hl++; //printf ("\t\t%02X (%c)\n", *a, *a);
        if (*a & 0x80) carry2 = 1; else carry2 = 0;
        *a <<= 1;
        *a |= *carry;
        *carry = carry2;
    }
    return hl;
}

unsigned short unpack (unsigned short de, unsigned char * hl) {
    unsigned char carry;
    unsigned char a = *hl++;
    unsigned char b;
    unsigned char c;
    unsigned char t;
    unsigned short bc;
    unsigned short _hl;
    unsigned short hl2;
    unsigned short ix = a >> 5;
    int i;

    //printf ("\t\t%02X (%c)\n", a, a);
    a <<= 3;
    a |= 0x04;
literal:
    /*__asm volatile ("LIMI 0\n");
    *VDPWADR = de;
    *VDPWADR = 0x40 | (de++ >> 8);
    *VDPWDATA = *hl++;
    __asm volatile ("LIMI 2\n");*/
    //printf ("%04X=%02X (%c)\n", de, *hl, *hl);
    dest [de++] = *hl++;
loop:
    hl = getbit (&a, hl, &carry);
    if (carry == 0) goto literal;

    _hl = 1;
//getlen:
    hl = getbit (&a, hl, &carry);
    if (carry == 0) goto lenok;
lus:
    hl = getbit (&a, hl, &carry);
    if (_hl & 0x8000) return de;
    _hl = _hl + _hl + carry;

    hl = getbit (&a, hl, &carry);
    if (carry == 0) goto lenok;

    hl = getbit (&a, hl, &carry);
    if (_hl & 0x8000) return de;
    _hl = _hl + _hl + carry;

    hl = getbit (&a, hl, &carry);
    if (carry) goto lus;
lenok:
    _hl++;
    c = *hl++; //printf ("\t\t%02X (%c)\n", c, c);
    b = 0;
    if ((c & 0x80) == 0) goto offsok;

    i = ix;
    if (i) {
        while (i) {
            hl = getbit (&a, hl, &carry);
            b <<= 1; b |= carry;
            i--;
        }
        hl = getbit (&a, hl, &carry);
        if (carry) {
            carry = 0;
            b++;
            c &= 0x7F;
        }
    }
offsok:
    bc = (b << 8) | c;
    bc++;
    hl2 = de - bc - carry;
    bc = _hl;
loop2:
    /*__asm volatile ("LIMI 0\n");
    ...
    __asm volatile ("LIMI 2\n");*/
    t = dest [hl2++]; //printf ("%04X=%02X (%c)\n", de, t, t);
    dest [de++] = t;
    bc--;
    if (bc) goto loop2;
    goto loop;
}

static char * args [] = {
    "p",
    "test.txt",
    "test.bin"
};

int mainy(int argc, char *argv[]);

void main () {
    int end;
    FILE * f;

    mainy (3, args); // compress test file using pletter.c with main() renamed

    f = fopen ("test.bin", "rb");
    if (f) {
        fread (data, 1, 1024 * 1024, f);
        fclose (f);
        end = unpack (0x0000, data);
        f = fopen ("result.bin", "wb");
        if (f) {
            fwrite (dest, 1, end, f);
            fclose (f);
        }
    }
    return;
}
