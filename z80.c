/*
 ** Z80 assembler output routines for CVBasic
 **
 ** by Oscar Toledo G.
 **
 ** Creation date: Jul/31/2024. Separated from CVBasic.c
 */

#include <stdio.h>
#include <string.h>
#include <ctype.h>
#include <stdlib.h>
#include "cvbasic.h"

static char z80_line[MAX_LINE_SIZE];

static char z80_line_1[MAX_LINE_SIZE];
static char z80_line_2[MAX_LINE_SIZE];
static char z80_line_3[MAX_LINE_SIZE];

static char z80_a_content[MAX_LINE_SIZE];
static char z80_hl_content[MAX_LINE_SIZE];
static int z80_flag_z_valid;

static void z80_emit_line(void);

void z80_emit_line(void)
{
    int c;
    int d;
    
    /*
     ** Optimize the following cases:
     **     JP Z,cv1
     **     JP somewhere
     ** cv1:
     **
     **     JP Z,cv1
     **     CALL somewhere
     ** cv1:
     */
    if (memcmp(z80_line_2, "\tJP NZ," INTERNAL_PREFIX, 9) == 0 && isdigit(z80_line_2[9]) &&
        (memcmp(z80_line_3, "\tJP ", 4) == 0 || memcmp(z80_line_3, "\tCALL ", 6) == 0) &&
        memcmp(z80_line, INTERNAL_PREFIX, 2) == 0 && isdigit(z80_line[2]) &&
        atoi(z80_line_2 + 9) == atoi(z80_line + 2)) {
        if (z80_line_3[1] == 'J') {
            strcpy(z80_line_2, "\tJP Z,");
            strcat(z80_line_2, z80_line_3 + 4);
        } else {
            strcpy(z80_line_2, "\tCALL Z,");
            strcat(z80_line_2, z80_line_3 + 6);
        }
        z80_line_3[0] = '\0';
        z80_line[0] = '\0';
    }
    
    /*
     ** Optimize the following case:
     **     CALL cv1
     **     RET
     */
    if (memcmp(z80_line_3, "\tCALL " INTERNAL_PREFIX, 8) == 0 && memcmp(z80_line, "\tRET\n", 5) == 0) {
        strcpy(z80_line, "\tJP ");
        strcat(z80_line, z80_line_3 + 6);
        z80_line_3[0] = '\0';
    }
    if (z80_line_1[0])
        fprintf(output, "%s", z80_line_1);
    strcpy(z80_line_1, z80_line_2);
    strcpy(z80_line_2, z80_line_3);
    strcpy(z80_line_3, z80_line);
}

void z80_dump(void)
{
    if (z80_line_1[0])
        fprintf(output, "%s", z80_line_1);
    if (z80_line_2[0])
        fprintf(output, "%s", z80_line_2);
    if (z80_line_3[0])
        fprintf(output, "%s", z80_line_3);
    z80_line_1[0] = '\0';
    z80_line_2[0] = '\0';
    z80_line_3[0] = '\0';
}

/*
 ** Emit a Z80 label
 */
void z80_label(char *label)
{
    sprintf(z80_line, "%s:\n", label);
    z80_emit_line();
    z80_a_content[0] = '\0';
    z80_hl_content[0] = '\0';
    z80_flag_z_valid = 0;
}

/*
 ** Reset A register (technically a null label)
 */
void z80_empty(void)
{
    z80_a_content[0] = '\0';
    z80_flag_z_valid = 0;
}

/*
 ** Emit a Z80 instruction with no operand
 */
void z80_noop(char *mnemonic)
{
    sprintf(z80_line, "\t%s\n", mnemonic);
    z80_emit_line();
    z80_a_content[0] = '\0';
    z80_hl_content[0] = '\0';
    z80_flag_z_valid = 0;
}

/*
 ** Emit a Z80 instruction with a single operand
 */
void z80_1op(char *mnemonic, char *operand)
{
    /*
     ** Optimize zero in register A
     */
    if (strcmp(mnemonic, "SUB") == 0) {
        if (strcmp(operand, "A") == 0) {
            if (strcmp(z80_a_content, "0") == 0)
                return;
        }
    }
    
    /*
     ** Important note: AND A is used for the sole purpose of
     ** make sure A is zero.
     **
     ** It is used OR A for clearing the carry flag for SBC HL,DE
     */
    if (strcmp(mnemonic, "AND") == 0) {
        if (strcmp(operand, "A") == 0) {
            if (z80_flag_z_valid)
                return;
        }
    }

    sprintf(z80_line, "\t%s %s\n", mnemonic, operand);
    z80_emit_line();
    
    if (strcmp(mnemonic, "PUSH") == 0) {
        /* No affected registers */
    } else if (strcmp(mnemonic, "CP") == 0) {
        /* No affected registers */
        z80_flag_z_valid = 0;
    } else if (strcmp(mnemonic, "POP") == 0) {
        if (strcmp(operand, "AF") == 0) {
            z80_a_content[0] = '\0';
            z80_flag_z_valid = 0;
        } else if (strcmp(operand, "HL") == 0) {
            z80_hl_content[0] = '\0';
        }
    } else if (strcmp(mnemonic, "CALL") == 0 ||
               strcmp(mnemonic, "JP") == 0) {
        z80_a_content[0] = '\0';
        z80_hl_content[0] = '\0';
        z80_flag_z_valid = 0;
    } else if (strcmp(mnemonic, "SUB") == 0) {
        if (strcmp(operand, "A") == 0)
            strcpy(z80_a_content, "0");
        else
            z80_a_content[0] = '\0';
        z80_flag_z_valid = 1;
    } else if (strcmp(mnemonic, "OR") == 0 ||
               strcmp(mnemonic, "XOR") == 0 ||
               strcmp(mnemonic, "AND") == 0) {
        z80_a_content[0] = '\0';
        z80_flag_z_valid = 1;
    } else if (strcmp(mnemonic, "SRL") == 0) {
        if (strcmp(operand, "H") == 0)
            z80_hl_content[0] = '\0';
        else if (strcmp(operand, "A") == 0)
            z80_flag_z_valid = 1;
    } else if (strcmp(mnemonic, "RR") == 0) {
        if (strcmp(operand, "L") == 0)
            z80_hl_content[0] = '\0';
        z80_flag_z_valid = 0;
    } else if (strcmp(mnemonic, "INC") == 0) {
        if (strcmp(operand, "H") == 0 ||
            strcmp(operand, "L") == 0 ||
            strcmp(operand, "HL") == 0) {
            z80_hl_content[0] = '\0';
            z80_flag_z_valid = 0;
        } else if (strcmp(operand, "A") == 0) {
            z80_a_content[0] = '\0';
            z80_flag_z_valid = 1;
        } else if (strcmp(operand, "(HL)") == 0) {
            z80_a_content[0] = '\0';
            z80_flag_z_valid = 0;
        }
    } else if (strcmp(mnemonic, "DEC") == 0) {
        if (strcmp(operand, "H") == 0 ||
            strcmp(operand, "L") == 0 ||
            strcmp(operand, "HL") == 0) {
            z80_hl_content[0] = '\0';
            z80_flag_z_valid = 0;
        } else if (strcmp(operand, "A") == 0) {
            z80_a_content[0] = '\0';
            z80_flag_z_valid = 1;
        } else if (strcmp(operand, "(HL)") == 0) {
            z80_a_content[0] = '\0';
            z80_flag_z_valid = 0;
        }
    } else if (strcmp(mnemonic, "DW") == 0 || strcmp(mnemonic, "ORG") == 0 || strcmp(mnemonic, "FORG") == 0) {
        /* Nothing to do */
    } else {
        fprintf(stderr, "z80_1op: not found mnemonic %s\n", mnemonic);
    }
}

/*
 ** Emit a Z80 instruction with two operands
 */
void z80_2op(char *mnemonic, char *operand1, char *operand2)
{
    
    /*
     ** Optimize constant expressions (both constants and access to memory variables)
     */
    if (strcmp(mnemonic, "LD") == 0) {
        if (strcmp(operand1, "A") == 0) {
            if (strcmp(operand2, z80_a_content) == 0)
                return;
            if (strcmp(operand2, z80_hl_content) == 0)
                operand2 = "L";
        } else if (strcmp(operand1, "HL") == 0) {
            if (strcmp(operand2, z80_hl_content) == 0)
                return;
        }
    }
    
    sprintf(z80_line, "\t%s %s,%s\n", mnemonic, operand1, operand2);
    z80_emit_line();

    if (strcmp(mnemonic, "JP") == 0 ||
        strcmp(mnemonic, "JR") == 0 ||
        strcmp(mnemonic, "OUT") == 0 ||
        strcmp(mnemonic, "RES") == 0 ||
        strcmp(mnemonic, "SET") == 0) {
        /* No affected registers or flags */
    } else if (strcmp(mnemonic, "EX") == 0) {
        z80_hl_content[0] = '\0';
    } else if (strcmp(mnemonic, "IN") == 0) {
        z80_a_content[0] = '\0';
        z80_flag_z_valid = 0;
    } else if (strcmp(mnemonic, "ADD") == 0 || strcmp(mnemonic, "SBC") == 0) {
        if (strcmp(operand1, "A") == 0) {
            z80_a_content[0] = '\0';
            z80_flag_z_valid = 1;
        } else {
            z80_hl_content[0] = '\0';
            z80_flag_z_valid = 0;
        }
    } else if (strcmp(mnemonic, "LD") == 0) {
        if (strcmp(operand1, "A") == 0)  /* Read value into accumulator */
            z80_flag_z_valid = 0;       /* Z status isn't valid */
        if (strcmp(operand1, "L") == 0 || strcmp(operand1, "H") == 0)
            z80_hl_content[0] = '\0';
        if (strcmp(operand1, "HL") == 0)
            strcpy(z80_hl_content, operand2);
        else if (strcmp(operand2, "HL") == 0)
            strcpy(z80_hl_content, operand1);
        if (strcmp(operand1, "A") == 0 && strcmp(operand2, "(HL)") == 0) {
            z80_a_content[0] = '\0';
        } else if (strcmp(operand1, "(HL)") == 0 && strcmp(operand2, "A") == 0) {
            /* A keeps its value */
        } else if (strcmp(operand1, "A") == 0) {
            if (isdigit(operand2[0]) || operand2[0] == '(')
                strcpy(z80_a_content, operand2);
            else
                z80_a_content[0] = '\0';
        } else if (strcmp(operand2, "A") == 0 && operand1[0] == '(') {
            strcpy(z80_a_content, operand1);
        }
    } else {
        fprintf(stderr, "z80_2op: not found mnemonic %s\n", mnemonic);
    }
}

